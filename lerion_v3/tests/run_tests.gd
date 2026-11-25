extends SceneTree
## Teste automate pentru etapa 1. Rulare (fără fereastră):
##   godot --headless --path . --script res://tests/run_tests.gd
## Cod de ieșire 0 = toate testele au trecut.

var _passed := 0
var _failed := 0


func _initialize() -> void:
	print("=== Lerion V3 – teste etapa 1 ===")
	_test_geometry()
	_test_dice()
	_test_movement()
	_test_state()
	await _test_scene()
	print("=== Rezultat: %d trecute, %d eșuate ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
		print("  OK   ", what)
	else:
		_failed += 1
		printerr("  EȘEC ", what)


# ---------------------------------------------------------------- traseu

func _test_geometry() -> void:
	print("-- Traseu")
	var cfg := BoardConfig.create_default()
	var line := BoardPath.compute_centerline(cfg)
	var tiles := BoardPath.compute_tiles(cfg, line)
	var errors := BoardPath.validate_layout(cfg, line, tiles)
	for e in errors:
		printerr("     ", e)
	_check(errors.is_empty(), "validarea completă a traseului nu are erori")
	_check(tiles.size() == 36, "36 de căsuțe")
	_check(LoopGeometry.count_self_intersections(line) == 0, "fără auto-intersecții")
	var mean := LoopGeometry.loop_length(line) / 36.0
	var closing := tiles[35].position.distance_to(tiles[0].position)
	_check(absf(closing - mean) < mean * 0.12, "căsuța 35 este vecină fizic cu 0 (%.2f ≈ %.2f)" % [closing, mean])
	_check(tiles[0].kind == BoardTile.KIND_START and tiles[0].position.z > 10.0, "START (0) este jos, în fața camerei")
	_check(Geometry2D.is_point_in_polygon(cfg.crystal_position, line), "cristalul este în interiorul buclei")
	var min_gap := INF
	for b in cfg.building_ids.size():
		min_gap = minf(min_gap, LoopGeometry.distance_to_point(line, cfg.building_positions[b]) - cfg.building_radius - cfg.road_half_width)
	_check(min_gap >= 0.45, "drumul stă în afara platformelor (spațiu minim %.2f)" % min_gap)
	_check(BoardPath.zone_sequence(tiles) == cfg.expected_zone_order, "trece pe lângă toate cele 6 clădiri, în ordine: %s" % str(BoardPath.zone_sequence(tiles)))

	# Validarea chiar prinde greșeli (test negativ): o clădire mutată pe drum.
	var bad := BoardConfig.create_default()
	bad.building_positions[3] = Vector2(4.5, 0.0)
	var bad_errors := BoardPath.validate_layout(bad, BoardPath.compute_centerline(bad), BoardPath.compute_tiles(bad, BoardPath.compute_centerline(bad)))
	_check(not bad_errors.is_empty(), "validarea respinge o clădire pusă pe drum")
	# Și o buclă care se auto-intersectează (opt).
	var eight := BoardConfig.create_default()
	eight.control_points = PackedVector2Array([Vector2(0, 10), Vector2(6, 5), Vector2(-6, -5), Vector2(0, -10), Vector2(6, -5), Vector2(-6, 5)])
	_check(LoopGeometry.count_self_intersections(BoardPath.compute_centerline(eight)) > 0, "validarea detectează un traseu în formă de 8")


# ---------------------------------------------------------------- zaruri

func _test_dice() -> void:
	print("-- Zaruri")
	var svc := DiceRollService.new(12345)
	var n := 360000
	var counts := {}
	var face_ok := true
	for i in n:
		var r := svc.roll()
		if r.die_a < 1 or r.die_a > 6 or r.die_b < 1 or r.die_b > 6 or r.total != r.die_a + r.die_b:
			face_ok = false
		counts[r.total] = int(counts.get(r.total, 0)) + 1
	_check(face_ok, "fiecare zar 1–6, suma = a + b")
	var keys: Array = counts.keys()
	keys.sort()
	_check(keys == [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12], "sumele posibile sunt exact 2..12")
	var dist_ok := true
	for s in range(2, 13):
		var expected := float(6 - absi(s - 7)) / 36.0
		var got := float(counts.get(s, 0)) / float(n)
		if absf(got - expected) > 0.004:
			dist_ok = false
			printerr("     suma %d: %.4f vs %.4f" % [s, got, expected])
	_check(dist_ok, "distribuție triunghiulară (7 ≈ 6/36, 2 și 12 ≈ 1/36) pe %d aruncări" % n)
	var a := DiceRollService.new(99)
	var b := DiceRollService.new(99)
	_check(a.roll().total == b.roll().total, "seed fix → rezultat reproductibil")


# ---------------------------------------------------------------- mutare

func _test_movement() -> void:
	print("-- Mutare")
	var m := BoardMovement.compute(0, 7, 36)
	_check(m.to_index == 7 and m.path == PackedInt32Array([1, 2, 3, 4, 5, 6, 7]), "0 + 7 → 7, trece prin 1..7")
	_check(not m.crossed_start(), "plecarea de pe START nu dă bonus")
	m = BoardMovement.compute(30, 8, 36)
	_check(m.to_index == 2 and m.path == PackedInt32Array([31, 32, 33, 34, 35, 0, 1, 2]), "30 + 8 → 2, trece 35 → 0 fără salt")
	_check(m.start_passes == 1, "trecerea peste START numărată o dată")
	m = BoardMovement.compute(28, 8, 36)
	_check(m.to_index == 0 and m.start_passes == 1, "oprirea fix pe START contează ca trecere")
	m = BoardMovement.compute(35, 12, 36)
	_check(m.to_index == 11 and m.path.size() == 12, "pașii parcurși = suma zarurilor (12)")
	var all_ok := true
	for from in 36:
		for steps in range(2, 13):
			var mv := BoardMovement.compute(from, steps, 36)
			if mv.path.size() != steps or mv.to_index != (from + steps) % 36 or mv.to_index < 0 or mv.to_index > 35:
				all_ok = false
			var prev := from
			for idx in mv.path:
				if idx != (prev + 1) % 36:
					all_ok = false
				prev = idx
	_check(all_ok, "toate cele 36×11 combinații: pași consecutivi, index în [0,35]")
	# 36 pași cumulați de la START → exact o trecere.
	var pos := 0
	var passes := 0
	for s in [6, 6, 6, 6, 6, 6]:
		var mv := BoardMovement.compute(pos, s, 36)
		passes += mv.start_passes
		pos = mv.to_index
	_check(pos == 0 and passes == 1, "după 36 de pași de la START: o singură trecere")
	_check(BoardMovement.duration_for_steps(2) >= 1.5 and BoardMovement.duration_for_steps(12) <= 2.5, "durata mutării între 1,5 și 2,5 s")


# ---------------------------------------------------------------- stare + salvare

func _test_state() -> void:
	print("-- Tranzacție și salvare")
	var cfg := BoardConfig.create_default()
	var path := "user://test_state_save.json"
	for suffix in ["", ".bak", ".tmp", ".corupt"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	var now := 1_000_000
	var st := GameState.new(path, cfg)
	st.load_or_create(now)
	st.building_levels["mina"] = 3
	st.coins = 4321
	var dice := DiceRollService.new(7)
	var tx := st.try_begin_roll(dice, 36, now)
	_check(tx != null and st.energy == 99, "o aruncare consumă exact 1 energie")
	var tx2 := st.try_begin_roll(dice, 36, now)
	_check(tx2 == null and st.last_error == "busy" and st.energy == 99, "dublu-tap în timpul mutării nu aruncă din nou")
	_check(st.board_position_index == tx.move.to_index, "poziția se actualizează la confirmare")
	_check(st.finish_roll(tx.id) and not st.finish_roll(tx.id), "finalizarea e acceptată o singură dată")

	# Repornire în mijlocul animației: rezultatul nu se repetă și nu se pierde.
	var tx3 := st.try_begin_roll(dice, 36, now + 1)
	var pos_after := st.board_position_index
	var energy_after := st.energy
	var st2 := GameState.new(path, cfg)
	st2.load_or_create(now + 2)
	_check(st2.recovered_pending_roll and st2.pending_roll_transaction_id == "", "aruncarea întreruptă e recuperată, fără re-aruncare")
	_check(st2.board_position_index == pos_after and st2.energy == energy_after, "poziția și energia rămân cele confirmate")
	_check(st2.building_level("mina") == 3 and st2.coins == 4321, "nivelurile clădirilor și resursele se păstrează")
	_check(st2.total_rolls == 2 and tx3 != null, "numărul de aruncări salvat corect")
	_check(FileAccess.file_exists(path + ".bak"), "se păstrează o copie .bak a salvării anterioare")

	# Fără energie.
	st2.energy = 0
	st2.energy_regen_anchor_unix = now + 2
	_check(st2.try_begin_roll(dice, 36, now + 2) == null and st2.last_error == "no_energy", "fără energie nu se poate arunca")
	st2.update_energy_regen(now + 2 + 300 * 3 + 10)
	_check(st2.energy == 3, "regenerare +1 la 5 minute (3 după 15 min)")
	st2.update_energy_regen(now + 10_000_000)
	_check(st2.energy == st2.energy_max, "regenerarea se oprește la maxim")

	# Salvare coruptă: nu se șterge, se păstrează ca .corupt.
	print("     (urmează o eroare JSON intenționată: testăm o salvare coruptă)")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{ asta nu e JSON")
	f.close()
	var st3 := GameState.new(path, cfg)
	st3.load_or_create(now)
	_check(FileAccess.file_exists(path + ".corupt"), "o salvare ilizibilă e păstrată ca .corupt, nu ștearsă")
	for suffix in ["", ".bak", ".tmp", ".corupt"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))


# ---------------------------------------------------------------- scenă

func _test_scene() -> void:
	print("-- Scena principală")
	var save := "user://test_scene_save.json"
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save + suffix))
	var main: Node = load("res://main.tscn").instantiate()
	main.set("save_path", save)
	root.add_child(main)
	for i in 5:
		await process_frame
	var board: BoardPath = main.get("board")
	var lerik: Lerik = main.get("lerik")
	var state: GameState = main.get("state")
	_check(board.get_node_or_null("LoopPath") is Path3D, "nodul LoopPath (Path3D) există în scenă")
	_check(board.get_node("Tiles").get_children().filter(func(n: Node) -> bool: return n is MeshInstance3D).size() == 36, "36 de căsuțe în scenă")
	_check(board.validate().is_empty(), "traseul din scenă trece validarea")
	var world: WorldBuilder = main.get("world")
	_check(world.buildings.size() == 6, "6 clădiri în scenă")
	_check(lerik.position.distance_to(board.get_tile(0).position + Vector3.UP * Lerik.TILE_TOP) < 0.01, "Lerik pornește pe START")

	var energy_before := state.energy
	var steps_seen: Array[int] = []
	lerik.stepped.connect(func(i: int) -> void: steps_seen.append(i))
	main.call("_on_roll_pressed")
	main.call("_on_roll_pressed")  # dublu-tap: doar grăbește, nu aruncă din nou
	var t0 := Time.get_ticks_msec()
	await lerik.move_finished
	var target := state.board_position_index
	_check(state.energy == energy_before - 1, "o singură aruncare la dublu-tap (energie %d → %d)" % [energy_before, state.energy])
	_check(steps_seen.size() >= 2 and steps_seen.size() <= 12 and steps_seen[steps_seen.size() - 1] == target, "Lerik a făcut %d pași și s-a oprit pe %d" % [steps_seen.size(), target])
	await process_frame
	_check(lerik.position.distance_to(board.get_tile(target).position + Vector3.UP * Lerik.TILE_TOP) < 0.01, "Lerik stă exact pe căsuța de oprire")
	print("     (mutare grăbită: %d ms)" % (Time.get_ticks_msec() - t0))

	# A doua aruncare, fără grăbire: măsurăm durata mutării.
	for i in 8:
		await process_frame
	main.call("_on_roll_pressed")
	var tx_steps := state.board_position_index - target
	if tx_steps <= 0:
		tx_steps += 36
	# durata mutării = de la primul pas până la final (fără animația zarurilor de 0,57 s)
	var start_ms := Time.get_ticks_msec()
	await lerik.move_finished
	var total := float(Time.get_ticks_msec() - start_ms) / 1000.0 - 0.57
	_check(total >= 1.3 and total <= 2.8, "durata mutării normale pentru %d pași: %.2f s (țintă 1,5–2,5)" % [tx_steps, total])
	await process_frame
	_check(state.pending_roll_transaction_id == "" and not state.is_rolling(), "tranzacția este închisă după animație")
	main.queue_free()
	await process_frame
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save + suffix))
