extends Node3D
## Builds the solar system and switches between on foot, piloting and the trade terminal.
## Run with `-- --selftest` for a headless check of the whole hauling loop,
## or `-- --capture` (with a display) to save screenshots into captures/.

const SKY := """
shader_type sky;
float h(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.11, 0.17, 0.13));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}
void sky() {
	vec3 d = EYEDIR;
	vec3 col = vec3(0.012, 0.010, 0.016);
	float n = 0.5 + 0.5 * sin(d.x * 3.0 + d.y * 5.0) * sin(d.z * 4.0 - d.y * 2.0);
	col += vec3(0.06, 0.028, 0.03) * pow(n, 3.0);
	float s = h(floor(d * 420.0));
	col += vec3(1.0, 0.95, 0.85) * (step(0.9965, s) * 0.7 + step(0.9993, s) * 1.6);
	float sd = max(dot(d, LIGHT0_DIRECTION), 0.0);
	col += vec3(1.0, 0.78, 0.5) * pow(sd, 900.0) * 30.0 + vec3(1.0, 0.6, 0.3) * pow(sd, 10.0) * 0.18;
	COLOR = col;
}
"""

var stations := {}
var ship: Ship
var player: Player
var hud: Hud
var mode := "foot" # foot, pilot, terminal
var bought_once := false


func _ready() -> void:
	_build_environment()
	for id in GameState.STATIONS:
		var st := Station.create(id)
		add_child(st)
		stations[id] = st
		st.terminal_used.connect(_on_terminal)
	_build_backdrop()

	ship = Ship.new()
	ship.build()
	add_child(ship)
	ship.stations.assign(stations.values())
	ship.place_landed(stations["ceres_yard"])
	ship.pilot_seat_used.connect(_on_seat)
	ship.pilot_exit_requested.connect(_leave_seat)

	player = Player.new()
	player.build()
	add_child(player)
	player.spawn_at(Transform3D(ship.global_basis.rotated(Vector3.UP, PI), ship.to_global(Vector3(0, -1.98, 25))))

	hud = Hud.new()
	add_child(hud)
	hud.setup(self)
	hud.terminal.closed.connect(_on_terminal_closed)

	_enter_foot()
	GameState.say("Welcome to Ceres Yard, Kestrel-9. The exchange is through the concourse door behind you.")

	var args := OS.get_cmdline_user_args()
	if "--selftest" in args:
		_selftest.call_deferred()
	elif "--capture" in args:
		_capture.call_deferred()


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SKY
	sm.shader = sh
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("8a7660")
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.05
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-32, -150, 0)
	sun.light_energy = 1.3
	sun.light_color = Color("ffe2b8")
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 500
	add_child(sun)


func _build_backdrop() -> void:
	var gas := ["d9a46a", "b8743f", "ecd2a0", "9c5a33", "e3b98a"]
	Vox.sphere(self, Vector3(-9000, 3500, -26000), 26, 260.0, func(x, y, z):
		if absi(y - 4) < 2 and x > 4 and x < 12 and z > 0:
			return Color("b04a2c")
		var b: int = ((y + 40) >> 2) % 5
		return Color(gas[(b + (1 if Vox.hash3(x, y, z) < 0.2 else 0)) % 5]))
	var mars := ["c4502f", "d9653b", "a8432a", "e98a5a"]
	Vox.sphere(self, Vector3(6500, -1200, -17000), 18, 160.0, func(x, y, z):
		if absi(y) > 15:
			return Color("f3e9e2")
		return Color(mars[int(Vox.hash3(x, y, z) * 4) % 4]))
	# Asteroids around Ceres Yard
	var rocks := StaticBody3D.new()
	rocks.collision_layer = Vox.L_WORLD
	add_child(rocks)
	var r := RandomNumberGenerator.new()
	r.seed = 7
	for i in 46:
		var dir := Vector3(r.randf_range(-1, 1), r.randf_range(-0.4, 0.4), r.randf_range(-1, 1)).normalized()
		var p := dir * r.randf_range(500, 2600)
		if p.z > 0 and absf(p.x) < 300:
			continue
		var s := Vector3.ONE * r.randf_range(12, 45)
		var mi := Vox.box(rocks, p, s, Color(["6e675f", "8a8279", "5b544d"][i % 3]))
		mi.rotation = Vector3(r.randf() * 3, r.randf() * 3, r.randf() * 3)
		Vox.add_shape(rocks, p, s, mi.basis)


# ---------------------------------------------------------------- modes

func _enter_foot() -> void:
	mode = "foot"
	ship.set_piloted(false)
	player.set_active(true)


func _on_seat() -> void:
	if mode != "foot":
		return
	if player.carried:
		GameState.say("Set the crate down in a slot first.")
		return
	mode = "pilot"
	player.set_active(false)
	ship.set_piloted(true)
	if ship.state == Ship.State.LANDED:
		GameState.say("In the seat. Press N / Y for the nav computer, then W / RT to lift off.")


func _leave_seat() -> void:
	ship.set_piloted(false)
	player.spawn_at(Transform3D(ship.global_basis.rotated(ship.global_basis.y, PI), ship.to_global(Vector3(0, 0.35, -2.4))))
	_enter_foot()


func _on_terminal(st: Station, kind: String) -> void:
	if kind == "contracts":
		GameState.say("The contract board is offline in this build. Hauling contracts come next.")
		return
	if ship.landed_at != st:
		GameState.say("Your ship must be landed on pad 07 here to trade.")
		return
	mode = "terminal"
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	hud.terminal.open(st, ship, player)


func _on_terminal_closed() -> void:
	bought_once = true
	mode = "foot"
	player.set_physics_process(true)
	player.set_process_unhandled_input(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if mode == "terminal" or (mode == "pilot" and ship.nav_mode):
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("cancel"):
		_set_paused(true)
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _set_paused(v: bool) -> void:
	get_tree().paused = v
	hud.set_paused(v)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if v else Input.MOUSE_MODE_CAPTURED


func objective() -> String:
	var here: Station = ship.landed_at
	var hold := ship.hold_count()
	if mode == "pilot" and ship.state == Ship.State.LANDED:
		if ship.course_target == null:
			return "Plot a course: press N / Y for the nav computer, press DIR to print a route slip, then key in its grid and press ENT."
		return "Lift off with W / RT (or Space), fly out of the bay and follow the amber marker."
	if mode == "pilot":
		var st := ship.nearest_station()
		var d := ship.global_position.distance_to(st.global_position)
		if d < 5000 and not st.docking_granted:
			return "Request docking at %s with L / X." % st.display_name
		if st.docking_granted and d < 5000:
			return "Fly into the hangar, hover over pad 07 below 14 m/s and press L / X to land."
		if ship.course_target != null:
			return "Follow the amber marker. Cruise with C / L3 once 1.5 km clear of stations."
		return "Plot a course with the nav computer (N / Y)."
	if mode == "foot" and here:
		var on_pallet := 0
		for s in here.pallet_slots:
			if s.occupant:
				on_pallet += 1
		if on_pallet > 0 and hold == 0 and bought_once:
			return "Carry the crates from pallet 07-B into your ship's hold. Aim at a crate and press F / A. Aim at a crate in the hold to stack on it."
		if on_pallet > 0 and hold > 0 and bought_once and here.station_id == "ceres_yard":
			return "Keep loading, or board: walk to the pilot seat at the front of your ship."
		if hold > 0 and here.station_id != "ceres_yard":
			return "Sell at the exchange in the concourse. Hold crates pay a 10% dock-crew fee; carry them to pallet 07-B for full price."
		if on_pallet > 0 and hold == 0 and here.station_id != "ceres_yard":
			return "Sell the crates on pallet 07-B at the exchange in the concourse."
		if hold > 0:
			return "Board your ship and fly your cargo to a station that pays more."
		return "Buy cargo at the commodity exchange in the concourse."
	return ""


# ---------------------------------------------------------------- self test

func _check(ok: bool, what: String) -> bool:
	print(("PASS  " if ok else "FAIL  ") + what)
	return ok


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## Steers the player toward a point with the walk input, like a person holding W.
func _walk_to(target: Vector3, max_frames := 900) -> bool:
	Input.action_press("move_forward")
	var reached := false
	for f in max_frames:
		var d := target - player.global_position
		d.y = 0
		if d.length() < 0.6:
			reached = true
			break
		player.rotation.y = atan2(-d.x, -d.z)
		await get_tree().physics_frame
	Input.action_release("move_forward")
	player.velocity = Vector3.ZERO
	return reached


func _aim_at(p: Vector3) -> void:
	var d := p - player.cam.global_position
	player.rotation.y = atan2(-d.x, -d.z)
	player._pitch = atan2(d.y, Vector2(d.x, d.z).length())
	player.cam.rotation.x = player._pitch
	await _frames(2)


## Points the camera at a world point and presses F, like a player would.
func _aim_use(p: Vector3) -> void:
	await _aim_at(p)
	await _press_key(KEY_F)


## Presses and releases a physical key.
func _press_key(k: Key) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = k
	e.keycode = k
	e.pressed = true
	Input.parse_input_event(e)
	await _frames(2)
	var u := e.duplicate()
	u.pressed = false
	Input.parse_input_event(u)
	await _frames(2)


func _selftest() -> void:
	var ok := true
	var ceres: Station = stations["ceres_yard"]
	var tharsis: Station = stations["tharsis_ring"]
	var start := GameState.credits
	await _frames(30)
	ok = _check(ship.state == Ship.State.LANDED and ship.landed_at == ceres, "ship starts landed at Ceres Yard") and ok
	ok = _check(mode == "foot" and player.is_on_floor(), "player starts on foot, standing on the hangar floor") and ok

	# Walk test: player moves under gravity without falling through.
	var y0 := player.global_position.y
	await _frames(30)
	ok = _check(absf(player.global_position.y - y0) < 0.6, "player stays on the floor") and ok

	# Walk from the pad through the concourse door to the exchange terminal.
	var walked := await _walk_to(ceres.to_global(Vector3(0, 0, -62))) and await _walk_to(ceres.to_global(Vector3(4.6, 0, -68)))
	ok = _check(walked, "walked from the pad through the concourse door to the exchange") and ok

	# Open the exchange by aiming at it and pressing F, then buy 4 ice with the keys.
	await _aim_use(ceres.to_global(Vector3(6.6, 1.2, -68)))
	ok = _check(mode == "terminal" and hud.terminal.visible, "opened the exchange by aiming at it and pressing F") and ok
	while hud.terminal.selected() != "water_ice":
		await _press_key(KEY_DOWN)
	for k in 3:
		await _press_key(KEY_D)
	await _press_key(KEY_F)
	await _press_key(KEY_ESCAPE)
	ok = _check(mode == "foot" and ceres.pallet_count("water_ice") == 4, "bought 4 water ice with F and closed the exchange with Esc") and ok
	ok = _check(GameState.credits < start, "credits went down after buying (%d -> %d)" % [start, GameState.credits]) and ok

	# Carry the first crate by walking: into the back wall (it must not pass
	# through), then up the ramp into the hold, and set it down by aiming.
	player.global_position = ceres.to_global(Vector3(18.8, 0, 2.6))
	player.velocity = Vector3.ZERO
	await _frames(5)
	var first := ceres.pallet_slots[0].occupant
	await _aim_use(ceres.to_global(ceres.pallet_slots[0].position))
	ok = _check(player.carried == first, "lifted a crate off the pallet by aiming at it") and ok
	await _walk_to(ceres.to_global(Vector3(18.8, 0, -60)), 720)
	var crate_z := ceres.to_local(first.global_position).z
	var half := Slot.CRATE_SIZE.z * Player.CARRY_SCALE / 2
	ok = _check(crate_z - half > -49.65, "carried crate stops at the hangar wall instead of passing through (front at z %.2f, wall trim at -49.6)" % (crate_z - half)) and ok
	walked = await _walk_to(ship.to_global(Vector3(0, -2, 28))) and await _walk_to(ship.to_global(Vector3(0, 0.3, 8)))
	var in_hold := ship.to_local(player.global_position)
	ok = _check(walked and absf(in_hold.y - 0.3) < 0.2, "walked up the ramp into the hold carrying a crate (hold floor height %.2f)" % in_hold.y) and ok
	var hs := ship.hold_slots # L1-L4, R1-R4 on the floor; L5-L8, R5-R8 on top
	await _walk_to(ship.to_global(Vector3(0, 0.3, 2.0)))
	await _aim_use(ship.to_global(hs[0].position))
	ok = _check(hs[0].occupant == first, "set the crate down in hold slot L1 by aiming at it") and ok

	# Cockpit furniture is solid: walking at the dash stops short of it.
	await _walk_to(ship.to_global(Vector3(0, 0.3, -2)))
	await _walk_to(ship.to_global(Vector3(3.3, 0.3, -13)), 240)
	var at_dash := ship.to_local(player.global_position)
	ok = _check(at_dash.z > -11.0 and at_dash.z < -10.0 and absf(at_dash.y - 0.3) < 0.2, "walked into the cockpit and stopped at the dash (z %.2f, front at -11.2)" % at_dash.z) and ok

	# Stacking by aim: point at the crate you want to stack on.
	await _fetch_from_pallet(ceres, 1)
	await _aim_use(ship.to_global(hs[0].position))
	ok = _check(hs[8].occupant != null and hs[8].below == hs[0], "aiming at the crate in L1 stacks the new one on top of it (L5)") and ok
	await _fetch_from_pallet(ceres, 2, hs[1].position.z)
	await _aim_use(ship.to_global(hs[9].position))
	ok = _check(hs[1].occupant != null and hs[9].occupant == null, "aiming at an empty top slot drops the crate to the floor below it (L2)") and ok
	await _fetch_from_pallet(ceres, 3, hs[1].position.z)
	await _aim_at(ship.to_global(hs[8].position))
	ok = _check(player.prompt == "That stack is full", "a full stack says so instead of taking the crate") and ok
	await _aim_use(ship.to_global(hs[1].position))
	ok = _check(hs[9].occupant != null and player.carried == null, "aiming at the crate in L2 stacks on it (L6)") and ok
	var top := hs[8].occupant
	await _aim_use(ship.to_global(hs[0].position))
	ok = _check(player.carried == top and hs[0].occupant != null, "aiming at a bottom crate lifts the one on top of it") and ok
	await _aim_use(ship.to_global(hs[0].position))
	ok = _check(hs[8].occupant == top, "and it stacks back on by aiming at the bottom crate") and ok
	ok = _check(ship.hold_count() == 4 and ceres.pallet_count("water_ice") == 0, "4 crates in the hold, 2 stacks of 2") and ok

	# Board by aiming at the seat and pressing F.
	player.global_position = ship.to_global(Vector3(0, 0.3, -5.2))
	await _frames(3)
	await _aim_use(ship.to_global(Vector3(0, 1.3, -7.9)))
	ok = _check(mode == "pilot" and ship.piloted, "boarded by aiming at the pilot seat and pressing F") and ok

	# M jumps to the route printer; Esc goes back to the keypad; N closes it.
	await _press_key(KEY_M)
	ok = _check(ship.dir_mode, "M opens the route printer from the seat") and ok
	await _press_key(KEY_ESCAPE)
	ok = _check(ship.nav_mode and not ship.dir_mode, "Esc goes from the route printer back to the keypad") and ok
	await _press_key(KEY_N)
	ok = _check(not ship.nav_mode, "N closes the nav computer") and ok

	# Plot a course the way a player does: N for the keypad, DIR (Tab) for the
	# route printer, pick Tharsis Ring, print the slip, then key in its grid.
	await _press_key(KEY_N)
	await _press_key(KEY_TAB)
	ok = _check(ship.dir_mode, "DIR on the keypad (Tab) swings over to the route printer") and ok
	while ship.directory.station_ids()[ship.directory.sel] != "tharsis_ring":
		await _press_key(KEY_S)
	await _press_key(KEY_F)
	var waited := 0
	while ship.dir_mode and waited < 300:
		await get_tree().physics_frame
		waited += 1
	var slip := ship.directory.slip
	ok = _check(slip != null and slip.get_parent() == ship.slip_clip and slip.get_meta("station") == "tharsis_ring", "F prints a Tharsis Ring route slip that clips next to the keypad") and ok
	ok = _check(ship.nav_mode and not ship.dir_mode, "after printing, the view returns to the keypad") and ok
	var lines: PackedStringArray = (slip.get_node("Text") as Label3D).text.split("\n")
	for axis in 3:
		var field := lines[2 + axis].split(" ")[1] # e.g. "-068"
		if field.begins_with("-"):
			await _press_key(KEY_MINUS)
		for ch in field.substr(1):
			await _press_key(KEY_0 + int(ch))
	await _press_key(KEY_ENTER)
	ok = _check(ship.course_station == "tharsis_ring", "typed the grid off the slip (%s %s %s) and the course is set to Tharsis Ring" % [lines[2], lines[3], lines[4]]) and ok
	await _press_key(KEY_N)

	# Lift off with the throttle and fly forward with assist.
	var p0 := ship.global_position
	Input.action_press("throttle_up")
	await _frames(90)
	Input.action_release("throttle_up")
	ok = _check(ship.state == Ship.State.FLYING and ship.global_position.distance_to(p0) > 20.0, "throttle lifts the ship off and flies it forward (%.0f m)" % ship.global_position.distance_to(p0)) and ok
	await _frames(120)
	ok = _check(ship.velocity.length() < 5.0, "flight assist brings the ship to a stop on release (%.1f m/s)" % ship.velocity.length()) and ok

	# The nacelles are solid: strafing into the hangar wall stops them at the wall.
	ship.global_transform = ceres.global_transform * Transform3D(Basis(Vector3.UP, PI), Vector3(36, 12, 0))
	ship.velocity = Vector3.ZERO
	Input.action_press("strafe_left")
	await _frames(180)
	Input.action_release("strafe_left")
	var wall_x := ceres.to_local(ship.global_position).x
	ok = _check(wall_x < 41.5, "nacelles stop the ship at the hangar wall (centre x %.2f, limit 41.4)" % wall_x) and ok

	# Cruise the real run: from just outside Ceres Yard to Tharsis Ring.
	var dir := (tharsis.global_position - ceres.global_position).normalized()
	ship.global_position = ceres.global_position + dir * 1600.0
	ship.velocity = Vector3.ZERO
	ship.look_at(tharsis.global_position)
	ship.toggle_cruise()
	await _frames(60)
	ok = _check(ship.cruise, "cruise engages 1.6 km out of Ceres Yard and stays on as you leave") and ok
	var t := 0
	while ship.cruise and t < 60 * 20:
		await get_tree().physics_frame
		t += 1
	await _frames(150)
	var stop_d := ship.global_position.distance_to(tharsis.global_position)
	ok = _check(not ship.cruise and stop_d < 1500 and stop_d > 300, "cruise drops out near Tharsis Ring and slows to a stop %.0f m out" % stop_d) and ok

	# Dock: request, move over the pad, land.
	ship.global_position = tharsis.global_position + Vector3(0, 30, 300)
	ship.velocity = Vector3.ZERO
	ship.request_dock()
	ok = _check(tharsis.docking_granted, "Tharsis Ring grants pad 07") and ok
	ship.global_position = tharsis.to_global(Station.PAD_CENTER + Vector3(2, 12, -3))
	ship.velocity = Vector3.ZERO
	ship.request_dock()
	await _frames(200)
	ok = _check(ship.state == Ship.State.LANDED and ship.landed_at == tharsis, "landing assist sets down on Tharsis pad 07") and ok
	ok = _check(ship.hold_count() == 4, "cargo is still in the hold after the flight") and ok

	# Leave the seat with F, then unload by hand: one crate walked down the ramp to
	# the pallet, one stacked on it, one carried to the exchange, one left aboard.
	await _press_key(KEY_F)
	await _frames(10)
	ok = _check(mode == "foot" and player.global_position.distance_to(ship.global_position) < 12.0, "F leaves the seat; standing inside the ship") and ok
	var tp := tharsis.pallet_slots
	await _aim_use(ship.to_global(hs[0].position))
	ok = _check(player.carried != null and hs[8].occupant == null, "lifted the top crate of the L1 stack") and ok
	walked = await _walk_to(ship.to_global(Vector3(0, 0.3, 14))) and await _walk_to(ship.to_global(Vector3(0, -2, 26)))
	walked = walked and await _walk_to(tharsis.to_global(Vector3(14, 0, -20))) and await _walk_to(tharsis.to_global(Vector3(18.2, 0, 0)))
	await _aim_use(tharsis.to_global(tp[0].position))
	ok = _check(walked and tp[0].occupant != null, "walked it down the ramp and set it on Tharsis pallet slot P1") and ok
	player.global_position = ship.to_global(Vector3(1.4, 0.3, 0.6))
	await _frames(3)
	await _aim_use(ship.to_global(hs[0].position))
	player.global_position = tharsis.to_global(Vector3(18.2, 0, 0))
	await _frames(3)
	await _aim_use(tharsis.to_global(tp[0].position))
	ok = _check(tp[9].occupant != null and tp[9].below == tp[0], "stacked a second crate on the pallet by aiming at the first (P10)") and ok
	player.global_position = ship.to_global(Vector3(1.4, 0.3, hs[1].position.z))
	await _frames(3)
	await _aim_use(ship.to_global(hs[1].position))
	ok = _check(player.carried != null and hs[1].occupant != null and hs[9].occupant == null, "lifted the top crate of the L2 stack") and ok
	walked = await _walk_to(ship.to_global(Vector3(0, 0.3, 14))) and await _walk_to(ship.to_global(Vector3(0, -2, 26)))
	# (Stops a step short: the crate in your arms bumps the terminal before you do.)
	walked = walked and await _walk_to(tharsis.to_global(Vector3(0, 0, -62))) and await _walk_to(tharsis.to_global(Vector3(3.4, 0, -68)))
	ok = _check(walked and player.carried != null, "carried a crate from the hold to the Tharsis exchange") and ok

	# Sell: aiming at the exchange with a crate in hand opens it, and R sells the
	# ice in your hands and on the pallet at full price, and the hold for a fee.
	var before := GameState.credits
	await _aim_use(tharsis.to_global(Vector3(6.6, 1.2, -68)))
	ok = _check(mode == "terminal" and hud.terminal.selected() == "water_ice", "the exchange opens with a crate in hand and picks the ice you brought") and ok
	var q := hud.terminal.quote_all("water_ice")
	await _press_key(KEY_R)
	var earned := GameState.credits - before
	ok = _check(earned == q["total"] and q["fee"] > 0 and earned > 0, "R sold all 4 ice for %d cr (dock crew fee %d on the 1 in the hold)" % [earned, q["fee"]]) and ok
	ok = _check(ship.hold_count() == 0 and tharsis.pallet_count("water_ice") == 0 and player.carried == null, "hand, pallet and hold are all empty after the sale") and ok
	await _press_key(KEY_ESCAPE)
	ok = _check(GameState.credits > start, "profit on the run: %d -> %d cr" % [start, GameState.credits]) and ok

	print("SELFTEST " + ("OK" if ok else "FAILED"))
	get_tree().quit(0 if ok else 1)


## Teleports beside Ceres pallet 07-B, lifts the crate in pallet slot i by aiming
## at it, and steps into the hold aisle level with an L column (by its z).
func _fetch_from_pallet(st: Station, i: int, column_z := 0.6) -> void:
	# Stand in front of that slot: beside the pallet for the near column, else in front of its row.
	var p := st.pallet_slots[i].position
	player.global_position = st.to_global(Vector3(p.x - 2.6, 0, p.z) if p.x < 22.0 else Vector3(p.x, 0, p.z - 2.6))
	await _frames(3)
	await _aim_use(st.to_global(st.pallet_slots[i].position))
	player.global_position = ship.to_global(Vector3(1.4, 0.3, column_z))
	await _frames(3)


# ---------------------------------------------------------------- screenshots

func _shot(name: String) -> void:
	await _frames(6)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://captures"))
	img.save_png("res://captures/%s.png" % name)
	print("saved ", name)


func _look_from(pos: Vector3, at: Vector3) -> void:
	player.global_position = pos
	var d := at - (pos + Vector3(0, 1.62, 0))
	player.rotation = Vector3(0, atan2(-d.x, -d.z), 0)
	player._pitch = atan2(d.y, Vector2(d.x, d.z).length())
	player.cam.rotation.x = player._pitch


func _capture() -> void:
	var ceres: Station = stations["ceres_yard"]
	var tharsis: Station = stations["tharsis_ring"]
	player.set_physics_process(false)
	await _frames(10)
	_look_from(ceres.to_global(Vector3(-22, 0, 34)), ship.to_global(Vector3(0, 2, 2)))
	await _shot("01_hangar")
	_look_from(ship.to_global(Vector3(4, -2, 31)), ship.to_global(Vector3(0, 0.5, 10)))
	await _shot("09_ramp")
	_look_from(ceres.to_global(Vector3(3, 0, -32)), ceres.to_global(Vector3(0, 2.5, -55)))
	await _shot("10_concourse_door")
	_look_from(ceres.to_global(Vector3(-2, 0, -62)), ceres.to_global(Vector3(6.6, 1.4, -68)))
	player._update_aim()
	await _shot("02_concourse")
	_on_terminal(ceres, "trade")
	hud.terminal.sel = 0
	hud.terminal.qty = 4
	hud.terminal.buy_selected()
	await _shot("03_exchange")
	hud.terminal.close()
	player.set_physics_process(false)
	var crates: Array[Crate] = []
	for s in ceres.pallet_slots:
		if s.occupant:
			crates.append(s.occupant)
	for k in 3:
		player.pick_up(crates[k])
		player.place(ship.hold_slots[k])
	player.pick_up(crates[3])
	# Stacking: aim at the crate in L1 and the ghost shows the slot on top of it.
	_look_from(ship.to_global(Vector3(-0.2, 0.3, 2.6)), ship.to_global(ship.hold_slots[0].position + Vector3(0, 0.3, 0)))
	await _frames(2)
	player._update_aim()
	await _shot("04_loading")
	player.place(Player.stack_target(ship.hold_slots[0].occupant))
	_on_seat()
	await _shot("05_cockpit")
	ship.enter_directory()
	await get_tree().create_timer(0.5).timeout
	while ship.directory.station_ids()[ship.directory.sel] != "tharsis_ring":
		ship.directory.press("DOWN")
	ship.directory.press("PRINT")
	await get_tree().create_timer(0.62).timeout
	await _shot("11_route_printer")
	while ship.dir_mode:
		await get_tree().process_frame
	for k in ["0", "2", "4", "0", "0", "3", "+/-", "0", "6"]:
		ship.nav.press(k)
	await get_tree().create_timer(0.5).timeout
	await _shot("06_nav_computer")
	ship.nav.press("8")
	ship.nav.press("ENT")
	ship.exit_nav()
	ship.take_off()
	ship.global_position = ceres.global_position + Vector3(300, 200, 2600)
	ship.look_at(tharsis.global_position + Vector3(600, 400, 0))
	await get_tree().create_timer(0.6).timeout
	await _shot("07_flight")
	tharsis.docking_granted = true
	ship.global_position = tharsis.to_global(Vector3(10, 30, 420))
	ship.look_at(tharsis.to_global(Vector3(0, 14, 0)))
	await _shot("08_approach")
	# Selling at Tharsis straight from the docked hold
	ship.place_landed(tharsis)
	_leave_seat()
	player.set_physics_process(false)
	_on_terminal(tharsis, "trade")
	await _shot("12_exchange_sell")
	get_tree().quit()
