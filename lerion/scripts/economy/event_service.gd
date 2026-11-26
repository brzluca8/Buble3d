extends RefCounted
## Timed events as pure functions over a save-state dictionary (no nodes, no I/O, no real clock).
## State layout: state.event = {} or {id, start, end, points, claimed:[milestone ids], claims:[receipts]}
##               state.event_history = [{id, start, end, points, claimed}] (latest 10)
## Every mutation works on a state copy passed by the caller, so the caller decides when to save.
## A server can replace the client calls by the same functions without changing the receipts.
const CONFIG := preload("res://CONFIG/events.json")
const RULES := preload("res://assets/board/rules.tres")
const HISTORY_LIMIT := 10


static func config() -> Dictionary:
	return CONFIG.data


static func definitions() -> Array:
	return CONFIG.data.events


static func definition(id: String) -> Dictionary:
	for item: Dictionary in definitions():
		if item.id == id:
			return item
	return {}


static func grace_seconds() -> int:
	return int(float(CONFIG.data.claim_grace_hours) * 3600.0)


static func duration_seconds(def: Dictionary) -> int:
	return int(float(def.duration_hours) * 3600.0)


static func empty_fields(state: Dictionary) -> void:
	if not state.has("event"):
		state.event = {}
	if not state.has("event_history"):
		state.event_history = []


## "none" | "active" (points and claims) | "claiming" (claims only) | "closed" (to be archived)
static func status(ev: Dictionary, now: int) -> String:
	if ev.is_empty():
		return "none"
	if now < int(ev.end):
		return "active"
	if now < int(ev.end) + grace_seconds():
		return "claiming"
	return "closed"


static func remaining(ev: Dictionary, now: int) -> int:
	return 0 if ev.is_empty() else maxi(0, int(ev.end) - now)


static func points_for(def: Dictionary, kind: String) -> int:
	return int(def.points.get(kind, 0))


static func start(next: Dictionary, id: String, now: int) -> bool:
	var def := definition(id)
	empty_fields(next)
	if def.is_empty() or status(next.event, now) in ["active","claiming"]:
		return false
	archive(next)
	next.event = {"id": id, "start": now, "end": now + duration_seconds(def), "points": 0, "claimed": [], "claims": []}
	return true


## Moves the current event to the history. Used for closed events and for debug resets.
static func archive(next: Dictionary) -> void:
	empty_fields(next)
	if next.event.is_empty():
		return
	var ev: Dictionary = next.event
	var history: Array = next.event_history
	history.append({"id": ev.id, "start": ev.start, "end": ev.end, "points": ev.points, "claimed": ev.claimed.duplicate()})
	while history.size() > HISTORY_LIMIT:
		history.pop_front()
	next.event = {}


static func archive_closed(next: Dictionary, now: int) -> bool:
	empty_fields(next)
	if status(next.event, now) == "closed":
		archive(next)
		return true
	return false


## Points only for the tile where the roll stopped. Returns the points granted (0 when none).
static func award_landing(next: Dictionary, tile_kind: String, now: int) -> int:
	empty_fields(next)
	if status(next.event, now) != "active":
		return 0
	var def := definition(str(next.event.id))
	var gained := points_for(def, tile_kind)
	if gained > 0:
		next.event.points = int(next.event.points) + gained
	return gained


static func milestone(def: Dictionary, milestone_id: String) -> Dictionary:
	for item: Dictionary in def.get("milestones", []):
		if item.id == milestone_id:
			return item
	return {}


static func is_claimed(ev: Dictionary, milestone_id: String) -> bool:
	return ev.get("claimed", []).has(milestone_id)


static func can_claim(ev: Dictionary, milestone_id: String, now: int) -> bool:
	if status(ev, now) not in ["active","claiming"]:
		return false
	var item := milestone(definition(str(ev.id)), milestone_id)
	return not item.is_empty() and int(ev.points) >= int(item.points) and not is_claimed(ev, milestone_id)


static func claimable(ev: Dictionary, now: int) -> PackedStringArray:
	var ids := PackedStringArray()
	if ev.is_empty():
		return ids
	for item: Dictionary in definition(str(ev.id)).milestones:
		if can_claim(ev, item.id, now):
			ids.append(item.id)
	return ids


## First milestone not reached yet, or {} when all are reached.
static func next_milestone(ev: Dictionary) -> Dictionary:
	if ev.is_empty():
		return {}
	for item: Dictionary in definition(str(ev.id)).milestones:
		if int(ev.points) < int(item.points):
			return item
	return {}


static func mill_percent(mill_level: int) -> int:
	var table: Array = CONFIG.data.mill_event_energy_bonus_percent
	return int(table[clampi(mill_level, 0, table.size() - 1)])


## Energy of an event reward after the Mill bonus. Chests are never multiplied.
static func energy_amount(base: int, mill_level: int) -> int:
	return roundi(float(base) * (100 + mill_percent(mill_level)) / 100.0)


## One claim: marks the milestone and grants the reward on `next`, or returns {} and changes
## nothing. The id is stored first, so the same reward can never be granted twice.
static func claim(next: Dictionary, milestone_id: String, now: int, mill_level := 0) -> Dictionary:
	empty_fields(next)
	if not can_claim(next.event, milestone_id, now):
		return {}
	var item := milestone(definition(str(next.event.id)), milestone_id)
	var receipt := {"event": next.event.id, "milestone": milestone_id, "kind": item.kind, "amount": int(item.amount),
		"chest": str(item.get("chest", "")), "base_amount": int(item.amount), "bonus_percent": 0}
	if item.kind == "energy":
		receipt.bonus_percent = mill_percent(mill_level)
		receipt.amount = energy_amount(int(item.amount), mill_level)
		next.energy = mini(RULES.energy_hard_cap, int(next.energy) + int(receipt.amount))
	else:
		var chests: Dictionary = next.chests
		chests[item.chest] = int(chests.get(item.chest, 0)) + int(item.amount)
	next.event.claimed.append(milestone_id)
	var log: Array = next.event.claims
	log.append(receipt.duplicate())
	while log.size() > 20:
		log.pop_front()
	return receipt


static func describe(receipt: Dictionary) -> String:
	if receipt.get("kind") == "energy":
		var text := "+%d energie" % int(receipt.amount)
		if int(receipt.get("bonus_percent", 0)) > 0:
			text += " (Moara +%d%%)" % int(receipt.bonus_percent)
		return text
	return {"wood": "Cufăr de lemn", "silver": "Cufăr de argint", "gold": "Cufăr de aur"}.get(str(receipt.get("chest", "")), "Cufăr")


static func describe_milestone(item: Dictionary) -> String:
	if item.kind == "energy":
		return "+%d energie" % int(item.amount)
	return {"wood": "Cufăr de lemn", "silver": "Cufăr de argint", "gold": "Cufăr de aur"}.get(str(item.get("chest", "")), "Cufăr")


## Save validation shared by the board save and the developer profile.
static func valid_fields(s: Dictionary, integer: Callable) -> bool:
	if not integer.call(s.get("clock_mark")) or not s.get("event") is Dictionary or not s.get("event_history") is Array:
		return false
	if s.event_history.size() > HISTORY_LIMIT:
		return false
	var ev: Dictionary = s.event
	if ev.is_empty():
		return true
	if not ev.get("id") is String or not integer.call(ev.get("start")) or not integer.call(ev.get("end")) or not integer.call(ev.get("points")):
		return false
	if not ev.get("claimed") is Array or not ev.get("claims") is Array:
		return false
	for id: Variant in ev.claimed:
		if not id is String:
			return false
	return int(ev.end) >= int(ev.start)
