shader_type spatial;
render_mode specular_disabled;
uniform vec4 base_color : source_color = vec4(0.8,0.8,0.7,1.0);
void fragment() {
    ALBEDO = base_color.rgb;
    ROUGHNESS = 1.0;
    SPECULAR = 0.0;
}
void light() {
    float n = max(dot(NORMAL,LIGHT),0.0);
    float broad_light = mix(n,smoothstep(0.08,0.80,n),0.68);
    DIFFUSE_LIGHT += broad_light * ATTENUATION * LIGHT_COLOR / PI;
}
