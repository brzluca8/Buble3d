extends Node3D
## Scena de test pentru insula 1 (rulează pe telefon, în editorul Godot: deschide test/test_insula.tscn și apasă
## „Run Current Scene”, F6). Nu atinge jocul; încarcă doar insula și pe Orion pe START.
##
## Butoane:
##   Cadru      - joc nou (D4), joc vechi, aproape (aterizare), captura 1 și 2 (unghiurile capturilor tale), mediu, panoramă
##   Mod        - normal, tablă de șah (densitatea texturii), clase (fiecare clasă o culoare), AO, normale
##   Calitate   - Mic / Mediu / Mare (reface insula)
##   Umbre, Estompare, Mișcare redusă - comutatoare
##   Aterizare  - pornește efectul de aterizare pe căsuța de sub Orion
##   DOF        - estompare ușoară a fundalului (CameraAttributesPractical); oprită implicit: măsoară FPS cu și fără
## Sus apar cifrele din Godot: FPS, triunghiuri, apeluri de desenare, obiecte, materiale unice.

const INSULA := preload("res://insula1/insula1.tscn")
const ORION_PATH := "res://assets/models/orion.glb"
const Board := preload("res://data/insula1_casute.gd")
# nume, yaw (null = în spatele lui Orion, pe direcția drumului, ca în joc), pitch, distanță, metri priviți înainte
const CADRE := [
	["joc nou (D4)", null, 0.87, 16.0, 3.0],
	["joc vechi", 0.0, 0.85, 16.0, 0.0],
	["aproape (aterizare)", null, 0.55, 6.0, 0.0],
	["captura 1", 0.0, 0.42, 12.5, 0.0],
	["captura 2", -0.95, 0.5, 7.0, 0.0],
	["mediu", 0.0, 0.85, 28.0, 0.0],
	["panoramă", 0.0, 0.92, 47.0, 0.0],
]
const MODURI := ["normal", "tablă de șah", "clase", "AO", "normale"]

var orion: Node3D  # citit de insula1.gd, pentru estompare
var insula: Node3D
var cam: Camera3D
var cadru := 0
var mod := 0
var calitate := 1
var miscare_redusa := false
var estompare := true
var umbre := true
var dof := false
var _lbl: Label
var _btn: Dictionary = {}
var _t_stat := 0.0
var _materiale := 0


func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = 40.0
	cam.far = 400.0
	add_child(cam)
	cam.make_current()
	var os_ := load(ORION_PATH) as PackedScene
	if os_:
		orion = os_.instantiate() as Node3D
		add_child(orion)
		orion.position = Board.CASUTE[0]
	calitate = 1 if OS.has_feature("mobile") else 2
	_fa_insula()
	_ui()
	_pune_camera()


func _fa_insula() -> void:
	if insula:
		insula.free()  # imediat: altfel ar fi două medii de lumină (WorldEnvironment) pentru un cadru
	insula = INSULA.instantiate() as Node3D
	insula.set("calitate", calitate)
	insula.set("mod_debug", mod)
	insula.set("miscare_redusa", miscare_redusa)
	insula.set("estompare", estompare)
	add_child(insula)
	var soare := insula.get_node_or_null("Soare") as DirectionalLight3D
	if soare and not umbre:
		soare.shadow_enabled = false
	_materiale = _numara_materiale(insula)


func _numara_materiale(n: Node) -> int:
	var set_ := {}
	for c in n.find_children("*", "GeometryInstance3D", true, false):
		var g := c as GeometryInstance3D
		if g.material_override:
			set_[g.material_override.get_instance_id()] = true
		elif g is MeshInstance3D and (g as MeshInstance3D).mesh:
			var mi := g as MeshInstance3D
			for i in mi.mesh.get_surface_count():
				var m := mi.get_active_material(i)
				if m:
					set_[m.get_instance_id()] = true
	return set_.size()


func _pune_camera() -> void:
	var c: Array = CADRE[cadru]
	var focus := Board.CASUTE[0] + Vector3(0.0, 0.7, 0.0)
	var nume := String(c[0])
	if nume == "mediu":
		focus = focus.lerp(Vector3(0.0, -1.0, 0.0), 0.45)
	elif nume == "panoramă":
		focus = Vector3(0.6, -2.4, -0.2)
	var yaw := 0.0
	if c[1] == null:
		# ca în joc (insula.gd): spre mijlocul următoarelor 6 căsuțe
		var m := Vector3.ZERO
		for j in range(1, 7):
			m += Board.CASUTE[j % Board.CASUTE.size()]
		m = m / 6.0 - Board.CASUTE[0]
		m.y = 0.0
		m = m.normalized()
		yaw = atan2(-m.x, -m.z)
	else:
		yaw = float(c[1])
	var pitch: float = c[2]
	var dist: float = c[3]
	focus += Vector3(-sin(yaw), 0.0, -cos(yaw)) * float(c[4])
	var dir := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	cam.position = focus + dir * dist
	cam.look_at(focus, Vector3.UP)


func _ui() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 30
	add_child(cl)
	_lbl = Label.new()
	_lbl.position = Vector2(10.0, 10.0)
	_lbl.add_theme_font_size_override("font_size", 22)
	_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	_lbl.add_theme_constant_override("outline_size", 6)
	cl.add_child(_lbl)
	var box := VBoxContainer.new()
	box.position = Vector2(10.0, 130.0)
	box.add_theme_constant_override("separation", 8)
	cl.add_child(box)
	for k in ["cadru", "mod", "calitate", "umbre", "estompare", "miscare", "aterizare", "dof"]:
		var b := Button.new()
		b.add_theme_font_size_override("font_size", 22)
		b.custom_minimum_size = Vector2(300.0, 56.0)
		b.pressed.connect(_apasat.bind(k))
		box.add_child(b)
		_btn[k] = b
	_texte()


func _texte() -> void:
	_btn["cadru"].text = "Cadru: " + String(CADRE[cadru][0])
	_btn["mod"].text = "Mod: " + String(MODURI[mod])
	_btn["calitate"].text = "Calitate: " + ["Mic", "Mediu", "Mare"][calitate]
	_btn["umbre"].text = "Umbre: " + ("da" if umbre else "nu")
	_btn["estompare"].text = "Estompare: " + ("da" if estompare else "nu")
	_btn["miscare"].text = "Mișcare redusă: " + ("da" if miscare_redusa else "nu")
	_btn["aterizare"].text = "Aterizare pe START"
	_btn["dof"].text = "DOF fundal: " + ("da" if dof else "nu")


func _apasat(k: String) -> void:
	match k:
		"cadru":
			cadru = (cadru + 1) % CADRE.size()
			_pune_camera()
		"mod":
			mod = (mod + 1) % MODURI.size()
			_fa_insula()
		"calitate":
			calitate = (calitate + 1) % 3
			_fa_insula()
		"umbre":
			umbre = not umbre
			_fa_insula()
		"estompare":
			estompare = not estompare
			_fa_insula()
		"miscare":
			miscare_redusa = not miscare_redusa
			_fa_insula()
		"aterizare":
			if insula and insula.has_method("on_landed"):
				insula.on_landed(0)
		"dof":
			dof = not dof
			_pune_dof()
	_texte()


## blur ușor de adâncime pentru fundal (insulițe, marea de nori), nu pentru insula din față; pe Mobile costă o
## trecere în plus pe tot ecranul, de aceea e oprit implicit: compară FPS-ul cu da/nu
func _pune_dof() -> void:
	if not dof:
		cam.attributes = null
		return
	var ca := CameraAttributesPractical.new()
	ca.dof_blur_far_enabled = true
	ca.dof_blur_far_distance = 32.0
	ca.dof_blur_far_transition = 24.0
	ca.dof_blur_amount = 0.06
	cam.attributes = ca


func _process(delta: float) -> void:
	_t_stat += delta
	if _t_stat > 0.5 and _lbl:
		_t_stat = 0.0
		_lbl.text = "FPS %d | triunghiuri %d | draw calls %d\nobiecte %d | materiale unice în insulă %d" % [
			Engine.get_frames_per_second(),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
			_materiale]
