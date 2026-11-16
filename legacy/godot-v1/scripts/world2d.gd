extends Node2D
## Lumea 2.5D: imagine pictată + animații peste ea (apă, nori, lumini, scântei,
## clădiri și mascotă care „respiră" și sar la upgrade). Totul e descris în
## res://art2d/layout.json, ca arta nouă să poată fi pusă fără cod.
##
## Imagini opționale care înlocuiesc automat zonele din fundal:
##   res://art2d/buildings/<id>_<nivel>.png   (sau <id>.png)  – clădire decupată
##   res://art2d/mascot/idle.png                              – mascota decupată

const LAYOUT_PATH := "res://art2d/layout.json"
const SOFT := preload("res://shaders/soft_region.gdshader")
const WATER := preload("res://shaders/water2d.gdshader")

var L: Dictionary
var bg_tex: Texture2D
var img_size := Vector2.ONE
var world: Node2D
var cam: Camera2D
var hot := {}                 # id -> Rect2 (pixeli imagine)
var anchors := {}             # id -> Vector2
var pieces := {}              # id -> Node2D (copie a regiunii sau sprite decupat)
var pop := {}                 # id -> progres animație upgrade (0..1)
var mascot: Node2D
var mascot_jump := 0.0
var marker: Node2D
var sparks: CPUParticles2D
var flash: Sprite2D
var glows: Array[Sprite2D] = []
var clouds: Array[Sprite2D] = []
var t := 0.0
var soft_tex: Texture2D

# intrare
var _touches := {}
var _pinch_d := 0.0
var _pressed := false
var _drag := 0.0
var _multi := false
const ZMIN := 0.32
const ZMAX := 1.4


func _ready() -> void:
	L = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_PATH))
	soft_tex = Proc.tex("soft")
	bg_tex = load(L.background)
	img_size = bg_tex.get_size()
	_sky()
	world = Node2D.new()
	world.name = "World"
	add_child(world)
	_background()
	_waterfalls()
	_buildings()
	_mascot()
	_fountain()
	_lights()
	_ambient()
	_front_clouds()
	_marker()
	_sparks()
	_camera()
	add_child(preload("res://scripts/ui/hud.gd").new())
	Game.selected.connect(_on_selected)
	Game.upgraded.connect(_on_upgraded)
	Game.mascot_jump.connect(func(): mascot_jump = 1.0)
	Game.quality_changed.connect(func(_q): _apply_quality())
	_apply_quality()


# ---------------- cer și nori ----------------
func _sky() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -10
	add_child(layer)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([Color(L.sky[0]), Color(L.sky[1]), Color(L.sky[2])])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	var tr := TextureRect.new()
	tr.texture = gt
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(tr)
	# nori îndepărtați, cu paralaxă (se mișcă mai încet decât insula)
	var far := CanvasLayer.new()
	far.layer = -5
	far.follow_viewport_enabled = true
	far.follow_viewport_scale = 0.55
	add_child(far)
	Proc.reseed(31)
	for i in 14:
		var s := Sprite2D.new()
		s.texture = soft_tex
		var w := 4.0 + Proc.rnd() * 5.0
		s.scale = Vector2(w, w * 0.45)
		s.position = Vector2(-900 + Proc.rnd() * 3800, -500 + Proc.rnd() * 3200)
		s.modulate = Color(1, 1, 1, 0.35 + Proc.rnd() * 0.35)
		far.add_child(s)
		clouds.append(s)


func _front_clouds() -> void:
	# câțiva nori moi în fața bazei insulei, pentru adâncime
	Proc.reseed(41)
	for i in 6:
		var s := Sprite2D.new()
		s.texture = soft_tex
		var w := 5.0 + Proc.rnd() * 4.0
		s.scale = Vector2(w, w * 0.4)
		s.position = Vector2(-200 + Proc.rnd() * (img_size.x + 400), img_size.y * (0.93 + Proc.rnd() * 0.12))
		s.modulate = Color(1, 1, 1, 0.55 + Proc.rnd() * 0.25)
		world.add_child(s)
		clouds.append(s)


# ---------------- fundal și piese ----------------
func _soft_material(region: Rect2, fade: Vector4) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SOFT
	m.set_shader_parameter("region", Vector4(region.position.x / img_size.x, region.position.y / img_size.y, region.size.x / img_size.x, region.size.y / img_size.y))
	m.set_shader_parameter("fade", fade)
	return m


func _background() -> void:
	var s := Sprite2D.new()
	s.texture = bg_tex
	s.centered = false
	var f: Array = L.get("fade", [0.04, 0.02, 0.04, 0.09])
	s.material = _soft_material(Rect2(Vector2.ZERO, img_size), Vector4(f[0], f[1], f[2], f[3]))
	world.add_child(s)


func _rect(a: Array) -> Rect2:
	return Rect2(a[0], a[1], a[2], a[3])


## Copie a unei zone din fundal, cu margini moi, pivot în `anchor` (pentru animații).
func _region_copy(r: Rect2, anchor: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = bg_tex
	s.centered = false
	s.region_enabled = true
	s.region_rect = r
	s.offset = r.position - anchor
	s.position = anchor
	s.material = _soft_material(r, Vector4(0.08, 0.08, 0.08, 0.03))
	return s


func _cutout(path_base: String, anchor: Vector2, scale_k: float) -> Sprite2D:
	for p in [path_base + ".png", path_base + ".webp"]:
		if ResourceLoader.exists(p):
			var s := Sprite2D.new()
			s.texture = load(p)
			s.centered = false
			s.offset = Vector2(-s.texture.get_width() / 2.0, -s.texture.get_height())
			s.position = anchor
			s.scale = Vector2.ONE * scale_k
			return s
	return null


func _buildings() -> void:
	for id in L.buildings:
		var b: Dictionary = L.buildings[id]
		hot[id] = _rect(b.rect)
		anchors[id] = Vector2(b.anchor[0], b.anchor[1])
		pop[id] = 1.0
		_refresh_building(id)


func _refresh_building(id: String) -> void:
	if pieces.has(id):
		pieces[id].queue_free()
	var lvl: int = Game.levels.get(id, 1)
	var k: float = L.buildings[id].get("scale", 1.0)
	var s := _cutout("res://art2d/buildings/%s_%d" % [id, lvl], anchors[id], k)
	if s == null:
		s = _cutout("res://art2d/buildings/%s" % id, anchors[id], k)
	if s == null:
		s = _region_copy(hot[id], anchors[id])
	world.add_child(s)
	pieces[id] = s


func _mascot() -> void:
	var m: Dictionary = L.mascot
	var anchor := Vector2(m.anchor[0], m.anchor[1])
	hot["mascot"] = _rect(m.rect)
	var s := _cutout("res://art2d/mascot/idle", anchor, m.get("scale", 1.0))
	mascot = s if s else _region_copy(hot["mascot"], anchor)
	world.add_child(mascot)


# ---------------- efecte ----------------
func _waterfalls() -> void:
	for w in L.waterfalls:
		var r := _rect(w)
		var c := ColorRect.new()
		c.position = r.position
		c.size = r.size
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var m := ShaderMaterial.new()
		m.shader = WATER
		m.set_shader_parameter("speed", 0.6 + randf() * 0.4)
		c.material = m
		world.add_child(c)
		# ceață la baza cascadei
		var mist := Sprite2D.new()
		mist.texture = soft_tex
		mist.position = Vector2(r.get_center().x, r.end.y - r.size.y * 0.06)
		mist.scale = Vector2(r.size.x / 128.0 * 2.2, r.size.x / 128.0 * 1.0)
		mist.modulate = Color(1, 1, 1, 0.55)
		mist.set_meta("mist", true)
		world.add_child(mist)
		glows.append(mist)


func _additive() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m


func _fountain() -> void:
	var p := CPUParticles2D.new()
	var f: Array = L.fountain
	p.position = Vector2(f[0], f[1])
	p.amount = 44
	p.lifetime = 0.9
	p.texture = soft_tex
	p.scale_amount_min = 0.05
	p.scale_amount_max = 0.1
	p.direction = Vector2.UP
	p.spread = 55.0
	p.initial_velocity_min = 90.0
	p.initial_velocity_max = 150.0
	p.gravity = Vector2(0, 380)
	p.color = Color(0.9, 0.97, 1.0, 0.85)
	p.material = _additive()
	world.add_child(p)
	var glint := CPUParticles2D.new()
	glint.position = p.position + Vector2(0, 80)
	glint.amount = 12
	glint.lifetime = 1.2
	glint.texture = soft_tex
	glint.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	glint.emission_rect_extents = Vector2(220, 40)
	glint.scale_amount_min = 0.04
	glint.scale_amount_max = 0.09
	glint.gravity = Vector2.ZERO
	glint.initial_velocity_min = 0.0
	glint.initial_velocity_max = 5.0
	glint.color = Color(1, 1, 1, 0.9)
	glint.material = _additive()
	world.add_child(glint)


func _lights() -> void:
	for l in L.lanterns:
		_glow(Vector2(l[0], l[1]), Color(1.0, 0.75, 0.35, 0.55), 1.3)
	for w in L.get("windows", []):
		_glow(Vector2(w[0], w[1]), Color(1.0, 0.72, 0.3, 0.3), w[2] * 2.2)


func _glow(p: Vector2, c: Color, sc: float) -> void:
	var g := Sprite2D.new()
	g.texture = soft_tex
	g.position = p
	g.scale = Vector2.ONE * sc
	g.modulate = c
	g.material = _additive()
	g.set_meta("base", c.a)
	g.set_meta("phase", randf() * TAU)
	world.add_child(g)
	glows.append(g)


func _ambient() -> void:
	# praf magic auriu deasupra insulei
	var p := CPUParticles2D.new()
	p.name = "Praf"
	p.position = img_size * Vector2(0.5, 0.42)
	p.amount = 36
	p.lifetime = 4.0
	p.texture = soft_tex
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = img_size * Vector2(0.45, 0.35)
	p.direction = Vector2.UP
	p.spread = 30.0
	p.initial_velocity_min = 8.0
	p.initial_velocity_max = 25.0
	p.gravity = Vector2.ZERO
	p.scale_amount_min = 0.05
	p.scale_amount_max = 0.12
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0))
	curve.add_point(Vector2(0.3, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	p.color = Color(1.0, 0.92, 0.6, 0.9)
	p.material = _additive()
	world.add_child(p)


func _marker() -> void:
	marker = Node2D.new()
	marker.visible = false
	marker.z_index = 5
	marker.set_script(preload("res://scripts/marker2d.gd"))
	world.add_child(marker)


func _sparks() -> void:
	sparks = CPUParticles2D.new()
	sparks.emitting = false
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.amount = 40
	sparks.lifetime = 1.1
	sparks.texture = soft_tex
	sparks.direction = Vector2.UP
	sparks.spread = 70.0
	sparks.initial_velocity_min = 250.0
	sparks.initial_velocity_max = 520.0
	sparks.gravity = Vector2(0, 700)
	sparks.scale_amount_min = 0.1
	sparks.scale_amount_max = 0.22
	sparks.color = Color(1.0, 0.85, 0.35)
	sparks.material = _additive()
	sparks.z_index = 6
	world.add_child(sparks)
	flash = Sprite2D.new()
	flash.texture = soft_tex
	flash.material = _additive()
	flash.modulate = Color(1, 0.9, 0.6, 0)
	flash.z_index = 4
	world.add_child(flash)


func _apply_quality() -> void:
	var high := Game.quality != "mic"
	var dust := world.get_node_or_null("Praf") as CPUParticles2D
	if dust:
		dust.amount = 36 if high else 14


# ---------------- cameră ----------------
func _camera() -> void:
	cam = Camera2D.new()
	add_child(cam)
	var vs := get_viewport_rect().size
	var z := vs.x / (img_size.x * 0.92)
	cam.zoom = Vector2.ONE * z
	# centrul insulei cade în spațiul liber dintre bara de sus și butoanele de jos
	cam.position = Vector2(img_size.x * 0.5, img_size.y * 0.47 + 110.0 / z)
	cam.make_current()


func _clamp_cam() -> void:
	var vs := get_viewport_rect().size / cam.zoom
	var margin := Vector2(img_size.x * 0.08, img_size.y * 0.1)
	var lo := Vector2.ZERO - margin + vs * 0.5
	var hi := img_size + margin - vs * 0.5
	cam.position.x = clampf(cam.position.x, minf(lo.x, hi.x), maxf(lo.x, hi.x)) if lo.x <= hi.x else img_size.x * 0.5
	cam.position.y = clampf(cam.position.y, minf(lo.y, hi.y), maxf(lo.y, hi.y)) if lo.y <= hi.y else img_size.y * 0.5


func _zoom_by(f: float) -> void:
	cam.zoom = (cam.zoom * f).clamp(Vector2.ONE * ZMIN, Vector2.ONE * ZMAX)
	_clamp_cam()


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		if e.pressed:
			_touches[e.index] = e.position
		else:
			_touches.erase(e.index)
		if _touches.size() >= 2:
			_multi = true
			_pinch_d = _pinch_dist()
		return
	if e is InputEventScreenDrag:
		_touches[e.index] = e.position
		if _touches.size() >= 2:
			var d := _pinch_dist()
			if _pinch_d > 0.0 and d > 0.0:
				_zoom_by(d / _pinch_d)
			_pinch_d = d
		return
	if e is InputEventMouseButton:
		if e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				_pressed = true
				_drag = 0.0
				_multi = _touches.size() >= 2
			elif _pressed:
				_pressed = false
				if _drag < 12.0 and not _multi:
					pick(e.position)
				_multi = false
		elif e.pressed and e.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_by(1.1)
		elif e.pressed and e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_by(0.9)
	elif e is InputEventMouseMotion and _pressed:
		if _touches.size() >= 2 or _multi:
			_drag += 99.0
			return
		cam.position -= e.relative / cam.zoom
		_clamp_cam()
		_drag += e.relative.length()
	elif e is InputEventMagnifyGesture:
		_zoom_by(e.factor)


func _pinch_dist() -> float:
	var v := _touches.values()
	return (v[0] as Vector2).distance_to(v[1]) if v.size() >= 2 else 0.0


## Atingere pe ecran: clădire → selecție; mascotă → salut.
func pick(screen: Vector2) -> void:
	var p := get_canvas_transform().affine_inverse() * screen
	if hot.has("mascot") and hot["mascot"].has_point(p):
		mascot_jump = 1.0
		Sfx.play("pop")
		Game.toast.emit("Salut! Hai să facem insula cea mai frumoasă dintre nori! ✨")
		return
	var best := ""
	var best_area := INF
	for id in L.buildings:
		var r: Rect2 = hot[id]
		if r.has_point(p) and r.get_area() < best_area:
			best = id
			best_area = r.get_area()
	Game.select(best)


func world_to_screen(p: Vector2) -> Vector2:
	return get_canvas_transform() * p


# ---------------- evenimente ----------------
func _on_selected(id: String) -> void:
	marker.visible = id != ""
	if id != "":
		marker.position = anchors[id]
		marker.set("w", hot[id].size.x * 0.75)
		marker.set("h", anchors[id].y - hot[id].position.y)
		Sfx.play("click")


func _on_upgraded(id: String) -> void:
	_refresh_building(id)
	pop[id] = 0.0
	sparks.position = anchors[id] - Vector2(0, hot[id].size.y * 0.45)
	sparks.restart()
	flash.position = hot[id].get_center()
	flash.scale = Vector2.ONE * hot[id].size.x / 128.0 * 1.6
	flash.modulate.a = 0.9


func _process(dt: float) -> void:
	t += dt
	# clădiri: animație „pop" la upgrade (doar întindere, ca să nu se vadă dubluri)
	for id in pieces:
		var s: Node2D = pieces[id]
		if pop[id] < 1.0:
			pop[id] = minf(1.0, pop[id] + dt / 1.0)
			var u: float = pop[id]
			var k := absf(sin(u * PI * 3.0)) * (1.0 - u)
			s.scale = Vector2(1.0 + 0.05 * k, 1.0 + 0.1 * k) * (L.buildings[id].get("scale", 1.0) if s.region_enabled == false else 1.0)
	# mascota respiră; sare la upgrade / atingere
	var breathe := 0.012 * (1.0 + sin(t * 2.2))
	var j := 0.0
	if mascot_jump > 0.0:
		mascot_jump = maxf(0.0, mascot_jump - dt * 1.5)
		j = sin((1.0 - mascot_jump) * PI)
	mascot.scale = Vector2(1.0 + breathe * 0.5 + 0.04 * j, 1.0 + breathe + 0.12 * j)
	mascot.rotation = sin(t * 1.3) * 0.012
	# lumini care pâlpâie, ceață
	for g in glows:
		if g.has_meta("mist"):
			g.modulate.a = 0.45 + 0.12 * sin(t * 1.7 + g.position.x)
		else:
			var ph: float = g.get_meta("phase")
			g.modulate.a = g.get_meta("base") * (0.8 + 0.2 * sin(t * 3.0 + ph) + 0.05 * sin(t * 11.0 + ph))
	for c in clouds:
		c.position.x += dt * 12.0
		if c.position.x > img_size.x + 1200:
			c.position.x = -1200
	if flash.modulate.a > 0.0:
		flash.modulate.a = maxf(0.0, flash.modulate.a - dt * 1.4)
