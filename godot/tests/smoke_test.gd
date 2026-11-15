extends SceneTree
## Test de fum: godot --headless --path godot -s res://tests/smoke_test.gd
## Pornește scena principală, simulează selectare, upgrade, o rundă Buble Blast
## și reclama DEMO, apoi verifică starea.

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("OK   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	await process_frame
	var game = root.get_node("Game")
	game.save_path = "user://test_save.json"   # nu atinge salvarea reală
	game.coins = 1000.0
	game.levels = {"palat": 1, "obs": 1, "turn": 1, "mag": 1, "sera": 1}
	game.island = 1
	game.pos = 0
	game.energy = 50
	game.mult = 1
	var main = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(main)
	for i in 10:
		await process_frame
	if "friends" in main and "repo" in main:
		# ---- orașul din glob ----
		check(main.city.get_node("Buildings").get_child_count() == 5, "5 clădiri în glob")
		check(main.friends.size() == 6, "6 bule de prieteni în jurul globului")
		await create_timer(0.3).timeout
		var empty_slots: int = main.friends.filter(func(f): return f.friend.is_empty()).size()
		check(main.repo.is_demo() and empty_slots == 6, "fără server: doar sloturi goale DEMO (fără jucători simulați)")
		for id in ["palat", "obs", "turn", "mag", "sera"]:
			var b = main.city.get_node("Buildings/" + id)
			var sp: Vector2 = main.cam.unproject_position(b.global_position + Vector3(0, Models.HEIGHT[id] * 0.25, 0))
			main.cam._pick(sp)
			check(game.sel == id, "atingerea în glob selectează %s (%s)" % [id, game.sel])
		game.select("")
		# atingerea unei bule goale deschide invitația
		var hud0 = main.get_children().filter(func(n): return n.has_method("show_toast"))[0]
		var fsp: Vector2 = main.cam.unproject_position(main.friends[0].global_position)
		main.cam._pick(fsp)
		await process_frame
		check(hud0.modal.visible, "atingerea unei bule goale deschide „Invită un prieten”")
		hud0._nav_to("home")
		# vizită (prieten real, prin repository de test)
		main.repo = load("res://tests/test_friends_repo.gd").new()
		await main.refresh_friends()
		check(main.friends[0].friend.get("name", "") == "Test", "prietenul apare în bulă")
		await main.visit(main.friends[0].friend)
		check(main.city.get_node("Buildings/palat")._lvl == 4 and main.visit_ui != null, "vizita arată orașul prietenului (palat nivel 4)")
		main.end_visit()
		check(main.city.get_node("Buildings/palat")._lvl == game.levels.palat, "înapoi acasă: orașul tău")
		var tier0: int = main.city_tier()
		for k in game.levels:
			game.levels[k] = 5
		game.changed.emit()
		check(main.city_tier() > tier0 and main.rings[0].visible, "nivelul orașului aprinde inele aurii pe glob")
		game.levels = {"palat": 1, "obs": 1, "turn": 1, "mag": 1, "sera": 1}
		game.changed.emit()
		game.select("palat")
	elif "pieces" in main:
		# lumea 2.5D pictată
		check(main.pieces.size() == 5, "5 clădiri create")
		main.pick(main.world_to_screen(main.hot["palat"].get_center()))
		check(game.sel == "palat", "atingerea selectează palatul (%s)" % game.sel)
	else:
		# lumea 3D cu cameră cinematografică
		check(main.island.get_node("Buildings").get_child_count() == 5, "5 clădiri 3D create")
		check(main.cam.buildings.size() == 5, "camera cunoaște clădirile")
		for id in ["palat", "obs", "turn", "mag", "sera"]:
			var b = main.island.get_node("Buildings/" + id)
			var sp: Vector2 = main.cam.unproject_position(b.global_position + Vector3(0, Models.HEIGHT[id] * 0.4, 0))
			main.cam._pick(sp)
			check(game.sel == id, "atingerea selectează %s (%s)" % [id, game.sel])
		for i in 90:
			await process_frame
		check(main.cam.dist < main.cam.HOME_DIST - 5.0, "camera se apropie de clădirea selectată (dist %.1f)" % main.cam.dist)
		check(absf(main.cam.yaw) <= main.cam.YAW_LIMIT + 0.001, "rotația rămâne în limita de ±25°")
		main.cam._t_yaw = 5.0
		main.cam._t_pitch = -1.0
		main.cam._unhandled_input(InputEventMouseMotion.new())
		game.select("")
		for i in 120:
			await process_frame
		check(absf(main.cam.dist - main.cam.home_dist) < 0.5 and main.mode == "insula", "deselectarea readuce vederea modului Insulă")
		check(main.cam.global_position.y > 3.0, "camera rămâne deasupra insulei (y %.1f)" % main.cam.global_position.y)
		main.cam._zoom(0.01)
		for i in 60:
			await process_frame
		check(main.cam.dist >= main.cam.DIST_MIN - 0.01, "zoomul are limită (dist %.1f)" % main.cam.dist)
		main.cam.reset_view()
		game.select("palat")
	var before: float = game.coins
	check(game.upgrade("palat"), "upgrade reușit")
	check(game.levels.palat == 2 and game.coins == before - 150, "cost și nivel corecte")
	game.coins = 0
	check(not game.upgrade("obs"), "upgrade refuzat fără monede")

	# Buble Blast: trage până se termină runda
	var hud = main.get_children().filter(func(n): return n.has_method("show_toast"))[0]
	hud._open_blast()
	await process_frame
	var bl = hud.blast
	check(bl != null, "Buble Blast deschis")
	var guard := 0
	while not bl.over and guard < 4000:
		if bl.mv == null:
			bl.aim_a = randf_range(0.4, PI - 0.4)
			bl._shoot()
		await process_frame
		guard += 1
	print("  dimensiune %s, lim %d, mutări rămase %d" % [bl.size, bl.lim, bl.shots])
	check(bl.over, "runda s-a terminat (scor %d, monede %d)" % [bl.score, bl.coins_won])
	var after_blast: float = game.coins
	check(game.missions.blast, "misiunea Buble Blast bifată")
	if bl.coins_won > 0:
		var won: int = bl.coins_won
		root.get_node("Monetization").show_rewarded("double_blast")
		root.get_node("Monetization").finish_demo_ad(true)
		check(game.coins == after_blast + won, "reclama DEMO dublează monedele")
	# bombă: sparge bulele din jur
	bl.start_level(1)
	var before_cells := 0
	for row in bl.g:
		for v in row:
			if v >= 0:
				before_cells += 1
	bl.mv = {"p": bl.cp(1, 3), "v": Vector2.ZERO, "c": bl.BOMB}
	bl._place()
	var after_cells := 0
	for row in bl.g:
		for v in row:
			if v >= 0:
				after_cells += 1
	check(after_cells < before_cells - 5, "bomba sparge bulele din jur (%d → %d)" % [before_cells, after_cells])
	var lvl_before: int = game.blast_level
	game.blast_reward(100, true)
	check(game.blast_level == lvl_before + 1, "victoria deblochează nivelul următor")
	bl.start_level(game.blast_level)
	check(bl.colors >= 3 and bl.shots > 24, "nivel nou pregătit (%d culori, %d mutări)" % [bl.colors, bl.shots])
	bl._quit()
	await process_frame
	check(hud.blast == null, "Buble Blast închis")

	# ---------------- bucla zaruri + traseu ----------------
	game.energy = 10
	game.mult = 1
	game.pos = 0
	var e0: int = game.energy
	var r: Dictionary = game.roll(Vector2i(2, 3))
	check(r.to == 5 and game.pos == 5, "aruncarea 2+3 mută mascota pe căsuța 5 (%s)" % r.get("to", -1))
	check(game.energy == e0 - 1, "aruncarea consumă o bulă de energie")
	r = game.roll(Vector2i(4, 4))
	check(game.energy == e0 - 1, "dubla dă o aruncare gratuită")
	game.pos = 20
	var c0: float = game.coins
	r = game.roll(Vector2i(3, 2))
	check(r.start_bonus > 0 and game.coins >= c0 + r.start_bonus, "trecerea pe la Start dă bonus (%d)" % r.start_bonus)
	game.energy = 0
	check(game.roll().is_empty(), "fără energie nu se poate arunca")
	c0 = game.coins
	var rc: Dictionary = game.resolve_tile("coins")
	check(rc.coins > 0 and game.coins == c0 + rc.coins, "căsuța de monede dă monede (%d)" % rc.coins)
	game.shields = 0
	game.resolve_tile("shield")
	check(game.shields == 1, "căsuța de scut adaugă un scut")
	var ev0: int = game.event_pts
	game.resolve_tile("event")
	check(game.event_pts > ev0, "căsuța de eveniment dă puncte")
	var rv0: int = game.rival["turn"]
	c0 = game.coins
	var ra: Dictionary = game.attack("turn")
	check(game.coins > c0 and (ra.blocked or game.rival["turn"] < rv0 or game.rival["turn"] >= 2), "atacul dă monede și strică clădirea rivalului")
	var cells: Array = game.start_raid()
	check(cells.size() == 9 and cells.count(0) == 3, "jaful are 9 nori, 3 goi")
	var got: Array = game.add_cards(3)
	check(got.size() == 3, "cuferele dau cărți pentru album")
	# insulă completă → insula următoare
	var isl: int = game.island
	for k in game.levels.keys():
		game.levels[k] = 5
	game.levels["sera"] = 4
	game.coins = 1e9
	game.upgrade("sera")
	check(game.island == isl + 1 and game.sum_levels() == 5, "insula completă deblochează insula următoare (%s)" % game.island_name())
	# interfața: aruncare completă cu animație (mascota sare pe traseu)
	if "board" in main:
		game.energy = 5
		game.pos = 0
		var play = hud.play
		play.roll()
		var frames := 0
		while play.busy and frames < 400:
			if play.popup.visible:
				# alege automat în ferestrele de atac / jaf
				for b in play.popup.find_children("*", "Button", true, false):
					if not b.disabled:
						b.emit_signal("pressed")
						break
			if hud.blast:
				hud.blast._quit()
			await create_timer(0.05).timeout
			frames += 1
		check(not play.busy, "aruncarea din interfață se termină (%.1f s)" % (frames * 0.05))
		check(main.mascot.position.distance_to(main.board.stand_pos(game.pos)) < 1.6, "mascota a ajuns pe căsuța %d" % game.pos)

	# modurile Joc / Insulă
	if "board" in main:
		main.set_mode("joc")
		await create_timer(0.6).timeout
		check(main.board.visible and absf(main.cam.home_dist - main.cam.HOME_DIST) < 0.1, "modul Joc arată traseul")
		game.select("mag")
		await create_timer(0.6).timeout
		check(main.mode == "insula" and not main.board.visible, "atingerea unei clădiri trece în modul Insulă")
		game.select("")

	# atac și jaf pe insula rivalului (cu animații)
	if "board" in main:
		var play2 = hud.play
		for flow in ["_attack_popup", "_raid_popup"]:
			var c_before: float = game.coins
			var st := {"done": false}
			var run := func():
				await play2.call(flow)
				st.done = true
			run.call()
			var waited := 0
			while not st.done and waited < 400:
				for b in play2.popup.find_children("*", "Button", true, false):
					if not b.disabled:
						b.emit_signal("pressed")
						break
				await create_timer(0.05).timeout
				waited += 1
			check(st.done, "%s se termină (%.1f s)" % [flow, waited * 0.05])
			check(game.coins > c_before or (flow == "_raid_popup" and game.coins >= c_before), "%s aduce monede" % flow)
			check(main.island.visible and not main.rival.visible, "%s: revenire pe insula proprie" % flow)

	game.save_game()
	var saved := FileAccess.get_file_as_string(game.save_path)
	check(saved.contains("\"isl\":2") and saved.contains("\"pos\""), "salvarea conține progresul (insula, poziția pe traseu)")
	print("REZULTAT: %s" % ("TOATE TESTELE AU TRECUT" if fails == 0 else "%d EȘECURI" % fails))
	quit(1 if fails else 0)
