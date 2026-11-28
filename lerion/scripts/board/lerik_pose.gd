extends "res://scripts/board/part_rig.gd"
## Lerik's rig. Joints (model space, before the 1.2 body scale):
##   neck, shoulders, hips; head-attached ears, eyes (blink), goggles; backpack, tail and scarf end.
## Pose keys (radians unless noted):
##   lift, lean, roll, twist, squash          root
##   head_yaw, head_pitch, head_roll           head (ears, eyes, goggles follow)
##   arm_l, arm_r (swing), raise_l, raise_r    shoulders
##   leg_l, leg_r                              hips
##   ear_l, ear_r, ear_back                    ear flick (sideways) and fold back
##   blink (0..1), goggles (0..1 over the eyes) face
##   pack_pitch, pack_roll, pack_lift          backpack (secondary motion)
##   tail_pitch, tail_yaw, scarf               tail and scarf end (secondary motion)
const NECK := Vector3(0,0.73,0)
const SHOULDER := Vector3(0.32,0.66,0.025)
const HIP := Vector3(0.18,0.33,0)
const EAR := Vector3(0.27,1.15,0.0)
const EYES := Vector3(0,0.99,0.32)
const GOGGLES := Vector3(0,1.2,0.12)
const PACK := Vector3(0,0.66,-0.18)
const TAIL := Vector3(0,0.24,-0.27)
const SCARF := Vector3(0.12,0.74,-0.2)
@onready var head: Node3D = find_child("Cap",true,false)


func apply(pose: Dictionary) -> void:
	apply_root(pose)
	for i in range(2):
		var side := -1.0 if i == 0 else 1.0
		var tag := "_l" if i == 0 else "_r"
		var lift := Basis(Vector3.BACK,side*(0.12 + v(pose,"raise" + tag)))
		set_part(["BratStang","BratDrept"][i],hinge(SHOULDER*Vector3(side,1,1),lift*Basis(Vector3.RIGHT,v(pose,"arm" + tag))))
		set_part(["PiciorStang","PiciorDrept"][i],hinge(HIP*Vector3(side,1,1),Basis(Vector3.RIGHT,v(pose,"leg" + tag))))
	var turn := Basis(Vector3.UP,v(pose,"head_yaw"))*Basis(Vector3.RIGHT,v(pose,"head_pitch"))*Basis(Vector3.BACK,v(pose,"head_roll"))
	var skull := hinge(NECK,turn)
	set_part("Cap",skull)
	for i in range(2):
		var side := -1.0 if i == 0 else 1.0
		var flick := v(pose,"ear_l" if i == 0 else "ear_r")
		var ear_turn := Basis(Vector3.BACK,-side*flick)*Basis(Vector3.RIGHT,-v(pose,"ear_back"))
		set_part(["UrecheStanga","UrecheDreapta"][i],skull*hinge(EAR*Vector3(side,1,1),ear_turn))
	var lid := clampf(1.0 - v(pose,"blink"),0.1,1.0)
	set_part("Ochi",skull*Transform3D(Basis.from_scale(Vector3(1,lid,1)),EYES - Basis.from_scale(Vector3(1,lid,1))*EYES))
	var raise := v(pose,"goggles")
	# goggles = 1 pulls them down over the eyes (adventurer mode), 0 is the usual forehead position.
	set_part("Ochelari",skull*Transform3D(Basis(Vector3.RIGHT,0.18*raise),Vector3(0,-0.215*raise,0.06*raise)))
	set_part("Rucsac",hinge(PACK,Basis(Vector3.RIGHT,v(pose,"pack_pitch"))*Basis(Vector3.BACK,v(pose,"pack_roll"))).translated(Vector3(0,v(pose,"pack_lift"),0)))
	set_part("Coada",hinge(TAIL,Basis(Vector3.UP,v(pose,"tail_yaw"))*Basis(Vector3.RIGHT,v(pose,"tail_pitch"))))
	set_part("CapatEsarfa",hinge(SCARF,Basis(Vector3.RIGHT,v(pose,"scarf"))*Basis(Vector3.BACK,0.3*v(pose,"scarf"))))


## Compatibility with the Etapa 2 API (stride, crouch, cheer, glance), used by older tests and tools.
func pose(stride: float, crouch: float, cheer: float, glance := 0.0) -> void:
	apply({"lift": position.y - rest_position.y, "lean": rotation.x, "roll": rotation.z, "twist": rotation.y,
		"squash": 1.0 - scale.y/maxf(0.001,rest_scale.y),
		"arm_l": -stride*0.93 - 0.24*crouch, "arm_r": stride*0.93 - 0.24*crouch, "raise_l": cheer*2.0, "raise_r": cheer*2.0,
		"leg_l": stride*0.78 + crouch*0.33, "leg_r": -stride*0.78 + crouch*0.33,
		"head_yaw": glance, "head_pitch": crouch*0.20 - cheer*0.19, "head_roll": stride*0.07 + cheer*0.09})


## Simple breathing idle (kept for tools); the game uses LerikAnimator.
func idle(age: float) -> void:
	var breath := sin(age*2.35)
	var look := sin(age*0.83)*smoothstep(0.12,0.88,sin(age*0.49))
	apply({"lift": 0.004 + 0.015*breath, "lean": 0.012*breath, "twist": 0.025*look,
		"arm_l": -0.04*breath - 0.01, "arm_r": 0.04*breath - 0.01, "leg_l": 0.035*breath, "leg_r": -0.035*breath,
		"head_yaw": 0.27*look, "head_pitch": 0.009*(breath + 1.0), "head_roll": 0.003*breath})
