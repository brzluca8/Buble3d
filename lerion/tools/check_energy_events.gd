extends SceneTree
## Etapa 3.5: energy without tile income, regeneration, events, Developer Panel tools and isolation.
## XDG_DATA_HOME=/tmp/lerion-ee godot --headless --fixed-fps 60 --script tools/check_energy_events.gd
const Scene := preload("res://scenes/board.tscn")
const Save := preload("res://scripts/board/board_save.gd")
const Legacy := preload("res://scripts/crystal/progress.gd")
const Crystal := preload("res://scripts/crystal/super_crystal_service.gd")
const Energy := preload("res://scripts/economy/energy_service.gd")
const Events := preload("res://scripts/economy/event_service.gd")
const Profile := preload("res://scripts/developer/dev_profile.gd")
const ECONOMY := preload("res://assets/board/economy.tres")
const RULES := preload("res://assets/board/rules.tres")
var T := 0
var prefix := "user://ee_check_%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()]
var failures := 0
var checks := 0


class PairSave extends "res://scripts/board/board_save.gd":
	var pair := Vector2i.ZERO
	func _draw_faces() -> Vector2i:
		return pair if pair != Vector2i.ZERO else super()


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		push_error(description)
		failures += 1


func _clean(p: String) -> void:
	for slot in range(2):
		DirAccess.remove_absolute("%s_board_v3.%d.json" % [p,slot])


func _land(game: PairSave, origin: int, pair: Vector2i, now: int, energy := 50) -> Dictionary:
	game.busy = false
	game.state.board_position_index = origin
	game.state.last_roll = {}
	game.state.energy = energy
	game.pair = pair
	var receipt := game.roll(now)
	game.busy = false
	return receipt


func economy_layout() -> void:
	var counts := {}
	for tile in range(36):
		var type := ECONOMY.kind(tile,36)
		counts[type] = int(counts.get(type,0)) + 1
		check(type != "energy","Nicio căsuță de energie: " + str(tile))
		check(type != ECONOMY.kind((tile+1)%36,36),"Vecine diferite %d→%d" % [tile,(tile+1)%36])
		check(not (type == ECONOMY.kind((tile+1)%36,36) and type == ECONOMY.kind((tile+2)%36,36)),"Fără triple, inclusiv 35→0")
	check(ECONOMY.tile_types.size() == 36 and ECONOMY.kind(0,36) == "start","36 de căsuțe, START la 0")
	check(counts == {"start":1,"coin":7,"crystal":7,"construction":7,"magic":7,"quest":7},"Distribuție 7×5 + START")
	check(not ECONOMY.payouts.has("energy"),"Fără tabel de plată pentru energie")
	check(ECONOMY.tiles_for("right_top",36).is_empty(),"Moara nu deține căsuțe")
	# Neither a tile nor a building table can ever pay energy.
	var rng := RandomNumberGenerator.new()
	for tile in range(1,36):
		for level in range(4):
			check(ECONOMY.award(tile,36,level,rng).resource != "energy","Premiu de căsuță fără energie")
	var unchanged := {1:"coin",3:"quest",5:"construction",6:"magic",10:"magic",14:"crystal",30:"quest"}
	for tile: int in unchanged:
		check(ECONOMY.kind(tile,36) == unchanged[tile],"Căsuța %d nemodificată" % tile)


func rules_and_regeneration() -> void:
	check(RULES.energy_max == 100 and RULES.energy_cost == 1 and RULES.regeneration_seconds == 600 and RULES.regen_amount == 1,"Valori inițiale 100 / 1 / 10 minute")
	var s := {"energy":0,"tick":T,"clock_mark":0}
	Energy.regenerate(s,T + 599)
	check(s.energy == 0,"599 s: nimic")
	Energy.regenerate(s,T + 600)
	check(s.energy == 1 and s.tick == T + 600,"600 s: +1")
	Energy.regenerate(s,T + 600 + 6*600 + 599)
	check(s.energy == 7 and s.tick == T + 600 + 6*600,"Pași întregi, rest păstrat")
	check(Energy.seconds_to_next(s,T + 600 + 6*600 + 599) == 1,"Timp rămas exact")
	s = {"energy":10,"tick":T,"clock_mark":0}
	Energy.regenerate(s,T + 100*86400)
	check(s.energy == 100,"Regenerarea se oprește la 100")
	s = {"energy":120,"tick":T,"clock_mark":0}
	Energy.regenerate(s,T + 100*86400)
	check(s.energy == 120 and Energy.seconds_to_next(s,T) == -1,"Peste 100: regenerare suspendată")
	s.clock_mark = 0
	check(Energy.spend(s,T + 5000) and s.energy == 119 and s.tick == T + 5000,"Cheltuirea de peste 100 repornește cronometrul")
	for i in range(19):
		Energy.spend(s,T + 5000)
	check(s.energy == 100,"Se scade 1 pe aruncare")
	s.clock_mark = 0
	check(Energy.spend(s,T + 6000) and s.energy == 99 and s.tick == T + 6000,"La 100 → 99 cronometrul pornește")
	check(Energy.grant(s,30) == 30 and s.energy == 129,"Premiu peste 100")
	check(Energy.grant(s,100000) == RULES.energy_hard_cap - 129,"Plafon tehnic")
	# Clock guard: an earlier phone clock never regenerates again, and never moves the timer back.
	s = {"energy":0,"tick":T,"clock_mark":0}
	Energy.regenerate(s,T + 600)
	check(s.energy == 1 and s.clock_mark == T + 600,"Ceas înregistrat")
	Energy.regenerate(s,T)
	Energy.regenerate(s,T + 100)
	check(s.energy == 1 and s.tick == T + 600,"Ceas dat înapoi: fără energie")
	Energy.regenerate(s,T + 1200)
	check(s.energy == 2,"Timpul real continuă normal")


func restart_regeneration() -> void:
	var p := prefix + "_regen"
	var game := PairSave.new(p,T)
	game.state.energy = 40
	game.state.tick = T
	game.state.clock_mark = 0
	game.pair = Vector2i(1,3)
	game.roll(T)
	game.busy = false
	var energy_after: int = game.state.energy
	check(energy_after == 39,"Aruncare: 1 energie")
	var tick: int = game.state.tick
	# Closed for 3 hours 5 minutes: 18 full steps, remainder carried.
	var reopened := Save.new(p,T + 3*3600 + 300)
	check(reopened.state.energy == 39 + 18 and reopened.state.tick == tick + 18*600,"După repornire: +18 și rest păstrat")
	check(Save.new(p,T + 3*3600 + 300).state.energy == 57,"Idempotent la încărcări repetate")
	check(Save.new(p,T).state.energy == 57,"Ceas dat înapoi după repornire: fără câștig și fără pierdere")
	reopened.regenerate(T + 3*3600 + 300 + 299)
	check(reopened.state.energy == 57,"Restul de 5 minute + 4:59 nu dă încă energie")
	reopened.regenerate(T + 3*3600 + 300 + 300)
	check(reopened.state.energy == 58,"Restul se adună: 5 + 5 minute = +1")
	_clean(p)


func no_tile_energy_loop() -> void:
	var p := prefix + "_loop"
	var game := Save.new(p,T)
	game.rng.seed = 11
	var landings := {}
	var wrong := 0
	for i in range(3000):
		game.state.energy = 100
		game.state.crystal_charge = 0
		var before: int = game.state.energy
		var receipt := game.roll(T)
		game.busy = false
		wrong += int(game.state.energy != before - 1)
		landings[str(receipt.landing.get("resource","none"))] = true
	check(wrong == 0,"3000 aruncări: de fiecare dată exact −1 energie, nicio creditare de pe traseu")
	check(not landings.has("energy") and landings.has("coins") and landings.has("quest_tokens"),"Resurse câștigate: " + str(landings.keys()))
	_clean(p)


func event_points_rules() -> void:
	var p := prefix + "_event"
	var game := PairSave.new(p,T)
	game.state.levels.fill(0)
	game.state.clock_mark = 0
	check(game.state.version == 6 and game.state.event.is_empty() and game.state.event_history.is_empty(),"Fără eveniment implicit")
	var idle := _land(game,2,Vector2i(1,2),T)
	check(not idle.has("event_points"),"Fără eveniment: fără puncte")
	check(game.start_event("pufi_festival",T) and not game.start_event("pufi_festival",T),"Pornire o singură dată")
	var def := Events.definition("pufi_festival")
	check(def.name == "Festivalul lui Pufi" and int(def.duration_hours) == 48 and game.state.event.end == T + 48*3600,"Festivalul lui Pufi, 48 de ore")
	# Passing over crystal, construction and magic tiles gives nothing: 2 → 7 (coin) passes 4, 5, 6.
	var points_before: int = game.state.event.points
	var pass_over := _land(game,2,Vector2i(2,3),T + 10)
	check(game.state.board_position_index == 7 and ECONOMY.kind(7,36) == "coin" and game.state.event.points == points_before and not pass_over.has("event_points"),"Trecerea peste căsuțe nu dă puncte")
	# Landing: each category pays exactly its points, on top of the normal reward.
	var expected := {"crystal":2,"construction":3,"magic":5}
	var pairs := {"crystal":Vector2i(1,3),"construction":Vector2i(2,3),"magic":Vector2i(3,3)}
	var tiles := {"crystal":4,"construction":5,"magic":6}
	for kind: String in expected:
		var before: Dictionary = game.state.duplicate(true)
		var receipt := _land(game,0,pairs[kind],T + 20)
		check(game.state.board_position_index == tiles[kind] and ECONOMY.kind(tiles[kind],36) == kind,"Aterizare pe " + kind)
		check(int(receipt.event_points) == expected[kind] and game.state.event.points == int(before.event.points) + expected[kind],"Puncte " + kind)
		var resource: String = receipt.landing.resource
		check(game.state.wallet[resource] == before.wallet[resource] + int(receipt.landing.amount),"Premiul obișnuit rămâne, în plus")
	var plain := {"coin":[7,Vector2i(3,4)],"quest":[3,Vector2i(1,2)]}
	for kind: String in plain:
		var before_points: int = game.state.event.points
		var receipt := _land(game,0,plain[kind][1],T + 30)
		check(game.state.board_position_index == plain[kind][0] and ECONOMY.kind(plain[kind][0],36) == kind and game.state.event.points == before_points and not receipt.has("event_points"),"Fără puncte pe " + kind)
	# Not active: after the end the roll gives nothing.
	var late := _land(game,0,Vector2i(1,3),T + 48*3600 + 1)
	check(ECONOMY.kind(4,36) == "crystal" and not late.has("event_points"),"După sfârșit: fără puncte")
	_clean(p)


func claims_and_mill() -> void:
	var p := prefix + "_claim"
	var game := PairSave.new(p,T)
	game.state.clock_mark = 0
	game.state.levels.fill(0)
	game.start_event("pufi_festival",T)
	check(game.claim_event_reward("p50",T + 5).is_empty() and game.state.event.claimed.is_empty(),"Prag neatins: refuzat")
	var next: Dictionary = game.state.duplicate(true)
	next.event.points = 160
	game._commit(next)
	game.state.energy = 90
	var sequence: int = game.state.seq
	var first := game.claim_event_reward("p50",T + 5)
	check(first.amount == 20 and game.state.energy == 110 and game.state.event.claimed == ["p50"],"+20 energie, peste 100")
	var after: Dictionary = game.state.duplicate(true)
	check(game.claim_event_reward("p50",T + 6).is_empty() and game.state == after and game.state.seq == sequence + 1,"A doua revendicare refuzată, fără scriere")
	check(game.claim_event_reward("p150",T + 7).amount == 50 and game.state.energy == 160,"+50 energie la 150")
	check(game.claim_event_reward("nu_exista",T).is_empty() and game.claim_event_reward("p350",T).is_empty(),"Necunoscut și neatins refuzate")
	var reloaded := Save.new(p,T + 8)
	check(reloaded.state.event.claimed == ["p50","p150"] and reloaded.claim_event_reward("p50",T + 9).is_empty(),"După repornire nu se poate revendica din nou")
	check(reloaded.state.event.claims.size() == 2 and typeof(reloaded.state.event.points) == TYPE_INT,"Chitanțe salvate, valori întregi")
	# Chests.
	next = game.state.duplicate(true)
	next.event.points = 1300
	game._commit(next)
	var wood := game.claim_event_reward("p350",T + 10)
	var silver := game.claim_event_reward("p1200",T + 10)
	check(wood.chest == "wood" and silver.chest == "silver" and game.state.chests.wood == 1 and game.state.chests.silver == 1,"Cufere de lemn și argint")
	# Mill bonus applies only to energy, per level, and never above the documented total.
	var table := [0,10,20,30]
	var totals := []
	for level in range(4):
		var g2 := PairSave.new(p + "_mill%d" % level,T)
		g2.state.clock_mark = 0
		g2.state.levels[1] = level
		g2.start_event("pufi_festival",T)
		g2.state.event.points = 5000
		g2.state.energy = 0
		var energy_total := 0
		var chests_total := 0
		for item: Dictionary in def_milestones():
			var receipt := g2.claim_event_reward(item.id,T + 1)
			check(not receipt.is_empty(),"Revendicare " + item.id)
			if receipt.kind == "energy":
				energy_total += int(receipt.amount)
				check(receipt.base_amount == item.amount and receipt.amount == roundi(item.amount*(100+table[level])/100.0),"Moara nivel %d: +%d%%" % [level,table[level]])
			else:
				chests_total += 1
				check(receipt.amount == item.amount and receipt.bonus_percent == 0,"Cufărul nu este multiplicat")
		check(g2.state.energy == energy_total and chests_total == 2,"Energie totală și cufere, nivel %d" % level)
		totals.append(energy_total)
		_clean(p + "_mill%d" % level)
	check(totals == [170,187,204,221],"Energie totală dintr-un festival: %s" % str(totals))
	# Claim window: claimable after the end, not after the grace period.
	var g3 := PairSave.new(p + "_window",T)
	g3.state.clock_mark = 0
	g3.start_event("pufi_festival",T)
	g3.state.event.points = 60
	var end := T + 48*3600
	check(g3.event_status(end - 1) == "active" and g3.event_status(end) == "claiming" and g3.event_status(end + 12*3600) == "closed","Faze active / revendicare / închis")
	var late_points := _land(g3,0,Vector2i(1,3),end + 10)
	check(not late_points.has("event_points") and g3.state.event.points == 60,"În perioada de revendicare nu se mai acordă puncte")
	check(not g3.claim_event_reward("p50",end + 100).is_empty(),"Revendicare după sfârșit, în perioada permisă")
	g3.state.event.points = 150
	check(g3.claim_event_reward("p150",end + 12*3600 + 1).is_empty(),"După perioadă: refuzat")
	check(g3.close_expired_events(end + 12*3600 + 1) and g3.state.event.is_empty() and g3.state.event_history.size() == 1 and g3.state.event_history[0].claimed == ["p50"],"Arhivare")
	check(g3.start_event("pufi_festival",end + 12*3600 + 2),"Eveniment nou după arhivare")
	_clean(p)
	_clean(p + "_window")


func def_milestones() -> Array:
	return Events.definition("pufi_festival").milestones


func crystal_compatibility() -> void:
	var p := prefix + "_compat"
	var game := PairSave.new(p,T)
	game.state.clock_mark = 0
	game.start_event("pufi_festival",T)
	game.state.crystal_charge = 50
	game.state.energy = 95
	var points: int = game.state.event.points
	var receipt := game.spin_wheel(T + 1)
	check(not receipt.is_empty() and game.state.event.points == points and game.state.crystal_charge == 0,"Rotirea nu schimbă punctele de eveniment")
	check(game.state.energy >= 95,"Premiul ruletei se adaugă")
	game.acknowledge_spin(int(receipt.id))
	# Rolls keep charging the crystal while an event runs.
	var charge: int = game.state.crystal_charge
	_land(game,0,Vector2i(1,3),T + 2)
	check(game.state.crystal_charge == charge + 1 and game.state.event.points == points + 2,"Încărcare cristal + puncte în aceeași aruncare")
	var reload := Save.new(p,T + 3)
	check(reload.state.event == game.state.event and reload.state.crystal_charge == game.state.crystal_charge and reload.state.chests == game.state.chests,"Salvare comună")
	_clean(p)


func migration() -> void:
	var p := prefix + "_old"
	var game := Save.new(p,T)
	var old: Dictionary = game.state.duplicate(true)
	old.version = 5
	for field in ["event","event_history","clock_mark"]:
		old.erase(field)
	old.wallet = {"coins":4321,"fragments":12,"build_points":8,"tickets":0,"quest_tokens":3}
	old.levels = [1,2,3,0,1,2]
	old.energy = 61
	old.chests = {"wood":2,"silver":1,"gold":0}
	old.crystal_charge = 33
	old.board_position_index = 21
	game._commit(old)
	var hashes := []
	for slot in range(2):
		hashes.append(FileAccess.get_sha256(game._path(slot)) if FileAccess.file_exists(game._path(slot)) else "")
	var loaded := Save.new(p,T)
	check(loaded.error.is_empty() and loaded.state.version == 6,"Salvare v5 încărcată")
	check(loaded.state.wallet == old.wallet and loaded.state.levels == old.levels and loaded.state.chests == old.chests and loaded.state.crystal_charge == 33 and loaded.state.board_position_index == 21,"Progresul existent rămâne")
	check(loaded.state.event.is_empty() and loaded.state.clock_mark == 0 and loaded.state.energy == 61,"Energie și câmpuri noi neutre")
	var again := []
	for slot in range(2):
		again.append(FileAccess.get_sha256(game._path(slot)) if FileAccess.file_exists(game._path(slot)) else "")
	check(hashes == again,"Încărcarea nu rescrie salvarea")
	_clean(p)


func developer_tools() -> void:
	var normal := Save.new(prefix + "_normal",T)
	normal._commit(normal.state.duplicate(true))
	var normal_hash := []
	for slot in range(2):
		normal_hash.append(FileAccess.get_sha256(normal._path(slot)) if FileAccess.file_exists(normal._path(slot)) else "")
	var profile := Profile.new()
	check(profile.allowed() and profile.reset_profile(true),"Profil DEBUG separat")
	check(profile.save_prefix != normal.save_prefix and not profile.save_prefix.begins_with(prefix),"Prefix distinct")
	for value in [0,1,50,99,100,500]:
		check(profile.set_energy(value) and profile.state.energy == value,"Energie %d" % value)
	check(not profile.set_energy(-1) and not profile.set_energy(RULES.energy_hard_cap + 1),"Energie invalidă refuzată")
	# Regeneration toggle and simulated time.
	check(profile.set_energy(10) and profile.set_regen(false) and not profile.regen_enabled(),"Regenerare oprită")
	check(profile.advance_time(3600) and profile.state.energy == 10,"Oprită: o oră nu dă nimic")
	check(profile.set_regen(true) and profile.regen_enabled(),"Regenerare pornită")
	check(profile.advance_time(600) and profile.state.energy == 11,"+10 minute → +1")
	check(profile.advance_time(3600) and profile.state.energy == 17,"+1 oră → +6")
	check(profile.advance_time(86400) and profile.state.energy == 100,"+24 ore → plafon 100")
	check(profile.regen_info().to_next == -1,"La 100 nu mai există timp rămas")
	check(profile.set_energy(40) and profile.regen_info().to_next > 0 and profile.regen_info().to_next <= 600,"Timp rămas până la regenerare")
	check(profile.set_energy(500) and profile.advance_time(86400) and profile.state.energy == 500,"Peste 100: neatins de timp")
	check(not profile.advance_time(0),"Timp zero refuzat")
	# Chosen landing tile through the real roll for every tile.
	for tile in range(36):
		profile.busy = false
		check(profile.set_energy(20) and profile.force_landing(tile),"Pregătire aterizare " + str(tile))
		var receipt := profile.roll()
		profile.busy = false
		check(not receipt.is_empty() and profile.state.board_position_index == tile,"Aterizează pe căsuța %d" % tile)
	# Chests.
	check(profile.set_chests(0,0,0),"Cufere zero")
	for kind in ["wood","silver","gold"]:
		for count in [1,10,100]:
			var before: int = profile.state.chests[kind]
			check(profile.add_chests(kind,count) and profile.state.chests[kind] == before + count,"+%d %s" % [count,kind])
	check(profile.state.chests == {"wood":111,"silver":111,"gold":111},"Inventar 111 × 3")
	check(profile.verify_saved().identical,"Verificarea salvării: memorie = disc")
	check(not profile.add_chests("platinum",1) and not profile.add_chests("wood",0),"Cufere invalide refuzate")
	# Events.
	check(profile.start_event("pufi_festival") and profile.state.event.points == 0,"Pornire eveniment de test")
	for kind in ["crystal","construction","magic","coin"]:
		var gained := profile.simulate_event_landing(kind)
		check(gained == {"crystal":2,"construction":3,"magic":5,"coin":0}[kind],"Simulare aterizare " + kind)
	check(profile.state.event.points == 10,"Puncte 2+3+5")
	check(profile.set_event_points(40) and profile.state.event.points == 40,"Puncte manuale")
	check(profile.force_milestone("p150") and profile.state.event.points == 150,"Forțare prag 150")
	check(profile.force_milestone("p50") and profile.state.event.points == 150,"Pragul inferior nu scade punctele")
	var duplicates := profile.duplicate_claim_test("p350")
	check(duplicates.first_granted and duplicates.second_refused and duplicates.state_unchanged_by_second,"Revendicare duplicată refuzată (copie izolată)")
	check(profile.state.event.claimed.is_empty(),"Testul duplicat nu atinge profilul")
	check(profile.claim_event_reward("p50").kind == "energy" and profile.claim_event_reward("p50").is_empty(),"Revendicare reală o singură dată")
	check(profile.expire_event("claiming") and Events.status(profile.state.event,profile.clock()) == "claiming","Simulare expirare: perioadă de revendicare")
	check(profile.simulate_event_landing("magic") == 0,"După expirare: fără puncte")
	check(profile.expire_event("closed") and profile.close_expired_events() and profile.state.event.is_empty() and profile.state.event_history.size() == 1,"Simulare închidere + arhivare")
	check(profile.start_event("pufi_festival") and profile.stop_event(false) and profile.state.event.is_empty(),"Oprire")
	check(profile.stop_event(true) and profile.state.event_history.is_empty(),"Resetare completă a evenimentelor")
	# Snapshot, history, selective reset.
	check(profile.set_energy(77) and profile.checkpoint(),"Snapshot")
	var snap: Dictionary = profile.state.duplicate(true)
	check(profile.set_energy(5) and profile.restore_checkpoint() and profile.state.energy == 77 and profile.state.wallet == snap.wallet,"Restaurare snapshot")
	check(profile.history_text().contains("set_energy") and profile.state.debug_log.size() <= Profile.LOG_LIMIT,"Istoric tranzacții")
	var kept: Dictionary = profile.state.duplicate(true)
	check(not profile.reset_part("chests",false),"Resetare selectivă cere confirmare")
	check(profile.reset_part("chests",true) and profile.state.chests == Crystal.empty_chests() and profile.state.energy == kept.energy and profile.state.wallet == kept.wallet and profile.state.levels == kept.levels,"Resetare selectivă: numai cuferele")
	check(profile.set_crystal(30,0) and profile.reset_part("crystal",true) and profile.state.crystal_charge == 0 and profile.state.chests == Crystal.empty_chests(),"Resetare selectivă: cristal")
	check(not profile.reset_part("necunoscut",true),"Parte necunoscută refuzată")
	# Crystal tools.
	check(profile.set_crystal(49,0) and Crystal.charge(profile.state) == 49 and profile.charge_crystal() and Crystal.is_ready(profile.state),"Cristal: 49 și încărcare instantanee")
	check(profile.force_prize("energy_30") and profile.set_energy(90),"Premiu forțat energie")
	var receipt := profile.spin_wheel()
	check(receipt.prize == "energy_30" and profile.state.energy == 120,"90 + 30 = 120")
	check(profile.spin_history_text().contains("+30 energie"),"Istoric premii")
	# Isolation: nothing above touched the normal profile.
	var after := []
	for slot in range(2):
		after.append(FileAccess.get_sha256(normal._path(slot)) if FileAccess.file_exists(normal._path(slot)) else "")
	check(after == normal_hash,"Salvarea normală neatinsă")
	var fake = Save.new(prefix + "_normal",T)
	check(not fake.has_method("advance_time") and not fake.has_method("set_energy") and not fake.has_method("stop_event"),"Funcțiile DEBUG nu există în salvarea normală")
	var simulated := profile.simulate_spins(1000)
	check(simulated.spins == 1000 and simulated.double_grants == 0,"Simulare rotiri")
	var sim_state: Dictionary = profile.state.duplicate(true)
	for count in [100,1000]:
		var report: Dictionary = await Simulation.new().run(sim_state,count,self)
		check(report.completed == count and report.energy_spent == count and report.energy_from_tiles == 0,"Simulare %d: consum de energie, fără venit din căsuțe" % count)
	check(profile.state == sim_state,"Simularea nu scrie în profil")
	for slot in range(2):
		DirAccess.remove_absolute(normal._path(slot))


const Simulation := preload("res://scripts/developer/economy_simulation.gd")


func _start(p: String) -> Node:
	var map := Scene.instantiate()
	map.save_prefix = p
	root.add_child(map)
	current_scene = map
	return map


func scene_flow() -> void:
	var p := prefix + "_scene"
	var legacy := Legacy.new(p)
	legacy.debug_grant()
	var map := _start(p)
	await process_frame
	await process_frame
	check(not map.hud.event_chip.visible,"Fără eveniment: fără buton")
	check(map.game.start_event("pufi_festival"),"Eveniment pornit")
	map._refresh()
	check(map.hud.event_chip.visible and map.hud.event_chip.text.contains("Festival"),"Buton eveniment cu timp rămas")
	map.open_event()
	check(map.event_screen.is_open() and map.event_screen.title.text == "Festivalul lui Pufi","Ecranul evenimentului")
	check(map.event_screen.timer_label.text.contains("Timp rămas") and map.event_screen.rows.get_child_count() == 5,"Timp și cinci recompense")
	check(map.event_screen.next_label.text.contains("50 puncte"),"Următoarea recompensă")
	map._roll()
	check(not map.game.busy,"Aruncarea este blocată cât timp ecranul este deschis")
	map.event_screen.close()
	# A real landing in the scene grants points and shows them.
	var game: RefCounted = map.game
	var state: Dictionary = game.state.duplicate(true)
	state.board_position_index = 0
	state.last_roll = {}
	state.energy = 50
	game._commit(state)
	game.rng.seed = 1
	var attempt := 0
	while attempt < 200:
		attempt += 1
		var probe := RandomNumberGenerator.new()
		probe.seed = attempt
		var pair := Vector2i(probe.randi_range(1,6),probe.randi_range(1,6))
		if pair.x + pair.y == 6:
			game.rng.seed = attempt
			break
	map._roll()
	map._finish()
	check(game.state.board_position_index == 6 and int(game.state.last_roll.get("event_points",0)) == 5 and game.state.event.points == 5,"Aterizare pe magie: +5 puncte")
	var toast_seen := false
	for child in map.hud.get_children():
		toast_seen = toast_seen or (child is Label and child.text.contains("+5 puncte · Festivalul lui Pufi"))
	check(toast_seen,"Mesaj de puncte")
	# Claim button: two presses, one reward.
	var next: Dictionary = game.state.duplicate(true)
	next.event.points = 60
	next.energy = 50
	game._commit(next)
	map.open_event()
	var button: Button = map.event_screen.rows.get_child(0).get_child(1)
	check(button.text == "Revendică" and not button.disabled,"Buton de revendicare")
	var seq: int = game.state.seq
	button.pressed.emit()
	button.pressed.emit()
	await process_frame
	check(game.state.energy == 70 and game.state.event.claimed == ["p50"] and game.state.seq == seq + 1,"Dublu tap: o singură revendicare")
	await process_frame
	var done: Button = map.event_screen.rows.get_child(0).get_child(1)
	check(done.disabled and done.text.contains("Revendicat"),"Recompensă marcată ca revendicată")
	map.event_screen.close()
	map.free()
	map = _start(p)
	await process_frame
	check(map.game.state.event.claimed == ["p50"] and map.hud.event_chip.visible,"Repornire: progres și revendicări păstrate")
	map.free()
	_clean(p)
	for slot in range(2):
		DirAccess.remove_absolute(legacy._path(slot))


func _run() -> void:
	T = int(Time.get_unix_time_from_system())
	economy_layout()
	rules_and_regeneration()
	restart_regeneration()
	no_tile_energy_loop()
	event_points_rules()
	claims_and_mill()
	crystal_compatibility()
	migration()
	await developer_tools()
	await scene_flow()
	print("Energie și evenimente: %d verificări, %d erori." % [checks,failures])
	quit(1 if failures else 0)
