extends "res://scripts/save_game.gd"
## Every purchase/roll is written as one snapshot before it becomes visible.
## Alternate slots retain an independently recoverable previous generation.
const Rewards := preload("res://scripts/crystal/rewards.gd")
const VERSION := 1

var engine := Rewards.new()
var forced: Array = []


func _init(prefix := "user://satul_trasnitilor", now := int(Time.get_unix_time_from_system()), read_only := false) -> void:
	cfg = engine.config
	save_prefix = prefix
	if not engine.valid():
		error = "Configurația cristalului este invalidă."
		return
	state = {"version": VERSION, "seq": 0, "wallet": cfg.starting_resources.duplicate(),
		"energy": int(cfg.energy.max), "tick": now, "charge": 0, "armed": false,
		"levels": [0, 0, 0, 0, 0, 0], "last": {}}
	for i in range(2):
		var path := _path(i)
		if not FileAccess.file_exists(path):
			continue
		var json := JSON.new()
		if json.parse(FileAccess.get_file_as_string(path)) == OK and _valid(json.data):
			if int(json.data.seq) > int(state.seq):
				state = _typed_snapshot(json.data)
		else:
			recovery_notice = "Salvarea deteriorată a fost ignorată."
	if not read_only:
		regenerate(now)


# JSON reads numbers as floats. Restore integer counters at the persistence boundary.
func _typed_snapshot(data: Dictionary) -> Dictionary:
	for key: String in ["seq","version","energy","tick","charge"]:
		data[key] = int(data[key])
	for key: String in Rewards.WALLET:
		data.wallet[key] = int(data.wallet[key])
	for i in range(data.levels.size()):
		data.levels[i] = int(data.levels[i])
	if not data.last.is_empty():
		for key: String in data.last.reward:
			data.last.reward[key] = int(data.last.reward[key])
	return data


func _valid(data: Variant) -> bool:
	if not data is Dictionary or not data.has_all(["version","seq","wallet","energy","tick","charge","armed","levels","last"]):
		return false
	if data.version != VERSION or not _integer(data.seq) or not _integer(data.tick) or not _integer(data.energy, int(cfg.energy.max)) or not _integer(data.charge, int(cfg.super_crystal.charge_max)):
		return false
	if not data.armed is bool or (data.armed and data.charge != cfg.super_crystal.charge_max):
		return false
	if not data.wallet is Dictionary or not data.levels is Array or data.levels.size() != 6:
		return false
	for key: String in Rewards.WALLET:
		if not _integer(data.wallet.get(key)):
			return false
	for level: Variant in data.levels:
		if not _integer(level, int(cfg.buildings.max_level)):
			return false
	if not data.last is Dictionary:
		return false
	if not data.last.is_empty():
		var last: Dictionary = data.last
		if not last.has_all(["symbols","reward","combo","super"]) or not last.symbols is Array or last.symbols.size() != 3 or not last.reward is Dictionary or not last.super is bool or not last.combo in ["","pair","mixed","triple"]:
			return false
		for key: Variant in last.symbols:
			if not key in Rewards.KEYS:
				return false
		for key: Variant in last.reward:
			if not key in Rewards.WALLET or not _integer(last.reward[key]):
				return false
	return true


func activate(now := int(Time.get_unix_time_from_system())) -> Dictionary:
	if busy or state.is_empty():
		return {}
	var next := state.duplicate(true)
	_regen(next, now)
	if next.energy < cfg.activation.energy_cost:
		return {}
	if next.energy == cfg.energy.max:
		next.tick = now
	busy = true
	var keys: Array = []
	if OS.is_debug_build() and forced.size() == 3 and engine.symbols.has_all(forced):
		keys = forced.duplicate()
	else:
		for i in range(int(cfg.activation.symbols_per_activation)):
			keys.append(engine.roll_symbol(rng))
	var result := engine.resolve(keys, rng, next.armed)
	next.energy = int(next.energy) - int(cfg.activation.energy_cost)
	for key: String in result.reward:
		next.wallet[key] = int(next.wallet[key]) + int(result.reward[key])
	next.charge = int(cfg.super_crystal.charge_after_special_activation) if next.armed else mini(int(cfg.super_crystal.charge_max), int(next.charge) + int(cfg.super_crystal.charge_per_normal_activation))
	next.armed = false
	next.last = result
	if not _commit(next):
		busy = false
		return {}
	forced.clear()
	return result


func arm() -> bool:
	if busy or state.armed or state.charge != cfg.super_crystal.charge_max:
		return false
	var next := state.duplicate(true)
	next.armed = true
	return _commit(next)


func debug_grant() -> bool:
	if not OS.is_debug_build() or busy:
		return false
	var next := state.duplicate(true)
	for key: String in Rewards.WALLET:
		next.wallet[key] = int(next.wallet[key]) + (12000 if key == "coins" else 80)
	next.energy = int(cfg.energy.max)
	next.charge = int(cfg.super_crystal.charge_max)
	return _commit(next)
