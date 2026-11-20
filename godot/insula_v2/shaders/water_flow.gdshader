// Insula 1 v2: apa (un singur shader pentru râu, lagună/iaz și cascade). Opac, fără textura de adâncime
// (scumpă pe rendererul Mobile): adâncimea vine din UV (râu) sau din culoarea de vârf (lacuri).
// Modul vine din COLOR.a (un singur material pentru toată apa):
//   COLOR.a = 0   râu:     UV.x = 0..1 pe lățime, UV.y = metri pe direcția curgerii
//   COLOR.a = 0.5 lac:     UV = poziția în metri (x, z), COLOR.r = adâncimea 0 (mal) .. 1 (mijloc)
//   COLOR.a = 1   cascadă: UV.x = 0..1 pe lățime, UV.y = metri de la buză în jos
// COLOR.g = spumă sub poduri / buza cascadei, COLOR.b = spumă la baza cascadei.
// Tangentele trebuie să existe (SurfaceTool.generate_tangents()) pentru NORMAL_MAP.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D tex_normale : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec3 culoare_mal : source_color = vec3(0.40, 0.93, 0.87);
uniform vec3 culoare_adanc : source_color = vec3(0.03, 0.43, 0.80);
uniform vec3 culoare_spuma : source_color = vec3(0.95, 1.0, 1.0);
uniform vec3 culoare_cascada : source_color = vec3(0.58, 0.90, 1.0);
uniform float viteza = 0.55;          // m/s, pe direcția UV.y (cascadele: de 5 ori mai repede)
uniform float scala = 0.45;           // repetări ale texturii de valuri pe metru
uniform float putere_normale = 0.55;
uniform float emisie = 0.22;          // ușor emisiv: apa pare însorită și în umbră
uniform bool calitate_mare = true;    // al doilea strat de valuri, spumă cu zgomot, sclipiri

void fragment() {
	int mod_apa = int(COLOR.a * 2.0 + 0.5);
	float t = TIME;
	vec2 uv1;
	vec2 uv2;
	float latime = 0.0;
	if (mod_apa == 1) {
		uv1 = UV * scala + vec2(t * 0.020, t * 0.013);
		uv2 = UV * scala * 1.63 + vec2(-t * 0.017, t * 0.024);
	} else {
		float v = viteza;
		if (mod_apa == 2) {
			v = viteza * 5.0;
		}
		uv1 = vec2(UV.x * 0.9, UV.y * scala - t * v * scala);
		uv2 = vec2(UV.x * 1.4 + 0.37, UV.y * scala * 1.9 - t * v * scala * 1.55);
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
	} else if (mod_apa == 1) {
		spuma = smoothstep(0.12, 0.0, COLOR.r + (zgomot - 0.5) * 0.08) * 0.75;
	} else {
		float dunga = texture(tex_normale, vec2(UV.x * 2.2, UV.y * 0.35 - t * viteza * 2.2)).r;
		c = mix(culoare_cascada, culoare_spuma, smoothstep(0.42, 0.62, dunga));
		spuma = smoothstep(0.86, 1.0, latime) * 0.6;
	}
	spuma = max(spuma, COLOR.g * smoothstep(0.3, 0.7, zgomot));
	spuma = max(spuma, COLOR.b * smoothstep(0.2, 0.65, zgomot));
	vec3 alb = mix(c, culoare_spuma, clamp(spuma, 0.0, 1.0));

	float sclipire = 0.0;
	if (calitate_mare && mod_apa != 2) {
		sclipire = pow(clamp(n1.r * n2.g * 1.25, 0.0, 1.0), 10.0) * 0.9;
	}
	float e_buza = 0.0;
	if (mod_apa == 2) {
		e_buza = COLOR.g * 0.25;
	}
	ALBEDO = alb;
	ROUGHNESS = mix(0.05, 0.55, spuma);
	SPECULAR = 0.65;
	EMISSION = alb * emisie + vec3(sclipire) + culoare_spuma * e_buza;
}
