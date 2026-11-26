extends "res://scripts/save_game.gd"

const Legacy := preload("res://scripts/crystal/progress.gd")
const Dice := preload("res://scripts/board/dice_roll.gd")
const RULES := preload("res://assets/board/rules.tres")
const ECONOMY := preload("res://assets/board/economy.tres")
const Crystal := preload("res://scripts/crystal/super_crystal_service.gd")
const WALLET := ["coins","build_points","fragments","tickets"]
const VERSION := 5


func _init(prefix := "user://satul_trasnitilor", now := int(Time.get_unix_time_from_system())) -> void:
	save_prefix = prefix + "_board_v3"
	cfg = preload("res://CONFIG_PROTOTIP.json").data.duplicate(true)
	cfg.energy.max = RULES.energy_max
	cfg.energy.regenerate_one_per_minutes = RULES.regeneration_seconds / 60.0
	cfg.activation.energy_cost = RULES.energy_cost
	var found := false
	var loaded_path := ""
	for slot in range(2):
		var path := _path(slot)
		if not FileAccess.file_exists(path):
			continue
		found = true
		var reader := JSON.new()
		if reader.parse(FileAccess.get_file_as_string(path)) == OK and _valid_board(reader.data):
			if state.is_empty() or reader.data.seq > state.seq:
				state = reader.data
				loaded_path = path
		else:
			recovery_notice = "O copie a salvării V3 este deteriorată."
	if state.is_empty():
		if found:
			error = "Salvarea V3 necesită recuperare. Copiile existente sunt păstrate."
			return
		# Migration is read-only, even when regeneration is due in the old save.
		var legacy := Legacy.new(prefix,now,true)
		if legacy.state.is_empty() or (legacy.state.seq == 0 and not legacy.recovery_notice.is_empty()):
			error = "Progresul V2 necesită recuperare înainte de migrare."
			return
		var old := legacy.state
		state = {"seq":0}
		var next := {"version":VERSION,"mode":"board_v3","seq":0,"wallet":old.wallet.duplicate(),
			"energy":old.energy,"tick":old.tick,"levels":old.levels.duplicate(),
			"board_position_index":0,"tile_count":RULES.tile_count,"laps":0,"last_roll":{},
			"crystal_charge":0,"super_crystal_remaining_landings":0}
		_add_crystal_fields(next)
		next.wallet.quest_tokens = 0
		if not _commit(next):
			state.clear()
			return
		recovery_notice = legacy.recovery_notice
	if state.version == 3:
		var backup := save_prefix + ".stage1.bak"
		if not FileAccess.file_exists(backup):
			var temp := backup + ".tmp"
			if DirAccess.copy_absolute(loaded_path, temp) != OK or DirAccess.rename_absolute(temp, backup) != OK:
				error = "Copia pentru migrare nu a putut fi salvată."
				state.clear()
				return
		var migrated := state.duplicate(true)
		migrated.version = VERSION
		migrated.wallet.quest_tokens = int(migrated.wallet.get("quest_tokens", 0))
		_add_crystal_fields(migrated)
		if not _commit(migrated):
			state.clear()
			return
	if state.version == 4:
		# Version 5 only adds Super Crystal fields with neutral defaults. The file is
		# rewritten by the next real transaction, never by loading.
		state.version = VERSION
		_add_crystal_fields(state)
	state.wallet.quest_tokens = int(state.wallet.quest_tokens)
	# JSON numbers are doubles. Restore integer resource and movement counters.
	for field: String in ["version","energy","seq","tick","laps","board_position_index","tile_count","crystal_charge","super_crystal_remaining_landings"]:
		state[field] = int(state[field])
	for key: String in WALLET:
		state.wallet[key] = int(state.wallet[key])
	var last: Dictionary = state.last_roll
	for field: String in ["a","b","from","start_coins"]:
		if last.has(field):
			last[field] = int(last[field])
	if last.has("landing") and not last.landing.is_empty():
		last.landing.amount = int(last.landing.amount)
	for i in range(6):
		state.levels[i] = int(state.levels[i])
	state.crystal_activations = int(state.crystal_activations)
	for kind: String in Crystal.CHEST_KINDS:
		state.chests[kind] = int(state.chests[kind])
	for field: String in ["id","amount"]:
		if state.last_spin.has(field):
			state.last_spin[field] = int(state.last_spin[field])
	# Keep the closest equivalent tile when tuning the length of the circuit.
	if int(state.tile_count) != RULES.tile_count:
		var next := state.duplicate(true)
		next.board_position_index = roundi(float(next.board_position_index) * RULES.tile_count / next.tile_count) % RULES.tile_count
		next.tile_count = RULES.tile_count
		next.last_roll = {}
		if not _commit(next):
			state.clear()
			return
	regenerate(now)


func _valid_board(s: Variant) -> bool:
	if not s is Dictionary or not s.has_all(["mode","version","seq","energy","tick","wallet","levels","board_position_index","tile_count","laps","last_roll","crystal_charge","super_crystal_remaining_landings"]):
		return false
	if s.mode != "board_v3" or not (s.version == 3 or s.version == 4 or s.version == VERSION) or not _integer(s.seq) or not _integer(s.tick) or not _integer(s.energy,Crystal.energy_limit()) or not _integer(s.laps):
		return false
	if not _integer(s.tile_count,36) or s.tile_count < 30 or not _integer(s.board_position_index,int(s.tile_count)-1):
		return false
	if not s.wallet is Dictionary or not s.levels is Array or s.levels.size() != 6 or not s.last_roll is Dictionary:
		return false
	if (s.version == 4 or s.wallet.has("quest_tokens")) and not _integer(s.wallet.get("quest_tokens")):
		return false
	for key: String in WALLET:
		if not _integer(s.wallet.get(key)):
			return false
	for level: Variant in s.levels:
		if not _integer(level,3):
			return false
	if not s.last_roll.is_empty():
		var r: Dictionary = s.last_roll
		if not r.has_all(["a","b","from"]) or not _integer(r.a,6) or not _integer(r.b,6) or mini(int(r.a),int(r.b)) < 1 or not _integer(r.from,int(s.tile_count)-1):
			return false
		if (int(r.from) + int(r.a) + int(r.b)) % int(s.tile_count) != s.board_position_index:
			return false
		if r.has("landing") or r.has("start_coins"):
			if not _integer(r.get("start_coins")) or not r.get("landing") is Dictionary:
				return false
			if int(s.board_position_index) == 0:
				if not r.landing.is_empty():
					return false
			elif not ECONOMY.UNITS.has(r.landing.get("resource")) or not _integer(r.landing.get("amount")):
				return false
	if s.version == VERSION and not Crystal.valid_fields(s,_integer):
		return false
	return _integer(s.crystal_charge,Crystal.max_target()) and _integer(s.super_crystal_remaining_landings,3)


func _add_crystal_fields(s: Dictionary) -> void:
	if not s.has("crystal_activations"):
		s.crystal_activations = 0
	if not s.has("chests"):
		s.chests = Crystal.empty_chests()
	if not s.has("last_spin"):
		s.last_spin = {}


func roll(now := int(Time.get_unix_time_from_system())) -> Dictionary:
	if busy or state.is_empty():
		return {}
	var next := state.duplicate(true)
	_regen(next,now)
	if next.energy < RULES.energy_cost:
		return {}
	var faces := _draw_faces()
	var origin := int(next.board_position_index)
	var steps := Dice.walk(origin,faces,RULES.tile_count)
	if next.energy >= RULES.energy_max:
		next.tick = now
	next.energy = int(next.energy) - RULES.energy_cost
	next.board_position_index = steps[-1]
	var bonus := 0
	if steps.has(0):
		next.laps = int(next.laps) + 1
		bonus = ECONOMY.start_coins
		next.wallet.coins = int(next.wallet.coins) + bonus
	var slot := building_at(steps[-1])
	var level := int(next.levels[slot]) if slot >= 0 else 0
	var landing := ECONOMY.award(steps[-1], RULES.tile_count, level, maxi(0,RULES.energy_max - int(next.energy)), rng)
	if not landing.is_empty():
		if landing.resource == "energy":
			next.energy += landing.amount
		else:
			next.wallet[landing.resource] = int(next.wallet[landing.resource]) + int(landing.amount)
	next.last_roll = {"a":faces.x,"b":faces.y,"from":origin,"start_coins":bonus,"landing":landing}
	Crystal.charge_after_roll(next)
	if not _commit(next):
		return {}
	busy = true
	return next.last_roll


func building_at(index: int) -> int:
	var id := ECONOMY.owner(index, RULES.tile_count)
	for slot in range(cfg.buildings.positions.size()):
		if cfg.buildings.positions[slot].id == id:
			return slot
	return -1


func _draw_faces() -> Vector2i:
	return Dice.draw(rng)


## Magic Wheel transaction: the prize is drawn once, then the consumed charge, the prize and
## the receipt are written in the same save. The animation only presents this receipt.
func spin_wheel(now := int(Time.get_unix_time_from_system())) -> Dictionary:
	if busy or state.is_empty() or not Crystal.is_ready(state) or not pending_spin().is_empty():
		return {}
	var next := state.duplicate(true)
	_regen(next,now)
	var receipt := Crystal.spin(next,_draw_prize())
	if receipt.is_empty() or not _commit(next):
		return {}
	return receipt.duplicate()


## A confirmed prize whose presentation has not been acknowledged (e.g. closed during the spin).
func pending_spin() -> Dictionary:
	var receipt: Dictionary = state.get("last_spin",{})
	return receipt if not receipt.is_empty() and not receipt.presented else {}


## Marks the presentation as seen. Balances are untouched, so repeating it never grants twice.
func acknowledge_spin(id: int) -> bool:
	var receipt := pending_spin()
	if busy or receipt.is_empty() or int(receipt.id) != id:
		return false
	var next := state.duplicate(true)
	next.last_spin.presented = true
	return _commit(next)


func _draw_prize() -> String:
	return Crystal.draw(rng)
