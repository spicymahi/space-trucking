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
	hud.terminal.open(st)


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
			return "Plot a course: press N / Y, press DIR to look up a station, key in its grid and press ENT."
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
			return "Carry the crates from pallet 07-B into your ship's hold. Aim at a crate and press F / A."
		if on_pallet > 0 and hold > 0 and bought_once and here.station_id == "ceres_yard":
			return "Keep loading, or board: walk to the pilot seat at the front of your ship."
		if hold > 0 and here.station_id != "ceres_yard":
			return "Unload your crates onto pallet 07-B, then sell them at the exchange."
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

	# Buy 4 crates of water ice.
	_on_terminal(ceres, "trade")
	hud.terminal.sel = GameState.COMMODITY_ORDER.find("water_ice")
	hud.terminal.qty = 4
	var n := hud.terminal.buy_selected()
	hud.terminal.close()
	ok = _check(n == 4 and ceres.pallet_count("water_ice") == 4, "bought 4 water ice crates onto pallet 07-B") and ok
	ok = _check(GameState.credits < start, "credits went down after buying (%d -> %d)" % [start, GameState.credits]) and ok

	# Load them into the hold.
	var crates: Array[Crate] = []
	for s in ceres.pallet_slots:
		if s.occupant:
			crates.append(s.occupant)
	for i in crates.size():
		player.pick_up(crates[i])
		player.place(ship.hold_slots[i])
	await _frames(2)
	ok = _check(ship.hold_count() == 4 and ceres.pallet_count("water_ice") == 0, "moved 4 crates from the pallet into the hold") and ok
	ok = _check(ship.hold_slots[0].occupant.get_parent() == ship, "hold crates are attached to the ship") and ok

	# Board and plot a course to Tharsis Ring on the keypad: X +024, Y +003, Z -068.
	_on_seat()
	ok = _check(mode == "pilot" and ship.piloted, "boarded the pilot seat") and ok
	ship.enter_nav()
	for k in ["0", "2", "4", "0", "0", "3", "+/-", "0", "6", "8", "ENT"]:
		ship.nav.press(k)
	ship.exit_nav()
	ok = _check(ship.course_station == "tharsis_ring", "nav computer course set to Tharsis Ring from typed grid") and ok

	# Lift off and fly forward with assist.
	ship.take_off()
	var p0 := ship.global_position
	Input.action_press("throttle_up")
	await _frames(90)
	Input.action_release("throttle_up")
	ok = _check(ship.state == Ship.State.FLYING and ship.global_position.distance_to(p0) > 20.0, "ship lifts off and flies forward (%.0f m)" % ship.global_position.distance_to(p0)) and ok
	await _frames(120)
	ok = _check(ship.velocity.length() < 5.0, "flight assist brings the ship to a stop on release (%.1f m/s)" % ship.velocity.length()) and ok

	# Cruise in open space, then check it drops near the destination.
	ship.global_position = tharsis.global_position + (tharsis.global_position - ceres.global_position).normalized() * 6000.0
	ship.look_at(tharsis.global_position)
	ship.toggle_cruise()
	ok = _check(ship.cruise, "cruise engages in open space") and ok
	await _frames(60 * 14)
	var stop_d := ship.global_position.distance_to(tharsis.global_position)
	ok = _check(not ship.cruise and stop_d < 3000 and stop_d > 800, "cruise drops out and slows before reaching Tharsis Ring (%.0f m out)" % stop_d) and ok

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

	# Leave the seat, unload to the pallet, sell.
	_leave_seat()
	await _frames(10)
	ok = _check(mode == "foot" and player.global_position.distance_to(ship.global_position) < 12.0, "left the seat and stand inside the ship") and ok
	var free := tharsis.free_pallet_slots()
	var i := 0
	for s in ship.hold_slots:
		if s.occupant:
			player.pick_up(s.occupant)
			player.place(free[i])
			i += 1
	ok = _check(tharsis.pallet_count("water_ice") == 4 and ship.hold_count() == 0, "unloaded 4 crates onto Tharsis pallet 07-B") and ok
	var before := GameState.credits
	_on_terminal(tharsis, "trade")
	hud.terminal.sel = GameState.COMMODITY_ORDER.find("water_ice")
	var earned := hud.terminal.sell_selected()
	hud.terminal.close()
	ok = _check(earned > 0 and GameState.credits == before + earned, "sold the ice for %d cr" % earned) and ok
	ok = _check(GameState.credits > start, "profit on the run: %d -> %d cr" % [start, GameState.credits]) and ok

	print("SELFTEST " + ("OK" if ok else "FAILED"))
	get_tree().quit(0 if ok else 1)


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
	_look_from(ship.to_global(Vector3(0, 0.35, 12.5)), ship.to_global(ship.hold_slots[3].position))
	player._update_aim()
	await _shot("04_loading")
	player.place(ship.hold_slots[3])
	_on_seat()
	await _shot("05_cockpit")
	ship.enter_nav()
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
	get_tree().quit()
