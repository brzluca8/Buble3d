extends SceneTree
## Etapa 4.0: visual polish. Effects must be budgeted, switchable, freed after use and must never change
## the game state. XDG_DATA_HOME=/tmp/lerion-vis godot --headless --fixed-fps 60 --script tools/check_visual.gd
const Scene := preload("res://scenes/board.tscn")
const Legacy := preload("res://scripts/crystal/progress.gd")
const Polish := preload("res://scripts/board/polish.gd")
const Crystal := preload("res://scripts/crystal/super_crystal_service.gd")
const ChestArt := preload("res://scripts/crystal/chest_art.gd")
const ResultArt := preload("res://scripts/crystal/result_art.gd")
const Audio := preload("res://scripts/board/board_audio.gd")
const Profile := preload("res://scripts/developer/dev_profile.gd")
const ECONOMY := preload("res://assets/board/economy.tres")
var prefix := "user://vis_check_%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()]
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


func _start(p: String) -> Node:
	var map := Scene.instantiate()
	map.save_prefix = p
	root.add_child(map)
	current_scene = map
	return map


func _fields(game: RefCounted) -> Dictionary:
	var s: Dictionary = game.state
	return {"wallet":s.wallet,"energy":s.energy,"pos":s.board_position_index,"laps":s.laps,"roll":s.last_roll,"charge":s.crystal_charge,"levels":s.levels}


func static_checks() -> void:
	for kind in ["coin","crystal","construction","magic","quest"]:
		check(Loop.CATEGORY_TINT.has(kind),"Culoare de categorie pentru " + kind)
	var used := {}
	for tile in range(1,36):
		used[ECONOMY.kind(tile,36)] = true
	for kind: String in used:
		check(Loop.CATEGORY_TINT.has(kind),"Fiecare tip de căsuță are culoare: " + kind)
	var colors := {}
	for kind: String in Loop.CATEGORY_TINT:
		colors[Loop.CATEGORY_TINT[kind]] = true
	check(colors.size() == Loop.CATEGORY_TINT.size(),"Culorile categoriilor sunt distincte")
	var bases := {}
	for kind in ["wood","silver","gold"]:
		bases[str(ChestArt.PALETTE[kind].base)] = true
	check(bases.size() == 3,"Cele trei cufere au culori distincte")
	# Budgets grow with the tier and stay small enough for phones.
	for key: String in ["fireflies","dust","leaves","sparkles","glints","puffs","burst","rings"]:
		check(Polish.TIERS[0][key] <= Polish.TIERS[1][key] and Polish.TIERS[1][key] <= Polish.TIERS[2][key],"Buget crescător: " + key)
	var total := 0
	for key: String in ["fireflies","dust","leaves","sparkles","glints"]:
		total += int(Polish.TIERS[2][key])
	check(total <= 64 and Polish.TIERS[2].burst <= 24 and Polish.TIERS[2].rings <= 4,"Bugete maxime: %d particule ambientale" % total)
	check(not Polish.TIERS[0].glow and Polish.TIERS[1].glow and Polish.TIERS[2].glow,"Bloom doar pe calitate medie și ridicată")
	for event in Audio.EVENTS:
		check(str(Audio.EVENTS[event]) in ["click","toss","land","gem","coin","magic","upgrade"],"Fallback sonor valid pentru " + event)
	check(Audio.EVENTS.size() >= 15,"Structură pregătită pentru sunete: %d evenimente" % Audio.EVENTS.size())
	var wheel := {"energy_10":28,"energy_20":18,"energy_30":10,"chest_wood":24,"chest_silver":15,"chest_gold":5}
	for id: String in wheel:
		check(is_equal_approx(Crystal.probability(id),wheel[id]/100.0),"Ruleta neschimbată: " + id)


const Loop := preload("res://scripts/board/loop_path.gd")


func chest_art_draws() -> void:
	var views := []
	for kind in ["wood","silver","gold"]:
		var view := ResultArt.new()
		view.size = Vector2(170,150)
		root.add_child(view)
		view.show_chest(kind)
		views.append(view)
	var energy := ResultArt.new()
	energy.size = Vector2(150,150)
	root.add_child(energy)
	energy.show_texture(preload("res://assets/crystal/energy.svg"),Color("#fff59a"))
	await process_frame
	await process_frame
	check(views[0].chest_kind == "wood" and views[2].chest_kind == "gold" and energy.texture != null and energy.chest_kind == "","Pictograme de rezultat: cufere și energie")
	for view in views:
		view.free()
	energy.free()


func scene_checks() -> void:
	var p := prefix + "_scene"
	var legacy := Legacy.new(p)
	legacy.debug_grant()
	var map := _start(p)
	await process_frame
	await process_frame
	var polish: Polish = map.polish
	check(polish != null and polish.get_parent() == map,"Nodul Polish există")
	var env: Environment = map.get_node("Lumina").environment
	# Colour grade and bloom follow quality, reduced effects and the debug switch.
	polish.configure(1,false)
	check(env.adjustment_enabled and env.glow_enabled and env.tonemap_mode == Environment.TONE_MAPPER_LINEAR,"Calitate medie: grad de culoare și bloom")
	polish.configure(0,false)
	check(env.adjustment_enabled and not env.glow_enabled,"Calitate redusă: fără bloom")
	polish.configure(2,false)
	check(env.glow_enabled,"Calitate ridicată: bloom")
	polish.set_toggle("post",false)
	check(not env.glow_enabled and not env.adjustment_enabled,"Comutator bloom/post oprit")
	polish.set_toggle("post",true)
	polish.configure(2,true)
	check(not env.glow_enabled and not polish.ambient_active() and not polish.special_active(),"Efecte reduse: fără bloom, ambient și speciale")
	# Particle budgets per tier.
	polish.configure(0,false)
	for key: String in ["fireflies","dust","leaves","sparkles","glints"]:
		check(polish.motes[key].multimesh.visible_instance_count == Polish.TIERS[0][key],"Buget %s redus" % key)
	polish.configure(2,false)
	for key: String in ["fireflies","dust","leaves","sparkles","glints"]:
		check(polish.motes[key].multimesh.visible_instance_count == Polish.TIERS[2][key] and polish.motes[key].visible,"Buget %s ridicat" % key)
	map.hud.prefs.quality = 2
	map.apply_preferences()
	check(map.get_node("Ambient").jets == 8 and polish.tier == 2,"Mai multe jeturi la fântână pe calitate ridicată")
	map.hud.prefs.quality = 0
	map.apply_preferences()
	check(map.get_node("Ambient").jets == 4 and polish.tier == 0,"Mai puține jeturi pe calitate redusă")
	map.hud.prefs.quality = 1
	map.apply_preferences()
	check(polish.tier == 1,"Calitatea se propagă din setări")
	# Switches.
	polish.set_toggle("ambient",false)
	var any_visible := false
	for key: String in polish.motes:
		any_visible = any_visible or polish.motes[key].visible
	check(not any_visible and not polish.start_beacon.visible,"Efecte ambientale oprite")
	polish.set_toggle("ambient",true)
	check(polish.motes.fireflies.visible and polish.start_beacon.visible,"Efecte ambientale pornite")
	polish.set_toggle("special",false)
	polish.ring_burst(Vector3.ZERO,Color.WHITE)
	polish.landing(Vector3.ZERO,Color.WHITE,true)
	polish.emote(Vector3.ZERO,"coins")
	check(polish.active_effects() == 0,"Efecte speciale oprite: nimic nu se creează")
	polish.set_toggle("special",true)
	# Effects are capped and freed.
	for i in range(12):
		polish.ring_burst(Vector3(i,0,0),Color.WHITE)
	var rings := 0
	for node in polish.fx_root.get_children():
		rings += int(node is MeshInstance3D)
	check(rings <= int(polish.budget().rings),"Inele limitate la buget: %d" % rings)
	polish.landing(Vector3.ZERO,Color.WHITE,true)
	polish.start_burst(Vector3.ZERO)
	polish.upgrade_burst(Vector3.ZERO)
	polish.crystal_burst()
	polish.emote(Vector3.ZERO,"coins")
	var particles := 0
	for node in polish.fx_root.get_children():
		if node is CPUParticles3D:
			particles += 1
			check(node.amount <= int(polish.budget().burst) and node.one_shot,"Particule scurte și limitate")
	check(particles > 0 and polish.active_effects() > 0,"Efectele speciale creează particule")
	await create_timer(2.2).timeout
	check(polish.active_effects() == 0 and polish.live_rings == 0,"Toate efectele se eliberează singure")
	# Crystal pulse decays.
	map.crystal_glow.pulse_now(1.0)
	check(map.crystal_glow.pulse > 0.9,"Puls de cristal pornit")
	await create_timer(0.7).timeout
	check(map.crystal_glow.pulse <= 0.01,"Pulsul scade singur")
	# HUD counters.
	var hud = map.hud
	await create_timer(0.8).timeout
	check(hud.coins.scale.is_equal_approx(Vector2.ONE) and hud.flights.get_child_count() == 0,"Contoare în repaus la început")
	var next: Dictionary = map.game.state.duplicate(true)
	next.wallet.coins += 250
	map.game._commit(next)
	map._refresh()
	await process_frame
	await process_frame
	check(hud.coins.scale.x > 1.0 and hud.flights.get_child_count() > 0,"Monedele pulsează și apare +N când cresc")
	await create_timer(1.2).timeout
	check(hud.coins.scale.is_equal_approx(Vector2.ONE) and hud.flights.get_child_count() == 0,"Contorul revine, efectele se eliberează")
	next = map.game.state.duplicate(true)
	next.wallet.coins -= 100
	map.game._commit(next)
	map._refresh()
	await process_frame
	check(hud.coins.scale.is_equal_approx(Vector2.ONE),"Scăderea monedelor nu pulsează ca un câștig")
	next = map.game.state.duplicate(true)
	next.energy -= 1
	map.game._commit(next)
	map._refresh()
	await create_timer(0.05).timeout
	check(hud.energy.scale.x < 1.0,"Energia cheltuită face o mică scufundare")
	await create_timer(0.4).timeout
	# Roll button.
	check(not hud.roll_button.disabled and hud.roll_fx != null and hud.roll_fx.is_valid(),"Butonul ARUNCĂ: lumină animată când este gata")
	check(hud.roll_button.get_theme_stylebox("normal").shadow_size > 0 and hud.roll_button.get_theme_stylebox("focus") != null,"ARUNCĂ: umbră, stare focus")
	hud.roll_button.button_down.emit()
	await create_timer(0.1).timeout
	check(hud.roll_button.scale.x < 1.0,"Apăsare: scufundare")
	hud.roll_button.button_up.emit()
	await create_timer(0.5).timeout
	check(hud.roll_button.scale.is_equal_approx(Vector2.ONE),"Eliberare: revenire")
	check(hud.crystal_chip.has_meta("no_press_fx") and hud.event_chip.has_meta("no_press_fx"),"Butoanele pulsatoare nu intră în conflict cu efectul de apăsare")
	# Landing popup keeps its Label type and gains an icon.
	hud.show_landing("+125 monede\nPiața Poznașă",map.camera,map.pawn.global_position,"coins")
	var popup := hud.get_child(hud.get_child_count() - 1) as Label
	check(popup != null and popup.name == "Premiu" and popup.get_child_count() == 1 and popup.text.begins_with("+125"),"Pop-up de câștig cu pictogramă")
	await create_timer(1.5).timeout
	# Mill blades: continuous angle, no jump when the phase wraps.
	next = map.game.state.duplicate(true)
	next.levels[1] = 2
	map.game._commit(next)
	map.village.set_level(1,2)
	var before: float = map.village.mill_angle
	map.village.phase = TAU*20.0 - 0.01
	await process_frame
	await process_frame
	var after: float = map.village.mill_angle
	check(absf(angle_difference(before,after)) < 0.5,"Palele morii: fără salt la reînceperea fazei")
	# Developer-only visual tests do not touch the state.
	var snapshot: Dictionary = map.game.state.duplicate(true)
	for key in ["coins","fragments","energy","build_points"]:
		map.debug_gain(key,10)
	map.debug_landing_effect(true)
	map.debug_start_effect()
	map.debug_upgrade_effect(0)
	map.debug_crystal_pulse(true)
	await create_timer(1.8).timeout
	check(map.game.state == snapshot,"Testele vizuale nu modifică starea")
	map.free()
	_clean(p)
	for slot in range(2):
		DirAccess.remove_absolute(legacy._path(slot))


func same_state_with_and_without_effects() -> void:
	var results := []
	for mode in ["on","off"]:
		var p: String = prefix + "_det_" + mode
		var legacy := Legacy.new(p)
		legacy.debug_grant()
		var map := _start(p)
		await process_frame
		await process_frame
		map.game.rng.seed = 20261
		map.polish.set_toggle("ambient",mode == "on")
		map.polish.set_toggle("special",mode == "on")
		map.polish.set_toggle("post",mode == "on")
		map.hud.sparks_enabled = mode == "on"
		for i in range(10):
			map._roll()
			map._finish()
		results.append(_fields(map.game))
		map.free()
		_clean(p)
		for slot in range(2):
			DirAccess.remove_absolute(legacy._path(slot))
	check(results[0] == results[1] and results[0].laps >= 0,"Aceeași stare cu efectele pornite și oprite (10 aruncări)")


func sound_hooks() -> void:
	var audio := Audio.new()
	root.add_child(audio)
	await process_frame
	for event in Audio.EVENTS:
		audio.play_event(event)
	audio.play_event("eveniment_necunoscut")
	audio.event_streams["wheel_tick"] = null
	audio.play_event("wheel_tick",1.2)
	check(true,"Evenimentele sonore pot fi apelate fără erori, chiar fără ieșire audio")
	audio.free()


func panel_checks() -> void:
	var map := _start(Profile.PREFIX)
	await process_frame
	await process_frame
	var panel = map.get_node("DeveloperPanel")
	check(panel.pages.size() == 10 and is_instance_valid(panel.visual_status),"Pagina «Efecte vizuale» în panoul existent")
	panel.refresh_data()
	check(panel.visual_status.text.contains("FPS") and panel.visual_status.text.contains("calitate"),"Starea efectelor în panou")
	var profile: Profile = map.game
	check(profile.reset_profile(true),"Profil DEBUG separat")
	map.polish.set_toggle("ambient",false)
	panel.refresh_data()
	check(panel.visual_status.text.contains("ambient nu"),"Comutatorul din panou se reflectă")
	map.polish.set_toggle("ambient",true)
	# Roulette test with a forced prize goes through the normal DEBUG path.
	check(profile.force_prize("chest_gold") and profile.charge_crystal(),"Premiu forțat pentru testul ruletei")
	map.open_crystal()
	# Etapa 4.2: the crystal dive (gather, wave, facets) precedes the wheel by about one second.
	var waited := 0.0
	while map.wheel.phase != map.wheel.Phase.READY and waited < 4.0:
		await create_timer(0.1).timeout
		waited += 0.1
	check(map.wheel.is_open() and map.wheel.phase == map.wheel.Phase.READY and waited < 2.5,"Ruleta se deschide din test")
	map.wheel._on_spin()
	await create_timer(0.8).timeout
	check(map.wheel.spin_power > 0.3 and map.wheel.ray_power > 0.5,"În timpul rotirii: lumina crește odată cu viteza")
	await create_timer(3.6).timeout
	check(map.wheel.phase == map.wheel.Phase.RESULT and map.wheel.wheel.win_index == Crystal.prize_index("chest_gold"),"La oprire: felia câștigătoare este evidențiată")
	check(map.wheel.result_icon.chest_kind == "gold" and map.wheel.result_panel.size.y < 700.0,"Cufăr de aur desenat în rezultat, panou cu dimensiune normală")
	map.wheel._on_continue()
	await create_timer(1.0).timeout
	for kind in ["wood","silver","gold"]:
		profile.add_chests(kind,1)
		map.open_chest(kind)
		await create_timer(0.7).timeout
		check(map.chest_screen.phase == map.chest_screen.Phase.READY and map.chest_screen.kind == kind,"Cufăr %s pregătit, cu apariție animată" % kind)
		map.chest_screen.open_button.pressed.emit()
		await create_timer(1.6).timeout
		map.chest_screen._on_skip()
		check(map.chest_screen.phase == map.chest_screen.Phase.DONE,"Cufăr %s deschis" % kind)
		map.chest_screen._on_continue()
		await create_timer(0.5).timeout
	map.free()


func _run() -> void:
	static_checks()
	await chest_art_draws()
	await scene_checks()
	await same_state_with_and_without_effects()
	await sound_hooks()
	await panel_checks()
	print("Polish vizual: %d verificări, %d erori." % [checks,failures])
	quit(1 if failures else 0)
