class_name UiKit
extends RefCounted
## Stiluri și controale comune (culorile Buble: auriu, violet, cerneală).

const GOLD := Color("f6c445")
const VIO := Color("6d3fc0")
const INK := Color("2a1766")
const NAVY := Color("201a5e")
const CARD := Color("2a2278")

static var _fonts := {}


static func font(weight := 700) -> Font:
	if not _fonts.has(weight):
		var emoji := SystemFont.new()
		emoji.font_names = PackedStringArray(["Noto Color Emoji", "Apple Color Emoji", "Segoe UI Emoji", "Twemoji"])
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Nunito", "Roboto", "Noto Sans", "Segoe UI", "Helvetica Neue", "Arial", "sans-serif"])
		f.font_weight = weight
		f.fallbacks = [emoji]
		_fonts[weight] = f
	return _fonts[weight]


static func theme() -> Theme:
	var t := Theme.new()
	t.default_font = font(700)
	t.default_font_size = 26
	return t


static func box(bg: Color, radius := 24, border := Color.TRANSPARENT, bw := 0, shadow := 0, pad := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	if bw > 0:
		s.border_color = border
		s.set_border_width_all(bw)
	if shadow > 0:
		s.shadow_color = Color(0, 0, 0, 0.3)
		s.shadow_size = shadow
		s.shadow_offset = Vector2(0, shadow * 0.5)
	s.set_content_margin_all(pad)
	s.anti_aliasing = true
	return s


static func label(text: String, size := 26, color := Color.WHITE, weight := 700, outline := 0, outline_color := Color("4b2aa0")) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(weight))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", outline_color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func button(text: String, size := 26, normal: StyleBox = null, color := Color.WHITE, pressed: StyleBox = null) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", font(800))
	b.add_theme_font_size_override("font_size", size)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, color)
	b.add_theme_color_override("font_disabled_color", Color(color, 0.5))
	var n: StyleBox = normal if normal else StyleBoxEmpty.new()
	var p: StyleBox = pressed if pressed else n
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", n)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("hover_pressed", p)
	b.add_theme_stylebox_override("disabled", n)
	b.focus_mode = Control.FOCUS_NONE
	return b


## Buton auriu principal (Îmbunătățește, Buble Blast...).
static func gold_button(text: String, size := 30) -> Button:
	var n := box(Color("f8c548"), 60, Color("ffe38a"), 3)
	n.border_width_bottom = 9
	n.border_color = Color("b57400")
	n.shadow_color = Color(0, 0, 0, 0.3)
	n.shadow_size = 10
	n.shadow_offset = Vector2(0, 6)
	var p := n.duplicate() as StyleBoxFlat
	p.border_width_bottom = 4
	p.content_margin_top = 5
	return button(text, size, n, INK, p)


static func full_rect(c: Control) -> Control:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c


## Ancorează un control: lățime completă (cu margini) sau centrat, pe sus/jos.
static func place(c: Control, top: bool, y: float, h: float, left := 20.0, right := 20.0) -> void:
	c.anchor_left = 0
	c.anchor_right = 1
	c.anchor_top = 0 if top else 1
	c.anchor_bottom = c.anchor_top
	c.offset_left = left
	c.offset_right = -right
	if top:
		c.offset_top = y
		c.offset_bottom = y + h
	else:
		c.offset_top = -y - h
		c.offset_bottom = -y
