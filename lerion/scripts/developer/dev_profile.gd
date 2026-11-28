extends "res://scripts/board/board_save.gd"
## Local-only debug storage. Every write is gated, including inherited economy calls.
const PREFIX := "user://lerion_developer/profile"
const ROOT := "user://lerion_developer/"
const FUTURE := preload("res://scripts/developer/future_features.json")
var memory_only := false
var forced_pair := Vector2i.ZERO
var forced_prize := ""
var forced_rarity := ""
var recording := false
var op := ""
const LOG_LIMIT := 40

func _init(in_memory := false) -> void:
	memory_only = in_memory
	if OS.is_debug_build():
		DirAccess.make_dir_recursive_absolute(ROOT)
	super(PREFIX if not memory_only else ROOT+"simulation")
	state = typed(state)

func allowed() -> bool:
	return OS.is_debug_build() and ProjectSettings.get_setting("lerion/developer_panel",true) and save_prefix == (PREFIX if not memory_only else ROOT+"simulation")+"_board_v3"

func _commit(next: Dictionary) -> bool:
	if not allowed():
		error = "Operație permisă numai în profilul local DEBUG."
		return false
	if recording:
		var history: Array = next.get("debug_history",[]).duplicate(true)
		history.append({"roll":next.last_roll.duplicate(true),"position":next.board_position_index,
			"wallet":next.wallet.duplicate(),"energy":next.energy,"laps":next.laps})
		if history.size() > 30:
			history.pop_front()
		next.debug_history = history
	if not op.is_empty():
		var log: Array = next.get("debug_log",[]).duplicate(true)
		var ev: Dictionary = next.get("event",{})
		log.append({"op":op,"seq":int(state.get("seq",0))+1,"tile":next.board_position_index,"energy":next.energy,
			"coins":next.wallet.coins,"charge":next.crystal_charge,"chests":next.chests.duplicate(),
			"event_points":int(ev.get("points",0)),"skew":int(next.get("debug_skew",0)),
			"prize":str(next.last_spin.get("prize","")),"spin_id":int(next.last_spin.get("id",0))})
		while log.size() > LOG_LIMIT:
			log.pop_front()
		next.debug_log = log
	op = ""
	if memory_only:
		next.seq = int(state.get("seq",0))+1
		state = next
		error = ""
		return true
	return super(next)

## Simulated clock: the real time plus the offset stored in the DEBUG profile.
func clock(now := -1) -> int:
	return super(now) + (int(state.get("debug_skew",0)) if now < 0 else 0)

## Regeneration can be paused for tests. While paused the timer does not accumulate.
func _regen(next: Dictionary, now: int) -> void:
	if bool(next.get("debug_regen_off",false)):
		next.clock_mark = Energy.effective_now(next,now)
		if int(next.energy) < Energy.capacity():
			next.tick = int(next.clock_mark)
		return
	super(next,now)

func _draw_faces() -> Vector2i:
	if allowed() and forced_pair != Vector2i.ZERO:
		return forced_pair
	return super()

func _forced_rarity() -> String:
	return forced_rarity if allowed() else ""

func force_rarity(id: String) -> bool:
	if not allowed() or busy or (not id.is_empty() and Cards.rarity(id).is_empty()):
		return false
	forced_rarity = id
	return true

func open_chest(kind: String) -> Dictionary:
	if not allowed():
		return {}
	op = "open_chest " + kind
	var receipt := super(kind)
	op = ""
	return receipt

## Opens `count` chests of one kind on an isolated in-memory copy and reports the statistics.
## The profile and the normal save are never written.
func simulate_chests(kind: String, count: int, seed_value := 4101, rarity := "") -> Dictionary:
	if not allowed() or kind not in Cards.CHEST_KINDS or count < 1 or count > 100000:
		return {}
	var trial = get_script().new(true)
	trial.state = state.duplicate(true)
	trial.state.cards = {}
	trial.state.last_open = {}
	trial.state.chests[kind] = count
	trial.rng.seed = seed_value
	trial.forced_rarity = rarity
	var report := {"chest":kind,"requested":count,"opened":0,"seed":seed_value,"forced_rarity":rarity,"cards_drawn":0,
		"by_rarity":{},"expected_percent":{},"observed_percent":{},"double_open_refused":0}
	for item: Dictionary in Cards.rarities():
		report.by_rarity[item.id] = 0
		report.expected_percent[item.id] = snappedf(Cards.rarity_probability(kind,item.id)*100.0,0.01)
	for i in range(count):
		var receipt: Dictionary = trial.open_chest(kind)
		if receipt.is_empty():
			return {"error":trial.error,"opened":report.opened}
		# A second request before the first is acknowledged must be refused.
		trial.state.chests[kind] += 1
		if trial.open_chest(kind).is_empty():
			report.double_open_refused += 1
		trial.state.chests[kind] -= 1
		trial.acknowledge_open(int(receipt.id))
		report.opened += 1
		for id: String in receipt.cards:
			report.by_rarity[Cards.card(id).rarity] += 1
			report.cards_drawn += 1
	for id: String in report.by_rarity:
		report.observed_percent[id] = snappedf(100.0*report.by_rarity[id]/maxf(1.0,report.cards_drawn),0.01)
	report.unique_cards = Cards.unique_owned(trial.state)
	report.catalog_size = Cards.catalog().size()
	report.total_copies = Cards.total_copies(trial.state)
	report.duplicate_copies = Cards.duplicate_copies(trial.state)
	report.cards_consistent = report.total_copies == report.cards_drawn and report.cards_drawn == count*Cards.chest_size(kind)
	report.chests_left = int(trial.state.chests[kind])
	var collections := {}
	for col: Dictionary in Cards.collections():
		collections[col.name] = "%d/6" % Cards.collection_owned(trial.state,col.id)
	report.collections = collections
	return report

## Compares the in-memory cards, chests and pending opening with a fresh load from disk.
func verify_cards_saved() -> Dictionary:
	if not allowed() or memory_only:
		return {}
	var disk = get_script().new()
	var same: bool = disk.state.cards == state.cards and disk.state.chests == state.chests and disk.state.last_open == state.last_open \
		and disk.state.chests_opened == state.chests_opened
	return {"identical":same,"unique":Cards.unique_owned(state),"unique_disk":Cards.unique_owned(disk.state),
		"copies":Cards.total_copies(state),"copies_disk":Cards.total_copies(disk.state),"opened":int(state.chests_opened),
		"opened_disk":int(disk.state.chests_opened),"pending":not disk.pending_open().is_empty()}

func cards_summary() -> String:
	return "Cărți unice %d/%d · exemplare %d · duplicate %d · cufere deschise %d" % [Cards.unique_owned(state),Cards.catalog().size(),
		Cards.total_copies(state),Cards.duplicate_copies(state),int(state.chests_opened)]

func _draw_prize() -> String:
	if allowed() and not forced_prize.is_empty():
		return Crystal.draw(rng,forced_prize)
	return super()

func spin_wheel(now := -1) -> Dictionary:
	if not allowed():
		return {}
	op = "spin"
	var receipt := super(now)
	op = ""
	if not receipt.is_empty():
		forced_prize = ""
	return receipt

## Next spin only; cleared after a saved spin, on profile reset and on restart.
func force_prize(id: String) -> bool:
	if not allowed() or busy or (not id.is_empty() and Crystal.prize_index(id) < 0):
		return false
	forced_prize = id
	return true

## Sets the crystal progress directly. `activations` 0 means the first (50-roll) cycle.
func set_crystal(charge: int, activations: int) -> bool:
	if not allowed() or busy or charge < 0 or activations < 0:
		return false
	var next := state.duplicate(true)
	next.crystal_activations = activations
	next.crystal_charge = mini(charge,Crystal.target(next))
	op = "set_crystal"
	return _commit(next)

func charge_crystal() -> bool:
	return set_crystal(Crystal.target(state),int(state.crystal_activations))

func set_chests(wood: int, silver: int, gold: int) -> bool:
	if not allowed() or busy or mini(wood,mini(silver,gold)) < 0:
		return false
	var next := state.duplicate(true)
	next.chests = {"wood":wood,"silver":silver,"gold":gold}
	op = "set_chests"
	return _commit(next)

## Many spins on an in-memory copy, through the same transaction. The profile is untouched.
func simulate_spins(count: int, seed_value := 3001) -> Dictionary:
	if not allowed() or count < 1 or count > 100000:
		return {}
	var trial = get_script().new(true)
	trial.state = state.duplicate(true)
	trial.state.last_spin = {}
	trial.rng.seed = seed_value
	var report := {"spins":0,"seed":seed_value,"prizes":{},"expected_percent":{},"observed_percent":{},
		"energy_added":0,"chests":Crystal.empty_chests(),"double_grants":0}
	for item: Dictionary in Crystal.prizes():
		report.prizes[item.id] = 0
		report.expected_percent[item.id] = snappedf(Crystal.probability(item.id)*100.0,0.01)
	for i in range(count):
		trial.state.crystal_charge = Crystal.target(trial.state)
		trial.state.energy = 0
		var receipt: Dictionary = trial.spin_wheel()
		if receipt.is_empty():
			return {"error":trial.error}
		# A second request for the same charge must be refused.
		if not trial.spin_wheel().is_empty():
			report.double_grants += 1
		trial.acknowledge_spin(int(receipt.id))
		report.prizes[receipt.prize] += 1
		report.spins += 1
		if receipt.kind == "energy":
			report.energy_added += int(receipt.amount)
		else:
			report.chests[receipt.chest] += int(receipt.amount)
	for id: String in report.prizes:
		report.observed_percent[id] = snappedf(100.0*report.prizes[id]/maxf(1.0,report.spins),0.01)
	return report

func force_pair(pair: Vector2i) -> bool:
	if not allowed() or busy or mini(pair.x,pair.y)<1 or maxi(pair.x,pair.y)>6:
		return false
	forced_pair = pair
	return true

func roll(now := -1) -> Dictionary:
	if not allowed():
		return {}
	op = "roll"
	recording = true
	var receipt := super(now)
	recording = false
	op = ""
	if not receipt.is_empty():
		forced_pair = Vector2i.ZERO
	return receipt

func set_resource(key: String, value: int, additive := false) -> bool:
	if not allowed() or busy or value < 0:
		return false
	var next := state.duplicate(true)
	if key == "energy":
		next.energy = clampi(value + (int(next.energy) if additive else 0),0,RULES.energy_max)
		next.tick = int(Time.get_unix_time_from_system())
	elif next.wallet.has(key):
		next.wallet[key] = mini(1000000000,value + (int(next.wallet[key]) if additive else 0))
	else:
		return false
	return _commit(next)

func teleport(tile: int) -> bool:
	if not allowed() or busy or tile < 0 or tile >= RULES.tile_count:
		return false
	var next := state.duplicate(true)
	next.board_position_index = tile
	next.last_roll = {}
	return _commit(next)

func set_level(slot: int, level: int) -> bool:
	if not allowed() or busy or slot < 0 or slot >= 6 or level < 0 or level > 3:
		return false
	var next := state.duplicate(true)
	next.levels[slot] = level
	return _commit(next)

func save_manual() -> bool:
	return allowed() and not busy and _commit(state.duplicate(true))

func write_json(filename: String, data: Dictionary) -> bool:
	if not allowed() or filename not in ["checkpoint.json","diagnostic.json"]:
		return false
	var path := ROOT+filename
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data,"  "))
	file.flush()
	var ok := file.get_error() == OK
	file.close()
	return ok and DirAccess.rename_absolute(path+".tmp",path) == OK

func checkpoint() -> bool:
	return not busy and write_json("checkpoint.json",state)

func restore_checkpoint() -> bool:
	if not allowed() or busy:
		return false
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROOT+"checkpoint.json")) if FileAccess.file_exists(ROOT+"checkpoint.json") else null
	if not _valid_board(data):
		error = "Checkpoint absent sau invalid."
		return false
	forced_pair = Vector2i.ZERO
	return _commit(typed(data))

func reset_profile(confirmed: bool) -> bool:
	if not allowed() or busy or not confirmed:
		return false
	var fresh = get_script().new(true)
	var next: Dictionary = fresh.state.duplicate(true)
	next.debug_history = []
	next.debug_log = []
	next.debug_skew = 0
	next.debug_regen_off = false
	forced_pair = Vector2i.ZERO
	forced_prize = ""
	forced_rarity = ""
	return _commit(next)

func set_future(charge: int, later: bool, prize: String) -> bool:
	if not allowed() or busy or charge < 0 or charge > 100 or prize not in FUTURE.data.prizes:
		return false
	var next := state.duplicate(true)
	next.debug_future = {"charge":charge,"later":later,"next_prize":prize,
		"threshold":int(FUTURE.data.later_rolls if later else FUTURE.data.first_rolls)}
	return _commit(next)

func energy_overflow_test(value: int) -> Dictionary:
	if not allowed():
		return {}
	var trial = get_script().new(true)
	trial.state = state.duplicate(true)
	trial.state.energy = clampi(value,101,10000)
	trial.state.board_position_index = 0
	trial.state.last_roll = {}
	trial.state.debug_regen_off = false
	trial.force_pair(Vector2i(1,1))
	var before: int = trial.state.energy
	var receipt: Dictionary = trial.roll()
	return {"before":before,"after":trial.state.energy,"receipt":receipt,
		"note":"Test izolat în memorie: de peste 100 se scade numai costul aruncării; căsuța nu mai acordă energie."}

# ---- Energy and clock -------------------------------------------------------------------------

func set_energy(value: int) -> bool:
	if not allowed() or busy or value < 0 or value > RULES.energy_hard_cap:
		return false
	var next := state.duplicate(true)
	next.energy = value
	next.tick = clock()
	op = "set_energy"
	return _commit(next)

func set_regen(enabled: bool) -> bool:
	if not allowed() or busy:
		return false
	var next := state.duplicate(true)
	next.debug_regen_off = not enabled
	next.tick = clock()
	op = "regen_on" if enabled else "regen_off"
	return _commit(next)

func regen_enabled() -> bool:
	return not bool(state.get("debug_regen_off",false))

## Moves the simulated clock forward, then credits regeneration through the normal rules.
func advance_time(seconds: int) -> bool:
	if not allowed() or busy or seconds <= 0:
		return false
	var next := state.duplicate(true)
	next.debug_skew = int(next.get("debug_skew",0)) + seconds
	op = "time+%ds" % seconds
	if not _commit(next):
		return false
	regenerate()
	return true

func regen_info() -> Dictionary:
	var now := clock()
	return {"energy":int(state.energy),"enabled":regen_enabled(),"to_next":Energy.seconds_to_next(state,now),
		"to_full":Energy.seconds_to_full(state,now),"interval":Energy.interval(),"skew":int(state.get("debug_skew",0))}

# ---- Dice and path ----------------------------------------------------------------------------

## Prepares one roll that stops exactly on `tile`. Moves Lerik closer without a reward when the
## tile is not 2..12 steps ahead. The roll itself uses the normal transaction.
func force_landing(tile: int) -> bool:
	if not allowed() or busy or tile < 0 or tile >= RULES.tile_count:
		return false
	var need := posmod(tile - int(state.board_position_index),RULES.tile_count)
	if need < 2 or need > 12:
		if not teleport(posmod(tile - 7,RULES.tile_count)):
			return false
		need = 7
	var first := maxi(1,need - 6)
	return force_pair(Vector2i(first,need - first))

# ---- Chests -----------------------------------------------------------------------------------

func add_chests(kind: String, count: int) -> bool:
	if not allowed() or busy or kind not in Crystal.CHEST_KINDS or count < 1:
		return false
	var next := state.duplicate(true)
	next.chests[kind] = mini(1000000,int(next.chests[kind]) + count)
	op = "chest+%d %s" % [count,kind]
	return _commit(next)

## Compares the memory state with what a fresh load from disk returns.
func verify_saved() -> Dictionary:
	if not allowed() or memory_only:
		return {}
	var disk = get_script().new()
	var same: bool = disk.state == state
	var diff := PackedStringArray()
	for key in state:
		if not disk.state.has(key) or disk.state[key] != state[key]:
			diff.append(str(key))
	return {"identical":same,"different_fields":diff,"disk_seq":int(disk.state.get("seq",-1)),"seq":int(state.seq),
		"chests_disk":disk.state.get("chests",{}),"chests":state.chests}

# ---- Events -----------------------------------------------------------------------------------

func start_event(id: String, now := -1) -> bool:
	op = "event_start"
	var ok := super(id,now) if allowed() else false
	op = ""
	return ok

func claim_event_reward(milestone_id: String, now := -1) -> Dictionary:
	if not allowed():
		return {}
	op = "claim " + milestone_id
	var receipt := super(milestone_id,now)
	op = ""
	return receipt

## Removes the running event without archiving. `history` also clears the archive.
func stop_event(history := false) -> bool:
	if not allowed() or busy:
		return false
	var next := state.duplicate(true)
	next.event = {}
	if history:
		next.event_history = []
	op = "event_stop"
	return _commit(next)

func set_event_points(points: int) -> bool:
	if not allowed() or busy or points < 0 or points > 1000000 or state.event.is_empty():
		return false
	var next := state.duplicate(true)
	next.event.points = points
	op = "event_points=%d" % points
	return _commit(next)

## Same points rule as a real landing, without moving Lerik and without the tile reward.
func simulate_event_landing(kind: String) -> int:
	if not allowed() or busy:
		return -1
	var next := state.duplicate(true)
	var gained := Events.award_landing(next,kind,clock())
	op = "event_landing " + kind
	return gained if _commit(next) else -1

func force_milestone(milestone_id: String) -> bool:
	if not allowed() or busy or state.event.is_empty():
		return false
	var item := Events.milestone(Events.definition(str(state.event.id)),milestone_id)
	return not item.is_empty() and set_event_points(maxi(int(state.event.points),int(item.points)))

## stage "claiming": just past the end of the event. stage "closed": past the claim window.
func expire_event(stage: String) -> bool:
	if not allowed() or busy or state.event.is_empty():
		return false
	var target := int(state.event.end) + 1
	if stage == "closed":
		target += Events.grace_seconds()
	var delta := target - clock()
	if delta <= 0:
		return false
	return advance_time(delta)

## Two claims of the same reward on an isolated copy. The profile is not modified.
func duplicate_claim_test(milestone_id: String) -> Dictionary:
	if not allowed() or state.event.is_empty():
		return {}
	var trial = get_script().new(true)
	trial.state = state.duplicate(true)
	var now: int = clock()
	var def := Events.definition(str(trial.state.event.id))
	var item := Events.milestone(def,milestone_id)
	if item.is_empty():
		return {}
	trial.state.event.points = maxi(int(trial.state.event.points),int(item.points))
	trial.state.event.claimed.erase(milestone_id)
	var before_energy: int = trial.state.energy
	var first: Dictionary = trial.claim_event_reward(milestone_id,now)
	var after_first: Dictionary = trial.state.duplicate(true)
	var second: Dictionary = trial.claim_event_reward(milestone_id,now)
	return {"first_granted":not first.is_empty(),"second_refused":second.is_empty(),
		"state_unchanged_by_second":trial.state == after_first,"first_receipt":first,
		"energy_gain":int(after_first.energy) - before_energy}

# ---- Selective reset, history -----------------------------------------------------------------

const RESET_PARTS := {"energy":"Energie","chests":"Cufere","cards":"Cărți și deschideri","crystal":"Super Cristal","event":"Evenimente",
	"position":"Poziție și ture","levels":"Niveluri clădiri","wallet":"Solduri","clock":"Ceas simulat"}

func reset_part(part: String, confirmed: bool) -> bool:
	if not allowed() or busy or not confirmed or not RESET_PARTS.has(part):
		return false
	var fresh = get_script().new(true)
	var base: Dictionary = fresh.state
	var next := state.duplicate(true)
	match part:
		"energy":
			next.energy = base.energy
			next.tick = clock()
			next.debug_regen_off = false
		"chests":
			next.chests = Crystal.empty_chests()
		"cards":
			next.cards = {}
			next.chests_opened = 0
			next.last_open = {}
			forced_rarity = ""
		"crystal":
			next.crystal_charge = 0
			next.crystal_activations = 0
			next.last_spin = {}
			forced_prize = ""
		"event":
			next.event = {}
			next.event_history = []
		"position":
			next.board_position_index = 0
			next.laps = 0
			next.last_roll = {}
			forced_pair = Vector2i.ZERO
		"levels":
			next.levels = base.levels.duplicate()
		"wallet":
			next.wallet = base.wallet.duplicate()
		"clock":
			next.debug_skew = 0
	op = "reset_" + part
	return _commit(next)

func spin_history_text() -> String:
	var lines := PackedStringArray()
	var log: Array = state.get("debug_log",[])
	for i in range(log.size() - 1,-1,-1):
		var e: Dictionary = log[i]
		if e.op == "spin":
			lines.append("Rotire #%d · %s · energie %d · cufere %s" % [int(e.spin_id),Crystal.describe({"prize":e.prize}),int(e.energy),str(e.chests)])
	return "\n".join(lines) if not lines.is_empty() else "Nicio rotire în istoricul acestui profil."

func history_text() -> String:
	var lines := PackedStringArray()
	var log: Array = state.get("debug_log",[])
	for i in range(log.size() - 1,-1,-1):
		var e: Dictionary = log[i]
		lines.append("#%d %s · căsuța %d · energie %d · monede %d · cristal %d · cufere %s · puncte eveniment %d" % [int(e.seq),e.op,int(e.tile),
			int(e.energy),int(e.coins),int(e.charge),str(e.chests),int(e.event_points)])
	return "\n".join(lines) if not lines.is_empty() else "Nicio tranzacție înregistrată în acest profil."

func typed(value: Variant) -> Variant:
	if value is Dictionary:
		var result := {}
		for key in value:
			result[key] = typed(value[key])
		return result
	if value is Array:
		var result := []
		for item in value:
			result.append(typed(item))
		return result
	if value is float and value == floor(value):
		return int(value)
	return value

func _valid_board(value: Variant) -> bool:
	if not super(value):
		return false
	var history: Variant = value.get("debug_history",[])
	var future: Variant = value.get("debug_future",{})
	var log: Variant = value.get("debug_log",[])
	return history is Array and history.size() <= 30 and future is Dictionary and log is Array and log.size() <= LOG_LIMIT
