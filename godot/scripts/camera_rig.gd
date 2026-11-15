class_name CameraRig
extends Camera3D
## Cameră cinematografică 2.5D: perspectivă oblică fixă, cu distorsiune redusă (FOV mic,
## lățimea cadrului fixă), rotație limitată la ±25°, zoom, mișcări amortizate și
## focalizare pe clădirea selectată.
##   tragere = rotire ușoară (orizontal) + înclinare (vertical, limitată)
##   ciupire / rotiță = zoom      atingere = selectare      reset_view() = vederea implicită

var buildings: Array = []                  # Array[Building]

# --- compoziția implicită (comparată cu randarea de referință) ---
const HOME_TARGET := Vector3(0.0, -0.2, 1.0)
const HOME_YAW := 0.0                      # privește insula din față (scările spre noi)
const HOME_PITCH := deg_to_rad(33.0)       # unghi față de orizontală
const HOME_DIST := 39.0
const FOV_W := 25.0                        # FOV orizontal (KEEP_WIDTH) – perspectivă „aplatizată"

const YAW_LIMIT := deg_to_rad(25.0)
const PITCH_MIN := deg_to_rad(24.0)
const PITCH_MAX := deg_to_rad(55.0)
const DIST_MIN := 14.0
const DIST_MAX := 50.0
const FOCUS_DIST := 22.0
const DAMP := 6.0

var target := HOME_TARGET
var yaw := HOME_YAW
var pitch := HOME_PITCH
var dist := HOME_DIST
# valorile „dorite" spre care camera alunecă lin
var _t_target := HOME_TARGET
var _t_yaw := HOME_YAW
var _t_pitch := HOME_PITCH
var _t_dist := HOME_DIST

var _touches := {}
var _pinch_d := 0.0
var _drag := 0.0
var _pressed := false
var _multi := false


func _ready() -> void:
	keep_aspect = Camera3D.KEEP_WIDTH
	fov = FOV_W
	near = 0.5
	far = 400.0
	Game.selected.connect(_on_selected)
	_apply(1.0)


## Vederea generală implicită (butonul ⟲ din interfață).
func reset_view() -> void:
	_t_target = HOME_TARGET
	_t_yaw = HOME_YAW
	_t_pitch = HOME_PITCH
	_t_dist = HOME_DIST


## Apropie camera lin de un punct (clădirea selectată).
func focus(point: Vector3, height: float) -> void:
	_t_target = point + Vector3(0, height * 0.42, 0)
	_t_dist = FOCUS_DIST
	_t_pitch = deg_to_rad(36.0)
	# păstrează orientarea curentă, dar o aduce puțin spre clădire
	_t_yaw = clampf(atan2(point.x, 12.0) * 0.6, -YAW_LIMIT, YAW_LIMIT)


func _on_selected(id: String) -> void:
	if id == "":
		reset_view()
		return
	for b in buildings:
		if b.id == id:
			focus(b.global_position, Models.HEIGHT.get(id, 4.0))


func _process(dt: float) -> void:
	_apply(1.0 - exp(-DAMP * dt))


func _apply(k: float) -> void:
	target = target.lerp(_t_target, k)
	yaw = lerpf(yaw, _t_yaw, k)
	pitch = lerpf(pitch, _t_pitch, k)
	dist = lerpf(dist, _t_dist, k)
	var dir := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	var pos := target + dir * dist
	# nu coborî sub nivelul insulei
	pos.y = maxf(pos.y, target.y + 3.0)
	look_at_from_position(pos, target)


# ---------------- intrare ----------------
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
				_zoom(_pinch_d / d)
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
					_pick(e.position)
				_multi = false
		elif e.pressed and e.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom(0.9)
		elif e.pressed and e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(1.1)
	elif e is InputEventMouseMotion and _pressed:
		if _touches.size() >= 2 or _multi:
			_drag += 99.0
			return
		var r: Vector2 = e.relative
		_t_yaw = clampf(_t_yaw - r.x * 0.004, -YAW_LIMIT, YAW_LIMIT)
		_t_pitch = clampf(_t_pitch + r.y * 0.003, PITCH_MIN, PITCH_MAX)
		_drag += absf(r.x) + absf(r.y)
	elif e is InputEventMagnifyGesture:
		_zoom(1.0 / e.factor)


func _zoom(f: float) -> void:
	_t_dist = clampf(_t_dist * f, DIST_MIN, DIST_MAX)
	# la zoom apropiat, ținta coboară spre piață; la depărtare revine spre centrul insulei
	var k := inverse_lerp(DIST_MIN, DIST_MAX, _t_dist)
	if Game.sel == "":
		_t_target = HOME_TARGET.lerp(Vector3(_t_target.x, 0.6, _t_target.z), 1.0 - k)


func _pinch_dist() -> float:
	var v := _touches.values()
	return (v[0] as Vector2).distance_to(v[1]) if v.size() >= 2 else 0.0


func _pick(screen: Vector2) -> void:
	var from := project_ray_origin(screen)
	var dir := project_ray_normal(screen)
	# 1) selecție exactă: raza lovește triunghiurile reale ale clădirilor
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 500.0, Building.PICK_LAYER)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit and hit.collider and hit.collider.has_meta("building"):
		Game.select(hit.collider.get_meta("building"))
		return
	# 2) rezervă: cutia aproximativă (ex. dacă un model nu are plase)
	var best := ""
	var best_d := INF
	for b in buildings:
		var d: float = b.ray_hit(from, dir)
		if d >= 0.0 and d < best_d:
			best_d = d
			best = b.id
	Game.select(best)
