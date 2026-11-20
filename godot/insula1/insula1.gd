extends Node3D
## Insula 1 (v3, Faza A): insula trimisă de tine (din Tripo), îmbunătățită pentru joc, fără s-o refacem.
## Modelul e tăiat în Blender pe clase (blender/insula1/v3_faza_a.py): stânci, iarbă, frunziș, flori, pânze,
## cristale, felinare, portal, barca, palele morii, restul + apa și cascadele. Toate clasele folosesc un singur
## material (insula.gdshader); diferențele (detaliul, vântul, lumina proprie) sunt uniforme pe instanță.
## Aici: lumina și cerul, apa care curge, moara care se rotește, barca care se leagănă, halouri la felinare,
## vârtejul portalului, cele 22 de căsuțe noi (Casuta.tscn) peste discurile vechi, nori, insulițe cu cascade,
## petale, fluturi, păsări și estomparea a ce ajunge între cameră și Orion.
## Logica jocului (zar, mutare, date, UI, cameră) rămâne în insula.gd; de aici se folosește doar on_landed(i).
##
## Setări (Project Settings > buble/..., sau din inspector):
##   calitate: -1 automat (Mediu pe telefon, Mare pe calculator), 0 Mic, 1 Mediu, 2 Mare
##   miscare_redusa: oprește vântul, particulele, pâlpâitul, pulsul, moara, barca, fluturii și păsările
##   mod_debug (buble/debug/mod_insula): 0 normal, 1 tablă de șah, 2 clase, 3 AO, 4 normale

const Info := preload("res://insula1/data/insula1_info.gd")
const Board := preload("res://data/insula1_casute.gd")
const Tipuri := preload("res://insula1/data/tipuri_casute.gd")
const CasutaScene := preload("res://insula1/casuta/Casuta.tscn")
const MODEL := "res://assets/models/insula1/insula1.glb"
const FUNDAL := "res://assets/models/fundal/"
const SH_INSULA := preload("res://insula1/shaders/insula.gdshader")
const SH_APA := preload("res://insula1/shaders/water_flow.gdshader")
const SH_PORTAL := preload("res://insula1/shaders/portal_vartej.gdshader")
const SH_CASUTA := preload("res://insula1/shaders/casuta.gdshader")
const SH_HALOU := preload("res://insula1/shaders/halou.gdshader")
const SH_CER := preload("res://insula1/shaders/cer.gdshader")
const TEX := "res://insula1/textures/"
const VANT_DIRECTIE := Vector2(0.8, -0.6)
const SCALA_CASUTA := 1.1  # căsuța nouă (raza 0,78 m) acoperă marginea discului vechi (raza 0,76 m)
## clasele insulei: [detaliu (0 fără, 1 stâncă, 2 iarbă, 3 granulație), vânt, lumină proprie, culoare de verificare]
const CLASE := {
	"Insula_restul": [3.0, 0.0, 0.0, Color(0.62, 0.62, 0.62)],
	"Insula_stanci": [1.0, 0.0, 0.0, Color(0.45, 0.36, 0.55)],
	"Insula_iarba": [2.0, 0.0, 0.0, Color(0.55, 0.85, 0.25)],
	"Insula_frunzis": [2.0, 1.0, 0.0, Color(0.05, 0.45, 0.12)],
	"Insula_flori": [3.0, 0.8, 0.0, Color(1.0, 0.45, 0.75)],
	"Insula_panze": [0.0, 1.2, 0.0, Color(1.0, 0.55, 0.0)],
	"Insula_cristale": [0.0, 0.0, 0.55, Color(0.3, 0.95, 1.0)],
	"Insula_felinare": [0.0, 0.0, 0.0, Color(1.0, 0.85, 0.1)],
	"Insula_portal": [3.0, 0.0, 0.0, Color(0.6, 0.2, 1.0)],
	"Barca": [3.0, 0.0, 0.0, Color(0.55, 0.3, 0.1)],
	"Moara_pale": [3.0, 0.0, 0.0, Color(1.0, 0.1, 0.1)],
}

@export_range(-1, 2) var calitate := -1
@export var miscare_redusa := false
@export_range(0, 4) var mod_debug := -1  # -1: din setarea de proiect buble/debug/mod_insula
@export var estompare := true

var _t := 0.0
var _env: Environment
var _soare: DirectionalLight3D
var _m_insula: ShaderMaterial
var _m_apa: ShaderMaterial
var _m_particule: StandardMaterial3D
var _m_corp: StandardMaterial3D
var _m_casuta: ShaderMaterial
var _moara: Node3D
var _barca: Node3D
var _barca_baza := Transform3D.IDENTITY
var _casute: Array = []
var _nori: Array = []
var _insulite: Array = []
var _fluturi: Array = []
var _pasari: Array = []
var _stat: Label
var _orion: Node3D


func _ready() -> void:
	_citeste_setari()
	RenderingServer.global_shader_parameter_set("vant_directie", VANT_DIRECTIE)
	RenderingServer.global_shader_parameter_set("orion_pozitie", Board.CASUTE[0])
	_materiale()
	_mediu()
	_insula()
	_ceata_cascade()
	_portal()
	_halouri()
	_casute_joc()
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
	if mod_debug < 0:
		mod_debug = int(ProjectSettings.get_setting("buble/debug/mod_insula", 0))


func _tex(nume: String) -> Texture2D:
	return load(TEX + nume) as Texture2D


# --------------------------------------------------------------------------- materiale
func _materiale() -> void:
	_m_insula = ShaderMaterial.new()
	_m_insula.shader = SH_INSULA
	_m_insula.set_shader_parameter("tex_detaliu", _tex("detaliu.png"))
	_m_insula.set_shader_parameter("animat", not miscare_redusa)
	_m_insula.set_shader_parameter("vant_activ", calitate >= 1 and not miscare_redusa)
	_m_insula.set_shader_parameter("detaliu_activ", calitate >= 1)
	_m_insula.set_shader_parameter("estompare", estompare)
	_m_insula.set_shader_parameter("mod_debug", mod_debug)
	# nuanțare măsurată pe captura din Godot: insula era mai deschisă (0,64) și mult mai puțin saturată (0,23)
	# decât blana lui Orion (0,57 și 0,55); o aducem spre contrastul și culorile lui
	_m_insula.set_shader_parameter("gama", 1.08)
	_m_insula.set_shader_parameter("saturatie", 1.18)
	_m_insula.set_shader_parameter("contrast", 1.1)

	# o singură apă: modul (râu / lac / cascadă) vine din COLOR.a; culorile sunt cele ale apei pictate pe insula ta
	_m_apa = ShaderMaterial.new()
	_m_apa.shader = SH_APA
	_m_apa.set_shader_parameter("tex_normale", _tex("apa_normal.png"))
	_m_apa.set_shader_parameter("calitate_mare", calitate >= 1)
	_m_apa.set_shader_parameter("viteza", 0.12 if miscare_redusa else 0.5)
	_m_apa.set_shader_parameter("culoare_mal", Color(0.36, 0.84, 0.82))
	_m_apa.set_shader_parameter("culoare_adanc", Color(0.04, 0.38, 0.6))
	_m_apa.set_shader_parameter("culoare_cascada", Color(0.55, 0.88, 0.96))

	# particule (ceață la cascade, petale): pete moi, culoarea din particulă
	_m_particule = StandardMaterial3D.new()
	_m_particule.albedo_texture = _tex("nor.png")
	_m_particule.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_m_particule.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_m_particule.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_m_particule.vertex_color_use_as_albedo = true

	# culori pe vârfuri: insulițele din fundal, fluturii, păsările
	_m_corp = StandardMaterial3D.new()
	_m_corp.vertex_color_use_as_albedo = true
	_m_corp.roughness = 0.85
	_m_corp.cull_mode = BaseMaterial3D.CULL_DISABLED

	_m_casuta = ShaderMaterial.new()
	_m_casuta.shader = SH_CASUTA
	_m_casuta.set_shader_parameter("tex_piatra", _tex("casuta_albedo.png"))
	_m_casuta.set_shader_parameter("norm_piatra", _tex("casuta_normal.png"))
	_m_casuta.set_shader_parameter("normale", calitate >= 1)


# --------------------------------------------------------------------------- cer, lumină, ceață
func _mediu() -> void:
	_env = Environment.new()
	var cer := ShaderMaterial.new()
	cer.shader = SH_CER
	cer.set_shader_parameter("tex_zgomot", _tex("apa_normal.png"))
	var sky := Sky.new()
	sky.sky_material = cer
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	_env.sky = sky
	_env.background_mode = Environment.BG_SKY
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_env.ambient_light_energy = 0.8
	_env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	_env.tonemap_mode = Environment.TONE_MAPPER_ACES
	_env.tonemap_white = 6.0
	_env.glow_enabled = calitate >= 1
	_env.glow_intensity = 0.6
	_env.glow_strength = 0.9
	_env.glow_bloom = 0.02
	_env.glow_hdr_threshold = 1.0
	_env.adjustment_enabled = true
	_env.adjustment_saturation = 1.04
	_env.adjustment_contrast = 1.03
	_env.fog_enabled = true
	_env.fog_light_color = Color("c4e0ff")
	_env.fog_density = 0.0035
	_env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.environment = _env
	add_child(we)

	# aceeași lumină ca pe Orion: cheie caldă sus-stânga-față, umbre reale în 2 trepte, distanță limitată;
	# venind mai din stânga decât din față, umbrele cad spre dreapta și se văd din camera de joc
	_soare = DirectionalLight3D.new()
	_soare.name = "Soare"
	_soare.light_color = Color("ffe7c4")
	_soare.light_energy = 1.4
	_soare.shadow_enabled = calitate >= 1
	_soare.shadow_bias = 0.04
	_soare.shadow_normal_bias = 1.2
	_soare.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	_soare.directional_shadow_max_distance = 45.0 if calitate >= 2 else 30.0
	add_child(_soare)
	_soare.look_at_from_position(Vector3(-14.0, 12.0, 6.0), Vector3.ZERO, Vector3.UP)
	var rim := DirectionalLight3D.new()
	rim.name = "ContourCyan"
	rim.light_color = Color("7fe6ff")
	rim.light_energy = 0.35
	rim.shadow_enabled = false
	add_child(rim)
	rim.look_at_from_position(Vector3(4.0, 8.0, -12.0), Vector3.ZERO, Vector3.UP)


# --------------------------------------------------------------------------- insula ta, pe clase, + apa ei
func _insula() -> void:
	var sc := load(MODEL) as PackedScene
	if sc == null:
		push_warning("Insula 1: lipsește " + MODEL)
		return
	var model := sc.instantiate() as Node3D
	model.name = "Insula1"
	add_child(model)
	var texturi_puse := false
	for n in model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var nume := String(mi.name)
		if nume.begins_with("Apa") or nume.begins_with("Cascade"):
			mi.material_override = _m_apa
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			continue
		if not texturi_puse:
			# texturile vin chiar din GLB (aceleași pentru toate clasele, nu se încarcă de două ori)
			var std := mi.get_active_material(0) as BaseMaterial3D
			if std:
				_m_insula.set_shader_parameter("tex_albedo", std.albedo_texture)
				_m_insula.set_shader_parameter("tex_orm", std.roughness_texture)
				texturi_puse = true
		mi.material_override = _m_insula
		var cl: Array = CLASE.get(_clasa(nume), CLASE["Insula_restul"])
		mi.set_instance_shader_parameter("detaliu", float(cl[0]))
		mi.set_instance_shader_parameter("vant", float(cl[1]))
		mi.set_instance_shader_parameter("lumina_proprie", float(cl[2]))
		var cc: Color = cl[3]
		mi.set_instance_shader_parameter("culoare_clasa", Vector3(cc.r, cc.g, cc.b))
		if calitate == 0:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if nume.begins_with("Moara_pale"):
			_moara = mi
		elif nume.begins_with("Barca"):
			_barca = mi
			_barca_baza = mi.transform


# numele din GLB pot primi sufixe la import („Insula_iarba_001”): păstrăm doar prefixul clasei
func _clasa(nume: String) -> String:
	for k in CLASE:
		if nume.begins_with(k):
			return k
	return "Insula_restul"


# ceață la baza cascadelor; cele care cad în gol se topesc într-un nor mai mare
func _ceata_cascade() -> void:
	if calitate == 0:
		return
	for c in Info.CASCADE:
		var baza: Vector3 = c[1]
		var latime: float = c[2]
		var in_gol := baza.y < -4.0
		var p := GPUParticles3D.new()
		p.name = "Ceata"
		p.amount = 18 if in_gol else 10
		p.lifetime = 2.8
		p.preprocess = 2.0
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = Vector3(latime * 0.5, 0.3, 0.4)
		pm.direction = Vector3(0.0, 1.0, 0.0)
		pm.spread = 60.0
		pm.initial_velocity_min = 0.2
		pm.initial_velocity_max = 0.7
		pm.gravity = Vector3(0.0, -0.25 if in_gol else 0.1, 0.0)
		pm.scale_min = 0.8 if in_gol else 0.5
		pm.scale_max = 2.6 if in_gol else 1.1
		var g := Gradient.new()
		g.set_color(0, Color(1.0, 1.0, 1.0, 0.0))
		g.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
		g.add_point(0.25, Color(1.0, 1.0, 1.0, 0.6))
		var gt := GradientTexture1D.new()
		gt.gradient = g
		pm.color_ramp = gt
		p.process_material = pm
		var q := QuadMesh.new()
		q.size = Vector2(1.3, 1.3)
		q.material = _m_particule
		p.draw_pass_1 = q
		p.position = baza + Vector3(0.0, 0.6 if in_gol else 0.25, 0.0)
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
	mi.transform = Transform3D(Basis.looking_at(-n, Vector3.UP), Info.PORTAL_CENTRU + n * 0.04)
	add_child(mi)


# halouri calde la flăcările felinarelor (un singur MultiMesh)
func _halouri() -> void:
	if Info.FLACARI.is_empty():
		return
	var m := ShaderMaterial.new()
	m.shader = SH_HALOU
	m.set_shader_parameter("animat", not miscare_redusa)
	var q := QuadMesh.new()
	q.size = Vector2(0.9, 0.9)
	q.material = m
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = q
	mm.instance_count = Info.FLACARI.size()
	for i in Info.FLACARI.size():
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Info.FLACARI[i] + Vector3(0.0, 0.05, 0.0)))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Halouri"
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


# --------------------------------------------------------------------------- cele 22 de căsuțe noi
func _casute_joc() -> void:
	var n := Board.CASUTE.size()
	for i in n:
		var t := CasutaScene.instantiate() as Node3D
		t.name = "Casuta_%02d" % i
		t.set("miscare_redusa", miscare_redusa)
		t.set("baza_scala", SCALA_CASUTA)
		add_child(t)
		t.position = Board.CASUTE[i] + Vector3(0.0, 0.04, 0.0)
		var urm: Vector3 = Board.CASUTE[(i + 1) % n]
		t.rotation.y = atan2(urm.x - t.position.x, urm.z - t.position.z)
		t.scale = Vector3.ONE * SCALA_CASUTA
		t.call("configureaza", Tipuri.tip(i), _m_casuta)
		_casute.append(t)


## Chemat de joc când Orion aterizează pe căsuța i: unda, aprinderea și turtirea scurtă a căsuței.
func on_landed(i: int) -> void:
	if i >= 0 and i < _casute.size():
		_casute[i].call("aterizare")


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
	# raze de soare false (sus-stânga, din partea soarelui; aditive)
	var raze := StandardMaterial3D.new()
	raze.albedo_texture = _tex("raze.png")
	raze.albedo_color = Color(1.0, 1.0, 1.0, 0.3)
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
		mi.position = Vector3(-24.0 - 5.0 * k, 16.0, -30.0 + 4.0 * k)
		mi.rotation_degrees = Vector3(0.0, 0.0, -28.0 - 5.0 * k)
		add_child(mi)
	# insulițe cu cascade în fundal (aceleași 3 modele, refolosite), se leagănă încet
	var pozitii := [[Vector3(-34.0, 3.0, -30.0), "a", 1.3, 0.4], [Vector3(38.0, -2.0, -26.0), "c", 1.2, 2.1],
		[Vector3(-26.0, -6.0, -52.0), "b", 1.8, 4.0], [Vector3(30.0, 7.0, -58.0), "a", 2.0, 1.2],
		[Vector3(-44.0, 1.0, 6.0), "c", 1.3, 5.2]]
	for p in pozitii:
		var cale: String = FUNDAL + "insulita_cascada_" + String(p[1]) + ".glb"
		if not ResourceLoader.exists(cale):
			continue
		var m := (load(cale) as PackedScene).instantiate() as Node3D
		m.position = p[0]
		m.scale = Vector3.ONE * float(p[2])
		m.rotation.y = float(p[3])
		add_child(m)
		for part in m.find_children("*", "MeshInstance3D", true, false):
			var mi := part as MeshInstance3D
			mi.material_override = _m_apa if String(mi.name).begins_with("Cascada") else _m_corp
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_insulite.append([m, (p[0] as Vector3).y, r.randf() * TAU, float(p[3])])


# --------------------------------------------------------------------------- viață: petale, fluturi, păsări
func _viata() -> void:
	if calitate == 0 or miscare_redusa:
		return
	var p := GPUParticles3D.new()
	p.name = "Petale"
	p.amount = 36  # maxim 40
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.visibility_aabb = AABB(Vector3(-16.0, -6.0, -16.0), Vector3(32.0, 14.0, 32.0))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(10.0, 2.5, 11.0)
	pm.direction = Vector3(VANT_DIRECTIE.x, -0.2, VANT_DIRECTIE.y)
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
	# 6 fluturi pe lângă drum + 3 păsări departe (maxim 10)
	var culori := [Color("ff8ac2"), Color("ffd84d"), Color("7fe6ff"), Color("ffffff"), Color("c79bff"), Color("ffb36b")]
	var n := Board.CASUTE.size()
	for k in 6:
		var a: Vector3 = Board.CASUTE[(k * 4 + 2) % n]
		var b: Vector3 = Board.CASUTE[(k * 4 + 3) % n]
		var m := (a + b) * 0.5
		var spre_margine := Vector3(m.x, 0.0, m.z).normalized()
		var c := m + spre_margine * 1.3 + Vector3(0.0, 0.7, 0.0)
		var mi := MeshInstance3D.new()
		mi.mesh = _plasa_fluture(culori[k], 1.0)
		mi.material_override = _m_corp
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = c
		add_child(mi)
		_fluturi.append([mi, c, float(k) * 1.7])
	for k in 3:
		var mi := MeshInstance3D.new()
		mi.mesh = _plasa_fluture(Color("3d4a66"), 4.0)
		mi.material_override = _m_corp
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_pasari.append([mi, 20.0 + 4.0 * k, 9.0 + 2.5 * k, float(k) * 2.1])


func _plasa_fluture(c: Color, marime: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lin := c.srgb_to_linear()
	for s in [-1.0, 1.0]:
		for v in [Vector3(0.0, 0.0, 0.03), Vector3(0.11 * s, 0.0, 0.07), Vector3(0.1 * s, 0.0, -0.04),
				Vector3(0.0, 0.0, 0.03), Vector3(0.1 * s, 0.0, -0.04), Vector3(0.0, 0.0, -0.05)]:
			st.set_color(lin)
			st.set_normal(Vector3.UP)
			st.add_vertex(v * marime)
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


## textul cu cifrele din Godot (FPS, triunghiuri, apeluri de desenare, obiecte), pentru scena de test
func text_statistici() -> String:
	return "FPS %d | triunghiuri %d | draw calls %d | obiecte %d | calitate %s" % [
		Engine.get_frames_per_second(),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		["Mic", "Mediu", "Mare"][calitate]]


func _process(delta: float) -> void:
	_t += delta
	var vant := 0.0
	if calitate >= 1 and not miscare_redusa:
		vant = 1.0 + 0.35 * sin(_t * 0.37) + 0.2 * sin(_t * 1.13)
	RenderingServer.global_shader_parameter_set("vant_putere", vant)
	# estomparea are nevoie de poziția lui Orion (doar citită din scena jocului)
	if _orion == null:
		var o: Variant = get_parent().get("orion") if get_parent() else null
		if o is Node3D:
			_orion = o
	if _orion:
		RenderingServer.global_shader_parameter_set("orion_pozitie", _orion.global_position)
	if not miscare_redusa:
		if _moara:
			_moara.rotate(Info.MOARA_AX.normalized(), -delta * (0.55 + 0.35 * vant))
		if _barca:
			var ax: Vector3 = Info.BARCA_AX.normalized()
			var perp := ax.cross(Vector3.UP).normalized()
			var b := Basis(ax, 0.05 * sin(_t * 1.1)) * Basis(perp, 0.03 * sin(_t * 0.9 + 0.7))
			_barca.transform = Transform3D(b * _barca_baza.basis, _barca_baza.origin + Vector3(0.0, 0.04 * sin(_t * 1.3), 0.0))
		for nd in _nori:
			var a: float = nd[1] + _t * float(nd[4])
			(nd[0] as Node3D).position = Vector3(cos(a) * float(nd[2]), float(nd[3]), sin(a) * float(nd[2]))
		for it in _insulite:
			var m: Node3D = it[0]
			m.position.y = float(it[1]) + 0.35 * sin(_t * 0.45 + float(it[2]))
			m.rotation = Vector3(0.025 * sin(_t * 0.3 + float(it[2])), float(it[3]), 0.02 * sin(_t * 0.37 + float(it[2]) * 1.3))
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
		for pa in _pasari:
			var mi: MeshInstance3D = pa[0]
			var a := _t * 0.12 + float(pa[3])
			var p := Vector3(cos(a) * float(pa[1]), float(pa[2]) + 0.6 * sin(_t * 0.7 + float(pa[3])), sin(a) * float(pa[1]))
			var dir := p - mi.position
			mi.position = p
			if dir.length() > 0.0001:
				mi.rotation.y = atan2(dir.x, dir.z)
			mi.scale = Vector3(0.3 + 0.7 * absf(sin(_t * 4.0 + float(pa[3]))), 1.0, 1.0)
	if _stat:
		_stat.text = text_statistici()
