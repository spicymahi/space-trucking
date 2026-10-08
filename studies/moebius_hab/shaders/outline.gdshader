shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;
uniform float stroke = 0.0013;
void vertex() {
    VERTEX += NORMAL * stroke;
}
void fragment() {
    ALBEDO = vec3(0.023,0.035,0.043);
}
