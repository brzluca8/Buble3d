extends CanvasLayer
## Interfața ecranului principal (orașul din glob): bară de sus, progresul nivelului, cufere,
## rezervor, serie zilnică, butonul spre mașina de bule, foaia de construcție, navigare și ferestre.
## Rotirile au pagina lor (scenes/mecanism.tscn, scripts/ui/mechanism_ui.gd, care extinde clasa asta).
## Fără emoji: iconițe Lucide (ISC) și fontul Nunito (OFL).

const K := preload("res://scripts/ui/ui_kit.gd")
const NAV_H := 112.0
const SLOT_H := 104.0                     # butonul „Mașina de bule” de deasupra navigării

var root: Control
var coins_lbl: Label
var perle_lbl: Label
var lvl_lbl: Label
var prog_lbl: Label
var prog_cnt: Label
var prog_bar: ProgressBar
var chest_btns: Array[Button] = []
var res_btn: Button
var streak_btn: Button
var title: Control
var sheet: PanelContainer
var sheet_box: VBoxContainer
var slot: Control
var toast_panel: PanelContainer
var toast_lbl: Label
var toast_timer: Timer
var modal: Control
var modal_box: VBoxContainer
var modal_title: Label
var action_panel: PanelContainer
var wipe_rect: ColorRect
var nav_buttons := {}


func _ready() -> void:
	root = K.full_rect(Control.new())
	root.theme = K.theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)
	_top_bar()
	_progress()
	_side()
	_title()
	_launcher()
	_sheet()
	_nav()
	_toast()
	_modal()
	_wipe_rect()
	Game.changed.connect(_refresh)
	Game.selected.connect(func(_id): _refresh_sheet())
	Game.toast.connect(show_toast)
	Game.globe_completed.connect(_on_globe_completed)
	Game.level_up.connect(func(l): _celebrate_level(l))
	_refresh()
	if not Game.pending_action.is_empty():
		_run_pending.call_deferred()
	elif Game.streak_available():
		get_tree().create_timer(0.8).timeout.connect(func(): open_modal("serie"))


func _apply_safe_area() -> void:
	var win := DisplayServer.window_get_size()
	var safe := DisplayServer.get_display_safe_area()
	var vp := root.get_viewport_rect().size
	if win.y <= 0:
		return
	var k := vp.y / float(win.y)
	var top := maxf(0.0, safe.position.y) * k
	var bottom := maxf(0.0, win.y - safe.end.y) * k
	if safe.size.y <= 0 or bottom > vp.y * 0.2:
		top = 0.0
		bottom = 0.0
	root.offset_top = top
	root.offset_bottom = -bottom


func _ignore(c: Control) -> Control:
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


# ---------------- bara de sus ----------------
func _top_bar() -> void:
	var hb := HBoxContainer.new()
	K.place(hb, true, 12, 70, 16, 16)
	hb.add_theme_constant_override("separation", 10)
	_ignore(hb)
	root.add_child(hb)
	# avatar: cercul auriu cu inițiala jucătorului
	var av := PanelContainer.new()
	av.custom_minimum_size = Vector2(66, 66)
	av.add_theme_stylebox_override("panel", K.box(Color("f3e9d6"), 33, K.GOLD, 4))
	var ini := K.label("B", 34, K.INK, 900)
	ini.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ini.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	av.add_child(ini)
	hb.add_child(_ignore(av))
	var logo := K.label("Buble", 44, Color.WHITE, 900, 8, Color(0.08, 0.05, 0.3, 0.7))
	logo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	logo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hb.add_child(logo)
	coins_lbl = _chip(hb, "coins", K.GOLD)
	perle_lbl = _chip(hb, "gem", Color("8ff4ec"))
	var badge := PanelContainer.new()
	var bs := K.box(Color("4a2a9e"), 22, K.GOLD, 3, 0, 4)
	bs.corner_radius_bottom_left = 36
	bs.corner_radius_bottom_right = 36
	badge.add_theme_stylebox_override("panel", bs)
	badge.custom_minimum_size = Vector2(70, 70)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", -6)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	var t := K.label("NIVEL", 13, Color(1, 1, 1, 0.8), 800)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lvl_lbl = K.label("1", 30, Color.WHITE, 900)
	lvl_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	vb.add_child(lvl_lbl)
	badge.add_child(vb)
	hb.add_child(_ignore(badge))


func _chip(parent: Control, icon: String, col: Color) -> Label:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", K.glass(26, 8, 0.75))
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	hb.add_child(K.icon_rect(icon, 28, col))
	var l := K.label("0", 24, Color.WHITE, 800)
	hb.add_child(l)
	p.add_child(hb)
	parent.add_child(_ignore(p))
	return l


func _progress() -> void:
	var p := PanelContainer.new()
	K.place(p, true, 92, 58, 16, 16)
	p.add_theme_stylebox_override("panel", K.glass(24, 10, 0.72))
	root.add_child(_ignore(p))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	p.add_child(_ignore(vb))
	var hb := HBoxContainer.new()
	prog_lbl = K.label("", 19, Color.WHITE, 800)
	prog_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prog_cnt = K.label("", 19, K.GOLD, 800)
	hb.add_child(prog_lbl)
	hb.add_child(prog_cnt)
	vb.add_child(_ignore(hb))
	prog_bar = ProgressBar.new()
	prog_bar.show_percentage = false
	prog_bar.custom_minimum_size = Vector2(0, 8)
	prog_bar.add_theme_stylebox_override("background", K.box(Color(1, 1, 1, 0.15), 4))
	prog_bar.add_theme_stylebox_override("fill", K.box(K.GOLD, 4))
	vb.add_child(_ignore(prog_bar))


## Cufere (stânga) și butoane rapide (dreapta).
func _side() -> void:
	var hb := HBoxContainer.new()
	hb.position = Vector2(16, 160)
	hb.add_theme_constant_override("separation", 8)
	root.add_child(hb)
	for i in int(Game.cfg("chests.slots", 3)):
		var b := K.icon_button("package", "", 15, K.glass(18, 4, 0.7), Color(1, 1, 1, 0.35), 34)
		b.custom_minimum_size = Vector2(84, 74)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		var idx := i
		b.pressed.connect(func(): _chest_tap(idx))
		hb.add_child(b)
		chest_btns.append(b)
	var col := VBoxContainer.new()
	col.anchor_left = 1
	col.anchor_right = 1
	col.offset_left = -84
	col.offset_right = -16
	col.offset_top = 160
	col.add_theme_constant_override("separation", 8)
	root.add_child(col)
	res_btn = _round(col, "wallet", "Rezervor", func():
		var a := Game.collect_reservoir()
		if a > 0:
			Sfx.play("coin")
			show_toast("Rezervor: +%s monede" % Game.fmt(a))
		else:
			show_toast("Rezervorul se umple din clădirile construite"))
	streak_btn = _round(col, "calendar", "Serie zilnică", func(): open_modal("serie"))
	_round(col, "settings", "Setări", func(): open_modal("setari"))
	_round(col, "rotate-ccw", "Vederea generală", _reset_view)


func _round(parent: Control, icon: String, tip: String, cb: Callable) -> Button:
	var b := K.icon_button(icon, "", 14, K.glass(34, 4, 0.75), Color.WHITE, 32)
	b.custom_minimum_size = Vector2(68, 68)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.tooltip_text = tip
	b.pressed.connect(func():
		Sfx.play("click")
		cb.call())
	parent.add_child(b)
	return b


func _title() -> void:
	var vb := VBoxContainer.new()
	K.place(vb, true, 250, 70, 110, 110)
	vb.add_theme_constant_override("separation", -2)
	var t1 := K.label(Game.globe_name(), 32, Color.WHITE, 900, 8, Color(0.08, 0.05, 0.3, 0.6))
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t1.name = "Glob"
	var t2 := K.label("Rotește, construiește, călătorește", 18, Color(1, 1, 1, 0.9), 700, 6, Color(0.08, 0.05, 0.3, 0.5))
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t1)
	vb.add_child(t2)
	root.add_child(_ignore(vb))
	title = vb
	get_tree().create_timer(5.0).timeout.connect(func(): create_tween().tween_property(title, "modulate:a", 0.0, 1.2))


# ---------------- butonul spre mașina de bule ----------------
var launch_energy: Label

func _launcher() -> void:
	var b := K.gold_button("", 30)
	slot = b
	K.place(slot, false, NAV_H + 18, SLOT_H, 40, 40)
	var hb := HBoxContainer.new()
	K.full_rect(hb)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 14)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(K.icon_rect("sparkles", 44, K.INK))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", -4)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(K.label("Mașina de bule", 34, K.INK, 900))
	launch_energy = K.label("", 18, Color(K.INK, 0.8), 800)
	vb.add_child(launch_energy)
	hb.add_child(vb)
	slot.add_child(hb)
	b.pressed.connect(open_mechanism)
	root.add_child(slot)


func open_mechanism() -> void:
	Sfx.play("click")
	Game.select("")
	Game.save_game()
	await wipe(func(): pass)
	get_tree().change_scene_to_file("res://scenes/mecanism.tscn")


## Atacul / raidul pornite din pagina mașinii se joacă aici, apoi jucătorul se întoarce acolo.
func _run_pending() -> void:
	var p: Dictionary = Game.pending_action
	Game.pending_action = {}
	await get_tree().create_timer(0.3).timeout
	match p.get("type", ""):
		"attack":
			await _attack_flow(int(p.get("mult", 1)))
		"raid":
			await _raid_flow(int(p.get("mult", 1)))
	if p.get("from", "") == "mecanism":
		await wipe(func(): pass)
		get_tree().change_scene_to_file("res://scenes/mecanism.tscn")


# ---------------- foaia de construcție ----------------
func _sheet() -> void:
	sheet = PanelContainer.new()
	sheet.add_theme_stylebox_override("panel", K.glass(30, 16, 0.92))
	sheet.anchor_left = 0
	sheet.anchor_right = 1
	sheet.anchor_top = 1
	sheet.anchor_bottom = 1
	sheet.offset_left = 22
	sheet.offset_right = -22
	sheet.offset_bottom = -(NAV_H + 18 + SLOT_H + 12)
	sheet.grow_vertical = Control.GROW_DIRECTION_BEGIN
	sheet.visible = false
	root.add_child(sheet)
	sheet_box = VBoxContainer.new()
	sheet_box.add_theme_constant_override("separation", 8)
	sheet.add_child(sheet_box)


func _refresh_sheet() -> void:
	var id := Game.sel
	sheet.visible = id != ""
	if id == "":
		return
	for c in sheet_box.get_children():
		c.queue_free()
	var b := Game.building(id)
	var st: int = Game.levels.get(id, 0)
	var row := HBoxContainer.new()
	var n := K.label(b.n, 30, Color.WHITE, 900)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(n)
	row.add_child(K.label("Etapa %d/%d" % [st, Game.MAX_STAGE], 22, K.GOLD, 800))
	var x := K.icon_button("x", "", 14, StyleBoxEmpty.new(), Color(1, 1, 1, 0.7), 28)
	x.pressed.connect(func(): Game.select(""))
	row.add_child(x)
	sheet_box.add_child(row)
	var u := Game.next_upgrade(id)
	if Game.is_building(id):
		var rem := Game.build_remaining(id)
		_sheet_text("În construcție: %s" % Game.fmt_time(rem))
		var sk := Game.skip_cost(id)
		var btn := K.icon_button("gem", "Termină acum · %d perle" % sk, 22, K.glass(30, 10), Color("8ff4ec"), 26)
		btn.custom_minimum_size = Vector2(0, 64)
		btn.disabled = Game.perle < sk
		btn.pressed.connect(func():
			if Game.skip_build(id):
				Sfx.play("upgrade"))
		sheet_box.add_child(btn)
	elif st >= Game.MAX_STAGE:
		_sheet_text("Construcție completă în acest glob.")
	elif Game.globe_locked():
		_sheet_text("Globul e terminat. Îmbunătățește dirijabilul ca să călătorești mai departe.")
	elif u.is_empty():
		_sheet_text("Următoarea etapă se deblochează la un nivel viitor.")
	else:
		var up := K.gold_button("", 28)
		up.custom_minimum_size = Vector2(0, 76)
		var hb := HBoxContainer.new()
		K.full_rect(hb)
		hb.alignment = BoxContainer.ALIGNMENT_CENTER
		hb.add_theme_constant_override("separation", 8)
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(K.label("Construiește", 28, K.INK, 900))
		hb.add_child(K.icon_rect("coins", 28, K.INK))
		hb.add_child(K.label(Game.fmt(u.cost), 28, K.INK, 900))
		up.add_child(hb)
		var ok: bool = Game.coins >= u.cost
		up.modulate = Color.WHITE if ok else Color(0.75, 0.72, 0.8)
		up.pressed.connect(func():
			if Game.upgrade(id):
				Sfx.play("build")
				Sfx.buzz(30)
				_refresh_sheet()
			elif Game.coins < u.cost:
				show_toast("Îți mai trebuie %s monede" % Game.fmt(int(u.cost - Game.coins))))
		sheet_box.add_child(up)
		var t: int = Game.build_time(u)
		_sheet_text(("Construcție: %s" % Game.fmt_time(t)) if t > 0 else "Construcție imediată")


func _sheet_text(t: String) -> void:
	var l := K.label(t, 21, Color(1, 1, 1, 0.85), 700)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sheet_box.add_child(l)


# ---------------- navigare ----------------
func _nav() -> void:
	var p := PanelContainer.new()
	K.place(p, false, 8, NAV_H, 12, 12)
	p.add_theme_stylebox_override("panel", K.glass(40, 6, 0.9))
	root.add_child(p)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 2)
	p.add_child(hb)
	for it in [["acasa", "house", "Acasă"], ["album", "book-open", "Album"], ["dirijabil", "ship", "Dirijabil"], ["evenimente", "calendar", "Evenimente"], ["magazin", "store", "Magazin"]]:
		var b := K.button(it[2], 17, StyleBoxEmpty.new(), Color.WHITE)
		b.icon = K.icon(it[1])
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 36)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var key: String = it[0]
		b.pressed.connect(func(): _nav_to(key))
		hb.add_child(b)
		nav_buttons[key] = b
	_set_nav("acasa")


func _set_nav(key: String) -> void:
	var on := K.box(Color(0.45, 0.32, 0.85, 0.55), 30, K.GOLD, 2)
	for k in nav_buttons:
		var b: Button = nav_buttons[k]
		for s in ["normal", "hover", "pressed", "hover_pressed"]:
			b.add_theme_stylebox_override(s, on if k == key else StyleBoxEmpty.new())


func _nav_to(key: String) -> void:
	Sfx.play("click")
	if key == "dirijabil":
		Game.save_game()
		get_tree().change_scene_to_file("res://scenes/airship.tscn")
		return
	_set_nav(key)
	if key == "acasa":
		close_modal()
	else:
		open_modal(key)


func _reset_view() -> void:
	Game.select("")
	var c := get_viewport().get_camera_3d()
	if c and c.has_method("reset_view"):
		c.reset_view()


# ---------------- actualizare ----------------
func _refresh() -> void:
	if launch_energy:
		launch_energy.text = "Energie %d / %d%s" % [Game.energy, Game.energy_cap(), ("  ·  +1 în " + Game.fmt_time(Game.energy_next_in())) if Game.energy < Game.energy_cap() else ""]
	coins_lbl.text = Game.fmt(int(Game.coins))
	perle_lbl.text = str(Game.perle)
	lvl_lbl.text = str(mini(Game.level, Game.max_level()))
	if Game.finished():
		prog_lbl.text = "Toate cele 30 de niveluri sunt gata"
		prog_cnt.text = ""
		prog_bar.value = 100
	else:
		var p := Game.level_progress()
		prog_lbl.text = "Nivelul %d · %s" % [Game.level, Game.globe_name(Game.level_globe())]
		prog_cnt.text = "%d/%d construcții" % [p.x, p.y]
		prog_bar.value = 100.0 * p.x / maxf(p.y, 1)
	for i in chest_btns.size():
		var b := chest_btns[i]
		if i < Game.chests.size():
			var c: Dictionary = Game.chests[i]
			var info := Game.chest_info(c.kind)
			b.modulate = Color(1, 1, 1, 1)
			if c.end <= 0.0:
				b.text = String(info.get("name", "")).replace("Cufăr ", "")
			elif c.end > Time.get_unix_time_from_system():
				b.text = Game.fmt_time(int(c.end - Time.get_unix_time_from_system())).replace(" s", "s")
			else:
				b.text = "Gata"
			b.add_theme_color_override("icon_normal_color", {"comun": Color("e0c080"), "rar": Color("8fc8ff"), "epic": Color("d8a0ff")}.get(c.kind, Color.WHITE))
		else:
			b.text = "liber"
			b.modulate = Color(1, 1, 1, 0.5)
	res_btn.text = Game.fmt(Game.reservoir_amount()) if Game.reservoir_amount() > 0 else ""
	streak_btn.modulate = Color(1.0, 0.9, 0.5) if Game.streak_available() else Color.WHITE
	if title:
		(title.get_node("Glob") as Label).text = Game.globe_name()
	_refresh_sheet()


func _process(_dt: float) -> void:
	if Engine.get_process_frames() % 30 == 0:
		_refresh()


func _chest_tap(i: int) -> void:
	if i >= Game.chests.size():
		open_modal("cufere")
		return
	var msg := Game.chest_action(i)
	if msg != "":
		Sfx.play("coin" if msg.begins_with("+") else "click")
		show_toast(msg)


# ---------------- mesaje și tranziții ----------------
func _toast() -> void:
	toast_panel = PanelContainer.new()
	K.place(toast_panel, true, 250, 0, 60, 60)
	toast_panel.add_theme_stylebox_override("panel", K.glass(24, 14, 0.92))
	toast_panel.modulate.a = 0.0
	toast_lbl = K.label("", 23, Color.WHITE, 800)
	toast_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_panel.add_child(toast_lbl)
	root.add_child(_ignore(toast_panel))
	toast_timer = Timer.new()
	toast_timer.one_shot = true
	toast_timer.timeout.connect(func(): create_tween().tween_property(toast_panel, "modulate:a", 0.0, 0.3))
	add_child(toast_timer)


func show_toast(msg: String, secs := 2.4) -> void:
	toast_lbl.text = msg
	create_tween().tween_property(toast_panel, "modulate:a", 1.0, 0.2)
	toast_timer.start(secs)


func _wipe_rect() -> void:
	wipe_rect = ColorRect.new()
	K.full_rect(wipe_rect)
	wipe_rect.color = Color("e8eeff")
	wipe_rect.modulate.a = 0.0
	wipe_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wipe_rect)


## Tranziție „prin nori": ecranul se albește, se schimbă ceva în lume, apoi revine.
func wipe(change: Callable) -> void:
	wipe_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(wipe_rect, "modulate:a", 1.0, 0.35)
	await tw.finished
	change.call()
	await get_tree().process_frame
	var back := create_tween()
	back.tween_property(wipe_rect, "modulate:a", 0.0, 0.45)
	await back.finished
	wipe_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _celebrate_level(l: int) -> void:
	Sfx.play("win")
	Sfx.buzz(60)
	show_toast("Nivelul %d" % l if l <= Game.max_level() else "Ai terminat toate nivelurile", 2.6)


func _on_globe_completed(g: int) -> void:
	await get_tree().create_timer(0.8).timeout
	open_modal("glob")
	modal_title.text = "%s – terminat" % Game.globe_name(g)


# ---------------- atac și raid ----------------
func _world() -> Node:
	return get_parent()


## Panou jos, peste glob, pentru alegeri în orașul țintei.
func _action(title_txt: String, label_txt: String) -> VBoxContainer:
	if action_panel:
		action_panel.queue_free()
	action_panel = PanelContainer.new()
	action_panel.add_theme_stylebox_override("panel", K.glass(30, 14, 0.94))
	K.place(action_panel, false, NAV_H + 18, 0, 14, 14)
	action_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(action_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	action_panel.add_child(vb)
	var t := K.label(title_txt, 26, Color.WHITE, 900)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(t)
	if label_txt != "":
		var tag := PanelContainer.new()
		tag.add_theme_stylebox_override("panel", K.box(Color("b8433f"), 12, Color.TRANSPARENT, 0, 0, 8))
		tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var tl := K.label(label_txt, 18, Color.WHITE, 800)
		tag.add_child(tl)
		vb.add_child(tag)
	slot.visible = false
	return vb


func _end_action() -> void:
	if action_panel:
		action_panel.queue_free()
		action_panel = null
	slot.visible = true


func _attack_flow(m: int) -> void:
	var w := _world()
	if not w.has_method("show_target"):
		return
	var tg: Dictionary = {}
	await wipe(func(): pass)
	tg = await w.show_target()
	var vb := _action("Atac: %s – atinge o clădire" % tg.get("name", "?"), tg.get("label", "") if tg.get("training", false) else "")
	if int(tg.get("shields", 0)) > 0:
		var sl := K.label("Ținta are %d %s" % [tg.shields, "scut" if tg.shields == 1 else "scuturi"], 20, Color("8fc8ff"), 800)
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(sl)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	vb.add_child(grid)
	var st := {"id": ""}
	var lv: Dictionary = tg.get("levels", {})
	for b in Game.BUILDINGS:
		var id: String = b.id
		var btn := K.button("%s  %d/5" % [b.n, int(lv.get(id, 0))], 18, K.glass(16, 6), Color.WHITE)
		btn.custom_minimum_size = Vector2(0, 54)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.disabled = int(lv.get(id, 0)) <= 0
		btn.pressed.connect(func(): st.id = id)
		grid.add_child(btn)
	var on_tap := func(what: String):
		if what.begins_with("b:") and int(lv.get(what.substr(2), 0)) > 0:
			st.id = what.substr(2)
	Game.target_tapped.connect(on_tap)
	while st.id == "":
		await get_tree().process_frame
	Game.target_tapped.disconnect(on_tap)
	_end_action()
	slot.visible = false
	var r: Dictionary = await w.attack_building(st.id)
	var c := Game.attack_reward(r.blocked, m)
	Game.add_coins(c)
	Analytics.log_event("attack", {"blocked": r.blocked, "coins": c, "training": tg.get("training", false)})
	show_toast(("Scutul a parat lovitura: +%s monede" if r.blocked else "Lovitură reușită: +%s monede") % Game.fmt(c))
	Sfx.play("coin")
	await get_tree().create_timer(1.2).timeout
	await wipe(func(): w.end_target())
	slot.visible = true
	Game.save_game()


func _raid_flow(m: int) -> void:
	var w := _world()
	if not w.has_method("show_target"):
		return
	await wipe(func(): pass)
	var tg: Dictionary = await w.show_target()
	w.make_raid_spots()
	var vals := Game.start_raid(m)
	var picks := Game.raid_picks()
	var vb := _action("Raid: %s – alege %d din %d locuri" % [tg.get("name", "?"), picks, vals.size()], tg.get("label", "") if tg.get("training", false) else "")
	var info := K.label("Găsit: 0", 22, K.GOLD, 800)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(info)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	vb.add_child(row)
	var st := {"n": 0, "total": 0, "busy": false, "dug": {}}
	var btns := []
	var dig := func(i: int):
		if st.busy or st.n >= picks or st.dug.has(i):
			return
		st.busy = true
		st.dug[i] = true
		btns[i].disabled = true
		var v := Game.raid_value(i)
		Game.add_coins(v)
		st.n += 1
		st.total += v
		Sfx.play("coin" if v > 0 else "click")
		await w.dig(i, v)
		info.text = "Găsit: %s  (%d/%d)" % [Game.fmt(st.total), st.n, picks]
		st.busy = false
	for i in vals.size():
		var b := K.button("Locul %d" % (i + 1), 20, K.glass(16, 6), Color.WHITE)
		b.custom_minimum_size = Vector2(0, 58)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func(): dig.call(i))
		row.add_child(b)
		btns.append(b)
	var on_tap := func(what: String):
		if what.begins_with("s:"):
			dig.call(int(what.substr(2)))
	Game.target_tapped.connect(on_tap)
	while st.n < picks or st.busy:
		await get_tree().process_frame
	Game.target_tapped.disconnect(on_tap)
	Analytics.log_event("raid", {"coins": st.total, "training": tg.get("training", false)})
	show_toast("Raid: +%s monede" % Game.fmt(st.total))
	await get_tree().create_timer(1.3).timeout
	_end_action()
	await wipe(func(): w.end_target())
	Game.save_game()


# ---------------- ferestre ----------------
func _modal() -> void:
	modal = K.full_rect(Control.new())
	modal.visible = false
	root.add_child(modal)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.08, 0.65)
	K.full_rect(dim)
	dim.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			_nav_to("acasa"))
	modal.add_child(dim)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", K.glass(36, 24, 0.96))
	card.anchor_left = 0.5
	card.anchor_right = 0.5
	card.anchor_top = 0.5
	card.anchor_bottom = 0.5
	card.offset_left = -330
	card.offset_right = 330
	card.offset_top = -470
	card.offset_bottom = 450
	modal.add_child(card)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	card.add_child(outer)
	var head := HBoxContainer.new()
	modal_title = K.label("", 34, Color.WHITE, 900)
	modal_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(modal_title)
	var x := K.icon_button("x", "", 14, StyleBoxEmpty.new(), Color.WHITE, 34)
	x.pressed.connect(func(): _nav_to("acasa"))
	head.add_child(x)
	outer.add_child(head)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	modal_box = VBoxContainer.new()
	modal_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal_box.add_theme_constant_override("separation", 10)
	scroll.add_child(modal_box)


func close_modal() -> void:
	modal.visible = false


func open_modal(kind: String) -> void:
	for c in modal_box.get_children():
		c.queue_free()
	var titles := {"album": "Album", "evenimente": "Evenimente", "magazin": "Magazin", "setari": "Setări", "sanse": "Șanse",
		"energie": "Fără energie", "serie": "Serie zilnică", "cufere": "Cufere", "glob": "Glob terminat", "prieteni": "Prieteni"}
	modal_title.text = titles.get(kind, "")
	call("_m_" + kind)
	modal.visible = true


func _p(t: String, size := 22, col := Color(1, 1, 1, 0.9)) -> Label:
	var l := K.label(t, size, col, 700)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(580, 0)
	modal_box.add_child(l)
	return l


func _h(t: String) -> void:
	modal_box.add_child(K.label(t, 26, K.GOLD, 900))


func _row(a: String, b: String, icon := "", action := Callable(), action_txt := "") -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", K.box(Color(1, 1, 1, 0.07), 18, Color(1, 1, 1, 0.12), 1, 0, 14))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	if icon != "":
		hb.add_child(K.icon_rect(icon, 30, K.GOLD))
	var la := K.label(a, 21, Color.WHITE, 700)
	la.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	la.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hb.add_child(la)
	if action.is_valid():
		var btn := K.gold_button(action_txt, 20)
		btn.custom_minimum_size = Vector2(160, 54)
		btn.pressed.connect(action)
		hb.add_child(btn)
	else:
		hb.add_child(K.label(b, 20, Color(1, 1, 1, 0.75), 800))
	p.add_child(hb)
	modal_box.add_child(p)


func _demo(t: String) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", K.box(Color("b8433f"), 12, Color.TRANSPARENT, 0, 0, 8))
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	p.add_child(K.label(t, 17, Color.WHITE, 900))
	modal_box.add_child(p)


func _m_album() -> void:
	var r: Dictionary = Game.cfg("card_set_reward", {})
	_p("Cărțile vin din mașina de bule, din cufere și din premii. Un set complet dă +%d energie și +%d perle." % [int(r.get("energy", 0)), int(r.get("perle", 0))])
	_demo("Schimburile de duplicate: DEMO – fără server")
	var sets: Array = Game.D.cards.sets
	for si in sets.size():
		var have := 0
		for ci in (sets[si].cards as Array).size():
			if int(Game.cards.get(Game.card_key(si, ci), 0)) > 0:
				have += 1
		_h("%s  %d/%d" % [sets[si].name, have, sets[si].cards.size()])
		var g := GridContainer.new()
		g.columns = 3
		g.add_theme_constant_override("h_separation", 8)
		g.add_theme_constant_override("v_separation", 8)
		for ci in (sets[si].cards as Array).size():
			var n := int(Game.cards.get(Game.card_key(si, ci), 0))
			var pc := PanelContainer.new()
			pc.custom_minimum_size = Vector2(186, 96)
			pc.add_theme_stylebox_override("panel", K.box(Color("2d2380") if n > 0 else Color(1, 1, 1, 0.05), 14, K.GOLD if n > 0 else Color(1, 1, 1, 0.18), 2, 0, 8))
			var vb := VBoxContainer.new()
			vb.alignment = BoxContainer.ALIGNMENT_CENTER
			var nm := K.label(sets[si].cards[ci] if n > 0 else "Necunoscută", 18, Color.WHITE if n > 0 else Color(1, 1, 1, 0.45), 800)
			nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			vb.add_child(nm)
			var rar := K.label("%s%s" % ["◆".repeat(1 + ci * 4 / sets[si].cards.size()), ("  ×%d" % n) if n > 1 else ""], 16, K.GOLD, 800)
			rar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			vb.add_child(rar)
			pc.add_child(vb)
			g.add_child(pc)
		modal_box.add_child(g)


func _m_evenimente() -> void:
	var name_ev: String = Game.cfg("event.name", "Eveniment")
	_h(name_ev)
	if Game.event_active():
		_p("Se termină în %s. Punctele vin din rotiri (atac, raid, cufere, câștiguri mari valorează mai mult)." % Game.fmt_time(int(Game.event_end() - Time.get_unix_time_from_system())))
	else:
		_p("Evenimentul s-a încheiat.")
	_p("Puncte: %d" % int(Game.event.points), 24, K.GOLD)
	var stages: Array = Game.cfg("event.stages", [])
	for i in stages.size():
		var s: Dictionary = stages[i]
		_row("Etapa %d · %d puncte" % [i + 1, int(s.points)], ("Primit" if i < int(Game.event.stage) else _reward_text(s)), "check" if i < int(Game.event.stage) else "star")
	_h("Serie zilnică")
	_p("Ziua %d din 7. Dacă lipsești o zi, seria se oprește, dar nu se pierde." % int(Game.streak.day))


func _reward_text(r: Dictionary) -> String:
	var p := []
	if r.has("energy"):
		p.append("%d energie" % int(r.energy))
	if r.has("units"):
		p.append("%s monede" % Game.fmt(int(float(r.units) * Game.bet_unit())))
	if r.has("cards"):
		p.append("%d cărți" % int(r.cards))
	if r.has("perle"):
		p.append("%d perle" % int(r.perle))
	if r.has("chest"):
		p.append(Game.chest_info(r.chest).get("name", "cufăr"))
	if r.has("cosmetic"):
		p.append("piesă de garderobă")
	return ", ".join(p)


func _m_serie() -> void:
	var days: Array = Game.cfg("streak", [])
	_p("Revino zilnic pentru recompense. Seria nu se resetează dacă lipsești: continuă de unde ai rămas.")
	for i in days.size():
		var got := i < int(Game.streak.day) and not (Game.streak_available() and i >= int(Game.streak.day))
		_row("Ziua %d" % (i + 1), _reward_text(days[i]), "check" if i < int(Game.streak.day) else "calendar")
	if Game.streak_available():
		var b := K.gold_button("Ia recompensa de azi", 26)
		b.custom_minimum_size = Vector2(0, 76)
		b.pressed.connect(func():
			var m := Game.claim_streak()
			Sfx.play("coin")
			show_toast(m, 3.0)
			_nav_to("acasa"))
		modal_box.add_child(b)
	else:
		_p("Ai luat recompensa de azi. Revino mâine.", 22, K.GOLD)


func _m_magazin() -> void:
	var shop: Dictionary = Monetization.shop()
	_demo("Plăți reale dezactivate în versiunea de test")
	_p("O singură monedă premium: %s. Ai %d perle (le câștigi la niveluri, din cufere epice, serie și evenimente)." % [shop.get("premium_name", "Perle"), Game.perle])
	_h("Cu perle")
	for it in shop.get("items", []):
		var iid: String = it.id
		_row("%s" % it.name, "", "gem", func():
			var m := Monetization.buy_with_perle(iid)
			show_toast(m)
			open_modal("magazin"), "%d perle" % int(it.perle))
	_h("Pachete de perle (preț întreg, fără bonusuri ascunse)")
	for pk in shop.get("perle_packs", []):
		var pid: String = pk.id
		_row("%d perle" % int(pk.perle), "", "gem", func(): Monetization.purchase(pid), pk.price)
	_p(shop.get("note", ""), 18, Color(1, 1, 1, 0.7))
	var odds := K.button("Vezi șansele", 22, K.glass(20, 10), Color.WHITE)
	odds.pressed.connect(func(): open_modal("sanse"))
	modal_box.add_child(odds)


func _m_sanse() -> void:
	_p("Rezultatul fiecărei rotiri se alege din acest tabel (data/spin_table.json). Rolele doar îl afișează.")
	for o in Game.spin_odds():
		_row(o.name, "%.1f%%" % (o.p * 100.0))
	_h("Cufere")
	var kinds: Dictionary = Game.cfg("chests.kinds", {})
	var tot := 0
	for k in kinds:
		tot += int(kinds[k].weight)
	for k in kinds:
		var c: Dictionary = kinds[k]
		_row("%s: %s monede, %d cărți%s%s · se deschide în %s" % [c.name, Game.fmt(int(float(c.units) * Game.bet_unit())), int(c.cards), (", %d energie" % int(c.energy)) if int(c.energy) > 0 else "", (", %d perle" % int(c.perle)) if int(c.perle) > 0 else "", Game.fmt_time(Game.chest_open_time(k))], "%.0f%%" % (100.0 * int(c.weight) / tot))


func _m_energie() -> void:
	_p("Energia se reface singură: 1 la %d minute, până la %d. Peste plafon nu se mai adună." % [int(Game.regen_s() / 60), Game.energy_cap()])
	_p("Următoarea în %s, plină în %s." % [Game.fmt_time(Game.energy_next_in()), Game.fmt_time(Game.energy_full_in())], 24, K.GOLD)
	_row("50 de energie", "", "zap", func():
		show_toast(Monetization.buy_with_perle("energie_50"))
		open_modal("energie"), "20 perle")


func _m_cufere() -> void:
	_p("Cuferele câștigate stau în 3 sloturi. Atinge un cufăr ca să pornești deschiderea (unul o dată), apoi atinge-l din nou când e gata. Dacă sloturile sunt pline, primești monedele pe loc.")
	_m_sanse()


func _m_glob() -> void:
	_p("Felicitări! Ai terminat globul. Ai primit un cufăr mare.")
	_p("Ca să călătorești spre globul următor, îmbunătățește dirijabilul în Atelier.", 24, K.GOLD)
	var b := K.gold_button("Spre dirijabil", 28)
	b.custom_minimum_size = Vector2(0, 80)
	b.pressed.connect(func(): _nav_to("dirijabil"))
	modal_box.add_child(b)


func _m_prieteni() -> void:
	_demo("DEMO – fără server")
	_p("Bulele din jurul globului sunt locuri pentru prieteni. În această versiune de test nu există alți jucători și nu se simulează nimeni. Invitațiile vor funcționa odată cu serverul.")


func _m_setari() -> void:
	_h("Calitate grafică")
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	for q in [["mic", "Mic"], ["mediu", "Mediu"], ["mare", "Mare"]]:
		var on: bool = Game.quality == q[0]
		var b := K.button(q[1], 22, K.box(Color("5a3ec0") if on else Color(1, 1, 1, 0.08), 18, K.GOLD if on else Color(1, 1, 1, 0.2), 2, 0, 12))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var key: String = q[0]
		b.pressed.connect(func():
			Game.set_quality(key)
			open_modal("setari"))
		hb.add_child(b)
	modal_box.add_child(hb)
	_p("Mic: fără strălucire și umbre. Mediu (implicit): echilibrat. Mare: umbre fine, anti-aliasing.", 18, Color(1, 1, 1, 0.7))
	for opt in [["sound", "Sunet"], ["vibration", "Vibrație"], ["notif_enabled", "Notificări (energie plină, cufăr gata; max. 2 pe zi)"]]:
		var key: String = opt[0]
		var val: bool = Game.get(key)
		_row(opt[1], "", "", func():
			Game.set(key, not Game.get(key))
			Game.save_game()
			open_modal("setari"), "Pornit" if val else "Oprit")
	_h("Despre")
	_p("Versiune de test pentru adulți. Fără plăți reale. Rezultatele mașinii de bule sunt aleatorii, cu șansele afișate în ecranul Șanse. Jocul simulează un mecanism de noroc fără bani reali.", 18, Color(1, 1, 1, 0.7))
