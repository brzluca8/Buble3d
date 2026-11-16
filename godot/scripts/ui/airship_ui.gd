extends CanvasLayer
## Interfața dirijabilului: Observator (arbore de abilități ca hartă de constelații), Garderobă,
## Atelier (îmbunătățiri care deschid globurile), Seră (însoțitorul), Salon (trofee, statistici, album).

const K := preload("res://scripts/ui/ui_kit.gd")

var root: Control
var panel: PanelContainer
var box: VBoxContainer
var title_lbl: Label
var points_lbl: Label
var coins_lbl: Label
var current := ""
var _sel_skill := ""


func _ready() -> void:
	root = K.full_rect(Control.new())
	root.theme = K.theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_top()
	_rooms_bar()
	_panel()
	Game.changed.connect(_refresh)
	Game.target_tapped.connect(_on_tap)
	Game.toast.connect(func(m): _toast(m))
	_refresh()


func _top() -> void:
	var hb := HBoxContainer.new()
	K.place(hb, true, 14, 70, 16, 16)
	hb.add_theme_constant_override("separation", 10)
	root.add_child(hb)
	var back := K.icon_button("house", "Glob", 22, K.glass(30, 10), Color.WHITE, 30)
	back.custom_minimum_size = Vector2(150, 64)
	back.pressed.connect(func():
		Sfx.play("click")
		get_tree().change_scene_to_file("res://scenes/globe.tscn"))
	hb.add_child(back)
	var t := K.label("Dirijabilul", 36, Color.WHITE, 900, 8, Color(0.08, 0.05, 0.3, 0.6))
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hb.add_child(t)
	var c := PanelContainer.new()
	c.add_theme_stylebox_override("panel", K.glass(26, 8, 0.8))
	var ch := HBoxContainer.new()
	ch.add_child(K.icon_rect("coins", 26, K.GOLD))
	coins_lbl = K.label("0", 22, Color.WHITE, 800)
	ch.add_child(coins_lbl)
	c.add_child(ch)
	hb.add_child(c)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", K.glass(26, 8, 0.8))
	var ph := HBoxContainer.new()
	ph.add_child(K.icon_rect("sparkles", 26, Color("b8a0ff")))
	points_lbl = K.label("0", 22, Color.WHITE, 800)
	ph.add_child(points_lbl)
	p.add_child(ph)
	hb.add_child(p)


func _rooms_bar() -> void:
	var p := PanelContainer.new()
	K.place(p, false, 8, 112, 12, 12)
	p.add_theme_stylebox_override("panel", K.glass(40, 6, 0.9))
	root.add_child(p)
	var hb := HBoxContainer.new()
	p.add_child(hb)
	for it in [["observator", "telescope", "Observator"], ["garderoba", "shirt", "Garderobă"], ["atelier", "wrench", "Atelier"], ["sera", "sprout", "Seră"], ["salon", "armchair", "Salon"]]:
		var b := K.button(it[2], 16, StyleBoxEmpty.new(), Color.WHITE)
		b.icon = K.icon(it[1])
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 34)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var key: String = it[0]
		b.pressed.connect(func(): open(key))
		hb.add_child(b)


func _panel() -> void:
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", K.glass(34, 20, 0.95))
	panel.anchor_left = 0
	panel.anchor_right = 1
	panel.anchor_top = 1
	panel.anchor_bottom = 1
	panel.offset_left = 14
	panel.offset_right = -14
	panel.offset_top = -760
	panel.offset_bottom = -132
	panel.visible = false
	root.add_child(panel)
	var outer := VBoxContainer.new()
	panel.add_child(outer)
	var head := HBoxContainer.new()
	title_lbl = K.label("", 32, Color.WHITE, 900)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title_lbl)
	var x := K.icon_button("x", "", 14, StyleBoxEmpty.new(), Color.WHITE, 32)
	x.pressed.connect(close)
	head.add_child(x)
	outer.add_child(head)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(sc)
	box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	sc.add_child(box)


func _on_tap(what: String) -> void:
	if what.begins_with("r:"):
		open(what.substr(2))


func close() -> void:
	panel.visible = false
	current = ""
	var w := get_parent()
	w.cam.reset_view()


func open(kind: String) -> void:
	Sfx.play("click")
	current = kind
	for c in box.get_children():
		c.queue_free()
	title_lbl.text = {"observator": "Observator · abilități", "garderoba": "Garderobă", "atelier": "Atelier", "sera": "Seră · însoțitor", "salon": "Salon"}[kind]
	call("_" + kind)
	panel.visible = true
	var w := get_parent()
	if kind == "garderoba":
		w.cam.focus(w.mascot.global_position + Vector3(0, -2.2, 0), 1.6)
	else:
		w.cam._t_target = Vector3(0, 0.4, 0)
		w.cam._t_dist = 36.0


func _refresh() -> void:
	coins_lbl.text = Game.fmt(int(Game.coins))
	points_lbl.text = "%d puncte" % Game.skill_points
	if panel.visible and current != "":
		open(current)


func _p(t: String, size := 21, col := Color(1, 1, 1, 0.9)) -> Label:
	var l := K.label(t, size, col, 700)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(600, 0)
	box.add_child(l)
	return l


func _row(text: String, right: String, action := Callable(), action_txt := "", enabled := true) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", K.box(Color(1, 1, 1, 0.07), 18, Color(1, 1, 1, 0.12), 1, 0, 12))
	var hb := HBoxContainer.new()
	var l := K.label(text, 20, Color.WHITE, 700)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hb.add_child(l)
	if action.is_valid():
		var b := K.gold_button(action_txt, 19)
		b.custom_minimum_size = Vector2(170, 54)
		b.disabled = not enabled
		b.modulate = Color.WHITE if enabled else Color(0.7, 0.68, 0.75)
		b.pressed.connect(action)
		hb.add_child(b)
	else:
		hb.add_child(K.label(right, 19, Color(1, 1, 1, 0.75), 800))
	p.add_child(hb)
	box.add_child(p)


func _toast(m: String) -> void:
	var l := K.label(m, 22, Color.WHITE, 800)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", K.glass(22, 12, 0.92))
	p.add_child(l)
	K.place(p, true, 96, 0, 60, 60)
	root.add_child(p)
	var tw := create_tween()
	tw.tween_interval(2.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(p.queue_free)


# ---------------- Observator: hartă de constelații ----------------
class Constellation:
	extends Control
	var nodes := {}          # id -> Vector2
	var links := []          # [a, b]

	func _draw() -> void:
		for i in 140:
			var p := Vector2(fmod(i * 97.3, size.x), fmod(i * 53.7, size.y))
			draw_circle(p, 1.2 + fmod(i, 3) * 0.6, Color(1, 1, 1, 0.25 + 0.15 * fmod(i, 2)))
		for l in links:
			var on: bool = Game.skills.has(l[1])
			draw_line(nodes[l[0]], nodes[l[1]], Color(1.0, 0.85, 0.4, 0.9) if on else Color(1, 1, 1, 0.25), 3.0 if on else 2.0, true)


func _observator() -> void:
	_p("Ai %d puncte de abilitate (1 la fiecare nivel). Atinge o stea." % Game.skill_points, 20, K.GOLD)
	var map := Constellation.new()
	map.custom_minimum_size = Vector2(0, 420)
	box.add_child(map)
	var branches: Array = Game.D.skills.branches
	for bi in branches.size():
		var br: Dictionary = branches[bi]
		var col := Color(br.color)
		var bx := 100.0 + bi * 200.0
		var lbl := K.label(br.name, 20, col, 900)
		lbl.position = Vector2(bx - 60, 4)
		lbl.size = Vector2(120, 30)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		map.add_child(lbl)
		var k := 0
		for s in Game.D.skills.skills:
			if s.branch != br.id:
				continue
			var pos := Vector2(bx + (34 if k % 2 else -34), 70 + k * 74)
			map.nodes[s.id] = pos
			if s.has("requires"):
				map.links.append([s.requires, s.id])
			var have: bool = Game.skills.has(s.id)
			var can := Game.can_unlock_skill(s.id)
			var st := K.box(col if have else Color(0.1, 0.07, 0.3, 0.9), 26, col if (have or can) else Color(1, 1, 1, 0.3), 3)
			var b := K.button(str(int(s.cost)), 18, st, K.INK if have else Color.WHITE)
			b.size = Vector2(52, 52)
			b.position = pos - Vector2(26, 26)
			b.tooltip_text = s.name
			var sid: String = s.id
			b.pressed.connect(func():
				_sel_skill = sid
				open("observator"))
			map.add_child(b)
			k += 1
	if _sel_skill != "":
		var s := Game.skill(_sel_skill)
		var have: bool = Game.skills.has(_sel_skill)
		var sid := _sel_skill
		var unlock := func():
			if Game.unlock_skill(sid):
				Sfx.play("upgrade")
				get_parent().mascot.joy()
		_row("%s – %s (cost %d)" % [s.name, s.desc, int(s.cost)], "Deblocată" if have else "", Callable() if have else unlock, "Deblochează", Game.can_unlock_skill(_sel_skill))
		if not have and s.has("requires") and not Game.skills.has(s.requires):
			_p("Cere întâi: %s" % Game.skill(s.requires).name, 18, Color(1, 1, 1, 0.65))


# ---------------- Garderobă ----------------
func _garderoba() -> void:
	_p("Piesele se câștigă jucând. Atinge „Poartă” ca s-o vezi pe mascotă.")
	var slots := {"casca": "Cască", "ochelari": "Ochelari", "esarfa": "Eșarfă", "corp": "Culoarea corpului", "efect": "Efect la rotire"}
	var defaults: Dictionary = Game.D.cosmetics.defaults
	for slot in slots:
		box.add_child(K.label(slots[slot], 22, K.GOLD, 900))
		var items := [{"id": defaults[slot], "name": "Implicit", "slot": slot}]
		for it in Game.D.cosmetics.items:
			if it.slot == slot:
				items.append(it)
		for it in items:
			var iid: String = it.id
			var owned: bool = it.name == "Implicit" or Game.cosmetics.has(iid)
			var worn: bool = Game.equipped.get(slot, "") == iid
			if worn:
				_row(it.name, "Purtat")
			elif owned:
				_row(it.name, "", func():
					Game.equip(iid)
					get_parent().mascot.apply_cosmetics()
					get_parent().mascot.joy(), "Poartă")
			else:
				_row(it.name, _unlock_text(it.get("unlock", {})))


func _unlock_text(u: Dictionary) -> String:
	if u.has("level"):
		return "Nivelul %d" % int(u.level)
	if u.has("streak_day"):
		return "Serie: ziua %d" % int(u.streak_day)
	if u.has("jackpots"):
		return "%d jackpoturi" % int(u.jackpots)
	if u.has("album_sets"):
		return "Un set de album"
	if u.has("spins"):
		return "%d rotiri" % int(u.spins)
	if u.has("event"):
		return "Eveniment"
	return "Blocat"


# ---------------- Atelier ----------------
func _atelier() -> void:
	_p("Îmbunătățirile dirijabilului deschid globurile următoare. Costul crește cu nivelul.")
	for a in Game.D.airship.upgrades:
		var aid: String = a.id
		var have: bool = Game.airship.has(aid)
		var lvl_ok: bool = Game.level - 1 >= int(a.requires_level)
		var txt := "%s · după nivelul %d" % [a.name, int(a.requires_level)]
		if have:
			_row(txt, "Montat")
		elif not lvl_ok:
			_row(txt, "Blocat")
		else:
			_row(txt, "", func():
				if Game.buy_airship(aid):
					Sfx.play("upgrade")
					get_parent().mascot.joy(), "%s monede" % Game.fmt(Game.airship_cost(a)), Game.can_buy_airship(a))
	if Game.can_travel():
		var b := K.gold_button("Călătorește spre %s" % Game.globe_name(Game.level_globe()), 24)
		b.custom_minimum_size = Vector2(0, 80)
		b.pressed.connect(func():
			panel.visible = false
			await get_parent().depart()
			Game.travel()
			get_tree().change_scene_to_file("res://scenes/globe.tscn"))
		box.add_child(b)
	elif Game.globe_locked():
		_p("Globul următor te așteaptă: montează îmbunătățirile de mai sus.", 20, K.GOLD)


# ---------------- Seră ----------------
func _sera() -> void:
	var c: Dictionary = Game.D.airship.companion
	var st := Game.companion_stage()
	_p("%s: %s" % [c.name, st.name], 26, Color("9fffc8"))
	_p("Bonus: +%d%% monede din rotiri. Crește singur odată cu nivelul tău." % int(round(float(st.bonus) * 100)))
	for s in c.stages:
		_row("%s · nivelul %d" % [s.name, int(s.level)], "+%d%%" % int(round(float(s.bonus) * 100)) + ("  (acum)" if s == st else ""))


# ---------------- Salon ----------------
func _salon() -> void:
	box.add_child(K.label("Trofee", 22, K.GOLD, 900))
	for t in Game.TROPHIES:
		_row("%s – %s" % [t.name, t.desc], "Obținut" if Game.trophies.has(t.id) else "—")
	box.add_child(K.label("Statistici", 22, K.GOLD, 900))
	var names := {"spins": "Rotiri", "coins": "Monede câștigate", "attacks": "Atacuri reușite", "raids": "Raiduri", "jackpots": "Jackpoturi", "chests": "Cufere deschise", "upgrades": "Construcții"}
	for k in names:
		_row(names[k], Game.fmt(int(Game.stats.get(k, 0))))
	box.add_child(K.label("Album", 22, K.GOLD, 900))
	var sets: Array = Game.D.cards.sets
	for si in sets.size():
		var have := 0
		for ci in (sets[si].cards as Array).size():
			if int(Game.cards.get(Game.card_key(si, ci), 0)) > 0:
				have += 1
		_row(sets[si].name, "%d/%d" % [have, sets[si].cards.size()])
