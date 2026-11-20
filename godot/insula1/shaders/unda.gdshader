// Insula 1: unda care se întinde când Orion aterizează pe o căsuță (pătrat orizontal, UV 0..1).
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

// un singur material pentru toate căsuțele: progresul și culoarea sunt pe instanță
instance uniform float progres = 0.0;   // 0 -> 1 în timpul animației
instance uniform vec3 culoare = vec3(1.0, 0.92, 0.62);

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float cerc = smoothstep(0.09, 0.0, abs(r - (0.35 + 0.65 * progres))) * (1.0 - progres);
	ALBEDO = culoare * cerc * 1.4;
	ALPHA = cerc;
}
