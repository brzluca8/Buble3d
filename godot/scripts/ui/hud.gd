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
	_nav()
	_settings_button()
	_play_ui()
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
	if Game.offline_msg != "":
		get_tree().create_timer(3.4).timeout.connect(func(): show_toast(Game.offline_msg, 4.0))


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
	K.place(hb, true, 12, 70, 16, 16)
	hb.add_theme_constant_override("separation", 12)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hb)

	var av := PanelContainer.new()
	av.custom_minimum_size = Vector2(68, 68)
	av.add_theme_stylebox_override("panel", K.box(Color("fff3e0"), 26, K.GOLD, 5))
	var face := K.label("☺", 40, K.INK)
	face.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	face.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	av.add_child(face)
	av.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(av)

	var name_lbl := K.label("Buble", 48, Color.WHITE, 900, 10)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hb.add_child(name_lbl)

	var pill := PanelContainer.new()
	pill.add_theme_stylebox_override("panel", K.box(Color("f6f0ff"), 50, Color("d9c8ff"), 2, 6, 14))
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coins_lbl = K.label("🪙 0", 27, K.INK, 800)
	pill.add_child(coins_lbl)
	hb.add_child(pill)

	var badge := PanelContainer.new()
	var bs := K.box(Color("7347d8"), 26, K.GOLD, 4, 0, 6)
	bs.corner_radius_bottom_left = 40
	bs.corner_radius_bottom_right = 40
	badge.add_theme_stylebox_override("panel", bs)
	badge.custom_minimum_size = Vector2(76, 70)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", -6)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := K.label("NIVEL", 15)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lvl_lbl = K.label("1", 32, Color.WHITE, 900)
	lvl_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	vb.add_child(lvl_lbl)
	badge.add_child(vb)
	hb.add_child(badge)


func _xp_bar() -> void:
	var p := PanelContainer.new()
	K.place(p, true, 92, 60, 16, 16)
	p.add_theme_stylebox_override("panel", K.box(Color(1, 1, 1, 0.8), 28, Color.TRANSPARENT, 0, 6, 10))
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
	prog_lbl = K.label("", 20, K.INK, 800)
	vb.add_child(prog_lbl)
	xp_bar = ProgressBar.new()
	xp_bar.show_percentage = false
	xp_bar.custom_minimum_size = Vector2(0, 12)
	xp_bar.add_theme_stylebox_override("background", K.box(Color(0.29, 0.23, 0.6, 0.33), 9))
	xp_bar.add_theme_stylebox_override("fill", K.box(Color("f7b82a"), 9))
	xp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(xp_bar)
	var mis := K.button("📜", 26, K.box(Color.WHITE, 22, Color("e4d8ff"), 2, 0, 8), K.VIO)
	mis.tooltip_text = "Misiuni"
	mis.pressed.connect(func():
		show_toast("%s Îmbunătățește o clădire  •  %s Joacă Buble Blast" % ["✅" if Game.missions.up else "⬜", "✅" if Game.missions.blast else "⬜"], 3.5))
	hb.add_child(mis)


func _title() -> void:
	var vb := VBoxContainer.new()
	K.place(vb, true, 214, 70, 100, 100)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", -2)
	var t1 := K.label(Game.island_name(), 34, Color.WHITE, 900, 9, Color(0.1, 0.05, 0.3, 0.55))
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var t2 := K.label("Aruncă zarurile, adună monede, construiește insula", 19, Color(1, 1, 1, 0.92), 600, 6, Color(0.1, 0.05, 0.3, 0.5))
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t1)
	vb.add_child(t2)
	root.add_child(vb)
	title = vb
	# titlul dispare după câteva secunde, ca să lase insula la vedere
	get_tree().create_timer(6.0).timeout.connect(func(): create_tween().tween_property(title, "modulate:a", 0.0, 1.2))


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
	sheet.offset_bottom = -252
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
	up.custom_minimum_size = Vector2(0, 76)
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
	var b := K.gold_button("", 44)
	K.place(b, false, 132, 104, 40, 40)
	var vb := VBoxContainer.new()
	K.full_rect(vb)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", -4)
	var t1 := K.label("Buble Blast", 44, K.INK, 900)
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var t2 := K.label("JOACĂ ȘI CÂȘTIGĂ MONEDE", 18, Color(K.INK, 0.7), 800)
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blast_sub = t2
	vb.add_child(t1)
	vb.add_child(t2)
	b.add_child(vb)
	b.pressed.connect(_open_blast)
	root.add_child(b)


func _nav() -> void:
	var p := PanelContainer.new()
	K.place(p, false, 10, 112, 12, 12)
	p.add_theme_stylebox_override("panel", K.box(Color(0.145, 0.114, 0.416, 0.93), 46, Color("7a6ad8"), 3, 0, 6))
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
		var ic := K.label(it[1], 36)
		ic.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var tx := K.label(it[2], 18, Color.WHITE, 800)
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
	# un singur buton ☰ care deschide un meniu mic (Setări, Vederea generală, Buble Blast)
	var st := K.box(Color(0.125, 0.1, 0.37, 0.78), 32, Color(1, 1, 1, 0.35), 2)
	var menu_btn := K.button("☰", 30, st)
	menu_btn.anchor_left = 1
	menu_btn.anchor_right = 1
	menu_btn.offset_left = -80
	menu_btn.offset_right = -16
	menu_btn.offset_top = 164
	menu_btn.offset_bottom = 228
	root.add_child(menu_btn)
	var menu := VBoxContainer.new()
	menu.anchor_left = 1
	menu.anchor_right = 1
	menu.offset_left = -250
	menu.offset_right = -16
	menu.offset_top = 236
	menu.offset_bottom = 470
	menu.add_theme_constant_override("separation", 8)
	menu.visible = false
	root.add_child(menu)
	var items := [["⚙️  Setări", func(): _open_modal("settings")], ["⟲  Vederea generală", _reset_view], ["🫧  Buble Blast", _open_blast]]
	for it in items:
		var b := K.button(it[0], 22, K.box(Color(0.125, 0.1, 0.37, 0.92), 22, Color(1, 1, 1, 0.3), 2, 0, 10))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var cb: Callable = it[1]
		b.pressed.connect(func():
			menu.visible = false
			cb.call())
		menu.add_child(b)
	menu_btn.pressed.connect(func():
		Sfx.play("click")
		menu.visible = not menu.visible)


var play: Control

func _play_ui() -> void:
	play = preload("res://scripts/ui/play_ui.gd").new()
	play.hud = self
	play.world = get_parent()
	root.add_child(play)


## Revine la perspectiva implicită a insulei.
func _reset_view() -> void:
	Sfx.play("click")
	Game.select("")
	var c := get_viewport().get_camera_3d()
	if c and c.has_method("reset_view"):
		c.reset_view()


# ---------------- mesaje ----------------
func _toast() -> void:
	toast_panel = PanelContainer.new()
	K.place(toast_panel, true, 164, 0, 96, 96)
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
	prog_lbl.text = "🏝️ %s • %d/25" % [Game.island_name(), Game.sum_levels()]
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
	# butonul ✕ stă în colțul ferestrei (nu în interiorul containerului, care l-ar centra)
	var x := K.button("✕", 40)
	x.anchor_left = 0.5
	x.anchor_right = 0.5
	x.anchor_top = 0.5
	x.anchor_bottom = 0.5
	x.offset_left = 330 - 84
	x.offset_right = 330 - 14
	x.offset_top = -440 + 6
	x.offset_bottom = -440 + 76
	x.pressed.connect(func(): _nav_to("home"))
	modal.add_child(x)


func _close_modal() -> void:
	modal.visible = false


func _open_modal(kind: String) -> void:
	for c in modal_box.get_children():
		c.queue_free()
	match kind:
		"album":
			_h("Album")
			_p("Cărțile vin din cufere și din premiile evenimentelor. Un set complet dă +%d 🫧. Schimbul de cărți cu prietenii vine odată cu conturile online." % Game.CARD_SET_REWARD)
			for si in Game.CARD_SETS.size():
				var set_d: Dictionary = Game.CARD_SETS[si]
				var have := 0
				for ci in set_d.cards.size():
					if Game.cards.get(Game.card_key(si, ci), 0) > 0:
						have += 1
				modal_box.add_child(K.label("%s  %d/%d%s" % [set_d.n, have, set_d.cards.size(), "  ✅" if have == set_d.cards.size() else ""], 28, K.GOLD, 900))
				var g := GridContainer.new()
				g.columns = 3
				g.add_theme_constant_override("h_separation", 10)
				g.add_theme_constant_override("v_separation", 10)
				for ci in set_d.cards.size():
					var n: int = Game.cards.get(Game.card_key(si, ci), 0)
					var pc := PanelContainer.new()
					pc.custom_minimum_size = Vector2(180, 110)
					pc.add_theme_stylebox_override("panel", K.box(Color("3a2f96") if n > 0 else Color(1, 1, 1, 0.07), 16, K.GOLD if n > 0 else Color(1, 1, 1, 0.25), 2, 0, 8))
					var stars := "★".repeat(1 + ci * 5 / set_d.cards.size())
					var lb := K.label(("%s\n%s%s" % [set_d.cards[ci], stars, ("  ×%d" % n) if n > 1 else ""]) if n > 0 else "🔒\n" + stars, 20, Color.WHITE if n > 0 else Color(1, 1, 1, 0.5), 800)
					lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
					lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
					lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
					pc.add_child(lb)
					g.add_child(pc)
				modal_box.add_child(g)
		"friends":
			_h("Prieteni")
			if not Net.online:
				_demo("OFFLINE")
				_p("Prietenii, atacurile între jucători, jafurile și cadourile de cărți funcționează cu serverul Buble. Adaugă adresa serverului în ⚙️ Setări. Până atunci, rivalul tău este %s." % Game.RIVAL)
			else:
				_p("Codul tău de prieten: %s – trimite-l prietenilor." % Net.code)
				var hb := HBoxContainer.new()
				var le := LineEdit.new()
				le.placeholder_text = "Codul unui prieten"
				le.add_theme_font_size_override("font_size", 26)
				le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				le.max_length = 6
				hb.add_child(le)
				var add := K.gold_button("Adaugă", 24)
				add.custom_minimum_size = Vector2(160, 60)
				add.pressed.connect(func():
					var r: Dictionary = await Net.add_friend(le.text)
					show_toast("Prieten adăugat 👥" if r._code == 200 else "Cod necunoscut")
					_open_modal("friends"))
				hb.add_child(add)
				modal_box.add_child(hb)
				if Net.friends.is_empty():
					await Net.load_friends()
				for f in Net.friends:
					var fid := int(f.id)
					_row("%s %s\n🏝️ insula %d" % ["🟢" if f.online else "⚪", f.name, f.island], "🃏 Cadou", func(): _gift_card(fid))
		"events":
			_h("Evenimente")
			modal_box.add_child(K.label("⭐ %s" % Game.EVENT_NAME, 30, K.GOLD, 900))
			_p("Puncte: %d / %d. Puncte primești pe căsuțele ⭐ (înmulțite cu multiplicatorul)." % [Game.event_pts, Game.event_next_goal()])
			for i in Game.EVENT_GOALS.size():
				var g: Array = Game.EVENT_GOALS[i]
				var rew: String = {"energy": "%d 🫧" % g[2], "coins": "%d unități 🪙" % g[2], "cards": "%d cărți 🃏" % g[2]}[g[1]]
				_row("%s %d puncte" % ["✅" if i < Game.event_step else "⬜", g[0]], rew)
			modal_box.add_child(K.label("👥 Expediția celor patru", 30, K.GOLD, 900))
			if not Net.online:
				_p("Eveniment în echipă de 4 jucători – disponibil cu serverul Buble (⚙️ Setări).")
			else:
				if Net.team == null:
					var join := K.gold_button("Intră într-o echipă", 26)
					join.custom_minimum_size = Vector2(0, 70)
					join.pressed.connect(func():
						await Net.team_join()
						_open_modal("events"))
					modal_box.add_child(join)
				else:
					_p("Echipa ta: %d / %d puncte" % [Net.team.points, Net.team.goal])
					for m in Net.team.members:
						_row(m.name, "%d ⭐" % m.points)
		"shop":
			_h("Magazin")
			_demo("DEMO – plăți dezactivate")
			for p in Monetization.PRODUCTS:
				var id: String = p.id
				_row("%s\n%s" % [p.n, p.desc], p.price, func(): Monetization.purchase(id))
		"settings":
			_settings()
	modal.visible = true


## Trimite unui prieten o carte dublură (ai cel puțin 2 exemplare).
func _gift_card(friend_id: int) -> void:
	var dup := ""
	for k in Game.cards:
		if Game.cards[k] >= 2:
			dup = k
			break
	if dup == "":
		show_toast("Nu ai cărți duble de dăruit")
		return
	var r: Dictionary = await Net.gift_card(friend_id, dup)
	if r._code == 200:
		Game.cards[dup] -= 1
		Game.save_game()
		show_toast("Carte trimisă 🃏")
	else:
		show_toast("Cadoul nu a putut fi trimis")


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
	modal_box.add_child(K.label("Server online", 30, Color.WHITE, 900))
	_p("Stare: %s%s" % ["🟢 conectat (cod %s)" % Net.code if Net.online else "⚪ offline", ("  – " + Net.last_error) if Net.last_error != "" and not Net.online else ""])
	var url := LineEdit.new()
	url.placeholder_text = "https://serverul-tau.ro"
	url.text = Net.base_url
	url.add_theme_font_size_override("font_size", 24)
	modal_box.add_child(url)
	var nm := LineEdit.new()
	nm.placeholder_text = "Numele tău în joc"
	nm.text = Net.player_name
	nm.max_length = 24
	nm.add_theme_font_size_override("font_size", 24)
	modal_box.add_child(nm)
	var conn := K.gold_button("Conectează" if url.text == "" or not Net.online else "Reconectează", 26)
	conn.custom_minimum_size = Vector2(0, 70)
	conn.pressed.connect(func():
		var ok: bool = await Net.set_server(url.text, nm.text)
		show_toast("Conectat la server 🟢" if ok else ("Mod offline" if url.text.strip_edges() == "" else "Serverul nu răspunde"))
		_open_modal("settings"))
	modal_box.add_child(conn)
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
