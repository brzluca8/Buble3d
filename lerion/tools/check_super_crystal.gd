extends SceneTree
## Super Crystal, Magic Wheel and chest inventory. Run with a separate XDG_DATA_HOME:
## XDG_DATA_HOME=/tmp/lerion-sc godot --headless --fixed-fps 60 --script tools/check_super_crystal.gd
const Scene := preload("res://scenes/board.tscn")
const Save := preload("res://scripts/board/board_save.gd")
const Legacy := preload("res://scripts/crystal/progress.gd")
const Crystal := preload("res://scripts/crystal/super_crystal_service.gd")
const Wheel := preload("res://scripts/crystal/magic_wheel.gd")
const WheelScreen := preload("res://scripts/crystal/wheel_screen.gd")
const RULES := preload("res://assets/board/rules.tres")
const Profile := preload("res://scripts/developer/dev_profile.gd")
var prefix := "user://super_check_%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()]
var failures := 0
var checks := 0


class ForcedSave extends "res://scripts/board/board_save.gd":
	var next_prize := ""
	func _draw_prize() -> String:
		return next_prize if not next_prize.is_empty() else super()


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		push_error(description)
		failures += 1


func _files(p: String) -> Array:
	var hashes := []
	for slot in range(2):
		var path := "%s_board_v3.%d.json" % [p,slot]
		hashes.append(FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "")
	return hashes


func config_and_odds() -> void:
	var expected := {"energy_10":28,"energy_20":18,"energy_30":10,"chest_wood":24,"chest_silver":15,"chest_gold":5}
	check(Crystal.total_weight() == 100,"Ponderi totale 100")
	for id: String in expected:
		check(is_equal_approx(Crystal.probability(id),expected[id]/100.0),"Probabilitate " + id)
	check(int(Crystal.config().first_target) == 50 and int(Crystal.config().later_target) == 100,"Praguri 50 / 100")
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var counts := {}
	var draws := 200000
	for i in range(draws):
		var id := Crystal.draw(rng)
		counts[id] = int(counts.get(id,0)) + 1
	for id: String in expected:
		var observed := 100.0*int(counts.get(id,0))/draws
		check(absf(observed - expected[id]) < 0.6,"Frecvență %s %.2f%% ≈ %d%%" % [id,observed,expected[id]])
	print("200000 extrageri: ",counts)
	check(Crystal.draw(rng,"chest_gold") == "chest_gold" and Crystal.draw(rng,"necunoscut") in expected,"Forțare numai pentru premii existente")


func wheel_geometry() -> void:
	var wheel := Wheel.new()
	wheel.size = Vector2(600,600)
	root.add_child(wheel)
	var total := 0.0
	for i in range(Crystal.prizes().size()):
		var share: float = wheel.spans[i]/TAU
		check(is_equal_approx(share,Crystal.probability(Crystal.prizes()[i].id)),"Felia %d proporțională cu șansa" % i)
		total += wheel.spans[i]
	check(is_equal_approx(total,TAU),"Feliile acoperă exact roata")
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in range(Crystal.prizes().size()):
		for k in range(200):
			var start := rng.randf_range(-40.0,40.0)
			var end: float = wheel.rotation_for(i,start,5,rng.randf())
			check(end >= start + TAU*5 - 0.0001 and end < start + TAU*6,"Cel puțin 5 ture")
			check(wheel.slice_under_pointer(end) == i,"Indicatorul se oprește pe premiul confirmat")
			# The curve ends exactly on the target and never runs backwards.
			var previous := 0.0
			var monotonic := true
			for step in range(41):
				var t := (WheelScreen.SPIN_ACCEL + WheelScreen.SPIN_DECEL)*step/40.0
				var angle := WheelScreen.spin_curve(t,end - start)
				monotonic = monotonic and angle >= previous - 0.000001
				previous = angle
			check(monotonic and is_equal_approx(previous,end - start),"Accelerare și decelerare continue")
	wheel.free()


func charging_and_spins() -> void:
	var p := prefix + "_tx"
	var game := ForcedSave.new(p)
	check(game.state.version == 6 and game.state.crystal_charge == 0 and game.state.chests == Crystal.empty_chests(),"Salvare nouă v6")
	check(Crystal.target(game.state) == 50 and not Crystal.is_ready(game.state),"Prima țintă 50")
	check(game.spin_wheel().is_empty(),"Rotire refuzată fără încărcare")
	for i in range(49):
		game.state.energy = 100
		check(not game.roll().is_empty(),"Aruncare validă")
		game.busy = false
	check(game.state.crystal_charge == 49 and not Crystal.is_ready(game.state),"49/50 nu este gata")
	game.state.energy = 0
	check(game.roll().is_empty() and int(game.state.crystal_charge) == 49,"Aruncarea fără energie nu încarcă")
	game.state.energy = 100
	game.roll()
	game.busy = false
	check(Crystal.is_ready(game.state) and game.state.crystal_charge == 50,"50/50 gata")
	for i in range(3):
		game.roll()
		game.busy = false
	check(game.state.crystal_charge == 50,"Încărcat rămâne la 50 până la rotire")
	var saved := Save.new(p)
	check(saved.state.crystal_charge == 50 and Crystal.is_ready(saved.state),"Încărcarea este salvată")
	# Energy prize can exceed 100. Regeneration stays suspended above the cap.
	game.state.energy = 90
	game.next_prize = "energy_30"
	var before: Dictionary = game.state.duplicate(true)
	var receipt: Dictionary = game.spin_wheel()
	check(receipt.prize == "energy_30" and game.state.energy == 120,"90 + 30 = 120 energie")
	check(game.state.crystal_charge == 0 and game.state.crystal_activations == 1 and Crystal.target(game.state) == 100,"Consumă încărcarea, următoarea țintă 100")
	check(game.state.board_position_index == before.board_position_index and game.state.levels == before.levels and game.state.wallet == before.wallet and game.state.laps == before.laps,"Poziția, clădirile și soldurile rămân intacte")
	check(game.spin_wheel().is_empty() and game.state.seq == before.seq + 1,"Dublu tap: o singură tranzacție")
	var disk := Save.new(p)
	check(disk.state.energy == 120 and disk.state.crystal_charge == 0 and disk.state.last_spin.id == receipt.id and not disk.state.last_spin.presented,"Încărcare consumată și premiu salvate împreună")
	check(not disk.pending_spin().is_empty(),"Premiul neafișat este recuperabil")
	game.regenerate(int(game.state.tick) + 100000)
	check(game.state.energy == 120,"Regenerare suspendată la cel puțin 100")
	check(game.acknowledge_spin(int(receipt.id)) and not game.acknowledge_spin(int(receipt.id)),"Confirmare unică")
	check(Save.new(p).pending_spin().is_empty() and Save.new(p).state.energy == 120,"Reluarea nu acordă din nou premiul")
	# Normal tile rewards keep the 100 cap: from 120, an energy tile pays nothing extra.
	var near := 0
	game.state.board_position_index = near
	game.state.last_roll = {}
	var roll_game := ForcedSave.new(p + "_roll")
	roll_game.state = game.state.duplicate(true)
	var landing := _roll_pair(roll_game,Vector2i(1,1))
	check(landing.resource != "energy" and roll_game.state.energy == 119,"Căsuțele nu mai acordă energie; de la 120 rămâne doar debitul")
	# Chest prizes and persistence across restarts, through all 100-roll cycles.
	for kind: String in ["wood","silver","gold"]:
		game.state.crystal_charge = Crystal.target(game.state)
		game.next_prize = "chest_" + kind
		var chest: Dictionary = game.spin_wheel()
		check(chest.kind == "chest" and chest.chest == kind and game.state.chests[kind] == 1,"Cufăr " + kind)
		game.acknowledge_spin(int(chest.id))
	var reloaded := Save.new(p)
	check(reloaded.state.chests == {"wood":1,"silver":1,"gold":1} and reloaded.state.crystal_activations == 4,"Inventarul de cufere se păstrează")
	check(typeof(reloaded.state.chests.gold) == TYPE_INT and typeof(reloaded.state.last_spin.id) == TYPE_INT,"Valori întregi după încărcare")
	check(not Save.new(p).has_method("force_prize"),"Forțarea premiului nu există în salvarea normală")
	for slot in range(2):
		DirAccess.remove_absolute("%s_board_v3.%d.json" % [p,slot])
		DirAccess.remove_absolute("%s_roll_board_v3.%d.json" % [p,slot])


func _roll_pair(game: RefCounted, faces: Vector2i) -> Dictionary:
	# Deterministic dice for this check only, through the normal roll transaction.
	var dice := RandomNumberGenerator.new()
	for s in range(100000):
		dice.seed = s
		var probe := Vector2i(dice.randi_range(1,6),dice.randi_range(1,6))
		if probe == faces:
			game.rng.seed = s
			break
	var receipt: Dictionary = game.roll()
	game.busy = false
	return receipt.get("landing",{})


func version_four_compatibility() -> void:
	var p := prefix + "_v4"
	var game := Save.new(p)
	var old: Dictionary = game.state.duplicate(true)
	old.version = 4
	for field in ["crystal_activations","chests","last_spin"]:
		old.erase(field)
	old.wallet = {"coins":9876,"fragments":55,"build_points":33,"tickets":4,"quest_tokens":7}
	old.levels = [3,2,1,0,2,3]
	old.board_position_index = 17
	old.last_roll = {}
	old.laps = 12
	old.energy = 44
	game._commit(old)
	var hashes := _files(p)
	var loaded := Save.new(p)
	check(loaded.error.is_empty() and loaded.state.version == 6,"Salvarea v4 se încarcă")
	check(loaded.state.wallet == old.wallet and loaded.state.levels == old.levels and loaded.state.board_position_index == 17 and loaded.state.laps == 12 and loaded.state.energy == 44,"Progresul v4 rămâne intact")
	check(loaded.state.crystal_charge == 0 and loaded.state.chests == Crystal.empty_chests() and loaded.state.last_spin.is_empty(),"Câmpuri noi neutre")
	check(hashes == _files(p),"Încărcarea nu rescrie salvarea v4")
	loaded.roll()
	check(Save.new(p).state.version == 6 and Save.new(p).state.crystal_charge == 1,"Prima tranzacție scrie v6")
	var corrupt := Save.new(p)
	var bad: Dictionary = corrupt.state.duplicate(true)
	bad.chests.gold = -1
	check(not corrupt._valid_board(bad),"Cufere negative respinse")
	bad = corrupt.state.duplicate(true)
	bad.crystal_charge = 101
	check(not corrupt._valid_board(bad),"Încărcare peste prag respinsă")
	bad = corrupt.state.duplicate(true)
	bad.last_spin = {"id":1,"prize":"premiu_vechi","kind":"chest","amount":1,"chest":"wood","presented":true}
	check(corrupt._valid_board(bad),"Chitanță cu premiu retras rămâne validă")
	for slot in range(2):
		DirAccess.remove_absolute("%s_board_v3.%d.json" % [p,slot])


func _start(p: String) -> Node:
	var map := Scene.instantiate()
	map.save_prefix = p
	root.add_child(map)
	current_scene = map
	return map


func _charge(map: Node) -> void:
	var next: Dictionary = map.game.state.duplicate(true)
	next.crystal_charge = Crystal.target(next)
	map.game._commit(next)
	map._refresh()


func _wait_phase(map: Node, phase: int, limit := 8.0) -> bool:
	var waited := 0.0
	while map.wheel.phase != phase and waited < limit:
		await process_frame
		waited += 1.0/60.0
	return map.wheel.phase == phase


func scene_flow() -> void:
	var p := prefix + "_scene"
	var legacy := Legacy.new(p)
	legacy.debug_grant()
	var map := _start(p)
	await process_frame
	await process_frame
	check(map.hud.crystal_chip.text.contains("0/50"),"HUD arată 0/50")
	var crystal_point: Vector2 = map.camera.unproject_position(map.crystal_glow.crystal_center())
	map._select_at(crystal_point)
	check(not map.wheel_open() and map.message.text.contains("0/50"),"Cristal neîncărcat: doar progres")
	_charge(map)
	check(map.hud.crystal_chip.text.contains("gata") and map.crystal_glow.charged,"Cristalul luminează când este încărcat")
	var before: Dictionary = map.game.state.duplicate(true)
	map._select_at(crystal_point)
	check(map.wheel_open() and map.camera.shot == map.camera.Shot.CRYSTAL,"Atingerea cristalului deschide ruleta cu apropiere")
	map._roll()
	check(map.game.state.seq == before.seq,"Aruncarea este blocată cât timp ruleta este deschisă")
	check(await _wait_phase(map,WheelScreen.Phase.READY),"Ruleta gata de rotire")
	map.wheel._on_spin()
	map.wheel._on_spin()
	map.wheel.spin_button.pressed.emit()
	check(map.game.state.seq == before.seq + 1,"Dublul tap pe ÎNVÂRTE salvează o singură rotire")
	var receipt: Dictionary = map.game.state.last_spin
	check(map.wheel.phase == WheelScreen.Phase.SPINNING and not receipt.presented,"Animația pornește după salvare")
	await create_timer(1.0).timeout
	check(map.wheel.phase == WheelScreen.Phase.SPINNING,"Rotirea durează")
	check(await _wait_phase(map,WheelScreen.Phase.RESULT,6.0),"Roata se oprește")
	check(map.wheel.wheel.slice_under_pointer(map.wheel.wheel.rotation) == Crystal.prize_index(receipt.prize),"Indicatorul arată exact premiul salvat")
	check(map.wheel.result_detail.text.begins_with(Crystal.describe(receipt).substr(0,3)),"Premiul afișat = premiul salvat")
	var after_spin: Dictionary = map.game.state.duplicate(true)
	map.wheel._on_continue()
	map.wheel._on_continue()
	check(map.game.state.last_spin.presented and map.game.state.seq == after_spin.seq + 1,"Revenire: o singură confirmare")
	check(map.game.state.energy == after_spin.energy and map.game.state.chests == after_spin.chests,"Revenirea nu modifică soldurile")
	check(map.camera.shot == map.camera.Shot.RETURN or map.camera.shot == map.camera.Shot.OVERVIEW,"Camera revine la hartă")
	await create_timer(0.5).timeout
	check(not map.wheel_open() and not map.wheel.visible,"Ecranul ruletei se închide")
	# "Later" keeps the crystal charged.
	_charge(map)
	map.open_crystal()
	await _wait_phase(map,WheelScreen.Phase.READY)
	var charged_seq: int = map.game.state.seq
	map.wheel._on_later()
	await create_timer(0.5).timeout
	check(not map.wheel_open() and Crystal.is_ready(map.game.state) and map.game.state.seq == charged_seq,"Mai târziu: cristalul rămâne încărcat")
	# Close the game in the middle of the spin animation.
	map.open_crystal()
	await _wait_phase(map,WheelScreen.Phase.READY)
	map.wheel._on_spin()
	var confirmed: Dictionary = map.game.state.duplicate(true)
	await create_timer(0.6).timeout
	check(map.wheel.phase == WheelScreen.Phase.SPINNING,"Închidere în timpul animației")
	map.free()
	map = _start(p)
	await process_frame
	await process_frame
	check(map.wheel_open() and map.wheel.phase == WheelScreen.Phase.RESULT,"La redeschidere se afișează premiul confirmat")
	check(map.game.state.energy == confirmed.energy and map.game.state.chests == confirmed.chests and map.game.state.wallet == confirmed.wallet,"Recuperare fără acordare dublă")
	check(map.game.state.board_position_index == confirmed.board_position_index and map.game.state.levels == confirmed.levels,"Poziția și nivelurile rămân intacte")
	map.wheel._on_continue()
	check(map.game.pending_spin().is_empty() and map.game.state.energy == confirmed.energy,"Confirmare după restart")
	map.free()
	map = _start(p)
	await process_frame
	await process_frame
	check(not map.wheel_open(),"A doua repornire nu mai afișează premiul")
	# Tapping during the spin only fast-forwards the presentation.
	_charge(map)
	map.open_crystal()
	await _wait_phase(map,WheelScreen.Phase.READY)
	map.wheel._on_spin()
	var tap := InputEventMouseButton.new()
	tap.pressed = true
	tap.button_index = MOUSE_BUTTON_LEFT
	map.wheel._screen_input(tap)
	check(map.wheel.phase == WheelScreen.Phase.RESULT and map.wheel.wheel.slice_under_pointer(map.wheel.wheel.rotation) == Crystal.prize_index(map.game.state.last_spin.prize),"Grăbirea se oprește tot pe premiul salvat")
	map.wheel._on_continue()
	map.free()
	for slot in range(2):
		DirAccess.remove_absolute("%s_board_v3.%d.json" % [p,slot])
		DirAccess.remove_absolute(legacy._path(slot))


func developer_tools() -> void:
	var normal := Save.new(prefix + "_normal")
	normal._commit(normal.state.duplicate(true))
	var normal_files := _files(prefix + "_normal")
	var map := _start(Profile.PREFIX)
	await process_frame
	var profile: Profile = map.game
	var panel = map.get_node("DeveloperPanel")
	check(profile.allowed() and profile.reset_profile(true),"Profil DEBUG separat")
	check(profile.set_crystal(49,0) and Crystal.charge(profile.state) == 49 and Crystal.target(profile.state) == 50,"DEBUG 49/50")
	profile.set_resource("energy",100)
	profile.roll()
	profile.busy = false
	check(Crystal.is_ready(profile.state),"A 50-a aruncare încarcă cristalul")
	check(profile.set_crystal(99,1) and Crystal.target(profile.state) == 100 and Crystal.charge(profile.state) == 99,"DEBUG 99/100")
	check(profile.charge_crystal() and Crystal.is_ready(profile.state),"Încărcare instantanee")
	check(profile.force_prize("chest_gold") and not profile.force_prize("inexistent"),"Forțare premiu validată")
	var receipt := profile.spin_wheel()
	check(receipt.prize == "chest_gold" and profile.forced_prize.is_empty() and profile.state.chests.gold >= 1,"Premiu forțat o singură dată")
	profile.acknowledge_spin(int(receipt.id))
	var kept: Dictionary = profile.state.duplicate(true)
	var report := profile.simulate_spins(10000)
	check(report.spins == 10000 and report.double_grants == 0 and profile.state == kept,"10000 rotiri simulate, profil neatins")
	for id: String in report.expected_percent:
		check(absf(float(report.observed_percent[id]) - float(report.expected_percent[id])) < 1.5,"Simulare apropiată de șansă " + id)
	check(profile.set_chests(2,1,0) and profile.state.chests == {"wood":2,"silver":1,"gold":0},"Inventar cufere DEBUG")
	panel.test_recovery()
	await process_frame
	await process_frame
	await process_frame
	var restarted: Node = current_scene
	check(restarted != map and restarted.wheel_open() and restarted.wheel.phase == WheelScreen.Phase.RESULT,"Test recuperare: premiul reapare după repornire")
	var recovered: Dictionary = restarted.game.state.duplicate(true)
	restarted.wheel._on_continue()
	check(restarted.game.state.energy == recovered.energy and restarted.game.state.chests == recovered.chests and restarted.game.pending_spin().is_empty(),"Test recuperare fără acordare dublă")
	check(_files(prefix + "_normal") == normal_files,"Salvarea normală rămâne neatinsă")
	restarted.free()
	for slot in range(2):
		DirAccess.remove_absolute("%s_normal_board_v3.%d.json" % [prefix,slot])


func _run() -> void:
	config_and_odds()
	wheel_geometry()
	charging_and_spins()
	version_four_compatibility()
	await scene_flow()
	await developer_tools()
	print("Super Cristal: %d verificări, %d erori." % [checks,failures])
	quit(1 if failures else 0)
