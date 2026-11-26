extends SceneTree

const Progress := preload("res://scripts/crystal/progress.gd")
const Rewards := preload("res://scripts/crystal/rewards.gd")
var checks := 0
var failures := 0
var rng := RandomNumberGenerator.new()
var engine := Rewards.new()
var prefix := "user://crystal_test_%s_%s" % [OS.get_process_id(), Time.get_ticks_usec()]


func check(ok: bool, name: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(name)


func _initialize() -> void:
	rng.seed = 7246
	check(engine.valid(), "Config V2")
	_distribution()
	_combinations()
	_transactions()
	print("Cristal: %d verificări, %d erori." % [checks,failures])
	for i in range(2):
		DirAccess.remove_absolute("%s.%d.json" % [prefix,i])
	quit(1 if failures else 0)


func _distribution() -> void:
	var counts := {}
	var total := {"coins":0,"build_points":0}
	var first_paid := 0
	for i in range(100000):
		var keys := []
		for j in range(3):
			var key := engine.roll_symbol(rng)
			keys.append(key)
			counts[key] = int(counts.get(key,0)) + 1
		var result := engine.resolve(keys,rng,false)
		for k: String in total:
			total[k] += int(result.reward.get(k,0))
		if first_paid == 0 and total.coins >= 1000 and total.build_points >= 10:
			first_paid = i + 1
	for key: String in Rewards.KEYS:
		var percent := float(counts[key]) / 3000
		check(absf(percent - float(engine.symbols[key].weight_percent)) < 0.5, "Distribuție " + key)
	print("100000 activări / 300000 simboluri: ",counts,". Prima construcție din recompense, fără sold inițial: ",first_paid)
	var invalid := Rewards.new()
	invalid.symbols = invalid.symbols.duplicate(true)
	invalid.symbols.coin.weight_percent += 1
	check(not invalid.valid(), "Suma ponderilor incorectă")


func _combinations() -> void:
	# Replay the individual base draws, then independently account for exactly one bonus.
	for key: String in Rewards.KEYS:
		for pair in [false,true]:
			var keys := [key,key,"hammer" if key != "hammer" else "coin"] if pair else [key,key,key]
			var twin := RandomNumberGenerator.new()
			twin.state = rng.state
			var expected := {}
			for k: String in keys:
				add(expected, engine.base(k,twin))
			if pair:
				add(expected,engine.base(key,twin))
			else:
				match key:
					"coin": add(expected,{"coins":500})
					"hammer": add(expected,{"build_points":5})
					"crystal": add(expected,{"fragments":12})
					"challenge": add(expected,{"tickets":5})
					"chest": add(expected,{"coins":twin.randi_range(250,600)})
					"chaos": add(expected,engine.config.combos.triples.chaos.reward_choices[twin.randi_range(0,1)])
			var result := engine.resolve(keys,rng,false)
			check(result.reward == expected and result.combo == ("pair" if pair else "triple"), "Combo " + str(keys))
	for a: String in ["coin","hammer","chest"]:
		for b: String in ["coin","hammer","chest"]:
			if b == a:
				continue
			var rest := ["coin","hammer","chest"]
			rest.erase(a)
			rest.erase(b)
			var r := engine.resolve([a,b,rest[0]],rng,false)
			check(r.combo == "mixed" and r.reward.coins >= 300 and r.reward.coins <= 400 and r.reward.build_points == 3, "Mixt " + a + b)
	var ordinary := engine.resolve(["coin","challenge","crystal"],rng,false)
	check(ordinary.combo == "" and ordinary.reward == {"coins":50,"tickets":1,"fragments":2}, "Premii independente")
	var special := engine.resolve(["coin","challenge","crystal"],rng,true)
	check(special.reward.tickets == 1 and special.reward.fragments == 2 and special.reward.coins >= 200 and special.reward.coins <= 300, "Super selectiv și cufăr")
	var bonus := engine.resolve(["hammer","hammer","hammer"],rng,true)
	check(bonus.reward.build_points == 16 and bonus.reward.coins >= 100 and bonus.reward.coins <= 200, "Super după bonus, un singur cufăr")


func add(total: Dictionary, delta: Dictionary) -> void:
	for key: String in delta:
		total[key] = int(total.get(key,0)) + int(delta[key])


func _transactions() -> void:
	var start := 100000
	var g := Progress.new(prefix,start)
	g.rng.seed = 294
	check(not g.arm(), "Armare prematură")
	for i in range(29):
		g.activate(start)
		g.busy = false
	check(g.state.charge == 29 and g.state.energy == 71, "29 obișnuite")
	var result := g.activate(start)
	check(not result.is_empty() and g.activate(start).is_empty() and not g.arm(), "Blocare dublu tap")
	var restarted := Progress.new(prefix,start)
	check(restarted.state.energy == 70 and restarted.state.charge == 30 and restarted.state.last.symbols == result.symbols and restarted.state.wallet.coins == g.state.wallet.coins, "Restart în timpul efectului")
	restarted.activate(start)
	restarted.busy = false
	check(restarted.state.charge == 30 and restarted.arm() and not restarted.arm(), "Alegerea Super")
	g = Progress.new(prefix,start)
	check(g.state.armed and g.activate(start).super and g.state.charge == 0 and not g.state.armed, "Armare salvată și consumată")
	g.busy = false
	g.activate(start)
	g.busy = false
	check(g.state.charge == 1, "Reîncărcare Super")
	while g.state.energy > 0:
		g.activate(start)
		g.busy = false
	var seq := int(g.state.seq)
	check(g.activate(start).is_empty() and g.state.seq == seq, "Energie zero")
	g = Progress.new(prefix,start+299)
	check(g.state.energy == 0, "Sub cinci minute")
	g.regenerate(start+601)
	check(g.state.energy == 2 and g.state.tick == start+600, "Recuperare offline cu rest")
	g.regenerate(start+100)
	check(g.state.energy == 2, "Ceas mutat înapoi")
	g.regenerate(start+100000)
	check(g.state.energy == 100, "Plafon regenerare")
	g.activate(start+100400)
	g.busy = false
	g.regenerate(start+100401)
	check(g.state.energy == 99, "Fără acumulare la energie maximă")
	g.state.wallet.coins = 1000
	g.state.wallet.build_points = 9
	check(not g.upgrade(2,0) and g.state.wallet.coins == 1000, "Cost parțial refuzat")
	for slot in range(6):
		g.debug_grant()
		var before: Dictionary = g.state.wallet.duplicate()
		for lvl in range(3):
			check(g.upgrade(slot,lvl) and not g.upgrade(slot,lvl), "Nivel unic %d/%d" % [slot,lvl])
		check(not g.upgrade(slot,3) and g.state.wallet.coins == before.coins - 12000 and g.state.wallet.build_points == before.build_points - 80, "Cost total")
	g = Progress.new(prefix,start)
	check(g.state.levels == [3,3,3,3,3,3], "Șase clădiri după restart")
	var good_seq := int(g.state.seq)
	var file := FileAccess.open("%s.%d.json" % [prefix,good_seq % 2], FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	g = Progress.new(prefix,start)
	check(g.state.seq == good_seq - 1 and g.state.levels[5] == 2, "Recuperare generație anterioară")
	var write_failure := Progress.new(prefix+"/absent/progress",start)
	check(write_failure.activate(start).is_empty() and write_failure.state.energy == 100 and write_failure.state.seq == 0 and not write_failure.busy, "Scriere eșuată fără debit")
