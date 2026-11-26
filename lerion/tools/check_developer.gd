extends SceneTree
const Profile := preload("res://scripts/developer/dev_profile.gd")
const Save := preload("res://scripts/board/board_save.gd")
const Simulation := preload("res://scripts/developer/economy_simulation.gd")
class FailingProfile extends Profile:
	var fail_write := false
	func _commit(next: Dictionary) -> bool:
		if fail_write:
			error = "Simulated write failure"
			return false
		return super(next)

var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, caption: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(caption)
func snapshot(path: String) -> String:
	return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""
func run() -> void:
	var retry := FailingProfile.new(true)
	retry.force_pair(Vector2i(4,5))
	retry.fail_write = true
	var retry_before: Dictionary = retry.state.duplicate(true)
	check(retry.roll().is_empty() and retry.state == retry_before and not retry.busy,"Failed save consumes nothing")
	check(retry.forced_pair == Vector2i(4,5),"Failed save retains forced pair")
	retry.fail_write = false
	var receipt := retry.roll()
	check(receipt.a == 4 and receipt.b == 5 and retry.forced_pair == Vector2i.ZERO,"Retry commits forced pair once")
	var normal := Save.new("user://normal_dev_test")
	normal.state.wallet.coins = 12345
	normal._commit(normal.state.duplicate(true))
	var normal_hash := [snapshot(normal._path(0)),snapshot(normal._path(1))]
	var map = load("res://scenes/board.tscn").instantiate()
	map.save_prefix = Profile.PREFIX
	root.add_child(map)
	await process_frame
	var panel = map.get_node("DeveloperPanel")
	check(panel.active and panel.launcher.visible,"Bouton DEBUG et profil distinct")
	await tap(panel.launcher)
	check(panel.cover.visible,"Touch Android opens the panel")
	var close: Control = panel.frame.get_child(0).get_child(0).get_child(1)
	await tap(close)
	check(not panel.cover.visible,"Touch closes the panel")
	var profile: Profile = map.game
	check(profile.allowed() and profile.save_prefix != normal.save_prefix,"Profil distinct")
	check(profile.reset_profile(true),"Initialisation isolée")
	check(profile.set_resource("coins",10000) and profile.set_resource("coins",500,true),"Set et ajout")
	check(profile.state.wallet.coins == 10500,"Montant exact")
	for key in ["fragments","build_points","quest_tokens"]:
		check(profile.set_resource(key,47) and profile.state.wallet[key] == 47,"Resource "+key)
	check(profile.set_resource("energy",1000) and profile.state.energy == 100,"Énergie plafonnée")
	check(not profile.set_resource("tickets",-1) and not profile.set_resource("unknown",5),"Entrées invalides")
	check(profile.teleport(34),"Téléport")
	var before: Dictionary = profile.state.duplicate(true)
	check(profile.force_pair(Vector2i(2,3)),"Paire préparée")
	panel.speed = 0
	panel.play_roll()
	check(profile.state.board_position_index == 3 and not profile.busy,"Aruncare completă instant")
	check(profile.state.last_roll.a == 2 and profile.state.last_roll.b == 3,"Dés confirmés")
	check(profile.state.wallet.coins == before.wallet.coins+100 and profile.state.laps == before.laps+1,"START une seule fois")
	var saved: Dictionary = profile.state.duplicate(true)
	map._finish()
	check(profile.state == saved and profile.forced_pair == Vector2i.ZERO,"Sans double récompense")
	check(not profile.force_pair(Vector2i(0,7)),"Dés invalides")
	check(profile.teleport(34) and profile.force_pair(Vector2i.ONE),"Préparer arrêt START")
	panel.speed = 3
	panel.play_roll()
	var confirmed: Dictionary = profile.state.duplicate(true)
	await create_timer(0.35).timeout
	check(profile.busy and not map.hud.throwing,"Animation 3× démarre la marche après 0,35s")
	check(profile.roll().is_empty(),"Double tap bloqué")
	map._finish()
	check(profile.state == confirmed and confirmed.last_roll.landing.is_empty(),"START sans deuxième prix")
	for i in range(6):
		for level in range(4):
			check(profile.set_level(i,level),"Niveau réglable")
			panel.sync_map()
			check(map.village.levels[i] == level,"Modèle actualisé")
	check(profile.checkpoint(),"Checkpoint")
	var held: Dictionary = profile.state.duplicate(true)
	profile.set_resource("coins",2)
	check(profile.restore_checkpoint() and profile.state.wallet == held.wallet,"Restauration")
	check(Profile.new().state == profile.state,"Rechargement identique")
	var untouched: Dictionary = profile.state.duplicate(true)
	var overflow := profile.energy_overflow_test(150)
	check(overflow.before == 150 and overflow.after == 149 and overflow.receipt.landing.resource != "energy","Énergie hors plafond isolée, sans énergie de case")
	check(profile.state == untouched,"Hors plafond sans mutation")
	check(profile.set_future(50,false,"wood") and profile.state.debug_future.threshold == 50,"Seuil initial préparé")
	check(profile.set_future(100,true,"gold") and profile.state.debug_future.threshold == 100,"Seuil ultérieur préparé")
	check(profile.state.wallet == untouched.wallet and profile.state.crystal_charge == untouched.crystal_charge,"Future sans récompense fictive")
	var simulator := Simulation.new()
	var source: Dictionary = profile.state.duplicate(true)
	var result: Dictionary = await simulator.run(source,1000,self)
	check(result.completed == 1000 and result.energy_spent == 1000,"1000 transactions normales")
	for count in [100,10000]:
		var batch: Dictionary = await Simulation.new().run(source,count,self)
		check(batch.completed == count and batch.energy_spent == count,"Simulation complète "+str(count))
	var sum := 0
	for n in result.categories.values(): sum += int(n)
	check(sum == 1000 and result.start_coins == result.start_passes*100,"Comptage catégories START")
	check(result.rewards.coins > result.baseline_rewards.coins,"Effet global mesuré")
	check(profile.state == source and Profile.new().state == source,"Simulation sans écritures du profil")
	check(profile.write_json("diagnostic.json",{"state":profile.state,"simulation":result}),"Diagnostic")
	check(not profile.write_json("../normal",{}),"Chemin export restreint")
	check(not profile.reset_profile(false),"Confirmation reset obligatoire")
	for pixels in [Vector2i(720,1280),Vector2i(720,1600),Vector2i(768,1024)]:
		root.size = pixels
		await process_frame
		panel.open_panel()
		await process_frame
		for page in range(panel.pages.size()):
			panel.show_page(page)
			await process_frame
			check(panel.frame.get_rect().end.x <= root.get_visible_rect().size.x and panel.frame.get_rect().end.y <= root.get_visible_rect().size.y,"Meniu încadrat "+str(pixels))
	panel.close_panel()
	# A failed write keeps the forced pair for a safe retry.
	var checkpoint_path := Profile.ROOT+"checkpoint.json"
	var file_hash := snapshot(checkpoint_path)
	check(not profile.write_json("other.json",{}),"Export avec destination fixe")
	check(snapshot(checkpoint_path) == file_hash,"Checkpoint intact")
	check(normal_hash == [snapshot(normal._path(0)),snapshot(normal._path(1))],"Salvările normale intacte")
	var original_path := profile.save_prefix
	profile.save_prefix = normal.save_prefix
	check(not profile.set_resource("coins",99) and profile.roll().is_empty(),"Refuză redirecționarea către profil normal")
	profile.save_prefix = original_path
	map.free()
	var main = load("res://scenes/board.tscn").instantiate()
	main.save_prefix = "user://normal_dev_test"
	root.add_child(main)
	var gate = main.get_node("DeveloperPanel")
	check(not gate.active and gate.pages.is_empty(),"Normal profile exposes only entry control")
	gate.switch_profile(true)
	await process_frame
	await process_frame
	var dev_map = current_scene
	check(dev_map.game is Profile and dev_map.get_node("DeveloperPanel").active,"Enter development profile")
	dev_map.get_node("DeveloperPanel").switch_profile(false)
	await process_frame
	await process_frame
	check(current_scene.game.save_prefix == normal.save_prefix,"Return to original profile")
	check(normal_hash == [snapshot(normal._path(0)),snapshot(normal._path(1))],"Switching never writes the original profile")
	current_scene.free()
	ProjectSettings.set_setting("lerion/developer_panel",false)
	var disabled = load("res://scenes/board.tscn").instantiate()
	disabled.save_prefix = "user://normal_dev_test"
	root.add_child(disabled)
	check(not disabled.has_node("DeveloperPanel"),"Configuration can disable the panel in DEBUG")
	check(not Profile.new(true).set_resource("coins",1),"Disabled developer configuration rejects writes")
	disabled.free()
	ProjectSettings.set_setting("lerion/developer_panel",true)
	print("Developer: %d verificări, %d erori." % [checks,failures])
	quit(1 if failures else 0)

func tap(control: Control) -> void:
	for pressed in [true,false]:
		var event := InputEventScreenTouch.new()
		event.pressed = pressed
		event.position = root.get_final_transform()*control.get_global_rect().get_center()
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await process_frame
