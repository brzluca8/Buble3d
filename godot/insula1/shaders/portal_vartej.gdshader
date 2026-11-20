// Insula 1: vârtejul din portal (un dreptunghi pus chiar în fața panoului din arcadă, UV 0..1).
// Spirală cyan care se rotește și pulsează, centru luminos, margine moale în elipsă (nu acoperă stâlpii).
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, shadows_disabled, depth_draw_never;

uniform vec3 culoare_a : source_color = vec3(0.45, 0.95, 1.0);
uniform vec3 culoare_b : source_color = vec3(0.30, 0.55, 1.0);
uniform float viteza = 1.0;
uniform float intensitate = 1.8;

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float t = TIME * viteza;
	float spirala = sin(a * 3.0 - log(r + 0.04) * 5.0 + t * 2.4);
	float val = sin(a * 5.0 + r * 9.0 - t * 1.7);
	float v = clamp(0.5 + 0.4 * spirala + 0.15 * val, 0.0, 1.0);
	float puls = 0.85 + 0.15 * sin(t * 2.2);
	vec3 c = mix(culoare_b, culoare_a, v) + vec3(0.85) * smoothstep(0.4, 0.0, r);
	float masca = 1.0 - smoothstep(0.72, 1.0, r);
	ALBEDO = c * intensitate * puls;
	ALPHA = masca * (0.7 + 0.3 * v);
}
