extends Control
## Buble Blast: grilă hexagonală de 8 coloane, grupuri de 3+, bulele fără sprijin cad.
## Niveluri: fiecare nivel are mai multe rânduri și culori. Bule speciale:
##   💣 bomba  – sparge tot în jurul locului unde cade (câștigată la o reacție în lanț ×3+)
##   🌈 curcubeul – ia culoarea celui mai mare grup vecin (câștigat la un grup de 6+)
## Monedele câștigate merg pe insulă.

signal closed(rewarded: bool)

const K := preload("res://scripts/ui/ui_kit.gd")
const COL := [Color("2bd4c8"), Color("9a63ff"), Color("ffc83d"), Color("ff6fa8"), Color("6fdc5a")]
const BOMB := 10
const RAINBOW := 11
const RW := 14
const CW := 8

var level := 1
var colors := 4
var g := []                 # g[r][c] = culoare, -1 = gol
var score := 0
var shots := 25
var over := false
var mv = null               # bula în zbor: {p, v, c}
var aim_a := PI / 2
var cc := 0
var nc := 0
var fx := []
var msg := ""
var mt := 0.0
var coins_won := 0
var won := false
var _aiming := false
var _t := 0.0

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

	resized.connect(_layout)
	Monetization.rewarded_done.connect(_on_rewarded)
	start_level(Game.blast_level)


## Pregătește un nivel: mai multe rânduri și culori pe măsură ce crește nivelul.
func start_level(n: int) -> void:
	level = n
	colors = mini(3 + (n - 1) / 2, COL.size())     # 3,3,4,4,5...
	var rows := mini(4 + n, 9)
	shots = 24 + mini(n, 12)
	score = 0
	over = false
	won = false
	mv = null
	fx.clear()
	coins_won = 0
	g.clear()
	for i in RW:
		var row := []
		row.resize(CW)
		row.fill(-1)
		g.append(row)
	for i in rows:
		for j in CW:
			g[i][j] = randi() % colors
	_layout()
	cc = _pick_color()
	nc = _pick_color()
	if n >= 3:
		nc = BOMB    # cadou de început de la nivelul 3
	msg = "Nivelul %d" % n
	mt = 1.6
	if result:
		result.queue_free()
		result = null


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
			if v >= 0 and v < COL.size():
				s[v] = true
	var a: Array = s.keys() if s.size() > 0 else range(colors)
	if randf() < 0.05:
		return RAINBOW
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
	if mv != null or shots <= 0 or over:
		return
	var sp := r * 30.0
	mv = {"p": Vector2(sx, sy), "v": Vector2(cos(aim_a), -sin(aim_a)) * sp, "c": cc}
	cc = nc
	nc = _pick_color()
	shots -= 1
	Sfx.play("shoot")


## Schimbă bula curentă cu următoarea (atingere pe bula mică).
func swap() -> void:
	if mv == null and not over:
		var t := cc
		cc = nc
		nc = t
		Sfx.play("click")


# ---------------- logică ----------------
func _process(dt: float) -> void:
	dt = minf(dt, 0.05)
	_t += dt
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


func _group(start: Vector2i, color: int) -> Dictionary:
	var same := {start: true}
	var st := [start]
	while st.size() > 0:
		var cur: Vector2i = st.pop_back()
		for n in nb(cur.x, cur.y):
			if g[n.x][n.y] == color and not same.has(n):
				same[n] = true
				st.append(n)
	return same


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
	var popped := 0
	if m.c == BOMB:
		# bomba: sparge celula și vecinii de până la 2 pași
		var hitset := {best: true}
		var ring := [best]
		for step in 2:
			var nxt := []
			for cell in ring:
				for n in nb(cell.x, cell.y):
					if not hitset.has(n):
						hitset[n] = true
						nxt.append(n)
			ring = nxt
		for cell in hitset:
			if g[cell.x][cell.y] >= 0:
				_pop(cell.x, cell.y, false)
				score += 15
				popped += 1
		msg = "Bum! 💣"
		mt = 1.0
		Sfx.play("bomb")
	else:
		var color: int = m.c
		if color == RAINBOW:
			# curcubeul ia culoarea celui mai mare grup vecin
			var best_c := -1
			var best_n := 0
			for n in nb(best.x, best.y):
				var v: int = g[n.x][n.y]
				if v >= 0 and v < COL.size():
					var sz := _group(n, v).size()
					if sz > best_n:
						best_n = sz
						best_c = v
			color = best_c if best_c >= 0 else randi() % colors
			Sfx.play("rainbow")
		g[best.x][best.y] = color
		var same := _group(best, color)
		if same.size() >= 3:
			for k in same:
				_pop(k.x, k.y, false)
				score += 10
			popped = same.size()
			Sfx.play("pop", 1.0 + minf(popped, 10) * 0.03)
			if popped >= 6:
				nc = RAINBOW
				msg = "Grup de %d! Curcubeu 🌈" % popped
				mt = 1.4
	var falls := 0
	if popped > 0:
		falls = _drop_unsupported()
	if falls > 0:
		score += falls * 20
		msg = "Reacție în lanț! ×%d" % falls
		mt = 1.5
		Sfx.play("fall")
		if falls >= 3:
			nc = BOMB
			msg += "  Bombă câștigată 💣"
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


func _drop_unsupported() -> int:
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
	var falls := 0
	for row in RW:
		for c in CW:
			if g[row][c] >= 0 and not ok.has(Vector2i(row, c)):
				_pop(row, c, true)
				falls += 1
	return falls


func _pop(row: int, c: int, fall: bool) -> void:
	var p := cp(row, c)
	var col: int = g[row][c]
	g[row][c] = -1
	if fall:
		fx.append({"p": p, "v": Vector2(randf_range(-60, 60), -100), "c": col, "big": true, "t": 1.2})
	for i in 5:
		fx.append({"p": p, "v": Vector2(randf_range(-150, 150), randf_range(-150, 150)), "c": col, "big": false, "t": 0.5})


func _end(win: bool) -> void:
	over = true
	won = win
	if win:
		score += shots * 25    # bonus pentru mutările rămase
	coins_won = Game.blast_reward(score, win)
	Sfx.play("win" if win else "lose")
	_show_result()


# ---------------- desen ----------------
func _dot(p: Vector2, c: int, rad: float, alpha := 1.0) -> void:
	draw_circle(p + Vector2(0, rad * 0.08), rad * 0.96, Color(0, 0, 0, 0.22 * alpha))
	if c == BOMB:
		draw_circle(p, rad * 0.94, Color(0.16, 0.1, 0.24, alpha))
		draw_circle(p - Vector2(rad * 0.3, rad * 0.3), rad * 0.22, Color(1, 1, 1, 0.35 * alpha))
		draw_line(p + Vector2(rad * 0.4, -rad * 0.7), p + Vector2(rad * 0.75, -rad * 1.1), Color("c8a060", alpha), 4.0)
		var spark := 0.6 + 0.4 * sin(_t * 18.0)
		draw_circle(p + Vector2(rad * 0.8, -rad * 1.15), rad * 0.18 * spark + 2.0, Color(1.0, 0.65, 0.15, alpha))
		return
	if c == RAINBOW:
		var n := COL.size()
		for i in n:
			var a0 := TAU * i / n + _t
			var pts := PackedVector2Array([p])
			for k in 7:
				var a := a0 + TAU / n * k / 6.0
				pts.append(p + Vector2(cos(a), sin(a)) * rad * 0.94)
			draw_colored_polygon(pts, Color(COL[i], alpha))
		draw_circle(p - Vector2(rad * 0.32, rad * 0.32), rad * 0.18, Color(1, 1, 1, 0.8 * alpha))
		return
	var col: Color = COL[c]
	col.a = alpha
	draw_circle(p, rad * 0.94, col)
	draw_circle(p + Vector2(rad * 0.08, rad * 0.1), rad * 0.72, col.lightened(0.08))
	draw_circle(p - Vector2(rad * 0.22, rad * 0.22), rad * 0.42, Color(1, 1, 1, 0.25 * alpha))
	draw_circle(p - Vector2(rad * 0.32, rad * 0.32), rad * 0.18, Color(1, 1, 1, 0.8 * alpha))


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
	draw_string(font, Vector2(sx - r * 5.2, sy + r * 2.0), "schimbă", HORIZONTAL_ALIGNMENT_CENTER, r * 4.0, 20, Color(1, 1, 1, 0.55))
	for f in fx:
		var a := minf(1.0, f.t * 2.0)
		if f.big:
			_dot(f.p, f.c, r, a)
		else:
			var cc2: Color = COL[f.c] if f.c < COL.size() else Color.WHITE
			draw_circle(f.p, r * 0.25, Color(cc2, a))
	draw_string(font, Vector2(26, 120), "Scor %d" % score, HORIZONTAL_ALIGNMENT_LEFT, -1, 36)
	draw_string(font, Vector2(0, 120), "Mutări: %d" % shots, HORIZONTAL_ALIGNMENT_CENTER, W, 36)
	draw_string(font, Vector2(26, 162), "Nivelul %d" % level, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("ffd86b"))
	if mt > 0:
		draw_string(font, Vector2(0, H / 2), msg, HORIZONTAL_ALIGNMENT_CENTER, W, 44, Color(1.0, 0.85, 0.42, minf(1.0, mt * 2.0)))


func _unhandled_input(_e: InputEvent) -> void:
	pass


func _input(e: InputEvent) -> void:
	# atingere pe bula „următoare" = schimbă
	if over or not visible:
		return
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var local: Vector2 = get_global_transform_with_canvas().affine_inverse() * e.position
		if local.distance_to(Vector2(sx - r * 3.2, sy + r * 0.6)) < r * 1.1:
			swap()
			get_viewport().set_input_as_handled()


# ---------------- rezultat ----------------
func _show_result() -> void:
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
	card.offset_top = -330
	card.offset_bottom = 330
	result.add_child(card)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 16)
	card.add_child(vb)
	var title := ("Nivelul %d finalizat! 🎉" % level) if won else "Sfârșit de rundă"
	for t in [[title, 40, 900, ""], ["Scor: %d" % score, 30, 700, ""], ["Ai câștigat 🪙 %d monede" % coins_won, 30, 700, "Won"]]:
		var l := K.label(t[0], t[1], Color.WHITE, t[2])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if t[3] != "":
			l.name = t[3]
		vb.add_child(l)
	if coins_won > 0 and Monetization.can_show_rewarded(Monetization.PLACEMENT_DOUBLE_BLAST):
		var dbl := K.button("🎬 Dublează monedele", 28, K.box(Color("7a5ad8"), 40, K.GOLD, 3, 0, 18))
		dbl.name = "Double"
		dbl.pressed.connect(func(): Monetization.show_rewarded(Monetization.PLACEMENT_DOUBLE_BLAST))
		vb.add_child(dbl)
	var again := K.gold_button(("Nivelul %d ▶" % Game.blast_level) if won else "Încearcă din nou", 30)
	again.custom_minimum_size = Vector2(0, 84)
	again.pressed.connect(func():
		Sfx.play("click")
		start_level(Game.blast_level))
	vb.add_child(again)
	var back := K.button("Înapoi pe insulă", 28, K.box(Color(1, 1, 1, 0.12), 40, Color(1, 1, 1, 0.3), 2, 0, 16))
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
	Sfx.play("coin")
	var won_lbl := result.find_child("Won", true, false) as Label
	if won_lbl:
		won_lbl.text = "Ai câștigat 🪙 %d monede" % coins_won
	var dbl := result.find_child("Double", true, false)
	if dbl:
		dbl.queue_free()


func _quit() -> void:
	# ✕ în timpul rundei: runda se abandonează fără recompensă.
	over = true
	closed.emit(result != null)
	queue_free()
