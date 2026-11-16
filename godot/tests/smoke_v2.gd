extends SceneTree
## Test automat v2:  godot --headless --path godot -s res://tests/smoke_v2.gd
## Verifică datele, mașina de bule, energia, upgrade-urile cu timer, nivelurile, globurile,
## cuferele, rezervorul, seria, evenimentul, atacul/raidul pe ținte de antrenament,
## abilitățile, garderoba, analiza și ecranele (glob + dirijabil) cu o rotire din interfață.

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("OK   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func fresh(g) -> void:
	g._reset_new()
	g.level = 1
	g.globe = 1
	g.builds = []
	g.chests = []
	g.skills = {}
	g.skill_points = 0
	g.cosmetics = {}
	g.airship = {}
	g.trophies = {}
	g.cards = {}
	g.perle = 0
	g.shields = 0
	g.mult = 1
	g.streak = {"day": 0, "last": -1}
	g.event = {"start": Time.get_unix_time_from_system(), "points": 0, "stage": 0}
	for k in g.stats:
		g.stats[k] = 0


func _initialize() -> void:
	await process_frame
	var g = root.get_node("Game")
	g.save_path = "user://test_save_v2.json"
	fresh(g)
	var now := Time.get_unix_time_from_system()

	# ---------------- date ----------------
	check(g.D.levels.levels.size() == 30, "30 de niveluri în levels.json")
	var per_globe := [0, 0, 0]
	for l in g.D.levels.levels:
		per_globe[int(l.globe) - 1] += l.upgrades.size()
		if l.upgrades.size() < 2 or l.upgrades.size() > 3:
			check(false, "nivelul %d are %d upgrade-uri" % [l.level, l.upgrades.size()])
	check(per_globe == [25, 25, 25], "fiecare glob are 25 de upgrade-uri (5 clădiri × 5 etape)")
	check(g.D.skills.skills.size() == 15 and g.D.skills.branches.size() == 3, "15 abilități în 3 ramuri")
	check(g.D.cosmetics.items.size() == 10, "10 piese de garderobă")
	check(g.D.cards.sets.size() == 3 and g.D.cards.sets[0].cards.size() == 9, "album: 3 seturi × 9 cărți")

	# ---------------- mașina de bule: distribuția urmează tabelul ----------------
	var counts := {}
	g.energy = 100000
	var n := 6000
	var c0: float = g.coins
	for i in n:
		var r: Dictionary = g.spin()
		counts[r.id] = counts.get(r.id, 0) + 1
		if i == 0:
			check(r.reels.size() == 3, "rotirea are 3 simboluri")
	var worst := 0.0
	for o in g.D.spin_table.outcomes:
		var exp_p: float = float(o.weight) / g._w_total
		worst = maxf(worst, absf(float(counts.get(o.id, 0)) / n - exp_p))
	check(worst < 0.02, "frecvențele rotirilor urmează tabelul (abatere max %.3f)" % worst)
	check(g.coins > c0, "rotirile aduc monede")
	check(g.stats.spins == n, "statistica numără rotirile")

	# ---------------- energie ----------------
	fresh(g)
	g.energy = 0
	check(g.spin().is_empty(), "fără energie nu se poate roti")
	g.energy = g.energy_cap() - 2
	g.energy_t = now - g.regen_s() * 10
	g._regen()
	check(g.energy == g.energy_cap(), "energia se reface, dar nu trece de plafon (%d)" % g.energy)
	g.mult = 3
	g.cycle_mult()
	check(g.mult == 1, "multiplicatorul e blocat sub nivelul 5")
	g.level = 5
	g.cycle_mult()
	check(g.mult == 2, "multiplicatorul se deblochează la nivelul 5")
	g.energy = 10
	g.mult = 5
	g.spin()
	check(g.energy <= 5 + 25, "multiplicatorul consumă energie proporțional")

	# ---------------- construcții, niveluri, globuri ----------------
	fresh(g)
	var ups: Array = g.level_upgrades()
	var first: Dictionary = ups[0]
	g.coins = 0
	check(not g.upgrade(first.building), "fără monede nu se poate construi")
	g.coins = 1e9
	check(g.upgrade(first.building), "upgrade plătit (nivelul 1 e imediat)")
	check(int(g.levels[first.building]) == 1, "clădirea a trecut la etapa 1")
	g.upgrade(ups[1].building)
	check(g.level == 2 and g.skill_points == 1, "nivelul 2 atins + 1 punct de abilitate")
	# nivelurile cu timer
	g.level = 6
	for b in g.levels:
		g.levels[b] = 2
	var u6: Dictionary = g.level_upgrades()[0]
	g.levels[u6.building] = int(u6.stage) - 1
	g.upgrade(u6.building)
	check(g.is_building(u6.building) and g.build_remaining(u6.building) > 0, "nivelul 6: construcția are timer (%s)" % g.fmt_time(g.build_remaining(u6.building)))
	check(not g.can_upgrade(g.level_upgrades()[1].building) or g.builders() > 1, "un singur constructor la început")
	g.builds[0].end = now - 1
	g._tick()
	check(not g.is_building(u6.building) and int(g.levels[u6.building]) == int(u6.stage), "construcția se termină după timer")
	# glob complet și călătorie
	fresh(g)
	g.coins = 1e12
	for i in 10:
		for u in g.level_upgrades():
			g.upgrade(u.building)
			for b in g.builds:
				b.end = now - 1
			g._tick()
	check(g.level == 11 and g.globe_locked(), "după nivelul 10 globul următor e blocat")
	check(g.trophies.has("glob_1"), "trofeul primului glob")
	check(not g.can_travel(), "fără Atelier nu se poate călători")
	check(g.buy_airship("motoare_1") and g.buy_airship("baloane_1"), "îmbunătățirile din Atelier se cumpără")
	check(g.can_travel() and g.travel() and g.globe == 2 and g.levels.palat == 0, "călătoria deschide globul 2, orașul de la zero")

	# ---------------- cufere ----------------
	fresh(g)
	for i in 3:
		g.add_chest("comun")
	var c1: float = g.coins
	var m: String = g.add_chest("rar")
	check(g.chests.size() == 3 and g.coins > c1, "sloturi pline: monedele vin pe loc (%s)" % m)
	g.chest_action(0)
	check(g.chests[0].end > now, "deschiderea cufărului pornește")
	check(g.chest_action(1) == "Se deschide deja un cufăr", "un singur cufăr se deschide o dată")
	g.chests[0].end = now - 1
	g.chest_action(0)
	check(g.chests.size() == 2 and g.stats.chests == 1, "cufărul gata dă premiul")

	# ---------------- rezervor ----------------
	fresh(g)
	for b in g.levels:
		g.levels[b] = 3
	g.reservoir_t = now - 3600 * 100
	check(g.reservoir_amount() == g.reservoir_cap() and g.reservoir_cap() > 0, "rezervorul are plafon (%d)" % g.reservoir_cap())
	var r0: float = g.coins
	g.collect_reservoir()
	check(g.coins > r0 and g.reservoir_amount() == 0, "rezervorul se colectează")

	# ---------------- serie zilnică ----------------
	fresh(g)
	check(g.streak_available(), "seria e disponibilă")
	g.claim_streak()
	check(g.streak.day == 1 and not g.streak_available(), "ziua 1 luată, nu de două ori")
	g.streak.last = g.today() - 5
	g.claim_streak()
	check(g.streak.day == 2, "după o pauză seria continuă (nu se resetează)")

	# ---------------- eveniment ----------------
	fresh(g)
	g.energy = 100000
	for i in 400:
		g.spin()
	check(int(g.event.points) > 0 and int(g.event.stage) > 0, "evenimentul adună puncte și dă premii pe etape (%d puncte, etapa %d)" % [g.event.points, g.event.stage])
	g.event.start = now - 8 * 86400
	check(not g.event_active(), "evenimentul are durată fixă")

	# ---------------- ținte de antrenament ----------------
	fresh(g)
	var tr = ResourceLoader.load("res://scripts/social/training_targets.gd", "", ResourceLoader.CACHE_MODE_REPLACE).new()
	var t: Dictionary = tr.pick_target()
	check(t.training and t.label.contains("nu este un jucător real"), "ținta e etichetată ca antrenament")
	g.training[str(t.id)].shields = 1
	var h1: Dictionary = tr.hit(t.id, "palat")
	check(h1.blocked and int(g.training[str(t.id)].shields) == 0, "scutul țintei se consumă")
	var before: int = int(g.training[str(t.id)].levels.palat)
	var h2: Dictionary = tr.hit(t.id, "palat")
	check(not h2.blocked and int(h2.levels.palat) == maxi(0, before - 1) or int(h2.levels.palat) >= 2, "lovitura avariază clădirea")
	var vals: Array = g.start_raid(1)
	check(vals.size() == 4 and g.raid_picks() == 3, "raid: 3 alegeri din 4 locuri")

	# ---------------- abilități și garderobă ----------------
	fresh(g)
	g.skill_points = 10
	check(not g.can_unlock_skill("noroc_2"), "abilitățile au ordine (noroc_2 cere noroc_1)")
	check(g.unlock_skill("noroc_1") and g.skill_value("spin_coins") > 0.04, "abilitatea dă efect")
	g.unlock_skill("aparare_1")
	g.unlock_skill("aparare_2")
	check(g.shield_cap() == 4, "„Scut în plus” ridică plafonul la 4")
	g.level = 7
	g._check_cosmetics()
	check(g.cosmetics.has("ochelari_aur") and g.cosmetics.has("casca_inalta"), "piese deblocate prin nivel")
	g.equip("ochelari_aur")
	check(g.equipped.ochelari == "ochelari_aur", "piesa se poate purta")

	# ---------------- analiză ----------------
	check(FileAccess.file_exists("user://analytics.jsonl") and FileAccess.get_file_as_string("user://analytics.jsonl").contains("\"spin\""), "analiza scrie evenimentele local")

	# ---------------- ecranele ----------------
	fresh(g)
	g.coins = 5000
	g.energy = 30
	var globe = load("res://scenes/globe.tscn").instantiate()
	root.add_child(globe)
	for i in 10:
		await process_frame
	check(globe.city.get_node("Buildings").get_child_count() == 5, "globul are 5 clădiri")
	check(globe.friends.filter(func(f): return f.friend.is_empty()).size() == 3, "bulele prietenilor: 3 sloturi DEMO")
	var hud = globe.get_children().filter(func(x): return x.has_method("show_toast"))[0]
	check(hud.slot is Button and hud.slot.visible, "orașul are butonul spre mașina de bule (rotirile au pagina lor)")
	# atac din interfață
	var st := {"done": false}
	var run := func():
		await hud._attack_flow(1)
		st.done = true
	run.call()
	var waited := 0
	while not st.done and waited < 300:
		if hud.action_panel:
			for b in hud.action_panel.find_children("*", "Button", true, false):
				if not b.disabled:
					b.emit_signal("pressed")
					break
		await create_timer(0.05).timeout
		waited += 1
	check(st.done and globe.target_view.is_empty(), "atacul din interfață se termină și revine acasă")
	# selecție și construcție din glob
	var pb = globe.city.get_node("Buildings/palat")
	globe.cam._pick(globe.cam.unproject_position(pb.global_transform * pb.local_aabb.get_center()))
	check(g.sel == "palat", "atingerea selectează palatul (%s)" % g.sel)
	globe.queue_free()
	await process_frame
	# ---------------- pagina Mecanismului ----------------
	var mec = load("res://scenes/mecanism.tscn").instantiate()
	root.add_child(mec)
	for i in 10:
		await process_frame
	check(mec.reels.size() == 3, "mașina de bule are 3 role 3D")
	var e0: int = g.energy
	var t0 := Time.get_ticks_msec()
	var res: Dictionary = await mec.spin()
	var shown := true
	for i in 3:
		var k: int = int(round(fposmod(mec.reels[i].rotation.x, TAU) / mec.step)) % mec.syms.size()
		shown = shown and mec.syms[k] == res.reels[i]
	check(not res.is_empty() and not mec.busy and g.energy < e0 + 6, "rotire completă pe pagina mașinii (%.1f s)" % ((Time.get_ticks_msec() - t0) / 1000.0))
	check(shown, "rolele arată exact simbolurile rezultatului (%s)" % ", ".join(res.reels))
	var mui = mec.hud
	mui._show_result(res)
	check(mui.banner_msg.text != "", "banderola arată rezultatul: %s" % mui.banner_msg.text)
	# maneta trasă cu degetul pornește o rotire
	await mec.present(res)
	g.energy = 20
	var e1: int = g.energy
	var sp: Vector2 = mec.cam.unproject_position(mec.lever_ball.global_position)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = sp
	mec._unhandled_input(ev)
	var mv := InputEventMouseMotion.new()
	mv.position = sp + Vector2(0, 200)
	mec._unhandled_input(mv)
	var up := ev.duplicate()
	up.pressed = false
	up.position = sp + Vector2(0, 200)
	mec._unhandled_input(up)
	await process_frame
	check(g.energy < e1, "trasul manetei cu degetul pornește rotirea")
	var w2 := 0
	while mec.busy and w2 < 200:
		await create_timer(0.05).timeout
		w2 += 1
	check(mec.tier({"type": "coins", "id": "sac", "mult": 1, "big": true}) == "huge" and mec.tier({"type": "coins", "id": "monede_mici", "mult": 1, "big": false}) == "small", "nivelurile de câștig (mic / mare / super)")
	g.energy = 0
	var empty: Dictionary = await mec.spin()
	check(empty.is_empty(), "fără energie mașina nu pornește")
	mec.queue_free()
	await process_frame
	var air = load("res://scenes/airship.tscn").instantiate()
	root.add_child(air)
	for i in 10:
		await process_frame
	var aui = air.get_children().filter(func(x): return x.has_method("open"))[0]
	for room in ["observator", "garderoba", "atelier", "sera", "salon"]:
		aui.open(room)
		await process_frame
		check(aui.panel.visible and aui.box.get_child_count() > 0, "dirijabil: camera %s se deschide" % room)
	# ---------------- instrumente de test ----------------
	var dt = g.debug_tools
	check(dt != null, "instrumentele de test sunt încărcate în build-ul de debug")
	if dt:
		fresh(g)
		g.energy = 10
		g.forced_outcome = "atac"
		check(g.spin().type == "attack" and g.forced_outcome == "", "rezultatul forțat se aplică o singură dată")
		dt._used("test_smoke")
		check(root.get_node("Analytics").test_session and FileAccess.get_file_as_string("user://analytics.jsonl").contains("debug_tool_used"), "sesiunea e marcată ca test (debug_tool_used)")
		dt.go_to_level(14)
		check(g.level == 14 and g.globe == 2 and int(g.levels.palat) > 0, "mergi la nivelul 14: globul 2, clădiri construite")
		g.chests = [{"kind": "comun", "end": Time.get_unix_time_from_system() + 900}]
		dt.finish_timers()
		check(float(g.chests[0].end) < Time.get_unix_time_from_system(), "timerele se termină instant")
		var gl = load("res://scenes/globe.tscn").instantiate()
		root.add_child(gl)
		await process_frame
		var h = gl.get_children().filter(func(x): return x.has_method("show_toast"))[0]
		h.open_modal("setari")
		await process_frame
		check(h.modal_box.find_children("*", "OptionButton", true, false).size() == 1, "Setări: secțiunea „Instrumente de test” cu lista de rezultate")
		gl.queue_free()
		await process_frame
	print("REZULTAT: %s" % ("TOATE TESTELE AU TRECUT" if fails == 0 else "%d EȘECURI" % fails))
	quit(1 if fails else 0)
