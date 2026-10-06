extends RefCounted
var ok := true
func check(label: String, result: bool) -> void:
	print("BLENDER ", label, ": ", result)
	ok = ok and result

func run(ship: Node3D) -> bool:
	var adapter = preload("res://scripts/longhaul_blender_assets.gd")
	check("All mechanical and display bindings installed", ship.get_meta("blender_movers", 0) == 11 and ship.get_meta("blender_displays", 0) == 8)
	for key in adapter.mechanical_roots(ship):
		var parent: Node3D = adapter.mechanical_roots(ship)[key]
		var found: Node3D
		for child in parent.get_children():
			if child.get_meta("extras", {}).get("game_mover", "") == key: found = child
		check(key + " follows its gameplay controller", is_instance_valid(found) and found.position.length() < 0.001)
		if is_instance_valid(found):
			var before: Transform3D = parent.transform
			parent.position += Vector3(0.02, 0.03, 0.04)
			check(key + " mesh stays aligned after movement", found.global_transform.is_equal_approx(parent.global_transform * found.get_meta("binding_pose")))
			parent.transform = before
			if "Door" in key or "Hatch" in key or "ServiceCover" in key:
				var old_bounds := bounds(parent, found)
				var new_bounds := bounds(found)
				check(key + " visible geometry aligns with original collision envelope", old_bounds.position.distance_to(new_bounds.position) < 0.04 and old_bounds.end.distance_to(new_bounds.end) < 0.04)
	for terminal in ship.terminals:
		var screen: MeshInstance3D = terminal.panel.get_meta("screen_mesh")
		check(terminal.kind + " uses a live Blender screen", screen.is_visible_in_tree() and screen.get_meta("extras", {}).has("display_binding") and screen.material_override.albedo_texture == terminal.viewport.get_texture())
	for indicator in adapter.live_visuals(ship):
		if indicator is MeshInstance3D:check("Live indicator remains visible", indicator.visible)
	var transparent := 0
	for mesh in ship.get_node("BlenderLonghaul").find_children("*", "MeshInstance3D", true, false):
		for i in mesh.mesh.get_surface_count():
			var mat: Material = mesh.get_active_material(i)
			if mat is BaseMaterial3D and mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED: transparent += 1
	check("Windshield and hab glazing remain transparent", transparent >= 3)
	check("Runtime paper printer still exists", is_instance_valid(ship.flight_sheet.feed) and is_instance_valid(ship.flight_sheet.paper_bin))
	return ok

func bounds(parent: Node3D, exclude: Node = null) -> AABB:
	var result := AABB()
	var first := true
	for mesh in parent.find_children("*", "MeshInstance3D", true, false):
		if exclude != null and exclude.is_ancestor_of(mesh): continue
		var box: AABB = mesh.global_transform * mesh.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result
