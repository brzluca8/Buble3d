// Insula 1 v2: semnele căsuțelor speciale, un singur material pentru toate:
// iconița (celula >= 0: celula din atlasul de 5 iconițe) și inelul luminos (celula < 0). Culoarea e pe instanță.
shader_type spatial;
render_mode cull_disabled, shadows_disabled;

uniform sampler2D atlas : source_color, filter_linear_mipmap;
uniform bool puls_activ = true;
instance uniform float celula = -1.0;
instance uniform vec3 culoare = vec3(1.0, 0.86, 0.5);

void fragment() {
	float puls = 1.0;
	if (puls_activ) {
		puls = 0.8 + 0.2 * sin(TIME * 2.2);
	}
	if (celula >= 0.0) {
		vec4 c = texture(atlas, vec2((UV.x + celula) * 0.2, UV.y));
		ALBEDO = mix(c.rgb, c.rgb * culoare, 0.35);
		EMISSION = c.rgb * culoare * 0.6;
		ALPHA = c.a;
		ALPHA_SCISSOR_THRESHOLD = 0.4;
	} else {
		ALBEDO = culoare;
		EMISSION = culoare * 1.3 * puls;
	}
	ROUGHNESS = 0.4;
}
