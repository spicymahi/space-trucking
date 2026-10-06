extends SceneTree
func _init() -> void:
	for asset in ["longhaul_interior", "longhaul_complete"]:
		var state := GLTFState.new()
		var document := GLTFDocument.new()
		var path := ProjectSettings.globalize_path("res://art/longhaul_v3/exports/" + asset + ".glb")
		var error := document.append_from_file(path, state)
		if error != OK:
			push_error("GLB load failed: " + asset)
			quit(1)
			return
		var scene := document.generate_scene(state)
		if scene == null:
			quit(1)
			return
		print("VALIDATED ", asset, " nodes=", scene.find_children("*", "", true, false).size())
		scene.free()
	quit(0)
