class_name Mascot
extends Node3D
## Mascota este „pionul" de pe traseu: sare din căsuță în căsuță după aruncarea zarurilor
## și sare de bucurie la upgrade / întoarcerea din Buble Blast.
## Dacă res://assets/models/mascota.glb are animații, se folosesc clipurile „idle", „walk"/„run", „jump".

const HOP_TIME := 0.26

var board: Board
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
	Game.mascot_jump.connect(func(): _jump = 1.0)
	Game.selected.connect(func(id): if id != "": _jump = 0.5)
	place_on(Game.pos)


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
	if _mouth:
		_mouth.scale.y = 0.5 + maxf(_jump, 0.0) * 1.5
	if _anim:
		_play("jump" if (moving or _jump > 0.0) else "idle")


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
