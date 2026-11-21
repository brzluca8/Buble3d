extends Node3D
## Insula 1 (v4): insula trimisă de tine (din Tripo) rămâne pentru clădiri, apă și faleze; tot ce e lângă drumul
## căsuțelor (Inelul 1: solul, cărările, iarba, florile, pietrele, copacii, tufele, gardurile, felinarele, cristalele)
## e nou, procedural: terenul (teren.glb, texturi de 512 px/m) și recuzita din godot/assets/models/inel1.
## Din v3, Faza A: insula ta, îmbunătățită pentru joc, fără s-o refacem.
## Modelul e tăiat în Blender pe clase (blender/insula1/v3_faza_a.py): stânci, iarbă, frunziș, flori, pânze,
## cristale, felinare, portal, barca, palele morii, restul + apa și cascadele. Toate clasele folosesc un singur
## material (insula.gdshader); diferențele (detaliul, vântul, lumina proprie) sunt uniforme pe instanță.
## Aici: lumina și cerul, apa care curge, moara care se rotește, barca care se leagănă, halouri la felinare,
## vârtejul portalului, cele 22 de căsuțe noi (Casuta.tscn) peste discurile vechi, nori, insulițe cu cascade,
## petale, fluturi, păsări și estomparea lină (pe obiect, fără puncte) a ce ajunge între cameră și Orion.
## Logica jocului (zar, mutare, date, UI, cameră) rămâne în insula.gd; de aici se folosește doar on_landed(i).
##
## Setări (Project Settings > buble/..., sau din inspector):
##   calitate: -1 automat (Mediu pe telefon, Mare pe calculator), 0 Mic, 1 Mediu, 2 Mare
##   miscare_redusa: oprește vântul, particulele, pâlpâitul, pulsul, moara, barca, fluturii, păsările, peștii;
##                   umbrele norilor rămân, dar stau pe loc
##   mod_debug (buble/debug/mod_insula): 0 normal, 1 tablă de șah, 2 clase, 3 AO, 4 normale

const Info := preload("res://insula1/data/insula1_info.gd")
const Inel1 := preload("res://insula1/data/inel1.gd")
const Board := preload("res://data/insula1_casute.gd")
const Tipuri := preload("res://insula1/data/tipuri_casute.gd")
const CasutaScene := preload("res://insula1/casuta/Casuta.tscn")
const MODEL := "res://assets/models/insula1/insula1.glb"
const TEREN := "res://assets/models/insula1/teren.glb"
const CLADIRI_NOI := "res://assets/models/cladiri/"  # GLB-uri generate: <nume>.glb ia locul piesei Cladire_<nume>
const RECUZITA := "res://assets/models/inel1/"
const TEX_TEREN := "res://insula1/textures/teren/"
const SH_TEREN := preload("res://insula1/shaders/teren.gdshader")
const SH_RECUZITA := preload("res://insula1/shaders/recuzita.gdshader")
const SH_UNDE := preload("res://insula1/shaders/unde_apa.gdshader")
const SH_RECUZITA_ESTOMPAT := preload("res://insula1/shaders/recuzita_estompat.gdshader")
const CULORI_FLORI := [Color("ff8ac2"), Color("ffd84d"), Color("ffffff"), Color("c79bff"), Color("ff7b5c"), Color("8fd3ff")]
const FUNDAL := "res://assets/models/fundal/"
const SH_INSULA := preload("res://insula1/shaders/insula.gdshader")
const SH_INSULA_ESTOMPAT := preload("res://insula1/shaders/insula_estompat.gdshader")
const SH_APA := preload("res://insula1/shaders/water_flow.gdshader")
const SH_PORTAL := preload("res://insula1/shaders/portal_vartej.gdshader")
const SH_CASUTA := preload("res://insula1/shaders/casuta.gdshader")
const SH_HALOU := preload("res://insula1/shaders/halou.gdshader")
const SH_CER := preload("res://insula1/shaders/cer.gdshader")
const TEX := "res://insula1/textures/"
const VANT_DIRECTIE := Vector2(0.8, -0.6)
const ESTOMPARE_ALFA := 0.22  # cât de transparent devine un obiect care acoperă pe Orion
const ESTOMPARE_SECUNDE := 0.35  # cât durează trecerea (lină, fără puncte)
const ESTOMPARE_REVENIRE := 0.5  # histerezis: obiectul revine abia după atâtea secunde în care nu mai acoperă
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
var _m_insula_estompat: ShaderMaterial
var _estompabile: Array = []  # [obiect, material opac, material estompat, alfa, secunde rămase de estompare]
var _m_apa: ShaderMaterial
var _m_particule: StandardMaterial3D
var _m_corp: StandardMaterial3D
var _m_casuta: ShaderMaterial
var _m_teren: ShaderMaterial
var _m_recuzita: ShaderMaterial
var _m_recuzita_estompat: ShaderMaterial
var _plase := {}  # recuzita nouă: nume -> Mesh
var _pesti: Array = []  # [nod, punctul din apă, defazaj, unda]
var _nori_dep := Vector2.ZERO
var _moara: Node3D
var _barca: Node3D
var _barca_baza := Transform3D.IDENTITY
var _casute: Array = []
var _nori: Array = []
var _nori_mm: MultiMesh  # toți norii într-un singur apel de desenare
var _insulite: Array = []
var _fluturi: Array = []  # [instanța, centrul, faza, poziția de dinainte]
var _pasari: Array = []  # [instanța, raza, înălțimea, faza, poziția de dinainte]
var _zbor_mm: MultiMesh  # fluturii și păsările: un singur apel de desenare
var _stat: Label
var _orion: Node3D


func _ready() -> void:
	_citeste_setari()
	RenderingServer.global_shader_parameter_set("vant_directie", VANT_DIRECTIE)
	RenderingServer.global_shader_parameter_set("orion_pozitie", Board.CASUTE[0])
	# umbrele norilor (merg cu vântul; la mișcare redusă stau pe loc) și conturul cyan discret (fără a doua lumină)
	RenderingServer.global_shader_parameter_set("nori_umbra", 0.28)
	RenderingServer.global_shader_parameter_set("nori_deplasare", Vector2.ZERO)
	RenderingServer.global_shader_parameter_set("contur_cyan", Vector4(0.5, 0.9, 1.0, 0.35))
	_materiale()
	_mediu()
	_insula()
	_cladiri()
	_teren()
	_inel1()
	_ceata_cascade()
	_portal()
	_halouri()
	_casute_joc()
	_atmosfera()
	_viata()
	_viata_v4()
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
	_m_insula.set_shader_parameter("tex_stanca_t", load(TEX_TEREN + "stanca_albedo.png"))
	_m_insula.set_shader_parameter("tex_iarba_t", load(TEX_TEREN + "iarba_albedo.png"))
	_m_insula.set_shader_parameter("animat", not miscare_redusa)
	_m_insula.set_shader_parameter("vant_activ", not miscare_redusa)  # vântul de bază rămâne și la Mic
	_m_insula.set_shader_parameter("detaliu_activ", calitate >= 1)
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
	_env.fog_aerial_perspective = 0.35  # departe (insulițele), culorile se duc spre cer: aer, adâncime
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
	# valorile implicite din Godot: cu cele micșorate în v3 (0,04 / 1,2) apăreau dungi de umbră pe fețele înclinate
	_soare.shadow_bias = 0.1
	_soare.shadow_normal_bias = 2.0
	_soare.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	_soare.directional_shadow_max_distance = 45.0 if calitate >= 2 else 30.0
	add_child(_soare)
	_soare.look_at_from_position(Vector3(-14.0, 12.0, 6.0), Vector3.ZERO, Vector3.UP)
	# o singură lumină direcțională (cerința v4): conturul cyan discret de la Orion îl dau shaderele (fresnel pe partea
	# dinspre spate-dreapta, global `contur_cyan`), nu o a doua lumină


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
	# varianta estompată are aceiași parametri; o primesc pe rând doar obiectele care acoperă pe Orion
	_m_insula_estompat = ShaderMaterial.new()
	_m_insula_estompat.shader = SH_INSULA_ESTOMPAT
	for u in SH_INSULA.get_shader_uniform_list():
		var nume_u: String = u["name"]
		_m_insula_estompat.set_shader_parameter(nume_u, _m_insula.get_shader_parameter(nume_u))
	if _barca:
		estompabil(_barca as GeometryInstance3D, _m_insula, _m_insula_estompat)


## Un obiect care poate ajunge între cameră și Orion: cât îl acoperă, devine transparent lin (alfa pe instanță),
## apoi revine. Merge pentru obiecte separate (barca, copaci, tufe, felinare, clădiri ca piese), nu pentru clasele
## întinse pe toată insula.
func estompabil(g: GeometryInstance3D, opac: Material, estompat: Material) -> void:
	g.material_override = opac
	_estompabile.append([g, opac, estompat, 1.0, 0.0])


func _estompeaza(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var a := cam.global_position
	var b := (_orion.global_position if _orion else Board.CASUTE[0]) + Vector3(0.0, 0.6, 0.0)
	for e in _estompabile:
		var g: GeometryInstance3D = e[0]
		if not is_instance_valid(g):
			continue
		var acopera := false
		if estompare and g.is_visible_in_tree():
			var box: AABB = (g.global_transform * g.get_aabb()).grow(0.1)
			acopera = box.intersects_segment(a, b) != null or box.grow(0.6).has_point(a)
		e[4] = ESTOMPARE_REVENIRE if acopera else maxf(0.0, float(e[4]) - delta)
		var tinta := ESTOMPARE_ALFA if float(e[4]) > 0.0 else 1.0
		var alfa := move_toward(float(e[3]), tinta, delta * (1.0 - ESTOMPARE_ALFA) / ESTOMPARE_SECUNDE)
		e[3] = alfa
		if alfa < 0.999:
			if g.material_override != e[2]:
				g.material_override = e[2]
			g.set_instance_shader_parameter("alfa", alfa)
		elif g.material_override != e[1]:
			g.material_override = e[1]


# numele din GLB pot primi sufixe la import („Insula_iarba_001”): păstrăm doar prefixul clasei
func _clasa(nume: String) -> String:
	for k in CLASE:
		if nume.begins_with(k):
			return k
	return "Insula_restul"


# --------------------------------------------------------------------------- Inelul 2 (v4): clădirile ca piese
## Clădirile (castel, poduri, piață, moară, portal, atelier cu debarcader) sunt piese separate în insula1.glb
## (Cladire_<nume>, tăiate de blender/insula1/v4_inel1.py), deocamdată PLACEHOLDER din insula veche. Se estompează
## lin când acoperă pe Orion. Înlocuire fără cod: pune res://assets/models/cladiri/<nume>.glb (originea la bază,
## în metri, Orion = 1,15 m); scena îl așază la ancora din data/inel1.gd (CLADIRI) și ascunde piesa veche.
func _cladiri() -> void:
	var model := get_node_or_null("Insula1")
	if model == null:
		return
	for n in model.find_children("Cladire_*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var nume := String(mi.name).trim_prefix("Cladire_")
		for k in Inel1.CLADIRI:
			if nume.begins_with(String(k)):
				nume = String(k)
				break
		var cale := CLADIRI_NOI + nume + ".glb"
		if Inel1.CLADIRI.has(nume) and ResourceLoader.exists(cale):
			var sc := load(cale) as PackedScene
			if sc:
				var nou := sc.instantiate() as Node3D
				nou.name = "Nou_" + nume
				var anc: Array = Inel1.CLADIRI[nume]
				nou.position = anc[0]
				nou.rotation.y = deg_to_rad(float(Inel1.CLADIRI_ROTATIE.get(nume, 0.0)))
				add_child(nou)
				mi.visible = false
				continue
		if nume != "poduri":  # podurile sunt lungi și joase: nu le estompăm (ar dispărea fără motiv)
			estompabil(mi, _m_insula, _m_insula_estompat)


# --------------------------------------------------------------------------- Inelul 1 (v4): terenul nou
## Terenul nou de lângă drum (teren.glb, din blender/insula1/v4_inel1.py): aceeași formă ca insula veche, dar cu
## texturi tileable de 512 px/m pe triplanar, AO și umbre de contact pe vârfuri.
func _teren() -> void:
	var sc := load(TEREN) as PackedScene
	if sc == null:
		push_warning("Insula 1: lipsește " + TEREN)
		return
	_m_teren = ShaderMaterial.new()
	_m_teren.shader = SH_TEREN
	for k in ["iarba", "pavaj", "pamant", "stanca", "muschi"]:
		var f: String = "piatra" if k == "pavaj" else String(k)
		_m_teren.set_shader_parameter("tex_" + k, load(TEX_TEREN + f + "_albedo.png"))
	for k in ["iarba", "pavaj", "pamant", "stanca"]:
		var f: String = "piatra" if k == "pavaj" else String(k)
		_m_teren.set_shader_parameter("norm_" + k, load(TEX_TEREN + f + "_normal.png"))
	_m_teren.set_shader_parameter("tex_zgomot", load(TEX_TEREN + "zgomot.png"))
	_m_teren.set_shader_parameter("tex_checker", load(TEX_TEREN + "checker_1024.png"))
	_m_teren.set_shader_parameter("normale", calitate >= 1)
	_m_teren.set_shader_parameter("mod_debug", mod_debug)
	var t := sc.instantiate() as Node3D
	t.name = "Teren"
	add_child(t)
	for n in t.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		mi.material_override = _m_teren
		# terenul primește umbre, dar nu le aruncă (e dedesubtul a tot; economisim o desenare pe treaptă de umbră)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _plasa(nume: String) -> Mesh:
	if _plase.has(nume):
		return _plase[nume]
	var m: Mesh = null
	var sc := load(RECUZITA + nume + ".glb") as PackedScene
	if sc:
		var nod := sc.instantiate()
		for n in nod.find_children("*", "MeshInstance3D", true, false):
			m = (n as MeshInstance3D).mesh
			break
		nod.free()
	_plase[nume] = m
	return m


func _baza(rot: float, scara: float) -> Basis:
	return Basis(Vector3.UP, rot).scaled(Vector3.ONE * scara)


## MultiMesh pentru o piesă repetată (un singur apel de desenare); culori opțional (flori, pietricele)
func _multi(nume: String, transformari: Array, culori: Array = [], umbre := false) -> MultiMeshInstance3D:
	var plasa := _plasa(nume)
	if plasa == null or transformari.is_empty():
		return null
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not culori.is_empty()
	mm.mesh = plasa
	mm.instance_count = transformari.size()
	for i in transformari.size():
		mm.set_instance_transform(i, transformari[i])
		if mm.use_colors:
			mm.set_instance_color(i, culori[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Inel1_" + nume
	mmi.multimesh = mm
	mmi.material_override = _m_recuzita
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if umbre and calitate >= 1 else \
		GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mmi


## Recuzita nouă a Inelului 1 (godot/assets/models/inel1, din blender/insula1/v4_recuzita.py), la pozițiile din
## data/inel1.gd: copacii (separat, ca să se poată estompa lin), restul în MultiMesh-uri.
func _inel1() -> void:
	_m_recuzita = ShaderMaterial.new()
	_m_recuzita.shader = SH_RECUZITA
	_m_recuzita.set_shader_parameter("animat", not miscare_redusa)
	_m_recuzita.set_shader_parameter("vant_activ", not miscare_redusa)
	_m_recuzita_estompat = ShaderMaterial.new()
	_m_recuzita_estompat.shader = SH_RECUZITA_ESTOMPAT
	_m_recuzita_estompat.set_shader_parameter("animat", not miscare_redusa)
	_m_recuzita_estompat.set_shader_parameter("vant_activ", not miscare_redusa)
	# copacii: câte un nod, ca să se estompeze lin când ajung între cameră și Orion
	for c in Inel1.COPACI:
		var plasa := _plasa(String(c[0]))
		if plasa == null:
			continue
		var mi := MeshInstance3D.new()
		mi.name = "Copac_" + String(c[0])
		mi.mesh = plasa
		mi.transform = Transform3D(_baza(float(c[2]), float(c[3])), c[1])
		mi.set_instance_shader_parameter("vant_obiect", 1.0)
		if calitate == 0:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		estompabil(mi, _m_recuzita, _m_recuzita_estompat)
	# tufe (3 variante), felinare, cristale (3 variante), butoaie, lăzi
	var tufe := [[], [], []]
	for t in Inel1.TUFE:
		(tufe[int(t[3])] as Array).append(Transform3D(_baza(float(t[1]), float(t[2])), t[0]))
	for k in 3:
		_multi("tufa_%d" % k, tufe[k], [], true)
	# felinarele: câte un nod (fără umbră), ca să se estompeze lin când stâlpul ajunge între cameră și Orion
	var plasa_f := _plasa("felinar")
	for p in Inel1.FELINARE:
		if plasa_f == null:
			break
		var mi := MeshInstance3D.new()
		mi.name = "Felinar"
		mi.mesh = plasa_f
		mi.position = p
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_instance_shader_parameter("vant_obiect", 0.0)
		add_child(mi)
		estompabil(mi, _m_recuzita, _m_recuzita_estompat)
	var cri := [[], [], []]
	for c in Inel1.CRISTALE:
		(cri[int(c[3])] as Array).append(Transform3D(_baza(float(c[1]), float(c[2])), c[0]))
	for k in 3:
		_multi("cristal_%d" % k, cri[k])
	var but: Array = []
	for b in Inel1.BUTOAIE:
		but.append(Transform3D(_baza(float(b[1]), float(b[2])), b[0]))
	_multi("butoi", but, [], true)
	var laz: Array = []
	for b in Inel1.LAZI:
		laz.append(Transform3D(_baza(float(b[1]), float(b[2])), b[0]))
	_multi("lada", laz, [], true)
	# garduri: segmentul de 1,2 m se întinde între capete
	var gar: Array = []
	for g in Inel1.GARDURI:
		var a: Vector3 = g[0]
		var b: Vector3 = g[1]
		var d := b - a
		var lung := Vector2(d.x, d.z).length()
		# scara pe lungimea segmentului, în axa lui (nu în axa lumii: Basis.scaled ar întinde pe X-ul lumii)
		var bz := Basis(Vector3.UP, atan2(-d.z, d.x)) * Basis.from_scale(Vector3(lung / 1.2, 1.0, 1.0))
		gar.append(Transform3D(bz, Vector3(a.x, minf(a.y, b.y), a.z)))
	_multi("gard", gar, [], true)
	# presărate: smocuri de iarbă, flori (culori pe instanță), pietricele; la calitatea Mic, jumătate
	var pas := 2 if calitate == 0 else 1
	_multi("iarba_smoc", _transformari(Inel1.IARBA, pas))
	var tf := _transformari(Inel1.FLORI, pas)
	var cf: Array = []
	for i in tf.size():
		cf.append((CULORI_FLORI[i % CULORI_FLORI.size()] as Color).srgb_to_linear())
	_multi("floare", tf, cf)
	var tp := _transformari(Inel1.PIETRICELE, pas)
	var cp: Array = []
	for i in tp.size():
		var v := 0.85 + 0.3 * fposmod(sin(float(i) * 12.9898) * 43758.5453, 1.0)
		cp.append(Color(v, v * 0.98, v * 1.02))
	_multi("pietricica", tp, cp)


func _transformari(date: Array, pas: int) -> Array:
	var out: Array = []
	var i := 0
	while i + 4 < date.size():
		if (i / 5) % pas == 0:
			out.append(Transform3D(_baza(float(date[i + 3]), float(date[i + 4])),
				Vector3(float(date[i]), float(date[i + 1]), float(date[i + 2]))))
		i += 5
	return out


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
	# v4: flăcările rămase pe clădirile vechi + felinarele noi de pe stâlpi (Inelul 1)
	var flacari: Array[Vector3] = []
	flacari.append_array(Inel1.FLACARI_RAMASE)
	for p in Inel1.FELINARE:
		flacari.append((p as Vector3) + Vector3(0.0, 1.36, 0.0))
	if flacari.is_empty():
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
	mm.instance_count = flacari.size()
	for i in flacari.size():
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, flacari[i] + Vector3(0.0, 0.05, 0.0)))
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
		# căsuțele sunt discuri plate: umbra lor nu se vede, dar ar costa 22 de desenări în plus pe fiecare treaptă de umbră
		for c in t.find_children("*", "GeometryInstance3D", true, false):
			(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
	var n_nori := 24 if calitate >= 1 else 12
	# v4: un singur MultiMesh (1 apel de desenare în loc de 30); fiecare nor își mută transformarea în _process
	_nori_mm = MultiMesh.new()
	_nori_mm.transform_format = MultiMesh.TRANSFORM_3D
	_nori_mm.mesh = quad
	_nori_mm.instance_count = n_nori
	for i in n_nori:
		var marea := i < int(n_nori * 0.7)  # marea de nori de dedesubt
		var a := r.randf() * TAU
		var raza := r.randf_range(10.0, 28.0) if marea else r.randf_range(45.0, 75.0)
		var y := r.randf_range(-14.0, -9.0) if marea else r.randf_range(-2.0, 16.0)
		var s := r.randf_range(7.0, 13.0) if marea else r.randf_range(10.0, 20.0)
		var sc := Vector3(s * 1.6, s, 1.0)
		_nori_mm.set_instance_transform(i, Transform3D(Basis.from_scale(sc), Vector3(cos(a) * raza, y, sin(a) * raza)))
		_nori.append([i, a, raza, y, r.randf_range(0.004, 0.012) * (1.0 if r.randf() < 0.5 else -1.0), sc])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Nori"
	mmi.multimesh = _nori_mm
	mmi.material_override = nor_mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
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
	# la Mic rămân (sunt ieftine): petalele și frunzele (pe jumătate), fluturii și păsările; pleacă doar particulele
	# scumpe (ceața de la cascade, fumul, scânteile, stropii)
	if miscare_redusa:
		return
	var p := GPUParticles3D.new()
	p.name = "Petale"
	p.amount = 26 if calitate >= 1 else 13  # cu frunzele de mai jos: maxim 40
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
	var fr := p.duplicate() as GPUParticles3D
	fr.name = "Frunze"
	fr.amount = 12 if calitate >= 1 else 6
	var pmf := pm.duplicate() as ParticleProcessMaterial
	pmf.color = Color("8fd05a")
	pmf.scale_min = 0.9
	pmf.scale_max = 1.5
	fr.process_material = pmf
	add_child(fr)
	# 6 fluturi pe lângă drum + 3 păsări departe (maxim 10)
	var culori := [Color("ff8ac2"), Color("ffd84d"), Color("7fe6ff"), Color("ffffff"), Color("c79bff"), Color("ffb36b")]
	var n := Board.CASUTE.size()
	_zbor_mm = MultiMesh.new()
	_zbor_mm.transform_format = MultiMesh.TRANSFORM_3D
	_zbor_mm.use_colors = true
	_zbor_mm.mesh = _plasa_fluture(Color.WHITE, 1.0)  # culoarea vine pe instanță
	_zbor_mm.instance_count = 9
	for k in 6:
		var a: Vector3 = Board.CASUTE[(k * 4 + 2) % n]
		var b: Vector3 = Board.CASUTE[(k * 4 + 3) % n]
		var m := (a + b) * 0.5
		var spre_margine := Vector3(m.x, 0.0, m.z).normalized()
		var c := m + spre_margine * 1.3 + Vector3(0.0, 0.7, 0.0)
		_zbor_mm.set_instance_color(k, (culori[k] as Color).srgb_to_linear())
		_zbor_mm.set_instance_transform(k, Transform3D(Basis.IDENTITY, c))
		_fluturi.append([k, c, float(k) * 1.7, c])
	for k in 3:
		_zbor_mm.set_instance_color(6 + k, Color("3d4a66").srgb_to_linear())
		_zbor_mm.set_instance_transform(6 + k, Transform3D(Basis.from_scale(Vector3.ONE * 4.0), Vector3.ZERO))
		_pasari.append([6 + k, 20.0 + 4.0 * k, 9.0 + 2.5 * k, float(k) * 2.1, Vector3.ZERO])
	var zb := MultiMeshInstance3D.new()
	zb.name = "FluturiSiPasari"
	zb.multimesh = _zbor_mm
	zb.material_override = _m_corp
	zb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(zb)


## v4: valuri la barcă, pești care sar, fum, licurici la portal, stropi la cascade (tabelul: docs/insula_alive.md)
func _viata_v4() -> void:
	var m_unde := ShaderMaterial.new()
	m_unde.shader = SH_UNDE
	m_unde.set_shader_parameter("animat", not miscare_redusa)
	# valurile din jurul bărcii: mereu (și la Mic); barca se leagănă pe ele
	if _barca:
		var q := MeshInstance3D.new()
		q.name = "ValuriBarca"
		var pm := PlaneMesh.new()
		pm.size = Vector2(4.4, 4.4)
		q.mesh = pm
		q.material_override = m_unde
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		q.position = Info.BARCA_PIVOT + Vector3(0.0, 0.03, 0.0)
		q.set_instance_shader_parameter("putere", 0.5)
		q.set_instance_shader_parameter("gol", 0.4)
		add_child(q)
	if miscare_redusa:
		return
	# pești care sar din lagună (din când în când), cu un val la ieșire și la intrare
	for i in Inel1.PESTI.size():
		var peste := MeshInstance3D.new()
		peste.name = "Peste_%d" % i
		peste.mesh = _plasa_peste(i)
		peste.material_override = _m_corp
		peste.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		peste.visible = false
		add_child(peste)
		var u := MeshInstance3D.new()
		var pu := PlaneMesh.new()
		pu.size = Vector2(1.8, 1.8)
		u.mesh = pu
		u.material_override = m_unde
		u.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		u.position = (Inel1.PESTI[i] as Vector3) + Vector3(0.0, 0.03, 0.0)
		u.set_instance_shader_parameter("putere", 0.0)
		u.set_instance_shader_parameter("gol", 0.05)
		add_child(u)
		_pesti.append([peste, Inel1.PESTI[i], 1.7 + float(i) * 2.6, u])
	if calitate == 0:
		return  # la Mic: fără particulele scumpe (fum, scântei, stropi)
	# fum din coșul atelierului
	if Inel1.CLADIRI.has("atelier_debarcader"):
		var anc: Array = Inel1.CLADIRI["atelier_debarcader"]
		var fum := GPUParticles3D.new()
		fum.name = "Fum"
		fum.amount = 10
		fum.lifetime = 5.0
		fum.preprocess = 5.0
		var pf := ParticleProcessMaterial.new()
		pf.direction = Vector3(VANT_DIRECTIE.x * 0.4, 1.0, VANT_DIRECTIE.y * 0.4)
		pf.spread = 12.0
		pf.initial_velocity_min = 0.25
		pf.initial_velocity_max = 0.4
		pf.gravity = Vector3(VANT_DIRECTIE.x * 0.12, 0.05, VANT_DIRECTIE.y * 0.12)
		pf.scale_min = 0.5
		pf.scale_max = 0.8
		var sc := Curve.new()
		sc.add_point(Vector2(0.0, 0.45))
		sc.add_point(Vector2(1.0, 1.6))
		var sct := CurveTexture.new()
		sct.curve = sc
		pf.scale_curve = sct
		var g := Gradient.new()
		g.set_color(0, Color(0.92, 0.9, 0.95, 0.0))
		g.set_color(1, Color(0.92, 0.9, 0.95, 0.0))
		g.add_point(0.15, Color(0.95, 0.93, 0.97, 0.55))
		var gt := GradientTexture1D.new()
		gt.gradient = g
		pf.color_ramp = gt
		fum.process_material = pf
		var q := QuadMesh.new()
		q.size = Vector2(0.9, 0.9)
		q.material = _m_particule
		fum.draw_pass_1 = q
		fum.position = (anc[0] as Vector3) + Vector3(0.4, (anc[1] as Vector3).y + 0.1, -0.3)
		add_child(fum)
	# licurici și scântei: la portal și sub copacul mare
	var m_sc := StandardMaterial3D.new()
	m_sc.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m_sc.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m_sc.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m_sc.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m_sc.vertex_color_use_as_albedo = true
	var gr := GradientTexture2D.new()
	gr.fill = GradientTexture2D.FILL_RADIAL
	gr.fill_from = Vector2(0.5, 0.5)
	gr.fill_to = Vector2(1.0, 0.5)
	var gg := Gradient.new()
	gg.set_color(0, Color(1, 1, 1, 1))
	gg.set_color(1, Color(1, 1, 1, 0))
	gr.gradient = gg
	m_sc.albedo_texture = gr
	var locuri: Array = [[Info.PORTAL_CENTRU, Color("9ff7ff"), 16]]
	for c in Inel1.COPACI:
		if String(c[0]) == "copac_mare":
			locuri.append([(c[1] as Vector3) + Vector3(0.0, 1.2, 0.0), Color("f4ff8a"), 10])
	for l in locuri:
		var sp := GPUParticles3D.new()
		sp.name = "Scantei"
		sp.amount = int(l[2])
		sp.lifetime = 4.0
		sp.preprocess = 4.0
		var ps := ParticleProcessMaterial.new()
		ps.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		ps.emission_box_extents = Vector3(2.0, 0.9, 2.0)
		ps.direction = Vector3(0.0, 1.0, 0.0)
		ps.spread = 180.0
		ps.initial_velocity_min = 0.05
		ps.initial_velocity_max = 0.2
		ps.gravity = Vector3(0.0, 0.02, 0.0)
		ps.turbulence_enabled = false
		ps.scale_min = 0.6
		ps.scale_max = 1.0
		var g2 := Gradient.new()
		var c0: Color = l[1]
		g2.set_color(0, Color(c0, 0.0))
		g2.set_color(1, Color(c0, 0.0))
		g2.add_point(0.3, Color(c0, 1.0))
		g2.add_point(0.7, Color(c0, 0.8))
		var gt2 := GradientTexture1D.new()
		gt2.gradient = g2
		ps.color_ramp = gt2
		sp.process_material = ps
		var q2 := QuadMesh.new()
		q2.size = Vector2(0.09, 0.09)
		q2.material = m_sc
		sp.draw_pass_1 = q2
		sp.position = l[0]
		add_child(sp)
	# stropi la baza cascadelor care cad în apă (cele care cad în gol au deja norul de ceață)
	for c in Info.CASCADE:
		var baza: Vector3 = c[1]
		if baza.y < -4.0:
			continue
		var st := GPUParticles3D.new()
		st.name = "Stropi"
		st.amount = 14
		st.lifetime = 0.9
		var pst := ParticleProcessMaterial.new()
		pst.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pst.emission_box_extents = Vector3(float(c[2]) * 0.4, 0.05, 0.2)
		pst.direction = Vector3(0.0, 1.0, 0.0)
		pst.spread = 35.0
		pst.initial_velocity_min = 1.0
		pst.initial_velocity_max = 2.0
		pst.gravity = Vector3(0.0, -6.0, 0.0)
		pst.scale_min = 0.12
		pst.scale_max = 0.25
		pst.color = Color(1.0, 1.0, 1.0, 0.85)
		st.process_material = pst
		var q3 := QuadMesh.new()
		q3.size = Vector2(0.5, 0.5)
		q3.material = _m_particule
		st.draw_pass_1 = q3
		st.position = baza + Vector3(0.0, 0.1, 0.0)
		add_child(st)


## un pește mic (portocaliu sau argintiu), turtit, cu coadă; capul spre -Z (ca să se poată orienta cu looking_at)
func _plasa_peste(i: int) -> ArrayMesh:
	var sus := (Color("ff8a3d") if i % 2 == 0 else Color("8fc3ea")).srgb_to_linear()
	var jos := (Color("ffd9a8") if i % 2 == 0 else Color("e9f4ff")).srgb_to_linear()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nas := Vector3(0.0, 0.0, -0.13)
	var coada := Vector3(0.0, 0.0, 0.1)
	var inel := [Vector3(0.035, 0.0, 0.0), Vector3(0.0, 0.045, 0.0), Vector3(-0.035, 0.0, 0.0), Vector3(0.0, -0.04, 0.0)]
	for k in 4:
		var a: Vector3 = inel[k]
		var b: Vector3 = inel[(k + 1) % 4]
		for tri in [[nas, a, b], [coada, b, a]]:
			for v in tri:
				st.set_color(sus if (v as Vector3).y >= 0.0 else jos)
				st.add_vertex(v)
	for v in [coada, Vector3(0.0, 0.055, 0.17), Vector3(0.0, -0.05, 0.17)]:
		st.set_color(sus)
		st.add_vertex(v)
	st.generate_normals()
	return st.commit()


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


func _misca_pesti() -> void:
	for f in _pesti:
		var nod: MeshInstance3D = f[0]
		var p0: Vector3 = f[1]
		var per := 5.0 + float(f[2]) * 0.45
		var tt := _t + float(f[2])
		var t := fmod(tt, per)
		var ciclu := floorf(tt / per)
		var dur := 0.95
		var u: MeshInstance3D = f[3]
		var ang := ciclu * 2.399  # altă direcție la fiecare săritură
		var dir := Vector3(cos(ang), 0.0, sin(ang))
		if t < dur:
			var k := t / dur
			nod.visible = true
			nod.position = p0 - dir * 0.45 + dir * (0.9 * k) + Vector3(0.0, 2.2 * k * (1.0 - k), 0.0)
			var tg := (dir * 0.9 + Vector3(0.0, 2.2 * (1.0 - 2.0 * k), 0.0)).normalized()
			nod.basis = Basis.looking_at(tg, Vector3.UP)
			u.position = p0 - dir * 0.45 + Vector3(0.0, 0.03, 0.0)
			u.set_instance_shader_parameter("progres_fix", t * 0.9)
		else:
			nod.visible = false
			u.position = p0 + dir * 0.45 + Vector3(0.0, 0.03, 0.0)
			u.set_instance_shader_parameter("progres_fix", (t - dur) * 0.9)
		u.set_instance_shader_parameter("putere", 0.8 if (t < dur or t - dur < 1.6) else 0.0)


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
	# Aliseron: vânt constant + rafale periodice (două ritmuri care se suprapun rar); la Mic, vântul de bază
	var vant := 0.0
	if not miscare_redusa:
		if calitate == 0:
			vant = 0.85 + 0.15 * sin(_t * 0.5)
		else:
			var rafala := pow(maxf(0.0, sin(_t * 0.62)), 6.0) * 0.9 + pow(maxf(0.0, sin(_t * 0.41 + 1.7)), 8.0) * 0.6
			vant = 0.8 + 0.12 * sin(_t * 1.13) + rafala
		_nori_dep += VANT_DIRECTIE * delta * (0.9 + 0.5 * vant)
		RenderingServer.global_shader_parameter_set("nori_deplasare", _nori_dep)
	RenderingServer.global_shader_parameter_set("vant_putere", vant)
	_misca_pesti()
	# estomparea are nevoie de poziția lui Orion (doar citită din scena jocului)
	if _orion == null:
		var o: Variant = get_parent().get("orion") if get_parent() else null
		if o is Node3D:
			_orion = o
	if _orion:
		RenderingServer.global_shader_parameter_set("orion_pozitie", _orion.global_position)
	_estompeaza(delta)
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
			_nori_mm.set_instance_transform(int(nd[0]), Transform3D(Basis.from_scale(nd[5]),
				Vector3(cos(a) * float(nd[2]), float(nd[3]), sin(a) * float(nd[2]))))
		for it in _insulite:
			var m: Node3D = it[0]
			m.position.y = float(it[1]) + 0.35 * sin(_t * 0.45 + float(it[2]))
			m.rotation = Vector3(0.025 * sin(_t * 0.3 + float(it[2])), float(it[3]), 0.02 * sin(_t * 0.37 + float(it[2]) * 1.3))
		for f in _fluturi:
			var c: Vector3 = f[1]
			var ph: float = f[2]
			var tt := _t * 0.6 + ph
			var p := c + Vector3(sin(tt) * 0.9, 0.25 * sin(tt * 2.3), sin(tt * 2.0) * 0.6)
			var dir := p - (f[3] as Vector3)
			f[3] = p
			var ry := atan2(dir.x, dir.z) if dir.length() > 0.0001 else 0.0
			var bz := Basis(Vector3.UP, ry) * Basis.from_scale(Vector3(0.25 + 0.75 * absf(sin(_t * 14.0 + ph)), 1.0, 1.0))
			_zbor_mm.set_instance_transform(int(f[0]), Transform3D(bz, p))
		for pa in _pasari:
			var a := _t * 0.12 + float(pa[3])
			var p := Vector3(cos(a) * float(pa[1]), float(pa[2]) + 0.6 * sin(_t * 0.7 + float(pa[3])), sin(a) * float(pa[1]))
			var dir := p - (pa[4] as Vector3)
			pa[4] = p
			var ry := atan2(dir.x, dir.z) if dir.length() > 0.0001 else 0.0
			var bz := Basis(Vector3.UP, ry) * Basis.from_scale(Vector3(4.0 * (0.3 + 0.7 * absf(sin(_t * 4.0 + float(pa[3])))), 4.0, 4.0))
			_zbor_mm.set_instance_transform(int(pa[0]), Transform3D(bz, p))
	if _stat:
		_stat.text = text_statistici()
