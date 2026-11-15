class_name Proc
extends RefCounted
## Geometrie procedurală (portată din prototipul web). Este varianta implicită
## pentru orice piesă care nu are încă un model în res://models/.

# ---------------- aleator determinist ----------------
static var _sd := 7

static func reseed(s: int) -> void:
	_sd = s

static func rnd() -> float:
	_sd = (_sd * 16807) % 2147483647
	return float(_sd) / 2147483647.0


# ---------------- texturi ----------------
static var _tex := {}

static func _bricks(w: int, h: int, rows: int, cols: int, base: Color, mortar: Color, jitter: float, gap: int) -> ImageTexture:
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	img.fill(mortar)
	var bw := w / cols
	var bh := h / rows
	for r in rows:
		for c in range(-1, cols + 1):
			var v := 1.0 - rnd() * jitter
			var x := c * bw + (r % 2) * bw / 2
			var rect := Rect2i(x + gap, r * bh + gap, bw - gap * 2, bh - gap * 2).intersection(Rect2i(0, 0, w, h))
			if rect.size.x > 0:
				img.fill_rect(rect, Color(base.r * v, base.g * v, base.b * v))
	# pete fine
	for i in 900:
		var px := int(rnd() * w)
		var py := int(rnd() * h)
		var c0 := img.get_pixel(px, py)
		img.set_pixel(px, py, c0.darkened(0.08 + rnd() * 0.1))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

static func _noise_tex(kind: int, freq: float, ramp: Array) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.noise_type = kind
	n.frequency = freq
	n.seed = 7
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray(ramp)
	var t := NoiseTexture2D.new()
	t.width = 256
	t.height = 256
	t.seamless = true
	t.noise = n
	t.color_ramp = g
	t.generate_mipmaps = true
	return t

static func _roof_tex() -> ImageTexture:
	# solzi de acoperiș: semicercuri suprapuse
	var w := 128
	var img := Image.create(w, w, false, Image.FORMAT_RGB8)
	for y in w:
		for x in w:
			var row := y / 16
			var ox := (row % 2) * 16
			var cx := float(((x + ox) / 32) * 32 + 16 - ox)
			var cy := float(row * 16)
			var d := Vector2(x - cx, y - cy).length() / 16.0
			var shade := clampf(1.0 - d * 0.35, 0.6, 1.0)
			if d > 0.92 and d < 1.05:
				shade *= 0.72
			img.set_pixel(x, y, Color(0.82 * shade + 0.18, 0.92 * shade + 0.08, 0.92 * shade + 0.08))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

static func tex(name: String) -> Texture2D:
	if _tex.has(name):
		return _tex[name]
	reseed(3)
	var t: Texture2D
	match name:
		"stone": t = _bricks(256, 256, 8, 4, Color(1, 0.985, 0.95), Color(0.62, 0.56, 0.47), 0.09, 1)
		"cobble": t = _bricks(256, 256, 8, 4, Color(1, 0.97, 0.9), Color(0.56, 0.5, 0.41), 0.12, 3)
		"roof": t = _roof_tex()
		"grass": t = _noise_tex(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.04, [Color(0.82, 0.9, 0.8), Color(1, 1, 1)])
		"rock": t = _noise_tex(FastNoiseLite.TYPE_CELLULAR, 0.03, [Color(0.7, 0.65, 0.75), Color(1, 0.98, 1)])
		"soft":
			# pată moale (nori, ceață, strălucire)
			var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
			for y in 128:
				for x in 128:
					var d := Vector2(x - 63.5, y - 63.5).length() / 64.0
					var a := clampf(1.0 - d, 0.0, 1.0)
					img.set_pixel(x, y, Color(1, 1, 1, a * a * (3.0 - 2.0 * a)))
			img.generate_mipmaps()
			t = ImageTexture.create_from_image(img)
	_tex[name] = t
	return t


# ---------------- materiale ----------------
static var _mat := {}

static func mat(color: Color, o := {}) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = o.get("rough", 0.6)
	m.metallic = o.get("metal", 0.0)
	if o.has("emit"):
		m.emission_enabled = true
		m.emission = o["emit"]
		m.emission_energy_multiplier = o.get("energy", 1.0)
	if o.has("alpha"):
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color.a = o["alpha"]
	if o.get("double", false):
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if o.has("tex"):
		m.albedo_texture = tex(o["tex"])
		m.uv1_triplanar = true
		var s: float = o.get("uv", 1.0)
		m.uv1_scale = Vector3(s, s, s)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if o.get("unshaded", false):
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

static func M(name: String) -> StandardMaterial3D:
	if _mat.is_empty():
		_mat = {
			"cream": mat(Color("f3e6cf"), {"tex": "stone", "uv": 0.55}),
			"gold": mat(Color("f2b630"), {"metal": 0.8, "rough": 0.3}),
			"teal": mat(Color("20a8a6"), {"metal": 0.3, "rough": 0.35, "tex": "roof", "uv": 1.2}),
			"vio": mat(Color("6d3fc0")),
			"stone": mat(Color("d9c7a3"), {"tex": "cobble", "uv": 0.5}),
			"brown": mat(Color("7a4a2a")),
			"green": mat(Color("4ea04a")),
			"glass": mat(Color("bfeeff"), {"alpha": 0.3, "rough": 0.1, "double": true}),
			"warm": mat(Color("ffd27a"), {"emit": Color("ffa030"), "energy": 2.2}),
			"ped": mat(Color("cdb690"), {"tex": "stone", "uv": 0.55}),
			"iv1": mat(Color("3f9a44")),
			"iv2": mat(Color("5cba50")),
			"gem": mat(Color("7ffff0"), {"emit": Color("20d8c8"), "energy": 2.5}),
			"sky": mat(Color("1a1a66"), {"emit": Color("5b3fd0"), "energy": 1.6}),
			"rock": mat(Color("8a7a8e"), {"rough": 0.9, "tex": "rock", "uv": 0.12}),
			"grass": mat(Color("6fbf4a"), {"rough": 0.9, "tex": "grass", "uv": 0.08}),
			"pink": mat(Color("ff6fa8")),
			"lilac": mat(Color("b07cff")),
			"crystal": mat(Color("5fe0e0"), {"emit": Color("2bb8b0"), "energy": 2.0}),
			"water": mat(Color("5fd8ff"), {"emit": Color("2aa0d0"), "energy": 0.6, "alpha": 0.85}),
			"leafA": mat(Color("4fae4a")),
			"leafB": mat(Color("66c458")),
			"pine": mat(Color("2f7a45")),
		}
	return _mat[name]


# ---------------- plase (cache) ----------------
static var _mesh := {}

static func _cached(key: String, f: Callable) -> Mesh:
	if not _mesh.has(key):
		_mesh[key] = f.call()
	return _mesh[key]

static func cyl(top: float, bottom: float, h: float, seg := 24) -> Mesh:
	return _cached("c%s,%s,%s,%s" % [top, bottom, h, seg], func():
		var c := CylinderMesh.new()
		c.top_radius = top
		c.bottom_radius = bottom
		c.height = h
		c.radial_segments = seg
		c.rings = 1
		return c)

static func sph(r: float, seg := 24, rings := 16) -> Mesh:
	return _cached("s%s,%s,%s" % [r, seg, rings], func():
		var s := SphereMesh.new()
		s.radius = r
		s.height = r * 2.0
		s.radial_segments = seg
		s.rings = rings
		return s)

static func box(w: float, h: float, d: float) -> Mesh:
	return _cached("b%s,%s,%s" % [w, h, d], func():
		var b := BoxMesh.new()
		b.size = Vector3(w, h, d)
		return b)

## Tor orizontal (inelul stă în planul XZ).
static func htor(r: float, t: float, seg := 32, sides := 8) -> Mesh:
	return _cached("t%s,%s,%s,%s" % [r, t, seg, sides], func():
		var m := TorusMesh.new()
		m.inner_radius = r - t
		m.outer_radius = r + t
		m.rings = seg
		m.ring_segments = sides
		return m)

## Arc de tub în planul XY, de la +X spre +Y (ca TorusGeometry din three.js).
static func arc(r: float, t: float, a: float, seg := 24, sides := 6) -> Mesh:
	return _cached("a%s,%s,%s,%s,%s" % [r, t, a, seg, sides], func():
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var P := []
		var N := []
		for i in seg + 1:
			var u := a * i / seg
			var row_p := []
			var row_n := []
			for j in sides + 1:
				var v := TAU * j / sides
				var n := Vector3(cos(v) * cos(u), cos(v) * sin(u), sin(v))
				row_n.append(n)
				row_p.append(Vector3(r * cos(u), r * sin(u), 0) + n * t)
			P.append(row_p)
			N.append(row_n)
		for i in seg:
			for j in sides:
				_quad(st, P[i][j], P[i + 1][j], P[i + 1][j + 1], P[i][j + 1], N[i][j], N[i + 1][j], N[i + 1][j + 1], N[i][j + 1])
		return st.commit())

## Suprafață de revoluție în jurul axei Y; profil = [Vector2(rază, y)] de jos în sus.
static func lathe(pts: Array, seg := 28) -> Mesh:
	return _cached("l%s,%s" % [str(pts), seg], func():
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var n2 := []
		for i in pts.size():
			var a: Vector2 = pts[maxi(i - 1, 0)]
			var b: Vector2 = pts[mini(i + 1, pts.size() - 1)]
			var tg := (b - a).normalized()
			n2.append(Vector2(tg.y, -tg.x))
		for i in pts.size() - 1:
			for j in seg:
				var f0 := TAU * j / seg
				var f1 := TAU * (j + 1) / seg
				var p0: Vector2 = pts[i]
				var p1: Vector2 = pts[i + 1]
				var q0: Vector2 = n2[i]
				var q1: Vector2 = n2[i + 1]
				_quad(st,
					Vector3(p0.x * sin(f0), p0.y, p0.x * cos(f0)), Vector3(p0.x * sin(f1), p0.y, p0.x * cos(f1)),
					Vector3(p1.x * sin(f1), p1.y, p1.x * cos(f1)), Vector3(p1.x * sin(f0), p1.y, p1.x * cos(f0)),
					Vector3(q0.x * sin(f0), q0.y, q0.x * cos(f0)), Vector3(q0.x * sin(f1), q0.y, q0.x * cos(f1)),
					Vector3(q1.x * sin(f1), q1.y, q1.x * cos(f1)), Vector3(q1.x * sin(f0), q1.y, q1.x * cos(f0)))
		return st.commit())

## Adaugă un patrulater în ambele sensuri de parcurgere (vizibil indiferent de orientare).
static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, na: Vector3, nb: Vector3, nc: Vector3, nd: Vector3) -> void:
	for tri in [[a, b, c, na, nb, nc], [a, c, d, na, nc, nd], [a, c, b, na, nc, nb], [a, d, c, na, nd, nc]]:
		for k in 3:
			st.set_normal(tri[k + 3])
			st.set_uv(Vector2(tri[k].x + tri[k].z, tri[k].y))
			st.add_vertex(tri[k])

static func hemi(r: float, seg := 24, rows := 10, top := PI / 2) -> Mesh:
	var pts := []
	for i in rows + 1:
		var th: float = top - top * i / rows   # de la margine spre vârf
		pts.append(Vector2(r * sin(th), r * cos(th)))
	return lathe(pts, seg)


# ---------------- ajutoare de scenă ----------------
static func add(p: Node3D, mesh: Mesh, m: Material, pos := Vector3.ZERO) -> MeshInstance3D:
	var o := MeshInstance3D.new()
	o.mesh = mesh
	o.material_override = m
	o.position = pos
	p.add_child(o)
	return o

static func rot(o: Node3D, x: float, y: float, z: float) -> Node3D:
	o.rotation_order = EULER_ORDER_XYZ
	o.rotation = Vector3(x, y, z)
	return o

static func dome(p: Node3D, r: float, x: float, y: float, z := 0.0, m: Material = null) -> void:
	add(p, hemi(r), m if m else M("teal"), Vector3(x, y, z))
	add(p, cyl(r * 0.07, r * 0.07, r * 0.5, 8), M("gold"), Vector3(x, y + r + 0.15, z))
	add(p, sph(r * 0.13, 8, 8), M("gold"), Vector3(x, y + r + 0.42, z))

static func onion(p: Node3D, r: float, x: float, y: float, z := 0.0) -> void:
	var pts := [Vector2(r, 0), Vector2(r * 1.06, r * 0.28), Vector2(r * 0.96, r * 0.62), Vector2(r * 0.5, r * 0.95), Vector2(r * 0.14, r * 1.2), Vector2(0, r * 1.45)]
	add(p, lathe(pts), M("teal"), Vector3(x, y, z))
	add(p, htor(r * 1.06, 0.04), M("gold"), Vector3(x, y + r * 0.28, z))
	add(p, htor(r * 0.96, 0.035), M("gold"), Vector3(x, y + r * 0.62, z))
	add(p, htor(r, 0.05), M("gold"), Vector3(x, y + 0.02, z))
	add(p, cyl(r * 0.04, r * 0.04, r * 0.6, 6), M("gold"), Vector3(x, y + r * 1.6, z))
	add(p, sph(r * 0.12, 8, 8), M("gold"), Vector3(x, y + r * 1.92, z))

static func arch(p: Node3D, x: float, y: float, z: float, w := 0.3, h := 0.55, ry := 0.0, m: Material = null) -> void:
	var mm: Material = m if m else M("warm")
	var g := Node3D.new()
	g.position = Vector3(x, y, z)
	g.rotation.y = ry
	add(g, box(w, h, 0.08), mm)
	rot(add(g, cyl(w / 2, w / 2, 0.08, 12), mm, Vector3(0, h / 2, 0)), PI / 2, 0, 0)
	add(g, arc(w / 2 + 0.03, 0.025, PI, 12, 5), M("gold"), Vector3(0, h / 2, 0.045))
	add(g, box(w + 0.1, 0.05, 0.1), M("gold"), Vector3(0, -h / 2, 0.04))
	p.add_child(g)

static func cornice(p: Node3D, w: float, d: float, y: float) -> void:
	add(p, box(w + 0.2, 0.1, d + 0.2), M("ped"), Vector3(0, y, 0))

static func column(p: Node3D, x: float, z: float, h: float) -> void:
	add(p, cyl(0.12, 0.14, h, 10), M("cream"), Vector3(x, h / 2, z))
	add(p, cyl(0.19, 0.19, 0.08, 10), M("gold"), Vector3(x, h, z))
	add(p, cyl(0.19, 0.19, 0.08, 10), M("gold"), Vector3(x, 0.04, z))

static func ivy(p: Node3D, x: float, y: float, z: float, n := 5) -> void:
	for i in n:
		add(p, sph(snappedf(0.12 + rnd() * 0.1, 0.02), 6, 5), M("iv1") if i % 2 else M("iv2"), Vector3(x + (rnd() - 0.5) * 0.6, y - rnd() * 0.9, z + rnd() * 0.1))

static func flag(p: Node3D, x: float, y: float, z: float) -> void:
	add(p, cyl(0.025, 0.025, 0.9, 5), M("gold"), Vector3(x, y + 0.45, z))
	add(p, box(0.5, 0.26, 0.02), M("vio"), Vector3(x + 0.27, y + 0.75, z))

static func lantern(p: Node3D, x: float, z: float) -> void:
	add(p, cyl(0.06, 0.08, 0.8, 8), M("gold"), Vector3(x, 0.4, z))
	add(p, sph(0.15, 8, 8), M("warm"), Vector3(x, 0.9, z))


# ---------------- clădiri ----------------
static func building(id: String) -> Node3D:
	M("cream")  # creează materialele/texturile înainte de a fixa seed-ul
	reseed(7 + id.length() * 31)
	var g := Node3D.new()
	g.name = "Procedural"
	match id:
		"palat": _b_palat(g)
		"obs": _b_obs(g)
		"turn": _b_turn(g)
		"mag": _b_mag(g)
		"sera": _b_sera(g)
	return g

static func _b_palat(g: Node3D) -> void:
	add(g, box(5.4, 0.25, 2.8), M("ped"), Vector3(0, 0.12, 0.25))
	add(g, box(4.6, 1.9, 1.9), M("cream"), Vector3(0, 1.2, 0))
	cornice(g, 4.6, 1.9, 2.17)
	add(g, cyl(1.35, 1.45, 3.2), M("cream"), Vector3(0, 1.85, 0.1))
	add(g, htor(1.4, 0.07), M("gold"), Vector3(0, 3, 0.1))
	onion(g, 1.4, 0, 3.45, 0.1)
	flag(g, 0, 5.95, 0.1)
	for s in [-1.0, 1.0]:
		add(g, cyl(0.8, 0.85, 2.8), M("cream"), Vector3(s * 2.2, 1.5, 0))
		add(g, htor(0.83, 0.05), M("gold"), Vector3(s * 2.2, 2.7, 0))
		onion(g, 0.9, s * 2.2, 2.85)
		flag(g, s * 2.2, 4.5, 0)
		arch(g, s * 2.2, 1.8, 0.86, 0.3, 0.6)
		arch(g, s * 1.4, 1.4, 0.96, 0.3, 0.55)
		add(g, box(0.34, 1, 0.05), M("vio"), Vector3(s * 1.15, 1.4, 0.98))
		arch(g, s * 0.5, 2.3, 1.4, 0.28, 0.5, s * 0.37)
		column(g, s * 0.75, 1.6, 1.5)
		ivy(g, s * 1.6, 1.7, 1, 6)
		ivy(g, s * 2.2, 1.9, 0.85, 4)
	arch(g, 0, 0.9, 1.55, 0.8, 1.2)
	add(g, sph(0.22, 10, 8), M("gem"), Vector3(0, 2, 1.58))
	for i in 3:
		add(g, box(2.2, 0.1, 0.45), M("stone"), Vector3(0, 0.05 + i * 0.1, 2.3 - i * 0.4))

static func _b_obs(g: Node3D) -> void:
	add(g, cyl(1.55, 1.65, 0.3), M("ped"), Vector3(0, 0.15, 0))
	add(g, cyl(1.3, 1.4, 1.7), M("cream"), Vector3(0, 1.15, 0))
	add(g, htor(1.35, 0.07), M("gold"), Vector3(0, 2, 0))
	add(g, hemi(1.3, 28, 12), M("vio"), Vector3(0, 2, 0))
	rot(add(g, box(0.5, 1.1, 0.1), M("sky"), Vector3(0, 2.65, 1.15)), -0.5, 0, 0)
	for i in 16:
		var a := rnd() * 6.28
		var b := 0.15 + rnd() * 1.1
		add(g, sph(0.04, 5, 4), M("warm"), Vector3(sin(b) * cos(a) * 1.32, 2 + cos(b) * 1.32, sin(b) * sin(a) * 1.32))
	rot(add(g, cyl(0.18, 0.24, 2.2, 16), M("gold"), Vector3(0.45, 3, 0.7)), -0.9, 0, -0.45)
	add(g, box(2.4, 1.1, 1.2), M("cream"), Vector3(0, 0.55, 1.75))
	arch(g, 0, 0.5, 2.36, 0.6, 0.8)
	for i in 5:
		rot(add(g, box(0.5, 0.08, 0.8), M("vio") if i % 2 else M("cream"), Vector3(-1 + i * 0.5, 1.1, 2.35)), 0.45, 0, 0)
	for s in [-1.0, 1.0]:
		arch(g, s * 0.95, 1.5, 0.97, 0.28, 0.5, s * 0.7)
	ivy(g, -1.3, 1.7, 0.9, 5)

static func _b_turn(g: Node3D) -> void:
	add(g, cyl(1, 1.1, 0.3), M("ped"), Vector3(0, 0.15, 0))
	add(g, cyl(0.8, 0.95, 3.6), M("cream"), Vector3(0, 2.1, 0))
	for y in [1.5, 2.9]:
		add(g, htor(0.99 - y * 0.0417, 0.06), M("gold"), Vector3(0, y, 0))
	add(g, cyl(1.05, 1.05, 0.1), M("gold"), Vector3(0, 3.9, 0))
	onion(g, 1, 0, 3.95)
	flag(g, 0, 5.8, 0)
	arch(g, 0, 0.85, 0.97, 0.5, 0.9, 0, M("brown"))
	add(g, box(0.5, 1.1, 0.05), M("vio"), Vector3(0, 1.95, 0.9))
	arch(g, 0, 3, 0.86, 0.26, 0.55)
	ivy(g, 0.5, 2.2, 0.8, 6)

static func _b_mag(g: Node3D) -> void:
	add(g, box(3, 0.2, 2.4), M("ped"), Vector3(0, 0.1, 0))
	add(g, box(2.8, 1.6, 2.2), M("cream"), Vector3(0, 1, 0))
	cornice(g, 2.8, 2.2, 1.82)
	add(g, cyl(0.001, 2.2, 1.2, 4), M("teal"), Vector3(0, 2.4, 0)).rotation.y = PI / 4
	add(g, sph(0.12, 8, 8), M("gold"), Vector3(0, 3.05, 0))
	for i in 6:
		rot(add(g, box(0.47, 0.08, 1), M("vio") if i % 2 else M("cream"), Vector3(-1.2 + i * 0.48, 1.55, 1.55)), 0.45, 0, 0)
	add(g, box(1.7, 0.85, 0.1), M("warm"), Vector3(0, 0.85, 1.12))
	add(g, box(1.8, 0.06, 0.12), M("gold"), Vector3(0, 1.3, 1.12))
	add(g, box(1.8, 0.06, 0.12), M("gold"), Vector3(0, 0.4, 1.12))
	arch(g, 1.12, 0.7, 1.13, 0.3, 0.8, 0, M("brown"))
	add(g, cyl(0.2, 0.15, 0.3, 8), M("brown"), Vector3(-1.2, 0.15, 1.7))
	add(g, sph(0.3, 8, 6), M("green"), Vector3(-1.2, 0.5, 1.7))
	add(g, sph(0.1, 6, 5), M("pink"), Vector3(-1.1, 0.75, 1.75))
	add(g, box(0.4, 0.4, 0.4), M("brown"), Vector3(1.2, 0.2, 1.7))
	ivy(g, -1.42, 1.5, 0, 5)

static func _b_sera(g: Node3D) -> void:
	add(g, cyl(1.8, 1.9, 0.3), M("ped"), Vector3(0, 0.15, 0))
	var gl := add(g, hemi(1.65, 28, 12), M("glass"), Vector3(0, 0.3, 0))
	gl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in 4:
		add(g, arc(1.65, 0.035, PI, 24, 6), M("gold"), Vector3(0, 0.3, 0)).rotation.y = i * PI / 4
	add(g, htor(1.65, 0.045), M("gold"), Vector3(0, 0.3, 0))
	add(g, htor(1.35, 0.035), M("gold"), Vector3(0, 1.25, 0))
	add(g, htor(0.7, 0.035), M("gold"), Vector3(0, 1.8, 0))
	add(g, sph(0.1, 8, 8), M("gold"), Vector3(0, 1.98, 0))
	add(g, sph(0.28, 10, 8), M("warm"), Vector3(0, 0.75, 0))
	for i in 10:
		var a := i * 0.63
		var r := 0.5 + (i % 3) * 0.4
		var x := cos(a) * r
		var z := sin(a) * r
		add(g, sph(0.28 + (i % 2) * 0.1, 8, 6), M("iv1") if i % 2 else M("iv2"), Vector3(x, 0.55 + (i % 3) * 0.2, z))
		add(g, sph(0.1, 6, 5), M("pink") if i % 3 else M("lilac"), Vector3(x, 0.85 + (i % 3) * 0.2, z))
	arch(g, 0, 0.75, 1.66, 0.5, 0.8, 0, M("brown"))


## Felinarele câștigate cu nivelul (maximum 4).
const LEVEL_SPOTS := [Vector2(-1.6, 2.6), Vector2(1.6, 2.6), Vector2(-2.9, 1.2), Vector2(2.9, 1.2)]

static func level_lanterns(level: int) -> Node3D:
	var g := Node3D.new()
	g.name = "Lanterns"
	for i in mini(level - 1, LEVEL_SPOTS.size()):
		lantern(g, LEVEL_SPOTS[i].x, LEVEL_SPOTS[i].y)
	return g


# ---------------- teren ----------------
## Stâncă low-poly cu fețe plate (ArrayMesh generat).
static func _rock_mesh() -> Mesh:
	var seg := 14
	var rows := 6
	var ring := []
	for i in rows + 1:
		var t := float(i) / rows
		var y := 3.25 - 6.5 * t
		var r := lerpf(7.0, 1.8, t)
		var row := []
		for j in seg:
			var a := TAU * j / seg
			var p := Vector3(sin(a) * r, y, cos(a) * r)
			if i > 0:
				p += Vector3((rnd() - 0.5) * 0.8, (rnd() - 0.5) * 0.4, (rnd() - 0.5) * 0.8)
			row.append(p)
		ring.append(row)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tri := func(a: Vector3, b: Vector3, c: Vector3, out: Vector3):
		var n := (b - a).cross(c - a).normalized()
		if n.dot(out) < 0:
			n = -n
		for v in [a, b, c, a, c, b]:
			st.set_normal(n)
			st.set_uv(Vector2(v.x + v.z, v.y) * 0.25)
			st.add_vertex(v)
	for i in rows:
		for j in seg:
			var a: Vector3 = ring[i][j]
			var b: Vector3 = ring[i][(j + 1) % seg]
			var c: Vector3 = ring[i + 1][(j + 1) % seg]
			var d: Vector3 = ring[i + 1][j]
			var out := Vector3(a.x, 0, a.z).normalized() + Vector3(0, -0.4, 0)
			tri.call(a, b, c, out)
			tri.call(a, c, d, out)
	var tip := Vector3(0, -3.6, 0)
	for j in seg:
		tri.call(ring[rows][j], ring[rows][(j + 1) % seg], tip, Vector3.DOWN)
	return st.commit()

static func terrain() -> Node3D:
	M("cream")
	reseed(7)
	var isl := Node3D.new()
	isl.name = "Procedural"
	add(isl, _rock_mesh(), M("rock"), Vector3(0, -3.75, 0))
	add(isl, cyl(7.2, 7, 0.5, 40), M("grass"), Vector3(0, -0.25, 0))
	for i in 5:
		var a := i * 1.3 + 0.4
		add(isl, cyl(0.35, 0.001, 1.4, 5), M("crystal"), Vector3(cos(a) * 2.2, -5.2, sin(a) * 2.2))
	for i in 16:
		var a := i * 0.4 + rnd() * 0.3
		add(isl, cyl(0.025, 0.015, snappedf(1 + rnd() * 1.6, 0.1), 4), M("iv1"), Vector3(cos(a) * 6.6, -0.9 - rnd() * 0.3, sin(a) * 6.6))
	for i in 7:
		var a := rnd() * 6.28
		add(isl, sph(snappedf(0.4 + rnd() * 0.4, 0.1), 6, 4), M("rock"), Vector3(cos(a) * 6.7, 0.15, sin(a) * 6.7))
	return isl


# ---------------- piață, fântână, vegetație ----------------
static func plaza() -> Node3D:
	M("cream")
	reseed(11)
	var isl := Node3D.new()
	isl.name = "Plaza"
	add(isl, lathe([Vector2(3.3, 0), Vector2(2.3, 0)], 48), M("stone"), Vector3(0, 0.02, 0.3))
	add(isl, box(1.8, 0.04, 4.6), M("stone"), Vector3(0, 0.02, 5.1))
	add(isl, cyl(1.6, 1.7, 0.5), M("stone"), Vector3(0, 0.25, 0.3))
	add(isl, cyl(1.35, 1.35, 0.1), M("water"), Vector3(0, 0.5, 0.3))
	add(isl, cyl(0.18, 0.25, 1.1, 12), M("stone"), Vector3(0, 1, 0.3))
	add(isl, cyl(0.75, 0.5, 0.2), M("stone"), Vector3(0, 1.5, 0.3))
	var gem := add(isl, sph(0.25, 6, 3), M("gem"), Vector3(0, 2, 0.3))
	gem.name = "Gem"

	for i in 20:
		var a := rnd() * 6.28
		var r := 5.7 + rnd() * 0.9
		var x := cos(a) * r
		var z := sin(a) * r
		if absf(x) < 2 and z > 0:
			continue
		if absf(absf(x) - 4.4) < 1.2 and z > 4.5:
			continue
		_tree(isl, x, z, snappedf(0.8 + rnd() * 0.5, 0.1), i % 4 == 0)

	# flori: un MultiMesh pe culoare
	var fc := [Color("ff6fa8"), Color("b07cff"), Color("7fa8ff"), Color("ffffff")]
	var lists := [[], [], [], []]
	for i in 70:
		var a := rnd() * 6.28
		var r := 5.9 + rnd() * 0.9
		var x := cos(a) * r
		var z := sin(a) * r
		if absf(x) < 1.5 and z > 0:
			continue
		lists[i % 4].append(Vector3(x, 0.12, z))
	for k in 4:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = sph(0.12, 6, 5)
		mm.instance_count = lists[k].size()
		for i in lists[k].size():
			mm.set_instance_transform(i, Transform3D(Basis(), lists[k][i]))
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = mat(fc[k], {"emit": fc[k], "energy": 0.15})
		isl.add_child(mi)

	for p in [Vector2(-1.4, 3.3), Vector2(1.4, 3.3), Vector2(-1.4, 6), Vector2(1.4, 6)]:
		lantern(isl, p.x, p.y)
	return isl

static func _tree(p: Node3D, x: float, z: float, s: float, conifer: bool) -> void:
	var g := Node3D.new()
	g.position = Vector3(x, 0, z)
	add(g, cyl(0.1 * s, 0.15 * s, 1 * s, 6), M("brown"), Vector3(0, 0.5 * s, 0))
	if conifer:
		add(g, cyl(0.001, 0.45 * s, 2.2 * s, 8), M("pine"), Vector3(0, 1.6 * s, 0))
	else:
		add(g, sph(0.7 * s, 8, 5), M("leafA"), Vector3(0, 1.4 * s, 0))
		add(g, sph(0.5 * s, 8, 5), M("leafB"), Vector3(0.3 * s, 1.9 * s, 0.1 * s))
	p.add_child(g)


# ---------------- insule îndepărtate ----------------
static func far_island() -> Node3D:
	var g := Node3D.new()
	add(g, cyl(2, 0.001, 3, 7), M("rock"), Vector3(0, -1.5, 0))
	add(g, cyl(2.1, 2, 0.3), M("grass"), Vector3(0, 0.1, 0))
	add(g, box(1, 0.8, 1), M("cream"), Vector3(0, 0.6, 0))
	dome(g, 0.7, 0, 1, 0)
	for c in g.get_children():
		(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return g


# ---------------- mascota ----------------
static func mascot() -> Node3D:
	var ms := Node3D.new()
	ms.name = "Procedural"
	var wh := mat(Color("fff6e8"), {"rough": 0.5})
	var dk := mat(Color("2a1a3a"))
	var shine := mat(Color.WHITE, {"emit": Color.WHITE, "energy": 1.0})
	var blush := mat(Color("ff9fb5"))
	var lens := mat(Color("2bd4c8"), {"metal": 0.5, "rough": 0.2})
	var leather := mat(Color("a8703a"))
	add(ms, sph(0.7, 24, 16), wh, Vector3(0, 0.75, 0)).scale = Vector3(1, 0.95, 0.92)
	for s in [-1.0, 1.0]:
		add(ms, sph(0.1, 8, 8), dk, Vector3(s * 0.23, 0.82, 0.58))
		add(ms, sph(0.03, 6, 6), shine, Vector3(s * 0.2, 0.86, 0.66))
		add(ms, sph(0.1, 8, 8), blush, Vector3(s * 0.4, 0.68, 0.52)).scale = Vector3(1, 0.6, 0.4)
		add(ms, sph(0.18, 12, 8), lens, Vector3(s * 0.25, 1.1, 0.5)).scale = Vector3(1, 0.8, 0.4)
		rot(add(ms, htor(0.18, 0.04), M("gold"), Vector3(s * 0.25, 1.1, 0.52)), PI / 2, 0, 0)
		add(ms, sph(0.17, 8, 8), wh, Vector3(s * 0.72, 0.6, 0.1))
		add(ms, sph(0.2, 8, 8), wh, Vector3(s * 0.3, 0.1, 0.1))
	var mouth := add(ms, sph(0.1, 8, 6), mat(Color("d8475a")), Vector3(0, 0.62, 0.64))
	mouth.scale = Vector3(1, 0.5, 0.5)
	mouth.name = "Mouth"
	add(ms, htor(0.5, 0.11, 24, 8), M("vio"), Vector3(0, 0.45, 0))
	rot(add(ms, box(0.2, 0.5, 0.08), M("vio"), Vector3(0.35, 0.25, 0.55)), 0, 0, 0.3)
	add(ms, box(0.6, 0.7, 0.3), M("brown"), Vector3(0, 0.7, -0.62))
	add(ms, htor(0.5, 0.03), M("gold"), Vector3(0, 1.05, 0.05))
	add(ms, hemi(0.76, 20, 6, PI * 0.3), M("brown"), Vector3(0, 0.75, -0.02))
	add(ms, htor(0.615, 0.05), leather, Vector3(0, 1.2, -0.02))
	for s in [-1.0, 1.0]:
		add(ms, sph(0.2, 8, 6), M("brown"), Vector3(s * 0.62, 0.95, -0.02)).scale = Vector3(0.5, 1, 0.8)
	return ms
