// Insula 1: semnele căsuțelor speciale, un singur material pentru toate:
// iconița (celula >= 0: celula din atlasul de 5 iconițe) și inelul luminos (celula < 0). Culoarea e pe instanță.
// v4: iconițele au culorile și conturul lor (lizibile), marginea e netedă (amestec alfa, nu prag: fără trepte),
// iar inelul e mai luminos.
shader_type spatial;
render_mode cull_disabled, shadows_disabled, depth_draw_opaque;

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
		vec4 c = texture(atlas, vec2((clamp(UV.x, 0.01, 0.99) + celula) * 0.2, UV.y));
		ALBEDO = c.rgb;
		EMISSION = c.rgb * 0.22;
		ALPHA = c.a;
	} else {
		ALBEDO = culoare;
		EMISSION = culoare * 1.7 * puls;
		ALPHA = 1.0;
	}
	ROUGHNESS = 0.5;
}
