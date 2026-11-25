class_name Lerik
extends Node3D
## Lerik – PLACEHOLDER procedural (râs biped cu ochelari și rucsac), până la modelul real.
## Se deplasează din căsuță în căsuță cu mici sărituri; logica nu depinde de model,
## deci modelul se poate înlocui ulterior fără a rescrie mișcarea.

signal stepped(tile_index: int)
signal move_finished

const HOP_HEIGHT := 0.45
const FAST_FORWARD_SPEED := 4.0
const TILE_TOP := 0.24

var _model: Node3D
var _tween: Tween
var _fast := false
var _target_yaw := 0.0
var _idle_time := 0.0
var _moving := false


func _ready() -> void:
	name = "Lerik"
	_model = Node3D.new()
	_model.name = "Model"
	add_child(_model)
	_model.add_child(_build_mesh())
	_add_ring()
	_add_blob_shadow()


func is_moving() -> bool:
	return _moving


func place_at(tile: BoardTile) -> void:
	position = tile.position + Vector3.UP * TILE_TOP
	_target_yaw = tile.yaw()
	rotation.y = _target_yaw


## Parcurge exact punctele date (câte unul pe căsuță) în `total_duration` secunde.
func move_along(indices: PackedInt32Array, points: PackedVector3Array, total_duration: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_moving = true
	_tween = create_tween()
	_tween.set_speed_scale(FAST_FORWARD_SPEED if _fast else 1.0)
	var hop := total_duration / float(maxi(1, points.size()))
	var from := position
	for k in points.size():
		var to: Vector3 = points[k] + Vector3.UP * TILE_TOP
		_tween.tween_callback(_face.bind(to - from))
		_tween.tween_method(_hop.bind(from, to), 0.0, 1.0, hop)
		_tween.tween_callback(_emit_step.bind(indices[k]))
		from = to
	_tween.tween_callback(_on_finished)


## Grăbește mutarea curentă (sau pe următoarea, dacă zarurile încă se rostogolesc).
func fast_forward() -> void:
	_fast = true
	if _tween != null and _tween.is_valid():
		_tween.set_speed_scale(FAST_FORWARD_SPEED)


func _face(dir: Vector3) -> void:
	if Vector2(dir.x, dir.z).length() > 0.001:
		_target_yaw = atan2(dir.x, dir.z)


func _hop(t: float, a: Vector3, b: Vector3) -> void:
	position = a.lerp(b, t) + Vector3.UP * (sin(t * PI) * HOP_HEIGHT)
	var squash := 1.0 - 0.12 * sin(t * PI * 2.0)
	_model.scale = Vector3(2.0 - squash, squash, 2.0 - squash)


func _emit_step(idx: int) -> void:
	stepped.emit(idx)


func _on_finished() -> void:
	_model.scale = Vector3.ONE
	_fast = false
	_moving = false
	move_finished.emit()


func _process(delta: float) -> void:
	rotation.y = lerp_angle(rotation.y, _target_yaw, minf(1.0, delta * 14.0))
	if not _moving:
		_idle_time += delta
		var s := 1.0 + sin(_idle_time * 3.0) * 0.025
		_model.scale = Vector3(1.0, s, 1.0)


func _add_ring() -> void:
	var ring := MeshInstance3D.new()
	ring.name = "Marker"
	var m := CylinderMesh.new()
	m.top_radius = 0.55
	m.bottom_radius = 0.55
	m.height = 0.02
	m.radial_segments = 20
	ring.mesh = m
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.3, 0.85, 1.0, 0.45)
	ring.material_override = mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position.y = 0.01
	add_child(ring)


func _add_blob_shadow() -> void:
	var blob := MeshInstance3D.new()
	blob.name = "BlobShadow"
	var m := CylinderMesh.new()
	m.top_radius = 0.34
	m.bottom_radius = 0.34
	m.height = 0.01
	m.radial_segments = 16
	blob.mesh = m
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.1, 0.07, 0.03, 0.35)
	blob.material_override = mat
	blob.position.y = 0.02
	add_child(blob)


func _build_mesh() -> MeshInstance3D:
	var fur := Color("e0a35a")
	var fur_dark := Color("c7843f")
	var cream := Color("f6dfb5")
	var dark := Color("231a14")
	var mb := MeshBuilder.new()
	for sx in [-0.13, 0.13]:
		mb.cyl(0.1, 0.11, 0.34, Vector3(sx, 0.2, 0), fur_dark, 8)
		mb.box(Vector3(0.18, 0.08, 0.27), Vector3(sx, 0.04, 0.04), Color("6b4423"))
		mb.cyl(0.065, 0.07, 0.32, Vector3(sx * 2.55, 0.62, 0.02), fur_dark, 6, Vector3(0, 0, -25.0 * signf(sx)))
	mb.sphere(0.32, Vector3(0, 0.6, 0), fur, Vector3(1.0, 1.12, 0.9))
	mb.sphere(0.21, Vector3(0, 0.56, 0.16), cream, Vector3(1, 1.1, 0.7))
	mb.sphere(0.3, Vector3(0, 1.02, 0), fur)
	mb.sphere(0.14, Vector3(0, 0.95, 0.24), cream, Vector3(1.1, 0.85, 0.9))
	mb.sphere(0.05, Vector3(0, 1.0, 0.37), Color("3b2416"), Vector3.ONE, 6, 4)
	for sx in [-0.11, 0.11]:
		mb.sphere(0.045, Vector3(sx, 1.07, 0.26), dark, Vector3.ONE, 6, 4)
		mb.cone(0.1, 0.26, Vector3(sx * 1.7, 1.33, -0.02), fur, 6, Vector3(0, 0, -15.0 * signf(sx)))
		mb.cone(0.03, 0.15, Vector3(sx * 1.95, 1.52, -0.02), dark, 5, Vector3(0, 0, -15.0 * signf(sx)))
		mb.cyl(0.085, 0.085, 0.06, Vector3(sx, 1.19, 0.24), Color("c9a227"), 10, Vector3(80, 0, 0))
		mb.cyl(0.062, 0.062, 0.07, Vector3(sx, 1.19, 0.245), Color("6fd0ff"), 10, Vector3(80, 0, 0))
	mb.cyl(0.302, 0.302, 0.06, Vector3(0, 1.19, 0), Color("5b3a1e"), 14)
	mb.box(Vector3(0.42, 0.46, 0.22), Vector3(0, 0.66, -0.31), Color("4f7a3a"))
	mb.box(Vector3(0.3, 0.16, 0.05), Vector3(0, 0.58, -0.43), Color("3d612d"))
	mb.cyl(0.09, 0.09, 0.46, Vector3(0, 0.94, -0.33), Color("b8452f"), 8, Vector3(0, 0, 90))
	mb.sphere(0.09, Vector3(0, 0.4, -0.27), fur, Vector3.ONE, 6, 4)
	var mi := mb.make_instance("LerikMesh")
	mi.scale = Vector3.ONE * 1.25
	return mi
