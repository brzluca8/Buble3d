// Insula 1 (v3): toate obiectele insulei (stânci, iarbă, frunziș, flori, pânze, cristale, felinare, portal, barca,
// palele morii, restul) folosesc acest shader, cu un singur material; clasa vine din uniformele pe instanță.
//   textura: albedo (mărită cu AI și ascuțită), ORM (R = mască de lumină, G = rugozitate, B = metal)
//   COLOR (din GLB): R = ocluzie ambientală (AO coaptă), A = cât se leagănă vârful în vânt (0 la sol, 1 sus)
//   strat de detaliu: textură tileable, triplanar, în coordonate de lume (scoate aspectul de plastilină)
//   nuanțare: gama, saturație, contrast (insula avea culorile spălate față de Orion)
//   estompare (A11): ce ajunge între cameră și Orion (sau foarte aproape de cameră) se destramă în puncte
// Fără cull: modelul din Tripo are și fețe subțiri, văzute din ambele părți.
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D tex_albedo : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D tex_orm : hint_default_black, filter_linear_mipmap;
uniform sampler2D tex_detaliu : hint_default_white, filter_linear_mipmap, repeat_enable;  // R stâncă, G iarbă, B granulație

global uniform vec2 vant_directie;
global uniform float vant_putere;
global uniform vec3 orion_pozitie;

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
uniform bool estompare = true;
uniform float raza_estompare = 1.1;  // metri în jurul liniei cameră-Orion
uniform int mod_debug = 0;           // 0 normal, 1 tablă de șah în UV (32 px), 2 clase, 3 AO, 4 normale

instance uniform float vant = 1.0;            // cât de tare se leagănă obiectul
instance uniform float detaliu = 3.0;         // 0 fără, 1 stâncă, 2 iarbă, 3 granulație fină
instance uniform float lumina_proprie = 0.0;  // cristale: strălucire proprie care pulsează
instance uniform vec3 culoare_clasa = vec3(0.6, 0.6, 0.6);

varying vec3 v_pos;
varying vec3 v_nrm;

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

// zgomot de destrămare (fără texturi): „interleaved gradient noise”, stabil pe ecran
float destramare(vec2 p) {
	return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
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
	if (estompare) {
		vec3 cam = CAMERA_POSITION_WORLD;
		vec3 tinta = orion_pozitie + vec3(0.0, 0.6, 0.0);
		vec3 ab = tinta - cam;
		float t = dot(v_pos - cam, ab) / max(dot(ab, ab), 0.0001);
		float d = length(v_pos - (cam + ab * clamp(t, 0.0, 1.0)));
		float f = 0.0;
		if (t > 0.0 && t < 0.92) {
			f = smoothstep(raza_estompare, raza_estompare * 0.4, d);
		}
		f = max(f, smoothstep(2.4, 1.2, length(v_pos - cam)));
		if (f > 0.0 && f * 0.92 > destramare(FRAGCOORD.xy)) {
			discard;
		}
	}
	vec3 alb = texture(tex_albedo, UV).rgb;
	vec3 orm = texture(tex_orm, UV).rgb;
	// nuanțare (în spațiu liniar): gama, saturație, contrast în jurul griului mediu
	alb = pow(max(alb, vec3(0.0)), vec3(gama));
	float lum = dot(alb, vec3(0.2126, 0.7152, 0.0722));
	alb = max(mix(vec3(lum), alb, saturatie), vec3(0.0));
	alb = max((alb - 0.18) * contrast + 0.18, vec3(0.0));
	float ao = mix(1.0, smoothstep(0.0, 0.85, COLOR.r), putere_ao);
	if (detaliu_activ && detaliu > 0.5) {
		vec3 dt = detaliu_triplanar(v_pos, v_nrm);
		float dv = detaliu < 1.5 ? dt.r : (detaliu < 2.5 ? dt.g : dt.b);
		alb *= 1.0 + (dv - 0.5) * 2.0 * putere_detaliu;
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
	ALBEDO = alb * ao;
	ROUGHNESS = orm.g;
	METALLIC = orm.b;
	EMISSION = alb * orm.r * putere_lumina * k + alb * lumina_proprie * puls;
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
