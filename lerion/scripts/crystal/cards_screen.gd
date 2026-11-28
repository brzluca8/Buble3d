extends CanvasLayer
## Read-only card inventory: six collections of six cards with copy counts. This is NOT the full
## album (no rewards, no trading); it only shows what is saved. Unowned cards stay hidden as "?".
signal closed
const Cards := preload("res://scripts/economy/card_service.gd")
const CardView := preload("res://scripts/crystal/card_view.gd")
const UiKit := preload("res://scripts/crystal/ui_kit.gd")
var detail: Label
var state_ref: Dictionary = {}
const GOLD := Color("#ffd06a")
const CREAM := Color("#fff3d6")
var hud: CanvasLayer
var screen := Control.new()
var summary: Label
var list := VBoxContainer.new()
var scroll := ScrollContainer.new()
var panel := PanelContainer.new()


func setup(owner_hud: CanvasLayer) -> void:
	hud = owner_hud
	layer = 2
	add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.03,0.06,0.16,0.93)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(panel)
	panel.add_theme_stylebox_override("panel",hud._style(Color("#12295a"),GOLD,22))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation",8)
	panel.add_child(col)
	col.add_child(hud._label("Cărțile mele",36,GOLD))
	summary = hud._label("",20,Color("#bfe9ff"))
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(summary)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",14)
	scroll.add_child(list)
	detail = hud._label("Atinge o carte pentru detalii",19,Color("#bfe9ff"))
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(detail)
	col.add_child(hud._button("Închide",close))
	get_viewport().size_changed.connect(_layout)
	hide()


func is_open() -> bool:
	return visible


func open(state: Dictionary) -> void:
	refresh(state)
	show()
	_layout()
	UiKit.pop_in(panel,hud.prefs.reduced)


func close() -> void:
	hide()
	closed.emit()


func _show_detail(id: String) -> void:
	var item: Dictionary = Cards.card(id)
	var copies := Cards.copies(state_ref,id)
	if copies <= 0:
		detail.text = "Carte nedescoperită · %s · %s" % [Cards.collection(str(item.collection)).name,Cards.rarity(str(item.rarity)).name]
	else:
		detail.text = "%s · %s · %s · %d %s" % [item.name,Cards.rarity(str(item.rarity)).name,Cards.collection(str(item.collection)).name,
			copies,"exemplar" if copies == 1 else "exemplare"]


func refresh(state: Dictionary) -> void:
	state_ref = state
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	summary.text = "%d/%d unice · %d exemplare · %d duplicate\n%d cufere deschise · ilustrații provizorii" % [Cards.unique_owned(state),
		Cards.catalog().size(),Cards.total_copies(state),Cards.duplicate_copies(state),int(state.get("chests_opened",0))]
	for col: Dictionary in Cards.collections():
		var owned := Cards.collection_owned(state,col.id)
		var header: Label = hud._label("%s  ·  %d/6" % [col.name,owned],24,Color(col.color).lightened(0.35))
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		list.add_child(header)
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation",10)
		grid.add_theme_constant_override("v_separation",12)
		list.add_child(grid)
		for item: Dictionary in Cards.cards_in_collection(col.id):
			var copies := Cards.copies(state,item.id)
			var view := CardView.new()
			view.custom_minimum_size = Vector2(150,206)
			view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			view.mouse_filter = Control.MOUSE_FILTER_IGNORE
			view.compact = true
			view.show_card(item.id,true,copies > 0)
			view.selectable = true
			view.selected.connect(_show_detail)
			if copies > 1:
				view.set_badge("×%d" % copies,Color("#3b82f6"))
			grid.add_child(view)


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
	panel.position = lo
	panel.size = hi - lo
