shader_type spatial;
// Becurile aparatului (MultiMesh): culoarea din COLOR, intensitatea din INSTANCE_CUSTOM.x.
render_mode unshaded, shadows_disabled;
varying float b;
varying vec3 c;

void vertex() {
	b = INSTANCE_CUSTOM.x;
	c = COLOR.rgb;
}

void fragment() {
	ALBEDO = c * (0.22 + b * 2.8);
}
