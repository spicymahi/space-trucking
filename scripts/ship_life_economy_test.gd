extends SceneTree
const Economy = preload("res://scripts/ship_life_economy.gd")
const System = preload("res://scripts/longhaul_system.gd")
var passed := 0
var failed := 0

func _init() -> void:
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	if condition: passed += 1
	else:
		failed += 1
		printerr("SHIP LIFE ECONOMY FAIL: ", label)

func run() -> void:
	check_quotes()
	check_advance_and_payment()
	check_collection()
	check_cancellation()
	check_save_restore()
	print("SHIP LIFE ECONOMY: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)

func check_quotes() -> void:
	var e = Economy.new()
	e.setup()
	for port in System.STATIONS.size():
		var board: Array = e.offers(port)
		check(not board.is_empty(), "work exists at " + System.NAMES[port])
		check(board[0].units == 24, "first offer is a manageable half-hold load")
		var nearest := INF
		for destination in System.STATIONS.size():
			if destination != port:
				nearest = minf(nearest, float(e._leg_quote(port, destination).world_hours))
		check(is_equal_approx(float(board[0].world_hours), nearest), "first job uses shortest solver-supported route")
		for job in board:
			check(job.advance == 0 and job.remaining_pay == job.payout, "fee paid at completion unless advance requested")
			var hours := 0.0
			for leg in job.legs:
				check(leg.world_hours > 0.0 and leg.world_hours <= 12.0, "single leg under twelve shipboard hours with slower clock")
				check(leg.minutes <= 30.0, "active flight estimate capped at thirty minutes")
				hours += float(leg.world_hours)
			check(is_equal_approx(job.world_hours, hours), "collection quote includes both world-time legs")
			check(job.payout > int(ceil(hours / 24.0)) * 12 + job.fuel_cost + 35, "normal supplies fuel and upkeep leave profit")
	check(e.offers()[0].world_hours < 3.0, "starting port offers a short job below three shipboard hours")
	var flight = Economy.FlightState.new()
	flight.fuel = 3000.0
	flight.cargo_mass = 980.0
	flight.command("engine", "port on")
	flight.command("engine", "starboard on")
	flight.plan_route(System.IDS[int(e.offers()[0].destination)])
	check(is_equal_approx(e.offers()[0].world_hours, ceilf((flight.plan.coast + 120.0) * Economy.WORLD_HOURS_PER_SECOND * 10.0) / 10.0), "world-time estimate derives from real planner plus approach allowance")
	var before: Array = e.stations.duplicate(true)
	e.tick(24.0)
	check(e.elapsed_hours == 24.0 and before != e.stations, "only shared tick advances economy")
	for port in System.STATIONS.size():
		check(not e.offers(port).is_empty(), "work remains after a shipboard day")
	var split = Economy.new()
	split.setup()
	var skipped = Economy.new()
	skipped.setup()
	for frame in 1000: split.tick(0.06)
	skipped.tick(60.0)
	check(split.stations == skipped.stations, "time skip and short clock increments produce identical markets")
	check(is_equal_approx(split.elapsed_hours, skipped.elapsed_hours), "shared elapsed time agrees across skip granularity")

func check_advance_and_payment() -> void:
	var e = Economy.new()
	e.setup()
	var quote: Dictionary = e.offers()[0]
	var old_credits: int = e.credits
	check(not e.accept(quote.id).is_empty(), "accept first fixed-fee job")
	check(e.credits == old_credits and not e.active.advance_paid, "acceptance grants no automatic money")
	check(e.request_advance(50) == 0 and not e.active.advance_requested, "unneeded advance neither pays nor consumes entitlement")
	e.credits = 10
	check(e.request_advance(90) == 80, "advance provides exact essential shortfall")
	check(e.credits == 90 and e.active.remaining_pay == quote.payout - 80, "advance subtracts from final payment")
	check(e.request_advance(100) == 0 and e.credits == 90, "advance cannot be drawn twice")
	check(not e.spend(-2) and not e.spend(91) and e.credits == 90, "invalid or unaffordable purchases do not change wallet")
	check(e.spend(90) and e.credits == 0, "essentials are paid by contractor")
	check(not e.finish_leg(quote.destination), "cargo must be secured before starting delivery")
	check(e.mark_collected(6), "secure outbound boxes")
	var hours: float = e.elapsed_hours
	check(e.finish_leg(quote.destination), "arrival completes correct outbound leg")
	check(e.credits == 0 and e.elapsed_hours == hours, "arrival neither debits quoted fuel nor duplicates clock advancement")
	check(not e.finish_leg(quote.destination), "same arrival cannot complete twice")
	check(not e.complete(5, 6, quote.destination), "all physical boxes required")
	check(e.complete(6, 6, quote.destination), "deliver whole consignment")
	check(e.credits == quote.payout - 80, "settles only unadvanced fee")
	check(not e.complete(6, 6, quote.destination) and e.credits == quote.payout - 80, "completion pays exactly once")
	var other = Economy.new()
	other.setup()
	other.credits = 0
	other.accept(other.offers()[0].id)
	check(other.request_advance(int(other.active.payout) + 1) == 0, "cannot borrow more than contract fee")
	check(not other.active.advance_requested and other.credits == 0, "rejected request preserves a later valid advance")
	other.mark_collected(6)
	check(other.request_advance(80) == 80, "securing cargo does not prevent financing before the first departure")
	other.station = (int(other.active.destination) + 1) % System.STATIONS.size()
	check(other.finish_leg(int(other.active.destination)), "intermediate provisioning stop does not invalidate contracted delivery")

func check_collection() -> void:
	var e = Economy.new()
	e.setup()
	var quote: Dictionary = e.offers()[2]
	check(quote.kind == "collection" and quote.legs.size() == 2, "collection work retains empty pickup leg")
	e.credits = 0
	e.accept(quote.id)
	check(e.request_advance(200) == 200, "collection can finance all essentials before initial departure")
	check(e.finish_leg(quote.source), "arrive at supplier")
	check(e.active.phase == "loading", "supplier arrival unlocks pickup")
	check(e.request_advance(300) == 0, "supplier docking does not reset finance allowance")
	check(e.mark_collected(7) and e.finish_leg(quote.destination), "loaded return reaches employer")
	check(e.complete(7, 7, quote.destination), "collection contract pays after return")
	check(e.credits == quote.payout, "advance and final settlement total exactly fixed fee")
	check(e.elapsed_hours == 0.0, "contract transitions leave elapsed time entirely to shared clock")

func check_cancellation() -> void:
	var e = Economy.new()
	e.setup()
	e.credits = 0
	var quote: Dictionary = e.offers()[0]
	var stock: float = e.stations[quote.source].supply[quote.commodity]
	e.accept(quote.id)
	e.request_advance(100)
	check(e.cancel(), "unstarted job may be cancelled")
	check(e.debt == 100 and e.credits == 100, "cancellation preserves advance as debt")
	check(e.stations[quote.source].supply[quote.commodity] == stock, "cancelled cargo returns to station stock")
	check(e.stations[quote.destination].reserved_inbound[quote.commodity] == 0, "cancellation releases inbound reservation")
	e.spend(100)
	var next: Dictionary = e.offers()[0]
	e.accept(next.id)
	check(e.request_advance(int(next.payout)) == 0, "existing debt reduces unpledged contract funds")
	e.mark_collected(6)
	check(not e.cancel(), "secured departure job cannot cancel through pickup API")
	e.finish_leg(next.destination)
	e.complete(6, 6, next.destination)
	check(e.debt == 0 and e.credits == next.payout - 100, "next settlement repays cancelled advance")
	check(e.receipts[-1].debt_repaid == 100 and e.receipts[-1].net_settlement == next.payout - 100, "receipt explains net settlement")

func check_save_restore() -> void:
	var e = Economy.new()
	e.setup(9842)
	e.offers(1)
	e.offers(14)
	var json: String = JSON.stringify(e.snapshot())
	var loaded = Economy.new()
	check(loaded.restore(JSON.parse_string(json)), "fresh board economy round-trips through JSON")
	check(loaded.stations == e.stations and JSON.stringify(loaded.offers(14)) == JSON.stringify(e.offers(14)), "stock and cached quotes retain exact values and IDs")
	check(loaded._rng.state == e._rng.state, "64-bit RNG state preserved without floating point truncation")
	var job: Dictionary = e.offers()[2]
	e.credits = 0
	e.accept(job.id)
	e.request_advance(70)
	e.finish_leg(job.source)
	e.tick(38.0)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(e.snapshot()))
	check(loaded.restore(saved), "active financed collection restores")
	check(JSON.stringify(loaded.active) == JSON.stringify(e.active) and loaded.credits == e.credits and loaded.elapsed_hours == e.elapsed_hours, "phase debt fee and clock preserved")
	check(loaded.request_advance(90) == 0, "reload cannot repeat an advance")
	check(loaded.mark_collected(7) and loaded.finish_leg(job.destination), "restored collection continues")
	check(loaded.complete(7, 7, job.destination), "restored collection settles")
	var old_save:Dictionary=saved.duplicate(true)
	old_save.erase("clock_rate")
	old_save.active.world_hours*=18.0
	for leg in old_save.active.legs:leg.world_hours*=18.0
	check(loaded.restore(old_save), "old fast-clock save migrates")
	check(loaded.active.payout==e.active.payout and loaded.active.remaining_pay==e.active.remaining_pay and loaded.credits==saved.credits and loaded.elapsed_hours==saved.elapsed_hours, "pacing migration preserves agreed fees wallet and elapsed progress")
	check(is_equal_approx(loaded.active.world_hours,saved.active.world_hours) and loaded._offer_cache.is_empty(), "pacing migration updates remaining estimates and expires unsold quotes")
	loaded.restore(saved)
	var stable := loaded.snapshot()
	var bad := saved.duplicate(true)
	bad.station = 50
	check(not loaded.restore(bad) and loaded.snapshot() == stable, "invalid station rejects atomically")
	bad = saved.duplicate(true)
	bad.stations[0].supply[Economy.PORT_SUPPLIES] = -1
	check(not loaded.restore(bad) and loaded.snapshot() == stable, "corrupt negative stock rejects atomically")
	bad = saved.duplicate(true)
	bad.rng_state = "not a state"
	check(not loaded.restore(bad), "invalid RNG rejected")
	bad = saved.duplicate(true)
	bad.active.legs = [{"from":0}]
	check(not loaded.restore(bad), "incomplete active contract cannot crash restore")
	e.tick(0.3)
	check(loaded.restore(JSON.parse_string(JSON.stringify(e.snapshot()))), "fractional market hour restores")
	e.tick(0.7)
	loaded.tick(0.7)
	check(e.stations == loaded.stations, "save and reload keep the next hourly market tick aligned")
