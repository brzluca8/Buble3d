extends Node
## Character Animation Controller for Lerik. Presentation only: it never reads or changes the save.
##
## Layers, evaluated every frame and written to the rigid-part rig (lerik_pose.gd):
##   1. base state     IDLE (breathing, looking around), WATCH (ready stance, eyes on the dice),
##                     RUN (stride cycle locked to distance travelled, lean, final jump)
##   2. one-shot clip  keyframed poses authored as data in CLIPS (landing, joy, comic reactions,
##                     idle fidgets), blended in and out; can be interrupted at any time
##   3. secondary      damped springs on backpack, ears, tail and scarf, driven by the real
##                     acceleration of the body, so every jump and stop moves them naturally
##   4. face           automatic blinking (sometimes a double blink)
## This is not skeletal animation: Lerik's model has no skeleton. A skinned model with the same
## part names can replace it; the clip data then becomes the reference for authored animations.
signal clip_finished(name: String)
enum State { IDLE, WATCH, RUN }
const BASE_LIFT := 0.02
## Clips: name -> [duration, [[time, pose], ...]]. Missing joints are neutral. Times are seconds.
const CLIPS := {
	"land": [0.5, [
		[0.0, {"squash": 0.24, "leg_l": 0.35, "leg_r": 0.35, "raise_l": 0.5, "raise_r": 0.5, "head_pitch": 0.22, "lean": 0.12}],
		[0.09, {"squash": 0.1, "leg_l": 0.15, "leg_r": 0.15, "raise_l": 0.7, "raise_r": 0.7}],
		[0.2, {"squash": -0.07, "lift": 0.2, "raise_l": 1.3, "raise_r": 1.3, "arm_l": -0.3, "arm_r": -0.3, "head_pitch": -0.18, "leg_l": -0.25, "leg_r": -0.25}],
		[0.33, {"squash": 0.0, "lift": 0.24, "raise_l": 1.5, "raise_r": 1.5, "head_pitch": -0.2, "twist": 0.0}],
		[0.43, {"squash": 0.1, "lift": 0.0, "raise_l": 0.4, "raise_r": 0.4}],
		[0.5, {}]]],
	"land_big": [0.9, [
		[0.0, {"squash": 0.28, "leg_l": 0.4, "leg_r": 0.4, "raise_l": 0.5, "raise_r": 0.5, "head_pitch": 0.25, "lean": 0.14}],
		[0.12, {"squash": 0.16, "leg_l": 0.3, "leg_r": 0.3, "head_pitch": 0.1}],
		[0.3, {"squash": -0.1, "lift": 0.46, "twist": 3.14, "raise_l": 2.4, "raise_r": 2.4, "leg_l": -0.5, "leg_r": -0.5, "ear_back": 0.3, "head_pitch": -0.25}],
		[0.5, {"squash": -0.04, "lift": 0.52, "twist": 6.283, "raise_l": 2.6, "raise_r": 2.6, "leg_l": -0.4, "leg_r": -0.4, "head_pitch": -0.3}],
		[0.62, {"squash": 0.18, "lift": 0.0, "twist": 6.283, "raise_l": 1.0, "raise_r": 2.4, "arm_r": -0.6, "leg_l": 0.3, "leg_r": 0.3}],
		[0.76, {"squash": -0.03, "lift": 0.05, "twist": 6.283, "raise_r": 2.7, "arm_r": -0.9, "head_pitch": -0.15}],
		[0.9, {"twist": 6.283}]]],
	"pass_cheer": [0.42, [
		[0.0, {}], [0.12, {"raise_l": 1.6, "raise_r": 1.6, "head_pitch": -0.2, "ear_back": -0.2}], [0.3, {"raise_l": 1.4, "raise_r": 1.4}], [0.42, {}]]],
	"wow": [0.38, [
		[0.0, {}], [0.08, {"squash": 0.1, "leg_l": 0.2, "leg_r": 0.2}],
		[0.2, {"lift": 0.18, "squash": -0.06, "raise_l": 2.0, "raise_r": 2.0, "head_pitch": -0.25, "ear_back": -0.3}],
		[0.32, {"squash": 0.06, "raise_l": 1.2, "raise_r": 1.2}], [0.38, {}]]],
	"hmm": [0.4, [
		[0.0, {}], [0.15, {"head_roll": 0.32, "head_yaw": 0.15, "raise_r": 1.6, "arm_r": -1.2, "ear_r": 0.3}],
		[0.3, {"head_roll": 0.3, "raise_r": 1.5, "arm_r": -1.1, "ear_r": 0.25}], [0.4, {}]]],
	"nod": [0.3, [[0.0, {}], [0.1, {"head_pitch": 0.25}], [0.2, {"head_pitch": -0.05}], [0.3, {}]]],
	"surprise": [0.8, [
		[0.0, {}], [0.07, {"lift": 0.16, "shift_z": -0.08, "squash": -0.12, "raise_l": 2.2, "raise_r": 2.2, "ear_back": -0.4, "head_pitch": -0.3, "blink": 0.0}],
		[0.2, {"lift": 0.12, "shift_z": -0.1, "raise_l": 2.0, "raise_r": 2.0, "ear_back": -0.4, "head_pitch": -0.25}],
		[0.34, {"lift": 0.0, "squash": 0.08, "shift_z": -0.1, "raise_l": 1.2, "raise_r": 1.2}],
		[0.55, {"shift_z": -0.05, "head_roll": 0.1, "raise_l": 0.3, "raise_r": 0.3}], [0.8, {}]]],
	"confused": [1.0, [
		[0.0, {}], [0.18, {"head_roll": 0.48, "ear_l": 0.55, "ear_r": -0.2, "raise_r": 2.4, "arm_r": -0.6, "lean": -0.04, "roll": 0.06}],
		[0.34, {"head_roll": 0.42, "ear_l": 0.55, "raise_r": 2.6, "arm_r": -0.8, "head_yaw": 0.14, "roll": 0.06}],
		[0.5, {"head_roll": 0.48, "ear_l": 0.55, "raise_r": 2.4, "arm_r": -0.6, "head_yaw": -0.12, "roll": 0.06}],
		[0.66, {"head_roll": 0.44, "ear_l": 0.5, "raise_r": 2.6, "arm_r": -0.8, "roll": 0.05}],
		[0.84, {"head_roll": 0.1, "raise_r": 0.5}], [1.0, {}]]],
	"wobble": [1.0, [
		[0.0, {}], [0.1, {"roll": 0.22, "raise_l": 1.8, "raise_r": 0.3, "leg_r": -0.3, "shift_x": 0.05, "head_roll": -0.2}],
		[0.24, {"roll": -0.26, "raise_l": 0.3, "raise_r": 1.9, "leg_l": -0.3, "shift_x": -0.06, "head_roll": 0.25, "ear_l": 0.3}],
		[0.38, {"roll": 0.18, "raise_l": 1.6, "raise_r": 0.4, "leg_r": -0.25, "shift_x": 0.04, "head_roll": -0.15}],
		[0.52, {"roll": -0.1, "raise_l": 0.6, "raise_r": 1.2, "squash": 0.06}],
		[0.66, {"squash": 0.14, "lift": 0.0, "raise_l": 0.9, "raise_r": 0.9}],
		[0.8, {"squash": -0.05, "lift": 0.08, "raise_l": 1.6, "raise_r": 0.2, "head_pitch": -0.15}], [1.0, {}]]],
	"look_around": [2.4, [
		[0.0, {}], [0.4, {"head_yaw": -0.75, "head_pitch": -0.06, "ear_l": -0.15, "twist": -0.12}],
		[1.0, {"head_yaw": -0.7, "head_pitch": -0.05, "twist": -0.1}],
		[1.45, {"head_yaw": 0.75, "head_pitch": -0.08, "ear_r": 0.15, "twist": 0.12}],
		[2.0, {"head_yaw": 0.7, "twist": 0.1}], [2.4, {}]]],
	"goggles": [1.4, [
		[0.0, {}], [0.25, {"raise_r": 2.4, "raise_l": 2.4, "arm_r": -0.5, "arm_l": -0.5, "head_pitch": -0.08}],
		[0.45, {"raise_r": 2.6, "raise_l": 2.6, "arm_r": -0.6, "arm_l": -0.6, "goggles": 1.0, "head_pitch": -0.15, "blink": 1.0}],
		[0.8, {"raise_r": 2.5, "raise_l": 2.5, "arm_r": -0.55, "arm_l": -0.55, "goggles": 0.85, "head_roll": 0.08}],
		[1.05, {"raise_r": 2.2, "raise_l": 2.2, "goggles": 0.0, "squash": 0.05}], [1.4, {}]]],
	"hitch_pack": [0.9, [
		[0.0, {}], [0.2, {"lift": 0.05, "squash": -0.04, "pack_lift": 0.07, "raise_l": 0.6, "raise_r": 0.6, "arm_l": 0.4, "arm_r": 0.4}],
		[0.36, {"squash": 0.06, "pack_lift": -0.02, "roll": 0.06}], [0.55, {"roll": -0.05}], [0.9, {}]]],
	"stretch": [1.6, [
		[0.0, {}], [0.4, {"raise_l": 2.8, "raise_r": 2.8, "lean": -0.12, "squash": -0.08, "head_pitch": -0.35, "blink": 1.0}],
		[0.95, {"raise_l": 2.85, "raise_r": 2.85, "lean": -0.14, "squash": -0.09, "head_pitch": -0.38, "blink": 1.0}],
		[1.25, {"raise_l": 0.4, "raise_r": 0.4, "squash": 0.04}], [1.6, {}]]],
}
const IDLE_CLIPS := ["look_around", "goggles", "hitch_pack", "stretch"]

var pawn: Node3D
var rig: Node3D
var shade: Node3D
var state := State.IDLE
var age := 0.0
var clip := ""
var clip_time := 0.0
var clip_weight := 0.0
var clip_speed := 1.0
var watch_target := Vector3.ZERO
var run_step := 0.0
var run_origin := 0.0
var run_steps := 1
var run_bank := 0.0
var run_cycles := 1.0
var idle_timer := 6.0
var blink_timer := 2.0
var blink := 0.0
var double_blink := false
var reduced := false
var intensity := 1.0
var rng := RandomNumberGenerator.new()
# Secondary motion: value and velocity per channel.
var spring := {"pack_pitch": Vector2.ZERO, "pack_roll": Vector2.ZERO, "ear_l": Vector2.ZERO, "ear_r": Vector2.ZERO,
	"ear_back": Vector2.ZERO, "tail_pitch": Vector2.ZERO, "tail_yaw": Vector2.ZERO, "scarf": Vector2.ZERO}
var last_world := Vector3.ZERO
var last_velocity := Vector3.ZERO
var has_history := false
var last_pose: Dictionary = {}


func setup(owner_pawn: Node3D, body: Node3D, shadow: Node3D) -> void:
	pawn = owner_pawn
	rig = body
	shade = shadow
	rng.randomize()
	set_process(true)


# ---- Commands from the game -------------------------------------------------------------------

func watch_dice(target: Vector3) -> void:
	state = State.WATCH
	watch_target = target
	idle_timer = 8.0


## Short reaction while the dice settle, chosen from the confirmed sum.
func react_to_dice(total: int) -> void:
	play("wow" if total >= 10 else ("hmm" if total <= 3 else "nod"))


func start_run(origin: float, steps: int, tile_length: float) -> void:
	state = State.RUN
	run_origin = origin
	run_steps = maxi(1,steps)
	run_step = origin
	# Two footfalls per stride; a stride covers about 0.9 m, so the feet keep pace with the ground.
	run_cycles = tile_length/0.9
	if clip in ["nod", "hmm"]:
		stop_clip()


func drive_run(step: float, bank: float) -> void:
	run_step = step
	run_bank = bank


func cheer_pass() -> void:
	play("pass_cheer")


## Landing on the final tile. `kind` is "normal", "big" (rare reward) or "empty" (START, no reward).
## `total` lets the dice result trigger an occasional comic reaction.
func land(kind := "normal", total := 7) -> void:
	state = State.IDLE
	idle_timer = 5.0 + rng.randf()*4.0
	var comic := ""
	if total == 2:
		comic = "confused"
	elif total == 12:
		comic = "surprise"
	elif kind != "big" and rng.randf() < 0.12:
		comic = "wobble"
	if comic != "" and not reduced:
		play(comic)
	else:
		play("land_big" if kind == "big" else "land")


func play(name: String, speed := 1.0) -> void:
	if not CLIPS.has(name):
		return
	clip = name
	clip_time = 0.0
	clip_speed = speed*(1.6 if reduced else 1.0)


func stop_clip() -> void:
	if clip != "":
		var ended := clip
		clip = ""
		clip_weight = 0.0
		clip_finished.emit(ended)


## Jump straight to rest (Grăbește, profile switch, tests).
func settle() -> void:
	state = State.IDLE
	stop_clip()
	for key: String in spring:
		spring[key] = Vector2.ZERO
	has_history = false
	_write(_idle_pose())


func busy() -> bool:
	return clip != "" or state != State.IDLE


# ---- Evaluation -------------------------------------------------------------------------------

static func sample(name: String, time: float) -> Dictionary:
	return sample_keys(CLIPS[name][1],time)


## Interpolates a list of [time, pose] keys with ease-in-out between neighbours.
static func sample_keys(keys: Array, time: float) -> Dictionary:
	if time <= float(keys[0][0]):
		return (keys[0][1] as Dictionary).duplicate()
	for i in range(keys.size() - 1):
		var a: Array = keys[i]
		var b: Array = keys[i + 1]
		if time <= float(b[0]):
			var u := smoothstep(0.0,1.0,(time - float(a[0]))/maxf(0.0001,float(b[0]) - float(a[0])))
			return blend(a[1],b[1],u)
	return (keys[-1][1] as Dictionary).duplicate()


static func blend(a: Dictionary, b: Dictionary, w: float) -> Dictionary:
	var out := {}
	for key in a:
		out[key] = float(a[key])*(1.0 - w)
	for key in b:
		out[key] = float(out.get(key,0.0)) + float(b[key])*w
	return out


func _idle_pose() -> Dictionary:
	var breath := sin(age*2.35)
	var look := sin(age*0.83)*smoothstep(0.12,0.88,sin(age*0.49))
	return {"lift": 0.004 + 0.012*breath, "lean": 0.012*breath, "twist": 0.02*look,
		"arm_l": -0.04*breath - 0.02, "arm_r": 0.04*breath - 0.02, "raise_l": 0.04, "raise_r": 0.04,
		"leg_l": 0.03*breath, "leg_r": -0.03*breath, "head_yaw": 0.25*look, "head_pitch": 0.01*(breath + 1.0),
		"head_roll": 0.004*breath, "ear_l": 0.04*sin(age*0.6), "ear_r": -0.04*sin(age*0.7 + 1.0)}


func _watch_pose() -> Dictionary:
	var local := pawn.to_local(watch_target)
	var yaw := clampf(atan2(local.x,local.z),-1.1,1.1)
	var bounce := sin(age*13.0)
	return {"lift": 0.01 + 0.012*absf(bounce), "squash": 0.05 + 0.02*bounce, "lean": 0.1, "twist": yaw*0.35,
		"head_yaw": yaw*0.65, "head_pitch": 0.18, "raise_l": 0.35, "raise_r": 0.35, "arm_l": -0.55, "arm_r": -0.55,
		"leg_l": 0.25, "leg_r": 0.25, "ear_back": -0.15}


func _run_pose() -> Dictionary:
	var travelled := run_step - run_origin
	var final := float(run_steps)
	var phase := travelled*run_cycles
	var stride := sin(TAU*phase)
	var contact := absf(cos(TAU*phase))
	var pose := {"lift": 0.075*(1.0 - contact), "squash": 0.05*contact - 0.03, "lean": 0.17*intensity + 0.02,
		"roll": -run_bank*0.32, "twist": 0.06*stride, "arm_l": -stride*0.95, "arm_r": stride*0.95,
		"raise_l": 0.18, "raise_r": 0.18, "leg_l": stride*0.85, "leg_r": -stride*0.85,
		"head_pitch": -0.05 + 0.04*contact, "head_roll": -0.04*stride + run_bank*0.25, "head_yaw": run_bank*0.6,
		"ear_back": 0.12}
	# The last tile is a jump: short crouch, take-off, tucked flight, and the landing clip follows.
	var p := travelled - (final - 1.0)
	if p > 0.0:
		var jump := {}
		if p < 0.2:
			var c := p/0.2
			jump = {"squash": 0.16*c, "lift": -0.02*c, "leg_l": 0.35*c, "leg_r": 0.35*c, "raise_l": 0.3, "raise_r": 0.3,
				"arm_l": 0.5*c, "arm_r": 0.5*c, "lean": 0.24, "head_pitch": 0.15*c}
		else:
			var u := clampf((p - 0.2)/0.8,0.0,1.0)
			var arc := sin(PI*u)
			jump = {"lift": 0.42*arc*intensity + 0.02, "squash": -0.09*arc + 0.08*smoothstep(0.85,1.0,u), "lean": 0.1 - 0.15*arc,
				"leg_l": -0.55*arc, "leg_r": -0.35*arc, "raise_l": 0.4 + 1.2*arc, "raise_r": 0.4 + 1.2*arc,
				"arm_l": -0.6*arc, "arm_r": -0.6*arc, "head_pitch": -0.15*arc, "ear_back": 0.35*arc}
		pose = blend(pose,jump,smoothstep(0.0,0.12,p))
	return pose


func _process(delta: float) -> void:
	if rig == null:
		return
	delta = minf(delta,1.0/15.0)
	age += delta
	var pose: Dictionary
	match state:
		State.WATCH: pose = _watch_pose()
		State.RUN: pose = _run_pose()
		_: pose = _idle_pose()
	if clip != "":
		clip_time += delta*clip_speed
		var length := float(CLIPS[clip][0])
		var fade_in := clampf(clip_time/0.07,0.0,1.0)
		var fade_out := clampf((length - clip_time)/0.1,0.0,1.0)
		clip_weight = minf(fade_in,fade_out) if clip_time > 0.0 else 0.0
		var key_pose := sample(clip,clip_time)
		if key_pose.has("twist"):
			# Spins end on a full turn; wrap so fading out never unwinds them.
			key_pose = key_pose.duplicate()
			key_pose.twist = wrapf(float(key_pose.twist),-PI,PI)
		pose = blend(pose,key_pose,clip_weight)
		if clip_time >= length:
			stop_clip()
	elif state == State.IDLE:
		idle_timer -= delta
		if idle_timer <= 0.0 and not reduced:
			play(IDLE_CLIPS[rng.randi_range(0,IDLE_CLIPS.size() - 1)])
			idle_timer = 7.0 + rng.randf()*6.0
	_blink(delta)
	pose["blink"] = maxf(float(pose.get("blink",0.0)),blink)
	_secondary(delta,pose)
	pose["lift"] = float(pose.get("lift",0.0)) + BASE_LIFT
	_write(pose)


func _blink(delta: float) -> void:
	blink_timer -= delta
	if blink_timer <= 0.0:
		var t := -blink_timer
		blink = sin(PI*clampf(t/0.13,0.0,1.0))
		if t >= 0.13:
			blink = 0.0
			if double_blink:
				double_blink = false
				blink_timer = 0.12
			else:
				double_blink = rng.randf() < 0.2
				blink_timer = 2.2 + rng.randf()*3.5


## Damped springs driven by the body's real acceleration in Lerik's own frame.
func _secondary(delta: float, pose: Dictionary) -> void:
	var world := rig.global_position
	if not has_history or world.distance_to(last_world) > 1.2:
		last_world = world
		last_velocity = Vector3.ZERO
		has_history = true
	var velocity := (world - last_world)/maxf(delta,0.001)
	var accel := ((velocity - last_velocity)/maxf(delta,0.001)).limit_length(40.0)
	last_world = world
	last_velocity = velocity
	var local := pawn.global_basis.inverse()*accel
	var speed := (pawn.global_basis.inverse()*velocity).z
	var forces := {"pack_pitch": -local.z*0.010 + local.y*0.004, "pack_roll": -local.x*0.008,
		"ear_l": -local.y*0.004, "ear_r": -local.y*0.004, "ear_back": local.z*0.006,
		"tail_pitch": -local.z*0.008 - local.y*0.006, "tail_yaw": -local.x*0.012, "scarf": -local.z*0.006}
	var rest := {"scarf": clampf(-speed*0.22,-0.9,0.2)}
	for key: String in spring:
		var s: Vector2 = spring[key]
		var stiffness := 90.0 if key.begins_with("ear") else 70.0
		var damping := 9.0
		var acc := stiffness*(float(rest.get(key,0.0)) - s.x) - damping*s.y + float(forces[key])*stiffness*intensity
		s.y += acc*delta
		s.x = clampf(s.x + s.y*delta,-0.7,0.7)
		spring[key] = s
		pose[key] = float(pose.get(key,0.0)) + s.x


func _write(pose: Dictionary) -> void:
	last_pose = pose
	rig.apply(pose)
	if shade:
		shade.scale = Vector3.ONE*clampf(1.0 - 0.45*(float(pose.get("lift",0.0)) - BASE_LIFT),0.6,1.05)
