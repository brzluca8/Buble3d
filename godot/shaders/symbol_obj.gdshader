shader_type spatial;
// Obiectul din bulă (monedă, sac, cristal...): o singură plasă cu culori pe vârfuri, saturată.
// Alfa culorii codifică metalul (0.5 = metal, 1 = mat). `glow` = strălucire la câștig.
instance uniform float glow = 0.0;

void fragment() {
	vec3 c = pow(COLOR.rgb, vec3(2.2));
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = clamp(mix(vec3(l), c, 1.35), 0.0, 1.0);          // mai saturat
	float metal = COLOR.a < 0.75 ? 1.0 : 0.0;
	ALBEDO = c;
	METALLIC = metal * 0.7;
	ROUGHNESS = mix(0.4, 0.25, metal);
	EMISSION = c * (0.32 + glow * 2.2);
}
