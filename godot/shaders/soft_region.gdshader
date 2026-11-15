shader_type canvas_item;
// Estompează marginile unei imagini (sau ale unei regiuni din ea), ca să se
// contopească cu fundalul. region = zona din textură, în coordonate UV.
uniform vec4 region = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 fade = vec4(0.05, 0.05, 0.05, 0.05);   // stânga, sus, dreapta, jos

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 l = (UV - region.xy) / region.zw;
	float a = smoothstep(0.0, fade.x, l.x) * smoothstep(0.0, fade.y, l.y)
		* smoothstep(0.0, fade.z, 1.0 - l.x) * smoothstep(0.0, fade.w, 1.0 - l.y);
	COLOR = vec4(c.rgb, c.a * a) * COLOR;
}
