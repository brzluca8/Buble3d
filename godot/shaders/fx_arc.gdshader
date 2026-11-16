shader_type spatial;
// Arc rupt (VFX): o fâșie curbă aditivă cu capete care se subțiază și o eroziune cu zgomot care
// mănâncă forma spre final (nu doar estompare). `life` 0→1 vine din cod.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.8, 0.4, 1.0);
uniform float intensity = 1.6;
uniform sampler2D noise : filter_linear, repeat_enable;
instance uniform float life = 0.0;

void fragment() {
	float along = UV.x;                         // 0..1 de-a lungul arcului
	float across = abs(UV.y - 0.5) * 2.0;       // 0 în mijloc, 1 pe margini
	float ends = smoothstep(0.0, 0.18, along) * smoothstep(1.0, 0.7, along);
	float body = (1.0 - across * across) * ends;
	float n = texture(noise, vec2(along * 2.0 + life * 0.6, UV.y * 0.5)).r;
	float cut = smoothstep(life * 1.15 - 0.1, life * 1.15 + 0.05, n);   // eroziune spre final
	float hot = pow(1.0 - across, 6.0);         // filet alb fierbinte în centru
	vec3 c = mix(color.rgb, vec3(1.0), hot * 0.6 * (1.0 - life));
	ALBEDO = c * intensity;
	ALPHA = clamp(body * cut * (0.85 - life * 0.35), 0.0, 1.0);
}
