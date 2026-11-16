extends SceneTree
## Capturi pentru comparația cu referințele:
##   godot --path godot -s res://tests/shot_v2.gd -- <dosar> [scenariu...]
## Scenarii: acasa, mecanism, nivel5, selectie, atac, raid, dirijabil, observator, garderoba, sanse, glob2, glob3

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[0]
	var only: Array = a.slice(1)
	root.size = Vector2i(720, 1280)
	await process_frame
	var g = root.get_node("Game")
	g.save_path = "user://shot_v2.json"
	g._reset_new()
	g.coins = 18500
	g.perle = 12
	g.energy = 42
	g.level = 3
	g.levels = {"palat": 2, "obs": 1, "turn": 1, "mag": 1, "sera": 1}
	g.chests = [{"kind": "rar", "end": Time.get_unix_time_from_system() + 2400}, {"kind": "comun", "end": 0.0}]
	g.streak = {"day": 1, "last": g.today()}
	for sc in ["acasa", "mecanism", "selectie", "atac", "raid", "nivel5", "sanse", "glob2", "glob3", "dirijabil", "observator", "garderoba"]:
		if not only.is_empty() and not sc in only:
			continue
		await _shot(g, sc, out + "/" + sc + ".png")
	quit()


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _shot(g, sc: String, path: String) -> void:
	var scene := "res://scenes/airship.tscn" if sc in ["dirijabil", "observator", "garderoba"] else ("res://scenes/mecanism.tscn" if sc in ["mecanism", "sanse"] else "res://scenes/globe.tscn")
	if sc == "nivel5":
		for b in g.levels:
			g.levels[b] = 5
		g.level = 10
	elif sc in ["glob2", "glob3"]:
		g.globe = 2 if sc == "glob2" else 3
		g.level = 14 if sc == "glob2" else 24
		for b in g.levels:
			g.levels[b] = 3
	else:
		g.globe = 1
		g.level = 3
		g.levels = {"palat": 2, "obs": 1, "turn": 1, "mag": 1, "sera": 1}
	if sc in ["observator", "garderoba"]:
		g.level = 12
		g.skill_points = 4
		g.skills = {"noroc_1": true, "constructor_1": true, "constructor_2": true}
		g._check_cosmetics()
		g.equip("ochelari_aur")
	var w = load(scene).instantiate()
	root.add_child(w)
	await _wait(40)
	var hud = w.get_children().filter(func(x): return x.has_method("show_toast") or x.has_method("open"))[0]
	match sc:
		"selectie":
			g.select("palat")
		"atac":
			hud._attack_flow(1)
			await _wait(50)
		"raid":
			hud._raid_flow(1)
			await _wait(50)
		"sanse":
			hud.open_modal("sanse")
		"observator":
			hud._sel_skill = "noroc_2"
			hud.open("observator")
		"garderoba":
			hud.open("garderoba")
	if sc == "mecanism":
		g.level = 7
		var res: Dictionary = await w.spin()
		while res.type in ["attack", "raid"] or res.coins <= 0:
			res = await w.spin()
		hud._show_result(res)
		g.energy = 42
	await _wait(90)
	print("STATISTICI %s: apeluri de desenare=%d, primitive=%d" % [sc, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
	root.get_texture().get_image().save_png(path)
	w.queue_free()
	await _wait(3)
