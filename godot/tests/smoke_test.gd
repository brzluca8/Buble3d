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
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 10:
		await process_frame
	check(main.island.get_node("Buildings").get_child_count() == 5, "5 clădiri create")
	check(main.cam.buildings.size() == 5, "camera cunoaște clădirile")

	# selectare prin raycast din centrul clădirii proiectat pe ecran
	var b = main.island.get_node("Buildings/palat")
	var sp: Vector2 = main.cam.unproject_position(b.global_position + Vector3(0, 2, 0))
	main.cam._pick(sp)
	check(game.sel == "palat", "atingerea selectează palatul (%s)" % game.sel)

	var before: float = game.coins
	check(game.upgrade("palat"), "upgrade reușit")
	check(game.levels.palat == 2 and game.coins == before - 150, "cost și nivel corecte")
	game.coins = 0
	check(not game.upgrade("obs"), "upgrade refuzat fără monede")

	# Buble Blast: trage până se termină runda
	var hud = main.get_children().filter(func(n): return n is CanvasLayer)[0]
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
	bl._quit()
	await process_frame
	check(hud.blast == null, "Buble Blast închis")

	game.save_game()
	var saved := FileAccess.get_file_as_string(game.SAVE_PATH)
	check(saved.contains("\"palat\":2"), "salvarea conține progresul")
	print("REZULTAT: %s" % ("TOATE TESTELE AU TRECUT" if fails == 0 else "%d EȘECURI" % fails))
	quit(1 if fails else 0)
