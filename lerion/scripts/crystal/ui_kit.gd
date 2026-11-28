extends RefCounted
## UI Animation Utilities shared by the screens: one entrance and one press language everywhere.

## Panel entrance: rises a little, scales from 92% with a soft overshoot, fades in.
static func pop_in(node: Control, reduced := false, delay := 0.0) -> Tween:
	node.pivot_offset = node.size*0.5
	if reduced:
		node.modulate.a = 1.0
		node.scale = Vector2.ONE
		return null
	node.modulate.a = 0.0
	node.scale = Vector2.ONE*0.92
	var tween := node.create_tween().set_parallel(true)
	tween.tween_property(node,"modulate:a",1.0,0.18).set_delay(delay)
	tween.tween_property(node,"scale",Vector2.ONE,0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(delay)
	return tween


## Number that counts up to `target` on a label; text uses `pattern` with one %d.
static func count_up(label: Label, from: int, target: int, pattern := "%d", time := 0.45) -> Tween:
	var tween := label.create_tween()
	tween.tween_method(func(v: int) -> void: label.text = pattern % v,from,target,time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	return tween
