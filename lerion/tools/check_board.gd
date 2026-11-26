extends SceneTree
const Scene := preload("res://scenes/board.tscn")
const Legacy := preload("res://scripts/crystal/progress.gd")
const Save := preload("res://scripts/board/board_save.gd")
const Dice := preload("res://scripts/board/dice_roll.gd")
const RULES := preload("res://assets/board/rules.tres")
var prefix := "user://board_check_%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()]
var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		push_error(description)
		failures += 1


func _start():
	var map := Scene.instantiate()
	map.save_prefix = prefix
	root.add_child(map)
	current_scene = map
	return map


func _flat(p: Vector3) -> Vector2:
	return Vector2(p.x,p.z)


func _geometry(map: Node) -> void:
	var path = map.path
	check(path.centers.size() == 36 and map.plots.get_child_count() == 6, "36 căsuțe, 6 parcele")
	var first: Vector3 = path.curve.sample_baked(0)
	var end: Vector3 = path.curve.sample_baked(path.length_m)
	check(path.curve.closed and first.distance_to(end) < 0.001 and path.at_step(35.999).distance_to(path.at_step(0.0)) < 0.003, "Închidere reală")
	var pts := PackedVector2Array()
	var nearest := PackedFloat32Array([999,999,999,999,999,999])
	var crystal_gap := INF
	var north := INF
	var sample_count := 720
	for i in range(sample_count):
		var pt := _flat(path.at_step(36.0*i/sample_count))
		pts.append(pt)
		for plot: Node3D in map.plots.get_children():
			var idx := plot.get_index()
			nearest[idx] = minf(nearest[idx],pt.distance_to(_flat(plot.global_position))-path.HALF_WIDTH-1.60)
		crystal_gap = minf(crystal_gap,pt.length()-path.HALF_WIDTH-1.61)
		north = minf(north,pt.y-path.HALF_WIDTH)
	var castle: MeshInstance3D = map.get_node("Castel").find_children("*","MeshInstance3D",true,false)[0]
	var bounds := castle.global_transform * castle.get_aabb()
	check(north > bounds.end.z and crystal_gap > 0.1, "Drumul este liber lângă castel și fântână")
	for gap: float in nearest:
		check(gap > 0.10 and gap < 1.8,"Traseul trece lângă platformă cu spațiu liber")
	print("Spațiu minim drum–platformă: %.3f m; fântână: %.3f m; castel: %.3f m." % [Array(nearest).min(),crystal_gap,north-bounds.end.z])
	var simple := true
	var wide_enough := true
	# Also check clearance of the whole paved width between non-neighbouring arcs.
	for i in range(sample_count):
		var a := pts[i]
		var b := pts[(i+1)%sample_count]
		for j in range(i+2,sample_count):
			var apart := mini(j-i,sample_count-(j-i))
			if apart < 2:
				continue
			if Geometry2D.segment_intersects_segment(a,b,pts[j],pts[(j+1)%sample_count]) != null:
				simple = false
			if apart > 38 and a.distance_to(pts[j]) < 2*path.HALF_WIDTH:
				wide_enough = false
	check(simple and wide_enough,"Fără intersecții sau suprapuneri de carosabil")
	for i in range(36):
		var d: float = path.centers[i].distance_to(path.centers[(i+1)%36])
		check(d > path.stride*0.84 and d <= path.stride*1.01,"Vecinătate fizică %d" % i)
	check(not map.get_node("Pajiste/Alei").visible, "Ramurile radiale sunt ascunse")
	path.toggle_indices()
	check(path.index_labels.visible and path.index_labels.get_child_count() == 36,"Indici 0–35 în debug")
	path.toggle_indices()
	for resolution in [Vector2i(720,1280),Vector2i(720,1600),Vector2i(768,1024)]:
		root.size = resolution
		await process_frame
		var rect := root.get_visible_rect()
		for center: Vector3 in path.centers:
			var p: Vector2 = map.camera.unproject_position(center)
			check(rect.has_point(p) and not map.hud.blocks_map(p),"Traseul încape în " + str(resolution))
		for plot: Node3D in map.plots.get_children():
			for sign_x: float in [-1.0,1.0]:
				check(rect.has_point(map.camera.unproject_position(plot.position + Vector3.RIGHT*sign_x*1.60)), "Platformă în cadru")
		for i in range(6):
			map._select_at(map.camera.unproject_position(map.plots.get_child(i).position+Vector3.UP*0.3))
			check(map.selected_plot == i,"Selectare " + str(i))
		map._deselect()


func _dice() -> void:
	var distribution := PackedInt32Array()
	distribution.resize(13)
	for origin in range(36):
		for a in range(1,7):
			for b in range(1,7):
				var steps := Dice.walk(origin,Vector2i(a,b),36)
				var contiguous := steps.size() == a+b
				for i in range(steps.size()):
					contiguous = contiguous and steps[i] == (origin+i+1)%36
				check(contiguous and steps.count(0) == int(origin+a+b >= 36),"Mers consecutiv și START")
				if origin == 0:
					distribution[a+b] += 1
	check(distribution.slice(2) == PackedInt32Array([1,2,3,4,5,6,5,4,3,2,1]),"Distribuție teoretică")
	var rng := RandomNumberGenerator.new()
	rng.seed = 4321
	var counts := PackedInt32Array()
	counts.resize(36)
	for i in range(100000):
		var faces := Dice.draw(rng)
		counts[(faces.x-1)*6+faces.y-1] += 1
	check(Array(counts).min() > 2500 and Array(counts).max() < 3050,"100.000 aruncări, 36 perechi independente")
	print("100000 aruncări, perechea cea mai rară/frecventă: ",Array(counts).min(),"/",Array(counts).max())


func _tap(control: Control) -> void:
	for pressed in [true,false]:
		var touch := InputEventScreenTouch.new()
		touch.pressed = pressed
		touch.position = root.get_final_transform() * control.get_global_rect().get_center()
		Input.parse_input_event(touch)
		Input.flush_buffered_events()
		await process_frame


func _run() -> void:
	_dice()
	var now := int(Time.get_unix_time_from_system())
	var v2 := Legacy.new(prefix,now)
	for i in range(6):
		v2.debug_grant()
		for k in range(i%4):
			v2.upgrade(i,k)
	v2.activate(now)
	v2.busy = false
	var backup := []
	for i in range(2):
		backup.append(FileAccess.get_sha256(v2._path(i)))
	var map = _start()
	map.game.rng.seed = 5990
	await process_frame
	await process_frame
	var migrated_wallet: Dictionary = v2.state.wallet.duplicate()
	migrated_wallet.quest_tokens = 0
	check(map.game.state.wallet == migrated_wallet and map.game.state.levels == v2.state.levels and map.game.state.energy == v2.state.energy,"Migrare solduri și niveluri V2")
	check(map.game.state.mode == "board_v3" and map.visual_tile == 0 and map.game.state.crystal_charge == 0,"START separat de V2")
	await _geometry(map)
	var snapshot: Dictionary = map.game.state.duplicate(true)
	await process_frame
	await _tap(map.hud.roll_button)
	map._roll()
	check(map.game.busy and map.game.state.seq == snapshot.seq+1 and map.game.state.energy == snapshot.energy-1,"Touch real simulat, un singur debit la dublu tap")
	var roll: Dictionary = map.game.state.last_roll
	var sum := int(roll.a)+int(roll.b)
	check(map.dice.faces[0].value == roll.a and map.dice.faces[1].value == roll.b,"Fețe HUD = rezultat salvat")
	var duration := RULES.duration(sum)
	await create_timer(map.dice.ROLL_TIME+duration+0.20).timeout
	check(not map.game.busy and map.walked_steps == sum and map.visual_tile == sum,"Toți pașii animați")
	check(_flat(map.pawn.position).distance_to(_flat(map.path.at_step(sum))) < 0.001,"Poziție fizică de aterizare")
	# Exercise actual wrapping moves and reload without injecting a roll into the UI.
	var wrap_seen := false
	for i in range(20):
		var origin := int(map.game.state.board_position_index)
		var old_laps := int(map.game.state.laps)
		map._roll()
		roll = map.game.state.last_roll
		var wrapped := origin+int(roll.a)+int(roll.b) >= 36
		if wrapped:
			await create_timer(map.dice.ROLL_TIME+RULES.duration(int(roll.a)+int(roll.b))+0.20).timeout
			check(map.walked_steps == int(roll.a)+int(roll.b) and map.visual_tile == map.game.state.board_position_index,"35→0 animat")
			wrap_seen = true
		map._finish()
		check(map.game.state.laps == old_laps+int(wrapped),"Tur numărat o dată")
		if wrap_seen: break
	check(wrap_seen,"Traversare START în scenă")
	map._roll()
	var committed: Dictionary = map.game.state.duplicate(true)
	map.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	map.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	check(not map.game.busy and map.game.state == committed,"Reluare fără a doua aruncare")
	map._roll()
	committed = map.game.state.duplicate(true)
	map.free()
	map = _start()
	await process_frame
	check(map.game.state.energy == committed.energy and map.game.state.seq == committed.seq and map.visual_tile == committed.board_position_index, "Restart în mers")
	check(map.game.state.wallet == committed.wallet and map.game.state.levels == snapshot.levels and map.game.state.crystal_charge == committed.crystal_charge,"Restart păstrează premiul confirmat, nivelurile și încărcarea cristalului")
	map._select_at(map.camera.unproject_position(map.plots.get_child(2).position+Vector3.UP*0.4))
	var initial_level := int(map.game.state.levels[2])
	var initial_coins := int(map.game.state.wallet.coins)
	map._upgrade(2,initial_level)
	var reloaded := Save.new(prefix,now)
	check(reloaded.state.levels[2] == initial_level+1 and map.village.levels[2] == initial_level+1 and reloaded.state.wallet.coins == initial_coins-8000, "Îmbunătățire V3 și persistență")
	var rollback := Legacy.new(prefix,now,true)
	check(rollback.state.levels == v2.state.levels and rollback.state.wallet == v2.state.wallet,"Rollback V2")
	for i in range(2):
		check(FileAccess.get_sha256(v2._path(i)) == backup[i],"Fișier V2 intact")
	var game: RefCounted = map.game
	game.state.energy = 0
	game.state.tick = now
	var stamp := int(game.state.seq)
	check(game.roll(now+299).is_empty() and game.state.seq == stamp,"Energie zero")
	check(not game.roll(now+300).is_empty() and game.state.energy == (game.state.last_roll.landing.amount if game.state.last_roll.landing.get("resource") == "energy" else 0),"Regenerare și aruncare")
	map.free()
	for i in range(2):
		DirAccess.remove_absolute(game._path(i))
		DirAccess.remove_absolute(v2._path(i))
	print("V3: %d verificări, %d erori." % [checks,failures])
	quit(1 if failures else 0)
