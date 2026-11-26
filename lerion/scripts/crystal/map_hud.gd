extends CanvasLayer

signal activate_requested
signal arm_requested
signal skip_requested
signal upgrade_requested(slot: int, level: int)
signal deselect_requested
signal grant_requested
signal force_requested(keys: Array)

const ICONS := {"coin": preload("res://assets/crystal/coin.svg"), "hammer": preload("res://assets/crystal/hammer.svg"),
	"crystal": preload("res://assets/crystal/crystal.svg"), "chest": preload("res://assets/crystal/chest.svg"),
	"challenge": preload("res://assets/crystal/challenge.svg"), "chaos": preload("res://assets/crystal/chaos.svg"),
	"energy": preload("res://assets/crystal/energy.svg"), "pongo": preload("res://assets/crystal/pongo.svg"),
	"lerik": preload("res://assets/crystal/lerik.svg"), "pufi": preload("res://assets/crystal/pufi.svg")}
const NAMES := {"coin":"Monedă","hammer":"Ciocan","crystal":"Cristal","chest":"Cufăr","challenge":"Provocare","chaos":"Haos"}
const UNITS := {"coins":"monede","build_points":"ciocane","fragments":"fragmente","tickets":"bilete"}
const DETAILS := [
	["Galerie cu cristale", "Șine și vagonet", "Felinar de cristal"],
	["Turn cu patru pale", "Saci de provizii", "Anexă și pale în mișcare"],
	["Atelier cu horn și ciocan", "Banc de lucru", "Ciocanul năzdrăvan"],
	["Laborator cu turn mov", "Cazan de poțiuni", "Cristale și puf de magie"],
	["Tarabă cu fructe", "Lăzi și butoi", "Firmă de negustor"],
	["Han cu acoperiș albastru", "Aripă pentru oaspeți", "Horn și felinar legănat"]]
const NAVY := Color("#23324b")
const EDGE := Color("#7ca7ae")
const CREAM := Color("#fff3d6")
const GOLD := Color("#ffd57a")

var coins: Button
var energy: Button
var fragments: Button
var bag: Button
@onready var top := HBoxContainer.new()
@onready var dock := PanelContainer.new()
@onready var home := VBoxContainer.new()
@onready var build := VBoxContainer.new()
var activate: Button
var skip: Button
var arm: Button
var meter: ProgressBar
var meter_text: Label
var title: Label
var price: Label
var confirm: Button
@onready var overlay := ColorRect.new()
var inventory: Label
var super_help: Label
var developer_box: VBoxContainer
var choices: Array[OptionButton] = []
const CrystalProjection := preload("res://scripts/crystal/projection.gd")
var effect: CrystalProjection
var cards: Array[PanelContainer] = []
var card_icons: Array[TextureRect] = []
var card_names: Array[Label] = []
@onready var reaction := HBoxContainer.new()
@onready var portrait := TextureRect.new()
@onready var prop := TextureRect.new()
var quip: Label
var selected := -1
var preview_level := 0
var effect_time := 0.0
var clip_length := 1.25
var playing := false
var source_camera: Camera3D
var reaction_tween: Tween


func _style(fill: Color, edge: Color, radius := 18) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = edge
	s.set_border_width_all(2)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 5
	s.content_margin_bottom = 5
	return s


func _label(text: String, size: int, color := CREAM) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _button(text: String, action: Callable, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 64
	b.add_theme_font_size_override("font_size", 24 if primary else 21)
	for mode: String in ["normal","hover","pressed","disabled"]:
		var fill := Color("#ffbd55") if primary else NAVY
		if mode == "pressed":
			fill = fill.darkened(0.14)
		elif mode == "hover":
			fill = fill.lightened(0.09)
		elif mode == "disabled":
			fill = Color("#546072")
		b.add_theme_stylebox_override(mode, _style(fill, GOLD if primary else EDGE))
		b.add_theme_color_override("font_" + mode + "_color", Color("#3b2d34") if primary and mode != "disabled" else CREAM)
	b.add_theme_color_override("font_color", Color("#3b2d34") if primary else CREAM)
	b.pressed.connect(action)
	return b


func _ready() -> void:
	top.add_theme_constant_override("separation", 8)
	add_child(top)
	coins = _stat("coin")
	fragments = _stat("crystal")
	energy = _stat("energy")
	bag = _button("Sac", _open_bag)
	bag.accessibility_name = "Deschide inventarul"
	top.add_child(bag)
	add_child(dock)
	dock.add_theme_stylebox_override("panel", _style(NAVY, EDGE, 22))
	var stack := VBoxContainer.new()
	dock.add_child(stack)
	stack.add_child(home)
	stack.add_child(build)
	_make_controls()
	title = _label("", 26, GOLD)
	price = _label("", 20)
	build.add_child(title)
	build.add_child(price)
	var actions := HBoxContainer.new()
	build.add_child(actions)
	actions.add_child(_button("Înapoi", func() -> void: deselect_requested.emit()))
	confirm = _button("Construiește", func() -> void: upgrade_requested.emit(selected, preview_level), true)
	confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(confirm)
	_make_projection()
	add_child(reaction)
	reaction.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.custom_minimum_size = Vector2(76, 76)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reaction.add_child(portrait)
	portrait.add_child(prop)
	prop.size = Vector2(38,38)
	prop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	prop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	prop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prop.pivot_offset = Vector2(9,30)
	quip = _label("", 19)
	quip.add_theme_stylebox_override("normal", _style(NAVY, GOLD))
	quip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	reaction.add_child(quip)
	reaction.hide()
	_make_bag()
	get_viewport().size_changed.connect(_layout)
	_layout()
	set_process(false)


func _stat(key: String) -> Button:
	var button := _button("", _open_bag)
	button.icon = ICONS[key]
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 43)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.accessibility_name = {"coin":"Monede","crystal":"Fragmente","energy":"Energie"}[key]
	top.add_child(button)
	return button


func _make_bag() -> void:
	add_child(overlay)
	overlay.color = Color(0.08,0.11,0.18,0.68)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(NAVY, GOLD, 22))
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.custom_minimum_size.x = 490
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	col.add_child(_label("Sacul lui Lerik", 31, GOLD))
	inventory = _label("", 24)
	col.add_child(inventory)
	super_help = _label("", 18)
	col.add_child(super_help)
	_make_debug(col)
	col.add_child(_button("Închide", func() -> void: overlay.hide()))
	overlay.hide()


func _force() -> void:
	var keys: Array = []
	for choice: OptionButton in choices:
		keys.append(NAMES.keys()[choice.selected])
	force_requested.emit(keys)
	overlay.hide()


func _open_bag() -> void:
	if not playing:
		overlay.show()


func _layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var lo := Vector2(16,16)
	var hi := viewport_size - Vector2(16,18)
	if OS.has_feature("android"):
		var safe := DisplayServer.get_display_safe_area()
		var inverse := get_viewport().get_screen_transform().affine_inverse()
		lo = lo.max(inverse * Vector2(safe.position) + Vector2(12,12))
		hi = hi.min(inverse * Vector2(safe.end) - Vector2(12,12))
	var width := minf(hi.x - lo.x, 720)
	var left := (hi.x + lo.x - width) * 0.5
	top.position = Vector2(left, lo.y)
	top.size = Vector2(width,64)
	dock.size = Vector2(width, dock.get_combined_minimum_size().y)
	dock.position = Vector2(left, hi.y - dock.size.y)
	var bar := $Bara as Control
	bar.offset_bottom = dock.position.y - viewport_size.y - 4
	bar.offset_top = bar.offset_bottom - 64
	reaction.position = Vector2(left, top.position.y + top.size.y + 8)


func refresh(game: RefCounted, slot: int) -> void:
	var s: Dictionary = game.state
	selected = slot
	coins.text = str(int(s.wallet.coins))
	fragments.text = str(int(s.wallet.fragments))
	energy.text = "%d/%d" % [s.energy,game.cfg.energy.max]
	inventory.text = "Monede   %d      Fragmente   %d\nCiocane   %d      Bilete   %d" % [s.wallet.coins,s.wallet.fragments,s.wallet.build_points,s.wallet.tickets]
	_refresh_controls(game, s)
	home.visible = slot < 0
	build.visible = slot >= 0
	if slot >= 0:
		preview_level = int(s.levels[slot])
		title.text = "%s  ·  %d/3" % [game.cfg.buildings.positions[slot].building,preview_level]
		confirm.visible = preview_level < game.cfg.buildings.max_level
		if confirm.visible:
			var cost: Dictionary = game.cfg.buildings.costs_to_reach_level[str(preview_level + 1)]
			var affordable: bool = s.wallet.coins >= cost.coins and s.wallet.build_points >= cost.build_points
			price.text = "%s   ·   %d monede + %d ciocane" % [DETAILS[slot][preview_level],cost.coins,cost.build_points]
			confirm.text = ("Construiește" if preview_level == 0 else "Îmbunătățește") if affordable else "Resurse insuficiente"
			confirm.disabled = not affordable or game.busy
		else:
			price.text = DETAILS[slot][2] + "   ·   Nivel maxim"
	_layout.call_deferred()


func describe(result: Dictionary) -> String:
	var entries := PackedStringArray()
	for key: String in UNITS:
		if result.reward.has(key):
			entries.append("+%d %s" % [result.reward[key],UNITS[key]])
	var name_prefix: String = {"":"", "triple":"Triplă", "mixed":"Echipă", "pair":"Pereche"}[result.combo]
	if result.super:
		name_prefix = "Super " + name_prefix
	return (" · ".join(entries) if name_prefix.is_empty() else name_prefix.strip_edges() + "  ·  " + " · ".join(entries))


func present(result: Dictionary, camera: Camera3D, duration: float) -> void:
	source_camera = camera
	clip_length = duration
	for i in range(3):
		var key: String = result.symbols[i]
		card_icons[i].texture = ICONS[key]
		card_names[i].text = NAMES[key]
	effect_time = 0.0
	playing = true
	effect.show()
	set_process(true)
	_process(0.0)


func _process(delta: float) -> void:
	effect_time += delta
	var size_v := get_viewport().get_visible_rect().size
	var start := source_camera.unproject_position(Vector3.UP * 2.4)
	var center := start.clamp(Vector2(165,250),size_v - Vector2(165,260))
	effect.origin = start
	effect.age = effect_time / clip_length
	effect.ends.clear()
	for i in range(3):
		var card := cards[i]
		var t := clampf((effect_time / clip_length - i * 0.095) * 2.7, 0, 1)
		var ease_out := 1.0 - pow(1.0-t, 3)
		card.pivot_offset = card.size * 0.5
		card.scale = Vector2.ONE * lerpf(0.25,1.0,ease_out)
		card.modulate.a = t
		var target := center + Vector2((i - 1) * 116,-116 - 20 * (i % 2))
		card.position = start.lerp(target,ease_out) - card.pivot_offset
		effect.ends.append(card.position + card.pivot_offset)
	effect.queue_redraw()
	if effect_time >= clip_length:
		skip_requested.emit()


func finish_effect() -> void:
	playing = false
	set_process(false)
	effect.hide()


func react(who: String, line: String) -> void:
	if reaction_tween:
		reaction_tween.kill()
	portrait.texture = ICONS[who]
	portrait.pivot_offset = Vector2(38,60)
	portrait.rotation = -0.22
	quip.text = line
	reaction.show()
	reaction.modulate.a = 1
	prop.visible = who != "lerik"
	prop.texture = ICONS["hammer" if who == "pongo" else "chaos"]
	prop.position = Vector2(53,26)
	prop.rotation = 0.2
	prop.scale = Vector2.ONE
	reaction_tween = create_tween()
	if who == "pongo":
		reaction_tween.tween_property(prop,"rotation",-1.15,0.19)
		reaction_tween.tween_property(prop,"rotation",0.65,0.10)
	elif who == "pufi":
		reaction_tween.tween_property(prop,"position",Vector2(61,-4),0.24)
		reaction_tween.parallel().tween_property(prop,"scale",Vector2.ONE * 1.35,0.24)
	reaction_tween.tween_property(portrait,"rotation",0.22,0.13)
	reaction_tween.tween_property(portrait,"rotation",-0.11,0.14)
	reaction_tween.tween_property(portrait,"rotation",0.0,0.14)
	reaction_tween.tween_interval(0.70)
	reaction_tween.tween_property(reaction,"modulate:a",0,0.22)
	reaction_tween.tween_callback(reaction.hide)

func blocks_map(point: Vector2) -> bool:
	return overlay.visible or top.get_global_rect().has_point(point) or dock.get_global_rect().has_point(point)


func _make_controls() -> void:
	meter = ProgressBar.new()
	var super_row := HBoxContainer.new()
	super_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	home.add_child(super_row)
	meter_text = _label("Super Cristal", 20)
	super_row.add_child(meter_text)
	meter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meter.custom_minimum_size = Vector2(50, 16)
	meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	meter.show_percentage = false
	meter.add_theme_stylebox_override("background", _style(Color("#152238"), Color("#4b6174"), 8))
	meter.add_theme_stylebox_override("fill", _style(Color("#66d6dc"), Color("#a0eff0"), 8))
	super_row.add_child(meter)
	arm = _button("Armează", func() -> void: arm_requested.emit())
	super_row.add_child(arm)
	activate = _button("ACTIVEAZĂ", func() -> void: activate_requested.emit(), true)
	home.add_child(activate)
	skip = _button("Sari animația", func() -> void: skip_requested.emit())
	super_row.add_child(skip)
	skip.hide()


func _make_projection() -> void:
	effect = CrystalProjection.new()
	add_child(effect)
	effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in range(3):
		var card := PanelContainer.new()
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_theme_stylebox_override("panel", _style(Color("#283755"), GOLD, 20))
		effect.add_child(card)
		var col := VBoxContainer.new()
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(col)
		var icon := TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(78, 62)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(icon)
		var caption := _label("", 16)
		col.add_child(caption)
		cards.append(card)
		card_icons.append(icon)
		card_names.append(caption)
	effect.hide()


func _make_debug(col: VBoxContainer) -> void:
	if OS.is_debug_build():
		developer_box = VBoxContainer.new()
		col.add_child(_button("Unelte de test", func() -> void: developer_box.visible = not developer_box.visible))
		col.add_child(developer_box)
		developer_box.add_child(_button("Adaugă resurse și încarcă Super Cristal", func() -> void: grant_requested.emit()))
		var row := HBoxContainer.new()
		developer_box.add_child(row)
		for i in range(3):
			var choice := OptionButton.new()
			choice.custom_minimum_size = Vector2(140,60)
			choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			for key: String in NAMES:
				choice.add_item(NAMES[key])
			row.add_child(choice)
			choices.append(choice)
		developer_box.add_child(_button("Fixează următoarele simboluri", _force))
		developer_box.hide()


func _refresh_controls(game: RefCounted, s: Dictionary) -> void:
	meter.max_value = game.cfg.super_crystal.charge_max
	meter.value = s.charge
	meter_text.text = "Super Cristal   %d/%d  " % [s.charge,meter.max_value]
	skip.visible = game.busy
	arm.visible = s.charge == meter.max_value and not game.busy
	arm.disabled = s.armed or game.busy
	arm.text = "Armat" if s.armed else "Armează"
	activate.text = "ACTIVEAZĂ SUPER CRISTAL" if s.armed else "ACTIVEAZĂ"
	activate.text += "  ·  %d energie" % game.cfg.activation.energy_cost
	super_help.text = "Super Cristal la %d activări\nMonede și ciocane ×2, plus un cufăr." % game.cfg.super_crystal.charge_max
	activate.disabled = game.busy or s.energy < game.cfg.activation.energy_cost
	if game.busy:
		activate.text = "Cristalul proiectează…"
	elif activate.disabled:
		var seconds := maxi(0, int(s.tick + game.cfg.energy.regenerate_one_per_minutes * 60) - int(Time.get_unix_time_from_system()))
		activate.text = "Energie în %d:%02d" % [seconds / 60,seconds % 60]
