extends "res://scripts/board/board_save.gd"
## Local-only debug storage. Every write is gated, including inherited economy calls.
const PREFIX := "user://lerion_developer/profile"
const ROOT := "user://lerion_developer/"
const FUTURE := preload("res://scripts/developer/future_features.json")
var memory_only := false
var forced_pair := Vector2i.ZERO
var forced_prize := ""
var recording := false

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
	if memory_only:
		next.seq = int(state.get("seq",0))+1
		state = next
		error = ""
		return true
	return super(next)

func _draw_faces() -> Vector2i:
	if allowed() and forced_pair != Vector2i.ZERO:
		return forced_pair
	return super()

func _draw_prize() -> String:
	if allowed() and not forced_prize.is_empty():
		return Crystal.draw(rng,forced_prize)
	return super()

func spin_wheel(now := int(Time.get_unix_time_from_system())) -> Dictionary:
	if not allowed():
		return {}
	var receipt := super(now)
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
	return _commit(next)

func charge_crystal() -> bool:
	return set_crystal(Crystal.target(state),int(state.crystal_activations))

func set_chests(wood: int, silver: int, gold: int) -> bool:
	if not allowed() or busy or mini(wood,mini(silver,gold)) < 0:
		return false
	var next := state.duplicate(true)
	next.chests = {"wood":wood,"silver":silver,"gold":gold}
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

func roll(now := int(Time.get_unix_time_from_system())) -> Dictionary:
	if not allowed():
		return {}
	recording = true
	var receipt := super(now)
	recording = false
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
	forced_pair = Vector2i.ZERO
	forced_prize = ""
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
	trial.force_pair(Vector2i(1,1))
	var before: int = trial.state.energy
	var receipt: Dictionary = trial.roll()
	return {"before":before,"after":trial.state.energy,"receipt":receipt,
		"note":"Test izolat în memorie, plafonul recompensei 100."}

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
	return history is Array and history.size() <= 30 and future is Dictionary
