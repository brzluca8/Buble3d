class_name Backdrop
extends RefCounted
## Fundalul comun pentru ecranul cu globul și mașina de bule: interiorul unui glob de sticlă la
## amurg – orașul estompat (bokeh), pete calde de lumină, raze care cad oblic. Ieftin: o textură
## mică estompată, un MultiMesh pentru bokeh, câteva quad-uri aditive.
## `offset` și `s` așază totul în coordonatele părintelui (la glob: în spațiul camerei).

## Fundalul: orașul din glob estompat, bokeh cald, raze de lumină, bule care urcă.
static func build(parent: Node3D, offset := Vector3.ZERO, s := 1.0, sunburst := true) -> MeshInstance3D:
	# siluetele orașului: o textură mică, apoi micșorată și mărită (estompare ieftină)
	var w := 160
	var h := 80
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	Proc.reseed(31)
	var x := 0
	while x < w:
		var bw := 6 + int(Proc.rnd() * 14)
		var bh := 18 + int(Proc.rnd() * 50)
		var dome := Proc.rnd() < 0.3
		for yy in range(h - bh, h):
			for xx in range(x, mini(x + bw, w)):
				var c := Color(0.2, 0.1, 0.35, 1.0)
				if (xx - x) % 3 == 1 and (yy - (h - bh)) % 4 == 2 and Proc.rnd() < 0.55:
					c = Color(1.0, 0.75, 0.45, 1.0)
				img.set_pixel(xx, yy, c)
		if dome:
			for yy in range(maxi(0, h - bh - bw / 2), h - bh):
				for xx in range(x, mini(x + bw, w)):
					if Vector2(xx - x - bw / 2.0, float(yy - (h - bh))).length() < bw / 2.0:
						img.set_pixel(xx, yy, Color(0.2, 0.1, 0.35, 1.0))
		x += bw + int(Proc.rnd() * 3)
	img.resize(40, 20, Image.INTERPOLATE_BILINEAR)
	img.resize(160, 80, Image.INTERPOLATE_CUBIC)
	var city := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(34, 17) * s
	city.mesh = qm
	var cm := StandardMaterial3D.new()
	cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cm.albedo_texture = ImageTexture.create_from_image(img)
	cm.albedo_color = Color(1.0, 0.85, 1.0, 0.9)
	city.material_override = cm
	city.position = offset + Vector3(0, 5.0, -16) * s
	parent.add_child(city)
	# bokeh: pete calde de lumină, mari și moi (o singură desenare)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var bq := QuadMesh.new()
	bq.size = Vector2.ONE
	mm.mesh = bq
	mm.instance_count = 46
	var cols := [Color(1.0, 0.7, 0.35, 0.55), Color(1.0, 0.45, 0.7, 0.45), Color(0.4, 0.95, 1.0, 0.35), Color(1.0, 0.9, 0.6, 0.5)]
	Proc.reseed(44)
	for i in 46:
		var sz := (0.4 + Proc.rnd() * 1.4) * s
		var p := offset + Vector3(-9.0 + Proc.rnd() * 18.0, 0.6 + Proc.rnd() * 9.0, -7.0 - Proc.rnd() * 7.0) * s
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * sz), p))
		mm.set_instance_color(i, cols[i % cols.size()])
	var bokeh := MultiMeshInstance3D.new()
	bokeh.multimesh = mm
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	bm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	bm.vertex_color_use_as_albedo = true
	bm.albedo_texture = _ring_soft_tex()
	bm.disable_fog = true
	bokeh.material_override = bm
	bokeh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(bokeh)
	# raze de lumină care cad oblic prin sticla globului
	for i in 4:
		var r := MeshInstance3D.new()
		var rq := QuadMesh.new()
		rq.size = Vector2(1.2 + i * 0.4, 16.0) * s
		r.mesh = rq
		var rm := StandardMaterial3D.new()
		rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		rm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		rm.albedo_texture = Proc.tex("soft")
		rm.albedo_color = Color(1.0, 0.85, 0.6, 0.09)
		rm.disable_fog = true
		r.material_override = rm
		r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		r.position = offset + Vector3(-4.5 + i * 2.6, 6.0, -4.0 - i * 0.6) * s
		r.rotation.z = -0.42
		r.name = "Raza%d" % i
		parent.add_child(r)
	if not sunburst:
		return null
	# raze „sunburst” în spatele aparatului (pornesc doar la super câștig)
	var rays := MeshInstance3D.new()
	var sq := QuadMesh.new()
	sq.size = Vector2(12, 12)
	rays.mesh = sq
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	sm.albedo_texture = _rays_tex()
	sm.albedo_color = Color(1.0, 0.8, 0.45, 0.0)
	sm.disable_fog = true
	rays.material_override = sm
	rays.position = Vector3(0, 2.6, -1.4)
	rays.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(rays)
	return rays


static func _ring_soft_tex() -> Texture2D:
	# pată bokeh: disc moale cu marginea puțin mai luminoasă
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := Vector2(x - 31.5, y - 31.5).length() / 32.0
			var a := clampf((1.0 - d) * 6.0, 0.0, 1.0) * (0.55 + 0.45 * smoothstep(0.6, 0.95, d))
			img.set_pixel(x, y, Color(1, 1, 1, a))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func _rays_tex() -> Texture2D:
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var p := Vector2(x - 63.5, y - 63.5) / 64.0
			var a := atan2(p.y, p.x)
			var v := pow(0.5 + 0.5 * cos(a * 14.0), 5.0) * clampf(1.0 - p.length(), 0.0, 1.0)
			v += clampf(1.0 - p.length() * 2.2, 0.0, 1.0) * 0.6
			img.set_pixel(x, y, Color(1, 1, 1, clampf(v, 0.0, 1.0)))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


