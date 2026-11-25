class_name Hud
extends CanvasLayer
## Interfața în portret: resurse sus, zarurile și butonul mare ARUNCĂ jos.
## Respectă zona sigură (notch / bara de navigare) pe Android.

signal roll_pressed
signal zoom_pressed
signal debug_indices_toggled(visible: bool)
signal debug_refill_pressed

const NAVY := Color("1d2742")

var roll_button: Button
var die_a: DieFace
var die_b: DieFace

var _margin: MarginContainer
var _coins: Label
var _gems: Label
var _energy: Label
var _regen: Label
var _sum: Label
var _info: Label
var _toast_panel: PanelContainer
var _toast_label: Label
var _toast_tween: Tween
var _indices_btn: Button


func _ready() -> void:
	name = "Hud"
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_margin = MarginContainer.new()
	_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_margin)

	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 10)
	_margin.add_child(col)

	# --- sus: resurse
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(top)
	_coins = _pill(top, HudIcon.Kind.COIN)
	_gems = _pill(top, HudIcon.Kind.GEM)
	_energy = _pill(top, HudIcon.Kind.ENERGY)

	var tools := HBoxContainer.new()
	tools.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tools.alignment = BoxContainer.ALIGNMENT_END
	tools.add_theme_constant_override("separation", 8)
	col.add_child(tools)
	_regen = _small_label("")
	_regen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools.add_child(_regen)
	var zoom_btn := _small_button("Zoom")
	zoom_btn.pressed.connect(func() -> void: zoom_pressed.emit())
	tools.add_child(zoom_btn)
	_indices_btn = _small_button("# Căsuțe")
	_indices_btn.toggle_mode = true
	_indices_btn.toggled.connect(func(on: bool) -> void: debug_indices_toggled.emit(on))
	tools.add_child(_indices_btn)
	if OS.is_debug_build():
		var refill := _small_button("+Energie (test)")
		refill.pressed.connect(func() -> void: debug_refill_pressed.emit())
		tools.add_child(refill)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(spacer)

	# --- jos: zaruri + buton
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(0.9, 30))
	col.add_child(panel)
	var bottom := VBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	panel.add_child(bottom)

	_info = Label.new()
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.add_theme_font_size_override("font_size", 28)
	_info.add_theme_color_override("font_color", Color("ffe7a8"))
	bottom.add_child(_info)

	var dice_row := HBoxContainer.new()
	dice_row.alignment = BoxContainer.ALIGNMENT_CENTER
	dice_row.add_theme_constant_override("separation", 22)
	bottom.add_child(dice_row)
	die_a = DieFace.new()
	die_b = DieFace.new()
	dice_row.add_child(die_a)
	var plus := _big_label("+")
	dice_row.add_child(plus)
	dice_row.add_child(die_b)
	_sum = _big_label("= ?")
	_sum.custom_minimum_size = Vector2(110, 0)
	dice_row.add_child(_sum)

	roll_button = Button.new()
	roll_button.name = "RollButton"
	roll_button.text = "ARUNCĂ"
	roll_button.custom_minimum_size = Vector2(0, 108)
	roll_button.add_theme_font_size_override("font_size", 54)
	roll_button.add_theme_color_override("font_color", Color.WHITE)
	roll_button.add_theme_color_override("font_hover_color", Color.WHITE)
	roll_button.add_theme_color_override("font_pressed_color", Color("fff3d6"))
	roll_button.add_theme_color_override("font_disabled_color", Color("e8e8e8"))
	roll_button.add_theme_color_override("font_outline_color", Color("9a4a10"))
	roll_button.add_theme_constant_override("outline_size", 10)
	roll_button.add_theme_stylebox_override("normal", _button_style(Color("ff9b2f"), Color("c4601a")))
	roll_button.add_theme_stylebox_override("hover", _button_style(Color("ffa845"), Color("c4601a")))
	roll_button.add_theme_stylebox_override("pressed", _button_style(Color("f08a1e"), Color("b3541a"), 4))
	roll_button.add_theme_stylebox_override("disabled", _button_style(Color("9aa3b5"), Color("6c7486")))
	roll_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	roll_button.pressed.connect(func() -> void: roll_pressed.emit())
	bottom.add_child(roll_button)

	# --- mesaj scurt (toast)
	_toast_panel = PanelContainer.new()
	_toast_panel.add_theme_stylebox_override("panel", _panel_style(0.94, 24))
	_toast_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast_panel.anchor_top = 0.3
	_toast_panel.anchor_bottom = 0.3
	_toast_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.modulate.a = 0.0
	root.add_child(_toast_panel)
	_toast_label = Label.new()
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.add_theme_font_size_override("font_size", 34)
	_toast_label.add_theme_color_override("font_color", Color("ffe7a8"))
	_toast_panel.add_child(_toast_label)

	get_viewport().size_changed.connect(_apply_safe_area)
	_apply_safe_area()


# ---------------------------------------------------------------- API

func set_resources(coins: int, gems: int, energy: int, energy_max: int) -> void:
	_coins.text = str(coins)
	_gems.text = str(gems)
	_energy.text = "%d/%d" % [energy, energy_max]


func set_regen_seconds(seconds: int) -> void:
	_regen.text = "" if seconds <= 0 else "+1 energie în %d:%02d" % [seconds / 60, seconds % 60]


func set_info(text: String) -> void:
	_info.text = text


func set_rolling(rolling: bool) -> void:
	roll_button.text = "» GRĂBEȘTE" if rolling else "ARUNCĂ"


func set_indices_button(on: bool) -> void:
	_indices_btn.set_pressed_no_signal(on)


## Animația zarurilor (rezultatul e deja decis). Așteaptă-o cu `await`.
func animate_dice(a: int, b: int, duration: float = 0.45) -> void:
	_sum.text = "= …"
	die_a.roll_to(a, duration)
	die_b.roll_to(b, duration)
	await get_tree().create_timer(duration + 0.12).timeout
	_sum.text = "= %d" % (a + b)


func show_toast(text: String, seconds: float = 1.4) -> void:
	_toast_label.text = text
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_panel.modulate.a = 1.0
	_toast_panel.scale = Vector2.ONE
	_toast_tween = create_tween()
	_toast_tween.tween_interval(seconds)
	_toast_tween.tween_property(_toast_panel, "modulate:a", 0.0, 0.3)


# ---------------------------------------------------------------- stil

func _apply_safe_area() -> void:
	var vp_size := get_viewport().get_visible_rect().size
	var win := Vector2(DisplayServer.window_get_size())
	var safe := Rect2(Vector2.ZERO, win)
	if DisplayServer.get_name() != "headless":
		var s := DisplayServer.get_display_safe_area()
		if s.size.x > 0 and s.size.y > 0:
			safe = Rect2(s)
	var k := 1.0 if win.y <= 0.0 else vp_size.y / win.y
	var top := maxf(14.0, safe.position.y * k + 8.0)
	var bottom := maxf(18.0, (win.y - safe.end.y) * k + 12.0)
	_margin.add_theme_constant_override("margin_left", 16)
	_margin.add_theme_constant_override("margin_right", 16)
	_margin.add_theme_constant_override("margin_top", int(top))
	_margin.add_theme_constant_override("margin_bottom", int(bottom))


func _panel_style(alpha: float, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(NAVY, alpha)
	s.border_color = Color("33406a")
	s.set_border_width_all(3)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 12
	s.content_margin_bottom = 14
	return s


func _button_style(bg: Color, edge: Color, bottom: int = 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = edge
	s.set_border_width_all(4)
	s.border_width_bottom = bottom
	s.set_corner_radius_all(40)
	return s


func _pill(parent: Control, kind: HudIcon.Kind) -> Label:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var st := _panel_style(0.92, 26)
	st.content_margin_top = 6
	st.content_margin_bottom = 6
	st.content_margin_left = 10
	p.add_theme_stylebox_override("panel", st)
	parent.add_child(p)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	p.add_child(row)
	row.add_child(HudIcon.new(kind))
	var l := Label.new()
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 30)
	l.add_theme_color_override("font_color", Color.WHITE)
	row.add_child(l)
	return l


func _small_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", NAVY)
	l.add_theme_constant_override("outline_size", 8)
	return l


func _small_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 58)
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color("ffe7a8"))
	b.add_theme_stylebox_override("normal", _panel_style(0.85, 22))
	b.add_theme_stylebox_override("hover", _panel_style(0.95, 22))
	var on := _panel_style(0.95, 22)
	on.border_color = Color("ffd35a")
	b.add_theme_stylebox_override("pressed", on)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


func _big_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 46)
	l.add_theme_color_override("font_color", Color.WHITE)
	return l
