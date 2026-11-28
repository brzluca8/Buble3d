extends SceneTree
## Etapa 4.3 · build points end to end: landing reward per Workshop level, wallet, HUD counter,
## Bag, upgrade panel, build-points window, Developer Panel edits, upgrades with every shortage,
## save/load, normal vs DEBUG separation, interrupted walks and the portrait top bar layout.
const BOARD := preload("res://scenes/board.tscn")
const Profile := preload("res://scripts/developer/dev_profile.gd")
const Save := preload("res://scripts/board/board_save.gd")
const ECONOMY := preload("res://assets/board/economy.tres")
const RULES := preload("res://assets/board/rules.tres")
const Hud := preload("res://scripts/board/board_hud.gd")
const Screen := preload("res://scripts/board/build_points_screen.gd")
var checks := 0
var failures := 0
var map: Node


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		push_error(description)
		failures += 1


func frames(count := 2) -> void:
	for i in range(count):
		await process_frame


func gain_badges() -> Array:
	return map.hud.flights.get_children().filter(func(node: Node) -> bool: return node.has_meta("gain") and not node.is_queued_for_deletion())


func snapshot(path: String) -> String:
	return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""


func _run() -> void:
	texts()
	var normal := Save.new("user://construction_normal")
	normal.state.wallet.build_points = 31
	normal._commit(normal.state.duplicate(true))
	var normal_hash := [snapshot(normal._path(0)),snapshot(normal._path(1))]
	root.size = Vector2i(720,1280)
	map = BOARD.instantiate()
	map.save_prefix = Profile.PREFIX
	root.add_child(map)
	await frames()
	var game: Profile = map.game
	check(game.reset_profile(true),"Profil DEBUG inițializat")
	map.get_node("DeveloperPanel").sync_map()
	await landing_rewards(game)
	await developer_edits(game)
	await upgrades(game)
	await build_window(game)
	await interrupted(game)
	await layout()
	check(snapshot(normal._path(0)) == normal_hash[0] and snapshot(normal._path(1)) == normal_hash[1],"Profilul normal rămâne neatins de DEBUG")
	check(Save.new("user://construction_normal").state.wallet.build_points == 31,"Soldul normal se încarcă separat")
	map.free()
	print("Construcție 4.3: %d verificări, %d erori." % [checks,failures])
	quit(1 if failures else 0)


## Wording of counts and shortages.
func texts() -> void:
	check(ECONOMY.amount_text("coins",1) == "1 monedă" and ECONOMY.amount_text("coins",19) == "19 monede","Numerale sub 20")
	check(ECONOMY.amount_text("coins",892) == "892 de monede" and ECONOMY.amount_text("coins",101) == "101 monede" and ECONOMY.amount_text("coins",200) == "200 de monede","Numerale cu «de»")
	check(Hud.shortage_text(892,0) == "Îți lipsesc 892 de monede.","Lipsă monede")
	check(Hud.shortage_text(0,5) == "Îți lipsesc 5 puncte de construcție.","Lipsă puncte")
	check(Hud.shortage_text(0,1) == "Îți lipsește 1 punct de construcție.","Lipsă un punct")
	check(Hud.shortage_text(10,25) == "Îți lipsesc 10 monede și 25 de puncte de construcție.","Lipsă ambele")
	check(Hud.shortage_text(0,0) == "","Fără lipsă")
	for level in range(4):
		check(Screen.tile_reward(level) == [2,3,4,5][level],"Tabel recompense Atelier nivel %d" % level)


func land_on_construction(game: Profile) -> int:
	# Tile 5 is a construction tile in the authored layout; 3 + (1+1) lands there.
	check(ECONOMY.kind(5,RULES.tile_count) == "construction","Căsuța 5 are ciocan")
	check(game.set_resource("energy",50) and game.teleport(3),"Poziție de test")
	map.get_node("DeveloperPanel").sync_map()
	await frames()
	var before := int(game.state.wallet.build_points)
	game.force_pair(Vector2i(1,1))
	map._roll()
	return before


func landing_rewards(game: Profile) -> void:
	var slot: int = game.building_slot("left_mid")
	for level in range(4):
		check(game.set_level(slot,level),"Atelier nivel %d" % level)
		var before := await land_on_construction(game)
		var expected: int = [2,3,4,5][level]
		check(int(game.state.wallet.build_points) == before + expected,"Wallet +%d la nivelul %d" % [expected,level])
		check(game.state.last_roll.landing == {"resource":"build_points","amount":expected},"Chitanța aterizării nivel %d" % level)
		check(map.hud.shown.build_points == before and map.hud.build_stat.text == str(before),"HUD ascunde premiul până la aterizare")
		map.hud.skip.pressed.emit()
		await frames()
		var now := int(game.state.wallet.build_points)
		check(not game.busy and map.hud.build_stat.text == str(now),"HUD sincronizat după aterizare nivel %d" % level)
		check(map.hud.build_stat.accessibility_name.ends_with(str(now)),"Nume accesibil cu soldul real")
		check(map.hud.inventory.text.contains("Puncte de construcție   %d" % now),"Sacul arată soldul")
		var badges: Array = gain_badges()
		var spelled := false
		for badge: Node in badges:
			for label: Node in badge.find_children("*","Label",true,false):
				spelled = spelled or (label as Label).text == "+%d puncte de construcție" % expected
		check(spelled,"Indicator «+%d puncte de construcție»" % expected)
		check(Save.new(Profile.PREFIX).state.wallet.build_points == now,"Salvat și reîncărcat nivel %d" % level)
	# The Workshop panel reads the new level and the hammer tiles of the whole loop.
	map._select_at(map.camera.unproject_position(map.plots.get_child(slot).position + Vector3.UP*0.3))
	await frames()
	check(map.selected_plot == slot and map.hud.level_line.text.begins_with("MAXIM") and map.hud.bonus_now.text == "+5 puncte de construcție","Atelier la maxim în panou")
	check(map.hud.price.text.contains("%d căsuțe cu ciocan" % ECONOMY.tiles_for("left_mid",RULES.tile_count).size()),"Bonus global pe toate căsuțele")
	map._deselect()
	game.set_level(slot,0)
	map.get_node("DeveloperPanel").sync_map()


func developer_edits(game: Profile) -> void:
	var panel = map.get_node("DeveloperPanel")
	panel.open_panel()
	panel.show_page(0)
	await frames()
	# Rows follow the order coins, fragments, build_points, quest_tokens.
	var field: SpinBox = panel.pages[0].find_children("*","SpinBox",true,false)[2]
	# Text typed without pressing Enter must still be the value used.
	field.get_line_edit().clear()
	field.get_line_edit().insert_text_at_caret("777")
	panel.change_resource("build_points",field,"set")
	await frames()
	check(game.state.wallet.build_points == 777 and map.hud.build_stat.text == "777","Setează: wallet și HUD")
	check(panel.notice.visible and panel.notice.text.contains("setat la 777") and panel.notice.text.contains("→ 777"),"Confirmare după Setează")
	check(panel.balance_labels.build_points.text == "Sold actual: 777","Soldul din panou")
	panel.refresh_data()
	panel.show_page(1)
	panel.show_page(0)
	check(panel.notice.text.contains("setat la 777"),"Confirmarea persistă după reîmprospătare")
	field.value = 23
	panel.change_resource("build_points",field,"add")
	await frames()
	check(game.state.wallet.build_points == 800 and map.hud.build_stat.text == "800" and panel.notice.text.contains("adăugat 23"),"Adaugă")
	check(map.hud.inventory.text.contains("Puncte de construcție   800"),"Sac după Adaugă")
	panel.change_resource("build_points",field,"zero")
	await frames()
	check(game.state.wallet.build_points == 0 and map.hud.build_stat.text == "0" and panel.notice.text.contains("pus pe zero"),"Zero")
	check(Save.new(Profile.PREFIX).state.wallet.build_points == 0,"Zero salvat")
	game.busy = true
	panel.change_resource("build_points",field,"set")
	check(panel.notice.text.begins_with("✖") and game.state.wallet.build_points == 0,"Refuz vizibil când jocul e ocupat")
	game.busy = false
	# The visual-only demo never changes a balance nor pops a counter.
	var before: Dictionary = game.state.duplicate(true)
	var shown_badges := gain_badges().size()
	panel.close_panel()
	map.debug_gain("build_points",5)
	await frames()
	check(game.state == before and map.hud.build_stat.text == "0","Demonstrația nu modifică soldul")
	check(gain_badges().size() == shown_badges,"Demonstrația nu afișează un câștig real")


func upgrade_state(game: Profile, slot: int, coins: int, points: int) -> void:
	game.set_resource("coins",coins)
	game.set_resource("build_points",points)
	map._select_at(map.camera.unproject_position(map.plots.get_child(slot).position + Vector3.UP*0.3))
	await frames()


func upgrades(game: Profile) -> void:
	var slot := 4
	check(game.set_level(slot,1),"Piața nivel 1")
	map.get_node("DeveloperPanel").sync_map()
	var cost: Dictionary = game.cfg.buildings.costs_to_reach_level["2"]
	var cases := [[cost.coins + 7,cost.build_points + 3,""],
		[cost.coins - 892,cost.build_points,"Îți lipsesc 892 de monede."],
		[cost.coins,cost.build_points - 5,"Îți lipsesc 5 puncte de construcție."],
		[cost.coins - 10,cost.build_points - 1,"Îți lipsesc 10 monede și 1 punct de construcție."]]
	for entry: Array in cases:
		check(game.set_level(slot,1),"Nivel de pornire")
		await upgrade_state(game,slot,int(entry[0]),int(entry[1]))
		var hud: Node = map.hud
		check(hud.confirm.visible and hud.confirm.disabled == not str(entry[2]).is_empty(),"Buton după resurse: " + str(entry))
		check(hud.shortage.text == entry[2] and hud.shortage.visible == not str(entry[2]).is_empty(),"Mesaj exact: " + str(entry[2]))
		check(hud.cost_values.coins.text == "%d / %d" % [entry[0],cost.coins] and hud.cost_values.build_points.text == "%d / %d" % [entry[1],cost.build_points],"Disponibil / necesar")
		check(hud.cost_states.coins.text.contains("insuficient" if int(entry[0]) < int(cost.coins) else "suficient"),"Stare monede")
		check(hud.cost_states.build_points.text.contains("insuficient" if int(entry[1]) < int(cost.build_points) else "suficient"),"Stare puncte")
		var wallet: Dictionary = game.state.wallet.duplicate()
		map._upgrade(slot,1)
		await frames()
		if str(entry[2]).is_empty():
			check(game.state.levels[slot] == 2 and game.state.wallet.coins == wallet.coins - cost.coins and game.state.wallet.build_points == wallet.build_points - cost.build_points,"Upgrade deduce exact ambele resurse")
			check(map.hud.build_stat.text == str(game.state.wallet.build_points) and map.hud.bonus_now.text == "+125 de monede","HUD și panou după upgrade")
			check(Save.new(Profile.PREFIX).state.wallet.build_points == wallet.build_points - cost.build_points,"Deducerea salvată")
		else:
			check(game.state.levels[slot] == 1 and game.state.wallet == wallet,"Upgrade refuzat fără cost")
		map._deselect()
	check(game.set_level(slot,3),"Nivel maxim")
	await upgrade_state(game,slot,99999,999)
	check(map.hud.level_line.text.begins_with("MAXIM") and not map.hud.confirm.visible and not map.hud.cost_box.visible and map.hud.bonus_now_caption.text == "Bonus final","Ecran MAXIM fără buton activ")
	var wallet: Dictionary = game.state.wallet.duplicate()
	map._upgrade(slot,3)
	check(game.state.levels[slot] == 3 and game.state.wallet == wallet,"Nicio plată peste maxim")
	map._deselect()


func build_window(game: Profile) -> void:
	var slot: int = game.building_slot("left_mid")
	game.set_level(slot,2)
	game.set_resource("build_points",64)
	map.get_node("DeveloperPanel").sync_map()
	map.hud.build_stat.pressed.emit()
	await frames(3)
	var screen: Screen = map.build_screen
	check(screen.is_open(),"Ciocanul deschide fereastra")
	check(screen.balance.text == "64","Fereastra arată soldul real")
	check(screen.reward.text.begins_with("+4 puncte de construcție"),"Recompensa după nivelul Atelierului")
	check(screen.reward_next.text.contains("La nivelul 3: +5"),"Recompensa următoare")
	check(screen.note.text.contains("tuturor căsuțelor de construcție"),"Mențiunea bonusului global")
	check(screen.sources.text.contains("%d căsuțe cu ciocan" % ECONOMY.tiles_for("left_mid",RULES.tile_count).size()),"Numărul de căsuțe citit din traseu")
	var rect: Rect2 = screen.panel.get_global_rect()
	check(Rect2(Vector2.ZERO,Vector2(root.size)).encloses(rect),"Fereastra încape pe ecran")
	game.set_resource("build_points",70)
	map._refresh()
	check(screen.balance.text == "70","Fereastra se actualizează când soldul se schimbă")
	var roll_before: Dictionary = game.state.duplicate(true)
	map._roll()
	check(game.state == roll_before,"Fereastra blochează aruncarea")
	screen.close()
	await create_timer(0.3).timeout
	check(not screen.is_open(),"Fereastra se închide")


## A walk interrupted by a restart keeps the saved receipt: the points are granted exactly once.
func interrupted(game: Profile) -> void:
	game.set_level(game.building_slot("left_mid"),1)
	var before := await land_on_construction(game)
	var saved: Dictionary = game.state.duplicate(true)
	check(game.busy and saved.wallet.build_points == before + 3,"Tranzacție confirmată înaintea mersului")
	map.free()
	map = BOARD.instantiate()
	map.save_prefix = Profile.PREFIX
	root.add_child(map)
	await frames()
	var again: Profile = map.game
	check(again.state.wallet.build_points == before + 3 and not again.busy,"Restart: punctele o singură dată")
	check(map.hud.build_stat.text == str(before + 3),"Restart: HUD cu soldul salvat")
	check(again.state.board_position_index == 5 and map.visual_tile == 5,"Restart: Lerik pe căsuța confirmată")


func layout() -> void:
	var game: Profile = map.game
	game.set_resource("coins",999999999)
	game.set_resource("fragments",88888)
	game.set_resource("build_points",123456)
	map._refresh()
	for pixels in [Vector2i(720,1280),Vector2i(720,1600),Vector2i(768,1024),Vector2i(720,1080),Vector2i(1080,1920)]:
		root.size = pixels
		await frames(3)
		var hud: Node = map.hud
		var view: Vector2 = hud.get_viewport().get_visible_rect().size
		var controls: Array = hud.top.get_children()
		check(controls.size() == 5 and controls[3] == hud.build_stat and controls[4] == hud.bag,"Ordinea barei de sus " + str(pixels))
		for i in range(controls.size()):
			var a: Control = controls[i]
			var box := Rect2(a.global_position,a.size)
			check(box.position.x >= 0.0 and box.end.x <= view.x and box.size.y >= 56.0 and box.size.x >= 56.0,"Element întreg și ușor de atins " + a.name + " " + str(pixels))
			if i > 0:
				# Layout boxes (a counter that is popping is briefly scaled; that is not an overlap).
				var left: Control = controls[i-1]
				check(left.position.x + left.size.x <= a.position.x,"Fără suprapuneri %s %s/%s" % [str(pixels),left.name,a.name])
			if a is Button and not (a as Button).text.is_empty():
				var button := a as Button
				var font := button.get_theme_font("font")
				var text_width := font.get_string_size(button.text,HORIZONTAL_ALIGNMENT_LEFT,-1,button.get_theme_font_size("font_size")).x
				var room: float = box.size.x - 18.0 - float(button.get_theme_constant("icon_max_width")) - float(button.get_theme_constant("h_separation"))
				check(text_width <= room,"Text netăiat %s «%s» %s" % [a.name,button.text,str(pixels)])
		check(hud.build_stat.text == "123,4k" and hud.coins.text == "999,9M" and hud.fragments.text == "88888","Valori mari compacte, trunchiate")
		check(hud.build_stat.accessibility_name == "Puncte de construcție: 123456" and hud.coins.accessibility_name.ends_with("999999999"),"Valoarea exactă în numele accesibil")
	root.size = Vector2i(720,1280)
	await frames()
