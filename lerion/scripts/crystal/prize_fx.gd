extends Control
## Lightweight 2D particles for the Magic Wheel prizes, drawn in one canvas item.
## Four styles: energy bolts, wooden splinters, silver stars and golden confetti.
const STYLES := {
	"energy": {"count":34,"colors":[Color("#fff59a"),Color("#b0ffb4"),Color("#7ff0ff")],"gravity":-60.0,"speed":[220.0,520.0],"life":1.0,"shape":"bolt"},
	"wood": {"count":26,"colors":[Color("#c98a4b"),Color("#8f5a2c"),Color("#9be07a")],"gravity":620.0,"speed":[200.0,460.0],"life":1.2,"shape":"chip"},
	"silver": {"count":38,"colors":[Color("#ffffff"),Color("#d6e6f5"),Color("#9fd2ff")],"gravity":90.0,"speed":[160.0,420.0],"life":1.4,"shape":"star"},
	"gold": {"count":68,"colors":[Color("#ffd04a"),Color("#ffb52e"),Color("#fff1a8"),Color("#ff8fd0")],"gravity":420.0,"speed":[260.0,720.0],"life":1.9,"shape":"confetti"},
}
var pos := PackedVector2Array()
var vel := PackedVector2Array()
var age := PackedFloat32Array()
var life := PackedFloat32Array()
var spin := PackedFloat32Array()
var colors := PackedColorArray()
var shape := "bolt"
var gravity := 0.0
var reduced := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func play(origin: Vector2, style: String) -> void:
	var spec: Dictionary = STYLES.get(style,STYLES.energy)
	shape = spec.shape
	gravity = spec.gravity
	var count := int(spec.count)
	if reduced:
		count = mini(count,10)
	for i in range(count):
		var direction := Vector2.from_angle(randf()*TAU)
		if style == "gold" or style == "wood":
			direction = Vector2.from_angle(randf_range(-PI*0.92,-PI*0.08))
		pos.append(origin + direction*randf_range(4.0,28.0))
		vel.append(direction*randf_range(spec.speed[0],spec.speed[1]))
		age.append(0.0)
		life.append(float(spec.life)*randf_range(0.7,1.15))
		spin.append(randf_range(-9.0,9.0))
		colors.append(spec.colors[i % spec.colors.size()])
	set_process(true)


func clear() -> void:
	pos.clear()
	vel.clear()
	age.clear()
	life.clear()
	spin.clear()
	colors.clear()
	set_process(false)
	queue_redraw()


func _process(delta: float) -> void:
	var i := 0
	while i < pos.size():
		age[i] += delta
		if age[i] >= life[i]:
			pos.remove_at(i)
			vel.remove_at(i)
			age.remove_at(i)
			life.remove_at(i)
			spin.remove_at(i)
			colors.remove_at(i)
			continue
		vel[i] = vel[i]*(1.0 - 1.6*delta) + Vector2(0,gravity*delta)
		pos[i] += vel[i]*delta
		i += 1
	queue_redraw()
	if pos.is_empty():
		set_process(false)


func _draw() -> void:
	for i in range(pos.size()):
		var t := age[i]/life[i]
		var fade := 1.0 - t*t
		var color := Color(colors[i],fade)
		var p := pos[i]
		var turn := spin[i]*age[i]
		match shape:
			"bolt":
				var r := 9.0*(1.0-0.4*t)
				draw_set_transform(p,turn*0.2,Vector2.ONE)
				draw_polyline(PackedVector2Array([Vector2(2,-r),Vector2(-r*0.55,r*0.1),Vector2(r*0.45,0),Vector2(-2,r*1.2)]),color,3.0,true)
			"chip":
				draw_set_transform(p,turn,Vector2.ONE)
				draw_rect(Rect2(-6,-3,12,6),color)
			"star":
				var r := 8.0*sin(PI*minf(1.0,t*1.3)) + 2.0
				draw_set_transform(p,turn*0.3,Vector2.ONE)
				draw_colored_polygon(PackedVector2Array([Vector2(0,-r*1.6),Vector2(r*0.32,-r*0.32),Vector2(r*1.6,0),
					Vector2(r*0.32,r*0.32),Vector2(0,r*1.6),Vector2(-r*0.32,r*0.32),Vector2(-r*1.6,0),Vector2(-r*0.32,-r*0.32)]),color)
			_:
				draw_set_transform(p,turn,Vector2(1.0,absf(cos(turn*0.7))+0.15))
				if i % 5 == 0:
					draw_circle(Vector2.ZERO,6.0,color)
				else:
					draw_rect(Rect2(-7,-4,14,8),color)
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
