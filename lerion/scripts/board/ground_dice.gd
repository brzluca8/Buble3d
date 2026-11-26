extends Node3D
signal ground_hit(strength: float)
var last_contact := -1
var reduced := false
const Die := preload("res://scripts/board/die_face.gd")
const ROLL_TIME := 0.74
const HOLD_TIME := 0.26
const RETIRE_TIME := 0.17
# Throw lanes in the space inside the loop, ordered from foreground towards the fountain.
const LANES := [Vector3(0,0.035,7.25),Vector3(0,0.035,3.48),Vector3(0,0.035,-4.32)]
var faces: Array[Die] = []
var motion: Tween
var impacts := preload("res://scripts/board/dice_impacts.gd").new()


func _ready() -> void:
	add_child(impacts)
	var ink := ShaderMaterial.new()
	ink.shader = preload("res://assets/board/contact_shadow.gdshader")
	var footprint := PlaneMesh.new()
	footprint.size = Vector2(1.62,1.45)
	footprint.material = ink
	for i in range(2):
		var shadow := MeshInstance3D.new()
		shadow.mesh = footprint
		shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(shadow)
		var die := Die.new()
		die.side = -1.0 if i == 0 else 1.0
		die.shadow = shadow
		add_child(die)
		faces.append(die)
	hide()


func _place(camera: Camera3D, safe_rect: Rect2) -> void:
	# Try full-size throws first. Close, off-centre views can use a shorter lane.
	var best := Transform3D.IDENTITY
	var smallest_overflow := INF
	for factor: float in [1.0,0.77,0.58]:
		for lane: Vector3 in LANES:
			for shift: float in [0.0,clampf(camera.position.x,-0.88,0.88)]:
				var placement := Transform3D(Basis.from_scale(Vector3.ONE*factor),lane+Vector3.RIGHT*shift)
				var overflow := 0.0
				for x: float in [-1.9,1.9]:
					for z: float in [-0.94,3.06]:
						for y: float in [0.0,2.3]:
							var screen := camera.unproject_position(placement*Vector3(x,y,z))
							overflow += screen.distance_to(screen.clamp(safe_rect.position,safe_rect.end))
				if overflow < 0.01:
					transform = placement
					return
				if overflow < smallest_overflow:
					smallest_overflow = overflow
					best = placement
	transform = best


func play(pair: Vector2i, camera: Camera3D, safe_rect: Rect2) -> void:
	cancel()
	last_contact = -1
	_place(camera,safe_rect)
	for i in range(2):
		var die := faces[i]
		die.prepare(pair[i],Vector3(die.side*0.98,0,die.side*0.13),camera)
	show()
	motion = create_tween()
	motion.tween_method(_roll,0.0,1.0,ROLL_TIME)
	motion.tween_interval(HOLD_TIME)
	motion.tween_method(_retire,1.0,0.015,RETIRE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	motion.tween_callback(hide)


func _roll(t: float) -> void:
	for die in faces:
		die.animate(t)
	if not reduced:
		impacts.draw_impact(faces,t)
	var contact := 1 if t >= 0.76 else (0 if t >= 0.46 else -1)
	if contact > last_contact:
		ground_hit.emit(1.0 if contact == 0 else 0.46)
		last_contact = contact


func _retire(factor: float) -> void:
	impacts.hide()
	for die in faces:
		die.animate(1.0,factor)


func cancel() -> void:
	if motion:
		motion.kill()
	impacts.hide()
	for die in faces:
		die.animate(1.0)
	hide()
