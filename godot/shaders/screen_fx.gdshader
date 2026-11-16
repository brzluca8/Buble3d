shader_type canvas_item;
// Efecte de ecran: iris (cerc care se închide, pentru raid) și vignetă irizată (interiorul globului).
uniform int mode = 0;              // 0 = vignetă, 1 = iris
uniform float r = 1.5;             // raza irisului (în unități de lățime)
uniform vec2 center = vec2(0.5, 0.5);
uniform float aspect = 0.5625;     // lățime / înălțime
uniform float strength = 1.0;

void fragment() {
	vec2 d = (UV - center) * vec2(1.0, 1.0 / aspect);
	if (mode == 1) {
		float a = smoothstep(r, r + 0.02, length(d));
		COLOR = vec4(0.06, 0.02, 0.14, a);
	} else {
		vec2 q = (UV - 0.5) * 2.0;
		float e = pow(clamp(length(q * vec2(1.0, 0.85)) - 0.55, 0.0, 1.0) * 1.6, 2.0);
		float ang = atan(q.y, q.x);
		vec3 irid = 0.5 + 0.5 * cos(6.28318 * (ang * 0.16 + vec3(0.0, 0.33, 0.67)) + TIME * 0.15);
		vec3 col = mix(vec3(0.2, 0.1, 0.4), irid, 0.55);
		COLOR = vec4(col, e * 0.32 * strength);
	}
}
