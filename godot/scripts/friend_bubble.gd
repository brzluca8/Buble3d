class_name FriendBubble
extends Node3D
## O bulă de prieten care plutește în jurul globului. Goală = slot „Invită un prieten" (DEMO,
## fără jucători simulați). Cu prieten real = un mini-oraș după nivelul lui; pulsează și primește
## un steag când prietenul te-a vizitat sau ți-a lăsat un cadou.

const LAYER := 8
const RADIUS := 1.3

var slot := 0
var friend := {}                     # {} = slot gol
var _glass: ShaderMaterial
var _inner: Node3D
var _flag: Node3D
var _base := Vector3.ZERO
var _t := 0.0


func setup(i: int, pos: Vector3) -> void:
	slot = i
	_base = pos
	position = pos
	_t = i * 1.7
	var sm := SphereMesh.new()
	sm.radius = RADIUS
	sm.height = RADIUS * 2
	sm.radial_segments = 32
	sm.rings = 16
	_glass = ShaderMaterial.new()
	_glass.shader = preload("res://shaders/glass_globe.gdshader")
	_glass.set_shader_parameter("rim_power", 2.2)
	var g := MeshInstance3D.new()
	g.mesh = sm
	g.material_override = _glass
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.sorting_offset = 1.0
	add_child(g)
	var body := StaticBody3D.new()
	body.collision_layer = LAYER
	body.collision_mask = 0
	body.set_meta("friend", i)
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = RADIUS
	cs.shape = sh
	body.add_child(cs)
	add_child(body)
	show_friend({}, true)


## Arată prietenul (sau slotul gol).
func show_friend(f: Dictionary, demo: bool) -> void:
	friend = f
	if _inner:
		_inner.queue_free()
	_inner = Node3D.new()
	add_child(_inner)
	if f.is_empty():
		_label("+", 120, Vector3(0, 0.15, 0), Color("ffe08a"))
		_label("Invită", 40, Vector3(0, -0.5, 0), Color.WHITE)
		if demo:
			_label("DEMO", 28, Vector3(0, -0.88, 0), Color("ff7a8a"))
	else:
		# mini-oraș: platou de iarbă + palatul la nivelul prietenului
		Proc.add(_inner, Proc.cyl(0.85, 0.7, 0.18, 24), Proc.M("grass"), Vector3(0, -0.55, 0))
		var lvl := 1
		var lv: Dictionary = f.get("levels", {})
		for v in lv.values():
			lvl = maxi(lvl, int(v))
		var m := Models.instance_level("palat", lvl)
		if m:
			m.scale = Vector3.ONE * 0.13
			m.position = Vector3(0, -0.46, -0.1)
			_inner.add_child(m)
		_label(str(f.get("name", "?")), 40, Vector3(0, 1.0, 0), Color.WHITE)
	set_flag(f.get("visited_me", false) or f.get("gift_waiting", false))


func set_flag(on: bool) -> void:
	if _flag:
		_flag.queue_free()
		_flag = null
	_glass.set_shader_parameter("pulse", 0.6 if on else 0.0)
	if on:
		_flag = Node3D.new()
		Proc.add(_flag, Proc.cyl(0.03, 0.03, 0.8, 6), Proc.M("gold"), Vector3(0, 0.4, 0))
		Proc.add(_flag, Proc.box(0.45, 0.26, 0.03), Proc.mat(Color("ff6fa8"), {"emit": Color("ff6fa8"), "energy": 0.6}), Vector3(0.24, 0.66, 0))
		_flag.position = Vector3(0.6, RADIUS * 0.8, 0)
		add_child(_flag)


func _label(text: String, size: int, pos: Vector3, col: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = UiKit.font(900)
	l.font_size = size
	l.pixel_size = 0.0085
	l.outline_size = 10
	l.outline_modulate = Color(0.1, 0.05, 0.3, 0.85)
	l.modulate = col
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = pos
	_inner.add_child(l)


func _process(dt: float) -> void:
	_t += dt
	position = _base + Vector3(sin(_t * 0.4) * 0.25, sin(_t * 0.7) * 0.35, 0)
	if _inner:
		_inner.rotation.y += dt * 0.3
	if _flag:
		_flag.rotation.y = sin(_t * 2.0) * 0.3
