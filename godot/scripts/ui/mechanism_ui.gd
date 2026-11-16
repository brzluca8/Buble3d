extends "res://scripts/ui/hud_v2.gd"
## Interfața paginii Mecanismului (rotirile): înapoi în oraș, titlu, Șanse, resurse,
## banderola cu rezultatul, licitația săptămânii, pariul, butonul Rotește și rotirile automate.
## Ferestrele (Șanse, Energie, Magazin...) sunt cele din hud_v2.gd.

var world: Node
var energy_lbl: Label
var energy_sub: Label
var sub_title: Label
var banner: PanelContainer
var banner_name: Label
var banner_msg: Label
var ev_name: Label
var ev_info: Label
var ev_bar: ProgressBar
var mult_btn: Button
var spin_btn: Button
var spin_cost: Label
var auto_btn: Button
var auto_sub: Label


func _ready() -> void:
	world = get_parent()
	root = K.full_rect(Control.new())
	root.theme = K.theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)
	_mec_top()
	_mec_resources()
	_mec_banner()
	_mec_event()
	_mec_controls()
	_toast()
	_modal()
	_wipe_rect()
	Game.changed.connect(_refresh)
	Game.toast.connect(show_toast)
	_refresh()
	wipe_rect.modulate.a = 1.0
	create_tween().tween_property(wipe_rect, "modulate:a", 0.0, 0.4)


func _mec_top() -> void:
	var back := K.icon_button("arrow-left", "", 14, K.glass(36, 4, 0.8), Color.WHITE, 34)
	back.position = Vector2(16, 14)
	back.custom_minimum_size = Vector2(76, 76)
	back.tooltip_text = "Înapoi în oraș"
	back.pressed.connect(go_home)
	root.add_child(back)
	var odds := K.icon_button("circle-help", "", 14, K.glass(36, 4, 0.8), Color.WHITE, 34)
	odds.anchor_left = 1
	odds.anchor_right = 1
	odds.offset_left = -92
	odds.offset_right = -16
	odds.offset_top = 14
	odds.offset_bottom = 90
	odds.tooltip_text = "Șanse"
	odds.pressed.connect(func():
		Sfx.play("click")
		open_modal("sanse"))
	root.add_child(odds)
	for it in [[54.0, "Oraș", 0.0], [-54.0, "Șanse", 1.0]]:
		var l := K.label(it[1], 15, Color(1, 1, 1, 0.75), 700)
		l.anchor_left = it[2]
		l.anchor_right = it[2]
		l.offset_left = it[0] - 50
		l.offset_right = it[0] + 50
		l.offset_top = 92
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		root.add_child(l)
	var vb := VBoxContainer.new()
	K.place(vb, true, 16, 80, 110, 110)
	vb.add_theme_constant_override("separation", -2)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := K.label("Mecanismul", 44, K.GOLD, 900, 6, Color(0, 0, 0, 0.6))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	sub_title = K.label("", 17, Color(1, 1, 1, 0.75), 700)
	sub_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sub_title)
	root.add_child(vb)


func _mec_resources() -> void:
	var hb := HBoxContainer.new()
	K.place(hb, true, 122, 56, 16, 16)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 10)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hb)
	coins_lbl = _chip(hb, "coins", K.COIN)
	perle_lbl = _chip(hb, "gem", Color("9fd8c8"))
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", K.glass(26, 8, 0.75))
	var eh := HBoxContainer.new()
	eh.add_theme_constant_override("separation", 6)
	eh.add_child(K.icon_rect("zap", 28, Color("8fb8e8")))
	var ev := VBoxContainer.new()
	ev.add_theme_constant_override("separation", -6)
	energy_lbl = K.label("", 24, Color.WHITE, 800)
	energy_sub = K.label("", 12, Color(1, 1, 1, 0.65), 700)
	ev.add_child(energy_lbl)
	ev.add_child(energy_sub)
	eh.add_child(ev)
	p.add_child(eh)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			open_modal("energie"))
	hb.add_child(p)
	# perlele deschid magazinul
	var pp := perle_lbl.get_parent().get_parent() as Control
	pp.mouse_filter = Control.MOUSE_FILTER_STOP
	pp.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			open_modal("magazin"))


func _mec_banner() -> void:
	banner = PanelContainer.new()
	var bs := K.box(Color(0.04, 0.05, 0.08, 0.9), 26, K.GOLD, 2, 12, 12)
	banner.add_theme_stylebox_override("panel", bs)
	K.place(banner, true, 196, 0, 110, 110)
	banner.modulate.a = 0.0
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	banner_name = K.label("", 16, K.GOLD, 800)
	banner_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_msg = K.label("", 34, Color.WHITE, 900)
	banner_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(banner_name)
	vb.add_child(banner_msg)
	banner.add_child(vb)
	root.add_child(banner)


func _mec_event() -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", K.glass(22, 10, 0.82))
	K.place(p, false, 196, 64, 20, 20)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			open_modal("evenimente"))
	root.add_child(p)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(hb)
	hb.add_child(K.icon_rect("gavel", 30, K.GOLD))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", -2)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ev_name = K.label("", 17, Color.WHITE, 800)
	ev_name.clip_text = true
	ev_info = K.label("", 13, Color(1, 1, 1, 0.65), 700)
	vb.add_child(ev_name)
	vb.add_child(ev_info)
	hb.add_child(vb)
	ev_bar = ProgressBar.new()
	ev_bar.show_percentage = false
	ev_bar.custom_minimum_size = Vector2(190, 10)
	ev_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ev_bar.add_theme_stylebox_override("background", K.box(Color(1, 1, 1, 0.12), 4))
	ev_bar.add_theme_stylebox_override("fill", K.box(K.GOLD, 4))
	ev_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(ev_bar)


func _mec_controls() -> void:
	var hb := HBoxContainer.new()
	K.place(hb, false, 54, 128, 20, 20)
	hb.add_theme_constant_override("separation", 12)
	root.add_child(hb)
	mult_btn = _side_btn("×1", "pariu", Color("1c0f38"))
	mult_btn.pressed.connect(func():
		Sfx.play("click")
		Game.cycle_mult()
		if Game.multipliers().size() == 1:
			show_toast("Pariul se deblochează la nivelul %d" % int(Game.cfg("multiplier_unlock_level", 5))))
	hb.add_child(mult_btn)
	spin_btn = K.gold_button("", 30)
	spin_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sv := VBoxContainer.new()
	K.full_rect(sv)
	sv.alignment = BoxContainer.ALIGNMENT_CENTER
	sv.add_theme_constant_override("separation", -4)
	sv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sl := K.label("Rotește", 46, Color.WHITE, 900)
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	spin_cost = K.label("", 17, Color(1, 1, 1, 0.8), 800)
	spin_cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sv.add_child(sl)
	sv.add_child(spin_cost)
	spin_btn.add_child(sv)
	spin_btn.pressed.connect(func():
		auto = false
		do_spin())
	hb.add_child(spin_btn)
	auto_btn = _side_btn("Auto", "oprit", Color("0a2228"))
	auto_sub = auto_btn.get_child(0).get_child(1) as Label
	auto_btn.pressed.connect(func():
		Sfx.play("click")
		auto = not auto
		_refresh()
		if auto:
			do_spin())
	hb.add_child(auto_btn)
	var hint := K.label("Rezultate aleatorii · șansele complete în „Șanse” · fără bani reali", 13, Color(1, 1, 1, 0.5), 600)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	K.place(hint, false, 14, 30, 10, 10)
	root.add_child(hint)


var auto := false


func _side_btn(big: String, small: String, col: Color) -> Button:
	var b := K.button("", 20, K.box(col, 26, K.GOLD, 2, 8, 6), Color.WHITE)
	b.custom_minimum_size = Vector2(118, 0)
	var vb := VBoxContainer.new()
	K.full_rect(vb)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", -2)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l1 := K.label(big, 34, Color.WHITE, 900)
	l1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var l2 := K.label(small, 15, Color(1, 1, 1, 0.7), 700)
	l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(l1)
	vb.add_child(l2)
	b.add_child(vb)
	return b


# ---------------- rotirea ----------------
func do_spin() -> void:
	if world.busy:
		return
	var res: Dictionary = await world.spin()
	if res.is_empty():
		auto = false
		_refresh()
		Sfx.play("click")
		open_modal("energie")
		return
	_show_result(res)
	if res.type in ["attack", "raid"]:
		auto = false
		Game.pending_action = {"type": res.type, "mult": int(res.mult), "from": "mecanism"}
		Game.save_game()
		await get_tree().create_timer(1.1).timeout
		await wipe(func(): pass)
		get_tree().change_scene_to_file("res://scenes/globe.tscn")
		return
	if auto:
		await get_tree().create_timer(1.6 if res.big else 0.7).timeout
		if auto and is_inside_tree():
			do_spin()


func _show_result(res: Dictionary) -> void:
	var name_txt: String = res.get("name", "")
	if int(res.mult) > 1:
		name_txt += "  ·  ×%d" % int(res.mult)
	banner_name.text = name_txt.to_upper()
	match res.type:
		"attack":
			banner_msg.text = "Sabotaj – alege o clădire a țintei"
		"raid":
			banner_msg.text = "Spargere – alege 3 seifuri"
		_:
			banner_msg.text = res.msg
	var bs := banner.get_theme_stylebox("panel") as StyleBoxFlat
	bs.border_color = K.GOLD if res.big or res.coins > 0 else Color(1, 1, 1, 0.3)
	banner.pivot_offset = banner.size / 2
	banner.scale = Vector2(0.92, 0.92)
	var tw := create_tween()
	tw.tween_property(banner, "modulate:a", 1.0, 0.15)
	tw.parallel().tween_property(banner, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func go_home() -> void:
	Sfx.play("click")
	auto = false
	Game.save_game()
	await wipe(func(): pass)
	get_tree().change_scene_to_file("res://scenes/globe.tscn")


# ---------------- actualizare ----------------
func _refresh() -> void:
	coins_lbl.text = Game.fmt(int(Game.coins))
	perle_lbl.text = str(Game.perle)
	energy_lbl.text = "%d / %d" % [Game.energy, Game.energy_cap()]
	energy_sub.text = ("+1 în " + Game.fmt_time(Game.energy_next_in())) if Game.energy < Game.energy_cap() else "plin"
	sub_title.text = "%s · nivelul %d" % [Game.globe_name(), mini(Game.level, Game.max_level())]
	(mult_btn.get_child(0).get_child(0) as Label).text = "×%d" % Game.mult
	mult_btn.modulate = Color.WHITE if Game.multipliers().size() > 1 else Color(1, 1, 1, 0.45)
	spin_cost.text = "%d energie" % Game.mult
	spin_btn.modulate = Color.WHITE if Game.energy >= Game.mult else Color(0.6, 0.6, 0.62)
	auto_sub.text = "pornit" if auto else "oprit"
	auto_btn.modulate = Color(1.25, 1.15, 0.9) if auto else Color.WHITE
	ev_name.text = Game.cfg("event.name", "Licitația")
	var stages: Array = Game.cfg("event.stages", [])
	var st := int(Game.event.stage)
	if Game.event_active() and st < stages.size():
		var prev := 0 if st == 0 else int(stages[st - 1].points)
		var nxt := int(stages[st].points)
		ev_bar.value = 100.0 * (int(Game.event.points) - prev) / maxf(nxt - prev, 1)
		ev_info.text = "lotul %d din %d · încă %s" % [st + 1, stages.size(), Game.fmt_time(int(Game.event_end() - Time.get_unix_time_from_system()))]
	else:
		ev_bar.value = 100
		ev_info.text = "încheiată" if not Game.event_active() else "toate loturile câștigate"
