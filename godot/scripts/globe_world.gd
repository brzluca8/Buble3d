extends Node3D
## Ecranul principal v2: orașul dintr-un glob de sticlă (vezi BUBLE_HANDOFF_v2.md).
## Globul stă pe un piedestal violet cu inele aurii și rune turcoaz; înăuntru e orașul
## (aceleași clădiri pe niveluri, piața, mascota), bule care urcă; în jur plutesc bulele
## prietenilor. Cer de amurg cu stele. Totul e 3D real; nimic nu e imagine statică.

const R := 6.0                                  # raza globului
const C := Vector3(0, 6.55, 0)                   # centrul globului (pe piedestal)
const GROUND := 1.7                             # platoul orașului este la C.y - GROUND
const CITY_SCALE := 0.64
const MASCOT_HOME := Vector3(-1.7, 0.0, 4.4)    # în coordonatele orașului (lângă scări)
const FRIEND_SLOTS := [Vector3(-7.6, 8.8, 1.5), Vector3(7.6, 9.4, 1.0), Vector3(-8.0, 3.6, 2.0),
	Vector3(8.0, 3.2, 2.0), Vector3(-5.6, 12.4, -3.5), Vector3(5.8, 12.2, -3.5)]

var env: Environment
var sun: DirectionalLight3D
var sky_mat: ProceduralSkyMaterial
var globe: Node3D                               # piedestal + glob + oraș (se mărește cu nivelul orașului)
var city: Node3D
var island: Node3D                              # alias pentru HUD/teste (orașul)
var cam: CameraRig
var mascot: Mascot
var bubbles: CPUParticles3D
var burst: CPUParticles3D
var glints: Array[Sprite3D] = []
var rings: Array[MeshInstance3D] = []
var stars: MultiMeshInstance3D
var friends: Array[FriendBubble] = []
var repo: FriendsRepository
var gem: Node3D
var ring_sel: MeshInstance3D
var visiting := {}                              # prietenul vizitat ({} = acasă)
var visit_ui: Control
var t := 0.0


func _ready() -> void:
	repo = NetFriendsRepository.new() if Net.online else LocalDemoRepository.new()
	_environment()
	_stars()
	globe = Node3D.new()
	globe.name = "Glob"
	add_child(globe)
	_pedestal()
	_city()
	_glass()
	_bubbles()
	_friends()
	cam = CameraRig.new()
	add_child(cam)
	cam.buildings = city.get_node("Buildings").get_children()
	cam.set_view(C + Vector3(0, -0.6, 0), 33.0, 16.0, 6.0, 38.0)
	cam.auto_rotate = true
	cam.focus_dist = 21.0
	add_child(preload("res://scripts/ui/hud.gd").new())
	Game.selected.connect(_on_selected)
	Game.upgraded.connect(_on_upgraded)
	Game.changed.connect(_update_rings)
	Game.blast_finished.connect(_on_blast)
	Game.friend_bubble_tapped.connect(_on_friend_tapped)
	Game.friend_signal.connect(func(_id): refresh_friends())
	Game.quality_changed.connect(func(_q): _apply_quality())
	Net.status_changed.connect(_on_net)
	_apply_quality()
	_update_rings()
	refresh_friends()


# ---------------- mediu: amurg cu stele ----------------
func _environment() -> void:
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("070624")
	sky_mat.sky_horizon_color = Color("2a1d7a")
	sky_mat.ground_horizon_color = Color("2b2486")
	sky_mat.ground_bottom_color = Color("0e5a7a")
	sky_mat.sky_curve = 0.25
	sky_mat.ground_curve = 0.2
	sky_mat.sun_angle_max = 0.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("a99ad8")
	env.ambient_light_energy = 0.6
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.tonemap_white = 5.0
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_bloom = 0.03
	env.glow_hdr_threshold = 0.95
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.fog_enabled = true
	env.fog_light_color = Color("2e2470")
	env.fog_density = 0.003
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.06
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	# soare cald (cheie) + lumină albastră de umplere
	sun = DirectionalLight3D.new()
	sun.light_color = Color("ffd9a8")
	sun.light_energy = 1.9
	sun.shadow_enabled = true
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.shadow_blur = 2.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 40.0
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(sun)
	sun.look_at_from_position(Vector3(-10, 18, 9), C)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color("7fb4ff")
	fill.light_energy = 0.7
	fill.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(fill)
	fill.look_at_from_position(Vector3(10, 4, 8), C)


func _stars() -> void:
	var n := 420
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	mm.mesh = q
	mm.instance_count = n
	Proc.reseed(77)
	var cols := [Color(1, 1, 1), Color("9ff4ff"), Color("d6b8ff"), Color("ffe8b0")]
	for i in n:
		var a := Proc.rnd() * TAU
		var el := lerpf(-0.45, 1.35, Proc.rnd())
		var d := Vector3(cos(el) * sin(a), sin(el), cos(el) * cos(a)) * 140.0
		var s := 1.6 + Proc.rnd() * 2.6 if Proc.rnd() < 0.85 else 4.5 + Proc.rnd() * 2.0
		var c: Color = cols[i % cols.size()]
		c.a = 0.55 + 0.45 * Proc.rnd()
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * s), d + Vector3(0, 10, 0)))
		mm.set_instance_color(i, c)
	stars = MultiMeshInstance3D.new()
	stars.multimesh = mm
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	sm.billboard_keep_scale = true
	sm.vertex_color_use_as_albedo = true
	sm.albedo_texture = Proc.tex("soft")
	sm.disable_fog = true
	sm.no_depth_test = false
	stars.material_override = sm
	stars.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sm.albedo_color = Color(1.6, 1.6, 1.6)
	add_child(stars)


# ---------------- piedestal, glob, oraș ----------------
func _pedestal() -> void:
	var p := Models.instance("piedestal")
	if p == null:
		p = Node3D.new()
		Proc.add(p, Proc.cyl(4.6, 5.0, 1.4, 64), Proc.mat(Color("5a3aa8"), {"rough": 0.35}), Vector3(0, 0.7, 0))
		for y in [0.45, 1.25]:
			Proc.add(p, Proc.htor(4.75, 0.07, 96, 8), Proc.M("gold"), Vector3(0, y, 0))
	p.scale = Vector3(1.0, 0.8, 1.0)
	globe.add_child(p)


func _city() -> void:
	# platoul orașului: un „pământ" care umple fundul globului, cu iarbă deasupra
	var gy := C.y - GROUND
	var top_r := sqrt(R * R - GROUND * GROUND) * 0.975
	var pts := []
	for i in 9:
		var y := lerpf(-R * 0.97, -GROUND, float(i) / 8.0)
		pts.append(Vector2(sqrt(maxf(R * R * 0.95 - y * y, 0.0)), y))
	pts.append(Vector2(0.0, -GROUND))
	var soil := Proc.add(globe, Proc.lathe(pts, 48), Proc.mat(Color("7b5ad0"), {"emit": Color("4a2a9a"), "energy": 0.25, "rough": 0.5}), Vector3(0, C.y, 0))
	soil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Proc.add(globe, Proc.cyl(top_r, top_r, 0.12, 64), Proc.M("grass"), Vector3(0, gy - 0.05, 0))
	Proc.add(globe, Proc.htor(top_r, 0.08, 96, 8), Proc.M("stone"), Vector3(0, gy, 0))

	city = Node3D.new()
	city.name = "Oras"
	city.position = Vector3(0, gy, 0)
	city.scale = Vector3.ONE * CITY_SCALE
	globe.add_child(city)
	island = city
	var plaza := Models.instance("plaza")
	if plaza:
		plaza.name = "Piata"
		city.add_child(plaza)
		gem = Proc.add(city, Proc.sph(0.22, 6, 3), Proc.M("gem"), Vector3(0, 2.35, 0.3))
	else:
		var pz := Proc.plaza()
		city.add_child(pz)
		gem = pz.get_node("Gem")
	var bs := Node3D.new()
	bs.name = "Buildings"
	city.add_child(bs)
	for info in Game.BUILDINGS:
		var b := Building.new()
		bs.add_child(b)
		b.setup(info)
	mascot = Mascot.new()
	city.add_child(mascot)
	mascot.set_home(MASCOT_HOME)
	mascot.scale = Vector3.ONE * 1.25
	ring_sel = Proc.add(city, Proc.htor(1.0, 0.035, 64, 8), Proc.mat(Color("ffd86b"), {"emit": Color("ffc040"), "energy": 3.0}))
	ring_sel.visible = false
	ring_sel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var warm := OmniLight3D.new()
	warm.light_color = Color("ffb060")
	warm.light_energy = 1.4
	warm.omni_range = 6.0
	warm.position = Vector3(0, 2.0, -1.5)
	city.add_child(warm)
	# fântâna: jet de apă
	var f := CPUParticles3D.new()
	f.amount = 30
	f.lifetime = 0.9
	var dm := SphereMesh.new()
	dm.radius = 0.04
	dm.height = 0.08
	dm.radial_segments = 6
	dm.rings = 3
	dm.material = Proc.mat(Color(1, 1, 1), {"unshaded": true, "alpha": 0.8})
	f.mesh = dm
	f.position = Vector3(0, 2.25, 0.3)
	f.direction = Vector3.UP
	f.spread = 35.0
	f.initial_velocity_min = 1.4
	f.initial_velocity_max = 1.9
	f.gravity = Vector3(0, -6, 0)
	city.add_child(f)


func _glass() -> void:
	var sm := SphereMesh.new()
	sm.radius = R
	sm.height = R * 2
	sm.radial_segments = 64
	sm.rings = 32
	# fața din spate (margine stinsă) + fața din față (margine irizată luminoasă)
	for back in [true, false]:
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://shaders/glass_globe.gdshader")
		mat.set_shader_parameter("rim_strength", 0.6 if back else 1.3)
		mat.set_shader_parameter("base_alpha", 0.0 if back else 0.03)
		mat.render_priority = -1 if back else 1
		var mi := MeshInstance3D.new()
		mi.mesh = sm
		mi.material_override = mat
		mi.position = C
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if back:
			mi.scale = Vector3(-1, 1, 1) * 0.995      # normalele întoarse = fața interioară
		globe.add_child(mi)
	# reflexii false: pete luminoase pe sticlă, orientate mereu spre cameră
	for i in 2:
		var s := Sprite3D.new()
		s.texture = Proc.tex("soft")
		s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		s.shaded = false
		s.transparent = true
		s.modulate = Color(1, 1, 1, 0.42 if i == 0 else 0.22)
		s.pixel_size = (0.028 if i == 0 else 0.014)
		s.scale = Vector3(1.0, 0.45, 1.0) if i == 0 else Vector3.ONE
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		s.sorting_offset = 5.0
		globe.add_child(s)
		glints.append(s)
	# inele aurii deblocate de nivelul orașului: pe baza globului (ca o ramă), unul peste altul
	for i in 5:
		var y := -GROUND - 0.15 - i * 0.22
		var r := sqrt(maxf(R * R - y * y, 0.1)) + 0.06
		var ring := Proc.add(globe, Proc.htor(r, 0.07, 96, 8), Proc.mat(Color("f6c445"), {"metal": 0.9, "rough": 0.25, "emit": Color("ffb030"), "energy": 0.5}), C + Vector3(0, y, 0))
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.visible = false
		rings.append(ring)


func _bubbles() -> void:
	var m := SphereMesh.new()
	m.radius = 0.12
	m.height = 0.24
	m.radial_segments = 12
	m.rings = 6
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/glass_globe.gdshader")
	mat.set_shader_parameter("rim_power", 1.6)
	mat.set_shader_parameter("base_alpha", 0.08)
	m.material = mat
	bubbles = CPUParticles3D.new()
	bubbles.mesh = m
	bubbles.amount = 26
	bubbles.lifetime = 7.0
	bubbles.position = C + Vector3(0, -GROUND + 0.4, 0)
	bubbles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	bubbles.emission_sphere_radius = 3.6
	bubbles.direction = Vector3.UP
	bubbles.spread = 12.0
	bubbles.initial_velocity_min = 0.35
	bubbles.initial_velocity_max = 0.8
	bubbles.gravity = Vector3(0, 0.08, 0)
	bubbles.scale_amount_min = 0.5
	bubbles.scale_amount_max = 1.6
	bubbles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	globe.add_child(bubbles)
	burst = bubbles.duplicate()
	burst.amount = 70
	burst.one_shot = true
	burst.explosiveness = 0.7
	burst.emitting = false
	burst.lifetime = 4.0
	burst.initial_velocity_min = 0.8
	burst.initial_velocity_max = 1.8
	globe.add_child(burst)


# ---------------- prieteni ----------------
func _friends() -> void:
	for i in FRIEND_SLOTS.size():
		var fb := FriendBubble.new()
		add_child(fb)
		fb.setup(i, FRIEND_SLOTS[i])
		friends.append(fb)


func _on_net(online: bool) -> void:
	repo = NetFriendsRepository.new() if online else LocalDemoRepository.new()
	refresh_friends()


## Actualizează bulele: prieteni reali (cu server) sau sloturi goale „Invită un prieten" (DEMO).
func refresh_friends() -> void:
	var list: Array = await repo.list_friends()
	for i in friends.size():
		friends[i].show_friend(list[i] if i < list.size() else {}, repo.is_demo())


func _on_friend_tapped(slot: int) -> void:
	if not visiting.is_empty():
		return
	var fb := friends[slot]
	Sfx.play("pop")
	if fb.friend.is_empty():
		var hud := _hud()
		if hud:
			hud._open_modal("friends")
		return
	await visit(fb.friend)


## Vizită: camera intră în bula prietenului, apoi globul arată orașul lui.
func visit(f: Dictionary) -> void:
	var city_d: Dictionary = await repo.get_city(int(f.id))
	if city_d.is_empty():
		return
	visiting = f
	Game.select("")
	cam.rival_mode = true              # atingerile nu mai selectează clădirile tale
	var slot_pos := friends[0].position
	for fb in friends:
		if fb.friend.get("id", -1) == f.id:
			slot_pos = fb.position
	cam._t_target = slot_pos
	cam._t_dist = 8.0
	await get_tree().create_timer(0.6).timeout
	var hud := _hud()
	if hud and hud.play:
		await hud.play._wipe(func(): _show_city(city_d.get("levels", {})))
	else:
		_show_city(city_d.get("levels", {}))
	cam.reset_view()
	repo.notify_visit(int(f.id))
	_visit_panel(f)


func _show_city(levels: Dictionary) -> void:
	for b in city.get_node("Buildings").get_children():
		b.show_level(int(levels.get(b.id, 1)) if not levels.is_empty() else -1)
	mascot.visible = levels.is_empty()


func end_visit() -> void:
	visiting = {}
	if visit_ui:
		visit_ui.queue_free()
	_show_city({})
	cam.rival_mode = false
	cam.reset_view()


func _visit_panel(f: Dictionary) -> void:
	var K := preload("res://scripts/ui/ui_kit.gd")
	visit_ui = PanelContainer.new()
	visit_ui.add_theme_stylebox_override("panel", K.box(Color(0.125, 0.1, 0.37, 0.92), 34, K.GOLD, 3, 10, 18))
	K.place(visit_ui, false, 250, 0, 20, 20)
	visit_ui.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	visit_ui.add_child(vb)
	var title := K.label("🏙️ Orașul lui %s" % f.get("name", "?"), 30, Color.WHITE, 900)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	var can := repo.can_gift_today(int(f.id))
	var hint := K.label("Lasă-i un cadou (o dată pe zi):" if can else "Ai lăsat deja un cadou azi 🎁", 22, Color(1, 1, 1, 0.85), 700)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(hint)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	vb.add_child(hb)
	for g in [["coins", "🪙 Monede"], ["card", "🃏 Carte"]]:
		var b := K.gold_button(g[1], 24)
		b.custom_minimum_size = Vector2(0, 66)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.disabled = not can
		var kind: String = g[0]
		b.pressed.connect(func():
			var r: Dictionary = await repo.send_gift(int(f.id), kind)
			Game.toast.emit(r.msg)
			if r.ok:
				Sfx.play("coin")
				for c in hb.get_children():
					(c as Button).disabled = true)
		hb.add_child(b)
	var back := K.button("⬅ Înapoi acasă", 24, K.box(Color(1, 1, 1, 0.12), 30, Color(1, 1, 1, 0.3), 2, 0, 12))
	back.pressed.connect(func():
		Sfx.play("click")
		end_visit())
	vb.add_child(back)
	var hud := _hud()
	if hud:
		hud.root.add_child(visit_ui)


func _hud() -> Node:
	for c in get_children():
		if c.has_method("show_toast"):
			return c
	return null


# ---------------- evenimente ----------------
func _building(id: String) -> Building:
	for b in city.get_node("Buildings").get_children():
		if b.id == id:
			return b
	return null


func _on_selected(id: String) -> void:
	ring_sel.visible = id != ""
	if id == "":
		return
	var b := _building(id)
	var r := maxf(b.local_aabb.size.x, b.local_aabb.size.z) * 0.5 * b.scale.x + 0.25
	ring_sel.position = Vector3(b.position.x, 0.08, b.position.z)
	ring_sel.scale = Vector3.ONE * r


func _on_upgraded(id: String) -> void:
	var b := _building(id)
	burst.position = globe.to_local(b.global_position) + Vector3(0, 1.0, 0)
	burst.restart()


func _on_blast(won: bool) -> void:
	if won:
		burst.position = C + Vector3(0, -GROUND + 0.5, 0)
		burst.restart()


## Nivelul orașului: la fiecare 4 niveluri de clădiri se aprinde un inel auriu și globul crește puțin.
func city_tier() -> int:
	return clampi((Game.sum_levels() - 5) / 4, 0, rings.size())


func _update_rings() -> void:
	var tier := city_tier()
	for i in rings.size():
		rings[i].visible = i < tier
	globe.scale = Vector3.ONE * (1.0 + 0.03 * tier)


func _apply_quality() -> void:
	var q := Game.quality
	env.glow_enabled = q != "mic"
	sun.shadow_enabled = q != "mic"
	RenderingServer.directional_shadow_atlas_set_size(2048 if q == "mare" else 1024, true)
	get_viewport().msaa_3d = Viewport.MSAA_2X if q == "mare" else Viewport.MSAA_DISABLED
	get_viewport().scaling_3d_scale = {"mic": 0.75, "mediu": 0.9, "mare": 1.0}[q]
	bubbles.amount = {"mic": 12, "mediu": 26, "mare": 44}[q]
	stars.multimesh.visible_instance_count = {"mic": 200, "mediu": 320, "mare": -1}[q]


func _process(dt: float) -> void:
	t += dt
	gem.rotation.y = t
	gem.position.y = 2.35 + sin(t * 2.0) * 0.08
	if ring_sel.visible:
		ring_sel.rotation.y = t * 0.3
	# reflexiile false urmăresc camera: o pată mare sus-stânga, una mică jos-dreapta
	var gc := globe.to_global(C)
	var v := (cam.global_position - gc).normalized()
	var side := v.cross(Vector3.UP).normalized()
	var up := side.cross(v).normalized()
	var rs := R * globe.scale.x
	glints[0].global_position = gc + (v * 0.82 + up * 0.42 + side * 0.32).normalized() * rs * 1.01
	glints[1].global_position = gc + (v * 0.9 - up * 0.3 - side * 0.3).normalized() * rs * 1.01
