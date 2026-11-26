extends RefCounted

var state: Dictionary = {}
var cfg: Dictionary
var busy := false
var error := ""
var recovery_notice := ""
var save_prefix: String
var rng := RandomNumberGenerator.new()


func _path(index: int) -> String:
	return "%s.%d.json" % [save_prefix, index]


func _integer(value: Variant, maximum := 9007199254740991) -> bool:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false
	return value >= 0 and value <= maximum and value == floor(value)


func _commit(next: Dictionary) -> bool:
	next.seq = int(state.seq) + 1
	var target := _path(int(next.seq) % 2)
	var temporary := target + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(next))
		file.flush()
		var ok := file.get_error() == OK
		file.close()
		if ok and DirAccess.rename_absolute(temporary, target) == OK:
			state = next
			error = ""
			return true
	error = "Salvarea a eșuat. Verifică spațiul disponibil și reîncearcă."
	return false


func _regen(next: Dictionary, now: int) -> void:
	if int(next.energy) >= int(cfg.energy.max):
		return
	var interval := int(cfg.energy.regenerate_one_per_minutes * 60)
	var count := floori(float(maxi(0, now - int(next.tick))) / interval)
	if count > 0:
		next.energy = mini(int(cfg.energy.max), int(next.energy) + count)
		next.tick = now if next.energy == cfg.energy.max else int(next.tick) + count * interval


func regenerate(now := int(Time.get_unix_time_from_system())) -> void:
	if state.is_empty() or state.energy >= cfg.energy.max or now - int(state.tick) < cfg.energy.regenerate_one_per_minutes * 60:
		return
	var next := state.duplicate(true)
	_regen(next, now)
	if next.energy != state.energy:
		_commit(next)


func upgrade(slot: int, from_level: int) -> bool:
	if busy or slot < 0 or slot >= state.levels.size() or state.levels[slot] != from_level or from_level >= cfg.buildings.max_level:
		return false
	var price: Dictionary = cfg.buildings.costs_to_reach_level[str(from_level + 1)]
	var next := state.duplicate(true)
	for key: String in price:
		if next.wallet[key] < price[key]:
			return false
		next.wallet[key] = int(next.wallet[key]) - int(price[key])
	next.levels[slot] = from_level + 1
	return _commit(next)
