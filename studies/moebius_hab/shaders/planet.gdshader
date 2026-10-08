shader_type spatial;
render_mode unshaded;
void fragment() {
    float y = UV.y;
    float shift=0.003*sin(UV.x*80.0+y*220.0)+0.0014*sin(UV.x*141.0-y*301.0);
    float band=sin((y+shift)*116.0)+0.35*sin((y+shift)*279.0);
    vec3 cream=vec3(0.91,0.84,0.66);
    vec3 orange=vec3(0.76,0.59,0.40);
    vec3 blue=vec3(0.60,0.70,0.76);
    vec3 col=mix(cream,orange,smoothstep(-0.3,0.6,band)*0.53);
    col=mix(col,blue,smoothstep(0.64,0.91,sin(y*49.0))*0.56);
    float limb=pow(max(dot(NORMAL,VIEW),0.0),0.20);
    ALBEDO=col*mix(0.72,1.0,limb);
}
