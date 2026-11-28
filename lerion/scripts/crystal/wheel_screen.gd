extends CanvasLayer
## Magic Wheel screen shown above the kingdom. Presentation only: it asks for a spin through
## `spin_requested`, then animates the receipt it is given. It never decides or grants a prize.
signal spin_requested
signal closed(receipt: Dictionary)
signal later_requested

const Crystal := preload("res://scripts/crystal/super_crystal_service.gd")
const Wheel := preload("res://scripts/crystal/magic_wheel.gd")
const Fx := preload("res://scripts/crystal/prize_fx.gd")
const ResultArt := preload("res://scripts/crystal/result_art.gd")
const ChestStage := preload("res://scripts/crystal/chest_stage.gd")
const ENERGY := preload("res://assets/crystal/energy.svg")
const CHEST := preload("res://assets/crystal/chest.svg")
const GOLD := Color("#ffd06a")
const CREAM := Color("#fff3d6")
const NAVY := Color("#0f2552")
enum Phase { HIDDEN, INTRO, READY, SPINNING, RESULT, OUTRO }
const SPIN_ACCEL := 0.55
const SPIN_DECEL := 3.75

var phase := Phase.HIDDEN
var hud: CanvasLayer
var sounds: Node
var reduced := false
var screen := Control.new()
var backdrop := ColorRect.new()
var rays := Control.new()
var title: Label
var subtitle: Label
var wheel: Wheel
var pointer := Control.new()
var odds := GridContainer.new()
var odds_note: Label
var spin_button: Button
var later_button: Button
var result_panel := PanelContainer.new()
var result_icon := ResultArt.new()
var result_stage: ChestStage = ChestStage.new()
var icon_box := Control.new()
var sheen := Control.new()
var spin_power := 0.0
var last_rotation := 0.0
var pointer_settle := 0.0
var shock := -1.0
var shake_tween: Tween
var bounce_tween: Tween
var result_title: Label
var result_detail: Label
var continue_button: Button
var open_now_button: Button
var open_now := false
var flash := ColorRect.new()
var fx: Fx
var receipt: Dictionary = {}
var spin_from := 0.0
var spin_to := 0.0
var spin_tween: Tween
var show_tween: Tween
var icon_tween: Tween
var last_slice := -1
var last_tick := 0.0
var pointer_kick := 0.0
var ray_age := 0.0
var ray_power := 0.35
var idle_drift := true


func setup(owner_hud: CanvasLayer, audio: Node) -> void:
	hud = owner_hud
	sounds = audio
	layer = 3
	add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_STOP
	screen.gui_input.connect(_screen_input)
	screen.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.03,0.07,0.17,0.86)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rays.draw.connect(_draw_rays)
	screen.add_child(rays)
	title = hud._label("Ruleta Magică",46,GOLD)
	title.add_theme_constant_override("outline_size",10)
	title.add_theme_color_override("font_outline_color",Color("#1a2f66"))
	screen.add_child(title)
	subtitle = hud._label("Super Cristalul s-a încărcat!",23,Color("#bfe9ff"))
	screen.add_child(subtitle)
	wheel = Wheel.new()
	screen.add_child(wheel)
	# Fixed (non-rotating) glass highlight over the wheel.
	sheen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheen.draw.connect(_draw_sheen)
	screen.add_child(sheen)
	pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pointer.draw.connect(_draw_pointer)
	screen.add_child(pointer)
	odds.columns = 2
	odds.add_theme_constant_override("h_separation",10)
	odds.add_theme_constant_override("v_separation",6)
	odds.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(odds)
	for item: Dictionary in Crystal.prizes():
		var chip: Label = hud._label("%s  ·  %s" % [item.label,_percent(Crystal.probability(item.id))],19,CREAM)
		chip.add_theme_stylebox_override("normal",hud._style(Color(0.06,0.16,0.36,0.92),Color("#6f9ad8"),14))
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		odds.add_child(chip)
	odds_note = hud._label("Mărimea fiecărei felii este egală cu șansa premiului.",17,Color("#a9c6e8"))
	odds_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	screen.add_child(odds_note)
	spin_button = hud._button("ÎNVÂRTE",_on_spin,true)
	spin_button.accessibility_name = "Învârte Ruleta Magică"
	spin_button.custom_minimum_size.y = 84
	spin_button.add_theme_font_size_override("font_size",34)
	screen.add_child(spin_button)
	later_button = hud._button("Mai târziu",_on_later)
	screen.add_child(later_button)
	_make_result()
	fx = Fx.new()
	screen.add_child(fx)
	fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(1,0.96,0.8,0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(flash)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_viewport().size_changed.connect(_layout)
	visible = false
	set_process(false)


func _make_result() -> void:
	result_panel.add_theme_stylebox_override("panel",hud._style(Color("#123063"),GOLD,26))
	result_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	screen.add_child(result_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation",10)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	result_panel.add_child(col)
	result_title = hud._label("Ai câștigat!",30,GOLD)
	col.add_child(result_title)
	var holder := CenterContainer.new()
	holder.custom_minimum_size = Vector2(170,170)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(holder)
	icon_box.custom_minimum_size = Vector2(170,160)
	icon_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(icon_box)
	result_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_box.add_child(result_icon)
	result_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Won chests are the same 3D chests the player opens next.
	icon_box.add_child(result_stage)
	result_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_stage.hide()
	result_detail = hud._label("",24,CREAM)
	result_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(result_detail)
	open_now_button = hud._button("Deschide acum",func() -> void:
		open_now = true
		_on_continue(),true)
	open_now_button.custom_minimum_size.y = 72
	col.add_child(open_now_button)
	open_now_button.hide()
	continue_button = hud._button("Continuă",_on_continue)
	continue_button.custom_minimum_size.y = 64
	col.add_child(continue_button)
	result_panel.hide()


static func _percent(value: float) -> String:
	var whole := value*100.0
	return ("%d%%" % roundi(whole)) if is_equal_approx(whole,roundf(whole)) else ("%.1f%%" % whole)


func is_open() -> bool:
	return phase != Phase.HIDDEN


## Shows the wheel ready to spin, after the camera has moved close to the crystal.
func open(delay := 0.45) -> void:
	_reset()
	phase = Phase.INTRO
	subtitle.text = "Super Cristalul s-a încărcat!"
	visible = true
	_layout()
	screen.modulate.a = 0.0
	wheel.scale = Vector2.ONE*0.6
	show_tween = create_tween()
	show_tween.tween_interval(0.0 if reduced else delay)
	show_tween.tween_property(screen,"modulate:a",1.0,0.25)
	show_tween.parallel().tween_property(wheel,"scale",Vector2.ONE,0.45 if not reduced else 0.01).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	show_tween.tween_callback(func() -> void:
		phase = Phase.READY
		spin_button.disabled = false
		later_button.disabled = false)
	set_process(true)


## Restores a confirmed but unseen spin after a restart. Nothing is granted here.
func show_recovered(confirmed: Dictionary) -> void:
	_reset()
	receipt = confirmed.duplicate()
	visible = true
	_layout()
	screen.modulate.a = 1.0
	var index := maxi(0,Crystal.prize_index(str(receipt.prize)))
	wheel.rotation = wheel.rotation_for(index,0.0,0,0.5)
	subtitle.text = "Premiul a fost confirmat înainte de închidere."
	_show_result(true)


func _reset() -> void:
	for tween: Tween in [spin_tween,show_tween,icon_tween]:
		if tween:
			tween.kill()
	receipt = {}
	spin_power = 0.0
	pointer_settle = 0.0
	shock = -1.0
	wheel.win_index = -1
	wheel.scale = Vector2.ONE
	screen.position = Vector2.ZERO
	open_now = false
	open_now_button.hide()
	fx.clear()
	result_panel.hide()
	flash.color.a = 0.0
	spin_button.show()
	spin_button.disabled = true
	spin_button.mouse_filter = Control.MOUSE_FILTER_STOP
	spin_button.text = "ÎNVÂRTE"
	later_button.show()
	later_button.disabled = true
	odds.show()
	odds_note.show()
	ray_power = 0.35
	idle_drift = true
	wheel.spinning = false
	pointer_kick = 0.0
	screen.modulate.a = 1.0
	screen.scale = Vector2.ONE


func _on_spin() -> void:
	# The button is disabled before the request, so a double tap cannot ask twice.
	if phase != Phase.READY or spin_button.disabled:
		return
	spin_button.disabled = true
	later_button.disabled = true
	hud.spark_screen(spin_button.get_global_rect().get_center(),GOLD)
	spin_requested.emit()


func _on_later() -> void:
	if phase != Phase.READY:
		return
	later_requested.emit()
	_hide()


## Receives the prize already saved by the game, then animates towards exactly that slice.
func play(confirmed: Dictionary) -> void:
	if phase != Phase.READY:
		return
	receipt = confirmed.duplicate()
	phase = Phase.SPINNING
	idle_drift = false
	later_button.hide()
	spin_button.text = "Atinge pentru a grăbi"
	spin_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wheel.spinning = true
	var index := maxi(0,Crystal.prize_index(str(receipt.prize)))
	spin_from = wheel.rotation
	spin_to = wheel.rotation_for(index,spin_from,5,randf())
	last_slice = wheel.slice_under_pointer(spin_from)
	last_rotation = wheel.rotation
	if sounds:
		sounds.play_event("wheel_spin")
	spin_tween = create_tween()
	spin_tween.tween_method(_spin_step,0.0,SPIN_ACCEL + SPIN_DECEL,SPIN_ACCEL + SPIN_DECEL)
	spin_tween.tween_callback(_land)


## Refusal (for example a failed save) returns to the ready state without any prize.
func refuse(text: String) -> void:
	subtitle.text = text
	phase = Phase.READY
	spin_button.disabled = false
	later_button.disabled = false


## Smooth acceleration followed by a long cubic deceleration with continuous velocity.
static func spin_curve(time: float, total: float) -> float:
	var top_speed := total/(SPIN_ACCEL*0.5 + SPIN_DECEL/3.0)
	if time <= SPIN_ACCEL:
		return 0.5*top_speed/SPIN_ACCEL*time*time
	var launched := 0.5*top_speed*SPIN_ACCEL
	var u := clampf((time - SPIN_ACCEL)/SPIN_DECEL,0.0,1.0)
	return launched + (total - launched)*(1.0 - pow(1.0 - u,3))


func _spin_step(time: float) -> void:
	wheel.rotation = spin_from + spin_curve(time,spin_to - spin_from)
	spin_power = lerpf(spin_power,clampf(absf(wheel.rotation - last_rotation)/0.3,0.0,1.0),0.35)
	last_rotation = wheel.rotation
	var slice := wheel.slice_under_pointer(wheel.rotation)
	if slice != last_slice:
		last_slice = slice
		pointer_kick = 1.0
		var now := Time.get_ticks_msec()/1000.0
		if sounds and now - last_tick > 0.06:
			last_tick = now
			sounds.play_event("wheel_tick")


func _land() -> void:
	wheel.rotation = spin_to
	wheel.spinning = false
	spin_power = 0.0
	wheel.win_index = wheel.slice_under_pointer(wheel.rotation)
	wheel.win_age = 0.0
	pointer_settle = 1.0
	pointer_kick = 1.0
	if sounds:
		sounds.play_event("wheel_stop")
	if not reduced:
		# Subtle stop: a ring of light leaves the rim and the wheel settles with a small bounce.
		var wave := create_tween()
		wave.tween_method(func(v: float) -> void: shock = v,0.0,1.0,0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		wave.tween_callback(func() -> void: shock = -1.0)
		if bounce_tween:
			bounce_tween.kill()
		wheel.pivot_offset = wheel.size*0.5
		bounce_tween = create_tween()
		bounce_tween.tween_property(wheel,"scale",Vector2.ONE*1.035,0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		bounce_tween.tween_property(wheel,"scale",Vector2.ONE,0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_show_result(false)


func _screen_input(event: InputEvent) -> void:
	var tapped: bool = (event is InputEventScreenTouch or event is InputEventMouseButton) and event.pressed
	if tapped and phase == Phase.SPINNING and spin_tween and spin_tween.is_running():
		# Fast-forward only changes the presentation; the receipt is already saved.
		spin_tween.kill()
		_land()


func _show_result(recovered: bool) -> void:
	phase = Phase.RESULT
	var kind := str(receipt.get("kind","energy"))
	var chest := str(receipt.get("chest",""))
	var style := "energy" if kind == "energy" else chest
	spin_button.hide()
	later_button.hide()
	odds.hide()
	odds_note.hide()
	result_title.text = "Premiu confirmat" if recovered else ("SUPER! Ai câștigat" if style == "gold" else "Ai câștigat!")
	result_detail.text = Crystal.describe(receipt)
	if kind == "energy":
		result_detail.text += "\nEnergia poate depăși 100. Regenerarea se reia sub 100."
	else:
		result_detail.text += "\n" + str(Crystal.config().chests.get(chest,{}).get("hint","")) + "\nCuferele se păstrează în Sac."
	if kind == "energy":
		result_icon.show()
		result_stage.hide()
		result_icon.show_texture(ENERGY,Color("#fff59a"))
	else:
		result_icon.show_chest(chest)
		result_icon.hide()
		result_stage.reduced = reduced
		result_stage.show()
		result_stage.show_kind(chest)
	result_panel.show()
	open_now_button.visible = kind == "chest" and not recovered
	open_now_button.disabled = false
	_layout()
	continue_button.disabled = false
	if sounds:
		sounds.play_event("win_energy" if kind == "energy" else "win_chest_" + chest)
	_pop_panel(style)
	_animate_icon(style)
	var origin := result_panel.position + Vector2(result_panel.size.x*0.5,result_panel.size.y*0.36)
	fx.reduced = reduced
	fx.play(origin,style)
	if style == "gold" and not reduced:
		flash.color.a = 0.8
		var glow := create_tween()
		glow.tween_property(flash,"color:a",0.0,0.6)
		ray_power = 1.8
		# The gold chest gets a second, wider burst and a short shake so it clearly outshines the rest.
		var again := create_tween()
		again.tween_interval(0.2)
		again.tween_callback(func() -> void: fx.play(origin + Vector2(0,-60),"gold"))
		_shake(9.0)
	elif style == "silver":
		ray_power = 0.6


func _shake(amount: float) -> void:
	if shake_tween:
		shake_tween.kill()
	shake_tween = create_tween()
	for i in range(6):
		shake_tween.tween_property(screen,"position",Vector2(randf_range(-1,1),randf_range(-1,1))*amount*(1.0 - i/6.0),0.04)
	shake_tween.tween_property(screen,"position",Vector2.ZERO,0.04)


## The result card pops in with a small overshoot instead of appearing flat.
func _pop_panel(style: String) -> void:
	if reduced:
		return
	result_panel.pivot_offset = result_panel.size*0.5
	result_panel.scale = Vector2.ONE*0.62
	var pop := create_tween()
	pop.tween_property(result_panel,"scale",Vector2.ONE*(1.08 if style == "gold" else 1.04),0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pop.tween_property(result_panel,"scale",Vector2.ONE,0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _animate_icon(style: String) -> void:
	if icon_tween:
		icon_tween.kill()
	icon_box.pivot_offset = icon_box.custom_minimum_size*0.5
	icon_box.modulate = Color.WHITE
	icon_box.rotation = 0.0
	icon_box.position.y = 0.0
	icon_tween = create_tween()
	if reduced:
		icon_box.scale = Vector2.ONE
		return
	match style:
		"energy":
			icon_box.scale = Vector2.ZERO
			icon_tween.tween_property(icon_box,"scale",Vector2.ONE*1.25,0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			icon_tween.tween_property(icon_box,"scale",Vector2.ONE,0.18)
			icon_tween.tween_property(result_icon,"modulate",Color("#ffffff"),0.12)
			icon_tween.tween_property(result_icon,"modulate",Color("#fff59a"),0.25)
			var amount := int(receipt.get("amount",0))
			icon_tween.parallel().tween_method(func(v: int) -> void: result_detail.text = "+%d energie\nEnergia poate depăși 100. Regenerarea se reia sub 100." % v,0,amount,0.6)
		"wood":
			icon_box.scale = Vector2.ONE
			icon_box.position.y = -160.0
			icon_tween.tween_property(icon_box,"position:y",0.0,0.55).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			icon_tween.tween_property(icon_box,"scale",Vector2(1.18,0.84),0.08)
			icon_tween.tween_property(icon_box,"scale",Vector2.ONE,0.16).set_trans(Tween.TRANS_BACK)
		"silver":
			icon_box.scale = Vector2.ZERO
			icon_tween.tween_property(icon_box,"scale",Vector2.ONE*1.15,0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			for k in range(3):
				icon_tween.tween_property(icon_box,"rotation",0.22,0.07)
				icon_tween.tween_property(icon_box,"rotation",-0.22,0.07)
			icon_tween.tween_property(icon_box,"rotation",0.0,0.07)
			icon_tween.tween_property(icon_box,"scale",Vector2.ONE,0.15)
		_:
			icon_box.scale = Vector2.ZERO
			icon_tween.tween_property(icon_box,"scale",Vector2.ONE*1.5,0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			icon_tween.tween_property(icon_box,"scale",Vector2.ONE*1.15,0.25)
			icon_tween.tween_property(icon_box,"rotation",0.08,0.2)
			icon_tween.tween_property(icon_box,"rotation",-0.08,0.2)
			icon_tween.tween_property(icon_box,"rotation",0.0,0.2)


func _on_continue() -> void:
	if phase != Phase.RESULT:
		return
	continue_button.disabled = true
	open_now_button.disabled = true
	var shown := receipt.duplicate()
	_hide()
	closed.emit(shown)


func _hide() -> void:
	phase = Phase.OUTRO
	if show_tween:
		show_tween.kill()
	show_tween = create_tween()
	show_tween.tween_property(screen,"modulate:a",0.0,0.01 if reduced else 0.3)
	show_tween.tween_callback(func() -> void:
		visible = false
		phase = Phase.HIDDEN
		fx.clear()
		set_process(false))


func _process(delta: float) -> void:
	ray_age += delta
	if idle_drift and phase in [Phase.INTRO,Phase.READY]:
		wheel.rotation += delta*0.12
	if pointer_kick > 0.0 or pointer_settle > 0.0:
		pointer_kick = maxf(0.0,pointer_kick - delta*7.0)
		pointer_settle = maxf(0.0,pointer_settle - delta*1.7)
		pointer.queue_redraw()
	var floor_power := 0.35 + 0.8*spin_power if phase == Phase.SPINNING else 0.35
	ray_power = lerpf(ray_power,floor_power,delta*(6.0 if phase == Phase.SPINNING else 0.8))
	if not reduced:
		rays.queue_redraw()


func _draw_rays() -> void:
	if wheel == null or not visible:
		return
	var c := wheel.position + wheel.size*0.5 - rays.position
	var reach := maxf(rays.size.x,rays.size.y)
	var count := 14
	for i in range(count):
		var a := ray_age*0.18 + TAU*i/count
		var w := 0.09
		var tint := Color(1.0,0.85,0.45,0.10*ray_power) if i % 2 == 0 else Color(0.5,0.8,1.0,0.08*ray_power)
		rays.draw_colored_polygon(PackedVector2Array([c,c + Vector2.from_angle(a - w)*reach,c + Vector2.from_angle(a + w)*reach]),tint)
	var pulse := 0.04*sin(ray_age*12.0)*spin_power
	rays.draw_circle(c,wheel.radius*(1.08 + pulse),Color(0.45,0.75,1.0,0.12 + 0.1*ray_power))
	rays.draw_arc(c,wheel.radius*(1.04 + pulse),0.0,TAU,64,Color(1.0,0.9,0.55,0.12 + 0.3*spin_power),6.0,true)
	if shock >= 0.0:
		rays.draw_arc(c,wheel.radius*lerpf(1.0,1.6,shock),0.0,TAU,72,Color(1.0,0.95,0.7,0.85*(1.0 - shock)),10.0*(1.0 - shock) + 2.0,true)


func _draw_sheen() -> void:
	if wheel == null:
		return
	var c := sheen.size*0.5
	var r := wheel.radius
	# Curved window reflection upper-left, a thin rim light lower-right and a specular dot.
	sheen.draw_arc(c,r*0.9,deg_to_rad(200.0),deg_to_rad(262.0),24,Color(1,1,1,0.22),12.0,true)
	sheen.draw_arc(c,r*0.8,deg_to_rad(206.0),deg_to_rad(246.0),16,Color(1,1,1,0.12),8.0,true)
	sheen.draw_arc(c,r*0.97,deg_to_rad(20.0),deg_to_rad(60.0),16,Color(1,0.95,0.7,0.35),5.0,true)
	sheen.draw_circle(c + Vector2.from_angle(deg_to_rad(228.0))*r*0.9,5.0,Color(1,1,1,0.55))


func _draw_pointer() -> void:
	var w := pointer.size.x
	var tilt := -0.35*pointer_kick + 0.2*pointer_settle*sin(ray_age*30.0)
	pointer.draw_set_transform(Vector2(w*0.5,10),tilt,Vector2.ONE*1.2)
	pointer.draw_circle(Vector2(0,26),38.0,Color(1.0,0.88,0.45,0.1 + 0.25*maxf(spin_power,pointer_settle)))
	var shape := PackedVector2Array([Vector2(-30,-4),Vector2(30,-4),Vector2(0,58)])
	pointer.draw_colored_polygon(PackedVector2Array([Vector2(-34,-8),Vector2(34,-8),Vector2(0,64)]),Color("#8a5a16"))
	pointer.draw_colored_polygon(shape,GOLD)
	pointer.draw_colored_polygon(PackedVector2Array([Vector2(-30,-4),Vector2(0,-4),Vector2(0,58)]),Color("#ffe9a6"))
	pointer.draw_circle(Vector2(0,8),12,Color("#1f6fd0"))
	pointer.draw_circle(Vector2(-3,5),4,Color("#c9f4ff"))
	pointer.draw_set_transform(Vector2.ZERO,0,Vector2.ONE)


func _layout() -> void:
	if not is_inside_tree():
		return
	var view := get_viewport().get_visible_rect().size
	var lo := Vector2(16,16)
	var hi := view - Vector2(16,18)
	if OS.has_feature("android"):
		var safe := DisplayServer.get_display_safe_area()
		var inverse := get_viewport().get_screen_transform().affine_inverse()
		lo = lo.max(inverse*Vector2(safe.position) + Vector2(12,12))
		hi = hi.min(inverse*Vector2(safe.end) - Vector2(12,12))
	var width := minf(hi.x - lo.x,720.0)
	var left := (hi.x + lo.x - width)*0.5
	rays.position = Vector2.ZERO
	rays.size = view
	var available := hi.y - lo.y
	var diameter := minf(width - 40.0,minf(620.0,available*0.5))
	# Centre the title, wheel and odds in the space above the buttons.
	var block := 124.0 + diameter + 18.0 + odds.get_combined_minimum_size().y + 40.0
	var top_y := lo.y + maxf(0.0,(available - 96.0 - block)*0.45)
	title.position = Vector2(left,top_y + 10)
	title.size = Vector2(width,60)
	subtitle.position = Vector2(left,top_y + 72)
	subtitle.size = Vector2(width,34)
	var wheel_top := top_y + 124
	wheel.size = Vector2.ONE*diameter
	sheen.size = wheel.size
	wheel.position = Vector2(left + (width - diameter)*0.5,wheel_top)
	sheen.position = wheel.position
	pointer.size = Vector2(80,80)
	pointer.position = Vector2(left + width*0.5 - 40,wheel_top - 26)
	var below := wheel_top + diameter + 18
	odds.position = Vector2(left + 8,below)
	odds.size = Vector2(width - 16,0)
	odds.reset_size()
	odds.size.x = width - 16
	odds_note.position = Vector2(left,below + odds.get_combined_minimum_size().y + 6)
	odds_note.size = Vector2(width,0)
	var buttons_y := hi.y - 84
	later_button.size = Vector2(170,72)
	later_button.position = Vector2(left,buttons_y + 6)
	spin_button.position = Vector2(left + 182,buttons_y)
	spin_button.size = Vector2(width - 182,84)
	var panel_width := minf(width - 40,520.0)
	# Give the wrapped prize text a real width before measuring; otherwise its minimum height explodes.
	result_detail.custom_minimum_size.x = panel_width - 48.0
	result_panel.size = Vector2(panel_width,0)
	result_panel.reset_size()
	result_panel.size.x = panel_width
	result_panel.position = Vector2(left + (width - panel_width)*0.5,wheel_top + diameter*0.5 - result_panel.get_combined_minimum_size().y*0.5)
