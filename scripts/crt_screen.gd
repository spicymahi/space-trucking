class_name CrtScreen
extends Node3D
## A cockpit CRT: a SubViewport with phosphor text, shown on a quad in 3D.

const SCANLINES := """
shader_type canvas_item;
void fragment() {
	float l = step(0.5, fract(FRAGCOORD.y / 4.0));
	vec2 c = UV - 0.5;
	float v = smoothstep(0.35, 0.75, length(c));
	COLOR = vec4(0.0, 0.0, 0.0, 0.22 * l + 0.55 * v);
}
"""

var label: Label
var viewport: SubViewport
var phosphor: Color


func _init(size_m := Vector2(2.0, 1.5), px := Vector2i(512, 384), p_phosphor := Vox.PHOS_GREEN, font_size := 30) -> void:
	phosphor = p_phosphor
	viewport = SubViewport.new()
	viewport.size = px
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.disable_3d = true
	add_child(viewport)
	var bg := ColorRect.new()
	bg.color = Color("0d2414") if phosphor == Vox.PHOS_GREEN else Color("2a1806")
	bg.size = px
	viewport.add_child(bg)
	label = Label.new()
	label.position = Vector2(22, 14)
	label.size = Vector2(px) - Vector2(44, 28)
	label.add_theme_font_override("font", GameState.font_crt)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", phosphor)
	label.add_theme_constant_override("line_spacing", -4)
	viewport.add_child(label)
	var lines := ColorRect.new()
	lines.size = px
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SCANLINES
	sm.shader = sh
	lines.material = sm
	viewport.add_child(lines)

	var quad := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = size_m
	quad.mesh = qm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = viewport.get_texture()
	m.emission_enabled = true
	m.emission_texture = viewport.get_texture()
	m.emission_energy_multiplier = 0.6
	quad.material_override = m
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(quad)
	# Bezel
	Vox.box(self, Vector3(0, 0, -0.06), Vector3(size_m.x + 0.24, size_m.y + 0.24, 0.1), Color("3a3029"))


func set_text(t: String) -> void:
	if label.text != t:
		label.text = t
