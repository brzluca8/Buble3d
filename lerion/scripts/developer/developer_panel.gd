extends CanvasLayer
const Profile := preload("res://scripts/developer/dev_profile.gd")
const Simulation := preload("res://scripts/developer/economy_simulation.gd")
const Crystal := preload("res://scripts/crystal/super_crystal_service.gd")
const Energy := preload("res://scripts/economy/energy_service.gd")
const Events := preload("res://scripts/economy/event_service.gd")
const RULES := preload("res://assets/board/rules.tres")
const Cards := preload("res://scripts/economy/card_service.gd")
var card_status: Label
var card_probe := {}
var rarity_menu: OptionButton
var sim_kind: OptionButton
var energy_report: TextEdit
var charge_value: SpinBox
var energy_status: Label
var event_status: Label
var event_report: TextEdit
var history_view: TextEdit
var spin_history_view: TextEdit
var travel_sim: TextEdit
var chest_report: TextEdit
var pending_part := ""
var reset_part_menu: OptionButton
var event_menu: OptionButton
var landing_input: SpinBox
var live_age := 0.0
var visual_status: Label
var visual_prize: OptionButton
var crystal_status: Label
var chest_status: Label
var sim_wheel: TextEdit
var recovery_probe := {}
var map: Node
var launcher: Button
var cover: ColorRect
var frame: PanelContainer
var pages: Array[ScrollContainer] = []
var section: OptionButton
var status: Label
var diagnostic: TextEdit
var sim_result: TextEdit
var confirmation: ConfirmationDialog
var speed := 1
var simulation: Simulation
var last_simulation := {}
var old_normal_prefix := "user://satul_trasnitilor"
var active := false
var spin_a: SpinBox
var spin_b: SpinBox
var tile_input: SpinBox
var future_prize: OptionButton
## Persistent confirmation of the last real change (Etapa 4.3). Live read-outs never overwrite it.
var notice: Label
var balance_labels := {}
const RESOURCE_NAMES := {"coins":"Monede","fragments":"Fragmente","build_points":"Puncte de construcție","quest_tokens":"Jetoane de aventură"}

func _ready() -> void:
	if not OS.is_debug_build() or not ProjectSettings.get_setting("lerion/developer_panel",true):
		queue_free()
		return
	active = map.game is Profile and map.game.allowed()
	launcher = button(null,"⚒",open_panel)
	launcher.accessibility_name = "Developer Panel"
	launcher.tooltip_text = "Profil de dezvoltare"
	add_child(launcher)
	cover = ColorRect.new()
	cover.color = Color(0.02,0.06,0.09,0.85)
	add_child(cover)
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame = PanelContainer.new()
	cover.add_child(frame)
	frame.minimum_size_changed.connect(func() -> void: layout_panel.call_deferred())
	frame.add_theme_stylebox_override("panel",map.hud._style(Color("#193944"),Color("#ffc877"),18))
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation",10)
	frame.add_child(layout)
	var heading := HBoxContainer.new()
	layout.add_child(heading)
	label(heading,"DEZVOLTARE · profil local" if active else "Developer Panel")
	button(heading,"Închide",close_panel)
	status = label(layout,"")
	status.add_theme_color_override("font_color",Color("#ffe29c"))
	notice = label(layout,"")
	notice.add_theme_font_size_override("font_size",20)
	notice.hide()
	if not active:
		label(layout,"Intră în profilul DEBUG separat pentru a testa resurse, zaruri și clădiri.")
		button(layout,"Intră în profilul de dezvoltare",switch_profile.bind(true))
	else:
		button(layout,"Înapoi la progresul normal",switch_profile.bind(false))
		section = OptionButton.new()
		section.custom_minimum_size.y = 58
		section.add_theme_font_size_override("font_size",23)
		layout.add_child(section)
		var names := ["Resurse","Energie","Zaruri și traseu","Clădiri","Super Cristal","Cufere","Efecte vizuale","Animații și momente","Evenimente","Salvări și diagnostic","Simularea economiei"]
		for title in names:
			section.add_item(title)
			var scroll := ScrollContainer.new()
			scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
			scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			layout.add_child(scroll)
			var col := VBoxContainer.new()
			col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			col.add_theme_constant_override("separation",12)
			scroll.add_child(col)
			pages.append(scroll)
		_resources(pages[0].get_child(0))
		_energy(pages[1].get_child(0))
		_travel(pages[2].get_child(0))
		_buildings(pages[3].get_child(0))
		_future(pages[4].get_child(0))
		_chests(pages[5].get_child(0))
		_visual(pages[6].get_child(0))
		_moments(pages[7].get_child(0))
		_events(pages[8].get_child(0))
		_diagnostics(pages[9].get_child(0))
		_simulations(pages[10].get_child(0))
		section.item_selected.connect(show_page)
		show_page(0)
		map.hud.roll_requested.connect(apply_speed)
	confirmation = ConfirmationDialog.new()
	confirmation.title = "Resetare profil DEBUG"
	confirmation.dialog_text = "Resetezi resursele, nivelurile și poziția profilului local de dezvoltare?"
	confirmation.ok_button_text = "Resetează DEBUG"
	confirmation.cancel_button_text = "Anulează"
	confirmation.confirmed.connect(_confirmed_reset)
	add_child(confirmation)
	cover.hide()
	get_viewport().size_changed.connect(layout_panel)
	layout_panel()

func label(parent: Node, text: String) -> Label:
	var item := Label.new()
	item.text = text
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item.add_theme_font_size_override("font_size",22)
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(item)
	return item

func button(parent: Node, text: String, action: Callable) -> Button:
	var item: Button = map.hud._button(text,action)
	item.custom_minimum_size.y = 58
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if parent != null:
		parent.add_child(item)
	return item

func number(parent: Node, maximum: int, value: int) -> SpinBox:
	var item := SpinBox.new()
	item.min_value = 0
	item.max_value = maximum
	item.step = 1
	item.value = value
	item.custom_minimum_size = Vector2(140,58)
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item.add_theme_font_size_override("font_size",23)
	item.get_line_edit().virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	item.get_line_edit().add_theme_font_size_override("font_size",22)
	parent.add_child(item)
	return item

func row(parent: Node) -> HBoxContainer:
	var item := HBoxContainer.new()
	item.add_theme_constant_override("separation",8)
	parent.add_child(item)
	return item

func layout_panel() -> void:
	if not is_inside_tree() or not is_instance_valid(cover):
		return
	var size_px := get_viewport().get_visible_rect().size
	var lo := Vector2(16,16)
	var hi := size_px-Vector2(16,18)
	if OS.has_feature("android"):
		var safe := DisplayServer.get_display_safe_area()
		var inv := get_viewport().get_screen_transform().affine_inverse()
		lo = lo.max(inv*Vector2(safe.position)+Vector2(12,12))
		hi = hi.min(inv*Vector2(safe.end)-Vector2(12,12))
	frame.position = lo
	frame.size = hi-lo
	launcher.size = Vector2(62,58)
	launcher.position = Vector2(hi.x-62,map.hud.top.position.y+map.hud.top.size.y+10)
	if active:
		launcher.text = "⚒ D"
	confirmation.size = Vector2i(mini(540,int(hi.x-lo.x)),230) if is_instance_valid(confirmation) else Vector2i(540,230)

func show_page(index: int) -> void:
	for i in range(pages.size()):
		pages[i].visible = i == index
	refresh_data()
	layout_panel.call_deferred()

func open_panel() -> void:
	if map.game.busy or map.wheel_open() or map.chest_screen.is_open():
		return
	cover.show()
	map.camera._reset_gesture()
	refresh_data()
	layout_panel()

func close_panel() -> void:
	cover.hide()

func switch_profile(development: bool) -> void:
	if map.game.busy or (simulation != null):
		status.text = "Așteaptă finalul operației."
		return
	_switch.call_deferred(development)

func _switch(development: bool, open_after := true) -> void:
	var next = load("res://scenes/board.tscn").instantiate()
	next.save_prefix = Profile.PREFIX if development else old_normal_prefix
	var tree := get_tree()
	var parent := map.get_parent()
	var previous := map
	parent.remove_child(previous)
	parent.add_child(next)
	tree.current_scene = next
	if development:
		var panel = next.get_node("DeveloperPanel")
		panel.old_normal_prefix = old_normal_prefix if active else previous.save_prefix
		if not card_probe.is_empty():
			panel.card_probe = card_probe
			panel.status.text = "Repornit. Cărțile confirmate #%d trebuie afișate o singură dată." % int(card_probe.receipt.id)
		if not recovery_probe.is_empty():
			panel.recovery_probe = recovery_probe
			panel.status.text = "Repornit. Premiul confirmat #%d trebuie să apară o singură dată." % int(recovery_probe.receipt.id)
		if open_after:
			panel.open_panel()
	previous.queue_free()

func result(ok: bool, done := "Profil DEBUG actualizat și salvat.") -> void:
	if not ok:
		confirm(false,map.game.error if not map.game.error.is_empty() else "Operație refuzată. Verifică valorile sau așteaptă oprirea.")
		return
	sync_map()
	confirm(true,done)
	refresh_data()


## Shows the outcome of the last real change until the next one; it survives refreshes and page changes.
func confirm(ok: bool, text: String) -> void:
	if not is_instance_valid(notice):
		return
	notice.text = ("✔ " if ok else "✖ ") + text
	notice.add_theme_color_override("font_color",Color("#9be8a8") if ok else Color("#ff9d8c"))
	notice.show()


## Real resource change in the DEBUG save, confirmed with the balance before and after.
func change_resource(key: String, field: SpinBox, mode: String) -> void:
	# Digits typed on the on-screen keyboard are applied even without pressing Enter.
	if field.has_meta("typed"):
		field.remove_meta("typed")
		field.apply()
	var before := int(map.game.state.wallet[key])
	var amount := int(field.value)
	var ok: bool
	match mode:
		"add": ok = map.game.set_resource(key,amount,true)
		"zero": ok = map.game.set_resource(key,0)
		_: ok = map.game.set_resource(key,amount)
	var after := int(map.game.state.wallet[key])
	var verb: String = {"add":"adăugat %d" % amount,"zero":"pus pe zero"}.get(mode,"setat la %d" % amount)
	result(ok,"%s: %s · sold %d → %d · salvat în profilul DEBUG." % [RESOURCE_NAMES[key],verb,before,after])

func sync_map() -> void:
	if not active or map.game.busy:
		return
	map.dice.cancel()
	map.path.clear_flash()
	map._pose(float(map.game.state.board_position_index))
	for i in range(6):
		if map.construction_tweens.has(i):
			map.construction_tweens[i].kill()
			map.construction_tweens.erase(i)
		if map.reveals.has(i):
			map.reveals[i].material_overlay = null
			map.reveals.erase(i)
		map.village.models[i].scale = Vector3.ONE
		map.village.set_level(i,int(map.game.state.levels[i]))
	map._refresh()
	map.message.text = "Profil DEBUG · " + map._last_message()

func _resources(col: Node) -> void:
	label(col,"MODIFICARE REALĂ · se salvează numai în profilul DEBUG. Efectele demonstrative sunt în «Efecte vizuale».")
	label(col,"Energia se editează în pagina «Energie».")
	for key: String in ["coins","fragments","build_points","quest_tokens"]:
		label(col,RESOURCE_NAMES[key])
		balance_labels[key] = label(col,"")
		balance_labels[key].add_theme_color_override("font_color",Color("#b7f5e8"))
		var controls := row(col)
		var value := number(controls,1000000000,map.game.state.wallet[key])
		value.get_line_edit().text_changed.connect(func(_text: String) -> void: value.set_meta("typed",true))
		button(controls,"Setează",change_resource.bind(key,value,"set"))
		button(controls,"Adaugă",change_resource.bind(key,value,"add"))
		button(controls,"Zero",change_resource.bind(key,value,"zero"))

func _travel(col: Node) -> void:
	label(col,"Următoarea aruncare · două zaruri 1–6")
	var pair := row(col)
	spin_a = number(pair,6,1)
	spin_b = number(pair,6,1)
	spin_a.min_value = 1
	spin_b.min_value = 1
	button(col,"Fixează următoarea pereche",func() -> void:
		var ok: bool = map.game.force_pair(Vector2i(int(spin_a.value),int(spin_b.value)))
		status.text = "Pereche pregătită pentru o singură aruncare." if ok else "Așteaptă oprirea.")
	button(col,"Revino la zaruri aleatorii",func() -> void:
		map.game.forced_pair = Vector2i.ZERO
		status.text = "Zaruri aleatorii.")
	label(col,"Alege căsuța de aterizare (aruncare normală, cu premiu)")
	landing_input = number(col,35,7)
	button(col,"Aterizează pe căsuță",func() -> void:
		if map.game.force_landing(int(landing_input.value)):
			sync_map()
			play_roll()
		else:
			status.text = "Așteaptă oprirea.")
	_travel_sims(col)
	label(col,"Mutare directă, fără premiu")
	tile_input = number(col,35,0)
	button(col,"Mută pe căsuță",func() -> void: result(map.game.teleport(int(tile_input.value))))
	var timing := OptionButton.new()
	for title in ["Viteză 1×","Viteză 3×","Instantaneu"]:
		timing.add_item(title)
	timing.custom_minimum_size.y = 58
	timing.add_theme_font_size_override("font_size",22)
	timing.item_selected.connect(func(index: int) -> void: speed = [1,3,0][index])
	col.add_child(timing)
	button(col,"Simulează o aruncare completă",play_roll)
	button(col,"Testează START · 34 + (2 + 3)",func() -> void:
		if map.game.teleport(34) and map.game.force_pair(Vector2i(2,3)):
			sync_map()
			play_roll())
	button(col,"Testează oprirea pe START · 34 + (1 + 1)",func() -> void:
		if map.game.teleport(34) and map.game.force_pair(Vector2i(1,1)):
			sync_map()
			play_roll())

func _travel_sims(col: Node) -> void:
	label(col,"Simulare pe o copie izolată a stării (profilul nu se modifică). Statistici: premii, consum de energie, puncte de eveniment.")
	var sims := row(col)
	for count in [100,1000,10000]:
		button(sims,str(count),start_simulation.bind(count))
	travel_sim = text_area(col,320)

func play_roll() -> void:
	if not active or map.game.busy:
		return
	map._deselect()
	map.hud.overlay.hide()
	close_panel()
	map.hud.roll_requested.emit()

func apply_speed() -> void:
	if not active or not map.game.busy:
		return
	if speed == 0:
		map._finish()
	else:
		map.travel.set_speed_scale(speed)
		map.dice.motion.set_speed_scale(speed)

func _buildings(col: Node) -> void:
	for slot in range(6):
		var building: Dictionary = map.game.cfg.buildings.positions[slot]
		label(col,building.building)
		for level in range(4):
			label(col,map.game.ECONOMY.preview(building.id,level))
		var controls := row(col)
		var level := number(controls,3,int(map.game.state.levels[slot]))
		button(controls,"Setează nivel",func() -> void: result(map.game.set_level(slot,int(level.value))))
		button(col,"Testează upgrade-ul cu cost",func() -> void:
			if map.game.busy:
				return
			var current: int = map.game.state.levels[slot]
			if current == 3:
				status.text = "Nivel maxim. Setează un nivel mai mic pentru test."
				return
			close_panel()
			map.selected_plot = slot
			map._refresh()
			map._upgrade(slot,current))

func _energy(col: Node) -> void:
	label(col,"Energie · valorile se aplică numai profilului DEBUG. Costul aruncării și regenerarea sunt în assets/board/rules.tres.")
	energy_status = label(col,"")
	label(col,"Setează energia")
	var presets := row(col)
	for value in [0,1,50]:
		button(presets,str(value),func() -> void: result(map.game.set_energy(value)))
	var presets_high := row(col)
	for value in [99,100,500]:
		button(presets_high,str(value),func() -> void: result(map.game.set_energy(value)))
	var custom := row(col)
	var amount := number(custom,RULES.energy_hard_cap,100)
	button(custom,"Setează",func() -> void: result(map.game.set_energy(int(amount.value))))
	var regen := CheckButton.new()
	regen.text = "Regenerare automată activă"
	regen.custom_minimum_size.y = 58
	regen.add_theme_font_size_override("font_size",22)
	regen.button_pressed = map.game.regen_enabled()
	regen.toggled.connect(func(on: bool) -> void: result(map.game.set_regen(on)))
	col.add_child(regen)
	label(col,"Simulează trecerea timpului (ceasul profilului DEBUG)")
	var jumps := row(col)
	for entry in [["10 min",600],["1 oră",3600],["24 ore",86400]]:
		button(jumps,entry[0],func() -> void: result(map.game.advance_time(int(entry[1]))))
	label(col,"Test separat cu energie peste plafon, pe o copie în memorie.")
	var extra := number(col,10000,150)
	extra.min_value = 101
	button(col,"Testează energia peste plafon",func() -> void:
		energy_report.text = JSON.stringify(map.game.energy_overflow_test(int(extra.value)),"  "))
	energy_report = text_area(col,220)

func _future(col: Node) -> void:
	var rules: Dictionary = Crystal.config()
	label(col,"Super Cristal · prima rotire la %d aruncări, următoarele la %d. Valorile afectează numai profilul DEBUG." % [int(rules.first_target),int(rules.later_target)])
	crystal_status = label(col,"")
	label(col,"Setează încărcarea (maximum: pragul curent)")
	var set_row := row(col)
	charge_value = number(set_row,int(rules.later_target),0)
	button(set_row,"Setează",func() -> void: result(map.game.set_crystal(int(charge_value.value),int(map.game.state.crystal_activations))))
	button(col,"Încarcă instantaneu cristalul",func() -> void: result(map.game.charge_crystal()))
	var presets := row(col)
	button(presets,"49/50",func() -> void: result(map.game.set_crystal(49,0)))
	button(presets,"99/100",func() -> void: result(map.game.set_crystal(99,maxi(1,int(map.game.state.crystal_activations)))))
	button(presets,"0 progres",func() -> void: result(map.game.set_crystal(0,int(map.game.state.crystal_activations))))
	button(col,"Activare instantanee · încarcă și deschide ruleta",func() -> void:
		if map.game.busy or not map.game.pending_spin().is_empty():
			return
		if not map.game.charge_crystal():
			result(false)
			return
		sync_map()
		close_panel()
		map.open_crystal())
	button(col,"Deschide Ruleta Magică",func() -> void:
		if map.game.busy:
			return
		close_panel()
		map.open_crystal())
	label(col,"Forțează premiul următoarei rotiri")
	future_prize = OptionButton.new()
	future_prize.add_item("Aleatoriu (probabilități configurate)")
	for item: Dictionary in Crystal.prizes():
		future_prize.add_item("%s · %s%%" % [item.label,str(snappedf(Crystal.probability(item.id)*100.0,0.1))])
	future_prize.custom_minimum_size.y = 58
	future_prize.add_theme_font_size_override("font_size",21)
	col.add_child(future_prize)
	button(col,"Aplică premiul forțat",func() -> void:
		var id: String = "" if future_prize.selected <= 0 else str(Crystal.prizes()[future_prize.selected-1].id)
		var ok: bool = map.game.force_prize(id)
		if not ok:
			status.text = "Așteaptă oprirea."
		elif id.is_empty():
			status.text = "Rotiri aleatorii."
		else:
			status.text = "Premiu forțat: %s, pentru o singură rotire." % Crystal.describe({"prize":id}))
	label(col,"Simulează rotiri pe o copie în memorie (aceeași tranzacție)")
	var sims := row(col)
	for count in [100,1000,10000]:
		button(sims,str(count),func() -> void:
			var report: Dictionary = map.game.simulate_spins(count)
			last_simulation = {"wheel":report}
			sim_wheel.text = JSON.stringify(report,"  "))
	sim_wheel = text_area(col,260)
	label(col,"Recuperare după restart: salvează o rotire fără animație, apoi repornește scena. Premiul trebuie afișat o singură dată, fără a fi acordat din nou.")
	button(col,"Testează recuperarea după restart",test_recovery)
	label(col,"Istoric premii (ultimele rotiri din acest profil)")
	spin_history_view = text_area(col,220)

func _chests(col: Node) -> void:
	label(col,"Cufere și cărți · profilul DEBUG. Probabilitățile de câștigare a cuferelor la ruletă nu se modifică aici.")
	chest_status = label(col,"")
	card_status = label(col,"")
	label(col,"Adaugă cufere")
	for kind in ["wood","silver","gold"]:
		var title: String = Crystal.chest_name(kind)
		var line := row(col)
		for count in [1,10,100]:
			button(line,"+%d %s" % [count,title.replace("Cufăr de ","")],func() -> void: result(map.game.add_chests(kind,count)))
	button(col,"Golește cuferele",func() -> void: result(map.game.set_chests(0,0,0)))
	label(col,"Deschide un cufăr real (cu animație). Adaugă unul dacă nu ai.")
	var openers := row(col)
	for kind in ["wood","silver","gold"]:
		button(openers,{"wood":"Lemn","silver":"Argint","gold":"Aur"}[kind],func() -> void:
			if map.game.busy or not map.game.pending_open().is_empty():
				status.text = "Așteaptă finalul operației."
				return
			if int(map.game.state.chests[kind]) < 1 and not map.game.add_chests(kind,1):
				result(false)
				return
			close_panel()
			sync_map()
			map.open_chest(kind))
	label(col,"Forțează raritatea tuturor cărților următoarelor deschideri (până la repornire)")
	rarity_menu = OptionButton.new()
	rarity_menu.add_item("Aleatoriu (ponderi configurate)")
	for item: Dictionary in Cards.rarities():
		rarity_menu.add_item("Numai %s" % str(item.name).to_lower())
	rarity_menu.custom_minimum_size.y = 58
	rarity_menu.add_theme_font_size_override("font_size",21)
	col.add_child(rarity_menu)
	button(col,"Aplică raritatea",func() -> void:
		var id: String = "" if rarity_menu.selected <= 0 else str(Cards.rarities()[rarity_menu.selected-1].id)
		var ok: bool = map.game.force_rarity(id)
		status.text = ("Raritate forțată: %s." % id if not id.is_empty() else "Rarități aleatorii.") if ok else "Așteaptă oprirea.")
	label(col,"Simulare izolată: deschide 10 / 100 / 1.000 de cufere pe o copie în memorie (profilul rămâne neschimbat)")
	sim_kind = OptionButton.new()
	for title in ["Cufere de lemn","Cufere de argint","Cufere de aur"]:
		sim_kind.add_item(title)
	sim_kind.custom_minimum_size.y = 58
	sim_kind.add_theme_font_size_override("font_size",21)
	col.add_child(sim_kind)
	var sims := row(col)
	for count in [10,100,1000]:
		button(sims,str(count),func() -> void:
			var kind: String = ["wood","silver","gold"][sim_kind.selected]
			var forced: String = "" if rarity_menu.selected <= 0 else str(Cards.rarities()[rarity_menu.selected-1].id)
			var report: Dictionary = map.game.simulate_chests(kind,count,4101,forced)
			last_simulation = {"chests":report}
			chest_report.text = _format_chest_report(report))
	chest_report = text_area(col,420)
	label(col,"Salvare și redeschidere")
	button(col,"Testează salvarea și redeschiderea",test_card_save)
	button(col,"Testează restart în timpul deschiderii",test_card_recovery)
	for title in ["Completează colecția","Testează recompensa albumului","Schimburi între jucători"]:
		var control := button(col,title+" · indisponibil",func() -> void: pass)
		control.disabled = true
		control.tooltip_text = "Albumul complet și schimburile vor fi implementate într-o etapă viitoare."

func _format_chest_report(report: Dictionary) -> String:
	if report.is_empty() or report.has("error"):
		return "Simularea a eșuat: %s" % str(report)
	var lines := PackedStringArray()
	lines.append("%d × %s · %d cărți extrase%s" % [int(report.opened),Crystal.chest_name(str(report.chest)),int(report.cards_drawn),
		(" · raritate forțată " + str(report.forced_rarity)) if str(report.forced_rarity) != "" else ""])
	for item: Dictionary in Cards.rarities():
		lines.append("  %s: %d (%s%% observat, %s%% configurat)" % [item.name,int(report.by_rarity[item.id]),str(report.observed_percent[item.id]),str(report.expected_percent[item.id])])
	lines.append("Cărți unice: %d din %d · duplicate: %d · exemplare: %d" % [int(report.unique_cards),int(report.catalog_size),int(report.duplicate_copies),int(report.total_copies)])
	lines.append("Contabilitate corectă: %s · a doua deschidere refuzată: %d/%d" % [str(report.cards_consistent),int(report.double_open_refused),int(report.opened)])
	for key: String in report.collections:
		lines.append("  %s: %s" % [key,str(report.collections[key])])
	return "\n".join(lines)

func test_card_save() -> void:
	if map.game.busy or not map.game.pending_open().is_empty():
		status.text = "Așteaptă finalul operației."
		return
	if int(map.game.state.chests.wood) < 1 and not map.game.add_chests("wood",1):
		result(false)
		return
	var before: Dictionary = map.game.state.duplicate(true)
	var receipt: Dictionary = map.game.open_chest("wood")
	if receipt.is_empty():
		status.text = map.game.error if not map.game.error.is_empty() else "Deschidere refuzată."
		return
	var again: Dictionary = map.game.open_chest("wood")
	map.game.acknowledge_open(int(receipt.id))
	var report: Dictionary = map.game.verify_cards_saved()
	chest_report.text = "Cufăr de lemn deschis · %s\nCufere lemn: %d → %d\nA doua deschidere imediată refuzată: %s\nMemorie = disc: %s · unice %d/%d · exemplare %d/%d · deschideri %d/%d" % [
		Cards.describe(receipt),int(before.chests.wood),int(map.game.state.chests.wood),str(again.is_empty()),str(report.identical),
		int(report.unique),int(report.unique_disk),int(report.copies),int(report.copies_disk),int(report.opened),int(report.opened_disk)]
	result(true)

func test_card_recovery() -> void:
	if map.game.busy or map.wheel_open() or map.chest_screen.is_open() or simulation != null or not map.game.pending_open().is_empty():
		status.text = "Așteaptă finalul operației."
		return
	if int(map.game.state.chests.silver) < 1 and not map.game.add_chests("silver",1):
		result(false)
		return
	var before: Dictionary = map.game.state.duplicate(true)
	var receipt: Dictionary = map.game.open_chest("silver")
	if receipt.is_empty():
		status.text = map.game.error if not map.game.error.is_empty() else "Deschidere refuzată."
		return
	card_probe = {"receipt":receipt,"cards_before":before.cards.duplicate(),"chests_before":before.chests.duplicate(),"copies_before":Cards.total_copies(before)}
	_switch.call_deferred(true,false)

func _add_chest(kind: String) -> bool:
	return map.game.add_chests(kind,1)

func test_recovery() -> void:
	if map.game.busy or map.wheel_open() or simulation != null:
		status.text = "Așteaptă finalul operației."
		return
	if not Crystal.is_ready(map.game.state) and not map.game.charge_crystal():
		status.text = "Cristalul nu a putut fi încărcat."
		return
	var before: Dictionary = map.game.state.duplicate(true)
	var receipt: Dictionary = map.game.spin_wheel()
	if receipt.is_empty():
		status.text = map.game.error if not map.game.error.is_empty() else "Rotire refuzată."
		return
	recovery_probe = {"receipt":receipt,"energy_before":int(before.energy),"chests_before":before.chests}
	_switch.call_deferred(true,false)

func _events(col: Node) -> void:
	label(col,"Evenimente · profilul DEBUG. Punctele se acordă numai la aterizare; trecerea peste o căsuță nu dă nimic.")
	event_status = label(col,"")
	event_menu = OptionButton.new()
	for def: Dictionary in Events.definitions():
		event_menu.add_item(str(def.name))
	event_menu.custom_minimum_size.y = 58
	event_menu.add_theme_font_size_override("font_size",21)
	col.add_child(event_menu)
	button(col,"Pornește evenimentul de test",func() -> void:
		var id: String = str(Events.definitions()[event_menu.selected].id)
		result(map.game.start_event(id)))
	var stops := row(col)
	button(stops,"Oprește",func() -> void: result(map.game.stop_event(false)))
	button(stops,"Resetează tot",func() -> void: result(map.game.stop_event(true)))
	label(col,"Setează manual punctele")
	var points_row := row(col)
	var points := number(points_row,1000000,0)
	button(points_row,"Setează",func() -> void: result(map.game.set_event_points(int(points.value))))
	label(col,"Simulează aterizarea pe categorie (fără mutare, fără premiul căsuței)")
	var kinds := row(col)
	for kind in ["crystal","construction","magic","coin","quest"]:
		button(kinds,{"crystal":"Cristal","construction":"Constr.","magic":"Magie","coin":"Monede","quest":"Jetoane"}[kind],func() -> void:
			var gained: int = map.game.simulate_event_landing(kind)
			result(gained >= 0)
			event_report.text = "Aterizare simulată pe «%s»: +%d puncte" % [kind,gained])
	label(col,"Forțează pragul de recompensă (setează punctele la prag)")
	var thresholds := row(col)
	for def: Dictionary in Events.definitions():
		for item: Dictionary in def.milestones:
			button(thresholds,str(int(item.points)),func() -> void: result(map.game.force_milestone(str(item.id))))
		break
	label(col,"Simulează expirarea")
	var expire := row(col)
	button(expire,"Început revendicare",func() -> void: result(map.game.expire_event("claiming")))
	button(expire,"Închis complet",func() -> void:
		result(map.game.expire_event("closed"))
		map.game.close_expired_events()
		sync_map())
	label(col,"Verifică revendicările duplicate (copie izolată, pentru fiecare prag)")
	button(col,"Rulează testul",func() -> void:
		var lines := PackedStringArray()
		if map.game.state.event.is_empty():
			event_report.text = "Pornește mai întâi un eveniment."
			return
		for item: Dictionary in Events.definition(str(map.game.state.event.id)).milestones:
			var report: Dictionary = map.game.duplicate_claim_test(str(item.id))
			lines.append("%s: prima=%s · a doua refuzată=%s · stare neschimbată=%s · energie +%d" % [item.id,report.first_granted,report.second_refused,report.state_unchanged_by_second,int(report.energy_gain)])
		event_report.text = "\n".join(lines))
	event_report = text_area(col,260)

func _visual(col: Node) -> void:
	label(col,"Efecte vizuale · numai pentru verificare. Nu modifică economia, salvarea sau probabilitățile.")
	visual_status = label(col,"")
	for entry in [["Efecte ambientale (licurici, praf, frunze, sclipiri)","ambient"],["Efecte speciale (inele, particule, emoții)","special"],["Bloom și grad de culoare","post"]]:
		var toggle := CheckButton.new()
		toggle.text = entry[0]
		toggle.custom_minimum_size.y = 58
		toggle.add_theme_font_size_override("font_size",20)
		toggle.button_pressed = bool(map.polish.get(entry[1] + "_on"))
		toggle.toggled.connect(func(on: bool) -> void:
			map.polish.set_toggle(entry[1],on)
			refresh_data())
		col.add_child(toggle)
	var sparks := CheckButton.new()
	sparks.text = "Scântei pe butoane și contoare"
	sparks.custom_minimum_size.y = 58
	sparks.add_theme_font_size_override("font_size",20)
	sparks.button_pressed = map.hud.sparks_enabled
	sparks.toggled.connect(func(on: bool) -> void: map.hud.sparks_enabled = on)
	col.add_child(sparks)
	label(col,"Calitate efecte (numai în această sesiune)")
	var tiers := OptionButton.new()
	for title in ["Redusă","Medie","Ridicată"]:
		tiers.add_item(title)
	tiers.select(map.hud.prefs.quality)
	tiers.custom_minimum_size.y = 58
	tiers.add_theme_font_size_override("font_size",21)
	tiers.item_selected.connect(func(index: int) -> void:
		map.hud.prefs.quality = index
		map.apply_preferences()
		refresh_data())
	col.add_child(tiers)
	label(col,"Ruletă Magică")
	visual_prize = OptionButton.new()
	visual_prize.add_item("Premiu aleatoriu")
	for item: Dictionary in Crystal.prizes():
		visual_prize.add_item(str(item.label))
	visual_prize.custom_minimum_size.y = 58
	visual_prize.add_theme_font_size_override("font_size",21)
	col.add_child(visual_prize)
	button(col,"Testează ruleta cu premiul ales",func() -> void:
		if map.game.busy or not map.game.pending_spin().is_empty() or map.chest_screen.is_open():
			status.text = "Așteaptă finalul operației."
			return
		var id: String = "" if visual_prize.selected <= 0 else str(Crystal.prizes()[visual_prize.selected - 1].id)
		if not map.game.force_prize(id) or not map.game.charge_crystal():
			result(false)
			return
		sync_map()
		close_panel()
		map.open_crystal())
	label(col,"Cufere")
	var chest_row := row(col)
	for kind in ["wood","silver","gold"]:
		button(chest_row,{"wood":"Lemn","silver":"Argint","gold":"Aur"}[kind],func() -> void:
			if map.game.busy or not map.game.pending_open().is_empty():
				status.text = "Așteaptă finalul operației."
				return
			if int(map.game.state.chests[kind]) < 1 and not map.game.add_chests(kind,1):
				result(false)
				return
			close_panel()
			sync_map()
			map.open_chest(kind))
	label(col,"DEMONSTRAȚIE VIZUALĂ · câștig resurse. Nu modifică soldul; pentru valori reale folosește «Resurse».")
	var gains := row(col)
	for entry in [["Monede","coins",125],["Cristale","fragments",8],["Energie","energy",10],["Puncte","build_points",5]]:
		button(gains,entry[0],func() -> void:
			close_panel()
			map.debug_gain(entry[1],entry[2]))
	label(col,"Alte efecte")
	var misc := row(col)
	button(misc,"Aterizare",func() -> void:
		close_panel()
		map.debug_landing_effect(false))
	button(misc,"Aterizare rară",func() -> void:
		close_panel()
		map.debug_landing_effect(true))
	var misc2 := row(col)
	button(misc2,"START",func() -> void:
		close_panel()
		map.debug_start_effect())
	button(misc2,"Upgrade",func() -> void:
		close_panel()
		map.debug_upgrade_effect(0))
	var crystal_row := row(col)
	button(crystal_row,"Puls cristal",func() -> void:
		close_panel()
		map.debug_crystal_pulse(false))
	button(crystal_row,"Cristal gata",func() -> void:
		close_panel()
		map.debug_crystal_pulse(true))

## Etapa 4.2: every animation and the three WOW moments on demand, plus presentation switches.
## Effects are visual; actions that need a real transaction (roll, wheel, chest) use this DEBUG profile.
func _moments(col: Node) -> void:
	label(col,"Animații și momente · numai profilul DEBUG. Aruncarea, ruleta și cuferele folosesc tranzacțiile reale ale acestui profil.")
	label(col,"Comutatoare de prezentare")
	for entry in [["Animații ambientale (vânt, apă, fum, păsări, licurici)","ambient"],["Particule și efecte speciale","special"],
		["Efecte de lumină (bloom, grad de culoare)","post"]]:
		var toggle := CheckButton.new()
		toggle.text = entry[0]
		toggle.custom_minimum_size.y = 58
		toggle.add_theme_font_size_override("font_size",20)
		toggle.button_pressed = bool(map.polish.get(entry[1] + "_on"))
		toggle.toggled.connect(func(on: bool) -> void: map.set_presentation(entry[1],on))
		col.add_child(toggle)
	var camera_toggle := CheckButton.new()
	camera_toggle.text = "Mișcare cinematică a camerei"
	camera_toggle.custom_minimum_size.y = 58
	camera_toggle.add_theme_font_size_override("font_size",20)
	camera_toggle.button_pressed = map.camera.motion < 2
	camera_toggle.toggled.connect(func(on: bool) -> void: map.set_presentation("camera",on))
	col.add_child(camera_toggle)
	var sound_toggle := CheckButton.new()
	sound_toggle.text = "Sunete"
	sound_toggle.custom_minimum_size.y = 58
	sound_toggle.add_theme_font_size_override("font_size",20)
	sound_toggle.button_pressed = map.sounds.effects_enabled
	sound_toggle.toggled.connect(func(on: bool) -> void: map.set_presentation("sound",on))
	col.add_child(sound_toggle)
	var tiers := row(col)
	for i in range(3):
		button(tiers,["Low","Medium","High"][i],func() -> void:
			map.hud.prefs.quality = i
			map.apply_preferences()
			refresh_data())
	label(col,"Secvența de aruncare")
	var dice_row := row(col)
	button(dice_row,"Zaruri (numai vizual)",func() -> void:
		close_panel()
		map.debug_dice())
	button(dice_row,"Aruncare + urmărire",play_roll)
	var land_row := row(col)
	button(land_row,"Aterizare",func() -> void:
		close_panel()
		map.debug_landing_effect(false))
	button(land_row,"Premiu obișnuit",func() -> void:
		close_panel()
		map.debug_gain("coins",100))
	button(land_row,"Premiu special",func() -> void:
		close_panel()
		map.debug_gain("coins",150)
		map.debug_landing_effect(true))
	var start_row := row(col)
	button(start_row,"Bonus START",func() -> void:
		close_panel()
		map.debug_start_effect())
	button(start_row,"Upgrade + Pongo",func() -> void:
		close_panel()
		map.debug_upgrade_effect(2)
		map.pongo_cameo(2))
	label(col,"Lerik")
	var clips := row(col)
	for clip in ["surprise","confused","wobble"]:
		button(clips,clip,func() -> void:
			close_panel()
			map.animator.play(clip))
	var clips2 := row(col)
	for clip in ["goggles","stretch","land_big"]:
		button(clips2,clip,func() -> void:
			close_panel()
			map.animator.play(clip))
	button(col,"Pufi strănută lângă Lerik",func() -> void:
		close_panel()
		map.pufi_cameo())
	label(col,"Super Cristal, ruletă, cufere")
	var crystal_row := row(col)
	button(crystal_row,"Cristal încărcat",func() -> void:
		close_panel()
		map.debug_crystal_pulse(true))
	button(crystal_row,"Activare cristal",func() -> void:
		if map.game.busy or not map.game.pending_spin().is_empty():
			return
		if map.game.charge_crystal():
			sync_map()
			close_panel()
			map.open_crystal())
	var prizes := row(col)
	for entry in [["Energie","energy_30"],["Lemn","chest_wood"],["Argint","chest_silver"],["Aur","chest_gold"]]:
		button(prizes,entry[0],func() -> void:
			if map.game.busy or not map.game.pending_spin().is_empty():
				return
			if map.game.force_prize(entry[1]) and map.game.charge_crystal():
				sync_map()
				close_panel()
				map.open_crystal())
	var opens := row(col)
	for kind in ["wood","silver","gold"]:
		button(opens,"Deschide " + {"wood":"lemn","silver":"argint","gold":"aur"}[kind],func() -> void:
			if map.game.busy or not map.game.pending_open().is_empty():
				return
			if int(map.game.state.chests[kind]) < 1:
				map.game.add_chests(kind,1)
			close_panel()
			sync_map()
			map.open_chest(kind))
	button(col,"Carte rară (cufăr de aur, rarități forțate)",func() -> void:
		if map.game.busy or not map.game.pending_open().is_empty():
			return
		map.game.force_rarity("rare")
		if int(map.game.state.chests.gold) < 1:
			map.game.add_chests("gold",1)
		close_panel()
		sync_map()
		map.open_chest("gold"))
	label(col,"Momentele WOW")
	button(col,"1 · Trezirea regatului",func() -> void:
		close_panel()
		map.awaken())
	button(col,"2 · Scufundarea în cristal (spre ruletă)",func() -> void:
		if map.game.busy or not map.game.pending_spin().is_empty():
			return
		if map.game.charge_crystal():
			sync_map()
			close_panel()
			map.open_crystal())
	button(col,"3 · Ceremonia cufărului de aur",func() -> void:
		if map.game.busy or not map.game.pending_open().is_empty():
			return
		if int(map.game.state.chests.gold) < 1:
			map.game.add_chests("gold",1)
		close_panel()
		sync_map()
		map.open_chest("gold")
		map.chest_screen.open_button.pressed.emit())

func _confirmed_reset() -> void:
	if pending_part.is_empty():
		result(map.game.reset_profile(true))
	else:
		var part := pending_part
		pending_part = ""
		result(map.game.reset_part(part,true))

func text_area(parent: Node, height: float) -> TextEdit:
	var item := TextEdit.new()
	item.editable = false
	item.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	item.custom_minimum_size.y = height
	item.add_theme_font_size_override("font_size",19)
	parent.add_child(item)
	return item

func _diagnostics(col: Node) -> void:
	button(col,"Salvează profilul DEBUG",func() -> void: result(map.game.save_manual()))
	button(col,"Încarcă profilul DEBUG",func() -> void:
		if map.game.busy:
			return
		var loaded := Profile.new()
		if loaded.state.is_empty():
			status.text = loaded.error
			return
		map.game = loaded
		result(true))
	button(col,"Snapshot DEBUG · salvează starea",func() -> void: result(map.game.checkpoint()))
	button(col,"Snapshot DEBUG · restaurează",func() -> void: result(map.game.restore_checkpoint()))
	button(col,"Exportă diagnostic JSON",func() -> void:
		var ok: bool = map.game.write_json("diagnostic.json",{"state":map.game.state,"simulation":last_simulation,
			"super_crystal_implemented":true,"engine":Engine.get_version_info(),"profile":"local_debug"})
		status.text = "Exportat în "+ProjectSettings.globalize_path(Profile.ROOT+"diagnostic.json") if ok else "Exportul a eșuat.")
	button(col,"Resetează tot profilul DEBUG…",func() -> void:
		pending_part = ""
		confirmation.title = "Resetare profil DEBUG"
		confirmation.dialog_text = "Resetezi resursele, nivelurile și poziția profilului local de dezvoltare?"
		confirmation.popup_centered())
	label(col,"Resetare selectivă (cu confirmare, numai profilul DEBUG)")
	reset_part_menu = OptionButton.new()
	for key: String in Profile.RESET_PARTS:
		reset_part_menu.add_item(Profile.RESET_PARTS[key])
	reset_part_menu.custom_minimum_size.y = 58
	reset_part_menu.add_theme_font_size_override("font_size",21)
	col.add_child(reset_part_menu)
	button(col,"Resetează partea aleasă…",func() -> void:
		pending_part = Profile.RESET_PARTS.keys()[reset_part_menu.selected]
		confirmation.title = "Resetare selectivă"
		confirmation.dialog_text = "Resetezi «%s» în profilul DEBUG? Restul rămâne neschimbat." % Profile.RESET_PARTS[pending_part]
		confirmation.popup_centered())
	label(col,"Istoricul ultimelor tranzacții")
	history_view = text_area(col,300)
	label(col,"Starea completă (JSON)")
	diagnostic = text_area(col,460)

func _simulations(col: Node) -> void:
	label(col,"Simulări izolate, aceleași zaruri și tranzacții. Compară nivelurile curente cu nivelul 0 folosind aceeași sămânță. Energia se reumple cu 100 numai la epuizare și este raportată separat.")
	for count in [100,1000,10000]:
		button(col,"Simulează %d aruncări" % count,start_simulation.bind(count))
	button(col,"Oprește simularea",func() -> void:
		if simulation != null:
			simulation.cancelled = true)
	sim_result = text_area(col,420)

func start_simulation(count: int) -> void:
	if simulation != null or map.game.busy:
		status.text = "O operație este deja în curs."
		return
	simulation = Simulation.new()
	status.text = "Simulare în curs…"
	last_simulation = await simulation.run(map.game.state.duplicate(true),count,get_tree())
	simulation = null
	sim_result.text = JSON.stringify(last_simulation,"  ")
	if is_instance_valid(travel_sim):
		travel_sim.text = sim_result.text
	status.text = "Simulare încheiată. Rezultatul poate fi exportat din Diagnostic."

func refresh_data() -> void:
	if active and is_instance_valid(crystal_status):
		var s: Dictionary = map.game.state
		crystal_status.text = "Încărcare %d/%d · rotiri %d · %s" % [Crystal.charge(s),Crystal.target(s),int(s.crystal_activations),"GATA" if Crystal.is_ready(s) else "în încărcare"]
		if not s.last_spin.is_empty():
			crystal_status.text += "\nUltima rotire #%d · %s · %s" % [int(s.last_spin.id),Crystal.describe(s.last_spin),"afișată" if s.last_spin.presented else "neafișată"]
		chest_status.text = "Lemn %d · Argint %d · Aur %d" % [int(s.chests.wood),int(s.chests.silver),int(s.chests.gold)]
		if not recovery_probe.is_empty():
			var probe: Dictionary = recovery_probe
			chest_status.text += "\nTest recuperare #%d · energie înainte %d, acum %d · cufere înainte %s" % [int(probe.receipt.id),int(probe.energy_before),int(s.energy),str(probe.chests_before)]
	if active and is_instance_valid(visual_status):
		visual_status.text = "FPS %d · efecte active %d · calitate %d · ambient %s · speciale %s · bloom %s" % [Engine.get_frames_per_second(),map.polish.active_effects(),
			map.polish.tier,"da" if map.polish.ambient_active() else "nu","da" if map.polish.special_active() else "nu","da" if map.polish.environment != null and map.polish.environment.glow_enabled else "nu"]
	if active and is_instance_valid(card_status):
		card_status.text = map.game.cards_summary()
		if not card_probe.is_empty():
			var copies_now := Cards.total_copies(map.game.state)
			card_status.text += "\nTest restart #%d · exemplare înainte %d, acum %d (așteptat +%d) · cufere argint înainte %d, acum %d" % [int(card_probe.receipt.id),
				int(card_probe.copies_before),copies_now,Cards.chest_size("silver"),int(card_probe.chests_before.silver),int(map.game.state.chests.silver)]
	if active and is_instance_valid(energy_status):
		_refresh_live()
		charge_value.value = Crystal.charge(map.game.state)
		spin_history_view.text = map.game.spin_history_text()
		history_view.text = map.game.history_text()
	if active and is_instance_valid(diagnostic):
		diagnostic.text = JSON.stringify(map.game.state,"  ")
	if active:
		for key: String in balance_labels:
			balance_labels[key].text = "Sold actual: %d" % int(map.game.state.wallet[key])
		status.text = "DEBUG · căsuța %d · energie %d · niveluri %s" % [map.game.state.board_position_index,map.game.state.energy,str(map.game.state.levels)]

## Energy and event read-outs, refreshed twice a second while the panel is open.
func _refresh_live() -> void:
	var info: Dictionary = map.game.regen_info()
	var next_text := "suspendată (energie ≥ %d)" % Energy.capacity() if int(info.to_next) < 0 else "+1 în %s" % map.event_screen.time_text(int(info.to_next))
	energy_status.text = "Energie %d/%d · regenerare %s · %s · plin în %s · ceas simulat %+d s" % [info.energy,Energy.capacity(),
		"ACTIVĂ" if info.enabled else "OPRITĂ",next_text,map.event_screen.time_text(int(info.to_full)),int(info.skew)]
	var ev: Dictionary = map.game.state.event
	var now: int = map.game.clock()
	if ev.is_empty():
		event_status.text = "Niciun eveniment activ. Arhivă: %d." % map.game.state.event_history.size()
	else:
		var def := Events.definition(str(ev.id))
		var upcoming := Events.next_milestone(ev)
		event_status.text = "%s · %s · puncte %d · timp rămas %s · revendicate %s · următorul prag %s · Moara +%d%%" % [def.name,Events.status(ev,now),
			int(ev.points),map.event_screen.time_text(Events.remaining(ev,now)),str(ev.claimed),
			"—" if upcoming.is_empty() else str(int(upcoming.points)),Events.mill_percent(map.game.mill_level())]

func _process(delta: float) -> void:
	if not active or not cover.visible or not is_instance_valid(energy_status):
		return
	live_age += delta
	if live_age >= 0.5:
		live_age = 0.0
		_refresh_live()

func _exit_tree() -> void:
	if simulation != null:
		simulation.cancelled = true
