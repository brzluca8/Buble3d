extends Node
## Starea jocului, economia și salvarea (autoload „Game").
##
## Bucla principală (inspirată din jocurile de tip „zaruri + construire"):
##   energie (bule) → Aruncă zarurile → mascota sare pe traseul din jurul insulei →
##   căsuța dă monede / cufăr / atac / jaf / scut / Buble Blast / eveniment →
##   monedele construiesc clădirile → insula completă deblochează insula următoare.

signal changed                       # monede / XP / niveluri / energie modificate
signal toast(msg: String)            # mesaj scurt pentru interfață
signal selected(id: String)          # clădire selectată ("" = niciuna)
signal upgraded(id: String)          # clădire îmbunătățită
signal mascot_jump                   # mascota sare (upgrade, întoarcere din Buble Blast)
signal quality_changed(q: String)
signal board_moved(from: int, to: int, d1: int, d2: int)
signal island_completed(index: int)
signal event_points(pts: int)           # puncte de eveniment câștigate (pentru echipă, online)
signal rival_tapped(what: String)    # atingere pe insula rivalului: "b:<clădire>" sau "m:<movilă>"

const SAVE_PATH := "user://save.json"
var save_path := SAVE_PATH            # testele folosesc alt fișier
const SAVE_VERSION := 2
const MAX_LVL := 5
const OFFLINE_MAX_S := 3600.0
const INCOME_EVERY_S := 10.0

const BUILDINGS := [
	# poziții (x, z) compuse după randarea de referință; fața insulei (scările) este spre +Z
	{"id": "palat", "n": "Palatul Norilor", "x": 0.0, "z": -4.3, "b": 150},
	{"id": "obs", "n": "Observatorul", "x": -4.7, "z": -1.5, "b": 100},
	{"id": "turn", "n": "Turnul Elegant", "x": 5.2, "z": 1.7, "b": 100},
	{"id": "mag", "n": "Magazinul", "x": -4.4, "z": 2.5, "b": 80},
	{"id": "sera", "n": "Sera de Cristal", "x": 3.7, "z": -1.6, "b": 90},
]

# ---------- energie și zaruri ----------
const ENERGY_MAX := 50
const ENERGY_REGEN_S := 120.0          # o bulă la 2 minute
const MULTS := [1, 2, 3, 5, 10, 20]

# ---------- traseul din jurul insulei ----------
const BOARD := [
	"start", "coins", "coins", "chest", "coins", "attack", "coins", "event",
	"shield", "coins", "raid", "coins", "blast", "coins", "chest", "attack",
	"coins", "event", "coins", "shield", "raid", "coins", "chest", "event",
]
const TILE_INFO := {
	"start": ["🏁", "Start", Color("f6c445")],
	"coins": ["🪙", "Monede", Color("ffd86b")],
	"chest": ["🎁", "Cufăr", Color("ff8fb8")],
	"attack": ["🔨", "Atac", Color("ff6b5a")],
	"raid": ["🕳️", "Jaf", Color("9a63ff")],
	"shield": ["🛡️", "Scut", Color("5ab8ff")],
	"blast": ["🫧", "Buble Blast", Color("2bd4c8")],
	"event": ["⭐", "Eveniment", Color("ffb347")],
}

const ISLAND_NAMES := ["Grădina dintre nori", "Insula de Cristal", "Valea Lavandei", "Țărmul de Aur", "Grădina Stelelor", "Cetatea Curcubeului"]
const RIVAL := "Contele Furtună"
const RIVAL_ISLAND := "Fortăreața Furtunii"

# ---------- album ----------
const CARD_SETS := [
	{"n": "Insula Norilor", "cards": ["Palatul", "Fântâna", "Observatorul", "Turnul", "Sera", "Magazinul", "Scările", "Cascada", "Cristalul"]},
	{"n": "Prietenii lui Buble", "cards": ["Buble", "Bufnița", "Vulpița", "Ariciul", "Fluturele", "Broscuța", "Iepurașul", "Pisoiul", "Dragonul mic"]},
	{"n": "Comorile cerului", "cards": ["Busola", "Harta", "Ochelarii", "Lanterna", "Cheia", "Coroana", "Steaua", "Perla", "Inima norilor"]},
]
const CARD_SET_REWARD := 25            # energie la completarea unui set

# ---------- eveniment ----------
const EVENT_NAME := "Turneul Norilor"
const EVENT_GOALS := [[20, "energy", 10], [60, "coins", 15], [120, "cards", 2], [220, "energy", 30], [350, "coins", 60]]

var coins: float = 300.0
var xp: int = 0
var levels := {"palat": 1, "obs": 1, "turn": 1, "mag": 1, "sera": 1}
var missions := {"up": false, "blast": false}
var quality := "inalta"
var sound := true
var blast_level := 1
var energy := ENERGY_MAX
var energy_t := 0.0                    # momentul (unix) de la care se numără refacerea
var mult := 1
var pos := 0
var shields := 0
var island := 1
var rival := {"palat": 3, "obs": 2, "turn": 3, "mag": 2, "sera": 2}
var cards := {}                        # "set:index" -> număr de exemplare
var event_pts := 0
var event_step := 0
var last_save_unix: float = 0.0
var sel := ""
var offline_gain := 0
var offline_msg := ""
var _raid_cells: Array = []


func _ready() -> void:
	load_game()
	offline_gain = _collect_offline()
	_rival_visit()
	_tick_energy()
	save_game()
	var e := Timer.new()
	e.wait_time = 1.0
	e.autostart = true
	e.timeout.connect(_tick_energy)
	add_child(e)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		save_game()


# ---------- reguli ----------
func building(id: String) -> Dictionary:
	for b in BUILDINGS:
		if b.id == id:
			return b
	return {}


func island_name() -> String:
	return ISLAND_NAMES[(island - 1) % ISLAND_NAMES.size()] + ("" if island <= ISLAND_NAMES.size() else " %d" % island)


## Costul crește cu nivelul clădirii și cu numărul insulei.
func cost(id: String) -> int:
	return roundi(building(id).b * pow(levels[id], 1.7) * pow(island, 2.0))


## Unitatea de recompensă: crește cu insula și cu progresul pe insulă.
func unit() -> int:
	return roundi(20.0 * island * (1.0 + 0.04 * (sum_levels() - 5)))


func sum_levels() -> int:
	var s := 0
	for v in levels.values():
		s += v
	return s


func player_level() -> int:
	return 1 + xp / 100


func can_upgrade(id: String) -> bool:
	return levels[id] < MAX_LVL and coins >= cost(id)


func island_complete() -> bool:
	for v in levels.values():
		if v < MAX_LVL:
			return false
	return true


# ---------- acțiuni: clădiri ----------
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
	if island_complete():
		_finish_island()
	save_game()
	return true


func _finish_island() -> void:
	var done := island
	var bonus := unit() * 20
	coins += bonus
	energy = mini(energy + 30, ENERGY_MAX + 60)
	xp += 200
	island += 1
	for k in levels.keys():
		levels[k] = 1
	rival = {"palat": 3, "obs": 3, "turn": 3, "mag": 3, "sera": 3}
	select("")
	island_completed.emit(done)
	toast.emit("Insula completă! 🎉 +%d 🪙  +30 🫧  Te așteaptă %s" % [bonus, island_name()])
	changed.emit()


func add_coins(n: float) -> void:
	coins += n
	changed.emit()


func blast_reward(score: int, won: bool) -> int:
	# recompensa crește cu insula, ca Buble Blast să rămână util și mai târziu
	var co := int((score / 4 + (100 + 20 * (blast_level - 1) if won else 0)) * (0.5 + 0.5 * island))
	coins += co
	xp += score / 5 + (30 if won else 0)
	missions.blast = true
	if won:
		blast_level += 1
	changed.emit()
	save_game()
	return co


## Câștigul mediu al unei runde de Buble Blast (folosit de simularea economiei).
func blast_estimate() -> int:
	return unit() * 8


func set_quality(q: String) -> void:
	quality = q
	quality_changed.emit(q)
	save_game()


# ---------- energie ----------
func _tick_energy() -> void:
	var now := Time.get_unix_time_from_system()
	if energy_t <= 0.0 or energy >= ENERGY_MAX:
		energy_t = now
		return
	var n := int((now - energy_t) / ENERGY_REGEN_S)
	if n > 0:
		energy = mini(ENERGY_MAX, energy + n)
		energy_t = now if energy >= ENERGY_MAX else energy_t + n * ENERGY_REGEN_S
		changed.emit()


## Secunde până la următoarea bulă (0 dacă energia e plină).
func energy_next_in() -> int:
	if energy >= ENERGY_MAX:
		return 0
	return maxi(0, int(ENERGY_REGEN_S - (Time.get_unix_time_from_system() - energy_t)))


func add_energy(n: int) -> void:
	energy += n
	changed.emit()


func cycle_mult() -> int:
	var i := MULTS.find(mult)
	mult = MULTS[(i + 1) % MULTS.size()]
	# nu poți alege un multiplicator mai mare decât energia disponibilă
	while mult > maxi(1, energy) and mult != 1:
		mult = MULTS[(MULTS.find(mult) + 1) % MULTS.size()]
	changed.emit()
	return mult


# ---------- zaruri și traseu ----------
## Aruncă două zaruri, mută mascota și întoarce rezultatul (sau {} dacă nu ai energie).
func roll(forced := Vector2i.ZERO) -> Dictionary:
	_tick_energy()
	if energy < mult:
		return {}
	if energy >= ENERGY_MAX:
		energy_t = Time.get_unix_time_from_system()
	energy -= mult
	var d1 := forced.x if forced.x > 0 else randi_range(1, 6)
	var d2 := forced.y if forced.y > 0 else randi_range(1, 6)
	var from := pos
	var steps := d1 + d2
	var passed := from + steps >= BOARD.size()
	pos = (from + steps) % BOARD.size()
	var res := {"d1": d1, "d2": d2, "from": from, "to": pos, "kind": BOARD[pos], "double": d1 == d2, "start_bonus": 0}
	if passed:
		var b := unit() * 3 * mult
		coins += b
		res.start_bonus = b
	if d1 == d2:
		energy += mult    # dubla: aruncare gratuită
	board_moved.emit(from, pos, d1, d2)
	changed.emit()
	save_game()
	return res


## Aplică efectul unei căsuțe simple. Atacul, jaful și Buble Blast cer alegeri în interfață.
func resolve_tile(kind: String) -> Dictionary:
	var u := unit() * mult
	var r := {"kind": kind, "coins": 0, "energy": 0, "cards": [], "msg": ""}
	match kind:
		"coins":
			r.coins = u * randi_range(2, 4)
			r.msg = "+%d 🪙" % r.coins
		"start":
			r.coins = u * 2
			r.msg = "Start! +%d 🪙" % r.coins
		"chest":
			var x := randf()
			if x < 0.45:
				r.coins = u * 6
				r.msg = "Cufăr: +%d 🪙" % r.coins
			elif x < 0.75:
				r.energy = 3 * mult
				r.msg = "Cufăr: +%d 🫧" % r.energy
			else:
				r.cards = add_cards(1 + (1 if mult >= 5 else 0))
				r.msg = "Cufăr: %d cărți noi 🃏" % r.cards.size()
		"shield":
			if shields < 3:
				shields += 1
				r.msg = "Scut +1 🛡️ (%d/3)" % shields
			else:
				r.coins = u * 2
				r.msg = "Scuturi pline – primești +%d 🪙" % r.coins
		"event":
			var pts := 2 * mult
			event_pts += pts
			event_points.emit(pts)
			r.msg = "%s: +%d ⭐" % [EVENT_NAME, pts]
			var rew := _event_rewards()
			if rew != "":
				r.msg += "  " + rew
	coins += r.coins
	energy += r.energy
	changed.emit()
	save_game()
	return r


func _event_rewards() -> String:
	var out := ""
	while event_step < EVENT_GOALS.size() and event_pts >= EVENT_GOALS[event_step][0]:
		var g: Array = EVENT_GOALS[event_step]
		match g[1]:
			"energy":
				energy += g[2]
				out += "Premiu: +%d 🫧 " % g[2]
			"coins":
				var c: int = unit() * g[2]
				coins += c
				out += "Premiu: +%d 🪙 " % c
			"cards":
				add_cards(g[2])
				out += "Premiu: %d cărți 🃏 " % g[2]
		event_step += 1
	return out


func event_next_goal() -> int:
	return EVENT_GOALS[event_step][0] if event_step < EVENT_GOALS.size() else EVENT_GOALS[-1][0]


## Atac asupra insulei rivalului: lovești o clădire și iei monede.
func attack(target: String) -> Dictionary:
	var u := unit() * mult
	var blocked := randf() < 0.25
	var r := {"target": target, "blocked": blocked, "coins": u * (3 if blocked else 8)}
	if not blocked:
		rival[target] = maxi(0, rival[target] - 1)
		var total := 0
		for v in rival.values():
			total += v
		if total <= 2:
			# Contele își reconstruiește fortăreața
			for k in rival.keys():
				rival[k] = randi_range(2, 4)
	coins += r.coins
	changed.emit()
	save_game()
	return r


## Jaf: 9 nori, sub 3 sunt comori mari, sub 3 mici, 3 sunt goi. Jucătorul alege 3.
func start_raid() -> Array:
	var u := unit() * mult
	_raid_cells = [u * randi_range(6, 10), u * randi_range(6, 10), u * randi_range(6, 10), u * randi_range(2, 4), u * randi_range(2, 4), u * randi_range(2, 4), 0, 0, 0]
	_raid_cells.shuffle()
	return _raid_cells


func raid_pick(i: int) -> int:
	if i < 0 or i >= _raid_cells.size():
		return 0
	var v: int = _raid_cells[i]
	coins += v
	changed.emit()
	return v


# ---------- album ----------
func card_key(s: int, i: int) -> String:
	return "%d:%d" % [s, i]


func set_complete(s: int) -> bool:
	for i in CARD_SETS[s].cards.size():
		if cards.get(card_key(s, i), 0) <= 0:
			return false
	return true


## Adaugă n cărți aleatoare (cele cu index mare sunt mai rare). Întoarce [[set, index], ...].
func add_cards(n: int) -> Array:
	var got := []
	for k in n:
		var s := randi() % CARD_SETS.size()
		var count: int = CARD_SETS[s].cards.size()
		# raritate: indexul mare apare mai rar
		var i := mini(count - 1, int(pow(randf(), 1.8) * count))
		var was := set_complete(s)
		var key := card_key(s, i)
		cards[key] = cards.get(key, 0) + 1
		got.append([s, i])
		if not was and set_complete(s):
			energy += CARD_SET_REWARD
			toast.emit("Set complet: %s! +%d 🫧" % [CARD_SETS[s].n, CARD_SET_REWARD])
	changed.emit()
	return got


# ---------- venit pasiv, offline, rival ----------
func _on_income() -> void:
	add_coins(sum_levels())
	save_game()


## Venitul pasiv a fost scos: energia (bulele) este resursa care se reface în timp.
func _collect_offline() -> int:
	if true:
		return 0
	if last_save_unix <= 0.0:
		return 0
	var el := minf(Time.get_unix_time_from_system() - last_save_unix, OFFLINE_MAX_S)
	if el <= 30.0:
		return 0
	var ga := int(el / INCOME_EVERY_S * sum_levels())
	coins += ga
	return ga


## Cât ai lipsit, Contele Furtună poate încerca un atac (personaj din poveste, nu un jucător).
func _rival_visit() -> void:
	if last_save_unix <= 0.0 or Time.get_unix_time_from_system() - last_save_unix < 7200.0 or randf() > 0.6:
		return
	if shields > 0:
		shields -= 1
		offline_msg = "%s a atacat cât ai lipsit, dar scutul tău a rezistat! 🛡️" % RIVAL
	else:
		var loss := mini(int(coins * 0.1), unit() * 10)
		coins -= loss
		offline_msg = "%s a atacat cât ai lipsit și a luat %d 🪙. Adună scuturi! 🛡️" % [RIVAL, loss]


# ---------- salvare ----------
func save_game() -> void:
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(save_dict()))


func save_dict() -> Dictionary:
	last_save_unix = Time.get_unix_time_from_system()
	return {
		"v": SAVE_VERSION, "coins": coins, "xp": xp, "b": levels, "mis": missions,
		"t": last_save_unix, "q": quality, "snd": sound, "bl": blast_level,
		"en": energy, "et": energy_t, "mult": mult, "pos": pos, "sh": shields, "isl": island,
		"rv": rival, "cards": cards, "ev": event_pts, "evs": event_step,
	}


## Mesaje de la server (alți jucători): atacuri, jafuri, cadouri, prieteni noi.
func apply_remote(kind: String, data: Dictionary) -> void:
	var who: String = str(data.get("from", "Cineva"))
	match kind:
		"attack":
			if data.get("blocked", false):
				shields = maxi(0, shields - 1)
				toast.emit("%s te-a atacat, dar scutul tău a rezistat! 🛡️" % who)
			else:
				var b: String = str(data.get("building", ""))
				if levels.has(b):
					levels[b] = clampi(int(data.get("level", levels[b])), 1, MAX_LVL)
					toast.emit("%s ți-a lovit %s! 🔨" % [who, building(b).n])
		"raid":
			var loss := mini(int(coins * 0.2), int(data.get("coins", 0)) / 2)
			coins -= loss
			toast.emit("%s ți-a făcut un jaf și a luat %d 🪙" % [who, loss])
		"card":
			var key: String = str(data.get("card", ""))
			if key.contains(":"):
				cards[key] = cards.get(key, 0) + 1
				toast.emit("%s ți-a trimis o carte 🃏" % who)
		"friend":
			toast.emit("%s te-a adăugat ca prieten 👥" % who)
	changed.emit()
	save_game()


func load_game() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(save_path))
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
	energy = maxi(0, int(d.get("en", ENERGY_MAX)))
	energy_t = float(d.get("et", 0.0))
	mult = int(d.get("mult", 1)) if int(d.get("mult", 1)) in MULTS else 1
	pos = clampi(int(d.get("pos", 0)), 0, BOARD.size() - 1)
	shields = clampi(int(d.get("sh", 0)), 0, 3)
	island = maxi(1, int(d.get("isl", 1)))
	var rv: Dictionary = d.get("rv", {})
	for k in rival.keys():
		rival[k] = clampi(int(rv.get(k, rival[k])), 0, MAX_LVL)
	var c = d.get("cards", {})
	if typeof(c) == TYPE_DICTIONARY:
		for k in c:
			cards[str(k)] = int(c[k])
	event_pts = int(d.get("ev", 0))
	event_step = clampi(int(d.get("evs", 0)), 0, EVENT_GOALS.size())
