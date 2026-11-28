extends Node3D
## Rigid-part rig: each GLB part is its own node, pivoted about a joint in model space.
## There is no skeleton. A pose is a Dictionary of named joint values (radians or 0..1 amounts);
## missing keys are neutral. Character scripts (lerik_pose, pongo, pufi) map poses to their parts.
## The root keeps `rest_scale`; `squash` > 0 flattens, < 0 stretches, volume roughly preserved.
var rest_scale := Vector3.ONE
var rest_position := Vector3.ZERO
var parts := {}


func _ready() -> void:
	rest_scale = scale
	rest_position = position


func part(name: String) -> Node3D:
	if not parts.has(name):
		parts[name] = find_child(name,true,false)
	return parts[name]


static func hinge(pivot: Vector3, turn: Basis) -> Transform3D:
	return Transform3D(turn,pivot - turn*pivot)


static func v(pose: Dictionary, key: String, default := 0.0) -> float:
	return float(pose.get(key,default))


func set_part(name: String, xf: Transform3D) -> void:
	var node := part(name)
	if node:
		node.transform = xf


## Root motion shared by every character: lift, lean (pitch), roll, twist and squash and stretch.
func apply_root(pose: Dictionary) -> void:
	var squash := v(pose,"squash")
	position = rest_position + Vector3(v(pose,"shift_x"),v(pose,"lift"),v(pose,"shift_z"))
	rotation = Vector3(v(pose,"lean"),v(pose,"twist"),v(pose,"roll"))
	scale = rest_scale*Vector3(1.0 + squash*0.55,1.0 - squash,1.0 + squash*0.55)
