class_name RivalIsland
extends Node3D
## Fortăreața Furtunii – insula lui Contele Furtună, unde se fac atacurile și jafurile.
## Clădirile reflectă nivelurile rivalului (nivel 0 = ruină). Animații: ciocan care lovește,
## scut care parează, movile de săpat cu comori.

const LAYER := 4                    # stratul de selecție pentru insula rivalului

var bld := {}                       # id -> {"w": Node3D, "m": Node3D, "rubble": Node3D}
var mounds: Array[Node3D] = []
var fx_sparks: CPUParticles3D
var fx_dust: CPUParticles3D
var _t := 0.0
var shown := {}                    # nivelurile afișate (rivalul din poveste sau un jucător real)


func _ready() -> void:
	name = "Rival"
	var terrain := Models.instance("insula")
	add_child(terrain if terrain else Proc.terrain())
	# piața simplă a fortăreței
	Proc.add(self, Proc.cyl(3.0, 3.0, 0.05, 48), Proc.M("stone"), Vector3(0, 0.03, 0.3))
	for info in Game.BUILDINGS:
		var id: String = info.id
		var w := Node3D.new()
		w.position = Vector3(info.x, 0, info.z)
		add_child(w)
		var m := Models.instance_level(id, 5)
		if m == null:
			m = Proc.building(id)
		w.add_child(m)
		_colliders(m, "b:" + id)
		var rubble := Node3D.new()
		for i in 7:
			var r := Proc.add(rubble, Proc.sph(0.35 + 0.1 * (i % 3), 6, 4), Proc.M("ped"), Vector3(cos(i * 2.4) * 0.8, 0.15, sin(i * 2.4) * 0.8))
			r.scale = Vector3(1.2, 0.6, 1.0)
		rubble.visible = false
		w.add_child(rubble)
		bld[id] = {"w": w, "m": m, "rubble": rubble}
	fx_sparks = _particles(Color("ffd86b"), 40, 6.0, 0.09, 3.0)
	fx_dust = _particles(Color(0.85, 0.8, 0.72, 0.8), 30, 2.5, 0.22, 0.0)
	refresh()


func _particles(col: Color, n: int, speed: float, size: float, emit: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = n
	p.lifetime = 1.0
	var m := SphereMesh.new()
	m.radius = size
	m.height = size * 2
	m.radial_segments = 6
	m.rings = 3
	m.material = Proc.mat(col, {"emit": col, "energy": emit} if emit > 0 else {"alpha": col.a})
	p.mesh = m
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -9, 0)
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	add_child(p)
	return p


func _colliders(n: Node, tag: String) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var shape := (n as MeshInstance3D).mesh.create_trimesh_shape()
		if shape:
			var body := StaticBody3D.new()
			body.collision_layer = LAYER
			body.collision_mask = 0
			body.set_meta("rival", tag)
			var cs := CollisionShape3D.new()
			cs.shape = shape
			body.add_child(cs)
			n.add_child(body)
	for c in n.get_children():
		if not (c is StaticBody3D):
			_colliders(c, tag)


func _scale_for(_lvl: int) -> float:
	return 1.0


## Pune modelul nivelului dat pentru clădirea rivalului (aceleași modele pe niveluri ca la jucător).
func _set_model(id: String, lvl: int) -> void:
	var d: Dictionary = bld[id]
	if d.get("lvl", -1) == lvl:
		return
	var m := Models.instance_level(id, lvl)
	if m == null:
		return
	d.m.queue_free()
	d.w.add_child(m)
	_colliders(m, "b:" + id)
	d.m = m
	d.lvl = lvl


## Arată clădirile după nivelurile rivalului.
func refresh(levels := {}) -> void:
	shown = levels if not levels.is_empty() else Game.rival
	for id in bld:
		var lvl: int = int(shown.get(id, 1))
		var d: Dictionary = bld[id]
		_set_model(id, maxi(lvl, 1))
		d.m.visible = lvl > 0
		d.rubble.visible = lvl <= 0
		d.w.scale = Vector3.ONE


func _process(dt: float) -> void:
	_t += dt
	position.y = sin(_t * 0.7) * 0.08


# ---------------- atac ----------------
## Animația atacului: ciocanul cade pe clădire; dacă e parat, apare un scut și ciocanul ricoșează.
func hit(id: String, blocked: bool, new_level: int, cam: Node) -> void:
	var d: Dictionary = bld[id]
	var w: Node3D = d.w
	var h: float = Models.HEIGHT.get(id, 4.0) * w.scale.y
	var hammer := _hammer()
	add_child(hammer)
	var top := w.position + Vector3(0, h + 7.0, 1.0)
	var impact := w.position + Vector3(0, h * 0.85, 0.6)
	hammer.position = top
	hammer.rotation = Vector3(0, 0, -1.2)
	var tw := create_tween()
	tw.tween_property(hammer, "position", impact, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(hammer, "rotation:z", 0.5, 0.4)
	await tw.finished
	if blocked:
		var shield := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = h * 0.75
		sm.height = h * 1.5
		shield.mesh = sm
		shield.material_override = Proc.mat(Color(0.5, 0.85, 1.0, 0.35), {"emit": Color(0.4, 0.8, 1.0), "energy": 1.5, "alpha": 0.35, "double": true})
		shield.position = w.position + Vector3(0, h * 0.5, 0)
		shield.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(shield)
		Sfx.play("pop")
		var bounce := create_tween()
		bounce.tween_property(hammer, "position", impact + Vector3(2.5, 4.0, 2.0), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		bounce.parallel().tween_property(hammer, "rotation:z", -3.0, 0.45)
		bounce.parallel().tween_property(shield, "scale", Vector3.ONE * 1.15, 0.2)
		bounce.tween_property(shield, "scale", Vector3.ZERO, 0.35)
		await bounce.finished
		shield.queue_free()
	else:
		Sfx.play("bomb")
		fx_sparks.position = impact
		fx_sparks.restart()
		fx_dust.position = w.position + Vector3(0, 0.3, 0)
		fx_dust.restart()
		if cam and cam.has_method("shake"):
			cam.shake(0.6)
		var sq := create_tween()
		sq.tween_property(w, "scale", Vector3(w.scale.x * 1.1, w.scale.y * 0.75, w.scale.z * 1.1), 0.12)
		sq.tween_property(w, "scale", Vector3.ONE * _scale_for(maxi(new_level, 1)), 0.35).set_trans(Tween.TRANS_BACK)
		sq.parallel().tween_property(hammer, "position", impact + Vector3(0, 2.0, 0), 0.3)
		await sq.finished
		if new_level > 0:
			_set_model(id, new_level)
		d.m.visible = new_level > 0
		d.rubble.visible = new_level <= 0
	var out := create_tween()
	out.tween_property(hammer, "scale", Vector3.ZERO, 0.25)
	await out.finished
	hammer.queue_free()


func _hammer() -> Node3D:
	var g := Node3D.new()
	Proc.add(g, Proc.cyl(0.12, 0.12, 2.6, 10), Proc.M("brown"), Vector3(0, 1.0, 0))
	Proc.add(g, Proc.box(1.5, 0.8, 0.8), Proc.M("gold"), Vector3(0, 2.4, 0))
	for s in [-1.0, 1.0]:
		Proc.add(g, Proc.cyl(0.42, 0.42, 0.12, 16), Proc.M("gold"), Vector3(s * 0.8, 2.4, 0)).rotation.z = PI / 2
	g.scale = Vector3.ONE * 1.3
	return g


# ---------------- jaf ----------------
const MOUND_SPOTS := [Vector2(-1.8, -0.9), Vector2(0, -1.3), Vector2(1.8, -0.9), Vector2(-2.2, 1.0), Vector2(0, 0.6), Vector2(2.2, 1.0), Vector2(-1.6, 2.8), Vector2(0, 3.2), Vector2(1.6, 2.8)]

func make_mounds() -> void:
	clear_mounds()
	for i in MOUND_SPOTS.size():
		var g := Node3D.new()
		g.position = Vector3(MOUND_SPOTS[i].x, 0.05, MOUND_SPOTS[i].y + 0.3)
		var dirt := Proc.add(g, Proc.sph(0.6, 12, 6), Proc.mat(Color("8a5a36"), {"rough": 0.95}), Vector3(0, 0, 0))
		dirt.scale = Vector3(1.0, 0.45, 1.0)
		dirt.name = "Dirt"
		var lbl := Label3D.new()
		lbl.text = "%d" % (i + 1)
		lbl.font = UiKit.font(900)
		lbl.font_size = 80
		lbl.pixel_size = 0.008
		lbl.outline_size = 12
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.position = Vector3(0, 0.75, 0)
		lbl.name = "Label"
		g.add_child(lbl)
		var body := StaticBody3D.new()
		body.collision_layer = LAYER
		body.collision_mask = 0
		body.set_meta("rival", "m:%d" % i)
		var cs := CollisionShape3D.new()
		var sh := SphereShape3D.new()
		sh.radius = 0.75
		cs.shape = sh
		body.add_child(cs)
		g.add_child(body)
		add_child(g)
		mounds.append(g)


func clear_mounds() -> void:
	for m in mounds:
		m.queue_free()
	mounds.clear()


## Sapă movila i: praf, apoi un cufăr cu monede (sau doar un nor de praf dacă e goală).
func dig(i: int, value: int) -> void:
	var g: Node3D = mounds[i]
	var lbl: Label3D = g.get_node("Label")
	var dirt: Node3D = g.get_node("Dirt")
	fx_dust.position = g.position + Vector3(0, 0.3, 0)
	fx_dust.restart()
	var tw := create_tween()
	tw.tween_property(dirt, "scale", Vector3(1.3, 0.1, 1.3), 0.25)
	await tw.finished
	if value > 0:
		var chest := Node3D.new()
		Proc.add(chest, Proc.box(0.8, 0.5, 0.55), Proc.M("brown"), Vector3(0, 0.25, 0))
		Proc.add(chest, Proc.box(0.84, 0.12, 0.6), Proc.M("gold"), Vector3(0, 0.52, 0))
		for k in 5:
			Proc.add(chest, Proc.cyl(0.1, 0.1, 0.03, 10), Proc.M("gold"), Vector3(-0.2 + k * 0.1, 0.6 + (k % 2) * 0.05, 0.0))
		chest.position = Vector3(0, -0.6, 0)
		chest.scale = Vector3.ONE * 0.2
		g.add_child(chest)
		var up := create_tween()
		up.tween_property(chest, "position:y", 0.05, 0.35).set_trans(Tween.TRANS_BACK)
		up.parallel().tween_property(chest, "scale", Vector3.ONE * 1.2, 0.35)
		fx_sparks.position = g.position + Vector3(0, 0.8, 0)
		fx_sparks.restart()
		lbl.text = "💰 %d" % value
		lbl.modulate = Color("ffe08a")
	else:
		lbl.text = "💨"
	g.set_meta("dug", true)
