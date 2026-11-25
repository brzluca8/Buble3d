class_name GameState
extends RefCounted
## Starea salvată a prototipului V3 (mod „board_v3”) și tranzacția de aruncare.
## Salvarea este atomică (fișier temporar + copie .bak) și versionată.

const SAVE_VERSION := 1
const MODE_ID := "board_v3"

var save_path: String
var config: BoardConfig

var board_position_index: int = 0
var energy: int = 100
var energy_max: int = 100
## Momentul (Unix, secunde) de la care se numără regenerarea următoarei unități de energie.
var energy_regen_anchor_unix: int = 0
var coins: int = 0
var crystals: int = 0
var build_points: int = 0
var quest_tokens: int = 0
## id clădire → nivel 0..3
var building_levels: Dictionary = {}
var total_rolls: int = 0
var laps: int = 0
## Etapa 3 (Super Cristal) – câmpuri rezervate, inițializate sigur.
var crystal_charge: int = 0
var super_crystal_remaining_landings: int = 0
var pending_roll_transaction_id: String = ""

var last_error: String = ""
## true dacă la încărcare exista o aruncare neterminată (deja aplicată, nu se repetă).
var recovered_pending_roll: bool = false

var _active_tx: RollTransaction


func _init(path: String, cfg: BoardConfig) -> void:
	save_path = path
	config = cfg
	energy_max = cfg.energy_max
	energy = cfg.energy_max
	# Niveluri de pornire ale prototipului (proiectul real își va păstra nivelurile salvate).
	building_levels = {"mina": 2, "moara": 3, "atelier": 3, "laborator": 2, "piata": 1, "han": 3}
	coins = 1000
	crystals = 50


# ---------------------------------------------------------------- aruncare

func is_rolling() -> bool:
	return _active_tx != null


## Consumă energia, aruncă zarurile, mută poziția și SALVEAZĂ – totul într-un singur pas.
## Returnează null (și last_error) dacă nu se poate arunca.
func try_begin_roll(dice: DiceRollService, tile_count: int, now_unix: int) -> RollTransaction:
	last_error = ""
	if _active_tx != null:
		last_error = "busy"
		return null
	update_energy_regen(now_unix)
	if energy < config.roll_energy_cost:
		last_error = "no_energy"
		return null
	var was_full := energy >= energy_max
	energy -= config.roll_energy_cost
	if was_full:
		energy_regen_anchor_unix = now_unix
	var roll := dice.roll()
	var mv := BoardMovement.compute(board_position_index, roll.total, tile_count, config.start_index)
	total_rolls += 1
	var tx := RollTransaction.new("%d-%d" % [now_unix, total_rolls], roll, mv)
	board_position_index = mv.to_index
	laps += mv.start_passes
	pending_roll_transaction_id = tx.id
	_active_tx = tx
	save()
	return tx


## Marchează aruncarea ca prezentată. A doua apelare cu același id nu face nimic.
func finish_roll(tx_id: String) -> bool:
	if _active_tx == null or _active_tx.id != tx_id:
		return false
	_active_tx = null
	pending_roll_transaction_id = ""
	save()
	return true


# ---------------------------------------------------------------- energie

## Regenerează +1 energie la fiecare `energy_regen_seconds`, până la maxim.
func update_energy_regen(now_unix: int) -> bool:
	if energy >= energy_max:
		energy_regen_anchor_unix = now_unix
		return false
	if now_unix < energy_regen_anchor_unix:
		energy_regen_anchor_unix = now_unix  # ceasul a fost dat înapoi
		return false
	var period := maxi(1, config.energy_regen_seconds)
	var gained := (now_unix - energy_regen_anchor_unix) / period
	if gained <= 0:
		return false
	energy = mini(energy_max, energy + gained)
	energy_regen_anchor_unix += gained * period
	if energy >= energy_max:
		energy_regen_anchor_unix = now_unix
	return true


func seconds_to_next_energy(now_unix: int) -> int:
	if energy >= energy_max:
		return 0
	return maxi(0, config.energy_regen_seconds - (now_unix - energy_regen_anchor_unix))


func building_level(id: String) -> int:
	return int(building_levels.get(id, 0))


# ---------------------------------------------------------------- salvare

func to_dict() -> Dictionary:
	return {
		"save_version": SAVE_VERSION,
		"mode": MODE_ID,
		"tile_count": config.tile_count,
		"board_position_index": board_position_index,
		"energy": energy,
		"energy_max": energy_max,
		"energy_regen_anchor_unix": energy_regen_anchor_unix,
		"coins": coins,
		"crystals": crystals,
		"build_points": build_points,
		"quest_tokens": quest_tokens,
		"building_levels": building_levels.duplicate(),
		"total_rolls": total_rolls,
		"laps": laps,
		"crystal_charge": crystal_charge,
		"super_crystal_remaining_landings": super_crystal_remaining_landings,
		"pending_roll_transaction_id": pending_roll_transaction_id,
	}


func apply_dict(d: Dictionary) -> void:
	board_position_index = posmod(int(d.get("board_position_index", 0)), config.tile_count)
	energy_max = int(d.get("energy_max", config.energy_max))
	energy = clampi(int(d.get("energy", energy_max)), 0, energy_max)
	energy_regen_anchor_unix = int(d.get("energy_regen_anchor_unix", 0))
	coins = maxi(0, int(d.get("coins", coins)))
	crystals = maxi(0, int(d.get("crystals", crystals)))
	build_points = maxi(0, int(d.get("build_points", 0)))
	quest_tokens = maxi(0, int(d.get("quest_tokens", 0)))
	var levels: Variant = d.get("building_levels", {})
	if levels is Dictionary:
		for id in config.building_ids:
			if (levels as Dictionary).has(id):
				building_levels[id] = clampi(int(levels[id]), 0, 3)
	total_rolls = maxi(0, int(d.get("total_rolls", 0)))
	laps = maxi(0, int(d.get("laps", 0)))
	crystal_charge = clampi(int(d.get("crystal_charge", 0)), 0, 30)
	super_crystal_remaining_landings = clampi(int(d.get("super_crystal_remaining_landings", 0)), 0, 3)
	pending_roll_transaction_id = String(d.get("pending_roll_transaction_id", ""))


## Încarcă salvarea dacă există; altfel creează una nouă. Nu șterge niciodată un fișier
## care nu poate fi citit – îl păstrează ca „.corupt” și pornește cu valori implicite.
func load_or_create(now_unix: int) -> void:
	recovered_pending_roll = false
	if FileAccess.file_exists(save_path):
		var text := FileAccess.get_file_as_string(save_path)
		var parsed: Variant = JSON.parse_string(text)
		if parsed is Dictionary and String((parsed as Dictionary).get("mode", "")) == MODE_ID:
			apply_dict(parsed)
		else:
			push_warning("Salvare V3 ilizibilă; păstrată ca .corupt, pornesc cu valori implicite.")
			DirAccess.copy_absolute(ProjectSettings.globalize_path(save_path), ProjectSettings.globalize_path(save_path + ".corupt"))
			energy_regen_anchor_unix = now_unix
	else:
		energy_regen_anchor_unix = now_unix
	# O aruncare întreruptă a fost deja aplicată la confirmare: doar o închidem, fără a re-arunca.
	if pending_roll_transaction_id != "":
		recovered_pending_roll = true
		pending_roll_transaction_id = ""
	update_energy_regen(now_unix)
	save()


func save() -> bool:
	var tmp := save_path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("Nu pot scrie salvarea: %s" % tmp)
		return false
	f.store_string(JSON.stringify(to_dict(), "\t"))
	f.close()
	var abs_path := ProjectSettings.globalize_path(save_path)
	if FileAccess.file_exists(save_path):
		DirAccess.copy_absolute(abs_path, abs_path + ".bak")
		DirAccess.remove_absolute(abs_path)
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), abs_path) == OK
