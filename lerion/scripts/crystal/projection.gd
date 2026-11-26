extends Control

var origin := Vector2.ZERO
var ends := PackedVector2Array()
var age := 0.0


func _draw() -> void:
	var pulse := sin(clampf(age,0,1) * PI)
	if pulse <= 0:
		return
	for i in range(3):
		var radius := 19.0 + 7.0 * i + 8.0 * pulse
		draw_circle(origin, radius, Color(0.54,0.96,1.0,0.045 * pulse))
	draw_arc(origin, 16.0 + 18.0 * pulse, 0, TAU, 36, Color(0.81,1,1,0.72 * pulse), 2, true)
	for i in range(ends.size()):
		var axis := ends[i] - origin
		if axis.length() < 12:
			continue
		var side := axis.normalized().orthogonal() * 5.0
		draw_colored_polygon(PackedVector2Array([origin,ends[i]+side,ends[i]-side]),Color(0.65,0.96,1,0.18*pulse))
		draw_line(origin,ends[i],Color(0.85,1,1,0.80*pulse),1.8,true)
		var sparkle := origin + axis * fmod(age * 1.55 + i * 0.27,1.0)
		draw_circle(sparkle,3.0,Color(1,0.92,0.61,pulse))
