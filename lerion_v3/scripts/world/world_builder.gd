class_name WorldBuilder
extends Node3D
## Lumea continentală: teren verde, coline și păduri la orizont, castelul albastru în spate,
## fântâna cu cristal în centru și cele 6 clădiri pe platformele lor.
## Totul procedural, cu puține draw call-uri (MultiMesh pentru copaci).

const GRASS := Color("74c257")
const PINE := Color("2f8a4e")
const PINE_DARK := Color("22704a")
const TRUNK := Color("7a4a26")

var config: BoardConfig
var buildings: Dictionary = {}  # id → BuildingVisual
var crystal: Node3D

var _centerline := PackedVector2Array()
var _rng := RandomNumberGenerator.new()


func build(cfg: BoardConfig, levels: Dictionary) -> void:
	config = cfg
	_centerline = BoardPath.compute_centerline(cfg)
	_rng.seed = 7341
	_build_environment()
	_build_ground()
	_build_castle()
	_build_fountain()
	for i in cfg.building_ids.size():
		var id: String = cfg.building_ids[i]
		var b := BuildingVisual.new()
		add_child(b)
		b.setup(id, cfg.building_names[i], int(levels.get(id, 0)), cfg.building_radius)
		var p: Vector2 = cfg.building_positions[i]
		b.position = Vector3(p.x, 0, p.y)
		# Fața clădirii spre cameră și ușor spre centru.
		b.rotation.y = deg_to_rad(28.0 if p.x < 0.0 else -28.0)
		buildings[id] = b
	_build_trees()
	_build_decor()


func set_building_level(id: String, lvl: int) -> void:
	if buildings.has(id):
		(buildings[id] as BuildingVisual).set_level(lvl)


# ---------------------------------------------------------------- mediu

func _build_environment() -> void:
	# Randerul Compatibility (folosit automat pe telefoanele fără Vulkan) iese mai întunecat
	# decât Mobile la aceleași valori; compensăm ca scena să arate la fel în ambele.
	var compat := RenderingServer.get_current_rendering_method() == "gl_compatibility"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("5aa8e8")
	sky_mat.sky_horizon_color = Color("bfe6f5")
	sky_mat.ground_horizon_color = Color("bfe6f5")
	sky_mat.ground_bottom_color = Color("4f8f3e")
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d8ecff")
	env.ambient_light_energy = 0.9 if compat else 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = false
	env.fog_light_color = Color("cfeaf2")
	env.fog_density = 0.0012
	env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color("fff1d6")
	sun.light_energy = 2.0 if compat else 1.15
	sun.rotation_degrees = Vector3(-55, -35, 0)
	# Fără umbre în timp real: mai ieftin pe telefoane și același aspect în randerele
	# Mobile și Compatibility. Fețele plate low-poly dau suficient volum; Lerik are umbră proprie.
	sun.shadow_enabled = false
	add_child(sun)


func _build_ground() -> void:
	var mb := MeshBuilder.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(420, 420)
	mb.add(plane, MeshBuilder.xf(Vector3(0, -0.01, -60)), GRASS)
	# Pajiște ușor mai deschisă sub zona de joc.
	mb.cyl(17.0, 17.0, 0.02, Vector3(0, 0.0, -2.0), Color("80cc60"), 28, Vector3.ZERO)
	# Coline la orizont și pe laterale (terenul continuă, nu e insulă).
	var hill_colors := [Color("5fae4a"), Color("6dbb52"), Color("57a347"), Color("4c9a44")]
	for i in 34:
		var ang := _rng.randf_range(-PI, PI)
		var dist := _rng.randf_range(34.0, 80.0)
		var pos := Vector3(sin(ang) * dist * 1.1, 0, -10.0 - cos(ang) * dist)
		if pos.z > 20.0:
			continue
		var r := _rng.randf_range(9.0, 18.0)
		mb.sphere(r, pos, hill_colors[i % hill_colors.size()], Vector3(1.0, _rng.randf_range(0.25, 0.45), 1.0), 12, 6)
	var mi := mb.make_instance("Ground")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


# ---------------------------------------------------------------- castel și cristal

func _build_castle() -> void:
	var beige := Color("f0cf94")
	var beige_dark := Color("d9b277")
	var mb := MeshBuilder.new()
	mb.box(Vector3(11.0, 0.8, 6.4), Vector3(0, 0.4, 0), Color("b7b0a2"))
	mb.box(Vector3(5.4, 3.6, 3.2), Vector3(0, 2.6, 0), beige)
	for i in 6:
		mb.box(Vector3(0.5, 0.45, 0.5), Vector3(-2.3 + i * 0.92, 4.62, 1.35), beige_dark)
	# Turnul central.
	mb.cyl(1.35, 1.4, 6.4, Vector3(0, 4.0, -0.4), beige, 12)
	mb.cyl(1.5, 1.5, 0.3, Vector3(0, 7.2, -0.4), GOLD_C, 12)
	mb.cone(1.85, 2.9, Vector3(0, 8.65, -0.4), Color("2f5fd0"), 12)
	mb.cyl(0.04, 0.04, 1.3, Vector3(0, 10.6, -0.4), Color("8a8a8a"), 6)
	mb.box(Vector3(0.7, 0.4, 0.04), Vector3(0.36, 11.05, -0.4), Color("e0443a"))
	mb.box(Vector3(0.32, 0.6, 0.1), Vector3(0, 5.6, 0.92), Color("2b3a66"))
	# Turnurile laterale.
	for sx in [-3.3, 3.3]:
		mb.cyl(1.05, 1.1, 4.8, Vector3(sx, 3.2, 0.3), beige, 12)
		mb.cyl(1.2, 1.2, 0.25, Vector3(sx, 5.65, 0.3), GOLD_C, 12)
		mb.cone(1.45, 2.3, Vector3(sx, 6.9, 0.3), Color("2f5fd0"), 12)
		mb.cyl(0.035, 0.035, 1.0, Vector3(sx, 8.5, 0.3), Color("8a8a8a"), 6)
		mb.box(Vector3(0.55, 0.32, 0.04), Vector3(sx + 0.29, 8.85, 0.3), Color("e0443a"))
		mb.box(Vector3(0.3, 0.55, 0.1), Vector3(sx, 3.8, 1.36), Color("2b3a66"))
	# Ușa, scutul, bannerele, scările roșii.
	mb.box(Vector3(1.6, 2.1, 0.14), Vector3(0, 1.85, 1.62), beige_dark)
	mb.box(Vector3(1.25, 1.8, 0.14), Vector3(0, 1.7, 1.66), Color("6b3b22"))
	mb.box(Vector3(0.75, 0.75, 0.1), Vector3(0, 3.45, 1.64), Color("8e2b3a"), Vector3(0, 0, 45))
	mb.box(Vector3(0.45, 0.45, 0.1), Vector3(0, 3.45, 1.7), GOLD_C, Vector3(0, 0, 45))
	for sx in [-1.75, 1.75]:
		mb.box(Vector3(0.5, 1.2, 0.06), Vector3(sx, 2.7, 1.63), Color("4b3a8c"))
		mb.box(Vector3(0.22, 0.22, 0.04), Vector3(sx, 2.75, 1.67), GOLD_C, Vector3(0, 0, 45))
	for i in 4:
		mb.box(Vector3(2.0, 0.2, 0.45), Vector3(0, 0.7 - i * 0.18, 1.95 + i * 0.4), Color("c8413a"))
	var castle := mb.make_instance("Castle")
	castle.position = Vector3(config.castle_center.x, 0, config.castle_center.y)
	add_child(castle)


const GOLD_C := Color("f4c542")


func _build_fountain() -> void:
	var c := config.crystal_position
	var mb := MeshBuilder.new()
	mb.cyl(2.15, 2.2, 0.26, Vector3(0, 0.13, 0), Color("4b3a78"), 18)
	mb.cyl(1.95, 1.98, 0.56, Vector3(0, 0.28, 0), Color("f4d27a"), 18)
	mb.cyl(1.65, 1.65, 0.58, Vector3(0, 0.3, 0), Color("4fc3ec"), 18)
	mb.cyl(0.42, 0.55, 0.9, Vector3(0, 0.95, 0), GOLD_C, 10)
	mb.cyl(0.85, 0.7, 0.22, Vector3(0, 1.45, 0), GOLD_C, 12)
	mb.cyl(0.7, 0.7, 0.24, Vector3(0, 1.48, 0), Color("6fd6f5"), 12)
	var fountain := mb.make_instance("Fountain")
	fountain.position = Vector3(c.x, 0, c.y)
	add_child(fountain)

	var spin := Spinner.new()
	spin.name = "Crystal"
	spin.degrees_per_second = 25.0
	spin.bob_height = 0.12
	spin.bob_speed = 1.4
	spin.position = Vector3(c.x, 2.55, c.y)
	var g := MeshBuilder.new()
	g.cone(0.66, 1.2, Vector3(0, 0.6, 0), Color("4fd8ff"), 6)
	g.cone(0.66, 0.85, Vector3(0, -0.42, 0), Color("2bb0ea"), 6, Vector3(180, 0, 0))
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = false
	mat.roughness = 0.25
	mat.emission_enabled = true
	mat.emission = Color("1f9fe0")
	mat.emission_energy_multiplier = 0.55
	spin.add_child(g.make_instance("CrystalMesh", mat))
	add_child(spin)
	crystal = spin


# ---------------------------------------------------------------- vegetație

func _is_free(p: Vector2, margin: float) -> bool:
	if LoopGeometry.distance_to_point(_centerline, p) < config.road_half_width + 0.25 + margin:
		return false
	for bp in config.building_positions:
		if p.distance_to(bp) < config.building_radius + margin:
			return false
	if p.distance_to(config.crystal_position) < config.crystal_radius + margin:
		return false
	var d := ((p - config.castle_center).abs() - config.castle_half_extents).max(Vector2.ZERO)
	if d.length() < margin:
		return false
	return true


func _pine_mesh() -> ArrayMesh:
	var mb := MeshBuilder.new()
	mb.cyl(0.18, 0.22, 0.7, Vector3(0, 0.35, 0), TRUNK, 6)
	mb.cone(1.15, 1.5, Vector3(0, 1.3, 0), PINE_DARK, 7)
	mb.cone(0.95, 1.3, Vector3(0, 2.0, 0), PINE, 7)
	mb.cone(0.7, 1.1, Vector3(0, 2.65, 0), Color("3a9a58"), 7)
	return mb.commit()


func _round_tree_mesh() -> ArrayMesh:
	var mb := MeshBuilder.new()
	mb.cyl(0.2, 0.28, 1.4, Vector3(0, 0.7, 0), TRUNK, 6)
	mb.sphere(1.0, Vector3(0, 1.9, 0), Color("57b046"), Vector3(1, 0.85, 1), 8, 5)
	mb.sphere(0.75, Vector3(0.65, 1.6, 0.2), Color("68c04e"), Vector3.ONE, 8, 5)
	mb.sphere(0.7, Vector3(-0.6, 1.65, -0.1), Color("4ea33f"), Vector3.ONE, 8, 5)
	return mb.commit()


func _multimesh(node_name: String, mesh: Mesh, xforms: Array[Transform3D]) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	mmi.material_override = MeshBuilder.vertex_color_material()
	add_child(mmi)


func _build_trees() -> void:
	var pines: Array[Transform3D] = []
	var rounds: Array[Transform3D] = []
	var attempts := 0
	while pines.size() < 230 and attempts < 4000:
		attempts += 1
		var p := Vector2(_rng.randf_range(-40, 40), _rng.randf_range(-60, 26))
		# În afara zonei de joc: pe laterale, în spatele castelului și în față.
		var inside := absf(p.x) < 11.6 and p.y > -21.0 and p.y < 14.2
		if inside or not _is_free(p, 1.0):
			continue
		var s := _rng.randf_range(0.85, 1.5) * (1.0 + maxf(0.0, -p.y - 20.0) * 0.012)
		var t := Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(p.x, 0, p.y))
		if _rng.randf() < 0.16:
			rounds.append(t)
		else:
			pines.append(t)
	# Câțiva copaci în spațiile libere din interior (nu pe drum / platforme).
	for p in [Vector2(-2.6, 7.6), Vector2(2.7, 6.2), Vector2(-10.8, -11.5), Vector2(10.9, -11.2), Vector2(-2.3, -6.2), Vector2(2.4, -5.0)]:
		if _is_free(p, 0.9):
			pines.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * 0.75), Vector3(p.x, 0, p.y)))
	_multimesh("Pines", _pine_mesh(), pines)
	_multimesh("RoundTrees", _round_tree_mesh(), rounds)


func _build_decor() -> void:
	var mb := MeshBuilder.new()
	var flower_cols := [Color("ffffff"), Color("f59ad0"), Color("b48cff"), Color("ffe066")]
	var placed := 0
	var attempts := 0
	while placed < 60 and attempts < 3000:
		attempts += 1
		var p := Vector2(_rng.randf_range(-11.5, 11.5), _rng.randf_range(-13.0, 14.0))
		if not _is_free(p, 0.35):
			continue
		placed += 1
		if placed % 5 == 0:
			mb.sphere(_rng.randf_range(0.35, 0.55), Vector3(p.x, 0.2, p.y), Color("4fa845"), Vector3(1, 0.75, 1), 7, 4)
			continue
		var col: Color = flower_cols[placed % flower_cols.size()]
		for k in 3:
			var o := Vector3(_rng.randf_range(-0.25, 0.25), 0, _rng.randf_range(-0.25, 0.25))
			mb.cyl(0.02, 0.02, 0.18, Vector3(p.x, 0.09, p.y) + o, Color("3f8f3a"), 4)
			mb.sphere(0.09, Vector3(p.x, 0.2, p.y) + o, col, Vector3(1, 0.6, 1), 6, 3)
	# Pietre.
	for p in [Vector2(-10.5, 3.6), Vector2(10.6, -3.8), Vector2(-3.0, 13.6), Vector2(9.8, 12.4), Vector2(-10.2, -4.0)]:
		if _is_free(p, 0.6):
			mb.sphere(0.6, Vector3(p.x, 0.25, p.y), Color("9aa0aa"), Vector3(1.3, 0.8, 1.0), 7, 4)
			mb.sphere(0.35, Vector3(p.x + 0.6, 0.15, p.y + 0.2), Color("858b96"), Vector3.ONE, 6, 3)
	# Garduri mici de lemn.
	for f in [[Vector2(-10.6, 10.5), 20.0], [Vector2(10.6, 10.8), -25.0], [Vector2(6.5, 13.3), 0.0]]:
		var fp: Vector2 = f[0]
		var rot: float = f[1]
		var basis := Basis(Vector3.UP, deg_to_rad(rot))
		for i in 4:
			var off := basis * Vector3(-0.9 + i * 0.6, 0, 0)
			mb.box(Vector3(0.12, 0.6, 0.12), Vector3(fp.x, 0.3, fp.y) + off, Color("a0622f"))
		mb.box(Vector3(1.9, 0.1, 0.08), Vector3(fp.x, 0.45, fp.y), Color("b8743a"), Vector3(0, rot, 0))
		mb.box(Vector3(1.9, 0.1, 0.08), Vector3(fp.x, 0.25, fp.y), Color("b8743a"), Vector3(0, rot, 0))
	var mi := mb.make_instance("Decor")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
