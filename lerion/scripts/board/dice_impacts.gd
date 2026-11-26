extends MultiMeshInstance3D
## Two synchronized fans of motes in one draw, below the painted faces.
func _ready() -> void:
	var clay := StandardMaterial3D.new()
	clay.vertex_color_use_as_albedo = true
	clay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mote := SphereMesh.new()
	mote.radius = 1
	mote.height = 2
	mote.radial_segments = 5
	mote.rings = 1
	mote.material = clay
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mote
	multimesh.instance_count = 16
	for i in range(16):
		multimesh.set_instance_color(i,Color("#ead699") if (i/2)%2 == 0 else (Color("#8be7ff") if i%2 == 0 else Color("#ffcf69")))
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hide()

func draw_impact(faces: Array, t: float) -> void:
	var hit := 0.46 if t < 0.76 else 0.76
	var u := (t-hit)/(0.22 if hit < 0.7 else 0.29)
	visible = u > 0 and u < 1
	if not visible:
		return
	for i in range(16 if multimesh.visible_instance_count < 0 else multimesh.visible_instance_count):
		var die: Node3D = faces[i%2]
		var angle: float = (i/2)*2.4 + die.side*0.4
		var radius := 0.44+0.60*(1.0-pow(1.0-u,2))
		var pos: Vector3 = die.shadow.position + Vector3(cos(angle)*radius,0.06+sin(PI*u)*0.20,sin(angle)*radius)
		var size_m := sin(PI*u)*(0.095 if (i/2)%2 == 0 else 0.069)
		var shape := Vector3(1.4,0.57,1.2) if (i/2)%2 == 0 else Vector3(0.68,1.45,0.68)
		multimesh.set_instance_transform(i,Transform3D(Basis.from_scale(shape*size_m),pos))
