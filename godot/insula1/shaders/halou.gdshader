// Insula 1: halou cald în jurul flăcării unui felinar („lumină caldă falsă”, fără lumini reale, ieftin pe telefon).
// Pătrat întors mereu spre cameră; folosit într-un MultiMesh (un singur apel de desenare pentru toate felinarele).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 culoare : source_color = vec3(1.0, 0.70, 0.32);
uniform float putere = 0.85;
uniform bool animat = true;

varying float v_faza;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
			vec4(0.0, 0.0, 0.0, 1.0));
	v_faza = dot(MODEL_MATRIX[3].xyz, vec3(3.1, 1.7, 2.3));
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float a = pow(max(1.0 - length(p), 0.0), 2.2);
	float k = 1.0;
	if (animat) {
		k = 0.78 + 0.14 * sin(TIME * 11.0 + v_faza) + 0.08 * sin(TIME * 17.3 + v_faza * 1.3);
	}
	ALBEDO = culoare * a * putere * k;
	ALPHA = a;
}
