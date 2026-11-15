extends SceneTree
## Simulare de echilibrare: joacă automat (×1, alegeri aleatoare la atac / jaf, cumpără cel mai
## ieftin upgrade) și măsoară câte aruncări trebuie pentru fiecare insulă.
##   godot --headless --path godot -s res://tests/economy_sim.gd -- [insule] [rulări]

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var islands := int(args[0]) if args.size() > 0 else 6
	var runs := int(args[1]) if args.size() > 1 else 20
	await process_frame
	var g = root.get_node("Game")
	var totals := []
	totals.resize(islands)
	totals.fill(0.0)
	var coins_per_roll := []
	coins_per_roll.resize(islands)
	coins_per_roll.fill(0.0)
	var cards_total := 0.0
	var blast_tiles := 0.0
	for run in runs:
		seed(1000 + run)
		g.island = 1
		g.coins = 0
		g.levels = {"palat": 1, "obs": 1, "turn": 1, "mag": 1, "sera": 1}
		g.cards = {}
		g.event_pts = 0
		g.event_step = 0
		g.pos = 0
		g.mult = 1
		for isl in islands:
			var rolls := 0
			var earned := 0.0
			while g.island == isl + 1 and rolls < 5000:
				g.energy = 10
				var before: float = g.coins
				var r: Dictionary = g.roll()
				rolls += 1
				match r.kind:
					"attack":
						var opts := []
						for k in g.rival:
							if g.rival[k] > 0:
								opts.append(k)
						g.attack(opts[randi() % opts.size()])
					"raid":
						g.start_raid()
						var picks := [0, 1, 2, 3, 4, 5, 6, 7, 8]
						picks.shuffle()
						for i in 3:
							g.raid_pick(picks[i])
					"blast":
						blast_tiles += 1
						g.coins += g.blast_estimate()
					_:
						g.resolve_tile(r.kind)
				earned += g.coins - before
				# cumpără cel mai ieftin upgrade posibil
				var bought := true
				while bought and g.island == isl + 1:
					bought = false
					var best := ""
					for k in g.levels:
						if g.levels[k] < g.MAX_LVL and (best == "" or g.cost(k) < g.cost(best)):
							best = k
					if best != "" and g.coins >= g.cost(best):
						g.upgrade(best)
						bought = true
			totals[isl] += rolls
			coins_per_roll[isl] += earned / maxf(rolls, 1)
		cards_total += g.cards.values().reduce(func(a, b): return a + b, 0)
	print("\n=== ECONOMIE (medie pe %d rulări, multiplicator ×1) ===" % runs)
	print("insula | aruncări | monede/aruncare | cost total insulă | zile (200 aruncări/zi)")
	for i in islands:
		g.island = i + 1
		g.levels = {"palat": 1, "obs": 1, "turn": 1, "mag": 1, "sera": 1}
		var cost := 0
		for k in g.levels:
			for l in range(1, g.MAX_LVL):
				g.levels[k] = l
				cost += g.cost(k)
		var r: float = totals[i] / runs
		print("  %d    |  %6.0f  |     %6.0f       |    %8d       |   %.1f" % [i + 1, r, coins_per_roll[i] / runs, cost, r / 200.0])
	print("cărți strânse în medie: %.0f   căsuțe Buble Blast: %.0f / rulare" % [cards_total / runs, blast_tiles / runs])
	quit()
