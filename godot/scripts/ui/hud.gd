extends CanvasLayer
## Interfața principală (toate textele în română).

const K := preload("res://scripts/ui/ui_kit.gd")
const BubleBlast := preload("res://scripts/ui/blast.gd")

var root: Control
var coins_lbl: Label
var lvl_lbl: Label
var prog_lbl: Label
var xp_bar: ProgressBar
var title: Control
var sheet: PanelContainer
var sheet_box: VBoxContainer
var toast_panel: PanelContainer
var toast_lbl: Label
var toast_timer: Timer
var nav_buttons := {}
var modal: Control
var modal_box: VBoxContainer
var blast: Control
var ad_overlay: Control
var blast_sub: Label


func _ready() -> void:
	root = K.full_rect(Control.new())
	root.theme = K.theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_vignette()
	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)
	_top_bar()
	_xp_bar()
	_title()
	_sheet()
	_blast_button()
	_nav()
	_settings_button()
	_toast()
	_modal()
	_ad_overlay()
	Game.changed.connect(_refresh)
	Game.selected.connect(func(_id): _refresh_sheet())
	Game.toast.connect(show_toast)
	Monetization.demo_ad_requested.connect(_show_demo_ad)
	_refresh()
	if Game.offline_gain > 0:
		get_tree().create_timer(0.6).timeout.connect(func(): show_toast("Bine ai revenit! Insula a produs 🪙 %d" % Game.offline_gain))


# Marginile sigure (decupaj / bară de navigare Android).
func _apply_safe_area() -> void:
	var win := DisplayServer.window_get_size()
	var safe := DisplayServer.get_display_safe_area()
	var vp := root.get_viewport_rect().size
	if win.x <= 0 or win.y <= 0:
		return
	var k := vp.y / float(win.y)
	var top := maxf(0.0, safe.position.y) * k
	var bottom := maxf(0.0, win.y - safe.end.y) * k
	if safe.size.y <= 0 or bottom > vp.y * 0.2:
		top = 0.0
		bottom = 0.0
	root.offset_top = top
	root.offset_bottom = -bottom


func _vignette() -> void:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.5, 1.0])
	g.colors = PackedColorArray([Color(0.1, 0.05, 0.27, 0.0), Color(0.1, 0.05, 0.27, 0.4)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.42)
	gt.fill_to = Vector2(1.1, 1.0)
	var tr := TextureRect.new()
	tr.texture = gt
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	K.full_rect(tr)
	add_child(tr)
	move_child(tr, 0)


# ---------------- bara de sus ----------------
func _top_bar() -> void:
	var hb := HBoxContainer.new()
	K.place(hb, true, 14, 84, 18, 18)
	hb.add_theme_constant_override("separation", 14)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hb)

	var av := PanelContainer.new()
	av.custom_minimum_size = Vector2(80, 80)
	av.add_theme_stylebox_override("panel", K.box(Color("fff3e0"), 26, K.GOLD, 5))
	var face := K.label("☺", 46, K.INK)
	face.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	face.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	av.add_child(face)
	av.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(av)

	var name_lbl := K.label("Buble", 56, Color.WHITE, 900, 10)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hb.add_child(name_lbl)

	var pill := PanelContainer.new()
	pill.add_theme_stylebox_override("panel", K.box(Color("f6f0ff"), 50, Color("d9c8ff"), 2, 6, 14))
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coins_lbl = K.label("🪙 0", 30, K.INK, 800)
	pill.add_child(coins_lbl)
	hb.add_child(pill)

	var badge := PanelContainer.new()
	var bs := K.box(Color("7347d8"), 26, K.GOLD, 4, 0, 6)
	bs.corner_radius_bottom_left = 40
	bs.corner_radius_bottom_right = 40
	badge.add_theme_stylebox_override("panel", bs)
	badge.custom_minimum_size = Vector2(86, 84)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", -6)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := K.label("NIVEL", 17)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lvl_lbl = K.label("1", 38, Color.WHITE, 900)
	lvl_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	vb.add_child(lvl_lbl)
	badge.add_child(vb)
	hb.add_child(badge)


func _xp_bar() -> void:
	var p := PanelContainer.new()
	K.place(p, true, 116, 92, 18, 18)
	p.add_theme_stylebox_override("panel", K.box(Color(1, 1, 1, 0.82), 32, Color.TRANSPARENT, 0, 8, 16))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(p)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(hb)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(vb)
	prog_lbl = K.label("", 24, K.INK, 800)
	vb.add_child(prog_lbl)
	xp_bar = ProgressBar.new()
	xp_bar.show_percentage = false
	xp_bar.custom_minimum_size = Vector2(0, 18)
	xp_bar.add_theme_stylebox_override("background", K.box(Color(0.29, 0.23, 0.6, 0.33), 9))
	xp_bar.add_theme_stylebox_override("fill", K.box(Color("f7b82a"), 9))
	xp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(xp_bar)
	var mis := K.button("Misiuni", 26, K.box(Color.WHITE, 26, Color("e4d8ff"), 2, 0, 14), K.VIO)
	mis.pressed.connect(func():
		show_toast("%s Îmbunătățește o clădire  •  %s Joacă Buble Blast" % ["✅" if Game.missions.up else "⬜", "✅" if Game.missions.blast else "⬜"], 3.5))
	hb.add_child(mis)


func _title() -> void:
	var vb := VBoxContainer.new()
	K.place(vb, false, 365, 90, 0, 0)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 0)
	var t1 := K.label("Grădina dintre nori", 44, Color.WHITE, 900, 10, Color(0.1, 0.05, 0.3, 0.6))
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var t2 := K.label("Atinge o clădire ca să o dezvolți", 24, Color(1, 1, 1, 0.9), 600, 6, Color(0.1, 0.05, 0.3, 0.5))
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t1)
	vb.add_child(t2)
	root.add_child(vb)
	title = vb


# ---------------- foaia de upgrade ----------------
func _sheet() -> void:
	sheet = PanelContainer.new()
	sheet.add_theme_stylebox_override("panel", K.box(Color(0.125, 0.1, 0.37, 0.95), 36, K.GOLD, 4, 14, 22))
	sheet.anchor_left = 0
	sheet.anchor_right = 1
	sheet.anchor_top = 1
	sheet.anchor_bottom = 1
	sheet.offset_left = 26
	sheet.offset_right = -26
	sheet.offset_bottom = -362
	sheet.grow_vertical = Control.GROW_DIRECTION_BEGIN
	sheet.visible = false
	root.add_child(sheet)
	sheet_box = VBoxContainer.new()
	sheet_box.add_theme_constant_override("separation", 10)
	sheet.add_child(sheet_box)


func _refresh_sheet() -> void:
	var id := Game.sel
	sheet.visible = id != ""
	title.visible = id == ""
	if id == "":
		return
	for c in sheet_box.get_children():
		c.queue_free()
	var b := Game.building(id)
	var lvl: int = Game.levels[id]
	var row := HBoxContainer.new()
	var n := K.label(b.n, 32, Color.WHITE, 900)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(n)
	row.add_child(K.label("Nivel %d/%d" % [lvl, Game.MAX_LVL], 28))
	sheet_box.add_child(row)
	var pips := K.label("●".repeat(lvl) + "○".repeat(Game.MAX_LVL - lvl), 30, K.GOLD)
	pips.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sheet_box.add_child(pips)
	if lvl >= Game.MAX_LVL:
		var mx := K.label("✨ Nivel maxim atins", 30, K.GOLD, 900)
		mx.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sheet_box.add_child(mx)
		return
	var cs := Game.cost(id)
	var up := K.gold_button("Îmbunătățește · 🪙 %d" % cs, 30)
	up.custom_minimum_size = Vector2(0, 84)
	var lack := Game.coins < cs
	if lack:
		up.modulate = Color(0.75, 0.72, 0.8, 0.8)
	up.pressed.connect(func():
		if Game.upgrade(id):
			Sfx.play("upgrade")
		else:
			Sfx.play("click")
			show_toast("Îți mai trebuie %d monede. Joacă Buble Blast!" % ceili(Game.cost(id) - Game.coins)))
	sheet_box.add_child(up)
	if lack:
		var s := K.label("Îți mai trebuie %d monede. Joacă Buble Blast!" % ceili(cs - Game.coins), 22, Color(1, 1, 1, 0.8), 600)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sheet_box.add_child(s)


# ---------------- butoane principale ----------------
func _blast_button() -> void:
	var b := K.gold_button("", 54)
	K.place(b, false, 168, 146, 30, 30)
	var vb := VBoxContainer.new()
	K.full_rect(vb)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", -4)
	var t1 := K.label("Buble Blast", 54, K.INK, 900)
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var t2 := K.label("JOACĂ ȘI CÂȘTIGĂ MONEDE", 22, Color(K.INK, 0.7), 800)
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blast_sub = t2
	vb.add_child(t1)
	vb.add_child(t2)
	b.add_child(vb)
	b.pressed.connect(_open_blast)
	root.add_child(b)


func _nav() -> void:
	var p := PanelContainer.new()
	K.place(p, false, 14, 132, 14, 14)
	p.add_theme_stylebox_override("panel", K.box(Color(0.145, 0.114, 0.416, 0.95), 52, Color("7a6ad8"), 4, 0, 8))
	root.add_child(p)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	p.add_child(hb)
	var on := K.box(Color(0.48, 0.35, 0.85, 0.67), 40, K.GOLD, 4)
	for it in [["home", "🏠", "Acasă"], ["album", "🃏", "Album"], ["friends", "👥", "Prieteni"], ["events", "🏆", "Evenimente"], ["shop", "🏪", "Magazin"]]:
		var b := K.button("", 20)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.set_meta("on_style", on)
		var vb := VBoxContainer.new()
		K.full_rect(vb)
		vb.alignment = BoxContainer.ALIGNMENT_CENTER
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_theme_constant_override("separation", 0)
		var ic := K.label(it[1], 44)
		ic.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var tx := K.label(it[2], 20, Color.WHITE, 800)
		tx.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(ic)
		vb.add_child(tx)
		b.add_child(vb)
		var key: String = it[0]
		b.pressed.connect(func(): _nav_to(key))
		hb.add_child(b)
		nav_buttons[key] = b
	_set_nav("home")


func _set_nav(key: String) -> void:
	for k in nav_buttons:
		var b: Button = nav_buttons[k]
		var st: StyleBox = b.get_meta("on_style") if k == key else StyleBoxEmpty.new()
		for s in ["normal", "hover", "pressed", "hover_pressed"]:
			b.add_theme_stylebox_override(s, st)


func _nav_to(key: String) -> void:
	Sfx.play("click")
	_set_nav(key)
	if key == "home":
		_close_modal()
	else:
		_open_modal(key)


func _settings_button() -> void:
	var b := K.button("⚙️ Setări", 22, K.box(Color(0.125, 0.1, 0.37, 0.8), 26, Color(1, 1, 1, 0.33), 2, 0, 12))
	b.anchor_left = 1
	b.anchor_right = 1
	b.offset_left = -190
	b.offset_right = -18
	b.offset_top = 228
	b.offset_bottom = 284
	b.pressed.connect(func(): _open_modal("settings"))
	root.add_child(b)


# ---------------- mesaje ----------------
func _toast() -> void:
	toast_panel = PanelContainer.new()
	K.place(toast_panel, true, 296, 0, 36, 36)
	toast_panel.add_theme_stylebox_override("panel", K.box(Color(0.125, 0.1, 0.37, 0.92), 30, Color.TRANSPARENT, 0, 8, 18))
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_panel.modulate.a = 0.0
	toast_lbl = K.label("", 26, Color.WHITE, 800)
	toast_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_panel.add_child(toast_lbl)
	root.add_child(toast_panel)
	toast_timer = Timer.new()
	toast_timer.one_shot = true
	toast_timer.timeout.connect(func(): create_tween().tween_property(toast_panel, "modulate:a", 0.0, 0.3))
	add_child(toast_timer)


func show_toast(msg: String, secs := 2.2) -> void:
	toast_lbl.text = msg
	create_tween().tween_property(toast_panel, "modulate:a", 1.0, 0.2)
	toast_timer.start(secs)


func _refresh() -> void:
	coins_lbl.text = "🪙 " + _fmt(int(Game.coins))
	lvl_lbl.text = str(Game.player_level())
	prog_lbl.text = "Dezvoltă insula • %d/25 niveluri" % Game.sum_levels()
	xp_bar.value = Game.xp % 100
	if blast_sub:
		blast_sub.text = "NIVELUL %d • JOACĂ ȘI CÂȘTIGĂ MONEDE" % Game.blast_level
	_refresh_sheet()


static func _fmt(n: int) -> String:
	# separator de mii în stil românesc: 12.345
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


# ---------------- ferestre ----------------
func _modal() -> void:
	modal = K.full_rect(Control.new())
	modal.visible = false
	root.add_child(modal)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	K.full_rect(dim)
	dim.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			_nav_to("home"))
	modal.add_child(dim)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", K.box(K.CARD, 44, K.GOLD, 4, 16, 30))
	card.anchor_left = 0.5
	card.anchor_right = 0.5
	card.anchor_top = 0.5
	card.anchor_bottom = 0.5
	card.offset_left = -330
	card.offset_right = 330
	card.offset_top = -440
	card.offset_bottom = 440
	modal.add_child(card)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card.add_child(scroll)
	modal_box = VBoxContainer.new()
	modal_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal_box.add_theme_constant_override("separation", 14)
	scroll.add_child(modal_box)
	var x := K.button("✕", 40)
	x.anchor_left = 1
	x.anchor_right = 1
	x.offset_left = -84
	x.offset_right = -14
	x.offset_top = 6
	x.offset_bottom = 76
	x.pressed.connect(func(): _nav_to("home"))
	card.add_child(x)


func _close_modal() -> void:
	modal.visible = false


func _open_modal(kind: String) -> void:
	for c in modal_box.get_children():
		c.queue_free()
	match kind:
		"album":
			_h("Album")
			_demo("DEMO – fără server")
			_p("Colecția de cărți se va debloca din Buble Blast și evenimente. Schimburile necesită conturi online.")
			_grid(12, "🔒")
		"friends":
			_h("Prieteni")
			_demo("DEMO – fără server")
			_p("Prietenii, vizitarea insulelor și duelurile necesită cont și backend. În această versiune nu există alți jucători.")
			_row("Invită un prieten", "În curând")
			_row("Vizitează o insulă", "În curând")
		"events":
			_h("Evenimente")
			_demo("DEMO – fără server")
			_p("Expediția celor patru: eveniment cooperativ pentru 4 persoane.")
			_grid(4, "Liber")
			_row("Clasament cluburi", "În curând")
		"shop":
			_h("Magazin")
			_demo("DEMO – plăți dezactivate")
			for p in Monetization.PRODUCTS:
				var id: String = p.id
				_row("%s\n%s" % [p.n, p.desc], p.price, func(): Monetization.purchase(id))
		"settings":
			_settings()
	modal.visible = true


func _h(t: String) -> void:
	modal_box.add_child(K.label(t, 44, Color.WHITE, 900))


func _p(t: String) -> void:
	var l := K.label(t, 26, Color.WHITE, 600)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(560, 0)
	modal_box.add_child(l)


func _demo(t: String) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", K.box(Color("e8445a"), 14, Color.TRANSPARENT, 0, 0, 8))
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	p.add_child(K.label(t, 20, Color.WHITE, 900))
	modal_box.add_child(p)


func _row(a: String, b: String, action := Callable()) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", K.box(Color(1, 1, 1, 0.1), 22, Color.TRANSPARENT, 0, 0, 18))
	var hb := HBoxContainer.new()
	var la := K.label(a, 25, Color.WHITE, 700)
	la.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	la.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hb.add_child(la)
	if action.is_valid():
		var btn := K.gold_button(b, 22)
		btn.custom_minimum_size = Vector2(170, 60)
		btn.pressed.connect(action)
		hb.add_child(btn)
	else:
		hb.add_child(K.label(b, 23, Color(1, 1, 1, 0.7), 700))
	p.add_child(hb)
	modal_box.add_child(p)


func _grid(n: int, txt: String) -> void:
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 14)
	g.add_theme_constant_override("v_separation", 14)
	for i in n:
		var p := PanelContainer.new()
		p.custom_minimum_size = Vector2(130, 170)
		p.add_theme_stylebox_override("panel", K.box(Color(1, 1, 1, 0.09), 18, Color(1, 1, 1, 0.33), 3))
		var l := K.label(txt, 36 if txt.length() < 3 else 22)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		p.add_child(l)
		g.add_child(p)
	modal_box.add_child(g)


func _settings() -> void:
	_h("Setări")
	modal_box.add_child(K.label("Calitate grafică", 30, Color.WHITE, 900))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	for q in [["inalta", "Înaltă"], ["scazuta", "Scăzută"]]:
		var on: bool = Game.quality == q[0]
		var b := K.button(q[1], 26, K.box(Color("7a5ad8") if on else Color(1, 1, 1, 0.1), 22, K.GOLD if on else Color(1, 1, 1, 0.27), 3, 0, 16))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var key: String = q[0]
		b.pressed.connect(func():
			Game.set_quality(key)
			_open_modal("settings"))
		hb.add_child(b)
	modal_box.add_child(hb)
	_p("Calitatea înaltă activează strălucirea (bloom), umbre fine și anti-aliasing. Pe telefoane lente, alege „Scăzută”.")
	modal_box.add_child(K.label("Sunet", 30, Color.WHITE, 900))
	var hs := HBoxContainer.new()
	hs.add_theme_constant_override("separation", 12)
	for q in [[true, "🔊 Pornit"], [false, "🔇 Oprit"]]:
		var on: bool = Game.sound == q[0]
		var b := K.button(q[1], 26, K.box(Color("7a5ad8") if on else Color(1, 1, 1, 0.1), 22, K.GOLD if on else Color(1, 1, 1, 0.27), 3, 0, 16))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var val: bool = q[0]
		b.pressed.connect(func():
			Game.sound = val
			Game.save_game()
			Sfx.play("click")
			_open_modal("settings"))
		hs.add_child(b)
	modal_box.add_child(hs)
	modal_box.add_child(K.label("Modele 3D", 30, Color.WHITE, 900))
	_p("Modelele se pun în folderul res://models/ al proiectului. Piesele fără model folosesc geometria din cod.")
	var names := {"palat": "Palat", "obs": "Observator", "turn": "Turn", "mag": "Magazin", "sera": "Seră", "mascot": "Mascotă", "insula": "Insulă"}
	for k in names:
		_row(names[k], "GLB" if Models.has(k) else "procedural")


# ---------------- Buble Blast + reclame ----------------
func _open_blast() -> void:
	Game.select("")
	blast = BubleBlast.new()
	K.full_rect(blast)
	blast.closed.connect(_on_blast_closed)
	Sfx.play("click")
	root.add_child(blast)
	get_viewport().disable_3d = true


func _on_blast_closed(rewarded: bool) -> void:
	get_viewport().disable_3d = false
	blast = null
	_refresh()
	if rewarded:
		Game.mascot_jump.emit()
		Sfx.play("coin")
		show_toast("Monedele au fost adăugate în insulă 🪙")


func _ad_overlay() -> void:
	ad_overlay = K.full_rect(ColorRect.new())
	(ad_overlay as ColorRect).color = Color(0.05, 0.03, 0.15, 0.97)
	ad_overlay.visible = false
	ad_overlay.z_index = 10
	add_child(ad_overlay)


func _show_demo_ad(_placement: String) -> void:
	for c in ad_overlay.get_children():
		c.queue_free()
	var vb := VBoxContainer.new()
	K.full_rect(vb)
	vb.offset_left = 60
	vb.offset_right = -60
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 22)
	ad_overlay.add_child(vb)
	var tag := K.label("RECLAMĂ DEMO", 30, Color("e8445a"), 900)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(tag)
	var info := K.label("Aici va rula o reclamă cu recompensă după activarea monetizării. Acum nu se afișează nicio reclamă reală.", 26, Color.WHITE, 600)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(info)
	var ok := K.gold_button("Primește recompensa (3)", 28)
	ok.custom_minimum_size = Vector2(0, 90)
	ok.disabled = true
	vb.add_child(ok)
	var cancel := K.button("Renunță", 24)
	vb.add_child(cancel)
	ok.pressed.connect(func():
		ad_overlay.visible = false
		Monetization.finish_demo_ad(true))
	cancel.pressed.connect(func():
		ad_overlay.visible = false
		Monetization.finish_demo_ad(false))
	ad_overlay.visible = true
	for i in range(2, -1, -1):
		await get_tree().create_timer(1.0).timeout
		ok.text = "Primește recompensa" + (" (%d)" % i if i > 0 else "")
	ok.disabled = false
