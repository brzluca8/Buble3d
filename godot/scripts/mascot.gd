class_name Mascot
extends Node3D
## Mascota merge spre clădirea selectată și sare la upgrade / întoarcerea din Buble Blast.
## Dacă res://models/mascot.glb are animații, se folosesc clipurile „idle", „walk"/„run", „jump".

var _target := Vector3(0, 0, 5)
var _jump := 0.0
var _ry := 0.0
var _t := 0.0
var _mouth: Node3D
var _anim: AnimationPlayer
var _clip := ""


func _ready() -> void:
	position = _target
	var visual := Models.instance("mascot")
	if visual:
		_anim = Models.find_anim(visual)
	else:
		visual = Proc.mascot()
		_mouth = visual.get_node("Mouth")
	add_child(visual)
	Game.selected.connect(_on_selected)
	Game.mascot_jump.connect(func(): _jump = 1.0)


func _on_selected(id: String) -> void:
	if id == "":
		return
	var b := Game.building(id)
	_target = Vector3(b.x + (-1.9 if b.x > 0 else 1.9), 0, b.z + 2.5)
	_jump = 0.5


func _process(dt: float) -> void:
	_t += dt
	var d := _target - position
	d.y = 0
	var moving := d.length() > 0.1
	var k := minf(1.0, dt * 2.2)
	position.x += d.x * k
	position.z += d.z * k
	var want := atan2(d.x, d.z) if moving else 0.0
	_ry += (want - _ry) * minf(1.0, dt * 5.0)
	rotation.y = _ry
	var y := absf(sin(_t * 10.0)) * 0.12 if moving else sin(_t * 2.0) * 0.03
	if _jump > 0.0:
		y += sin((1.0 - _jump) * PI) * 1.2
		_jump -= dt * 1.4
	position.y = y
	if _mouth:
		_mouth.scale.y = 0.5 + maxf(_jump, 0.0) * 1.5
	if _anim:
		_play("jump" if _jump > 0.0 else ("walk" if moving else "idle"))


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
		_anim.play(pick, 0.25)
