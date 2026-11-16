extends Node3D
## Pagina separată a rotirilor: mașina de bule (catifea violet, alamă, dom de sticlă) în interiorul
## unui glob de sticlă la amurg, cu orașul estompat în spate. Rezultatul vine din Game.spin()
## (data/spin_table.json); scena doar îl prezintă:
##   maneta (trasă cu butonul sau cu degetul) → rolele cu blur de mișcare → oprire pe rând cu recul
##   → anticipare dacă primele două se potrivesc → câștig pe niveluri (mic / mare / uriaș) sau
##   intrarea specifică pentru atac, raid, cufăr, scut, energie, carte.
## Becurile aleargă în repaus, clipesc la rotire, ard toate la câștig. Cristalul din dom se încarcă.
## Mascota urmărește rolele, își ține respirația, se bucură sau ridică din umeri.
## Atacul și raidul se joacă în glob: interfața pune Game.pending_action și schimbă scena.

signal spun(res: Dictionary)

const WZ := 2.05                                 # centrul ferestrei rolelor
const REEL_R := 0.6
const REEL_X := [-0.86, 0.0, 0.86]
const REEL_Z := 0.02
const BUBBLE_R := 0.225
const LEVER_PIVOT := Vector3(1.98, 1.72, 0.3)
## Culoarea de bază a fiecărui simbol (pentru blur și lumini).
const SYM_COL := {
	"coin": Color("ffc93c"), "bag": Color("e0a050"), "gem": Color("7ff6ff"), "energy": Color("9dff5a"),
	"shield": Color("6f8cff"), "hammer": Color("ff6a5a"), "shovel": Color("b48aff"), "chest": Color("d08a40"),
	"card": Color("ff8fc8"),
}
## Încărcarea cristalului din dom păstrată între vizite (doar prezentare).
static var charge := 0.0

var syms: Array = []
var step := 0.0
var reels: Array[Node3D] = []
var sym_nodes := []                              # [rolă][index simbol] = [obiect, bulă, suport]
var sym_mesh := {}                               # simbol -> ArrayMesh (folosit și pentru intrările mari)
var blur_quads: Array[MeshInstance3D] = []
var _prev_rot := [0.0, 0.0, 0.0]
var busy := false
var auto := false
var lever: Node3D
var lever_ball: MeshInstance3D
var gears: Array[Node3D] = []
var lamps: Array[OmniLight3D] = []
var crystal_mat: BaseMaterial3D
var crystal_light: OmniLight3D
var bulbs: MultiMeshInstance3D
var bulb_mode := "idle"
var _mode_t := 0.0
var coins_fx: CPUParticles3D
var coin_rain: CPUParticles3D
var bubble_burst: CPUParticles3D
var dust: CPUParticles3D
var rays: MeshInstance3D
var majordom: Node3D
var _anim: AnimationPlayer
var _mascot_rest := Transform3D.IDENTITY
var cam: Camera3D
var cam_base := Vector3.ZERO
var cam_look := Vector3.ZERO
var env: Environment
var hud: CanvasLayer
var t := 0.0
var _tick := 0
var _gear_speed := 0.3
var _drag := {"on": false, "y0": 0.0, "pull": 0.0}
var _lever_by_hand := false


func _ready() -> void:
	syms = Game.D.spin_table.symbols
	step = TAU / syms.size()
	_environment()
	rays = Backdrop.build(self)
	_floor()
	_machine()
	_symbols()
	_reels()
	_payline()
	_bulbs()
	_lever()
	_majordom()
	_effects()
	cam = Camera3D.new()
	# lățimea fixă: pe telefoanele mai înalte se vede mai mult sus/jos, nu se taie maneta
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	add_child(cam)
	_place_camera()
	hud = preload("res://scripts/ui/mechanism_ui.gd").new()
	add_child(hud)
	Game.quality_changed.connect(func(_q): _apply_quality())
	_apply_quality()
	_set_charge(charge)


# ---------------- mediu: amurg în glob, lumini ----------------
func _environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("1e1450")
	sky_mat.sky_horizon_color = Color("c8689a")
	sky_mat.ground_horizon_color = Color("e88a8a")
	sky_mat.ground_bottom_color = Color("1a1040")
	sky_mat.sky_curve = 0.12
	sky_mat.sun_angle_max = 0.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b8a0e8")
	env.ambient_light_energy = 0.3
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 5.0
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_strength = 1.05
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.fog_enabled = true
	env.fog_light_color = Color("6a3a7a")
	env.fog_density = 0.012
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.15
	env.adjustment_contrast = 1.08
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	# lumină caldă de sus (cu umbre moi), contur violet și turcoaz din spate
	var key := SpotLight3D.new()
	key.light_color = Color("ffe0b0")
	key.light_energy = 5.0
	key.spot_range = 20.0
	key.spot_angle = 34.0
	key.spot_attenuation = 0.5
	key.shadow_enabled = true
	key.shadow_blur = 2.5
	key.name = "Cheie"
	add_child(key)
	key.look_at_from_position(Vector3(-1.2, 9.0, 5.5), Vector3(0, 1.8, 0))
	for it in [[Vector3(-6, 5, -6), Color("a050ff"), 1.4], [Vector3(6, 4, -6), Color("38e0e0"), 1.2]]:
		var d := DirectionalLight3D.new()
		d.light_color = it[1]
		d.light_energy = it[2]
		add_child(d)
		d.look_at_from_position(it[0], Vector3(0, 2, 0))
	var fill := DirectionalLight3D.new()
	fill.light_color = Color("ffc8e0")
	fill.light_energy = 0.35
	add_child(fill)
	fill.look_at_from_position(Vector3(4, 2, 8), Vector3(0, 2, 0))


## Podea lucioasă sub aparat (reflexii din sondă), cu inel de alamă și o pată caldă de lumină.
func _floor() -> void:
	var fl := MeshInstance3D.new()
	fl.mesh = _cyl(7.0, 7.0, 0.1, 64)
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color("241650")
	fm.roughness = 0.06
	fm.metallic = 0.25
	fm.metallic_specular = 1.0
	fl.material_override = fm
	fl.position = Vector3(0, -0.05, 0.6)
	add_child(fl)
	Proc.add(self, Proc.htor(3.0, 0.04, 96, 8), Proc.mat(Color("e9b54a"), {"metal": 0.9, "rough": 0.2}), Vector3(0, 0.0, 0.5))
	var glow := MeshInstance3D.new()
	var gq := QuadMesh.new()
	gq.size = Vector2(6.5, 4.0)
	glow.mesh = gq
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	gm.albedo_texture = Proc.tex("soft")
	gm.albedo_color = Color(1.0, 0.7, 0.4, 0.28)
	glow.material_override = gm
	glow.rotation.x = -PI / 2
	glow.position = Vector3(0, 0.01, 1.2)
	add_child(glow)
	var probe := ReflectionProbe.new()
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	probe.size = Vector3(14, 9, 14)
	probe.position = Vector3(0, 2.5, 2.0)
	probe.box_projection = true
	probe.intensity = 0.9
	probe.max_distance = 30.0
	add_child(probe)


# ---------------- aparatul ----------------
func _machine() -> void:
	var m := Models.instance("mecanism")
	if m == null:
		m = Node3D.new()
		Proc.add(m, Proc.box(3.4, 3.4, 1.6), Proc.mat(Color("4a2a8e"), {"rough": 0.8}), Vector3(0, 1.9, -0.1))
		Proc.add(m, Proc.box(2.76, 1.6, 0.1), Proc.M("gold"), Vector3(0, WZ, -0.7))
	add_child(m)
	# maneta din model rămâne ascunsă: o înlocuiește maneta aurie animată (vezi _lever)
	var old := m.find_child("Maneta", true, false) as Node3D
	if old:
		old.visible = false
	for i in 3:
		var g := m.find_child("Roata%d" % i, true, false) as Node3D
		if g:
			gears.append(g)
	# cristalul din dom: material propriu, ca să se încarce
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var m3 := mi as MeshInstance3D
		for i in m3.mesh.get_surface_count():
			var mat := m3.mesh.surface_get_material(i)
			if mat and mat.resource_name.get_slice(".", 0) == "CristalJackpot":
				crystal_mat = (mat as BaseMaterial3D).duplicate() as BaseMaterial3D
				crystal_mat.emission_enabled = true
				m3.set_surface_override_material(i, crystal_mat)
	crystal_light = OmniLight3D.new()
	crystal_light.light_color = Color("ff8fd0")
	crystal_light.omni_range = 2.6
	crystal_light.position = Vector3(0, 3.85, 0.3)
	add_child(crystal_light)
	var win := OmniLight3D.new()
	win.light_color = Color("c8a0ff")
	win.light_energy = 0.9
	win.omni_range = 2.4
	win.position = Vector3(0, WZ + 0.3, 1.5)
	add_child(win)
	lamps.append(win)
	var tray := OmniLight3D.new()
	tray.light_color = Color("ffc56a")
	tray.light_energy = 0.8
	tray.omni_range = 2.2
	tray.position = Vector3(0, 0.95, 1.5)
	add_child(tray)
	lamps.append(tray)


# ---------------- simbolurile 3D ----------------
## Fiecare simbol e o singură plasă cu culori pe vârfuri (un apel de desenare), plus bula.
func _symbols() -> void:
	var gold := Color("ffc93c")
	var gold_m := Color(gold.r, gold.g, gold.b, 0.5)
	var dkgold := Color(0.85, 0.6, 0.15, 0.5)
	var steel := Color(0.82, 0.85, 0.92, 0.5)
	var wood := Color("8a5a30")
	var face := Basis(Vector3.RIGHT, PI / 2)       # cilindru cu fața spre cameră
	sym_mesh.coin = _merge([
		[_cyl(0.125, 0.125, 0.04, 28), Transform3D(face.rotated(Vector3.UP, 0.35), Vector3.ZERO), gold_m],
		[_cyl(0.088, 0.088, 0.05, 24), Transform3D(face.rotated(Vector3.UP, 0.35), Vector3(0, 0, 0.004)), dkgold],
		[_box(0.03, 0.09, 0.06), Transform3D(Basis(Vector3.UP, 0.35), Vector3(0.006, 0, 0.02)), gold_m],
	])
	sym_mesh.bag = _merge([
		[_sph(0.115), Transform3D(Basis().scaled(Vector3(1.0, 0.95, 0.85)), Vector3(0, -0.035, 0)), Color("c8873a")],
		[_cyl(0.04, 0.05, 0.06, 14), Transform3D(Basis(), Vector3(0, 0.07, 0)), Color("b07432")],
		[_cyl(0.075, 0.04, 0.05, 14), Transform3D(Basis(), Vector3(0, 0.115, 0)), Color("c8873a")],
		[_tor(0.045, 0.062), Transform3D(Basis(), Vector3(0, 0.07, 0)), gold_m],
		[_cyl(0.045, 0.045, 0.014, 16), Transform3D(face, Vector3(0.0, -0.04, 0.1)), gold_m],
	])
	sym_mesh.gem = _merge([
		[_cyl(0.13, 0.0, 0.13, 8), Transform3D(Basis(Vector3.UP, 0.2), Vector3(0, -0.04, 0)), Color("7ff6ff")],
		[_cyl(0.08, 0.13, 0.05, 8), Transform3D(Basis(Vector3.UP, 0.2), Vector3(0, 0.05, 0)), Color("b8fbff")],
	])
	var bolt := Color("b8ff5a")
	sym_mesh.energy = _merge([
		[_box(0.06, 0.15, 0.05), Transform3D(Basis(Vector3.BACK, -0.45), Vector3(0.035, 0.065, 0)), bolt],
		[_box(0.13, 0.045, 0.05), Transform3D(Basis(), Vector3.ZERO), bolt],
		[_box(0.06, 0.15, 0.05), Transform3D(Basis(Vector3.BACK, -0.45), Vector3(-0.035, -0.065, 0)), bolt],
		[_cyl(0.0, 0.04, 0.06, 4), Transform3D(Basis(Vector3.BACK, 2.7), Vector3(-0.07, -0.135, 0)), bolt],
	])
	sym_mesh.shield = _merge([
		[_sph(0.13), Transform3D(Basis().scaled(Vector3(0.95, 1.12, 0.35)), Vector3.ZERO), Color("5a7cff")],
		[_tor(0.118, 0.138), Transform3D(Basis().scaled(Vector3(0.95, 1.12, 1.0)) * face, Vector3.ZERO), gold_m],
		[_sph(0.035), Transform3D(Basis(), Vector3(0, 0.0, 0.045)), gold_m],
		[_box(0.02, 0.17, 0.02), Transform3D(Basis(), Vector3(0, 0, 0.038)), Color(0.85, 0.9, 1.0, 0.5)],
	])
	sym_mesh.hammer = _merge([
		[_cyl(0.022, 0.022, 0.27, 10), Transform3D(Basis(Vector3.BACK, 0.6), Vector3(0.02, -0.03, 0)), wood],
		[_box(0.2, 0.075, 0.085), Transform3D(Basis(Vector3.BACK, 0.6), Vector3(-0.055, 0.085, 0)), steel],
	])
	sym_mesh.shovel = _merge([
		[_cyl(0.02, 0.02, 0.2, 10), Transform3D(Basis(Vector3.BACK, -0.5), Vector3(-0.03, 0.05, 0)), wood],
		[_box(0.08, 0.026, 0.026), Transform3D(Basis(Vector3.BACK, -0.5), Vector3(-0.08, 0.14, 0)), wood],
		[_sph(0.08), Transform3D(Basis(Vector3.BACK, -0.5) * Basis().scaled(Vector3(0.9, 1.3, 0.25)), Vector3(0.05, -0.08, 0)), steel],
	])
	sym_mesh.chest = _merge([
		[_box(0.22, 0.12, 0.14), Transform3D(Basis(), Vector3(0, -0.035, 0)), Color("9a5a2a")],
		[_cyl(0.07, 0.07, 0.22, 16), Transform3D(Basis(Vector3.BACK, PI / 2), Vector3(0, 0.025, 0)), Color("b8743a")],
		[_box(0.026, 0.2, 0.155), Transform3D(Basis(), Vector3(-0.07, 0.0, 0)), gold_m],
		[_box(0.026, 0.2, 0.155), Transform3D(Basis(), Vector3(0.07, 0.0, 0)), gold_m],
		[_box(0.045, 0.05, 0.02), Transform3D(Basis(), Vector3(0, -0.005, 0.075)), gold_m],
	])
	sym_mesh.card = _merge([
		[_box(0.13, 0.18, 0.008), Transform3D(Basis(Vector3.BACK, 0.3), Vector3(-0.03, 0.0, -0.02)), Color("ff8fc0")],
		[_box(0.13, 0.18, 0.008), Transform3D(Basis(Vector3.BACK, -0.25), Vector3(0.03, 0.0, -0.01)), Color("c890ff")],
		[_box(0.13, 0.18, 0.01), Transform3D(Basis(), Vector3(0, 0, 0.01)), Color("fff4f8")],
		[_cyl(0.045, 0.045, 0.012, 4), Transform3D(face, Vector3(0, 0, 0.02)), gold_m],
	])


func _cyl(top: float, bottom: float, h: float, seg := 16) -> PrimitiveMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return c


func _box(x: float, y: float, z: float) -> PrimitiveMesh:
	var b := BoxMesh.new()
	b.size = Vector3(x, y, z)
	return b


func _sph(r: float) -> PrimitiveMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 18
	s.rings = 9
	return s


func _tor(inner: float, outer: float) -> PrimitiveMesh:
	var tm := TorusMesh.new()
	tm.inner_radius = inner
	tm.outer_radius = outer
	tm.rings = 24
	tm.ring_segments = 6
	return tm


## Unește piese [plasă, transformare, culoare] într-o singură plasă cu culori pe vârfuri.
func _merge(parts: Array) -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for p in parts:
		var arr: Array = (p[0] as PrimitiveMesh).get_mesh_arrays()
		var xf: Transform3D = p[1]
		var nb := xf.basis.inverse().transposed()
		var base := verts.size()
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		for i in v.size():
			verts.append(xf * v[i])
			norms.append((nb * n[i]).normalized())
			cols.append(p[2])
		var ii: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		for j in ii:
			idx.append(base + j)
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = verts
	a[Mesh.ARRAY_NORMAL] = norms
	a[Mesh.ARRAY_COLOR] = cols
	a[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	return m


# ---------------- rolele ----------------
func _reels() -> void:
	var drum_mat := StandardMaterial3D.new()
	drum_mat.albedo_color = Color("2a1866")
	drum_mat.roughness = 0.35
	drum_mat.metallic = 0.2
	drum_mat.emission_enabled = true
	drum_mat.emission = Color("2a1060")
	drum_mat.emission_energy_multiplier = 0.4
	var rim_mat := Proc.mat(Color("e9b54a"), {"metal": 0.9, "rough": 0.22})
	var drum := _cyl(REEL_R - 0.05, REEL_R - 0.05, 0.78, 48)
	var rim := _cyl(REEL_R + 0.01, REEL_R + 0.01, 0.025, 48)
	var bubble := SphereMesh.new()
	bubble.radius = BUBBLE_R
	bubble.height = BUBBLE_R * 2.0
	bubble.radial_segments = 24
	bubble.rings = 12
	var bubble_mat := ShaderMaterial.new()
	bubble_mat.shader = preload("res://shaders/symbol_bubble.gdshader")
	bubble_mat.render_priority = 1
	var obj_mat := ShaderMaterial.new()
	obj_mat.shader = preload("res://shaders/symbol_obj.gdshader")
	var blur_mat := ShaderMaterial.new()
	blur_mat.shader = preload("res://shaders/reel_blur.gdshader")
	blur_mat.set_shader_parameter("strip", _blur_strip())
	blur_mat.render_priority = 2
	var bq := QuadMesh.new()
	bq.size = Vector2(0.8, 1.44)
	for i in 3:
		var reel := Node3D.new()
		reel.name = "Rola%d" % i
		reel.position = Vector3(REEL_X[i], WZ, REEL_Z)
		add_child(reel)
		var d := MeshInstance3D.new()
		d.mesh = drum
		d.material_override = drum_mat
		d.rotation.z = PI / 2
		reel.add_child(d)
		for sx in [-0.4, 0.4]:
			var r := MeshInstance3D.new()
			r.mesh = rim
			r.material_override = rim_mat
			r.rotation.z = PI / 2
			r.position.x = sx
			reel.add_child(r)
		var row := []
		for k in syms.size():
			var sid: String = syms[k]
			var pivot := Node3D.new()
			pivot.rotation.x = -k * step
			reel.add_child(pivot)
			var holder := Node3D.new()
			holder.position.z = REEL_R + 0.02
			pivot.add_child(holder)
			var ob := MeshInstance3D.new()
			ob.mesh = sym_mesh[sid]
			ob.scale = Vector3.ONE * 1.4          # obiectul umple bula
			ob.material_override = obj_mat
			ob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			holder.add_child(ob)
			var bb := MeshInstance3D.new()
			bb.mesh = bubble
			bb.material_override = bubble_mat
			bb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			holder.add_child(bb)
			row.append([ob, bb, holder])
		sym_nodes.append(row)
		reel.rotation.x = randi_range(0, syms.size() - 1) * step
		_prev_rot[i] = reel.rotation.x
		reels.append(reel)
		var bl := MeshInstance3D.new()
		bl.mesh = bq
		bl.material_override = blur_mat
		bl.position = Vector3(REEL_X[i], WZ, REEL_Z + REEL_R + 0.26)
		bl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bl.set_instance_shader_parameter("amount", 0.0)
		add_child(bl)
		blur_quads.append(bl)


## Banda pentru blur: culorile simbolurilor, întinse și estompate vertical, pe fond indigo.
func _blur_strip() -> Texture2D:
	var w := 16
	var cell := 32
	var h := cell * syms.size()
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var bg := Color("2a1866")
	for y in h:
		var k := y / cell
		var c: Color = SYM_COL[syms[syms.size() - 1 - k]]
		var dy := absf((y % cell) - cell / 2.0) / (cell / 2.0)
		for x in w:
			var dx := absf(x - w / 2.0 + 0.5) / (w / 2.0)
			var a := exp(-dy * dy * 2.2) * (1.0 - dx * dx * 0.8)
			img.set_pixel(x, y, bg.lerp(c, clampf(a, 0.0, 1.0)))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Linia de câștig: o bandă aurie luminoasă pe rândul din mijloc (două filete + umplere caldă).
func _payline() -> void:
	var gold := Proc.mat(Color(1.0, 0.82, 0.35), {"unshaded": true})
	gold.albedo_color = Color(2.8, 2.1, 0.8)
	for dy in [-0.27, 0.27]:
		var line := MeshInstance3D.new()
		line.mesh = _box(2.62, 0.03, 0.01)
		line.material_override = gold
		line.position = Vector3(0, WZ + dy, REEL_Z + REEL_R + 0.3)
		line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(line)
	var band := MeshInstance3D.new()
	var bq := QuadMesh.new()
	bq.size = Vector2(2.62, 0.54)
	band.mesh = bq
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	bm.albedo_color = Color(1.0, 0.72, 0.25, 0.13)
	bm.render_priority = 3
	band.material_override = bm
	band.position = Vector3(0, WZ, REEL_Z + REEL_R + 0.29)
	band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(band)
	var halo := MeshInstance3D.new()
	var hq := QuadMesh.new()
	hq.size = Vector2(3.1, 0.9)
	halo.mesh = hq
	var hm := StandardMaterial3D.new()
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	hm.albedo_texture = Proc.tex("soft")
	hm.albedo_color = Color(1.0, 0.75, 0.3, 0.16)
	hm.render_priority = 3
	halo.material_override = hm
	halo.position = Vector3(0, WZ, REEL_Z + REEL_R + 0.28)
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(halo)


# ---------------- becurile ----------------
func _bulbs() -> void:
	var pts := []
	for i in 13:
		pts.append(Vector3(-1.3 + i * (2.6 / 12.0), WZ + 0.86, 0.85))           # sus, stânga → dreapta
	for i in range(5, 0, -1):
		pts.append(Vector3(1.44, WZ - 0.72 + i * 0.24, 0.85))                 # dreapta, sus → jos
	for i in range(12, -1, -1):
		pts.append(Vector3(-1.3 + i * (2.6 / 12.0), WZ - 0.86, 0.85))         # jos, dreapta → stânga
	for i in range(1, 6):
		pts.append(Vector3(-1.44, WZ - 0.72 + i * 0.24, 0.85))                # stânga, jos → sus
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	var s := SphereMesh.new()
	s.radius = 0.056
	s.height = 0.112
	s.radial_segments = 10
	s.rings = 5
	mm.mesh = s
	mm.instance_count = pts.size()
	for i in pts.size():
		mm.set_instance_transform(i, Transform3D(Basis(), pts[i]))
		mm.set_instance_color(i, Color(1.0, 0.82, 0.5))
		mm.set_instance_custom_data(i, Color(0.3, 0, 0, 0))
	bulbs = MultiMeshInstance3D.new()
	bulbs.multimesh = mm
	var bm := ShaderMaterial.new()
	bm.shader = preload("res://shaders/bulbs.gdshader")
	bulbs.material_override = bm
	bulbs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bulbs)


func _update_bulbs() -> void:
	var mm := bulbs.multimesh
	var n := mm.instance_count
	var mt := t - _mode_t
	for i in n:
		var b := 0.25
		var c := Color(1.0, 0.72, 0.28)
		match bulb_mode:
			"idle":
				var head := fposmod(t * 9.0, float(n))
				var d := fposmod(head - i, float(n))
				b = 0.4 + 1.0 * clampf(1.0 - d / 5.0, 0.0, 1.0)
			"spin":
				b = 1.0 if (i + int(t * 16.0)) % 2 == 0 else 0.12
			"anticip":
				b = 0.35 + 0.75 * (0.5 + 0.5 * sin(t * 18.0))
				c = Color(1.0, 0.55, 0.75)
			"win":
				b = 1.1 + 0.25 * sin(t * 12.0 + i * 0.6)
				c = Color.from_hsv(fposmod(i / float(n) + mt * 0.6, 1.0), 0.45, 1.0)
		mm.set_instance_color(i, c)
		mm.set_instance_custom_data(i, Color(b, 0, 0, 0))


func set_bulbs(mode: String) -> void:
	bulb_mode = mode
	_mode_t = t


# ---------------- maneta aurie cu bilă violetă ----------------
func _lever() -> void:
	lever = Node3D.new()
	lever.name = "ManetaNoua"
	lever.position = LEVER_PIVOT
	add_child(lever)
	var gold := Proc.mat(Color("f2c04a"), {"metal": 0.95, "rough": 0.18})
	var hub := MeshInstance3D.new()
	hub.mesh = _cyl(0.13, 0.13, 0.12, 24)
	hub.material_override = gold
	hub.rotation.z = PI / 2
	lever.add_child(hub)
	var rod := MeshInstance3D.new()
	rod.mesh = _cyl(0.04, 0.05, 1.05, 14)
	rod.material_override = gold
	rod.position = Vector3(0.03, 0.55, 0)
	lever.add_child(rod)
	var collar := MeshInstance3D.new()
	collar.mesh = _tor(0.05, 0.075)
	collar.material_override = gold
	collar.position = Vector3(0.03, 1.02, 0)
	lever.add_child(collar)
	var ball_mat := StandardMaterial3D.new()
	ball_mat.albedo_color = Color("7a3cff")
	ball_mat.metallic = 0.3
	ball_mat.roughness = 0.12
	ball_mat.clearcoat_enabled = true
	ball_mat.clearcoat = 1.0
	ball_mat.clearcoat_roughness = 0.05
	ball_mat.emission_enabled = true
	ball_mat.emission = Color("5a20d0")
	ball_mat.emission_energy_multiplier = 0.5
	lever_ball = MeshInstance3D.new()
	lever_ball.mesh = _sph(0.17)
	lever_ball.material_override = ball_mat
	lever_ball.position = Vector3(0.03, 1.2, 0)
	lever.add_child(lever_ball)
	var hl := MeshInstance3D.new()
	var hq := QuadMesh.new()
	hq.size = Vector2(0.12, 0.08)
	hl.mesh = hq
	var hm := StandardMaterial3D.new()
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	hm.albedo_texture = Proc.tex("soft")
	hm.albedo_color = Color(1, 1, 1, 0.85)
	hm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	hl.material_override = hm
	hl.position = Vector3(-0.05, 0.07, 0.12)
	lever_ball.add_child(hl)


## Trasul manetei: animat la fiecare rotire (dacă n-a tras-o deja jucătorul cu degetul).
func _pull_lever() -> void:
	Sfx.play("lever")
	Sfx.buzz(15)
	var tw := create_tween()
	if not _lever_by_hand:
		tw.tween_property(lever, "rotation:x", 1.15, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(lever, "rotation:x", 0.0, 0.55).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_lever_by_hand = false


func _unhandled_input(e: InputEvent) -> void:
	if cam == null or busy:
		return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			var sp := cam.unproject_position(lever_ball.global_position)
			if e.position.distance_to(sp) < 90.0:
				_drag.on = true
				_drag.y0 = e.position.y
				_drag.pull = 0.0
				get_viewport().set_input_as_handled()
		elif _drag.on:
			_drag.on = false
			if _drag.pull > 0.55 and hud:
				_lever_by_hand = true
				hud.do_spin()
			else:
				create_tween().tween_property(lever, "rotation:x", 0.0, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	elif e is InputEventMouseMotion and _drag.on:
		var before := int(_drag.pull * 6.0)
		_drag.pull = clampf((e.position.y - _drag.y0) / 220.0, 0.0, 1.0)
		lever.rotation.x = _drag.pull * 1.15
		if int(_drag.pull * 6.0) != before:
			Sfx.play("tick", 0.8 + _drag.pull * 0.4)


# ---------------- mascota ----------------
func _majordom() -> void:
	majordom = Models.instance("mascot")
	if majordom == null:
		return
	add_child(majordom)
	majordom.scale = Vector3.ONE * 0.5
	majordom.position = Vector3(-1.12, 3.15, 0.2)
	majordom.rotation.y = 0.2
	_mascot_rest = majordom.transform
	_anim = Models.find_anim(majordom)
	_play("idle")
	var eq: Dictionary = Game.equipped
	# aceeași garderobă ca în glob: culoarea corpului și a eșarfei
	_tint(majordom, "Blana", Mascot.BODY.get(eq.get("corp", ""), Mascot.BODY.corp_crem))
	_tint(majordom, "Violet", Mascot.SCARF.get(eq.get("esarfa", ""), Mascot.SCARF.esarfa_violet))


func _tint(n: Node, mat_name: String, col: Color) -> void:
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m3 := mi as MeshInstance3D
		for i in m3.mesh.get_surface_count():
			var m := m3.mesh.surface_get_material(i)
			if m and m.resource_name.get_slice(".", 0) == mat_name:
				var c := (m as BaseMaterial3D).duplicate() as BaseMaterial3D
				c.albedo_color = col
				m3.set_surface_override_material(i, c)


func _play(kind: String) -> void:
	if _anim == null:
		return
	_anim.speed_scale = 1.0
	for a in _anim.get_animation_list():
		if a.begins_with(kind) or a.contains(kind):
			_anim.play(a, 0.2)
			if kind != "idle":
				_anim.queue(_idle_name())
			return


func _idle_name() -> String:
	for a in _anim.get_animation_list():
		if a.contains("idle"):
			return a
	return ""


## Mascota se întoarce spre role și se apleacă să le urmărească.
func _mascot_watch(on: bool) -> void:
	if majordom == null:
		return
	var target := _mascot_rest
	if on:
		target = Transform3D(Basis.from_euler(Vector3(0.32, 0.75, 0.0)).scaled(Vector3.ONE * 0.5), _mascot_rest.origin + Vector3(0.1, 0, 0.05))
	create_tween().tween_property(majordom, "transform", target, 0.3).set_trans(Tween.TRANS_SINE)


## Își ține respirația: se umflă puțin și îngheață.
func _mascot_hold(on: bool) -> void:
	if majordom == null:
		return
	if _anim:
		_anim.speed_scale = 0.0 if on else 1.0
	var b := majordom.transform.basis.orthonormalized()
	create_tween().tween_property(majordom, "transform:basis", b.scaled(Vector3(0.53, 0.56, 0.53) if on else Vector3.ONE * 0.5), 0.25)


func _mascot_shrug() -> void:
	if majordom == null:
		return
	if _anim:
		_anim.speed_scale = 0.0
	var arms := [majordom.find_child("BratS", true, false) as Node3D, majordom.find_child("BratD", true, false) as Node3D]
	var tw := create_tween()
	tw.tween_property(majordom, "transform", _mascot_rest, 0.2)
	for k in 2:
		var a: Node3D = arms[k]
		if a:
			tw.parallel().tween_property(a, "rotation:z", (1.0 if k == 0 else -1.0) * 1.1, 0.18).set_trans(Tween.TRANS_BACK)
	tw.parallel().tween_property(majordom, "rotation:z", 0.18, 0.18)
	tw.tween_interval(0.45)
	for a in arms:
		if a:
			tw.parallel().tween_property(a, "rotation:z", 0.0, 0.25)
	tw.parallel().tween_property(majordom, "rotation:z", 0.0, 0.25)
	tw.tween_callback(func():
		if _anim:
			_anim.speed_scale = 1.0)


func _mascot_joy() -> void:
	if majordom == null:
		return
	majordom.transform = _mascot_rest
	_play("joy")
	var tw := create_tween()
	tw.tween_property(majordom, "position:y", _mascot_rest.origin.y + 0.35, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(majordom, "position:y", _mascot_rest.origin.y, 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


# ---------------- efecte ----------------
func _coin_mesh() -> Mesh:
	var cm := _cyl(0.075, 0.075, 0.02, 14)
	cm.material = Proc.mat(Color("ffc93c"), {"metal": 0.95, "rough": 0.18, "emit": Color("ff9a20"), "energy": 0.25})
	return cm


func _effects() -> void:
	# fântâna de monede din tava aparatului
	coins_fx = CPUParticles3D.new()
	coins_fx.mesh = _coin_mesh()
	coins_fx.emitting = false
	coins_fx.one_shot = true
	coins_fx.amount = 70
	coins_fx.lifetime = 1.8
	coins_fx.explosiveness = 0.75
	coins_fx.position = Vector3(0, 0.8, 1.05)
	coins_fx.direction = Vector3(0, 1, 0.35)
	coins_fx.spread = 28.0
	coins_fx.initial_velocity_min = 4.0
	coins_fx.initial_velocity_max = 6.8
	coins_fx.gravity = Vector3(0, -9.8, 0)
	coins_fx.angular_velocity_min = -500.0
	coins_fx.angular_velocity_max = 500.0
	coins_fx.particle_flag_rotate_y = true
	coins_fx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(coins_fx)
	# ploaie de monede (super câștig)
	coin_rain = CPUParticles3D.new()
	coin_rain.mesh = _coin_mesh()
	coin_rain.emitting = false
	coin_rain.one_shot = true
	coin_rain.amount = 90
	coin_rain.lifetime = 2.6
	coin_rain.explosiveness = 0.15
	coin_rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	coin_rain.emission_box_extents = Vector3(2.6, 0.2, 1.0)
	coin_rain.position = Vector3(0, 6.5, 1.6)
	coin_rain.direction = Vector3.DOWN
	coin_rain.spread = 10.0
	coin_rain.initial_velocity_min = 1.0
	coin_rain.initial_velocity_max = 2.5
	coin_rain.gravity = Vector3(0, -5.0, 0)
	coin_rain.angular_velocity_min = -400.0
	coin_rain.angular_velocity_max = 400.0
	coin_rain.particle_flag_rotate_y = true
	coin_rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(coin_rain)
	# bule care urcă încet prin glob, și o explozie de bule la super câștig
	var bm := SphereMesh.new()
	bm.radius = 0.12
	bm.height = 0.24
	bm.radial_segments = 12
	bm.rings = 6
	var gm := ShaderMaterial.new()
	gm.shader = preload("res://shaders/symbol_bubble.gdshader")
	bm.material = gm
	dust = CPUParticles3D.new()
	dust.mesh = bm
	dust.amount = 22
	dust.lifetime = 11.0
	dust.preprocess = 11.0
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(5.5, 0.5, 3)
	dust.position = Vector3(0, -0.5, -0.5)
	dust.direction = Vector3.UP
	dust.spread = 10.0
	dust.initial_velocity_min = 0.5
	dust.initial_velocity_max = 0.9
	dust.gravity = Vector3.ZERO
	dust.scale_amount_min = 0.5
	dust.scale_amount_max = 2.4
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dust)
	bubble_burst = dust.duplicate()
	bubble_burst.amount = 40
	bubble_burst.one_shot = true
	bubble_burst.preprocess = 0.0
	bubble_burst.explosiveness = 0.8
	bubble_burst.emitting = false
	bubble_burst.lifetime = 3.0
	bubble_burst.position = Vector3(0, 1.0, 1.2)
	bubble_burst.emission_box_extents = Vector3(1.5, 0.3, 0.4)
	bubble_burst.spread = 35.0
	bubble_burst.initial_velocity_min = 1.8
	bubble_burst.initial_velocity_max = 3.6
	add_child(bubble_burst)


func _place_camera() -> void:
	# aparatul ocupă ~60–65% din înălțime; camera e puțin mai jos și privește ușor în sus
	cam.fov = 30.0
	cam_base = Vector3(0.05, 2.1, 8.9)
	cam_look = Vector3(0.05, 2.22, 0.0)     # aparatul stă deasupra barei evenimentului
	cam.position = cam_base
	cam.look_at(cam_look)


func _apply_quality() -> void:
	var q := Game.quality
	env.glow_enabled = q != "mic"
	dust.amount = {"mic": 10, "mediu": 22, "mare": 34}[q]
	get_viewport().msaa_3d = Viewport.MSAA_2X if q == "mare" else Viewport.MSAA_DISABLED
	get_viewport().scaling_3d_scale = {"mic": 0.75, "mediu": 0.9, "mare": 1.0}[q]
	var key := get_node_or_null("Cheie") as SpotLight3D
	if key:
		key.shadow_enabled = q != "mic"


# ---------------- cristalul ----------------
func _set_charge(c: float) -> void:
	charge = clampf(c, 0.0, 1.0)
	if crystal_light:
		crystal_light.light_energy = 0.3 + charge * 2.6


# ---------------- rotirea ----------------
## O rotire completă: rezultatul din tabel, maneta, rolele, apoi semnalul spun.
## Întoarce {} dacă nu e energie (interfața deschide fereastra de energie).
func spin() -> Dictionary:
	if busy:
		return {}
	var res := Game.spin()
	if res.is_empty():
		_lever_by_hand = false
		create_tween().tween_property(lever, "rotation:x", 0.0, 0.3)
		return {}
	busy = true
	_reset_glow()
	_pull_lever()
	Sfx.play("spin")
	set_bulbs("spin")
	_mascot_watch(true)
	_set_charge(charge + 0.12)
	_gear_speed = 4.0
	var anticip: bool = res.reels[0] == res.reels[1]
	var tws := []
	for i in 3:
		var reel := reels[i]
		var k: int = syms.find(res.reels[i])
		var a := k * step
		var cur := reel.rotation.x
		var turns := 2 + i + (2 if anticip and i == 2 else 0)
		var target := cur + fposmod(a - cur, TAU) + TAU * turns
		var dur := 0.8 + 0.35 * i + (1.5 if anticip and i == 2 else 0.0)
		var tw := create_tween()
		tw.tween_interval(0.14)
		tw.tween_property(reel, "rotation:x", cur + 0.55, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.tween_property(reel, "rotation:x", target + 0.08, dur).set_trans(Tween.TRANS_SINE if anticip and i == 2 else Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tw.tween_property(reel, "rotation:x", target, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_callback(func():
			Sfx.play("reel_stop", 1.0 + i * 0.1)
			Sfx.buzz(12 + i * 6)
			_bump_reel(i)
			if anticip and i == 1:
				_start_anticipation())
		tws.append(tw)
	await tws[2].finished
	for r in reels:
		r.rotation.x = fposmod(r.rotation.x, TAU)
	for i in 3:
		_prev_rot[i] = reels[i].rotation.x
	_gear_speed = 0.3
	_mascot_hold(false)
	_mascot_watch(false)
	set_bulbs("idle")
	busy = false
	spun.emit(res)
	return res


## Mică săritură a rolei la oprire (recul vizual).
func _bump_reel(i: int) -> void:
	var r := reels[i]
	var tw := create_tween()
	tw.tween_property(r, "position:y", WZ - 0.03, 0.05)
	tw.tween_property(r, "position:y", WZ, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _start_anticipation() -> void:
	set_bulbs("anticip")
	Sfx.play("anticip")
	_mascot_hold(true)
	for k in 6:
		get_tree().create_timer(0.25 * k).timeout.connect(func(): Sfx.buzz(8))
	var tw := create_tween()
	tw.tween_property(cam, "position", cam_base + Vector3(0, 0.05, -0.7), 1.2).set_trans(Tween.TRANS_SINE)
	tw.tween_property(cam, "position", cam_base, 0.5)


# ---------------- prezentarea rezultatului ----------------
## Nivelul câștigului (doar pentru prezentare): "huge", "big", "small" sau "".
func tier(res: Dictionary) -> String:
	if res.type == "coins":
		if res.id in ["jackpot", "sac"] or int(res.mult) >= 5:
			return "huge"
		if res.big or res.id == "monede" or int(res.mult) >= 3:
			return "big"
		return "small"
	if res.type == "energy":
		return "small"
	return ""


## Rolele cu simbolurile câștigătoare de pe linia din mijloc (cele care formează combinația).
func winners(res: Dictionary) -> Array:
	var cnt := {}
	for s in res.reels:
		cnt[s] = cnt.get(s, 0) + 1
	var best := ""
	for s in cnt:
		if cnt[s] >= 2 and (best == "" or cnt[s] > cnt[best]):
			best = s
	var out := []
	if res.type == "none" or best == "":
		return out
	for i in 3:
		if res.reels[i] == best:
			out.append(i)
	return out


func _reset_glow() -> void:
	for row in sym_nodes:
		for n in row:
			(n[0] as GeometryInstance3D).set_instance_shader_parameter("glow", 0.0)
			(n[1] as GeometryInstance3D).set_instance_shader_parameter("glow", 0.0)
			(n[2] as Node3D).scale = Vector3.ONE


func _set_glow(n: Array, v: float) -> void:
	(n[0] as GeometryInstance3D).set_instance_shader_parameter("glow", v)
	(n[1] as GeometryInstance3D).set_instance_shader_parameter("glow", v)
	(n[2] as Node3D).scale = Vector3.ONE * (1.0 + v * 0.22)


## Simbolurile câștigătoare pulsează și strălucesc.
func _pulse_winners(res: Dictionary, times := 3) -> void:
	for i in winners(res):
		var k: int = syms.find(res.reels[i])
		var n: Array = sym_nodes[i][k]
		var tw := create_tween()
		for r in times:
			tw.tween_method(func(v: float): _set_glow(n, v), 0.0, 1.0, 0.18)
			tw.tween_method(func(v: float): _set_glow(n, v), 1.0, 0.45, 0.22)


func _winner_pos(i: int, res: Dictionary) -> Vector3:
	var k: int = syms.find(res.reels[i])
	return (sym_nodes[i][k][2] as Node3D).global_position + Vector3(0, 0, 0.25)


func screen_of(p: Vector3) -> Vector2:
	return cam.unproject_position(p)


func middle_screen() -> Vector2:
	return screen_of(Vector3(0, WZ, REEL_Z + REEL_R + 0.2))


## Prezintă rezultatul: câștig mic / mare / uriaș sau intrarea specifică. Se poate aștepta.
func present(res: Dictionary) -> void:
	if res.is_empty():
		return
	match tier(res):
		"huge":
			await _win_huge(res)
			return
		"big":
			await _win_big(res)
			return
		"small":
			await _win_small(res)
			return
	match res.type:
		"none":
			Sfx.play("shrug")
			_mascot_shrug()
			await get_tree().create_timer(0.5).timeout
		"attack":
			await _intro_hammer(res)
		"raid":
			await _intro_shovel(res)
		"chest":
			await _intro_chest(res)
		"shield":
			await _intro_shield(res)
		"card":
			await _intro_card(res)


func _win_small(res: Dictionary) -> void:
	_pulse_winners(res, 2)
	Sfx.play("win_small" if res.coins > 0 else "zap")
	Sfx.buzz(25)
	set_bulbs("win")
	_play("wave")
	for i in winners(res):
		Fx.win(self, _winner_pos(i, res), 0.55, false)
	if res.coins > 0:
		hud.fly_coins(middle_screen(), 7)
	elif res.energy > 0:
		hud.fly_energy(middle_screen(), 5)
	await get_tree().create_timer(1.0).timeout
	set_bulbs("idle")


func _win_big(res: Dictionary) -> void:
	_pulse_winners(res, 4)
	Sfx.play("win_big")
	Sfx.buzz(120)
	set_bulbs("win")
	_mascot_joy()
	# contact la tavă (bliț + arce aurii + scântei în sus), apoi monedele și sclipirile pe simboluri
	Fx.win(self, coins_fx.global_position + Vector3(0, 0.2, 0.25), 1.0, true)
	for i in winners(res):
		Fx.sparkle(self, _winner_pos(i, res), 0.7, Color(1.0, 0.9, 0.55), 5, 0.3)
	coins_fx.amount = 70 if Game.quality != "mic" else 40
	coins_fx.restart()
	_flash_lamps(3.5)
	var tw := create_tween()
	tw.tween_property(cam, "position", cam_base + Vector3(0, 0.05, -1.5), 0.3).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(0.5)
	tw.tween_property(cam, "position", cam_base, 0.6).set_trans(Tween.TRANS_SINE)
	await get_tree().create_timer(0.3).timeout
	shake(0.45, 0.06)
	hud.big_text("CÂȘTIG MARE", false)
	hud.fly_coins(screen_of(coins_fx.position), 14)
	await get_tree().create_timer(1.6).timeout
	set_bulbs("idle")


func _win_huge(res: Dictionary) -> void:
	_pulse_winners(res, 6)
	Sfx.play("win_huge")
	Sfx.buzz(250)
	set_bulbs("win")
	_mascot_joy()
	# ralanti: totul încetinește o clipă, razele se aprind în spatele aparatului
	Engine.time_scale = 0.35
	var rm := rays.material_override as StandardMaterial3D
	var tw := create_tween()
	tw.tween_property(rm, "albedo_color:a", 0.85, 0.25)
	tw.parallel().tween_property(rays, "scale", Vector3.ONE * 1.25, 0.6).from(Vector3.ONE * 0.4)
	tw.parallel().tween_property(cam, "position", cam_base + Vector3(0, 0.1, -1.8), 0.4).set_trans(Tween.TRANS_SINE)
	coin_rain.restart()
	bubble_burst.restart()
	Fx.flash(self, Vector3(0, WZ, REEL_Z + REEL_R + 0.5), 1.1)
	Fx.arcs(self, Vector3(0, WZ, REEL_Z + REEL_R + 0.4), 1.25, Color("ffd24a"), 5, 0.6)
	for i in winners(res):
		Fx.sparkle(self, _winner_pos(i, res), 0.8, Color(1.0, 0.92, 0.6), 6, 0.35)
	coins_fx.amount = 90 if Game.quality == "mare" else 60
	coins_fx.restart()
	_flash_lamps(5.0)
	_set_charge(1.0)
	await get_tree().create_timer(0.9, true, false, true).timeout
	Engine.time_scale = 1.0
	shake(0.6, 0.08)
	hud.big_text("SUPER CÂȘTIG", true)
	hud.count_banner(int(res.coins), 2.2)
	hud.fly_coins(screen_of(coins_fx.position), 22)
	var back := create_tween()
	back.tween_interval(1.6)
	back.tween_property(cam, "position", cam_base, 0.8).set_trans(Tween.TRANS_SINE)
	back.parallel().tween_property(rm, "albedo_color:a", 0.0, 1.2)
	# cristalul se descarcă după super câștig
	back.tween_callback(func(): _set_charge(0.0))
	await get_tree().create_timer(2.6).timeout
	set_bulbs("idle")


func _flash_lamps(e: float) -> void:
	var tw := create_tween()
	for l in lamps:
		tw.parallel().tween_property(l, "light_energy", e, 0.12)
	tw.tween_interval(0.3)
	for l in lamps:
		tw.parallel().tween_property(l, "light_energy", 0.9, 0.9)


func shake(dur: float, amp: float) -> void:
	var tw := create_tween()
	var n := int(dur / 0.04)
	var base := cam.position
	for k in n:
		var f := 1.0 - float(k) / n
		tw.tween_property(cam, "position", base + Vector3(randf_range(-amp, amp), randf_range(-amp, amp), 0) * f, 0.04)
	tw.tween_property(cam, "position", base, 0.05)


## Obiectul simbolului iese mare din bula din mijloc, spre cameră.
func _pop_out(kind: String, scale_to := 4.0) -> MeshInstance3D:
	var obj := MeshInstance3D.new()
	obj.mesh = sym_mesh[kind]
	var om := ShaderMaterial.new()
	om.shader = preload("res://shaders/symbol_obj.gdshader")
	obj.material_override = om
	add_child(obj)
	obj.set_instance_shader_parameter("glow", 0.12)
	obj.position = Vector3(0, WZ, REEL_Z + REEL_R + 0.05)
	Sfx.play("whoosh")
	var tw := create_tween()
	tw.tween_property(obj, "position", Vector3(0, WZ + 0.15, 4.2), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(obj, "scale", Vector3.ONE * scale_to, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return obj


## Atac: ciocanul iese din bulă, se ridică și lovește ecranul, care se crapă.
func _intro_hammer(res: Dictionary) -> void:
	_pulse_winners(res, 2)
	_mascot_joy()
	var h := _pop_out("hammer", 3.4)
	await get_tree().create_timer(0.5).timeout
	# anticipare: ciocanul se ridică și capul lui sclipește
	Fx.sparkle(self, h.global_position + Vector3(-0.25, 0.4, 0), 0.6, Color(1, 1, 1), 3, 0.15)
	var tw := create_tween()
	tw.tween_property(h, "rotation:z", 1.2, 0.22).set_trans(Tween.TRANS_SINE)
	tw.tween_property(h, "rotation:z", -0.6, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(h, "position:z", 5.3, 0.1)
	await tw.finished
	Sfx.play("smash")
	Sfx.buzz(140)
	shake(0.35, 0.1)
	Fx.hit_heavy(self, h.global_position + Vector3(0, 0, -0.4), 0.55, Vector3(0, 0.6, 1.0))
	hud.crack(screen_of(h.global_position))
	await get_tree().create_timer(0.7).timeout
	h.queue_free()


## Raid: lopata iese din bulă, sapă de două ori, apoi ecranul se închide în cerc.
func _intro_shovel(res: Dictionary) -> void:
	_pulse_winners(res, 2)
	var s := _pop_out("shovel", 5.0)
	await get_tree().create_timer(0.5).timeout
	for k in 2:
		var tw := create_tween()
		tw.tween_property(s, "rotation:z", 0.9, 0.14)
		tw.parallel().tween_property(s, "position:y", WZ - 0.3, 0.14)
		tw.tween_property(s, "rotation:z", 0.0, 0.16)
		tw.parallel().tween_property(s, "position:y", WZ + 0.15, 0.16)
		await tw.finished
		Sfx.play("bomb", 1.4)
		Sfx.buzz(50)
		shake(0.15, 0.05)
	await hud.iris(middle_screen())
	s.queue_free()


## Cufăr: iese din bulă, se rotește cu o explozie de lumină, apoi pleacă spre sloturi.
func _intro_chest(res: Dictionary) -> void:
	_pulse_winners(res, 2)
	_mascot_joy()
	var c := _pop_out("chest", 4.2)
	await get_tree().create_timer(0.5).timeout
	Sfx.play("chest")
	Sfx.buzz(40)
	Fx.flash(self, c.global_position + Vector3(0, 0.3, 0.2), 0.8, Color(1.0, 0.85, 0.5))
	Fx.sparkle(self, c.global_position, 0.8, Color(1.0, 0.9, 0.5), 10, 0.7)
	Fx.motes(self, c.global_position, 0.7, Color(1.0, 0.85, 0.45), 12)
	var burst := OmniLight3D.new()
	burst.light_color = Color("ffd27a")
	burst.light_energy = 0.0
	burst.omni_range = 5.0
	add_child(burst)
	burst.global_position = c.global_position + Vector3(0, 0.6, 0.3)
	var tw := create_tween()
	tw.tween_property(c, "rotation:y", TAU, 0.6).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(burst, "light_energy", 8.0, 0.25)
	tw.tween_property(burst, "light_energy", 0.0, 0.4)
	tw.parallel().tween_property(c, "position", Vector3(-1.6, WZ + 2.4, 3.0), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(c, "scale", Vector3.ONE * 0.5, 0.4)
	await tw.finished
	c.queue_free()
	burst.queue_free()


## Scut: scutul iese din bulă, iar o bulă protectoare albastră se umflă în jurul aparatului.
func _intro_shield(res: Dictionary) -> void:
	_pulse_winners(res, 2)
	var s := _pop_out("shield", 4.0)
	Sfx.play("shield")
	Sfx.buzz(30)
	var dome := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 3.0
	sm.height = 6.0
	sm.radial_segments = 40
	sm.rings = 20
	dome.mesh = sm
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/glass_globe.gdshader")
	mat.set_shader_parameter("tint", Color(0.5, 0.75, 1.0))
	mat.set_shader_parameter("pulse", 1.0)
	mat.render_priority = 2
	dome.material_override = mat
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dome)
	dome.position = Vector3(0, 2.0, 0.3)
	var tw := create_tween()
	tw.tween_property(dome, "scale", Vector3.ONE, 0.45).from(Vector3.ONE * 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(s, "scale", Vector3.ONE * 0.1, 0.5).set_delay(0.4)
	tw.tween_interval(0.5)
	tw.tween_property(dome, "scale", Vector3.ONE * 1.15, 0.2)
	tw.tween_callback(func(): Fx.shield_break(self, dome.global_position + Vector3(0, 0, 1.2), 1.6))
	tw.tween_property(dome, "scale", Vector3.ZERO, 0.25)
	await tw.finished
	s.queue_free()
	dome.queue_free()


## Carte: cartea iese, se întoarce o dată spre cameră, apoi zboară sus.
func _intro_card(res: Dictionary) -> void:
	_pulse_winners(res, 2)
	_play("wave")
	var c := _pop_out("card", 4.5)
	Sfx.play("chest", 1.2)
	var st := c.create_tween()
	st.tween_interval(0.45)
	st.tween_callback(func(): Fx.sparkle(self, c.global_position, 0.7, Color(1.0, 0.8, 0.95), 8, 0.5))
	var tw := create_tween()
	tw.tween_interval(0.45)
	tw.tween_property(c, "rotation:y", TAU, 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(c, "position", Vector3(0, WZ + 3.0, 3.0), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(c, "scale", Vector3.ONE * 0.4, 0.35)
	await tw.finished
	c.queue_free()


# ---------------- în fiecare cadru ----------------
func _process(dt: float) -> void:
	t += dt
	for i in gears.size():
		gears[i].rotation.y += dt * _gear_speed * (1.0 if i % 2 == 0 else -1.6)
	# blur de mișcare: urmărește viteza fiecărei role
	for i in reels.size():
		var r := reels[i].rotation.x
		var speed := absf(r - float(_prev_rot[i])) / maxf(dt, 0.001)
		_prev_rot[i] = r
		blur_quads[i].set_instance_shader_parameter("amount", clampf((speed - 6.0) / 14.0, 0.0, 1.0))
		blur_quads[i].set_instance_shader_parameter("offset", -r / TAU)
	# un tic la fiecare simbol care trece prin dreptul ferestrei (doar prima rolă)
	if busy and reels.size() > 0:
		var idx := int(floor((reels[0].rotation.x + step * 0.5) / step))
		if idx != _tick:
			_tick = idx
			Sfx.play("tick", 0.9 + randf() * 0.2)
	_update_bulbs()
	rays.rotation.z = t * 0.25
	for i in 4:
		var r := get_node_or_null("Raza%d" % i) as Node3D
		if r:
			r.rotation.z = -0.42 + sin(t * 0.3 + i) * 0.04
	# cristalul pulsează, mai tare și mai repede când e încărcat
	if crystal_mat:
		crystal_mat.emission_energy_multiplier = (1.0 + charge * 7.0) * (0.85 + 0.15 * sin(t * (2.0 + charge * 6.0)))
	if not busy and cam and not _drag.on:
		cam.position.x = cam_base.x + sin(t * 0.25) * 0.06


func _exit_tree() -> void:
	Engine.time_scale = 1.0          # dacă jucătorul pleacă în timpul ralantiului
