// Insula 1 (v4): valuri pe apă, cercuri care se lărgesc (pătrat orizontal, UV 0..1).
//   la barcă: `putere` fix, cercurile pleacă la nesfârșit din jurul ei (barca se leagănă pe valuri);
//   la pești: `putere` o urcă insula1.gd când peștele intră sau iese din apă, apoi scade.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec3 culoare : source_color = vec3(0.82, 0.96, 1.0);
uniform float viteza = 0.32;
uniform bool animat = true;
instance uniform float faza = 0.0;
instance uniform float putere = 0.45;
instance uniform float gol = 0.25;   // raza din mijloc fără cercuri (sub barcă)
instance uniform float progres_fix = -1.0;  // >= 0: un val nou care pornește acum din centru (pești), nu în buclă

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float t = animat ? TIME * viteza + faza : faza;
	float a = 0.0;
	for (int k = 0; k < 3; k++) {
		float pr = fract(t + float(k) / 3.0);
		float vizibil = 1.0;
		if (progres_fix >= 0.0) {
			pr = progres_fix - float(k) * 0.18;
			vizibil = step(0.0, pr) * step(pr, 1.0);
			pr = clamp(pr, 0.0, 1.0);
		}
		float raza = gol + (1.0 - gol) * pr;
		a += smoothstep(0.06, 0.0, abs(r - raza)) * (1.0 - pr) * smoothstep(0.0, 0.12, pr) * vizibil;
	}
	a *= putere * smoothstep(1.0, 0.8, r);
	ALBEDO = culoare * a;
	ALPHA = clamp(a, 0.0, 1.0);
}
