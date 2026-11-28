extends SceneTree

const Scene := preload("res://scenes/board.tscn")
const Legacy := preload("res://scripts/crystal/progress.gd")
const Save := preload("res://scripts/board/board_save.gd")
const Dice := preload("res://scripts/board/dice_roll.gd")
const ECONOMY := preload("res://assets/board/economy.tres")
const EXPECTED := {
	"coin":{"coins":[100,110,125,150]},
	"crystal":{"fragments":[5,6,7,8]}, "construction":{"build_points":[2,3,4,5]},
	"quest":{"quest_tokens":[1,2,3,4]}, "magic":{"coins":[75,83,94,113],"fragments":[2,3,4,5]}}
const TYPES := ["crystal","event_energy","construction","magic","coin","quest"]
var prefix := "user://rewards_%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()]
var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(description)


func start_map():
	var map := Scene.instantiate()
	map.save_prefix = prefix
	root.add_child(map)
	return map


func seed_for(sum: int) -> int:
	var rng := RandomNumberGenerator.new()
	for candidate in range(10000):
		rng.seed = candidate
		var pair := Dice.draw(rng)
		if pair.x + pair.y == sum:
			return candidate
	return -1


func prepare(game: RefCounted, origin: int, sum: int, energy := 40) -> void:
	game.busy = false
	var state: Dictionary = game.state.duplicate(true)
	state.board_position_index = origin
	state.energy = energy
	state.tick = int(Time.get_unix_time_from_system())
	state.last_roll = {}
	check(game._commit(state),"Creare poziție de test")
	game.rng.seed = seed_for(sum)


func market_flow(map: Node) -> void:
	map._select_at(map.camera.unproject_position(map.plots.get_child(4).position + Vector3.UP*0.3))
	check(map.selected_plot == 4 and map.hud.price.text.contains("Nivel 1 → 2\nToate căsuțele cu monede · 110 → 125 monede"),"Previzualizarea Pieței")
	check(map.path.studs.multimesh.instance_count == 7,"Marcaj de nivel pe fiecare dală a Pieței")
	check(map.path.selected_tiles == PackedInt32Array([1,7,11,13,19,26,32]),"Toate cele șapte dale cu monede")
	check(map.hud.price.text.contains("3000 monede + 25 puncte"),"Costul înaintea cumpărării")
	var coins := int(map.game.state.wallet.coins)
	var points := int(map.game.state.wallet.build_points)
	map.hud.confirm.pressed.emit()
	check(map.path.studs.multimesh.instance_count == 14,"Marcajele de nivel după îmbunătățire")
	check(map.village.levels[4] == 2 and map.game.state.levels[4] == 2 and map.hud.price.text.contains("125 → 150"),"Model și previzualizare după confirmare")
	check(map.game.state.wallet.coins == coins-3000 and map.game.state.wallet.build_points == points-25,"Costul cumpărării")
	map._deselect()
	prepare(map.game,25,7)
	coins = int(map.game.state.wallet.coins)
	map.hud.roll_button.pressed.emit()
	var confirmed: Dictionary = map.game.state.duplicate(true)
	map.hud.roll_button.pressed.emit()
	map.hud.skip.pressed.emit()
	check(map.game.state == confirmed and not map.game.busy,"Dublu tap + Grăbește păstrează tranzacția")
	check(map.visual_tile == 32 and map.game.state.wallet.coins == coins+125,"Aterizare pe dală după upgrade")
	check(map.hud.get_node("Premiu").text == "+125 monede\nPiața Poznașă · niv. 2" and map.path.markers[32].visible,"Suma afișată și lumina dalei")
	print("Piața · nivel 1 → 2 · dale 1/7/13/19/26/32 · aterizare pe 32 · +125 monede")


func check_balance(before: Dictionary, after: Dictionary, award: Dictionary, bonus: int) -> void:
	var key: String = award.get("resource","")
	var amount := int(award.get("amount",0))
	for resource: String in before.wallet:
		var delta := amount if resource == key else 0
		if resource == "coins":
			delta += bonus
		check(after.wallet[resource] == before.wallet[resource] + delta,"Sold exact pentru " + resource)
	check(key != "energy" and after.energy == before.energy - 1,"Energie: doar debitul aruncării, fără premiu de pe traseu")
	check(after.laps == before.laps + int(bonus > 0),"Numărul de tururi")


func zones_and_rewards(map: Node) -> void:
	var game: RefCounted = map.game
	for slot in range(6):
		var building: String = game.cfg.buildings.positions[slot].id
		for count in range(30,37):
			var zone := ECONOMY.tiles_for(building,count)
			if building == "right_top":
				check(zone.is_empty(),"Moara fără dale la %d dale" % count)
				continue
			check(zone.size() >= 3 and not zone.has(0),"Zona pentru %d dale" % count)
		var tiles := ECONOMY.tiles_for(building,36)
		if TYPES[slot] == "event_energy":
			check(tiles.is_empty(),"Moara nu deține nicio căsuță: energia nu vine de pe traseu")
			continue
		map._select_at(map.camera.unproject_position(map.plots.get_child(slot).position+Vector3.UP*0.3))
		for i in range(36):
			check(map.path.markers[i].visible == tiles.has(i),"Evidențiere exclusivă pentru " + building)
		for level in range(4):
			var tile := tiles[1]
			game.state.levels[slot] = level
			map._refresh()
			if level == 3:
				check(map.hud.price.text.contains("Nivel maxim") and not map.hud.confirm.visible,"Nivel maxim")
			var type: String = TYPES[slot]
			var seen := {}
			for attempt in range(36):
				# Test with actual random pairs. Choose the origin so each roll lands on the target.
				var rng := RandomNumberGenerator.new()
				rng.seed = attempt
				var pair := Dice.draw(rng)
				prepare(game,posmod(tile-pair.x-pair.y,36),pair.x+pair.y)
				game.rng.seed = attempt
				var before: Dictionary = game.state.duplicate(true)
				var receipt: Dictionary = game.roll()
				var reward: Dictionary = receipt.landing
				var resource: String = reward.resource
				seen[resource] = true
				check(game.state.board_position_index == tile and EXPECTED[type].has(resource),"Tipul de aterizare")
				check(reward.amount == EXPECTED[type][resource][level],"Valoare configurată nivel %d" % level)
				check(map.hud.price.text.contains(str(int(reward.amount))),"Previzualizare și recompensă")
				check_balance(before,game.state,reward,100 if before.board_position_index > tile else 0)
				game.busy = false
				if seen.size() == EXPECTED[type].size():
					break
			check(seen.size() == EXPECTED[type].size(),"Toate alternativele la " + type)
		map._deselect()


func landing_labels(map: Node) -> void:
	var rewards_seen := {}
	for dest in [3,10,15,20,24,32]:
		for seed_value in range(36):
			var rng := RandomNumberGenerator.new()
			rng.seed = seed_value
			var faces := Dice.draw(rng)
			prepare(map.game,posmod(dest-faces.x-faces.y,36),faces.x+faces.y)
			map.game.rng.seed = seed_value
			var before: Dictionary = map.game.state.duplicate(true)
			map._roll()
			map._finish()
			var receipt: Dictionary = map.game.state.last_roll
			var award: Dictionary = receipt.landing
			var gain: int = int(map.game.state.wallet[award.resource] - before.wallet[award.resource])
			if award.resource == "coins":
				gain -= int(receipt.start_coins)
			var label: Label = map.hud.get_child(-1)
			var units: String = ECONOMY.unit(award.resource,gain)
			check(label.text.get_slice("\n",0) == "+%d %s" % [gain,units],"Mesajul de aterizare corespunde soldului")
			rewards_seen["%d/%s" % [dest,award.resource]] = true
			if dest != 10 or (rewards_seen.has("10/coins") and rewards_seen.has("10/fragments")):
				break
	check(rewards_seen.size() == 7,"Șase pictograme și ambele premii ale magiei")


func start_cases(map: Node) -> void:
	var game: RefCounted = map.game
	game.state.levels.fill(0)
	for sum in [5,2]:
		prepare(game,34,sum)
		var before: Dictionary = game.state.duplicate(true)
		map._roll()
		var receipt: Dictionary = game.state.last_roll
		check(receipt.start_coins == 100 and game.state.board_position_index == (34+sum)%36,"START din 34, suma %d" % sum)
		if sum == 2:
			check(receipt.landing.is_empty(),"Oprirea pe START acordă numai bonusul")
		else:
			check(receipt.landing == {"resource":"quest_tokens","amount":1},"34+5 plătește și dala 3")
		check_balance(before,game.state,receipt.landing,100)
		map.hud.skip.pressed.emit()
	var confirmed := Save.new(prefix)
	check(confirmed.state.wallet == game.state.wallet and confirmed.state.laps == game.state.laps,"Redeschidere pe START")
	prepare(game,0,3)
	var coins := int(game.state.wallet.coins)
	map._roll()
	map._finish()
	check(game.state.wallet.coins == coins and game.state.last_roll.start_coins == 0,"Plecare de pe START")


func interruptions(map: Node) -> void:
	prepare(map.game,0,2,100)
	map._roll()
	check(map.game.state.energy == 99 and map.game.state.last_roll.landing.resource == "fragments","Căsuța 2 nu mai plătește energie")
	map._finish()
	prepare(map.game,5,5)
	map._roll()
	var confirmed: Dictionary = map.game.state.duplicate(true)
	map.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	map.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	map._finish()
	check(not map.game.busy and map.game.state == confirmed,"Reluare și Grăbește după magie")
	prepare(map.game,6,4)
	map._roll()
	confirmed = map.game.state.duplicate(true)
	map.free()
	map = start_map()
	check(map.visual_tile == 10 and map.game.state == confirmed and not map.game.busy,"Închidere în mers, aceeași magie și același sold")
	var real_prefix: String = map.game.save_prefix
	map.game.save_prefix += "/inexistent"
	map._roll()
	check(not map.game.error.is_empty() and not map.game.busy and map.visual_tile == 10 and map.game.state == confirmed,"Scriere eșuată fără debit, mutare sau premiu")
	map.game.save_prefix = real_prefix
	check(Save.new(prefix).state == confirmed,"Salvarea anterioară rămâne intactă")
	map.free()


func migrate_stage_one() -> void:
	var old_prefix := prefix + "_old"
	var initial := Save.new(old_prefix)
	var old := initial.state.duplicate(true)
	old.version = 3
	old.wallet.erase("quest_tokens")
	old.wallet.tickets = 71
	old.wallet.fragments = 19
	old.board_position_index = 0
	old.last_roll = {"a":1,"b":1,"from":34}
	old.laps = 17
	old.energy = 29
	old.levels = [2,3,1,2,2,3]
	initial._commit(old)
	var hash_before := FileAccess.get_sha256(initial._path(int(old.seq)%2))
	var migrated := Save.new(old_prefix)
	var backup := initial.save_prefix + ".stage1.bak"
	check(FileAccess.get_sha256(backup) == hash_before,"Backup identic cu ultima salvare a etapei 1")
	var expected := old.duplicate(true)
	expected.seq += 1
	expected.version = 7
	expected.wallet.quest_tokens = 0
	check(migrated.state == expected and Save.new(old_prefix).state == expected,"Migrare integrală și idempotentă, fără bonus retroactiv")
	for slot in range(2):
		DirAccess.remove_absolute(initial._path(slot))
	DirAccess.remove_absolute(backup)


func global_categories(map: Node) -> void:
	var game: RefCounted = map.game
	check(map.path.centers.size() == 36 and ECONOMY.tile_types.size() == 36,"Exact 36 de căsuțe")
	check(ECONOMY.kind(0,36) == "start" and ECONOMY.owner(0,36).is_empty(),"START separat")
	var counts := {}
	for tile in range(36):
		var type := ECONOMY.kind(tile,36)
		counts[type] = int(counts.get(type,0))+1
		check(not (type == ECONOMY.kind((tile+1)%36,36) and type == ECONOMY.kind((tile+2)%36,36)),"Fără triple, inclusiv închiderea buclei")
	check(counts == {"start":1,"coin":7,"crystal":7,"construction":7,"magic":7,"quest":7},"Distribuție echilibrată, fără energie")
	check(not ECONOMY.tile_types.has("energy") and not ECONOMY.payouts.has("energy"),"Nicio căsuță și niciun tabel de energie")
	for tile in range(36):
		check(ECONOMY.kind(tile,36) != ECONOMY.kind((tile+1)%36,36),"Căsuțe vecine diferite, inclusiv 35→0")
	for slot in range(6):
		for level in range(4):
			game.state.levels.fill(3)
			game.state.levels[slot] = level
			for tile in range(1,36):
				var kind := ECONOMY.kind(tile,36)
				var owner_slot: int = TYPES.find(kind)
				check(game.building_at(tile) == owner_slot,"Categoria are o singură clădire")
				prepare(game,posmod(tile-2,36),2)
				var before: Dictionary = game.state.duplicate(true)
				var receipt: Dictionary = game.roll()
				var reward: Dictionary = receipt.landing
				var expected_level := level if owner_slot == slot else 3
				check(EXPECTED[kind].has(reward.resource),"Premiu exclusiv categoriei")
				check(reward.amount == EXPECTED[kind][reward.resource][expected_level],"Nivel global pe orice dală, celelalte categorii independente")
				check_balance(before,game.state,reward,100 if tile == 1 else 0)
				game.busy = false
	map._deselect()
	check(map.path.selected_tiles.is_empty(),"Deselectarea șterge evidențierea globală")
	print("Global · monede 1/7/13/19/26/32 · toate oferă 125 la nivelul 2")


func load_previous_layout() -> void:
	var old_prefix := prefix+"_previous"
	var game := Save.new(old_prefix)
	var old: Dictionary = game.state.duplicate(true)
	old.wallet = {"coins":12417,"fragments":83,"build_points":61,"tickets":19,"quest_tokens":27}
	old.energy = 67
	old.levels = [1,3,2,2,2,1]
	old.laps = 24
	old.board_position_index = 4
	# Tile 4 used to pay a quest token; the receipt must survive its new crystal type.
	old.last_roll = {"a":2,"b":2,"from":0,"start_coins":0,"landing":{"resource":"quest_tokens","amount":2}}
	game._commit(old)
	var saved: Dictionary = game.state.duplicate(true)
	var hashes := [FileAccess.get_sha256(game._path(0)),FileAccess.get_sha256(game._path(1))]
	var loaded := Save.new(old_prefix)
	check(loaded.state == saved,"Toate câmpurile versiunii 4 se păstrează integral")
	check(loaded.state.last_roll.landing.resource == "quest_tokens" and ECONOMY.kind(4,36) == "crystal","Chitanța veche rămâne confirmată după redistribuire")
	check(hashes == [FileAccess.get_sha256(game._path(0)),FileAccess.get_sha256(game._path(1))],"Încărcarea nu rescrie salvările vechi")
	for slot in range(2):
		DirAccess.remove_absolute(game._path(slot))


func _run() -> void:
	var legacy := Legacy.new(prefix)
	legacy.debug_grant()
	legacy.upgrade(4,0)
	var map = start_map()
	await process_frame
	market_flow(map)
	zones_and_rewards(map)
	global_categories(map)
	load_previous_layout()
	landing_labels(map)
	start_cases(map)
	interruptions(map)
	migrate_stage_one()
	for slot in range(2):
		DirAccess.remove_absolute(legacy._path(slot))
		DirAccess.remove_absolute(prefix+"_board_v3.%d.json" % slot)
	print("Economie: %d verificări, %d erori." % [checks,failures])
	quit(1 if failures else 0)
