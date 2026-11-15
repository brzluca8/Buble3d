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
	_apply_level(false)
	Game.upgraded.connect(_on_upgraded)
	Game.island_completed.connect(func(_i): _apply_level(false))


func _on_upgraded(b: String) -> void:
	if b == id and level_override < 1:
		_apply_level(true)


var _visual: Node3D
var _lvl := -1

## Încarcă modelul nivelului curent (clădirea crește și își schimbă forma).
## Arată clădirea la un nivel anume (ex. orașul unui prieten); -1 = nivelul tău.
var level_override := -1

func show_level(l: int) -> void:
	level_override = l
	_apply_level(false)


func _apply_level(animate: bool) -> void:
	var lvl: int = level_override if level_override >= 1 else Game.levels[id]
	if lvl != _lvl:
		_lvl = lvl
		if _visual:
			_visual.queue_free()
		_visual = Models.instance_level(id, lvl)
		var procedural := _visual == null
		if procedural:
			_visual = Proc.building(id)
		add_child(_visual)
		local_aabb = Models.subtree_aabb(_visual, Transform3D.IDENTITY).grow(0.2)
		_add_colliders(_visual)
		if _lanterns:
			_lanterns.queue_free()
			_lanterns = null
		if procedural:
			# fără modele pe niveluri: felinare + creștere ușoară, ca înainte
			_lanterns = Proc.level_lanterns(lvl)
			add_child(_lanterns)
	_base = 1.0 if Models.has("%s_1" % id) else 1.0 + 0.07 * (lvl - 1)
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


## Forme de coliziune exacte (din triunghiurile modelului) pentru selectarea prin atingere.
## Stau pe stratul 2, folosit doar de cameră pentru raza de selecție.
const PICK_LAYER := 2

func _add_colliders(n: Node) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var shape := (n as MeshInstance3D).mesh.create_trimesh_shape()
		if shape:
			var body := StaticBody3D.new()
			body.collision_layer = PICK_LAYER
			body.collision_mask = 0
			body.set_meta("building", id)
			var cs := CollisionShape3D.new()
			cs.shape = shape
			body.add_child(cs)
			n.add_child(body)
	for c in n.get_children():
		if not (c is StaticBody3D):
			_add_colliders(c)
