extends Node3D
## Isolated visual walkthrough; never creates a flight state or touches saves.
var walker: CharacterBody3D
var camera: Camera3D
var pitch := 0.0
var ready_to_walk := false

func v(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])

func _ready() -> void:
	DisplayServer.window_set_title("Longhaul — Blender interior preview")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/longhaul_v3/source/interior_layout.json"))
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_file(ProjectSettings.globalize_path("res://art/longhaul_v3/exports/longhaul_complete.glb"), state)
	if error != OK:
		push_error("Blender ship could not load: " + str(error))
		return
	var ship := document.generate_scene(state)
	add_child(ship)
	# Use the approved simple collision envelopes, not expensive detailed triangle collision.
	var body := StaticBody3D.new()
	add_child(body)
	for item in data.colliders:
		if item.shape != "BoxShape3D":
			continue
		var shape := BoxShape3D.new()
		shape.size = v(item.size)
		var collider := CollisionShape3D.new()
		collider.shape = shape
		var t: Array = item.transform
		collider.transform = Transform3D(Basis(v(t[0]), v(t[1]), v(t[2])), v(t[3]))
		body.add_child(collider)
	for item in data.lights:
		var light := OmniLight3D.new()
		light.position = v(item.position)
		light.light_color = Color(item.color[0], item.color[1], item.color[2])
		light.light_energy = item.energy * 1.7
		light.omni_range = item.range
		light.shadow_enabled = true
		add_child(light)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("09131c")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("a7bbce")
	settings.ambient_light_energy = 0.22
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = settings
	add_child(environment)
	walker = CharacterBody3D.new()
	walker.floor_snap_length = 0.25
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.25
	capsule.height = 1.7
	var collision := CollisionShape3D.new()
	collision.shape = capsule
	collision.position.y = 0.85
	walker.add_child(collision)
	camera = Camera3D.new()
	camera.position.y = 1.62
	camera.near = 0.035
	camera.fov = 80
	walker.add_child(camera)
	add_child(walker)
	walker.position = Vector3(0, 0.12, -4.5)
	camera.current = true
	var layer := CanvasLayer.new()
	add_child(layer)
	var label := Label.new()
	label.position = Vector2(20, 18)
	label.text = "LONGHAUL / BLENDER WALKTHROUGH\nWASD walk · Mouse look · Shift hurry · Esc release mouse\n1 Cockpit · 2 Hab · 3 Service · 4 Cargo · 5 Engineering\nVisual preview — terminals and machinery are not interactive yet"
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(label)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	ready_to_walk = true
	print("BLENDER WALKTHROUGH READY: ", data.colliders.size(), " collision envelopes")

func _unhandled_input(event: InputEvent) -> void:
	if not ready_to_walk:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		walker.rotate_y(-event.relative.x * 0.0025)
		pitch = clampf(pitch - event.relative.y * 0.0025, -1.45, 1.45)
		camera.rotation.x = pitch
	if event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		var places := {KEY_1: Vector3(0, 0.15, -10.5), KEY_2: Vector3(0, 0.15, -4.5), KEY_3: Vector3(0, 0.15, -2.5), KEY_4: Vector3(0, 0.15, 1.0), KEY_5: Vector3(0, 0.15, 10.5)}
		if places.has(event.keycode):
			walker.position = places[event.keycode]
			walker.velocity = Vector3.ZERO
			walker.rotation = Vector3.ZERO
			pitch = 0.0
			camera.rotation = Vector3.ZERO

func _physics_process(delta: float) -> void:
	if not ready_to_walk:
		return
	var direction := Vector3.ZERO
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		direction = Vector3(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), 0, float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	direction = walker.basis * direction.normalized()
	var speed := 3.5 if Input.is_physical_key_pressed(KEY_SHIFT) else 2.0
	walker.velocity.x = direction.x * speed
	walker.velocity.z = direction.z * speed
	walker.velocity.y = -0.5 if walker.is_on_floor() else walker.velocity.y - 18.0 * delta
	walker.move_and_slide()
	if walker.position.y < -4:
		walker.position = Vector3(0, 0.15, -4.5)
		walker.velocity = Vector3.ZERO
