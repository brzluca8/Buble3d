extends SceneTree
const BOARD := preload("res://scenes/board.tscn")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func verify(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _run() -> void:
	var map := BOARD.instantiate()
	map.save_prefix = "user://presentation_test_%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()]
	root.add_child(map)
	await process_frame
	var home: Transform3D = map.camera.transform
	var state: Dictionary = map.game.state.duplicate(true)
	for size_px in [Vector2i(720,1280),Vector2i(720,1600),Vector2i(768,1024)]:
		root.size = size_px
		await process_frame
		for tile in range(36):
			var point: Vector3 = map.path.at_step(tile)
			map.camera.track_path(point,map.path.at_step(tile+3.7))
			map.camera._process(2.0)
			var visible_route := true
			var rect: Rect2 = map.hud.map_window()
			for lead in range(5):
				visible_route = visible_route and rect.has_point(map.camera.unproject_position(map.path.at_step(tile+lead)))
			verify(visible_route,"Lerik și patru dale în cadru: %d / %s" % [tile,size_px])
			verify(map.camera.global_position.distance_to(point) < 20.0,"Cadru apropiat în mers")
	map.camera.frame_landing(map.path.at_step(35),true)
	for i in range(120):
		map.camera._process(1.0/60.0)
	verify(map.camera.transform.is_equal_approx(home),"Revenire la perspectiva inițială")
	map.dice.play(Vector2i(6,1),map.camera,map.hud.map_window())
	map.camera.frame_throw(map.dice.global_position)
	map.camera._process(1.0)
	map.dice._roll(0.54)
	verify(map.dice.impacts.visible,"Impact pe iarbă")
	map.dice._roll(1.0)
	for die in map.dice.faces:
		var normal: Vector3 = die.basis * die.NORMALS[die.value-1]
		var eye: Vector3 = die.global_position.direction_to(map.camera.global_position)
		for side: Vector3 in die.NORMALS:
			verify(normal.dot(eye)+0.0001 >= (die.basis*side).dot(eye),"Fața citită după apropierea camerei")
	verify(map.game.state == state,"Regia nu scrie în tranzacție")
	map.body.idle(0.4)
	var earlier: Transform3D = map.body.head.transform
	map.body.idle(2.16)
	verify(not map.body.head.transform.is_equal_approx(earlier),"Capul urmărește respirația în repaus")
	var flyers: int = map.hud.flights.get_child_count()
	map.hud.fly_prize("energy",map.pawn.position,map.camera,100,false,0)
	verify(map.hud.flights.get_child_count() == flyers,"Soldul plafonat nu lansează un simbol fictiv")
	map.hud.fly_prize("coins",map.pawn.position,map.camera,125,true,125)
	var burst = map.hud.flights.get_child(-1)
	verify(burst.rare and burst.shape == "coins","Coroana de monede pentru un câștig mare")
	verify(map.game.state == state,"Reacția de bucurie și efectele nu acordă resurse")
	var ambient = map.get_node("Ambient")
	ambient._drift_embers()
	verify(ambient.embers.visible_instance_count == 4,"Luminile laboratorului așteaptă construcția")
	map.village.set_level(3,1)
	ambient._drift_embers()
	verify(ambient.embers.visible_instance_count == 8,"Pufuri de magie lângă laboratorul construit")
	for part in ["Borduri","Felinare"]:
		verify(map.get_node("BorduriDeSat").find_child(part,true,false) != null,"Decor importat: "+part)
	var prefs = map.hud.prefs
	prefs.path = map.save_prefix+"_settings.cfg"
	map.hud.music_toggle.button_pressed = false
	verify(not prefs.music and prefs.sfx,"Muzica și efectele sunt independente")
	map.hud.reduced_toggle.button_pressed = true
	verify(map.dice.reduced and map.camera.reduced,"Setarea efectelor ajunge în scenă")
	var loaded = prefs.get_script().new()
	loaded.path = prefs.path
	loaded.read()
	verify(not loaded.music and loaded.sfx and loaded.reduced,"Preferințele persistă separat")
	verify(map.sounds.MUSIC.loop_mode == AudioStreamWAV.LOOP_FORWARD,"Bucla instrumentală se repetă")
	map.hud.fx_toggle.button_pressed = false
	verify(not map.sounds.effects_enabled,"Oprirea efectelor sonore")
	verify(map.game.state == state,"Setările nu ating salvarea")
	for tier in range(3):
		map.hud.quality_menu.item_selected.emit(tier)
		verify(prefs.quality == tier and Engine.max_fps == (30 if tier == 0 else 60),"Profil și limită de cadre")
		verify(map.get_node("Soare").shadow_enabled == (tier > 0),"Bugetul umbrelor")
		loaded.read()
		verify(loaded.quality == tier,"Profil memorat")
	verify(map.game.state == state,"Profilurile grafice protejează progresul")
	map.hud.reduced_toggle.button_pressed = false
	map.camera.manual_override = false
	map.sounds.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	verify(map.sounds.suspended,"Suspendare audio")
	map.sounds.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	verify(not map.sounds.suspended and not map.sounds.effects_enabled,"Reluare cu preferințele păstrate")
	check_sightlines(map)
	DirAccess.remove_absolute(prefs.path)
	var prefix: String = map.save_prefix
	map.free()
	for i in range(2):
		DirAccess.remove_absolute(prefix+"_board_v3.%d.json" % i)
	print("Premium: %d verificări, %d erori." % [checks,failures])
	quit(1 if failures else 0)

func check_sightlines(map: Node) -> void:
	for i in range(6):
		map.village.set_level(i,3)
	var occluders := []
	for branch in ["Sat","Parcele","Castel","Fantana","Gradina","BorduriDeSat","Vegetatie"]:
		for obj: MeshInstance3D in map.get_node(branch).find_children("*","MeshInstance3D",true,false):
			if obj.is_visible_in_tree():
				occluders.append([obj.global_transform.affine_inverse(),obj.get_aabb(),obj.mesh.generate_triangle_mesh()])
	var safe: Rect2 = map.hud.map_window()
	for origin in range(36):
		map.camera.return_home()
		map.camera._process(2)
		map.camera.frame_throw(map.dice.LANES[0])
		map.camera._process(map.dice.ROLL_TIME)
		var in_frame := true
		var clear := true
		for tick in range(61):
			var step := origin+0.2*tick
			var foot: Vector3 = map.path.at_step(step)
			map.camera.track_path(foot,map.path.at_step(step+3.7))
			map.camera._process(2.5/60.0)
			var face := foot+Vector3.UP*1.31
			in_frame = in_frame and safe.has_point(map.camera.unproject_position(face))
			for mesh in occluders:
				var start: Vector3 = mesh[0]*map.camera.global_position
				var end: Vector3 = mesh[0]*face
				if mesh[1].intersects_segment(start,end) != null and not mesh[2].intersect_segment(start,end).is_empty():
					clear = false
		verify(in_frame,"Lerik încadrat în mișcare de pe "+str(origin))
		verify(clear,"Vizibilitate până la fața lui Lerik de pe "+str(origin))
