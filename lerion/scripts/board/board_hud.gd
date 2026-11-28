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
var motion_menu: OptionButton
signal roll_requested
signal indices_requested
signal crystal_requested
signal stat_popped
signal event_requested
signal open_chest_requested(kind: String)
signal cards_requested
signal build_points_requested
var build_stat: Button
## Balances currently shown on the counters (masked during a walk until each gain is revealed).
var shown := {}
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
	crystal_chip.custom_minimum_size = Vector2(0,56)
	crystal_chip.add_theme_font_size_override("font_size",19)
	crystal_chip.set_meta("no_press_fx",true)
	crystal_chip.accessibility_name = "Super Cristal"
	crystal_chip.tooltip_text = "Super Cristal · se încarcă la fiecare aruncare"
	add_child(crystal_chip)
	event_chip = _button("",func() -> void: event_requested.emit())
	event_chip.icon = ICONS["chaos"]
	event_chip.expand_icon = true
	event_chip.add_theme_constant_override("icon_max_width",30)
	event_chip.custom_minimum_size = Vector2(0,56)
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
	var motion_row := HBoxContainer.new()
	col.add_child(motion_row)
	var motion_caption := _label("Mișcare cameră",21)
	motion_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	motion_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	motion_row.add_child(motion_caption)
	motion_menu = OptionButton.new()
	motion_menu.accessibility_name = "Mișcarea camerei"
	motion_menu.custom_minimum_size = Vector2(185,56)
	motion_menu.add_theme_font_size_override("font_size",21)
	for item in ["Completă","Ușoară","Fixă"]:
		motion_menu.add_item(item)
	motion_menu.select(prefs.camera_motion)
	motion_row.add_child(motion_menu)
	motion_menu.item_selected.connect(func(index: int) -> void:
		prefs.camera_motion = index
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
	var values := {"coins": int(s.wallet.coins), "fragments": int(s.wallet.fragments),
		"build_points": int(s.wallet.build_points), "energy": int(s.energy)}
	if not result.is_empty():
		total.text = "%d + %d\n%d pași" % [result.a,result.b,int(result.a)+int(result.b)]
		if throwing:
			total.text = "Două zaruri"
		if playing:
			# The wallet is already committed; reveal each gain at its board event.
			var landing: Dictionary = result.get("landing",{})
			var key: String = landing.get("resource","")
			if values.has(key):
				values[key] -= int(landing.get("amount",0))
			if not lap_revealed:
				values.coins -= int(result.get("start_coins",0))
	for key: String in values:
		_show_value(key,values[key])

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
	_refresh_upgrade(game,slot)
	price.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


## Compact balance for the top bar: full digits up to 99 999, then "123,4k" and "1,2M".
## The exact value stays in the accessibility name and in the Bag.
static func short_number(value: int) -> String:
	# Truncated, never rounded up: a balance is not shown larger than it is.
	if value < 100000:
		return str(value)
	for unit: Array in [[1000000000,"mld"],[1000000,"M"],[1000,"k"]]:
		if value >= int(unit[0]):
			var tenths := value / (int(unit[0]) / 10)
			return "%d,%d%s" % [tenths / 10,tenths % 10,unit[1]]
	return str(value)


const STAT_NAMES := {"coins":"Monede","fragments":"Cristale","build_points":"Puncte de construcție","energy":"Energie"}

func _show_value(key: String, value: int) -> void:
	shown[key] = value
	var button := stat_button(key)
	if button == null:
		return
	button.text = "%d/%d" % [value,RULES.energy_max] if key == "energy" else short_number(value)
	button.accessibility_name = "%s: %d" % [STAT_NAMES[key],value]
	button.tooltip_text = button.accessibility_name


## Counters pop when their displayed value goes up and energy dips when it is spent.
func _react_counters() -> void:
	var now := shown.duplicate()
	if not stat_values.is_empty():
		for key: String in now:
			var change: int = now[key] - int(stat_values[key])
			if change > 0:
				pop_stat(key,change)
			elif change < 0 and key == "energy":
				dip_stat(key)
	stat_values = now


func stat_button(key: String) -> Button:
	return {"coins": coins, "fragments": fragments, "energy": energy, "build_points": build_stat}.get(key)


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
	stat_popped.emit()
	var tween := button.create_tween()
	stat_tweens[key] = tween
	tween.tween_property(button,"scale",Vector2.ONE*(1.0 + 0.1*strength),0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button,"scale",Vector2.ONE,0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_balance_glint(button)
	if gained > 0:
		gain_badge(key,gained,button)


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


## Animated "+X" under a counter, with the resource icon. Build points spell out the unit.
## Driven by the displayed balance changing, so it always reflects a confirmed transaction.
func gain_badge(key: String, gained: int, button: Control) -> Control:
	if prefs.reduced or gained <= 0:
		return null
	var text := "+%d" % gained
	if key == "build_points":
		text = "+%s" % ("1 punct de construcție" if gained == 1 else "%d %spuncte de construcție" % [gained,"de " if gained % 100 >= 20 or gained % 100 == 0 else ""])
	var badge := PanelContainer.new()
	badge.name = "CastigBadge"
	badge.set_meta("gain",key)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tint: Color = TINTS.get(key,GOLD)
	var frame := _style(Color("#163440"),tint,16)
	frame.content_margin_left = 8
	frame.content_margin_right = 12
	frame.content_margin_top = 3
	frame.content_margin_bottom = 3
	badge.add_theme_stylebox_override("panel",frame)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(row)
	var icon := TextureRect.new()
	icon.texture = ICONS[PRIZE_ICONS.get(key,"coin")]
	icon.custom_minimum_size = Vector2(28,28)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var label := _label(text,21,tint.lightened(0.35))
	label.add_theme_constant_override("outline_size",6)
	label.add_theme_color_override("font_outline_color",Color("#143040"))
	row.add_child(label)
	flights.add_child(badge)
	# The icon and label are not laid out yet: size the badge from its content before placing it.
	badge.size = badge.get_combined_minimum_size()
	var anchor := button.get_global_rect()
	var bounds := get_viewport().get_visible_rect().size
	var x := clampf(anchor.get_center().x - badge.size.x*0.5,top.position.x,minf(bounds.x,top.position.x + top.size.x) - badge.size.x)
	# Below the chip row (Super Cristal, event, DEBUG launcher), so nothing covers the badge.
	var y := maxf(anchor.end.y + 6.0,top.position.y + top.size.y + 76.0)
	badge.position = Vector2(x,y + 10.0)
	badge.pivot_offset = badge.size*0.5
	badge.scale = Vector2.ONE*0.6
	badge.modulate.a = 0.0
	var motion := badge.create_tween()
	motion.tween_property(badge,"modulate:a",1.0,0.12)
	motion.parallel().tween_property(badge,"scale",Vector2.ONE,0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	motion.parallel().tween_property(badge,"position:y",y,0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	motion.tween_interval(0.75 if key == "build_points" else 0.45)
	motion.tween_property(badge,"modulate:a",0.0,0.25)
	motion.parallel().tween_property(badge,"position:y",y - 12.0,0.25)
	motion.tween_callback(badge.queue_free)
	return badge


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
		"build_points": target = build_stat
		_:
			var caption := "Jetoane"
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
	# Etapa 4.3: a permanent build-points counter (hammer) between energy and the Bag.
	build_stat = _button("",func() -> void: build_points_requested.emit())
	build_stat.name = "PuncteConstructie"
	build_stat.icon = ICONS["hammer"]
	build_stat.expand_icon = true
	build_stat.accessibility_name = "Puncte de construcție"
	top.add_child(build_stat)
	top.move_child(build_stat,bag.get_index())
	# The Bag becomes a compact icon so five controls fit the portrait bar without clipping.
	bag.text = ""
	bag.icon = preload("res://assets/crystal/bag.svg")
	bag.expand_icon = true
	bag.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bag.add_theme_constant_override("icon_max_width",40)
	bag.custom_minimum_size = Vector2(66,64)
	bag.size_flags_horizontal = Control.SIZE_SHRINK_END
	bag.accessibility_name = "Sac · inventar și setări"
	bag.tooltip_text = bag.accessibility_name
	top.add_theme_constant_override("separation",6)
	# Counters use a slightly bolder face so numbers read at a glance on small screens.
	var numerals := FontVariation.new()
	numerals.base_font = ThemeDB.fallback_font
	numerals.variation_embolden = 0.28
	var ratios := [1.18,1.0,1.18,0.92]
	var fills := [Color("#ffd277"),Color("#8fddef"),Color("#9bdcc0"),Color("#ffb487")]
	for i in range(4):
		var stat: Button = [coins,fragments,energy,build_stat][i]
		stat.add_theme_font_override("font",numerals)
		stat.add_theme_font_size_override("font_size",22)
		stat.add_theme_constant_override("icon_max_width",32)
		stat.add_theme_constant_override("h_separation",5)
		stat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stat.size_flags_stretch_ratio = ratios[i]
		stat.custom_minimum_size = Vector2(96,64)
		stat.clip_text = true
		stat.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var plate := _style(Color("#1e424d"),fills[i],22)
		plate.content_margin_left = 9
		plate.content_margin_right = 9
		stat.add_theme_stylebox_override("normal",plate)
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
	_make_upgrade_panel()
	_layout.call_deferred()


# Upgrade panel (Etapa 4.3): name, levels, current and next bonus, each cost against the balance
# and the exact shortage. Values come from the save, the building config and the economy resource.
const OK_TINT := Color("#9be8a8")
const LOW_TINT := Color("#ff9d8c")
var level_line: Label
var bonus_row := HBoxContainer.new()
var bonus_now: Label
var bonus_now_caption: Label
var bonus_next: Label
var bonus_next_box: PanelContainer
var cost_box := VBoxContainer.new()
var cost_values := {}
var cost_states := {}
var shortage: Label


func _make_upgrade_panel() -> void:
	build.add_theme_constant_override("separation",7)
	level_line = _label("",20,Color("#cfe6df"))
	build.add_child(level_line)
	build.move_child(level_line,ranks.get_index() + 1)
	bonus_row.add_theme_constant_override("separation",8)
	bonus_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	build.add_child(bonus_row)
	build.move_child(bonus_row,level_line.get_index() + 1)
	var now_parts := _bonus_card("Bonus actual",Color("#4e7f84"))
	bonus_now_caption = now_parts[1]
	bonus_now = now_parts[2]
	var next_parts := _bonus_card("După upgrade",GOLD)
	bonus_next_box = next_parts[0]
	bonus_next = next_parts[2]
	price.add_theme_font_size_override("font_size",17)
	price.add_theme_color_override("font_color",Color("#b7f5e8"))
	build.move_child(price,bonus_row.get_index() + 1)
	cost_box.add_theme_constant_override("separation",4)
	cost_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	build.add_child(cost_box)
	build.move_child(cost_box,price.get_index() + 1)
	for key: String in ["coins","build_points"]:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation",8)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cost_box.add_child(line)
		var icon := TextureRect.new()
		icon.texture = ICONS[PRIZE_ICONS[key]]
		icon.custom_minimum_size = Vector2(30,30)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(icon)
		var caption := _label("Monede:" if key == "coins" else "Construcție:",20)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		caption.custom_minimum_size.x = 128
		line.add_child(caption)
		var value := _label("",21)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(value)
		var state := _label("",18)
		state.custom_minimum_size.x = 132
		line.add_child(state)
		cost_values[key] = value
		cost_states[key] = state
	shortage = _label("",19,LOW_TINT)
	shortage.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	build.add_child(shortage)
	build.move_child(shortage,cost_box.get_index() + 1)


func _bonus_card(heading: String, edge: Color) -> Array:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := _style(Color("#143039"),edge,16)
	fill.content_margin_top = 6
	fill.content_margin_bottom = 7
	card.add_theme_stylebox_override("panel",fill)
	bonus_row.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation",1)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(col)
	var caption := _label(heading,16,Color("#a9d3cc") if edge != GOLD else GOLD)
	col.add_child(caption)
	var value := _label("",20)
	value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(value)
	return [card,caption,value]


## "Îți lipsesc 892 de monede.", "Îți lipsește 1 punct de construcție.", or both together.
static func shortage_text(missing_coins: int, missing_points: int) -> String:
	var parts := PackedStringArray()
	if missing_coins > 0:
		parts.append(ECONOMY_TEXT.amount_text("coins",missing_coins))
	if missing_points > 0:
		parts.append(ECONOMY_TEXT.amount_text("build_points",missing_points))
	if parts.is_empty():
		return ""
	var verb := "lipsește" if parts.size() == 1 and (missing_coins == 1 or missing_points == 1) else "lipsesc"
	return "Îți %s %s." % [verb," și ".join(parts)]

const ECONOMY_TEXT := preload("res://assets/board/economy.tres")


func _refresh_upgrade(game: RefCounted, slot: int) -> void:
	var s: Dictionary = game.state
	var id: String = game.cfg.buildings.positions[slot].id
	var top_level: int = game.cfg.buildings.max_level
	var level := preview_level
	title.text = str(game.cfg.buildings.positions[slot].building)
	price.text = ECONOMY_TEXT.scope_text(id,RULES.tile_count)
	var maxed := level >= top_level
	bonus_next_box.visible = not maxed
	cost_box.visible = not maxed
	if maxed:
		level_line.text = "MAXIM  ·  Nivel %d/%d" % [level,top_level]
		level_line.add_theme_color_override("font_color",GOLD)
		bonus_now_caption.text = "Bonus final"
		bonus_now.text = ECONOMY_TEXT.bonus_text(id,level)
		shortage.text = ""
		shortage.hide()
		confirm.visible = false
		return
	level_line.text = "Nivel %d  →  Nivel %d" % [level,level + 1]
	level_line.add_theme_color_override("font_color",Color("#cfe6df"))
	bonus_now_caption.text = "Bonus actual" if level > 0 else "Acum · neconstruită"
	bonus_now.text = ECONOMY_TEXT.bonus_text(id,level)
	bonus_next.text = ECONOMY_TEXT.bonus_text(id,level + 1)
	var cost: Dictionary = game.cfg.buildings.costs_to_reach_level[str(level + 1)]
	var missing := {}
	for key: String in cost_values:
		var have := int(s.wallet[key])
		var need := int(cost[key])
		missing[key] = maxi(0,need - have)
		var enough: bool = missing[key] == 0
		var value: Label = cost_values[key]
		value.text = "%d / %d" % [have,need]
		value.add_theme_color_override("font_color",CREAM if enough else LOW_TINT)
		var state: Label = cost_states[key]
		state.text = "— suficient" if enough else "— insuficient"
		state.add_theme_color_override("font_color",OK_TINT if enough else LOW_TINT)
	shortage.text = shortage_text(int(missing.coins),int(missing.build_points))
	shortage.visible = not shortage.text.is_empty()
	var affordable := shortage.text.is_empty()
	confirm.visible = true
	confirm.text = "Construiește" if level == 0 else "Îmbunătățește"
	confirm.disabled = not affordable or game.busy

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
