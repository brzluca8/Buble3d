extends Node2D
## Inel auriu care pulsează la baza clădirii selectate.

var w := 400.0
var h := 600.0
var _t := 0.0


func _process(dt: float) -> void:
	_t += dt
	queue_redraw()


func _draw() -> void:
	var k := 1.0 + 0.05 * sin(_t * 4.0)
	var rx := w * 0.5 * k
	var ry := rx * 0.32
	var pts := PackedVector2Array()
	for i in 49:
		var a := TAU * i / 48.0
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	draw_polyline(pts, Color(1.0, 0.85, 0.35, 0.35), 22.0, true)
	draw_polyline(pts, Color(1.0, 0.88, 0.45, 0.95), 7.0, true)
	# săgeată care plutește deasupra
	var y := -h - 10.0 - 20.0 * absf(sin(_t * 3.0))
	var tri := PackedVector2Array([Vector2(-34, y - 44), Vector2(34, y - 44), Vector2(0, y)])
	draw_colored_polygon(tri, Color(1.0, 0.82, 0.3))
	draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), Color("b57400"), 5.0, true)
