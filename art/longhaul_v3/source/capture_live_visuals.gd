extends "res://art/longhaul_v3/source/capture_interior.gd"
func capture() -> void:
	ship = CaptureShip.new()
	root.add_child(ship)
	ship.process_mode = Node.PROCESS_MODE_DISABLED
	var live := preload("res://scripts/longhaul_blender_assets.gd").live_visuals(ship)
	# The printer is built by the gameplay sheet controller, after asset installation.
	for node in ship.find_children("*", "MeshInstance3D", true, false):
		if node.mesh is QuadMesh and node.material_override is ShaderMaterial:
			live.append(node.get_parent())
	var records_out: Array = []
	for node in ship.find_children("*", "MeshInstance3D", true, false):
		if preload("res://scripts/longhaul_blender_assets.gd").under_any(node, live) and node.mesh is BoxMesh:
			records_out.append({"position": v(node.global_position), "size": v(node.mesh.size)})
	FileAccess.open("res://art/longhaul_v3/source/live_visuals.json", FileAccess.WRITE).store_string(JSON.stringify(records_out))
	print("Captured ", records_out.size(), " live surfaces")
	ship.queue_free()
	quit()
