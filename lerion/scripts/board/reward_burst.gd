extends Control
## Paint a short crown of resource-shaped glints in one canvas item.
var eye: Camera3D
var point := Vector3.ZERO
var tint := Color.WHITE
var phase := 0.0
var shape := ""
var rare := false
var point2d := Vector2.ZERO

func play(camera: Camera3D, location: Vector3, color: Color, key := "", special := false) -> void:
	eye = camera
	point = location
	tint = color
	shape = key
	rare = special
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sparkle := create_tween()
	sparkle.tween_method(_frame,0.0,1.0,0.52 if rare else 0.39)
	sparkle.tween_callback(queue_free)

## Same crown of glints at a screen position (HUD buttons and counters).
func play_at(screen: Vector2, color: Color, key := "", special := false) -> void:
	point2d = screen
	play(null,Vector3.ZERO,color,key,special)


func _frame(t: float) -> void:
	phase = t
	position = eye.unproject_position(point) if eye else point2d
	queue_redraw()

func _draw() -> void:
	var count := 10 if rare else 6
	var swell := sin(PI*phase)
	if swell <= 0.015:
		return
	if rare:
		var radius := lerpf(15,52,phase)
		for i in range(4):
			var start := PI*0.5*i+phase*0.45
			draw_arc(Vector2.ZERO,radius,start,start+0.85,10,Color(tint,0.76*swell),2.5,true)
	for i in range(count):
		var axis := Vector2.from_angle(TAU*i/count+0.25)
		var p := axis*lerpf(12,54 if rare else 37,phase)
		var r := (5.3 if i%2 == 0 else 3.6)*swell
		match shape:
			"coins":
				draw_circle(p,r,tint,true,-1,true)
				draw_line(p-Vector2.UP*r*0.52,p+Vector2.UP*r*0.52,Color("#a06940"),1.3,true)
			"energy":
				draw_polyline(PackedVector2Array([p+Vector2(0,-r),p+Vector2(-r*0.6,0),p+Vector2(r*0.45,0),p+Vector2(0,r*1.3)]),tint,2.3,true)
			"build_points":
				draw_set_transform(p,phase*1.4,Vector2.ONE)
				draw_rect(Rect2(-r,-r,2*r,2*r),tint)
				draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
			_:
				draw_colored_polygon(PackedVector2Array([p+Vector2.UP*r*1.65,p+Vector2.RIGHT*r,
					p+Vector2.DOWN*r*1.65,p+Vector2.LEFT*r]),tint)
