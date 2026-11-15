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
	game.coins = 1000.0
	game.levels = {"palat": 1, "obs": 1, "turn": 1, "mag": 1, "sera": 1}
	var main = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(main)
	for i in 10:
		await process_frame
	if "pieces" in main:
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
		check(absf(main.cam.dist - main.cam.HOME_DIST) < 0.5, "deselectarea readuce vederea generală")
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

	game.save_game()
	var saved := FileAccess.get_file_as_string(game.SAVE_PATH)
	check(saved.contains("\"palat\":2"), "salvarea conține progresul")
	print("REZULTAT: %s" % ("TOATE TESTELE AU TRECUT" if fails == 0 else "%d EȘECURI" % fails))
	quit(1 if fails else 0)
