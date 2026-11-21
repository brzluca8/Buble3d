// Insula 1 (v4): terenul nou al Inelului 1 (teren.glb din blender/insula1/v4_inel1.py).
// Texturi tileable mapate triplanar în coordonatele lumii (fără UV-uri, deci nimic întins): 1024 px pe 2 m = 512 px/m.
//   iarbă pe plat, stâncă pe abrupt, mușchi la tranziție și unde e masca lui; pavaj și pământ din măști.
//   COLOR (pe vârfuri): r = AO (raze + umbre de contact false sub căsuțe și recuzită), g = pavaj, b = pământ, a = mușchi.
//   variație mare de culoare (pete calde/reci, la 9 și 23 m) din zgomot în coordonatele lumii: textura repetată la 2 m
//   nu se vede în grilă.
//   mod_debug 1: tabla de șah (un pătrat = 25 cm = 128 px), pentru verificarea densității de 512 px/m.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://insula1/shaders/umbre_nori.gdshaderinc"

uniform sampler2D tex_iarba : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_pavaj : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_pamant : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_stanca : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_muschi : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D norm_iarba : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D norm_pavaj : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D norm_pamant : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D norm_stanca : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_zgomot : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_checker : source_color, filter_linear_mipmap, repeat_enable;

uniform float metri_pe_textura = 2.0;
uniform bool normale = true;          // oprit la calitatea Mic
uniform float putere_normale = 0.7;
uniform float putere_ao = 1.0;
uniform float variatie = 0.16;        // cât de tare sunt petele mari, calde și reci
uniform int mod_debug = 0;            // 0 normal, 1 tablă de șah (25 cm), 3 AO, 4 măști

varying vec3 v_pos;
varying vec3 v_nrm;

void vertex() {
	v_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec3 greutati(vec3 n) {
	vec3 w = pow(abs(n), vec3(4.0));
	return w / max(w.x + w.y + w.z, 0.0001);
}

// proiecțiile laterale au V = -înălțimea, ca partea de sus a imaginii să fie sus pe perete
vec3 tri(sampler2D t, vec3 p, vec3 w) {
	return texture(t, vec2(p.z, -p.y)).rgb * w.x + texture(t, p.xz).rgb * w.y + texture(t, vec2(p.x, -p.y)).rgb * w.z;
}

// normală triplanară (amestec UDN în spațiul lumii)
vec3 tri_normala(sampler2D t, vec3 p, vec3 n, vec3 w, float k) {
	vec2 tx = (texture(t, vec2(p.z, -p.y)).rg * 2.0 - 1.0) * k;
	vec2 ty = (texture(t, p.xz).rg * 2.0 - 1.0) * k;
	vec2 tz = (texture(t, vec2(p.x, -p.y)).rg * 2.0 - 1.0) * k;
	vec3 nx = vec3(n.x, n.y - tx.y, n.z + tx.x);
	vec3 ny = vec3(n.x + ty.x, n.y, n.z + ty.y);
	vec3 nz = vec3(n.x + tz.x, n.y - tz.y, n.z);
	return normalize(nx * w.x + ny * w.y + nz * w.z);
}

vec3 normala_sus(sampler2D t, vec2 uv, vec3 n, float k) {
	vec2 d = (texture(t, uv).rg * 2.0 - 1.0) * k;
	return normalize(vec3(n.x + d.x, n.y, n.z + d.y));
}

void fragment() {
	vec3 n = normalize(v_nrm);
	vec3 p = v_pos / metri_pe_textura;
	vec3 w = greutati(n);
	float abrupt = smoothstep(0.78, 0.56, n.y);
	float pavaj = smoothstep(0.3, 0.7, COLOR.g) * (1.0 - abrupt);
	float pamant = smoothstep(0.3, 0.7, COLOR.b) * (1.0 - abrupt);
	float muschi = clamp(COLOR.a + smoothstep(0.95, 0.8, n.y) * (1.0 - abrupt) * 0.6, 0.0, 1.0);
	// variația mare, în lume: două octave de zgomot (9 m și 23 m), nu se repetă vizibil
	vec3 z1 = texture(tex_zgomot, v_pos.xz / 9.0).rgb;
	vec3 z2 = texture(tex_zgomot, v_pos.xz / 23.0 + vec2(0.37, 0.71)).rgb;
	float cald = smoothstep(0.45, 0.75, z1.r * 0.6 + z2.g * 0.4);
	float rece = smoothstep(0.5, 0.8, z2.r * 0.7 + z1.b * 0.3);

	vec3 iarba = texture(tex_iarba, p.xz).rgb;
	iarba = mix(iarba, iarba * vec3(1.16, 1.08, 0.72), cald * variatie * 2.0);   // pete galben-verzi
	iarba = mix(iarba, iarba * vec3(0.82, 0.98, 1.06), rece * variatie * 2.0);   // pete verzi-reci
	vec3 c = mix(iarba, texture(tex_muschi, p.xz * 1.3).rgb, muschi * 0.75);
	c = mix(c, texture(tex_pamant, p.xz).rgb * (0.94 + 0.12 * z1.g), pamant);
	c = mix(c, texture(tex_pavaj, p.xz).rgb * (0.95 + 0.1 * z1.b), pavaj);
	c = mix(c, tri(tex_stanca, p, w), abrupt);
	float rug = mix(mix(0.95, 0.86, pavaj), 0.88, abrupt);

	float ao = mix(1.0, COLOR.r, putere_ao);
	ALBEDO = c * ao * umbra_nori(v_pos);
	ROUGHNESS = rug;
	SPECULAR = 0.25;
	if (normale) {
		// texturile se citesc mereu (derivate corecte pentru mipmap), nu pe ramificații
		vec3 ni = normala_sus(norm_iarba, p.xz, n, putere_normale * 0.6);
		vec3 np = normala_sus(norm_pavaj, p.xz, n, putere_normale);
		vec3 nm = normala_sus(norm_pamant, p.xz, n, putere_normale * 0.8);
		vec3 ns = tri_normala(norm_stanca, p, n, w, putere_normale);
		vec3 nw = normalize(mix(mix(mix(ni, nm, pamant), np, pavaj), ns, abrupt));
		NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	}
	if (mod_debug == 1) {
		ALBEDO = tri(tex_checker, p, w);
	} else if (mod_debug == 3) {
		ALBEDO = vec3(ao);
	} else if (mod_debug == 4) {
		ALBEDO = vec3(pavaj, 1.0 - max(pavaj, pamant), pamant) * 0.8 + vec3(0.0, 0.0, muschi * 0.2);
	}
}
