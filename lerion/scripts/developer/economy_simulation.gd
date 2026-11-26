extends RefCounted
const Profile := preload("res://scripts/developer/dev_profile.gd")
var cancelled := false

func run(source: Dictionary, count: int, tree: SceneTree, seed_value := 2801) -> Dictionary:
	if not OS.is_debug_build() or count not in [100,1000,10000]:
		return {}
	var current := Profile.new(true)
	var baseline := Profile.new(true)
	current.state = source.duplicate(true)
	baseline.state = source.duplicate(true)
	baseline.state.levels.fill(0)
	current.rng.seed = seed_value
	baseline.rng.seed = seed_value
	var report := {"seed":seed_value,"requested":count,"completed":0,"categories":{},
		"rewards":{},"baseline_rewards":{},"energy_spent":0,"energy_won":0,
		"energy_supplied":0,"baseline_energy_supplied":0,"start_passes":0,"start_coins":0,
		"levels":source.levels.duplicate()}
	# Refill only at zero so energy-cap behaviour stays part of the experiment.
	for i in range(count):
		if cancelled:
			break
		for model in [current,baseline]:
			model.busy = false
			if model.state.energy < 1:
				var field := "energy_supplied" if model == current else "baseline_energy_supplied"
				report[field] += 100
				model.set_resource("energy",100)
			var receipt: Dictionary = model.roll(int(source.tick))
			if receipt.is_empty():
				return {"error":model.error}
			var key := "rewards" if model == current else "baseline_rewards"
			var award: Dictionary = receipt.landing
			if not award.is_empty():
				report[key][award.resource] = int(report[key].get(award.resource,0))+int(award.amount)
			if model == current:
				var kind: String = model.ECONOMY.kind(model.state.board_position_index,36)
				report.categories[kind] = int(report.categories.get(kind,0))+1
				report.energy_spent += 1
				if award.get("resource") == "energy":
					report.energy_won += int(award.amount)
				report.start_coins += int(receipt.start_coins)
				report.start_passes += int(receipt.start_coins > 0)
		report.completed += 1
		if i%50 == 49 and tree != null:
			await tree.process_frame
	report.cancelled = cancelled
	return report
