// Insula 1 v2: teren și stânci. Texturi tileable mapate triplanar în spațiul lumii (fără UV-uri, deci nimic întins):
// iarbă pe plat, stâncă pe abrupt, mușchi la tranziție; pavaj, nisip și mușchi din culorile de vârf;
// AO coaptă în culorile de vârf.  COLOR: r = AO, g = pavaj, b = nisip, a = mușchi.
// O textură de 1024 px acoperă `metri_pe_textura` = 2 m -> 512 px/m peste tot.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D tex_iarba : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_muschi : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_stanca : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_piatra : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_nisip : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D norm_stanca : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D norm_piatra : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_checker : source_color, filter_linear_mipmap, repeat_enable;

uniform float metri_pe_textura = 2.0;
uniform bool debug_checker = false;     // modul de verificare a densității: un pătrat = 25 cm
uniform bool normale = true;            // oprit la calitatea Mic
uniform float putere_normale = 0.8;
uniform float putere_ao = 1.0;
uniform vec3 nuanta_jos : source_color = vec3(0.62, 0.66, 0.98);  // stâncile se albăstresc spre fund (aer)
uniform float y_aer_sus = -3.0;
uniform float y_aer_jos = -11.0;

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
vec3 tri_culoare(sampler2D t, vec3 p, vec3 w) {
	vec3 cx = texture(t, vec2(p.z, -p.y)).rgb;
	vec3 cy = texture(t, p.xz).rgb;
	vec3 cz = texture(t, vec2(p.x, -p.y)).rgb;
	return cx * w.x + cy * w.y + cz * w.z;
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

void fragment() {
	vec3 n = normalize(v_nrm);
	vec3 p = v_pos / metri_pe_textura;
	vec3 w = greutati(n);
	float sus = n.y;
	float abrupt = smoothstep(0.80, 0.58, sus);
	float tranzitie = smoothstep(0.94, 0.76, sus) * (1.0 - abrupt);
	float pavaj = smoothstep(0.35, 0.65, COLOR.g);
	float nisip = smoothstep(0.3, 0.7, COLOR.b);

	vec3 c;
	float rugozitate;
	if (debug_checker) {
		c = tri_culoare(tex_checker, p, w);
		rugozitate = 0.9;
	} else {
		vec3 iarba = texture(tex_iarba, p.xz).rgb;
		vec3 muschi = texture(tex_muschi, p.xz * 1.3).rgb;
		vec3 piatra = texture(tex_piatra, p.xz).rgb;
		vec3 nis = texture(tex_nisip, p.xz).rgb;
		vec3 stanca = tri_culoare(tex_stanca, p, w);
		c = mix(iarba, muschi, tranzitie * 0.85);
		c = mix(c, piatra, pavaj);
		c = mix(c, nis, nisip);
		c = mix(c, stanca, abrupt);
		// mușchi pe marginea de sus a stâncilor și lângă apă
		c = mix(c, c * vec3(0.52, 0.86, 0.42) + vec3(0.02, 0.05, 0.0), COLOR.a * abrupt);
		rugozitate = mix(mix(0.92, 0.78, pavaj), 0.86, abrupt);
		rugozitate = mix(rugozitate, 0.55, nisip * 0.6);
		// aer: stâncile de jos spre albăstrui
		float aer = smoothstep(y_aer_sus, y_aer_jos, v_pos.y);
		c = mix(c, c * nuanta_jos, aer * 0.55);
	}
	c *= mix(1.0, COLOR.r, putere_ao);
	ALBEDO = c;
	ROUGHNESS = rugozitate;
	SPECULAR = 0.3;

	if (normale && !debug_checker) {
		// fără ramificații pe valori care variază pe pixel: texturile se citesc mereu (derivate corecte pentru mipmap)
		vec3 ns = tri_normala(norm_stanca, p, n, w, putere_normale);
		vec2 tp = (texture(norm_piatra, p.xz).rg * 2.0 - 1.0) * putere_normale;
		vec3 np = normalize(vec3(n.x + tp.x, n.y, n.z + tp.y));
		vec3 nw = normalize(mix(n, ns, abrupt));
		nw = normalize(mix(nw, np, pavaj * (1.0 - abrupt)));
		NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	}
}
