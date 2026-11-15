class_name CameraRig
extends Camera3D
## Cameră orbitală: tragere = rotire, ciupire (2 degete) / rotiță = zoom, atingere = selectare.

var buildings: Array = []          # Array[Building]
var target := Vector3(0, 0.5, 0)
var th := 0.15
var ph := 0.95
var dist := 34.0

var _touches := {}                 # index -> poziție (pentru ciupire)
var _pinch_d := 0.0
var _drag := 0.0
var _pressed := false
var _multi := false


func _ready() -> void:
	fov = 45.0
	near = 0.1
	far = 300.0
	var vs := get_viewport().get_visible_rect().size
	dist = 34.0 if vs.x < vs.y else 26.0


func _process(_dt: float) -> void:
	position = target + Vector3(dist * sin(ph) * sin(th), dist * cos(ph), dist * sin(ph) * cos(th))
	look_at(target)


func _unhandled_input(e: InputEvent) -> void:
	# Ciupire: evenimente de atingere brute (doar pentru 2 degete).
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
				dist = clampf(dist * _pinch_d / d, 16.0, 52.0)
			_pinch_d = d
		return
	# Un deget / mouse: Godot emulează mouse-ul din atingere, iar butoanele
	# interfeței consumă clicurile înainte să ajungă aici.
	if e is InputEventMouseButton:
		if e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				_pressed = true
				_drag = 0.0
				_multi = _touches.size() >= 2
			elif _pressed:
				_pressed = false
				if _drag < 12.0 and not _multi:
					_pick(e.position)
				_multi = false
		elif e.pressed and e.button_index == MOUSE_BUTTON_WHEEL_UP:
			dist = clampf(dist * 0.9, 16.0, 52.0)
		elif e.pressed and e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			dist = clampf(dist * 1.1, 16.0, 52.0)
	elif e is InputEventMouseMotion and _pressed:
		if _touches.size() >= 2 or _multi:
			_drag += 99.0
			return
		var r: Vector2 = e.relative
		th -= r.x * 0.006
		ph = clampf(ph - r.y * 0.004, 0.6, 1.3)
		_drag += absf(r.x) + absf(r.y)
	elif e is InputEventMagnifyGesture:
		dist = clampf(dist / e.factor, 16.0, 52.0)


func _pinch_dist() -> float:
	var v := _touches.values()
	return (v[0] as Vector2).distance_to(v[1]) if v.size() >= 2 else 0.0


func _pick(screen: Vector2) -> void:
	var from := project_ray_origin(screen)
	var dir := project_ray_normal(screen)
	var best := ""
	var best_d := INF
	for b in buildings:
		var d: float = b.ray_hit(from, dir)
		if d >= 0.0 and d < best_d:
			best_d = d
			best = b.id
	Game.select(best)
