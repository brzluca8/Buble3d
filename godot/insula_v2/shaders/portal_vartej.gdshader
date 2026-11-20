// Insula 1 v2: vârtejul din portal (cyan/violet, se rotește și pulsează). Nu folosește UV: coordonatele polare
// vin din poziția locală a discului (centrul și razele elipsei sunt cele din build_props.py, în metri).
shader_type spatial;
render_mode cull_disabled, shadows_disabled;

uniform vec3 culoare_a : source_color = vec3(0.35, 0.95, 1.0);
uniform vec3 culoare_b : source_color = vec3(0.55, 0.25, 1.0);
uniform vec2 centru = vec2(0.0, 1.75);
uniform vec2 raza = vec2(0.72, 1.05);
uniform float viteza = 1.0;
uniform float intensitate = 2.6;

varying vec2 vp;

void vertex() {
	vp = (VERTEX.xy - centru) / raza;
}

void fragment() {
	float r = length(vp);
	float a = atan(vp.y, vp.x);
	float vartej = sin(a * 3.0 + r * 9.0 - TIME * viteza * 3.0) * 0.5 + 0.5;
	float inele = sin(r * 18.0 - TIME * viteza * 4.0) * 0.5 + 0.5;
	vec3 c = mix(culoare_b, culoare_a, vartej * 0.7 + inele * 0.3);
	c = mix(c, vec3(1.0), smoothstep(0.55, 0.0, r) * 0.6);
	float puls = 0.85 + 0.15 * sin(TIME * 2.0);
	ALBEDO = vec3(0.0);
	ROUGHNESS = 1.0;
	EMISSION = c * intensitate * puls * smoothstep(1.02, 0.85, r);
}
