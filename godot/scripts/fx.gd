class_name Fx
extends RefCounted
## Efecte vizuale scurte, construite după regulile de meserie din effekseer-vfx-skill
## (references/craft.md, timing.md, layering.md), dar direct în Godot, fără Effekseer:
##   1. structură în timp: anticipare → contact (2–5 cadre) → corp → mișcare secundară → disipare (cea mai lungă);
##   2. valori în straturi: miez alb-fierbinte, corp saturat, materie mai închisă (praf, fum, cioburi);
##   3. forma se schimbă: arcele rupte se lărgesc și sunt erodate, nu doar scalate și estompate;
##   4. viteze variate: scânteile țâșnesc, apoi încetinesc și cad;
##   5. reacție pe ecran (tremur, bliț) – o face apelantul.
## Bugete mici (≤ 60 de particule pe efect), fără straturi aditive de mărimea ecranului.
## Toate funcțiile primesc un părinte Node3D (din scenă), o poziție globală și o scară `s`.

static var _tex := {}


# ---------------- texturi generate o singură dată ----------------
static func tex(kind: String) -> Texture2D:
	if _tex.has(kind):
		return _tex[kind]
	var t: Texture2D
	match kind:
		"star":
			# stea cu 4 colțuri (sclipire / bliț de contact)
			t = _paint(64, func(p: Vector2) -> float:
				var d := p.length()
				var cross := maxf(exp(-absf(p.x) * 26.0) * (1.0 - absf(p.y)), exp(-absf(p.y) * 26.0) * (1.0 - absf(p.x)))
				return clampf(cross * 1.2 + exp(-d * d * 18.0), 0.0, 1.0))
		"streak":
			t = _paint(32, func(p: Vector2) -> float:
				return clampf(exp(-p.x * p.x * 40.0) * (1.0 - absf(p.y)) * 1.4, 0.0, 1.0))
		"puff":
			# fum / praf: pată moale cu marginea zdrențuită (zgomot)
			var nz := FastNoiseLite.new()
			nz.frequency = 0.09
			t = _paint(64, func(p: Vector2) -> float:
				var d := p.length() + nz.get_noise_2d(p.x * 40.0, p.y * 40.0) * 0.35
				return clampf(1.0 - d, 0.0, 1.0) * 0.9)
		"chunk":
			t = _paint(16, func(p: Vector2) -> float:
				return 1.0 if maxf(absf(p.x), absf(p.y * 1.3)) < 0.8 else 0.0)
		"noise":
			var img := Image.create(64, 64, false, Image.FORMAT_L8)
			var nz2 := FastNoiseLite.new()
			nz2.frequency = 0.08
			nz2.fractal_octaves = 3
			for y in 64:
				for x in 64:
					var v := nz2.get_noise_3d(cos(x / 64.0 * TAU) * 6.0, sin(x / 64.0 * TAU) * 6.0, y * 1.2) * 0.5 + 0.5
					img.set_pixel(x, y, Color(v, v, v))
			img.generate_mipmaps()
			t = ImageTexture.create_from_image(img)
	_tex[kind] = t
	return t


static func _paint(n: int, f: Callable) -> Texture2D:
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var p := Vector2(x - n / 2.0 + 0.5, y - n / 2.0 + 0.5) / (n / 2.0)
			img.set_pixel(x, y, Color(1, 1, 1, f.call(p)))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func _mat(kind: String, col: Color, add := true, billboard := true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if add else BaseMaterial3D.BLEND_MODE_MIX
	m.albedo_texture = tex(kind)
	m.albedo_color = col
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_fog = true
	if billboard:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	return m


static func _free_after(n: Node, secs: float) -> void:
	# tween-ul aparține nodului: dacă scena se schimbă între timp, dispare odată cu el
	var tw := n.create_tween()
	tw.tween_interval(secs)
	tw.tween_callback(n.queue_free)


static func _curve(points: Array) -> Curve:
	var c := Curve.new()
	for p in points:
		c.add_point(Vector2(p[0], p[1]))
	return c


static func _ramp(cols: Array) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(cols.map(func(c): return c[0]))
	g.colors = PackedColorArray(cols.map(func(c): return c[1]))
	return g


# ---------------- straturi ----------------
## Contactul: o stea albă, 1.5–2× corpul, care apare într-un cadru și dispare în ~4 cadre.
static func flash(parent: Node3D, at: Vector3, s := 1.0, col := Color(1.0, 0.95, 0.8)) -> void:
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2.ONE * 2.6 * s
	q.mesh = qm
	var m := _mat("star", Color(col.r * 3.0, col.g * 3.0, col.b * 3.0), true, true)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	q.material_override = m
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(q)
	q.global_position = at
	q.rotation.z = randf() * TAU
	q.scale = Vector3.ONE * 0.6
	var tw := q.create_tween()
	tw.tween_property(q, "scale", Vector3.ONE * 1.15, 0.033)
	tw.tween_property(q, "scale", Vector3.ONE * 0.2, 0.06)
	tw.parallel().tween_property(m, "albedo_color:a", 0.0, 0.06)
	tw.tween_callback(q.queue_free)


## Arce rupte (nu inele întregi): 3–5 fâșii de 60–200°, fiecare cu raza, înclinarea și grosimea ei,
## care se deschid cu încetinire și sunt erodate spre final.
static func arcs(parent: Node3D, at: Vector3, s := 1.0, col := Color("ffc84a"), n := 4, life := 0.42, facing := Vector3.BACK) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/fx_arc.gdshader")
	mat.set_shader_parameter("color", col)
	mat.set_shader_parameter("noise", tex("noise"))
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = at
	root.look_at(at + facing, Vector3.UP if absf(facing.y) < 0.9 else Vector3.FORWARD)
	for i in n:
		var sweep := deg_to_rad(randf_range(60.0, 200.0))
		var r := randf_range(0.55, 1.0) * s
		var w := randf_range(0.06, 0.14) * s
		var mi := MeshInstance3D.new()
		mi.mesh = _arc_mesh(r, w, sweep)
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.rotation = Vector3(randf_range(-0.5, 0.5), randf_range(-0.5, 0.5), randf() * TAU)
		mi.scale = Vector3.ONE * 0.35
		root.add_child(mi)
		var l := life * randf_range(0.8, 1.15)
		var tw := mi.create_tween()
		tw.tween_property(mi, "scale", Vector3.ONE * randf_range(1.3, 1.8), l).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_method(func(v: float): mi.set_instance_shader_parameter("life", v), 0.0, 1.0, l).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_free_after(root, life * 1.3)


static func _arc_mesh(r: float, w: float, sweep: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 18
	for i in seg:
		var a0 := sweep * i / seg
		var a1 := sweep * (i + 1) / seg
		var u0 := float(i) / seg
		var u1 := float(i + 1) / seg
		var p := [Vector3(cos(a0), sin(a0), 0) * (r - w), Vector3(cos(a0), sin(a0), 0) * (r + w),
			Vector3(cos(a1), sin(a1), 0) * (r - w), Vector3(cos(a1), sin(a1), 0) * (r + w)]
		var uv := [Vector2(u0, 0), Vector2(u0, 1), Vector2(u1, 0), Vector2(u1, 1)]
		for k in [0, 1, 2, 2, 1, 3]:
			st.set_uv(uv[k])
			st.add_vertex(p[k])
	return st.commit()


## Scântei în două trepte: țâșnesc repede, apoi încetinesc și cad (nu viteză constantă în linie).
## `dir` = direcția principală (spray-ul merge în sensul loviturii, nu ca o sferă simetrică).
static func sparks(parent: Node3D, at: Vector3, s := 1.0, col := Color("ffd27a"), count := 26, dir := Vector3.UP, spread := 70.0) -> void:
	for tier in 2:
		var p := CPUParticles3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.05, 0.32) * s * (1.0 if tier == 0 else 0.6)
		p.mesh = qm
		p.material_override = _mat("streak", Color(col.r * 2.2, col.g * 2.2, col.b * 2.2), true, false)
		p.amount = count if tier == 0 else count / 2
		p.lifetime = 0.55 if tier == 0 else 0.9
		p.one_shot = true
		p.explosiveness = 0.95
		p.direction = dir
		p.spread = spread
		p.initial_velocity_min = 5.0 * s
		p.initial_velocity_max = 9.0 * s if tier == 0 else 5.0 * s
		p.damping_min = 9.0 * s
		p.damping_max = 14.0 * s
		p.gravity = Vector3(0, -9.0, 0) * s
		p.particle_flag_align_y = true
		p.scale_amount_curve = _curve([[0.0, 1.0], [0.6, 0.7], [1.0, 0.0]])
		p.color_ramp = _ramp([[0.0, Color(1, 1, 1, 1)], [0.5, Color(1, 0.8, 0.5, 1)], [1.0, Color(1, 0.4, 0.2, 0)]])
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(p)
		p.global_position = at
		p.emitting = true
		_free_after(p, p.lifetime + 0.2)


## Sclipiri cu 4 colțuri: apar, stau puțin, apoi se strâng (pop → hold → pinch).
static func sparkle(parent: Node3D, at: Vector3, s := 1.0, col := Color(1.0, 0.92, 0.6), count := 8, radius := 0.8) -> void:
	var p := CPUParticles3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2.ONE * 0.42 * s
	p.mesh = qm
	p.material_override = _mat("star", Color(col.r * 2.5, col.g * 2.5, col.b * 2.5))
	p.amount = count
	p.lifetime = 0.75
	p.one_shot = true
	p.explosiveness = 0.55
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius * s
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 0.15 * s
	p.angle_min = 0.0
	p.angle_max = 45.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	p.scale_amount_curve = _curve([[0.0, 0.0], [0.12, 1.15], [0.55, 0.9], [1.0, 0.0]])
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	p.global_position = at
	p.emitting = true
	_free_after(p, 1.0)


## Materie: praf / fum alfa (nu aditiv), mai închis, care rămâne după ce lumina s-a stins
## și se rostogolește încet la sol. Trăiește cel mai mult (disiparea).
static func dust(parent: Node3D, at: Vector3, s := 1.0, col := Color(0.82, 0.74, 0.66), count := 12, life := 1.3) -> void:
	var p := CPUParticles3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2.ONE * 0.9 * s
	p.mesh = qm
	p.material_override = _mat("puff", col, false)
	p.amount = count
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 0.9
	p.direction = Vector3(0, 0.25, 0)
	p.spread = 180.0
	p.flatness = 0.75
	p.initial_velocity_min = 1.2 * s
	p.initial_velocity_max = 2.4 * s
	p.damping_min = 2.5 * s
	p.damping_max = 3.5 * s
	p.gravity = Vector3(0, 0.25, 0) * s
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.angular_velocity_min = -40.0
	p.angular_velocity_max = 40.0
	p.scale_amount_curve = _curve([[0.0, 0.4], [0.3, 1.0], [1.0, 1.6]])
	p.color_ramp = _ramp([[0.0, Color(1, 1, 1, 0.0)], [0.08, Color(1, 1, 1, 0.75)], [0.6, Color(0.9, 0.9, 0.9, 0.4)], [1.0, Color(0.8, 0.8, 0.8, 0.0)]])
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	p.global_position = at
	p.emitting = true
	_free_after(p, life + 0.2)


## Cioburi / bucăți care zboară și cad sub gravitație (scut spart, piatră lovită).
static func shards(parent: Node3D, at: Vector3, s := 1.0, col := Color(0.6, 0.85, 1.0), count := 18, add := true) -> void:
	var p := CPUParticles3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.16, 0.24) * s
	p.mesh = qm
	p.material_override = _mat("chunk", Color(col.r * (1.8 if add else 1.0), col.g * (1.8 if add else 1.0), col.b * (1.8 if add else 1.0)), add, false)
	p.amount = count
	p.lifetime = 1.0
	p.one_shot = true
	p.explosiveness = 0.9
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.4 * s
	p.direction = Vector3(0, 0.6, 0.4)
	p.spread = 80.0
	p.initial_velocity_min = 2.5 * s
	p.initial_velocity_max = 5.0 * s
	p.gravity = Vector3(0, -11.0, 0) * s
	p.angular_velocity_min = -540.0
	p.angular_velocity_max = 540.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.3
	p.scale_amount_curve = _curve([[0.0, 1.0], [0.75, 1.0], [1.0, 0.0]])
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	p.global_position = at
	p.emitting = true
	_free_after(p, 1.2)


## Mote care urcă încet (disiparea pentru câștiguri, upgrade, vindecare): lumini mici, sclipesc.
static func motes(parent: Node3D, at: Vector3, s := 1.0, col := Color(1.0, 0.85, 0.5), count := 14, life := 1.6, radius := 0.9) -> void:
	var p := CPUParticles3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2.ONE * 0.18 * s
	p.mesh = qm
	p.material_override = _mat("star", Color(col.r * 2.0, col.g * 2.0, col.b * 2.0))
	p.amount = count
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 0.4
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius * s
	p.direction = Vector3.UP
	p.spread = 15.0
	p.initial_velocity_min = 0.6 * s
	p.initial_velocity_max = 1.4 * s
	p.gravity = Vector3(0, 0.4, 0) * s
	p.damping_min = 0.3
	p.damping_max = 0.6
	p.scale_amount_curve = _curve([[0.0, 0.0], [0.15, 1.0], [0.7, 0.8], [1.0, 0.0]])
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	p.global_position = at
	p.emitting = true
	_free_after(p, life + 0.2)


## Inele care urcă (upgrade / scut / vindecare): fără bliț de contact, apariție lentă, ușor overshoot.
static func rising_halos(parent: Node3D, at: Vector3, s := 1.0, col := Color(1.0, 0.85, 0.45), n := 3) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/fx_arc.gdshader")
	mat.set_shader_parameter("color", col)
	mat.set_shader_parameter("noise", tex("noise"))
	mat.set_shader_parameter("intensity", 1.8)
	for i in n:
		var mi := MeshInstance3D.new()
		mi.mesh = _arc_mesh(1.0 * s, 0.05 * s, TAU * 0.92)
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)
		mi.global_position = at
		mi.rotation = Vector3(-PI / 2, 0, randf() * TAU)
		mi.scale = Vector3.ONE * 0.5
		mi.set_instance_shader_parameter("life", 1.0)
		var d := i * 0.16
		var tw := mi.create_tween()
		tw.tween_interval(d)
		tw.tween_method(func(v: float): mi.set_instance_shader_parameter("life", v), 1.0, 0.0, 0.25)
		tw.parallel().tween_property(mi, "scale", Vector3.ONE * (1.0 - i * 0.18), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(mi, "global_position:y", at.y + (1.8 + i * 0.5) * s, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_method(func(v: float): mi.set_instance_shader_parameter("life", v), 0.0, 1.0, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(mi.queue_free)


# ---------------- efecte compuse ----------------
## Lovitură grea (atac): contact → arce rupte → scântei în direcția loviturii → praf → bucăți.
static func hit_heavy(parent: Node3D, at: Vector3, s := 1.0, dir := Vector3.UP, col := Color("ffc84a")) -> void:
	flash(parent, at, s * 1.2)
	arcs(parent, at, s * 1.1, col, 5, 0.38)
	sparks(parent, at, s, col, 24, dir, 65.0)
	dust(parent, at - Vector3(0, 0.2 * s, 0), s * 1.2, Color(0.8, 0.72, 0.64), 10, 1.4)
	shards(parent, at, s * 0.8, Color(0.85, 0.78, 0.68), 12, false)


## Scut care parează / se sparge: inel care se rupe în cioburi albastre, fără bliț alb mare.
static func shield_break(parent: Node3D, at: Vector3, s := 1.0) -> void:
	arcs(parent, at, s * 1.3, Color("8fd0ff"), 4, 0.5)
	shards(parent, at, s, Color(0.55, 0.85, 1.0), 22, true)
	sparkle(parent, at, s, Color(0.75, 0.9, 1.0), 6, 1.0)


## Câștig: sclipiri + mote care urcă; `big` adaugă bliț și arce aurii.
static func win(parent: Node3D, at: Vector3, s := 1.0, big := false) -> void:
	if big:
		# corpul rămâne lizibil: arcele sunt mici față de aparat (regula „fără pată albă”)
		flash(parent, at, s * 0.7)
		arcs(parent, at, s * 0.65, Color("ffd24a"), 4, 0.45)
		sparks(parent, at, s * 0.8, Color("ffe08a"), 18, Vector3.UP, 55.0)
	sparkle(parent, at, s, Color(1.0, 0.92, 0.6), 10 if big else 6, 1.0)
	motes(parent, at, s, Color(1.0, 0.85, 0.5), 12 if big else 7)
