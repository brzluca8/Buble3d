extends CanvasLayer
## Event screen ("Festivalul lui Pufi" and future events). Presentation only: it reads the saved
## event state, asks for a claim through `claim_requested` and never grants anything itself.
signal claim_requested(milestone_id: String)
signal closed

const Events := preload("res://scripts/economy/event_service.gd")
const Energy := preload("res://scripts/economy/energy_service.gd")
const ECONOMY := preload("res://assets/board/economy.tres")
const VIOLET := Color("#34205f")
const DEEP := Color("#231443")
const TEAL := Color("#5fe0cf")
const GOLD := Color("#ffd06a")
const CREAM := Color("#fff3d6")
const KIND_TITLES := {"crystal": "Cristale", "construction": "Construcție", "magic": "Magie"}
const KIND_ICONS := {"crystal": "crystal", "construction": "hammer", "magic": "chaos"}

var hud: CanvasLayer
var game: RefCounted
var screen := Control.new()
var panel := PanelContainer.new()
var title: Label
var tagline: Label
var timer_label: Label
var track := Control.new()
var next_label: Label
var mill_label: Label
var rows := VBoxContainer.new()
var chips := HBoxContainer.new()
var status_label: Label
var age := 0.0
var shown := ""


static func time_text(seconds: int) -> String:
	if seconds >= 86400:
		return "%dz %02dh" % [seconds / 86400, (seconds % 86400) / 3600]
	if seconds >= 3600:
		return "%dh %02dm" % [seconds / 3600, (seconds % 3600) / 60]
	return "%d:%02d" % [seconds / 60, seconds % 60]


func setup(owner_hud: CanvasLayer) -> void:
	hud = owner_hud
	layer = 2
	add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.05,0.03,0.12,0.82)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var frame: StyleBoxFlat = hud._style(VIOLET,TEAL,26)
	frame.set_border_width_all(3)
	frame.content_margin_left = 18
	frame.content_margin_right = 18
	frame.content_margin_top = 14
	frame.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel",frame)
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.custom_minimum_size.x = 540
	col.add_theme_constant_override("separation",9)
	panel.add_child(col)
	title = hud._label("",34,GOLD)
	title.add_theme_constant_override("outline_size",8)
	title.add_theme_color_override("font_outline_color",DEEP)
	col.add_child(title)
	tagline = hud._label("",18,Color("#d9c9ff"))
	tagline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(tagline)
	timer_label = hud._label("",26,TEAL)
	timer_label.add_theme_stylebox_override("normal",hud._style(DEEP,TEAL,16))
	col.add_child(timer_label)
	track.custom_minimum_size = Vector2(0,78)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.draw.connect(_draw_track)
	col.add_child(track)
	col.add_child(hud._label("Căsuțe care dau puncte",18,Color("#d9c9ff")))
	chips.add_theme_constant_override("separation",8)
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(chips)
	next_label = hud._label("",21,CREAM)
	next_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(next_label)
	rows.add_theme_constant_override("separation",6)
	col.add_child(rows)
	mill_label = hud._label("",17,Color("#b7f5e8"))
	mill_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(mill_label)
	status_label = hud._label("",18,GOLD)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(status_label)
	col.add_child(hud._button("Închide",close))
	screen.hide()
	hide()
	set_process(false)


func is_open() -> bool:
	return visible


func open(source: RefCounted) -> void:
	game = source
	shown = ""
	refresh()
	show()
	screen.show()
	set_process(true)


func close() -> void:
	hide()
	set_process(false)
	closed.emit()


func _process(delta: float) -> void:
	age += delta
	if age >= 0.5:
		age = 0.0
		update_time()


func _now() -> int:
	return game.clock()


func update_time() -> void:
	if game == null or game.state.is_empty():
		return
	var ev: Dictionary = game.state.event
	if ev.is_empty():
		return
	var now := _now()
	var phase := Events.status(ev,now)
	if phase == "active":
		timer_label.text = "Timp rămas  ·  %s" % time_text(Events.remaining(ev,now))
	elif phase == "claiming":
		timer_label.text = "Încheiat · revendică în %s" % time_text(int(ev.end) + Events.grace_seconds() - now)
	else:
		timer_label.text = "Eveniment încheiat"
	if shown != phase:
		refresh()


## Rebuilds everything from the saved state. Cheap: runs on open, claim and phase change only.
func refresh() -> void:
	if game == null or game.state.is_empty():
		return
	var ev: Dictionary = game.state.event
	var now := _now()
	for holder: Container in [rows,chips]:
		for child in holder.get_children():
			holder.remove_child(child)
			child.queue_free()
	if ev.is_empty():
		title.text = "Niciun eveniment"
		tagline.text = "Revino când începe următorul eveniment."
		timer_label.text = ""
		next_label.text = ""
		mill_label.text = ""
		status_label.text = ""
		shown = "none"
		track.queue_redraw()
		return
	var def := Events.definition(str(ev.id))
	var phase := Events.status(ev,now)
	shown = phase
	title.text = str(def.name)
	tagline.text = str(def.tagline)
	update_time()
	for kind: String in KIND_TITLES:
		if not def.points.has(kind):
			continue
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel",hud._style(DEEP,TEAL,14))
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var inner := HBoxContainer.new()
		inner.alignment = BoxContainer.ALIGNMENT_CENTER
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(inner)
		var icon := TextureRect.new()
		icon.texture = hud.ICONS[KIND_ICONS[kind]]
		icon.custom_minimum_size = Vector2(30,30)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(icon)
		inner.add_child(hud._label("%s +%d" % [KIND_TITLES[kind],int(def.points[kind])],17,CREAM))
		chips.add_child(chip)
	var upcoming := Events.next_milestone(ev)
	if upcoming.is_empty():
		next_label.text = "Toate recompensele au fost atinse!"
	else:
		next_label.text = "Următoarea: %s la %d puncte (încă %d)" % [Events.describe_milestone(upcoming),int(upcoming.points),int(upcoming.points) - int(ev.points)]
	for item: Dictionary in def.milestones:
		_add_row(item,ev,now)
	var level: int = game.mill_level()
	var percent := Events.mill_percent(level)
	mill_label.text = "Moara Trăsnită nivel %d: +%d%% energie din evenimente." % [level,percent] if percent > 0 else "Construiește Moara Trăsnită pentru mai multă energie din evenimente."
	status_label.text = "Punctele se acordă numai când te oprești pe căsuță, în plus față de premiul ei." if phase == "active" else "Punctele nu se mai acordă. Revendică recompensele atinse."
	track.queue_redraw()


func _add_row(item: Dictionary, ev: Dictionary, now: int) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",8)
	rows.add_child(row)
	var reached := int(ev.points) >= int(item.points)
	var claimed := Events.is_claimed(ev,str(item.id))
	var text: Label = hud._label("%d pct  ·  %s" % [int(item.points),Events.describe_milestone(item)],20,CREAM if reached else Color("#a99bc9"))
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	var action: Button
	if claimed:
		action = hud._button("Revendicat ✓",func() -> void: pass)
		action.disabled = true
	elif Events.can_claim(ev,str(item.id),now):
		action = hud._button("Revendică",func() -> void: claim_requested.emit(str(item.id)),true)
	else:
		action = hud._button("Blocat" if not reached else "—",func() -> void: pass)
		action.disabled = true
	action.custom_minimum_size = Vector2(170,52)
	action.add_theme_font_size_override("font_size",19)
	row.add_child(action)


func _draw_track() -> void:
	if game == null or game.state.is_empty() or game.state.event.is_empty():
		return
	var ev: Dictionary = game.state.event
	var def := Events.definition(str(ev.id))
	var milestones: Array = def.milestones
	var top: float = float(milestones[-1].points)
	var width := track.size.x - 24.0
	var bar := Rect2(12,34,width,20)
	track.draw_rect(bar,DEEP)
	var fraction := clampf(float(ev.points) / top,0.0,1.0)
	track.draw_rect(Rect2(bar.position,Vector2(bar.size.x*fraction,bar.size.y)),TEAL)
	track.draw_rect(bar,Color("#8d79c9"),false,2.0)
	for item: Dictionary in milestones:
		var x := bar.position.x + bar.size.x*float(item.points)/top
		var reached := int(ev.points) >= int(item.points)
		track.draw_circle(Vector2(x,44),11.0,GOLD if reached else Color("#6b5a9a"))
		track.draw_circle(Vector2(x,44),7.0,DEEP if not reached else Color("#fff1b0"))
		var caption := str(int(item.points))
		var font := track.get_theme_default_font()
		var w := font.get_string_size(caption,HORIZONTAL_ALIGNMENT_CENTER,-1,15).x
		track.draw_string(font,Vector2(clampf(x - w*0.5,0.0,track.size.x - w),74),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,15,CREAM if reached else Color("#a99bc9"))
	var label := "%d puncte" % int(ev.points)
	var font := track.get_theme_default_font()
	track.draw_string(font,Vector2(12,22),label,HORIZONTAL_ALIGNMENT_LEFT,-1,20,GOLD)
