extends Node
## Starea jocului, economia și salvarea (autoload „Game").

signal changed                       # monede / XP / niveluri modificate
signal toast(msg: String)            # mesaj scurt pentru interfață
signal selected(id: String)          # clădire selectată ("" = niciuna)
signal upgraded(id: String)          # clădire îmbunătățită
signal mascot_jump                   # mascota sare (upgrade, întoarcere din Buble Blast)
signal quality_changed(q: String)

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 1
const MAX_LVL := 5
const OFFLINE_MAX_S := 3600.0
const INCOME_EVERY_S := 10.0

const BUILDINGS := [
	{"id": "palat", "n": "Palatul Norilor", "x": 0.0, "z": -4.0, "b": 150},
	{"id": "obs", "n": "Observatorul", "x": -4.6, "z": -1.2, "b": 100},
	{"id": "turn", "n": "Turnul Elegant", "x": 4.6, "z": -1.2, "b": 100},
	{"id": "mag", "n": "Magazinul", "x": -4.0, "z": 2.6, "b": 80},
	{"id": "sera", "n": "Sera de Cristal", "x": 4.0, "z": 2.6, "b": 90},
]

var coins: float = 300.0
var xp: int = 0
var levels := {"palat": 1, "obs": 1, "turn": 1, "mag": 1, "sera": 1}
var missions := {"up": false, "blast": false}
var quality := "inalta"          # "inalta" | "scazuta"
var sound := true
var blast_level := 1             # nivelul curent din Buble Blast
var last_save_unix: float = 0.0
var sel := ""
var offline_gain := 0


func _ready() -> void:
	load_game()
	offline_gain = _collect_offline()
	save_game()
	var t := Timer.new()
	t.wait_time = INCOME_EVERY_S
	t.autostart = true
	t.timeout.connect(_on_income)
	add_child(t)


func _notification(what: int) -> void:
	# Salvează când aplicația trece în fundal sau se închide (Android).
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		save_game()


# ---------- reguli ----------
func building(id: String) -> Dictionary:
	for b in BUILDINGS:
		if b.id == id:
			return b
	return {}


func cost(id: String) -> int:
	return roundi(building(id).b * pow(levels[id], 1.7))


func sum_levels() -> int:
	var s := 0
	for v in levels.values():
		s += v
	return s


func player_level() -> int:
	return 1 + xp / 100


func can_upgrade(id: String) -> bool:
	return levels[id] < MAX_LVL and coins >= cost(id)


# ---------- acțiuni ----------
func select(id: String) -> void:
	sel = id
	selected.emit(id)


func upgrade(id: String) -> bool:
	if not can_upgrade(id):
		return false
	coins -= cost(id)
	levels[id] += 1
	xp += 40
	missions.up = true
	upgraded.emit(id)
	mascot_jump.emit()
	toast.emit("%s a ajuns la nivelul %d ✨" % [building(id).n, levels[id]])
	changed.emit()
	save_game()
	return true


func add_coins(n: float) -> void:
	coins += n
	changed.emit()


func blast_reward(score: int, won: bool) -> int:
	var co := score / 4 + (100 + 20 * (blast_level - 1) if won else 0)
	coins += co
	xp += score / 5 + (30 if won else 0)
	missions.blast = true
	if won:
		blast_level += 1
	changed.emit()
	save_game()
	return co


func set_quality(q: String) -> void:
	quality = q
	quality_changed.emit(q)
	save_game()


func _on_income() -> void:
	add_coins(sum_levels())
	save_game()


func _collect_offline() -> int:
	if last_save_unix <= 0.0:
		return 0
	var el := minf(Time.get_unix_time_from_system() - last_save_unix, OFFLINE_MAX_S)
	if el <= 30.0:
		return 0
	var ga := int(el / INCOME_EVERY_S * sum_levels())
	coins += ga
	return ga


# ---------- salvare ----------
func save_game() -> void:
	last_save_unix = Time.get_unix_time_from_system()
	var d := {
		"v": SAVE_VERSION, "coins": coins, "xp": xp, "b": levels, "mis": missions,
		"t": last_save_unix, "q": quality, "snd": sound, "bl": blast_level,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(d) != TYPE_DICTIONARY:
		return
	coins = float(d.get("coins", coins))
	xp = int(d.get("xp", xp))
	var b: Dictionary = d.get("b", {})
	for k in levels.keys():
		levels[k] = clampi(int(b.get(k, 1)), 1, MAX_LVL)
	var m: Dictionary = d.get("mis", {})
	missions.up = bool(m.get("up", false))
	missions.blast = bool(m.get("blast", false))
	last_save_unix = float(d.get("t", 0.0))
	sound = bool(d.get("snd", true))
	blast_level = maxi(1, int(d.get("bl", 1)))
	var q: String = str(d.get("q", quality))
	if q in ["inalta", "scazuta"]:
		quality = q
