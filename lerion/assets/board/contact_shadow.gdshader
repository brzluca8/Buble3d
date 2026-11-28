shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
void fragment() {
	float r = length(UV * 2.0 - 1.0);
	// Darker core and a tighter edge ground Lerik more firmly without a hard outline.
	ALBEDO = vec3(0.07, 0.10, 0.13);
	ALPHA = 0.46 * (1.0 - smoothstep(0.18, 0.95, r)) + 0.12 * (1.0 - smoothstep(0.0, 0.5, r));
}
