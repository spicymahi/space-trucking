extends "res://scripts/ship_life_trial.gd"
## Complete gameplay inside the Blender station, with a separate persistent save.
const STATION_SAVE := "user://station_trial_v1.json"
const STATION_CHECKPOINT := "user://station_trial_departure_v1.json"
var station_hangar: Node3D
var screen_refresh := 0.0

func _create_ship() -> Node3D:
	return preload("res://scripts/station_trial_flight.gd").new()

func _create_dock() -> Dictionary:
	station_hangar = preload("res://scripts/station_hangar.gd").new()
	add_child(station_hangar)
	return station_hangar.build(self)

func _ready() -> void:
	var existing := FileAccess.file_exists(_save_path(LIFE_SAVE)) and "--ship-life-new" not in OS.get_cmdline_user_args()
	super._ready()
	DisplayServer.window_set_title("Space Trucking — Blender Station Playtest")
	# Replace the old apron kiosks; all hab fixtures retain their existing bindings.
	for action in ["provisions","repairs"]:
		var old: Node3D = life_art.targets[action].get_parent()
		old.hide()
		for body in old.find_children("*","CollisionObject3D",true,false): body.collision_layer = 0
		life_art.targets[action] = station_hangar.targets[action]
	life_art.port_readout = station_hangar.terminals.provisions.get_node("StatusText")
	life_art.repairs_readout = station_hangar.terminals.repairs.get_node("StatusText")
	if not existing:
		walker.position = Vector3(9.3,-1.275,7.5); walker.rotation.y = -PI/2
		camera.rotation = Vector3(-0.08,0,0); pitch = -0.08
		save_life(CHECKPOINT)
	_refresh_station(); refresh_dock_visibility(); station_hangar.refresh_screens()
	message("BLENDER STATION / F at CONTRACTS to choose work. Counter also has provisions, repairs, fuel and delivery. F1: playtest guide. This session has its own save.")
	var args := OS.get_cmdline_user_args()
	if "--station-trial-test" in args: _run_station_tests.call_deferred()
	elif "--station-trial-capture" in args: _capture_station.call_deferred()

func _process(delta:float) -> void:
	super._process(delta)
	screen_refresh += delta
	if screen_refresh >= 0.25:
		screen_refresh = 0.0; station_hangar.refresh_screens()

func _advance_simulation(seconds:float,thrust:=Vector3.ZERO,rotation_input:=Vector3.ZERO,stop:=false) -> float:
	station_hangar.advance_door(seconds)
	return super._advance_simulation(seconds,thrust,rotation_input,stop)

func refresh_dock_visibility() -> void:
	if not station_hangar or not ship: return
	var index: int = ship.nearby_station_id()
	var f = ship.flight
	var near: bool = f.ship_position.distance_to(f.station_position(index,f.elapsed)) < 1800
	station_hangar.transform = ship.station_frame(index) * Transform3D(Basis.IDENTITY,Vector3(0,-1.315,0))
	station_hangar.set_active(near,f.phase=="docked")
	if not ship.ramp_moving and not ship.ramp_up: ship.ramp_pivot.rotation.x = atan(1.315/4.2)

func _save_path(path:String) -> String:
	var mapped := STATION_SAVE if path==LIFE_SAVE else (STATION_CHECKPOINT if path==CHECKPOINT else path)
	var args := OS.get_cmdline_user_args()
	if ("--station-trial-test" in args or "--station-trial-capture" in args) and mapped.begins_with("user://"):
		return "/tmp/"+("station-integration-" if "--station-trial-test" in args else "station-capture-")+mapped.get_file()
	return mapped

func _use_life(action:String) -> void:
	if action=="refuel": open_terminal(action)
	else: super._use_life(action)

func _action_hint(action:String) -> String:
	return "PORT REFUELLING / TANK AND PRICE" if action=="refuel" else super._action_hint(action)

func _terminal_text(mode:String) -> String:
	if mode=="refuel":
		return "FUEL SUPPLY / %s\n\nTANK %.0f / 3000 KG\nTOP UP %d CR / WALLET %d CR\n\nrefuel : fill tank\nadvance : request essential-cost shortfall against your contract\nstatus / return / help" % [System.NAMES[economy.station],ship.flight.fuel,_fuel_cost(),economy.credits]
	return super._terminal_text(mode)

func _command(text:String) -> void:
	var op := text.strip_edges().to_lower()
	if terminal_mode=="refuel" and op in ["refuel","advance"]:
		terminal_history.append(readout.text)
		output = buy_fuel() if op=="refuel" else request_advance()
		readout.text=output; command.clear(); _refresh_station()
	else: super._command(text)

func flight_departure() -> String:
	ship.sync_hardware()
	if not life.can_depart(): return "Sensor failure blocks takeoff. Repair at the hangar service terminal."
	if not economy.active.is_empty() and economy.active.phase not in ["complete","to_pickup"] and (not load_readiness().is_empty() or not locked): return "Load and secure every contracted case before departure."
	if economy.leg_destination()>=0 and ship.flight.destination!=economy.leg_destination(): return "Route does not match this contract's next station: "+System.NAMES[economy.leg_destination()]
	var notice: String = ship.prepare_hangar_departure()
	if not notice.is_empty(): return notice
	return super.flight_departure()

func start_test_cruise() -> String:
	var was_docked: bool = ship.flight.phase=="docked"
	var result := super.start_test_cruise()
	if was_docked and ship.flight.autopilot:
		var f = ship.flight
		f.ship_position=f.station_position(f.dock_id,f.elapsed)+Vector3(0,2,420)
		f.velocity=f.station_velocity(f.dock_id,f.elapsed)
		f.plan_route(System.IDS[economy.leg_destination()]); f.entered_coords=f.plan.target
		f.entered_burn=f.plan.burn; f.entered_reserve=f.plan.reserve; f.load_route(); f.engage_navigation()
		ship._update_flight_world()
	return result

func _guide_text() -> String:
	return "BLENDER STATION PLAYTEST\n\nDispatch counter: CONTRACTS, PROVISIONS, REPAIRS, REFUEL, DELIVERY.\nPickup grids: left of ramp. Delivery grids: right. F carries and places.\nEvery marked grid supports stacking; keep the centre aisle clear.\n\nThe outer door opens after your cockpit departure checklist.\nCOMMS depart opens it; wait six seconds, then depart again.\nExit backwards (S) through the door behind the ship; NAV engage when clear.\nArrival: NAV approach, then auto dock (or manual forward entry).\nOnly lower the ramp/open the cargo hatch after touchdown.\n\n"+super._guide_text()

func _run_station_tests() -> void:
	var ok: bool = await preload("res://scripts/station_trial_test.gd").new().run(self)
	get_tree().quit(0 if ok else 1)

func _capture_station() -> void:
	await preload("res://scripts/station_trial_capture.gd").new().run(self)
