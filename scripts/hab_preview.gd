extends Node3D
## Standalone walkable art study. Run scenes/hab_preview.tscn (F6).
## Uses its own controller and never changes the main game's world or player.

const CREAM := Color("b8aa8b")
const LIGHT := Color("d3c5a4")
const SHADOW := Color("85775f")
const DARK := Color("34332d")
const ORANGE := Color("b55f25")
const GOLD := Color("bc8c30")
const FLOOR := Color("777060")
var mats: Dictionary = {}
var hull: StaticBody3D
var player: CharacterBody3D
var camera: Camera3D
var pitch := 0.0
var overlay: Control
var font := preload("res://assets/fonts/VT323-Regular.ttf")
var solid_count := 0
var connected_layout := false


func _ready() -> void:
	DisplayServer.window_set_title("Kestrel — Walkable Hab Study")
	_build_environment()
	hull = StaticBody3D.new()
	hull.name = "RoomCollision"
	add_child(hull)
	_shell()
	_panel_details()
	_window()
	_bed()
	_galley()
	_bulkhead()
	_personal_objects()
	_lighting()
	_controller()
	_ui()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var args := OS.get_cmdline_user_args()
	if "--hab-test" in args:
		_selftest.call_deferred()
	if "--hab-capture" in args:
		_capture.call_deferred()


func _material(color: Color, glow := false) -> StandardMaterial3D:
	var key := color.to_html() + str(glow)
	if mats.has(key):
		return mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.92
	if glow:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 1.25
	mats[key] = m
	return m


func _box(pos: Vector3, size: Vector3, color: Color, solid := false, glow := false) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.position = pos
	mesh.material_override = _material(color, glow)
	add_child(mesh)
	if solid:
		var collider := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		collider.shape = box
		collider.position = pos
		hull.add_child(collider)
		solid_count += 1
	return mesh


func _text(value: String, pos: Vector3, size := 0.0025, color := DARK, yaw := 0.0) -> Label3D:
	var label := Label3D.new()
	label.text = value
	label.font = font
	label.font_size = 64
	label.pixel_size = size
	label.modulate = color
	label.outline_size = 0
	label.no_depth_test = false
	label.position = pos
	label.rotation.y = yaw
	add_child(label)
	return label


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("050a12")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b2b9c8")
	env.ambient_light_energy = 0.18
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	if RenderingServer.get_current_rendering_method() == "forward_plus":
		env.ssao_enabled = true
		env.ssao_radius = 0.55
		env.ssao_intensity = 2.2
		env.ssao_light_affect = 0.65
		env.ssil_enabled = true
		env.ssil_intensity = 0.65
		env.glow_enabled = true
		env.glow_intensity = 0.3
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)


func _shell() -> void:
	_box(Vector3(0, -0.15, 0), Vector3(6.2, 0.3, 8.4), DARK, true)
	# Broad, flush floor plates. The narrow dark seams are actual gaps in the finish.
	for x in 6:
		for z in 8:
			_box(Vector3(-2.5 + x, 0.006, -3.5 + z), Vector3(0.976, 0.012, 0.976), FLOOR.lightened(0.025 * ((x + z) % 3)))
	_box(Vector3(0, 3.28, 0), Vector3(6.2, 0.25, 8.4), SHADOW, true)
	_box(Vector3(3.1, 1.6, 0), Vector3(0.2, 3.2, 8.4), CREAM, true)
	if connected_layout:
		for x in [-2.05, 2.05]:
			_box(Vector3(x, 1.6, 4.15), Vector3(2.1, 3.2, 0.2), CREAM, true)
		_box(Vector3(0, 2.94, 4.15), Vector3(2, 0.52, 0.2), CREAM, true)
	else:
		_box(Vector3(0, 1.6, 4.15), Vector3(6.2, 3.2, 0.2), CREAM, true)
	# Left wall leaves a genuine aperture for the observation window.
	_box(Vector3(-3.1, 0.6, 0), Vector3(0.2, 1.2, 8.4), CREAM, true)
	_box(Vector3(-3.1, 2.97, 0), Vector3(0.2, 0.46, 8.4), CREAM, true)
	_box(Vector3(-3.1, 1.97, -3.6), Vector3(0.2, 1.54, 1.2), CREAM, true)
	_box(Vector3(-3.1, 1.97, 2.65), Vector3(0.2, 1.54, 3.1), CREAM, true)
	for z in [-3.8, -1.2, 1.4, 3.95]:
		_box(Vector3(0, 3.03, z), Vector3(6, 0.22, 0.16), SHADOW, true)
		_box(Vector3(2.93, 1.55, z), Vector3(0.14, 3.1, 0.16), SHADOW, true)
	for x in [-2.94, 2.94]:
		_box(Vector3(x, 0.13, 0), Vector3(0.1, 0.26, 8.1), DARK)
		_box(Vector3(x, 2.82, 0), Vector3(0.11, 0.12, 8.1), ORANGE)
	# A flat woven rug made from broad color blocks, with no raised trip edge.
	_box(Vector3(-0.1, 0.016, 1.25), Vector3(2.6, 0.008, 3.0), ORANGE)
	_box(Vector3(-0.1, 0.022, 1.25), Vector3(2.38, 0.005, 2.77), GOLD)
	_box(Vector3(-0.1, 0.026, 1.25), Vector3(2.14, 0.003, 2.53), Color("907749"))
	for z in [0.13, 2.37]:
		_box(Vector3(-0.1, 0.03, z), Vector3(2.1, 0.004, 0.07), ORANGE)


func _window() -> void:
	# Thick stepped frame with block corners, matching the reference's voxel language.
	for z in [-2.97, 1.07]:
		_box(Vector3(-2.97, 1.96, z), Vector3(0.22, 1.58, 0.18), SHADOW, true)
		_box(Vector3(-2.82, 1.96, z), Vector3(0.14, 1.4, 0.09), ORANGE)
	for y in [1.22, 2.71]:
		_box(Vector3(-2.97, y, -0.95), Vector3(0.22, 0.18, 4.22), SHADOW, true)
		_box(Vector3(-2.8, y, -0.95), Vector3(0.18, 0.09, 3.98), ORANGE)
	for y in [1.34, 2.6]:
		for z in [-2.85, 0.95]:
			_box(Vector3(-2.84, y, z), Vector3(0.2, 0.22, 0.22), CREAM, true)
	# Glass is a visible, very dark plane with its own collision.
	_box(Vector3(-3.14, 1.96, -0.95), Vector3(0.025, 1.38, 3.9), Color("081423"), true, true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 85:
		var s := rng.randf_range(0.008, 0.019)
		_box(Vector3(-3.12, rng.randf_range(1.32, 2.58), rng.randf_range(-2.82, 0.92)), Vector3(0.007, s, s), Color("9cb9cb") if i % 4 else Color("e8dac1"), false, true)
	_box(Vector3(-2.79, 1.15, -0.95), Vector3(0.38, 0.12, 4.2), LIGHT, true)
	for y in [1.37, 2.56]:
		_box(Vector3(-3.108, y, -0.95), Vector3(0.026, 0.035, 3.77), DARK)


func _panel_details() -> void:
	# Recessed-looking plates give large surfaces the same broad voxel rhythm as the props.
	for z in [-2.45, -0.35, 1.75, 3.35]:
		for x in [-1.83, 1.83]:
			_box(Vector3(x, 3.127, z), Vector3(1.6, 0.045, 1.42), DARK)
			_box(Vector3(x, 3.099, z), Vector3(1.52, 0.042, 1.34), SHADOW)
	for x in [-1.43, 1.09, 2.85]:
		_box(Vector3(x, 1.55, -3.924), Vector3(0.055, 3.02, 0.055), SHADOW)
	for x in [-2.47, -1.74]:
		_box(Vector3(x, 2.79, -3.858), Vector3(0.62, 0.035, 0.08), DARK)
	# Small service panel beside the washroom, with block vents and a mechanical switch.
	_box(Vector3(1.23, 1.62, -3.805), Vector3(0.23, 0.67, 0.11), SHADOW, true)
	for y in [1.43, 1.49, 1.55]:
		_box(Vector3(1.23, y, -3.741), Vector3(0.15, 0.021, 0.012), DARK)
	_box(Vector3(1.23, 1.79, -3.723), Vector3(0.075, 0.12, 0.052), GOLD)
	# Layered trim on the entrance wall keeps the reverse view finished too.
	for y in [0.95, 2.61]:
		_box(Vector3(-1.07, y, 4.025), Vector3(3.4, 0.055, 0.03), SHADOW)
	for x in [-2.54, -1.16, 0.21]:
		_box(Vector3(x, 1.74, 4.022), Vector3(0.04, 1.72, 0.035), SHADOW)


func _bed() -> void:
	_box(Vector3(-2.18, 0.35, -0.6), Vector3(1.48, 0.7, 3.7), SHADOW, true)
	_box(Vector3(-2.18, 0.69, -0.6), Vector3(1.59, 0.13, 3.83), LIGHT, true)
	_box(Vector3(-2.18, 0.83, -0.6), Vector3(1.39, 0.18, 3.57), Color("c9bca1"), true)
	_box(Vector3(-2.18, 0.94, -1.8), Vector3(1.1, 0.2, 0.7), LIGHT, true)
	_box(Vector3(-2.18, 0.96, -0.18), Vector3(1.44, 0.12, 2.45), GOLD, true)
	_box(Vector3(-1.48, 0.83, -0.18), Vector3(0.1, 0.23, 2.45), GOLD.darkened(0.12))
	for z in range(8):
		for x in range(4):
			_box(Vector3(-2.7 + x * 0.35, 1.024, -1.24 + z * 0.3), Vector3(0.34, 0.008, 0.29), GOLD.lightened(0.018 * ((x * 3 + z) % 4)))
	for z in [-1.6, 0.15]:
		_box(Vector3(-1.428, 0.37, z), Vector3(0.04, 0.41, 1.48), CREAM)
		_box(Vector3(-1.39, 0.44, z), Vector3(0.055, 0.085, 0.46), DARK)
	# Headboard shelving, inset into the back-left corner.
	_box(Vector3(-2.2, 1.95, -3.84), Vector3(1.28, 1.95, 0.3), SHADOW, true)
	_box(Vector3(-2.2, 1.97, -3.64), Vector3(1.1, 0.68, 0.12), DARK)
	for i in 5:
		var colors := [ORANGE, GOLD, CREAM, Color("6e7b65"), Color("4a615a")]
		_box(Vector3(-2.64 + i * 0.2, 1.89, -3.49), Vector3(0.15, 0.42 + 0.05 * (i % 2), 0.22), colors[i], true)
	_box(Vector3(-2.2, 1.6, -3.43), Vector3(1.22, 0.09, 0.43), LIGHT, true)


func _galley() -> void:
	_box(Vector3(2.52, 0.49, 0.14), Vector3(0.95, 0.98, 4.2), CREAM, true)
	_box(Vector3(2.46, 1.025, 0.14), Vector3(1.13, 0.1, 4.3), LIGHT, true)
	for i in 4:
		var z := -1.43 + i * 1.02
		_box(Vector3(2.031, 0.5, z), Vector3(0.035, 0.83, 0.93), ORANGE if i == 1 else SHADOW)
		_box(Vector3(1.999, 0.78, z), Vector3(0.055, 0.07, 0.29), DARK)
	# Sink recess and square faucet.
	_box(Vector3(2.45, 1.083, 0.5), Vector3(0.68, 0.023, 0.72), DARK)
	_box(Vector3(2.45, 1.097, 0.5), Vector3(0.49, 0.025, 0.55), Color("64716d"))
	_box(Vector3(2.83, 1.28, 0.5), Vector3(0.09, 0.39, 0.1), DARK, true)
	_box(Vector3(2.68, 1.46, 0.5), Vector3(0.37, 0.08, 0.1), DARK, true)
	# Food cupboard and an open shelf above the worktop.
	_box(Vector3(2.73, 2.55, 0.1), Vector3(0.57, 0.72, 4.12), SHADOW, true)
	for z in [-1.35, -0.34, 0.67, 1.68]:
		_box(Vector3(2.427, 2.55, z), Vector3(0.045, 0.61, 0.94), ORANGE if z < 0 else CREAM)
		_box(Vector3(2.385, 2.4, z), Vector3(0.05, 0.055, 0.24), DARK)
	_box(Vector3(2.65, 1.95, -0.7), Vector3(0.73, 0.07, 2.2), LIGHT, true)
	for i in 5:
		_box(Vector3(2.64, 2.09, -1.52 + i * 0.37), Vector3(0.32, 0.24, 0.26), [GOLD, CREAM, Color("778565")][i % 3], true)
	# Simple blue water tank and dispenser.
	_box(Vector3(2.62, 1.29, -1.3), Vector3(0.55, 0.4, 0.54), SHADOW, true)
	_box(Vector3(2.62, 1.68, -1.3), Vector3(0.45, 0.4, 0.44), Color("6b9399"), true)
	_box(Vector3(2.32, 1.37, -1.3), Vector3(0.13, 0.08, 0.1), DARK, true)
	_text("WATER", Vector3(2.323, 1.18, -1.3), 0.0013, LIGHT, -PI / 2)
	_mug(Vector3(2.25, 1.085, 1.37), ORANGE)
	# A counter appliance uses the same large-box detail scale.
	_box(Vector3(2.55, 1.28, 1.85), Vector3(0.65, 0.4, 0.5), SHADOW, true)
	_box(Vector3(2.21, 1.3, 1.85), Vector3(0.02, 0.2, 0.32), DARK)
	_box(Vector3(2.196, 1.2, 1.66), Vector3(0.022, 0.05, 0.05), Color("91bd70"), false, true)


func _bulkhead() -> void:
	# Full-height center doorway into a shallow engineering display alcove.
	_box(Vector3(-2.02, 1.6, -4.05), Vector3(2.16, 3.2, 0.2), CREAM, true)
	_box(Vector3(2.02, 1.6, -4.05), Vector3(2.16, 3.2, 0.2), CREAM, true)
	_box(Vector3(0, 2.94, -4.05), Vector3(1.9, 0.52, 0.2), CREAM, true)
	for x in [-0.98, 0.98]:
		_box(Vector3(x, 1.34, -3.86), Vector3(0.17, 2.68, 0.23), ORANGE, true)
	_box(Vector3(0, 2.64, -3.86), Vector3(2.13, 0.18, 0.23), ORANGE, true)
	_text("ENGINEERING", Vector3(0, 2.92, -3.935), 0.0017, DARK)
	_box(Vector3(0, -0.12, -4.8), Vector3(2, 0.24, 1.5), FLOOR, true)
	_box(Vector3(0, 1.5, -5.55), Vector3(2.2, 3, 0.2), DARK, true)
	for x in [-1.08, 1.08]:
		_box(Vector3(x, 1.5, -4.8), Vector3(0.16, 3, 1.5), SHADOW, true)
	_box(Vector3(0, 3, -4.8), Vector3(2.3, 0.2, 1.5), SHADOW, true)
	for x in [-0.6, 0.0, 0.6]:
		_box(Vector3(x, 0.57, -5.15), Vector3(0.54, 1.14, 0.64), SHADOW, true)
		_box(Vector3(x, 0.7, -4.817), Vector3(0.3, 0.26, 0.03), DARK)
		_box(Vector3(x + 0.13, 0.96, -4.79), Vector3(0.07, 0.07, 0.025), GOLD, false, true)
	_box(Vector3(0, 1.61, -5.16), Vector3(1.08, 0.78, 0.5), CREAM, true)
	_box(Vector3(0, 1.63, -4.897), Vector3(0.87, 0.55, 0.035), Color("082b1d"), false, true)
	_text("SYSTEMS\nPOWER   OK\nCOOLANT OK\nDRIVE   OK", Vector3(0, 1.64, -4.869), 0.0017, Color("83d989"))
	# Closed washroom door: deliberately a prop in this one-room study.
	_box(Vector3(2, 1.36, -3.87), Vector3(1.36, 2.72, 0.22), SHADOW, true)
	_box(Vector3(2, 1.37, -3.734), Vector3(1.16, 2.47, 0.055), LIGHT)
	_box(Vector3(2, 0.52, -3.697), Vector3(1.13, 0.21, 0.022), ORANGE)
	_box(Vector3(1.56, 1.12, -3.66), Vector3(0.08, 0.34, 0.06), DARK, true)
	_text("WASH\n01", Vector3(2, 1.85, -3.69), 0.004, SHADOW)
	_box(Vector3(2, 2.85, -3.78), Vector3(0.19, 0.12, 0.06), Color("b1c78a"), false, true)


func _mug(pos: Vector3, color: Color) -> void:
	_box(pos + Vector3(0, 0.105, 0), Vector3(0.17, 0.21, 0.17), color, true)
	_box(pos + Vector3(0, 0.214, 0), Vector3(0.125, 0.009, 0.125), DARK)
	_box(pos + Vector3(0.135, 0.11, 0), Vector3(0.09, 0.035, 0.06), color)
	_box(pos + Vector3(0.17, 0.075, 0), Vector3(0.03, 0.105, 0.06), color)
	_box(pos + Vector3(0.135, 0.033, 0), Vector3(0.09, 0.035, 0.06), color)


func _personal_objects() -> void:
	# Fold-out table sits off the center route through the room.
	_box(Vector3(-0.91, 0.85, 0.95), Vector3(1.0, 0.1, 1.22), SHADOW, true)
	_box(Vector3(-1.14, 0.43, 0.95), Vector3(0.14, 0.83, 0.58), DARK, true)
	_mug(Vector3(-0.84, 0.9, 0.7), ORANGE)
	_box(Vector3(-0.96, 0.921, 1.25), Vector3(0.29, 0.045, 0.37), Color("668077"), true)
	_box(Vector3(-0.96, 0.947, 1.25), Vector3(0.24, 0.01, 0.29), LIGHT)
	# Stool: chunky cushion over a hollow four-legged frame.
	_box(Vector3(-0.5, 0.48, 2.05), Vector3(0.56, 0.16, 0.55), GOLD, true)
	for x in [-0.7, -0.3]:
		for z in [1.86, 2.24]:
			_box(Vector3(x, 0.2, z), Vector3(0.13, 0.4, 0.13), SHADOW, true)
	# Tiny voxel landscape print, built from a handful of flat blocks.
	_box(Vector3(-2.19, 1.13, -3.59), Vector3(0.57, 0.47, 0.07), LIGHT)
	_box(Vector3(-2.19, 1.13, -3.546), Vector3(0.43, 0.33, 0.02), Color("7f8b87"))
	_box(Vector3(-2.19, 1.04, -3.53), Vector3(0.43, 0.15, 0.015), Color("856548"))
	_box(Vector3(-2.13, 1.13, -3.515), Vector3(0.16, 0.13, 0.012), GOLD)
	# Entry wall storage completes the room when looking back.
	_box(Vector3(1.82, 1.34, 3.9), Vector3(1.56, 2.66, 0.34), SHADOW, true)
	for x in [1.43, 2.2]:
		_box(Vector3(x, 1.4, 3.706), Vector3(0.7, 2.37, 0.035), CREAM)
		_box(Vector3(x - 0.22, 1.31, 3.675), Vector3(0.06, 0.28, 0.045), DARK)
	_text("PERSONAL / 01", Vector3(1.81, 2.78, 3.72), 0.002, DARK, PI)


func _lamp(pos: Vector3, energy: float, radius: float, color: Color, shadows := false) -> void:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = radius
	light.omni_attenuation = 1.4
	light.shadow_enabled = shadows
	light.shadow_bias = 0.025
	add_child(light)


func _lighting() -> void:
	for z in [-2.7, 0.25, 2.9]:
		_box(Vector3(0, 3.04, z), Vector3(1.35, 0.16, 0.78), DARK)
		_box(Vector3(0, 2.944, z), Vector3(1.1, 0.045, 0.58), Color("ffd893"), false, true)
		_lamp(Vector3(0, 2.76, z), 0.95, 4.1, Color("ffe1ac"), true)
	_box(Vector3(2.62, 2.165, 0.15), Vector3(0.31, 0.025, 3.85), Color("ffe5b3"), false, true)
	_lamp(Vector3(2.05, 1.85, 0.1), 0.35, 2.6, Color("ffdb9a"))
	_lamp(Vector3(-2.8, 1.95, -0.9), 0.4, 3.8, Color("99b7de"))
	_lamp(Vector3(0, 2.45, -4.9), 0.65, 2.8, Color("e7d8ad"))


func _controller() -> void:
	player = CharacterBody3D.new()
	player.name = "PreviewPlayer"
	player.collision_layer = 2
	player.collision_mask = 1
	player.floor_snap_length = 0.18
	player.floor_max_angle = deg_to_rad(45)
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.25
	capsule.height = 1.72
	collision.shape = capsule
	collision.position.y = 0.86
	player.add_child(collision)
	camera = Camera3D.new()
	camera.position.y = 1.63
	camera.fov = 76
	camera.near = 0.04
	player.add_child(camera)
	add_child(player)
	player.position = Vector3(0.35, 0.04, 3.35)
	pitch = -0.04
	camera.rotation.x = pitch
	camera.current = true


func _ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var title := Label.new()
	title.text = "KESTREL / HAB 01"
	title.position = Vector2(24, 20)
	title.add_theme_font_override("font", font)
	title.add_theme_font_size_override("font_size", 24)
	title.modulate = Color("d4c8ad")
	root.add_child(title)
	var hints := Label.new()
	hints.text = "WASD  WALK     MOUSE  LOOK     SHIFT  HURRY     ESC  RELEASE MOUSE"
	hints.add_theme_font_override("font", font)
	hints.add_theme_font_size_override("font_size", 22)
	hints.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hints.position = Vector2(24, -42)
	hints.modulate = Color("d4c8ad")
	root.add_child(hints)
	overlay = root


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		player.rotate_y(-event.relative.x * 0.0022)
		pitch = clampf(pitch - event.relative.y * 0.0022, -1.4, 1.4)
		camera.rotation.x = pitch
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
		elif event.physical_keycode == KEY_F1:
			overlay.visible = not overlay.visible
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	if player == null:
		return
	var move := Vector2.ZERO
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or "--hab-test" in OS.get_cmdline_user_args() or "--longhaul-test" in OS.get_cmdline_user_args():
		move = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := player.basis * Vector3(move.x, 0, move.y)
	var speed := 3.3 if Input.is_action_pressed("sprint") else 2.15
	player.velocity.x = direction.x * speed
	player.velocity.z = direction.z * speed
	player.velocity.y = -0.4 if player.is_on_floor() else player.velocity.y - 15 * delta
	player.move_and_slide()


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _selftest() -> void:
	await _frames(30)
	var ok := player.is_on_floor()
	print("HAB floor: ", ok)
	Input.action_press("move_forward")
	await _frames(180)
	Input.action_release("move_forward")
	var walked := player.position.z < -2.5 and player.position.y < 0.15
	ok = ok and walked
	print("HAB unobstructed center aisle: ", walked)
	Input.action_press("move_forward")
	await _frames(130)
	Input.action_release("move_forward")
	var terminal_stops := player.position.z > -4.7 and player.position.z < -4.0
	ok = ok and terminal_stops
	print("HAB engineering equipment collision: ", terminal_stops)
	Input.action_press("move_back")
	await _frames(140)
	Input.action_release("move_back")
	Input.action_press("move_right")
	await _frames(130)
	Input.action_release("move_right")
	var counter_stops := player.position.x < 1.85 and player.position.x > 1.5
	ok = ok and counter_stops
	print("HAB galley collision: ", counter_stops)
	Input.action_press("move_left")
	await _frames(200)
	Input.action_release("move_left")
	var furniture_stops := player.position.x > -1.3 and player.position.y < 0.15
	ok = ok and furniture_stops
	print("HAB furniture collision: ", furniture_stops)
	print("HAB solids: ", solid_count)
	print("HAB TEST ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)


func _capture() -> void:
	await _frames(40)
	await RenderingServer.frame_post_draw
	var args := OS.get_cmdline_user_args()
	var index := args.find("--hab-capture")
	var dest := args[index + 1] if index + 1 < args.size() else "/tmp/hab-preview.png"
	var err := get_viewport().get_texture().get_image().save_png(dest)
	print("HAB capture: ", dest, " status ", err)
	get_tree().quit(0 if err == OK else 1)
