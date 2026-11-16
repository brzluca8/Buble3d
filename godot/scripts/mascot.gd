class_name Mascot
extends Node3D
## Mascota (varianta „cască de bulă"): stă, salută, se bucură la upgrade și la câștigurile mari.
## Dacă res://assets/models/mascota.glb are animații, se folosesc clipurile „idle", „walk",
## „wave" (salut), „joy" (bucurie); altfel animația e procedurală (săritură, rotire).

const HOP_TIME := 0.26

var board: Node3D                   # (opțional) un traseu cu stand_pos(i)
var _action := ""
var _action_t := 0.0
var _hops: Array = []
var _hop_from := Vector3.ZERO
var _hop_t := 0.0
var _done := Callable()
var _jump := 0.0
var _ry := 0.0
var _t := 0.0
var _mouth: Node3D
var _anim: AnimationPlayer
var _clip := ""
var _base := Vector3.ZERO


func _ready() -> void:
	var visual := Models.instance("mascot")
	if visual:
		_anim = Models.find_anim(visual)
	else:
		visual = Proc.mascot()
		_mouth = visual.get_node("Mouth")
	add_child(visual)
	apply_cosmetics()
	Game.mascot_jump.connect(joy)
	Game.selected.connect(_on_selected)
	get_tree().create_timer(1.2).timeout.connect(wave)


func _on_selected(id: String) -> void:
	if id != "":
		_jump = 0.5


## Garderoba: aplică piesele echipate (culoarea corpului, eșarfa, casca, ochelarii).
## Nox (asistentul robot): carcasa (perlată / crom / grafit), lumina inelului de la gât
## (magenta / turcoaz / aurie), antena (scurtă / înaltă / cu halou), vizorul auriu.
const BODY := {"corp_crem": Color("eef0f6"), "corp_perlat": Color("c8ced8"), "corp_lavanda": Color("23252e")}
const SCARF := {"esarfa_violet": Color("ff3fa4"), "esarfa_turcoaz": Color("37e8f5"), "esarfa_aur": Color("ffc94a")}
var _extras: Array[Node3D] = []

func apply_cosmetics() -> void:
	var eq: Dictionary = Game.equipped
	_tint("Blana", BODY.get(eq.get("corp", ""), BODY.corp_crem), 0.9 if eq.get("corp", "") == "corp_perlat" else 0.0)
	_tint("Violet", SCARF.get(eq.get("esarfa", ""), SCARF.esarfa_violet), 0.6 if eq.get("esarfa", "") == "esarfa_aur" else 0.0)
	for x in _extras:
		x.queue_free()
	_extras.clear()
	var casca := find_child("Casca", true, false) as Node3D
	if casca:
		casca.scale = Vector3(1, 1.9, 1) if eq.get("casca", "") == "casca_inalta" else Vector3.ONE   # antenă înaltă
		if eq.get("casca", "") == "casca_inel":
			var r := Proc.add(casca, Proc.htor(0.3, 0.02, 40, 6), Proc.mat(Color("ff3fa4"), {"emit": Color("ff3fa4"), "energy": 3.0}))
			r.position = Vector3(0, 0.12, 0)
			_extras.append(r)
	if eq.get("ochelari", "") == "ochelari_aur":
		var g := Node3D.new()
		var body := find_child("Corp", true, false) as Node3D
		(body if body else self).add_child(g)
		# ramă aurie în jurul vizorului
		var v := Proc.add(g, Proc.htor(0.34, 0.02, 40, 6), Proc.M("gold"), Vector3(0, 1.38, 0.33))
		v.rotation.x = PI / 2
		v.scale = Vector3(1.1, 1.0, 0.66)
		_extras.append(g)


func _tint(mat_name: String, col: Color, metal: float) -> void:
	for mi in find_children("*", "MeshInstance3D", true, false):
		var m3 := mi as MeshInstance3D
		if m3.mesh == null:
			continue
		for i in m3.mesh.get_surface_count():
			var m := m3.mesh.surface_get_material(i)
			if m and m.resource_name.get_slice(".", 0) == mat_name:
				var c := (m as BaseMaterial3D).duplicate() as BaseMaterial3D
				c.albedo_color = col
				if c.emission_enabled:
					c.emission = col
				c.metallic = metal
				c.roughness = 0.3 if metal > 0.0 else c.roughness
				m3.set_surface_override_material(i, c)


## Salut (clip „wave" sau rotire ușoară).
func wave() -> void:
	_action = "wave"
	_action_t = 0.0


## Bucurie: săritură cu o rotire completă (clip „joy" dacă există).
func joy() -> void:
	_jump = 1.0
	_action = "joy"
	_action_t = 0.0


## Pune mascota într-un punct fix (ex. în orașul din glob, fără traseu).
func set_home(p: Vector3) -> void:
	_base = p
	position = p


func place_on(i: int) -> void:
	if board:
		_base = board.stand_pos(i)
		position = _base


## Sare prin punctele date, apoi apelează `done`.
func hop_path(points: Array, done: Callable) -> void:
	_hops = points.duplicate()
	_hop_from = _base
	_hop_t = 0.0
	_done = done
	if _hops.is_empty() and done.is_valid():
		done.call()


## Merge (în câteva sărituri) până la un punct oarecare.
func walk_to(p: Vector3) -> void:
	var pts := []
	var n := maxi(1, int(_base.distance_to(p) / 1.6))
	for i in range(1, n + 1):
		pts.append(_base.lerp(p, float(i) / n))
	hop_path(pts, Callable())


func is_hopping() -> bool:
	return not _hops.is_empty()


func _process(dt: float) -> void:
	_t += dt
	var y := 0.0
	var moving := false
	if not _hops.is_empty():
		moving = true
		_hop_t += dt / HOP_TIME
		var to: Vector3 = _hops[0]
		var k := minf(_hop_t, 1.0)
		var p := _hop_from.lerp(to, k)
		p.y += sin(k * PI) * 0.9
		position = p
		var d := to - _hop_from
		if Vector2(d.x, d.z).length() > 0.01:
			_ry = lerp_angle(_ry, atan2(d.x, d.z), minf(1.0, dt * 12.0))
		if _hop_t >= 1.0:
			Sfx.play("click", 1.0 + 0.05 * (_hops.size() % 4))
			_hop_from = to
			_base = to
			_hops.pop_front()
			_hop_t = 0.0
			if _hops.is_empty():
				_jump = 0.6
				if _done.is_valid():
					var cb := _done
					_done = Callable()
					cb.call()
	else:
		# privește spre cameră (spre +Z), respiră
		_ry = lerp_angle(_ry, 0.0, minf(1.0, dt * 4.0))
		y = sin(_t * 2.0) * 0.03
		if _jump > 0.0:
			y += sin((1.0 - _jump) * PI) * 1.0
			_jump -= dt * 1.4
		position = _base + Vector3(0, y, 0)
	rotation.y = _ry
	if _action != "":
		_action_t += dt
		if _action == "joy":
			rotation.y = _ry + minf(_action_t / 0.8, 1.0) * TAU
			if _action_t > 0.8:
				_action = ""
		elif _action == "wave":
			rotation.z = sin(_action_t * 9.0) * 0.08
			if _action_t > 2.0:
				_action = ""
				rotation.z = 0.0
	if _mouth:
		_mouth.scale.y = 0.5 + maxf(_jump, 0.0) * 1.5
	if _anim:
		_play(_action if _action != "" else ("walk" if moving else ("jump" if _jump > 0.0 else "idle")))


func _play(want: String) -> void:
	if want == _clip:
		return
	_clip = want
	var names := _anim.get_animation_list()
	var pick := ""
	for n in names:
		var ln := String(n).to_lower()
		if ln.contains(want) or (want == "walk" and ln.contains("run")):
			pick = n
			break
	if pick == "":
		for n in names:
			if String(n).to_lower().contains("idle"):
				pick = n
				break
	if pick == "" and names.size() > 0:
		pick = names[0]
	if pick != "":
		_anim.play(pick, 0.2)
