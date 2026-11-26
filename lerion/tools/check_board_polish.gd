extends SceneTree
const BOARD := preload("res://scenes/board.tscn")
const Dice := preload("res://scripts/board/die_face.gd")
const Legacy := preload("res://scripts/crystal/progress.gd")
const Save := preload("res://scripts/board/board_save.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		push_error(description)
		failures += 1


func check_framing(map: Node) -> void:
	var initial_size := root.size
	var distance: float = map.camera.distance
	var focus: Vector3 = map.camera.focus
	for pixels in [Vector2i(720,1280),Vector2i(720,1600),Vector2i(768,1024)]:
		root.size = pixels
		await process_frame
		for zoom in [15.0,30.8,34.0]:
			for x in [-3.2,0.0,3.2]:
				for z in [-4.2,1.1,3.5]:
					map.camera.distance = zoom
					map.camera.focus = Vector3(x,0,z)
					map.camera._update_pose()
					var safe: Rect2 = map.hud.map_window()
					map.dice.play(Vector2i(4,3),map.camera,safe)
					var framed := true
					var clearance := INF
					for tick in range(11):
						map.dice._roll(tick/10.0)
						for die in map.dice.faces:
							for corner in range(8):
								var local := Vector3(-0.5 if corner&1 else 0.5,-0.5 if corner&2 else 0.5,-0.5 if corner&4 else 0.5)
								var p: Vector3 = die.to_global(local)
								framed = framed and safe.has_point(map.camera.unproject_position(p))
								p.y = 0.0
								var nearest: Vector3 = map.path.curve.get_closest_point(p)
								clearance = minf(clearance,p.distance_to(nearest))
					check(framed,"Zaruri vizibile la zoom și pan " + str(map.camera.focus))
					check(clearance > map.path.HALF_WIDTH,"Zaruri în afara drumului " + str(map.camera.focus))
	map.dice.cancel()
	root.size = initial_size
	map.camera.distance = distance
	map.camera.focus = focus
	map.camera._update_pose()
	await process_frame


func _run() -> void:
	var prefix := "user://polish_%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()]
	var legacy := Legacy.new(prefix)
	legacy.debug_grant()
	legacy.upgrade(1,0)
	var map := BOARD.instantiate()
	map.save_prefix = prefix
	root.add_child(map)
	await process_frame
	await check_framing(map)
	var before: Dictionary = map.game.state.duplicate(true)
	for a in range(1,7):
		for b in range(1,7):
			map.dice.play(Vector2i(a,b),map.camera,map.hud.map_window())
			map.dice._roll(0.34)
			for die in map.dice.faces:
				check(die.position.y > die.origin.y+0.65 and die.position.z > die.origin.z,"Salt și deplasare pe teren")
			map.dice._roll(1.0)
			for die: Dice in map.dice.faces:
				var visible_face := 0
				var nearest := -INF
				var eye := die.global_position.direction_to(map.camera.global_position)
				for i in range(6):
					var alignment: float = (die.basis * Dice.NORMALS[i]).dot(eye)
					if alignment > nearest:
						nearest = alignment
						visible_face = i+1
				check(visible_face == die.value and absf(die.position.y-die.origin.y-Dice.WIDTH*0.5)<0.001,"Fața fizică finală pe sol")
	map.dice.cancel()
	check(map.game.state == before,"Cele 36 de animații nu scriu progres")
	var blades: Node3D = map.village.accents[1]
	var angle := blades.rotation.z
	await create_timer(0.25).timeout
	check(not is_equal_approx(blades.rotation.z,angle),"Moară de nivel 1 în mișcare")
	check(map.get_node("Ambient").flags.size() == 3,"Cele trei steaguri au pivoți")
	# Force a known destination through the normal dice service using a test seed.
	var fixture: Dictionary = map.game.state.duplicate(true)
	fixture.board_position_index = 25
	map.game._commit(fixture)
	var rng := RandomNumberGenerator.new()
	for candidate in range(1024):
		rng.seed = candidate
		var pair := Vector2i(rng.randi_range(1,6),rng.randi_range(1,6))
		if pair.x + pair.y == 7:
			map.game.rng.seed = candidate
			break
	map._roll()
	check(map.hud.coins.text == str(fixture.wallet.coins) and map.game.state.wallet.coins == fixture.wallet.coins+100,"Soldul este confirmat înaintea dezvăluirii")
	var roll: Dictionary = map.game.state.duplicate(true)
	map._roll()
	map.hud.skip.pressed.emit()
	check(map.game.state == roll and map.visual_tile == roll.board_position_index,"Grăbește și dublu tap în timpul zarurilor")
	check(map.hud.coins.text == str(roll.wallet.coins),"Sold dezvăluit la aterizare")
	check(not map.dice.visible,"Zarurile se retrag la Grăbește")
	await create_timer(1.6).timeout
	check(map.hud.flights.get_child_count() == 0 and map.path.lit_tiles.is_empty(),"Efectele tranzitorii se eliberează")
	check(map.body.scale.is_equal_approx(map.rest_scale) and is_zero_approx(map.camera.v_offset),"Pionul și camera revin la repaus")
	check(Save.new(prefix).state == roll,"Efectele de aterizare nu modifică salvarea")
	map._select_at(map.camera.unproject_position(map.plots.get_child(4).position+Vector3.UP*0.3))
	map._upgrade(4,0)
	check(map.path.lit_tiles == PackedInt32Array([1,7,13,19,26,32]),"Construcție pe toate dalele cu monede")
	var purchase: Dictionary = map.game.state.duplicate(true)
	map._upgrade(4,0)
	check(map.game.state == purchase and map.find_children("*","CPUParticles3D",true,false).size() == 1,"Un singur șantier la confirmare")
	await create_timer(1.65).timeout
	check(map.find_children("*","CPUParticles3D",true,false).is_empty() and map.game.state == purchase,"Șantierul dispare fără să modifice progresul")
	map._deselect()
	map._roll()
	var in_flight: Dictionary = map.game.state.duplicate(true)
	check(map.hud.throwing and map.dice.visible and map.walked_steps == 0,"Zarurile preced mersul")
	await create_timer(map.dice.ROLL_TIME+0.38).timeout
	check(not map.hud.throwing and map.game.busy and map.walked_steps > 0,"Lerik înaintează după stabilire")
	map.free()
	map = BOARD.instantiate()
	map.save_prefix = prefix
	root.add_child(map)
	check(map.game.state == in_flight and not map.dice.visible and map.visual_tile == in_flight.board_position_index,"Restart în timpul mersului")
	map._roll()
	var suspended: Dictionary = map.game.state.duplicate(true)
	map.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	map.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	check(not map.dice.visible and not map.game.busy and map.game.state == suspended,"Reluare în timpul aruncării")
	map.free()
	for i in range(2):
		DirAccess.remove_absolute(legacy._path(i))
		DirAccess.remove_absolute(prefix+"_board_v3.%d.json" % i)
	print("Prezentare: %d verificări, %d erori." % [checks,failures])
	quit(1 if failures else 0)
