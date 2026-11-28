extends Node3D

const MODELS := [preload("res://assets/village/mine.glb"), preload("res://assets/village/mill.glb"),
	preload("res://assets/village/workshop.glb"), preload("res://assets/village/lab.glb"),
	preload("res://assets/village/market.glb"), preload("res://assets/village/inn.glb")]
const PIVOTS := [Vector3(-0.38,0.82,0.58), Vector3(0,1.48,0.65), Vector3(0,1.81,0.79),
	Vector3(-0.66,0.57,0.54), Vector3(0.72,1.64,-0.18), Vector3(1.03,1.13,0.56)]
var models: Array[Node3D] = []
var accents: Array[Node3D] = []
var levels: Array = []
@export_range(1,3) var mill_moves_from_level := 3
var phase := 0.0
var mill_angle := 0.0


func populate(plots: Node3D, saved: Array) -> void:
	for i in range(MODELS.size()):
		var model: Node3D = MODELS[i].instantiate()
		model.position = plots.get_child(i).position + Vector3.UP * 0.26
		model.rotation.y = 0.28 if i % 2 == 0 else -0.28
		add_child(model)
		models.append(model)
		var accent := model.find_child("Accent", true, false) as Node3D
		accents.append(accent)
		accent.position = PIVOTS[i]
		levels.append(-1)
		set_level(i, int(saved[i]))


func set_level(i: int, level: int) -> void:
	if level == levels[i]:
		return
	levels[i] = level
	models[i].visible = level > 0
	models[i].find_child("Upgrade2", true, false).visible = level >= 2
	models[i].find_child("Upgrade3", true, false).visible = level >= 3
	accents[i].visible = level >= 3 or i == 1
	set_process(levels.has(3) or (levels.size() > 1 and levels[1] >= mill_moves_from_level))


func _process(delta: float) -> void:
	phase = fmod(phase + delta, TAU * 20)
	for i in range(levels.size()):
		if levels[i] != 3 and (i != 1 or levels[i] < mill_moves_from_level):
			continue
		match i:
			0, 3: accents[i].position.y = PIVOTS[i].y + 0.08 * sin(phase * (2 + i))
			1:
				# Blades speed up and ease off with the breeze; the angle is accumulated so it never jumps.
				mill_angle = fmod(mill_angle + delta*(0.85 + 0.35*sin(phase*0.41) + 0.12*sin(phase*1.7)),TAU)
				accents[i].rotation.z = mill_angle
				accents[i].rotation.x = 0.025*sin(phase*0.9)
			2: accents[i].rotation.z = 0.32 * sin(phase * 3)
			4, 5: accents[i].rotation.z = 0.13 * sin(phase * 2 + i)


func pick(camera: Camera3D, screen: Vector2) -> int:
	var origin := camera.project_ray_origin(screen)
	var ray := camera.project_ray_normal(screen)
	var closest := INF
	var slot := -1
	for i in range(models.size()):
		if not models[i].visible:
			continue
		var model := models[i]
		var local_origin := model.to_local(origin)
		var local_ray := model.global_transform.basis.inverse() * ray
		for part: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			if not part.visible:
				continue
			var box: AABB = part.transform * part.get_aabb()
			var hit: Variant = box.intersects_ray(local_origin, local_ray)
			if hit is Vector3:
				var dist := local_origin.distance_squared_to(hit)
				if dist < closest:
					closest = dist
					slot = i
	return slot
