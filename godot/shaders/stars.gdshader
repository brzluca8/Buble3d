shader_type spatial;
// Stele mici care sclipesc (MultiMesh de pătrate orientate spre cameră).
render_mode unshaded, blend_add, depth_draw_never, shadows_disabled, cull_disabled;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0, 0, 0), vec4(0, length(MODEL_MATRIX[1].xyz), 0, 0), vec4(0, 0, 1, 0), vec4(0, 0, 0, 1));
}

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float a = smoothstep(1.0, 0.0, d);
	a = a * a;
	float tw = 0.65 + 0.35 * sin(TIME * (1.0 + COLOR.a * 3.0) + COLOR.a * 40.0);
	ALBEDO = COLOR.rgb * 2.4 * tw;
	ALPHA = a * tw;
}
