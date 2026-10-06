extends RefCounted
## Walk and interact through the real preview bindings; never teleport or call use directly.
var host: Node3D
var service: Node3D
var all_ok := true
var checks := 0

func run(ship: Node3D) -> bool:
	host = ship
	service = host.service_module
	all_ok = true
	checks = 0
	check("Both service doors start open", service.doors.wash.open and service.doors.air.open)
	await _walk(Vector3(0,0,-2.5), "Walk from hab into service corridor")
	await _use("wash_door")
	check("Corridor control closes washroom door", not service.doors.wash.open and not service.doors.wash.moving)
	await _use("air_door")
	check("Corridor control closes inner airlock hatch", not service.doors.air.open and not service.doors.air.moving)
	await _walk(Vector3(0,0,-3.65), "Walk forward with both side doors closed")
	await _walk(Vector3(0,0,-1.35), "Walk aft with both side doors closed")
	await _walk(Vector3(0,0,-2.5), "Return to closed side-door openings")
	await _push(Vector3.LEFT,30)
	check("Closed washroom door blocks crossing", host.player.position.x > -0.53 and host.player.position.x < -0.30 and host.player.is_on_floor())
	await _walk(Vector3(0,0,-2.5), "Return from closed washroom door")
	await _push(Vector3.RIGHT,30)
	check("Closed airlock hatch blocks crossing", host.player.position.x < 0.53 and host.player.position.x > 0.30 and host.player.is_on_floor())
	await _walk(Vector3(0,0,-2.5), "Return from closed airlock hatch")
	await _use("wash_door")
	await _use("air_door")
	check("Both corridor controls reopen their doors", service.doors.wash.open and service.doors.air.open)
	# Start closing from clear space, then physically enter the sweep before it finishes.
	await _use("wash_door",0)
	check("Washroom starts closing before mid-close entry", service.doors.wash.moving and not service.doors.wash.open)
	await _push(Vector3.LEFT,15)
	await host._frames(30)
	check("Washroom door reverses when player enters during closing", service.doors.wash.open and not service.doors.wash.moving and host.player.position.x < -0.18 and host.player.is_on_floor())
	await _walk(Vector3(0,0,-2.5), "Clear washroom after automatic reopening")
	await _use("air_door",0)
	check("Airlock starts closing before mid-close entry", service.doors.air.moving and not service.doors.air.open)
	await _push(Vector3.RIGHT,15)
	await host._frames(30)
	check("Airlock hatch reverses when player enters during closing", service.doors.air.open and not service.doors.air.moving and host.player.position.x > 0.18 and host.player.is_on_floor())
	await _walk(Vector3(0,0,-2.5), "Clear airlock after automatic reopening")

	await _walk(Vector3(-0.74,0,-2.5), "Stand in washroom doorway")
	await _use("wash_door")
	check("Washroom door refuses to close on the player", service.doors.wash.open and not service.doors.wash.moving)
	await _walk(Vector3(0,0,-2.5), "Clear washroom doorway")
	await _walk(Vector3(0.74,0,-2.5), "Stand in airlock doorway")
	await _use("air_door")
	check("Airlock hatch refuses to close on the player", service.doors.air.open and not service.doors.air.moving)
	await _walk(Vector3(0,0,-2.5), "Clear airlock doorway")

	await _walk(Vector3(-1.75,0,-2.7), "Enter washroom through the open door")
	await _walk(Vector3(-2.24,0,-2.35), "Reach vacuum-toilet standing space")
	await _walk(Vector3(-1.75,0,-2.7), "Return to washroom turning space")
	await _walk(Vector3(-2.05,0,-3.35), "Walk onto the flush shower tray")
	await _use("shower")
	check("Shower switch starts visible water", service.shower_on and service.shower_flow.visible)
	await _use("shower")
	check("Shower switch stops water", not service.shower_on and not service.shower_flow.visible)
	await _walk(Vector3(-1.75,0,-2.7), "Leave shower without a step or obstruction")
	await _walk(Vector3(-1.27,0,-2.05), "Stand at wash basin")
	await _use("tap")
	check("Tap starts visible basin water", service.tap_on and service.tap_flow.visible)
	await _use("tap")
	check("Tap stops basin water", not service.tap_on and not service.tap_flow.visible)
	await _walk(Vector3(-1.75,0,-2.5), "Clear washroom door sweep from inside")
	await _use("wash_inside")
	check("Inside washroom control closes the door", not service.doors.wash.open and not service.doors.wash.moving)
	await _use("wash_inside")
	check("Inside washroom control reopens the door", service.doors.wash.open and not service.doors.wash.moving)
	await _walk(Vector3(0,0,-2.5), "Leave washroom through its doorway")

	await _walk(Vector3(1.70,0,-2.5), "Enter the airlock")
	await _walk(Vector3(1.70,0,-3.04), "Reach suit-rack working space")
	await _walk(Vector3(1.70,0,-2.5), "Return to airlock turning space")
	await _push(Vector3.RIGHT,35)
	check("Sealed outer hatch blocks exit through hull", host.player.position.x < 2.40 and host.player.position.x > 2.10 and host.player.is_on_floor())
	await _walk(Vector3(1.70,0,-2.5), "Back away from sealed outer hatch")
	await _walk(Vector3(1.70,0,-2.0), "Reach airlock pressure console")
	await _use("pressure")
	check("Seal check refuses to run with inner hatch open", not service.pressure_busy and not service.pressure_checked and service.doors.air.open)
	await _use("air_inside")
	check("Inside airlock control closes inner hatch", not service.doors.air.open and not service.doors.air.moving)
	await _use("pressure")
	check("Seal check starts with inner hatch closed", service.pressure_busy and not service.pressure_checked)
	await _use("air_inside")
	check("Inner hatch cannot open during seal check", service.pressure_busy and not service.doors.air.open and not service.doors.air.moving)
	await host._frames(160)
	check("Seal check completes and reports success", not service.pressure_busy and service.pressure_checked and "SEALS / OK" in service.pressure_label.text)
	await _use("air_inside")
	check("Inner hatch reopens after completed seal check", service.doors.air.open and not service.doors.air.moving and not service.pressure_checked)
	await _walk(Vector3(1.70,0,-2.5), "Return to airlock exit line")
	await _walk(Vector3(0,0,-2.5), "Exit airlock into the corridor")
	await _walk(Vector3(0,0,-0.5), "Walk aft into the cargo hold")
	await _walk(Vector3(0,0,-4.65), "Return through service module to hab")
	print("LONGHAUL SERVICE ", "PASS" if all_ok else "FAIL", " / ", checks, " checks")
	return all_ok

func check(title: String, passed: bool) -> void:
	checks += 1
	all_ok = all_ok and passed
	print("SERVICE ", title, ": ", passed)

func _walk(target: Vector3, title: String) -> bool:
	var reached: bool = await host._walk_to(target)
	check(title, reached and host.player.is_on_floor())
	return reached

func _push(direction: Vector3, frames: int) -> void:
	host.player.rotation.y = atan2(-direction.x,-direction.z)
	Input.action_press("move_forward")
	await host._frames(frames)
	Input.action_release("move_forward")
	await host._frames(2)

func _key() -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_F
	event.keycode = KEY_F
	event.pressed = true
	Input.parse_input_event(event)
	await host._frames(2)
	var release := InputEventKey.new()
	release.physical_keycode = KEY_F
	release.keycode = KEY_F
	release.pressed = false
	Input.parse_input_event(release)
	await host._frames(2)

func _use(action: String, settle_frames := 30) -> bool:
	var body: Node3D = service.use_targets[action]
	var target: Vector3 = body.global_position
	var direction: Vector3 = (target - host.camera.global_position).normalized()
	host.player.rotation.y = atan2(-direction.x,-direction.z)
	host.pitch = asin(direction.y)
	host.camera.rotation = Vector3(host.pitch,0,0)
	await host._frames(2)
	var hit: Dictionary = service.interaction(host.camera,host.player)
	var aimed: bool = not hit.is_empty() and hit.get("action", "") == action
	check("Aim at reachable " + action + " control", aimed)
	if not aimed:
		print("SERVICE interaction miss / expected ", action, " / got ", hit, " / player ", host.player.position, " / target ", target)
		return false
	await _key()
	if settle_frames > 0:
		await host._frames(settle_frames)
	return true
