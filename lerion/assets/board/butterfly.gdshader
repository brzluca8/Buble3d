shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D wings : source_color, filter_linear_mipmap;
void vertex() {
	float flap = 0.48 + 0.39 * sin(TIME * 18.0 + MODEL_MATRIX[3].x);
	VERTEX.y += abs(VERTEX.x) * sin(flap);
	VERTEX.x *= cos(flap);
}
void fragment() {
	vec4 pigment = texture(wings, UV);
	ALBEDO = pigment.rgb;
	ALPHA = pigment.a;
	ALPHA_SCISSOR_THRESHOLD = 0.48;
}
