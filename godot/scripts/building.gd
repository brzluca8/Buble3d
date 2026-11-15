class_name Building
extends Node3D
## O clădire: model GLB sau procedural, felinare pe nivel, animație la upgrade.

var id := ""
var local_aabb := AABB()
var _base := 1.0
var _pop := 1.0
var _lanterns: Node3D


func setup(info: Dictionary) -> void:
	id = info.id
	name = id
	position = Vector3(info.x, 0, info.z)
	var visual := Models.instance(id)
	if visual == null:
		visual = Proc.building(id)
	add_child(visual)
	local_aabb = Models.subtree_aabb(visual, Transform3D.IDENTITY).grow(0.2)
	_apply_level(false)
	Game.upgraded.connect(_on_upgraded)


func _on_upgraded(b: String) -> void:
	if b == id:
		_apply_level(true)


func _apply_level(animate: bool) -> void:
	var lvl: int = Game.levels[id]
	if _lanterns:
		_lanterns.queue_free()
	_lanterns = Proc.level_lanterns(lvl)
	add_child(_lanterns)
	_base = 1.0 + 0.07 * (lvl - 1)
	_pop = 0.0 if animate else 1.0
	scale = Vector3.ONE * _base


func _process(dt: float) -> void:
	if _pop >= 1.0:
		return
	_pop = minf(1.0, _pop + dt / 0.9)
	var t := _pop - 1.0
	var e := 1.0 + 2.7 * t * t * t + 1.7 * t * t
	scale = Vector3(_base * (0.8 + 0.2 * e), _base * (0.5 + 0.5 * e), _base * (0.8 + 0.2 * e))


## Distanța de-a lungul razei până la clădire (sau -1).
func ray_hit(from: Vector3, dir: Vector3) -> float:
	var inv := global_transform.affine_inverse()
	var lf := inv * from
	var ld := inv.basis * dir
	var p = local_aabb.intersects_ray(lf, ld)
	if p == null:
		return -1.0
	return from.distance_to(global_transform * (p as Vector3))
