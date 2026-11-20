// Insula 1 v2: cristale care pulsează (aceeași familie de strălucire cyan ca la Orion). COLOR.rgb = culoarea.
shader_type spatial;
render_mode cull_disabled;

uniform float intensitate = 1.8;
uniform float viteza = 1.7;
uniform bool puls_activ = true;

varying float faza;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	faza = wp.x * 1.3 + wp.z * 0.7;
}

void fragment() {
	float puls = 1.0;
	if (puls_activ) {
		puls = 0.7 + 0.3 * sin(TIME * viteza + faza);
	}
	ALBEDO = COLOR.rgb * 0.55;
	ROUGHNESS = 0.15;
	SPECULAR = 0.7;
	EMISSION = COLOR.rgb * intensitate * puls;
	RIM = 0.5;
	RIM_TINT = 0.6;
}
