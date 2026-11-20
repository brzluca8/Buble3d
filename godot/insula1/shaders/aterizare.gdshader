// Insula 1: efectul de aterizare pe o căsuță (un pătrat orizontal peste căsuță, UV 0..1).
// Căsuța se aprinde scurt (disc moale) și o undă pleacă din marginea ei spre exterior.
// Un singur material pentru toate: progresul și culoarea sunt pe instanță.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

instance uniform float progres = 0.0;   // 0 -> 1 în timpul animației
instance uniform vec3 culoare = vec3(1.0, 0.86, 0.5);
uniform float raza_casuta = 0.42;       // marginea căsuței, ca fracție din jumătatea pătratului

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float stinge = 1.0 - progres;
	float disc = (1.0 - smoothstep(raza_casuta * 0.75, raza_casuta, r)) * stinge * stinge * 0.45;
	float raza_unda = mix(raza_casuta, 0.96, progres);
	float unda = smoothstep(0.07, 0.0, abs(r - raza_unda)) * stinge;
	float a = disc + unda;
	ALBEDO = culoare * a * 1.5;
	ALPHA = clamp(a, 0.0, 1.0);
}
