class_name DieFace
extends Control
## Un zar desenat 2D (fețe 1..6 cu puncte), cu animație scurtă de rostogolire.

var value: int = 1:
	set(v):
		value = clampi(v, 1, 6)
		queue_redraw()

const PIPS := {
	1: [Vector2(0.5, 0.5)],
	2: [Vector2(0.27, 0.27), Vector2(0.73, 0.73)],
	3: [Vector2(0.27, 0.27), Vector2(0.5, 0.5), Vector2(0.73, 0.73)],
	4: [Vector2(0.27, 0.27), Vector2(0.73, 0.27), Vector2(0.27, 0.73), Vector2(0.73, 0.73)],
	5: [Vector2(0.27, 0.27), Vector2(0.73, 0.27), Vector2(0.5, 0.5), Vector2(0.27, 0.73), Vector2(0.73, 0.73)],
	6: [Vector2(0.27, 0.25), Vector2(0.73, 0.25), Vector2(0.27, 0.5), Vector2(0.73, 0.5), Vector2(0.27, 0.75), Vector2(0.73, 0.75)],
}

var _box := StyleBoxFlat.new()


func _init() -> void:
	custom_minimum_size = Vector2(80, 80)
	_box.bg_color = Color("fffaf0")
	_box.border_color = Color("d9c59c")
	_box.set_border_width_all(4)
	_box.border_width_bottom = 9
	_box.set_corner_radius_all(20)
	_box.shadow_color = Color(0, 0, 0, 0.25)
	_box.shadow_size = 4


func _ready() -> void:
	resized.connect(func() -> void: pivot_offset = size * 0.5)
	pivot_offset = size * 0.5


func _draw() -> void:
	draw_style_box(_box, Rect2(Vector2.ZERO, size))
	var inner := Rect2(Vector2(4, 4), size - Vector2(8, 13))
	var r := minf(inner.size.x, inner.size.y) * 0.095
	for p in PIPS[value]:
		var pos: Vector2 = inner.position + (p as Vector2) * inner.size
		draw_circle(pos, r, Color("2b2533"))


## Rostogolire: fețe aleatoare timp de `duration`, apoi fața finală (deja decisă).
func roll_to(final_value: int, duration: float) -> void:
	var t := create_tween()
	var frames := maxi(3, int(duration / 0.07))
	for i in frames:
		t.tween_callback(func() -> void: value = randi_range(1, 6))
		t.tween_property(self, "rotation", deg_to_rad(randf_range(-25.0, 25.0)), 0.07)
	t.tween_callback(func() -> void: value = final_value)
	t.tween_property(self, "rotation", 0.0, 0.08)
	t.parallel().tween_property(self, "scale", Vector2(1.18, 1.18), 0.08)
	t.tween_property(self, "scale", Vector2.ONE, 0.1)
