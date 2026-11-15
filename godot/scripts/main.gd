extends Node3D
## Scena principală 2.5D: modele 3D reale (insulă, piață, clădiri, mascotă) văzute printr-o
## cameră cinematografică; fundal atmosferic din elemente 2D/prerandate (cer, nori, insule
## îndepărtate) și efecte (cascade, fântână, scântei, lumini).

const WATERFALLS := [Vector2(-4.66, 5.55), Vector2(4.66, 5.55)]     # pe marginea insulei, de o parte și de alta a scărilor
const FOUNTAIN := Vector3(0, 2.35, 0.3)                              # vârful fântânii (cristalul)
const FAR := [Vector3(-26, 9, -46), Vector3(27, 12, -52), Vector3(-38, 2, -70)]
const CLOUD_TEX := ["res://art3d/cloud_0.png", "res://art3d/cloud_1.png", "res://art3d/cloud_2.png"]

var env: Environment
var sun: DirectionalLight3D
var island: Node3D
var cam: CameraRig
var gem: Node3D
var ring: MeshInstance3D
var sel_light: OmniLight3D
var sparks: CPUParticles3D
var clouds: Array[Node3D] = []
var far_islands: Array[Node3D] = []
var t := 0.0


func _ready() -> void:
	_build_environment()
	_build_island()
	_build_sky()
	cam = CameraRig.new()
	add_child(cam)
	cam.buildings = island.get_node("Buildings").get_children()
	add_child(preload("res://scripts/ui/hud.gd").new())
	Game.selected.connect(_on_selected)
	Game.upgraded.connect(_on_upgraded)
	Game.quality_changed.connect(func(_q): _apply_quality())
	_apply_quality()


# ---------------- mediu și lumini ----------------
func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("3d72cf")
	sky_mat.sky_horizon_color = Color("a9cdf3")
	sky_mat.ground_horizon_color = Color("bcd6f5")
	sky_mat.ground_bottom_color = Color("8fb4e8")
	sky_mat.sky_curve = 0.18
	sky_mat.ground_curve = 0.1
	sky_mat.sun_angle_max = 0.0
	var sky := Sky.new()
	sky.sky_material = sky_mat

	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	# lumină ambientală: un amestec de cer (albastru) și o culoare caldă – umbre colorate, nu cenușii
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.5
	env.ambient_light_sky_contribution = 0.45
	env.ambient_light_color = Color("c9a98a")
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.95
	env.tonemap_white = 6.0
	# strălucire: doar emisivele (ferestre, felinare, cristale) trec de prag
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_strength = 1.0
	env.glow_bloom = 0.02
	env.glow_hdr_threshold = 1.05
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_intensity = 0.45
	# profunzime atmosferică: ceață albăstruie care crește cu distanța
	env.fog_enabled = true
	env.fog_light_color = Color("b9d3f3")
	env.fog_density = 0.0016
	env.fog_aerial_perspective = 0.15
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.18
	env.adjustment_contrast = 1.1
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	# soare cald din stânga-sus, ușor din față (ca în randare)
	sun = DirectionalLight3D.new()
	sun.light_color = Color("ffe4b8")
	sun.light_energy = 2.4
	sun.shadow_enabled = true
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.shadow_blur = 2.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 45.0
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(sun)
	sun.look_at_from_position(Vector3(-11, 15, 7), Vector3.ZERO)

	# lumină de umplere rece din dreapta (umbrele nu devin negre)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color("a9c4ff")
	fill.light_energy = 0.45
	fill.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(fill)
	fill.look_at_from_position(Vector3(10, 6, 9), Vector3.ZERO)


func _apply_quality() -> void:
	var high := Game.quality == "inalta"
	env.glow_enabled = high
	sun.shadow_blur = 2.0 if high else 1.0
	RenderingServer.directional_shadow_atlas_set_size(2048 if high else 1024, true)
	get_viewport().msaa_3d = Viewport.MSAA_2X if high else Viewport.MSAA_DISABLED
	get_viewport().scaling_3d_scale = 1.0 if high else 0.8
	for i in clouds.size():
		clouds[i].visible = high or i % 3 != 0
	# calitate scăzută: decorurile mici (piața, vegetația) nu mai aruncă umbre
	var plaza := island.get_node_or_null("Piata")
	if plaza:
		for n in plaza.find_children("*", "GeometryInstance3D", true, false):
			(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if high else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

# ---------------- insula ----------------
func _build_island() -> void:
	island = Node3D.new()
	island.name = "Island"
	add_child(island)

	var terrain := Models.instance("insula")
	island.add_child(terrain if terrain else Proc.terrain())
	var plaza := Models.instance("plaza")
	if plaza:
		plaza.name = "Piata"
		island.add_child(plaza)
		gem = Proc.add(island, Proc.sph(0.22, 6, 3), Proc.M("gem"), FOUNTAIN)
	else:
		var p := Proc.plaza()
		island.add_child(p)
		gem = p.get_node("Gem")

	var bs := Node3D.new()
	bs.name = "Buildings"
	island.add_child(bs)
	for info in Game.BUILDINGS:
		var b := Building.new()
		bs.add_child(b)
		b.setup(info)

	island.add_child(Mascot.new())

	ring = Proc.add(island, Proc.htor(1.0, 0.035, 64, 8), Proc.mat(Color("ffd86b"), {"emit": Color("ffc040"), "energy": 3.0}))
	ring.visible = false
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sel_light = OmniLight3D.new()
	sel_light.light_color = Color("ffd38a")
	sel_light.omni_range = 7.0
	sel_light.light_energy = 0.0
	island.add_child(sel_light)

	_build_water()
	_build_sparks()

	var o1 := OmniLight3D.new()
	o1.light_color = Color("ffb060")
	o1.light_energy = 1.6
	o1.omni_range = 9.0
	o1.position = Vector3(0, 1.8, -1.6)
	island.add_child(o1)
	var o2 := OmniLight3D.new()
	o2.light_color = Color("7fe8ff")
	o2.light_energy = 1.0
	o2.omni_range = 5.0
	o2.position = FOUNTAIN + Vector3(0, 0.3, 0)
	island.add_child(o2)


func _drop_mesh(size: float) -> Mesh:
	var m := SphereMesh.new()
	m.radius = size
	m.height = size * 2
	m.radial_segments = 6
	m.rings = 3
	m.material = Proc.mat(Color(1, 1, 1, 0.9), {"unshaded": true, "alpha": 0.8})
	return m


func _build_water() -> void:
	# jetul fântânii
	var f := CPUParticles3D.new()
	f.amount = 56
	f.lifetime = 1.0
	f.mesh = _drop_mesh(0.045)
	f.position = FOUNTAIN + Vector3(0, -0.1, 0)
	f.direction = Vector3.UP
	f.spread = 35.0
	f.initial_velocity_min = 1.6
	f.initial_velocity_max = 2.2
	f.gravity = Vector3(0, -6.0, 0)
	f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	island.add_child(f)

	# cascade: trei straturi de apă + spumă sus + ceață jos + stropi
	var shader: Shader = preload("res://shaders/waterfall.gdshader")
	var layers := [
		{"w": 2.2, "h": 7.6, "speed": 0.32, "a": 0.55, "off": -0.08, "c": Color("6fc8f5")},
		{"w": 1.6, "h": 7.2, "speed": 0.55, "a": 0.9, "off": 0.0, "c": Color("bdeeff")},
		{"w": 0.9, "h": 6.8, "speed": 0.9, "a": 0.75, "off": 0.08, "c": Color("ffffff")},
	]
	for w in WATERFALLS:
		var out := Vector3(w.x, 0, w.y).normalized()
		var g := Node3D.new()
		g.position = Vector3(w.x, 0, w.y) + out * 0.25 + Vector3(0, -0.35, 0)
		g.rotation.y = atan2(w.x, w.y)
		island.add_child(g)
		for L in layers:
			var q := QuadMesh.new()
			q.size = Vector2(L.w, L.h)
			var sm := ShaderMaterial.new()
			sm.shader = shader
			var c: Color = L.c
			c.a = L.a
			sm.set_shader_parameter("tint", c)
			sm.set_shader_parameter("speed", L.speed)
			var mi := MeshInstance3D.new()
			mi.mesh = q
			mi.material_override = sm
			mi.position = Vector3(0, -L.h / 2.0, L.off)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			g.add_child(mi)
		var foam := _soft_quad(Vector2(2.4, 0.8), Color(1, 1, 1, 0.75))
		foam.position = Vector3(0, -0.05, 0.12)
		g.add_child(foam)
		var mist := _soft_quad(Vector2(5.0, 2.6), Color(1, 1, 1, 0.75))
		mist.position = Vector3(0, -7.0, 0.3)
		mist.name = "Mist"
		g.add_child(mist)
		var d := CPUParticles3D.new()
		d.amount = 26
		d.lifetime = 1.6
		d.mesh = _drop_mesh(0.06)
		d.position = Vector3(0, -6.6, 0.2)
		d.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		d.emission_box_extents = Vector3(0.9, 0.1, 0.2)
		d.direction = Vector3(0, 1, 0.4)
		d.spread = 40.0
		d.initial_velocity_min = 0.8
		d.initial_velocity_max = 1.8
		d.gravity = Vector3(0, -1.5, 0)
		d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.add_child(d)


func _soft_quad(size: Vector2, col: Color) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = size
	var m := StandardMaterial3D.new()
	m.albedo_texture = Proc.tex("soft")
	m.albedo_color = col
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _build_sparks() -> void:
	sparks = CPUParticles3D.new()
	sparks.emitting = false
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.amount = 36
	sparks.lifetime = 1.0
	var m := SphereMesh.new()
	m.radius = 0.09
	m.height = 0.18
	m.radial_segments = 6
	m.rings = 3
	m.material = Proc.mat(Color("ffd86b"), {"emit": Color("ffc040"), "energy": 3.0})
	sparks.mesh = m
	sparks.direction = Vector3.UP
	sparks.spread = 60.0
	sparks.initial_velocity_min = 3.0
	sparks.initial_velocity_max = 6.5
	sparks.gravity = Vector3(0, -9.0, 0)
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	sparks.scale_amount_curve = curve
	sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	island.add_child(sparks)


# ---------------- cer: nori 2D pe straturi + insule prerandate ----------------
func _cloud(pos: Vector3, width: float, alpha: float, tex_i: int, flip: bool) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = load(CLOUD_TEX[tex_i % CLOUD_TEX.size()])
	s.pixel_size = width / 512.0
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.shaded = false
	s.double_sided = true
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	s.modulate = Color(1, 1, 1, alpha)
	s.flip_h = flip
	s.position = pos
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(s)
	clouds.append(s)
	return s


func _build_sky() -> void:
	Proc.reseed(23)
	# 1) marea de nori de sub insulă (mai jos decât stânca, ca insula să pară suspendată)
	for i in 14:
		var a := Proc.rnd() * TAU
		var r := 12.0 + Proc.rnd() * 24.0
		var p := Vector3(cos(a) * r, -15.0 - Proc.rnd() * 4.0, sin(a) * r * 0.8 - 2.0)
		_cloud(p, 16.0 + Proc.rnd() * 14.0, 0.9, i, i % 2 == 0)
	# 2) câțiva nori jos, în prim-plan, sub nivelul stâncii (paralaxă la rotire)
	for i in 3:
		_cloud(Vector3(-15.0 + i * 15.0 + Proc.rnd() * 3.0, -17.0 - Proc.rnd() * 2.0, 9.0 + Proc.rnd() * 4.0), 15.0 + Proc.rnd() * 5.0, 0.95, i + 1, i % 2 == 1)
	# 3) nori îndepărtați în spatele insulei (ceața îi estompează)
	for i in 9:
		_cloud(Vector3((Proc.rnd() - 0.5) * 120.0, -6.0 + Proc.rnd() * 14.0, -50.0 - Proc.rnd() * 40.0), 26.0 + Proc.rnd() * 20.0, 0.7, i + 2, i % 2 == 0)
	# insule îndepărtate: imagine prerandată din modelele jocului
	var tex: Texture2D = load("res://art3d/far_island.png") if ResourceLoader.exists("res://art3d/far_island.png") else null
	for i in FAR.size():
		var g: Node3D
		if tex:
			var s := Sprite3D.new()
			s.texture = tex
			s.pixel_size = (11.0 - i * 2.0) / tex.get_width()
			s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
			s.shaded = false
			s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
			s.flip_h = i == 1
			s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			g = s
		else:
			g = Proc.far_island()
		g.position = FAR[i]
		add_child(g)
		far_islands.append(g)


# ---------------- evenimente ----------------
func _building(id: String) -> Building:
	for b in island.get_node("Buildings").get_children():
		if b.id == id:
			return b
	return null


func _on_selected(id: String) -> void:
	ring.visible = id != ""
	if id == "":
		return
	var b := _building(id)
	var r := maxf(b.local_aabb.size.x, b.local_aabb.size.z) * 0.5 * b.scale.x + 0.25
	ring.position = Vector3(b.position.x, 0.08, b.position.z)
	ring.set_meta("r", r)
	sel_light.position = b.position + Vector3(0, Models.HEIGHT.get(id, 4.0) * 0.6, 2.0)


func _on_upgraded(id: String) -> void:
	var b := _building(id)
	sparks.position = b.position + Vector3(0, Models.HEIGHT.get(id, 4.0) * 0.5, 0)
	sparks.restart()


func _process(dt: float) -> void:
	t += dt
	island.position.y = sin(t * 0.7) * 0.08
	gem.rotation.y = t
	gem.position.y = FOUNTAIN.y + sin(t * 2.0) * 0.08
	if ring.visible:
		ring.scale = Vector3.ONE * float(ring.get_meta("r", 2.0)) * (1.0 + sin(t * 4.0) * 0.03)
		sel_light.light_energy = 1.2 + 0.4 * sin(t * 4.0)
	else:
		sel_light.light_energy = 0.0
	for c in clouds:
		c.position.x += dt * 0.35
		if c.position.x > 70.0:
			c.position.x = -70.0
	for i in far_islands.size():
		far_islands[i].position.y = FAR[i].y + sin(t * 0.5 + i) * 0.4
