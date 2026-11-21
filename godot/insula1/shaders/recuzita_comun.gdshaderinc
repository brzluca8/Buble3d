// Insula 1 (v4): codul comun al recuzitei noi (copaci, tufe, iarbă, flori, pietricele, garduri, felinare, butoaie,
// lăzi, cristale din godot/assets/models/inel1, făcute de blender/insula1/v4_recuzita.py).
//   COLOR.rgb = culoarea (liniară; la MultiMesh, Godot o înmulțește cu culoarea instanței), COLOR.a = AO coaptă
//   UV.x = cât luminează (sticla felinarului, cristalele), UV.y = cât se leagănă (0 la bază, 1 în vârf)
// Vântul (Aliseron): direcția și puterea sunt globale (insula1.gd); rafalele trec ca valuri peste insulă
// (același zgomot ca umbrele norilor), deci iarba, florile, frunzele și coroanele se mișcă împreună, în valuri.
#include "res://insula1/shaders/umbre_nori.gdshaderinc"

global uniform vec2 vant_directie;
global uniform float vant_putere;

uniform float putere_lumina = 2.2;
uniform bool animat = true;          // false la „mișcare redusă”
uniform bool vant_activ = true;
uniform float leganare = 0.12;       // metri la vârf, la vânt 1
uniform float putere_ao = 0.9;
uniform bool flacara = false;        // felinare: pâlpâie; altfel (cristale): pulsează încet

instance uniform float alfa = 1.0;   // doar în varianta estompată
instance uniform float vant_obiect = 1.0;

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
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float g = UV.y;
	if (vant_activ && g > 0.001) {
		vec3 o = MODEL_MATRIX[3].xyz;
		float faza = o.x * 0.71 + o.z * 0.53;
		float rafala = nori_zgomot(wp.xz * 0.09 - vant_directie * TIME * 1.6);
		float s = vant_putere * (0.45 + 0.9 * rafala) * (0.65 + 0.35 * sin(TIME * 1.9 + faza))
				+ 0.12 * sin(TIME * 4.3 + faza * 2.1 + wp.y * 3.0);
		vec3 dep = vec3(vant_directie.x, 0.0, vant_directie.y) * s * g * g * leganare * vant_obiect;
		dep.y -= length(dep) * 0.35;
		mat3 m = mat3(MODEL_MATRIX);
		VERTEX += (transpose(m) * dep) / max(dot(m[0], m[0]), 0.0001);
		wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	}
	v_pos = wp;
	v_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 alb = COLOR.rgb;
	float ao = mix(1.0, COLOR.a, putere_ao);
	ALBEDO = alb * ao * umbra_nori(v_pos);
	ROUGHNESS = 0.8;
	SPECULAR = 0.3;
	float e = UV.x;
	float k = 1.0;
	if (animat) {
		float faza = dot(floor(v_pos * 2.0), vec3(1.7, 3.1, 2.3));
		// sticla felinarelor (UV.x = 1) pâlpâie ca o flacără; cristalele (UV.x < 1) pulsează încet
		k = (flacara || e > 0.9) ? 0.84 + 0.11 * sin(TIME * 11.0 + faza) + 0.05 * sin(TIME * 17.3 + faza * 1.3)
				: 0.7 + 0.3 * sin(TIME * 1.7 + faza * 0.37);
	}
	EMISSION = alb * e * putere_lumina * k + contur(v_nrm, NORMAL, VIEW);
#ifdef ESTOMPAT
	ALPHA = alfa;
#endif
}
