extends Node3D
## Insula 1, versiunea 2: tot vizualul insulei, modular (teren triplanar, apă care curge, clădiri pe faze,
## vegetație instanțiată cu vânt, căsuțe, atmosferă). Logica jocului (zar, mutare, date, UI, cameră) rămâne în
## insula.gd; de aici se folosește doar on_landed(i), chemat când Orion aterizează pe căsuța i.
##
## Setări (Project Settings > buble/..., sau din inspector):
##   calitate: -1 automat (Mediu pe telefon, Mare pe calculator), 0 Mic, 1 Mediu, 2 Mare
##   miscare_redusa: oprește vântul, particulele, rotațiile și pulsațiile
##   faza_curenta: 1 natură, 2 sat, 3 castel/port/portal (clădirile au câmpul "faza" în data/props.gd)
##   arata_placeholder: inel magenta + etichetă pe clădirile care sunt încă PLACEHOLDER
##   debug_checker: textură de verificare pe teren (un pătrat = 25 cm, 512 px/m)

const Teren := preload("res://insula_v2/data/teren_info.gd")
const Props := preload("res://insula_v2/data/props.gd")
const Veg := preload("res://insula_v2/data/vegetatie.gd")
const Board := preload("res://data/insula1_casute.gd")
const Tipuri := preload("res://insula_v2/data/tipuri_casute.gd")
const TileScene := preload("res://insula_v2/Tile.tscn")
const PanglicaApa := preload("res://insula_v2/water_ribbon.gd")
const SH_TEREN := preload("res://insula_v2/shaders/teren_triplanar.gdshader")
const SH_APA := preload("res://insula_v2/shaders/water_flow.gdshader")
const SH_VEG := preload("res://insula_v2/shaders/vegetatie.gdshader")
const SH_PORTAL := preload("res://insula_v2/shaders/portal_vartej.gdshader")
const SH_CRISTAL := preload("res://insula_v2/shaders/cristal.gdshader")
const SH_CASUTA := preload("res://insula_v2/shaders/casuta.gdshader")
const MODELE := "res://assets/models/insula1_v2/"
const TEX := "res://insula_v2/textures/"
const VANT_DIRECTIE := Vector2(0.8, -0.6)
# elemente mici care nu contează când camera e departe (vedere de ansamblu): dispar după VIZIBIL_MIC metri
const MICI_DEPARTE := ["iarba", "floare_roz", "floare_galbena", "floare_alba", "nufar", "grau", "piatra_a", "piatra_b"]
const VIZIBIL_MIC := 34.0
const FARA_UMBRA := ["iarba", "floare_roz", "floare_galbena", "floare_alba", "nufar", "grau"]
const INALTIME_ETICHETA := {"castel": 7.6, "moara": 4.9, "portal": 4.3, "piata": 2.7, "atelier": 2.9,
	"debarcader": 1.3, "barca": 2.9, "pod_sus": 1.5, "pod_jos": 1.5, "copac_mare": 4.6}

@export_range(-1, 2) var calitate := -1
@export var miscare_redusa := false
@export_range(1, 3) var faza_curenta := 3
@export var arata_placeholder := true
@export var debug_checker := false

var _t := 0.0
var _soare: DirectionalLight3D
var _env: Environment
var _m_teren: ShaderMaterial
var _m_rau: ShaderMaterial
var _m_lac: ShaderMaterial
var _m_cascada: ShaderMaterial
var _m_veg: ShaderMaterial
var _m_cristal: ShaderMaterial
var _m_portal: ShaderMaterial
var _m_casuta: ShaderMaterial
var _m_corp: StandardMaterial3D
var _m_lumina: StandardMaterial3D
var _m_marcaj: StandardMaterial3D
var _props := {}
var _panze: Node3D
var _barca: Node3D
var _barca_y := 0.0
var _casute: Array = []
var _particule: Array[GPUParticles3D] = []
var _nori: Array = []
var _insulite: Array = []
var _fluturi: Array = []
var _stat: Label


func _ready() -> void:
	_citeste_setari()
	RenderingServer.global_shader_parameter_set("vant_directie", VANT_DIRECTIE)
	_materiale()
	_mediu()
	_teren()
	_apa()
	_cladiri()
	_vegetatie()
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


# --------------------------------------------------------------------------- materiale comune
func _tex(nume: String) -> Texture2D:
	return load(TEX + nume) as Texture2D


func _materiale() -> void:
	_m_teren = ShaderMaterial.new()
	_m_teren.shader = SH_TEREN
	for p in [["tex_iarba", "iarba_albedo.png"], ["tex_muschi", "muschi_albedo.png"], ["tex_stanca", "stanca_albedo.png"],
			["tex_piatra", "piatra_albedo.png"], ["tex_nisip", "nisip_albedo.png"], ["norm_stanca", "stanca_normal.png"],
			["norm_piatra", "piatra_normal.png"], ["tex_checker", "checker_1024.png"]]:
		_m_teren.set_shader_parameter(p[0], _tex(p[1]))
	_m_teren.set_shader_parameter("debug_checker", debug_checker)
	_m_teren.set_shader_parameter("normale", calitate >= 1)

	_m_rau = _mat_apa(0)
	_m_lac = _mat_apa(1)
	_m_cascada = _mat_apa(2)

	_m_veg = ShaderMaterial.new()
	_m_veg.shader = SH_VEG
	_m_veg.set_shader_parameter("vant_activ", calitate >= 1 and not miscare_redusa)

	_m_cristal = ShaderMaterial.new()
	_m_cristal.shader = SH_CRISTAL
	_m_cristal.set_shader_parameter("puls_activ", not miscare_redusa)

	_m_portal = ShaderMaterial.new()
	_m_portal.shader = SH_PORTAL
	_m_portal.set_shader_parameter("viteza", 0.25 if miscare_redusa else 1.0)

	_m_casuta = ShaderMaterial.new()
	_m_casuta.shader = SH_CASUTA
	_m_casuta.set_shader_parameter("tex_piatra", _tex("casuta_albedo.png"))
	_m_casuta.set_shader_parameter("norm_piatra", _tex("casuta_normal.png"))
	_m_casuta.set_shader_parameter("normale", calitate >= 1)

	_m_corp = StandardMaterial3D.new()
	_m_corp.vertex_color_use_as_albedo = true
	_m_corp.roughness = 0.78
	_m_corp.cull_mode = BaseMaterial3D.CULL_DISABLED

	_m_lumina = StandardMaterial3D.new()
	_m_lumina.albedo_color = Color("ffd68a")
	_m_lumina.emission_enabled = true
	_m_lumina.emission = Color("ffc861")
	_m_lumina.emission_energy_multiplier = 2.0

	_m_marcaj = StandardMaterial3D.new()
	_m_marcaj.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_m_marcaj.albedo_color = Color("ff2bd6")
	_m_marcaj.cull_mode = BaseMaterial3D.CULL_DISABLED


func _mat_apa(mod: int) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SH_APA
	m.set_shader_parameter("mod_apa", mod)
	m.set_shader_parameter("tex_normale", _tex("apa_normal.png"))
	m.set_shader_parameter("calitate_mare", calitate >= 1)
	if mod == 0:
		m.set_shader_parameter("viteza", 0.0 if miscare_redusa else 0.55)
	elif mod == 2:
		m.set_shader_parameter("viteza", 0.15 if miscare_redusa else 0.6)
	return m


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
	_env.adjustment_saturation = 1.12
	_env.adjustment_contrast = 1.05
	# ceață de distanță: insulele din fundal se pierd în aer
	_env.fog_enabled = true
	_env.fog_light_color = Color("bfe0ff")
	_env.fog_density = 0.0035
	_env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.environment = _env
	add_child(we)

	# o singură direcție de lumină, ca la Orion: cheie caldă sus-stânga-față
	_soare = DirectionalLight3D.new()
	_soare.name = "Soare"
	_soare.light_color = Color("ffe9c8")
	_soare.light_energy = 1.35
	_soare.shadow_enabled = calitate >= 1
	_soare.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	_soare.directional_shadow_max_distance = 45.0 if calitate >= 2 else 32.0
	add_child(_soare)
	_soare.look_at_from_position(Vector3(-10.0, 13.0, 10.0), Vector3.ZERO, Vector3.UP)
	# contur cyan discret din spate (fără umbre)
	var rim := DirectionalLight3D.new()
	rim.name = "ContourCyan"
	rim.light_color = Color("7fe6ff")
	rim.light_energy = 0.35
	rim.shadow_enabled = false
	add_child(rim)
	rim.look_at_from_position(Vector3(4.0, 8.0, -12.0), Vector3.ZERO, Vector3.UP)


# --------------------------------------------------------------------------- teren
func _teren() -> void:
	var sc := load(MODELE + "teren.glb") as PackedScene
	if sc == null:
		push_warning("Insula v2: lipsește teren.glb")
		return
	var t := sc.instantiate()
	t.name = "Teren"
	add_child(t)
	for n in t.find_children("*", "MeshInstance3D", true, false):
		(n as MeshInstance3D).material_override = _m_teren


# --------------------------------------------------------------------------- apă
func _apa() -> void:
	var poduri := PackedVector3Array()
	for d in Props.PROPS:
		if d["fisier"] == "pod":
			poduri.append(d["poz"])
	var rau := PanglicaApa.new()
	rau.name = "Rau"
	var c := Curve3D.new()
	for p in Teren.RAU_PUNCTE:
		c.add_point(p)
	rau.curve = c
	rau.latimi = PackedFloat32Array(Teren.RAU_LATIME)
	rau.poduri = poduri
	rau.material = _m_rau
	add_child(rau)
	rau.construieste()

	_lac("Laguna", Teren.LAGUNA_CONTUR, Teren.NIVEL_LAGUNA)
	var cerc: Array[Vector3] = []
	for i in 20:
		var a := TAU * float(i) / 20.0
		cerc.append(Teren.IAZ_DEAL + Vector3(cos(a), 0.0, sin(a)) * Teren.IAZ_DEAL_RAZA)
	_lac("IazDeal", cerc, Teren.IAZ_DEAL.y)

	for f in Teren.CASCADE:
		var jos: Vector3 = f[2]
		_cascada(f[0], f[1], jos, f[3])
		if calitate >= 1:
			var spre_nori := jos.y < -5.0
			_ceata(jos + Vector3(0.0, 0.3, 0.0), f[3], spre_nori)


# Suprafață de lac: inele spre centru; COLOR.r = adâncimea (0 la mal, 1 la mijloc), UV = metri (x, z).
func _lac(nume: String, contur: Array, nivel: float) -> void:
	var n := contur.size()
	if n < 3:
		return
	var centru := Vector3.ZERO
	for p in contur:
		centru += p
	centru /= float(n)
	var inele := [1.0, 0.8, 0.58, 0.36, 0.15]
	var poz: Array[Vector3] = []
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in inele.size():
		var f: float = inele[k]
		var adanc := pow(1.0 - f, 0.6)
		for i in n:
			var q: Vector3 = centru.lerp(contur[i], f)
			q.y = nivel
			poz.append(q)
			st.set_uv(Vector2(q.x, q.z))
			st.set_color(Color(adanc, 0.0, 0.0, 1.0))
			st.set_normal(Vector3.UP)
			st.add_vertex(q)
	var ic := poz.size()
	var cq := Vector3(centru.x, nivel, centru.z)
	poz.append(cq)
	st.set_uv(Vector2(cq.x, cq.z))
	st.set_color(Color(1.0, 0.0, 0.0, 1.0))
	st.set_normal(Vector3.UP)
	st.add_vertex(cq)
	for k in inele.size() - 1:
		for i in n:
			var a := k * n + i
			var b := k * n + (i + 1) % n
			var c := (k + 1) * n + (i + 1) % n
			var d := (k + 1) * n + i
			_tri(st, poz, a, b, c, Vector3.UP)
			_tri(st, poz, a, c, d, Vector3.UP)
	var last := (inele.size() - 1) * n
	for i in n:
		_tri(st, poz, last + i, last + (i + 1) % n, ic, Vector3.UP)
	st.generate_tangents()
	var mi := MeshInstance3D.new()
	mi.name = nume
	mi.mesh = st.commit()
	mi.material_override = _m_lac
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


# Cascadă: panglică de la buză în jos, puțin bombată în față; UV.y = metri de la buză.
# COLOR.g = 1 la buză (margine luminoasă), COLOR.b = 1 jos (spumă).
func _cascada(nume: String, sus: Vector3, jos: Vector3, latime: float) -> void:
	var fata := Vector3(jos.x - sus.x, 0.0, jos.z - sus.z)
	if fata.length() < 0.05:
		fata = Vector3(0.0, 0.0, 1.0)
	fata = fata.normalized()
	var lat := Vector3(-fata.z, 0.0, fata.x)
	var pct: Array[Vector3] = [sus - fata * 0.3 + Vector3(0.0, 0.02, 0.0)]
	var N := 16
	for i in N + 1:
		var s := float(i) / float(N)
		var p := sus.lerp(jos, s) + fata * (0.45 * sin(minf(s * 4.0, 1.0) * PI * 0.5))
		pct.append(p)
	var lung := 0.0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var poz: Array[Vector3] = []
	var total := 0.0
	for i in range(1, pct.size()):
		total += pct[i].distance_to(pct[i - 1])
	for i in pct.size():
		if i > 0:
			lung += pct[i].distance_to(pct[i - 1])
		var w := latime * (1.0 + 0.35 * lung / maxf(total, 0.01))
		var normala := fata if i > 1 else Vector3.UP
		for j in 3:
			var u := float(j) / 2.0
			var q := pct[i] + lat * (u - 0.5) * w
			poz.append(q)
			st.set_uv(Vector2(u, lung))
			st.set_color(Color(0.0, 1.0 if i <= 1 else 0.0, clampf((lung - (total - 0.9)) / 0.9, 0.0, 1.0), 1.0))
			st.set_normal(normala)
			st.add_vertex(q)
	for i in pct.size() - 1:
		for j in 2:
			var a := i * 3 + j
			_tri(st, poz, a, a + 1, a + 4, fata)
			_tri(st, poz, a, a + 4, a + 3, fata)
	st.generate_tangents()
	var mi := MeshInstance3D.new()
	mi.name = "Cascada_" + nume
	mi.mesh = st.commit()
	mi.material_override = _m_cascada
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


# Godot desenează fața din față cu vârfurile în sensul acelor de ceas: (b - a) x (c - a) opus normalei vizibile.
static func _tri(st: SurfaceTool, poz: Array[Vector3], a: int, b: int, c: int, normala: Vector3) -> void:
	var cr := (poz[b] - poz[a]).cross(poz[c] - poz[a])
	if cr.dot(normala) > 0.0:
		var tmp := b
		b = c
		c = tmp
	st.add_index(a)
	st.add_index(b)
	st.add_index(c)


func _ceata(poz: Vector3, latime: float, spre_nori: bool) -> void:
	var p := GPUParticles3D.new()
	p.name = "Ceata"
	p.amount = 22 if spre_nori else 14
	p.lifetime = 2.6
	p.preprocess = 2.0
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(latime * 0.6, 0.2, 0.5)
	pm.direction = Vector3(0.0, 1.0, 0.0)
	pm.spread = 60.0
	pm.initial_velocity_min = 0.3
	pm.initial_velocity_max = 0.9
	pm.gravity = Vector3(0.0, 0.1, 0.0)
	pm.scale_min = 0.8
	pm.scale_max = 2.2 if spre_nori else 1.4
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 1.0, 1.0, 0.0))
	g.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	g.add_point(0.25, Color(1.0, 1.0, 1.0, 0.6))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(1.4, 1.4)
	var m := StandardMaterial3D.new()
	m.albedo_texture = _tex("nor.png")
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	q.material = m
	p.draw_pass_1 = q
	p.position = poz
	p.emitting = not miscare_redusa
	add_child(p)
	_particule.append(p)


# --------------------------------------------------------------------------- clădiri (hero props), pe faze
func _cladiri() -> void:
	for d in Props.PROPS:
		var cale: String = MODELE + "props/" + String(d["fisier"]) + ".glb"
		if not ResourceLoader.exists(cale):
			push_warning("Insula v2: lipsește " + cale)
			continue
		var model := (load(cale) as PackedScene).instantiate() as Node3D
		var rad := Node3D.new()
		rad.name = String(d["id"])
		rad.position = d["poz"]
		rad.rotation.y = deg_to_rad(float(d["rot"]))
		rad.add_child(model)
		add_child(rad)
		var e_placeholder := _materiale_model(model)
		if e_placeholder and arata_placeholder:
			var l := Label3D.new()
			l.text = "PLACEHOLDER\n" + String(d["id"])
			l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			l.font_size = 56
			l.pixel_size = 0.006
			l.outline_size = 14
			l.modulate = Color("ff2bd6")
			l.position = Vector3(0.0, float(INALTIME_ETICHETA.get(String(d["id"]), 3.0)), 0.0)
			rad.add_child(l)
		rad.visible = int(d["faza"]) <= faza_curenta
		_props[String(d["id"])] = {"nod": rad, "faza": int(d["faza"])}
		if d["fisier"] == "moara":
			_panze = model.find_child("Panze", true, false) as Node3D
		if d["fisier"] == "barca":
			_barca = rad
			_barca_y = rad.position.y


# Materiale după numele pieselor (aceleași nume trebuie păstrate în modelele generate care înlocuiesc placeholder-ele).
# Întoarce true dacă modelul are marcajul de PLACEHOLDER.
func _materiale_model(model: Node) -> bool:
	var e_placeholder := false
	for n in model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var nume := String(mi.name)
		if nume.begins_with("Lumina"):
			mi.material_override = _m_lumina
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif nume.begins_with("Vartej"):
			mi.material_override = _m_portal
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif nume.begins_with("Cristal"):
			mi.material_override = _m_cristal
		elif nume.begins_with("Frunze") or nume.begins_with("Steag") or nume.begins_with("Panza"):
			mi.material_override = _m_veg
		elif nume.begins_with("Marcaj"):
			e_placeholder = true
			mi.material_override = _m_marcaj
			mi.visible = arata_placeholder
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif mi.get_active_material(0) == null or _are_culori(mi):
			mi.material_override = _m_corp
	return e_placeholder


# modelele procedurale au culori pe vârfuri; cele generate (cu texturi proprii) își păstrează materialul
func _are_culori(mi: MeshInstance3D) -> bool:
	if mi.mesh == null or mi.mesh.get_surface_count() == 0:
		return false
	var arr := mi.mesh.surface_get_arrays(0)
	return arr[Mesh.ARRAY_COLOR] != null and arr[Mesh.ARRAY_TEX_UV] == null


## Schimbă faza la rulare: clădirile noi apar cu un „pop” scurt.
func seteaza_faza(f: int) -> void:
	faza_curenta = f
	for id in _props:
		var p: Dictionary = _props[id]
		var nod: Node3D = p["nod"]
		var trebuie := int(p["faza"]) <= f
		if trebuie and not nod.visible:
			nod.visible = true
			if miscare_redusa:
				continue
			nod.scale = Vector3.ONE * 0.05
			var tw := create_tween()
			tw.tween_property(nod, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		elif not trebuie:
			nod.visible = false


# --------------------------------------------------------------------------- vegetație și elemente mici (MultiMesh)
func _vegetatie() -> void:
	for nume in Veg.INSTANTE:
		var date: Array = Veg.INSTANTE[nume]
		var cale: String = MODELE + "mici/" + String(nume) + ".glb"
		if not ResourceLoader.exists(cale):
			continue
		var n := int(date.size() / 5.0)
		var xf: Array[Transform3D] = []
		for k in n:
			var b := Basis(Vector3.UP, float(date[5 * k + 3])).scaled(Vector3.ONE * float(date[5 * k + 4]))
			xf.append(Transform3D(b, Vector3(float(date[5 * k]), float(date[5 * k + 1]), float(date[5 * k + 2]))))
		var sc := (load(cale) as PackedScene).instantiate()
		for part in sc.find_children("*", "MeshInstance3D", true, false):
			var mi := part as MeshInstance3D
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = mi.mesh
			mm.instance_count = n
			var local := mi.transform
			for k in n:
				mm.set_instance_transform(k, xf[k] * local)
			var mmi := MultiMeshInstance3D.new()
			mmi.name = String(nume) + "_" + String(mi.name)
			mmi.multimesh = mm
			var pn := String(mi.name)
			if pn.begins_with("Frunze"):
				mmi.material_override = _m_veg
			elif pn.begins_with("Lumina"):
				mmi.material_override = _m_lumina
			elif pn.begins_with("Cristal"):
				mmi.material_override = _m_cristal
			else:
				mmi.material_override = _m_corp
			if String(nume) in FARA_UMBRA or calitate == 0:
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if String(nume) in MICI_DEPARTE:
				mmi.visibility_range_end = VIZIBIL_MIC
			add_child(mmi)
		sc.queue_free()


# --------------------------------------------------------------------------- căsuțe
func _casute_joc() -> void:
	var n := Board.CASUTE.size()
	for i in n:
		var t := TileScene.instantiate() as Node3D
		t.name = "Casuta_%02d" % i
		add_child(t)
		t.position = Board.CASUTE[i]
		# gravura în romb orientată pe direcția drumului
		var urm: Vector3 = Board.CASUTE[(i + 1) % n]
		t.rotation.y = atan2(urm.x - t.position.x, urm.z - t.position.z)
		t.set("miscare_redusa", miscare_redusa)
		t.call("configureaza", Tipuri.tip(i), _m_casuta)
		_casute.append(t)


## Chemat de joc când Orion aterizează pe căsuța i: unda + aprinderea căsuței.
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
		var raza := r.randf_range(9.0, 28.0) if marea else r.randf_range(45.0, 75.0)
		var y := r.randf_range(-13.0, -7.5) if marea else r.randf_range(-2.0, 16.0)
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
	# insulițe plutitoare în fundal
	var pozitii := [[Vector3(-34.0, 3.0, -30.0), "insulita_a", 1.6], [Vector3(38.0, -2.0, -26.0), "insulita_c", 1.4],
		[Vector3(-26.0, -6.0, -52.0), "insulita_b", 2.2], [Vector3(30.0, 7.0, -58.0), "insulita_a", 2.4],
		[Vector3(-44.0, 1.0, 6.0), "insulita_b", 1.5]]
	for p in pozitii:
		var cale: String = MODELE + String(p[1]) + ".glb"
		if not ResourceLoader.exists(cale):
			continue
		var m := (load(cale) as PackedScene).instantiate() as Node3D
		m.position = p[0]
		m.scale = Vector3.ONE * float(p[2])
		add_child(m)
		_materiale_model(m)
		_insulite.append([m, (p[0] as Vector3).y, r.randf() * TAU])


# --------------------------------------------------------------------------- viață: frunze și petale, fluturi
func _viata() -> void:
	if calitate == 0 or miscare_redusa:
		return
	var p := GPUParticles3D.new()
	p.name = "FrunzeSiPetale"
	p.amount = 36
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.visibility_aabb = AABB(Vector3(-16.0, -6.0, -16.0), Vector3(32.0, 14.0, 32.0))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(11.0, 2.5, 12.0)
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
	q.size = Vector2(0.12, 0.09)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	q.material = m
	p.draw_pass_1 = q
	p.position = Vector3(0.0, 4.0, 0.0)
	add_child(p)
	_particule.append(p)
	# fluturi (6): două aripi care bat, zbor în bucle în jurul florilor
	var flori: Array = Veg.INSTANTE.get("floare_roz", [])
	var aripi := _plasa_fluture()
	var culori := [Color("ff8ac2"), Color("ffd84d"), Color("7fe6ff"), Color("ffffff"), Color("c79bff"), Color("ffb36b")]
	for k in 6:
		var c := Vector3(0.0, 0.5, 4.0)
		if flori.size() >= 5:
			var idx := (k * 37 % int(flori.size() / 5.0)) * 5
			c = Vector3(float(flori[idx]), float(flori[idx + 1]) + 0.6, float(flori[idx + 2]))
		var mi := MeshInstance3D.new()
		mi.mesh = aripi
		var fm := StandardMaterial3D.new()
		fm.albedo_color = culori[k]
		fm.emission_enabled = true
		fm.emission = culori[k]
		fm.emission_energy_multiplier = 0.25
		fm.cull_mode = BaseMaterial3D.CULL_DISABLED
		mi.material_override = fm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = c
		add_child(mi)
		_fluturi.append([mi, c, float(k) * 1.7])


func _plasa_fluture() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for s in [-1.0, 1.0]:
		for v in [Vector3(0.0, 0.0, 0.03), Vector3(0.11 * s, 0.0, 0.07), Vector3(0.1 * s, 0.0, -0.04),
				Vector3(0.0, 0.0, 0.03), Vector3(0.1 * s, 0.0, -0.04), Vector3(0.0, 0.0, -0.05)]:
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
	var vant := 0.0
	if calitate >= 1 and not miscare_redusa:
		vant = 1.0 + 0.35 * sin(_t * 0.37) + 0.2 * sin(_t * 1.13)
	RenderingServer.global_shader_parameter_set("vant_putere", vant)
	if _panze and not miscare_redusa:
		_panze.rotate_object_local(Vector3(0.0, 0.0, 1.0), delta * (0.5 + 0.5 * vant))
	if _barca and not miscare_redusa:
		_barca.position.y = _barca_y + 0.05 * sin(_t * 1.3)
		_barca.rotation.z = 0.045 * sin(_t * 1.1)
		_barca.rotation.x = 0.03 * sin(_t * 0.9 + 0.7)
	if not miscare_redusa:
		_m_lumina.emission_energy_multiplier = 1.9 + 0.22 * sin(_t * 13.0) + 0.12 * sin(_t * 7.7)
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
