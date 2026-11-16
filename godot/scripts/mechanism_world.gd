extends Node3D
## Pagina separată a rotirilor: mașina de bule (catifea violet, alamă, dom de sticlă) pe o
## platformă printre nori, la amurg, cu 3 role 3D. Rezultatul vine din Game.spin() (data/spin_table.json);
## rolele doar îl arată: maneta coboară, rolele accelerează, se rotesc și frânează pe rând,
## cu un mic recul. Mascota stă alături și se bucură la câștiguri.
## Atacul și raidul se joacă în glob: pagina pune Game.pending_action și schimbă scena.

signal spun(res: Dictionary)

const WZ := 2.05                                 # centrul ferestrei rolelor
const REEL_R := 0.6
const REEL_X := [-0.86, 0.0, 0.86]
const REEL_Z := 0.02
## Simbolurile: iconița albă și culoarea jetonului din bulă.
const SYM := {
	"coin": ["coins", Color("f2b630")], "bag": ["hand-coins", Color("d99a2b")], "gem": ["gem", Color("2bd4c8")],
	"energy": ["zap", Color("35c46a")], "shield": ["shield", Color("6f8cff")], "hammer": ["hammer", Color("e8645a")],
	"shovel": ["shovel", Color("9a6ae8")], "chest": ["package", Color("c08040")], "card": ["layers", Color("e66fa8")],
}

var syms: Array = []
var step := 0.0
var reels: Array[Node3D] = []
var busy := false
var auto := false
var lever: Node3D
var gears: Array[Node3D] = []
var lamps: Array[OmniLight3D] = []
var coins_fx: CPUParticles3D
var dust: CPUParticles3D
var majordom: Node3D
var _anim: AnimationPlayer
var cam: Camera3D
var env: Environment
var hud: CanvasLayer
var t := 0.0
var _tick := [0, 0, 0]
var _gear_speed := 0.3


func _ready() -> void:
	syms = Game.D.spin_table.symbols
	step = TAU / syms.size()
	_environment()
	_room()
	_machine()
	_reels()
	_majordom()
	_effects()
	cam = Camera3D.new()
	cam.fov = 46.0
	cam.keep_aspect = Camera3D.KEEP_WIDTH if get_viewport().get_visible_rect().size.aspect() > 0.7 else Camera3D.KEEP_HEIGHT
	add_child(cam)
	_place_camera()
	hud = preload("res://scripts/ui/mechanism_ui.gd").new()
	add_child(hud)
	Game.quality_changed.connect(func(_q): _apply_quality())
	_apply_quality()


# ---------------- cerul de amurg și platforma printre nori ----------------
func _environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("2e2280")
	sky_mat.sky_horizon_color = Color("e890c0")
	sky_mat.ground_horizon_color = Color("ffc9a0")
	sky_mat.ground_bottom_color = Color("b88ad8")
	sky_mat.sky_curve = 0.18
	sky_mat.sun_angle_max = 0.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c8b4f0")
	env.ambient_light_energy = 0.4
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 5.0
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 0.95
	env.fog_enabled = true
	env.fog_light_color = Color("e8b8d8")
	env.fog_density = 0.0025
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.15
	env.adjustment_contrast = 1.06
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	# soare cald din față-stânga, contur turcoaz din spate, umplere lavandă
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("ffe2b8")
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.shadow_blur = 2.0
	sun.directional_shadow_max_distance = 30.0
	add_child(sun)
	sun.look_at_from_position(Vector3(-5, 8, 7), Vector3(0, 1.5, 0))
	var rim := DirectionalLight3D.new()
	rim.light_color = Color("8ff3ff")
	rim.light_energy = 0.8
	add_child(rim)
	rim.look_at_from_position(Vector3(2, 6, -6), Vector3(0, 2, 0))
	var fill := DirectionalLight3D.new()
	fill.light_color = Color("c8b4ff")
	fill.light_energy = 0.4
	add_child(fill)
	fill.look_at_from_position(Vector3(6, 2, 5), Vector3(0, 2, 0))


func _room() -> void:
	# platforma plutitoare: disc crem cu inel de alamă, covor violet, dale turcoaz
	var cream := Proc.mat(Color("f6ecd8"), {"rough": 0.5})
	var brass := Proc.mat(Color("e9b54a"), {"metal": 0.9, "rough": 0.25})
	Proc.add(self, Proc.cyl(4.6, 4.3, 0.5, 64), cream, Vector3(0, -0.25, 0.6))
	Proc.add(self, Proc.htor(4.6, 0.08, 96, 8), brass, Vector3(0, 0.0, 0.6))
	Proc.add(self, Proc.cyl(3.4, 3.4, 0.04, 64), Proc.mat(Color("4a2a8e"), {"rough": 0.85}), Vector3(0, 0.02, 0.4))
	Proc.add(self, Proc.htor(3.4, 0.035, 96, 8), brass, Vector3(0, 0.04, 0.4))
	var teal := Proc.mat(Color("1fb2ab"), {"rough": 0.3})
	for i in 16:
		var a := i / 16.0 * TAU
		var tile := Proc.add(self, Proc.box(0.5, 0.04, 0.5), teal, Vector3(cos(a) * 4.0, 0.01, 0.6 + sin(a) * 4.0))
		tile.rotation.y = -a
	# nori moi în jur și dedesubt (aceleași imagini ca la dirijabil)
	Proc.reseed(9)
	for i in 14:
		var c := Sprite3D.new()
		c.texture = load("res://art3d/cloud_%d.png" % (i % 3))
		c.pixel_size = (12.0 + Proc.rnd() * 14.0) / 512.0
		c.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		c.shaded = false
		c.modulate = Color(1, 0.9, 0.96, 0.7)
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var side := -1.0 if i % 2 == 0 else 1.0
		if i < 6:
			c.position = Vector3(side * (5.5 + Proc.rnd() * 4.0), -1.5 - Proc.rnd() * 2.0, -2.0 + Proc.rnd() * 6.0)
		else:
			c.position = Vector3(side * (3.0 + Proc.rnd() * 9.0), 2.0 + Proc.rnd() * 9.0, -9.0 - Proc.rnd() * 10.0)
		add_child(c)


# ---------------- automatul ----------------
func _machine() -> void:
	var m := Models.instance("mecanism")
	if m == null:
		# rezervă procedurală: dulap violet cu ramă aurie
		m = Node3D.new()
		Proc.add(m, Proc.box(3.4, 3.4, 1.6), Proc.mat(Color("4a2a8e"), {"rough": 0.8}), Vector3(0, 1.9, -0.1))
		Proc.add(m, Proc.box(2.76, 1.6, 0.1), Proc.M("gold"), Vector3(0, WZ, -0.7))
	add_child(m)
	lever = m.find_child("Maneta", true, false) as Node3D
	for i in 3:
		var g := m.find_child("Roata%d" % i, true, false) as Node3D
		if g:
			gears.append(g)
	# lumina interioară a ferestrei, cristalul din dom și tava (pulsează la câștig)
	var win := OmniLight3D.new()
	win.light_color = Color("ffe8c0")
	win.light_energy = 1.0
	win.omni_range = 2.6
	win.position = Vector3(0, WZ + 0.5, 1.4)
	add_child(win)
	for it in [[Vector3(0, 3.85, 0.4), Color("ff8fd0")], [Vector3(0, 1.0, 1.4), Color("ffc56a")]]:
		var l := OmniLight3D.new()
		l.light_color = it[1]
		l.light_energy = 1.2
		l.omni_range = 3.0
		l.position = it[0]
		add_child(l)
		lamps.append(l)


func _reels() -> void:
	var enamel := Proc.mat(Color("f6eedc"), {"rough": 0.5})
	var gold := Proc.mat(Color("b9822c"), {"metal": 0.9, "rough": 0.3})
	var drum := CylinderMesh.new()
	drum.top_radius = REEL_R - 0.04
	drum.bottom_radius = REEL_R - 0.04
	drum.height = 0.78
	drum.radial_segments = 48
	var rim := CylinderMesh.new()
	rim.top_radius = REEL_R + 0.01
	rim.bottom_radius = REEL_R + 0.01
	rim.height = 0.025
	rim.radial_segments = 48
	var disc := CylinderMesh.new()
	disc.top_radius = 0.2
	disc.bottom_radius = 0.2
	disc.height = 0.045
	disc.radial_segments = 32
	var ring := TorusMesh.new()
	ring.inner_radius = 0.19
	ring.outer_radius = 0.225
	ring.rings = 32
	ring.ring_segments = 6
	var quad := QuadMesh.new()
	quad.size = Vector2(0.27, 0.27)
	# fiecare jeton stă într-o bulă de sticlă irizată (același shader ca globul)
	var bubble := SphereMesh.new()
	bubble.radius = 0.235
	bubble.height = 0.47
	bubble.radial_segments = 20
	bubble.rings = 10
	var bubble_mat := ShaderMaterial.new()
	bubble_mat.shader = preload("res://shaders/glass_globe.gdshader")
	bubble_mat.set_shader_parameter("rim_power", 2.2)
	bubble_mat.set_shader_parameter("base_alpha", 0.02)
	bubble_mat.render_priority = 1
	var tok_mats := {}
	var icon_mats := {}
	var ring_mats := {}
	for s in SYM:
		ring_mats[s] = Proc.mat(Color("e9b54a"), {"metal": 0.9, "rough": 0.25})
		tok_mats[s] = Proc.mat(SYM[s][1], {"rough": 0.35, "emit": SYM[s][1], "energy": 0.08})
		var im := StandardMaterial3D.new()
		im.albedo_texture = UiKit.icon(SYM[s][0])
		im.albedo_color = Color("241250")   # iconiță închisă: se citește pe orice jeton
		im.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		im.alpha_scissor_threshold = 0.4
		im.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		icon_mats[s] = im
	for i in 3:
		var reel := Node3D.new()
		reel.name = "Rola%d" % i
		reel.position = Vector3(REEL_X[i], WZ, REEL_Z)
		add_child(reel)
		var d := MeshInstance3D.new()
		d.mesh = drum
		d.material_override = enamel
		d.rotation.z = PI / 2
		reel.add_child(d)
		for sx in [-0.4, 0.4]:
			var r := MeshInstance3D.new()
			r.mesh = rim
			r.material_override = gold
			r.rotation.z = PI / 2
			r.position.x = sx
			reel.add_child(r)
		for k in syms.size():
			var sid: String = syms[k]
			var pivot := Node3D.new()
			pivot.rotation.x = -k * step
			reel.add_child(pivot)
			var tok := MeshInstance3D.new()
			tok.mesh = disc
			tok.material_override = tok_mats[sid]
			tok.rotation.x = PI / 2
			tok.position.z = REEL_R - 0.02
			pivot.add_child(tok)
			var rg := MeshInstance3D.new()
			rg.mesh = ring
			rg.material_override = ring_mats[sid]
			rg.rotation.x = PI / 2
			rg.position.z = REEL_R + 0.0
			pivot.add_child(rg)
			var ic := MeshInstance3D.new()
			ic.mesh = quad
			ic.material_override = icon_mats[sid]
			ic.position.z = REEL_R + 0.006
			pivot.add_child(ic)
			var bb := MeshInstance3D.new()
			bb.mesh = bubble
			bb.material_override = bubble_mat
			bb.position.z = REEL_R - 0.02
			bb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			pivot.add_child(bb)
		reel.rotation.x = randi_range(0, syms.size() - 1) * step
		reels.append(reel)


func _majordom() -> void:
	majordom = Models.instance("mascot")
	if majordom == null:
		return
	add_child(majordom)
	majordom.scale = Vector3.ONE * 0.5
	majordom.position = Vector3(-1.12, 3.15, 0.2)
	majordom.rotation.y = 0.2
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
				if c.emission_enabled:
					c.emission = col
				m3.set_surface_override_material(i, c)


func _play(kind: String) -> void:
	if _anim == null:
		return
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


func _effects() -> void:
	# monede care sar din fantă la câștig
	var cm := CylinderMesh.new()
	cm.top_radius = 0.07
	cm.bottom_radius = 0.07
	cm.height = 0.018
	cm.radial_segments = 14
	cm.material = Proc.mat(Color("e2b860"), {"metal": 0.95, "rough": 0.2})
	coins_fx = CPUParticles3D.new()
	coins_fx.mesh = cm
	coins_fx.emitting = false
	coins_fx.one_shot = true
	coins_fx.amount = 40
	coins_fx.lifetime = 1.6
	coins_fx.explosiveness = 0.85
	coins_fx.position = Vector3(0, 1.0, 0.95)
	coins_fx.direction = Vector3(0, 1, 0.6)
	coins_fx.spread = 40.0
	coins_fx.initial_velocity_min = 3.0
	coins_fx.initial_velocity_max = 5.5
	coins_fx.gravity = Vector3(0, -9.8, 0)
	coins_fx.angular_velocity_min = -400.0
	coins_fx.angular_velocity_max = 400.0
	coins_fx.particle_flag_rotate_y = true
	add_child(coins_fx)
	# bule care urcă încet prin aer
	var bm := SphereMesh.new()
	bm.radius = 0.12
	bm.height = 0.24
	bm.radial_segments = 12
	bm.rings = 6
	var gm := ShaderMaterial.new()
	gm.shader = preload("res://shaders/glass_globe.gdshader")
	gm.set_shader_parameter("rim_power", 1.6)
	gm.set_shader_parameter("base_alpha", 0.06)
	bm.material = gm
	dust = CPUParticles3D.new()
	dust.mesh = bm
	dust.amount = 26
	dust.lifetime = 9.0
	dust.preprocess = 9.0
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(6, 0.5, 3)
	dust.position = Vector3(0, -0.5, 0.5)
	dust.direction = Vector3.UP
	dust.spread = 12.0
	dust.initial_velocity_min = 0.6
	dust.initial_velocity_max = 1.2
	dust.gravity = Vector3.ZERO
	dust.scale_amount_min = 0.5
	dust.scale_amount_max = 2.2
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dust)


func _place_camera() -> void:
	cam.position = Vector3(0.0, 3.3, 13.6)
	cam.look_at(Vector3(-0.15, 1.95, 0.0))


func _sun_index() -> int:
	for c in get_children():
		if c is DirectionalLight3D:
			return c.get_index()
	return -1


func _apply_quality() -> void:
	var q := Game.quality
	env.glow_enabled = q != "mic"
	dust.amount = {"mic": 10, "mediu": 26, "mare": 40}[q]
	get_viewport().msaa_3d = Viewport.MSAA_2X if q == "mare" else Viewport.MSAA_DISABLED
	get_viewport().scaling_3d_scale = {"mic": 0.75, "mediu": 0.9, "mare": 1.0}[q]
	for c in find_children("*", "DirectionalLight3D", true, false):
		if (c as DirectionalLight3D).shadow_enabled or q == "mic":
			(c as DirectionalLight3D).shadow_enabled = q != "mic" and c.get_index() == _sun_index()


# ---------------- rotirea ----------------
## O rotire completă: rezultatul din tabel, maneta, rolele, apoi semnalul spun.
## Întoarce {} dacă nu e energie (interfața deschide fereastra de energie).
func spin() -> Dictionary:
	if busy:
		return {}
	var res := Game.spin()
	if res.is_empty():
		return {}
	busy = true
	Sfx.play("click")
	Sfx.buzz(20)
	if lever:
		var lt := create_tween()
		lt.tween_property(lever, "rotation:x", 0.75, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		lt.tween_property(lever, "rotation:x", 0.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_gear_speed = 4.0
	var tws := []
	for i in 3:
		var reel := reels[i]
		var k: int = syms.find(res.reels[i])
		var a := k * step
		var cur := reel.rotation.x
		var target := cur + fposmod(a - cur, TAU) + TAU * (2 + i)
		var tw := create_tween()
		tw.tween_interval(0.12)
		tw.tween_property(reel, "rotation:x", cur + 0.5, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.tween_property(reel, "rotation:x", target + 0.07, 0.8 + 0.35 * i).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tw.tween_property(reel, "rotation:x", target, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_callback(func():
			Sfx.play("reel_stop", 1.0 + i * 0.08)
			Sfx.buzz(15))
		tws.append(tw)
	await tws[2].finished
	for r in reels:
		r.rotation.x = fposmod(r.rotation.x, TAU)
	_gear_speed = 0.3
	if res.big:
		_celebrate(res)
	elif res.coins > 0:
		Sfx.play("coin")
		coins_fx.amount = 14
		coins_fx.restart()
		_play("wave")
	elif res.energy > 0:
		Sfx.play("coin")
	busy = false
	spun.emit(res)
	return res


func _celebrate(_res: Dictionary) -> void:
	Sfx.play("bigwin")
	Sfx.buzz(120)
	coins_fx.amount = 40
	coins_fx.restart()
	_play("joy")
	var tw := create_tween()
	for l in lamps:
		tw.parallel().tween_property(l, "light_energy", 4.0, 0.15)
	tw.tween_interval(0.3)
	for l in lamps:
		tw.parallel().tween_property(l, "light_energy", 1.2, 0.8)
	var base := cam.position
	var sh := create_tween()
	for k in 5:
		sh.tween_property(cam, "position", base + Vector3(randf_range(-0.06, 0.06), randf_range(-0.05, 0.05), 0), 0.04)
	sh.tween_property(cam, "position", base, 0.06)


func _process(dt: float) -> void:
	t += dt
	for i in gears.size():
		gears[i].rotation.y += dt * _gear_speed * (1.0 if i % 2 == 0 else -1.6)
	# un tic la fiecare simbol care trece prin dreptul ferestrei (doar prima rolă, ca sunetul să nu se îngrămădească)
	if busy and reels.size() > 0:
		var idx := int(floor((reels[0].rotation.x + step * 0.5) / step))
		if idx != _tick[0]:
			_tick[0] = idx
			Sfx.play("tick", 0.9 + randf() * 0.2)
	if not busy and cam:
		cam.position.x = sin(t * 0.25) * 0.12
	for l in lamps:
		if not busy:
			l.light_energy = 1.2 + sin(t * 3.1 + l.position.x) * 0.05
