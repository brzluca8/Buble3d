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
	for sc in ["acasa", "setari", "santier", "mecanism", "mec_rotire", "mec_super", "mec_mare", "mec_atac", "mec_scut", "mec_cufar", "upgrade", "selectie", "atac", "raid", "nivel5", "sanse", "glob2", "glob3", "dirijabil", "observator", "garderoba"]:
		if not only.is_empty() and not sc in only:
			continue
		await _shot(g, sc, out + "/" + sc + ".png")
	quit()


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _shot(g, sc: String, path: String) -> void:
	var scene := "res://scenes/airship.tscn" if sc in ["dirijabil", "observator", "garderoba"] else ("res://scenes/mecanism.tscn" if sc in ["mecanism", "sanse"] or sc.begins_with("mec_") else "res://scenes/globe.tscn")
	if sc == "nivel5":
		for b in g.levels:
			g.levels[b] = 5
		g.level = 10
	elif sc in ["glob2", "glob3"]:
		g.globe = 2 if sc == "glob2" else 3
		g.level = 14 if sc == "glob2" else 24
		for b in g.levels:
			g.levels[b] = 3
	elif sc == "santier":
		g.globe = 1
		g.level = 1
		g.levels = {"palat": 1, "obs": 0, "turn": 0, "mag": 0, "sera": 0}
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
	if sc.begins_with("mec_"):
		g.level = 7
		await _mec_moment(g, w, hud, sc)
		root.get_texture().get_image().save_png(path)
		print("STATISTICI %s: apeluri de desenare=%d, primitive=%d" % [sc, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
		Engine.time_scale = 1.0
		w.queue_free()
		await _wait(3)
		return
	match sc:
		"selectie":
			g.select("palat")
		"upgrade":
			g.upgraded.emit("palat")
			await create_timer(0.55, true, false, true).timeout
			root.get_texture().get_image().save_png(path)
			w.queue_free()
			await _wait(3)
			return
		"atac":
			hud._attack_flow(1)
			await _wait(50)
		"raid":
			hud._raid_flow(1)
			await _wait(50)
		"sanse":
			hud.open_modal("sanse")
		"setari":
			hud.open_modal("setari")
			await _wait(5)
			var sc_box: ScrollContainer = hud.modal_box.get_parent()
			sc_box.scroll_vertical = 2000
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


## Momente din animațiile Mecanismului: rotire (blur), câștig mare, super câștig, intrarea atacului.
func _mec_moment(g, w, hud, sc: String) -> void:
	var gem: int = w.syms.find("gem")
	match sc:
		"mec_rotire":
			hud.do_spin()
			await create_timer(1.75, true, false, true).timeout
		"mec_super", "mec_mare":
			var sym := "gem" if sc == "mec_super" else "coin"
			for i in 3:
				w.reels[i].rotation.x = w.syms.find(sym) * w.step
			var res := {"id": "jackpot" if sc == "mec_super" else "monede", "name": "Trei perle" if sc == "mec_super" else "Trei monede",
				"type": "coins", "reels": [sym, sym, sym], "mult": 1, "coins": 6200 if sc == "mec_super" else 620,
				"energy": 0, "big": sc == "mec_super", "msg": "+6.200 monede" if sc == "mec_super" else "+620 monede"}
			hud.shown_coins = g.coins
			hud._show_result(res)
			w.present(res)
			await create_timer(1.25 if sc == "mec_super" else 0.62, true, false, true).timeout
		"mec_scut", "mec_cufar":
			var sym := "shield" if sc == "mec_scut" else "chest"
			var k: int = w.syms.find(sym)
			for i in 3:
				w.reels[i].rotation.x = k * w.step
			var res := {"id": "scut" if sc == "mec_scut" else "cufar", "name": "Scut" if sc == "mec_scut" else "Cufăr", "type": "shield" if sc == "mec_scut" else "chest",
				"reels": [sym, sym, sym], "mult": 1, "coins": 0, "energy": 0, "big": false, "msg": "Scut 1/3" if sc == "mec_scut" else "Cufăr rar adăugat"}
			hud._show_result(res)
			w.present(res)
			await create_timer(1.55 if sc == "mec_scut" else 0.62, true, false, true).timeout
		"mec_atac":
			var h: int = w.syms.find("hammer")
			for i in 3:
				w.reels[i].rotation.x = h * w.step
			var res := {"id": "atac", "name": "Atac", "type": "attack", "reels": ["hammer", "hammer", "hammer"], "mult": 1, "coins": 0, "energy": 0, "big": false, "msg": "Atac!"}
			hud._show_result(res)
			w.present(res)
			await create_timer(0.97, true, false, true).timeout
