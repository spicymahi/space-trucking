extends "res://scripts/cargo_trial_economy.gd"
## Fixed-fee freight economics for the persistent ship-life session.
## Only the shared world clock calls tick(); arriving never advances time or
## deducts quoted fuel. The flight controller owns actual fuel consumption.

const SAVE_VERSION := 1
const PORT_SUPPLIES := "Port supplies"
const FlightState = preload("res://scripts/longhaul_flight_state.gd")
const WORLD_HOURS_PER_SECOND := 0.12
var debt := 0
var _economy_remainder := 0.0
var _route_quote_cache: Dictionary = {}

func setup(seed_value: int = 4026) -> void:
	super.setup(seed_value)
	debt = 0
	_economy_remainder = 0.0
	_route_quote_cache.clear()
	# Routine station supplies provide real replenishing local work alongside the
	# authored speciality exports. They are reserved exactly like other freight.
	for index in stations.size():
		_add_producer(index, PORT_SUPPLIES, 2.0)
		_add_consumer(index, PORT_SUPPLIES, 2.0)

func tick(hours: float) -> void:
	if not is_finite(hours) or hours <= 0.0: return
	var target_hours := elapsed_hours + hours
	_economy_remainder += hours
	# Production and NPC trades resolve on common hour boundaries, so a sleep
	# skip and ordinary frame-by-frame clock updates produce the same economy.
	while _economy_remainder >= 1.0 - 0.000000001:
		super.tick(1.0)
		_economy_remainder = maxf(0.0, _economy_remainder - 1.0)
	elapsed_hours = target_hours

func _leg_quote(source: int, destination: int) -> Dictionary:
	var key := "%d:%d" % [source, destination]
	if _route_quote_cache.has(key): return _route_quote_cache[key].duplicate(true)
	# Match the actual proven flight solver and universal-clock conversion.
	# Quotes use a full load at the catalogue epoch; CHART remains authoritative
	# for the departure epoch and manual manoeuvres. Memoize each port pair so
	# background market matching does not continually run the flight solver.
	var flight := FlightState.new()
	flight.dock_id = source
	flight.ship_position = flight.station_position(source, 0.0)
	flight.velocity = flight.station_velocity(source, 0.0)
	flight.fuel = FlightState.CAPACITY
	flight.cargo_mass = 980.0
	flight.command("engine", "port on")
	flight.command("engine", "starboard on")
	flight.plan_route(System.IDS[destination])
	var quote: Dictionary = super._leg_quote(source, destination)
	quote.route_available = not flight.plan.is_empty()
	if quote.route_available:
		var duration := float(flight.plan.coast) + 120.0
		quote.minutes = ceilf(duration / 6.0) / 10.0
		quote.world_hours = ceilf(duration * WORLD_HOURS_PER_SECOND * 10.0) / 10.0
		quote.fuel_cost = int(ceil(float(flight.plan.fuel) * 0.08))
	else:
		# Unavailable routes remain usable as bounded internal market distances,
		# but _quote excludes them from player offers rather than inventing an ETA.
		quote.world_hours = 216.0
	_route_quote_cache[key] = quote.duplicate(true)
	return quote

func _quote(kind: String, employer: int, source: int, destination: int, commodity: String, units: int) -> Dictionary:
	var quote: Dictionary = super._quote(kind, employer, source, destination, commodity, units)
	var hours := 0.0
	for leg in quote.legs:
		hours += float(leg.world_hours)
	# The customer advertises one fixed fee. These estimates balance the fee;
	# they are not reimbursement, and spending more never increases payment.
	var expected_days := maxi(1, int(ceil(hours / 24.0)))
	var operating_estimate := int(quote.fuel_cost) + expected_days * 40 + 35
	quote.payout = operating_estimate + units * 9 + int(ceil(float(quote.minutes) * 8.0)) + 150
	quote.advance = 0
	quote.advance_paid = false
	quote.remaining_pay = quote.payout
	quote.world_hours = snappedf(hours, 0.1)
	quote.essential_estimate = operating_estimate
	quote.quote_note = "FIXED CONTRACT FEE / contractor pays all operating costs"
	quote.profit = int(quote.payout) - operating_estimate
	var scarcity := float(stations[destination].demand.get(commodity, 0.0)) / MAX_DEMAND
	var value := float(COMMODITY_VALUE.get(commodity, 150))
	quote.employer_margin = int(floor(value * units * (0.8 + scarcity))) - int(quote.payout)
	for leg in quote.legs:
		if not bool(leg.route_available): quote.employer_margin = -1
	return quote

func _nearest_match(employer: int) -> Dictionary:
	var best: Dictionary = {}
	for commodity in stations[employer].supply:
		if float(stations[employer].supply[commodity]) < SMALL_UNITS: continue
		for destination in stations.size():
			if destination == employer: continue
			if float(stations[destination].demand.get(commodity, 0.0)) < SMALL_UNITS: continue
			var quote := _quote("outbound", employer, employer, destination, str(commodity), SMALL_UNITS)
			if int(quote.employer_margin) <= 0: continue
			if best.is_empty() or float(quote.world_hours) < float(best.world_hours): best = quote
	return best

func offers(employer: int = 0) -> Array:
	if employer < 0 or employer >= stations.size(): return []
	if not active.is_empty() and active.phase != "complete": return []
	if _offer_cache.has(employer): return _offer_cache[employer].duplicate(true)
	var board: Array = []
	for contract in [_nearest_match(employer), _best_match("outbound", employer, FULL_UNITS), _best_match("collection", employer, SMALL_UNITS)]:
		if contract.is_empty(): continue
		_serial += 1
		contract.id = "SL-%03d-%04d" % [employer + 1, _serial]
		board.append(contract)
	_offer_cache[employer] = board
	return board.duplicate(true)

func accept(id: String) -> Dictionary:
	var accepted: Dictionary = super.accept(id)
	if accepted.is_empty(): return {}
	# Base acceptance reserves goods and destination capacity. The overridden
	# quote carries zero automatic advance; borrowing is an explicit action.
	active.advance_paid = false
	active.advance_requested = false
	return active.duplicate(true)

func request_advance(essential_cost: int) -> int:
	error = ""
	if active.is_empty() or active.phase not in ["loading", "to_pickup", "delivery"]:
		error = "An advance is available before the first departure on an accepted contract."
		return 0
	if int(active.legs_completed) != 0 or bool(active.get("advance_requested", false)):
		error = "This contract's advance has already been used or its journey has begun."
		return 0
	if essential_cost <= credits:
		error = "Your available credits already cover those essentials."
		return 0
	var shortfall := essential_cost - credits
	var available := maxi(0, int(active.remaining_pay) - debt)
	if shortfall > available:
		error = "This contract cannot fund that shortfall. Choose a smaller route or reduce purchases."
		return 0
	credits += shortfall
	active.advance = shortfall
	active.advance_paid = true
	active.advance_requested = true
	active.remaining_pay = int(active.payout) - shortfall
	return shortfall

func spend(amount: int) -> bool:
	error = ""
	if amount < 0 or amount > credits:
		error = "Not enough credits for this purchase."
		return false
	credits -= amount
	return true

func finish_leg(destination: int) -> bool:
	error = ""
	if destination < 0 or destination != leg_destination():
		error = "This is not the next station on the accepted route."
		return false
	var leg_index := int(active.legs_completed)
	if leg_index >= active.legs.size(): return false
	var leg: Dictionary = active.legs[leg_index]
	# The controller may update station after a fuel/provision stop en route.
	# Arrival at the contracted destination still completes the same leg.
	if int(leg.to) != destination:
		error = "The arrival does not match the next contracted port."
		return false
	active.legs_completed = leg_index + 1
	station = destination
	active.phase = "loading" if active.phase == "to_pickup" else "unloading"
	active.current_phase = active.phase
	return true

func travel_to(destination: int) -> bool:
	# Compatibility for callers of the cargo-trial API. Combined-session travel
	# never silently skips time or takes money for a fuel quote.
	return finish_leg(destination)

func complete(delivered_count: int, total_count: int, at_station: int) -> bool:
	if not super.complete(delivered_count, total_count, at_station): return false
	var repaid := mini(debt, int(active.remaining_pay))
	credits -= repaid
	debt -= repaid
	active.debt_repaid = repaid
	active.net_settlement = int(active.remaining_pay) - repaid
	receipts[-1] = active.duplicate(true)
	return true

func cancel() -> bool:
	error = ""
	# Physical cargo must be returned at pickup. The caller also removes that
	# manifest; never cancel in transit and materialize goods at another port.
	if active.is_empty() or active.phase not in ["loading", "to_pickup"] or int(active.legs_completed) != 0:
		error = "Cancel at the employer's port before beginning the journey."
		return false
	if station != int(active.employer): return false
	var source: Dictionary = stations[int(active.source)]
	var destination: Dictionary = stations[int(active.destination)]
	var commodity := str(active.commodity)
	var units := int(active.units)
	source.supply[commodity] = minf(MAX_STOCK, float(source.supply.get(commodity, 0.0)) + units)
	destination.reserved_inbound[commodity] = maxi(0, int(destination.reserved_inbound.get(commodity, 0)) - units)
	destination.demand[commodity] = minf(MAX_DEMAND - float(destination.reserved_inbound[commodity]), float(destination.demand.get(commodity, 0.0)) + units)
	debt += int(active.advance)
	var receipt := active.duplicate(true)
	receipt.phase = "cancelled"
	receipt.advance_debt = int(active.advance)
	receipts.append(receipt)
	active.clear()
	_offer_cache.clear()
	return true

func snapshot() -> Dictionary:
	var cache: Dictionary = {}
	for key in _offer_cache: cache[str(key)] = _offer_cache[key].duplicate(true)
	return {"version":SAVE_VERSION, "stations":stations.duplicate(true), "active":active.duplicate(true),
		"receipts":receipts.duplicate(true), "credits":credits, "station":station, "debt":debt,
		"elapsed_hours":elapsed_hours, "error":error, "offer_cache":cache, "serial":_serial,
		"economy_remainder":_economy_remainder,
		"rng_seed":str(_rng.seed), "rng_state":str(_rng.state)}

func restore(data: Dictionary) -> bool:
	# Validate before changing live state. RNG integers are strings to survive
	# JSON's double precision numeric representation without losing bits.
	if int(data.get("version", 0)) != SAVE_VERSION: return false
	if not data.get("stations") is Array or data.stations.size() != System.STATIONS.size(): return false
	if not data.get("active") is Dictionary or not data.get("receipts") is Array: return false
	if not data.get("offer_cache") is Dictionary: return false
	if not _valid_contract(data.active, true): return false
	for receipt in data.receipts:
		if not receipt is Dictionary or not _valid_contract(receipt): return false
	if int(data.get("station", -1)) < 0 or int(data.station) >= System.STATIONS.size(): return false
	if int(data.get("credits", -1)) < 0 or int(data.get("debt", -1)) < 0: return false
	if not is_finite(float(data.get("elapsed_hours", -1.0))) or float(data.elapsed_hours) < 0.0: return false
	if float(data.get("economy_remainder", -1.0)) < 0.0 or float(data.economy_remainder) >= 1.0: return false
	if not str(data.get("rng_seed", "")).is_valid_int() or not str(data.get("rng_state", "")).is_valid_int(): return false
	for state in data.stations:
		if not state is Dictionary: return false
		for field in ["supply", "demand", "production", "consumption", "reserved_inbound", "fulfilled"]:
			if not state.get(field) is Dictionary: return false
			for value in state[field].values():
				if not (value is int or value is float) or not is_finite(float(value)) or float(value) < 0.0: return false
	var cache: Dictionary = {}
	for key in data.offer_cache:
		if not str(key).is_valid_int() or int(key) < 0 or int(key) >= System.STATIONS.size(): return false
		if not data.offer_cache[key] is Array: return false
		for contract in data.offer_cache[key]:
			if not contract is Dictionary or not _valid_contract(contract): return false
		cache[int(key)] = data.offer_cache[key].duplicate(true)
		for contract in cache[int(key)]: _normalize_contract(contract)
	stations = data.stations.duplicate(true)
	for state in stations:
		for field in ["supply", "demand", "production", "consumption"]:
			for commodity in state[field]: state[field][commodity] = float(state[field][commodity])
		for field in ["reserved_inbound", "fulfilled"]:
			for commodity in state[field]: state[field][commodity] = int(state[field][commodity])
	active = data.active.duplicate(true)
	_normalize_contract(active)
	receipts = data.receipts.duplicate(true)
	for receipt in receipts: _normalize_contract(receipt)
	credits = int(data.credits)
	station = int(data.station)
	debt = int(data.debt)
	elapsed_hours = float(data.elapsed_hours)
	_economy_remainder = float(data.economy_remainder)
	error = str(data.get("error", ""))
	_offer_cache = cache
	_serial = int(data.get("serial", 0))
	_rng.seed = int(data.rng_seed)
	_rng.state = int(data.rng_state)
	return true

func _valid_contract(contract: Dictionary, allow_empty: bool = false) -> bool:
	if contract.is_empty(): return allow_empty
	for field in ["employer", "source", "destination"]:
		if int(contract.get(field, -1)) < 0 or int(contract[field]) >= System.STATIONS.size(): return false
	for field in ["units", "payout", "advance", "remaining_pay", "fuel_cost"]:
		if not contract.has(field) or int(contract[field]) < 0: return false
	if int(contract.units) not in [SMALL_UNITS, FULL_UNITS]: return false
	if contract.get("kind", "") not in ["outbound", "collection"]: return false
	if not contract.get("legs") is Array: return false
	if contract.legs.size() != (2 if contract.kind == "collection" else 1): return false
	for leg in contract.legs:
		if not leg is Dictionary: return false
		for field in ["from", "to"]:
			if int(leg.get(field, -1)) < 0 or int(leg[field]) >= System.STATIONS.size(): return false
		for field in ["minutes", "world_hours", "fuel_cost"]:
			if not leg.has(field) or not is_finite(float(leg[field])) or float(leg[field]) < 0.0: return false
	return true

func _normalize_contract(contract: Dictionary) -> void:
	for key in ["employer", "source", "destination", "units", "fuel_cost", "handling_pay", "time_pay", "upkeep", "profit", "payout", "advance", "remaining_pay", "employer_margin", "essential_estimate", "fuel_spent", "legs_completed", "box_count", "debt_repaid", "net_settlement", "advance_debt"]:
		if contract.has(key): contract[key] = int(contract[key])
	for key in ["minutes", "world_hours"]:
		if contract.has(key): contract[key] = float(contract[key])
	for leg in contract.get("legs", []):
		for key in ["from", "to", "fuel_cost"]: leg[key] = int(leg[key])
		for key in ["minutes", "world_hours"]: leg[key] = float(leg[key])
