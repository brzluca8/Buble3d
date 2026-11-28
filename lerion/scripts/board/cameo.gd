extends Node3D
## A short, contextual appearance of Pongo or Pufi on the map. It pops in, plays one authored
## clip, emits `event` at marked moments (hits, sneezes, cheers) so the scene can add effects
## and sound, then pops out and frees itself. Rare by design; never blocks input or state.
signal event(name: String, at: Vector3)
const Animator := preload("res://scripts/board/lerik_animator.gd")
const MODELS := {"pongo": preload("res://assets/board/pongo.glb"), "pufi": preload("res://assets/board/pufi.glb")}
const RIG := preload("res://scripts/board/cameo_rig.gd")
## Clips: [duration, keys, events]. `pop` scales the whole character in and out.
const CLIPS := {
	"pongo_build": [2.5, [
		[0.0, {"pop": 0.0, "lift": 0.5}],
		[0.18, {"pop": 1.12, "lift": 0.0, "squash": 0.22}],
		[0.3, {"pop": 1.0, "squash": 0.0}],
		[0.45, {"pop": 1.0, "raise_r": 2.4, "arm_r": -0.4, "hammer": 0.5, "head_pitch": -0.12}],
		[0.58, {"pop": 1.0, "raise_r": 0.5, "arm_r": -1.3, "hammer": -0.7, "squash": 0.08, "head_pitch": 0.15}],
		[0.72, {"pop": 1.0, "raise_r": 2.4, "arm_r": -0.4, "hammer": 0.5}],
		[0.85, {"pop": 1.0, "raise_r": 0.5, "arm_r": -1.3, "hammer": -0.7, "squash": 0.08, "head_pitch": 0.15}],
		[1.05, {"pop": 1.0, "raise_r": 2.9, "arm_r": 0.2, "hammer": 0.9, "lean": -0.15, "lift": 0.06, "head_pitch": -0.2}],
		[1.22, {"pop": 1.0, "raise_r": 0.3, "arm_r": -1.5, "hammer": -1.0, "squash": 0.26, "lean": 0.2, "head_pitch": 0.25}],
		[1.38, {"pop": 1.0, "raise_r": 0.3, "raise_l": 2.4, "arm_l": -1.2, "leg_l": -0.7, "lift": 0.16, "roll": 0.22, "head_roll": -0.3, "blink": 1.0}],
		[1.55, {"pop": 1.0, "raise_l": 2.2, "arm_l": -1.1, "leg_r": -0.7, "lift": 0.12, "roll": -0.22, "head_roll": 0.3, "blink": 1.0}],
		[1.72, {"pop": 1.0, "raise_l": 2.4, "arm_l": -1.2, "leg_l": -0.6, "lift": 0.14, "roll": 0.18, "head_roll": -0.25}],
		[1.92, {"pop": 1.0, "raise_l": 2.7, "raise_r": 2.7, "lift": 0.3, "squash": -0.12, "head_pitch": -0.25}],
		[2.1, {"pop": 1.0, "squash": 0.15, "lift": 0.0}],
		[2.3, {"pop": 1.06}],
		[2.5, {"pop": 0.0, "lift": 0.3}]],
		[[0.58, "hit"], [0.85, "hit"], [1.22, "big_hit"], [1.92, "cheer"]]],
	"pufi_sneeze": [2.3, [
		[0.0, {"pop": 0.0, "lift": 1.8}],
		[0.25, {"pop": 1.0, "lift": 1.15}],
		[0.5, {"pop": 1.0, "lift": 1.05, "head_pitch": -0.2, "squash": -0.08}],
		[0.72, {"pop": 1.0, "lift": 1.08, "head_pitch": -0.38, "squash": -0.16, "blink": 1.0}],
		[0.84, {"pop": 1.0, "lift": 1.0, "head_pitch": 0.45, "squash": 0.24, "lean": 0.3, "blink": 1.0}],
		[1.02, {"pop": 1.0, "lift": 1.25, "shift_z": -0.35, "roll": 0.45, "head_roll": 0.2}],
		[1.3, {"pop": 1.0, "lift": 1.15, "shift_z": -0.2, "head_roll": 0.25, "blink": 1.0, "raise_l": 1.4, "raise_r": 1.4}],
		[1.55, {"pop": 1.0, "lift": 1.25, "twist": 0.0}],
		[1.95, {"pop": 1.0, "lift": 1.4, "twist": 6.283}],
		[2.1, {"pop": 1.0, "lift": 1.7, "twist": 6.283}],
		[2.3, {"pop": 0.0, "lift": 2.3, "twist": 6.283}]],
		[[0.84, "sneeze"]]],
	"pufi_orbit": [2.6, [
		[0.0, {"pop": 0.0, "lift": 0.6}],
		[0.3, {"pop": 1.0, "lift": 0.4}],
		[1.6, {"pop": 1.0, "lift": 0.7, "roll": -0.3}],
		[1.85, {"pop": 1.0, "lift": 0.6, "head_pitch": -0.35, "squash": -0.15, "blink": 1.0}],
		[1.98, {"pop": 1.0, "lift": 0.55, "head_pitch": 0.45, "squash": 0.22, "lean": 0.3, "blink": 1.0}],
		[2.25, {"pop": 1.0, "lift": 0.9, "raise_l": 1.6, "raise_r": 1.6}],
		[2.6, {"pop": 0.0, "lift": 1.6}]],
		[[1.98, "sneeze"]]],
}
var character := "pongo"
var clip := ""
var time := 0.0
var rig: Node3D
var model: Node3D
var base_scale := 1.0
var fired := {}
var orbit_center := Vector3.ZERO
var orbit := false
var speed := 1.0


func start(who: String, name: String, at: Vector3, look_at_point: Vector3, size := 1.0) -> void:
	character = who
	clip = name
	base_scale = size
	model = MODELS[who].instantiate()
	add_child(model)
	model.set_script(RIG)
	rig = model
	rig.character = who
	rig.rest_scale = Vector3.ONE*size
	var paint := StandardMaterial3D.new()
	paint.vertex_color_use_as_albedo = true
	paint.roughness = 0.68
	paint.metallic_specular = 0.3
	paint.rim_enabled = true
	paint.rim = 0.25
	paint.rim_tint = 0.5
	for part: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		part.material_override = paint
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	global_position = at
	var to := look_at_point - at
	rotation.y = atan2(to.x,to.z)
	_evaluate()


## Pufi's orbit: circles `center` once while the clip plays, facing along the path.
func circle(center: Vector3) -> void:
	orbit = true
	orbit_center = center


func _process(delta: float) -> void:
	if rig == null:
		return
	time += delta*speed
	_evaluate()
	for item: Array in CLIPS[clip][2]:
		if time >= float(item[0]) and not fired.has(item[1] + str(item[0])):
			fired[item[1] + str(item[0])] = true
			event.emit(str(item[1]),global_position + Vector3.UP*(0.9 if character == "pongo" else 1.4))
	if time >= float(CLIPS[clip][0]):
		queue_free()


func _evaluate() -> void:
	var pose := Animator.sample_keys(CLIPS[clip][1],time)
	if pose.has("twist"):
		pose = pose.duplicate()
		pose.twist = wrapf(float(pose.twist),-PI,PI)
	if character == "pufi":
		pose["wings"] = 0.5 + 0.5*sin(time*26.0)
		pose["tail_yaw"] = 0.3*sin(time*6.0)
	pose["blink"] = maxf(float(pose.get("blink",0.0)),1.0 if fposmod(time,2.7) < 0.12 else 0.0)
	var pop := float(pose.get("pop",1.0))
	rig.rest_scale = Vector3.ONE*base_scale*maxf(0.001,pop)
	rig.apply(pose)
	if orbit:
		var u := clampf(time/float(CLIPS[clip][0]),0.0,1.0)
		var a := u*TAU*1.15 - PI*0.5
		var radius := 1.9 - 0.6*u
		global_position = orbit_center + Vector3(cos(a)*radius,0.0,sin(a)*radius)
		rotation.y = atan2(-sin(a),cos(a)) + PI*0.5
