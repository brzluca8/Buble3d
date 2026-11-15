extends Control
## Interfața buclei principale: butonul ARUNCĂ (energie), multiplicatorul, zarurile,
## recompensele căsuțelor și ferestrele de atac / jaf / insulă completă / fără energie.

const K := preload("res://scripts/ui/ui_kit.gd")

var hud: Node                      # HUD-ul (pentru mesaje și Buble Blast)
var world: Node                    # scena 3D (main.gd): board + mascot
var roll_btn: Button
var roll_lbl: Label
var energy_lbl: Label
var timer_lbl: Label
var mult_btn: Button
var info_lbl: Label
var dice: Control
var dice_lbls: Array[Label] = []
var float_lbl: Label
var popup: Control
var wipe_rect: Control
var busy := false
var auto_roll := false


func _ready() -> void:
	K.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_roll_button()
	_info_bar()
	_dice()
	_float_label()
	popup = K.full_rect(Control.new())
	popup.visible = false
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE   # lasă atingerile să ajungă la lumea 3D
	add_child(popup)
	wipe_rect = K.full_rect(ColorRect.new())
	(wipe_rect as ColorRect).color = Color("eef3ff")
	wipe_rect.modulate.a = 0.0
	wipe_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wipe_rect)
	Game.changed.connect(_refresh)
	Game.island_completed.connect(_on_island_completed)
	_refresh()


# ---------------- construcție ----------------
func _roll_button() -> void:
	roll_btn = K.gold_button("", 40)
	roll_btn.anchor_left = 0.5
	roll_btn.anchor_right = 0.5
	roll_btn.anchor_top = 1
	roll_btn.anchor_bottom = 1
	roll_btn.offset_left = -170
	roll_btn.offset_right = 170
	roll_btn.offset_top = -244
	roll_btn.offset_bottom = -132
	var vb := VBoxContainer.new()
	K.full_rect(vb)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", -6)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	roll_lbl = K.label("ARUNCĂ 🎲", 42, K.INK, 900)
	roll_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	energy_lbl = K.label("", 20, Color(K.INK, 0.75), 800)
	energy_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(roll_lbl)
	vb.add_child(energy_lbl)
	roll_btn.add_child(vb)
	roll_btn.pressed.connect(roll)
	add_child(roll_btn)
	# ținere apăsată = aruncare automată
	roll_btn.button_down.connect(func():
		get_tree().create_timer(0.8).timeout.connect(func():
			if roll_btn.button_pressed:
				auto_roll = true
				Game.toast.emit("Aruncare automată – atinge din nou ca să oprești")))

	mult_btn = K.button("×1", 30, K.box(Color("7a5ad8"), 40, K.GOLD, 3, 6))
	mult_btn.anchor_left = 0.5
	mult_btn.anchor_right = 0.5
	mult_btn.anchor_top = 1
	mult_btn.anchor_bottom = 1
	mult_btn.offset_left = -300
	mult_btn.offset_right = -186
	mult_btn.offset_top = -226
	mult_btn.offset_bottom = -150
	mult_btn.pressed.connect(func():
		Sfx.play("click")
		Game.cycle_mult())
	add_child(mult_btn)

	timer_lbl = K.label("", 19, Color.WHITE, 800, 6, Color(0.1, 0.05, 0.3, 0.7))
	timer_lbl.anchor_left = 0.5
	timer_lbl.anchor_right = 0.5
	timer_lbl.anchor_top = 1
	timer_lbl.anchor_bottom = 1
	timer_lbl.offset_left = 180
	timer_lbl.offset_right = 340
	timer_lbl.offset_top = -214
	timer_lbl.offset_bottom = -160
	timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	timer_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	add_child(timer_lbl)


func _info_bar() -> void:
	var p := PanelContainer.new()
	K.place(p, true, 160, 46, 16, 100)
	p.add_theme_stylebox_override("panel", K.box(Color(0.125, 0.1, 0.37, 0.72), 22, Color(1, 1, 1, 0.25), 2, 0, 8))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_lbl = K.label("", 19, Color.WHITE, 800)
	info_lbl.clip_text = true
	p.add_child(info_lbl)
	add_child(p)


func _dice() -> void:
	dice = HBoxContainer.new()
	dice.anchor_left = 0.5
	dice.anchor_right = 0.5
	dice.anchor_top = 0.42
	dice.anchor_bottom = 0.42
	dice.offset_left = -130
	dice.offset_right = 130
	dice.offset_top = -60
	dice.offset_bottom = 60
	(dice as HBoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
	dice.add_theme_constant_override("separation", 24)
	dice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dice.modulate.a = 0.0
	for i in 2:
		var d := PanelContainer.new()
		d.custom_minimum_size = Vector2(110, 110)
		d.add_theme_stylebox_override("panel", K.box(Color("fffaf0"), 26, K.GOLD, 5, 12))
		var l := K.label("6", 64, K.INK, 900)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		d.add_child(l)
		dice.add_child(d)
		dice_lbls.append(l)
	add_child(dice)


func _float_label() -> void:
	float_lbl = K.label("", 40, Color("ffe08a"), 900, 12, Color(0.2, 0.08, 0.35, 0.9))
	float_lbl.anchor_left = 0
	float_lbl.anchor_right = 1
	float_lbl.anchor_top = 0.3
	float_lbl.anchor_bottom = 0.3
	float_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	float_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	float_lbl.modulate.a = 0.0
	add_child(float_lbl)


func _refresh() -> void:
	energy_lbl.text = "🫧 %d / %d" % [Game.energy, Game.ENERGY_MAX]
	mult_btn.text = "×%d" % Game.mult
	var nxt := Game.energy_next_in()
	timer_lbl.text = "" if nxt == 0 else "+1 🫧 în\n%d:%02d" % [nxt / 60, nxt % 60]
	info_lbl.text = "🛡️ %d/3   ⭐ %s %d/%d   🏝️ %s" % [Game.shields, Game.EVENT_NAME, Game.event_pts, Game.event_next_goal(), Game.island_name()]
	roll_btn.modulate = Color.WHITE if Game.energy >= Game.mult else Color(0.8, 0.78, 0.85)


func _process(_dt: float) -> void:
	# cronometrul energiei se actualizează în fiecare secundă
	if Engine.get_process_frames() % 30 == 0:
		_refresh()


# ---------------- aruncarea ----------------
func roll() -> void:
	if busy:
		auto_roll = false
		return
	if Game.energy < Game.mult:
		auto_roll = false
		if Game.energy > 0 and Game.mult > 1:
			Game.mult = 1
			Game.changed.emit()
			Game.toast.emit("Multiplicatorul a revenit la ×1")
			return
		_no_energy()
		return
	var res := Game.roll()
	if res.is_empty():
		return
	busy = true
	Game.select("")
	Sfx.play("shoot")
	await _animate_dice(res.d1, res.d2)
	if res.start_bonus > 0:
		_float("Ai trecut de Start! +%d 🪙" % res.start_bonus)
	var board: Board = world.board if world and "board" in world else null
	var mascot: Mascot = world.mascot if world and "mascot" in world else null
	if board and mascot:
		board.highlight(res.to)
		# funcțiile anonime copiază variabilele simple – folosim un dicționar (referință)
		var st := {"done": false}
		mascot.hop_path(board.path(res.from, res.to), func(): st.done = true)
		while not st.done:
			await get_tree().process_frame
	await land(res.kind, res.double)
	if board:
		board.highlight(-1)
	busy = false
	if auto_roll and popup.visible == false:
		await get_tree().create_timer(0.35).timeout
		if auto_roll:
			roll()


func _animate_dice(d1: int, d2: int) -> void:
	var tw := create_tween()
	tw.tween_property(dice, "modulate:a", 1.0, 0.12)
	for i in 8:
		dice_lbls[0].text = str(randi_range(1, 6))
		dice_lbls[1].text = str(randi_range(1, 6))
		dice.rotation = randf_range(-0.08, 0.08)
		await get_tree().create_timer(0.05).timeout
	dice.rotation = 0.0
	dice_lbls[0].text = str(d1)
	dice_lbls[1].text = str(d2)
	if d1 == d2:
		_float("Dublă! Aruncare gratuită 🎲")
	await get_tree().create_timer(0.35).timeout
	create_tween().tween_property(dice, "modulate:a", 0.0, 0.3).set_delay(0.6)


## Aplică efectul căsuței pe care a aterizat mascota.
func land(kind: String, _double := false) -> void:
	match kind:
		"attack":
			await _attack_popup()
		"raid":
			await _raid_popup()
		"blast":
			_float("Buble Blast! 🫧")
			await get_tree().create_timer(0.6).timeout
			if hud:
				hud._open_blast()
		_:
			var r := Game.resolve_tile(kind)
			_float(r.msg)
			Sfx.play("coin" if r.coins > 0 else "pop")
			await get_tree().create_timer(0.5).timeout


func _float(msg: String) -> void:
	float_lbl.text = msg
	float_lbl.position.y = 0
	var tw := create_tween()
	tw.tween_property(float_lbl, "modulate:a", 1.0, 0.15)
	tw.parallel().tween_property(float_lbl, "position:y", -40.0, 1.2)
	tw.tween_property(float_lbl, "modulate:a", 0.0, 0.5).set_delay(0.6)


# ---------------- ferestre ----------------
func _card(title: String, w := 620.0, h := 760.0) -> VBoxContainer:
	for c in popup.get_children():
		c.queue_free()
	var dim := K.full_rect(ColorRect.new())
	(dim as ColorRect).color = Color(0, 0, 0, 0.6)
	popup.add_child(dim)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", K.box(K.CARD, 44, K.GOLD, 4, 16, 30))
	card.anchor_left = 0.5
	card.anchor_right = 0.5
	card.anchor_top = 0.5
	card.anchor_bottom = 0.5
	card.offset_left = -w / 2
	card.offset_right = w / 2
	card.offset_top = -h / 2
	card.offset_bottom = h / 2
	popup.add_child(card)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 16)
	card.add_child(vb)
	var t := K.label(title, 40, Color.WHITE, 900)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(t)
	popup.visible = true
	return vb


func _text(vb: Control, s: String, size := 26, col := Color.WHITE) -> Label:
	var l := K.label(s, size, col, 700)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(l)
	return l


func _close_popup() -> void:
	popup.visible = false
	for c in popup.get_children():
		c.queue_free()


signal _popup_done


## Ascunde / arată comenzile principale (pe insula rivalului nu se aruncă zarurile).
func _controls(on: bool) -> void:
	for c in [roll_btn, mult_btn, timer_lbl]:
		c.visible = on


## Tranziție „prin nori": ecranul se albește, se schimbă lumea, apoi revine.
func _wipe(change: Callable) -> void:
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


## Panou jos, peste lumea 3D (fără întunecarea ecranului), pentru alegeri pe insula rivalului.
func _bottom_panel(title: String) -> VBoxContainer:
	for c in popup.get_children():
		c.queue_free()
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", K.box(Color(0.125, 0.1, 0.37, 0.9), 34, K.GOLD, 3, 10, 18))
	K.place(p, false, 136, 0, 16, 16)
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	popup.add_child(p)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	p.add_child(vb)
	_text(vb, title, 24)
	popup.visible = true
	return vb


func _attack_popup() -> void:
	if not (world and world.has_method("visit_rival")):
		await _attack_card()
		return
	# online: țintă reală (prieten sau jucător activ); offline: Contele Furtună
	var target := {}
	if Net.online:
		target = await Net.pick_target()
	var lv: Dictionary = target.get("levels", {}) if not target.is_empty() else Game.rival
	var foe: String = target.get("name", Game.RIVAL) if not target.is_empty() else Game.RIVAL
	await _wipe(func():
		_controls(false)
		world.visit_rival(true, lv))
	var vb := _bottom_panel("🔨 Atinge o clădire a lui %s ca s-o lovești" % foe)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	vb.add_child(grid)
	var st := {"id": ""}
	for b in Game.BUILDINGS:
		var id: String = b.id
		var lvl: int = int(lv.get(id, 1))
		var btn := K.button("%s %s" % [b.n.split(" ")[0], "●".repeat(lvl)], 19, K.box(Color(1, 1, 1, 0.12), 18, Color(1, 1, 1, 0.3), 2, 0, 8))
		btn.custom_minimum_size = Vector2(205, 56)
		btn.disabled = lvl <= 0
		btn.pressed.connect(func(): st.id = id)
		grid.add_child(btn)
	var on_tap := func(what: String):
		if what.begins_with("b:") and int(lv.get(what.substr(2), 0)) > 0:
			st.id = what.substr(2)
	Game.rival_tapped.connect(on_tap)
	while st.id == "":
		await get_tree().process_frame
	Game.rival_tapped.disconnect(on_tap)
	_close_popup()
	var before: int = int(lv.get(st.id, 1))
	var r := {}
	if not target.is_empty():
		var nr := await Net.attack(int(target.id), st.id, Game.mult)
		if nr._code == 200:
			r = {"blocked": nr.blocked, "coins": int(nr.coins)}
			Game.add_coins(r.coins)
			Game.save_game()
	if r.is_empty():
		r = Game.attack(st.id)
	var after := before if r.blocked else (maxi(1, before - 1) if not target.is_empty() else before - 1)
	await world.rival.hit(st.id, r.blocked, after, world.cam)
	_float(("Scutul Contelui a parat! +%d 🪙" if r.blocked else "Lovitură! +%d 🪙") % r.coins)
	Sfx.play("coin")
	await get_tree().create_timer(1.2).timeout
	await _wipe(func():
		world.visit_rival(false)
		_controls(true))


func _raid_popup() -> void:
	if not (world and world.has_method("visit_rival")):
		await _raid_card()
		return
	var target := {}
	if Net.online:
		target = await Net.pick_target()
		if not target.is_empty():
			var rs := await Net.raid_start(int(target.id), Game.mult)
			if rs._code != 200:
				target = {}
	var lv: Dictionary = target.get("levels", {}) if not target.is_empty() else {}
	await _wipe(func():
		_controls(false)
		world.visit_rival(true, lv))
	world.rival.make_mounds()
	if target.is_empty():
		Game.start_raid()
	var vb := _bottom_panel("🕳️ Jaf la %s – sapă în 3 movile!" % (target.get("name", Game.RIVAL) if not target.is_empty() else Game.RIVAL))
	var info := _text(vb, "Atinge o movilă (0/3)", 22, Color("ffe08a"))
	var grid := GridContainer.new()
	grid.columns = 9
	grid.add_theme_constant_override("h_separation", 6)
	vb.add_child(grid)
	var st := {"picks": 0, "total": 0, "busy": false, "dug": {}}
	var btns := []
	var dig := func(i: int):
		if st.busy or st.picks >= 3 or st.dug.has(i):
			return
		st.busy = true
		st.dug[i] = true
		btns[i].disabled = true
		var v := 0
		if not target.is_empty():
			var rp := await Net.raid_pick(i)
			v = int(rp.get("value", 0))
			Game.add_coins(v)
		else:
			v = Game.raid_pick(i)
		st.picks += 1
		st.total += v
		Sfx.play("coin" if v > 0 else "click")
		await world.rival.dig(i, v)
		info.text = "Ai găsit %d 🪙  (%d/3)" % [st.total, st.picks]
		st.busy = false
	for i in 9:
		var b := K.button(str(i + 1), 22, K.box(Color(1, 1, 1, 0.12), 14, Color(1, 1, 1, 0.3), 2))
		b.custom_minimum_size = Vector2(66, 56)
		b.pressed.connect(func(): dig.call(i))
		grid.add_child(b)
		btns.append(b)
	var on_tap := func(what: String):
		if what.begins_with("m:"):
			dig.call(int(what.substr(2)))
	Game.rival_tapped.connect(on_tap)
	while st.picks < 3 or st.busy:
		await get_tree().process_frame
	Game.rival_tapped.disconnect(on_tap)
	_close_popup()
	_float("Jaf reușit! +%d 🪙" % st.total)
	await get_tree().create_timer(1.3).timeout
	await _wipe(func():
		world.visit_rival(false)
		_controls(true))


func _attack_card() -> void:
	var vb := _card("🔨 Atac asupra %s" % Game.RIVAL_ISLAND)
	_text(vb, "Alege o clădire a lui %s:" % Game.RIVAL, 24, Color(1, 1, 1, 0.85))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	vb.add_child(grid)
	for b in Game.BUILDINGS:
		var id: String = b.id
		var lvl: int = Game.rival[id]
		var btn := K.button("%s\n%s" % [b.n.replace("Palatul Norilor", "Palatul"), "●".repeat(lvl) + "○".repeat(Game.MAX_LVL - lvl)], 22,
			K.box(Color(1, 1, 1, 0.12) if lvl > 0 else Color(0, 0, 0, 0.25), 22, Color(1, 1, 1, 0.3), 2, 0, 12))
		btn.custom_minimum_size = Vector2(270, 96)
		btn.disabled = lvl <= 0
		btn.pressed.connect(func():
			var r := Game.attack(id)
			Sfx.play("bomb")
			_close_popup()
			_float(("Scutul Contelui a parat! +%d 🪙" if r.blocked else "Lovitură! +%d 🪙") % r.coins)
			_popup_done.emit())
		grid.add_child(btn)
	await _popup_done


func _raid_card() -> void:
	var cells := Game.start_raid()
	var vb := _card("🕳️ Jaf la %s" % Game.RIVAL_ISLAND)
	var info := _text(vb, "Alege 3 nori – sub unii sunt comori!", 24, Color(1, 1, 1, 0.85))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	vb.add_child(grid)
	var picks := [0]
	var total := [0]
	for i in cells.size():
		var b := K.button("☁️", 54, K.box(Color(1, 1, 1, 0.14), 26, Color(1, 1, 1, 0.35), 2))
		b.custom_minimum_size = Vector2(170, 150)
		b.pressed.connect(func():
			if picks[0] >= 3 or b.disabled:
				return
			var v := Game.raid_pick(i)
			picks[0] += 1
			total[0] += v
			b.disabled = true
			b.text = ("💰\n%d" % v) if v > 0 else "💨"
			b.add_theme_font_size_override("font_size", 30)
			Sfx.play("coin" if v > 0 else "click")
			info.text = "Ai găsit %d 🪙  (%d/3)" % [total[0], picks[0]]
			if picks[0] >= 3:
				await get_tree().create_timer(1.0).timeout
				_close_popup()
				_float("Jaf reușit! +%d 🪙" % total[0])
				_popup_done.emit())
		grid.add_child(b)
	await _popup_done


func _no_energy() -> void:
	var vb := _card("Ai rămas fără bule 🫧", 600, 560)
	var nxt := Game.energy_next_in()
	_text(vb, "Următoarea bulă vine în %d:%02d. Bulele se refac singure (1 la 2 minute)." % [nxt / 60, nxt % 60], 24)
	var ad := K.gold_button("🎬 +10 bule (reclamă)", 28)
	ad.custom_minimum_size = Vector2(0, 84)
	ad.pressed.connect(func():
		_close_popup()
		Monetization.rewarded_done.connect(_on_energy_ad, CONNECT_ONE_SHOT)
		Monetization.show_rewarded("energy"))
	vb.add_child(ad)
	var shop := K.button("🏪 Magazin", 26, K.box(Color(1, 1, 1, 0.12), 40, Color(1, 1, 1, 0.3), 2, 0, 14))
	shop.pressed.connect(func():
		_close_popup()
		if hud:
			hud._nav_to("shop"))
	vb.add_child(shop)
	var later := K.button("Mai târziu", 24)
	later.pressed.connect(_close_popup)
	vb.add_child(later)


func _on_energy_ad(placement: String, ok: bool) -> void:
	if placement == "energy" and ok:
		Game.add_energy(10)
		Game.save_game()
		Sfx.play("coin")
		_float("+10 🫧")


func _on_island_completed(done: int) -> void:
	var vb := _card("🎉 Insulă completă!", 600, 560)
	_text(vb, "Ai construit tot pe %s." % Game.ISLAND_NAMES[(done - 1) % Game.ISLAND_NAMES.size()], 26)
	_text(vb, "Te așteaptă: %s 🏝️" % Game.island_name(), 30, Color("ffd86b"))
	var ok := K.gold_button("Mai departe!", 30)
	ok.custom_minimum_size = Vector2(0, 84)
	ok.pressed.connect(_close_popup)
	vb.add_child(ok)
	Sfx.play("win")
