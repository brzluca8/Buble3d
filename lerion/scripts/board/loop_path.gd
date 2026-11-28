@tool
extends Path3D
## Travel, paving and the index overlay sample the same closed centreline.
const RULES := preload("res://assets/board/rules.tres")
const HALF_WIDTH := 0.70
const SURFACE_Y := 0.16
const ANCHORS := [Vector2(0,9.25), Vector2(1.78,8.90), Vector2(2.68,7.15),
	Vector2(3.00,5.63), Vector2(4.46,4.22), Vector2(4.80,3.25),
	Vector2(3.55,1.90), Vector2(2.95,0.20), Vector2(3.36,-1.48),
	Vector2(4.64,-2.82), Vector2(4.62,-3.80), Vector2(3.35,-4.96),
	Vector2(2.75,-6.03),Vector2(1.62,-6.24),Vector2(0,-6.21)]
const PALETTE := ["f3ca86","ffdda2","efbc7a"]
## Each category gets its own hue so a tile reads at a glance; the sandy palette still alternates underneath.
const CATEGORY_TINT := {"coin": "f9d47a", "crystal": "9fdcea", "construction": "f7b37c", "magic": "b3a0e6", "quest": "a6dc98"}
const ECONOMY := preload("res://assets/board/economy.tres")
const ICONS := {
	"coin":preload("res://assets/crystal/coin.svg"), "crystal":preload("res://assets/crystal/crystal.svg"),
	"construction":preload("res://assets/crystal/hammer.svg"), "energy":preload("res://assets/crystal/energy.svg"),
	"magic":preload("res://assets/crystal/chaos.svg"), "quest":preload("res://assets/crystal/challenge.svg")}
@onready var studs := MultiMeshInstance3D.new()
var markers: Array[MeshInstance3D] = []
var selected_tiles := PackedInt32Array()
var flashing := -1
var flash_tween: Tween
var lit_tiles := PackedInt32Array()
var pulse_material := ShaderMaterial.new()
var centers := PackedVector3Array()
var length_m := 0.0
var stride := 0.0
@onready var index_labels := Node3D.new()
var surface := SurfaceTool.new()


func _ready() -> void:
	pulse_material.shader = preload("res://assets/board/tile_pulse.gdshader")
	var knots: Array = ANCHORS.duplicate()
	for i in range(ANCHORS.size()-2,0,-1):
		knots.append(Vector2(-ANCHORS[i].x,ANCHORS[i].y))
	# The front half gets more room in portrait perspective.
	for i in range(knots.size()):
		if knots[i].y > 0.0:
			knots[i] = Vector2(knots[i].x,knots[i].y * 1.32)
	curve = Curve3D.new()
	curve.bake_interval = 0.035
	for k in range(knots.size()):
		var point: Vector2 = knots[k]
		var tangent: Vector2 = (knots[(k+1)%knots.size()] - knots[posmod(k-1,knots.size())]) / 6.0
		curve.add_point(Vector3(point.x,0,point.y),Vector3(-tangent.x,0,-tangent.y),Vector3(tangent.x,0,tangent.y))
	curve.closed = true
	length_m = curve.get_baked_length()
	stride = length_m / RULES.tile_count
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# A narrow worn verge eases the raised stone into the meadow in the same draw.
	_ribbon(-0.5,RULES.tile_count-0.5,RULES.tile_count*6,HALF_WIDTH+0.14,0.012,0.020,Color("#92af5b"),Color("#acaa68"))
	# The narrow mortar bed continues across all seams, including 35 to START.
	_ribbon(-0.5, RULES.tile_count - 0.5, RULES.tile_count * 6, HALF_WIDTH, 0.025, 0.076, Color("#ba8654"), Color("#dca871"))
	for i in range(RULES.tile_count):
		centers.append(at_step(i))
		var color := Color(PALETTE[i % 3])
		if i == 0:
			color = Color("#e99363")
		else:
			var tint: String = CATEGORY_TINT.get(ECONOMY.kind(i, RULES.tile_count), "")
			if not tint.is_empty():
				color = Color(tint).lerp(color,0.22)
		_ribbon(i-0.479,i+0.479,8,HALF_WIDTH-0.055,0.077,SURFACE_Y,color.darkened(0.3),color)
		if i == 0:
			_start_arrow()
	var paint := StandardMaterial3D.new()
	paint.vertex_color_use_as_albedo = true
	paint.vertex_color_is_srgb = false
	paint.roughness = 0.82
	paint.metallic_specular = 0.10
	surface.set_material(paint)
	var paving := MeshInstance3D.new()
	paving.name = "Pavaj"
	paving.mesh = surface.commit()
	paving.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(paving)
	_build_markers()
	surface.clear()
	_build_icons()
	add_child(studs)
	add_child(index_labels)
	index_labels.hide()


func at_step(step: float) -> Vector3:
	return curve.sample_baked(fposmod(step * stride,length_m)) + Vector3.UP * SURFACE_Y


func _point(step: float, across: float, height: float) -> Vector3:
	var center := at_step(step)
	var tangent := (at_step(step+0.012)-at_step(step-0.012)).normalized()
	return Vector3(center.x + tangent.z * across,height,center.z - tangent.x * across)


func _tri(a: Vector3,b: Vector3,c: Vector3,color: Color) -> void:
	var n := (c-a).cross(b-a).normalized()
	if n.y < 0:
		var temp := b
		b = c
		c = temp
		n = -n
	for p: Vector3 in [a,b,c]:
		surface.set_normal(n)
		surface.set_color(color.srgb_to_linear())
		surface.add_vertex(p)


func _ribbon(first: float,last: float,slices: int,width: float,low: float,high: float,side: Color,top: Color) -> void:
	var prev := PackedVector3Array()
	for j in range(slices+1):
		var t := float(j)/slices
		var step := lerpf(first,last,t)
		var cap := slices == 8 and (j == 0 or j == slices)
		var w := width - (0.065 if cap else 0.0)
		var h := high - (0.03 if cap else 0.0)
		var row := PackedVector3Array([_point(step,-w,low),_point(step,-w+0.045,h),_point(step,w-0.045,h),_point(step,w,low)])
		if j > 0:
			for lane in range(3):
				var col := top if lane == 1 else side
				_tri(prev[lane],row[lane],row[lane+1],col)
				_tri(prev[lane],row[lane+1],prev[lane+1],col)
		prev = row


func _start_arrow() -> void:
	var center := centers[0] + Vector3.UP * 0.007
	var a := (at_step(0.02) - at_step(-0.02)).normalized()
	var b := Vector3(a.z,0,-a.x)
	var shape := PackedVector2Array([Vector2(-0.38,-0.28),Vector2(0.42,0),Vector2(-0.38,0.28),Vector2(-0.15,0)])
	for j in range(shape.size()):
		var p := shape[j]
		var q := shape[(j+1)%shape.size()]
		_tri(center,center+a*p.x+b*p.y,center+a*q.x+b*q.y,Color("#fff1bb"))


func _build_icons() -> void:
	# One instanced draw per symbol, with a transparent cutout on top of the road.
	for type: String in ICONS:
		var positions := PackedVector3Array()
		for i in range(1, centers.size()):
			if ECONOMY.kind(i, centers.size()) == type:
				positions.append(centers[i] + Vector3.UP * 0.026)
		# A dark offset copy under each icon works as a cartoon outline and lifts contrast.
		var outline := StandardMaterial3D.new()
		outline.albedo_texture = ICONS[type]
		outline.albedo_color = Color(0.1,0.14,0.28)
		outline.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		outline.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		outline.alpha_scissor_threshold = 0.4
		var halo := PlaneMesh.new()
		halo.size = Vector2(1.04,1.04)
		halo.material = outline
		var shade_batch := MultiMesh.new()
		shade_batch.transform_format = MultiMesh.TRANSFORM_3D
		shade_batch.mesh = halo
		shade_batch.instance_count = positions.size()
		for j in range(positions.size()):
			shade_batch.set_instance_transform(j, Transform3D(Basis.IDENTITY, positions[j] + Vector3(0.022,-0.0015,0.03)))
		var shade_node := MultiMeshInstance3D.new()
		shade_node.multimesh = shade_batch
		shade_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(shade_node)
		var ink := StandardMaterial3D.new()
		ink.albedo_texture = ICONS[type]
		ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ink.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		ink.alpha_scissor_threshold = 0.4
		var stamp := PlaneMesh.new()
		stamp.size = Vector2(0.94,0.94)
		stamp.material = ink
		var batch := MultiMesh.new()
		batch.transform_format = MultiMesh.TRANSFORM_3D
		batch.mesh = stamp
		batch.instance_count = positions.size()
		for j in range(positions.size()):
			batch.set_instance_transform(j, Transform3D(Basis.IDENTITY, positions[j]))
		var node := MultiMeshInstance3D.new()
		node.multimesh = batch
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)


func _build_markers() -> void:
	var enamel := StandardMaterial3D.new()
	enamel.vertex_color_use_as_albedo = true
	enamel.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in range(centers.size()):
		surface = SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		_ribbon(i-0.465,i+0.465,8,0.63,0.163,0.175,Color("#325064"),Color("#325064"))
		_ribbon(i-0.415,i+0.415,8,0.55,0.176,0.182,Color("#fff3a1"),Color("#ffda54"))
		surface.set_material(enamel)
		var marker := MeshInstance3D.new()
		marker.mesh = surface.commit()
		marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(marker)
		marker.hide()
		markers.append(marker)


func mark_levels(levels: Array, buildings: Array) -> void:
	var stamps := PackedVector3Array()
	for slot in range(buildings.size()):
		for i in ECONOMY.tiles_for(buildings[slot].id, centers.size()):
			for rank in range(int(levels[slot])):
				stamps.append(_point(i + (rank - 1) * 0.115, 0.49, 0.197))
	if studs.multimesh == null:
		var ink := StandardMaterial3D.new()
		ink.albedo_color = Color("#254867")
		ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var pip := CylinderMesh.new()
		pip.radial_segments = 6
		pip.rings = 0
		pip.top_radius = 0.055
		pip.bottom_radius = 0.065
		pip.height = 0.026
		pip.material = ink
		studs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		studs.multimesh = MultiMesh.new()
		studs.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		studs.multimesh.mesh = pip
	studs.multimesh.instance_count = stamps.size()
	for i in range(stamps.size()):
		studs.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY,stamps[i]))


func show_zone(tiles: PackedInt32Array) -> void:
	selected_tiles = tiles
	for i in range(markers.size()):
		markers[i].visible = i in selected_tiles or i == flashing


func clear_flash() -> void:
	if flash_tween:
		flash_tween.kill()
	_end_pulse()


func _end_pulse() -> void:
	for tile in lit_tiles:
		markers[tile].material_override = null
	lit_tiles.clear()
	flashing = -1
	show_zone(selected_tiles)


func flash(index: int, tint := Color("#fff0a4")) -> void:
	clear_flash()
	flashing = index
	show_zone(selected_tiles)
	_pulse(PackedInt32Array([index]),tint)


func pulse_zone() -> void:
	clear_flash()
	_pulse(selected_tiles)


func _pulse(tiles: PackedInt32Array, tint := Color("#fff0a4")) -> void:
	pulse_material.set_shader_parameter("enamel",tint)
	lit_tiles = tiles.duplicate()
	for tile in lit_tiles:
		markers[tile].material_override = pulse_material
	flash_tween = create_tween()
	flash_tween.tween_method(func(t: float) -> void:
		pulse_material.set_shader_parameter("gleam", pow(sin(PI*t),2) * (0.7+0.3*cos(TAU*t*2))),0.0,1.0,0.62)
	flash_tween.tween_callback(_end_pulse)


func toggle_indices() -> void:
	if not OS.is_debug_build():
		return
	if index_labels.get_child_count() == 0:
		for i in range(centers.size()):
			var label := Label3D.new()
			label.text = str(i)
			label.position = centers[i] + Vector3.UP * 0.30
			label.pixel_size = 0.009
			label.font_size = 39
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.no_depth_test = true
			index_labels.add_child(label)
	index_labels.visible = not index_labels.visible
