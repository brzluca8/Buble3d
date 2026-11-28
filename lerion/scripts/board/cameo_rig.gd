extends "res://scripts/board/part_rig.gd"
## Rig for the side characters (Pongo, Pufi). Same pose keys as Lerik where they apply, plus
## `hammer` (Pongo's hammer swing) and `wings` (Pufi's wing beat). Rigid parts, no skeleton.
var character := "pongo"
const SPEC := {
	"pongo": {"neck": Vector3(0,0.62,0), "shoulder": Vector3(0.3,0.5,0.04), "hip": Vector3(0.15,0.2,0),
		"head_parts": ["Cap","Casca","Ochi","UrecheStanga","UrecheDreapta"], "eyes": Vector3(0,0.85,0.28)},
	"pufi": {"neck": Vector3(0,0.46,0.02), "shoulder": Vector3(0.26,0.42,0.1), "hip": Vector3(0.15,0.16,0),
		"head_parts": ["Cap","Ochi"], "eyes": Vector3(0,0.75,0.24)},
}


func apply(pose: Dictionary) -> void:
	apply_root(pose)
	var spec: Dictionary = SPEC[character]
	var arms := {}
	for i in range(2):
		var side := -1.0 if i == 0 else 1.0
		var tag := "_l" if i == 0 else "_r"
		var shoulder: Vector3 = spec.shoulder*Vector3(side,1,1)
		var lift := Basis(Vector3.BACK,side*(0.1 + v(pose,"raise" + tag)))
		arms[i] = hinge(shoulder,lift*Basis(Vector3.RIGHT,v(pose,"arm" + tag)))
		set_part(["BratStang","BratDrept"][i],arms[i])
		set_part(["PiciorStang","PiciorDrept"][i],hinge(spec.hip*Vector3(side,1,1),Basis(Vector3.RIGHT,v(pose,"leg" + tag))))
	var skull := hinge(spec.neck,Basis(Vector3.UP,v(pose,"head_yaw"))*Basis(Vector3.RIGHT,v(pose,"head_pitch"))*Basis(Vector3.BACK,v(pose,"head_roll")))
	for name: String in spec.head_parts:
		set_part(name,skull)
	var lid := clampf(1.0 - v(pose,"blink"),0.1,1.0)
	var eyes: Vector3 = spec.eyes
	set_part("Ochi",skull*Transform3D(Basis.from_scale(Vector3(1,lid,1)),eyes - Basis.from_scale(Vector3(1,lid,1))*eyes))
	if character == "pongo":
		# The hammer is held in the right paw and swings about the grip.
		set_part("Ciocan",arms[1]*hinge(Vector3(0.42,0.3,0.06),Basis(Vector3.RIGHT,v(pose,"hammer"))))
	else:
		var flap := v(pose,"wings")
		set_part("AripaStanga",hinge(Vector3(-0.2,0.32,-0.1),Basis(Vector3.UP,-flap*0.9)*Basis(Vector3.BACK,-flap*0.4)))
		set_part("AripaDreapta",hinge(Vector3(0.2,0.32,-0.1),Basis(Vector3.UP,flap*0.9)*Basis(Vector3.BACK,flap*0.4)))
		set_part("Coada",hinge(Vector3(0,0.14,-0.24),Basis(Vector3.UP,v(pose,"tail_yaw"))*Basis(Vector3.RIGHT,v(pose,"tail_pitch"))))
