extends Node3D
## Scena principală: mediu, lumini, insula plutitoare, cer, cameră și interfață.

const WATERFALLS := [Vector2(-4.4, 5.2), Vector2(4.4, 5.2)]
const FAR := [Vector3(-13, 5, -16), Vector3(14, 6, -14), Vector3(18, 0, -24)]

var env: Environment
var sun: DirectionalLight3D
var island: Node3D
var cam: CameraRig
var gem: Node3D
var ring: MeshInstance3D
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
	sky_mat.sky_top_color = Color("2a56c6")
	sky_mat.sky_horizon_color = Color("8fc0f5")
	sky_mat.ground_horizon_color = Color("a8cdf5")
	sky_mat.ground_bottom_color = Color("4f86d8")
	sky_mat.sky_curve = 0.12
	sky_mat.ground_curve = 0.08
	var sky := Sky.new()
	sky.sky_material = sky_mat

	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.4
	env.ambient_light_sky_contribution = 0.85
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.tonemap_white = 4.0
	# „bloom": doar ce depășește pragul HDR (emisivele) strălucește
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_strength = 1.0
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	# ceață ușoară pentru adâncime
	env.fog_enabled = true
	env.fog_light_color = Color("c9e3ff")
	env.fog_density = 0.0015
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.2
	env.adjustment_contrast = 1.06
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.light_color = Color("fff0d0")
	sun.light_energy = 2.0
	sun.shadow_enabled = true
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 1.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 60.0
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(sun)
	sun.look_at_from_position(Vector3(9, 16, 11), Vector3.ZERO)

	# lumină de umplere violet dinspre jos (ca HemisphereLight din prototip)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color("9a7ad0")
	fill.light_energy = 0.35
	fill.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(fill)
	fill.look_at_from_position(Vector3(-6, -10, -4), Vector3.ZERO)


func _apply_quality() -> void:
	var high := Game.quality == "inalta"
	env.glow_enabled = high
	sun.shadow_blur = 1.5 if high else 1.0
	RenderingServer.directional_shadow_atlas_set_size(2048 if high else 1024, true)
	get_viewport().msaa_3d = Viewport.MSAA_2X if high else Viewport.MSAA_DISABLED
	get_viewport().scaling_3d_scale = 1.0 if high else 0.75
	for i in clouds.size():
		clouds[i].visible = high or i % 2 == 0


# ---------------- insula ----------------
func _build_island() -> void:
	island = Node3D.new()
	island.name = "Island"
	add_child(island)

	var terrain := Models.instance("insula")
	island.add_child(terrain if terrain else Proc.terrain())
	var plaza := Proc.plaza()
	island.add_child(plaza)
	gem = plaza.get_node("Gem")

	var bs := Node3D.new()
	bs.name = "Buildings"
	island.add_child(bs)
	for info in Game.BUILDINGS:
		var b := Building.new()
		bs.add_child(b)
		b.setup(info)

	island.add_child(Mascot.new())

	ring = Proc.add(island, Proc.htor(2.2, 0.07, 48, 8), Proc.mat(Color("ffd86b"), {"emit": Color("ffc040"), "energy": 2.5}))
	ring.visible = false
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_build_water()
	_build_sparks()

	var o1 := OmniLight3D.new()
	o1.light_color = Color("ffb060")
	o1.light_energy = 2.0
	o1.omni_range = 12.0
	o1.position = Vector3(0, 2, -1.5)
	island.add_child(o1)
	var o2 := OmniLight3D.new()
	o2.light_color = Color("4fe8d8")
	o2.light_energy = 1.4
	o2.omni_range = 7.0
	o2.position = Vector3(0, 2.3, 0.3)
	island.add_child(o2)


func _drop_mesh(size: float) -> Mesh:
	var m := SphereMesh.new()
	m.radius = size
	m.height = size * 2
	m.radial_segments = 6
	m.rings = 3
	m.material = Proc.mat(Color(1, 1, 1, 0.9), {"unshaded": true, "alpha": 0.85})
	return m


func _build_water() -> void:
	# jetul fântânii
	var f := CPUParticles3D.new()
	f.amount = 48
	f.lifetime = 1.1
	f.mesh = _drop_mesh(0.06)
	f.position = Vector3(0, 2.0, 0.3)
	f.direction = Vector3.UP
	f.spread = 40.0
	f.initial_velocity_min = 2.2
	f.initial_velocity_max = 2.8
	f.gravity = Vector3(0, -6.0, 0)
	f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	island.add_child(f)

	var shader: Shader = preload("res://shaders/waterfall.gdshader")
	var layers := [
		{"w": 1.5, "h": 4.8, "speed": 0.35, "a": 0.35, "off": -0.06, "c": Color("7fd6ff")},
		{"w": 1.1, "h": 4.5, "speed": 0.6, "a": 0.75, "off": 0.0, "c": Color("bff0ff")},
		{"w": 0.6, "h": 4.3, "speed": 0.95, "a": 0.55, "off": 0.06, "c": Color("ffffff")},
	]
	for w in WATERFALLS:
		var g := Node3D.new()
		g.position = Vector3(w.x * 1.03, -2.3, w.y * 1.03)
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
			mi.position.z = L.off
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			g.add_child(mi)
		# stropi care cad
		var d := CPUParticles3D.new()
		d.amount = 30
		d.lifetime = 1.4
		d.mesh = _drop_mesh(0.07)
		d.position = Vector3(w.x * 1.05, 0.0, w.y * 1.05)
		d.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		d.emission_box_extents = Vector3(0.4, 0.05, 0.1)
		d.direction = Vector3.DOWN
		d.spread = 5.0
		d.initial_velocity_min = 1.0
		d.initial_velocity_max = 1.6
		d.gravity = Vector3(0, -2.0, 0)
		d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		island.add_child(d)
		# ceață la bază
		var mist := _soft_quad(Vector2(3.2, 1.6), Color(1, 1, 1, 0.7))
		mist.position = Vector3(w.x * 1.08, -4.6, w.y * 1.08)
		mist.name = "Mist"
		island.add_child(mist)


func _soft_quad(size: Vector2, col: Color) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = size
	var m := StandardMaterial3D.new()
	m.albedo_texture = Proc.tex("soft")
	m.albedo_color = col
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.disable_fog = false
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
	sparks.amount = 26
	sparks.lifetime = 0.9
	var m := SphereMesh.new()
	m.radius = 0.09
	m.height = 0.18
	m.radial_segments = 6
	m.rings = 3
	m.material = Proc.mat(Color("ffd86b"), {"emit": Color("ffc040"), "energy": 3.0})
	sparks.mesh = m
	sparks.direction = Vector3.UP
	sparks.spread = 60.0
	sparks.initial_velocity_min = 2.5
	sparks.initial_velocity_max = 5.5
	sparks.gravity = Vector3(0, -9.0, 0)
	sparks.scale_amount_min = 1.0
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	sparks.scale_amount_curve = curve
	sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	island.add_child(sparks)


# ---------------- cer ----------------
func _build_sky() -> void:
	Proc.reseed(23)
	for i in 16:
		var low := i < 10
		var c := Node3D.new()
		if low:
			c.position = Vector3((Proc.rnd() - 0.5) * 60, -9 + Proc.rnd() * 3.5, -8 + Proc.rnd() * 22)
		else:
			c.position = Vector3((Proc.rnd() - 0.5) * 80, -3 + Proc.rnd() * 10, -24 - Proc.rnd() * 20)
		var tint := Color.WHITE if i % 3 else Color("e4ecff")
		for j in 6:
			var s := 5.0 + Proc.rnd() * 5.0
			var puff := _soft_quad(Vector2(s, s * 0.7), Color(tint.r, tint.g, tint.b, 0.55 + Proc.rnd() * 0.3))
			puff.position = Vector3((j - 2.5) * 1.6 + Proc.rnd(), Proc.rnd() * 1.2, Proc.rnd() * 1.5)
			c.add_child(puff)
		add_child(c)
		clouds.append(c)
	for p in FAR:
		var g := Proc.far_island()
		g.position = p
		add_child(g)
		far_islands.append(g)


# ---------------- evenimente ----------------
func _on_selected(id: String) -> void:
	ring.visible = id != ""
	if id != "":
		var b := Game.building(id)
		ring.position = Vector3(b.x, 0.1, b.z)


func _on_upgraded(id: String) -> void:
	var b := Game.building(id)
	sparks.position = Vector3(b.x, 1.5, b.z)
	sparks.restart()


func _process(dt: float) -> void:
	t += dt
	island.position.y = sin(t * 0.8) * 0.15
	gem.rotation.y = t
	gem.position.y = 2.0 + sin(t * 2.0) * 0.08
	if ring.visible:
		ring.scale = Vector3.ONE * (1.0 + sin(t * 4.0) * 0.05)
	for c in clouds:
		c.position.x += dt * 0.5
		if c.position.x > 45.0:
			c.position.x = -45.0
	for i in far_islands.size():
		far_islands[i].position.y = FAR[i].y + sin(t * 0.6 + i) * 0.35
