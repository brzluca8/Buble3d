class_name Building
extends Node3D
## O clădire din oraș: etapa 0 = fundație goală, etapele 1–5 = modelele pe niveluri
## (clădirea crește și primește detalii). În timpul construcției: schele aurii și timer.

const PICK_LAYER := 2
const FOOT := {"palat": 2.9, "obs": 2.0, "turn": 1.2, "mag": 1.9, "sera": 1.7}

var id := ""
var local_aabb := AABB()
var level_override := -1              # -1 = etapa ta; altfel o etapă anume (orașul altcuiva)
var _visual: Node3D
var _lvl := -1
var _pop := 1.0
var _scaffold: Node3D
var _timer: Label3D


func setup(info: Dictionary) -> void:
	id = info.id
	name = id
	position = Vector3(info.x, 0, info.z)
	_apply_level(false)
	Game.upgraded.connect(_on_upgraded)
	Game.build_started.connect(_on_build_started)
	Game.traveled.connect(_on_traveled)


func _on_upgraded(b: String) -> void:
	if b == id and level_override < 0:
		_apply_level(true)


func _on_build_started(b: String) -> void:
	if b == id:
		_refresh_build()


func _on_traveled(_g: int) -> void:
	_apply_level(false)


func stage() -> int:
	return level_override if level_override >= 0 else int(Game.levels.get(id, 0))


func show_level(l: int) -> void:
	level_override = l
	_apply_level(false)


func _apply_level(animate: bool) -> void:
	var lvl := stage()
	if lvl != _lvl:
		_lvl = lvl
		if _visual:
			_visual.queue_free()
		if lvl <= 0:
			_visual = _foundation()
		else:
			_visual = Models.instance_level(id, lvl)
			if _visual == null:
				_visual = Proc.building(id)
		add_child(_visual)
		local_aabb = Models.subtree_aabb(_visual, Transform3D.IDENTITY).grow(0.2)
		if lvl <= 0:
			local_aabb = AABB(Vector3(-FOOT[id], 0, -FOOT[id]), Vector3(FOOT[id] * 2, 1.0, FOOT[id] * 2))
		_add_colliders(_visual)
	_pop = 0.0 if animate else 1.0
	if animate:
		Sfx.play("upgrade")
	_refresh_build()


## Locul gol de construcție (etapa 0): fundație de piatră în trepte, schele de lemn,
## blocuri de piatră pregătite și un panou de lemn cu prețul primei etape.
var _price: Label3D

func _foundation() -> Node3D:
	var g := Node3D.new()
	var r: float = FOOT[id]
	var stone := Proc.M("ped")
	var wood := Proc.mat(Color("8a5a32"), {"rough": 0.75})
	var wood_lt := Proc.mat(Color("b07a44"), {"rough": 0.7})
	# fundația: două trepte de piatră (dreptunghiulare, ca pentru o clădire)
	Proc.add(g, Proc.box(r * 1.9, 0.22, r * 1.7), stone, Vector3(0, 0.11, 0))
	Proc.add(g, Proc.box(r * 1.6, 0.16, r * 1.4), stone, Vector3(0, 0.3, 0))
	# schele de lemn pe trei laturi, cu scânduri
	var h := 1.6
	var xs := [-r * 0.8, r * 0.8]
	var zs := [-r * 0.7, r * 0.7]
	var pole := Proc.cyl(0.045, 0.045, h, 6)
	for x in xs:
		for z in zs:
			Proc.add(g, pole, wood, Vector3(x, 0.38 + h / 2, z))
	for y in [0.9, 1.6]:
		Proc.add(g, Proc.box(r * 1.7, 0.05, 0.32), wood_lt, Vector3(0, 0.38 + y - 0.38, zs[0]))
		for x in xs:
			Proc.add(g, Proc.box(0.32, 0.05, r * 1.5), wood_lt, Vector3(x, 0.38 + y - 0.38, 0))
	var brace := Proc.add(g, Proc.box(0.04, h * 1.15, 0.04), wood, Vector3(0, 0.38 + h / 2, zs[0]))
	brace.rotation.z = 0.9
	# blocuri de piatră pregătite
	for k in 3:
		Proc.add(g, Proc.box(0.38, 0.26, 0.3), stone, Vector3(-r * 0.35 + k * 0.4, 0.51, r * 0.15))
	Proc.add(g, Proc.box(0.38, 0.26, 0.3), stone, Vector3(-r * 0.15, 0.77, r * 0.15))
	# panoul cu prețul, în față
	Proc.add(g, Proc.cyl(0.04, 0.04, 1.3, 6), wood, Vector3(r * 0.55, 0.65, r * 0.95))
	Proc.add(g, Proc.box(1.5, 0.62, 0.08), wood_lt, Vector3(r * 0.55, 1.2, r * 0.95))
	Proc.add(g, Proc.box(1.58, 0.06, 0.1), Proc.M("gold"), Vector3(r * 0.55, 1.53, r * 0.95))
	_price = Label3D.new()
	_price.font = UiKit.font(900)
	_price.font_size = 54
	_price.pixel_size = 0.0075
	_price.outline_size = 6
	_price.outline_modulate = Color(0.25, 0.12, 0.04, 1.0)
	_price.modulate = Color("ffe9a8")
	_price.position = Vector3(r * 0.55, 1.2, r * 0.95 + 0.05)
	_price.width = 200
	_price.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	g.add_child(_price)
	_update_price()
	var body := StaticBody3D.new()
	body.collision_layer = PICK_LAYER
	body.collision_mask = 0
	body.set_meta("building", id)
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = r
	sh.height = 1.8
	cs.shape = sh
	cs.position.y = 0.9
	body.add_child(cs)
	g.add_child(body)
	return g


func _update_price() -> void:
	if _price == null or not is_instance_valid(_price):
		return
	var u: Dictionary = Game.next_upgrade(id) if level_override < 0 else {}
	if level_override >= 0:
		_price.text = "Șantier"
	elif u.is_empty():
		_price.text = "Nivel viitor"
	else:
		_price.text = "%s\nmonede" % Game.fmt(int(u.cost))


## Schele aurii și timer cât timp clădirea e în construcție.
func _refresh_build() -> void:
	var on := level_override < 0 and Game.is_building(id)
	if on and _scaffold == null:
		_scaffold = Node3D.new()
		var r: float = FOOT[id] * 0.95
		var h: float = Models.HEIGHT.get(id, 4.0) * 0.7
		var pole := Proc.cyl(0.05, 0.05, h, 6)
		var bar := Proc.box(r * 2, 0.06, 0.06)
		var m := Proc.mat(Color("d8a640"), {"metal": 0.6, "rough": 0.4})
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				Proc.add(_scaffold, pole, m, Vector3(sx * r, h / 2, sz * r))
		for y in [h * 0.33, h * 0.66, h]:
			for sz in [-1.0, 1.0]:
				Proc.add(_scaffold, bar, m, Vector3(0, y, sz * r))
				Proc.rot(Proc.add(_scaffold, bar, m, Vector3(sz * r, y, 0)), 0, PI / 2, 0)
		add_child(_scaffold)
		_timer = Label3D.new()
		_timer.font = UiKit.font(900)
		_timer.font_size = 64
		_timer.pixel_size = 0.012
		_timer.outline_size = 12
		_timer.outline_modulate = Color(0.08, 0.05, 0.25, 0.9)
		_timer.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_timer.no_depth_test = true
		_timer.position = Vector3(0, h + 1.0, 0)
		add_child(_timer)
	elif not on and _scaffold:
		_scaffold.queue_free()
		_timer.queue_free()
		_scaffold = null
		_timer = null


func _process(dt: float) -> void:
	if _timer:
		_timer.text = Game.fmt_time(Game.build_remaining(id))
		_scaffold.rotation.y = sin(Time.get_ticks_msec() / 900.0) * 0.02
		if not Game.is_building(id):
			_refresh_build()
	if _visual and _lvl <= 0 and Engine.get_process_frames() % 30 == 0:
		_update_price()
	if _pop >= 1.0:
		return
	_pop = minf(1.0, _pop + dt / 0.9)
	var t := _pop - 1.0
	var e := 1.0 + 2.7 * t * t * t + 1.7 * t * t
	scale = Vector3(0.8 + 0.2 * e, 0.5 + 0.5 * e, 0.8 + 0.2 * e)


## Distanța de-a lungul razei până la clădire (sau -1).
func ray_hit(from: Vector3, dir: Vector3) -> float:
	var inv := global_transform.affine_inverse()
	var p = local_aabb.intersects_ray(inv * from, inv.basis * dir)
	if p == null:
		return -1.0
	return from.distance_to(global_transform * (p as Vector3))


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
