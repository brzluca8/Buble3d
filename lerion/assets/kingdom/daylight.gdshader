shader_type sky;

// Soft atmospheric gradient behind the distant ridges.
uniform vec4 haze : source_color = vec4(0.75, 0.90, 0.95, 1.0);
uniform vec4 zenith : source_color = vec4(0.26, 0.65, 0.89, 1.0);

void sky() {
	float height = smoothstep(-0.13, 0.08, EYEDIR.y);
	COLOR = mix(haze.rgb, zenith.rgb, height);
}
