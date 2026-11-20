extends Node3D
## O căsuță de joc (Tile.tscn): piatră bej cu gravură în romb și chenar auriu. Căsuțele speciale au iconiță
## în relief și un inel luminos în culoarea tipului. La aterizare: o undă se întinde și căsuța se aprinde scurt.
## Materialul pietrei e comun tuturor căsuțelor (îl dă insula); aprinderea e un uniform pe instanță.

const ICONITE := preload("res://insula_v2/textures/iconite_casute.png")
const UNDA := preload("res://insula_v2/shaders/unda.gdshader")
const Tipuri := preload("res://insula_v2/data/tipuri_casute.gd")

var tip := "simpla"
var culoare := Color(1.0, 0.86, 0.5)
var miscare_redusa := false
var _piatra: GeometryInstance3D
var _inel: MeshInstance3D
var _inel_mat: StandardMaterial3D
var _unda: MeshInstance3D
var _unda_mat: ShaderMaterial
var _t_aprindere := -1.0
var _t_unda := -1.0
var _t := 0.0


func configureaza(tip_casuta: String, mat_piatra: Material) -> void:
	tip = tip_casuta
	culoare = Tipuri.CULORI.get(tip, Tipuri.CULORI["simpla"])
	for n in find_children("*", "MeshInstance3D", true, false):
		_piatra = n as GeometryInstance3D
		break
	if _piatra:
		_piatra.material_override = mat_piatra
		_piatra.set_instance_shader_parameter("culoare_tip", Vector3(culoare.r, culoare.g, culoare.b))
		_piatra.set_instance_shader_parameter("aprindere", 0.0)
	if tip != "simpla":
		_adauga_iconita()
		_adauga_inel()
	_unda = MeshInstance3D.new()
	var plan := PlaneMesh.new()
	plan.size = Vector2(3.2, 3.2)
	_unda.mesh = plan
	_unda_mat = ShaderMaterial.new()
	_unda_mat.shader = UNDA
	_unda_mat.set_shader_parameter("culoare", culoare)
	_unda.material_override = _unda_mat
	_unda.position = Vector3(0.0, 0.03, 0.0)
	_unda.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_unda.visible = false
	add_child(_unda)


func _adauga_iconita() -> void:
	var q := QuadMesh.new()
	q.size = Vector2(0.78, 0.78)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.rotation_degrees = Vector3(-90.0, 0.0, 0.0)  # culcat pe piatră, cu fața în sus
	mi.position = Vector3(0.0, 0.012, 0.0)
	var m := StandardMaterial3D.new()
	m.albedo_texture = ICONITE
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.4
	m.uv1_scale = Vector3(0.2, 1.0, 1.0)
	m.uv1_offset = Vector3(0.2 * float(Tipuri.ICONITA.get(tip, 0)), 0.0, 0.0)
	m.albedo_color = culoare.lightened(0.35)
	m.emission_enabled = true
	m.emission = culoare
	m.emission_energy_multiplier = 0.6
	m.roughness = 0.4
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _adauga_inel() -> void:
	var t := TorusMesh.new()
	t.inner_radius = 0.80
	t.outer_radius = 0.88
	t.rings = 48
	t.ring_segments = 6
	_inel = MeshInstance3D.new()
	_inel.mesh = t
	_inel.position = Vector3(0.0, -0.04, 0.0)
	_inel_mat = StandardMaterial3D.new()
	_inel_mat.albedo_color = culoare
	_inel_mat.emission_enabled = true
	_inel_mat.emission = culoare
	_inel_mat.emission_energy_multiplier = 1.4
	_inel.material_override = _inel_mat
	_inel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_inel)


## cheamă asta când Orion aterizează pe căsuță
func aterizare() -> void:
	_t_aprindere = 0.0
	if not miscare_redusa:
		_t_unda = 0.0
		_unda.visible = true


func _process(delta: float) -> void:
	_t += delta
	if _inel_mat and not miscare_redusa:
		_inel_mat.emission_energy_multiplier = 1.1 + 0.4 * sin(_t * 2.2)
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
		_unda_mat.set_shader_parameter("progres", minf(_t_unda, 1.0))
		if _t_unda >= 1.0:
			_t_unda = -1.0
			_unda.visible = false
