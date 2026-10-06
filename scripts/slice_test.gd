extends RefCounted
## End-to-end input test: walks every route, aims at real targets, presses keys.
## No player teleportation, flight teleportation or direct gameplay mutations.

var game: Node3D
var checks := 0


func frames(count: int) -> void:
	for i in count:
		await game.get_tree().physics_frame


func key(code: int, down := true) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	if code >= KEY_0 and code <= KEY_9: event.unicode = code
	if code == KEY_MINUS: event.unicode = 45
	Input.parse_input_event(event)
	await frames(2)


func press(code: int) -> void:
	await key(code)
	await key(code, false)


func check(ok: bool, label: String) -> bool:
	checks += 1
	print("SLICE ", "PASS " if ok else "FAIL ", label)
	if not ok:
		print("  player=", game.player.position, " menu=", game.menu, " prompt=", game.prompt_label.text, " message=", game.toast_text)
		if game.menu == "nav": print("  fields=", game.nav_fields.map(func(f): return f.text), " focus=", game.get_viewport().gui_get_focus_owner())
		game.get_tree().quit(1)
	return ok


func walk(point: Vector3, limit := 1600) -> bool:
	Input.action_press("move_forward")
	for i in limit:
		var d: Vector3 = point - game.player.position
		d.y = 0
		if d.length() < 0.2:
			Input.action_release("move_forward")
			await frames(2)
			return true
		game.player.rotation.y = atan2(-d.x, -d.z)
		await frames(1)
	Input.action_release("move_forward")
	return check(false, "walk to " + str(point))


func aim_use(point: Vector3) -> void:
	var d: Vector3 = point - game.camera.global_position
	game.player.rotation.y = atan2(-d.x, -d.z)
	game.pitch = atan2(d.y, Vector2(d.x, d.z).length())
	game.camera.rotation.x = game.pitch
	await frames(3)
	await press(KEY_F)


func use_target(name: String) -> void:
	await aim_use(game.targets[name].global_position)


func central(z: float) -> bool:
	if not await walk(Vector3(0.25, 0, game.player.position.z)): return false
	return await walk(Vector3(0.25, 0, z))


func terminal(name: String, point: Vector3) -> bool:
	if not await central(point.z): return false
	if not await walk(point): return false
	await use_target(name + "-1")
	return check(game.menu == name, "opened " + name + " by walking, aiming and F")


func load_crate(id: int, index: int) -> bool:
	if not await central(12.65): return false
	var p: Vector3 = game._slot_pos("pad", index)
	if not await walk(Vector3(p.x, 0, 12.65)): return false
	await aim_use(p)
	if not check(not game.state.hand().is_empty() and game.state.hand().id == id, "lifted job crate %d" % id): return false
	if not await central(5.3 + index * 1.65): return false
	await use_target("slot" + str(index))
	return check(game.state.hand().is_empty() and game.state.count_at("hold") == index + 1, "walked crate into hold and secured slot %d" % index)


func run(scene: Node3D) -> void:
	game = scene
	game.get_tree().create_timer(600).timeout.connect(func(): print("SLICE FAIL timed out"); game.get_tree().quit(1))
	await frames(10)
	await press(KEY_1)
	await frames(30)
	if not check(game.player.is_on_floor() and game.menu == "", "new run starts standing in hab"): return
	if not await terminal("contracts", Vector3(-2.8, 0, 20.8)): return
	await press(KEY_1)
	if not check(game.state.cargo.size() == 2 and not game.state.contract.is_empty(), "contract supplies exactly two free crates"): return
	await press(KEY_1)
	if not check(game.state.cargo.size() == 2, "cannot sign a duplicate active job"): return
	await press(KEY_ESCAPE)
	if not await load_crate(1, 0): return
	if not await load_crate(2, 1): return
	if not await terminal("trade", Vector3(-2.8, 0, 17.5)): return
	await press(KEY_2)
	if not check(game.state.cargo.size() == 2 and game.state.credits == 600, "exchange cannot sell client cargo"): return
	await press(KEY_1)
	if not check(game.state.credits == 520 and game.state.cargo.size() == 3, "bought own commodity cargo"): return
	await press(KEY_ESCAPE)
	if not await terminal("services", Vector3(0.25, 0, 20.4)): return
	await press(KEY_1)
	if not check(game.state.count_at("hold") == 3 and game.state.credits == 505, "paid crew loads personal crate and charges once"): return
	await press(KEY_1)
	if not check(game.state.credits == 505, "empty handling request does not charge money"): return
	await press(KEY_ESCAPE)
	if not await central(-7.7): return
	await use_target("seat-1")
	if not check(game.piloting, "walked through hold, hab and corridor to pilot seat"): return
	await press(KEY_N)
	if not check(game.menu == "nav", "opened navigation map and coordinate entry"): return
	# Deliberately submit an incomplete route first.
	await press(KEY_ENTER)
	if not check(not game.state.route_set, "incomplete coordinates rejected"): return
	for code in [KEY_2, KEY_4, KEY_TAB, KEY_3, KEY_TAB, KEY_MINUS, KEY_6, KEY_8, KEY_ENTER]:
		await press(code)
	if not check(game.state.route_set and game.state.destination == 1 and game.menu == "", "typed Tharsis coordinates and programmed route"): return
	await press(KEY_SPACE)
	await press(KEY_C)
	if not check(game.state.flight == "manual", "autopilot prohibited inside departure zone"): return
	await key(KEY_W)
	await frames(430)
	await key(KEY_W, false)
	if not check(game.state.position.length() > 400, "flew manual departure on W"): return
	await press(KEY_C)
	if not check(game.state.flight == "transit", "engaged programmed route after departure"): return
	await press(KEY_F)
	if not check(not game.piloting, "left seat safely while ship travels"): return
	if not await central(-5.35): return
	if not await walk(Vector3(0.9, 0, -5.35)): return
	await use_target("engineering-1")
	if not check(game.menu == "engineering", "inspected live engineering computer"): return
	await press(KEY_ESCAPE)
	if not await walk(Vector3(0.85, 0, -6.5)): return
	await use_target("repair-1")
	if not check(game.menu == "repair", "walked to physical coolant pump"): return
	await press(KEY_5)
	if not check(not game.state.patched, "invalid repair circuit rejected"): return
	for code in [KEY_4, KEY_1, KEY_2, KEY_2, KEY_3, KEY_3, KEY_5]: await press(code)
	if not check(game.state.patched and game.state.pump == 78, "isolated, aligned and tested temporary bypass"): return
	if not await central(-0.7): return
	if not await walk(Vector3(1.25, 0, -0.7)): return
	await use_target("eat-1")
	if not check(game.state.completed.has("eat") and game.state.rations == 2, "ate a ration from galley"): return
	if not await walk(Vector3(1.25, 0, -1.3)): return
	await use_target("drink-1")
	if not check(game.state.completed.has("drink") and game.state.drinks == 3, "drank water at dispenser"): return
	if not await central(-2.8): return
	if not await walk(Vector3(1.65, 0, -2.8)): return
	await use_target("wash-1")
	await frames(170)
	if not check(game.state.completed.has("wash") and game.state.drinks == 2, "washed in hab using water supply"): return
	if not await central(-7.7): return
	await use_target("seat-1")
	for i in 8000:
		if game.state.flight == "arrival": break
		await frames(1)
	if not check(game.state.flight == "arrival", "route reaches safe arrival hold"): return
	var target := Vector3(2400, 300, -6800)
	if not check(game.state.position.distance_to(target) > 600 and game.travel_velocity.length() == 0, "arrival holds clear of station without countdown"): return
	await key(KEY_W)
	for i in 1000:
		if game.state.position.distance_to(target) < 245: break
		await frames(1)
	await key(KEY_W, false)
	await press(KEY_L)
	if not check(game.state.flight == "arrival", "docking rejected while too fast"): return
	await frames(170)
	await press(KEY_L)
	if not check(game.state.flight == "docked" and game.state.dock == 1 and game.state.fuel < 72, "manual approach, braking and docking at Tharsis consume fuel"): return
	await press(KEY_F)
	for index in 2:
		if not await central(5.3 + index * 1.65): return
		await aim_use(game._slot_pos("hold", index))
		if not check(not game.state.hand().is_empty(), "lifted job crate for unloading"): return
		if not await central(12.65): return
		var p: Vector3 = game._slot_pos("pad", index)
		if not await walk(Vector3(p.x, 0, 12.65)): return
		await use_target("pad_slot" + str(index))
		if not check(game.state.hand().is_empty(), "unloaded job crate onto destination pallet"): return
	if not await terminal("services", Vector3(0.25, 0, 20.4)): return
	await press(KEY_2)
	if not check(game.state.count_at("hold") == 0 and game.state.completed.has("crew_unload"), "paid crew unloads remaining personal crate"): return
	await press(KEY_ESCAPE)
	if not await terminal("contracts", Vector3(-2.8, 0, 20.8)): return
	await press(KEY_2)
	if not check(game.state.delivered == 1 and game.state.earnings == 520 and game.state.cargo.size() == 1, "full delivery payout reclaims only job crates"): return
	await press(KEY_2)
	if not check(game.state.delivered == 1, "delivery cannot pay twice"): return
	await press(KEY_ESCAPE)
	if not await terminal("trade", Vector3(-2.8, 0, 17.5)): return
	await press(KEY_2)
	if not check(game.state.traded == 1 and game.state.earnings == 675, "sold trade cargo at destination for profit"): return
	await press(KEY_ESCAPE)
	if not await terminal("services", Vector3(0.25, 0, 20.4)): return
	for code in [KEY_3, KEY_4, KEY_5]: await press(code)
	if not check(game.state.fuel == 100 and game.state.pump == 100 and not game.state.patched and game.state.rations == 5, "refueled, bought supplies and paid technician for permanent repair"): return
	await press(KEY_ESCAPE)
	await press(KEY_F5)
	var saved_credits: int = game.state.credits
	if not await terminal("trade", Vector3(-2.8, 0, 17.5)): return
	await press(KEY_1)
	await press(KEY_ESCAPE)
	if not check(game.state.credits == saved_credits - 100, "post-save transaction changed session"): return
	await press(KEY_F9)
	if not check(game.state.credits == saved_credits and game.state.cargo.is_empty() and game.state.dock == 1 and game.state.completed.has("repair"), "save/load restores money, cargo, station and checklist"): return
	if not await terminal("contracts", Vector3(-2.8, 0, 20.8)): return
	await press(KEY_1)
	if not check(game.state.contract.dest == 0 and game.state.cargo.size() == 2, "return contract makes the slice repeatable"): return
	print("SLICE TEST PASS / ", checks, " checks / all routes traversed with movement input")
	game.get_tree().quit(0)
