class_name HudIcon
extends Control
## Iconițe vectoriale simple (fără fișiere externe): monedă, cristal, energie.

enum Kind { COIN, GEM, ENERGY }

var kind: Kind = Kind.COIN


func _init(k: Kind = Kind.COIN) -> void:
	kind = k
	custom_minimum_size = Vector2(40, 40)


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.45
	match kind:
		Kind.COIN:
			draw_circle(c, r, Color("e0a31e"))
			draw_circle(c, r * 0.78, Color("ffd35a"))
			draw_circle(c, r * 0.4, Color("f3b72f"))
		Kind.GEM:
			var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.8, -r * 0.2), c + Vector2(0, r), c + Vector2(-r * 0.8, -r * 0.2)])
			draw_colored_polygon(pts, Color("4fd8ff"))
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.8, -r * 0.2), c]), Color("a6ecff"))
			draw_polyline(pts + PackedVector2Array([pts[0]]), Color("1c6fa8"), 2.0)
		Kind.ENERGY:
			var bolt := PackedVector2Array([
				c + Vector2(r * 0.2, -r), c + Vector2(-r * 0.55, r * 0.12), c + Vector2(-r * 0.02, r * 0.12),
				c + Vector2(-r * 0.25, r), c + Vector2(r * 0.6, -r * 0.18), c + Vector2(r * 0.05, -r * 0.18),
			])
			draw_colored_polygon(bolt, Color("ffd02e"))
			draw_polyline(bolt + PackedVector2Array([bolt[0]]), Color("c47f00"), 2.0)
