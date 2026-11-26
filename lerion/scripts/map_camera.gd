extends Camera3D

signal map_tapped(screen_point: Vector2)

const PITCH := 29.0
const DEFAULT_FOV := 58.0
const DEFAULT_ASPECT := 720.0 / 1280.0
const MIN_DISTANCE := 15.0
const MAX_DISTANCE := 27.0
const TAP_SLOP := 13.0
const GROUND := Plane(Vector3.UP, 0)

@export var pitch_degrees := PITCH
@export var max_distance := MAX_DISTANCE
@export var focus := Vector3(0, 0, -0.70)
@export var distance := 24.6
var fingers: Dictionary = {}
var press_point := Vector2.ZERO
var tap_possible := false
var mouse_down := false


func _ready() -> void:
	get_viewport().size_changed.connect(_frame)
	get_window().focus_exited.connect(_reset_gesture)
	_frame()


func _reset_gesture() -> void:
	fingers.clear()
	mouse_down = false
	tap_possible = false


func _frame() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var aspect := viewport_size.x / maxf(viewport_size.y, 1.0)
	# Preserve the full clearing on narrow phones, including its outer stone rims.
	fov = rad_to_deg(2.0 * atan(tan(deg_to_rad(DEFAULT_FOV * 0.5)) * maxf(1.0, DEFAULT_ASPECT / aspect)))
	_update_pose()


func _update_pose() -> void:
	focus.x = clampf(focus.x, -3.2, 3.2)
	focus.z = clampf(focus.z, -4.2, 3.5)
	var pitch := deg_to_rad(pitch_degrees)
	position = focus + Vector3(0.0, sin(pitch), cos(pitch)) * distance
	rotation.x = -pitch


func _move_view(previous: Vector2, current: Vector2, scale_factor: float = 1.0) -> void:
	# Rays near the horizon meet the ground far away. Use a nearer pair of
	# rays there, preserving the finger delta so a sky drag pans gently.
	var horizon_guard := get_viewport().get_visible_rect().size.y * 0.22
	var shift := maxf(0.0, horizon_guard - minf(previous.y, current.y))
	previous.y += shift
	current.y += shift
	var before: Variant = GROUND.intersects_ray(project_ray_origin(previous), project_ray_normal(previous))
	distance = clampf(distance * scale_factor, MIN_DISTANCE, max_distance)
	_update_pose()
	var after: Variant = GROUND.intersects_ray(project_ray_origin(current), project_ray_normal(current))
	if before != null and after != null:
		var start: Vector3 = before
		var finish: Vector3 = after
		focus += start - finish
		_update_pose()


# Keep a drag that began on the map when it crosses a HUD control.
func _input(event: InputEvent) -> void:
	if event is InputEventScreenDrag and fingers.has(event.index):
		_drag(event)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and not event.pressed and fingers.has(event.index):
		_touch(event)
		get_viewport().set_input_as_handled()
	elif mouse_down and event is InputEventMouseMotion:
		_slide(event.position - event.relative, event.position)
		get_viewport().set_input_as_handled()
	elif mouse_down and event is InputEventMouseButton and not event.pressed:
		_mouse_button(event)
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		var hud := get_node("../Interfata")
		if hud.blocks_map(event.position):
			return
	if event is InputEventScreenTouch:
		_touch(event)
	elif event is InputEventScreenDrag:
		_drag(event)
	elif event is InputEventMouseButton and fingers.is_empty():
		_mouse_button(event)
	elif event is InputEventMouseMotion and mouse_down:
		_slide(event.position - event.relative, event.position)


func _touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		fingers[event.index] = event.position
		mouse_down = false
		tap_possible = fingers.size() == 1
		press_point = event.position
	elif fingers.has(event.index):
		if tap_possible and not event.canceled and press_point.distance_to(event.position) < TAP_SLOP:
			map_tapped.emit(event.position)
		fingers.erase(event.index)
		tap_possible = false


func _drag(event: InputEventScreenDrag) -> void:
	if not fingers.has(event.index):
		return
	var previous: Vector2 = fingers[event.index]
	fingers[event.index] = event.position
	if fingers.size() == 1:
		_slide(previous, event.position)
	elif fingers.size() == 2:
		var ids := fingers.keys()
		var other: Vector2 = fingers[ids[1] if ids[0] == event.index else ids[0]]
		var factor := maxf(previous.distance_to(other), 1.0) / maxf(event.position.distance_to(other), 1.0)
		_move_view((previous + other) * 0.5, (event.position + other) * 0.5, factor)


func _slide(previous: Vector2, current: Vector2) -> void:
	if tap_possible:
		if current.distance_to(press_point) < TAP_SLOP:
			return
		tap_possible = false
		previous = press_point
	_move_view(previous, current)


func _mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			mouse_down = true
			tap_possible = true
			press_point = event.position
		else:
			if mouse_down and tap_possible and press_point.distance_to(event.position) < TAP_SLOP:
				map_tapped.emit(event.position)
			mouse_down = false
			tap_possible = false
	elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_move_view(event.position, event.position, 0.88)
	elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_move_view(event.position, event.position, 1.0 / 0.88)
