extends RefCounted
## Super Crystal and Magic Wheel rules. Pure functions over the saved state, no nodes and no I/O.
## The client calls them inside one save transaction today; a future server can run the same
## rules and return the identical receipt {id, prize, kind, amount, chest, presented}.

const CONFIG := preload("res://CONFIG/super_crystal.json")
const CHEST_KINDS := ["wood","silver","gold"]


static func config() -> Dictionary:
	return CONFIG.data


static func prizes() -> Array:
	return CONFIG.data.prizes


static func prize(id: String) -> Dictionary:
	for item: Dictionary in prizes():
		if item.id == id:
			return item
	return {}


static func prize_index(id: String) -> int:
	for i in range(prizes().size()):
		if prizes()[i].id == id:
			return i
	return -1


static func total_weight() -> int:
	var total := 0
	for item: Dictionary in prizes():
		total += int(item.weight)
	return total


## Exact probability of a prize, derived only from the configured weights.
static func probability(id: String) -> float:
	var item := prize(id)
	return 0.0 if item.is_empty() else float(item.weight) / maxf(1.0, float(total_weight()))


static func max_target() -> int:
	return maxi(int(CONFIG.data.first_target), int(CONFIG.data.later_target))


static func energy_limit() -> int:
	return int(CONFIG.data.energy_limit)


static func target(state: Dictionary) -> int:
	return int(CONFIG.data.first_target if int(state.get("crystal_activations", 0)) == 0 else CONFIG.data.later_target)


static func charge(state: Dictionary) -> int:
	return mini(int(state.get("crystal_charge", 0)), target(state))


static func is_ready(state: Dictionary) -> bool:
	return int(state.get("crystal_charge", 0)) >= target(state)


## One valid roll adds charge until the target. A charged crystal waits for the spin.
static func charge_after_roll(next: Dictionary) -> void:
	next.crystal_charge = mini(target(next), int(next.get("crystal_charge", 0)) + int(CONFIG.data.charge_per_roll))


## Weighted draw from 1..total_weight. A forced id is accepted only when it exists.
static func draw(rng: RandomNumberGenerator, forced := "") -> String:
	if not forced.is_empty() and prize_index(forced) >= 0:
		return forced
	var ticket := rng.randi_range(1, total_weight())
	for item: Dictionary in prizes():
		ticket -= int(item.weight)
		if ticket <= 0:
			return item.id
	return prizes()[-1].id


## Applies one spin to a state copy. Returns the receipt, or {} when the crystal is not charged.
static func spin(next: Dictionary, prize_id: String) -> Dictionary:
	var item := prize(prize_id)
	if item.is_empty() or not is_ready(next):
		return {}
	var receipt := {"id": int(next.get("last_spin", {}).get("id", 0)) + 1, "prize": prize_id,
		"kind": item.kind, "amount": int(item.amount), "chest": str(item.get("chest", "")), "presented": false}
	if item.kind == "energy":
		# Special energy may exceed the normal cap; regeneration stops at or above it.
		next.energy = mini(energy_limit(), int(next.energy) + int(item.amount))
	else:
		var chests: Dictionary = next.chests
		chests[item.chest] = int(chests.get(item.chest, 0)) + int(item.amount)
	next.crystal_charge = 0
	next.crystal_activations = int(next.get("crystal_activations", 0)) + 1
	next.last_spin = receipt
	return receipt


static func empty_chests() -> Dictionary:
	return {"wood": 0, "silver": 0, "gold": 0}


static func chest_name(kind: String) -> String:
	return str(CONFIG.data.chests.get(kind, {}).get("name", "Cufăr"))


static func describe(receipt: Dictionary) -> String:
	var item := prize(str(receipt.get("prize", "")))
	if not item.is_empty():
		return str(item.label)
	if receipt.get("kind") == "energy":
		return "+%d energie" % int(receipt.get("amount", 0))
	return chest_name(str(receipt.get("chest", "")))


## Save validation helpers shared by the board save and the developer profile.
static func valid_fields(s: Dictionary, integer: Callable) -> bool:
	if not integer.call(s.get("crystal_activations")) or not s.get("chests") is Dictionary or not s.get("last_spin") is Dictionary:
		return false
	for kind: String in CHEST_KINDS:
		if not integer.call(s.chests.get(kind)):
			return false
	var receipt: Dictionary = s.last_spin
	if receipt.is_empty():
		return true
	# Unknown ids stay loadable so a retuned wheel never invalidates an old receipt.
	return integer.call(receipt.get("id")) and receipt.get("prize") is String and receipt.get("presented") is bool \
		and receipt.get("kind") in ["energy","chest"] and integer.call(receipt.get("amount"))
