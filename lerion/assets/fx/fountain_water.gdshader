shader_type spatial;
// Stylised water surface for the fountain basin: drifting rings, a soft caustic net and
// sparkles that catch the light. Additive, unshaded, one quad.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 tint : source_color = vec4(0.55, 0.95, 1.0, 1.0);
uniform float radius = 0.48;

float hash(vec2 p) { return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5); }

void fragment() {
	vec2 p = UV - 0.5;
	float r = length(p);
	float inside = 1.0 - smoothstep(radius - 0.02, radius, r);
	float inner = smoothstep(0.1, 0.16, r);
	float rings = pow(0.5 + 0.5 * sin(r * 70.0 - TIME * 2.6), 6.0);
	vec2 q = p * 14.0 + vec2(TIME * 0.4, -TIME * 0.3);
	float net = pow(abs(sin(q.x + sin(q.y * 1.3)) * sin(q.y + sin(q.x * 1.1))), 0.3);
	float caustic = smoothstep(0.82, 1.0, net);
	vec2 cell = floor(p * 40.0);
	float sparkle = step(0.992, hash(cell + floor(TIME * 3.0)));
	float a = (0.16 * rings + 0.22 * caustic + 0.9 * sparkle) * inside * inner;
	ALBEDO = tint.rgb;
	ALPHA = clamp(a, 0.0, 1.0);
}
