shader_type canvas_item;
render_mode blend_add;
// Dâre de apă care curg în jos, peste cascadele pictate.
uniform float speed = 0.8;
uniform float strength = 0.35;
float hash(float n) { return fract(sin(n) * 43758.5453); }
void fragment() {
	float col = floor(UV.x * 9.0);
	float off = hash(col);
	float v = fract(UV.y * 2.2 - TIME * speed * (0.7 + off * 0.6) + off);
	float streak = smoothstep(0.0, 0.35, v) * (1.0 - smoothstep(0.45, 1.0, v));
	float edge = smoothstep(0.0, 0.25, UV.x) * smoothstep(1.0, 0.75, UV.x);
	float fade = smoothstep(0.0, 0.08, UV.y) * (1.0 - smoothstep(0.7, 1.0, UV.y));
	COLOR = vec4(vec3(0.85, 0.96, 1.0), streak * edge * fade * strength);
}
