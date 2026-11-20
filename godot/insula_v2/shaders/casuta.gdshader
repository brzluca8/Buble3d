// Insula 1 v2: căsuța de joc. Piatră bej cu gravura în romb (textură + normal map pe UV), chenar auriu
// (COLOR.r = 1), AO în COLOR.g. `aprindere` e un uniform pe instanță: căsuța se aprinde scurt la aterizare;
// `culoare_tip` colorează aprinderea (și inelul căsuțelor speciale).
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D tex_piatra : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D norm_piatra : hint_normal, filter_linear_mipmap_anisotropic;
uniform vec3 culoare_aur : source_color = vec3(0.98, 0.76, 0.30);
uniform bool normale = true;
instance uniform float aprindere = 0.0;
instance uniform vec3 culoare_tip = vec3(1.0, 0.86, 0.5);

void fragment() {
	float aur = COLOR.r;
	vec3 piatra = texture(tex_piatra, UV).rgb * COLOR.g;
	ALBEDO = mix(piatra, culoare_aur, aur);
	METALLIC = aur * 0.85;
	ROUGHNESS = mix(0.82, 0.32, aur);
	if (normale) {
		NORMAL_MAP = texture(norm_piatra, UV).rgb;
		NORMAL_MAP_DEPTH = 0.8 * (1.0 - aur);
	}
	EMISSION = culoare_tip * aprindere * 0.9;
}
