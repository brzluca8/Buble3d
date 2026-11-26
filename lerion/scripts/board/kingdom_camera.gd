extends "res://scripts/map_camera.gd"
## User pan/zoom stays in the overview pose. Cinematic targets are transient.
enum Shot { OVERVIEW, DICE, TRACK, LAND, RETURN, CRYSTAL }
var shot := Shot.OVERVIEW
var target_eye := Vector3.ZERO
var target_pitch := 0.0
var landing_hold := 0.0
var manual_override := false
var reduced := false

func _ready() -> void:
	super()
	set_process(false)

func _eye(center: Vector3, radius: float, angle: float) -> Vector3:
	return center + Vector3(0, sin(angle), cos(angle)) * radius

func frame_throw(lane: Vector3) -> void:
	manual_override = reduced
	if reduced:
		return_home()
		return
	shot = Shot.DICE
	# Move along the viewing ray so the winning face is still the nearest face.
	target_eye = global_position.lerp(lane + Vector3.UP * 0.65, 0.13)
	var angle := atan2(target_eye.y-lane.y, maxf(1.0,target_eye.z-lane.z))
	target_pitch = lerpf(-rotation.x, angle, 0.30)
	set_process(true)

func track_path(here: Vector3, ahead: Vector3) -> void:
	if manual_override or reduced:
		return
	shot = Shot.TRACK
	target_pitch = deg_to_rad(53.0)
	# Preserve north throughout the turn. The elevated eye clears the roofs.
	target_eye = _eye(here.lerp(ahead,0.36) + Vector3.UP*0.44, 15.6, target_pitch)
	set_process(true)

func frame_landing(point: Vector3, walked: bool) -> void:
	if manual_override or not walked:
		return_home()
		return
	shot = Shot.LAND
	target_pitch = deg_to_rad(51.0)
	target_eye = _eye(point + Vector3.UP*0.8, 14.8, target_pitch)
	landing_hold = 0.42

## Holds a close view of the Super Crystal until return_home(). Skipped with reduced motion.
func frame_crystal(point: Vector3) -> void:
	if reduced:
		return
	shot = Shot.CRYSTAL
	target_pitch = deg_to_rad(36.0)
	target_eye = _eye(point + Vector3.UP*0.9, 9.5, target_pitch)
	set_process(true)

func return_home() -> void:
	shot = Shot.RETURN
	target_pitch = deg_to_rad(pitch_degrees)
	target_eye = _eye(focus,distance,target_pitch)
	set_process(true)

func _process(delta: float) -> void:
	var rate := 5.0 if shot == Shot.DICE else (3.2 if shot == Shot.CRYSTAL else 8.0)
	var weight := 1.0-exp(-rate*delta)
	position = position.lerp(target_eye,weight)
	rotation.x = lerpf(rotation.x,-target_pitch,weight)
	if shot == Shot.LAND:
		landing_hold -= delta
		if landing_hold <= 0.0:
			return_home()
	elif shot == Shot.RETURN and position.distance_squared_to(target_eye) < 0.0004:
		shot = Shot.OVERVIEW
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
