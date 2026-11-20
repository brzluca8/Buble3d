// Insula 1: apa (un singur shader pentru râu, lagună, iazuri și cascade). Opac, fără textura de adâncime
// (scumpă pe rendererul Mobile): adâncimea vine din UV (râu) sau din culoarea de vârf (lacuri).
// Plasele de apă sunt chiar apa din modelul trimis, separată în Blender (blender/insula1/imbunatateste.py și
// v3_faza_a.py), cu UV-uri și culori de vârf după convențiile de mai jos.
// Modul vine din COLOR.a (un singur material pentru toată apa):
//   COLOR.a = 0   râu:     UV.x = 0..1 pe lățime, UV.y = metri pe direcția curgerii
//   COLOR.a = 0.5 lac:     UV = poziția în metri (x, z), COLOR.r = adâncimea 0 (mal) .. 1 (mijloc)
//   COLOR.a = 1   cascadă: UV.x = 0..1 pe lățime, UV.y = metri de la buză în jos
// COLOR.g = spumă (sub poduri, la buza cascadei, inele în jurul a ce iese din apă), COLOR.b = spumă la baza cascadei.
// Cascade: COLOR.r = 1 dacă ea cade în gol; spre bază se destramă în puncte și se topește în norii de dedesubt.
// NORMAL_MAP are nevoie de tangente: Godot le generează la importul GLB-ului (opțiunea implicită).
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D tex_normale : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec3 culoare_mal : source_color = vec3(0.40, 0.93, 0.87);
uniform vec3 culoare_adanc : source_color = vec3(0.03, 0.43, 0.80);
uniform vec3 culoare_spuma : source_color = vec3(0.95, 1.0, 1.0);
uniform vec3 culoare_cascada : source_color = vec3(0.58, 0.90, 1.0);
uniform float viteza = 0.55;          // m/s, pe direcția UV.y (cascadele: de 5 ori mai repede)
uniform float scala = 0.32;           // repetări ale texturii de valuri pe metru (mai mic = valuri mai mari, mai puțin zgomot)
uniform float putere_normale = 0.42;
uniform float emisie = 0.2;           // ușor emisiv: apa pare însorită și în umbră
uniform bool calitate_mare = true;    // al doilea strat de valuri, dungi de curent, spumă cu zgomot, sclipiri

float destramare(vec2 p) {
	return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
}

void fragment() {
	int mod_apa = int(COLOR.a * 2.0 + 0.5);
	float t = TIME;
	if (mod_apa == 2 && COLOR.r > 0.5) {
		// cascadă care cade în gol: se destramă spre bază (COLOR.b crește spre bază)
		float f = smoothstep(0.15, 1.0, COLOR.b);
		if (f > destramare(FRAGCOORD.xy) + 0.02) {
			discard;
		}
	}
	vec2 uv1;
	vec2 uv2;
	float latime = 0.0;
	float v = viteza;
	if (mod_apa == 1) {
		// lac: două straturi care alunecă încet în direcții diferite (unde mici)
		uv1 = UV * scala + vec2(t * 0.020, t * 0.013);
		uv2 = UV * scala * 1.63 + vec2(-t * 0.017, t * 0.024);
	} else {
		if (mod_apa == 2) {
			v = viteza * 5.0;
		}
		// două straturi pe direcția curgerii, cu viteze diferite: direcția se vede
		uv1 = vec2(UV.x * 0.9, UV.y * scala - t * v * scala);
		uv2 = vec2(UV.x * 1.4 + 0.37, UV.y * scala * 1.9 - t * v * scala * 1.6);
		latime = abs(UV.x * 2.0 - 1.0);
	}
	vec3 n1 = texture(tex_normale, uv1).rgb;
	vec3 n2 = texture(tex_normale, uv2).rgb;
	vec3 nm = n1 * 2.0 - 1.0;
	if (calitate_mare) {
		nm = normalize(nm + (n2 * 2.0 - 1.0) * vec3(1.0, 1.0, 0.0));
	}
	NORMAL_MAP = nm * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = putere_normale;

	float adanc = 0.35;
	if (mod_apa == 1) {
		adanc = COLOR.r;
	} else if (mod_apa == 0) {
		adanc = 1.0 - latime * latime;
	}
	vec3 c = mix(culoare_mal, culoare_adanc, smoothstep(0.05, 0.85, adanc));

	float zgomot = 0.5;
	if (calitate_mare) {
		zgomot = texture(tex_normale, uv1 * 2.3 + vec2(0.0, t * 0.1)).r;
	}
	float spuma = 0.0;
	if (mod_apa == 0) {
		spuma = smoothstep(0.80, 0.99, latime + (zgomot - 0.5) * 0.3);
		if (calitate_mare) {
			// dungi de curent care curg pe râu (arată direcția)
			float dunga = texture(tex_normale, vec2(UV.x * 1.3, UV.y * 0.22 - t * v * 0.22)).r;
			spuma = max(spuma, smoothstep(0.64, 0.74, dunga) * 0.28 * (1.0 - latime));
		}
	} else if (mod_apa == 1) {
		spuma = smoothstep(0.12, 0.0, COLOR.r + (zgomot - 0.5) * 0.08) * 0.75;
	} else {
		float dunga = texture(tex_normale, vec2(UV.x * 2.2, UV.y * 0.35 - t * v * 0.45)).r;
		c = mix(culoare_cascada, culoare_spuma, smoothstep(0.42, 0.62, dunga));
		spuma = smoothstep(0.86, 1.0, latime) * 0.6;
	}
	spuma = max(spuma, COLOR.g * smoothstep(0.3, 0.7, zgomot));
	spuma = max(spuma, COLOR.b * smoothstep(0.2, 0.65, zgomot));
	vec3 alb = mix(c, culoare_spuma, clamp(spuma, 0.0, 1.0));

	// sclipiri de soare, moi (fără vârfuri de un pixel care pâlpâie pe ecranul telefonului)
	float sclipire = 0.0;
	if (calitate_mare && mod_apa != 2) {
		sclipire = smoothstep(0.62, 0.9, n1.r * n2.g * 1.25) * 0.35;
	}
	float e_buza = 0.0;
	if (mod_apa == 2) {
		e_buza = COLOR.g * 0.25;
	}
	ALBEDO = alb;
	ROUGHNESS = mix(0.12, 0.55, spuma);
	SPECULAR = 0.55;
	EMISSION = alb * emisie + vec3(sclipire) + culoare_spuma * e_buza;
}
