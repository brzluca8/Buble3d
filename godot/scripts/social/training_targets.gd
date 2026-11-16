class_name TrainingTargets
extends TargetsRepository
## Ținte de antrenament (fără backend). Nu sunt jucători reali și sunt etichetate vizibil.
## Starea lor (niveluri, scuturi) se păstrează în salvare și se reface când rămân fără clădiri.


func label() -> String:
	return str(Game.D.targets.get("label", "Țintă de antrenament – nu este un jucător real"))


func pick_target() -> Dictionary:
	var ts: Array = Game.D.targets.get("targets", [])
	var t: Dictionary = ts[randi() % ts.size()]
	var st: Dictionary = Game.training.get(str(int(t.id)), {"levels": _city(), "shields": 0})
	return {"id": int(t.id), "name": t.name, "levels": st.levels, "shields": int(st.shields), "training": true, "label": label()}


func _city() -> Dictionary:
	var out := {}
	for b in Game.BUILDINGS:
		out[b.id] = randi_range(2, 5)
	return out


func hit(id: int, building: String) -> Dictionary:
	var st: Dictionary = Game.training.get(str(id), {"levels": {}, "shields": 0})
	var blocked := int(st.shields) > 0
	if blocked:
		st.shields = int(st.shields) - 1          # scutul țintei se consumă
	else:
		st.levels[building] = maxi(0, int(st.levels.get(building, 1)) - 1)
		var total := 0
		for v in st.levels.values():
			total += int(v)
		if total <= 3:
			# ținta de antrenament se reconstruiește și primește un scut nou
			for b in Game.BUILDINGS:
				st.levels[b.id] = randi_range(2, 5)
			st.shields = randi_range(0, 2)
	Game.training[str(id)] = st
	Game.save_game()
	return {"blocked": blocked, "levels": st.levels.duplicate()}
