extends "res://scripts/hab_preview.gd"
## Two-station gameplay slice. The hab remains in a stable local reference frame;
## the exterior moves relative to it, so walking aboard during transit is reliable.

const StateModel = preload("res://scripts/slice_state.gd")
var state = StateModel.new()
var piloting := false
var paused := false
var menu := ""
var toast_time := 0.0
var toast_text := ""
var travel_velocity := Vector3.ZERO
var flight_basis := Basis(Vector3.UP, PI)
var space: Node3D
var station_room: Node3D
var station_art := false
var station_labels: Array[Label3D] = []
var gate: StaticBody3D
var gate_mesh: MeshInstance3D
var targets: Dictionary = {}
var cargo_root: Node3D
var held_visual: Node3D
var selected_target: Node3D
var panel: PanelContainer
var panel_body: VBoxContainer
var menu_actions: Dictionary = {}
var ui_root: Control
var status_label: Label
var goal_label: Label
var prompt_label: Label
var toast_label: Label
var hints_label: Label
var reticle: Label
var marker: Label
var screens: Array[Label3D] = []
var nav_fields: Array[LineEdit] = []
var selected_route := 1
var repair_isolated := false
var repair_rotations := [0, 1, 0]
var repair_labels: Array[Button] = []
var repair_status: Label
var room_timer := 0.0
var _auto_saved := false
var _welcome := true
var test_mode := false
var wash_time := 0.0
var sound: AudioStreamPlayer
var sound_playback: AudioStreamGeneratorPlayback
var tone_remaining := 0.0
var tone_phase := 0.0
var test_runner: RefCounted


func _ready() -> void:
	test_mode = "--slice-test" in OS.get_cmdline_user_args()
	connected_layout = true
	GameState.turnover_enabled = false
	DisplayServer.window_set_title("Kestrel — A Quiet Delivery")
	_build_environment()
	hull = StaticBody3D.new()
	hull.name = "ShipInterior"
	add_child(hull)
	_shell()
	_panel_details()
	_window()
	_bed()
	_galley()
	_bulkhead()
	_personal_objects()
	_lighting()
	_build_cockpit()
	_build_hold()
	_build_station()
	_build_space()
	_controller()
	camera.far = 30000
	_register_hab_actions()
	_build_slice_ui()
	_build_sound()
	_rebuild_cargo()
	_sync_world()
	_open_menu("welcome")
	if test_mode:
		test_runner = load("res://scripts/slice_test.gd").new()
		test_runner.run.call_deferred(self)
	if "--slice-capture" in OS.get_cmdline_user_args():
		_capture_slice.call_deferred()


func _box(pos: Vector3, size: Vector3, color: Color, solid := false, glow := false) -> MeshInstance3D:
	var mesh := super._box(pos, size, color, solid, glow)
	if station_art:
		mesh.reparent(station_room, false)
	return mesh


func _text(value: String, pos: Vector3, size := 0.0025, color := DARK, yaw := 0.0) -> Label3D:
	var label := super._text(value, pos, size, color, yaw)
	if station_art:
		label.reparent(station_room, false)
	return label


func _bulkhead() -> void:
	for x in [-2.02, 2.02]:
		_box(Vector3(x, 1.6, -4.05), Vector3(2.16, 3.2, 0.2), CREAM, true)
	_box(Vector3(0, 2.94, -4.05), Vector3(1.9, 0.52, 0.2), CREAM, true)
	for x in [-0.98, 0.98]:
		_box(Vector3(x, 1.34, -3.86), Vector3(0.17, 2.68, 0.23), ORANGE, true)
	_box(Vector3(0, 2.64, -3.86), Vector3(2.13, 0.18, 0.23), ORANGE, true)
	_text("FLIGHT DECK / ENGINEERING", Vector3(0, 2.91, -3.9), 0.0017, LIGHT)
	_box(Vector3(0.8, -0.12, -5.55), Vector3(3.8, 0.24, 3.2), FLOOR, true)
	_box(Vector3(0.8, 3, -5.55), Vector3(3.8, 0.2, 3.2), SHADOW, true)
	_box(Vector3(-1.1, 1.5, -5.55), Vector3(0.18, 3, 3.2), CREAM, true)
	_box(Vector3(2.8, 1.5, -5.55), Vector3(0.18, 3, 3.2), SHADOW, true)
	for z in [-4.13, -7.02]:
		_box(Vector3(1.86, 1.5, z), Vector3(1.8, 3, 0.14), SHADOW, true)
	_box(Vector3(2.3, 0.57, -5.35), Vector3(0.68, 1.14, 1.1), DARK, true)
	_box(Vector3(2.3, 1.6, -5.35), Vector3(0.55, 0.85, 1.1), CREAM, true)
	_box(Vector3(2.009, 1.64, -5.35), Vector3(0.025, 0.65, 0.9), Color("082b1d"), false, true)
	screens.append(_text("ENGINEERING\nCOOLANT 58%\nDRIVE   89%", Vector3(1.99, 1.64, -5.35), 0.0019, Color("8cff9e"), -PI / 2))
	_usebox("engineering", "Engineering diagnostics", Vector3(1.96, 1.6, -5.35), Vector3(0.06, 0.75, 0.95))
	_box(Vector3(2.23, 0.76, -6.5), Vector3(0.83, 1.5, 0.66), Color("697566"), true)
	_box(Vector3(1.797, 0.95, -6.5), Vector3(0.07, 0.52, 0.49), ORANGE)
	_text("COOLANT\nP-01", Vector3(1.75, 1.15, -6.5), 0.0015, LIGHT, -PI / 2)
	_usebox("repair", "Open coolant pump P-01", Vector3(1.73, 0.92, -6.5), Vector3(0.1, 0.85, 0.59))
	for y in [0.3, 0.48, 0.66]:
		_box(Vector3(1.78, y, -6.5), Vector3(0.07, 0.035, 0.41), DARK)
	_lamp(Vector3(0.5, 2.6, -5.4), 0.8, 4, Color("dfdfbd"))
	# Washroom remains a compact functional interaction rather than another room.
	_box(Vector3(2, 1.36, -3.87), Vector3(1.36, 2.72, 0.22), SHADOW, true)
	_box(Vector3(2, 1.37, -3.73), Vector3(1.16, 2.47, 0.055), LIGHT)
	_box(Vector3(2, 0.52, -3.69), Vector3(1.13, 0.21, 0.022), ORANGE)
	_text("WASH\n01", Vector3(2, 1.85, -3.69), 0.004, SHADOW)
	_usebox("wash", "Wash up · 1 water", Vector3(2, 1.36, -3.64), Vector3(1.08, 2.35, 0.06))


func _build_cockpit() -> void:
	_box(Vector3(0, -0.12, -9.2), Vector3(5.8, 0.24, 4.4), FLOOR, true)
	_box(Vector3(0, 3.3, -9.2), Vector3(5.8, 0.25, 4.4), SHADOW, true)
	for x in [-2.9, 2.9]:
		_box(Vector3(x, 1.6, -9.2), Vector3(0.18, 3.2, 4.4), CREAM, true)
	for x in [-1.98, 1.98]:
		_box(Vector3(x, 1.5, -7.05), Vector3(1.87, 3, 0.16), CREAM, true)
	_box(Vector3(0, 0.42, -11.4), Vector3(5.8, 0.84, 0.18), SHADOW, true)
	_box(Vector3(0, 3, -11.4), Vector3(5.8, 0.5, 0.18), SHADOW, true)
	var glass := _box(Vector3(0, 1.79, -11.43), Vector3(5.2, 1.9, 0.025), Color("62828b"), true)
	var glass_material := StandardMaterial3D.new()
	glass_material.albedo_color = Color(0.25, 0.4, 0.43, 0.045)
	glass_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glass.material_override = glass_material
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for x in [-2.73, 2.73]:
		_box(Vector3(x, 1.86, -11.4), Vector3(0.28, 2.7, 0.24), ORANGE, true)
	_box(Vector3(0, 1.0, -10.62), Vector3(5.4, 0.22, 1.12), SHADOW, true)
	for x in [-1.22, 1.22]:
		_box(Vector3(x, 1.43, -10.72), Vector3(1.58, 0.81, 0.38), CREAM, true)
		_box(Vector3(x, 1.47, -10.515), Vector3(1.35, 0.57, 0.025), Color("082b1d") if x < 0 else Color("302408"), false, true)
	screens.append(_text("NAV / STANDBY", Vector3(-1.22, 1.48, -10.486), 0.0021, Color("8cff9e")))
	screens.append(_text("FUEL 72\nDOCKED", Vector3(1.22, 1.48, -10.486), 0.0021, Color("ffd48a")))
	for i in 12:
		_box(Vector3(-0.3 + (i % 3) * 0.21, 1.155, -10.34 + floori(i / 3.0) * 0.14), Vector3(0.17, 0.09, 0.11), LIGHT)
	_box(Vector3(0, 0.46, -9.0), Vector3(0.68, 0.82, 0.68), SHADOW, true)
	_box(Vector3(0, 0.94, -9.0), Vector3(0.84, 0.2, 0.84), GOLD, true)
	_box(Vector3(0, 1.39, -8.65), Vector3(0.84, 0.83, 0.18), GOLD, true)
	_usebox("seat", "Take the pilot seat", Vector3(0, 1.4, -8.5), Vector3(0.9, 0.9, 0.13))
	_text("KESTREL-9", Vector3(0, 2.98, -11.285), 0.003, LIGHT)
	_lamp(Vector3(0, 2.75, -8.3), 0.85, 4.3, Color("ffe0a9"))
	_box(Vector3(0, 3.06, -8.5), Vector3(1.2, 0.12, 0.6), Color("ffdb97"), false, true)


func _build_hold() -> void:
	_box(Vector3(0, -0.12, 7.8), Vector3(6.2, 0.24, 7.5), FLOOR, true)
	_box(Vector3(0, 3.2, 7.8), Vector3(6.2, 0.24, 7.5), SHADOW, true)
	for x in [-3.1, 3.1]:
		_box(Vector3(x, 1.6, 7.8), Vector3(0.2, 3.2, 7.5), CREAM, true)
		_box(Vector3(x * 0.97, 2.4, 7.8), Vector3(0.08, 0.18, 7.3), ORANGE)
	for x in [-0.99, 0.99]:
		_box(Vector3(x, 1.3, 4.27), Vector3(0.12, 2.6, 0.15), ORANGE, true)
	_text("HAB / FLIGHT DECK", Vector3(0, 2.9, 4.28), 0.002, LIGHT, PI)
	for i in 8:
		var p := _slot_pos("hold", i)
		_box(p + Vector3(0, -0.66, 0), Vector3(1.32, 0.025, 1.35), GOLD)
		_box(p + Vector3(0, -0.64, 0), Vector3(1.19, 0.015, 1.22), DARK)
		_usebox("slot", "Secure cargo · hold %d" % (i + 1), p, Vector3(1.18, 1.22, 1.18), i)
	for z in [5.5, 8.4, 10.8]:
		_box(Vector3(0, 3.035, z), Vector3(1.3, 0.08, 0.42), Color("ffe3aa"), false, true)
		_lamp(Vector3(0, 2.7, z), 0.7, 3.7, Color("ffe1b8"))
	_box(Vector3(0, 0.02, 11.8), Vector3(3.3, 0.04, 1.4), SHADOW, true)
	for x in [-1.55, 1.55]:
		_box(Vector3(x, 0.048, 11.8), Vector3(0.13, 0.017, 1.4), GOLD)
	gate = StaticBody3D.new()
	add_child(gate)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6, 3.1, 0.17)
	shape.shape = box
	shape.position = Vector3(0, 1.55, 11.5)
	gate.add_child(shape)
	gate_mesh = _box(Vector3(0, 1.55, 11.5), box.size, SHADOW)
	_usebox("airlock", "Outer hatch · closed in flight", Vector3(0, 1.5, 11.39), Vector3(2.4, 2.5, 0.04))
	cargo_root = Node3D.new()
	add_child(cargo_root)


func _build_station() -> void:
	station_room = Node3D.new()
	station_room.name = "Dockside"
	add_child(station_room)
	station_art = true
	_box(Vector3(0, -0.12, 17.5), Vector3(13, 0.24, 12), FLOOR, true)
	_box(Vector3(0, 4.15, 17.5), Vector3(13, 0.3, 12), SHADOW, true)
	for x in [-6.5, 6.5]:
		_box(Vector3(x, 2, 17.5), Vector3(0.2, 4, 12), CREAM, true)
	_box(Vector3(0, 2, 23.5), Vector3(13, 4, 0.2), CREAM, true)
	for x in [-4.8, 4.8]:
		_box(Vector3(x, 2, 11.5), Vector3(3.4, 4, 0.2), CREAM, true)
	for x in [-3.35, 3.35]:
		_box(Vector3(x, 1.6, 11.6), Vector3(0.22, 3.2, 0.22), ORANGE, true)
	station_labels.append(_text("CERES YARD", Vector3(0, 3.2, 23.37), 0.011, DARK, PI))
	_text("PAD 07 / KESTREL", Vector3(0, 3.4, 11.68), 0.006, DARK)
	for z in [14.2, 18.4, 22]:
		_box(Vector3(0, 3.93, z), Vector3(3.5, 0.08, 0.7), Color("ffe9bd"), false, true)
		_lamp(Vector3(0, 3.5, z), 1.1, 6.5, Color("ffe1b1"))
	for i in 8:
		var p := _slot_pos("pad", i)
		_box(p + Vector3(0, -0.64, 0), Vector3(1.27, 0.06, 1.27), GOLD)
		_usebox("pad_slot", "Set cargo on station pallet %d" % (i + 1), p, Vector3(1.12, 1.2, 1.12), i)
	_terminal("contracts", "CONTRACTS", Vector3(-4.8, 0, 20.8), Color("e6a34f"), PI / 2)
	_terminal("trade", "EXCHANGE", Vector3(-4.8, 0, 17.5), Color("80cb96"), PI / 2)
	_terminal("services", "DOCK SERVICES", Vector3(0, 0, 22.5), Color("93bbbe"), PI)
	station_art = false


func _terminal(action: String, title: String, pos: Vector3, color: Color, yaw: float) -> void:
	_box(pos + Vector3(0, 0.7, 0), Vector3(1.1, 1.4, 1.1), SHADOW, true)
	_box(pos + Vector3(0, 1.66, 0), Vector3(1.3, 0.86, 1.3), CREAM, true)
	var facing := Basis(Vector3.UP, yaw) * Vector3(0, 0, 1)
	var surface := pos + Vector3(0, 1.68, 0) + facing * 0.668
	var screen := _box(surface, Vector3(1.06, 0.6, 0.022), color.darkened(0.82), false, true)
	screen.rotation.y = yaw
	_text(title + "\n[F] CONNECT", surface + facing * 0.018, 0.0024, color, yaw)
	_usebox(action, title.capitalize(), surface + facing * 0.04, Vector3(1.1, 0.78, 0.06), -1, yaw)


func _visual(parent: Node3D, pos: Vector3, size: Vector3, color: Color, emissive := false) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = pos
	mesh.material_override = _material(color, emissive)
	parent.add_child(mesh)
	return mesh


func _build_space() -> void:
	space = Node3D.new()
	space.name = "ExteriorReferenceFrame"
	add_child(space)
	for i in 2:
		var station := Node3D.new()
		space.add_child(station)
		station.position = Vector3(StateModel.GRIDS[i]) * 100
		var accent := ORANGE if i == 0 else Color("447f7e")
		_visual(station, Vector3(0, -35, -30), Vector3(140, 15, 140), CREAM)
		_visual(station, Vector3(0, 40, -30), Vector3(140, 15, 140), CREAM)
		for x in [-64, 64]:
			_visual(station, Vector3(x, 0, -30), Vector3(12, 80, 140), SHADOW)
			_visual(station, Vector3(x, 0, 42), Vector3(10, 66, 4), accent, true)
			_visual(station, Vector3(x * 1.9, 0, -55), Vector3(110, 4, 60), Color("354f69"))
		_visual(station, Vector3(0, 0, -93), Vector3(140, 80, 12), DARK)
		_visual(station, Vector3(0, 70, -40), Vector3(24, 55, 26), SHADOW)
		for x in range(-40, 41, 20):
			_visual(station, Vector3(x, -26, 35), Vector3(4, 2, 6), Color("b7d68a"), true)
	# Distant stars, centered on the player so travel never leaves the star field.
	var stars := Node3D.new()
	stars.name = "Stars"
	add_child(stars)
	var rng := RandomNumberGenerator.new()
	rng.seed = 83
	for i in 280:
		var p := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized() * 18000
		_visual(stars, p, Vector3.ONE * rng.randf_range(3, 9), Color("acb9c8"), true)


func _register_hab_actions() -> void:
	_usebox("eat", "Prepare a meal · 1 ration", Vector3(2.36, 2.23, -0.7), Vector3(0.09, 0.68, 1.3))
	_usebox("drink", "Drink water · 1 water", Vector3(2.27, 1.45, -1.3), Vector3(0.06, 0.65, 0.55))
	_usebox("rest", "Sit on your bunk", Vector3(-1.39, 1.03, -0.5), Vector3(0.08, 0.26, 2.2))


func _usebox(action: String, label: String, pos: Vector3, size: Vector3, id := -1, yaw := 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 64
	body.collision_mask = 0
	body.position = pos
	body.rotation.y = yaw
	body.set_meta("action", action)
	body.set_meta("label", label)
	body.set_meta("id", id)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	add_child(body)
	targets[action + str(id)] = body
	return body


func _slot_pos(location: String, slot: int) -> Vector3:
	if location == "hold":
		return Vector3(-2.05 if slot < 4 else 2.05, 0.68, 5.3 + (slot % 4) * 1.65)
	return Vector3(3.4 + (slot % 2) * 1.5, 0.68, 14.4 + floori(slot / 2.0) * 1.6)


func _crate_visual(parent: Node3D, good: String, job: bool) -> void:
	var col := Color("90b6ba") if good == "ICE" else Color("869565")
	_visual(parent, Vector3.ZERO, Vector3(1.04, 1.16, 1.04), col)
	_visual(parent, Vector3.ZERO, Vector3(1.055, 0.16, 1.055), DARK)
	for x in [-0.4, 0.4]:
		_visual(parent, Vector3(x, 0, 0), Vector3(0.08, 1.175, 1.07), GOLD if job else ORANGE)
	for z in [-0.531, 0.531]:
		var label := Label3D.new()
		label.text = ("JOB\n" if job else "") + good
		label.font = font
		label.font_size = 64
		label.pixel_size = 0.0038
		label.modulate = LIGHT
		label.outline_size = 0
		label.position = Vector3(0, 0.24, z)
		label.rotation.y = PI if z < 0 else 0.0
		parent.add_child(label)


func _rebuild_cargo() -> void:
	for child in cargo_root.get_children():
		child.free()
	if is_instance_valid(held_visual):
		held_visual.free()
	for c in state.cargo:
		if c.location == "hand":
			held_visual = Node3D.new()
			camera.add_child(held_visual)
			held_visual.position = Vector3(0.36, -0.35, -0.68)
			held_visual.scale = Vector3.ONE * 0.28
			_crate_visual(held_visual, c.good, c.job)
			continue
		if c.location != "hold" and (state.flight != "docked" or c.location != "pad_%d" % state.dock): continue
		var crate := StaticBody3D.new()
		crate.position = _slot_pos("hold" if c.location == "hold" else "pad", int(c.slot))
		crate.collision_layer = 65
		crate.collision_mask = 0
		crate.set_meta("action", "crate")
		crate.set_meta("id", int(c.id))
		crate.set_meta("label", "Lift %s%s" % ["job " if c.job else "", c.good])
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.075, 1.18, 1.075)
		shape.shape = box
		crate.add_child(shape)
		cargo_root.add_child(crate)
		_crate_visual(crate, c.good, c.job)
	# Empty slot targets don't obstruct the ray to crates occupying them.
	for i in 8:
		for location in ["hold", "pad"]:
			var action := "slot" if location == "hold" else "pad_slot"
			var where: String = "hold" if location == "hold" else "pad_%d" % state.dock
			var occupied: bool = state.cargo.any(func(c): return c.location == where and c.slot == i)
			targets[action + str(i)].collision_layer = 0 if occupied or (location == "pad" and state.flight != "docked") else 64


func _build_sound() -> void:
	sound = AudioStreamPlayer.new()
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = 22050
	stream.buffer_length = 0.1
	sound.stream = stream
	sound.volume_db = -26
	add_child(sound)
	if not test_mode:
		sound.play()
		sound_playback = sound.get_stream_playback()


func _audio(delta: float) -> void:
	if sound_playback == null: return
	tone_remaining = maxf(0, tone_remaining - delta)
	var count := sound_playback.get_frames_available()
	for i in count:
		tone_phase += TAU * (520 if tone_remaining > 0 else 52) / 22050.0
		var value := sin(tone_phase) * (0.11 if tone_remaining > 0 else (0.012 if state.flight == "transit" else 0.004))
		sound_playback.push_frame(Vector2.ONE * value)


func _hud_label(pos: Vector2, size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = pos
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color("101713"))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	ui_root.add_child(label)
	return label


func _build_slice_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui_root = Control.new()
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui_root)
	status_label = _hud_label(Vector2(24, 18), 24, Color("f1ddb5"))
	goal_label = _hud_label(Vector2(24, 80), 23, Color("e9e2cf"))
	goal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	goal_label.size.x = 680
	prompt_label = _hud_label(Vector2.ZERO, 26, Color("fff0bc"))
	toast_label = _hud_label(Vector2.ZERO, 23, Color("d4efcd"))
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hints_label = _hud_label(Vector2.ZERO, 21, Color("d8d0b7"))
	reticle = _hud_label(Vector2.ZERO, 20, Color("fff0bc"))
	reticle.text = "·"
	marker = _hud_label(Vector2.ZERO, 24, Color("ffce75"))
	marker.text = "+"
	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -450
	panel.offset_top = -335
	panel.offset_right = 450
	panel.offset_bottom = 335
	var style := StyleBoxFlat.new()
	style.bg_color = Color("18211e")
	style.border_color = CREAM
	style.set_border_width_all(7)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	ui_root.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	panel_body = VBoxContainer.new()
	panel_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_body.add_theme_constant_override("separation", 12)
	scroll.add_child(panel_body)
	panel.visible = false


func _paragraph(value: String, size := 24, color := Color("dacdb2")) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_body.add_child(label)
	return label


func _button(label: String, callback: Callable, shortcut := 0) -> Button:
	var button := Button.new()
	button.text = ("[%d] " % shortcut if shortcut else "") + label
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size.y = 43
	button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", 25)
	button.add_theme_color_override("font_color", Color("ecdfbb"))
	button.pressed.connect(callback)
	panel_body.add_child(button)
	if shortcut: menu_actions[KEY_0 + shortcut] = callback
	return button


func _clear_panel() -> void:
	for child in panel_body.get_children():
		panel_body.remove_child(child)
		child.queue_free()
	menu_actions.clear()
	nav_fields.clear()
	repair_labels.clear()


func _open_menu(kind: String) -> void:
	menu = kind
	paused = kind in ["welcome", "pause", "restart"]
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	panel.visible = true
	_clear_panel()
	var title: String = {"welcome": "KESTREL / A QUIET DELIVERY", "contracts": "CONTRACT BOARD", "trade": "COMMODITY EXCHANGE", "services": "DOCK SERVICES", "nav": "ROUTE PLANNING / MK-II", "engineering": "ENGINEERING DIAGNOSTICS", "repair": "P-01 / COOLANT BYPASS", "pause": "SHIP LOG / PAUSED", "journal": "YOUR FIRST ROUND TRIP", "restart": "START A FRESH RUN?", "rescue": "STATION ASSISTANCE"}.get(kind, kind.to_upper())
	_paragraph(title, 35, Color("edbc72"))
	match kind:
		"welcome":
			_paragraph("You are a delivery pilot. Your ship is also your home.\n\nA short run connects Ceres Yard and Tharsis Ring. Take a two-crate job, load it yourself, plot your course, and look after the ship along the way. Return jobs let you try paid handling and trading.")
			_paragraph("WASD walk · mouse look · F use\nIn the seat: N map/computer · Space lift off · W/S thrust\nArrows/mouse steer · C route autopilot · L dock · F leave seat\nJ opens your loop checklist. Esc pauses. F5 saves / F9 loads.", 23)
			_paragraph("Transit takes about 80 seconds, longer with a worn coolant pump. Arrival holds safely until you are ready. Needs are gentle; there is no deadline.", 22)
			_button("Start a new delivery", func(): _welcome = false; _close_menu(); _say("Welcome aboard. The station is through the cargo hold behind you."), 1)
			if FileAccess.file_exists(_save_path()):
				_button("Continue saved session", _load_session, 2)
		"contracts":
			_paragraph("%s  /  %d CR" % [StateModel.STATIONS[state.dock], state.credits])
			if state.contract.is_empty():
				_paragraph("LOCAL CO-OP HAUL\n2 crates of %s → %s\nPAY 520 CR · NO DEADLINE\nCargo belongs to the client and is supplied free on the station pallet." % [StateModel.GOODS[state.dock], StateModel.STATIONS[1 - state.dock]])
				_button("Sign delivery contract", func(): _mutate(state.sign_contract), 1)
			else:
				_paragraph("ACTIVE JOB\n2 crates → %s\nHold: %d job crates\nDeliver both crates here at the destination.\nHand/pallet delivery pays full price; the crew charges 26 CR per hold crate." % [StateModel.STATIONS[int(state.contract.dest)], state.count_at("hold", true)])
				_button("Deliver current job", func(): _mutate(state.deliver), 2)
		"trade":
			_paragraph("%s  /  %d CR\n\nBuy local %s for %d CR per crate.\nThe other station pays %d CR per crate.\nLocal resale pays 75%% of purchase price. Cargo left in the hold pays a 10%% unloading fee." % [StateModel.STATIONS[state.dock], state.credits, StateModel.GOODS[state.dock], StateModel.BUY[state.dock], StateModel.SELL[state.dock]])
			_button("Buy one personal cargo crate", func(): _mutate(state.buy_cargo), 1)
			_button("Sell all personal cargo here", func(): _mutate(state.sell_cargo), 2)
			_paragraph("The exchange never buys contract cargo.", 22)
		"services":
			_paragraph("%s  /  %d CR\nFuel %d%% · meals %d · water %d\nPallet %d/8 crates · hold %d/8 crates" % [StateModel.STATIONS[state.dock], state.credits, int(state.fuel), state.rations, state.drinks, state.count_at("pad_%d" % state.dock), state.count_at("hold")])
			_button("Crew: load pallet → hold · %d CR" % (state.count_at("pad_%d" % state.dock) * 15), func(): _mutate(state.handling.bind(true)), 1)
			_button("Crew: unload hold → pallet · %d CR" % (state.count_at("hold") * 15), func(): _mutate(state.handling.bind(false)), 2)
			_button("Refuel to full · %d CR" % ceili((100 - state.fuel) * 2), func(): _mutate(state.service.bind("refuel")), 3)
			_button("Buy 3 meals + 5 water · 35 CR", func(): _mutate(state.service.bind("provisions")), 4)
			_button("Technician: permanent repairs · 120 CR", func(): _mutate(state.service.bind("technician")), 5)
		"engineering":
			_paragraph("COOLANT PUMP P-01       %d%%  %s\nDRIVE ASSEMBLY D-01     %d%%\nFUEL                   %d%%\n\nCoolant below 60%% limits cruise output. The ship can still reach port.\n\nP-01 is the orange service panel immediately to the right of this console. Walk to it and press F to fit a temporary bypass. A station technician restores both systems permanently." % [int(state.pump), "TEMPORARY BYPASS" if state.patched else "WORN" if state.pump < 80 else "HEALTHY", int(state.drive), int(state.fuel)])
			state.mark("diagnostics")
		"repair":
			_paragraph("Isolate the coolant pump, then turn the three bypass connectors to match their etched routing arrows. Test the circuit to complete the temporary repair.", 23)
			_button("Isolate / reconnect pump", _isolate, 4)
			for i in 3:
				repair_labels.append(_button("", _rotate_connector.bind(i), i + 1))
			_button("Test bypass circuit", _test_repair, 5)
			repair_status = _paragraph("", 23)
			_refresh_repair()
		"nav":
			_build_navigation()
		"journal", "pause":
			_paragraph("%d completed deliveries · %d personal crates sold\nEarned %d CR · spent %d CR · balance %d CR" % [state.delivered, state.traded, state.earnings, state.spent, state.credits])
			var items := [["contract", "Sign a delivery job"], ["load", "Load cargo by hand"], ["route", "Read the map and enter coordinates"], ["depart", "Fly a manual departure"], ["autopilot", "Travel on a programmed route"], ["eat", "Eat a meal"], ["drink", "Drink water"], ["wash", "Wash up"], ["diagnostics", "Inspect engineering diagnostics"], ["repair", "Fit a temporary repair"], ["dock", "Fly the approach and dock"], ["unload", "Unload cargo by hand"], ["deliver", "Get paid for a delivery"], ["buy", "Buy personal trade cargo"], ["sell", "Sell personal cargo"], ["crew_load", "Pay a loading crew"], ["crew_unload", "Pay an unloading crew"], ["refuel", "Refuel"], ["provisions", "Buy provisions"], ["technician", "Pay for permanent repairs"]]
			var lines := ""
			for item in items:
				lines += ("[DONE] " if state.completed.has(item[0]) else "[    ] ") + item[1] + "\n"
			_paragraph(lines, 22)
			_button("Save this session", _save_session, 1)
			_button("Load saved session", _load_session, 2)
			_button("Start fresh…", func(): _open_menu("restart"), 3)
			if kind == "pause": _button("Quit to desktop", func(): get_tree().quit(), 4)
		"restart":
			_paragraph("This resets the current run. Your existing save stays available until you save or dock again.")
			_button("Start a fresh run", _restart, 1)
		"rescue":
			_paragraph("A station tug can bring you and your cargo to the nearest dock.\n\nFee: 50 CR. If you cannot afford it, the remaining fee is recorded as a negative balance. There is no game-over for running out of fuel.")
			_button("Request the tug · 50 CR", _rescue, 1)
	if kind != "welcome":
		_button("Close / return aboard [Esc]", _close_menu)


func _close_menu() -> void:
	menu = ""
	paused = false
	panel.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_viewport().gui_release_focus()


func _build_navigation() -> void:
	var map := Control.new()
	map.custom_minimum_size = Vector2(760, 160)
	panel_body.add_child(map)
	map.draw.connect(func():
		map.draw_rect(Rect2(0, 0, 790, 160), Color("101a19"))
		for x in range(20, 790, 40): map.draw_line(Vector2(x, 0), Vector2(x, 160), Color("263832"))
		for y in range(0, 161, 40): map.draw_line(Vector2(0, y), Vector2(790, y), Color("263832"))
		map.draw_line(Vector2(135, 50), Vector2(640, 105), Color("c8a364"), 2)
		map.draw_circle(Vector2(135, 50), 7, Color("88bf98"))
		map.draw_circle(Vector2(640, 105), 7, Color("dfb477"))
		map.draw_string(font, Vector2(40, 30), "CERES YARD", HORIZONTAL_ALIGNMENT_LEFT, -1, 23, Color("d3ddca"))
		map.draw_string(font, Vector2(550, 145), "THARSIS RING", HORIZONTAL_ALIGNMENT_LEFT, -1, 23, Color("d3ddca"))
		map.draw_string(font, Vector2(320, 61), "7.2 KM / LOCAL ROUTE", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("9daea0")))
	_paragraph("Choose a station, read its slip, then enter the three coordinates below.", 22)
	var directory := HBoxContainer.new()
	directory.add_theme_constant_override("separation", 12)
	panel_body.add_child(directory)
	for i in 2:
		var choose := Button.new()
		choose.text = StateModel.STATIONS[i]
		choose.add_theme_font_override("font", font)
		choose.add_theme_font_size_override("font_size", 25)
		choose.custom_minimum_size = Vector2(280, 38)
		choose.pressed.connect(_select_route.bind(i))
		directory.add_child(choose)
	var grid: Vector3i = StateModel.GRIDS[selected_route]
	_paragraph("ROUTE SLIP / %s    X %+04d   Y %+04d   Z %+04d\nFuel budget: 12 units · current tank: %d" % [StateModel.STATIONS[selected_route], grid.x, grid.y, grid.z, int(state.fuel)], 24, Color("ecc990"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel_body.add_child(row)
	for axis in ["X", "Y", "Z"]:
		var field := LineEdit.new()
		field.placeholder_text = axis + " grid"
		field.max_length = 5
		field.keep_editing_on_text_submit = true
		field.custom_minimum_size = Vector2(180, 42)
		field.add_theme_font_override("font", font)
		field.add_theme_font_size_override("font_size", 27)
		field.text_submitted.connect(func(_text): _plot_route())
		row.add_child(field)
		nav_fields.append(field)
	_button("ENT / Program route", _plot_route)
	_paragraph("Fly 400 m clear, then C engages the route. F leaves the seat during transit.", 22)
	nav_fields[0].grab_focus()


func _select_route(index: int) -> void:
	selected_route = index
	_open_menu("nav")


func _plot_route() -> void:
	for field in nav_fields:
		var value := field.text.strip_edges().trim_prefix("+")
		if not value.is_valid_int():
			_say("Enter all three signed grid coordinates from the route slip.")
			return
	var grid := Vector3i(int(nav_fields[0].text), int(nav_fields[1].text), int(nav_fields[2].text))
	var index: int = StateModel.GRIDS.find(grid)
	if index < 0:
		_say("No station at that grid. Check the route slip.")
		return
	if index == state.dock:
		_say("That is your departure station. Select the other station's route slip.")
		return
	state.destination = index
	state.route_set = true
	state.mark("route")
	_close_menu()
	_say("Route programmed for %s. Fly clear of the station, then press C." % StateModel.STATIONS[index])


func _isolate() -> void:
	repair_isolated = not repair_isolated
	_refresh_repair()


func _rotate_connector(index: int) -> void:
	if not repair_isolated:
		repair_status.text = "Isolate the pump before adjusting connectors."
		return
	repair_rotations[index] = (repair_rotations[index] + 1) % 4
	_refresh_repair()


func _refresh_repair() -> void:
	var arrows := ["UP", "RIGHT", "DOWN", "LEFT"]
	var target := [1, 3, 2]
	for i in 3:
		repair_labels[i].text = "[%d] Connector %s: %-5s  /  etched arrow: %s" % [i + 1, ["A", "B", "C"][i], arrows[repair_rotations[i]], arrows[target[i]]]
	repair_status.text = "PUMP ISOLATED / align connectors, then test." if repair_isolated else "PUMP CONNECTED / isolate before touching the bypass."


func _test_repair() -> void:
	if not repair_isolated or repair_rotations != [1, 3, 2]:
		repair_status.text = "Circuit open. Isolate the pump and match all three etched arrows."
		return
	state.patch_pump()
	repair_isolated = false
	_close_menu()
	_say(state.message)
	_autosave()


func _mutate(callback: Callable) -> void:
	callback.call()
	var message: String = state.message
	_rebuild_cargo()
	var previous := menu
	_open_menu(previous)
	_say(message)
	_autosave()


func _say(value: String) -> void:
	toast_text = value
	toast_time = 7
	tone_remaining = 0.1


func _save_path() -> String:
	return "/tmp/kestrel-slice-test.json" if test_mode else StateModel.SAVE_PATH


func _autosave() -> void:
	if state.flight == "docked" and not test_mode:
		state.heading = flight_basis.get_euler()
		state.save_game(_save_path())


func _save_session() -> void:
	state.heading = flight_basis.get_euler()
	state.save_game(_save_path())
	_say(state.message)


func _load_session() -> void:
	if not state.load_game(_save_path()):
		_say(state.message)
		return
	_welcome = false
	flight_basis = Basis.from_euler(state.heading)
	piloting = false
	travel_velocity = Vector3.ZERO
	player.position = Vector3(0.35, 0.08, 3.35)
	player.rotation = Vector3.ZERO
	pitch = 0
	camera.rotation = Vector3.ZERO
	_rebuild_cargo()
	_sync_world()
	_close_menu()
	_say("Session restored. You are safely inside your hab.")


func _restart() -> void:
	state = StateModel.new()
	flight_basis = Basis(Vector3.UP, PI)
	travel_velocity = Vector3.ZERO
	piloting = false
	player.position = Vector3(0.35, 0.08, 3.35)
	player.rotation = Vector3.ZERO
	pitch = 0
	camera.rotation = Vector3.ZERO
	repair_rotations = [0, 1, 0]
	repair_isolated = false
	_rebuild_cargo()
	_sync_world()
	_close_menu()
	_say("Fresh run. Your first delivery is waiting at the station contract board.")


func _sync_world() -> void:
	var docked: bool = state.flight == "docked"
	station_room.visible = docked
	gate_mesh.visible = not docked
	gate.collision_layer = 0 if docked else 1
	targets["airlock-1"].collision_layer = 0 if docked else 64
	for name in ["contracts-1", "trade-1", "services-1"]:
		targets[name].collision_layer = 64 if docked else 0
	for label in station_labels:
		label.text = StateModel.STATIONS[state.dock].to_upper()
	_update_exterior()


func _update_exterior() -> void:
	var eye := Vector3(0, 1.68, -8.95)
	space.transform = Transform3D(flight_basis.inverse(), eye - flight_basis.inverse() * state.position)
	get_node("Stars").basis = flight_basis.inverse()


func _update_aim() -> void:
	selected_target = null
	if piloting or menu != "": return
	var from := camera.global_position
	# Empty cargo slots are selectable only while carrying something.
	var carrying: bool = not state.hand().is_empty()
	for i in 8:
		for key in ["slot", "pad_slot"]:
			var target: StaticBody3D = targets[key + str(i)]
			var where: String = "hold" if key == "slot" else "pad_%d" % state.dock
			var occupied: bool = state.cargo.any(func(c): return c.location == where and c.slot == i)
			target.collision_layer = 64 if carrying and not occupied and (key == "slot" or state.flight == "docked") else 0
	var query := PhysicsRayQueryParameters3D.create(from, from - camera.global_basis.z * 3.2, 65, [player.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.collider.has_meta("action"):
		selected_target = hit.collider


func _use() -> void:
	if piloting:
		_leave_pilot()
		return
	_update_aim()
	if not is_instance_valid(selected_target): return
	var action: String = selected_target.get_meta("action")
	var id: int = selected_target.get_meta("id")
	match action:
		"seat":
			if not state.hand().is_empty():
				_say("Secure the crate in the hold before taking the pilot seat.")
				return
			piloting = true
			player.position = Vector3(0, 0.05, -8.95)
			player.rotation = Vector3.ZERO
			player.velocity = Vector3.ZERO
			pitch = 0
			camera.rotation = Vector3.ZERO
			_say("N: route map/computer. Space: lift off. W/S: thrust. C: programmed route. F: leave seat.")
		"crate":
			state.pick(id)
			_rebuild_cargo()
			_say(state.message)
		"slot", "pad_slot":
			state.place("hold" if action == "slot" else "pad_%d" % state.dock, id)
			_rebuild_cargo()
			_say(state.message)
			_autosave()
		"eat", "drink", "rest":
			state.consume(action)
			_say(state.message)
			_autosave()
		"wash":
			if state.drinks > 0:
				wash_time = 2.5
				_say("Washing up…")
			else: _say("Washing needs one water unit. Refill at a station.")
		"repair":
			if state.pump >= 78:
				_say("The pump is serviceable. A technician can make a temporary patch permanent.")
			else: _open_menu("repair")
		"airlock":
			_say("Outer hatch sealed. Dock at a station before leaving the ship.")
		_:
			_open_menu(action)


func _leave_pilot() -> void:
	if state.flight == "manual":
		_say("Engage the programmed route before leaving the pilot seat.")
		return
	piloting = false
	player.position = Vector3(0, 0.05, -7.7)
	player.rotation = Vector3(0, PI, 0)
	pitch = 0
	camera.rotation = Vector3.ZERO
	_say("You have the ship to yourself. Visit the hab or engineering; the arrival hold waits for you.")


func _unhandled_input(event: InputEvent) -> void:
	if player == null: return
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.physical_keycode
		if key == KEY_ESCAPE:
			if menu != "": _close_menu()
			else: _open_menu("pause")
			get_viewport().set_input_as_handled()
			return
		if menu != "":
			if menu_actions.has(key):
				menu_actions[key].call()
				get_viewport().set_input_as_handled()
			return
		match key:
			KEY_F: _use()
			KEY_J: _open_menu("journal")
			KEY_F5: _save_session()
			KEY_F9: _load_session()
			KEY_N, KEY_M:
				if piloting:
					selected_route = 1 - state.dock
					_open_menu("nav")
			KEY_SPACE:
				if piloting and state.flight == "docked": _depart()
			KEY_C:
				if piloting: _engage_route()
			KEY_L:
				if piloting: _dock()
			KEY_R:
				if piloting and state.flight != "docked": _open_menu("rescue")
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and menu == "" and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if piloting:
			if state.flight in ["manual", "arrival"]:
				flight_basis = flight_basis * Basis(Vector3.UP, -event.relative.x * 0.0018)
				flight_basis = (flight_basis * Basis(Vector3.RIGHT, -event.relative.y * 0.0018)).orthonormalized()
		else:
			player.rotate_y(-event.relative.x * 0.0022)
			pitch = clampf(pitch - event.relative.y * 0.0022, -1.4, 1.4)
			camera.rotation.x = pitch
	elif event is InputEventMouseButton and event.pressed and menu == "":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _depart() -> void:
	if state.fuel < 3:
		_say("Fuel too low for departure. Refill at the dock service terminal.")
		return
	state.flight = "manual"
	travel_velocity = Vector3.ZERO
	state.mark("depart")
	_rebuild_cargo()
	_sync_world()
	_say("Undocked. W flies ahead. Reach 400 m from port, then C engages your programmed route.")


func _engage_route() -> void:
	if state.flight == "transit":
		_say("Route already engaged. F leaves the seat; the computer handles this leg.")
		return
	if state.flight not in ["manual", "arrival"] or not state.route_set:
		_say("Program a destination in the navigation computer first [N].")
		return
	var origin := Vector3(StateModel.GRIDS[state.dock]) * 100
	if state.position.distance_to(origin) < 400:
		_say("Fly 400 m clear of the departure station before engaging the route.")
		return
	if state.fuel < 12:
		_say("This route needs a 12-unit fuel reserve. R requests station assistance if needed.")
		return
	var target := Vector3(StateModel.GRIDS[state.destination]) * 100
	if state.position.distance_to(target) < 700:
		_say("You are in the approach zone. Fly in manually and press L below 12 m/s.")
		return
	state.transit_start = state.position
	state.transit_end = target + (state.position - target).normalized() * 620
	state.transit_progress = 0
	state.flight = "transit"
	state.mark("autopilot")
	flight_basis = Basis.looking_at(target - state.position, Vector3.UP)
	travel_velocity = Vector3.ZERO
	_say("Route engaged. F leaves the seat. Eat, drink, wash, or check engineering while the ship travels.")


func _flight_tick(delta: float) -> void:
	if state.flight != "docked": state.drive = maxf(0, state.drive - delta * 0.004)
	if state.flight == "transit":
		var rate := 0.7 if state.pump < 60 else 1.0
		state.transit_progress = minf(1, state.transit_progress + delta * rate / 80)
		state.position = state.transit_start.lerp(state.transit_end, state.transit_progress)
		state.fuel = maxf(0, state.fuel - delta * rate * 0.09)
		if state.transit_progress > 0.2 and not state.fault_seen:
			state.fault_seen = true
			if state.pump < 70 and not state.patched:
				state.pump = 44
				_say("Engineering: P-01 coolant flow is low. The route continues at reduced output; inspect the pump when convenient.")
		if state.transit_progress >= 1:
			state.flight = "arrival"
			travel_velocity = Vector3.ZERO
			_say("Arrival hold at %s. Return to the pilot seat for manual approach. No rush." % StateModel.STATIONS[state.destination])
	elif state.flight in ["manual", "arrival"]:
		var active_controls := piloting and menu == ""
		var yaw := (float(Input.is_physical_key_pressed(KEY_LEFT)) - float(Input.is_physical_key_pressed(KEY_RIGHT))) if active_controls else 0.0
		var tilt := (float(Input.is_physical_key_pressed(KEY_UP)) - float(Input.is_physical_key_pressed(KEY_DOWN))) if active_controls else 0.0
		flight_basis = flight_basis * Basis(Vector3.UP, yaw * delta * 0.85)
		flight_basis = (flight_basis * Basis(Vector3.RIGHT, tilt * delta * 0.85)).orthonormalized()
		var throttle := (Input.get_action_strength("throttle_up") - Input.get_action_strength("throttle_down")) if active_controls else 0.0
		var strafe := Input.get_axis("strafe_left", "strafe_right") if active_controls else 0.0
		var up := Input.get_axis("thrust_down", "thrust_up") if active_controls else 0.0
		var desired := flight_basis * Vector3(strafe * 24, up * 24, -throttle * 58)
		if state.fuel <= 0:
			desired = Vector3.ZERO
		travel_velocity = travel_velocity.move_toward(desired, delta * 22)
		state.position += travel_velocity * delta
		state.fuel = maxf(0, state.fuel - travel_velocity.length() * delta * 0.0015)
		for i in 2:
			var center := Vector3(StateModel.GRIDS[i]) * 100
			var offset: Vector3 = state.position - center
			if offset.length() < 125:
				state.position = center + offset.normalized() * 125
				travel_velocity = Vector3.ZERO
				_say("Proximity assist stopped the ship. Press L to dock.")
	_update_exterior()


func _dock() -> void:
	if state.flight not in ["manual", "arrival"]: return
	var nearest := 0
	var distance := INF
	for i in 2:
		var d: float = state.position.distance_to(Vector3(StateModel.GRIDS[i]) * 100)
		if d < distance:
			distance = d
			nearest = i
	if distance > 260:
		_say("Fly within 260 m of the station to request final docking. Currently %d m." % int(distance))
		return
	if travel_velocity.length() > 12:
		_say("Release thrust and slow below 12 m/s before docking.")
		return
	state.dock = nearest
	state.flight = "docked"
	state.route_set = false
	state.position = Vector3(StateModel.GRIDS[nearest]) * 100 + Vector3(0, 0, 180)
	flight_basis = Basis(Vector3.UP, PI)
	travel_velocity = Vector3.ZERO
	state.mark("dock")
	_rebuild_cargo()
	_sync_world()
	_autosave()
	_say("Docked at %s. F leaves the seat. Unload, deliver, and visit dock services." % StateModel.STATIONS[nearest])


func _rescue() -> void:
	state.credits -= 50
	state.spent += 50
	var nearest := 0 if state.position.length() < state.position.distance_to(Vector3(StateModel.GRIDS[1]) * 100) else 1
	state.dock = nearest
	state.flight = "docked"
	state.route_set = false
	state.position = Vector3(StateModel.GRIDS[nearest]) * 100 + Vector3(0, 0, 180)
	flight_basis = Basis(Vector3.UP, PI)
	travel_velocity = Vector3.ZERO
	state.fuel = maxf(state.fuel, 15)
	_rebuild_cargo()
	_sync_world()
	_close_menu()
	_say("The tug brought you to %s and supplied reserve fuel. Fee: 50 CR." % StateModel.STATIONS[nearest])
	_autosave()


func _physics_process(delta: float) -> void:
	if player == null or paused: return
	state.tick(delta)
	_flight_tick(delta)
	if wash_time > 0:
		wash_time -= delta
		if wash_time <= 0:
			state.consume("wash")
			_say(state.message)
			_autosave()
	if not piloting:
		var move := Input.get_vector("move_left", "move_right", "move_forward", "move_back") if menu == "" and wash_time <= 0 else Vector2.ZERO
		var direction := player.basis * Vector3(move.x, 0, move.y)
		var speed := 3.3 if Input.is_action_pressed("sprint") else 2.6
		if not state.hand().is_empty(): speed *= 0.85
		if minf(state.food, state.water) < 15: speed *= 0.8
		player.velocity.x = direction.x * speed
		player.velocity.z = direction.z * speed
		player.velocity.y = -0.4 if player.is_on_floor() else player.velocity.y - 15 * delta
		player.move_and_slide()
	_update_aim()


func _objective() -> String:
	if state.flight == "transit":
		if state.pump < 60: return "Transit: inspect engineering, then open orange pump P-01 to fit a bypass. The ship continues its route."
		return "Transit: eat at the galley, drink, wash, or rest. Return to the cockpit when the arrival notice sounds."
	if state.flight == "arrival": return "Arrival hold: take the pilot seat, fly toward the station, release W to brake, then L within 260 m and below 12 m/s."
	if state.flight == "manual": return "Departure: W flies ahead. Get 400 m clear, then C engages your programmed route. N opens the map/computer."
	if state.contract.is_empty():
		if state.delivered > 0: return "Delivery complete. Sell personal cargo, refuel, restock, and book repairs. Take a return job to try the other loops. J: checklist."
		return "First job: turn around and walk through the cargo hold to the station. Find CONTRACTS on the left of the service concourse."
	if state.contract.dest == state.dock: return "Unload to the station pallet by hand, or pay the crew. Then deliver at CONTRACTS. Hold delivery is available for a fee."
	if state.count_at("hold", true) < 2: return "Load both JOB crates from the station pallet into the ship's hold. F lifts; aim at a marked empty space and F secures."
	if not state.route_set: return "Cargo aboard. Walk through the hab to the cockpit, take the seat [F], then N to read the map and enter your route."
	return "Ready for departure. Take the pilot seat and press Space to release the dock."


func _process(delta: float) -> void:
	if status_label == null: return
	_audio(delta)
	toast_time = maxf(0, toast_time - delta)
	var viewport := get_viewport().get_visible_rect().size
	var travel: String = "DOCKED / " + StateModel.STATIONS[state.dock]
	if state.flight == "transit": travel = "ROUTE / %ds TO ARRIVAL" % ceili((1 - state.transit_progress) * 80 / (0.7 if state.pump < 60 else 1.0))
	elif state.flight == "arrival": travel = "ARRIVAL HOLD / " + StateModel.STATIONS[state.destination]
	elif state.flight == "manual": travel = "MANUAL FLIGHT / %d M/S" % int(travel_velocity.length())
	status_label.text = "%s   ·   %d CR   ·   FUEL %d%%\nFOOD %d   WATER %d   HYGIENE %d   ·   %d MEALS / %d WATER UNITS" % [travel, state.credits, int(state.fuel), int(state.food), int(state.water), int(state.hygiene), state.rations, state.drinks]
	goal_label.text = _objective()
	goal_label.size.x = minf(740, viewport.x - 48)
	status_label.visible = menu == ""
	goal_label.visible = menu == ""
	toast_label.text = toast_text
	toast_label.visible = toast_time > 0
	toast_label.size.x = minf(960, viewport.x - 48)
	toast_label.position = Vector2((viewport.x - toast_label.size.x) / 2, viewport.y - 122)
	toast_label.z_index = 5
	hints_label.text = "N MAP   SPACE UNDOCK   W/S THRUST   ARROWS STEER   C ROUTE   L DOCK   F STAND" if piloting else "WASD WALK   MOUSE LOOK   F USE   J CHECKLIST   ESC PAUSE"
	hints_label.position = Vector2(24, viewport.y - 37)
	hints_label.visible = menu == ""
	prompt_label.text = ""
	if is_instance_valid(selected_target) and menu == "" and not piloting:
		prompt_label.text = "[F] " + str(selected_target.get_meta("label"))
	if wash_time > 0: prompt_label.text = "Washing up…"
	prompt_label.reset_size()
	prompt_label.position = Vector2((viewport.x - prompt_label.size.x) / 2, viewport.y - 170)
	reticle.visible = menu == "" and not piloting
	reticle.position = viewport / 2 - Vector2(4, 12)
	marker.visible = piloting and state.flight in ["manual", "arrival"] and menu == "" and state.route_set
	if marker.visible:
		var target := Vector3(StateModel.GRIDS[state.destination]) * 100
		var local: Vector3 = space.transform * target
		var distance: float = state.position.distance_to(target)
		var p := camera.unproject_position(local)
		if camera.is_position_behind(local): p = Vector2(viewport.x / 2, 160)
		marker.text = ("TARGET BEHIND" if camera.is_position_behind(local) else "+ %s" % StateModel.STATIONS[state.destination]) + " / %d M" % int(distance)
		marker.position = Vector2(clampf(p.x, 20, viewport.x - 310), clampf(p.y, 160, viewport.y - 200))
	room_timer += delta
	if room_timer >= 0.25:
		room_timer = 0
		screens[0].text = "COOLANT %d%%\nDRIVE   %d%%\n%s" % [int(state.pump), int(state.drive), "BYPASS FITTED" if state.patched else "F: DIAGNOSTICS"]
		screens[1].text = "NAV / %s\n%s" % ["PROGRAMMED" if state.route_set else "STANDBY", StateModel.STATIONS[state.destination].to_upper() if state.route_set else "N: MAP + GRID"]
		screens[2].text = "FUEL %d%%\n%s\n%03d M/S" % [int(state.fuel), state.flight.to_upper(), int(travel_velocity.length())]


func _capture_slice() -> void:
	var args := OS.get_cmdline_user_args()
	var index := args.find("--slice-capture")
	var view := args[index + 1] if index + 1 < args.size() else "hab"
	_close_menu()
	match view:
		"welcome": _open_menu("welcome")
		"nav": _open_menu("nav")
		"repair": _open_menu("repair")
		"cockpit":
			piloting = true
			player.position = Vector3(0, 0.05, -8.95)
			player.rotation = Vector3.ZERO
			camera.rotation = Vector3.ZERO
			state.position = Vector3(2400, 300, -6180)
			state.flight = "arrival"
			state.route_set = true
			flight_basis = Basis.IDENTITY
			_sync_world()
		"station":
			player.position = Vector3(0.2, 0.05, 12.5)
			player.rotation.y = PI
			camera.rotation.x = -0.08
	await _frames(45)
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://../life-slice-%s.png" % view)
	get_viewport().get_texture().get_image().save_png(path)
	print("SLICE CAPTURE ", path)
	get_tree().quit()
