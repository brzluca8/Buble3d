shader_type spatial;
// Bula din jurul fiecărui simbol: doar un contur subțire irizat (Fresnel), fără reflexii peste
// obiect, ca simbolul să se vadă clar. `glow` = simbol câștigător (conturul devine auriu).
render_mode blend_mix, depth_draw_never, unshaded, cull_back, shadows_disabled;

instance uniform float glow = 0.0;

void fragment() {
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.5);
	vec3 irid = 0.5 + 0.5 * cos(6.28318 * (f * 1.4 + vec3(0.0, 0.33, 0.67)) + TIME * 0.3);
	vec3 col = mix(vec3(0.9, 0.95, 1.0), irid, 0.7);
	col = mix(col, vec3(1.0, 0.78, 0.28) * 2.4, glow);
	ALBEDO = col * (0.8 + 1.0 * f);
	ALPHA = clamp(f * (0.85 + glow * 0.6) + glow * 0.06, 0.0, 1.0);
}
