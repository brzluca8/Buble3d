extends Node3D
## O căsuță de joc (casuta/Casuta.tscn): piatră bej cu gravură în romb și chenar auriu. Căsuțele speciale au iconiță
## în relief și un inel luminos în culoarea tipului. La aterizare: o undă se întinde și căsuța se aprinde scurt.
## Materialul pietrei e comun tuturor căsuțelor (îl dă insula); aprinderea e un uniform pe instanță.

const ICONITE := preload("res://insula1/textures/iconite_casute.png")
const UNDA := preload("res://insula1/shaders/unda.gdshader")
const SEMN := preload("res://insula1/shaders/casuta_semn.gdshader")
const Tipuri := preload("res://insula1/data/tipuri_casute.gd")

# materiale comune tuturor căsuțelor (diferențele sunt uniforme pe instanță): mai puține materiale unice
static var _mat_semn: ShaderMaterial
static var _mat_unda: ShaderMaterial

var tip := "simpla"
var baza_scala := 1.0  # căsuța nouă e puțin mai mare decât discul vechi, ca să-i acopere marginea
var culoare := Color(1.0, 0.86, 0.5)
var miscare_redusa := false
var _piatra: GeometryInstance3D
var _inel: MeshInstance3D
var _unda: MeshInstance3D
var _t_aprindere := -1.0
var _t_unda := -1.0
var _t_turtire := -1.0
var _t := 0.0


func configureaza(tip_casuta: String, mat_piatra: Material) -> void:
	tip = tip_casuta
	culoare = Tipuri.CULORI.get(tip, Tipuri.CULORI["simpla"])
	if _mat_semn == null:
		_mat_semn = ShaderMaterial.new()
		_mat_semn.shader = SEMN
		_mat_semn.set_shader_parameter("atlas", ICONITE)
		_mat_semn.set_shader_parameter("puls_activ", not miscare_redusa)
		_mat_unda = ShaderMaterial.new()
		_mat_unda.shader = UNDA
	for n in find_children("*", "MeshInstance3D", true, false):
		_piatra = n as GeometryInstance3D
		break
	var c3 := Vector3(culoare.r, culoare.g, culoare.b)
	if _piatra:
		_piatra.material_override = mat_piatra
		_piatra.set_instance_shader_parameter("culoare_tip", c3)
		_piatra.set_instance_shader_parameter("aprindere", 0.0)
	if tip != "simpla":
		_adauga_iconita(c3)
		_adauga_inel(c3)
	_unda = MeshInstance3D.new()
	var plan := PlaneMesh.new()
	plan.size = Vector2(3.2, 3.2)
	_unda.mesh = plan
	_unda.material_override = _mat_unda
	_unda.set_instance_shader_parameter("culoare", c3)
	_unda.set_instance_shader_parameter("progres", 0.0)
	_unda.position = Vector3(0.0, 0.03, 0.0)
	_unda.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_unda.visible = false
	add_child(_unda)


func _adauga_iconita(c3: Vector3) -> void:
	var q := QuadMesh.new()
	q.size = Vector2(0.98, 0.98)  # v4: mai mare, ca să se citească din camera de joc
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.rotation_degrees = Vector3(-90.0, 0.0, 0.0)  # culcat pe piatră, cu fața în sus
	mi.position = Vector3(0.0, 0.014, 0.0)
	mi.material_override = _mat_semn
	mi.set_instance_shader_parameter("celula", float(Tipuri.ICONITA.get(tip, 0)))
	mi.set_instance_shader_parameter("culoare", c3)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _adauga_inel(c3: Vector3) -> void:
	var t := TorusMesh.new()
	t.inner_radius = 0.81
	t.outer_radius = 0.92
	t.rings = 48
	t.ring_segments = 6
	_inel = MeshInstance3D.new()
	_inel.mesh = t
	_inel.position = Vector3(0.0, -0.04, 0.0)
	_inel.material_override = _mat_semn
	_inel.set_instance_shader_parameter("celula", -1.0)
	_inel.set_instance_shader_parameter("culoare", c3)
	_inel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_inel)


## cheamă asta când Orion aterizează pe căsuță
func aterizare() -> void:
	_t_aprindere = 0.0
	if not miscare_redusa:
		_t_turtire = 0.0
	if not miscare_redusa:
		_t_unda = 0.0
		_unda.visible = true


func _process(delta: float) -> void:
	_t += delta
	if _t_turtire >= 0.0:
		# turtire scurtă (squash and stretch): căsuța se lasă puțin sub Orion și revine elastic
		_t_turtire += delta / 0.35
		var k := clampf(_t_turtire, 0.0, 1.0)
		var sq := 1.0 - 0.18 * sin(k * PI) * (1.0 - k * 0.6)
		scale = Vector3(baza_scala * (1.0 + (1.0 - sq) * 0.5), baza_scala * sq, baza_scala * (1.0 + (1.0 - sq) * 0.5))
		if _t_turtire >= 1.0:
			_t_turtire = -1.0
			scale = Vector3.ONE * baza_scala
	if _t_aprindere >= 0.0:
		_t_aprindere += delta / 0.7
		var a := 1.0 - _t_aprindere
		if _t_aprindere >= 1.0:
			_t_aprindere = -1.0
			a = 0.0
		if _piatra:
			_piatra.set_instance_shader_parameter("aprindere", maxf(a, 0.0))
	if _t_unda >= 0.0:
		_t_unda += delta / 0.8
		_unda.set_instance_shader_parameter("progres", minf(_t_unda, 1.0))
		if _t_unda >= 1.0:
			_t_unda = -1.0
			_unda.visible = false
