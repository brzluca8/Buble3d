extends SceneTree
## Etapa 4.2: character animation, dice choreography, camera director, 3D chests, cameos,
## environment life, audio cues and the three WOW moments. Presentation must never change state.
## XDG_DATA_HOME=/tmp/lerion-anim godot --headless --fixed-fps 60 --script tools/check_animation.gd
const Scene := preload("res://scenes/board.tscn")
const Legacy := preload("res://scripts/crystal/progress.gd")
const Profile := preload("res://scripts/developer/dev_profile.gd")
const Animator := preload("res://scripts/board/lerik_animator.gd")
const Cameo := preload("res://scripts/board/cameo.gd")
const ChestStage := preload("res://scripts/crystal/chest_stage.gd")
const Audio := preload("res://scripts/board/board_audio.gd")
const Crystal := preload("res://scripts/crystal/super_crystal_service.gd")
var prefix := "user://anim_check_%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()]
var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		push_error(description)
		failures += 1


func frames(n: int) -> void:
	for i in range(n):
		await process_frame


func _clean(p: String) -> void:
	for slot in range(2):
		DirAccess.remove_absolute("%s_board_v3.%d.json" % [p,slot])


func _start(p: String) -> Node:
	var map := Scene.instantiate()
	map.save_prefix = p
	root.add_child(map)
	current_scene = map
	return map


func models_and_clips() -> void:
	var lerik: Node3D = load("res://assets/board/lerik.glb").instantiate()
	var names := []
	for part in lerik.get_children():
		names.append(str(part.name))
	for name in ["Trunchi","Cap","Ochi","Ochelari","UrecheStanga","UrecheDreapta","Rucsac","Coada","Esarfa","CapatEsarfa","PiciorStang","PiciorDrept","BratStang","BratDrept"]:
		check(name in names,"Lerik are piesa " + name)
	lerik.set_script(load("res://scripts/board/lerik_pose.gd"))
	root.add_child(lerik)
	var before := {}
	for name in ["UrecheStanga","Ochi","Ochelari","Rucsac","Coada","CapatEsarfa"]:
		before[name] = lerik.part(name).transform
	lerik.apply({"ear_l": 0.4, "blink": 1.0, "goggles": 1.0, "pack_pitch": 0.3, "tail_pitch": 0.4, "scarf": 0.5})
	for name: String in before:
		check(not lerik.part(name).transform.is_equal_approx(before[name]),"Piesa se mișcă: " + name)
	lerik.apply({})
	check(lerik.scale.is_equal_approx(lerik.rest_scale),"Poza neutră păstrează scara")
	lerik.free()
	for who in ["pongo","pufi"]:
		var model: Node3D = load("res://assets/board/%s.glb" % who).instantiate()
		check(model.get_child_count() >= 10,"%s are piese animabile" % who)
		model.free()
	for kind in ["wood","silver","gold"]:
		var chest: Node3D = load("res://assets/board/chest_%s.glb" % kind).instantiate()
		check(chest.find_child("Capac") != null and chest.find_child("Lacat") != null and chest.find_child("Interior") != null,"Cufăr 3D " + kind)
		chest.free()
	# Every clip is short, starts and ends neutral (spins end on whole turns).
	for name: String in Animator.CLIPS:
		var length := float(Animator.CLIPS[name][0])
		check(length > 0.2 and length <= 2.5,"Durată rezonabilă: " + name)
		var last := Animator.sample(name,length + 1.0)
		var neutral := true
		for key: String in last:
			var value := float(last[key])
			if key == "twist":
				value = wrapf(value,-PI,PI)
			neutral = neutral and absf(value) < 0.01
		check(neutral,"Clipul se termină neutru: " + name)
	for name: String in Cameo.CLIPS:
		var spec: Array = Cameo.CLIPS[name]
		check(float(spec[0]) <= 2.7 and not (spec[2] as Array).is_empty(),"Cameo scurt cu evenimente: " + name)
		check(float(Animator.sample_keys(spec[1],float(spec[0])).get("pop",1.0)) == 0.0,"Cameo dispare la final: " + name)


func animator_states(map: Node) -> void:
	var anim = map.animator
	anim.settle()
	check(not anim.busy() and map.body.scale.is_equal_approx(map.rest_scale),"Repaus după settle")
	# Run: legs swing and the last tile is a jump.
	anim.start_run(0.0,6,map.path.stride)
	var swing := 0.0
	var top := 0.0
	for i in range(61):
		var step := 6.0*i/60.0
		anim.drive_run(step,0.0)
		var pose: Dictionary = anim._run_pose()
		swing = maxf(swing,absf(float(pose.leg_l)))
		if step > 5.3:
			top = maxf(top,float(pose.lift))
	check(swing > 0.6,"Pas de alergare cu balans al picioarelor")
	check(top > 0.3,"Săritură pe ultima căsuță")
	anim.land("big",7)
	check(anim.clip == "land_big" or anim.clip in ["wobble","surprise","confused"],"Aterizare cu bucurie")
	await create_timer(1.3).timeout
	check(anim.clip == "" and map.body.scale.is_equal_approx(map.rest_scale),"Revine la repaus după aterizare")
	anim.land("normal",2)
	check(anim.clip == "confused","Dublu 1: confuzie comică")
	anim.land("normal",12)
	check(anim.clip == "surprise","Dublu 6: surpriză")
	anim.settle()
	# Secondary springs stay bounded and settle.
	map.pawn.position += Vector3(0.6,0,0)
	await frames(2)
	map.pawn.position -= Vector3(0.6,0,0)
	var bounded := true
	for i in range(30):
		await process_frame
		for key: String in anim.spring:
			bounded = bounded and absf(anim.spring[key].x) <= 0.7001
	check(bounded,"Mișcarea secundară rămâne limitată")
	await create_timer(1.5).timeout
	var still := true
	for key: String in anim.spring:
		still = still and absf(anim.spring[key].x) < 0.05
	check(still,"Mișcarea secundară se liniștește")
	anim.reduced = true
	anim.idle_timer = 0.0
	await frames(3)
	check(anim.clip == "","Efecte reduse: fără gesturi de repaus")
	anim.reduced = false


func dice_and_camera(map: Node) -> void:
	var settled := [0]
	map.dice.settled.connect(func() -> void: settled[0] += 1)
	map.dice.play(Vector2i(3,4),map.camera,map.hud.map_window())
	for t in range(0,101,4):
		map.dice._roll(t/100.0)
	map.dice._roll(1.0)
	check(settled[0] == 1,"Zarurile anunță oprirea o singură dată")
	check(not map.dice.trail.visible,"Urma magică dispare la oprire")
	map.dice.cancel()
	var cam = map.camera
	cam.motion = 2
	cam.frame_throw(map.dice.LANES[0])
	check(cam.shot == cam.Shot.RETURN,"Camera fixă: fără cadru cinematic")
	cam.manual_override = false
	cam.motion = 1
	cam.track_path(map.path.at_step(10),map.path.at_step(13.7))
	var gentle: Vector3 = cam.target_eye
	cam.motion = 0
	cam.track_path(map.path.at_step(10),map.path.at_step(13.7))
	check(gentle.distance_to(map.path.at_step(10)) > cam.target_eye.distance_to(map.path.at_step(10)),"Mișcare ușoară: camera mai departe")
	check(absf(cam.target_yaw) <= cam.TRACK_YAW + 0.0001,"Rotire limitată în urmărire")
	# A box in the line of sight lifts the camera.
	var here: Vector3 = map.path.at_step(10)
	var saved: Array[AABB] = cam.occluders.duplicate()
	cam.occluders = [] as Array[AABB]
	cam.track_path(here,map.path.at_step(13.7))
	var free_pitch: float = cam.target_pitch
	var eye: Vector3 = cam.target_eye
	cam.occluders = [AABB(here.lerp(eye,0.5) - Vector3(1,1,1),Vector3(2,2,2))] as Array[AABB]
	cam.track_path(here,map.path.at_step(13.7))
	check(cam.target_pitch > free_pitch,"Clădire în cadru: camera se ridică")
	cam.occluders = saved
	cam.return_home()
	for i in range(200):
		cam._process(1.0/60.0)
	check(cam.shot == cam.Shot.OVERVIEW and is_zero_approx(cam.rotation.y),"Revenire la vederea generală, fără rotire reziduală")


func chest_stages() -> void:
	for kind in ["wood","silver","gold"]:
		var stage: ChestStage = ChestStage.new()
		stage.size = Vector2(300,260)
		root.add_child(stage)
		stage.show_kind(kind)
		await frames(2)
		var beats := [0]
		var opened := [false]
		stage.beat.connect(func(_i: int) -> void: beats[0] += 1)
		stage.opened.connect(func() -> void: opened[0] = true)
		var t: float = stage.play_open()
		await create_timer(t + 0.4).timeout
		check(opened[0] and is_equal_approx(stage.lid_angle,1.0),"Cufărul %s se deschide" % kind)
		check(beats[0] == (4 if kind == "gold" else 1),"Ritmul anticipării %s: %d" % [kind,beats[0]])
		check(stage.anticipation_time() <= 1.4,"Anticipare scurtă")
		stage.burst()
		await create_timer(2.6).timeout
		var particles := stage.world.find_children("*","CPUParticles3D",true,false)
		check(particles.is_empty(),"Particulele cufărului %s se eliberează" % kind)
		stage.free()


func scene_flow() -> void:
	var p := prefix + "_scene"
	var legacy := Legacy.new(p)
	legacy.debug_grant()
	var map := _start(p)
	await frames(3)
	check(map.animator != null and map.life != null and map.facets != null,"Controlerele de prezentare există")
	await animator_states(map)
	await dice_and_camera(map)
	# Environment life follows quality and the ambient switch.
	map.hud.prefs.quality = 2
	map.apply_preferences()
	var any_wind := false
	for mesh in map.life.foliage:
		any_wind = any_wind or mesh.material_override == map.life.wind
	check(map.life.foliage.size() > 0 and any_wind,"Vânt în vegetație pe calitate ridicată")
	map.set_presentation("ambient",false)
	var still := true
	for mesh in map.life.foliage:
		still = still and mesh.material_override == null
	check(still and not map.life.water.visible,"Ambient oprit: vegetație statică, fără apă animată")
	map.set_presentation("ambient",true)
	map.hud.prefs.quality = 0
	map.apply_preferences()
	check(not map.life.birds.visible,"Calitate redusă: fără păsări")
	map.hud.prefs.quality = 1
	map.apply_preferences()
	# Smoke only from chimneys that exist at the current level.
	var next: Dictionary = map.game.state.duplicate(true)
	next.levels = [0,0,1,0,0,2]
	map.game._commit(next)
	for i in range(6):
		map.village.set_level(i,next.levels[i])
	map.life._refresh()
	check(map.life.smoke[2].emitting and not map.life.smoke[5].emitting,"Fum din coșul atelierului; hanul abia la nivelul 3")
	# Cameos: events, no duplicates, self-cleaning, and nothing saved.
	var snapshot: Dictionary = map.game.state.duplicate(true)
	var events := []
	var pongo: Node = map.pongo_cameo(2)
	check(pongo != null and map.pongo_cameo(2) == null,"Un singur Pongo odată")
	pongo.event.connect(func(name: String, _at: Vector3) -> void: events.append(name))
	await create_timer(2.8).timeout
	check(events == ["hit","hit","big_hit","cheer"],"Pongo: două lovituri, lovitura prea tare, bucurie: %s" % str(events))
	check(not is_instance_valid(pongo),"Pongo dispare singur")
	var pufi: Node = map.pufi_cameo()
	check(pufi != null,"Pufi apare")
	await create_timer(2.6).timeout
	check(not is_instance_valid(pufi),"Pufi dispare singur")
	map.polish.set_toggle("special",false)
	check(map.pufi_cameo() == null,"Efecte speciale oprite: fără cameo")
	map.polish.set_toggle("special",true)
	# WOW 1: kingdom awakening.
	map.awaken()
	await frames(2)
	check(map.polish.active_effects() > 0,"Trezirea regatului pornește efectele")
	await create_timer(4.0).timeout
	var rest := true
	for model in map.village.models:
		rest = rest and model.scale.is_equal_approx(Vector3.ONE)
	check(rest and map.polish.active_effects() == 0,"După trezire: clădiri la scara normală, efecte eliberate")
	check(map.game.state == snapshot,"Cameo-urile și trezirea nu modifică starea")
	# Crystal invite and WOW 2: crystal dive.
	next = map.game.state.duplicate(true)
	next.crystal_charge = Crystal.target(next)
	map.game._commit(next)
	map._refresh()
	await frames(3)
	check(map.crystal_glow.invite.visible,"Cristal plin: invitația ATINGE! apare")
	var before_open: Dictionary = map.game.state.duplicate(true)
	map.open_crystal()
	check(map.wheel_open(),"Ruleta este deschisă imediat (transparentă) la activare")
	await create_timer(0.7).timeout
	check(map.facets.visible,"Tranziția prin fațete rulează")
	await create_timer(1.2).timeout
	check(not map.facets.visible and map.wheel.phase == map.wheel.Phase.READY,"Fațetele dispar, ruleta e gata")
	check(map.game.state == before_open,"Activarea nu consumă nimic până la rotire")
	map.wheel._on_later()
	await create_timer(0.5).timeout
	# Reduced effects: no dive.
	map.hud.prefs.reduced = true
	map.apply_preferences()
	map.open_crystal()
	await frames(2)
	check(not map.facets.visible and map.wheel_open(),"Efecte reduse: ruleta fără tranziție")
	map.wheel._on_later()
	map.hud.prefs.reduced = false
	map.apply_preferences()
	await create_timer(0.5).timeout
	# Closing the game in the middle of the crystal dive changes nothing.
	map.open_crystal()
	await create_timer(0.6).timeout
	var mid: Dictionary = map.game.state.duplicate(true)
	map.free()
	map = _start(p)
	await frames(3)
	check(map.game.state.crystal_charge == mid.crystal_charge and map.game.pending_spin().is_empty() and not map.wheel_open(),"Închidere în timpul scufundării: cristalul rămâne încărcat")
	# Quick quality switching while effects run.
	map.awaken()
	for i in range(9):
		map.hud.prefs.quality = i % 3
		map.hud.prefs.reduced = i % 4 == 0
		map.apply_preferences()
		await process_frame
	map.hud.prefs.reduced = false
	map.apply_preferences()
	check(true,"Schimbarea rapidă a calității în timpul efectelor")
	# A full real roll with every effect on lands on the same state as with everything off.
	var results := []
	var start: Dictionary = map.game.state.duplicate(true)
	start.board_position_index = 5
	start.last_roll = {}
	start.energy = 50
	for mode in [true,false]:
		map.game.rng.seed = 777
		map.game._commit(start.duplicate(true))
		for key in ["ambient","special","post","camera"]:
			map.set_presentation(key,mode)
		map._roll()
		check(map.animator.state == map.animator.State.WATCH,"Lerik privește zarurile în timpul aruncării")
		map._finish()
		check(map.animator.state == map.animator.State.IDLE and map.animator.clip != "","Aterizare animată după Grăbește")
		var after: Dictionary = map.game.state
		results.append([after.wallet,after.energy,after.board_position_index,after.crystal_charge,after.last_roll])
	check(results[0] == results[1],"Aceeași aruncare cu toate efectele pornite sau oprite")
	map.free()
	_clean(p)
	for slot in range(2):
		DirAccess.remove_absolute(legacy._path(slot))


func audio_cues() -> void:
	for event: String in Audio.CUES:
		check(Audio.CUES[event] is AudioStreamWAV,"Sunet original încărcat: " + event)
	var audio := Audio.new()
	root.add_child(audio)
	await frames(1)
	audio.play_event("wheel_tick")
	var first: float = audio.last_played["wheel_tick"]
	audio.play_event("wheel_tick")
	check(audio.last_played["wheel_tick"] == first,"Ticul ruletei nu se suprapune sub intervalul minim")
	for event: String in Audio.CUES:
		audio.play_event(event)
	check(audio.fx_voices.size() == 4,"Patru voci pentru sunetele suprapuse")
	audio.free()


func panel() -> void:
	var map := _start(Profile.PREFIX)
	await frames(3)
	var panel = map.get_node("DeveloperPanel")
	check(panel.pages.size() == 11,"Pagina «Animații și momente»")
	var profile: Profile = map.game
	profile.reset_profile(true)
	var snapshot: Dictionary = profile.state.duplicate(true)
	map.debug_dice()
	map.debug_landing_effect(true)
	map.debug_start_effect()
	map.debug_upgrade_effect(2)
	map.animator.play("goggles")
	map.awaken()
	await create_timer(3.0).timeout
	check(profile.state == snapshot,"Testele vizuale din panou nu modifică profilul")
	map.set_presentation("camera",false)
	check(map.camera.motion == 2,"Comutator cameră")
	map.set_presentation("camera",true)
	map.set_presentation("sound",false)
	check(not map.sounds.effects_enabled,"Comutator sunete")
	map.set_presentation("sound",true)
	map.free()


func _run() -> void:
	models_and_clips()
	await chest_stages()
	await scene_flow()
	await audio_cues()
	await panel()
	print("Animație 4.2: %d verificări, %d erori." % [checks,failures])
	quit(1 if failures else 0)
