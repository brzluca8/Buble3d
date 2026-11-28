extends RefCounted
## Collectible cards and chest opening as pure functions. No nodes, no I/O, no clock.
## Opening is two steps so that a server can take over the first one:
##   1. draw_contents(rng, kind, forced_rarity) -> card ids      (random, authoritative on the server)
##   2. open(next, kind, ids) -> receipt                          (deterministic state change)
## State: state.cards = {card_id: copies}, state.chests_opened, state.last_open = receipt or {}.
## Receipt: {id, chest, cards:[ids], new:[bool], counts:[copies after each card], presented}.
const CONFIG := preload("res://CONFIG/cards.json")
const CHEST_KINDS := ["wood","silver","gold"]
static var _index := {}


static func data() -> Dictionary:
	return CONFIG.data


static func catalog() -> Array:
	return CONFIG.data.cards


static func card(id: String) -> Dictionary:
	if _index.is_empty():
		for item: Dictionary in CONFIG.data.cards:
			_index[item.id] = item
	return _index.get(id, {})


static func rarities() -> Array:
	return CONFIG.data.rarities


static func rarity(id: String) -> Dictionary:
	for item: Dictionary in rarities():
		if item.id == id:
			return item
	return {}


static func collections() -> Array:
	return CONFIG.data.collections


static func collection(id: String) -> Dictionary:
	for item: Dictionary in collections():
		if item.id == id:
			return item
	return {}


static func cards_in_collection(id: String) -> Array:
	return catalog().filter(func(item: Dictionary) -> bool: return item.collection == id)


static func cards_of_rarity(id: String) -> Array:
	return catalog().filter(func(item: Dictionary) -> bool: return item.rarity == id)


static func chest_size(kind: String) -> int:
	return int(CONFIG.data.chests[kind].cards)


static func weights(kind: String) -> Dictionary:
	return CONFIG.data.chests[kind].rarity_weights


static func weight_total(kind: String) -> int:
	var total := 0
	for key: String in weights(kind):
		total += int(weights(kind)[key])
	return total


## Chance that one card of this chest has the given rarity, from the configured weights only.
static func rarity_probability(kind: String, rarity_id: String) -> float:
	return float(weights(kind).get(rarity_id, 0)) / maxf(1.0, float(weight_total(kind)))


static func draw_rarity(rng: RandomNumberGenerator, kind: String) -> String:
	var ticket := rng.randi_range(1, weight_total(kind))
	for item: Dictionary in rarities():
		ticket -= int(weights(kind).get(item.id, 0))
		if ticket <= 0:
			return item.id
	return rarities()[-1].id


## Card ids for one chest. A forced rarity (tests only) replaces the weighted rarity draw.
static func draw_contents(rng: RandomNumberGenerator, kind: String, forced_rarity := "") -> Array:
	var ids := []
	for slot in range(chest_size(kind)):
		var wanted := forced_rarity if not rarity(forced_rarity).is_empty() else draw_rarity(rng, kind)
		var pool := cards_of_rarity(wanted)
		ids.append(pool[rng.randi_range(0, pool.size() - 1)].id)
	return ids


static func empty_fields(s: Dictionary) -> void:
	if not s.has("cards"):
		s.cards = {}
	if not s.has("chests_opened"):
		s.chests_opened = 0
	if not s.has("last_open"):
		s.last_open = {}


## Consumes one chest and adds every card, on `next` (a state copy). Returns {} and changes
## nothing when the chest is missing or the ids do not match the chest.
static func open(next: Dictionary, kind: String, ids: Array) -> Dictionary:
	empty_fields(next)
	if kind not in CHEST_KINDS or int(next.chests.get(kind, 0)) < 1 or ids.size() != chest_size(kind):
		return {}
	for id: Variant in ids:
		if not id is String or card(id).is_empty():
			return {}
	var receipt := {"id": int(next.last_open.get("id", 0)) + 1, "chest": kind, "cards": ids.duplicate(),
		"new": [], "counts": [], "presented": false}
	next.chests[kind] = int(next.chests[kind]) - 1
	for id: String in ids:
		var before := int(next.cards.get(id, 0))
		next.cards[id] = before + 1
		receipt.new.append(before == 0)
		receipt.counts.append(before + 1)
	next.chests_opened = int(next.chests_opened) + 1
	next.last_open = receipt
	return receipt


static func copies(state: Dictionary, id: String) -> int:
	return int(state.get("cards", {}).get(id, 0))


static func unique_owned(state: Dictionary) -> int:
	var count := 0
	for id: String in state.get("cards", {}):
		if copies(state, id) > 0 and not card(id).is_empty():
			count += 1
	return count


static func total_copies(state: Dictionary) -> int:
	var count := 0
	for id: String in state.get("cards", {}):
		count += copies(state, id)
	return count


static func duplicate_copies(state: Dictionary) -> int:
	var count := 0
	for id: String in state.get("cards", {}):
		count += maxi(0, copies(state, id) - 1)
	return count


static func collection_owned(state: Dictionary, collection_id: String) -> int:
	var count := 0
	for item: Dictionary in cards_in_collection(collection_id):
		count += int(copies(state, item.id) > 0)
	return count


static func describe(receipt: Dictionary) -> String:
	var fresh := 0
	for flag: Variant in receipt.get("new", []):
		fresh += int(flag)
	var total: int = receipt.get("cards", []).size()
	return "%d cărți · %d noi · %d duplicate" % [total, fresh, total - fresh]


## Save validation shared by the board save and the developer profile.
static func valid_fields(s: Dictionary, integer: Callable) -> bool:
	if not s.get("cards") is Dictionary or not integer.call(s.get("chests_opened")) or not s.get("last_open") is Dictionary:
		return false
	for id: Variant in s.cards:
		# Unknown ids stay loadable so a retired card never invalidates a save.
		if not id is String or not integer.call(s.cards[id]) or int(s.cards[id]) < 1:
			return false
	var receipt: Dictionary = s.last_open
	if receipt.is_empty():
		return true
	if not integer.call(receipt.get("id")) or receipt.get("chest") not in CHEST_KINDS or not receipt.get("presented") is bool:
		return false
	var ids: Variant = receipt.get("cards")
	if not ids is Array or not receipt.get("new") is Array or not receipt.get("counts") is Array:
		return false
	if receipt.new.size() != ids.size() or receipt.counts.size() != ids.size():
		return false
	for i in range(ids.size()):
		if not ids[i] is String or not receipt.new[i] is bool or not integer.call(receipt.counts[i]):
			return false
	return true
