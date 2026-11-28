extends CanvasLayer
## "Puncte de construcție" window. Presentation only: every number is read from the saved state,
## the economy resource and the building config each time it refreshes. It never writes anything.
signal closed

const ECONOMY := preload("res://assets/board/economy.tres")
const RULES := preload("res://assets/board/rules.tres")
const UiKit := preload("res://scripts/crystal/ui_kit.gd")
const WORKSHOP := "left_mid"
const PANEL := Color("#1c3d49")
const DEEP := Color("#143039")
const EDGE := Color("#ffb487")
const GOLD := Color("#ffdf99")
const CREAM := Color("#fff3d6")
const SOFT := Color("#cfe6df")

var hud: CanvasLayer
var game: RefCounted
var screen := Control.new()
var panel := PanelContainer.new()
var balance: Label
var reward: Label
var reward_next: Label
var uses: Label
var sources: Label
var costs: Label
var note: Label
var hammer := TextureRect.new()
var closing: Tween


func setup(owner_hud: CanvasLayer) -> void:
	hud = owner_hud
	layer = 2
	add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.04,0.09,0.12,0.74)
	screen.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Tapping outside the window closes it, like the other screens.
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			close())
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var frame: StyleBoxFlat = hud._style(PANEL,EDGE,26)
	frame.set_border_width_all(3)
	frame.content_margin_left = 22
	frame.content_margin_right = 22
	frame.content_margin_top = 16
	frame.content_margin_bottom = 18
	frame.shadow_color = Color(1.0,0.7,0.45,0.22)
	frame.shadow_size = 14
	panel.add_theme_stylebox_override("panel",frame)
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.custom_minimum_size.x = 560
	col.add_theme_constant_override("separation",10)
	panel.add_child(col)
	var title: Label = hud._label("Puncte de construcție",32,GOLD)
	title.add_theme_constant_override("outline_size",8)
	title.add_theme_color_override("font_outline_color",DEEP)
	col.add_child(title)
	# Large hammer on a warm medallion, with the balance beside it.
	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation",18)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	var medal := PanelContainer.new()
	var disc: StyleBoxFlat = hud._style(Color("#4a3a37"),EDGE,60)
	disc.set_border_width_all(4)
	medal.add_theme_stylebox_override("panel",disc)
	medal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(medal)
	hammer.texture = hud.ICONS["hammer"]
	hammer.custom_minimum_size = Vector2(92,92)
	hammer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hammer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hammer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	medal.add_child(hammer)
	var figures := VBoxContainer.new()
	figures.alignment = BoxContainer.ALIGNMENT_CENTER
	figures.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(figures)
	figures.add_child(hud._label("Sold actual",19,SOFT))
	balance = hud._label("",46,CREAM)
	balance.add_theme_constant_override("outline_size",8)
	balance.add_theme_color_override("font_outline_color",DEEP)
	figures.add_child(balance)
	reward = _section(col,"Recompensa actuală pe căsuța cu ciocan")
	reward.add_theme_font_size_override("font_size",24)
	reward.add_theme_color_override("font_color",GOLD)
	reward_next = hud._label("",18,SOFT)
	reward_next.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reward.get_parent().add_child(reward_next)
	uses = _section(col,"La ce folosesc")
	sources = _section(col,"Cum le obțin")
	costs = hud._label("",18,SOFT)
	costs.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	uses.get_parent().add_child(costs)
	note = hud._label("",18,Color("#b7f5e8"))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(note)
	var close_button: Button = hud._button("Închide",close)
	close_button.custom_minimum_size.y = 64
	col.add_child(close_button)
	screen.hide()
	hide()


func _section(col: VBoxContainer, heading: String) -> Label:
	var box := PanelContainer.new()
	var fill: StyleBoxFlat = hud._style(DEEP,Color("#3f6f72"),16)
	fill.content_margin_left = 14
	fill.content_margin_right = 14
	fill.content_margin_top = 8
	fill.content_margin_bottom = 10
	box.add_theme_stylebox_override("panel",fill)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(box)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation",4)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(inner)
	var caption: Label = hud._label(heading,18,EDGE)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	inner.add_child(caption)
	var body: Label = hud._label("",20,CREAM)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(body)
	return body


func is_open() -> bool:
	return visible


func open(source: RefCounted) -> void:
	game = source
	if closing:
		closing.kill()
	screen.modulate.a = 1.0
	refresh()
	show()
	screen.show()
	_fit()
	UiKit.pop_in(panel,hud.prefs.reduced)


func close() -> void:
	if not visible or (closing and closing.is_running()):
		return
	if hud.prefs.reduced:
		_hide()
		return
	panel.pivot_offset = panel.size*0.5
	closing = screen.create_tween().set_parallel(true)
	closing.tween_property(screen,"modulate:a",0.0,0.16)
	closing.tween_property(panel,"scale",Vector2.ONE*0.94,0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	closing.chain().tween_callback(_hide)


func _hide() -> void:
	hide()
	screen.hide()
	screen.modulate.a = 1.0
	panel.scale = Vector2.ONE
	closed.emit()


## Keeps the window inside the HUD margins on narrow or short screens.
func _fit() -> void:
	var width := get_viewport().get_visible_rect().size.x
	var column := panel.get_child(0) as Control
	column.custom_minimum_size.x = clampf(width - 32.0 - 44.0,300.0,600.0)


func workshop_level() -> int:
	var slot: int = game.building_slot(WORKSHOP)
	return int(game.state.levels[slot]) if slot >= 0 else 0


## Build points paid by every construction tile at the given Workshop level.
static func tile_reward(level: int) -> int:
	return ECONOMY.amount("construction","build_points",level)


func refresh() -> void:
	if game == null or game.state.is_empty():
		return
	var s: Dictionary = game.state
	balance.text = str(int(s.wallet.build_points))
	var level := workshop_level()
	var top: int = game.cfg.buildings.max_level
	var slot: int = game.building_slot(WORKSHOP)
	var workshop: String = game.cfg.buildings.positions[slot].building if slot >= 0 else "Atelierul lui Pongo"
	reward.text = "+%s pe fiecare căsuță" % ECONOMY.amount_text("build_points",tile_reward(level))
	if level < top:
		reward_next.text = "%s · nivel %d. La nivelul %d: +%s." % [workshop,level,level + 1,ECONOMY.amount_text("build_points",tile_reward(level + 1))]
	else:
		reward_next.text = "%s · nivel maxim (%d)." % [workshop,level]
	uses.text = "Împreună cu monedele, plătesc construcția și îmbunătățirea celor șase clădiri ale regatului."
	var steps := PackedStringArray()
	for next_level in range(1,top + 1):
		var cost: Dictionary = game.cfg.buildings.costs_to_reach_level[str(next_level)]
		steps.append("nivel %d: %d" % [next_level,int(cost.build_points)])
	costs.text = "Necesar pe clădire · " + " · ".join(steps)
	var tiles := ECONOMY.tiles_for(WORKSHOP,RULES.tile_count).size()
	sources.text = "Oprește-te pe una dintre cele %d căsuțe cu ciocan de pe traseu. Punctele se primesc doar pe căsuța unde se oprește Lerik." % tiles
	note.text = "Îmbunătățirea Atelierului lui Pongo mărește recompensa tuturor căsuțelor de construcție de pe traseu, nu doar a celor din apropiere."
