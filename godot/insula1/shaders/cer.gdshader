// Insula 1: cerul. Degradeu albastru (adânc sus, luminos la orizont), nori moi lângă orizont, marea de nori de
// dedesubt (insula plutește) și strălucirea soarelui. Fără TIME: cerul nu se recalculează în fiecare cadru
// (pe telefon e scump); norii care se mișcă sunt sprite-urile din scenă.
shader_type sky;

uniform vec3 culoare_sus : source_color = vec3(0.13, 0.40, 0.88);
uniform vec3 culoare_orizont : source_color = vec3(0.70, 0.86, 1.0);
uniform vec3 culoare_jos : source_color = vec3(0.86, 0.92, 1.0);
uniform vec3 culoare_nori : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 culoare_soare : source_color = vec3(1.0, 0.92, 0.75);
uniform sampler2D tex_zgomot : filter_linear_mipmap, repeat_enable;
uniform float nori = 0.55;

void sky() {
	vec3 d = EYEDIR;
	float y = d.y;
	vec3 c = mix(culoare_orizont, culoare_sus, smoothstep(0.02, 0.7, y));
	// marea de nori de dedesubt: alb-albăstrui, mai luminos aproape de orizont
	c = mix(c, culoare_jos, smoothstep(0.0, -0.25, y));
	// nori moi lângă orizont (deasupra) și ondulații în marea de dedesubt
	vec2 p = d.xz / max(abs(y) + 0.18, 0.18);
	float n = texture(tex_zgomot, p * 0.11).r * 0.65 + texture(tex_zgomot, p * 0.29 + 0.37).r * 0.35;
	float sus = smoothstep(0.55, 0.78, n) * smoothstep(0.45, 0.04, y) * smoothstep(-0.02, 0.05, y);
	float jos = smoothstep(0.45, 0.75, n) * smoothstep(0.0, -0.12, y);
	c = mix(c, culoare_nori, clamp(sus * nori + jos * 0.6, 0.0, 1.0));
	// soarele: disc mic + strălucire largă
	if (LIGHT0_ENABLED) {
		float s = max(dot(d, LIGHT0_DIRECTION), 0.0);
		c += culoare_soare * (pow(s, 900.0) * 6.0 + pow(s, 24.0) * 0.35 + pow(s, 4.0) * 0.08);
	}
	COLOR = c;
}
