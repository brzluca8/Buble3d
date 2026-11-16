extends Node3D
## Pagina separată a rotirilor: Mecanismul – un automat Neon noir (grafit, crom, neon) pe o
## stradă udă, noaptea, în ploaie, cu 3 role 3D. Rezultatul vine din Game.spin() (data/spin_table.json);
## rolele doar îl arată: maneta coboară, rolele accelerează, se rotesc și frânează pe rând,
## cu un mic recul. Nox, asistentul robot, plutește alături și reacționează la câștiguri.
## Sabotajul și spargerea se joacă în glob: pagina pune Game.pending_action și schimbă scena.

signal spun(res: Dictionary)

const WZ := 2.05                                 # centrul ferestrei rolelor
const REEL_R := 0.6
const REEL_X := [-0.86, 0.0, 0.86]
const REEL_Z := 0.02
## Simbolurile: iconița și culoarea neonului (pe jeton negru).
const SYM := {
	"coin": ["coins", Color("ffc94a")], "bag": ["hand-coins", Color("ff9a3a")], "gem": ["gem", Color("37e8f5")],
	"energy": ["zap", Color("7ab8ff")], "shield": ["shield", Color("8a7aff")], "hammer": ["hammer", Color("ff4a5a")],
	"shovel": ["venetian-mask", Color("c24aff")], "chest": ["package", Color("3aff9a")], "card": ["layers", Color("ff3fa4")],
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


# ---------------- strada: noapte, ploaie, neon ----------------
func _environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("030308")
	sky_mat.sky_horizon_color = Color("1a0c2a")
	sky_mat.ground_horizon_color = Color("0c0814")
	sky_mat.ground_bottom_color = Color("020205")
	sky_mat.sun_angle_max = 0.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("5a5a8a")
	env.ambient_light_energy = 0.35
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 1.0
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 0.85
	env.fog_enabled = true
	env.fog_light_color = Color("1c0e2e")
	env.fog_density = 0.03
	env.fog_sky_affect = 0.3
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.1
	env.adjustment_saturation = 1.15
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	# cheie rece de sus (felinar), magenta din stânga, turcoaz din dreapta
	var key := SpotLight3D.new()
	key.light_color = Color("dfe6ff")
	key.light_energy = 6.0
	key.spot_range = 22.0
	key.spot_angle = 30.0
	key.spot_attenuation = 0.6
	key.shadow_enabled = true
	add_child(key)
	key.look_at_from_position(Vector3(1.5, 10.0, 7.0), Vector3(0, 2.0, 0))
	for it in [[Vector3(-5.0, 3.0, 2.5), Color("ff3fa4")], [Vector3(5.0, 3.5, 2.0), Color("37e8f5")]]:
		var o := OmniLight3D.new()
		o.light_color = it[1]
		o.light_energy = 3.5
		o.omni_range = 9.0
		o.position = it[0]
		add_child(o)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color("8a6aff")
	rim.light_energy = 0.6
	add_child(rim)
	rim.look_at_from_position(Vector3(0, 6, -8), Vector3(0, 2, 0))


func _room() -> void:
	# asfalt ud: aproape negru, foarte lucios, cu bălți (zgomot în rugozitate)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	floor_mi.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color("0b0b12")
	fm.roughness_texture = _puddle_tex()
	fm.roughness = 1.0
	fm.metallic_specular = 1.0
	fm.uv1_scale = Vector3(7, 7, 1)
	floor_mi.material_override = fm
	add_child(floor_mi)
	# reflexii false ale neonului pe asfaltul ud (benzi luminoase întinse pe sol)
	for it in [[-3.4, Color(1.0, 0.25, 0.64, 0.35)], [3.4, Color(0.2, 0.9, 0.96, 0.3)], [0.0, Color(0.2, 0.9, 0.96, 0.18)]]:
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(1.6, 9.0)
		q.mesh = qm
		var gm := StandardMaterial3D.new()
		gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		gm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		gm.albedo_texture = Proc.tex("soft")
		gm.albedo_color = it[1]
		q.material_override = gm
		q.rotation.x = -PI / 2
		q.position = Vector3(it[0], 0.02, 1.5)
		add_child(q)
	# zidul din spate: beton închis, firme de neon, ferestre aprinse
	Proc.add(self, Proc.box(30, 14, 0.2), Proc.mat(Color("101018"), {"rough": 0.8}), Vector3(0, 7, -5))
	var pink := Proc.mat(Color("ffb0dc"), {"emit": Color("ff3fa4"), "energy": 4.0})
	var cyan := Proc.mat(Color("9ff8ff"), {"emit": Color("37e8f5"), "energy": 4.0})
	# firmă verticală stânga (bare magenta), panou orizontal dreapta (turcoaz), linii pe zid
	for k in 5:
		Proc.add(self, Proc.box(0.9, 0.06, 0.06), pink, Vector3(-4.6, 3.2 + k * 0.7, -4.8))
	Proc.add(self, Proc.box(0.06, 3.6, 0.06), pink, Vector3(-5.1, 4.6, -4.8))
	Proc.add(self, Proc.box(2.6, 0.06, 0.06), cyan, Vector3(4.4, 6.2, -4.8))
	Proc.add(self, Proc.box(2.6, 0.06, 0.06), cyan, Vector3(4.4, 5.2, -4.8))
	Proc.add(self, Proc.box(0.06, 1.0, 0.06), cyan, Vector3(3.1, 5.7, -4.8))
	Proc.add(self, Proc.box(0.06, 1.0, 0.06), cyan, Vector3(5.7, 5.7, -4.8))
	for it in [[-4.6, Color(1.0, 0.25, 0.64, 0.4)], [4.4, Color(0.2, 0.9, 0.96, 0.35)]]:
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(5.0, 6.0)
		q.mesh = qm
		var gm := StandardMaterial3D.new()
		gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		gm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		gm.albedo_texture = Proc.tex("soft")
		gm.albedo_color = it[1]
		q.material_override = gm
		q.position = Vector3(it[0], 5.0, -4.7)
		add_child(q)
	# orașul în depărtare, peste zid: turnuri negre cu ferestre aprinse
	var tower := Proc.mat(Color("07070c"), {"rough": 0.9})
	var win_tex := _windows_tex()
	Proc.reseed(11)
	for i in 12:
		var w := 1.4 + Proc.rnd() * 2.2
		var h := 6.0 + Proc.rnd() * 10.0
		var x := -14.0 + i * 2.6 + Proc.rnd()
		var t := Proc.add(self, Proc.box(w, h, 1.0), tower, Vector3(x, 14.0 + h * 0.5 - 4.0, -14.0 - Proc.rnd() * 6.0))
		var wm := StandardMaterial3D.new()
		wm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		wm.albedo_texture = win_tex
		wm.albedo_color = Color("ffc890") if i % 3 else Color("9ff0ff")
		wm.uv1_triplanar = true
		wm.uv1_scale = Vector3(0.4, 0.4, 0.4)
		t.material_override = wm
	# o bordură de trotuar cu LED în fața automatului
	Proc.add(self, Proc.box(9.0, 0.12, 0.3), Proc.mat(Color("1a1b22"), {"rough": 0.6}), Vector3(0, 0.06, -1.2))


func _puddle_tex() -> Texture2D:
	var n := 256
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.frequency = 0.012
	noise.fractal_octaves = 4
	for y in n:
		for x in n:
			var v := noise.get_noise_2d(x, y) * 0.5 + 0.5
			var r := 0.12 if v > 0.55 else lerpf(0.3, 0.45, v * 2.0)     # bălți lucioase
			img.set_pixel(x, y, Color(r, r, r))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _windows_tex() -> Texture2D:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color.BLACK)
	Proc.reseed(5)
	for gy in 8:
		for gx in 8:
			if Proc.rnd() < 0.35:
				var c := Color(1, 1, 1) * (0.5 + Proc.rnd() * 0.5)
				for y in range(gy * 8 + 2, gy * 8 + 6):
					for x in range(gx * 8 + 2, gx * 8 + 5):
						img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


# ---------------- automatul ----------------
func _machine() -> void:
	var m := Models.instance("mecanism")
	if m == null:
		# rezervă procedurală: dulap simplu de lac cu ramă aurie
		m = Node3D.new()
		Proc.add(m, Proc.box(3.4, 3.4, 1.6), Proc.mat(Color("101218"), {"rough": 0.2}), Vector3(0, 1.9, -0.1))
		Proc.add(m, Proc.box(2.76, 1.6, 0.1), Proc.mat(Color("d9b56c"), {"metal": 0.9, "rough": 0.3}), Vector3(0, WZ, -0.7))
	add_child(m)
	lever = m.find_child("Maneta", true, false) as Node3D
	for i in 3:
		var g := m.find_child("Roata%d" % i, true, false) as Node3D
		if g:
			gears.append(g)
	# lumina interioară a ferestrei și neonul haloului (pulsează la câștig)
	var win := OmniLight3D.new()
	win.light_color = Color("cfe8ff")
	win.light_energy = 1.2
	win.omni_range = 2.6
	win.position = Vector3(0, WZ + 0.5, 1.4)
	add_child(win)
	for it in [[Vector3(0, 4.05, 0.8), Color("ff3fa4")], [Vector3(0, 1.0, 1.2), Color("ffb43a")]]:
		var l := OmniLight3D.new()
		l.light_color = it[1]
		l.light_energy = 1.2
		l.omni_range = 3.0
		l.position = it[0]
		add_child(l)
		lamps.append(l)


func _reels() -> void:
	var enamel := Proc.mat(Color("1a1c26"), {"rough": 0.3, "metal": 0.3})
	var gold := Proc.mat(Color("d8dde6"), {"metal": 1.0, "rough": 0.15})
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
	quad.size = Vector2(0.24, 0.24)
	var tok_mats := {}
	var icon_mats := {}
	var ring_mats := {}
	for s in SYM:
		ring_mats[s] = Proc.mat(SYM[s][1], {"emit": SYM[s][1], "energy": 2.2})
		tok_mats[s] = Proc.mat(Color("07080c"), {"rough": 0.15, "emit": SYM[s][1], "energy": 0.12})
		var im := StandardMaterial3D.new()
		im.albedo_texture = UiKit.icon(SYM[s][0])
		im.albedo_color = SYM[s][1] * 1.6
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
		reel.rotation.x = randi_range(0, syms.size() - 1) * step
		reels.append(reel)


func _majordom() -> void:
	majordom = Models.instance("mascot")
	if majordom == null:
		return
	add_child(majordom)
	majordom.scale = Vector3.ONE * 0.62
	majordom.position = Vector3(-2.5, 0.35, 1.4)
	majordom.rotation.y = 0.45
	_anim = Models.find_anim(majordom)
	_play("idle")
	var eq: Dictionary = Game.equipped
	# aceeași garderobă ca în glob: culoarea carcasei și a papionului
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
	# ploaie: picături lungi, subțiri, luminate de neon
	var qm := QuadMesh.new()
	qm.size = Vector2(0.012, 0.45)
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	dm.albedo_color = Color(0.7, 0.85, 1.0, 0.35)
	qm.material = dm
	dust = CPUParticles3D.new()
	dust.mesh = qm
	dust.amount = 220
	dust.lifetime = 0.9
	dust.preprocess = 1.0
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(7, 0.5, 4)
	dust.position = Vector3(0, 8.5, 1.0)
	dust.direction = Vector3(0.05, -1, 0)
	dust.spread = 2.0
	dust.initial_velocity_min = 10.0
	dust.initial_velocity_max = 13.0
	dust.gravity = Vector3.ZERO
	dust.scale_amount_min = 0.7
	dust.scale_amount_max = 1.2
	add_child(dust)


func _place_camera() -> void:
	cam.position = Vector3(0.0, 3.3, 13.6)
	cam.look_at(Vector3(-0.15, 1.95, 0.0))


func _apply_quality() -> void:
	var q := Game.quality
	env.glow_enabled = q != "mic"
	dust.amount = {"mic": 80, "mediu": 220, "mare": 360}[q]
	get_viewport().msaa_3d = Viewport.MSAA_2X if q == "mare" else Viewport.MSAA_DISABLED
	get_viewport().scaling_3d_scale = {"mic": 0.75, "mediu": 0.9, "mare": 1.0}[q]
	for c in find_children("*", "SpotLight3D", true, false):
		(c as SpotLight3D).shadow_enabled = q != "mic"


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
		gears[i].rotation.z += dt * _gear_speed * (1.0 if i % 2 == 0 else -1.6)
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
