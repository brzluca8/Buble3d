extends CanvasLayer
## Full-screen crystal-facet transition between the map and a special screen.
## Facets grow out of a screen point (the crystal), cover everything, then shatter away in the
## same order to reveal what is underneath. Visual only; it never blocks input once finished.
signal covered
signal finished
var rect := ColorRect.new()
var material := ShaderMaterial.new()
var tween: Tween


func _ready() -> void:
	layer = 4
	material.shader = preload("res://assets/fx/facet_transition.gdshader")
	rect.material = material
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false


func running() -> bool:
	return tween != null and tween.is_valid() and tween.is_running()


## Covers the screen from `origin` (screen pixels), holds for `hold`, then reveals.
func play(origin: Vector2, cover_time := 0.42, hold := 0.12, reveal_time := 0.5) -> void:
	if tween:
		tween.kill()
	var size := get_viewport().get_visible_rect().size
	material.set_shader_parameter("screen_size",size)
	material.set_shader_parameter("origin",origin)
	material.set_shader_parameter("cell",maxf(44.0,size.x/11.0))
	material.set_shader_parameter("progress",0.0)
	material.set_shader_parameter("reveal",0.0)
	visible = true
	tween = create_tween()
	tween.tween_method(func(v: float) -> void: material.set_shader_parameter("progress",v),0.0,1.0,cover_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void: covered.emit())
	tween.tween_interval(hold)
	tween.tween_method(func(v: float) -> void: material.set_shader_parameter("reveal",v),0.0,1.0,reveal_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void:
		visible = false
		finished.emit())


func stop() -> void:
	if tween:
		tween.kill()
	visible = false
