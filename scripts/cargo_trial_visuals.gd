extends RefCounted
## Dock and packing equipment for the cargo trial. Gameplay and collision rules
## belong to the trial controller; these helpers only author their visible parts.

const CREAM := Color("b9b39b")
const LIGHT := Color("ddd1b0")
const DARK := Color("252f2b")
const EDGE := Color("64716a")
const ORANGE := Color("b96934")
const GREEN := Color("9de6b0")
const AMBER := Color("e0bd72")
const FONT = preload("res://assets/fonts/VT323-Regular.ttf")
static var _materials: Dictionary = {}


static func box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, solid := false) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	var geometry := BoxMesh.new()
	geometry.size = size
	item.mesh = geometry
	item.position = pos
	item.material_override = _material(color)
	parent.add_child(item)
	if solid:
		_collider(parent, pos, size)
	return item


static func label(parent: Node3D, words: String, pos: Vector3, size := 0.002) -> Label3D:
	var item := Label3D.new()
	item.font = FONT
	item.font_size = 64
	item.pixel_size = size
	item.text = words
	item.modulate = LIGHT
	item.outline_size = 0
	item.position = pos
	item.no_depth_test = false
	parent.add_child(item)
	return item


static func crate(id: int, size: Vector3i, commodity: String, cell := 0.45) -> Node3D:
	var root := Node3D.new()
	root.name = "CargoCase_%02d" % id
	root.set_meta("cargo_id", id)
	var dimensions := Vector3(size) * cell - Vector3.ONE * 0.025
	var palette: Array[Color] = [Color("849c93"), Color("b3a77f"), Color("919788"), Color("a98a65"), Color("7e9598")]
	var tint: Color = palette[posmod(id, palette.size())]
	box(root, Vector3.ZERO, dimensions, tint)
	# Corner armour and straps remain inside the case's reserved grid footprint.
	var width := minf(0.045, dimensions.x * 0.1)
	for x_sign in [-1.0, 1.0]:
		for z_sign in [-1.0, 1.0]:
			box(root, Vector3(x_sign * (dimensions.x - width) * 0.5, 0, z_sign * (dimensions.z - width) * 0.5), Vector3(width + 0.006, dimensions.y + 0.006, width + 0.006), DARK)
	for y_sign in [-1.0, 1.0]:
		box(root, Vector3(0, y_sign * (dimensions.y * 0.5 - 0.025), 0), Vector3(dimensions.x + 0.009, 0.036, dimensions.z + 0.009), EDGE)
	# Recessed grip and label on every vertical face: IDs stay visible after rotation.
	for side in 4:
		var face := Node3D.new()
		face.name = "CaseFace_%d" % side
		root.add_child(face)
		face.rotation.y = side * PI * 0.5
		var face_width: float = dimensions.x if side % 2 == 0 else dimensions.z
		var depth: float = dimensions.z if side % 2 == 0 else dimensions.x
		face.position = Basis(Vector3.UP, face.rotation.y) * Vector3(0, 0, depth * 0.5 + 0.003)
		var tag_width := minf(face_width * 0.75, 0.66)
		box(face, Vector3(0, -dimensions.y * 0.12, 0), Vector3(tag_width, minf(0.16, dimensions.y * 0.38), 0.004), LIGHT)
		var words := "%02d / %s" % [id, commodity.to_upper()]
		var tag := label(face, words, Vector3(0, -dimensions.y * 0.12, 0.004), minf(0.00085, tag_width / maxf(words.length() * 30.0, 1.0)))
		tag.modulate = DARK
		var grip_width := minf(face_width * 0.48, 0.28)
		box(face, Vector3(0, dimensions.y * 0.26, 0), Vector3(grip_width, 0.062, 0.005), DARK)
		box(face, Vector3(0, dimensions.y * 0.26 + 0.019, 0.004), Vector3(grip_width * 0.72, 0.022, 0.005), EDGE)
		for x in [-0.38, 0.38]:
			box(face, Vector3(x * face_width, 0, 0), Vector3(0.026, dimensions.y * 0.87, 0.004), ORANGE)
		_batch_meshes(face)
	_batch_meshes(root)
	return root


static func rack() -> Node3D:
	var root := Node3D.new()
	root.name = "PackingRack"
	# Coordinates describe the usable packing volume, not a shelf partition.
	# The unobstructed loading face is x=0; all rails sit outside that volume.
	box(root, Vector3(0.45, -0.065, 0.90), Vector3(1.02, 0.13, 1.92), DARK)
	box(root, Vector3(0.96, 0.70, 0.90), Vector3(0.09, 1.53, 1.92), EDGE)
	for z in [-0.047, 1.847]:
		box(root, Vector3(0.94, 0.70, z), Vector3(0.10, 1.53, 0.08), ORANGE)
		box(root, Vector3(0.46, 1.43, z), Vector3(1.08, 0.09, 0.08), ORANGE)
		box(root, Vector3(0.46, -0.007, z), Vector3(1.08, 0.037, 0.07), ORANGE)
	box(root, Vector3(-0.045, 1.43, 0.9), Vector3(0.075, 0.09, 1.96), ORANGE)
	# Non-raised grid marks on the bed and back plate match the 45 cm packing grid.
	for i in 3:
		box(root, Vector3(i * 0.45, 0.002, 0.90), Vector3(0.008, 0.003, 1.80), EDGE)
	for i in 5:
		box(root, Vector3(0.45, 0.002, i * 0.45), Vector3(0.90, 0.003, 0.008), EDGE)
		box(root, Vector3(0.912, 0.675, i * 0.45), Vector3(0.003, 1.35, 0.009), DARK)
	for i in 4:
		box(root, Vector3(0.912, i * 0.45, 0.90), Vector3(0.003, 0.009, 1.80), DARK)
	for z in [0.12, 0.58, 1.22, 1.68]:
		box(root, Vector3(-0.021, -0.032, z), Vector3(0.029, 0.065, 0.11), LIGHT)
		box(root, Vector3(0.91, 1.44, z), Vector3(0.032, 0.025, 0.07), DARK)
	# Labels describe the exact local cells used by the optional packing plan.
	# They stay outside the storage volume and remain visible when a rack is full.
	box(root, Vector3(-0.045, -0.064, 0.9), Vector3(0.075, 0.13, 1.96), DARK)
	for i in 4:
		var length_label := label(root, str(i + 1), Vector3(-0.085, -0.06, (i + 0.5) * 0.45), 0.0014)
		length_label.rotation.y = -PI * 0.5
		length_label.modulate = AMBER
	box(root, Vector3(-0.04, 0.70, -0.055), Vector3(0.075, 1.53, 0.07), ORANGE)
	for i in 3:
		var height_label := label(root, str(i + 1), Vector3(-0.081, (i + 0.5) * 0.45, -0.054), 0.00082)
		height_label.rotation.y = -PI * 0.5
	for i in 2:
		var depth_label := label(root, "%d / %s" % [i + 1, "FRONT" if i == 0 else "REAR"], Vector3((i + 0.5) * 0.45, 1.435, -0.092), 0.00062)
		depth_label.rotation.y = PI
	var description := label(root, "45 CM / RESTRAINT GRID", Vector3(-0.086, 1.435, 0.90), 0.00070)
	description.rotation.y = -PI * 0.5
	_batch_meshes(root)
	return root


static func dock(parent: Node3D) -> Dictionary:
	var root := Node3D.new()
	root.name = "CargoTrialDock"
	parent.add_child(root)
	# Ship's open ramp meets this floor at the existing loading deck elevation.
	box(root, Vector3(0, -1.34, 20.5), Vector3(28, 0.28, 21), Color("505c57"), true)
	for x in range(-14, 15, 2):
		box(root, Vector3(x, -1.196, 20.5), Vector3(0.018, 0.006, 21), DARK)
	for z in range(10, 32, 2):
		box(root, Vector3(0, -1.194, z), Vector3(28, 0.006, 0.018), DARK)
	# Central traffic corridor always stays clear of cargo and terminals.
	for x in [-2.0, 2.0]:
		box(root, Vector3(x, -1.187, 22.2), Vector3(0.075, 0.008, 17.0), LIGHT)
		for z in range(15, 31):
			box(root, Vector3(x + signf(x) * 0.13, -1.183, z), Vector3(0.045, 0.008, 0.38), ORANGE)
	var arrow := label(root, "SHIP / LOADING RAMP", Vector3(0, -1.176, 19.7), 0.0022)
	arrow.rotation.x = -PI / 2
	arrow.modulate = LIGHT
	var aisle := label(root, "KEEP WALKWAY CLEAR", Vector3(0, -1.176, 28.5), 0.0020)
	aisle.rotation.x = -PI / 2
	# The rear station wall anchors the test space in a working freight terminal.
	box(root, Vector3(0, 1.35, 31.13), Vector3(28.3, 5.1, 0.26), CREAM, true)
	box(root, Vector3(0, -0.56, 30.96), Vector3(28, 1.26, 0.08), DARK)
	box(root, Vector3(0, 3.15, 30.94), Vector3(28, 0.13, 0.10), ORANGE)
	for x in range(-12, 13, 4):
		box(root, Vector3(x, 1.35, 30.94), Vector3(0.14, 5.08, 0.12), EDGE)
		for y in [0.25, 2.5]:
			box(root, Vector3(x, y, 30.84), Vector3(0.24, 0.10, 0.12), ORANGE)
	var sign_text := label(root, "AUREL / FREIGHT EXCHANGE", Vector3(0, 2.60, 30.76), 0.0048)
	sign_text.rotation.y = PI
	sign_text.modulate = DARK
	var sign_small := label(root, "BERTH 01     •     LONGHAUL     •     DOCK SERVICES", Vector3(0, 2.11, 30.75), 0.0019)
	sign_small.rotation.y = PI
	sign_small.modulate = DARK
	for x in [-13.65, 13.65]:
		box(root, Vector3(x, -0.54, 21), Vector3(0.15, 1.32, 20), EDGE, true)
		box(root, Vector3(x, 0.15, 21), Vector3(0.20, 0.085, 20), ORANGE)
		for z in [11.5, 17.5, 23.5, 29.5]:
			box(root, Vector3(x, 1.45, z), Vector3(0.21, 5.3, 0.21), DARK)
	# Overhead cable trays and light bars terminate outside the Longhaul hull.
	for z in [19.1, 24.0, 29.0]:
		box(root, Vector3(0, 4.10, z), Vector3(27.5, 0.21, 0.22), DARK)
		for x in [-8.0, 0.0, 8.0]:
			box(root, Vector3(x, 3.96, z), Vector3(3.8, 0.065, 0.35), LIGHT).material_override = _material(LIGHT, true)
			var lamp := OmniLight3D.new()
			lamp.position = Vector3(x, 3.7, z)
			lamp.light_color = Color("ffe4b8")
			lamp.light_energy = 1.65
			lamp.omni_range = 9.0
			lamp.shadow_enabled = false
			root.add_child(lamp)
	# 12 wide marked spots per apron, with clear gaps for carrying and retrieval.
	var pickup_positions: Array[Vector3] = []
	var drop_positions: Array[Vector3] = []
	for row in 4:
		for column in 3:
			var x := 5.35 + column * 2.60
			var z := 21.05 + row * 2.55
			pickup_positions.append(Vector3(-x, -1.2, z))
			drop_positions.append(Vector3(x, -1.2, z))
			_apron_slot(root, Vector3(-x, -1.185, z), row * 3 + column + 1, ORANGE)
			_apron_slot(root, Vector3(x, -1.185, z), row * 3 + column + 1, GREEN)
	_zone_title(root, "01 / COLLECTION", Vector3(-8.0, -1.172, 19.30), ORANGE)
	_zone_title(root, "02 / DELIVERY", Vector3(8.0, -1.172, 19.30), GREEN)
	var terminal := _terminal(root, Vector3(-3.0, -1.2, 18.0), "contract", "CONTRACTS", "FREIGHT EXCHANGE\nAVAILABLE WORK\n[F] CONTRACTS")
	var completion := _terminal(root, Vector3(3.0, -1.2, 18.0), "complete", "DELIVERY", "DELIVERY RECEIPT\nAWAITING CARGO\n[F] COMPLETE")
	var transit := _terminal(root, Vector3(2.5, -1.2, 16.5), "depart", "DEPARTURE", "BERTH CONTROL\nSECURE CARGO FIRST\n[F] DEPARTURE")
	transit.rotation.y = -PI * 0.5
	_batch_meshes(root)
	return {"terminal": terminal, "completion": completion, "transit": transit, "pickup_positions": pickup_positions, "drop_positions": drop_positions}


static func _apron_slot(parent: Node3D, pos: Vector3, index: int, tint: Color) -> void:
	for side in [-1.0, 1.0]:
		box(parent, pos + Vector3(side * 1.0, 0, 0), Vector3(0.037, 0.006, 2.0), tint)
		box(parent, pos + Vector3(0, 0, side * 1.0), Vector3(2.0, 0.006, 0.037), tint)
	var number := label(parent, "%02d" % index, pos + Vector3(-0.78, 0.006, 0.82), 0.00145)
	number.rotation.x = -PI * 0.5
	number.modulate = tint


static func _zone_title(parent: Node3D, words: String, pos: Vector3, tint: Color) -> void:
	var text := label(parent, words, pos, 0.0036)
	text.rotation.x = -PI * 0.5
	text.modulate = tint


static func _terminal(parent: Node3D, pos: Vector3, action: String, title: String, screen_words: String) -> Node3D:
	var root := Node3D.new()
	root.name = "DockTerminal_" + action
	root.position = pos
	root.set_meta("action", action)
	parent.add_child(root)
	box(root, Vector3(0, 0.08, 0), Vector3(0.86, 0.16, 0.72), DARK)
	box(root, Vector3(0, 0.64, -0.025), Vector3(0.63, 1.07, 0.48), CREAM)
	box(root, Vector3(0, 0.54, 0.225), Vector3(0.50, 0.72, 0.025), EDGE)
	for i in 5:
		box(root, Vector3(0, 0.35 + i * 0.062, 0.244), Vector3(0.38, 0.027, 0.02), DARK)
	box(root, Vector3(0, 1.04, 0.07), Vector3(0.90, 0.10, 0.68), ORANGE)
	box(root, Vector3(0, 1.46, -0.06), Vector3(0.86, 0.72, 0.43), DARK)
	box(root, Vector3(0, 1.47, 0.166), Vector3(0.72, 0.53, 0.04), EDGE)
	box(root, Vector3(0, 1.47, 0.192), Vector3(0.65, 0.46, 0.018), Color("09271c"))
	var screen := label(root, screen_words, Vector3(0, 1.47, 0.207), 0.0010)
	screen.name = "StatusText"
	screen.modulate = GREEN
	label(root, title, Vector3(0, 1.96, 0.08), 0.00150)
	for i in 9:
		box(root, Vector3(-0.3 + i * 0.075, 1.111, 0.23), Vector3(0.056, 0.041, 0.078), ORANGE if i == 8 else LIGHT)
	box(root, Vector3(0.335, 1.21, 0.19), Vector3(0.044, 0.035, 0.022), GREEN).material_override = _material(GREEN, true)
	var body := _collider(root, Vector3(0, 0.93, 0), Vector3(0.92, 1.86, 0.69), action)
	body.name = "InteractionBody"
	_batch_meshes(root)
	return root


static func _collider(parent: Node3D, pos: Vector3, size: Vector3, action := "") -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)
	if not action.is_empty():
		body.set_meta("action", action)
	return body


static func _material(color: Color, glow := false) -> StandardMaterial3D:
	var key := color.to_html() + ("glow" if glow else "solid")
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.87
		if glow:
			material.emission_enabled = true
			material.emission = color
			material.emission_energy_multiplier = 1.2
		_materials[key] = material
	return _materials[key]


static func _batch_meshes(parent: Node3D) -> void:
	# Merge fixed cuboid fittings by material; retain labels and interactive roots.
	var groups: Dictionary = {}
	for child in parent.get_children():
		if child is MeshInstance3D and child.mesh != null and child.get_child_count() == 0:
			var material: Material = child.material_override
			if not groups.has(material):
				groups[material] = []
			groups[material].append(child)
	for material in groups:
		var meshes: Array = groups[material]
		if meshes.size() < 2:
			continue
		var builder := SurfaceTool.new()
		builder.begin(Mesh.PRIMITIVE_TRIANGLES)
		for mesh: MeshInstance3D in meshes:
			builder.append_from(mesh.mesh, 0, mesh.transform)
		var instance := MeshInstance3D.new()
		instance.name = "BatchedFittings"
		instance.mesh = builder.commit()
		instance.material_override = material
		parent.add_child(instance)
		for mesh: MeshInstance3D in meshes:
			parent.remove_child(mesh)
			mesh.free()
