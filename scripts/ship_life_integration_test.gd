extends RefCounted
## Exercises the combined scene's real terminals, fixture rays, cargo controller,
## shared clock and persistence. Test files stay in /tmp, never normal saves.
const Packing = preload("res://scripts/cargo_trial_packing.gd")
const Life = preload("res://scripts/ship_life_state.gd")
const CargoChecks = preload("res://scripts/cargo_trial_integration_test.gd")
var host: Node3D
var passed := 0
var failed := 0

func check(value: bool, label: String) -> void:
	if value: passed += 1
	else:
		failed += 1
		push_error("SHIP LIFE INTEGRATION FAIL: " + label)
	print("SHIP LIFE INTEGRATION ", label, ": ", value)

func run(controller: Node3D) -> bool:
	host = controller
	var paths := ["user://longhaul_flight_v1.json", "user://ship_life_v1.json", "user://ship_life_departure_v1.json"]
	var hashes: Dictionary = {}
	for path in paths: hashes[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "ABSENT"
	await frames(4)
	# Keep frame-driven cooking and UI out of deterministic checks. Physics still
	# resolves the real player body; world time advances only through explicit calls.
	host.set_process(false)
	host.paused_life = false
	host.panel.hide()
	check(host.life.day() == 1 and host.life.hour() == 6.0, "fresh scene starts at06 with shared life clock")
	check(host.ship.controller == host and host.economy == host.life_economy, "flight and cargo use the combined controller")
	await _provision_and_accept()
	await _kitchen()
	await _shower_and_checks()
	await _rest_clock()
	await _persistence()
	await _cargo_and_cruise()
	await _repairs_and_emergency()
	host.skip.clear()
	host.skip_screen.hide()
	for path in paths:
		var after := FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "ABSENT"
		check(after == hashes[path], "test leaves existing save unchanged: " + path)
	print("SHIP LIFE INTEGRATION TOTAL: %d passed / %d failed" % [passed, failed])
	return failed == 0

func _provision_and_accept() -> void:
	await aim(Vector3(-3,-1.13,20.7),host.dock.terminal.global_position + Vector3(0,1.47,0.2))
	host._update_aim()
	press(KEY_F)
	check(host.panel.visible and host.terminal_mode == "contract", "real dock computer ray and F open contract board")
	var wallet: int = host.economy.credits
	host._command("accept 1")
	check(not host.economy.active.is_empty() and not host.parcels.is_empty(), "typed accept spawns contracted cases")
	check(host.economy.credits == wallet and host.economy.active.advance == 0, "acceptance pays no automatic operating-cost advance")
	check(host.readout.text.contains("FIXED FEE"), "contract shows fixed fee and contractor expenses")
	await use_fixture("provisions",Vector3(-5.3,-1.13,20.0))
	check(host.panel.visible and host.terminal_mode == "provisions", "real provisions kiosk is reachable at dock")
	host._command("buy food 4")
	host._command("buy water 4")
	check(host.life.food_stock == 4 and host.life.water_stock == 4, "port CLI buys separate days of food and water")
	check(host.economy.credits == wallet - 4 * (host.FOOD_PRICE + host.WATER_PRICE), "provisions charge exact purchase price")
	var paid_wallet: int = host.economy.credits
	host._command("buy food 99")
	check(host.life.food_stock == 4 and host.economy.credits == paid_wallet, "over-capacity purchase changes neither money nor inventory")
	await use_fixture("hab",Vector3(-0.7,0.05,-4.65))
	check(host.panel.visible and host.terminal_mode == "hab", "hab monitor is reachable through its actual ray")
	host._command("stock")
	check(host.readout.text.contains("FOOD: 4 / 12") and host.readout.text.contains("WATER: 4 / 12"), "hab shows the same authoritative stocks as port")
	var previous_screen: String = host.readout.text
	host._command("checklist")
	check(host.readout.text != previous_screen, "hab checklist opens a distinct terminal view")
	host._command("return")
	check(host.readout.text == previous_screen, "return restores previous hab terminal view")
	host._command("print")
	check(host.printed and host.life.printed_day == 1, "hab terminal prints the current daily checklist")
	check(host.paper_in_tray and host.printed_timer > 0.0, "printing starts physical tray feed before paper can be read")
	press(KEY_ESCAPE)
	press(KEY_J)
	check(not host.panel.visible and host.paper_in_tray, "J cannot collect paper before printer feed finishes")
	host.printed_timer = 0.0
	host._update_life_visuals()
	check(host.life_art.printer_paper.visible, "finished printed checklist is visible in tray")
	check(host.life_art.hab_readout.text.contains("4") and host.life_art.port_readout.text.contains("4"), "physical port and hab screens reflect purchased stock")
	press(KEY_J)
	check(host.panel.visible and host.terminal_mode == "daily", "printed checklist can be opened with J")
	host._update_life_visuals()
	check(host.printed and not host.paper_in_tray and not host.life_art.printer_paper.visible, "J collects the paper and clears the physical printer tray")
	press(KEY_ESCAPE)
	press(KEY_J)
	check(host.panel.visible and host.printed and not host.paper_in_tray, "collected checklist remains readable without creating another tray sheet")
	host._command("discard")
	check(not host.printed and not host.paper_in_tray, "discard removes carried daily paper")
	host.open_terminal("hab")
	host._command("print")
	host.printed_timer = 0.0
	host._update_life_visuals()
	await use_fixture("paper",Vector3(-0.65,0.05,-4.80))
	check(host.panel.visible and host.terminal_mode == "daily" and host.printed and not host.paper_in_tray, "F collects a finished sheet from the physical printer")
	host.panel.hide()

func _kitchen() -> void:
	await use_fixture("fridge",Vector3(0,0.05,-5.60))
	check(host.life.hand_item == "raw_food" and host.life.food_stock == 3, "F on physical fridge reserves one food day")
	check(is_instance_valid(host.life_hand) and host.life_hand.get_parent() == host.camera, "carried meal pack has a visible camera prop")
	await use_fixture("oven",Vector3(0,0.05,-7.02))
	check(host.life.oven_state == "cooking" and host.life.hand_item == "", "physical oven receives food and starts cooking")
	host.life.tick_interactions(4.0)
	host._update_life_visuals()
	check(host.life_art.oven_plate.visible, "ready meal is visible in oven")
	press(KEY_F)
	check(host.life.hand_item == "meal" and host.life.hand_bites == 5, "F retrieves cooked five-bite meal")
	await use_fixture("table",Vector3(-0.45,0.05,-4.50))
	check(host.life.table_bites == 5 and host.seated_table, "placing plate uses table and seats player")
	press(KEY_F)
	check(host.life.table_bites == 4 and is_equal_approx(host.life.daily_food,0.2), "seated F eats first bite")
	for bite in 4: press(KEY_F)
	check(host.life.table_bites == 0 and is_equal_approx(host.life.daily_food,1.0), "five real F presses finish daily meal and leave dirty plate")
	check(host.life_art.table_plate.visible, "finished plate remains visible until collected")
	press(KEY_F)
	check(host.life.hand_item == "dirty_plate" and host.life.table_bites == -1, "F picks up used plate without creating a new meal")
	press(KEY_G)
	check(not host.seated_table, "G leaves dining seat")
	await use_fixture("sink",Vector3(0,0.05,-8.12))
	check(host.life.hand_item == "" and not host.life_art.table_plate.visible, "sink F washes plate and clears the next meal's place")
	await use_fixture("cabinet",Vector3(0,0.05,-6.63))
	check(host.life.hand_item == "empty_glass", "overhead glass cabinet is reachable")
	await use_fixture("water",Vector3(0,0.05,-6.48))
	check(host.life.hand_item == "water_glass" and host.life.water_stock == 3, "cooler F fills glass and reserves one water day")
	await aim(Vector3(0,0.05,-6.3),Vector3(0,1.65,-4.0))
	press(KEY_F)
	check(host.life.daily_water and host.life.hand_item == "used_glass", "away from fittings F drinks the held glass")
	await use_fixture("sink",Vector3(0,0.05,-8.12))
	check(host.life.hand_item == "", "physical sink returns used glass")
	check(host.life.food_stock == 3 and host.life.water_stock == 3, "whole kitchen loop consumes exactly one food and one water unit")

func _shower_and_checks() -> void:
	host.life.hygiene = 25.0
	await use_fixture("shower",Vector3(-2.02,0.05,-3.25))
	check(host.shower_on, "shower control can be reached inside actual shower bounds")
	var stock: int = host.life.water_stock
	host._process(4.0)
	check(host.life.hygiene >= 45.0 and host.life.water_stock == stock, "standing under shower restores hygiene without drinking-water use")
	host.walker.position = Vector3(0,0.05,-3.25)
	var clean: float = host.life.hygiene
	host._process(2.0)
	check(is_equal_approx(host.life.hygiene,clean), "running shower cannot clean player outside its bounds")
	host.shower_on = false
	await use_fixture("sensors",Vector3(0,0.05,8.15))
	check(host.panel.visible and host.terminal_mode == "sensors", "engineering sensor screen is physically accessible")
	host._command("status")
	check(host.readout.text.contains("CHECK DUE"), "sensor status identifies random daily inspections")
	for sensor in host.life.selected_sensors: host._command("check " + sensor)
	check(host.life.checked_sensors.size() == 2 and host.life.checklist_complete(), "sensor commands complete today's existing daily routine")
	host.panel.hide()
	press(KEY_J)
	check(host.readout.text.contains("[X] Eat daily meal") and not host.readout.text.contains("[ ]"), "printed checklist reflects actions without reprinting")
	host.panel.hide()

func _rest_clock() -> void:
	var before: float = host.life.elapsed_hours
	host._advance_simulation(10.0)
	check(is_equal_approx(host.life.elapsed_hours-before,10.0*host.WORLD_HOURS_PER_SECOND), "active controller advances one universal world clock")
	var shared_before: float = host.life_economy.elapsed_hours
	host.open_terminal("bunk")
	host._command("pass")
	check(not host.skip.is_empty() and host.skip_screen.visible and host.skip_screen.color == Color.BLACK, "passing time opens required black screen")
	check(host.skip_bar.visible and host.skip_bar.value == 0, "time skip has a visible progress bar")
	host._process_skip(1.0)
	check(not host.skip.is_empty() and host.skip_bar.value > 0 and host.skip_label.text.contains("remaining"), "skip progress shows remaining shipboard time")
	host._process_skip(10.0)
	check(host.skip.is_empty() and is_equal_approx(host.life.hour(),20.0), "pass completes exactly at20")
	check(host.life_economy.elapsed_hours > shared_before, "station economy advances during skipped time")
	var selected: String = host.life.selected_sensors[0]
	var sensor_before: float = host.life.sensors[selected]
	host.start_rest("sleep")
	check(not host.skip.is_empty(), "normal sleep available after completed day at bedtime")
	host._process_skip(10.0)
	check(host.skip.is_empty() and host.life.day() == 2 and is_equal_approx(host.life.hour(),6.0), "sleep crosses midnight and wakes at06")
	check(host.life.daily_food == 0 and not host.life.daily_water and host.life.checked_sensors.is_empty(), "calendar boundary creates one new checklist")
	check(not host.printed and not host.paper_in_tray, "new calendar day retires the previous daily printout")
	check(is_equal_approx(host.life.sensors[selected],sensor_before-0.5), "completed sensor inspection applies half daily wear")
	check(host.start_rest("pass").contains("checklist") and host.skip.is_empty(), "new day cannot be skipped until chores complete")

func _persistence() -> void:
	var path := "/tmp/ship-life-integration-save.json"
	host.life.interact("cabinet")
	host.life.interact("cooler")
	host._update_life_visuals()
	var state: Dictionary = host.life.snapshot()
	var credits: int = host.economy.credits
	var count: int = host.parcels.size()
	var clock: float = host.ship.flight.elapsed
	var reply: String = host.save_life(path)
	check(FileAccess.file_exists(path), "combined session writes isolated test save")
	host.life.food_stock = 0
	host.life.hand_item = ""
	host.economy.credits = 0
	host._advance_simulation(5.0)
	reply = host.load_life(path)
	check(equivalent(host.life.snapshot(),state), "load restores provisions held glass calendar and daily checklist together")
	check(host.economy.credits == credits and host.parcels.size() == count, "load restores contract wallet and physical cargo")
	check(is_equal_approx(host.ship.flight.elapsed,clock), "load restores flight clock with survival clock")
	check(host.life_hand != null and host.life.hand_item == "water_glass", "held survival item survives load with its visual")
	host._use_life("drink")
	host._use_life("sink")
	check(host.life.hand_item == "", "restored glass remains usable and cleanable")

func _cargo_and_cruise() -> void:
	host.panel.hide()
	host.seated_table = false
	await aim(Vector3(0,-1.13,18),Vector3(0,0,12))
	var cargo_checks = CargoChecks.new()
	cargo_checks.host = host
	check(cargo_checks._load_solution(), "actual cargo controller loads every guaranteed-fit case into racks")
	check(host.stage_count() == 0 and host.load_readiness().is_empty(), "loaded cargo clears staging and departure readiness")
	check(host.toggle_lock() and host.locked, "cargo-lock control secures the full manifest")
	var count: int = host.parcels.size()
	var wallet: int = host.economy.credits
	var cost: int = host._fuel_cost()
	host.buy_fuel()
	check(is_equal_approx(host.ship.flight.fuel,3000) and host.economy.credits == wallet-cost, "player purchases actual ship fuel from own wallet")
	await _manual_departure_commands()
	var result: String = host.start_test_cruise()
	check(host.ship.flight.phase != "docked" and host.ship.flight.autopilot, "prepared cruise starts the real navigation flight state")
	check(host.parcels.size() == count and host.packing.placements.size() == count and host.locked, "cruise preserves all packed cargo and locks")
	check(not host.dock.terminal.get_parent().visible, "hangar disappears during actual space travel")
	var food: int = host.life.food_stock
	check(host.buy_provisions("food",1).contains("station") and host.life.food_stock == food, "provisions cannot be purchased from ship in flight")
	# Integrate the actual route to five seconds before the arrival watch. A
	# requested full sleep must stop at the warning rather than advancing past it.
	var f = host.ship.flight
	var to_watch: float = maxf(0.0,f.arrival_wake_in()-5.0)
	host._advance_simulation(to_watch)
	host.life.elapsed_hours = floorf(host.life.elapsed_hours/24.0)*24.0+20.0
	host.life.daily_food = 1.0
	host.life.daily_water = true
	host.life.hygiene = 80
	var before: float = f.elapsed
	result = host.start_rest("sleep")
	check(not host.skip.is_empty(), "safe active NAV cruise allows bunk sleep")
	host._process_skip(10.0)
	check(host.skip.is_empty() and f.time_to_burn() >= 89.999 and f.time_to_burn() <= 90.001, "sleep stops exactly90 active seconds before arrival burn")
	check(f.autopilot and f.elapsed-before <= 5.001, "arrival wake preserves NAV and discards unused skipped time")
	check(host.start_rest("sleep").contains("Arrival watch") and host.skip.is_empty(), "arrival watch prevents repeated sleep past safety boundary")
	# Flight-state unit checks own the long automatic docking integration. Deliver
	# its arrival event here to validate surviving physical cargo and accounting.
	f.phase = "docked"
	f.dock_id = host.economy.leg_destination()
	f.autopilot = false
	f.ship_position = f.station_position(f.dock_id,f.elapsed)
	f.velocity = f.station_velocity(f.dock_id,f.elapsed)
	host._arrived()
	check(host.economy.active.phase == "unloading" and host.economy.station == f.dock_id, "flight arrival transitions accepted cargo to destination unloading")
	check(host.dock.terminal.get_parent().visible and host.parcels.size() == count, "arrival restores destination apron without duplicating cases")
	check(host.toggle_lock() and not host.locked, "arrival allows cargo locks to release")
	await aim(Vector3(0,-1.13,18),Vector3(0,0,12))
	var order: Array[int] = host.packing.get_solution_order()
	order.reverse()
	var unloaded := true
	for index in order.size():
		var id: int = order[index]
		unloaded = host.pick_case(id) and unloaded
		if host.held != id: continue
		unloaded = host.place_held(host.floor_target("drop",index,Vector3i.ZERO,host.held_size)) and unloaded
	check(unloaded and host.delivered_count() == count, "real hand-tool controller unloads every case into destination grids")
	wallet = host.economy.credits
	var remaining: int = host.economy.active.remaining_pay
	check(host.complete_delivery() and host.economy.credits == wallet+remaining, "delivery button pays remaining fixed fee after player-funded operating costs")
	wallet = host.economy.credits
	check(not host.complete_delivery() and host.economy.credits == wallet, "repeated delivery cannot duplicate payment")

func _manual_departure_commands() -> void:
	var path := "/tmp/ship-life-manual-departure-save.json"
	host.save_life(path)
	var ship = host.ship
	var f = ship.flight
	var id: int = host.packing.get_solution_order().back()
	var solved: Dictionary = host.packing.manifest[id].duplicate(true)
	host.toggle_lock()
	await aim(Vector3(0,-1.13,18),Vector3(0,0,12))
	var staged: bool = host.pick_case(id)
	staged = host.place_held(host.floor_target("stage",0,Vector3i.ZERO,host.held_size)) and staged
	check(staged and host.stage_count() == 1, "manual departure test moves an actual racked case into staging")
	await aim(Vector3(0,0.05,-10.32),Vector3(0,1.4,-12))
	ship.terminal_command("engine","port on")
	ship.terminal_command("engine","starboard on")
	check(f.engines[0] and f.engines[1], "cockpit engine CLI enables both actual engines")
	ship.terminal_command("chart","plot " + host.System.IDS[host.economy.leg_destination()] + " direct")
	check(not f.plan.is_empty() and not f.loaded, "CHART plot supplies route without silently loading NAV")
	if f.plan.is_empty():
		host.load_life(path)
		return
	var target: Vector3 = f.plan.target / 1000.0
	ship.terminal_command("nav","coords %.8f %.8f %.8f" % [target.x,target.y,target.z])
	ship.terminal_command("nav","burn %.8f" % float(f.plan.burn))
	ship.terminal_command("nav","reserve %.8f" % float(f.plan.reserve))
	var reply: String = ship.terminal_command("nav","load")
	check(f.loaded and f.entered_coords.distance_to(f.plan.target) < 2, "manually typed coordinates burn and reserve validate at NAV")
	ship.terminal_command("comms","request")
	ship.terminal_command("comms","code " + f.clearance)
	check(f.clearance_confirmed, "COMMS request and exact code readback authorize departure")
	reply = ship.terminal_command("checklist","hatch close")
	await host.get_tree().create_timer(2.4).timeout
	ship.sync_hardware()
	check(not ship.loading_module.hatch_open and not ship.loading_module.hatch_moving and f.hatch_closed, "CHECKLIST closes actual animated hatch while player is safely in cockpit")
	reply = ship.terminal_command("checklist","ramp raise")
	await host.get_tree().create_timer(3.4).timeout
	ship.sync_hardware()
	check(ship.ramp_up and not ship.ramp_moving and f.ramp_raised, "CHECKLIST raises actual animated loading ramp")
	var old_condition: float = host.life.sensors.navigation
	host.life.sensors.navigation = 0.0
	reply = ship.terminal_command("comms","depart")
	check(f.phase == "docked" and reply.contains("Sensor"), "COMMS depart enforces zero-condition sensor interlock")
	host.life.sensors.navigation = old_condition
	reply = ship.terminal_command("comms","depart")
	check(f.phase == "docked" and reply.contains("secure"), "COMMS depart refuses genuine staged cargo despite complete cockpit checklist")
	await aim(Vector3(0,-1.13,18),Vector3(0,0,12))
	var repacked: bool = host.pick_case(id)
	var rack_target := {"kind":"rack","bin":solved.solution_bin,"cell":solved.solution_cell,"reason":"", "transform":host.racks[solved.solution_bin].global_transform * Transform3D(Basis.IDENTITY,(Vector3(solved.solution_cell)+Vector3(solved.solution_size)*0.5)*Packing.CELL)}
	repacked = host.place_held(rack_target) and repacked
	repacked = host.toggle_lock() and repacked
	check(repacked and host.stage_count() == 0 and host.locked, "repacking staged case and locking satisfies real cargo gate")
	await aim(Vector3(0,0.05,-10.32),Vector3(0,1.4,-12))
	reply = ship.terminal_command("comms","depart")
	check(f.phase == "departure" and not f.autopilot, "full cockpit command sequence releases berth for manual departure")
	check(host.locked and host.packing.placements.size() == host.parcels.size(), "manual departure preserves loaded locked contract freight")
	var restored: String = host.load_life(path)
	check(f.phase == "docked" and host.locked, "isolated manual-departure fixture restores prepared dock session")
	await frames(3)

func _repairs_and_emergency() -> void:
	host.ship.flight.phase = "docked"
	host.life.sensors.navigation = 0.0
	host.ship.sync_hardware()
	check(not host.ship.flight.sensors_ready and host.flight_departure().contains("Sensor"), "failed sensor participates in actual departure interlock")
	host.economy.credits = 0
	var debt: int = host.life_economy.debt
	check(host.repair_sensors("navigation").contains("emergency") and host.life.sensors.navigation == 0.0, "unaffordable repair offers explicit emergency service")
	host.repair_sensors("emergency")
	check(host.life.sensors.navigation == 100.0 and host.life_economy.debt == debt+200, "essential repair debt prevents a zero-money departure softlock")
	host.life.food_stock = 0
	host.life.water_stock = 0
	host.life.daily_food = 0
	host.life.daily_water = false
	host.life.emergency_uses = 2
	host.life.hand_item = ""
	host.life.table_bites = -1
	host.life.oven_state = ""
	host.start_rest("emergency")
	check(host.life.emergency_uses == 3 and not host.skip.is_empty(), "third emergency rest starts black progress without ending run")
	host._process_skip(10.0)
	host.start_rest("emergency")
	check(host.life.game_over and host.skip.is_empty(), "fourth emergency rest ends the playable run")
	host._process(0.0)
	check(host.skip_screen.visible and host.skip_label.text.contains("RUN ENDED"), "run end presents rescue and checkpoint reload")
	host.life.game_over = false
	host.skip_screen.hide()
	host.economy.credits = 40
	host.life.begin_station_visit()
	host.buy_provisions("food",1)
	check(host.life.emergency_uses == 3, "station food purchase alone leaves emergency uses unchanged")
	host.buy_provisions("water",1)
	check(host.life.emergency_uses == 0, "buying both food and water resets emergency allowance in actual port controller")

func use_fixture(action: String, from: Vector3) -> void:
	await aim(from,host.fixtures.targets[action].global_position)
	var hit: Dictionary = host._life_hit()
	var reached: bool = not hit.is_empty() and hit.collider.get_meta("life_action","") == action
	if not reached:
		print("LIFE FIXTURE RAY DEBUG ",action," eye=",host.camera.global_position," target=",host.fixtures.targets[action].global_position," hit=",hit)
	check(reached,"fixture ray reaches " + action)
	press(KEY_F)

func aim(from: Vector3, target: Vector3) -> void:
	host.panel.hide()
	host.paused_life = false
	host.walker.position = from
	host.walker.velocity = Vector3.ZERO
	host.walker.rotation = Vector3.ZERO
	host.camera.position.y = 1.62
	host.camera.look_at(target,Vector3.UP)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await frames(3)
	host.camera.look_at(target,Vector3.UP)
	host._update_aim()

func press(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	host._unhandled_input(event)

func frames(count: int) -> void:
	for index in count: await host.get_tree().process_frame

func equivalent(a: Variant, b: Variant) -> bool:
	if (a is float or a is int) and (b is float or b is int): return is_equal_approx(float(a),float(b))
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key in a:
			if not b.has(key) or not equivalent(a[key],b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for index in a.size():
			if not equivalent(a[index],b[index]): return false
		return true
	return a == b
