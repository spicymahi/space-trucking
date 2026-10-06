extends RefCounted
## Blender supplies the surfaces; existing nodes remain authoritative for gameplay.
const MODEL := preload("res://assets/ships/longhaul/longhaul_playable.glb")

static func mechanical_roots(ship: Node) -> Dictionary:
	var result := {
		"Hab_FoldingTable": ship.hab_module.table_pivot,
		"Hab_Drawer": ship.hab_module.drawer,
		"Engineering_ServiceCover": ship.engineering_module.service_cover,
		"Engineering_PumpRotor": ship.engineering_module.pump_rotor,
		"Cargo_TransferCase": ship.cargo_module.held_crate,
	}
	for key in ["wash", "air"]:
		for i in 2:
			result["Service_%s_Door_%d" % [key, i]] = ship.service_module.doors[key].leaves[i]
	for i in 2:
		result["Loading_Hatch_%d" % i] = ship.loading_module.leaves[i]
	return result

static func live_visuals(ship: Node) -> Array:
	var result: Array = [ship.hab_module.reading_lens, ship.service_module.pressure_lamp, ship.engineering_module.pump_lamp]
	result.append_array(ship.engineering_module.status_bars)
	result.append_array(ship.engineering_module.fuse_lenses)
	result.append_array(ship.cargo_module.lock_lamps)
	result.append_array(ship.loading_module.status_lights)
	for child in ship.cargo_module.get_children():
		if child.has_meta("jaw_side"):
			result.append(child)
	for flow in [ship.service_module.shower_flow, ship.service_module.tap_flow]:
		if is_instance_valid(flow): result.append(flow)
	if is_instance_valid(ship.ramp_pivot): result.append(ship.ramp_pivot)
	return result

static func under_any(node: Node, roots: Array) -> bool:
	for parent in roots:
		if is_instance_valid(parent) and (node == parent or parent.is_ancestor_of(node)):
			return true
	return false

static func install(ship: Node3D, cockpit: Node3D) -> Node3D:
	var model: Node3D = MODEL.instantiate()
	model.name = "BlenderLonghaul"
	# Hide surfaces only. Labels, colliders, triggers, lights, and controllers stay live.
	var keep := live_visuals(ship)
	for mesh in ship.find_children("*", "MeshInstance3D", true, false):
		if not under_any(mesh, keep): mesh.hide()
	ship.add_child(model)
	var roots := mechanical_roots(ship)
	var moved := 0
	var displays := 0
	for node in model.find_children("*", "Node3D", true, false):
		var extras: Dictionary = node.get_meta("extras", {})
		var key: String = extras.get("game_mover", "")
		if roots.has(key):
			# Keep the imported axis conversion inside the visual root. Replacing it
			# with identity would rotate doors and furniture away from their colliders.
			node.reparent(roots[key], true)
			node.set_meta("binding_pose", node.transform)
			moved += 1
		var binding: String = extras.get("display_binding", "")
		if not binding.is_empty():
			var index := int(binding.split("_")[1])
			var panel: Node3D = cockpit.monitor_faces[index]
			var old: MeshInstance3D = panel.get_meta("screen_mesh")
			node.material_override = old.material_override
			panel.set_meta("screen_mesh", node)
			displays += 1
	assert(moved == 11, "Missing Blender mechanical bindings")
	assert(displays == 8, "Missing Blender cockpit displays")
	ship.set_meta("blender_movers", moved)
	ship.set_meta("blender_displays", displays)
	print("BLENDER ASSETS ACTIVE: ", moved, " mechanical roots, ", displays, " live displays")
	return model
