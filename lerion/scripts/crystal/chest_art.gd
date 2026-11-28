extends RefCounted
## Chest drawing shared by the opening screen and the wheel result, in a 300x260 design space.
## PROVISIONAL ART: the chests are vector-drawn from code (planks, bands, gems), not final 3D models.
## Each tier is clearly different: wood = planks and iron, silver = bevelled and shiny, gold = ornate
## with gems, a crown and a radiant aura.
const PALETTE := {
	"wood": {"base": Color("#b9763a"), "light": Color("#d99a58"), "dark": Color("#6a3a16"), "metal": Color("#8b919b"), "lock": Color("#9aa1ad")},
	"silver": {"base": Color("#c9d8e6"), "light": Color("#f2f8ff"), "dark": Color("#6b8097"), "metal": Color("#8fa4ba"), "lock": Color("#eaf3fb")},
	"gold": {"base": Color("#ffc93a"), "light": Color("#fff0a0"), "dark": Color("#b4780f"), "metal": Color("#e09a1c"), "lock": Color("#fff3b8")}}
const GEMS := [Color("#ff4d6d"), Color("#4dd0ff"), Color("#6bf08f")]


static func box(canvas: CanvasItem, rect: Rect2, fill: Color, radius: int, border: Color, width := 0) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(radius)
	if width > 0:
		style.border_color = border
		style.set_border_width_all(width)
	canvas.draw_style_box(style, rect)


static func star(canvas: CanvasItem, c: Vector2, r: float, color: Color) -> void:
	var pts := PackedVector2Array([c + Vector2(0,-r), c + Vector2(r*0.18,-r*0.18), c + Vector2(r,0), c + Vector2(r*0.18,r*0.18),
		c + Vector2(0,r), c + Vector2(-r*0.18,r*0.18), c + Vector2(-r,0), c + Vector2(-r*0.18,-r*0.18)])
	canvas.draw_colored_polygon(pts, color)


## `lid` 0 closed .. 1 open, `glow` 0..1 light from inside, `age` seconds for idle shine and twinkles.
static func draw(canvas: CanvasItem, kind: String, lid: float, glow: float, age: float, aura := true, xf := Transform2D.IDENTITY) -> void:
	canvas.draw_set_transform_matrix(xf)
	var tone: Dictionary = PALETTE.get(kind, PALETTE.wood)
	var base: Color = tone.base
	var light: Color = tone.light
	var dark: Color = tone.dark
	var metal: Color = tone.metal
	var body := Rect2(30, 120, 240, 120)
	var tier := ["wood", "silver", "gold"].find(kind)
	# Aura behind the chest: none for wood, cool shimmer for silver, radiant gold.
	if aura and tier > 0:
		var halo: Color = Color("#bfe6ff") if tier == 1 else Color("#ffd866")
		var breath := 0.5 + 0.5*sin(age*2.0)
		for k in range(3):
			canvas.draw_circle(Vector2(150, 170), (118.0 + k*26.0)*(1.0 + 0.04*breath), Color(halo, (0.1 if tier == 1 else 0.17)*(1.0 - k*0.28)))
	canvas.draw_circle(Vector2(150, 242), 104.0, Color(0, 0, 0, 0.28))
	if glow > 0.02:
		var beam := PackedVector2Array([Vector2(60,126), Vector2(240,126), Vector2(310,-70), Vector2(-10,-70)])
		canvas.draw_colored_polygon(beam, Color(1, 0.95, 0.7, 0.32*glow))
		canvas.draw_circle(Vector2(150,124), 70.0*glow + 10.0, Color(1, 0.96, 0.75, 0.55*glow))
	box(canvas, body, base, 16, dark, 6)
	# Front detail by tier.
	if tier == 0:
		for y in [152.0, 182.0, 212.0]:
			canvas.draw_rect(Rect2(36, y, 228, 3), Color(dark, 0.55))
		for x in [88.0, 150.0, 214.0]:
			canvas.draw_rect(Rect2(x, 126, 2, 108), Color(dark, 0.4))
	elif tier == 1:
		canvas.draw_rect(Rect2(38, 128, 224, 9), Color(1, 1, 1, 0.5))
		box(canvas, Rect2(104, 166, 92, 52), Color(dark, 0.28), 10, Color(light, 0.9), 2)
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(150,172), Vector2(176,192), Vector2(150,212), Vector2(124,192)]), Color(light, 0.85))
	else:
		canvas.draw_rect(Rect2(38, 128, 224, 8), Color(1, 1, 1, 0.55))
		for i in range(6):
			canvas.draw_circle(Vector2(52 + i*39.0, 232), 9.0, Color(dark, 0.9))
			canvas.draw_circle(Vector2(52 + i*39.0, 230), 6.5, light)
		# Crown emblem.
		var crown := PackedVector2Array([Vector2(118,214), Vector2(118,178), Vector2(134,194), Vector2(150,170), Vector2(166,194), Vector2(182,178), Vector2(182,214)])
		canvas.draw_colored_polygon(crown, Color(dark, 0.85))
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(124,208), Vector2(124,186), Vector2(135,198), Vector2(150,178), Vector2(165,198), Vector2(176,186), Vector2(176,208)]), light)
	# Bands.
	for x in [66.0, 216.0]:
		canvas.draw_rect(Rect2(x, 120, 20, 120), metal)
		canvas.draw_rect(Rect2(x, 120, 5, 120), Color(light, 0.55))
		canvas.draw_circle(Vector2(x + 10, 134), 3.4, light)
		canvas.draw_circle(Vector2(x + 10, 226), 3.4, light)
	canvas.draw_rect(Rect2(30, 204, 240, 10), Color(metal, 0.9))
	if lid > 0.02:
		box(canvas, Rect2(40, 120, 220, 26), Color("#2a1a10") if glow < 0.5 else Color(1, 0.9, 0.55), 10, Color(0,0,0,0))
	# Lid, hinged at the back left.
	canvas.draw_set_transform_matrix(xf * Transform2D(-lid*1.05, Vector2(30, 128)))
	box(canvas, Rect2(0, -86, 240, 96), base.lightened(0.07), 28, dark, 6)
	canvas.draw_rect(Rect2(14, -80, 212, 8), Color(1, 1, 1, 0.34 if tier == 0 else 0.5))
	for x in [36.0, 186.0]:
		canvas.draw_rect(Rect2(x, -86, 20, 96), metal)
		canvas.draw_rect(Rect2(x, -86, 5, 96), Color(light, 0.55))
	if tier == 0:
		for y in [-60.0, -36.0, -12.0]:
			canvas.draw_rect(Rect2(14, y, 212, 3), Color(dark, 0.45))
	elif tier == 1:
		# Moving shine across the lid.
		var sweep := fposmod(age*0.5, 1.6) - 0.3
		var x0 := 20.0 + sweep*200.0
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(x0,-84), Vector2(x0 + 26,-84), Vector2(x0 + 8,8), Vector2(x0 - 18,8)]), Color(1,1,1,0.38))
		box(canvas, Rect2(92, -64, 56, 8), Color(light, 0.8), 4, Color(0,0,0,0))
	else:
		for i in range(3):
			var c := Vector2(70 + i*50.0, -40.0)
			canvas.draw_circle(c, 15.0, Color(dark, 0.9))
			canvas.draw_circle(c, 11.5, GEMS[i])
			canvas.draw_circle(c + Vector2(-3,-3.5), 3.5, Color(1,1,1,0.85))
		for i in range(12):
			canvas.draw_circle(Vector2(20 + i*18.5, 4), 7.0, Color(dark, 0.7))
			canvas.draw_circle(Vector2(20 + i*18.5, 3), 5.0, light)
	canvas.draw_set_transform_matrix(xf)
	# Lock plate.
	var lock_y := 118.0 + lid*8.0
	canvas.draw_circle(Vector2(150, lock_y + 24), 22.0, dark)
	canvas.draw_circle(Vector2(150, lock_y + 24), 16.0, tone.lock)
	canvas.draw_rect(Rect2(146, lock_y + 24, 8, 16), dark)
	# Twinkles: gold always, silver a little.
	if tier > 0:
		var count := 5 if tier == 2 else 2
		for i in range(count):
			var t := pow(maxf(0.0, sin(age*2.2 + i*1.9)), 4.0)
			var p: Vector2 = Vector2(60 + fposmod(i*53.0 + 20.0, 190.0), 60 + fposmod(i*37.0, 120.0)) if lid < 0.2 else Vector2(70 + i*40.0, 40.0 + 14.0*sin(i*2.0))
			star(canvas, p, 6.0 + 14.0*t, Color(1, 1, 0.85, 0.9*t))
