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


## Fundația goală (etapa 0): placă de piatră cu un inel auriu și un cristal care plutește.
func _foundation() -> Node3D:
	var g := Node3D.new()
	var r: float = FOOT[id]
	Proc.add(g, Proc.cyl(r, r + 0.1, 0.18, 32), Proc.M("ped"), Vector3(0, 0.09, 0))
	Proc.add(g, Proc.htor(r * 0.8, 0.04, 48, 6), Proc.mat(Color("f6c445"), {"emit": Color("ffb030"), "energy": 1.2}), Vector3(0, 0.2, 0))
	var gem := Proc.add(g, Proc.sph(0.22, 6, 3), Proc.M("gem"), Vector3(0, 1.0, 0))
	gem.name = "Gem"
	var body := StaticBody3D.new()
	body.collision_layer = PICK_LAYER
	body.collision_mask = 0
	body.set_meta("building", id)
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = r
	sh.height = 1.4
	cs.shape = sh
	cs.position.y = 0.7
	body.add_child(cs)
	g.add_child(body)
	return g


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
	if _visual and _lvl <= 0:
		var g := _visual.get_node_or_null("Gem")
		if g:
			g.position.y = 1.0 + sin(Time.get_ticks_msec() / 500.0) * 0.12
			g.rotation.y += dt
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
