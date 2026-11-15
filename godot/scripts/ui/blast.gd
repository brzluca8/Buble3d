extends Control
## Buble Blast: grilă hexagonală de 8 coloane, 25 de mutări, grupuri de 3+,
## bulele rămase fără sprijin cad (reacție în lanț). Monedele merg pe insulă.

signal closed(rewarded: bool)

const K := preload("res://scripts/ui/ui_kit.gd")
const COL := [Color("2bd4c8"), Color("9a63ff"), Color("ffc83d"), Color("ff6fa8")]
const RW := 14
const CW := 8
const SHOTS := 25

var g := []                 # g[r][c] = culoare sau -1
var score := 0
var shots := SHOTS
var over := false
var mv = null               # bula în zbor: {p, v, c}
var aim_a := PI / 2
var cc := 0
var nc := 0
var fx := []
var msg := ""
var mt := 0.0
var coins_won := 0
var _aiming := false

# geometrie
var W := 720.0
var H := 1280.0
var r := 40.0
var rs := 69.0
var x0 := 0.0
var y0 := 0.0
var sx := 0.0
var sy := 0.0
var lim := 10

var result: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := TextureRect.new()
	var gr := Gradient.new()
	gr.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	gr.colors = PackedColorArray([Color("1b1470"), Color("3b2a9a"), Color("5b3fc0")])
	var gt := GradientTexture2D.new()
	gt.gradient = gr
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	bg.texture = gt
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.show_behind_parent = true
	K.full_rect(bg)
	add_child(bg)

	var x := K.button("✕", 40, K.box(Color(1, 1, 1, 0.2), 22))
	x.anchor_left = 1
	x.anchor_right = 1
	x.offset_left = -96
	x.offset_right = -18
	x.offset_top = 14
	x.offset_bottom = 92
	x.pressed.connect(_quit)
	add_child(x)

	for i in RW:
		var row := []
		row.resize(CW)
		row.fill(-1)
		g.append(row)
	for i in 6:
		for j in CW:
			g[i][j] = randi() % 4
	resized.connect(_layout)
	_layout()
	cc = _pick_color()
	nc = _pick_color()
	Monetization.rewarded_done.connect(_on_rewarded)


func _layout() -> void:
	W = size.x if size.x > 0 else 720.0
	H = size.y if size.y > 0 else 1280.0
	# raza: încape pe lățime și lasă cel puțin ~11 rânduri până la linia-limită
	r = minf(minf(W / 17.0, (H - 380.0) / 22.7), 60.0)
	rs = r * 1.732
	x0 = (W - 17.0 * r) / 2.0 + r
	y0 = 190.0 + r
	sx = W / 2.0
	sy = H - 190.0
	lim = int((sy - 2.6 * r - y0) / rs)


func cp(row: int, c: int) -> Vector2:
	return Vector2(x0 + c * 2.0 * r + (row % 2) * r, y0 + row * rs)


func nb(row: int, c: int) -> Array:
	var p := row % 2
	var o := [Vector2i(row, c - 1), Vector2i(row, c + 1)]
	for q in [row - 1, row + 1]:
		o.append(Vector2i(q, c - 1 + p))
		o.append(Vector2i(q, c + p))
	return o.filter(func(a): return a.x >= 0 and a.x < RW and a.y >= 0 and a.y < CW)


func _pick_color() -> int:
	var s := {}
	for row in g:
		for v in row:
			if v >= 0:
				s[v] = true
	var a: Array = s.keys() if s.size() > 0 else [0, 1, 2, 3]
	return a[randi() % a.size()]


# ---------------- intrare ----------------
func _gui_input(e: InputEvent) -> void:
	if over:
		return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_aiming = true
			_aim(e.position)
		elif _aiming:
			_aiming = false
			_aim(e.position)
			_shoot()
		accept_event()
	elif e is InputEventMouseMotion and _aiming:
		_aim(e.position)
		accept_event()


func _aim(p: Vector2) -> void:
	aim_a = clampf(atan2(sy - p.y, p.x - sx), 0.2, PI - 0.2)


func _shoot() -> void:
	if mv != null or shots <= 0:
		return
	var sp := r * 30.0
	mv = {"p": Vector2(sx, sy), "v": Vector2(cos(aim_a), -sin(aim_a)) * sp, "c": cc}
	cc = nc
	nc = _pick_color()
	shots -= 1


# ---------------- logică ----------------
func _process(dt: float) -> void:
	dt = minf(dt, 0.05)
	if mv != null:
		for s in 4:
			if mv == null:
				break
			var d := dt / 4.0
			mv.p += mv.v * d
			var L := x0 - r
			var R := L + 17.0 * r
			if mv.p.x < L + r:
				mv.p.x = L + r
				mv.v.x = -mv.v.x
			if mv.p.x > R - r:
				mv.p.x = R - r
				mv.v.x = -mv.v.x
			var hit: bool = mv.p.y <= y0
			if not hit:
				for row in RW:
					for c in CW:
						if g[row][c] >= 0 and cp(row, c).distance_squared_to(mv.p) < pow(1.75 * r, 2):
							hit = true
							break
					if hit:
						break
			if hit:
				_place()
	var keep := []
	for f in fx:
		f.t -= dt
		if f.t > 0:
			f.p += f.v * dt
			f.v.y += (900.0 if f.big else 200.0) * dt
			keep.append(f)
	fx = keep
	if mt > 0:
		mt -= dt
	queue_redraw()


func _place() -> void:
	var m = mv
	mv = null
	var best := Vector2i(-1, -1)
	var bd := INF
	for row in RW:
		for c in CW:
			if g[row][c] < 0:
				var d := cp(row, c).distance_squared_to(m.p)
				if d < bd:
					bd = d
					best = Vector2i(row, c)
	if best.x < 0:
		_end(false)
		return
	g[best.x][best.y] = m.c
	var same := {best: true}
	var st := [best]
	while st.size() > 0:
		var cur: Vector2i = st.pop_back()
		for n in nb(cur.x, cur.y):
			if g[n.x][n.y] == m.c and not same.has(n):
				same[n] = true
				st.append(n)
	var falls := 0
	if same.size() >= 3:
		for k in same:
			_pop(k.x, k.y, false)
			score += 10
		var ok := {}
		var q := []
		for c in CW:
			if g[0][c] >= 0:
				ok[Vector2i(0, c)] = true
				q.append(Vector2i(0, c))
		while q.size() > 0:
			var cur: Vector2i = q.pop_back()
			for n in nb(cur.x, cur.y):
				if g[n.x][n.y] >= 0 and not ok.has(n):
					ok[n] = true
					q.append(n)
		for row in RW:
			for c in CW:
				if g[row][c] >= 0 and not ok.has(Vector2i(row, c)):
					_pop(row, c, true)
					falls += 1
					score += 20
	if falls > 0:
		msg = "Reacție în lanț! ×%d" % falls
		mt = 1.5
	var empty := true
	for row in g:
		for v in row:
			if v >= 0:
				empty = false
	if empty:
		_end(true)
		return
	for row in range(lim, RW):
		for v in g[row]:
			if v >= 0:
				_end(false)
				return
	if shots <= 0:
		_end(false)


func _pop(row: int, c: int, fall: bool) -> void:
	var p := cp(row, c)
	var col: int = g[row][c]
	g[row][c] = -1
	if fall:
		fx.append({"p": p, "v": Vector2(randf_range(-60, 60), -100), "c": col, "big": true, "t": 1.2})
	for i in 5:
		fx.append({"p": p, "v": Vector2(randf_range(-150, 150), randf_range(-150, 150)), "c": col, "big": false, "t": 0.5})


func _end(won: bool) -> void:
	over = true
	coins_won = Game.blast_reward(score, won)
	_show_result(won)


# ---------------- desen ----------------
func _dot(p: Vector2, c: int, rad: float) -> void:
	var col: Color = COL[c]
	draw_circle(p + Vector2(0, rad * 0.08), rad * 0.96, Color(0, 0, 0, 0.22))
	draw_circle(p, rad * 0.94, col)
	draw_circle(p + Vector2(rad * 0.08, rad * 0.1), rad * 0.72, col.lightened(0.08))
	draw_circle(p - Vector2(rad * 0.22, rad * 0.22), rad * 0.42, Color(1, 1, 1, 0.25))
	draw_circle(p - Vector2(rad * 0.32, rad * 0.32), rad * 0.18, Color(1, 1, 1, 0.8))


func _draw() -> void:
	var font := K.font(800)
	var ly := y0 + lim * rs - r
	draw_dashed_line(Vector2(0, ly), Vector2(W, ly), Color(1, 1, 1, 0.25), 2.0, 14.0)
	for row in RW:
		for c in CW:
			if g[row][c] >= 0:
				_dot(cp(row, c), g[row][c], r)
	if mv == null and not over:
		for i in range(1, 9):
			var p := Vector2(sx + cos(aim_a) * i * r * 1.6, sy - sin(aim_a) * i * r * 1.6)
			draw_circle(p, 5.0, Color(1, 1, 1, 0.6))
	if mv != null:
		_dot(mv.p, mv.c, r)
	_dot(Vector2(sx, sy), cc, r)
	_dot(Vector2(sx - r * 3.2, sy + r * 0.6), nc, r * 0.7)
	for f in fx:
		var a := minf(1.0, f.t * 2.0)
		if f.big:
			draw_circle(f.p, r * 0.94, Color(COL[f.c], a))
		else:
			draw_circle(f.p, r * 0.25, Color(COL[f.c], a))
	draw_string(font, Vector2(26, 120), "Scor %d" % score, HORIZONTAL_ALIGNMENT_LEFT, -1, 38)
	draw_string(font, Vector2(0, 120), "Mutări: %d" % shots, HORIZONTAL_ALIGNMENT_CENTER, W, 38)
	if mt > 0:
		draw_string(font, Vector2(0, H / 2), msg, HORIZONTAL_ALIGNMENT_CENTER, W, 48, Color("ffd86b"))


# ---------------- rezultat ----------------
func _show_result(won: bool) -> void:
	result = K.full_rect(ColorRect.new())
	(result as ColorRect).color = Color(0, 0, 0, 0.65)
	add_child(result)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", K.box(K.CARD, 44, K.GOLD, 4, 16, 40))
	card.anchor_left = 0.5
	card.anchor_right = 0.5
	card.anchor_top = 0.5
	card.anchor_bottom = 0.5
	card.offset_left = -300
	card.offset_right = 300
	card.offset_top = -280
	card.offset_bottom = 280
	result.add_child(card)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 18)
	card.add_child(vb)
	for t in [["Nivel finalizat! 🎉" if won else "Sfârșit de rundă", 44, 900], ["Scor: %d" % score, 30, 700], ["Ai câștigat 🪙 %d monede" % coins_won, 30, 700]]:
		var l := K.label(t[0], t[1], Color.WHITE, t[2])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if String(t[0]).begins_with("Ai"):
			l.name = "Won"
		vb.add_child(l)
	if coins_won > 0 and Monetization.can_show_rewarded(Monetization.PLACEMENT_DOUBLE_BLAST):
		var dbl := K.button("🎬 Dublează monedele", 28, K.box(Color("7a5ad8"), 40, K.GOLD, 3, 0, 18))
		dbl.name = "Double"
		dbl.pressed.connect(func(): Monetization.show_rewarded(Monetization.PLACEMENT_DOUBLE_BLAST))
		vb.add_child(dbl)
	var back := K.gold_button("Înapoi pe insulă", 30)
	back.custom_minimum_size = Vector2(0, 90)
	back.pressed.connect(func():
		closed.emit(true)
		queue_free())
	vb.add_child(back)


func _on_rewarded(placement: String, ok: bool) -> void:
	if placement != Monetization.PLACEMENT_DOUBLE_BLAST or not ok or result == null:
		return
	Game.add_coins(coins_won)
	Game.save_game()
	coins_won *= 2
	var won_lbl := result.find_child("Won", true, false) as Label
	if won_lbl:
		won_lbl.text = "Ai câștigat 🪙 %d monede" % coins_won
	var dbl := result.find_child("Double", true, false)
	if dbl:
		dbl.queue_free()


func _quit() -> void:
	# ✕ în timpul rundei: runda se abandonează fără recompensă (ca în prototip).
	over = true
	closed.emit(result != null)
	queue_free()
