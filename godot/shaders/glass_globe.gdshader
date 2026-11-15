shader_type spatial;
// Sticla globului: centru aproape transparent, margine luminoasă irizată (Fresnel),
// fără refracție (ieftin pe telefon). `back` = fața din spate, mai stinsă.
render_mode blend_mix, depth_draw_never, unshaded, shadows_disabled, cull_back;

uniform vec4 tint : source_color = vec4(0.72, 0.84, 1.0, 1.0);
uniform float rim_power = 2.6;
uniform float rim_strength = 1.3;
uniform float base_alpha = 0.035;
uniform float iridescence = 0.9;
uniform float pulse = 0.0;           // puls (ex. bula unui prieten care te-a vizitat)

void fragment() {
	float f = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), rim_power);
	vec3 irid = 0.5 + 0.5 * cos(6.28318 * (f * 1.3 + vec3(0.0, 0.33, 0.67)) + TIME * 0.25);
	vec3 col = mix(tint.rgb, irid, iridescence * f);
	float p = 1.0 + pulse * (0.5 + 0.5 * sin(TIME * 6.0));
	ALBEDO = col * (0.55 + rim_strength * f) * p;
	ALPHA = clamp(base_alpha + f * 0.8 * p, 0.0, 1.0);
}
