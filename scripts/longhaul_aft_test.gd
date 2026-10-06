extends RefCounted
## Input-driven checks for the fitted aft rooms and loading route.
## All movement and interactions use the same bindings as the walkthrough.
var host: Node3D
var all_ok := true
var checks := 0

func run(ship: Node3D) -> bool:
	host = ship
	all_ok = true
	checks = 0
	await _walk(Vector3(0,0,0.0), "Enter cargo through aligned service doorway")
	await _cargo_checks()
	await _engineering_checks()
	await _loading_checks()
	await _walk(Vector3(0,0,-4.65), "Return through cargo and service corridor")
	print("LONGHAUL AFT ", "PASS" if all_ok else "FAIL", " / ", checks, " checks")
	return all_ok

func _cargo_checks() -> void:
	var cargo: Node3D = host.cargo_module
	check("Receiving case starts restrained in port berth", cargo.locked and not cargo.carrying and cargo.crate_slot==0)
	await _walk(Vector3(-1.05,0,0.15), "Reach manifest from forward cargo working space")
	await _use(cargo,"cargo_manifest")
	check("Manifest identifies case berth and clamp state", "BERTH 01" in cargo.manifest.text and "LOCKED" in cargo.manifest.text and not cargo.notice.is_empty())
	await _walk(Vector3(-1.78,0,0.28), "Enter manifest operator bay for straight-on reading")
	await _use(cargo,"cargo_manifest")
	check("Manifest remains readable and interactive from its working position", "BERTH 01" in cargo.manifest.text and "LOCKED" in cargo.manifest.text and not cargo.notice.is_empty())
	await _walk(Vector3(-1.05,0,0.15), "Leave manifest operator bay without rack obstruction")
	await _walk(Vector3(0,0,0.30), "Clear manifest and reach cargo aisle")
	await _walk(Vector3(0,0,5.68), "Walk full cargo handling aisle to receiving berths")
	await _use(cargo,"cargo_berth_0")
	check("Restrained service case cannot be picked up", cargo.locked and not cargo.carrying and cargo.crate_slot==0)
	await _use(cargo,"cargo_berth_1")
	check("Empty berth does not create another cargo case", not cargo.carrying and cargo.crate_slot==0)
	await _walk(Vector3(0,0,0.30), "Return to receiving-clamp controls")
	await _use(cargo,"cargo_clamps")
	check("Receiving clamps release visibly in manifest", not cargo.locked and "RELEASED" in cargo.manifest.text)
	await _walk(Vector3(0,0,5.68), "Reach released case from clear handling aisle")
	await _use(cargo,"cargo_berth_0")
	check("F picks up case with a carried collision shape", cargo.carrying and is_instance_valid(cargo.carry_shape) and cargo.held_crate.get_parent()==host.player and "IN TRANSIT" in cargo.manifest.text)
	if not cargo.carrying: return
	await _push(Vector3.LEFT,40)
	check("Carried case stops before colliding through receiving berth", host.player.position.x > -1.0 and host.player.position.x < -0.20 and host.player.is_on_floor())
	await _walk(Vector3(0,0,5.68), "Back away with case into turning space")
	await _walk(Vector3(0,0,9.0), "Carry case through widened engineering doorway")
	await _walk(Vector3(0,0,16.0), "Carry case down loading ramp to hangar")
	check("Case remains held while walking onto hangar floor", cargo.carrying and host.player.position.y < -1.0 and host.player.is_on_floor())
	await _walk(Vector3(0,0,9.0), "Carry case up ramp through engineering")
	await _walk(Vector3(0,0,0.30), "Return carried case along entire cargo handling route")
	await _use(cargo,"cargo_clamps")
	check("Clamps cannot lock while case is in the player's hands", cargo.carrying and not cargo.locked)
	await _walk(Vector3(0,0,5.68), "Return to receiving berths with case")
	await _use(cargo,"cargo_berth_1")
	check("F places case into starboard berth and removes carried shape", not cargo.carrying and cargo.crate_slot==1 and cargo.carry_shape==null and cargo.held_crate.get_parent()==cargo and "BERTH 02" in cargo.manifest.text)
	await _use(cargo,"cargo_berth_1")
	check("Case can be picked up again from its new berth", cargo.carrying)
	if cargo.carrying:
		await _use(cargo,"cargo_berth_0")
		check("Case transfers back to port berth", not cargo.carrying and cargo.crate_slot==0)
	await _walk(Vector3(0,0,0.30), "Reach clamps after placing cargo")
	await _use(cargo,"cargo_clamps")
	check("Clamps secure placed case and restore manifest state", cargo.locked and not cargo.carrying and "LOCKED" in cargo.manifest.text)
	await _walk(Vector3(0,0,6.30), "Leave cargo aisle clear after handling")

func _engineering_checks() -> void:
	var engine: Node3D = host.engineering_module
	await _walk(Vector3(0,0,8.15), "Enter fitted engineering through freight opening")
	await _walk(Vector3(0.70,0,8.15), "Stand at engineering diagnostic computer")
	await _use(engine,"eng_diag")
	check("Diagnostic computer reports degraded coolant pump", not engine.repaired and not engine.isolated and "46%" in engine.status_label.text)
	await _walk(Vector3(-0.75,0,10.0), "Reach coolant service hatch working space")
	await _use(engine,"eng_access")
	check("Live pump service cover refuses to open", not engine.cover_open and not engine.cover_moving)
	await _walk(Vector3(-0.70,0,8.5), "Reach coolant isolation lever")
	await _use(engine,"eng_isolate")
	check("Isolation lever stops coolant circuit and updates diagnostic state", engine.isolated and "ISOLATED / SAFE" in engine.status_label.text and "00%" in engine.status_label.text)
	await _use(engine,"eng_isolate")
	check("Incomplete bypass cannot be restored", engine.isolated and not engine.repaired)
	await _walk(Vector3(-0.75,0,10.0), "Return to safely isolated service bay")
	await _use(engine,"eng_access")
	check("Isolated service cover clears fuse controls within cabinet", engine.cover_open and not engine.cover_moving and engine.service_cover.position.y > 1.90 and engine.service_cover.position.y < 2.07)
	await _use(engine,"eng_fuse_0")
	check("Partial fuse sequence does not complete bypass", engine.fuse_pattern==[true,true,false] and not engine.bypass_ready)
	await _use(engine,"eng_fuse_1")
	check("Second fuse changes independently", engine.fuse_pattern==[true,false,false] and not engine.bypass_ready)
	await _use(engine,"eng_fuse_2")
	check("Marked fuse pattern completes temporary bypass", engine.fuse_pattern==[true,false,true] and engine.bypass_ready and not engine.repaired)
	await _use(engine,"eng_isolate")
	check("Circuit cannot restore with service cover open", engine.isolated and engine.cover_open and not engine.repaired)
	await _use(engine,"eng_access")
	check("Service cover closes before restoring power", not engine.cover_open and not engine.cover_moving and absf(engine.service_cover.position.y-1.13)<0.02)
	await _walk(Vector3(-0.70,0,8.5), "Return to isolation lever after closing service cover")
	await _use(engine,"eng_isolate")
	check("Restoring circuit runs repaired temporary bypass", not engine.isolated and engine.repaired and "BYPASS / RUNNING" in engine.status_label.text and "82%" in engine.status_label.text)
	await _walk(Vector3(0.70,0,8.15), "Read repaired system from diagnostic workstation")
	await _use(engine,"eng_diag")
	check("Diagnostics explain temporary repair and station overhaul", "overhaul" in engine.notice.to_lower())
	await _use(engine,"eng_reset")
	check("Fault-test control resets a completed repair for another attempt", not engine.repaired and not engine.isolated and not engine.cover_open and engine.fuse_pattern==[false,true,false] and "46%" in engine.status_label.text)
	await _walk(Vector3(0.75,0,9.80), "Reach spares workbench without blocking freight route")
	await _walk(Vector3(0,0,10.20), "Return to loading hatch approach")

func _loading_checks() -> void:
	var loading: Node3D = host.loading_module
	check("Loading hatch starts fully open for loading", loading.hatch_open and not loading.hatch_moving)
	await _use(loading,"load_inner",50)
	check("Inside hatch control seals loading opening", not loading.hatch_open and not loading.hatch_moving)
	await _push(Vector3.BACK,45)
	check("Closed loading hatch blocks passage onto ramp", host.player.position.z < 10.85 and host.player.position.z > 10.50 and host.player.is_on_floor())
	await _walk(Vector3(0,0,10.20), "Back away from sealed hatch")
	await _use(loading,"load_inner",50)
	check("Inside control fully reopens loading hatch", loading.hatch_open and not loading.hatch_moving)
	await _walk(Vector3(0,0,11.10), "Stand within loading doorway")
	await _use(loading,"load_inner",50)
	check("Loading hatch refuses to close on occupied doorway", loading.hatch_open and not loading.hatch_moving)
	await _walk(Vector3(0,0,10.20), "Clear loading doorway before closing")
	await _use(loading,"load_inner",0)
	check("Hatch begins closing while threshold is clear", not loading.hatch_open and loading.hatch_moving)
	await _push(Vector3.BACK,18)
	await host._frames(50)
	check("Closing hatch reopens if player enters its path", loading.hatch_open and not loading.hatch_moving)
	await _walk(Vector3(0,0,16.0), "Descend unobstructed ramp to hangar floor")
	await _walk(Vector3(0,0,12.05), "Approach outer hatch control from ramp")
	await _use(loading,"load_outer",50)
	check("Outer control seals hatch from loading ramp", not loading.hatch_open and not loading.hatch_moving)
	await _push(Vector3.FORWARD,35)
	check("Closed hatch also blocks entry from outside", host.player.position.z > 11.35 and host.player.position.z < 11.70 and host.player.is_on_floor())
	await _walk(Vector3(0,0,12.05), "Step back from closed outer hatch")
	await _use(loading,"load_outer",50)
	check("Outer control reopens hatch without trapping player outside", loading.hatch_open and not loading.hatch_moving)
	await _walk(Vector3(0,0,10.20), "Reenter engineering over flush loading threshold")

func check(title: String, passed: bool) -> void:
	checks += 1
	all_ok = all_ok and passed
	print("AFT ", title, ": ", passed)

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

func _key(code: int = KEY_F) -> void:
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

func _use(module: Node3D, action: String, settle_frames := 36, local_aim := Vector3.ZERO) -> bool:
	if not module.use_targets.has(action):
		check("Reachable " + action + " control exists", false)
		return false
	var body: Node3D = module.use_targets[action]
	var target: Vector3 = body.to_global(local_aim)
	var direction: Vector3 = (target - host.camera.global_position).normalized()
	host.player.rotation.y = atan2(-direction.x,-direction.z)
	host.pitch = asin(direction.y)
	host.camera.rotation = Vector3(host.pitch,0,0)
	await host._frames(2)
	var hit: Dictionary = module.interaction(host.camera,host.player)
	var aimed: bool = not hit.is_empty() and hit.get("action", "") == action
	check("Aim at reachable " + action + " control", aimed)
	if not aimed:
		print("AFT interaction miss / expected ", action, " / got ", hit, " / player ", host.player.position, " / target ", target)
		return false
	await _key()
	if settle_frames > 0:
		await host._frames(settle_frames)
	return true
