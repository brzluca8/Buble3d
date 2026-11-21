// Insula 1: codul comun al materialului insulei (inclus de insula.gdshader și insula_estompat.gdshader).
//   textura: albedo (mărită cu AI și ascuțită), ORM (R = mască de lumină, G = rugozitate, B = metal)
//   COLOR (din GLB): R = ocluzie ambientală (AO coaptă), A = cât se leagănă vârful în vânt (0 la sol, 1 sus)
//   strat de detaliu: textură tileable, triplanar, în coordonate de lume (scoate aspectul de plastilină)
//   nuanțare: gama, saturație, contrast (insula avea culorile spălate față de Orion)
// v4: fără destrămare în puncte. Ce poate ajunge între cameră și Orion (barca, copacii, tufele, felinarele,
// clădirile ca piese separate) primește pe rând varianta estompată, cu `alfa` care scade lin (insula1.gd).
#include "res://insula1/shaders/umbre_nori.gdshaderinc"

uniform sampler2D tex_albedo : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D tex_orm : hint_default_black, filter_linear_mipmap;
uniform sampler2D tex_detaliu : hint_default_white, filter_linear_mipmap, repeat_enable;  // R stâncă, G iarbă, B granulație
// v4: stâncile și iarba rămase din insula veche iau detaliul clar din texturile terenului nou (512 px/m, triplanar);
// culoarea rămâne cea pictată (doar luminozitatea fină vine din textură)
uniform sampler2D tex_stanca_t : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_iarba_t : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float putere_suprapunere = 0.75;

global uniform vec2 vant_directie;
global uniform float vant_putere;

uniform float putere_lumina = 2.4;
uniform bool animat = true;          // false la „mișcare redusă”
uniform bool vant_activ = true;
uniform float putere_ao = 0.55;
uniform bool detaliu_activ = true;
uniform float putere_detaliu = 0.22;
uniform float metri_detaliu = 1.6;   // o repetare a texturii de detaliu, în metri
uniform float gama = 1.04;
uniform float saturatie = 1.12;
uniform float contrast = 1.08;
uniform int mod_debug = 0;           // 0 normal, 1 tablă de șah în UV (32 px), 2 clase, 3 AO, 4 normale

instance uniform float vant = 1.0;            // cât de tare se leagănă obiectul
instance uniform float detaliu = 3.0;         // 0 fără, 1 stâncă, 2 iarbă, 3 granulație fină
instance uniform float lumina_proprie = 0.0;  // cristale: strălucire proprie care pulsează
instance uniform vec3 culoare_clasa = vec3(0.6, 0.6, 0.6);
instance uniform float alfa = 1.0;            // doar în varianta estompată: obiectul devine transparent lin

varying vec3 v_pos;
varying vec3 v_nrm;

// contur cyan discret, ca la Orion, fără a doua lumină direcțională: fresnel pe partea dinspre spate-dreapta-sus
global uniform vec4 contur_cyan;   // rgb = culoarea, a = puterea (0 = oprit)
vec3 contur(vec3 n_lume, vec3 n_vedere, vec3 spre_camera) {
	float f = pow(1.0 - clamp(dot(n_vedere, spre_camera), 0.0, 1.0), 4.0);
	float spate = clamp(dot(n_lume, normalize(vec3(0.27, 0.53, -0.80))) * 0.5 + 0.5, 0.0, 1.0);
	return contur_cyan.rgb * contur_cyan.a * f * spate;
}

void vertex() {
	if (vant_activ && vant > 0.0 && COLOR.a > 0.001) {
		vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float g = COLOR.a * vant;
		float faza = wp.x * 0.37 + wp.z * 0.29;
		float s = 0.55 + sin(TIME * 1.6 + faza) * 0.6 + sin(TIME * 3.7 + faza * 1.7) * 0.25;
		vec3 dep = vec3(vant_directie.x, 0.0, vant_directie.y) * vant_putere * s * g * 0.1;
		dep.y -= length(dep) * 0.25;
		mat3 m = mat3(MODEL_MATRIX);
		VERTEX += (transpose(m) * dep) / max(dot(m[0], m[0]), 0.0001);
	}
	v_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec3 detaliu_triplanar(vec3 p, vec3 n) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= max(w.x + w.y + w.z, 0.0001);
	vec3 a = texture(tex_detaliu, p.zy / metri_detaliu).rgb;
	vec3 b = texture(tex_detaliu, p.xz / metri_detaliu).rgb;
	vec3 c = texture(tex_detaliu, p.xy / metri_detaliu).rgb;
	return a * w.x + b * w.y + c * w.z;
}

void fragment() {
	vec3 alb = texture(tex_albedo, UV).rgb;
	vec3 orm = texture(tex_orm, UV).rgb;
	// nuanțare (în spațiu liniar): gama, saturație, contrast în jurul griului mediu
	alb = pow(max(alb, vec3(0.0)), vec3(gama));
	float lum = dot(alb, vec3(0.2126, 0.7152, 0.0722));
	alb = max(mix(vec3(lum), alb, saturatie), vec3(0.0));
	alb = max((alb - 0.18) * contrast + 0.18, vec3(0.0));
	float ao = mix(1.0, smoothstep(0.0, 0.85, COLOR.r), putere_ao);
	if (detaliu_activ && detaliu > 0.5) {
		if (detaliu < 2.5) {
			vec3 w = pow(abs(v_nrm), vec3(4.0));
			w /= max(w.x + w.y + w.z, 0.0001);
			vec3 q = v_pos / 2.0;
			vec3 t = detaliu < 1.5
					? texture(tex_stanca_t, vec2(q.z, -q.y)).rgb * w.x + texture(tex_stanca_t, q.xz).rgb * w.y
							+ texture(tex_stanca_t, vec2(q.x, -q.y)).rgb * w.z
					: texture(tex_iarba_t, q.xz).rgb;
			float ref = detaliu < 1.5 ? 0.305 : 0.378;  // luminanța medie (liniară) a texturii
			alb *= mix(1.0, dot(t, vec3(0.2126, 0.7152, 0.0722)) / ref, putere_suprapunere);
		} else {
			vec3 dt = detaliu_triplanar(v_pos, v_nrm);
			alb *= 1.0 + (dt.b - 0.5) * 2.0 * putere_detaliu;
		}
	}
	float k = 1.0;
	float puls = 1.0;
	if (animat) {
		float faza = dot(floor(v_pos * 3.0), vec3(1.7, 3.1, 2.3));  // fiecare felinar în ritmul lui
		float rece = smoothstep(-0.05, 0.1, alb.b - alb.r);         // cristale (albastru) / flăcări (galben)
		float palpaie = 0.82 + 0.12 * sin(TIME * 11.0 + faza) + 0.06 * sin(TIME * 17.3 + faza * 1.3);
		puls = 0.65 + 0.35 * sin(TIME * 1.7 + faza * 0.37);
		k = mix(palpaie, puls, rece);
	}
	ALBEDO = alb * ao * umbra_nori(v_pos);
	ROUGHNESS = orm.g;
	METALLIC = orm.b;
	EMISSION = alb * orm.r * putere_lumina * k + alb * lumina_proprie * puls + contur(v_nrm, NORMAL, VIEW);
#ifdef ESTOMPAT
	ALPHA = alfa;
#endif
	if (mod_debug == 1) {
		float c = mod(floor(UV.x * 128.0) + floor(UV.y * 128.0), 2.0);
		ALBEDO = mix(vec3(0.95, 0.55, 0.1), vec3(0.15, 0.45, 0.9), c);
		EMISSION = vec3(0.0);
	} else if (mod_debug == 2) {
		ALBEDO = culoare_clasa;
		EMISSION = culoare_clasa * 0.35;
	} else if (mod_debug == 3) {
		ALBEDO = vec3(ao);
		EMISSION = vec3(0.0);
	} else if (mod_debug == 4) {
		ALBEDO = v_nrm * 0.5 + 0.5;
		EMISSION = vec3(0.0);
	}
}
