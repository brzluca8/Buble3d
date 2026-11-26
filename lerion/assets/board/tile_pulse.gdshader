shader_type spatial;
render_mode unshaded;
uniform float gleam : hint_range(0.0, 1.0) = 0.0;
uniform vec4 enamel : source_color = vec4(1.0, 0.94, 0.61, 1.0);
void fragment() {
	ALBEDO = mix(COLOR.rgb, enamel.rgb, gleam * 0.84);
}
