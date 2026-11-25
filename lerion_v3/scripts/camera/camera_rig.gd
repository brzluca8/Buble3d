class_name CameraRig
extends Node3D
## Cameră fixă înclinată spre castel: vedere de ansamblu sau apropiere care îl urmărește
## pe Lerik. Zoom: ciupire cu două degete (Android), rotița mouse-ului sau butonul din HUD.

const OVERVIEW_TARGET := Vector3(0, 0, 1.2)
const OVERVIEW_DISTANCE := 33.0
const CLOSE_DISTANCE := 15.0
const PITCH_DEG := 55.0
const FOV_WIDTH_DEG := 46.0

var follow_target: Node3D
var camera: Camera3D
var zoom: float = 0.0
var zoom_goal: float = 0.0

var _touches: Dictionary = {}
var _pinch_start_dist := 0.0
var _pinch_start_zoom := 0.0


func _ready() -> void:
	name = "CameraRig"
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.fov = FOV_WIDTH_DEG
	camera.near = 0.3
	camera.far = 300.0
	add_child(camera)
	camera.make_current()
	_apply(true)


func toggle_zoom() -> void:
	zoom_goal = 0.0 if zoom_goal > 0.5 else 1.0


func _process(delta: float) -> void:
	zoom = lerpf(zoom, zoom_goal, minf(1.0, delta * 6.0))
	_apply(false)


func _apply(_instant: bool) -> void:
	var focus := OVERVIEW_TARGET
	if follow_target != null and is_instance_valid(follow_target):
		var f := follow_target.global_position
		focus = OVERVIEW_TARGET.lerp(Vector3(f.x, 0.0, f.z), zoom)
	var dist := lerpf(OVERVIEW_DISTANCE, CLOSE_DISTANCE, zoom)
	var p := deg_to_rad(PITCH_DEG)
	camera.global_position = focus + Vector3(0, sin(p) * dist, cos(p) * dist)
	camera.look_at(focus, Vector3.UP)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_goal = clampf(zoom_goal + 0.15, 0.0, 1.0)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_goal = clampf(zoom_goal - 0.15, 0.0, 1.0)
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_touches[st.index] = st.position
		else:
			_touches.erase(st.index)
		if _touches.size() == 2:
			_pinch_start_dist = _touch_distance()
			_pinch_start_zoom = zoom_goal
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		_touches[sd.index] = sd.position
		if _touches.size() == 2 and _pinch_start_dist > 10.0:
			var ratio := _touch_distance() / _pinch_start_dist
			zoom_goal = clampf(_pinch_start_zoom + (ratio - 1.0) * 1.2, 0.0, 1.0)
	elif event is InputEventMagnifyGesture:
		var mg := event as InputEventMagnifyGesture
		zoom_goal = clampf(zoom_goal + (mg.factor - 1.0), 0.0, 1.0)


func _touch_distance() -> float:
	var pts: Array = _touches.values()
	if pts.size() < 2:
		return 0.0
	return (pts[0] as Vector2).distance_to(pts[1] as Vector2)
