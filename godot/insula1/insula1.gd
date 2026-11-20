extends Node3D
## Insula 1: insula trimisă de tine (din Tripo), îmbunătățită pentru joc, fără s-o refacem:
## textura mărită (4096 px, culori mai vii), apa ei care acum curge (râul, laguna, iazurile), cascadele ei cu dungi
## care cad și ceață la bază, vârtej în portal, felinare care pâlpâie și cristale care pulsează, cer, nori,
## insulițe în fundal, petale și fluturi, plus un efect de lumină și undă când Orion aterizează pe o căsuță.
## Logica jocului (zar, mutare, date, UI, cameră) rămâne în insula.gd; de aici se folosește doar on_landed(i).
##
## Setări (Project Settings > buble/..., sau din inspector):
##   calitate: -1 automat (Mediu pe telefon, Mare pe calculator), 0 Mic, 1 Mediu, 2 Mare
##   miscare_redusa: oprește particulele, pâlpâitul, pulsul și fluturii; apa și vârtejul merg foarte încet

const Info := preload("res://insula1/data/insula1_info.gd")
const Board := preload("res://data/insula1_casute.gd")
const MODEL := "res://assets/models/insula1/insula1.glb"
const FUNDAL := "res://assets/models/fundal/"
const SH_INSULA := preload("res://insula1/shaders/insula.gdshader")
const SH_APA := preload("res://insula1/shaders/water_flow.gdshader")
const SH_PORTAL := preload("res://insula1/shaders/portal_vartej.gdshader")
const SH_ATERIZARE := preload("res://insula1/shaders/aterizare.gdshader")
const TEX := "res://insula1/textures/"
const VANT := Vector2(0.8, -0.6)  # direcția în care zboară petalele
const DURATA_ATERIZARE := 0.9

@export_range(-1, 2) var calitate := -1
@export var miscare_redusa := false

var _t := 0.0
var _env: Environment
var _m_insula: ShaderMaterial
var _m_apa: ShaderMaterial
var _m_particule: StandardMaterial3D
var _m_corp: StandardMaterial3D
var _m_aterizare: ShaderMaterial
var _efecte: Array = []  # [MeshInstance3D, timp 0..1 sau -1 dacă e liber]
var _nori: Array = []
var _insulite: Array = []
var _fluturi: Array = []
var _stat: Label


func _ready() -> void:
	_citeste_setari()
	_materiale()
	_mediu()
	_insula()
	_ceata_cascade()
	_portal()
	_pregateste_aterizare()
	_atmosfera()
	_viata()
	_statistici()


func _citeste_setari() -> void:
	if calitate < 0:
		calitate = int(ProjectSettings.get_setting("buble/grafica/calitate", -1))
	if calitate < 0:
		calitate = 1 if OS.has_feature("mobile") else 2
	if ProjectSettings.get_setting("buble/accesibilitate/miscare_redusa", false):
		miscare_redusa = true


func _tex(nume: String) -> Texture2D:
	return load(TEX + nume) as Texture2D


# --------------------------------------------------------------------------- materiale
func _materiale() -> void:
	_m_insula = ShaderMaterial.new()
	_m_insula.shader = SH_INSULA
	_m_insula.set_shader_parameter("animat", not miscare_redusa)

	# o singură apă: modul (râu / lac / cascadă) vine din culoarea de vârf (COLOR.a) a fiecărei plase;
	# culorile sunt cele ale apei pictate pe insula ta, puțin mai luminoase
	_m_apa = ShaderMaterial.new()
	_m_apa.shader = SH_APA
	_m_apa.set_shader_parameter("tex_normale", _tex("apa_normal.png"))
	_m_apa.set_shader_parameter("calitate_mare", calitate >= 1)
	_m_apa.set_shader_parameter("viteza", 0.12 if miscare_redusa else 0.5)
	_m_apa.set_shader_parameter("culoare_mal", Color(0.36, 0.82, 0.80))
	_m_apa.set_shader_parameter("culoare_adanc", Color(0.05, 0.40, 0.58))
	_m_apa.set_shader_parameter("culoare_cascada", Color(0.55, 0.88, 0.95))

	# particule (ceață la cascade, petale): pete moi, culoarea din particulă
	_m_particule = StandardMaterial3D.new()
	_m_particule.albedo_texture = _tex("nor.png")
	_m_particule.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_m_particule.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_m_particule.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_m_particule.vertex_color_use_as_albedo = true

	# culori pe vârfuri: insulițele din fundal și fluturii
	_m_corp = StandardMaterial3D.new()
	_m_corp.vertex_color_use_as_albedo = true
	_m_corp.roughness = 0.8
	_m_corp.cull_mode = BaseMaterial3D.CULL_DISABLED

	_m_aterizare = ShaderMaterial.new()
	_m_aterizare.shader = SH_ATERIZARE


# --------------------------------------------------------------------------- cer, lumină, ceață
func _mediu() -> void:
	_env = Environment.new()
	var cer := ProceduralSkyMaterial.new()
	cer.sky_top_color = Color("2f7fe0")
	cer.sky_horizon_color = Color("bfe3ff")
	cer.ground_horizon_color = Color("bfe3ff")
	cer.ground_bottom_color = Color("7cbcf4")  # sub insulă e tot cer
	var sky := Sky.new()
	sky.sky_material = cer
	_env.sky = sky
	_env.background_mode = Environment.BG_SKY
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_env.ambient_light_energy = 0.85
	_env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	_env.tonemap_mode = Environment.TONE_MAPPER_ACES
	_env.tonemap_white = 6.0
	_env.glow_enabled = calitate >= 1
	_env.glow_intensity = 0.7
	_env.glow_strength = 0.9
	_env.glow_bloom = 0.02
	_env.glow_hdr_threshold = 1.0
	_env.adjustment_enabled = true
	_env.adjustment_saturation = 1.08
	_env.adjustment_contrast = 1.04
	# ceață de distanță: insulițele din fundal se pierd în aer
	_env.fog_enabled = true
	_env.fog_light_color = Color("bfe0ff")
	_env.fog_density = 0.0035
	_env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.environment = _env
	add_child(we)

	# o singură direcție de lumină, ca la Orion: cheie caldă sus-stânga-față, umbre în 2 trepte
	var soare := DirectionalLight3D.new()
	soare.name = "Soare"
	soare.light_color = Color("ffe9c8")
	soare.light_energy = 1.3
	soare.shadow_enabled = calitate >= 1
	soare.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	soare.directional_shadow_max_distance = 45.0 if calitate >= 2 else 32.0
	add_child(soare)
	soare.look_at_from_position(Vector3(-10.0, 13.0, 10.0), Vector3.ZERO, Vector3.UP)
	# contur cyan discret din spate (fără umbre)
	var rim := DirectionalLight3D.new()
	rim.name = "ContourCyan"
	rim.light_color = Color("7fe6ff")
	rim.light_energy = 0.35
	rim.shadow_enabled = false
	add_child(rim)
	rim.look_at_from_position(Vector3(4.0, 8.0, -12.0), Vector3.ZERO, Vector3.UP)


# --------------------------------------------------------------------------- insula ta + apa ei
func _insula() -> void:
	var sc := load(MODEL) as PackedScene
	if sc == null:
		push_warning("Insula 1: lipsește " + MODEL)
		return
	var model := sc.instantiate() as Node3D
	model.name = "Insula1"
	add_child(model)
	for n in model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var nume := String(mi.name)
		if nume.begins_with("Apa") or nume.begins_with("Cascade"):
			mi.material_override = _m_apa
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		else:
			# texturile vin chiar din GLB (aceleași, nu se încarcă de două ori)
			var std := mi.get_active_material(0) as BaseMaterial3D
			if std:
				_m_insula.set_shader_parameter("tex_albedo", std.albedo_texture)
				_m_insula.set_shader_parameter("tex_orm", std.roughness_texture)
			mi.material_override = _m_insula
			if calitate == 0:
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# ceață la baza cascadelor (cele care cad în gol fac un nor mai mare)
func _ceata_cascade() -> void:
	if calitate == 0:
		return
	for c in Info.CASCADE:
		var baza: Vector3 = c[1]
		var latime: float = c[2]
		var in_gol := baza.y < -4.0
		var p := GPUParticles3D.new()
		p.name = "Ceata"
		p.amount = 20 if in_gol else 10
		p.lifetime = 2.6
		p.preprocess = 2.0
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = Vector3(latime * 0.5, 0.2, 0.4)
		pm.direction = Vector3(0.0, 1.0, 0.0)
		pm.spread = 60.0
		pm.initial_velocity_min = 0.25
		pm.initial_velocity_max = 0.8
		pm.gravity = Vector3(0.0, 0.1 if not in_gol else -0.3, 0.0)
		pm.scale_min = 0.6
		pm.scale_max = 2.0 if in_gol else 1.1
		var g := Gradient.new()
		g.set_color(0, Color(1.0, 1.0, 1.0, 0.0))
		g.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
		g.add_point(0.25, Color(1.0, 1.0, 1.0, 0.55))
		var gt := GradientTexture1D.new()
		gt.gradient = g
		pm.color_ramp = gt
		p.process_material = pm
		var q := QuadMesh.new()
		q.size = Vector2(1.2, 1.2)
		q.material = _m_particule
		p.draw_pass_1 = q
		p.position = baza + Vector3(0.0, 0.25, 0.0)
		p.emitting = not miscare_redusa
		add_child(p)


# vârtejul din portal: un dreptunghi chiar în fața panoului din arcadă
func _portal() -> void:
	var m := ShaderMaterial.new()
	m.shader = SH_PORTAL
	m.set_shader_parameter("viteza", 0.25 if miscare_redusa else 1.0)
	var q := QuadMesh.new()
	q.size = Info.PORTAL_MARIME
	var mi := MeshInstance3D.new()
	mi.name = "PortalVartej"
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var n: Vector3 = Info.PORTAL_NORMALA.normalized()
	# QuadMesh privește spre +Z; Basis.looking_at(-n) pune +Z pe direcția n
	mi.transform = Transform3D(Basis.looking_at(-n, Vector3.UP), Info.PORTAL_CENTRU + n * 0.04)
	add_child(mi)


# --------------------------------------------------------------------------- aterizarea pe căsuțe
func _pregateste_aterizare() -> void:
	var q := QuadMesh.new()
	var lat := Board.RAZA * 2.0 / 0.42  # căsuța ocupă 42% din jumătatea pătratului, restul e pentru undă
	q.size = Vector2(lat, lat)
	for k in 3:  # câteva în paralel, pentru sărituri rapide una după alta
		var mi := MeshInstance3D.new()
		mi.name = "Aterizare_%d" % k
		mi.mesh = q
		mi.material_override = _m_aterizare
		mi.rotation_degrees = Vector3(-90.0, 0.0, 0.0)  # culcat, cu fața în sus
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		add_child(mi)
		_efecte.append([mi, -1.0])


## Chemat de joc când Orion aterizează pe căsuța i: căsuța se aprinde scurt și pleacă o undă.
func on_landed(i: int) -> void:
	if i < 0 or i >= Board.CASUTE.size():
		return
	var ales: Array = _efecte[0]
	for e in _efecte:
		if float(e[1]) < 0.0:
			ales = e
			break
		if float(e[1]) > float(ales[1]):
			ales = e
	var mi: MeshInstance3D = ales[0]
	mi.position = Board.CASUTE[i] + Vector3(0.0, 0.1, 0.0)  # puțin deasupra: căsuțele din model sunt ușor bombate
	mi.set_instance_shader_parameter("culoare", Vector3(1.0, 0.86, 0.5))
	mi.set_instance_shader_parameter("progres", 0.0)
	mi.visible = true
	ales[1] = 0.0


# --------------------------------------------------------------------------- atmosferă: nori, raze, insulițe
func _atmosfera() -> void:
	var nor_mat := StandardMaterial3D.new()
	nor_mat.albedo_texture = _tex("nor.png")
	nor_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	nor_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	nor_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	nor_mat.billboard_keep_scale = true
	nor_mat.disable_receive_shadows = true
	var quad := QuadMesh.new()
	var r := RandomNumberGenerator.new()
	r.seed = 21
	var n_nori := 30 if calitate >= 1 else 14
	for i in n_nori:
		var marea := i < int(n_nori * 0.7)  # marea de nori de dedesubt
		var a := r.randf() * TAU
		var raza := r.randf_range(10.0, 28.0) if marea else r.randf_range(45.0, 75.0)
		var y := r.randf_range(-14.0, -9.0) if marea else r.randf_range(-2.0, 16.0)
		var mi := MeshInstance3D.new()
		mi.mesh = quad
		mi.material_override = nor_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var s := r.randf_range(7.0, 13.0) if marea else r.randf_range(10.0, 20.0)
		mi.scale = Vector3(s * 1.6, s, 1.0)
		mi.position = Vector3(cos(a) * raza, y, sin(a) * raza)
		add_child(mi)
		_nori.append([mi, a, raza, y, r.randf_range(0.004, 0.012) * (1.0 if r.randf() < 0.5 else -1.0)])
	# raze de soare false (sus-dreapta, aditive)
	var raze := StandardMaterial3D.new()
	raze.albedo_texture = _tex("raze.png")
	raze.albedo_color = Color(1.0, 1.0, 1.0, 0.32)
	raze.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	raze.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	raze.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	raze.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	raze.cull_mode = BaseMaterial3D.CULL_DISABLED
	for k in 3:
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(5.0 + 2.0 * k, 34.0)
		mi.mesh = q
		mi.material_override = raze
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(22.0 + 5.0 * k, 16.0, -34.0 + 4.0 * k)
		mi.rotation_degrees = Vector3(0.0, 0.0, 28.0 + 5.0 * k)
		add_child(mi)
	# insulițe plutitoare în fundal (culori pe vârfuri)
	var pozitii := [[Vector3(-34.0, 3.0, -30.0), "insulita_a", 1.6], [Vector3(38.0, -2.0, -26.0), "insulita_c", 1.4],
		[Vector3(-26.0, -6.0, -52.0), "insulita_b", 2.2], [Vector3(30.0, 7.0, -58.0), "insulita_a", 2.4],
		[Vector3(-44.0, 1.0, 6.0), "insulita_b", 1.5]]
	for p in pozitii:
		var cale: String = FUNDAL + String(p[1]) + ".glb"
		if not ResourceLoader.exists(cale):
			continue
		var m := (load(cale) as PackedScene).instantiate() as Node3D
		m.position = p[0]
		m.scale = Vector3.ONE * float(p[2])
		add_child(m)
		for part in m.find_children("*", "MeshInstance3D", true, false):
			(part as MeshInstance3D).material_override = _m_corp
			(part as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_insulite.append([m, (p[0] as Vector3).y, r.randf() * TAU])


# --------------------------------------------------------------------------- viață: petale, fluturi
func _viata() -> void:
	if calitate == 0 or miscare_redusa:
		return
	var p := GPUParticles3D.new()
	p.name = "Petale"
	p.amount = 36
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.visibility_aabb = AABB(Vector3(-16.0, -6.0, -16.0), Vector3(32.0, 14.0, 32.0))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(10.0, 2.5, 11.0)
	pm.direction = Vector3(VANT.x, -0.2, VANT.y)
	pm.spread = 25.0
	pm.initial_velocity_min = 0.6
	pm.initial_velocity_max = 1.4
	pm.gravity = Vector3(0.0, -0.18, 0.0)
	pm.angle_min = 0.0
	pm.angle_max = 360.0
	pm.angular_velocity_min = -90.0
	pm.angular_velocity_max = 90.0
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	pm.color = Color("ffa6cf")
	pm.hue_variation_min = -0.12
	pm.hue_variation_max = 0.12
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.16, 0.16)
	q.material = _m_particule
	p.draw_pass_1 = q
	p.position = Vector3(0.0, 4.0, 0.0)
	add_child(p)
	# fluturi (6): două aripi care bat, zbor în bucle pe lângă drum, spre marginea insulei
	var culori := [Color("ff8ac2"), Color("ffd84d"), Color("7fe6ff"), Color("ffffff"), Color("c79bff"), Color("ffb36b")]
	var n := Board.CASUTE.size()
	for k in 6:
		var a: Vector3 = Board.CASUTE[(k * 4 + 2) % n]
		var b: Vector3 = Board.CASUTE[(k * 4 + 3) % n]
		var m := (a + b) * 0.5
		var spre_margine := Vector3(m.x, 0.0, m.z).normalized()
		var c := m + spre_margine * 1.3 + Vector3(0.0, 0.7, 0.0)
		var mi := MeshInstance3D.new()
		mi.mesh = _plasa_fluture(culori[k])
		mi.material_override = _m_corp
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = c
		add_child(mi)
		_fluturi.append([mi, c, float(k) * 1.7])


func _plasa_fluture(c: Color) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lin := c.srgb_to_linear()
	for s in [-1.0, 1.0]:
		for v in [Vector3(0.0, 0.0, 0.03), Vector3(0.11 * s, 0.0, 0.07), Vector3(0.1 * s, 0.0, -0.04),
				Vector3(0.0, 0.0, 0.03), Vector3(0.1 * s, 0.0, -0.04), Vector3(0.0, 0.0, -0.05)]:
			st.set_color(lin)
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
	return st.commit()


# --------------------------------------------------------------------------- statistici (debug)
func _statistici() -> void:
	if not ProjectSettings.get_setting("buble/debug/statistici", false):
		return
	var cl := CanvasLayer.new()
	cl.layer = 20
	add_child(cl)
	_stat = Label.new()
	_stat.position = Vector2(12.0, 230.0)
	_stat.add_theme_font_size_override("font_size", 20)
	_stat.add_theme_color_override("font_outline_color", Color.BLACK)
	_stat.add_theme_constant_override("outline_size", 6)
	cl.add_child(_stat)


func _process(delta: float) -> void:
	_t += delta
	for e in _efecte:
		if float(e[1]) < 0.0:
			continue
		e[1] = float(e[1]) + delta / DURATA_ATERIZARE
		var mi: MeshInstance3D = e[0]
		if float(e[1]) >= 1.0:
			e[1] = -1.0
			mi.visible = false
		else:
			mi.set_instance_shader_parameter("progres", float(e[1]))
	if not miscare_redusa:
		for nd in _nori:
			var a: float = nd[1] + _t * float(nd[4])
			(nd[0] as Node3D).position = Vector3(cos(a) * float(nd[2]), float(nd[3]), sin(a) * float(nd[2]))
		for it in _insulite:
			(it[0] as Node3D).position.y = float(it[1]) + 0.35 * sin(_t * 0.45 + float(it[2]))
		for f in _fluturi:
			var mi: MeshInstance3D = f[0]
			var c: Vector3 = f[1]
			var ph: float = f[2]
			var tt := _t * 0.6 + ph
			var p := c + Vector3(sin(tt) * 0.9, 0.25 * sin(tt * 2.3), sin(tt * 2.0) * 0.6)
			var dir := p - mi.position
			mi.position = p
			if dir.length() > 0.0001:
				mi.rotation.y = atan2(dir.x, dir.z)
			mi.scale = Vector3(0.25 + 0.75 * absf(sin(_t * 14.0 + ph)), 1.0, 1.0)
	if _stat:
		_stat.text = "FPS %d | triunghiuri %d | draw calls %d | obiecte %d | calitate %s" % [
			Engine.get_frames_per_second(),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
			["Mic", "Mediu", "Mare"][calitate]]
