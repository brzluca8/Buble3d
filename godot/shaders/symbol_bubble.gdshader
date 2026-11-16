shader_type spatial;
// Bula lucioasă din jurul fiecărui simbol: centru transparent, margine irizată (Fresnel),
// două reflexii fixe față de cameră (sus-stânga mare, jos-dreapta mică). `glow` = simbol câștigător.
render_mode blend_mix, depth_draw_never, unshaded, cull_back, shadows_disabled;

instance uniform float glow = 0.0;

void fragment() {
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.4);
	vec3 irid = 0.5 + 0.5 * cos(6.28318 * (f * 1.4 + vec3(0.0, 0.33, 0.67)) + TIME * 0.3);
	vec3 col = mix(vec3(0.85, 0.9, 1.0), irid, 0.8 * f);
	float hl = smoothstep(0.86, 0.97, dot(NORMAL, normalize(vec3(-0.45, 0.6, 0.66))));
	float hl2 = smoothstep(0.94, 0.99, dot(NORMAL, normalize(vec3(0.5, -0.45, 0.74)))) * 0.5;
	col = mix(col, vec3(1.0, 0.78, 0.28) * 2.2, glow * (0.4 + f));
	ALBEDO = col * (0.6 + 1.2 * f) + vec3(hl + hl2) * 1.6;
	ALPHA = clamp(0.03 + f * 0.75 + hl * 0.9 + hl2 + glow * (0.12 + f * 0.5), 0.0, 1.0);
}
