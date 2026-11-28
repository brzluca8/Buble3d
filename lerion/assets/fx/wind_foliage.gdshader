shader_type spatial;
// Same look as assets/kingdom/pigment.tres (vertex colours, matte) plus a gentle breeze on the
// green foliage only. Trunks, rocks and flowers keep still. Cost: a few ALU ops per vertex.
render_mode cull_back;
uniform float strength = 1.0;
uniform float speed = 1.0;

varying float green;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	green = smoothstep(0.02, 0.12, COLOR.g - max(COLOR.r, COLOR.b));
	float t = TIME * speed;
	float sway = sin(t * 1.3 + world.x * 0.45 + world.z * 0.31) * 0.6 + sin(t * 2.7 + world.x * 1.7) * 0.25;
	float flutter = sin(t * 7.0 + world.x * 5.0 + world.z * 4.0) * 0.15;
	float h = clamp(world.y - 0.25, 0.0, 2.5);
	VERTEX.x += (sway + flutter) * 0.035 * strength * green * h;
	VERTEX.z += sway * 0.02 * strength * green * h;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.94;
	SPECULAR = 0.18;
}
