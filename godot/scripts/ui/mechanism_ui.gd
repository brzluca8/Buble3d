extends "res://scripts/ui/hud_v2.gd"
## Interfața paginii mașinii de bule (rotirile): înapoi în oraș, titlu, Șanse, resurse,
## banderola cu rezultatul, evenimentul, pariul, butonul Rotește și rotirile automate.
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
var fx: Control                                  # stratul efectelor de ecran (monede, texte, crăpături)
var shown_coins := -1.0                         # contorul afișat în timpul animațiilor (-1 = valoarea reală)
var _flying := 0


func _ready() -> void:
	world = get_parent()
	root = K.full_rect(Control.new())
	root.theme = K.theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)
	_vignette()
	_mec_top()
	_mec_resources()
	_mec_banner()
	_mec_event()
	_mec_controls()
	fx = K.full_rect(Control.new())
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fx)
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
	var t := K.label("Mașina de bule", 40, Color.WHITE, 900, 8, Color(0.08, 0.05, 0.3, 0.6))
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
	coins_lbl = _chip(hb, "coins", K.GOLD)
	perle_lbl = _chip(hb, "gem", Color("8ff4ec"))
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", K.glass(26, 8, 0.75))
	var eh := HBoxContainer.new()
	eh.add_theme_constant_override("separation", 6)
	eh.add_child(K.icon_rect("zap", 28, Color("7ff0a0")))
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
	var bs := K.box(Color(0.12, 0.08, 0.32, 0.92), 30, K.GOLD, 3, 12, 12)
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
	hb.add_child(K.icon_rect("sparkles", 30, K.GOLD))
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
	mult_btn = _side_btn("×1", "pariu", Color("6d3fc0"))
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
	var sl := K.label("Rotește", 46, K.INK, 900)
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	spin_cost = K.label("", 17, Color(K.INK, 0.75), 800)
	spin_cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sv.add_child(sl)
	sv.add_child(spin_cost)
	spin_btn.add_child(sv)
	spin_btn.pressed.connect(func():
		auto = false
		do_spin())
	hb.add_child(spin_btn)
	auto_btn = _side_btn("Auto", "oprit", Color("1f9e9c"))
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
	shown_coins = Game.coins            # contorul rămâne pe loc până zboară monedele
	var res: Dictionary = await world.spin()
	if res.is_empty():
		shown_coins = -1.0
		auto = false
		_refresh()
		Sfx.play("click")
		open_modal("energie")
		return
	_show_result(res)
	await world.present(res)
	if _flying == 0:
		shown_coins = -1.0
		_refresh()
	if res.type in ["attack", "raid"]:
		auto = false
		Game.pending_action = {"type": res.type, "mult": int(res.mult), "from": "mecanism"}
		Game.save_game()
		await get_tree().create_timer(0.15).timeout
		await wipe(func(): pass)
		get_tree().change_scene_to_file("res://scenes/globe.tscn")
		return
	if auto:
		await get_tree().create_timer(0.5).timeout
		if auto and is_inside_tree():
			do_spin()


func _show_result(res: Dictionary) -> void:
	var name_txt: String = res.get("name", "")
	if int(res.mult) > 1:
		name_txt += "  ·  ×%d" % int(res.mult)
	banner_name.text = name_txt.to_upper()
	match res.type:
		"attack":
			banner_msg.text = "Atac – atinge o clădire a țintei"
		"raid":
			banner_msg.text = "Raid – alege 3 locuri"
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
	coins_lbl.text = Game.fmt(int(shown_coins if shown_coins >= 0.0 else Game.coins))
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
	ev_name.text = Game.cfg("event.name", "Eveniment")
	var stages: Array = Game.cfg("event.stages", [])
	var st := int(Game.event.stage)
	if Game.event_active() and st < stages.size():
		var prev := 0 if st == 0 else int(stages[st - 1].points)
		var nxt := int(stages[st].points)
		ev_bar.value = 100.0 * (int(Game.event.points) - prev) / maxf(nxt - prev, 1)
		ev_info.text = "etapa %d din %d · încă %s" % [st + 1, stages.size(), Game.fmt_time(int(Game.event_end() - Time.get_unix_time_from_system()))]
	else:
		ev_bar.value = 100
		ev_info.text = "încheiat" if not Game.event_active() else "toate etapele câștigate"


# ---------------- efecte de ecran ----------------
## Vigneta irizată de la margini: senzația că ești în interiorul globului de sticlă.
func _vignette() -> void:
	var v := ColorRect.new()
	K.full_rect(v)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/screen_fx.gdshader")
	m.set_shader_parameter("mode", 0)
	v.material = m
	root.add_child(v)


func _chip_center(lbl: Label) -> Vector2:
	var chip := lbl.get_parent().get_parent() as Control
	return chip.get_global_rect().get_center()


func _pulse_chip(lbl: Label) -> void:
	var chip := lbl.get_parent().get_parent() as Control
	chip.pivot_offset = chip.size / 2
	var tw := create_tween()
	tw.tween_property(chip, "scale", Vector2.ONE * 1.12, 0.05)
	tw.tween_property(chip, "scale", Vector2.ONE, 0.12)


## Monede care zboară din `from` spre contorul de sus; contorul crește cu fiecare monedă.
func fly_coins(from: Vector2, n: int) -> void:
	if shown_coins < 0.0:
		shown_coins = Game.coins
	var start := shown_coins
	var target_val := float(Game.coins)
	var to := _chip_center(coins_lbl) - fx.get_global_rect().position
	from -= fx.get_global_rect().position
	_flying += n
	for i in n:
		var c := K.icon_rect("coins", 46, K.GOLD)
		c.size = Vector2(46, 46)
		c.pivot_offset = Vector2(23, 23)
		fx.add_child(c)
		var p0 := from + Vector2(randf_range(-60, 60), randf_range(-30, 30))
		var ctrl := Vector2(lerpf(p0.x, to.x, 0.3) + randf_range(-140, 140), minf(p0.y, to.y) - randf_range(60, 200))
		c.position = p0 - c.size / 2
		c.scale = Vector2.ZERO
		var k := i
		var tw := create_tween()
		tw.tween_interval(k * 0.045)
		tw.tween_property(c, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK)
		tw.tween_method(func(u: float):
			var a := p0.lerp(ctrl, u)
			var b := ctrl.lerp(to, u)
			c.position = a.lerp(b, u) - c.size / 2
			c.rotation = u * 6.0
			c.scale = Vector2.ONE * lerpf(1.0, 0.6, u), 0.0, 1.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.tween_callback(func():
			c.queue_free()
			_flying -= 1
			shown_coins = lerpf(start, target_val, float(k + 1) / n) if _flying > 0 else -1.0
			_refresh()
			_pulse_chip(coins_lbl)
			Sfx.play("tick", 1.0 + k * 0.04))


## Fulgere mici care zboară spre energie.
func fly_energy(from: Vector2, n: int) -> void:
	var to := _chip_center(energy_lbl) - fx.get_global_rect().position
	from -= fx.get_global_rect().position
	for i in n:
		var c := K.icon_rect("zap", 40, Color("7ff0a0"))
		c.size = Vector2(40, 40)
		fx.add_child(c)
		var p0 := from + Vector2(randf_range(-50, 50), randf_range(-20, 20))
		c.position = p0
		var tw := create_tween()
		tw.tween_interval(i * 0.06)
		tw.tween_property(c, "position", to - c.size / 2, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.tween_callback(func():
			c.queue_free()
			_pulse_chip(energy_lbl))


## Textul mare de câștig („CÂȘTIG MARE” / „SUPER CÂȘTIG”), care sare în ecran și apoi dispare.
func big_text(txt: String, huge: bool) -> void:
	var flash := ColorRect.new()
	K.full_rect(flash)
	flash.color = Color(1, 0.95, 0.8, 0.55 if huge else 0.3)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx.add_child(flash)
	create_tween().tween_property(flash, "color:a", 0.0, 0.4)
	get_tree().create_timer(0.5).timeout.connect(flash.queue_free)
	var l := K.label(txt, 84 if huge else 72, Color("ffd34a"), 900, 18, Color("3a1680"))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_constant_override("shadow_offset_y", 8)
	l.add_theme_color_override("font_shadow_color", Color(0.1, 0.02, 0.25, 0.6))
	fx.add_child(l)
	l.size = Vector2(fx.size.x, 120)
	l.position = Vector2(0, fx.size.y * 0.36)
	l.pivot_offset = l.size / 2
	l.scale = Vector2.ONE * 0.2
	l.rotation = -0.08
	var tw := create_tween()
	tw.tween_property(l, "scale", Vector2.ONE * 1.18, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "rotation", 0.03, 0.22)
	tw.tween_property(l, "scale", Vector2.ONE, 0.15)
	tw.parallel().tween_property(l, "rotation", 0.0, 0.15)
	if huge:
		for k in 6:
			tw.tween_property(l, "modulate", Color(1.3, 0.85, 1.2) if k % 2 == 0 else Color(1.2, 1.2, 0.9), 0.14)
	else:
		tw.tween_interval(0.9)
	tw.tween_property(l, "modulate:a", 0.0, 0.35)
	tw.parallel().tween_property(l, "scale", Vector2.ONE * 1.12, 0.35)
	tw.tween_callback(l.queue_free)


## Contorul din banderolă numără animat până la suma câștigată.
func count_banner(coins: int, dur: float) -> void:
	var tw := create_tween()
	tw.tween_method(func(v: float): banner_msg.text = "+%s monede" % Game.fmt(int(v)), 0.0, float(coins), dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	banner.pivot_offset = banner.size / 2
	tw.tween_property(banner, "scale", Vector2.ONE * 1.08, 0.1)
	tw.tween_property(banner, "scale", Vector2.ONE, 0.15)


class Crack:
	extends Control
	var at := Vector2.ZERO
	var lines := []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		for k in 14:
			var a := k / 14.0 * TAU + randf_range(-0.15, 0.15)
			var pts := PackedVector2Array([at])
			var p := at
			var len := randf_range(180.0, 520.0)
			var segs := 6
			for s in segs:
				a += randf_range(-0.35, 0.35)
				p += Vector2(cos(a), sin(a)) * len / segs
				pts.append(p)
			lines.append(pts)

	func _draw() -> void:
		for pts in lines:
			draw_polyline(pts, Color(0.1, 0.05, 0.2, 0.55), 6.0, true)
			draw_polyline(pts, Color(1, 1, 1, 0.9), 2.5, true)
		for r in [40.0, 95.0, 160.0]:
			var ring := PackedVector2Array()
			for k in 25:
				var a := k / 24.0 * TAU
				ring.append(at + Vector2(cos(a), sin(a)) * r * randf_range(0.85, 1.15))
			draw_polyline(ring, Color(1, 1, 1, 0.55), 1.8, true)
		draw_circle(at, 22.0, Color(1, 1, 1, 0.8))


## Ecranul se crapă în punctul de impact (atac).
func crack(at: Vector2) -> void:
	var flash := ColorRect.new()
	K.full_rect(flash)
	flash.color = Color(1, 1, 1, 0.7)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx.add_child(flash)
	create_tween().tween_property(flash, "color:a", 0.0, 0.25)
	var c := Crack.new()
	c.at = at - fx.get_global_rect().position
	K.full_rect(c)
	fx.add_child(c)
	get_tree().create_timer(2.0).timeout.connect(func():
		if is_instance_valid(c):
			c.queue_free())


## Irisul se închide spre punctul dat (raid: „intrăm” în orașul țintei).
func iris(center: Vector2) -> void:
	var r := ColorRect.new()
	K.full_rect(r)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/screen_fx.gdshader")
	m.set_shader_parameter("mode", 1)
	var sz := fx.size
	m.set_shader_parameter("center", (center - fx.get_global_rect().position) / sz)
	m.set_shader_parameter("aspect", sz.x / maxf(sz.y, 1.0))
	m.set_shader_parameter("r", 1.6)
	r.material = m
	fx.add_child(r)
	var tw := create_tween()
	tw.tween_method(func(v: float): m.set_shader_parameter("r", v), 1.6, 0.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
