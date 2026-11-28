extends "res://scripts/crystal/map_hud.gd"

signal preferences_changed
signal control_touched
var prefs := preload("res://scripts/board/presentation_preferences.gd").new()
var rolls_left: Label
var ranks := HBoxContainer.new()
var energy_bar := ProgressBar.new()
var setting_error: Label
var fx_toggle: CheckButton
var music_toggle: CheckButton
var reduced_toggle: CheckButton
var quality_menu: OptionButton
signal roll_requested
signal indices_requested
signal crystal_requested
signal event_requested
signal open_chest_requested(kind: String)
signal cards_requested
const Cards := preload("res://scripts/economy/card_service.gd")
var chest_buttons := {}
var stat_values := {}
var stat_tweens := {}
var roll_shine: Control
var roll_glow: Panel
var roll_fx: Tween
var sparks_enabled := true
const Events := preload("res://scripts/economy/event_service.gd")
const Energy := preload("res://scripts/economy/energy_service.gd")
const EventScreen := preload("res://scripts/crystal/event_screen.gd")
var event_chip: Button
var event_tween: Tween
const Crystal := preload("res://scripts/crystal/super_crystal_service.gd")
var crystal_chip: Button
var chip_tween: Tween
const RULES := preload("res://assets/board/rules.tres")
var total: Label
var roll_button: Button
var throwing := false
var lap_revealed := false
@onready var flights := Control.new()
const Spark := preload("res://scripts/board/reward_burst.gd")
const PRIZE_ICONS := {"coins":"coin","energy":"energy","fragments":"crystal","build_points":"hammer","quest_tokens":"challenge"}


func _make_controls() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",10)
	home.add_child(row)
	total = _label("Două zaruri",22)
	total.custom_minimum_size.x = 98
	var readout := VBoxContainer.new()
	readout.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(readout)
	readout.add_theme_constant_override("separation",0)
	readout.add_child(total)
	rolls_left = _label("",16,Color("#bce6d9"))
	readout.add_child(rolls_left)
	roll_button = _button("ARUNCĂ",func() -> void: roll_requested.emit(),true)
	roll_button.custom_minimum_size.y = 78
	roll_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roll_button.icon = preload("res://assets/board/crown_dice.svg")
	roll_button.expand_icon = true
	roll_button.add_theme_constant_override("icon_max_width",49)
	roll_button.add_theme_constant_override("h_separation",12)
	row.add_child(roll_button)
	_decorate_roll(roll_button)
	skip = _button("Grăbește",func() -> void: skip_requested.emit())
	row.add_child(skip)
	skip.hide()


## Shine sweep and a soft gold outline that breathe while the button is ready to use.
func _decorate_roll(button: Button) -> void:
	button.clip_contents = true
	roll_glow = Panel.new()
	roll_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var outline := StyleBoxFlat.new()
	outline.bg_color = Color(1,1,1,0)
	outline.border_color = Color("#fff4c2")
	outline.set_border_width_all(3)
	outline.set_corner_radius_all(19)
	roll_glow.add_theme_stylebox_override("panel",outline)
	roll_glow.modulate.a = 0.0
	button.add_child(roll_glow)
	roll_glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	roll_shine = Control.new()
	roll_shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	roll_shine.draw.connect(func() -> void:
		var h := roll_shine.size.y
		roll_shine.draw_colored_polygon(PackedVector2Array([Vector2(h*0.45,0),Vector2(h*0.45 + 46,0),Vector2(46,h),Vector2(0,h)]),Color(1,1,1,0.34))
		roll_shine.draw_colored_polygon(PackedVector2Array([Vector2(h*0.45 + 58,0),Vector2(h*0.45 + 72,0),Vector2(72,h),Vector2(58,h)]),Color(1,1,1,0.2)))
	roll_shine.size = Vector2(90,78)
	roll_shine.position = Vector2(-120,0)
	button.add_child(roll_shine)


func _update_roll_fx(ready: bool) -> void:
	if roll_button == null or roll_shine == null:
		return
	var animate := ready and not prefs.reduced
	if animate and (roll_fx == null or not roll_fx.is_valid() or not roll_fx.is_running()):
		roll_fx = roll_button.create_tween().set_loops()
		roll_fx.tween_interval(2.6)
		roll_fx.tween_property(roll_shine,"position:x",roll_button.size.x + 40.0,0.75).from(-120.0).set_trans(Tween.TRANS_SINE)
		roll_fx.parallel().tween_property(roll_glow,"modulate:a",0.8,0.35).from(0.0)
		roll_fx.tween_property(roll_glow,"modulate:a",0.0,0.4)
	elif not animate:
		if roll_fx:
			roll_fx.kill()
		roll_shine.position.x = -120.0
		roll_glow.modulate.a = 0.0


func _make_projection() -> void:
	crystal_chip = _button("",func() -> void: crystal_requested.emit())
	crystal_chip.icon = ICONS["crystal"]
	crystal_chip.expand_icon = true
	crystal_chip.add_theme_constant_override("icon_max_width",30)
	crystal_chip.custom_minimum_size = Vector2(0,52)
	crystal_chip.add_theme_font_size_override("font_size",19)
	crystal_chip.set_meta("no_press_fx",true)
	crystal_chip.accessibility_name = "Super Cristal"
	crystal_chip.tooltip_text = "Super Cristal · se încarcă la fiecare aruncare"
	add_child(crystal_chip)
	event_chip = _button("",func() -> void: event_requested.emit())
	event_chip.icon = ICONS["chaos"]
	event_chip.expand_icon = true
	event_chip.add_theme_constant_override("icon_max_width",30)
	event_chip.custom_minimum_size = Vector2(0,52)
	event_chip.add_theme_font_size_override("font_size",19)
	event_chip.set_meta("no_press_fx",true)
	event_chip.accessibility_name = "Eveniment"
	event_chip.hide()
	add_child(event_chip)
	flights.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flights)
	flights.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _make_debug(col: VBoxContainer) -> void:
	col.add_child(_label("Cufere · atinge pentru a deschide",21,GOLD))
	var chest_row := HBoxContainer.new()
	chest_row.add_theme_constant_override("separation",8)
	col.add_child(chest_row)
	for kind in Cards.CHEST_KINDS:
		var opener := _button("",func() -> void:
			overlay.hide()
			open_chest_requested.emit(kind))
		opener.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		opener.add_theme_font_size_override("font_size",19)
		chest_row.add_child(opener)
		chest_buttons[kind] = opener
	col.add_child(_button("Cărțile mele",func() -> void:
		overlay.hide()
		cards_requested.emit()))
	var audio_row := HBoxContainer.new()
	col.add_child(audio_row)
	music_toggle = _toggle(audio_row,"Muzică","music")
	fx_toggle = _toggle(audio_row,"Sunete","sfx")
	reduced_toggle = _toggle(col,"Efecte vizuale reduse","reduced")
	var quality_row := HBoxContainer.new()
	col.add_child(quality_row)
	var caption := _label("Grafică",21)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quality_row.add_child(caption)
	quality_menu = OptionButton.new()
	quality_menu.accessibility_name = "Calitate grafică"
	quality_menu.custom_minimum_size = Vector2(185,56)
	quality_menu.add_theme_font_size_override("font_size",21)
	for item in ["Redus","Mediu","Ridicat"]:
		quality_menu.add_item(item)
	quality_menu.select(prefs.quality)
	quality_row.add_child(quality_menu)
	quality_menu.item_selected.connect(func(index: int) -> void:
		prefs.quality = index
		_save_preferences())
	setting_error = _label("",18,GOLD)
	setting_error.hide()
	col.add_child(setting_error)
	if OS.is_debug_build():
		col.add_child(_button("Indici traseu 0–%d" % (RULES.tile_count-1), func() -> void:
			indices_requested.emit()
			overlay.hide()))


func _refresh_controls(game: RefCounted, s: Dictionary) -> void:
	playing = game.busy
	super_help.text = "O aruncare consumă %d energie." % RULES.energy_cost
	roll_button.disabled = playing or int(s.energy) < RULES.energy_cost
	_update_roll_fx(not roll_button.disabled)
	roll_button.text = "ARUNCĂ"
	if playing:
		roll_button.text = "Aruncare…" if throwing else "În mers…"
	elif roll_button.disabled:
		var seconds := maxi(0,Energy.seconds_to_next(s,game.clock()))
		roll_button.text = "Energie în %d:%02d" % [seconds/60,seconds%60]
	skip.visible = playing
	var result: Dictionary = s.last_roll
	if not result.is_empty():
		total.text = "%d + %d\n%d pași" % [result.a,result.b,int(result.a)+int(result.b)]
		if throwing:
			total.text = "Două zaruri"
		if playing:
			# The wallet is already committed; reveal each gain at its board event.
			var landing: Dictionary = result.landing
			var amount := int(landing.get("amount",0))
			var key: String = landing.get("resource","")
			var lap_due := 0 if lap_revealed else int(result.start_coins)
			coins.text = str(int(s.wallet.coins)-lap_due-(amount if key == "coins" else 0))
			if key == "fragments":
				fragments.text = str(int(s.wallet.fragments)-amount)
			if key == "energy":
				energy.text = "%d/%d" % [int(s.energy)-amount,RULES.energy_max]

	_refresh_crystal(s)
	refresh_event(game,s)
	var available := int(energy.text.get_slice("/",0))/maxi(1,RULES.energy_cost)
	rolls_left.text = "1 aruncare" if available == 1 else "%d aruncări" % available


func map_window() -> Rect2:
	var bounds := get_viewport().get_visible_rect()
	var upper := top.get_global_rect().end.y + 8.0
	return Rect2(8,upper,bounds.size.x-16,dock.position.y-70.0-upper)


func refresh(game: RefCounted, slot: int) -> void:
	super(game, slot)
	_react_counters()
	energy_bar.value = int(energy.text.get_slice("/",0))
	for i in range(ranks.get_child_count()):
		ranks.get_child(i).color = GOLD if i < preview_level else Color("#4e7779")
	inventory.text = inventory.text.replace("Ciocane","Puncte de construcție")
	inventory.text += "\nJetoane locale   %d" % game.state.wallet.quest_tokens
	var chests: Dictionary = game.state.get("chests",{})
	inventory.text += "\nCufere   lemn %d · argint %d · aur %d" % [int(chests.get("wood",0)),int(chests.get("silver",0)),int(chests.get("gold",0))]
	inventory.text += "\nCărți   %d/%d unice · %d exemplare" % [Cards.unique_owned(game.state),Cards.catalog().size(),Cards.total_copies(game.state)]
	for kind: String in chest_buttons:
		var have := int(chests.get(kind,0))
		var opener: Button = chest_buttons[kind]
		opener.text = "%s ×%d" % [{"wood":"Lemn","silver":"Argint","gold":"Aur"}[kind],have]
		opener.disabled = have < 1 or game.busy
	if slot < 0:
		return
	var building: String = game.cfg.buildings.positions[slot].id
	var text: String = game.ECONOMY.preview(building, preview_level)
	if preview_level < 3:
		var cost: Dictionary = game.cfg.buildings.costs_to_reach_level[str(preview_level + 1)]
		price.text = "%s\nCost · %d monede + %d puncte de construcție" % [text,cost.coins,cost.build_points]
	else:
		price.text = text
	price.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


## Coins, crystals and energy pop when their displayed value goes up and dip when energy is spent.
func _react_counters() -> void:
	var now := {"coins": int(coins.text), "fragments": int(fragments.text), "energy": int(energy.text.get_slice("/",0))}
	if not stat_values.is_empty():
		for key: String in now:
			var change: int = now[key] - int(stat_values[key])
			if change > 0:
				pop_stat(key,change)
			elif change < 0 and key == "energy":
				dip_stat(key)
	stat_values = now


func stat_button(key: String) -> Button:
	return {"coins": coins, "fragments": fragments, "energy": energy}.get(key)


func pop_stat(key: String, gained := 0, strength := 1.0) -> void:
	var button := stat_button(key)
	if button == null:
		return
	if stat_tweens.has(key) and stat_tweens[key]:
		stat_tweens[key].kill()
	button.pivot_offset = button.size*0.5
	button.scale = Vector2.ONE
	if prefs.reduced:
		return
	var tween := button.create_tween()
	stat_tweens[key] = tween
	tween.tween_property(button,"scale",Vector2.ONE*(1.0 + 0.1*strength),0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button,"scale",Vector2.ONE,0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_balance_glint(button)
	if gained > 0:
		_float_text("+%d" % gained,button.get_global_rect().position + Vector2(button.size.x*0.5,button.size.y*0.15),TINTS.get({"coins":"coins","fragments":"fragments","energy":"energy"}[key],GOLD))


func dip_stat(key: String) -> void:
	var button := stat_button(key)
	if button == null or prefs.reduced:
		return
	if stat_tweens.has(key) and stat_tweens[key]:
		stat_tweens[key].kill()
	button.pivot_offset = button.size*0.5
	var tween := button.create_tween()
	stat_tweens[key] = tween
	tween.tween_property(button,"scale",Vector2.ONE*0.965,0.06)
	tween.tween_property(button,"scale",Vector2.ONE,0.14).set_trans(Tween.TRANS_SINE)


func _float_text(text: String, at: Vector2, color: Color) -> void:
	if prefs.reduced:
		return
	var label := _label(text,24,color)
	label.add_theme_constant_override("outline_size",7)
	label.add_theme_color_override("font_outline_color",Color("#143040"))
	flights.add_child(label)
	label.reset_size()
	label.position = at - Vector2(label.size.x*0.5,0)
	var rise := label.create_tween().set_parallel(true)
	rise.tween_property(label,"position:y",at.y - 30.0,0.8).set_trans(Tween.TRANS_SINE)
	rise.tween_property(label,"modulate:a",0.0,0.3).set_delay(0.5)
	rise.chain().tween_callback(label.queue_free)


## Small crown of glints at a screen position, used by buttons and counters.
func spark_screen(at: Vector2, color: Color, key := "", special := false) -> void:
	if prefs.reduced or not sparks_enabled:
		return
	var spark := Spark.new()
	flights.add_child(spark)
	spark.play_at(at,color,key,special)


func _toast(text: String) -> Label:
	var label := _label(text, 24, GOLD)
	label.add_theme_stylebox_override("normal", _style(NAVY, GOLD, 14))
	add_child(label)
	label.reset_size()
	return label


func show_lap(bonus: int) -> void:
	var label := _toast("Tur nou · +%d monede" % bonus)
	label.position = Vector2(top.position.x + (top.size.x-label.size.x)*0.5, top.position.y+top.size.y+8)
	var fade := label.create_tween()
	fade.tween_interval(0.9)
	fade.tween_property(label, "modulate:a", 0, 0.25)
	fade.tween_callback(label.queue_free)


func show_landing(text: String, camera: Camera3D, point: Vector3, key := "") -> void:
	var label := _toast(text)
	label.name = "Premiu"
	var tint: Color = TINTS.get(key,GOLD)
	label.add_theme_font_size_override("font_size",27)
	label.add_theme_color_override("font_color",Color("#fff8e0"))
	label.add_theme_constant_override("outline_size",8)
	label.add_theme_color_override("font_outline_color",Color("#16303f"))
	var frame := _style(NAVY,tint,16)
	frame.set_border_width_all(3)
	frame.shadow_color = Color(tint,0.35)
	frame.shadow_size = 8
	if PRIZE_ICONS.has(key):
		frame.content_margin_left = 58
		label.add_theme_stylebox_override("normal",frame)
		var badge := TextureRect.new()
		badge.texture = ICONS[PRIZE_ICONS[key]]
		badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		badge.size = Vector2(40,40)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_child(badge)
		label.reset_size()
		badge.position = Vector2(10,(label.size.y - 40.0)*0.5)
	else:
		label.add_theme_stylebox_override("normal",frame)
		label.reset_size()
	if not prefs.reduced:
		label.pivot_offset = label.size*0.5
		label.scale = Vector2.ONE*0.55
		var pop := label.create_tween()
		pop.tween_property(label,"scale",Vector2.ONE*1.12,0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		pop.tween_property(label,"scale",Vector2.ONE,0.12).set_trans(Tween.TRANS_BACK)
	var track := func(rise: float) -> void:
		var p := camera.unproject_position(point) - Vector2(label.size.x*0.5,label.size.y+rise)
		label.position = p.clamp(Vector2(top.position.x,top.position.y+top.size.y),
			Vector2(top.position.x+top.size.x-label.size.x,dock.position.y-label.size.y))
	track.call(0.0)
	var float_up := label.create_tween()
	float_up.tween_method(track,0.0,20.0,0.85)
	float_up.tween_property(label,"modulate:a",0,0.20)
	float_up.tween_callback(label.queue_free)


const TINTS := {"coins":Color("#ffda79"),"fragments":Color("#85eeff"),"energy":Color("#b0ffb4"),
	"build_points":Color("#ffb487"),"quest_tokens":Color("#efb6ff")}

func prize_color(key: String) -> Color:
	return TINTS.get(key,GOLD)

func fly_prize(key: String, point: Vector3, camera: Camera3D, balance: int, special := false, amount := 1) -> void:
	if amount <= 0:
		return
	var target: Control
	match key:
		"coins": target = coins
		"energy": target = energy
		"fragments": target = fragments
		_:
			var caption := "Puncte" if key == "build_points" else "Jetoane"
			var chip := _label("%s · %d" % [caption,balance],21)
			chip.add_theme_stylebox_override("normal",_style(NAVY,GOLD,12))
			flights.add_child(chip)
			chip.reset_size()
			chip.position = bag.global_position + Vector2(bag.size.x-chip.size.x,bag.size.y+6)
			target = chip
			var lifetime := chip.create_tween()
			lifetime.tween_interval(1.14)
			lifetime.tween_property(chip,"modulate:a",0.0,0.18)
			lifetime.tween_callback(chip.queue_free)
	var icon := TextureRect.new()
	icon.texture = ICONS[PRIZE_ICONS[key]]
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.size = Vector2(43,43)
	icon.pivot_offset = icon.size * 0.5
	flights.add_child(icon)
	spark_at(camera,point,prize_color(key),key,special)
	var start := camera.unproject_position(point)
	var raised := start + Vector2(13,-38)
	var glide := func(t: float) -> void:
		var end := target.get_global_rect().get_center()
		var bend := raised.lerp(end,0.5) + Vector2(48,-68)
		icon.position = raised.bezier_interpolate(bend,bend,end,t) - icon.pivot_offset
		icon.scale = Vector2.ONE * lerpf(1.0,0.68,t)
	icon.position = start-icon.pivot_offset
	var flight := icon.create_tween()
	flight.tween_property(icon,"position",raised-icon.pivot_offset,0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	flight.tween_method(glide,0.0,1.0,0.53).set_trans(Tween.TRANS_SINE)
	flight.tween_callback(_balance_glint.bind(target))
	flight.tween_callback(icon.queue_free)


func _press_fx(button: Button, down: bool) -> void:
	if prefs.reduced or button.has_meta("no_press_fx") or button.disabled:
		return
	button.pivot_offset = button.size*0.5
	var tween := button.create_tween()
	if down:
		tween.tween_property(button,"scale",Vector2.ONE*0.95,0.06).set_trans(Tween.TRANS_QUAD)
	else:
		tween.tween_property(button,"scale",Vector2.ONE*1.045,0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(button,"scale",Vector2.ONE,0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _balance_glint(target: Control) -> void:
	var ring := Panel.new()
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame := _style(Color(1.0,0.84,0.43,0.13),GOLD,17)
	ring.add_theme_stylebox_override("panel",frame)
	target.add_child(ring)
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ring.pivot_offset = target.size * 0.5
	var pulse := ring.create_tween().set_parallel(true)
	pulse.tween_property(ring,"scale",Vector2.ONE*1.065,0.23)
	pulse.tween_property(ring,"modulate:a",0.0,0.29)
	pulse.chain().tween_callback(ring.queue_free)


func spark_at(camera: Camera3D, point: Vector3, color: Color, key := "", special := false) -> void:
	if prefs.reduced:
		return
	var spark := Spark.new()
	flights.add_child(spark)
	spark.play(camera,point,color,key,special)

func _toggle(parent: Container, caption: String, key: String) -> CheckButton:
	var choice := CheckButton.new()
	choice.text = caption
	choice.custom_minimum_size.y = 56
	choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choice.add_theme_font_size_override("font_size",21)
	choice.button_pressed = prefs.get(key)
	parent.add_child(choice)
	choice.toggled.connect(func(enabled: bool) -> void:
		prefs.set(key,enabled)
		_save_preferences())
	return choice

func _save_preferences() -> void:
	setting_error.visible = prefs.write() != OK
	setting_error.text = "Setările se aplică doar în această sesiune." if setting_error.visible else ""
	preferences_changed.emit()

func _ready() -> void:
	prefs.read()
	super()
	bag.text = "Sac"
	bag.accessibility_name = "Inventar și setări"
	bag.tooltip_text = bag.accessibility_name
	for stat: Button in [coins,fragments,energy]:
		stat.add_theme_font_size_override("font_size",23)
		stat.add_theme_constant_override("icon_max_width",37)
	var fills := [Color("#ffd277"),Color("#8fddef"),Color("#9bdcc0")]
	for i in range(3):
		var stat: Button = [coins,fragments,energy][i]
		stat.add_theme_stylebox_override("normal",_style(Color("#1e424d"),fills[i],22))
	energy_bar.show_percentage = false
	energy_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	energy_bar.max_value = RULES.energy_max
	energy.add_child(energy_bar)
	energy_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	energy_bar.offset_left = 17
	energy_bar.offset_right = -17
	energy_bar.offset_top = -9
	energy_bar.offset_bottom = -5
	for part in ["background","fill"]:
		var rail := StyleBoxFlat.new()
		rail.bg_color = Color("#83d6af") if part == "fill" else Color("#335e63")
		rail.set_corner_radius_all(2)
		energy_bar.add_theme_stylebox_override(part,rail)
	build.add_child(ranks)
	build.move_child(ranks,1)
	ranks.alignment = BoxContainer.ALIGNMENT_CENTER
	ranks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in range(3):
		var mark := ColorRect.new()
		mark.custom_minimum_size = Vector2(24,4)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ranks.add_child(mark)
	var dock_frame := _style(Color("#1c3d49"),Color("#78b5af"),23)
	dock_frame.content_margin_left = 16
	dock_frame.content_margin_right = 16
	dock_frame.content_margin_top = 9
	dock_frame.content_margin_bottom = 10
	dock.add_theme_stylebox_override("panel",dock_frame)
	title.add_theme_color_override("font_color",Color("#ffdf99"))
	_layout.call_deferred()

func _button(caption: String, action: Callable, primary := false) -> Button:
	var button := super(caption,action,primary)
	button.button_down.connect(func() -> void: control_touched.emit())
	button.resized.connect(func() -> void: button.pivot_offset = button.size*0.5)
	button.button_down.connect(func() -> void: _press_fx(button,true))
	button.button_up.connect(func() -> void: _press_fx(button,false))
	for state_name in ["normal","hover","pressed","disabled"]:
		var color := Color("#ffd283") if primary else Color("#305461")
		if state_name == "hover":
			color = color.lightened(0.08)
		elif state_name == "pressed":
			color = color.darkened(0.13)
		elif state_name == "disabled":
			color = Color("#516570")
		var style := _style(color,Color("#d89e58") if primary else Color("#73a5a5"),19)
		style.border_width_bottom = 2 if state_name == "pressed" else 5
		style.shadow_size = 2
		style.shadow_offset = Vector2(0,2)
		style.shadow_color = Color(0.05,0.13,0.16,0.28)
		if primary and state_name == "normal":
			style.shadow_color = Color(1.0,0.82,0.4,0.38)
			style.shadow_size = 7
		button.add_theme_stylebox_override(state_name,style)
		if state_name == "hover":
			var focus := style.duplicate() as StyleBoxFlat
			focus.border_color = Color("#fff4c2")
			focus.set_border_width_all(4)
			button.add_theme_stylebox_override("focus",focus)
	if primary:
		var lettering := FontVariation.new()
		lettering.base_font = ThemeDB.fallback_font
		lettering.variation_embolden = 0.36
		lettering.spacing_glyph = 1
		button.add_theme_font_override("font",lettering)
		button.add_theme_font_size_override("font_size",28)
	return button

func _layout() -> void:
	super()
	if crystal_chip:
		crystal_chip.reset_size()
		crystal_chip.position = Vector2(top.position.x,top.position.y+top.size.y+10)
		event_chip.reset_size()
		event_chip.position = Vector2(top.position.x+crystal_chip.size.x+8,top.position.y+top.size.y+10)
	if overlay.get_child_count() == 0:
		return
	# Anchor the inventory and its close control inside the same safe margins as the HUD.
	var center := overlay.get_child(0) as CenterContainer
	var viewport_size := get_viewport().get_visible_rect().size
	center.offset_left = top.position.x
	center.offset_right = top.position.x+top.size.x-viewport_size.x
	center.offset_top = top.position.y
	center.offset_bottom = dock.position.y+dock.size.y-viewport_size.y


func _refresh_crystal(s: Dictionary) -> void:
	var ready := Crystal.is_ready(s)
	var text := "Super Cristal gata!" if ready else "Super Cristal  %d/%d" % [Crystal.charge(s),Crystal.target(s)]
	if crystal_chip.text == text:
		return
	crystal_chip.text = text
	crystal_chip.reset_size()
	var fill := Color("#ffcf5a") if ready else Color("#1e424d")
	var style := _style(fill,Color("#fff1b0") if ready else Color("#7fd8e6"),20)
	for mode in ["normal","hover","pressed"]:
		crystal_chip.add_theme_stylebox_override(mode,style)
	for mode in ["font_color","font_hover_color","font_pressed_color"]:
		crystal_chip.add_theme_color_override(mode,Color("#3b2d34") if ready else CREAM)
	if chip_tween:
		chip_tween.kill()
	crystal_chip.scale = Vector2.ONE
	if ready and not prefs.reduced:
		crystal_chip.pivot_offset = crystal_chip.size*0.5
		chip_tween = crystal_chip.create_tween().set_loops()
		chip_tween.tween_property(crystal_chip,"scale",Vector2.ONE*1.06,0.45).set_trans(Tween.TRANS_SINE)
		chip_tween.tween_property(crystal_chip,"scale",Vector2.ONE,0.45).set_trans(Tween.TRANS_SINE)
	_layout.call_deferred()


## Event button next to the crystal button: name and time left, pulsing when a reward can be claimed.
func refresh_event(game: RefCounted, s: Dictionary) -> void:
	var ev: Dictionary = s.get("event",{})
	var now: int = game.clock()
	var phase := Events.status(ev,now)
	var show_chip := phase == "active" or phase == "claiming"
	event_chip.visible = show_chip
	if not show_chip:
		return
	var def := Events.definition(str(ev.id))
	var claimable := Events.claimable(ev,now).size() > 0
	var time_left := EventScreen.time_text(Events.remaining(ev,now)) if phase == "active" else "revendică"
	var text := "Recompensă gata!" if claimable else "%s · %s" % [str(def.name).replace("Festivalul lui ","Festival "),time_left]
	if event_chip.text != text:
		event_chip.text = text
		event_chip.reset_size()
		var style := _style(Color("#5a35a8") if not claimable else Color("#ffcf5a"),Color("#9ef0e1") if not claimable else Color("#fff1b0"),20)
		for mode in ["normal","hover","pressed"]:
			event_chip.add_theme_stylebox_override(mode,style)
		for mode in ["font_color","font_hover_color","font_pressed_color"]:
			event_chip.add_theme_color_override(mode,Color("#3b2d34") if claimable else CREAM)
		if event_tween:
			event_tween.kill()
		event_chip.scale = Vector2.ONE
		if claimable and not prefs.reduced:
			event_chip.pivot_offset = event_chip.size*0.5
			event_tween = event_chip.create_tween().set_loops()
			event_tween.tween_property(event_chip,"scale",Vector2.ONE*1.06,0.45).set_trans(Tween.TRANS_SINE)
			event_tween.tween_property(event_chip,"scale",Vector2.ONE,0.45).set_trans(Tween.TRANS_SINE)
		_layout.call_deferred()


func show_event_points(points: int, event_name: String) -> void:
	var label := _toast("+%d puncte · %s" % [points,event_name])
	label.add_theme_color_override("font_color",Color("#9ef0e1"))
	label.position = Vector2(top.position.x + (top.size.x-label.size.x)*0.5,top.position.y+top.size.y+72)
	var fade := label.create_tween()
	fade.tween_interval(1.1)
	fade.tween_property(label,"modulate:a",0,0.25)
	fade.tween_callback(label.queue_free)


func blocks_map(point: Vector2) -> bool:
	return super(point) or (crystal_chip.visible and crystal_chip.get_global_rect().has_point(point)) or (event_chip.visible and event_chip.get_global_rect().has_point(point))
