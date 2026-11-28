extends Control
## The Magic Wheel disc. Every slice spans an angle proportional to its configured weight,
## so the area a player sees equals the real chance. Rotation is applied to this Control,
## the slices are drawn once; only the rim bulbs are redrawn by a small child at ~12 Hz.
const Crystal := preload("res://scripts/crystal/super_crystal_service.gd")
const ENERGY := preload("res://assets/crystal/energy.svg")
const CHEST := preload("res://assets/crystal/chest.svg")
const POINTER_ANGLE := -PI*0.5
const CHEST_TINT := {"wood":Color("#d79a5c"),"silver":Color("#e4eef7"),"gold":Color("#ffd04a")}
const FILLS := [Color("#1d4fa3"),Color("#13377a"),Color("#2766c4"),Color("#163f8a"),Color("#2f7fdc"),Color("#0f2d66")]
const GOLD := Color("#ffd06a")
const DEEP_GOLD := Color("#c98a26")
var starts := PackedFloat32Array()
var spans := PackedFloat32Array()
var radius := 280.0
var bulbs: Control
var bulb_phase := 0
var bulb_clock := 0.0
var spinning := false
var win_index := -1
var win_age := 0.0
const ACCENT := {"energy": Color("#5fe0cf"), "wood": Color("#d99a58"), "silver": Color("#e6f0f8"), "gold": Color("#ffd04a")}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var angle := 0.0
	var total := float(Crystal.total_weight())
	for item: Dictionary in Crystal.prizes():
		starts.append(angle)
		var span := TAU*float(item.weight)/total
		spans.append(span)
		angle += span
	bulbs = Control.new()
	bulbs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bulbs.draw.connect(_draw_bulbs)
	add_child(bulbs)
	resized.connect(_fit)
	_fit()


func _fit() -> void:
	radius = minf(size.x,size.y)*0.5
	pivot_offset = size*0.5
	bulbs.size = size
	queue_redraw()
	bulbs.queue_redraw()


## Wheel-local angle of a slice's centre.
func slice_center(index: int) -> float:
	return starts[index] + spans[index]*0.5


## Index of the slice that sits under the fixed pointer for a given wheel rotation.
func slice_under_pointer(wheel_rotation: float) -> int:
	var local := fposmod(POINTER_ANGLE - wheel_rotation,TAU)
	for i in range(starts.size()):
		if local >= starts[i] and local < starts[i] + spans[i]:
			return i
	return starts.size()-1


## Final rotation that places the pointer inside the confirmed slice, away from its borders.
func rotation_for(index: int, from_rotation: float, turns: int, offset01: float) -> float:
	var inside := starts[index] + spans[index]*lerpf(0.18,0.82,clampf(offset01,0.0,1.0))
	var goal := POINTER_ANGLE - inside
	var base := from_rotation + TAU*turns
	return base + fposmod(goal - base,TAU)


func _process(delta: float) -> void:
	bulb_clock += delta
	win_age += delta
	if bulb_clock >= (0.07 if spinning else (0.04 if win_index >= 0 else 0.16)):
		bulb_clock = 0.0
		bulb_phase += 1
		bulbs.queue_redraw()


func _draw() -> void:
	var c := size*0.5
	var r := radius
	draw_circle(c + Vector2(0,10),r,Color(0.02,0.05,0.12,0.45))
	draw_circle(c,r,DEEP_GOLD)
	draw_circle(c,r-4,GOLD)
	draw_circle(c,r-16,Color("#0c2350"))
	var inner := r-20
	var font := get_theme_default_font()
	for i in range(starts.size()):
		var item: Dictionary = Crystal.prizes()[i]
		var points := PackedVector2Array([c])
		var steps := maxi(4,int(spans[i]/0.06))
		for k in range(steps+1):
			points.append(c + Vector2.from_angle(starts[i] + spans[i]*k/steps)*inner)
		var fill: Color = FILLS[i % FILLS.size()]
		if item.kind == "chest" and item.chest == "gold":
			fill = Color("#5a2f86")
		draw_colored_polygon(points,fill)
		# Lighter inner band gives the slices a soft enamel look.
		var band := PackedVector2Array([c])
		for k in range(steps+1):
			band.append(c + Vector2.from_angle(starts[i] + spans[i]*k/steps)*inner*0.42)
		draw_colored_polygon(band,fill.lightened(0.12))
		# Rim band in the prize colour so energy and each chest tier read at a glance.
		var accent: Color = ACCENT["energy"] if item.kind == "energy" else ACCENT[item.chest]
		var rim := PackedVector2Array()
		for k in range(steps+1):
			rim.append(c + Vector2.from_angle(starts[i] + spans[i]*k/steps)*inner)
		for k in range(steps,-1,-1):
			rim.append(c + Vector2.from_angle(starts[i] + spans[i]*k/steps)*(inner - 11.0))
		draw_colored_polygon(rim,Color(accent,0.85))
		# Soft highlight on the outer third of the slice.
		var gloss := PackedVector2Array()
		for k in range(steps+1):
			gloss.append(c + Vector2.from_angle(starts[i] + spans[i]*(0.1 + 0.8*k/steps))*(inner*0.9))
		for k in range(steps,-1,-1):
			gloss.append(c + Vector2.from_angle(starts[i] + spans[i]*(0.1 + 0.8*k/steps))*(inner*0.62))
		draw_colored_polygon(gloss,Color(1,1,1,0.06))
	for i in range(starts.size()):
		draw_line(c,c + Vector2.from_angle(starts[i])*inner,GOLD,4.0,true)
		draw_circle(c + Vector2.from_angle(starts[i])*(inner-3),5.0,Color("#fff3c4"))
	for i in range(starts.size()):
		var item: Dictionary = Crystal.prizes()[i]
		var mid := slice_center(i)
		var icon_size := clampf(spans[i]*inner*0.52,38.0,74.0)
		var at := c + Vector2.from_angle(mid)*inner*0.66
		draw_set_transform(at,mid + PI*0.5,Vector2.ONE)
		var texture: Texture2D = ENERGY if item.kind == "energy" else CHEST
		var tint: Color = Color("#fff59a") if item.kind == "energy" else CHEST_TINT.get(item.chest,Color.WHITE)
		draw_texture_rect(texture,Rect2(Vector2(-icon_size*0.5,-icon_size*0.62),Vector2.ONE*icon_size),false,tint)
		var caption: String = ("+%d" % int(item.amount)) if item.kind == "energy" else {"wood":"LEMN","silver":"ARGINT","gold":"AUR"}[item.chest]
		var font_size := 30 if item.kind == "energy" else (20 if spans[i] > 0.5 else 15)
		var width := font.get_string_size(caption,HORIZONTAL_ALIGNMENT_CENTER,-1,font_size).x
		draw_string_outline(font,Vector2(-width*0.5,icon_size*0.62+font_size*0.4),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,6,Color("#0b1b3c"))
		draw_string(font,Vector2(-width*0.5,icon_size*0.62+font_size*0.4),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color("#fff4d0"))
		draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
	draw_arc(c,inner,0,TAU,96,GOLD,4.0,true)
	# Hub with a crystal facet.
	draw_circle(c,r*0.17,DEEP_GOLD)
	draw_circle(c,r*0.15,GOLD)
	draw_circle(c,r*0.11,Color("#1f6fd0"))
	var gem := PackedVector2Array()
	for k in range(6):
		gem.append(c + Vector2.from_angle(TAU*k/6.0 - PI*0.5)*Vector2(r*0.07,r*0.09))
	draw_colored_polygon(gem,Color("#9ff0ff"))
	draw_colored_polygon(PackedVector2Array([gem[0],gem[1],c]),Color("#e8ffff"))


func _draw_bulbs() -> void:
	var c := size*0.5
	var count := 24
	for i in range(count):
		var lit := (i + bulb_phase) % 2 == 0 if not spinning else (i + bulb_phase) % 4 == 0
		var p := c + Vector2.from_angle(TAU*i/count)*(radius-10)
		bulbs.draw_circle(p,6.5,Color("#fff7cf") if lit else Color("#a5691e"))
		if lit:
			bulbs.draw_circle(p,10.0,Color(1.0,0.95,0.7,0.25))
	var inner := radius - 20.0
	# The gold slice always twinkles a little: it is the prize worth spotting.
	var now := Time.get_ticks_msec()/1000.0
	for i in range(starts.size()):
		var item: Dictionary = Crystal.prizes()[i]
		if item.kind == "chest" and item.chest == "gold":
			for k in range(4):
				var t := pow(maxf(0.0,sin(now*2.3 + k*1.7)),4.0)
				var a: float = starts[i] + spans[i]*(0.2 + 0.2*k)
				var q := c + Vector2.from_angle(a)*(inner*(0.5 + 0.12*k))
				var r := 4.0 + 8.0*t
				bulbs.draw_colored_polygon(PackedVector2Array([q + Vector2(0,-r),q + Vector2(r*0.2,-r*0.2),q + Vector2(r,0),q + Vector2(r*0.2,r*0.2),
					q + Vector2(0,r),q + Vector2(-r*0.2,r*0.2),q + Vector2(-r,0),q + Vector2(-r*0.2,-r*0.2)]),Color(1,1,0.8,0.9*t))
	# Winning slice: pulsing light over the confirmed prize.
	if win_index >= 0 and win_index < starts.size():
		var pulse := 0.5 + 0.5*sin(win_age*9.0)
		var poly := PackedVector2Array([c])
		var steps := maxi(4,int(spans[win_index]/0.05))
		for k in range(steps+1):
			poly.append(c + Vector2.from_angle(starts[win_index] + spans[win_index]*k/steps)*inner)
		bulbs.draw_colored_polygon(poly,Color(1,0.97,0.75,0.16 + 0.22*pulse))
		bulbs.draw_arc(c,inner - 3.0,starts[win_index],starts[win_index] + spans[win_index],24,Color(1,0.95,0.6,0.7 + 0.3*pulse),6.0,true)
