extends Control
## One collectible card, drawn in a single canvas item. Illustrations are PLACEHOLDERS built from
## existing Lerion icons; the card says so ("PROVIZORIU") until final art replaces `art`.
const Cards := preload("res://scripts/economy/card_service.gd")
const ICONS := {"lerik": preload("res://assets/crystal/lerik.svg"), "pongo": preload("res://assets/crystal/pongo.svg"),
	"pufi": preload("res://assets/crystal/pufi.svg"), "chest": preload("res://assets/crystal/chest.svg"),
	"coin": preload("res://assets/crystal/coin.svg"), "crystal": preload("res://assets/crystal/crystal.svg"),
	"energy": preload("res://assets/crystal/energy.svg"), "hammer": preload("res://assets/crystal/hammer.svg"),
	"challenge": preload("res://assets/crystal/challenge.svg"), "chaos": preload("res://assets/crystal/chaos.svg")}
const INK := Color("#1b2547")
const CREAM := Color("#fff3d6")
var card := {}
var face_up := true
var owned := true
var badge := ""
var badge_color := Color("#ff6b6b")
var compact := false
var shine := 0.0


func show_card(id: String, up := true, has_it := true) -> void:
	card = Cards.card(id)
	face_up = up
	owned = has_it
	badge = ""
	queue_redraw()


func set_badge(text: String, color: Color) -> void:
	badge = text
	badge_color = color
	queue_redraw()


func flip_to(up: bool) -> void:
	face_up = up
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var unit := minf(size.x / 160.0, size.y / 220.0)
	var rare: Dictionary = Cards.rarity(str(card.get("rarity", "common")))
	var rarity_color := Color(str(rare.get("color", "#9fb4c8")))
	var shadow := StyleBoxFlat.new()
	shadow.bg_color = Color(0, 0, 0, 0.3)
	shadow.set_corner_radius_all(int(16 * unit))
	draw_style_box(shadow, Rect2(rect.position + Vector2(0, 5 * unit), rect.size))
	if not face_up or card.is_empty():
		_draw_back(rect, unit)
		return
	var col: Dictionary = Cards.collection(str(card.collection))
	var base := Color(str(col.get("color", "#3f7fe0")))
	var frame := StyleBoxFlat.new()
	frame.bg_color = rarity_color if owned else Color("#59607a")
	frame.set_corner_radius_all(int(16 * unit))
	draw_style_box(frame, rect)
	var inner := rect.grow(-6 * unit)
	var body := StyleBoxFlat.new()
	body.bg_color = base.darkened(0.45) if owned else Color("#2a3048")
	body.set_corner_radius_all(int(12 * unit))
	draw_style_box(body, inner)
	var art_rect := Rect2(inner.position + Vector2(10, 30) * unit, Vector2(inner.size.x - 20 * unit, inner.size.y * 0.42))
	var panel := StyleBoxFlat.new()
	panel.bg_color = base.lightened(0.15) if owned else Color("#3a415c")
	panel.set_corner_radius_all(int(10 * unit))
	draw_style_box(panel, art_rect)
	var font := get_theme_default_font()
	if owned:
		var icon: Texture2D = ICONS.get(str(card.art.get("icon", "chest")), ICONS.chest)
		var side := minf(art_rect.size.x, art_rect.size.y) * 0.82
		draw_texture_rect(icon, Rect2(art_rect.get_center() - Vector2.ONE * side * 0.5, Vector2.ONE * side), false)
		if shine > 0.0:
			draw_rect(Rect2(art_rect.position + Vector2(art_rect.size.x * shine - 12 * unit, 0), Vector2(18 * unit, art_rect.size.y)), Color(1, 1, 1, 0.28))
	else:
		var q := "?"
		var qs := int(60 * unit)
		draw_string(font, art_rect.get_center() + Vector2(-qs * 0.3, qs * 0.35), q, HORIZONTAL_ALIGNMENT_LEFT, -1, qs, Color(1, 1, 1, 0.25))
	# Rarity stars (top, centred).
	var stars := int(rare.get("stars", 1))
	for i in range(stars):
		var c := Vector2(inner.get_center().x + (i - (stars - 1) * 0.5) * 16 * unit, inner.position.y + 16 * unit)
		_star(c, 6.5 * unit, rarity_color if owned else Color("#59607a"))
	# Name and collection.
	var name_size := int(maxf(11.0, 17.0 * unit))
	var text := str(card.name) if owned else "Carte #%s" % str(card.id).get_slice("_", 1)
	var name_rect_y := art_rect.end.y + 6 * unit
	draw_multiline_string(font, Vector2(inner.position.x + 4 * unit, name_rect_y + name_size), text, HORIZONTAL_ALIGNMENT_CENTER,
		inner.size.x - 8 * unit, name_size, 2, CREAM if owned else Color("#8a91ad"))
	if not compact:
		var small := int(maxf(9.0, 12.0 * unit))
		draw_string(font, Vector2(inner.position.x, inner.end.y - 24 * unit), str(col.get("name", "")), HORIZONTAL_ALIGNMENT_CENTER, inner.size.x, small, base.lightened(0.6) if owned else Color("#6d748f"))
		draw_string(font, Vector2(inner.position.x, inner.end.y - 8 * unit), "ILUSTRAȚIE PROVIZORIE", HORIZONTAL_ALIGNMENT_CENTER, inner.size.x, int(maxf(8.0, 9.0 * unit)), Color(1, 1, 1, 0.45))
	if badge != "":
		_draw_badge(rect, unit, font)


func _draw_badge(rect: Rect2, unit: float, font: Font) -> void:
	var fs := int(maxf(12.0, 18.0 * unit))
	var w := font.get_string_size(badge, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x + 16 * unit
	var box := Rect2(Vector2(rect.end.x - w + 8 * unit, rect.position.y - 8 * unit), Vector2(w, fs + 10 * unit))
	var style := StyleBoxFlat.new()
	style.bg_color = badge_color
	style.border_color = Color.WHITE
	style.set_border_width_all(2)
	style.set_corner_radius_all(int(10 * unit))
	draw_style_box(style, box)
	draw_string(font, box.position + Vector2(8 * unit, fs + 1 * unit), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


func _draw_back(rect: Rect2, unit: float) -> void:
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color("#ffd06a")
	frame.set_corner_radius_all(int(16 * unit))
	draw_style_box(frame, rect)
	var body := StyleBoxFlat.new()
	body.bg_color = Color("#1d4fa3")
	body.set_corner_radius_all(int(12 * unit))
	draw_style_box(body, rect.grow(-6 * unit))
	var c := rect.get_center()
	var gem := PackedVector2Array()
	for k in range(6):
		gem.append(c + Vector2.from_angle(TAU * k / 6.0 - PI * 0.5) * Vector2(34, 44) * unit)
	draw_colored_polygon(gem, Color("#9ff0ff"))
	draw_colored_polygon(PackedVector2Array([gem[0], gem[1], c]), Color("#e8ffff"))
	draw_arc(c, 54 * unit, 0, TAU, 40, Color("#ffd06a"), 3.0 * unit, true)


func _star(c: Vector2, r: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for k in range(10):
		pts.append(c + Vector2.from_angle(-PI * 0.5 + TAU * k / 10.0) * (r if k % 2 == 0 else r * 0.45))
	draw_colored_polygon(pts, color)
