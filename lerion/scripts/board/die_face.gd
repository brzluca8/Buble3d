extends Node3D
## Roll a rounded cube over grass. Its support height follows its orientation.
const MODEL := preload("res://assets/board/die.glb")
const NORMALS := [Vector3.BACK,Vector3.RIGHT,Vector3.UP,Vector3.DOWN,Vector3.LEFT,Vector3.FORWARD]
const WIDTH := 1.18
var value := 1
var side := 1.0
var origin := Vector3.ZERO
var rest := Basis.IDENTITY
var shadow: MeshInstance3D
var lacquer := StandardMaterial3D.new()


func _ready() -> void:
	var model := MODEL.instantiate()
	add_child(model)
	lacquer.vertex_color_use_as_albedo = true
	lacquer.roughness = 0.41
	lacquer.metallic_specular = 0.32
	for mesh in model.find_children("*","MeshInstance3D",true,false):
		mesh.material_override = lacquer


func prepare(face: int, end: Vector3, camera: Camera3D) -> void:
	value = face
	origin = end
	var eye := (get_parent() as Node3D).to_global(end + Vector3.UP*WIDTH*0.5).direction_to(camera.global_position)
	var target := Vector3.UP if eye.y > Vector2(eye.x,eye.z).length()*cos(0.14) else Vector3.BACK
	var heading := atan2(eye.x,eye.z) + side*0.14
	rest = Basis(Vector3.UP,heading) * Basis(Quaternion(NORMALS[value-1],target))
	animate(0.0)


func animate(t: float, size_factor := 1.0) -> void:
	lacquer.albedo_color = Color.WHITE.lerp(Color("#ffeab0"),0.55*sin(PI*smoothstep(0.81,1.0,t)))
	var remaining := pow(1.0-t,1.65)
	var rotation_axis := Vector3(1.0,0.15*side,0.22*side).normalized()
	var spin := Basis(rotation_axis,TAU * 1.12 * remaining)
	var pose := spin * rest
	var size_m := WIDTH * size_factor
	basis = pose.scaled(Vector3.ONE*size_m)
	var hop := 0.0
	if t < 0.46:
		hop = 0.50*sin(PI*t/0.46)
	elif t < 0.76:
		hop = 0.17*sin(PI*(t-0.46)/0.30)
	else:
		hop = 0.045*sin(PI*(t-0.76)/0.24)
	# The model has a 0.39 half-core and 0.11 rounding radius on each edge.
	var support := 0.11 + 0.39*(absf(pose.x.y)+absf(pose.y.y)+absf(pose.z.y))
	position = origin + Vector3(-side*0.20*remaining,support*size_m+hop,2.08*remaining)
	shadow.position = Vector3(position.x,origin.y+0.016,position.z)
	shadow.scale = Vector3.ONE * size_factor * (1.0-0.30*hop)
