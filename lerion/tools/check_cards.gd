extends SceneTree
## Etapa 4.1: chests, collectible cards, saves, animation flow and developer tools.
## XDG_DATA_HOME=/tmp/lerion-cards godot --headless --fixed-fps 60 --script tools/check_cards.gd
const Scene := preload("res://scenes/board.tscn")
const Save := preload("res://scripts/board/board_save.gd")
const Legacy := preload("res://scripts/crystal/progress.gd")
const Crystal := preload("res://scripts/crystal/super_crystal_service.gd")
const Cards := preload("res://scripts/economy/card_service.gd")
const Profile := preload("res://scripts/developer/dev_profile.gd")
const ChestScreen := preload("res://scripts/crystal/chest_screen.gd")
const WheelScreen := preload("res://scripts/crystal/wheel_screen.gd")
var prefix := "user://cards_check_%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()]
var failures := 0
var checks := 0


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


func _hashes(p: String) -> Array:
	var out := []
	for slot in range(2):
		var path := "%s_board_v3.%d.json" % [p,slot]
		out.append(FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "")
	return out


func catalog() -> void:
	var cards := Cards.catalog()
	check(cards.size() == 36,"36 de cărți")
	var ids := {}
	var per_collection := {}
	var per_rarity := {}
	for item: Dictionary in cards:
		check(not ids.has(item.id),"Identificator unic " + str(item.id))
		ids[item.id] = true
		check(str(item.id).begins_with("c") and str(item.id).length() == 5,"Format stabil al identificatorului")
		check(not str(item.name).is_empty() and not Cards.collection(str(item.collection)).is_empty() and not Cards.rarity(str(item.rarity)).is_empty(),"Nume, colecție, raritate: " + str(item.id))
		check(item.art.status == "placeholder" and ChestScreen.CardView.ICONS.has(item.art.icon),"Referință grafică provizorie marcată: " + str(item.id))
		per_collection[item.collection] = int(per_collection.get(item.collection,0)) + 1
		per_rarity[item.rarity] = int(per_rarity.get(item.rarity,0)) + 1
	check(Cards.collections().size() == 6,"6 colecții")
	for col: Dictionary in Cards.collections():
		check(per_collection.get(col.id,0) == 6 and Cards.cards_in_collection(col.id).size() == 6,"Colecția %s are 6 cărți" % col.id)
	check(per_rarity == {"common":18,"uncommon":12,"rare":6},"Raritățile: 18 / 12 / 6")
	# The ids are part of the save format: they must never change silently.
	var joined := PackedStringArray()
	for item: Dictionary in cards:
		joined.append(item.id)
	check(",".join(joined).sha256_text() == ",".join(PackedStringArray(["c1_01","c1_02","c1_03","c1_04","c1_05","c1_06","c2_01","c2_02","c2_03","c2_04","c2_05","c2_06","c3_01","c3_02","c3_03","c3_04","c3_05","c3_06","c4_01","c4_02","c4_03","c4_04","c4_05","c4_06","c5_01","c5_02","c5_03","c5_04","c5_05","c5_06","c6_01","c6_02","c6_03","c6_04","c6_05","c6_06"])).sha256_text(),"Identificatori stabili, în ordine")
	check(Cards.chest_size("wood") == 3 and Cards.chest_size("silver") == 4 and Cards.chest_size("gold") == 5,"3 / 4 / 5 cărți")
	for kind: String in Cards.CHEST_KINDS:
		var total := 0.0
		for item: Dictionary in Cards.rarities():
			total += Cards.rarity_probability(kind,item.id)
		check(is_equal_approx(total,1.0),"Ponderile %s însumează 100%%" % kind)
	check(Cards.rarity_probability("gold","rare") > Cards.rarity_probability("silver","rare") and Cards.rarity_probability("silver","rare") > Cards.rarity_probability("wood","rare"),"Aurul are cele mai bune șanse la rare")
	check(Cards.rarity_probability("wood","common") > 0.7,"Lemnul: predominant comune")
	# The wheel chances stay exactly as before.
	var wheel := {"energy_10":28,"energy_20":18,"energy_30":10,"chest_wood":24,"chest_silver":15,"chest_gold":5}
	for id: String in wheel:
		check(is_equal_approx(Crystal.probability(id),wheel[id]/100.0),"Ruleta neschimbată: " + id)


func draws() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	for kind: String in Cards.CHEST_KINDS:
		var counts := {"common":0,"uncommon":0,"rare":0}
		var openings := 40000
		for i in range(openings):
			var ids := Cards.draw_contents(rng,kind)
			check(ids.size() == Cards.chest_size(kind),"Dimensiunea cufărului") if i < 50 else null
			for id: String in ids:
				counts[Cards.card(id).rarity] += 1
		var drawn := openings*Cards.chest_size(kind)
		for rarity_id: String in counts:
			var observed: float = 100.0*float(counts[rarity_id])/drawn
			var expected: float = Cards.rarity_probability(kind,rarity_id)*100.0
			check(absf(observed - expected) < 0.7,"%s %s: %.2f%% ≈ %.1f%%" % [kind,rarity_id,observed,expected])
	for forced: String in ["common","uncommon","rare"]:
		var ids := Cards.draw_contents(rng,"gold",forced)
		var all := true
		for id: String in ids:
			all = all and Cards.card(id).rarity == forced
		check(all and ids.size() == 5,"Raritate forțată " + forced)
	check(Cards.draw_contents(rng,"wood","inexistent").size() == 3,"Raritate necunoscută: ignorată")
	# Every card can come out of some chest.
	var seen := {}
	for i in range(3000):
		for id: String in Cards.draw_contents(rng,"gold"):
			seen[id] = true
	check(seen.size() == 36,"Toate cele 36 de cărți pot fi extrase")


func transaction() -> void:
	var p := prefix + "_tx"
	var game := Save.new(p)
	check(game.state.version == 7 and game.state.cards == {} and game.state.chests_opened == 0 and game.state.last_open.is_empty(),"Salvare nouă v7, fără cărți")
	check(game.open_chest("wood").is_empty() and game.state.seq == 1 or game.open_chest("wood").is_empty(),"Fără cufăr: refuzat")
	var untouched: Dictionary = game.state.duplicate(true)
	check(game.open_chest("platinum").is_empty() and game.state == untouched,"Tip necunoscut: refuzat")
	game.state.chests = {"wood":2,"silver":1,"gold":1}
	game._commit(game.state.duplicate(true))
	var before: Dictionary = game.state.duplicate(true)
	game.rng.seed = 5
	var receipt := game.open_chest("wood")
	check(not receipt.is_empty() and receipt.cards.size() == 3 and receipt.chest == "wood" and not receipt.presented,"Cufăr de lemn: 3 cărți")
	check(game.state.chests.wood == before.chests.wood - 1 and game.state.chests.silver == before.chests.silver and game.state.chests.gold == before.chests.gold,"Se consumă exact un cufăr")
	check(Cards.total_copies(game.state) == 3 and game.state.chests_opened == 1 and game.state.seq == before.seq + 1,"Cărți și cufăr într-o singură salvare")
	check(game.state.wallet == before.wallet and game.state.energy == before.energy and game.state.levels == before.levels and game.state.board_position_index == before.board_position_index and game.state.crystal_charge == before.crystal_charge,"Restul progresului neatins")
	var seq: int = game.state.seq
	check(game.open_chest("wood").is_empty() and game.state.seq == seq and game.state.chests.wood == 1,"Dublu tap: a doua deschidere refuzată până la confirmare")
	var disk := Save.new(p)
	check(disk.state.cards == game.state.cards and disk.state.chests == game.state.chests and disk.pending_open().id == receipt.id,"Salvat pe disc, deschidere neafișată recuperabilă")
	check(game.acknowledge_open(int(receipt.id)) and not game.acknowledge_open(int(receipt.id)) and not game.acknowledge_open(99),"Confirmare unică, doar pentru id-ul corect")
	check(Save.new(p).pending_open().is_empty() and Save.new(p).state.cards == game.state.cards,"După confirmare cărțile rămân")
	# Duplicates inside one chest and across chests.
	game.state.cards = {}
	game.state.last_open = {}
	var next: Dictionary = game.state.duplicate(true)
	var direct := Cards.open(next,"gold",["c1_01","c1_01","c2_03","c1_01","c6_06"])
	check(direct.new == [true,false,true,false,true] and direct.counts == [1,2,1,3,1] and next.cards.c1_01 == 3,"Duplicate în același cufăr: NOUĂ o singură dată, apoi numărul de exemplare")
	check(Cards.unique_owned(next) == 3 and Cards.total_copies(next) == 5 and Cards.duplicate_copies(next) == 2,"Unice 3, exemplare 5, duplicate 2")
	var invalid: Dictionary = game.state.duplicate(true)
	check(Cards.open(invalid,"wood",["c1_01","nu_exista","c2_01"]).is_empty() and invalid == game.state,"Carte necunoscută: nimic nu se schimbă")
	check(Cards.open(invalid,"wood",["c1_01"]).is_empty(),"Număr greșit de cărți: refuzat")
	# Several chests: the inventory accumulates and survives a reload.
	for kind in ["wood","silver","gold"]:
		game.state.chests[kind] = 1
		game.busy = false
		var opened := game.open_chest(kind)
		check(opened.cards.size() == Cards.chest_size(kind),"Cufăr " + kind)
		game.acknowledge_open(int(opened.id))
	var reloaded := Save.new(p)
	check(reloaded.state.cards == game.state.cards and reloaded.state.chests_opened == 4,"Inventarul se păstrează după repornire")
	var typed := true
	for id: String in reloaded.state.cards:
		typed = typed and typeof(reloaded.state.cards[id]) == TYPE_INT
	check(typed and typeof(reloaded.state.last_open.id) == TYPE_INT and typeof(reloaded.state.last_open.counts[0]) == TYPE_INT,"Valori întregi după încărcare")
	# Validation of bad saves.
	var bad: Dictionary = reloaded.state.duplicate(true)
	bad.cards.c1_01 = 0
	check(not reloaded._valid_board(bad),"Număr de exemplare 0 respins")
	bad = reloaded.state.duplicate(true)
	bad.last_open.chest = "platinum"
	check(not reloaded._valid_board(bad),"Chitanță cu tip invalid respinsă")
	bad = reloaded.state.duplicate(true)
	bad.cards["carte_retrasa"] = 2
	check(reloaded._valid_board(bad),"Carte retrasă din catalog: salvarea rămâne validă")
	_clean(p)


func compatibility() -> void:
	var p := prefix + "_v6"
	var game := Save.new(p)
	var old: Dictionary = game.state.duplicate(true)
	old.version = 6
	for field in ["cards","chests_opened","last_open"]:
		old.erase(field)
	old.chests = {"wood":2,"silver":1,"gold":3}
	old.wallet = {"coins":777,"fragments":9,"build_points":4,"tickets":1,"quest_tokens":2}
	old.levels = [2,1,3,0,2,1]
	old.energy = 130
	old.board_position_index = 19
	old.crystal_charge = 12
	game._commit(old)
	var hashes := _hashes(p)
	var loaded := Save.new(p)
	check(loaded.error.is_empty() and loaded.state.version == 7,"Salvare v6 încărcată")
	check(loaded.state.chests == old.chests and loaded.state.wallet == old.wallet and loaded.state.levels == old.levels and loaded.state.energy == 130 and loaded.state.board_position_index == 19 and loaded.state.crystal_charge == 12,"Progresul și cuferele v6 rămân")
	check(loaded.state.cards == {} and loaded.state.chests_opened == 0 and loaded.state.last_open.is_empty(),"Câmpuri noi neutre")
	check(hashes == _hashes(p),"Încărcarea nu rescrie salvarea v6")
	var receipt := loaded.open_chest("gold")
	check(not receipt.is_empty() and Save.new(p).state.version == 7 and Save.new(p).state.chests.gold == 2,"Prima deschidere scrie v7")
	_clean(p)


func developer_tools() -> void:
	var normal := Save.new(prefix + "_normal")
	normal.state.chests = {"wood":5,"silver":5,"gold":5}
	normal._commit(normal.state.duplicate(true))
	var normal_hash := _hashes(prefix + "_normal")
	var profile := Profile.new()
	check(profile.allowed() and profile.reset_profile(true),"Profil DEBUG separat")
	for kind in ["wood","silver","gold"]:
		check(profile.add_chests(kind,100) and profile.state.chests[kind] == 100,"+100 " + kind)
	check(profile.force_rarity("rare") and not profile.force_rarity("legendar"),"Forțare raritate validată")
	var receipt := profile.open_chest("silver")
	var all_rare := true
	for id: String in receipt.cards:
		all_rare = all_rare and Cards.card(id).rarity == "rare"
	check(all_rare and receipt.cards.size() == 4,"Cufăr de argint cu 4 cărți rare forțate")
	profile.acknowledge_open(int(receipt.id))
	check(profile.force_rarity("") and profile.forced_rarity == "","Rarități aleatorii")
	var kept: Dictionary = profile.state.duplicate(true)
	for entry in [["wood",10],["silver",100],["gold",1000]]:
		var report := profile.simulate_chests(entry[0],entry[1])
		check(report.opened == entry[1] and report.cards_drawn == entry[1]*Cards.chest_size(entry[0]),"Simulare %d × %s" % [entry[1],entry[0]])
		check(report.cards_consistent and report.double_open_refused == report.opened and report.chests_left == 0,"Contabilitate și dublă deschidere refuzată")
		check(report.unique_cards <= 36 and report.unique_cards + report.duplicate_copies == report.total_copies,"Unice + duplicate = exemplare")
		if entry[1] >= 1000:
			for rarity_id: String in report.observed_percent:
				check(absf(float(report.observed_percent[rarity_id]) - float(report.expected_percent[rarity_id])) < 2.0,"Distribuție observată ≈ configurată: " + rarity_id)
			check(report.unique_cards == 36,"1000 de cufere de aur: toate cele 36 de cărți apar")
	var forced := profile.simulate_chests("wood",20,4101,"uncommon")
	check(forced.by_rarity.uncommon == 60 and forced.by_rarity.common == 0 and forced.by_rarity.rare == 0,"Simulare cu raritate forțată")
	check(profile.state == kept and Save.new(prefix + "_normal").state.chests == {"wood":5,"silver":5,"gold":5},"Simulările nu scriu în profil")
	# Save and reopen test on the real DEBUG profile.
	var saved := profile.verify_cards_saved()
	check(saved.identical and saved.unique == saved.unique_disk and saved.copies == saved.copies_disk,"Memorie = disc")
	var again := profile.open_chest("wood")
	check(not again.is_empty() and not profile.verify_cards_saved().pending == false,"Deschidere salvată, neafișată")
	check(profile.verify_cards_saved().identical and Profile.new().state.cards == profile.state.cards,"Redeschiderea profilului păstrează cărțile")
	profile.acknowledge_open(int(again.id))
	check(profile.history_text().contains("open_chest"),"Istoric tranzacții cu deschideri")
	var unique_before := Cards.unique_owned(profile.state)
	check(not profile.reset_part("cards",false) and profile.state.cards.size() == unique_before,"Resetare cu confirmare")
	check(profile.reset_part("cards",true) and profile.state.cards == {} and profile.state.chests_opened == 0 and profile.state.chests.wood > 0,"Resetare selectivă: numai cărțile")
	check(_hashes(prefix + "_normal") == normal_hash,"Salvarea normală neatinsă")
	var fake := Save.new(prefix + "_normal")
	check(not fake.has_method("force_rarity") and not fake.has_method("simulate_chests") and fake._forced_rarity() == "","Funcțiile DEBUG nu există în salvarea normală")
	_clean(prefix + "_normal")


func _start(p: String) -> Node:
	var map := Scene.instantiate()
	map.save_prefix = p
	root.add_child(map)
	current_scene = map
	return map


func _wait(phase: int, map: Node, limit := 12.0) -> bool:
	var waited := 0.0
	while map.chest_screen.phase != phase and waited < limit:
		await process_frame
		waited += 1.0/60.0
	return map.chest_screen.phase == phase


func scene_flow() -> void:
	var p := prefix + "_scene"
	var legacy := Legacy.new(p)
	legacy.debug_grant()
	var map := _start(p)
	await process_frame
	await process_frame
	var game: RefCounted = map.game
	# 1. Win a chest on the wheel, then open it right away.
	var state: Dictionary = game.state.duplicate(true)
	state.crystal_charge = 50
	game._commit(state)
	game.rng.seed = 1
	var wanted := -1
	for attempt in range(5000):
		var probe := RandomNumberGenerator.new()
		probe.seed = attempt
		if Crystal.draw(probe) == "chest_silver":
			wanted = attempt
			break
	check(wanted >= 0,"Seed pentru cufăr de argint")
	game.rng.seed = wanted
	map._refresh()
	map.open_crystal()
	var waited := 0.0
	while map.wheel.phase != WheelScreen.Phase.READY and waited < 5.0:
		await process_frame
		waited += 1.0/60.0
	map.wheel._on_spin()
	var tap := InputEventMouseButton.new()
	tap.pressed = true
	tap.button_index = MOUSE_BUTTON_LEFT
	map.wheel._screen_input(tap)
	check(game.state.last_spin.prize == "chest_silver" and game.state.chests.silver == 1,"Cufăr de argint câștigat la ruletă")
	check(map.wheel.open_now_button.visible,"Buton «Deschide acum» pe premiul de cufăr")
	map.wheel.open_now_button.pressed.emit()
	map.wheel.open_now_button.pressed.emit()
	await create_timer(0.7).timeout
	check(map.chest_screen.is_open() and map.chest_screen.phase == ChestScreen.Phase.READY and map.chest_screen.kind == "silver","Ecranul cufărului se deschide după ruletă")
	check(game.state.last_spin.presented and game.state.chests.silver == 1 and game.state.energy <= 100,"Premiul ruletei confirmat o singură dată")
	map._roll()
	check(not game.busy,"Aruncarea este blocată cât timp cufărul este deschis")
	# 2. Open it: double tap, one opening.
	var before: Dictionary = game.state.duplicate(true)
	var button: Button = map.chest_screen.open_button
	button.pressed.emit()
	button.pressed.emit()
	var receipt: Dictionary = game.state.last_open
	check(game.state.seq == before.seq + 1 and receipt.chest == "silver" and receipt.cards.size() == 4 and game.state.chests.silver == 0,"Dublu tap: un singur cufăr consumat, 4 cărți")
	check(map.chest_screen.phase == ChestScreen.Phase.OPENING and Cards.total_copies(game.state) == 4 and not receipt.presented,"Cărțile sunt salvate înainte de animație")
	# 3. Cards are revealed one by one.
	check(await _wait(ChestScreen.Phase.REVEAL,map),"Cufărul se deschide și cărțile apar")
	check(map.chest_screen.cards.size() == 4 and map.chest_screen.revealed <= 1,"Cărțile încep întoarse")
	var seen_counts := []
	for i in range(40):
		await create_timer(0.1).timeout
		seen_counts.append(map.chest_screen.revealed)
	check(map.chest_screen.phase == ChestScreen.Phase.DONE or map.chest_screen.revealed >= 3,"Cărțile se dezvăluie pe rând")
	var monotonic := true
	for i in range(1,seen_counts.size()):
		monotonic = monotonic and seen_counts[i] >= seen_counts[i-1] and seen_counts[i] - seen_counts[i-1] <= 1
	check(monotonic,"Una câte una")
	check(await _wait(ChestScreen.Phase.DONE,map),"Toate cărțile dezvăluite")
	for i in range(4):
		var view = map.chest_screen.cards[i]
		check(view.face_up and view.card.id == receipt.cards[i],"Cartea %d: fața corectă" % i)
		check(view.badge == ("NOUĂ!" if receipt.new[i] else "×%d" % int(receipt.counts[i])),"Cartea %d: marcaj NOUĂ / exemplare" % i)
	check(map.chest_screen.summary.text == Cards.describe(receipt),"Rezumat")
	# 4. Confirm, return to the game, restart: cards are still there, exactly once.
	var after_open: Dictionary = game.state.duplicate(true)
	map.chest_screen._on_continue()
	map.chest_screen._on_continue()
	check(game.state.last_open.presented and game.state.cards == after_open.cards and game.state.chests == after_open.chests,"Confirmare fără a modifica cărțile")
	await create_timer(0.5).timeout
	check(not map.chest_screen.is_open(),"Revenire la joc")
	map.free()
	map = _start(p)
	await process_frame
	await process_frame
	check(not map.chest_screen.is_open() and map.game.state.cards == after_open.cards and map.game.state.chests.silver == 0,"După repornire cărțile sunt în inventar")
	map.open_cards()
	check(map.cards_screen.is_open(),"Ecranul «Cărțile mele»")
	var owned := 0
	var copies_total := 0
	for grid in map.cards_screen.list.get_children():
		if grid is GridContainer:
			for view in grid.get_children():
				if view.owned:
					owned += 1
	for id: String in map.game.state.cards:
		copies_total += int(map.game.state.cards[id])
	check(owned == Cards.unique_owned(map.game.state) and copies_total == 4,"Inventarul afișează cărțile unice; exemplarele totale = 4")
	map.cards_screen.close()
	# 5. Close the game in the middle of the opening animation.
	var next: Dictionary = map.game.state.duplicate(true)
	next.chests.gold = 1
	map.game._commit(next)
	map._refresh()
	map.open_chest("gold")
	check(map.chest_screen.phase == ChestScreen.Phase.READY,"Cufăr de aur pregătit")
	map.chest_screen.open_button.pressed.emit()
	var confirmed: Dictionary = map.game.state.duplicate(true)
	await create_timer(0.8).timeout
	check(map.chest_screen.phase == ChestScreen.Phase.OPENING or map.chest_screen.phase == ChestScreen.Phase.REVEAL,"Animație în curs")
	map.free()
	map = _start(p)
	await process_frame
	await process_frame
	await process_frame
	check(map.chest_screen.is_open() and map.chest_screen.phase == ChestScreen.Phase.DONE and map.chest_screen.cards.size() == 5,"La redeschidere se afișează cele 5 cărți confirmate")
	check(map.game.state.cards == confirmed.cards and map.game.state.chests == confirmed.chests and map.game.state.wallet == confirmed.wallet and map.game.state.levels == confirmed.levels and map.game.state.board_position_index == confirmed.board_position_index,"Fără pierdere, fără dublare, restul neatins")
	map.chest_screen._on_continue()
	check(map.game.pending_open().is_empty() and map.game.state.cards == confirmed.cards,"Confirmare după repornire")
	map.free()
	map = _start(p)
	await process_frame
	await process_frame
	check(not map.chest_screen.is_open() and map.game.state.cards == confirmed.cards,"A doua repornire: nimic de afișat")
	# 6. Skip and speed.
	next = map.game.state.duplicate(true)
	next.chests.wood = 2
	map.game._commit(next)
	map._refresh()
	map.open_chest("wood")
	map.chest_screen.open_button.pressed.emit()
	map.chest_screen._on_speed()
	check(map.chest_screen.speed == ChestScreen.FAST,"Accelerare")
	await create_timer(0.3).timeout
	map.chest_screen._on_skip()
	check(map.chest_screen.phase == ChestScreen.Phase.DONE and map.chest_screen.revealed == 3,"Omitere: toate cărțile afișate imediat")
	var skipped: Dictionary = map.game.state.last_open
	for i in range(3):
		check(map.chest_screen.cards[i].face_up and map.chest_screen.cards[i].card.id == skipped.cards[i],"Carte afișată după omitere")
	check(not skipped.presented and Cards.total_copies(map.game.state) >= 3,"Omiterea nu schimbă cărțile salvate")
	map.chest_screen._on_continue()
	await create_timer(0.4).timeout
	# Tap-to-reveal.
	map.open_chest("wood")
	map.chest_screen.open_button.pressed.emit()
	check(await _wait(ChestScreen.Phase.REVEAL,map),"Al doilea cufăr: apar cărțile")
	var before_tap: int = map.chest_screen.revealed
	map.chest_screen._screen_input(tap)
	check(map.chest_screen.revealed == before_tap + 1,"Atingerea dezvăluie următoarea carte")
	map.chest_screen._on_skip()
	map.chest_screen._on_continue()
	await create_timer(0.4).timeout
	map.free()
	_clean(p)
	for slot in range(2):
		DirAccess.remove_absolute(legacy._path(slot))


func panel_flow() -> void:
	var map := _start(Profile.PREFIX)
	await process_frame
	await process_frame
	var panel = map.get_node("DeveloperPanel")
	var profile: Profile = map.game
	profile.reset_profile(true)
	map.sync_map() if false else null
	panel.sync_map()
	check(panel.card_status.text.contains("0/36"),"Panou: starea cărților")
	panel.test_card_save()
	check(panel.chest_report.text.contains("Memorie = disc: true") and panel.chest_report.text.contains("refuzată: true"),"Test salvare și redeschidere din panou")
	panel.test_card_recovery()
	await process_frame
	await process_frame
	await process_frame
	await process_frame
	var restarted: Node = current_scene
	check(restarted != map and restarted.chest_screen.is_open() and restarted.chest_screen.phase == ChestScreen.Phase.DONE and restarted.chest_screen.cards.size() == 4,"Test restart: cărțile confirmate reapar")
	var copies: int = Cards.total_copies(restarted.game.state)
	restarted.chest_screen._on_continue()
	check(Cards.total_copies(restarted.game.state) == copies and restarted.game.pending_open().is_empty(),"Test restart: fără dublare")
	var restarted_panel = restarted.get_node("DeveloperPanel")
	restarted_panel.refresh_data()
	check(restarted_panel.card_status.text.contains("exemplare înainte") and restarted_panel.card_status.text.contains("(așteptat +4)"),"Panoul compară înainte/după")
	restarted_panel.chest_report.text = ""
	restarted_panel.sim_kind.select(2)
	restarted.game.simulate_chests("gold",10)
	restarted.free()


func _run() -> void:
	catalog()
	draws()
	transaction()
	compatibility()
	developer_tools()
	await scene_flow()
	await panel_flow()
	print("Cufere și cărți: %d verificări, %d erori." % [checks,failures])
	quit(1 if failures else 0)
