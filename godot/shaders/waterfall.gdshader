shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;

// Perdea de apă: dâre verticale care curg în jos, margini și capăt estompate.
uniform vec4 tint : source_color = vec4(0.75, 0.94, 1.0, 0.75);
uniform float speed = 0.6;
uniform float streaks = 14.0;
uniform float boost = 1.25;

float hash(float n) { return fract(sin(n) * 43758.5453); }

void fragment() {
	float col = floor(UV.x * streaks);
	float off = hash(col);
	float v = fract(UV.y * 1.6 - TIME * speed * (0.7 + off * 0.6) + off);
	float streak = smoothstep(0.0, 0.45, v) * (1.0 - smoothstep(0.55, 1.0, v));
	float edge = smoothstep(0.0, 0.2, UV.x) * smoothstep(1.0, 0.8, UV.x);
	float fade = 1.0 - smoothstep(0.7, 1.0, UV.y);
	ALBEDO = mix(tint.rgb, vec3(1.0), streak * 0.6) * boost;
	ALPHA = tint.a * edge * fade * (0.5 + 0.5 * streak);
}
