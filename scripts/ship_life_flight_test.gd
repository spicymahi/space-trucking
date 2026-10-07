extends RefCounted
## Regression for the complete physical flight/cargo lifecycle. The combined
## integration suite may leave any state behind; reset a fresh isolated fixture,
## then use the real solver, command adapters and arrival callback throughout.
## Run only inside --ship-life-test: the controller redirects checkpoint writes.
const Life = preload("res://scripts/ship_life_state.gd")
const LifeEconomy = preload("res://scripts/ship_life_economy.gd")
const CargoChecks = preload("res://scripts/cargo_trial_integration_test.gd")
var host: Node3D
var passed := 0
var failed := 0

func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error("SHIP LIFE FLIGHT FAIL: " + label)
	print("SHIP LIFE FLIGHT ", label, ": ", ok)

func run(controller: Node3D) -> bool:
	host = controller
	if "--ship-life-test" not in OS.get_cmdline_user_args():
		push_error("Run ship-life flight checks with --ship-life-test to protect save files.")
		return false
	var paths := ["user://longhaul_flight_v1.json", "user://ship_life_v1.json", "user://ship_life_departure_v1.json"]
	var hashes: Dictionary = {}
	for path in paths: hashes[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "ABSENT"
	var process_before := host.is_processing()
	var physics_before := host.is_physics_processing()
	host.set_process(false)
	host.set_physics_process(false)
	_reset_fixture()
	await host.get_tree().physics_frame
	await host.get_tree().physics_frame
	check(host.accept_job(0), "fresh fixture accepts small outbound contract")
	if host.economy.active.is_empty(): return _finish(paths, hashes, process_before, physics_before)
	var helper = CargoChecks.new()
	helper.host = host
	check(helper._load_solution(), "controller physically parents and packs the manifest")
	check(host.toggle_lock(), "controller locks packed cargo for departure")
	var count: int = host.parcels.size()
	var destination: int = host.economy.leg_destination()
	host.buy_fuel()
	var reply: String = host.start_test_cruise()
	var flight = host.ship.flight
	check(flight.autopilot and flight.phase == "injection", "prepared test enters the real flight solver")
	if not flight.autopilot:
		print("SHIP LIFE FLIGHT START: ", reply)
		return _finish(paths, hashes, process_before, physics_before)
	var phases: Array[String] = [flight.phase]
	# The solver briefly enters brake at the end of its controlled transfer.
	# Sample that boundary finely; five-second sampling can miss it entirely.
	for step in 1200:
		host._advance_simulation(0.1 if flight.time_to_burn() < 5.0 else 5.0)
		if flight.phase not in phases: phases.append(flight.phase)
		if flight.phase == "approach" or not flight.autopilot: break
	check(flight.phase == "approach" and flight.arrival_hold, "actual transfer reaches the destination holding point")
	check("coast" in phases and "brake" in phases, "real simulation passes coast and arrival braking")
	check(host.packing.placements.size() == count and host.locked, "physical manifest stays packed and locked through flight")
	host.ship.terminal_command("nav", "approach")
	host.ship.terminal_command("nav", "auto dock")
	check(flight.auto_docking and flight.approach_clearance, "NAV CLI obtains berth and starts actual automatic docking")
	for step in 600:
		host._advance_simulation(2.0)
		if flight.phase == "docked" or not flight.autopilot: break
	check(flight.phase == "docked" and flight.dock_id == destination, "nose-first autodock physically captures the destination berth")
	check(host.economy.active.phase == "unloading" and host.economy.station == destination, "real arrival callback changes contract to destination unloading")
	check(host.dock.terminal.get_parent().visible, "real arrival restores the destination cargo apron")
	if flight.phase != "docked": return _finish(paths, hashes, process_before, physics_before)
	# Re-open actual animated hardware before unloading, as a player must do.
	host.ship.terminal_command("checklist", "hatch open")
	host.ship.terminal_command("checklist", "ramp lower")
	await host.get_tree().create_timer(2.0).timeout
	check(host.ship.loading_module.hatch_open and not host.ship.loading_module.hatch_moving and not host.ship.ramp_up and not host.ship.ramp_moving, "destination checklist opens the real loading hatch and ramp")
	check(host.toggle_lock() and not host.locked, "arrival allows the cargo lock to release")
	host.walker.position = Vector3(0, -1.13, 18)
	host.walker.rotation = Vector3.ZERO
	var order: Array[int] = host.packing.get_solution_order()
	order.reverse()
	var unloading := true
	for index in order.size():
		var id: int = order[index]
		unloading = host.pick_case(id) and unloading
		if host.held == id:
			unloading = host.place_held(host.floor_target("drop", index, Vector3i.ZERO, host.held_size)) and unloading
	check(unloading and host.delivered_count() == count, "real travelled cases unload through the carry and floor-grid controllers")
	var wallet: int = host.economy.credits
	var fee: int = host.economy.active.remaining_pay
	check(host.complete_delivery() and host.economy.credits == wallet + fee, "actual flight and delivery earn exactly the fixed final fee")
	check(not host.complete_delivery(), "duplicate delivery payment is rejected")
	print("SHIP LIFE FLIGHT OBSERVED PHASES: ", phases, " -> docked")
	return _finish(paths, hashes, process_before, physics_before)

func _reset_fixture() -> void:
	if host.ship.active_terminal != null: host.ship.close_terminal()
	host._clear_cases()
	host.locked = false
	host.completion_receipt = ""
	host.life = Life.new()
	host.life_economy = LifeEconomy.new()
	host.life_economy.setup()
	host.economy = host.life_economy
	# Preserve the adapter subclass containing the live sensor departure gate.
	host.ship.flight = host.ship.flight.get_script().new()
	host.ship.flight.fuel = 900
	if host.ship.ramp_tween: host.ship.ramp_tween.kill()
	if host.ship.loading_module.hatch_tween: host.ship.loading_module.hatch_tween.kill()
	host.ship.ramp_moving = false
	host.ship.ramp_up = false
	host.ship.ramp_pivot.rotation.x = atan(1.2 / 4.2)
	host.ship.ramp_fold.rotation.x = 0
	host.ship.loading_module.hatch_moving = false
	host.ship.loading_module.hatch_open = true
	for index in 2: host.ship.loading_module.leaves[index].position.x = (-1 if index == 0 else 1) * 2.14
	host.ship.loading_module._update_status()
	host.paused_life = false
	host.seated_pilot = false
	host.seated_table = false
	host.shower_on = false
	host.printed = false
	host.paper_in_tray = false
	host.printed_timer = 0.0
	host.observed_phase = "docked"
	host.demo_mode = false
	host.skip.clear()
	host.skip_screen.hide()
	host.panel.hide()
	host.ghost.hide()
	host.test_walk_input = Vector3.ZERO
	host.walker.position = Vector3(0, -1.13, 18)
	host.walker.rotation = Vector3.ZERO
	host.walker.velocity = Vector3.ZERO
	host.camera.position = Vector3(0, 1.62, 0)
	host.camera.rotation = Vector3.ZERO
	host.pitch = 0
	host.jobs = host.economy.offers(0)
	host.ship.sync_hardware()
	host.ship._update_flight_world()
	host._update_life_visuals()
	host._refresh_station()

func _finish(paths: Array, hashes: Dictionary, process_before: bool, physics_before: bool) -> bool:
	for path in paths:
		var after := FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "ABSENT"
		check(after == hashes[path], "flight regression preserves existing save " + path)
	host.set_process(process_before)
	host.set_physics_process(physics_before)
	print("SHIP LIFE FLIGHT TOTAL: %d passed / %d failed" % [passed, failed])
	return failed == 0
