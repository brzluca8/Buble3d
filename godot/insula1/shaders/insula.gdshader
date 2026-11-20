// Insula 1 (insula trimisă, din Tripo, îmbunătățită): textura mărită (4096 px) + lumini vii.
// tex_orm vine din GLB: R = masca de lumină (flăcări, ferestre, cristale), G = rugozitate, B = metal.
// Lumina = albedo x mască: flăcările și ferestrele calde pâlpâie, cristalele reci pulsează încet.
// Fără cull: modelul din Tripo are și fețe întoarse.
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D tex_albedo : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D tex_orm : hint_default_black, filter_linear_mipmap;
uniform float putere_lumina = 2.4;
uniform bool animat = true;  // false la „mișcare redusă”: luminile stau aprinse, fără pâlpâit

void fragment() {
	vec3 alb = texture(tex_albedo, UV).rgb;
	vec3 orm = texture(tex_orm, UV).rgb;
	ALBEDO = alb;
	ROUGHNESS = orm.g;
	METALLIC = orm.b;
	float k = 1.0;
	if (animat) {
		vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float faza = dot(floor(wp * 3.0), vec3(1.7, 3.1, 2.3));  // fiecare felinar în ritmul lui
		float rece = smoothstep(-0.05, 0.1, alb.b - alb.r);       // cristale (albastru) / flăcări (galben)
		float palpaie = 0.82 + 0.12 * sin(TIME * 11.0 + faza) + 0.06 * sin(TIME * 17.3 + faza * 1.3);
		float puls = 0.65 + 0.35 * sin(TIME * 1.7 + faza * 0.37);
		k = mix(palpaie, puls, rece);
	}
	EMISSION = alb * orm.r * putere_lumina * k;
}
