// Insula 1 v2: vegetație, steaguri și pânze legănate de vânt (alizeul din Aliseron).
// Vântul e un uniform global (Project Settings > Shader Globals): vant_directie (x, z) și vant_putere.
// COLOR.rgb = culoarea (cu AO coaptă), COLOR.a = cât se mișcă vârful (0 la bază, 1 în vârful frunzei).
// Merge și pe instanțe MultiMesh (MODEL_MATRIX include transformarea instanței).
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

global uniform vec2 vant_directie;
global uniform float vant_putere;
uniform float flexibilitate = 1.0;
uniform float frecventa = 1.6;
uniform bool vant_activ = true;       // oprit la calitatea Mic și la „mișcare redusă”
uniform float rugozitate = 0.85;

void vertex() {
	if (vant_activ) {
		vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float g = COLOR.a * flexibilitate;
		float faza = wp.x * 0.37 + wp.z * 0.29;
		float s = 0.55 + sin(TIME * frecventa + faza) * 0.6 + sin(TIME * frecventa * 2.3 + faza * 1.7) * 0.25;
		vec3 dep = vec3(vant_directie.x, 0.0, vant_directie.y) * vant_putere * s * g * 0.18;
		dep.y -= length(dep) * 0.25;
		// deplasarea e în spațiul lumii; o aducem în spațiul local (instanțele au doar rotație și scară uniformă)
		mat3 m = mat3(MODEL_MATRIX);
		VERTEX += (transpose(m) * dep) / max(dot(m[0], m[0]), 0.0001);
	}
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = rugozitate;
	SPECULAR = 0.25;
}
