extends RefCounted
## Energy rules as pure functions over a save-state dictionary. No nodes, no I/O, no real clock:
## the caller passes `now`. A server can run the same functions and return the same result.
##
## Rules (values live in assets/board/rules.tres):
##  - one roll costs `energy_cost`;
##  - regeneration gives `regen_amount` every `regeneration_seconds`, only below `energy_max`;
##  - prize energy (wheel, events) may exceed `energy_max`, up to `energy_hard_cap`;
##  - at or above `energy_max` regeneration is suspended and its timer restarts at the next spend.
const RULES := preload("res://assets/board/rules.tres")


static func capacity() -> int:
	return RULES.energy_max


static func interval() -> int:
	return maxi(1, RULES.regeneration_seconds)


## Offline clock guard (prototype only). The latest time ever seen is stored in `clock_mark`;
## an earlier phone clock never moves regeneration backwards or repeats it. A clock moved
## forward cannot be detected offline: only a server can validate time.
static func effective_now(state: Dictionary, now: int) -> int:
	if not RULES.clock_mark_enabled:
		return now
	return maxi(now, int(state.get("clock_mark", 0)))


## Credits elapsed regeneration to `next` (a state copy) and advances `clock_mark`.
static func regenerate(next: Dictionary, now: int) -> void:
	var t := effective_now(next, now)
	next.clock_mark = t
	if int(next.energy) >= capacity():
		return
	var steps := floori(float(maxi(0, t - int(next.tick))) / interval())
	if steps <= 0:
		return
	next.energy = mini(capacity(), int(next.energy) + steps * RULES.regen_amount)
	next.tick = t if int(next.energy) >= capacity() else int(next.tick) + steps * interval()


static func can_spend(state: Dictionary, cost := -1) -> bool:
	return int(state.energy) >= (RULES.energy_cost if cost < 0 else cost)


## Debits a roll. When the balance is at or above capacity the regeneration timer restarts now.
static func spend(next: Dictionary, now: int, cost := -1) -> bool:
	var price: int = RULES.energy_cost if cost < 0 else cost
	if int(next.energy) < price:
		return false
	if int(next.energy) >= capacity():
		next.tick = effective_now(next, now)
	next.energy = int(next.energy) - price
	return true


## Adds prize energy. Returns the amount actually credited (limited only by the hard cap).
static func grant(next: Dictionary, amount: int) -> int:
	var before := int(next.energy)
	next.energy = mini(RULES.energy_hard_cap, before + maxi(0, amount))
	return int(next.energy) - before


## Seconds until the next +1, or -1 when regeneration is suspended (energy at or above capacity).
static func seconds_to_next(state: Dictionary, now: int) -> int:
	if int(state.energy) >= capacity():
		return -1
	var t := effective_now(state, now)
	return maxi(0, int(state.tick) + interval() - t)


## Seconds until the energy bar is full again, or 0 when it already is.
static func seconds_to_full(state: Dictionary, now: int) -> int:
	var missing := capacity() - int(state.energy)
	if missing <= 0:
		return 0
	return seconds_to_next(state, now) + (missing - 1) * interval()
