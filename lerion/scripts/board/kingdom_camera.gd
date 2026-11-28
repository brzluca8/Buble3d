extends "res://scripts/map_camera.gd"
## Camera Director. User pan/zoom stays in the overview pose; cinematic shots are transient:
##   OVERVIEW (whole map) -> DICE (dice focus) -> TRACK (follow Lerik, 3-5 tiles ahead)
##   -> LAND (reward focus, held briefly) -> RETURN (back to the overview), plus CRYSTAL.
## `motion` sets how much the camera moves: 0 full, 1 gentle (farther, no yaw, no kicks),
## 2 fixed (no cinematic shots, like reduced effects). Building bounds passed in `occluders`
## lift the follow camera when a roof would hide Lerik.
enum Shot { OVERVIEW, DICE, TRACK, LAND, RETURN, CRYSTAL }
var motion := 0
var occluders: Array[AABB] = []
var target_yaw := 0.0
const TRACK_YAW := 0.11
var shot := Shot.OVERVIEW
var target_eye := Vector3.ZERO
var target_pitch := 0.0
var landing_hold := 0.0
var manual_override := false
var reduced := false

func _ready() -> void:
	super()
	set_process(false)

func _eye(center: Vector3, radius: float, angle: float, yaw := 0.0) -> Vector3:
	return center + Basis(Vector3.UP,yaw)*Vector3(0, sin(angle), cos(angle)) * radius


func still() -> bool:
	return reduced or motion >= 2


func reach() -> float:
	return 1.22 if motion == 1 else 1.0


## Small downward nudge on a dice impact. Absorbed by the normal smoothing, no shake.
func kick(strength: float) -> void:
	if still() or motion > 0 or shot == Shot.OVERVIEW:
		return
	position += Vector3(0,-0.07,0.02)*clampf(strength,0.0,1.0)


## Raises the camera until no building box sits between the eye and Lerik's face.
func _clear_eye(center: Vector3, radius: float, pitch: float, yaw: float, face: Vector3) -> Vector3:
	var eye := _eye(center,radius,pitch,yaw)
	for attempt in range(4):
		var blocked := false
		for box: AABB in occluders:
			if box.intersects_segment(eye,face) != null:
				blocked = true
				break
		if not blocked:
			break
		pitch = minf(pitch + deg_to_rad(5.0),deg_to_rad(70.0))
		target_pitch = pitch
		eye = _eye(center,radius,pitch,yaw)
	return eye

func frame_throw(lane: Vector3) -> void:
	manual_override = still()
	if still():
		return_home()
		return
	shot = Shot.DICE
	# Move along the viewing ray so the winning face is still the nearest face.
	target_eye = global_position.lerp(lane + Vector3.UP * 0.65, 0.13)
	var angle := atan2(target_eye.y-lane.y, maxf(1.0,target_eye.z-lane.z))
	target_pitch = lerpf(-rotation.x, angle, 0.30)
	set_process(true)

func track_path(here: Vector3, ahead: Vector3) -> void:
	if manual_override or still():
		return
	shot = Shot.TRACK
	target_pitch = deg_to_rad(53.0)
	# Mostly north-up; a small yaw leans the view into the direction of travel so the curve ahead
	# opens up instead of the camera swinging round it.
	var heading := ahead - here
	target_yaw = 0.0 if motion > 0 else clampf(heading.x*0.04,-TRACK_YAW,TRACK_YAW)
	target_eye = _clear_eye(here.lerp(ahead,0.36) + Vector3.UP*0.44,15.6*reach(),target_pitch,target_yaw,here + Vector3.UP*1.3)
	set_process(true)

func frame_landing(point: Vector3, walked: bool) -> void:
	if manual_override or not walked:
		return_home()
		return
	shot = Shot.LAND
	# Reward focus: a little closer and held long enough to read the prize next to Lerik.
	target_pitch = deg_to_rad(50.0)
	target_yaw *= 0.5
	target_eye = _clear_eye(point + Vector3.UP*0.8,13.6*reach(),target_pitch,target_yaw,point + Vector3.UP*1.3)
	landing_hold = 0.75

## Holds a close view of the Super Crystal until return_home(). Skipped with reduced motion.
func frame_crystal(point: Vector3) -> void:
	if still():
		return
	shot = Shot.CRYSTAL
	target_yaw = 0.0
	target_pitch = deg_to_rad(36.0)
	target_eye = _eye(point + Vector3.UP*0.9, 9.5, target_pitch)
	set_process(true)

func return_home() -> void:
	shot = Shot.RETURN
	target_yaw = 0.0
	target_pitch = deg_to_rad(pitch_degrees)
	target_eye = _eye(focus,distance,target_pitch)
	set_process(true)

func _process(delta: float) -> void:
	var rate := 5.0 if shot == Shot.DICE else (3.2 if shot == Shot.CRYSTAL else 8.0)
	var weight := 1.0-exp(-rate*delta)
	position = position.lerp(target_eye,weight)
	rotation.x = lerpf(rotation.x,-target_pitch,weight)
	rotation.y = lerp_angle(rotation.y,target_yaw,weight*0.6)
	if shot == Shot.LAND:
		landing_hold -= delta
		if landing_hold <= 0.0:
			return_home()
	elif shot == Shot.RETURN and position.distance_squared_to(target_eye) < 0.0004:
		shot = Shot.OVERVIEW
		rotation.y = 0.0
		_update_pose()
		set_process(false)

func _move_view(previous: Vector2, current: Vector2, scale_factor := 1.0) -> void:
	if shot == Shot.OVERVIEW:
		super(previous,current,scale_factor)
		return
	manual_override = true
	var visible_pose := transform
	_update_pose()
	super(previous,current,scale_factor)
	transform = visible_pose
	return_home()

func _frame() -> void:
	var visible_pose := transform
	super()
	if shot != Shot.OVERVIEW:
		transform = visible_pose
