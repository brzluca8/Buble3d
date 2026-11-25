class_name BoardPath
extends Node3D
## Traseul închis al lui Lerik: Path3D „LoopPath” + drum vizual + 36 de căsuțe.
## Logica (poziții, zone, validare) este în funcții statice, testabile fără scenă.

const TILE_Y := 0.0
const SAMPLES_PER_SEGMENT := 16

var config: BoardConfig
var centerline := PackedVector2Array()
var tiles: Array[BoardTile] = []
var path_node: Path3D

var _index_labels: Array[Label3D] = []


# ---------------------------------------------------------------- logică pură

static func compute_centerline(cfg: BoardConfig) -> PackedVector2Array:
	return LoopGeometry.catmull_rom_closed(cfg.control_points, SAMPLES_PER_SEGMENT)


static func compute_tiles(cfg: BoardConfig, line: PackedVector2Array) -> Array[BoardTile]:
	var result: Array[BoardTile] = []
	var sample: Dictionary = LoopGeometry.sample_evenly(line, cfg.tile_count)
	var positions: PackedVector2Array = sample["positions"]
	var tangents: PackedVector2Array = sample["tangents"]
	for i in cfg.tile_count:
		var t := BoardTile.new()
		t.index = i
		t.position = Vector3(positions[i].x, TILE_Y, positions[i].y)
		t.forward = Vector3(tangents[i].x, 0.0, tangents[i].y).normalized()
		t.kind = BoardTile.KIND_START if i == cfg.start_index else BoardTile.KIND_NORMAL
		if t.kind == BoardTile.KIND_NORMAL:
			for b in cfg.building_ids.size():
				var d := positions[i].distance_to(cfg.building_positions[b])
				if d <= cfg.zone_max_distance and d < t.zone_distance:
					t.zone_distance = d
					t.zone_building_id = StringName(cfg.building_ids[b])
		result.append(t)
	return result


## Ordinea zonelor de-a lungul traseului (secvențe consecutive comprimate).
static func zone_sequence(tile_list: Array[BoardTile]) -> PackedStringArray:
	var seq := PackedStringArray()
	for t in tile_list:
		if t.zone_building_id == &"none":
			continue
		var id := String(t.zone_building_id)
		if seq.is_empty() or seq[seq.size() - 1] != id:
			seq.append(id)
	return seq


## Verifică toate condițiile obligatorii ale traseului. Listă goală = traseu valid.
static func validate_layout(cfg: BoardConfig, line: PackedVector2Array, tile_list: Array[BoardTile]) -> PackedStringArray:
	var errors := PackedStringArray()
	var n := tile_list.size()
	if n != cfg.tile_count or n < 30 or n > 36:
		errors.append("Număr de căsuțe invalid: %d" % n)
		return errors

	# 1. Buclă închisă cu pas uniform, inclusiv legătura ultima → prima.
	var mean := LoopGeometry.loop_length(line) / float(n)
	for i in n:
		var d := tile_list[i].position.distance_to(tile_list[(i + 1) % n].position)
		if absf(d - mean) > mean * 0.12:
			errors.append("Pas neuniform între căsuțele %d și %d: %.2f (medie %.2f)" % [i, (i + 1) % n, d, mean])
	# Căsuțele nu se suprapun (latura de-a lungul drumului ~1.36).
	if mean < 1.45:
		errors.append("Căsuțele sunt prea înghesuite (pas %.2f)" % mean)

	# 2. Fără auto-intersecții și fără porțiuni de drum care se ating vizual.
	var hits := LoopGeometry.count_self_intersections(line)
	if hits > 0:
		errors.append("Traseul se intersectează cu el însuși (%d)" % hits)
	var near := LoopGeometry.min_non_local_distance(line, 4.0 * mean)
	if near < cfg.road_half_width * 2.0 + 0.6:
		errors.append("Două porțiuni de drum sunt prea apropiate (%.2f) – intersecție ambiguă" % near)

	# 3. Drumul nu intră pe platformele clădirilor, în cristal sau în castel.
	for b in cfg.building_ids.size():
		var gap := LoopGeometry.distance_to_point(line, cfg.building_positions[b]) - cfg.building_radius - cfg.road_half_width
		if gap < cfg.min_clearance:
			errors.append("Drumul atinge platforma „%s” (spațiu %.2f)" % [cfg.building_ids[b], gap])
	var cgap := LoopGeometry.distance_to_point(line, cfg.crystal_position) - cfg.crystal_radius - cfg.road_half_width
	if cgap < cfg.min_clearance:
		errors.append("Drumul atinge cristalul central (spațiu %.2f)" % cgap)
	var kgap := LoopGeometry.distance_to_rect(line, cfg.castle_center, cfg.castle_half_extents) - cfg.road_half_width
	if kgap < cfg.min_clearance:
		errors.append("Drumul atinge castelul (spațiu %.2f)" % kgap)
	# Cristalul trebuie să fie ÎN INTERIORUL buclei.
	if not Geometry2D.is_point_in_polygon(cfg.crystal_position, line):
		errors.append("Cristalul nu este în interiorul buclei")
	for b in cfg.building_ids.size():
		if Geometry2D.is_point_in_polygon(cfg.building_positions[b], line):
			errors.append("Clădirea „%s” este în interiorul buclei" % cfg.building_ids[b])

	# 4. Traseul trece pe lângă toate cele 6 clădiri, în ordinea cerută.
	for id in cfg.building_ids:
		var c := 0
		for t in tile_list:
			if String(t.zone_building_id) == id:
				c += 1
		if c < 2:
			errors.append("Clădirea „%s” are doar %d căsuțe în apropiere (minim 2)" % [id, c])
	var seq := zone_sequence(tile_list)
	if seq != cfg.expected_zone_order:
		errors.append("Ordinea zonelor %s ≠ %s" % [str(seq), str(cfg.expected_zone_order)])
	if tile_list[cfg.start_index].kind != BoardTile.KIND_START:
		errors.append("Căsuța START lipsește")
	return errors


# ---------------------------------------------------------------- scenă

func build(cfg: BoardConfig) -> void:
	config = cfg
	centerline = compute_centerline(cfg)
	tiles = compute_tiles(cfg, centerline)
	_build_path3d()
	_build_road()
	_build_tiles()
	_build_start_sign()


func validate() -> PackedStringArray:
	return validate_layout(config, centerline, tiles)


func tile_count() -> int:
	return tiles.size()


func get_tile(i: int) -> BoardTile:
	return tiles[posmod(i, tiles.size())]


func set_debug_indices_visible(v: bool) -> void:
	for l in _index_labels:
		l.visible = v


func debug_indices_visible() -> bool:
	return not _index_labels.is_empty() and _index_labels[0].visible


func _build_path3d() -> void:
	path_node = Path3D.new()
	path_node.name = "LoopPath"
	var curve := Curve3D.new()
	for p in centerline:
		curve.add_point(Vector3(p.x, TILE_Y + 0.15, p.y))
	curve.add_point(Vector3(centerline[0].x, TILE_Y + 0.15, centerline[0].y))  # închiderea 35 → 0
	path_node.curve = curve
	add_child(path_node)


func _build_road() -> void:
	# Bordură închisă + suprafață deschisă: două fâșii netede de-a lungul liniei centrale.
	var mesh := ArrayMesh.new()
	_add_strip(mesh, config.road_half_width + 0.2, 0.02, Color("b98a4e"))
	_add_strip(mesh, config.road_half_width, 0.04, Color("f1d7a0"))
	var mi := MeshInstance3D.new()
	mi.name = "Road"
	mi.mesh = mesh
	var mat := MeshBuilder.vertex_color_material().duplicate() as StandardMaterial3D
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _add_strip(mesh: ArrayMesh, half: float, y: float, color: Color) -> void:
	var n := centerline.size()
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var left := PackedVector3Array()
	var right := PackedVector3Array()
	for i in n:
		var prev: Vector2 = centerline[(i - 1 + n) % n]
		var next: Vector2 = centerline[(i + 1) % n]
		var tan := (next - prev).normalized()
		var nrm := Vector2(-tan.y, tan.x)
		var p: Vector2 = centerline[i]
		left.append(Vector3(p.x + nrm.x * half, y, p.y + nrm.y * half))
		right.append(Vector3(p.x - nrm.x * half, y, p.y - nrm.y * half))
	for i in n:
		var j := (i + 1) % n
		for v in [left[i], right[i], left[j], left[j], right[i], right[j]]:
			verts.append(v)
			norms.append(Vector3.UP)
			cols.append(color.srgb_to_linear())
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


func _tile_mesh(top: Color, mark: Color) -> ArrayMesh:
	var mb := MeshBuilder.new()
	mb.box(Vector3(1.42, 0.14, 1.36), Vector3(0, 0.09, 0), Color("c99a5c"))
	mb.box(Vector3(1.26, 0.06, 1.2), Vector3(0, 0.18, 0), top)
	mb.box(Vector3(0.34, 0.03, 0.34), Vector3(0, 0.22, 0), mark, Vector3(0, 45, 0))
	return mb.commit()


func _build_tiles() -> void:
	var holder := Node3D.new()
	holder.name = "Tiles"
	add_child(holder)
	var mesh_a := _tile_mesh(Color("fff3d6"), Color("f0c987"))
	var mesh_b := _tile_mesh(Color("f8e0b0"), Color("e3b46e"))
	var mesh_start := _tile_mesh(Color("ffd35a"), Color("e08a1e"))
	for t in tiles:
		var mi := MeshInstance3D.new()
		mi.name = "Tile_%02d" % t.index
		if t.kind == BoardTile.KIND_START:
			mi.mesh = mesh_start
		else:
			mi.mesh = mesh_a if t.index % 2 == 0 else mesh_b
		mi.material_override = MeshBuilder.vertex_color_material()
		mi.position = t.position
		mi.rotation.y = t.yaw()
		holder.add_child(mi)

		var lbl := Label3D.new()
		lbl.name = "Index"
		lbl.text = str(t.index)
		lbl.font_size = 44
		lbl.outline_size = 12
		lbl.pixel_size = 0.012
		lbl.modulate = Color("3b2a16")
		lbl.outline_modulate = Color("fff3d6")
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.position = t.position + Vector3(0, 0.55, 0)
		holder.add_child(lbl)
		_index_labels.append(lbl)


func _build_start_sign() -> void:
	var t := tiles[config.start_index]
	var outward := Vector3(t.position.x, 0, t.position.z).normalized()
	var base := t.position + outward * (config.road_half_width + 0.9)
	var mb := MeshBuilder.new()
	mb.box(Vector3(0.14, 1.3, 0.14), Vector3(-0.75, 0.65, 0), Color("8b5a2b"))
	mb.box(Vector3(0.14, 1.3, 0.14), Vector3(0.75, 0.65, 0), Color("8b5a2b"))
	mb.box(Vector3(1.9, 0.55, 0.12), Vector3(0, 1.2, 0), Color("ffd35a"))
	mb.box(Vector3(2.0, 0.1, 0.16), Vector3(0, 1.5, 0), Color("e08a1e"))
	var sign := mb.make_instance("StartSign")
	sign.position = base
	add_child(sign)
	var lbl := Label3D.new()
	lbl.name = "StartLabel"
	lbl.text = "START"
	lbl.font_size = 64
	lbl.outline_size = 12
	lbl.pixel_size = 0.009
	lbl.modulate = Color("5a3410")
	lbl.outline_modulate = Color("fff3d6")
	lbl.position = base + Vector3(0, 1.2, 0.08)
	add_child(lbl)
