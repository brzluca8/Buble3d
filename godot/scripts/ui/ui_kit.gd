class_name UiKit
extends RefCounted
## Stiluri și controale comune – direcția Neon noir (18+): negru de noapte, neon turcoaz
## și magenta, sticlă fumurie, colțuri teșite. Titluri cu Chakra Petch, text cu Montserrat (OFL).

const GOLD := Color("37e8f5")          # accentul principal (neon turcoaz; numele vechi rămâne pentru cod)
const GOLD_DK := Color("0f6f7a")
const PINK := Color("ff3fa4")          # neon magenta: butonul principal
const PINK_DK := Color("8a1458")
const COIN := Color("ffc94a")          # monedele rămân aurii, ca să se recunoască
const VIO := Color("7a3cff")
const INK := Color("0a0b12")
const NAVY := Color("07080e")
const CARD := Color("12131c")
const IVORY := Color("f2f4ff")
const RUBY := Color("e0304a")

static var _fonts := {}


## Greutatea 900 = titluri (Chakra Petch 700); restul = Montserrat 600/700/800.
## Fiecare are subsetul latin-ext ca rezervă, pentru ă/ș/ț.
static func font(weight := 700) -> Font:
	var w := clampi(int(round(weight / 100.0)) * 100, 600, 900)
	if not _fonts.has(w):
		var fam := "chakra-petch" if w >= 900 else "montserrat"
		var fw := 700 if w >= 900 else w
		var ext := load("res://assets/fonts/%s-latin-ext-%d-normal.woff2" % [fam, fw]) as FontFile
		var base := load("res://assets/fonts/%s-latin-%d-normal.woff2" % [fam, fw]) as FontFile
		var f: Font = base
		if base == null:
			var sf := SystemFont.new()
			sf.font_weight = fw
			f = sf
		if ext:
			f.fallbacks = [ext]
		_fonts[w] = f
	return _fonts[w]


static var _icons := {}

## Iconiță albă (Lucide, ISC) din res://assets/icons; se colorează cu modulate.
static func icon(name: String) -> Texture2D:
	if not _icons.has(name):
		_icons[name] = load("res://assets/icons/%s.png" % name) if ResourceLoader.exists("res://assets/icons/%s.png" % name) else null
	return _icons[name]


static func icon_rect(name: String, size := 40.0, col := Color.WHITE) -> TextureRect:
	var t := TextureRect.new()
	t.texture = icon(name)
	t.custom_minimum_size = Vector2(size, size)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.modulate = col
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## Panou de sticlă fumurie: negru translucid, filet de neon turcoaz, colțuri teșite.
static func glass(radius := 28, pad := 16, alpha := 0.82) -> StyleBoxFlat:
	var s := box(Color(0.03, 0.035, 0.06, alpha), radius, Color(GOLD, 0.45), 2, 10, pad)
	s.shadow_color = Color(GOLD, 0.12)
	return s


## Buton cu iconiță și text (fără emoji).
static func icon_button(icon_name: String, text: String, size := 24, style: StyleBox = null, col := Color.WHITE, icon_size := 34.0) -> Button:
	var b := button(text, size, style if style else glass(22, 10), col)
	b.icon = icon(icon_name)
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width", int(icon_size))
	b.add_theme_color_override("icon_normal_color", col)
	b.add_theme_color_override("icon_pressed_color", col)
	b.add_theme_color_override("icon_hover_color", col)
	return b


static func theme() -> Theme:
	var t := Theme.new()
	t.default_font = font(700)
	t.default_font_size = 26
	return t


static func box(bg: Color, radius := 24, border := Color.TRANSPARENT, bw := 0, shadow := 0, pad := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	# Art Deco: colțuri teșite (un singur segment), mai mici decât rotunjirile vechi
	s.set_corner_radius_all(int(radius * 0.45))
	s.corner_detail = 1
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


static func label(text: String, size := 26, color := Color.WHITE, weight := 700, outline := 0, outline_color := Color("0a0c12")) -> Label:
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


## Butonul principal (Rotește, Construiește...): magenta neon, cu halou luminos.
static func gold_button(text: String, size := 30) -> Button:
	var n := box(PINK, 30, Color("ffb0dc"), 2)
	n.border_width_bottom = 7
	n.border_color = PINK_DK
	n.shadow_color = Color(PINK, 0.45)
	n.shadow_size = 18
	n.shadow_offset = Vector2(0, 0)
	var p := n.duplicate() as StyleBoxFlat
	p.border_width_bottom = 4
	p.content_margin_top = 5
	return button(text, size, n, Color.WHITE, p)


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
