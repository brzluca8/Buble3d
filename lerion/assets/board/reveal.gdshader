shader_type spatial;
render_mode unshaded, depth_draw_never, shadows_disabled;
uniform float sweep = 0.0;
varying float height;
void vertex() {
	height = VERTEX.y;
	VERTEX += NORMAL * 0.006;
}
void fragment() {
	float band = 1.0 - smoothstep(0.02,0.38,abs(height - mix(-0.5,3.9,sweep)));
	ALBEDO = vec3(1.0,0.76,0.35);
	ALPHA = band * 0.69;
}
