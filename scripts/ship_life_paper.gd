extends Node3D
## A carried, textured sheet in camera space, not another terminal window.
const FONT = preload("res://assets/fonts/VT323-Regular.ttf")
var page: SubViewport
var ink: Label
var sheet: MeshInstance3D
var motion: Tween
var closeup := false
var last_text := ""

func build(camera: Camera3D) -> void:
	camera.add_child(self)
	name = "CarriedDailyChecklist"
	page = SubViewport.new()
	page.size = Vector2i(700, 940)
	page.disable_3d = true
	page.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(page)
	var background := ColorRect.new()
	background.color = Color("e9ddbd")
	background.size = Vector2(700, 940)
	page.add_child(background)
	for x in [18, 667]:
		for y in range(28, 930, 42):
			var hole := ColorRect.new()
			hole.position = Vector2(x, y)
			hole.size = Vector2(12, 12)
			hole.color = Color("b5aa8b")
			page.add_child(hole)
	ink = Label.new()
	ink.position = Vector2(53, 34)
	ink.size = Vector2(590, 870)
	ink.add_theme_font_override("font", FONT)
	ink.add_theme_font_size_override("font_size", 34)
	ink.add_theme_color_override("font_color", Color("26322d"))
	ink.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(ink)
	sheet = MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.30, 0.403)
	sheet.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_texture = page.get_texture()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = true
	material.render_priority = 8
	sheet.material_override = material
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sheet)
	set_closeup(false, true)
	hide()

func set_text(words: String) -> void:
	if words == last_text: return
	last_text = words
	ink.text = "LONGHAUL / DAILY WORK ORDER\n--------------------------------\n" + words + "\n\n--------------------------------\nTAB  raise / lower     J  stow\nDEL  recycle"

func set_closeup(value: bool, instant := false) -> void:
	closeup = value
	if motion: motion.kill()
	var target := Vector3(0, -0.005, -0.32) if closeup else Vector3(-0.30, -0.21, -0.60)
	var angles := Vector3.ZERO if closeup else Vector3(0.04, 0.10, 0.10)
	if instant:
		position = target
		rotation = angles
	else:
		motion = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		motion.tween_property(self, "position", target, 0.20)
		motion.tween_property(self, "rotation", angles, 0.20)
