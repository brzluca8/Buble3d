shader_type canvas_item;
// Crystal-facet transition: hexagonal facets grow outward from `origin` until they cover the
// screen (progress 0 -> 1), then shrink away in the same order (reveal 0 -> 1).
// Each facet is shaded like a cut gem: a light side, a dark side and a bright rim.
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float reveal : hint_range(0.0, 1.0) = 0.0;
uniform vec2 origin = vec2(360.0, 640.0);
uniform vec2 screen_size = vec2(720.0, 1280.0);
uniform float cell = 62.0;
uniform vec4 deep : source_color = vec4(0.05, 0.18, 0.42, 1.0);
uniform vec4 light : source_color = vec4(0.45, 0.92, 1.0, 1.0);
uniform vec4 rim : source_color = vec4(1.0, 0.88, 0.5, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 px = UV * screen_size;
	vec2 p = px / cell;
	vec2 r = vec2(1.0, 1.7320508);
	vec2 h = r * 0.5;
	vec2 a = mod(p, r) - h;
	vec2 b = mod(p - h, r) - h;
	vec2 gv = dot(a, a) < dot(b, b) ? a : b;
	vec2 id = p - gv;
	float far = length(screen_size);
	float d = length(id * cell - origin) / far;
	float order = d * 0.8 + hash(id) * 0.2;
	float grow = smoothstep(order, order + 0.18, progress * 1.2);
	float shrink = 1.0 - smoothstep(order, order + 0.18, reveal * 1.2);
	float size = grow * shrink;
	float hx = max(abs(gv.x) * 0.866 + abs(gv.y) * 0.5, abs(gv.y));
	float inside = 1.0 - smoothstep(0.53 * size - 0.015, 0.53 * size, hx);
	if (size <= 0.001 || inside <= 0.0) {
		COLOR = vec4(0.0);
	} else {
		// Gem cut: six flat bevel faces around a brighter central table.
		float angle = atan(gv.y, gv.x);
		float sector = floor((angle + 3.14159) / 1.0472);
		float shade = 0.25 + 0.75 * hash(vec2(sector, hash(id) * 17.0));
		vec3 tint = mix(light.rgb, vec3(0.62, 0.5, 1.0), hash(id + 9.7) * 0.5);
		vec3 body = mix(deep.rgb, tint, shade);
		if (hx < 0.24 * size) {
			body = mix(tint, vec3(1.0), 0.35);
		}
		float edge = smoothstep(0.42 * size, 0.53 * size, hx);
		vec3 col = mix(body, rim.rgb, edge * 0.85);
		float sparkle = step(0.985, hash(id + floor(TIME * 8.0))) * 0.6;
		COLOR = vec4(col + sparkle, inside);
	}
}
