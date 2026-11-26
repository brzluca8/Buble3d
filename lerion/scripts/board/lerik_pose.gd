extends Node3D
## Pivot the existing painted parts about their shoulders, hips and neck.
@onready var head: Node3D = find_child("Cap",true,false)
@onready var arms := [find_child("BratStang",true,false),find_child("BratDrept",true,false)]
@onready var legs := [find_child("PiciorStang",true,false),find_child("PiciorDrept",true,false)]


func pose(stride: float, crouch: float, cheer: float, glance := 0.0) -> void:
	for i in range(2):
		var side := -1.0 if i == 0 else 1.0
		var shoulder := Vector3(side*0.32,0.66,0.025)
		var hip := Vector3(side*0.18,0.33,0)
		var lift := Basis(Vector3.BACK,side*(0.12+cheer*2.0))
		hinge(arms[i],shoulder,lift*Basis(Vector3.RIGHT,side*stride*0.93-0.24*crouch))
		hinge(legs[i],hip,Basis(Vector3.RIGHT,-side*stride*0.78+crouch*0.33))
	var nod := Basis(Vector3.RIGHT,crouch*0.20-cheer*0.19)
	hinge(head,Vector3(0,0.73,0),Basis(Vector3.UP,glance)*nod*Basis(Vector3.BACK,stride*0.07+cheer*0.09))


func hinge(part: Node3D, pivot: Vector3, turn: Basis) -> void:
	part.transform = Transform3D(turn,pivot-turn*pivot)

func idle(age: float) -> void:
	var breath := sin(age*2.35)
	var look := sin(age*0.83)*smoothstep(0.12,0.88,sin(age*0.49))
	position.y = 0.024 + 0.015*breath
	rotation = Vector3(0.012*breath,0.025*look,0)
	pose(0.045*breath,0.045*(breath+1.0),0.0,0.27*look)
