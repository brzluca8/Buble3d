extends CanvasLayer
const Profile := preload("res://scripts/developer/dev_profile.gd")
const Simulation := preload("res://scripts/developer/economy_simulation.gd")
const Crystal := preload("res://scripts/crystal/super_crystal_service.gd")
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
	if not active:
		label(layout,"Intră în profilul DEBUG separat pentru a testa resurse, zaruri și clădiri.")
		button(layout,"Intră în profilul de dezvoltare",switch_profile.bind(true))
	else:
		button(layout,"Înapoi la progresul normal",switch_profile.bind(false))
		section = OptionButton.new()
		section.custom_minimum_size.y = 58
		section.add_theme_font_size_override("font_size",23)
		layout.add_child(section)
		var names := ["Resurse","Zaruri și traseu","Clădiri","Super Cristal și cufere","Salvări și diagnostic","Simularea economiei"]
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
		_travel(pages[1].get_child(0))
		_buildings(pages[2].get_child(0))
		_future(pages[3].get_child(0))
		_diagnostics(pages[4].get_child(0))
		_simulations(pages[5].get_child(0))
		section.item_selected.connect(show_page)
		show_page(0)
		map.hud.roll_requested.connect(apply_speed)
	confirmation = ConfirmationDialog.new()
	confirmation.title = "Resetare profil DEBUG"
	confirmation.dialog_text = "Resetezi resursele, nivelurile și poziția profilului local de dezvoltare?"
	confirmation.ok_button_text = "Resetează DEBUG"
	confirmation.cancel_button_text = "Anulează"
	confirmation.confirmed.connect(func() -> void: result(map.game.reset_profile(true)))
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
	if map.game.busy or map.wheel_open():
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
		if not recovery_probe.is_empty():
			panel.recovery_probe = recovery_probe
			panel.status.text = "Repornit. Premiul confirmat #%d trebuie să apară o singură dată." % int(recovery_probe.receipt.id)
		if open_after:
			panel.open_panel()
	previous.queue_free()

func result(ok: bool) -> void:
	if not ok:
		status.text = map.game.error if not map.game.error.is_empty() else "Operație refuzată. Verifică valorile sau așteaptă oprirea."
		return
	sync_map()
	status.text = "Profil DEBUG actualizat."
	refresh_data()

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
	label(col,"Valorile se aplică numai profilului DEBUG.")
	for key: String in ["coins","fragments","energy","build_points","quest_tokens"]:
		label(col,{"coins":"Monede","fragments":"Fragmente","energy":"Energie (0–100)","build_points":"Puncte de construcție","quest_tokens":"Jetoane de aventură"}[key])
		var controls := row(col)
		var initial: int = map.game.state.energy if key == "energy" else map.game.state.wallet[key]
		var value := number(controls,100 if key == "energy" else 1000000000,initial)
		button(controls,"Setează",func() -> void: result(map.game.set_resource(key,int(value.value))))
		if key == "coins":
			button(controls,"Adaugă",func() -> void: result(map.game.set_resource(key,int(value.value),true)))
		button(controls,"Zero",func() -> void: result(map.game.set_resource(key,0)))
	label(col,"Test separat cu energie peste plafon, pe o copie în memorie.")
	var extra := number(col,10000,150)
	extra.min_value = 101
	button(col,"Testează energia peste plafon",func() -> void:
		status.text = JSON.stringify(map.game.energy_overflow_test(int(extra.value))))

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

func _future(col: Node) -> void:
	var rules: Dictionary = Crystal.config()
	label(col,"Super Cristal · prima rotire la %d aruncări, următoarele la %d. Valorile afectează numai profilul DEBUG." % [int(rules.first_target),int(rules.later_target)])
	crystal_status = label(col,"")
	button(col,"Încarcă instantaneu cristalul",func() -> void: result(map.game.charge_crystal()))
	var presets := row(col)
	button(presets,"49/50",func() -> void: result(map.game.set_crystal(49,0)))
	button(presets,"99/100",func() -> void: result(map.game.set_crystal(99,maxi(1,int(map.game.state.crystal_activations)))))
	button(presets,"0 progres",func() -> void: result(map.game.set_crystal(0,int(map.game.state.crystal_activations))))
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
	sim_wheel = text_area(col,300)
	label(col,"Inventar cufere")
	chest_status = label(col,"")
	var chest_row := row(col)
	button(chest_row,"+1 lemn",func() -> void: result(_add_chest("wood")))
	button(chest_row,"+1 argint",func() -> void: result(_add_chest("silver")))
	button(chest_row,"+1 aur",func() -> void: result(_add_chest("gold")))
	button(col,"Golește cuferele",func() -> void: result(map.game.set_chests(0,0,0)))
	label(col,"Recuperare după restart: salvează o rotire fără animație, apoi repornește scena. Premiul trebuie afișat o singură dată, fără a fi acordat din nou.")
	button(col,"Testează recuperarea după restart",test_recovery)
	for title in ["Deschide cufăr","Generează cărți","Adaugă duplicate","Completează colecția","Testează recompensa albumului"]:
		var control := button(col,title+" · indisponibil",func() -> void: pass)
		control.disabled = true
		control.tooltip_text = "Albumul și deschiderea cuferelor vor fi implementate într-o etapă viitoare."

func _add_chest(kind: String) -> bool:
	var next: Dictionary = map.game.state.chests.duplicate()
	next[kind] = int(next[kind]) + 1
	return map.game.set_chests(int(next.wood),int(next.silver),int(next.gold))

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
	button(col,"Păstrează checkpoint de test",func() -> void: result(map.game.checkpoint()))
	button(col,"Restaurează checkpointul de test",func() -> void: result(map.game.restore_checkpoint()))
	button(col,"Exportă diagnostic JSON",func() -> void:
		var ok: bool = map.game.write_json("diagnostic.json",{"state":map.game.state,"simulation":last_simulation,
			"super_crystal_implemented":true,"engine":Engine.get_version_info(),"profile":"local_debug"})
		status.text = "Exportat în "+ProjectSettings.globalize_path(Profile.ROOT+"diagnostic.json") if ok else "Exportul a eșuat.")
	button(col,"Resetează profilul DEBUG…",func() -> void: confirmation.popup_centered())
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
	if active and is_instance_valid(diagnostic):
		diagnostic.text = JSON.stringify(map.game.state,"  ")
	if active:
		status.text = "DEBUG · căsuța %d · energie %d · niveluri %s" % [map.game.state.board_position_index,map.game.state.energy,str(map.game.state.levels)]

func _exit_tree() -> void:
	if simulation != null:
		simulation.cancelled = true
