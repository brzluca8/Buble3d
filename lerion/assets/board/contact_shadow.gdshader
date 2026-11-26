shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
void fragment() {
	float r = length(UV * 2.0 - 1.0);
	ALBEDO = vec3(0.12, 0.15, 0.17);
	ALPHA = 0.31 * (1.0 - smoothstep(0.25, 1.0, r));
}
