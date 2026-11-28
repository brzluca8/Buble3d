extends Node3D
## Environment Animation Controller. Small, specific signs of life, each tied to a real place in
## the existing models (coordinates come from tools/build_village.py). Presentation only.
##   foliage   breeze on tree canopies and grass (vertex shader, same matte look as before)
##   fountain  animated water surface: rings, caustics and sparkles
##   mine      the crystal lantern glows (level 3)        mill     flour puffs at the door
##   workshop  chimney smoke, sparks when the hammer hits  lab      bubbles from the cauldron
##   inn       chimney smoke and a flickering lantern       castle   birds circling the towers
## Everything follows the ambient switch and the quality tier; nothing is created per frame.
const Polish := preload("res://scripts/board/polish.gd")
const SMOKE := {2: Vector3(0.53,2.2,-0.38), 5: Vector3(0.42,2.26,-0.19)}
const SMOKE_LEVEL := {2: 1, 5: 3}
const BUBBLES := Vector3(-0.66,0.5,0.54)
const LANTERNS := {0: [Vector3(-0.38,0.82,0.58),Color(0.55,0.95,1.0)], 5: [Vector3(1.03,0.95,0.56),Color(1.0,0.78,0.4)]}
var village: Node
var ambient: Node
var castle: Node3D
var fountain: Node3D
var enabled := true
var tier := 1
var age := 0.0
var clock := 0.0
var wind := ShaderMaterial.new()
var foliage: Array[MeshInstance3D] = []
var water := MeshInstance3D.new()
var smoke := {}
var bubbles: CPUParticles3D
var lanterns := {}
var birds := MultiMeshInstance3D.new()
var last_strike := 0.0
var flour_timer := 3.0


func setup(sat: Node, ambience: Node, castle_node: Node3D, fountain_node: Node3D, plants: Array) -> void:
	village = sat
	ambient = ambience
	castle = castle_node
	fountain = fountain_node
	Polish.make_textures()
	wind.shader = preload("res://assets/fx/wind_foliage.gdshader")
	for branch: Node in plants:
		for mesh: MeshInstance3D in branch.find_children("*","MeshInstance3D",true,false):
			if mesh.is_visible_in_tree() and mesh.get_aabb().size.x < 40.0:
				foliage.append(mesh)
	_make_water()
	for slot: int in SMOKE:
		smoke[slot] = _smoke()
	bubbles = _bubbles()
	for slot: int in LANTERNS:
		lanterns[slot] = _glow(LANTERNS[slot][1])
	_make_birds()
	configure(tier,false)


func _soft(color: Color, size: float, add := true) -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(size,size)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if add else BaseMaterial3D.BLEND_MODE_MIX
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = Polish.soft_texture
	m.albedo_color = color
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.disable_receive_shadows = true
	quad.material = m
	return quad


func _make_water() -> void:
	var disc := QuadMesh.new()
	disc.size = Vector2(2.3,2.3)
	disc.orientation = PlaneMesh.FACE_Y
	var m := ShaderMaterial.new()
	m.shader = preload("res://assets/fx/fountain_water.gdshader")
	disc.material = m
	water.mesh = disc
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water.position = fountain.global_position + Vector3(0,0.633,0)
	add_child(water)


func _smoke() -> CPUParticles3D:
	var puff := CPUParticles3D.new()
	puff.mesh = _soft(Color(0.95,0.95,1.0,0.32),0.55,false)
	puff.amount = 7
	puff.lifetime = 3.2
	puff.preprocess = 3.0
	puff.direction = Vector3(0.25,1,0)
	puff.spread = 8.0
	puff.initial_velocity_min = 0.28
	puff.initial_velocity_max = 0.4
	puff.gravity = Vector3(0.06,0.02,0)
	puff.scale_amount_min = 0.5
	puff.scale_amount_max = 0.8
	var grow := Curve.new()
	grow.add_point(Vector2(0,0.4))
	grow.add_point(Vector2(1,1.6))
	puff.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.set_color(0,Color(1,1,1,0))
	fade.add_point(0.15,Color(1,1,1,0.7))
	fade.set_color(1,Color(1,1,1,0))
	puff.color_ramp = fade
	puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(puff)
	return puff


func _bubbles() -> CPUParticles3D:
	var pop := CPUParticles3D.new()
	pop.mesh = _soft(Color(1,1,1,0.9),0.16)
	pop.amount = 6
	pop.lifetime = 1.6
	pop.preprocess = 1.6
	pop.direction = Vector3.UP
	pop.spread = 15.0
	pop.initial_velocity_min = 0.3
	pop.initial_velocity_max = 0.5
	pop.gravity = Vector3.ZERO
	var colours := Gradient.new()
	colours.set_color(0,Color("#a6ffda"))
	colours.add_point(0.5,Color("#d59bff"))
	colours.set_color(1,Color(1,0.7,1,0))
	pop.color_ramp = colours
	pop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(pop)
	return pop


func _glow(color: Color) -> MeshInstance3D:
	var light := MeshInstance3D.new()
	light.mesh = _soft(color,1.1)
	light.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(light)
	return light


func _make_birds() -> void:
	# A tiny V of two flat wings; flapping is a vertical scale in the instance transform.
	var wing := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(0,0,0.06),Vector3(-0.32,0.1,-0.05),Vector3(0,0,-0.06),
		Vector3(0,0,0.06),Vector3(0,0,-0.06),Vector3(0.32,0.1,-0.05)])
	wing.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var ink := StandardMaterial3D.new()
	ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ink.albedo_color = Color("#3b4a6a")
	ink.cull_mode = BaseMaterial3D.CULL_DISABLED
	wing.surface_set_material(0,ink)
	birds.multimesh = MultiMesh.new()
	birds.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	birds.multimesh.mesh = wing
	birds.multimesh.instance_count = 3
	birds.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	birds.custom_aabb = AABB(Vector3(-12,0,-20),Vector3(24,16,24))
	add_child(birds)


func configure(quality: int, fewer: bool) -> void:
	tier = quality
	enabled = not fewer
	var on := enabled
	wind.set_shader_parameter("strength",1.0 if quality > 0 else 0.6)
	for mesh in foliage:
		mesh.material_override = wind if on and quality > 0 else null
	water.visible = on
	birds.visible = on and quality > 0
	bubbles.amount = 4 if quality == 0 else 6
	_refresh()
	set_process(on)


func set_enabled(on: bool) -> void:
	configure(tier,not on)


func _model(slot: int) -> Node3D:
	return village.models[slot] if village and slot < village.models.size() else null


func _level(slot: int) -> int:
	return int(village.levels[slot]) if village and slot < village.levels.size() else 0


## Places the effects of the buildings that exist at their current level.
func _refresh() -> void:
	for slot: int in smoke:
		var model := _model(slot)
		var show: bool = enabled and tier > 0 and model != null and model.visible and _level(slot) >= int(SMOKE_LEVEL[slot])
		smoke[slot].emitting = show
		smoke[slot].visible = show
		if model:
			smoke[slot].global_position = model.to_global(SMOKE[slot])
	var lab := _model(3)
	var cauldron: bool = enabled and lab != null and lab.visible and _level(3) >= 2
	bubbles.emitting = cauldron
	bubbles.visible = cauldron
	if lab:
		bubbles.global_position = lab.to_global(BUBBLES)
	for slot: int in lanterns:
		var model := _model(slot)
		lanterns[slot].visible = enabled and model != null and model.visible and _level(slot) >= 3
		if model:
			lanterns[slot].global_position = model.to_global(LANTERNS[slot][0])


func _process(delta: float) -> void:
	age += delta
	clock += delta
	if clock >= 0.25:
		clock = 0.0
		_refresh()
	for slot: int in lanterns:
		var light: MeshInstance3D = lanterns[slot]
		if light.visible:
			var flicker := 0.8 + 0.12*sin(age*9.0 + slot) + 0.08*sin(age*23.0 + slot*2.0)
			light.scale = Vector3.ONE*flicker
	if birds.visible:
		for i in range(3):
			var a := age*0.35 + i*0.9
			var center := castle.global_position + Vector3(0,9.0 + i*0.6,0.5)
			var p := center + Vector3(cos(a)*(4.5 + i),sin(a*2.0)*0.4,sin(a)*(2.5 + i*0.5))
			var heading := Vector3(-sin(a),0,cos(a))
			var flap := 0.4 + 0.6*absf(sin(age*7.0 + i*1.3))
			var basis := Basis.looking_at(heading,Vector3.UP).scaled(Vector3(1,flap,1))
			birds.multimesh.set_instance_transform(i,Transform3D(basis,p))
	_workshop_sparks()
	_mill_flour(delta)


func _workshop_sparks() -> void:
	var model := _model(2)
	if model == null or not model.visible or _level(2) < 3 or tier == 0:
		return
	# The accent hammer swings with sin(phase*3); a hit is the lowest point of the swing.
	var swing := sin(village.phase*3.0)
	if swing < -0.97 and age - last_strike > 0.6:
		last_strike = age
		_spark(model.to_global(Vector3(0.0,1.45,0.95)),Color("#ffb347"),5)


func _mill_flour(delta: float) -> void:
	var model := _model(1)
	if model == null or not model.visible or _level(1) < 1 or tier == 0:
		return
	flour_timer -= delta
	if flour_timer <= 0.0:
		flour_timer = 4.0 + fposmod(age*1.7,3.0)
		_spark(model.to_global(Vector3(0,0.35,0.78)),Color(1,1,0.95,0.7),6,false)


func _spark(at: Vector3, color: Color, count: int, star := true) -> void:
	var cloud := CPUParticles3D.new()
	cloud.mesh = _soft(Color.WHITE,0.16 if star else 0.35,star)
	if star:
		(cloud.mesh.material as StandardMaterial3D).albedo_texture = Polish.star_texture
	cloud.amount = count
	cloud.one_shot = true
	cloud.explosiveness = 0.9
	cloud.lifetime = 0.6 if star else 1.2
	cloud.spread = 70.0
	cloud.direction = Vector3(0,1,0.4)
	cloud.initial_velocity_min = 0.8 if star else 0.2
	cloud.initial_velocity_max = 1.8 if star else 0.5
	cloud.gravity = Vector3(0,-3.0 if star else 0.1,0)
	cloud.color = color
	cloud.scale_amount_curve = Polish._shrink_curve()
	cloud.position = at
	cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cloud)
	cloud.finished.connect(cloud.queue_free)
	cloud.emitting = true
