class_name Spinner
extends Node3D
## Animație ieftină, fără AnimationPlayer: rotire continuă și/sau plutire sus-jos.

@export var axis: Vector3 = Vector3.UP
@export var degrees_per_second: float = 30.0
@export var bob_height: float = 0.0
@export var bob_speed: float = 1.5

var _base_y: float = 0.0
var _time: float = 0.0


func _ready() -> void:
	_base_y = position.y


func _process(delta: float) -> void:
	_time += delta
	if degrees_per_second != 0.0:
		rotate_object_local(axis.normalized(), deg_to_rad(degrees_per_second) * delta)
	if bob_height != 0.0:
		position.y = _base_y + sin(_time * bob_speed) * bob_height
