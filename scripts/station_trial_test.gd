extends RefCounted
## Blender hangar integration regression. Runs only in an isolated station trial.
## Covers new physical anchors and access paths; legacy suites own kitchen,
## packing permutations, and flight mathematics.
const Packing = preload("res://scripts/cargo_trial_packing.gd")
const CargoChecks = preload("res://scripts/cargo_trial_integration_test.gd")
const FLOOR_Y := -1.315
var host: Node3D
var passed := 0
var failed := 0
var save_hashes: Dictionary = {}

func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error("STATION TRIAL FAIL: " + label)
	print("STATION TRIAL ", label, ": ", ok)

func run(controller: Node3D) -> bool:
	host = controller
	if "--station-trial-test" not in OS.get_cmdline_user_args():
		push_error("Station tests require --station-trial-test to isolate saves.")
		return false
	for path in ["user://longhaul_flight_v1.json", "user://ship_life_v1.json", "user://ship_life_departure_v1.json", "user://station_trial_v1.json", "user://station_trial_departure_v1.json"]:
		save_hashes[path] = _hash(path)
	host.set_process(false)
	host.paused_life = false
	host.panel.hide()
	await frames(4)
	check(host.station_hangar != null, "combined controller owns the imported station hangar")
	check(host.ship.flight.phase == "docked", "new station trial begins docked")
	var initial_distance: float = host.ship.flight.ship_position.distance_to(host.ship.flight.station_position(host.ship.flight.dock_id, host.ship.flight.elapsed))
	check(initial_distance < 0.01, "new docked ship begins at its station orbital position")
	if initial_distance > 0.01: return false
	check(host.dock.pickup_positions.size() == 12 and host.dock.drop_positions.size() == 12, "both aprons retain twelve stackable grids")
	_geometry()
	await _terminals()
	await _walking_and_carrying()
	await _cargo_departure_arrival()
	await _save_isolation()
	_release_walk()
	for path in save_hashes:
		check(_hash(path) == save_hashes[path], "preserves existing save " + path)
	print("STATION TRIAL TOTAL: %d passed / %d failed" % [passed, failed])
	return failed == 0

func _geometry() -> void:
	var ground := true
	var aligned := true
	for kind in ["pickup", "drop"]:
		for index in host._floor_positions(kind).size():
			var center: Vector3 = host._floor_positions(kind)[index]
			var hit := _ray(center + Vector3(0, 0.4, 0), center - Vector3(0, 0.4, 0))
			ground = ground and not hit.is_empty() and absf(float(hit.get("position", Vector3.ZERO).y) - FLOOR_Y) < 0.04
			aligned = aligned and absf(host._floor_origin(kind, index).y - FLOOR_Y) < 0.06
	check(ground, "every pickup and delivery grid has solid floor at the imported deck height")
	check(aligned, "cargo grid origins agree with the Blender floor rather than the old apron")
	var ship_ground := _ray(Vector3(0, 0.5, 6), Vector3(0, -0.5, 6))
	check(not ship_ground.is_empty() and absf(ship_ground.position.y) < 0.12, "ship interior retains its original walkable deck height")
	var door_ray := _ray(Vector3(0, 2, 30), Vector3(0, 2, 37))
	check(not door_ray.is_empty(), "closed pressure door physically blocks the flight opening")
	var wall_ray := _ray(Vector3(0, 2, 29), Vector3(17, 2, 29))
	check(not wall_ray.is_empty(), "hangar perimeter is solid rather than decorative geometry alone")

func _terminals() -> void:
	for action in ["contract", "provisions", "repairs", "refuel", "depart"]:
		await _use_terminal(action)
		check(host.panel.visible and host.terminal_mode == action, "physical F targeting opens " + action + " terminal")
		if action == "provisions":
			var wallet: int = host.economy.credits
			host._command("buy food 4")
			host._command("buy water 4")
			check(host.life.food_stock == 4 and host.life.water_stock == 4 and host.economy.credits == wallet - 4 * (host.FOOD_PRICE + host.WATER_PRICE), "new provisions screen purchases real pantry stock at the correct cost")
		elif action == "repairs":
			host.life.sensors.navigation = 50.0
			host._command("repair navigation")
			check(host.life.sensors.navigation == 100.0, "new repairs screen services the actual ship sensor")
		elif action == "refuel":
			var wallet: int = host.economy.credits
			var cost: int = host._fuel_cost()
			host._command("refuel")
			check(is_equal_approx(host.ship.flight.fuel, 3000.0) and host.economy.credits == wallet - cost, "dedicated refuel terminal fills the real tank and bills once")
	await _use_terminal("contract")
	var index := _full_job()
	check(index >= 0, "station offers a guaranteed-fit full cargo contract")
	if index >= 0: host._command("accept %d" % (index + 1))
	check(host.parcels.size() >= 8 and host.parcels.size() <= 12, "accepting at the Blender dispatch counter spawns the physical manifest")
	check(not host.toggle_lock(), "unloaded goods cannot be secured for departure")
	host.panel.hide()

func _walking_and_carrying() -> void:
	await aim(Vector3(9, FLOOR_Y + 0.04, 14), Vector3(9, 0, 18))
	check(await walk_to(Vector3(9, FLOOR_Y, 18)), "player walks from service counter to aft handling aisle")
	check(await walk_to(Vector3(0, FLOOR_Y, 18)), "player crosses the handling aisle without hitting cargo pads or furniture")
	check(await walk_to(Vector3(0, 0.05, 5.7)), "player walks up the adjusted ramp through engineering into the cargo hold")
	check(await walk_to(Vector3(0, FLOOR_Y, 18)), "player returns down the ramp without a floor seam or fall")
	if host.parcels.is_empty(): return
	var first: int = int(host.parcels.keys()[0])
	for id in host.parcels:
		if host.parcels[id].slot == 0: first = int(id)
	var at: Vector3 = host.cases[first].global_position
	await aim(Vector3(-3.3, FLOOR_Y + 0.04, at.z), at)
	press(KEY_F)
	check(host.held == first and host.tool.visible, "real F on a collection box equips the carrying tool")
	if host.held == first:
		var slot: int = 0
		check(host.place_held(host.floor_target("pickup", slot, Vector3i.ZERO, host.held_size)), "collection grid accepts returning the carried parcel")
	var longest := first
	for id in host.parcels:
		if host.parcels[id].size.z > host.parcels[longest].size.z: longest = int(id)
	await aim(Vector3(0, FLOOR_Y + 0.04, 18), Vector3(0, 0, 8))
	var source_slot: int = host.parcels[longest].slot
	check(host.pick_case(longest), "longest manifest box can be held in the clear loading aisle")
	if host.held == longest:
		check(await walk_to(Vector3(0, 0.05, 5.7)), "largest lengthwise cargo clears the real ramp and ship passage")
		check(host.place_held(host.floor_target("pickup", source_slot, Vector3i.ZERO, host.held_size)), "cargo movement leaves the source grid usable")
		await walk_to(Vector3(0, FLOOR_Y, 18))

func _cargo_departure_arrival() -> void:
	if host.parcels.is_empty(): return
	await aim(Vector3(0, FLOOR_Y + 0.04, 18), Vector3(0, 0, 9))
	var helper = CargoChecks.new()
	helper.host = host
	check(helper._load_solution() and host.packing.occupied_volume() == 48, "full guaranteed-fit manifest loads into the unchanged ship racks")
	check(host.toggle_lock() and host.locked, "real cargo lock secures the full manifest")
	await _manual_departure()
	var count: int = host.parcels.size()
	var destination: int = host.economy.leg_destination()
	# Departure and long-route state use the combined controller, not fabricated arrival events.
	var response: String = host.start_test_cruise()
	check(host.ship.flight.autopilot, "prepared test enters a real transfer: " + response.get_slice("\n", 0))
	if not host.ship.flight.autopilot: return
	check(host.ship.nearby_station_id() == host.ship.flight.dock_id and host.station_hangar.visible, "NAV destination selection keeps the nearby departure station visible until it is left")
	host.set_physics_process(false)
	var flight = host.ship.flight
	for step in 1400:
		host._advance_simulation(0.1 if flight.time_to_burn() < 5.0 else 5.0)
		if flight.phase == "approach" or not flight.autopilot: break
	check(flight.phase == "approach" and flight.arrival_hold, "real transfer reaches the station holding position")
	host.ship.terminal_command("nav", "approach")
	host.ship.terminal_command("nav", "auto dock")
	check(flight.auto_docking and flight.approach_clearance, "NAV obtains an actual berth and starts automatic docking")
	for step in 2400:
		host._advance_simulation(0.5)
		if flight.phase == "docked" or not flight.autopilot: break
	check(flight.phase == "docked" and flight.dock_id == destination, "nose-first approach reaches the modeled bay dock anchor")
	check(host.economy.active.phase == "unloading" and host.economy.station == destination, "physical arrival advances the cargo contract at its destination")
	check(host.parcels.size() == count and host.packing.placements.size() == count and host.locked, "station transition preserves every secured cargo box")
	if flight.phase != "docked": return
	host.ship.terminal_command("checklist", "hatch open")
	host.ship.terminal_command("checklist", "ramp lower")
	await host.get_tree().create_timer(2.0).timeout
	host.set_physics_process(true)
	check(host.toggle_lock() and not host.locked, "destination cargo lock releases for unloading")
	await aim(Vector3(0, FLOOR_Y + 0.04, 18), Vector3(0, 0, 9))
	var sequence: Array[int] = host.packing.get_solution_order()
	sequence.reverse()
	var ok := true
	for index in sequence.size():
		var id: int = sequence[index]
		ok = host.pick_case(id) and ok
		if host.held != id: continue
		if index == 0:
			var center: Vector3 = host.dock.drop_positions[0]
			await aim(Vector3(3.3, FLOOR_Y + 0.04, center.z), center + Vector3(0, 0.015, 0))
			host._update_aim()
			check(not host.candidate.is_empty() and host.candidate.get("kind") == "drop" and host.candidate.get("reason", "!").is_empty(), "actual delivery floor ray produces an unobstructed placement ghost")
			press(KEY_F)
			ok = host.held == -1 and ok
			if host.held == id: host.place_held(host.floor_target("drop", index, Vector3i.ZERO, host.held_size))
			check(not host.complete_delivery(), "delivery counter refuses partial unloading")
			await aim(Vector3(0, FLOOR_Y + 0.04, 18), Vector3(0, 0, 9))
		else: ok = host.place_held(host.floor_target("drop", index, Vector3i.ZERO, host.held_size)) and ok
	check(ok and host.delivered_count() == count, "complete travelled manifest unloads to the new delivery grids")
	var wallet: int = host.economy.credits
	var payment: int = host.economy.active.remaining_pay
	await _use_terminal("complete")
	check(host.economy.active.phase == "complete" and host.economy.credits == wallet + payment, "physical completion terminal pays the agreed fee exactly once")
	check(host.parcels.is_empty() and host.cases.is_empty() and host.floor_packing.placements.is_empty(), "completion removes all delivered boxes and grid occupancy")
	press(KEY_F)
	check(host.economy.credits == wallet + payment, "repeated F at delivery cannot duplicate payment")

func _manual_departure() -> void:
	var path := "/tmp/station-trial-before-departure.json"
	host.save_life(path)
	var flight = host.ship.flight
	await aim(Vector3(0, 0.05, -10.32), Vector3(0, 1.4, -12))
	host.ship.terminal_command("engine", "port on")
	host.ship.terminal_command("engine", "starboard on")
	host.ship.terminal_command("chart", "plot " + host.System.IDS[host.economy.leg_destination()] + " direct")
	if flight.plan.is_empty():
		check(false, "manual departure has a valid route solution")
		return
	var target: Vector3 = flight.plan.target / 1000.0
	host.ship.terminal_command("nav", "coords %.8f %.8f %.8f" % [target.x, target.y, target.z])
	host.ship.terminal_command("nav", "burn %.8f" % float(flight.plan.burn))
	host.ship.terminal_command("nav", "reserve %.8f" % float(flight.plan.reserve))
	host.ship.terminal_command("nav", "load")
	host.ship.terminal_command("comms", "request")
	host.ship.terminal_command("comms", "code " + flight.clearance)
	host.ship.terminal_command("checklist", "hatch close")
	await host.get_tree().create_timer(2.4).timeout
	host.ship.terminal_command("checklist", "ramp raise")
	await host.get_tree().create_timer(3.4).timeout
	host.ship.sync_hardware()
	var reply: String = host.ship.terminal_command("comms", "depart")
	check(flight.phase == "docked" and reply.to_lower().contains("door"), "COMMS waits for the actual pressure door before releasing the berth")
	for step in 30: host._advance_simulation(0.25)
	await frames(3)
	check(host.station_hangar.door_clear_for_flight, "station pressure-door leaves reach a fully clear opening")
	var clear_ray := _ray(Vector3(0, 2, 30), Vector3(0, 2, 37))
	check(clear_ray.is_empty(), "opened pressure-door collision moves clear of the flight corridor")
	var walker_before: Vector3 = host.walker.position
	host.walker.position = Vector3(0, FLOOR_Y, 34)
	host.station_hangar.set_door_open(false)
	host.station_hangar.advance_door(1.0)
	check(host.station_hangar.door_clear_for_flight, "pressure door refuses to close through a player in its threshold")
	host.walker.position = walker_before
	host.station_hangar.set_door_open(true)
	reply = host.ship.terminal_command("comms", "depart")
	check(flight.phase == "departure" and not flight.autopilot, "second COMMS depart releases the ship for manual flight")
	var frame: Transform3D = host.ship.station_frame(flight.dock_id)
	check(frame.origin.length() < 0.01 and frame.basis.is_equal_approx(Basis.IDENTITY), "docked station frame agrees exactly with the Blender ship anchor")
	check(flight.hangar_obstruction(Vector3(0, 2, 34), Basis.IDENTITY).is_empty(), "level full-size Longhaul fits the open aperture at its arrival lift")
	check(not flight.hangar_obstruction(Vector3(5, 2, 34), Basis.IDENTITY).is_empty(), "manual-flight hull clearance detects an off-center doorway collision")
	flight.hangar_door_clear = false
	check(not flight.hangar_obstruction(Vector3(0, 2, 34), Basis.IDENTITY).is_empty(), "manual-flight hull clearance rejects the closed pressure door")
	flight.ship_position = flight.station_position(flight.dock_id, flight.elapsed) + Vector3(0, 2, 20)
	flight.velocity = flight.station_velocity(flight.dock_id, flight.elapsed) + Vector3(0, 0, 10)
	flight.attitude = Basis.IDENTITY
	flight._step(0.2, Vector3.ZERO, Vector3.ZERO, false)
	var stopped: Vector3 = flight.ship_position - flight.station_position(flight.dock_id, flight.elapsed)
	check(stopped.distance_to(Vector3(0, 2, 20)) < 0.01 and flight.relative_velocity_local().length() < 0.01, "real manual flight step arrests a hull crossing into the closed door without damage")
	flight.hangar_door_clear = true
	host.load_life(path)
	check(host.ship.flight.phase == "docked" and host.locked, "isolated fixture restore preserves the loaded contract before transfer")

func _save_isolation() -> void:
	host.panel.hide()
	var path := "/tmp/station-trial-integration-roundtrip.json"
	check(host.save_life(path).contains("saved"), "station session saves to an explicit isolated file")
	var position: Vector3 = host.walker.position
	var credits: int = host.economy.credits
	host.walker.position += Vector3(0, 0, 1)
	host.economy.credits -= 7
	var result: String = host.load_life(path)
	check(host.walker.position.is_equal_approx(position) and host.economy.credits == credits, "station session restores player pose and economy together: " + result.get_slice("\n", 0))

func _use_terminal(action: String) -> void:
	var target: Node3D = host.station_hangar.targets[action]
	var from := target.global_position + Vector3(-1.7, 0, 0)
	from.y = FLOOR_Y + 0.04
	if action == "depart": from = Vector3(-3.4, FLOOR_Y + 0.04, 20)
	await aim(from, target.global_position)
	press(KEY_F)

func _full_job() -> int:
	for index in host.jobs.size():
		if host.jobs[index].kind == "outbound" and host.jobs[index].full: return index
	return -1

func _ray(from: Vector3, to: Vector3) -> Dictionary:
	return host.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1, [host.walker.get_rid()]))

func aim(from: Vector3, target: Vector3) -> void:
	_release_walk()
	host.panel.hide()
	host.paused_life = false
	host.walker.position = from
	host.walker.velocity = Vector3.ZERO
	host.walker.rotation = Vector3.ZERO
	host.camera.position.y = 1.62
	host.camera.look_at(target, Vector3.UP)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await frames(3)
	host.camera.look_at(target, Vector3.UP)
	host._update_aim()

func walk_to(target: Vector3) -> bool:
	host.panel.hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var offset: Vector3 = target - host.walker.position
	host.walker.rotation.y = atan2(-offset.x, -offset.z)
	host.camera.rotation = Vector3.ZERO
	host.test_walk_input = Vector3(0, 0, -1)
	var reached := false
	var last: Vector3 = host.walker.position
	var stalled := 0
	for tick in 1600:
		await host.get_tree().physics_frame
		var position: Vector3 = host.walker.position
		if Vector2(position.x - target.x, position.z - target.z).length() < 0.14:
			reached = absf(position.y - target.y) < 0.3
			break
		stalled = stalled + 1 if position.distance_to(last) < 0.001 else 0
		if stalled >= 90: break
		last = position
	_release_walk()
	if not reached: print("STATION WALK STOP ", host.walker.position, " target=", target)
	await frames(2)
	return reached

func _release_walk() -> void:
	if host: host.test_walk_input = Vector3.ZERO

func press(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	host._unhandled_input(event)

func frames(count: int) -> void:
	for index in count: await host.get_tree().physics_frame

func _hash(path: String) -> String:
	return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "ABSENT"
