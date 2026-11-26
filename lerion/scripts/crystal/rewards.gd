extends RefCounted
## Pure reward evaluation. Supplying the RNG also makes chest/chaos rolls reproducible.
const FILE := preload("res://CONFIG_PROTOTIP.json")
const KEYS := ["coin", "hammer", "crystal", "chest", "challenge", "chaos"]
const WALLET := ["coins", "build_points", "fragments", "tickets"]

var config: Dictionary = FILE.data
var symbols: Dictionary = {}


func _init(settings: Dictionary = FILE.data) -> void:
	config = settings
	var rows: Variant = config.get("symbols")
	if rows is Array:
		for row: Variant in rows:
			if row is Dictionary and row.get("key") is String:
				symbols[row.key] = row


func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


func _amount(value: Variant, minimum := 0) -> bool:
	return _number(value) and value >= minimum and value == floor(value)


func _wallet(value: Variant, minimum := 1) -> bool:
	if not value is Dictionary or value.is_empty():
		return false
	for key: Variant in value:
		if key not in WALLET or not _amount(value[key], minimum):
			return false
	return true


func _limits(value: Variant) -> bool:
	return value is Array and value.size() == 2 and _amount(value[0],1) and _amount(value[1],1) and value[0] <= value[1]


func _choices(value: Variant) -> bool:
	if not value is Array or value.is_empty():
		return false
	for entry: Variant in value:
		if not _wallet(entry):
			return false
	return true


func valid() -> bool:
	for section: String in ["activation","energy","super_crystal","combos","buildings","starting_resources"]:
		if not config.get(section) is Dictionary:
			return false
	if symbols.size() != KEYS.size() or config.symbols.size() != KEYS.size():
		return false
	var sum := 0.0
	for key: String in KEYS:
		var entry: Dictionary = symbols.get(key,{})
		if not _number(entry.get("weight_percent")) or entry.weight_percent < 0:
			return false
		sum += float(entry.weight_percent)
		match key:
			"chest":
				if not entry.get("base_reward_range") is Dictionary or not _limits(entry.base_reward_range.get("coins")):
					return false
			"chaos":
				if not _choices(entry.get("base_reward_choice_proposal")):
					return false
			_:
				if not _wallet(entry.get("base_reward")):
					return false
	var activation: Dictionary = config.activation
	var energy: Dictionary = config.energy
	var charged: Dictionary = config.super_crystal
	var duration: Variant = activation.get("normal_animation_target_seconds")
	if not is_equal_approx(sum,100.0) or activation.get("symbols_per_activation") != 3 or not _amount(activation.get("energy_cost"),1):
		return false
	if not duration is Array or duration.size() != 2 or not _number(duration[0]) or not _number(duration[1]) or duration[0] <= 0 or duration[1] < duration[0]:
		return false
	if not _amount(energy.get("max"), int(activation.energy_cost)) or not _number(energy.get("regenerate_one_per_minutes")) or energy.regenerate_one_per_minutes * 60 < 1:
		return false
	if not _amount(charged.get("charge_max"),1) or not _amount(charged.get("charge_per_normal_activation"),1) or charged.get("charge_after_special_activation") != 0 or not _limits(charged.get("extra_chest_coins_range")):
		return false
	if charged.get("armed_next_activation_doubles") != ["coins","build_points"]:
		return false
	var triples: Variant = config.combos.get("triples")
	if not triples is Dictionary or not triples.has_all(KEYS) or not config.combos.get("mixed") is Dictionary:
		return false
	for key: String in KEYS:
		var bonus: Variant = triples[key]
		if not bonus is Dictionary:
			return false
		match key:
			"chest":
				if not _limits(bonus.get("bonus_chest_coins_range")):
					return false
			"chaos":
				if not _choices(bonus.get("reward_choices")):
					return false
			_:
				if not _wallet(bonus):
					return false
	for recipe: String in config.combos.mixed:
		var parts := recipe.split("+")
		if parts.size() != 3 or parts[0] == parts[1] or parts[1] == parts[2] or parts[0] == parts[2] or not symbols.has_all(parts) or not _wallet(config.combos.mixed[recipe]):
			return false
	var buildings: Dictionary = config.buildings
	if buildings.get("slots") != 6 or buildings.get("max_level") != 3 or not buildings.get("positions") is Array or buildings.positions.size() != 6 or not buildings.get("costs_to_reach_level") is Dictionary:
		return false
	for plot: Variant in buildings.positions:
		if not plot is Dictionary or not plot.get("building") is String:
			return false
	for level in range(1,4):
		var cost: Variant = buildings.costs_to_reach_level.get(str(level))
		if not _wallet(cost) or not cost.has_all(["coins","build_points"]) or cost.size() != 2:
			return false
	return _wallet(config.starting_resources,0) and config.starting_resources.has_all(WALLET)


func roll_symbol(rng: RandomNumberGenerator) -> String:
	var pick := rng.randf_range(0.0, 100.0)
	var last := ""
	for key: String in symbols:
		var weight := float(symbols[key].weight_percent)
		if weight > 0:
			last = key
		if pick < weight:
			return key
		pick -= weight
	return last


func _range(rng: RandomNumberGenerator, limits: Array) -> int:
	return rng.randi_range(int(limits[0]), int(limits[1]))


func _choice(rng: RandomNumberGenerator, options: Array) -> Dictionary:
	return options[rng.randi_range(0, options.size() - 1)]


func base(key: String, rng: RandomNumberGenerator) -> Dictionary:
	var entry: Dictionary = symbols[key]
	if entry.has("base_reward_range"):
		return {"coins": _range(rng, entry.base_reward_range.coins)}
	if entry.has("base_reward_choice_proposal"):
		return _choice(rng, entry.base_reward_choice_proposal)
	return entry.base_reward


func _add(total: Dictionary, reward: Dictionary) -> void:
	for key: String in reward:
		total[key] = int(total.get(key, 0)) + int(reward[key])


func resolve(keys: Array, rng: RandomNumberGenerator, charged: bool) -> Dictionary:
	var total := {}
	var counts := {}
	for key: String in keys:
		_add(total, base(key, rng))
		counts[key] = int(counts.get(key, 0)) + 1
	var combo := ""
	if counts.size() == 1:
		combo = "triple"
		var bonus: Dictionary = config.combos.triples[keys[0]]
		if bonus.has("reward_choices"):
			_add(total, _choice(rng, bonus.reward_choices))
		elif bonus.has("bonus_chest_coins_range"):
			_add(total, {"coins": _range(rng, bonus.bonus_chest_coins_range)})
		else:
			_add(total, bonus)
	elif counts.size() == 2:
		combo = "pair"
		for key: String in counts:
			if counts[key] == 2:
				_add(total, base(key, rng))
	else:
		for recipe: String in config.combos.mixed:
			if counts.has_all(recipe.split("+")):
				combo = "mixed"
				_add(total, config.combos.mixed[recipe])
				break
	if charged:
		for key: String in config.super_crystal.armed_next_activation_doubles:
			if total.has(key):
				total[key] *= 2
		_add(total, {"coins": _range(rng, config.super_crystal.extra_chest_coins_range)})
	return {"symbols": keys.duplicate(), "combo": combo, "reward": total, "super": charged}
