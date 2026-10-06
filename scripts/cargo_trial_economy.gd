extends RefCounted
## Save-free cargo trial economy. Quotes are fixed estimates for this trial's
## abstract transfers; the live flight planner remains the authority in game.
const System = preload("res://scripts/longhaul_system.gd")
const SMALL_UNITS := 24
const FULL_UNITS := 48
const MAX_STOCK := 120.0
const MAX_DEMAND := 120.0
const COMMODITY_VALUE := {
	"Mixed supplies":90, "Machine parts":145, "Provisions":85,
	"Consumer goods":110, "Refined metals":100, "Survey equipment":190,
	"Fuel catalysts":140, "Filters and valves":120, "Mineral samples":160,
	"Ore concentrates":95, "Mining tools":140, "Fresh produce":100,
	"Water filters":115, "Medical supplies":180, "Research samples":220,
	"Laboratory supplies":175, "Spare components":135,
	"Instrument packages":210, "Recorder cartridges":175, "Electronic parts":155
}

var stations: Array = []
var active: Dictionary = {}
var receipts: Array = []
var credits := 600
var station := 0
var elapsed_hours := 0.0
var error := ""
var _rng := RandomNumberGenerator.new()
var _offer_cache: Dictionary = {}
var _serial := 0

func setup(seed_value: int = 4026) -> void:
	_rng.seed = seed_value
	stations.clear()
	active.clear()
	receipts.clear()
	_offer_cache.clear()
	credits = 600
	station = 0
	elapsed_hours = 0.0
	_serial = 0
	error = ""
	for entry in System.STATIONS:
		stations.append({"supply":{}, "demand":{}, "production":{},
			"consumption":{}, "reserved_inbound":{}, "fulfilled":{}})
		var index: int = stations.size()-1
		_add_producer(index, str(entry.exports), 4.0)
		_add_consumer(index, str(entry.imports), 3.5)
	# Secondary products and needs complete the authored station specialities.
	# Ceres is the wholesale source for items without a dedicated factory.
	for commodity in ["Consumer goods", "Filters and valves", "Water filters", "Laboratory supplies", "Electronic parts"]:
		_add_producer(0, commodity, 2.0)
	for pair in [[0,"Medical supplies"], [0,"Provisions"], [2,"Fuel catalysts"],
		[6,"Mineral samples"], [11,"Survey equipment"], [10,"Research samples"],
		[14,"Instrument packages"], [13,"Recorder cartridges"], [1,"Mixed supplies"]]:
		_add_consumer(int(pair[0]), str(pair[1]), 2.0)

func _add_producer(index: int, commodity: String, rate: float) -> void:
	stations[index].supply[commodity] = float(_rng.randi_range(62, 92))
	stations[index].production[commodity] = rate

func _add_consumer(index: int, commodity: String, rate: float) -> void:
	stations[index].demand[commodity] = float(_rng.randi_range(48, 88))
	stations[index].consumption[commodity] = rate

func tick(hours: float) -> void:
	if not is_finite(hours) or hours <= 0.0: return
	elapsed_hours += hours
	for state in stations:
		for commodity in state.production:
			state.supply[commodity] = minf(MAX_STOCK, float(state.supply.get(commodity, 0.0))+float(state.production[commodity])*hours)
		for commodity in state.consumption:
			var free_capacity: float = MAX_DEMAND-float(state.reserved_inbound.get(commodity, 0.0))
			state.demand[commodity] = minf(free_capacity, float(state.demand.get(commodity, 0.0))+float(state.consumption[commodity])*hours)
	# Background haulers touch only free stock/demand. Accepted freight has been
	# taken out of those pools and cannot be consumed by competing deliveries.
	for source in stations.size():
		for commodity in stations[source].supply:
			var destination := _best_buyer(source, commodity)
			if destination < 0: continue
			var amount := minf(float(stations[source].supply[commodity]), float(stations[destination].demand[commodity]))
			# A tick represents a limited background fleet, not an instantaneous
			# perfect market. Keep room for player jobs even after a long time jump.
			amount = minf(amount*0.35, hours*1.5)
			stations[source].supply[commodity] -= amount
			stations[destination].demand[commodity] -= amount
	_offer_cache.clear()

func _best_buyer(source: int, commodity: String) -> int:
	var best := -1
	var score := -INF
	for destination in stations.size():
		if destination == source or float(stations[destination].demand.get(commodity, 0.0)) < 1.0: continue
		var candidate: float = float(stations[destination].demand[commodity])-_leg_quote(source, destination).minutes
		if candidate > score:
			score = candidate
			best = destination
	return best

func _leg_quote(source: int, destination: int) -> Dictionary:
	var distance := System.station_position(source, 0.0).distance_to(System.station_position(destination, 0.0))
	# Mirrors the broad geographic duration curve, not a flight/fuel simulation.
	var minutes := clampf((380.0+distance/650.0)/60.0, 6.0, 30.0)
	return {"from":source, "to":destination, "minutes":snappedf(minutes, 0.1), "fuel_cost":int(ceil(25.0+minutes*3.0))}

func _quote(kind: String, employer: int, source: int, destination: int, commodity: String, units: int) -> Dictionary:
	var legs: Array = []
	if kind == "collection": legs.append(_leg_quote(employer, source))
	legs.append(_leg_quote(source, destination))
	var minutes := 0.0
	var fuel := 0
	for leg in legs:
		minutes += float(leg.minutes)
		fuel += int(leg.fuel_cost)
	var handling := units*9
	var time_pay := int(ceil(minutes*8.0))
	var upkeep := int(ceil(minutes*2.0))+20
	var profit := 100+units*5
	var payout := fuel+handling+time_pay+upkeep+profit
	var scarcity := float(stations[destination].demand.get(commodity, 0.0))/MAX_DEMAND
	var value := float(COMMODITY_VALUE.get(commodity, 100))
	var employer_margin := int(floor(value*units*(0.8+scarcity)))-payout
	return {"id":"", "kind":kind, "employer":employer, "source":source,
		"destination":destination, "commodity":commodity, "units":units,
		"full":units == FULL_UNITS, "minutes":snappedf(minutes, 0.1),
		"fuel_cost":fuel, "handling_pay":handling, "time_pay":time_pay,
		"upkeep":upkeep, "profit":profit, "payout":payout,
		"advance":fuel, "remaining_pay":payout-fuel,
		"employer_margin":employer_margin, "legs":legs,
		"quote_note":"CARGO TRIAL ESTIMATE / fixed route, fuel and handling quote"}

func _best_match(kind: String, employer: int, units: int) -> Dictionary:
	var best: Dictionary = {}
	for source in stations.size():
		if kind == "outbound" and source != employer: continue
		if kind == "collection" and source == employer: continue
		for commodity in stations[source].supply:
			if float(stations[source].supply[commodity]) < units: continue
			for destination in stations.size():
				if destination == source: continue
				if kind == "collection" and destination != employer: continue
				if float(stations[destination].demand.get(commodity, 0.0)) < units: continue
				var candidate := _quote(kind, employer, source, destination, commodity, units)
				if candidate.employer_margin <= 0: continue
				if best.is_empty() or candidate.employer_margin > best.employer_margin:
					best = candidate
	return best

func offers(employer: int = 0) -> Array:
	if employer < 0 or employer >= stations.size(): return []
	if not active.is_empty() and active.phase != "complete": return []
	if _offer_cache.has(employer): return _offer_cache[employer].duplicate(true)
	var board: Array = []
	# A short job is available first. Full loads and collection work are separate
	# choices, each selected from actual profitable supply/demand matches.
	for specification in [["outbound", SMALL_UNITS], ["outbound", FULL_UNITS], ["collection", SMALL_UNITS]]:
		var contract := _best_match(str(specification[0]), employer, int(specification[1]))
		if contract.is_empty(): continue
		_serial += 1
		contract.id = "CY-%03d-%04d" % [employer+1, _serial]
		board.append(contract)
	_offer_cache[employer] = board
	return board.duplicate(true)

func accept(id: String) -> Dictionary:
	error = ""
	if not active.is_empty() and active.phase != "complete":
		error = "Finish your active contract first."
		return {}
	var selected: Dictionary = {}
	for employer in _offer_cache:
		for contract in _offer_cache[employer]:
			if contract.id == id: selected = contract
	if selected.is_empty():
		error = "This quote has changed. Refresh the contract board."
		return {}
	if station != int(selected.employer):
		error = "Accept this contract at the employer's station."
		return {}
	var source: Dictionary = stations[selected.source]
	var destination: Dictionary = stations[selected.destination]
	var commodity: String = selected.commodity
	var units: int = selected.units
	if float(source.supply.get(commodity, 0.0)) < units or float(destination.demand.get(commodity, 0.0)) < units:
		error = "Available stock or demand changed. Refresh the board."
		_offer_cache.clear()
		return {}
	source.supply[commodity] -= units
	destination.demand[commodity] -= units
	destination.reserved_inbound[commodity] = int(destination.reserved_inbound.get(commodity, 0))+units
	active = selected.duplicate(true)
	active.phase = "to_pickup" if active.kind == "collection" else "loading"
	active.current_phase = active.phase
	active.fuel_spent = 0
	active.legs_completed = 0
	active.paid = false
	active.advance_paid = true
	active.box_count = 0
	credits += int(active.advance)
	_offer_cache.clear()
	return active.duplicate(true)

func leg_destination() -> int:
	if active.is_empty(): return -1
	if active.phase == "to_pickup": return int(active.source)
	if active.phase == "delivery": return int(active.destination)
	return -1

func mark_collected(box_count: int = 0) -> bool:
	error = ""
	if active.is_empty() or active.phase != "loading" or station != int(active.source):
		error = "Collect and secure the complete consignment at its pickup station."
		return false
	if box_count < 0: return false
	if box_count > 0: active.box_count = box_count
	active.phase = "delivery"
	active.current_phase = active.phase
	return true

func travel_to(destination: int) -> bool:
	error = ""
	if destination < 0 or destination != leg_destination():
		error = "This is not the next station on the accepted route."
		return false
	var leg: Dictionary = active.legs[int(active.legs_completed)]
	if int(leg.from) != station or int(leg.to) != destination: return false
	var cost: int = leg.fuel_cost
	if credits < cost:
		error = "The quoted fuel cost is not available."
		return false
	credits -= cost
	active.fuel_spent += cost
	active.legs_completed += 1
	station = destination
	active.phase = "loading" if active.phase == "to_pickup" else "unloading"
	active.current_phase = active.phase
	tick(float(leg.minutes)/60.0)
	return true

func complete(delivered_count: int, total_count: int, at_station: int) -> bool:
	error = ""
	if active.is_empty() or active.phase != "unloading" or active.paid:
		error = "There is no unpaid delivery to complete here."
		return false
	if at_station != station or station != int(active.destination):
		error = "Deliver this consignment to its contracted destination."
		return false
	if total_count <= 0 or delivered_count != total_count:
		error = "Unload every assigned box into the delivery area first."
		return false
	if int(active.box_count) > 0 and total_count != int(active.box_count):
		error = "The delivery count does not match the reserved consignment."
		return false
	var destination: Dictionary = stations[station]
	var commodity: String = active.commodity
	var units: int = active.units
	destination.reserved_inbound[commodity] = maxi(0, int(destination.reserved_inbound.get(commodity, 0))-units)
	destination.fulfilled[commodity] = int(destination.fulfilled.get(commodity, 0))+units
	credits += int(active.remaining_pay)
	active.paid = true
	active.phase = "complete"
	active.current_phase = active.phase
	receipts.append(active.duplicate(true))
	_offer_cache.clear()
	return true
