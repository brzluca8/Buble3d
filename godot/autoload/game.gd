extends Node
## Starea și regulile jocului v2 (autoload „Game"). Toate valorile vin din res://data/*.json,
## deci economia se reglează fără cod (vezi BALANCE.md).
##
## Bucla: energie → rotire la mașina de bule → monede / energie / scut / atac / raid / cufăr / carte
## → upgrade-uri de clădiri (cu timer) → 30 de niveluri în 3 globuri × 10 → dirijabilul.

signal changed                          # orice valoare afișată s-a schimbat
signal toast(msg: String)
signal selected(id: String)             # clădire selectată ("" = niciuna)
signal upgraded(id: String)             # o clădire a trecut la etapa următoare
signal build_started(id: String)
signal mascot_jump
signal quality_changed(q: String)
signal level_up(level: int)
signal globe_completed(globe: int)
signal traveled(globe: int)
signal big_win(kind: String)            # câștig mare (pentru animații, vibrație)
signal friend_signal(id: int)
signal friend_bubble_tapped(slot: int)
signal target_tapped(what: String)      # atingere în orașul țintei: "b:<clădire>" / "s:<loc>"
signal event_points(pts: int)

const SAVE_VERSION := 2
const BUILDINGS := [
	# poziții (x, z) în oraș; fața (fântâna, scările) spre +Z
	{"id": "palat", "n": "Palatul", "x": 0.0, "z": -4.3},
	{"id": "obs", "n": "Observatorul", "x": -4.7, "z": -1.5},
	{"id": "turn", "n": "Turnul", "x": 5.2, "z": 1.7},
	{"id": "mag", "n": "Magazinul", "x": -4.4, "z": 2.5},
	{"id": "sera", "n": "Sera", "x": 3.7, "z": -1.6},
]
const MAX_STAGE := 5
const TROPHIES := [
	{"id": "prima_rotire", "name": "Prima rotire", "desc": "Ai pornit Mecanismul"},
	{"id": "jackpot", "name": "Trei perle", "desc": "Ai prins jackpotul"},
	{"id": "atacator", "name": "Strateg", "desc": "10 atacuri reușite"},
	{"id": "raider", "name": "Căutător de comori", "desc": "10 raiduri"},
	{"id": "glob_1", "name": "Grădina dintre nori", "desc": "Primul glob terminat"},
	{"id": "glob_2", "name": "Orașul de cristal", "desc": "Al doilea glob terminat"},
	{"id": "glob_3", "name": "Portul de amurg", "desc": "Al treilea glob terminat"},
	{"id": "colectionar", "name": "Colecționar", "desc": "Un set de album complet"},
	{"id": "serie_7", "name": "Constanță", "desc": "Seria zilnică de 7 zile"},
	{"id": "capitan", "name": "Căpitan", "desc": "Cârma de aur montată pe dirijabil"},
]

var save_path := "user://save_v2.json"

# ---------------- date ----------------
var D := {}                             # config, spin, levels, skills, cosmetics, airship, shop, cards, targets

# ---------------- stare ----------------
var coins := 0.0
var perle := 0
var energy := 50
var energy_t := 0.0                     # momentul de la care se numără refacerea
var mult := 1
var shields := 0
var level := 1                          # 1..30; 31 = toate terminate
var globe := 1                          # globul în care stai (1..3)
var levels := {}                        # clădire -> etapă (0..5) în globul curent
var builds := []                        # [{"b": id, "stage": n, "end": unix}]
var skill_points := 0
var skills := {}                        # id -> true
var cosmetics := {}                     # id -> true (deblocate)
var equipped := {}                      # slot -> id
var airship := {}                       # id -> true
var chests := []                        # [{"kind": "rar", "end": 0 (nepornit) / unix}]
var reservoir_t := 0.0
var streak := {"day": 0, "last": -1}
var event := {"start": 0.0, "points": 0, "stage": 0}
var cards := {}                         # "set:index" -> exemplare
var stats := {"spins": 0, "coins": 0, "attacks": 0, "raids": 0, "jackpots": 0, "chests": 0, "upgrades": 0}
var trophies := {}
var training := {}                      # id țintă -> {"levels": {...}, "shields": n}
var notif_enabled := false
var quality := "mediu"
var sound := true
var vibration := true
var first_open := 0.0
var last_save := 0.0
var gift_days := {}
var friend_flags := {}
var sel := ""
var pending_action := {}               # sabotaj/spargere pornite din Mecanism: {"type", "mult", "from"}
var _raid := []
var _w_total := 0


func _ready() -> void:
	_load_data()
	_reset_new()
	load_game()
	if first_open <= 0.0:
		first_open = _now()
		event.start = first_open
	_tick()
	save_game()
	var t := Timer.new()
	t.wait_time = 1.0
	t.autostart = true
	t.timeout.connect(_tick)
	add_child(t)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		save_game()
		Notifier.plan()


func _now() -> float:
	return Time.get_unix_time_from_system()


func today() -> int:
	return int((_now() + 7200.0) / 86400.0)     # zi locală aproximativă (UTC+2)


# ---------------- date ----------------
func _load_data() -> void:
	for k in ["config", "spin_table", "levels", "skills", "cosmetics", "airship", "shop", "cards", "targets"]:
		var txt := FileAccess.get_file_as_string("res://data/%s.json" % k)
		var v = JSON.parse_string(txt)
		if typeof(v) != TYPE_DICTIONARY:
			push_error("[Buble] data/%s.json invalid" % k)
			v = {}
		D[k] = v
	_w_total = 0
	for o in D.spin_table.outcomes:
		_w_total += int(o.weight)


func cfg(path: String, def = null):
	var cur = D.config
	for p in path.split("."):
		if typeof(cur) != TYPE_DICTIONARY or not cur.has(p):
			return def
		cur = cur[p]
	return cur


func _reset_new() -> void:
	energy = int(cfg("energy.start", 50))
	coins = 0.0
	levels = {}
	for b in BUILDINGS:
		levels[b.id] = 0
	equipped = (D.cosmetics.get("defaults", {}) as Dictionary).duplicate()
	for t in D.targets.get("targets", []):
		training[str(int(t.id))] = {"levels": _random_city(), "shields": int(t.shields)}


func _random_city() -> Dictionary:
	var out := {}
	for b in BUILDINGS:
		out[b.id] = randi_range(2, 5)
	return out


# ---------------- reguli generale ----------------
func building(id: String) -> Dictionary:
	for b in BUILDINGS:
		if b.id == id:
			return b
	return {}


func level_data(l := -1) -> Dictionary:
	var lv: Array = D.levels.levels
	var i := clampi((level if l < 0 else l) - 1, 0, lv.size() - 1)
	return lv[i]


func max_level() -> int:
	return (D.levels.levels as Array).size()


func finished() -> bool:
	return level > max_level()


func bet_unit() -> int:
	return int(level_data().bet_unit)


func globe_name(g := -1) -> String:
	var gl: Array = D.levels.globes
	return gl[clampi((globe if g < 0 else g) - 1, 0, gl.size() - 1)].name


func level_globe(l := -1) -> int:
	return int(level_data(l).globe)


## Upgrade-urile nivelului curent: [{building, stage, cost, time_s, done, building_now}]
func level_upgrades() -> Array:
	if finished():
		return []
	var out := []
	for u in level_data().upgrades:
		var d: Dictionary = (u as Dictionary).duplicate()
		d.done = int(levels.get(u.building, 0)) >= int(u.stage)
		d.building_now = is_building(u.building)
		d.cost = upgrade_cost(u)
		out.append(d)
	return out


func level_progress() -> Vector2i:
	var ups := level_upgrades()
	var done := 0
	for u in ups:
		if u.done:
			done += 1
	return Vector2i(done, ups.size())


## Următorul upgrade disponibil pentru o clădire în nivelul curent (sau {}).
func next_upgrade(id: String) -> Dictionary:
	if globe_locked():
		return {}
	for u in level_upgrades():
		if u.building == id and not u.done:
			return u
	return {}


func upgrade_cost(u: Dictionary) -> int:
	return int(round(float(u.cost) * (1.0 - skill_value("upgrade_discount"))))


func build_time(u: Dictionary) -> int:
	return int(round(float(u.time_s) * (1.0 - skill_value("build_speed"))))


func is_building(id: String) -> bool:
	for b in builds:
		if b.b == id:
			return true
	return false


func builders() -> int:
	return int(cfg("builders", 1)) + int(skill_value("builders"))


## Globul următor e blocat până la îmbunătățirile din Atelier (dirijabil).
func globe_locked() -> bool:
	return not finished() and level_globe() > globe


func can_upgrade(id: String) -> bool:
	var u := next_upgrade(id)
	return not u.is_empty() and not u.building_now and coins >= u.cost and builds.size() < builders()


func select(id: String) -> void:
	sel = id
	selected.emit(id)


func upgrade(id: String) -> bool:
	var u := next_upgrade(id)
	if u.is_empty() or u.building_now or coins < u.cost:
		return false
	if builds.size() >= builders():
		toast.emit("Constructorul e ocupat. Așteaptă să termine.")
		return false
	coins -= u.cost
	var t := build_time(u)
	builds.append({"b": id, "stage": int(u.stage), "end": _now() + t})
	Analytics.log_event("upgrade", {"building": id, "stage": u.stage, "cost": u.cost, "level": level})
	build_started.emit(id)
	changed.emit()
	if t <= 0:
		_tick()
	save_game()
	return true


## Termină construcția cu perle (1 perlă / 10 minute rămase).
func skip_cost(id: String) -> int:
	for b in builds:
		if b.b == id:
			return maxi(1, ceili((b.end - _now()) / 600.0) * int(cfg("skip_perle_per_10_min", 1)))
	return 0


func skip_build(id: String) -> bool:
	var c := skip_cost(id)
	if c <= 0 or perle < c:
		return false
	perle -= c
	for b in builds:
		if b.b == id:
			b.end = _now()
	_tick()
	return true


func build_remaining(id: String) -> int:
	for b in builds:
		if b.b == id:
			return maxi(0, int(b.end - _now()))
	return 0


func _finish_builds() -> void:
	var now := _now()
	var keep := []
	for b in builds:
		if b.end <= now:
			levels[b.b] = maxi(int(levels[b.b]), int(b.stage))
			stats.upgrades += 1
			upgraded.emit(b.b)
			mascot_jump.emit()
		else:
			keep.append(b)
	if keep.size() != builds.size():
		builds = keep
		_check_level()
		changed.emit()
		save_game()


func _check_level() -> void:
	while not finished() and not globe_locked():
		var p := level_progress()
		if p.x < p.y:
			return
		var r: Dictionary = level_data().reward
		var finished_level := level
		_grant({"units": r.get("units", 0), "energy": r.get("energy", 0), "perle": r.get("perle", 0), "chest": r.get("chest", "")}, "nivel")
		skill_points += 1
		level += 1
		Analytics.log_event("level_up", {"level": level})
		level_up.emit(level)
		toast.emit("Nivelul %d! +1 punct de abilitate" % level)
		if finished_level % 10 == 0:
			var g := finished_level / 10
			_trophy("glob_%d" % g)
			globe_completed.emit(g)
		_check_cosmetics()


## Călătoria cu dirijabilul spre globul următor (după îmbunătățirile din Atelier).
func can_travel() -> bool:
	if finished() or not globe_locked():
		return false
	var need := level_globe()
	for a in D.airship.upgrades:
		if int(a.get("opens_globe", 0)) == need and not airship.has(a.id):
			return false
	return true


func travel() -> bool:
	if not can_travel():
		return false
	globe = level_globe()
	for k in levels:
		levels[k] = 0
	builds.clear()
	select("")
	traveled.emit(globe)
	toast.emit("Bun venit în %s" % globe_name())
	changed.emit()
	save_game()
	return true


# ---------------- energie și multiplicator ----------------
func energy_cap() -> int:
	return int(cfg("energy.cap", 50)) + int(skill_value("energy_cap"))


func regen_s() -> float:
	return float(cfg("energy.regen_s", 600)) * (1.0 - skill_value("energy_regen"))


func energy_next_in() -> int:
	if energy >= energy_cap():
		return 0
	return maxi(0, int(regen_s() - (_now() - energy_t)))


func energy_full_in() -> int:
	if energy >= energy_cap():
		return 0
	return energy_next_in() + int((energy_cap() - energy - 1) * regen_s())


func _regen() -> void:
	var now := _now()
	if energy >= energy_cap():
		energy_t = now
		return
	if energy_t <= 0.0:
		energy_t = now
	var n := int((now - energy_t) / regen_s())
	if n > 0:
		energy = mini(energy_cap(), energy + n)     # peste plafon nu se acumulează
		energy_t = now if energy >= energy_cap() else energy_t + n * regen_s()
		changed.emit()


func multipliers() -> Array:
	if level < int(cfg("multiplier_unlock_level", 5)):
		return [1]
	var out := []
	for m in cfg("multipliers", [1]):
		out.append(int(m))
	return out


func cycle_mult() -> void:
	var m := multipliers()
	mult = m[(m.find(mult) + 1) % m.size()]
	changed.emit()


# ---------------- mașina de bule ----------------
## O rotire. Întoarce rezultatul cu simbolurile de afișat pe role, sau {} fără energie.
func spin() -> Dictionary:
	_regen()
	if not mult in multipliers():
		mult = 1
	if energy < mult:
		Analytics.log_event("energy_empty", {"level": level})
		return {}
	if energy >= energy_cap():
		energy_t = _now()
	energy -= mult
	var r := randi() % _w_total
	var o: Dictionary = {}
	for x in D.spin_table.outcomes:
		r -= int(x.weight)
		if r < 0:
			o = x
			break
	var res := {"id": o.id, "name": o.name, "type": o.type, "reels": _reels(o), "mult": mult, "coins": 0, "energy": 0, "big": false, "msg": ""}
	var u := bet_unit() * mult
	var cm := 1.0 + skill_value("spin_coins") + companion_bonus()
	match o.type:
		"coins":
			res.coins = int(round(o.units * u * cm))
			res.big = bool(o.get("big", false)) or int(o.units) >= 8
			res.msg = "+%s monede" % fmt(res.coins)
			if o.id == "jackpot":
				stats.jackpots += 1
				_trophy("jackpot")
		"energy":
			res.energy = int(o.amount) * mult
			res.msg = "+%d energie" % res.energy
		"shield":
			if shields < shield_cap():
				shields += 1
				res.msg = "Scut %d/%d" % [shields, shield_cap()]
			else:
				res.coins = int(round(o.units_if_full * u * cm))
				res.msg = "Scuturi pline: +%s monede" % fmt(res.coins)
		"chest":
			res.msg = add_chest(_pick_chest())
		"card":
			var got := add_cards(int(o.get("amount", 1)) * (1 if mult < 3 else 2))
			res.msg = "Carte nouă: %s" % card_name(got[0])
		"attack", "raid":
			res.msg = "Sabotaj!" if o.type == "attack" else "Spargere!"
		_:
			res.msg = "Fără câștig"
	coins += res.coins
	energy += res.energy
	stats.spins += 1
	stats.coins += res.coins
	_trophy("prima_rotire")
	_add_event_points(o.id)
	Analytics.log_event("spin", {"result": o.id, "mult": mult, "coins": res.coins})
	if res.big:
		big_win.emit(o.id)
	_check_cosmetics()
	changed.emit()
	save_game()
	return res


## Simbolurile de pe cele 3 role pentru un rezultat.
func _reels(o: Dictionary) -> Array:
	var syms: Array = D.spin_table.symbols
	if typeof(o.reels) == TYPE_ARRAY:
		var out := []
		for s in o.reels:
			if s == "*":
				var pick: String = syms[randi() % syms.size()]
				while pick == "coin":
					pick = syms[randi() % syms.size()]
				out.append(pick)
			else:
				out.append(s)
		if out.has("*") == false and o.reels.has("*"):
			out.shuffle()
		return out
	# „mix": trei simboluri diferite, fără două monede
	var pool := syms.duplicate()
	pool.shuffle()
	return [pool[0], pool[1], pool[2]] if not (pool[0] == "coin" and pool[1] == "coin") else [pool[1], pool[2], pool[3]]


func spin_odds() -> Array:
	var out := []
	for o in D.spin_table.outcomes:
		out.append({"name": o.name, "p": float(o.weight) / _w_total})
	return out


func shield_cap() -> int:
	return int(cfg("shield_max", 3)) + int(skill_value("shield_cap"))


# ---------------- atac și raid ----------------
func outcome(id: String) -> Dictionary:
	for o in D.spin_table.outcomes:
		if o.id == id:
			return o
	return {}


## Atac asupra unei ținte (TargetsRepository decide dacă e de antrenament sau reală).
func attack_reward(blocked: bool, m: int) -> int:
	var o := outcome("atac")
	var u := bet_unit() * m * (1.0 + skill_value("spin_coins"))
	var c := float(o.units_blocked if blocked else o.units) * u
	if blocked:
		c *= 1.0 + skill_value("blocked_bonus")
	stats.attacks += 0 if blocked else 1
	if stats.attacks >= 10:
		_trophy("atacator")
	return int(round(c))


func start_raid(m: int) -> Array:
	var o := outcome("raid")
	_raid = []
	for s in o.spots_units:
		_raid.append(int(round(float(s) * bet_unit() * m * (1.0 + skill_value("raid_coins")))))
	_raid.shuffle()
	stats.raids += 1
	if stats.raids >= 10:
		_trophy("raider")
	return _raid


func raid_picks() -> int:
	return int(outcome("raid").get("picks", 3))


func raid_value(i: int) -> int:
	return _raid[i] if i >= 0 and i < _raid.size() else 0


func add_coins(n: float) -> void:
	coins += n
	stats.coins += int(n)
	changed.emit()


# ---------------- cufere ----------------
func _pick_chest() -> String:
	var kinds: Dictionary = cfg("chests.kinds", {})
	var tot := 0
	for k in kinds:
		tot += int(kinds[k].weight)
	var r := randi() % maxi(tot, 1)
	for k in kinds:
		r -= int(kinds[k].weight)
		if r < 0:
			return k
	return kinds.keys()[0]


func chest_info(kind: String) -> Dictionary:
	return cfg("chests.kinds", {}).get(kind, {})


## Adaugă un cufăr într-un slot liber; dacă sloturile sunt pline, primești monedele pe loc.
func add_chest(kind: String) -> String:
	var info := chest_info(kind)
	if chests.size() < int(cfg("chests.slots", 3)):
		chests.append({"kind": kind, "end": 0.0})
		changed.emit()
		return "%s adăugat" % info.get("name", "Lot")
	var c := int(round(float(info.get("units", 5)) * bet_unit()))
	add_coins(c)
	return "Sloturi pline: %s deschis pe loc, +%s monede" % [info.get("name", "Lot"), fmt(c)]


func chest_open_time(kind: String) -> int:
	return int(round(float(chest_info(kind).get("open_s", 900)) * (1.0 - skill_value("chest_speed"))))


func chest_unlocking() -> int:
	for i in chests.size():
		if chests[i].end > 0.0:
			return i
	return -1


## Pornește deschiderea (un cufăr o dată) sau ia premiul dacă e gata. Întoarce un mesaj.
func chest_action(i: int) -> String:
	if i < 0 or i >= chests.size():
		return ""
	var c: Dictionary = chests[i]
	if c.end <= 0.0:
		if chest_unlocking() >= 0:
			return "Se deschide deja un lot"
		c.end = _now() + chest_open_time(c.kind)
		changed.emit()
		save_game()
		return "Lotul se deschide"
	if c.end > _now():
		return "Mai sunt %s" % fmt_time(int(c.end - _now()))
	chests.remove_at(i)
	stats.chests += 1
	var info := chest_info(c.kind)
	var msg := _grant({"units": float(info.get("units", 0)) * (1.0 + skill_value("chest_coins")), "energy": info.get("energy", 0), "perle": info.get("perle", 0), "cards": info.get("cards", 0)}, "cufar")
	Analytics.log_event("chest_open", {"kind": c.kind})
	changed.emit()
	save_game()
	return msg


# ---------------- rezervor ----------------
func built_stages() -> int:
	var s := (globe - 1) * BUILDINGS.size() * MAX_STAGE
	for v in levels.values():
		s += int(v)
	return s


func reservoir_rate() -> float:
	return float(cfg("reservoir.units_per_upgrade_per_hour", 0.25)) * built_stages() * bet_unit() * (1.0 + skill_value("reservoir_rate"))


func reservoir_cap() -> int:
	return int(reservoir_rate() * float(cfg("reservoir.cap_hours", 4)))


func reservoir_amount() -> int:
	if reservoir_t <= 0.0:
		reservoir_t = _now()
	return mini(reservoir_cap(), int(reservoir_rate() * (_now() - reservoir_t) / 3600.0))


func collect_reservoir() -> int:
	var a := reservoir_amount()
	if a <= 0:
		return 0
	add_coins(a)
	reservoir_t = _now()
	save_game()
	return a


# ---------------- serie zilnică ----------------
## Seria de 7 zile: se oprește când lipsești, dar nu se resetează.
func streak_available() -> bool:
	return int(streak.last) != today()


func claim_streak() -> String:
	if not streak_available():
		return ""
	var days: Array = cfg("streak", [])
	streak.day = int(streak.day) % days.size() + 1
	streak.last = today()
	var msg := _grant(days[streak.day - 1], "serie")
	if streak.day == days.size():
		_trophy("serie_7")
	_check_cosmetics()
	save_game()
	return "Ziua %d: %s" % [streak.day, msg]


# ---------------- eveniment ----------------
func event_end() -> float:
	return float(event.start) + float(cfg("event.duration_days", 7)) * 86400.0


func event_active() -> bool:
	return _now() < event_end()


func _add_event_points(outcome_id: String) -> void:
	if not event_active():
		return
	var pts: Dictionary = cfg("event.points", {})
	var p := int(pts.get(outcome_id, pts.get("default", 1))) * mult
	event.points = int(event.points) + p
	event_points.emit(p)
	var stages: Array = cfg("event.stages", [])
	while int(event.stage) < stages.size() and int(event.points) >= int(stages[event.stage].points):
		var msg := _grant(stages[event.stage], "eveniment")
		if stages[event.stage].has("cosmetic"):
			cosmetics[stages[event.stage].cosmetic] = true
		event.stage = int(event.stage) + 1
		toast.emit("%s, etapa %d: %s" % [cfg("event.name", "Eveniment"), event.stage, msg])


# ---------------- recompense ----------------
## Acordă o recompensă descrisă ca în fișierele de date. Întoarce textul.
func _grant(r: Dictionary, _src: String) -> String:
	var parts := []
	if float(r.get("units", 0)) > 0:
		var c := int(round(float(r.units) * bet_unit()))
		coins += c
		parts.append("+%s monede" % fmt(c))
	if int(r.get("energy", 0)) > 0:
		energy += int(r.energy)
		parts.append("+%d energie" % int(r.energy))
	if int(r.get("perle", 0)) > 0:
		perle += int(r.perle)
		parts.append("+%d perle" % int(r.perle))
	if int(r.get("cards", 0)) > 0:
		add_cards(int(r.cards))
		parts.append("%d cărți" % int(r.cards))
	if str(r.get("chest", "")) != "":
		parts.append(add_chest(str(r.chest)))
	changed.emit()
	return ", ".join(parts)


# ---------------- album ----------------
func card_key(s: int, i: int) -> String:
	return "%d:%d" % [s, i]


func card_name(k: Array) -> String:
	return D.cards.sets[k[0]].cards[k[1]]


func set_complete(s: int) -> bool:
	for i in (D.cards.sets[s].cards as Array).size():
		if int(cards.get(card_key(s, i), 0)) <= 0:
			return false
	return true


## Cărți noi: 70% din setul globului curent; indexul mare e mai rar.
func add_cards(n: int) -> Array:
	var got := []
	var sets: Array = D.cards.sets
	for k in n:
		var s := clampi(globe - 1, 0, sets.size() - 1) if randf() < 0.7 else randi() % mini(globe, sets.size())
		var cnt: int = (sets[s].cards as Array).size()
		var i := mini(cnt - 1, int(pow(randf(), 1.7) * cnt))
		var was := set_complete(s)
		cards[card_key(s, i)] = int(cards.get(card_key(s, i), 0)) + 1
		got.append([s, i])
		if not was and set_complete(s):
			var rw: Dictionary = cfg("card_set_reward", {})
			toast.emit("Set complet: %s! %s" % [sets[s].name, _grant(rw, "album")])
			_trophy("colectionar")
	changed.emit()
	return got


func album_sets_complete() -> int:
	var n := 0
	for s in (D.cards.sets as Array).size():
		if set_complete(s):
			n += 1
	return n


# ---------------- abilități ----------------
func skill(id: String) -> Dictionary:
	for s in D.skills.skills:
		if s.id == id:
			return s
	return {}


func can_unlock_skill(id: String) -> bool:
	var s := skill(id)
	if s.is_empty() or skills.has(id) or skill_points < int(s.cost):
		return false
	return not s.has("requires") or skills.has(s.requires)


func unlock_skill(id: String) -> bool:
	if not can_unlock_skill(id):
		return false
	skill_points -= int(skill(id).cost)
	skills[id] = true
	Analytics.log_event("skill_unlock", {"skill": id})
	changed.emit()
	save_game()
	return true


## Suma efectelor deblocate pentru o cheie (ex. „spin_coins").
func skill_value(effect: String) -> float:
	var v := 0.0
	for id in skills:
		var s := skill(id)
		if s.get("effect", "") == effect:
			v += float(s.value)
	return v


# ---------------- garderobă, însoțitor, dirijabil ----------------
func _check_cosmetics() -> void:
	for it in D.cosmetics.items:
		if cosmetics.has(it.id):
			continue
		var u: Dictionary = it.unlock
		var ok := false
		if u.has("level"):
			ok = level >= int(u.level)
		elif u.has("streak_day"):
			ok = int(streak.day) >= int(u.streak_day)
		elif u.has("jackpots"):
			ok = int(stats.jackpots) >= int(u.jackpots)
		elif u.has("album_sets"):
			ok = album_sets_complete() >= int(u.album_sets)
		elif u.has("spins"):
			ok = int(stats.spins) >= int(u.spins)
		if ok:
			cosmetics[it.id] = true
			toast.emit("Piesă nouă în garderobă: %s" % it.name)


func equip(item_id: String) -> void:
	for it in D.cosmetics.items:
		if it.id == item_id and cosmetics.has(item_id):
			equipped[it.slot] = item_id
			Analytics.log_event("cosmetic_equip", {"item": item_id})
	for slot in D.cosmetics.defaults:
		if D.cosmetics.defaults[slot] == item_id:
			equipped[slot] = item_id
	changed.emit()
	save_game()


func companion_stage() -> Dictionary:
	var st: Array = D.airship.companion.stages
	var cur: Dictionary = st[0]
	for s in st:
		if level >= int(s.level):
			cur = s
	return cur


func companion_bonus() -> float:
	return float(companion_stage().get("bonus", 0.0))


func airship_cost(a: Dictionary) -> int:
	return int(round(float(a.cost_units) * bet_unit()))


func can_buy_airship(a: Dictionary) -> bool:
	if airship.has(a.id) or level - 1 < int(a.requires_level):
		return false
	if a.has("requires") and not airship.has(a.requires):
		return false
	return coins >= airship_cost(a)


func buy_airship(id: String) -> bool:
	for a in D.airship.upgrades:
		if a.id == id and can_buy_airship(a):
			coins -= airship_cost(a)
			airship[id] = true
			if a.has("trophy"):
				_trophy(a.trophy)
			changed.emit()
			save_game()
			return true
	return false


func _trophy(id: String) -> void:
	if trophies.has(id):
		return
	trophies[id] = _now()
	for t in TROPHIES:
		if t.id == id and id != "prima_rotire":
			toast.emit("Trofeu: %s" % t.name)


# ---------------- ceas ----------------
func _tick() -> void:
	_regen()
	_finish_builds()


# ---------------- formatare ----------------
static func fmt(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


static func fmt_time(sec: int) -> String:
	if sec >= 3600:
		return "%d h %02d min" % [sec / 3600, (sec % 3600) / 60]
	if sec >= 60:
		return "%d min %02d s" % [sec / 60, sec % 60]
	return "%d s" % sec


func set_quality(q: String) -> void:
	quality = q
	quality_changed.emit(q)
	save_game()


# ---------------- prieteni (server, opțional) ----------------
func apply_remote(kind: String, data: Dictionary) -> void:
	var who: String = str(data.get("from", "Cineva"))
	match kind:
		"visit":
			var fid := int(data.get("from_id", -1))
			var fl: Dictionary = friend_flags.get(str(fid), {})
			fl["visit"] = true
			friend_flags[str(fid)] = fl
			friend_signal.emit(fid)
			toast.emit("%s ți-a vizitat orașul" % who)
		"gift":
			var gid := int(data.get("from_id", -1))
			var gf: Dictionary = friend_flags.get(str(gid), {})
			gf["gift"] = true
			friend_flags[str(gid)] = gf
			if str(data.get("card", "")).contains(":"):
				cards[str(data.card)] = int(cards.get(str(data.card), 0)) + 1
			else:
				add_coins(int(data.get("coins", 0)))
			friend_signal.emit(gid)
			toast.emit("%s ți-a lăsat un cadou" % who)
	changed.emit()
	save_game()


# ---------------- salvare ----------------
func save_dict() -> Dictionary:
	last_save = _now()
	return {
		"v": SAVE_VERSION, "coins": coins, "perle": perle, "en": energy, "et": energy_t, "mult": mult,
		"sh": shields, "lvl": level, "glob": globe, "b": levels, "builds": builds, "sp": skill_points,
		"skills": skills, "cos": cosmetics, "eq": equipped, "air": airship, "chests": chests,
		"rt": reservoir_t, "streak": streak, "event": event, "cards": cards, "stats": stats,
		"tro": trophies, "tr": training, "notif": notif_enabled, "q": quality, "snd": sound,
		"vib": vibration, "first": first_open, "t": last_save, "gd": gift_days, "ff": friend_flags,
	}


func save_game() -> void:
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(save_dict()))


func load_game() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if typeof(d) != TYPE_DICTIONARY or int(d.get("v", 0)) != SAVE_VERSION:
		return
	coins = float(d.get("coins", 0))
	perle = int(d.get("perle", 0))
	energy = int(d.get("en", energy))
	energy_t = float(d.get("et", 0))
	mult = int(d.get("mult", 1))
	shields = int(d.get("sh", 0))
	level = clampi(int(d.get("lvl", 1)), 1, max_level() + 1)
	globe = clampi(int(d.get("glob", 1)), 1, 3)
	var b: Dictionary = d.get("b", {})
	for k in levels:
		levels[k] = clampi(int(b.get(k, 0)), 0, MAX_STAGE)
	builds = d.get("builds", [])
	skill_points = int(d.get("sp", 0))
	skills = d.get("skills", {})
	cosmetics = d.get("cos", {})
	var eq: Dictionary = d.get("eq", {})
	for k in eq:
		equipped[k] = eq[k]
	airship = d.get("air", {})
	chests = d.get("chests", [])
	reservoir_t = float(d.get("rt", 0))
	streak = d.get("streak", streak)
	event = d.get("event", event)
	cards = d.get("cards", {})
	var st: Dictionary = d.get("stats", {})
	for k in st:
		stats[k] = int(st[k])
	trophies = d.get("tro", {})
	var tr: Dictionary = d.get("tr", {})
	for k in tr:
		training[k] = tr[k]
	notif_enabled = bool(d.get("notif", false))
	var q := str(d.get("q", quality))
	quality = q if q in ["mic", "mediu", "mare"] else "mediu"
	sound = bool(d.get("snd", true))
	vibration = bool(d.get("vib", true))
	first_open = float(d.get("first", 0))
	last_save = float(d.get("t", 0))
	gift_days = d.get("gd", {})
	friend_flags = d.get("ff", {})
