shader_type spatial;
// Obiectul din bulă (monedă, sac, cristal...): o singură plasă cu culori pe vârfuri.
// Alfa culorii codifică metalul (0.5 = metal, 1 = mat). `glow` = strălucire la câștig.
instance uniform float glow = 0.0;

void fragment() {
	vec3 c = pow(COLOR.rgb, vec3(2.2));
	float metal = COLOR.a < 0.75 ? 1.0 : 0.0;
	ALBEDO = c;
	METALLIC = metal * 0.85;
	ROUGHNESS = mix(0.38, 0.2, metal);
	EMISSION = c * (0.18 + glow * 2.2);
}
