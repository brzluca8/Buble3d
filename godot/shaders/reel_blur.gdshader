shader_type spatial;
// Blur de mișcare peste o rolă: o bandă cu simbolurile întinse vertical, care curge
// odată cu rola. `amount` urmează viteza rolei (0 = oprită).
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform sampler2D strip : filter_linear, repeat_enable;
instance uniform float amount = 0.0;
instance uniform float offset = 0.0;

void fragment() {
	vec4 s = texture(strip, vec2(UV.x, UV.y * 0.34 + offset));
	float edge = smoothstep(0.0, 0.16, UV.y) * smoothstep(1.0, 0.84, UV.y);
	ALBEDO = s.rgb;
	ALPHA = amount * edge * 0.92;
}
