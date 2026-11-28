extends CanvasLayer
## Chest opening screen. Presentation only: it asks for an opening through `open_requested`, then
## animates the receipt it is given. The cards were already drawn and saved by the game; skipping
## or closing at any moment can neither lose nor repeat them.
signal open_requested(kind: String)
signal closed(receipt: Dictionary)

const Cards := preload("res://scripts/economy/card_service.gd")
const Crystal := preload("res://scripts/crystal/super_crystal_service.gd")
const CardView := preload("res://scripts/crystal/card_view.gd")
const Fx := preload("res://scripts/crystal/prize_fx.gd")
const ChestArt := preload("res://scripts/crystal/chest_art.gd")
const RAY_TINT := {"wood": Color(1.0,0.8,0.5), "silver": Color(0.75,0.9,1.0), "gold": Color(1.0,0.86,0.4)}
const READY_RAYS := {"wood": 0.2, "silver": 0.4, "gold": 0.75}
const GOLD := Color("#ffd06a")
const CREAM := Color("#fff3d6")
const NAVY := Color("#0f2552")
const TINT := {"wood": Color("#b9763a"), "silver": Color("#cfdde9"), "gold": Color("#ffc93a")}
const DARK := {"wood": Color("#6e3d17"), "silver": Color("#7d8fa3"), "gold": Color("#b67b12")}
const FX_STYLE := {"common": "wood", "uncommon": "silver", "rare": "gold"}
enum Phase { HIDDEN, READY, OPENING, REVEAL, DONE, OUTRO }
const FAST := 2.5

var phase := Phase.HIDDEN
var hud: CanvasLayer
var sounds: Node
var reduced := false
var kind := "wood"
var owned := 0
var receipt: Dictionary = {}
var screen := Control.new()
var rays := Control.new()
var title: Label
var subtitle: Label
var odds_label: Label
var summary: Label
var hint: Label
var chest := Control.new()
var card_layer := Control.new()
var open_button: Button
var later_button: Button
var speed_button: Button
var skip_button: Button
var continue_button: Button
var fx: Fx
var flash := ColorRect.new()
var cards: Array[CardView] = []
var slots: Array[Vector2] = []
var lid := 0.0
var glow := 0.0
var wobble := 0.0
var revealed := 0
var speed := 1.0
var ray_age := 0.0
var ray_power := 0.0
var seq: Tween
var show_tween: Tween
var flips: Array[Tween] = []
var chest_rest_y := 0.0
var shake_tween: Tween


func setup(owner_hud: CanvasLayer, audio: Node) -> void:
	hud = owner_hud
	sounds = audio
	layer = 3
	add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_STOP
	screen.gui_input.connect(_screen_input)
	var dim := ColorRect.new()
	dim.color = Color(0.03,0.06,0.16,0.9)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rays.draw.connect(_draw_rays)
	screen.add_child(rays)
	title = hud._label("",44,GOLD)
	title.add_theme_constant_override("outline_size",10)
	title.add_theme_color_override("font_outline_color",Color("#1a2f66"))
	screen.add_child(title)
	subtitle = hud._label("",22,Color("#bfe9ff"))
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	screen.add_child(subtitle)
	chest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chest.custom_minimum_size = Vector2(300,260)
	chest.size = Vector2(300,260)
	chest.pivot_offset = Vector2(150,200)
	chest.draw.connect(_draw_chest)
	screen.add_child(chest)
	card_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(card_layer)
	odds_label = hud._label("",19,Color("#a9c6e8"))
	odds_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	screen.add_child(odds_label)
	summary = hud._label("",26,GOLD)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	screen.add_child(summary)
	hint = hud._label("Atinge ecranul pentru a dezvălui următoarea carte",18,Color("#a9c6e8"))
	screen.add_child(hint)
	open_button = hud._button("DESCHIDE",_on_open,true)
	open_button.accessibility_name = "Deschide cufărul"
	open_button.custom_minimum_size.y = 84
	open_button.add_theme_font_size_override("font_size",34)
	screen.add_child(open_button)
	later_button = hud._button("Mai târziu",_on_later)
	screen.add_child(later_button)
	speed_button = hud._button("Accelerează",_on_speed)
	screen.add_child(speed_button)
	skip_button = hud._button("Sari",_on_skip)
	screen.add_child(skip_button)
	continue_button = hud._button("Continuă",_on_continue,true)
	continue_button.custom_minimum_size.y = 84
	continue_button.add_theme_font_size_override("font_size",32)
	screen.add_child(continue_button)
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


func is_open() -> bool:
	return phase != Phase.HIDDEN


# ---- Entry points -----------------------------------------------------------------------------

## Shows the chest, ready to be opened. `count` is the number of such chests in the inventory.
func open(chest_kind: String, count: int) -> void:
	_reset()
	kind = chest_kind
	owned = count
	phase = Phase.READY
	title.text = Crystal.chest_name(kind)
	subtitle.text = "Ai %d %s. Deschide unul acum." % [count,"cufăr de acest tip" if count == 1 else "cufere de acest tip"]
	var parts := PackedStringArray()
	for item: Dictionary in Cards.rarities():
		var chance := Cards.rarity_probability(kind,item.id)
		if chance > 0.0:
			parts.append("%s %d%%" % [item.name,roundi(chance*100.0)])
	odds_label.text = "%d cărți · %s\n%s" % [Cards.chest_size(kind)," · ".join(parts),str(Crystal.config().chests.get(kind,{}).get("hint",""))]
	open_button.disabled = count < 1
	later_button.disabled = false
	_present()
	_drop_in()


## Restores a confirmed but unseen opening after a restart. Nothing is granted here.
func show_recovered(confirmed: Dictionary) -> void:
	_reset()
	receipt = confirmed.duplicate(true)
	kind = str(receipt.chest)
	title.text = Crystal.chest_name(kind)
	subtitle.text = "Cărțile au fost confirmate înainte de închidere."
	_build_cards()
	for view in cards:
		view.position = slots[view.get_index()]
		view.scale = Vector2.ONE
		view.modulate.a = 1.0
	for i in range(cards.size()):
		_apply_face(i)
	revealed = cards.size()
	lid = 1.0
	_present()
	_finish()


## Receives the contents already saved by the game, then animates exactly those cards.
func play(confirmed: Dictionary) -> void:
	if phase != Phase.READY:
		return
	receipt = confirmed.duplicate(true)
	phase = Phase.OPENING
	_build_cards()
	_buttons()
	odds_label.hide()
	subtitle.text = ""
	hint.text = "Se deschide…"
	var gap := 0.0 if reduced else 1.0
	seq = create_tween()
	seq.set_speed_scale(speed)
	if not reduced:
		seq.tween_method(_shake,0.0,1.0,0.6)
	seq.tween_callback(func() -> void:
		if sounds:
			sounds.upgrade())
	seq.tween_method(func(t: float) -> void: lid = t; glow = t; chest.queue_redraw(),0.0,1.0,0.4 if not reduced else 0.01).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	seq.tween_callback(_burst)
	seq.tween_interval(0.25*gap)
	seq.tween_method(_deal,0.0,1.0,0.5 + 0.13*cards.size())
	seq.tween_callback(_start_reveal)


## Refusal (for example a failed save) returns to the ready state without opening anything.
func refuse(text: String) -> void:
	subtitle.text = text
	phase = Phase.READY
	open_button.disabled = false
	later_button.disabled = false


# ---- Presentation -----------------------------------------------------------------------------

func _reset() -> void:
	for tween: Tween in [seq,show_tween]:
		if tween:
			tween.kill()
	for tween in flips:
		if tween:
			tween.kill()
	flips.clear()
	for view in cards:
		card_layer.remove_child(view)
		view.queue_free()
	cards.clear()
	slots.clear()
	receipt = {}
	revealed = 0
	lid = 0.0
	glow = 0.0
	wobble = 0.0
	speed = 1.0
	ray_power = 0.0
	chest.rotation = 0.0
	chest.scale = Vector2.ONE
	chest.modulate.a = 1.0
	chest.show()
	fx.clear()
	flash.color.a = 0.0
	summary.text = ""
	hint.text = ""
	odds_label.show()
	speed_button.text = "Accelerează"
	screen.modulate.a = 1.0
	_buttons()


func _present() -> void:
	visible = true
	_layout()
	_buttons()
	screen.modulate.a = 0.0
	show_tween = create_tween()
	show_tween.tween_property(screen,"modulate:a",1.0,0.01 if reduced else 0.25)
	chest.queue_redraw()
	set_process(true)


## The chest drops in with a squash and a ring of dust, tinted by its tier.
func _drop_in() -> void:
	if reduced:
		return
	chest.position.y = chest_rest_y - 300.0
	chest.scale = Vector2(0.9,1.1)
	var drop := create_tween()
	drop.tween_property(chest,"position:y",chest_rest_y,0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	drop.parallel().tween_property(chest,"scale",Vector2.ONE,0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	drop.tween_callback(func() -> void:
		fx.reduced = reduced
		fx.play(_chest_center() + Vector2(0,90),kind)
		ray_power = READY_RAYS[kind]
		if sounds:
			sounds.play_event("landing"))


func _buttons() -> void:
	open_button.visible = phase == Phase.READY
	later_button.visible = phase == Phase.READY
	speed_button.visible = phase == Phase.OPENING or phase == Phase.REVEAL
	skip_button.visible = phase == Phase.OPENING or phase == Phase.REVEAL
	continue_button.visible = phase == Phase.DONE
	hint.visible = phase == Phase.REVEAL
	chest.visible = phase != Phase.DONE and phase != Phase.REVEAL
	if phase == Phase.DONE:
		continue_button.disabled = false


func _build_cards() -> void:
	var ids: Array = receipt.cards
	_layout()
	for i in range(ids.size()):
		var view := CardView.new()
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		view.size = _card_size()
		view.pivot_offset = view.size*0.5
		view.show_card(str(ids[i]),false)
		view.position = _chest_center() - view.size*0.5
		view.scale = Vector2.ONE*0.25
		view.modulate.a = 0.0
		card_layer.add_child(view)
		cards.append(view)


func _apply_face(i: int) -> void:
	var view := cards[i]
	view.flip_to(true)
	if bool(receipt.new[i]):
		view.set_badge("NOUĂ!",Color("#ff5d73"))
	else:
		view.set_badge("×%d" % int(receipt.counts[i]),Color("#3b82f6"))


func _shake(t: float) -> void:
	wobble = t
	chest.rotation = sin(t*TAU*4.0)*0.07*(1.0 - 0.3*t)
	var squash := 0.04*sin(t*TAU*2.0)
	chest.scale = Vector2(1.0 + squash,1.0 - squash)
	glow = 0.35*t


func _burst() -> void:
	chest.rotation = 0.0
	chest.scale = Vector2.ONE
	ray_power = {"wood": 0.7, "silver": 1.0, "gold": 1.6}[kind]
	if sounds:
		sounds.play_event("chest_open")
	fx.reduced = reduced
	var top := _chest_center() - Vector2(0,40)
	fx.play(top,kind)
	if kind == "gold" and not reduced:
		# Second, wider burst a moment later and a short screen shake: the gold chest feels bigger.
		var again := create_tween()
		again.tween_interval(0.18)
		again.tween_callback(func() -> void: fx.play(top + Vector2(0,-30),"gold"))
		_shake_screen(10.0)
	elif kind == "silver" and not reduced:
		_shake_screen(4.0)
	if not reduced:
		flash.color.a = {"wood": 0.2, "silver": 0.35, "gold": 0.6}[kind]
		var fade := create_tween()
		fade.tween_property(flash,"color:a",0.0,0.45)


func _shake_screen(amount: float) -> void:
	if shake_tween:
		shake_tween.kill()
	shake_tween = create_tween()
	for i in range(6):
		shake_tween.tween_property(screen,"position",Vector2(randf_range(-1,1),randf_range(-1,1))*amount*(1.0 - i/6.0),0.04)
	shake_tween.tween_property(screen,"position",Vector2.ZERO,0.04)


func _deal(t: float) -> void:
	var n := cards.size()
	chest.modulate.a = 1.0 - smoothstep(0.0,0.5,t)
	for i in range(n):
		var start := float(i)/(n + 2.0)
		var p := clampf((t - start)/(1.0 - start*0.6),0.0,1.0)
		var e := 1.0 - pow(1.0 - p,3)
		var view := cards[i]
		var from := _chest_center() - view.size*0.5
		view.position = from.lerp(slots[i],e) + Vector2(0,-70.0*sin(PI*e))
		view.scale = Vector2.ONE*lerpf(0.25,1.0,e)
		view.modulate.a = clampf(p*4.0,0.0,1.0)


func _start_reveal() -> void:
	phase = Phase.REVEAL
	chest.hide()
	_buttons()
	hint.text = "Atinge ecranul pentru a dezvălui următoarea carte"
	_schedule(0.45)


func _schedule(first_delay: float) -> void:
	if seq:
		seq.kill()
	if revealed >= cards.size():
		_finish()
		return
	seq = create_tween()
	seq.set_speed_scale(speed)
	seq.tween_interval(first_delay)
	for i in range(revealed,cards.size()):
		seq.tween_callback(_reveal_next)
		seq.tween_interval(0.95)
	seq.tween_callback(_finish)


func _reveal_next() -> void:
	if revealed >= cards.size() or phase != Phase.REVEAL:
		return
	var i := revealed
	revealed += 1
	var view := cards[i]
	if reduced:
		_apply_face(i)
		_reveal_effects(i)
		return
	var flip := create_tween()
	flip.set_speed_scale(speed)
	flips.append(flip)
	flip.tween_property(view,"scale:x",0.0,0.12).set_trans(Tween.TRANS_SINE)
	flip.tween_callback(func() -> void: _apply_face(i))
	flip.tween_property(view,"scale:x",1.08,0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	flip.tween_property(view,"scale",Vector2.ONE,0.1)
	_reveal_effects(i)


func _reveal_effects(i: int) -> void:
	var view := cards[i]
	var rarity_id: String = str(Cards.card(str(receipt.cards[i])).rarity)
	if sounds:
		sounds.play_event("card_reveal_rare" if rarity_id == "rare" else "card_reveal")
	fx.reduced = reduced
	fx.play(view.position + view.size*0.5,FX_STYLE.get(rarity_id,"wood"))
	if not reduced and rarity_id != "common":
		var glint := create_tween()
		glint.tween_method(view.set_shine,0.0,1.0,0.55).set_delay(0.2)
		glint.tween_callback(view.set_shine.bind(0.0))
		var halo := create_tween()
		halo.tween_method(view.set_aura,1.0 if rarity_id == "rare" else 0.6,0.0,1.2)
	if rarity_id == "rare" and not reduced:
		flash.color.a = 0.35
		var glint := create_tween()
		glint.tween_property(flash,"color:a",0.0,0.35)
		ray_power = 1.0


func _finish() -> void:
	if seq:
		seq.kill()
	for i in range(revealed,cards.size()):
		_apply_face(i)
	for view in cards:
		view.scale = Vector2.ONE
		view.modulate.a = 1.0
	revealed = cards.size()
	phase = Phase.DONE
	summary.text = Cards.describe(receipt)
	_buttons()
	_layout()


# ---- Input ------------------------------------------------------------------------------------

func _on_open() -> void:
	# Disabled before the request, so a double tap cannot ask twice.
	if phase != Phase.READY or open_button.disabled:
		return
	open_button.disabled = true
	later_button.disabled = true
	open_requested.emit(kind)


func _on_later() -> void:
	if phase == Phase.READY:
		_hide(false)


func _on_speed() -> void:
	speed = 1.0 if speed > 1.0 else FAST
	speed_button.text = "Viteză normală" if speed > 1.0 else "Accelerează"
	if seq and seq.is_valid():
		seq.set_speed_scale(speed)
	for tween in flips:
		if tween and tween.is_valid():
			tween.set_speed_scale(speed)


## Omit: show everything now. The receipt is already saved, so nothing can be lost.
func _on_skip() -> void:
	if phase != Phase.OPENING and phase != Phase.REVEAL:
		return
	if seq:
		seq.kill()
	for tween in flips:
		if tween:
			tween.kill()
	flips.clear()
	lid = 1.0
	glow = 1.0
	chest.hide()
	for i in range(cards.size()):
		cards[i].position = slots[i]
	phase = Phase.REVEAL
	_finish()


func _on_continue() -> void:
	if phase != Phase.DONE:
		return
	continue_button.disabled = true
	var shown := receipt.duplicate(true)
	_hide(true)
	closed.emit(shown)


func _screen_input(event: InputEvent) -> void:
	var tapped: bool = (event is InputEventScreenTouch or event is InputEventMouseButton) and event.pressed
	if tapped and phase == Phase.REVEAL:
		_reveal_next()
		_schedule(0.85)


func _hide(_acknowledged: bool) -> void:
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
	ray_power = maxf(0.0,ray_power - delta*0.5)
	if not reduced and (ray_power > 0.0 or phase == Phase.READY):
		rays.queue_redraw()
	if chest.visible and (phase == Phase.READY or phase == Phase.OPENING):
		# Idle shine, twinkles and a gentle bob while the chest waits.
		if phase == Phase.READY and not reduced:
			chest.position.y = chest_rest_y + 5.0*sin(ray_age*2.4)
		chest.queue_redraw()


# ---- Drawing ----------------------------------------------------------------------------------

func _draw_rays() -> void:
	if not visible:
		return
	var c := _chest_center() if phase < Phase.REVEAL else rays.size*0.5
	var reach := maxf(rays.size.x,rays.size.y)
	var power := maxf(READY_RAYS.get(kind,0.25) if phase == Phase.READY else 0.0,ray_power)
	var count := 12
	for i in range(count):
		var a := ray_age*0.2 + TAU*i/count
		var w := 0.08
		var warm: Color = RAY_TINT.get(kind,Color(1.0,0.86,0.45))
		var tint := Color(warm,0.15*power) if i % 2 == 0 else Color(0.5,0.8,1.0,0.1*power)
		rays.draw_colored_polygon(PackedVector2Array([c,c + Vector2.from_angle(a - w)*reach,c + Vector2.from_angle(a + w)*reach]),tint)


func _draw_chest() -> void:
	ChestArt.draw(chest,kind,lid,glow,ray_age)


# ---- Layout -----------------------------------------------------------------------------------

func _bounds() -> Rect2:
	var view := get_viewport().get_visible_rect().size
	var lo := Vector2(16,16)
	var hi := view - Vector2(16,18)
	if OS.has_feature("android"):
		var safe := DisplayServer.get_display_safe_area()
		var inverse := get_viewport().get_screen_transform().affine_inverse()
		lo = lo.max(inverse*Vector2(safe.position) + Vector2(12,12))
		hi = hi.min(inverse*Vector2(safe.end) - Vector2(12,12))
	var width := minf(hi.x - lo.x,720.0)
	return Rect2(Vector2((hi.x + lo.x - width)*0.5,lo.y),Vector2(width,hi.y - lo.y))


func _chest_center() -> Vector2:
	return chest.position + Vector2(150,150)


func _card_size() -> Vector2:
	var n := maxi(1,receipt.get("cards",[]).size())
	var area := _bounds()
	var columns := n if n <= 4 else 3
	var rows := ceili(float(n)/columns)
	var width := minf(190.0,(area.size.x - 24.0 - (columns - 1)*12.0)/columns)
	var avail_h := area.size.y - 330.0
	var height := minf(width*1.38,(avail_h - (rows - 1)*12.0)/rows)
	return Vector2(minf(width,height/1.38),height)


func _layout_slots() -> void:
	slots.clear()
	var n: int = receipt.get("cards",[]).size()
	if n == 0:
		return
	var area := _bounds()
	var size := _card_size()
	var columns := n if n <= 4 else 3
	var rows := ceili(float(n)/columns)
	var top := area.position.y + 150.0 + maxf(0.0,(area.size.y - 330.0 - rows*size.y - (rows - 1)*12.0)*0.4)
	for i in range(n):
		var row := i/columns
		var in_row := mini(columns,n - row*columns)
		var col := i % columns
		var row_width := in_row*size.x + (in_row - 1)*12.0
		slots.append(Vector2(area.position.x + (area.size.x - row_width)*0.5 + col*(size.x + 12.0),top + row*(size.y + 12.0)))


func _layout() -> void:
	if not is_inside_tree():
		return
	var area := _bounds()
	var view := get_viewport().get_visible_rect().size
	rays.position = Vector2.ZERO
	rays.size = view
	title.position = Vector2(area.position.x,area.position.y + 14)
	title.size = Vector2(area.size.x,60)
	subtitle.position = Vector2(area.position.x + 10,area.position.y + 76)
	subtitle.size = Vector2(area.size.x - 20,60)
	chest_rest_y = area.position.y + 190.0
	chest.position = Vector2(area.position.x + (area.size.x - 300.0)*0.5,chest_rest_y)
	odds_label.position = Vector2(area.position.x + 10,chest.position.y + 280.0)
	odds_label.size = Vector2(area.size.x - 20,70)
	var buttons_y := area.end.y - 84.0
	open_button.position = Vector2(area.position.x + 182,buttons_y)
	open_button.size = Vector2(area.size.x - 182,84)
	later_button.position = Vector2(area.position.x,buttons_y + 6)
	later_button.size = Vector2(170,72)
	speed_button.position = Vector2(area.position.x,buttons_y + 6)
	speed_button.size = Vector2(minf(280.0,area.size.x*0.5 - 6),72)
	skip_button.position = Vector2(area.position.x + area.size.x - 150,buttons_y + 6)
	skip_button.size = Vector2(150,72)
	continue_button.position = Vector2(area.position.x,buttons_y)
	continue_button.size = Vector2(area.size.x,84)
	hint.position = Vector2(area.position.x,buttons_y - 40)
	hint.size = Vector2(area.size.x,30)
	summary.position = Vector2(area.position.x,buttons_y - 76)
	summary.size = Vector2(area.size.x,60)
	_layout_slots()
	for i in range(cards.size()):
		cards[i].size = _card_size()
		cards[i].pivot_offset = cards[i].size*0.5
		if phase >= Phase.REVEAL:
			cards[i].position = slots[i]
