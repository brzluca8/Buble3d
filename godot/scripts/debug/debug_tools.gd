extends Node
## Instrumente de test (doar versiunea de probă). Se încarcă din Game._install_debug_tools() numai
## într-un build de debug sau cu DEBUG_TOOLS = true în data/config.json. Exportul de lansare exclude
## acest fișier (export_presets.cfg → „Android (lansare)”), deci codul nu ajunge în jocul publicat.
## Valorile butoanelor vin din data/debug_tools.json. Orice acțiune trimite debug_tool_used și
## marchează sesiunea ca test (Analytics.mark_test_session()).

const K := preload("res://scripts/ui/ui_kit.gd")

var cfg := {}
var badge: CanvasLayer
var _confirm_reset := false


func _ready() -> void:
	var v = JSON.parse_string(FileAccess.get_file_as_string("res://data/debug_tools.json")) if FileAccess.file_exists("res://data/debug_tools.json") else null
	cfg = v if typeof(v) == TYPE_DICTIONARY else {}
	_badge()


## Semnul „TEST” din colțul ecranului (deasupra tuturor scenelor).
func _badge() -> void:
	badge = CanvasLayer.new()
	badge.layer = 120
	add_child(badge)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", K.box(Color("d23a4a"), 10, Color.WHITE, 2, 0, 4))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.anchor_left = 0
	p.anchor_top = 1
	p.anchor_bottom = 1
	p.offset_left = 4
	p.offset_top = -30
	p.offset_bottom = -4
	var l := K.label("TEST", 14, Color.WHITE, 900)
	p.add_child(l)
	badge.add_child(p)


func _used(tool: String, extra := {}) -> void:
	Analytics.mark_test_session()
	var p := {"tool": tool}
	p.merge(extra)
	Analytics.log_event("debug_tool_used", p)
	Game.save_game()
	Game.changed.emit()


func _btn(parent: Control, text: String, cb: Callable, col := Color("3a2a8e")) -> Button:
	var b := K.button(text, 19, K.box(col, 16, Color(1, 1, 1, 0.25), 2, 0, 8), Color.WHITE)
	b.custom_minimum_size = Vector2(0, 54)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _row(box: VBoxContainer) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	box.add_child(hb)
	return hb


## Adaugă secțiunea „Instrumente de test” în fereastra de Setări (apelat din hud_v2._m_setari).
func build_section(hud) -> void:
	var box: VBoxContainer = hud.modal_box
	var head := PanelContainer.new()
	head.add_theme_stylebox_override("panel", K.box(Color("d23a4a"), 12, Color.TRANSPARENT, 0, 0, 8))
	head.add_child(K.label("Instrumente de test – doar în versiunea de probă", 20, Color.WHITE, 800))
	box.add_child(head)
	var refresh := func(msg: String):
		hud.show_toast(msg)
		hud.open_modal("setari")
	# monede și perle
	var r1 := _row(box)
	for n in cfg.get("coins", [1000, 10000, 100000]):
		var v := int(n)
		_btn(r1, "+%s monede" % Game.fmt(v), func():
			Game.add_coins(v)
			_used("coins", {"amount": v})
			refresh.call("+%s monede" % Game.fmt(v)))
	var r2 := _row(box)
	for n in cfg.get("perle", [10, 100]):
		var v := int(n)
		_btn(r2, "+%d perle" % v, func():
			Game.perle += v
			_used("perle", {"amount": v})
			refresh.call("+%d perle" % v))
	# energie și scut
	var r3 := _row(box)
	_btn(r3, "Reumple energia", func():
		Game.energy = maxi(Game.energy, Game.energy_cap())
		_used("energy_refill")
		refresh.call("Energie plină"))
	var ea := int(cfg.get("energy_add", 50))
	_btn(r3, "+%d energie" % ea, func():
		Game.energy += ea
		_used("energy_add", {"amount": ea})
		refresh.call("+%d energie" % ea))
	_btn(r3, "+1 scut", func():
		Game.shields = mini(Game.shields + int(cfg.get("shield_add", 1)), Game.shield_cap())
		_used("shield")
		refresh.call("Scuturi: %d/%d" % [Game.shields, Game.shield_cap()]))
	# niveluri
	var r4 := _row(box)
	_btn(r4, "Un nivel în plus", func():
		go_to_level(mini(Game.level + 1, Game.max_level()))
		_used("level_up")
		hud.get_tree().reload_current_scene())
	var spin := SpinBox.new()
	spin.min_value = 1
	spin.max_value = Game.max_level()
	spin.value = mini(Game.level, Game.max_level())
	spin.custom_minimum_size = Vector2(130, 54)
	spin.add_theme_font_size_override("font_size", 22)
	r4.add_child(spin)
	_btn(r4, "Mergi la nivel", func():
		go_to_level(int(spin.value))
		_used("level_set", {"level": int(spin.value)})
		hud.get_tree().reload_current_scene())
	# timere
	_btn(_row(box), "Termină instant toate timerele (construcții, cufere)", func():
		finish_timers()
		_used("finish_timers")
		refresh.call("Toate timerele s-au terminat"))
	# rezultat forțat
	var r6 := _row(box)
	r6.add_child(K.label("Următoarea rotire:", 19, Color.WHITE, 700))
	var opt := OptionButton.new()
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt.custom_minimum_size = Vector2(0, 54)
	opt.add_theme_font_size_override("font_size", 20)
	opt.add_item("aleatorie (tabelul de șanse)")
	opt.set_item_metadata(0, "")
	var outs: Array = cfg.get("outcomes", [])
	for i in outs.size():
		opt.add_item(String(outs[i].name))
		opt.set_item_metadata(i + 1, String(outs[i].id))
		if Game.forced_outcome == String(outs[i].id):
			opt.select(i + 1)
	opt.item_selected.connect(func(idx: int):
		Game.forced_outcome = String(opt.get_item_metadata(idx))
		_used("force_outcome", {"outcome": Game.forced_outcome})
		hud.show_toast("Următoarea rotire: " + (opt.get_item_text(idx) if Game.forced_outcome != "" else "aleatorie")))
	r6.add_child(opt)
	# resetare
	var rb := _btn(_row(box), "Apasă din nou ca să ștergi tot progresul" if _confirm_reset else "Resetează tot progresul", func():
		if not _confirm_reset:
			_confirm_reset = true
			hud.open_modal("setari")
			return
		_confirm_reset = false
		_used("reset_all")
		reset_all()
		hud.get_tree().reload_current_scene(), Color("8a1c2a"))
	rb.custom_minimum_size = Vector2(0, 60)


## Duce jocul la nivelul `l`: globul nivelului, clădirile cu etapele nivelurilor anterioare din glob.
func go_to_level(l: int) -> void:
	l = clampi(l, 1, Game.max_level())
	var g := Game.level_globe(l)
	var old := Game.level
	Game.builds = []
	Game.globe = g
	for b in Game.levels:
		Game.levels[b] = 0
	for ld in Game.D.levels.levels:
		if int(ld.globe) == g and int(ld.level) < l:
			for u in ld.upgrades:
				Game.levels[u.building] = maxi(int(Game.levels.get(u.building, 0)), int(u.stage))
	Game.level = l
	Game.skill_points += maxi(0, l - old)
	Game._check_cosmetics()


func finish_timers() -> void:
	var now := Time.get_unix_time_from_system()
	for b in Game.builds:
		b.end = now - 1
	for c in Game.chests:
		if float(c.end) > 0.0:
			c.end = now - 1
	Game._tick()


## Șterge salvarea și readuce jocul la starea de început.
func reset_all() -> void:
	if FileAccess.file_exists(Game.save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.save_path))
	Game._reset_new()
	Game.level = 1
	Game.globe = 1
	Game.builds = []
	Game.chests = []
	Game.skills = {}
	Game.skill_points = 0
	Game.cosmetics = {}
	Game.airship = {}
	Game.trophies = {}
	Game.cards = {}
	Game.perle = 0
	Game.shields = 0
	Game.mult = 1
	Game.streak = {"day": 0, "last": -1}
	Game.event = {"start": Time.get_unix_time_from_system(), "points": 0, "stage": 0}
	for k in Game.stats:
		Game.stats[k] = 0
	Game.forced_outcome = ""
	Game.save_game()
