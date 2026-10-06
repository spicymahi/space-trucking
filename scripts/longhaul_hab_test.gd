extends RefCounted
## Input-driven furniture and circulation checks for the walkable Longhaul preview.
## Called after the existing tour; movement always uses the normal character controller.
var host: Node3D
var all_ok := true
var checks := 0

func run(ship: Node3D) -> bool:
	host = ship
	all_ok = true
	checks = 0
	# The front hab previously hid the cockpit hint but still accepted its distant F action.
	await _walk(Vector3(0,0,-8.5), "Reach hab side of the cockpit doorway")
	host.player.rotation = Vector3.ZERO
	host.pitch = 0.0
	host.camera.rotation = Vector3.ZERO
	var before_door: Vector3 = host.player.position
	await _key(KEY_F)
	check("F in the hab cannot take the distant cockpit seat", not host.seated and host.player.position.distance_to(before_door) < 0.08)
	if host.seated:
		await _key(KEY_F)
		await _walk(Vector3(0,0,-8.3), "Return to hab after failed cockpit regression")

	await _walk(Vector3(0,0,-7.97), "Reach bunk storage from center aisle")
	await _use("drawer")
	check("Bunk drawer opens from clear aisle", host.hab_module.drawer_open)
	await _use("drawer")
	check("Bunk drawer closes from clear aisle", not host.hab_module.drawer_open)
	await _walk(Vector3(-0.40,0,-7.97), "Approach bunk inside drawer clearance")
	await _use("drawer")
	check("Drawer opening is blocked while the player occupies its clearance", not host.hab_module.drawer_open)
	await _walk(Vector3(0.15,0,-7.97), "Back away from bunk storage")
	# Recover only through the real interaction if the occupancy regression failed.
	if host.hab_module.drawer_open:
		await _use("drawer")
	await _use("drawer")
	check("Drawer opens after the player clears its path", host.hab_module.drawer_open)
	await _walk(Vector3(0.15,0,-8.50), "Walk forward past the open bunk drawer")
	await _walk(Vector3(0.15,0,-7.35), "Walk aft past the open bunk drawer")
	await _walk(Vector3(0.15,0,-7.97), "Return to the open drawer without obstruction")
	await _use("drawer")
	check("Drawer is stowed before continuing", not host.hab_module.drawer_open)

	await _walk(Vector3(0,0,-8.34), "Reach bunk reading-light switch")
	var light_before: bool = host.hab_module.lamp_on
	await _use("lamp")
	check("Reading-light switch changes light state", host.hab_module.lamp_on != light_before and host.hab_module.reading_light.visible == host.hab_module.lamp_on)
	await _use("lamp")
	check("Reading-light switch restores light state", host.hab_module.lamp_on == light_before and host.hab_module.reading_light.visible == light_before)

	await _walk(Vector3(0,0,-8.0), "Cross the forward hab aisle")
	await _walk(Vector3(0.57,0,-8.0), "Stand at galley sink without collision")
	await _walk(Vector3(0.57,0,-6.75), "Walk along galley work surface")
	await _walk(Vector3(0,0,-6.45), "Return from galley to aisle")
	await _walk(Vector3(0,0,-5.10), "Reach aft utility area")
	await _walk(Vector3(0.62,0,-5.10), "Approach refrigerator and personal storage")
	await _walk(Vector3(0,0,-5.18), "Reach foldaway table from aisle")

	await _use("table")
	check("Table folds into wall recess", host.hab_module.table_folded and absf(host.hab_module.table_pivot.rotation.z - PI/2) < 0.02)
	await _walk(Vector3(-1.16,0,-5.18), "Enter space made available by folded table")
	await _use("table")
	check("Table lowering is blocked while player occupies its footprint", host.hab_module.table_folded)
	await _walk(Vector3(0,0,-5.18), "Leave table unfolding clearance")
	if not host.hab_module.table_folded:
		await _use("table")
	await _use("table")
	check("Table lowers after the player clears its footprint", not host.hab_module.table_folded and absf(host.hab_module.table_pivot.rotation.z) < 0.02)

	await _walk(Vector3(0,0,-4.65), "Reach dining bench from service doorway")
	await _use("bench")
	check("F sits at the dining bench", host.hab_seated and not host.seated and absf(host.camera.position.y - 1.22) < 0.01)
	if host.hab_seated:
		var seated_position: Vector3 = host.player.position
		Input.action_press("move_forward")
		await host._frames(12)
		Input.action_release("move_forward")
		check("Movement input keeps the seated player fixed", host.player.position.is_equal_approx(seated_position))
		await _key(KEY_T)
		await host._frames(24)
		check("T folds the table while seated", host.hab_module.table_folded)
		await _key(KEY_T)
		await host._frames(24)
		check("T lowers the table safely while seated", not host.hab_module.table_folded)
		await _key(KEY_F)
		check("F stands into a clear aisle and restores standing eye height", not host.hab_seated and absf(host.player.position.x) < 0.05 and absf(host.camera.position.y - 1.63) < 0.01)
	await _walk(Vector3(0,0,-5.85), "Walk away after leaving the dining bench")
	await _walk(Vector3(0,0,-3.65), "Leave hab through service-room connection")
	await _walk(Vector3(0,0,-4.65), "Return to hab without furniture obstruction")
	print("LONGHAUL HAB ", "PASS" if all_ok else "FAIL", " / ", checks, " checks")
	return all_ok

func check(title: String, passed: bool) -> void:
	checks += 1
	all_ok = all_ok and passed
	print("HAB ", title, ": ", passed)

func _walk(target: Vector3, title: String) -> bool:
	var reached: bool = await host._walk_to(target)
	check(title, reached and host.player.is_on_floor())
	return reached

func _key(code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await host._frames(2)
	var release := InputEventKey.new()
	release.physical_keycode = code
	release.keycode = code
	release.pressed = false
	Input.parse_input_event(release)
	await host._frames(2)

func _use(action: String) -> bool:
	var body: Node3D = host.hab_module.use_targets[action]
	var target: Vector3 = body.global_position
	if action == "drawer":
		# Aim at the exposed front, not the body center concealed inside the bunk.
		target = body.to_global(Vector3(0,0,0.249))
	var direction: Vector3 = (target - host.camera.global_position).normalized()
	host.player.rotation.y = atan2(-direction.x,-direction.z)
	host.pitch = asin(direction.y)
	host.camera.rotation = Vector3(host.pitch,0,0)
	await host._frames(2)
	var hit: Dictionary = host.hab_module.interaction(host.camera,host.player)
	var aimed: bool = not hit.is_empty() and hit.get("action", "") == action
	check("Aim at reachable " + action + " interaction", aimed)
	if not aimed:
		print("HAB interaction miss / expected ", action, " / got ", hit, " / player ", host.player.position, " / target ", target)
		return false
	await _key(KEY_F)
	await host._frames(24)
	return true
