extends "res://scripts/main.gd"

const CONSTRUCTION_PUFF := preload("res://scenes/construction_puff.tscn")
const BoardSave := preload("res://scripts/board/board_save.gd")
const RULES := preload("res://assets/board/rules.tres")
const LoopPath := preload("res://scripts/board/loop_path.gd")
const Crystal := preload("res://scripts/crystal/super_crystal_service.gd")
const CrystalGlow := preload("res://scripts/board/crystal_glow.gd")
const Polish := preload("res://scripts/board/polish.gd")
const LerikAnimator := preload("res://scripts/board/lerik_animator.gd")
const EnvironmentLife := preload("res://scripts/board/environment_life.gd")
const Cameo := preload("res://scripts/board/cameo.gd")
var life: EnvironmentLife
var cameo_rng := RandomNumberGenerator.new()
var awaken_pending := false
var animator: LerikAnimator
var dice_reacted := false
var roll_total := 7
var polish: Polish
var aura: MeshInstance3D
var aura_material: StandardMaterial3D
var aura_tween: Tween
var last_charge := -1
var last_ready := false
const WheelScreen := preload("res://scripts/crystal/wheel_screen.gd")
const FacetTransition := preload("res://scripts/crystal/facet_transition.gd")
var facets: FacetTransition
var crystal_glow: CrystalGlow
var wheel: WheelScreen
const EventScreen := preload("res://scripts/crystal/event_screen.gd")
const Events := preload("res://scripts/economy/event_service.gd")
var event_screen: EventScreen
const ChestScreen := preload("res://scripts/crystal/chest_screen.gd")
const CardsScreen := preload("res://scripts/crystal/cards_screen.gd")
const CardService := preload("res://scripts/economy/card_service.gd")
var chest_screen: ChestScreen
var cards_screen: CardsScreen
var event_clock := 0.0
@onready var sounds := $Sunete
@onready var dice := $Zaruri
@onready var path: LoopPath = $LoopPath
@onready var pawn: Node3D = $Lerik
@onready var body := $Lerik/Corp
@onready var shade: MeshInstance3D = $Lerik/Umbra
@onready var rest_scale: Vector3 = body.scale
var camera_tween: Tween
var construction_tweens := {}
var reveals := {}
var joy: Tween
var launch_yaw := 0.2
var launch_step := 0
var marked_levels: Array = []
var travel: Tween
var idle_turn: Tween
var visual_tile := 0
var walked_steps := 0
var idle_age := 0.0
var rare_joy := false


func _open_game() -> RefCounted:
	if OS.is_debug_build() and save_prefix == "user://lerion_developer/profile":
		return load("res://scripts/developer/dev_profile.gd").new()
	return BoardSave.new(save_prefix)


func _connect_mode() -> void:
	# The painted buildings share one satin finish at every level.
	var enamel := StandardMaterial3D.new()
	enamel.vertex_color_use_as_albedo = true
	enamel.roughness = 0.72
	enamel.metallic_specular = 0.27
	# A faint warm rim keeps the silhouettes of roofs and towers readable against the meadow.
	enamel.rim_enabled = true
	enamel.rim = 0.22
	enamel.rim_tint = 0.55
	for group in [village,$Castel]:
		for part in group.find_children("*","MeshInstance3D",true,false):
			part.material_override = enamel
	hud.preferences_changed.connect(apply_preferences)
	hud.control_touched.connect(sounds.click)
	hud.stat_popped.connect(func() -> void: sounds.play_event("hud_pop"))
	dice.ground_hit.connect(sounds.impact)
	dice.ground_hit.connect(_dice_hit)
	dice.settled.connect(_dice_settled)
	apply_preferences()
	hud.roll_requested.connect(_roll)
	hud.indices_requested.connect(path.toggle_indices)
	crystal_glow = CrystalGlow.new()
	crystal_glow.name = "SuperCristal"
	add_child(crystal_glow)
	crystal_glow.setup($Ambient.gem,glow)
	polish = Polish.new()
	polish.name = "Polish"
	add_child(polish)
	polish.setup(path,village,crystal_glow.crystal_center())
	polish.configure(hud.prefs.quality,hud.prefs.reduced)
	_make_aura()
	animator = LerikAnimator.new()
	animator.name = "AnimatieLerik"
	add_child(animator)
	animator.setup(pawn,body,shade)
	life = EnvironmentLife.new()
	life.name = "ViataRegatului"
	add_child(life)
	life.setup(village,$Ambient,$Castel,$Fantana,[$Vegetatie,$Gradina])
	life.configure(hud.prefs.quality,hud.prefs.reduced)
	cameo_rng.randomize()
	camera.occluders = _building_bounds()
	animator.reduced = hud.prefs.reduced
	facets = FacetTransition.new()
	facets.name = "TranzitieFatete"
	add_child(facets)
	wheel = WheelScreen.new()
	wheel.name = "RuletaMagica"
	add_child(wheel)
	wheel.setup(hud,sounds)
	wheel.spin_requested.connect(_spin_wheel)
	wheel.closed.connect(_wheel_closed)
	wheel.later_requested.connect(_wheel_later)
	hud.crystal_requested.connect(open_crystal)
	event_screen = EventScreen.new()
	event_screen.name = "Eveniment"
	add_child(event_screen)
	event_screen.setup(hud)
	event_screen.claim_requested.connect(_claim_event)
	hud.event_requested.connect(open_event)
	chest_screen = ChestScreen.new()
	chest_screen.name = "DeschidereCufar"
	add_child(chest_screen)
	chest_screen.setup(hud,sounds)
	chest_screen.open_requested.connect(_open_chest_request)
	chest_screen.closed.connect(_chest_closed)
	cards_screen = CardsScreen.new()
	cards_screen.name = "CartileMele"
	add_child(cards_screen)
	cards_screen.setup(hud)
	hud.open_chest_requested.connect(open_chest)
	hud.cards_requested.connect(open_cards)
	game.start_scheduled_events()
	game.close_expired_events()
	_sync_crystal()
	if not game.pending_spin().is_empty():
		_recover_spin.call_deferred()
	elif not game.pending_open().is_empty():
		_recover_open.call_deferred()
	_pose(float(game.state.board_position_index))
	pawn.rotation.y = 0.20
	if OS.is_debug_build() and ProjectSettings.get_setting("lerion/developer_panel",true):
		var panel = load("res://scenes/DeveloperPanel.tscn").instantiate()
		panel.map = self
		add_child(panel)


func _last_message() -> String:
	var lap := int(game.state.laps) + 1
	var tile := int(game.state.board_position_index)
	return "START  ·  Turul %d" % lap if tile == 0 else "Căsuța %d  ·  Turul %d" % [tile,lap]


func _roll() -> void:
	if selected_plot >= 0 or hud.overlay.visible or wheel_open() or event_screen.is_open() or _screens_open():
		return
	var roll: Dictionary = game.roll()
	if roll.is_empty():
		_refresh()
		return
	if idle_turn:
		idle_turn.kill()
	hud.throwing = true
	hud.lap_revealed = false
	path.clear_flash()
	walked_steps = 0
	var origin := int(roll.from)
	var steps := int(roll.a) + int(roll.b)
	_refresh()
	sounds.toss()
	polish.ring_burst(pawn.position,Color("#ffe08a"),1.2,0.4)
	hud.spark_screen(hud.roll_button.get_global_rect().get_center(),Color("#ffe08a"))
	dice.play(Vector2i(roll.a,roll.b),camera,hud.map_window())
	camera.frame_throw(dice.global_position)
	roll_total = steps
	dice_reacted = false
	animator.watch_dice(dice.global_position)
	launch_yaw = pawn.rotation.y
	launch_step = origin
	travel = create_tween()
	travel.tween_method(_anticipate,0.0,1.0,dice.ROLL_TIME)
	travel.tween_callback(_start_walk)
	for step in range(steps):
		var start := float(origin+step)
		travel.tween_method(_pose,start,start+1.0,RULES.duration(steps)/steps)
		travel.tween_callback(_arrived.bind((origin+step+1)%RULES.tile_count))
	travel.tween_callback(_finish)


func _start_walk() -> void:
	hud.throwing = false
	animator.start_run(float(launch_step),walked_target(),path.stride)
	_show_aura(true)
	_refresh()


## Lerik watches the dice; when they settle (the face is the confirmed result) he reacts to the sum.
func _anticipate(t: float) -> void:
	if t >= 0.78 and not dice_reacted:
		dice_reacted = true
		animator.react_to_dice(roll_total)


func walked_target() -> int:
	var last: Dictionary = game.state.last_roll
	return int(last.get("a",1)) + int(last.get("b",1))


func _pose(step: float) -> void:
	var here := path.at_step(step)
	var direction := path.at_step(step+0.18) - path.at_step(step-0.10)
	var next_direction := path.at_step(step+0.50) - here
	var bank := clampf(direction.signed_angle_to(next_direction,Vector3.UP),-0.40,0.40)
	var phase := fposmod(step,1.0)
	var hop := 4.0*phase*(1.0-phase)
	if game.busy and not hud.throwing:
		camera.track_path(here,path.at_step(step+3.7))
	animator.drive_run(step,bank)
	pawn.position = here + Vector3.UP * 0.038
	pawn.rotation.y = lerp_angle(launch_yaw,atan2(direction.x,direction.z),smoothstep(0.0,0.70,step-launch_step))
	visual_tile = posmod(roundi(step),RULES.tile_count)


func _arrived(index: int) -> void:
	walked_steps += 1
	sounds.step(index)
	polish.step_dust(pawn.position)
	if index == 0:
		_show_lap()
		animator.cheer_pass()
	message.text = "START" if index == 0 else "Căsuța %d" % index


func _finish() -> void:
	if not game.busy:
		return
	if travel:
		travel.kill()
	dice.cancel()
	hud.throwing = false
	sounds.land()
	_pose(float(game.state.board_position_index))
	# Even a skipped wrap ends facing along the curve at the destination.
	var tangent := path.at_step(visual_tile+0.025) - path.at_step(visual_tile)
	pawn.rotation.y = atan2(tangent.x,tangent.z)
	idle_turn = create_tween()
	var forward := pawn.rotation.y + angle_difference(pawn.rotation.y,0.20)
	idle_turn.tween_property(pawn,"rotation:y",forward,0.24)
	camera.frame_landing(pawn.position,walked_steps > 0)
	game.busy = false
	message.text = _last_message()
	_refresh()

	if not hud.lap_revealed and game.state.last_roll.start_coins > 0:
		_show_lap()
	var landing: Dictionary = game.state.last_roll.landing
	var key := str(landing.get("resource","coins"))
	rare_joy = game.ECONOMY.kind(visual_tile,RULES.tile_count) == "magic" or (key == "coins" and int(landing.get("amount",0)) >= 125)
	path.flash(visual_tile,hud.prize_color(key))
	_show_aura(false)
	var category: String = game.ECONOMY.kind(visual_tile,RULES.tile_count)
	polish.landing(path.centers[visual_tile],Color(path.CATEGORY_TINT.get(category,"ffd866")).lightened(0.25),rare_joy)
	if not landing.is_empty():
		polish.emote(pawn.position + Vector3.UP*1.95,str(landing.resource))
	# Rare and short: sometimes Pufi pops in to sneeze magic over a magic tile.
	if awaken_pending:
		awaken_pending = false
		get_tree().create_timer(0.7).timeout.connect(awaken)
	elif category == "magic" and cameo_rng.randf() < 0.3:
		pufi_cameo()
	var event_points := int(game.state.last_roll.get("event_points",0))
	if event_points > 0:
		hud.show_event_points(event_points,str(Events.definition(str(game.state.event.id)).name))
	_celebrate()
	if not landing.is_empty():
		sounds.reward(landing.resource)
		if game.ECONOMY.kind(visual_tile,RULES.tile_count) == "magic":
			sounds.magic()
		var text: String = game.ECONOMY.describe(landing)
		var slot: int = game.building_at(visual_tile)
		if slot >= 0 and game.state.levels[slot] > 0:
			text += "\n%s · niv. %d" % [game.cfg.buildings.positions[slot].building,game.state.levels[slot]]
		if rare_joy:
			_camera_lift(0.085)
		var balance := int(game.state.wallet.get(landing.resource,game.state.energy))
		hud.fly_prize(landing.resource,pawn.global_position + Vector3.UP*0.8,camera,balance,rare_joy,int(landing.amount))
		hud.show_landing(text,camera,pawn.global_position + Vector3.UP * 2.13,key)


func _show_lap() -> void:
	hud.lap_revealed = true
	if game.busy:
		_refresh()
	_camera_lift(0.085)
	polish.start_burst(path.centers[0])
	hud.pop_stat("coins",0,1.3)
	var coins := int(game.state.last_roll.start_coins)
	sounds.reward("coins")
	hud.fly_prize("coins",path.centers[0]+Vector3.UP*0.75,camera,int(game.state.wallet.coins))
	if game.state.board_position_index == 0:
		hud.show_landing("Tur nou · +%d monede" % coins,camera,path.centers[0] + Vector3.UP * 1.0)
	else:
		hud.show_lap(coins)


func _refresh() -> void:
	super()
	_sync_crystal()
	if marked_levels != game.state.levels:
		marked_levels = game.state.levels.duplicate()
		path.mark_levels(marked_levels, game.cfg.buildings.positions)
	var tiles := PackedInt32Array()
	if selected_plot >= 0:
		if path.flashing >= 0:
			path.clear_flash()
		var building: String = game.cfg.buildings.positions[selected_plot].id
		tiles = game.ECONOMY.tiles_for(building, RULES.tile_count)
	path.show_zone(tiles)


func _upgrade(slot: int, level: int) -> void:
	if slot != selected_plot or not game.upgrade(slot, level):
		_refresh()
		return
	sounds.upgrade()
	village.set_level(slot, level + 1)
	camera.occluders = _building_bounds()
	_refresh()
	path.pulse_zone()
	var model: Node3D = village.models[slot]
	var previous: Tween = construction_tweens.get(slot)
	if previous:
		previous.kill()
	# Models are instantiated at unit scale; animate about their ground-level root.
	_camera_lift(0.09)
	model.scale = Vector3(1.04,0.85,1.04)
	var pop := model.create_tween()
	construction_tweens[slot] = pop
	pop.tween_property(model,"scale",Vector3(0.98,1.06,0.98),0.16).set_trans(Tween.TRANS_SINE)
	pop.tween_property(model,"scale",Vector3.ONE,0.20).set_trans(Tween.TRANS_SINE)
	if reveals.has(slot):
		reveals[slot].material_overlay = null
	var part: MeshInstance3D = model.find_child(["Base","Upgrade2","Upgrade3"][level],true,false)
	var gild := ShaderMaterial.new()
	gild.shader = preload("res://assets/board/reveal.gdshader")
	part.material_overlay = gild
	reveals[slot] = part
	pop.parallel().tween_method(func(t: float) -> void: gild.set_shader_parameter("sweep",t),0.0,1.0,0.42)
	pop.tween_callback(func() -> void:
		part.material_overlay = null
		reveals.erase(slot)
		construction_tweens.erase(slot))
	hud.spark_at(camera,model.global_position+Vector3.UP*1.45,Color("#ffe992"))
	polish.upgrade_burst(model.global_position)
	sounds.play_event("upgrade")
	pongo_cameo(slot)
	if not hud.prefs.reduced:
		var puff := CONSTRUCTION_PUFF.instantiate() as CPUParticles3D
		puff.amount = [5,8,12][hud.prefs.quality]
		add_child(puff)
		puff.position = model.position + Vector3.UP * 0.67
		puff.finished.connect(puff.queue_free)
		puff.emitting = true
	var building: String = game.cfg.buildings.positions[slot].id
	# Preview the transition just purchased; the panel already shows the next one.
	message.text = game.ECONOMY.preview(building, level)


func _select_at(screen_point: Vector2) -> void:
	if event_screen.is_open() or _screens_open():
		return
	if not game.busy and not wheel_open() and _crystal_hit(screen_point):
		open_crystal()
		return
	super(screen_point)
	if selected_plot >= 0 and game.error.is_empty():
		var indices := PackedStringArray()
		for tile in path.selected_tiles:
			indices.append(str(tile))
		message.text = "Bonus global · căsuțele %s" % ", ".join(indices) if not indices.is_empty() else "Moara Trăsnită · energie mai multă din evenimente"


## Landing and joy are played by the animator; the kind depends on the confirmed receipt only.
func _celebrate() -> void:
	var landing: Dictionary = game.state.last_roll.get("landing",{})
	animator.land("big" if rare_joy else ("empty" if landing.is_empty() else "normal"),roll_total)


func _camera_lift(height: float) -> void:
	if hud.prefs.reduced:
		return
	if camera_tween:
		camera_tween.kill()
	camera_tween = create_tween()
	camera_tween.tween_property(camera,"v_offset",height,0.13).set_trans(Tween.TRANS_SINE)
	camera_tween.tween_property(camera,"v_offset",0.0,0.24).set_trans(Tween.TRANS_SINE)

func _process(delta: float) -> void:
	super(delta)
	event_clock += delta
	if event_clock >= 1.0:
		event_clock = 0.0
		_tick_events()

func apply_preferences() -> void:
	var tier: int = hud.prefs.quality
	var viewport := get_viewport()
	Engine.max_fps = 30 if tier == 0 else 60
	viewport.scaling_3d_scale = [0.70,0.86,1.0][tier]
	viewport.msaa_3d = Viewport.MSAA_2X if tier == 2 else Viewport.MSAA_DISABLED
	var sun: DirectionalLight3D = $Soare
	sun.shadow_enabled = tier > 0
	sun.directional_shadow_max_distance = 44.0 if tier == 2 else 31.0
	$Ambient.configure(tier,hud.prefs.reduced)
	sounds.configure(hud.prefs.music,hud.prefs.sfx)
	camera.reduced = hud.prefs.reduced
	camera.motion = hud.prefs.camera_motion
	if animator:
		animator.reduced = hud.prefs.reduced
	if crystal_glow:
		crystal_glow.configure(tier,hud.prefs.reduced)
	if polish:
		polish.configure(tier,hud.prefs.reduced)
	if life:
		life.configure(tier,hud.prefs.reduced or not polish.ambient_on)
	if wheel:
		wheel.reduced = hud.prefs.reduced
	if chest_screen:
		chest_screen.reduced = hud.prefs.reduced
	dice.reduced = hud.prefs.reduced
	dice.impacts.multimesh.visible_instance_count = 8 if tier == 0 else 16
	if camera.reduced and camera.shot != camera.Shot.OVERVIEW:
		camera.return_home()


# Super Crystal and Magic Wheel. The save owns every decision; the wheel only presents receipts.

func wheel_open() -> bool:
	return wheel != null and wheel.is_open()


func _sync_crystal() -> void:
	if crystal_glow == null or game.state.is_empty():
		return
	var s: Dictionary = game.state
	var charge := Crystal.charge(s)
	var ready := Crystal.is_ready(s)
	crystal_glow.set_progress(float(charge)/Crystal.target(s),ready)
	# Visual beats only: a pulse for every point of charge, a burst when the crystal becomes ready.
	if last_charge >= 0 and polish:
		if ready and not last_ready:
			# The roll that fills the crystal is still on screen: wake the kingdom after landing.
			if game.busy:
				awaken_pending = true
			else:
				awaken()
		elif charge > last_charge:
			crystal_glow.pulse_now(0.7)
			sounds.play_event("crystal_pulse")
	last_charge = charge
	last_ready = ready


func _crystal_hit(screen_point: Vector2) -> bool:
	if crystal_glow == null or camera.is_position_behind(crystal_glow.crystal_center()):
		return false
	var point := crystal_glow.crystal_center()
	var middle := camera.unproject_position(point)
	var reach := middle.distance_to(camera.unproject_position(point + camera.global_basis.x*1.15))
	# The fountain basin below the gem counts too, with a finger-sized minimum.
	var base := camera.unproject_position(point - Vector3.UP*1.0)
	return screen_point.distance_to(middle) <= maxf(reach,46.0) or screen_point.distance_to(base) <= maxf(reach,46.0)


func open_crystal() -> void:
	if game.busy or wheel_open() or _screens_open() or hud.overlay.visible or game.state.is_empty():
		return
	if selected_plot >= 0:
		_deselect()
	var s: Dictionary = game.state
	if not Crystal.is_ready(s):
		message.text = "Super Cristal · %d/%d aruncări" % [Crystal.charge(s),Crystal.target(s)]
		crystal_glow.burst()
		return
	camera.manual_override = false
	camera.frame_crystal(crystal_glow.crystal_center())
	message.text = "Ruleta Magică"
	if hud.prefs.reduced or not polish.special_active():
		crystal_glow.burst()
		polish.crystal_burst()
		sounds.magic()
		wheel.open()
		return
	# Crystal dive: energy is drawn in, a wave leaves the fountain, and crystal facets open onto
	# the wheel. The wheel screen is already open (transparent) so input and state stay consistent.
	polish.crystal_gather()
	crystal_glow.pulse_now(1.0)
	sounds.play_event("crystal_activate")
	wheel.open(1.0)
	var beat := create_tween()
	beat.tween_interval(0.5)
	beat.tween_callback(func() -> void:
		crystal_glow.pulse_now(2.0)
		crystal_glow.burst()
		polish.crystal_wave()
		sounds.magic())
	beat.tween_interval(0.08)
	beat.tween_callback(func() -> void:
		var point := crystal_glow.crystal_center()
		var origin := camera.unproject_position(point) if not camera.is_position_behind(point) else get_viewport().get_visible_rect().size*0.5
		facets.play(origin))


func _spin_wheel() -> void:
	var receipt: Dictionary = game.spin_wheel()
	if receipt.is_empty():
		wheel.refuse(game.error if not game.error.is_empty() else "Cristalul nu este încărcat.")
		return
	_sync_crystal()
	wheel.play(receipt)


func _wheel_later() -> void:
	camera.return_home()
	message.text = "Super Cristalul rămâne încărcat"
	_refresh()


func _wheel_closed(receipt: Dictionary) -> void:
	var open_now: bool = wheel.open_now
	camera.return_home()
	if not game.acknowledge_spin(int(receipt.get("id",0))) and not game.pending_spin().is_empty():
		message.text = game.error
	else:
		message.text = "Ruleta Magică · " + Crystal.describe(receipt)
	_refresh()
	if receipt.get("kind") == "energy":
		hud.fly_prize("energy",crystal_glow.crystal_center(),camera,int(game.state.energy),true,int(receipt.amount))
	else:
		hud.spark_at(camera,crystal_glow.crystal_center(),Color("#ffd04a"),"",true)
	crystal_glow.burst()
	if open_now and receipt.get("kind") == "chest":
		_open_when_wheel_gone(str(receipt.chest))
	elif not game.pending_open().is_empty():
		_open_when_wheel_gone("")


func _recover_spin() -> void:
	var receipt: Dictionary = game.pending_spin()
	if receipt.is_empty() or wheel_open():
		return
	message.text = "Premiu confirmat · " + Crystal.describe(receipt)
	wheel.show_recovered(receipt)


# Events. The screen shows the saved state; claims go through the save transaction.

func open_event() -> void:
	if game.busy or wheel_open() or _screens_open() or hud.overlay.visible or game.state.event.is_empty():
		return
	if selected_plot >= 0:
		_deselect()
	event_screen.open(game)


func _claim_event(milestone_id: String) -> void:
	var receipt: Dictionary = game.claim_event_reward(milestone_id)
	if receipt.is_empty():
		event_screen.refresh()
		return
	sounds.reward("energy" if receipt.kind == "energy" else "coins")
	message.text = "Eveniment · " + Events.describe(receipt)
	_refresh()
	event_screen.refresh()
	hud.spark_at(camera,pawn.global_position + Vector3.UP*1.2,Color("#9ef0e1"),"",true)


func _tick_events() -> void:
	if game.state.is_empty() or game.busy:
		return
	var before: String = Events.status(game.state.event,game.clock())
	if before == "closed":
		game.close_expired_events()
		event_screen.refresh()
	hud.refresh_event(game,game.state)


# Chests and cards. The screens show saved receipts; opening goes through the save transaction.

func _screens_open() -> bool:
	return chest_screen != null and (chest_screen.is_open() or cards_screen.is_open())


func open_chest(kind: String) -> void:
	if game.busy or wheel_open() or event_screen.is_open() or _screens_open() or hud.overlay.visible or game.state.is_empty():
		return
	if selected_plot >= 0:
		_deselect()
	if not game.pending_open().is_empty():
		_recover_open()
		return
	var count := int(game.state.chests.get(kind,0))
	if count < 1:
		message.text = "Nu ai cufere de acest tip"
		return
	chest_screen.open(kind,count)


func _open_chest_request(kind: String) -> void:
	var receipt: Dictionary = game.open_chest(kind)
	if receipt.is_empty():
		chest_screen.refuse(game.error if not game.error.is_empty() else "Cufărul nu a putut fi deschis.")
		return
	_refresh()
	chest_screen.play(receipt)


func _chest_closed(receipt: Dictionary) -> void:
	game.acknowledge_open(int(receipt.get("id",0)))
	message.text = "Cufăr deschis · " + CardService.describe(receipt)
	_refresh()


## The wheel fades out for a moment after it is closed; the chest screen opens right after.
func _open_when_wheel_gone(kind: String) -> void:
	while wheel_open():
		await get_tree().process_frame
	if kind.is_empty():
		_recover_open()
	else:
		open_chest(kind)


func _recover_open() -> void:
	var receipt: Dictionary = game.pending_open()
	if receipt.is_empty() or _screens_open() or wheel_open():
		return
	message.text = "Cărți confirmate · " + CardService.describe(receipt)
	chest_screen.show_recovered(receipt)


func open_cards() -> void:
	if game.busy or wheel_open() or _screens_open() or hud.overlay.visible:
		return
	cards_screen.open(game.state)


# Soft golden ground spot that follows Lerik while he walks, so the eye keeps him in view.

func _make_aura() -> void:
	aura_material = polish.glow_material(Polish.soft_texture,false)
	aura_material.albedo_color = Color(1.0,0.86,0.45,0.0)
	var disc := QuadMesh.new()
	disc.size = Vector2(2.3,2.3)
	disc.orientation = PlaneMesh.FACE_Y
	disc.material = aura_material
	aura = MeshInstance3D.new()
	aura.name = "Aura"
	aura.mesh = disc
	aura.position = Vector3(0,-0.17,0)
	aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	aura.visible = false
	pawn.add_child(aura)


func _show_aura(on: bool) -> void:
	if aura == null:
		return
	if aura_tween:
		aura_tween.kill()
	if not on or not polish.special_active():
		aura_tween = create_tween()
		aura_tween.tween_property(aura_material,"albedo_color:a",0.0,0.2)
		aura_tween.tween_callback(func() -> void: aura.visible = false)
		return
	aura.visible = true
	aura_tween = create_tween()
	aura_tween.tween_property(aura_material,"albedo_color:a",0.5,0.2)


# Visual-effect tests for the Developer Panel. They only play effects: no state is read for rewards
# and nothing is saved.

func debug_gain(key: String, amount: int) -> void:
	var stat: String = {"coins": "coins", "fragments": "fragments", "energy": "energy"}.get(key,"")
	hud.fly_prize(key,pawn.global_position + Vector3.UP*0.8,camera,0,amount >= 100,amount)
	polish.emote(pawn.position + Vector3.UP*1.95,key)
	if not stat.is_empty():
		hud.pop_stat(stat,amount)
	hud.show_landing("+%d %s" % [amount,game.ECONOMY.unit(key,amount)],camera,pawn.global_position + Vector3.UP*2.13,key)
	sounds.play_event("coin_gain" if key == "coins" else "hud_pop")


func debug_landing_effect(rare := false) -> void:
	var tile := visual_tile
	polish.landing(path.centers[tile],Color("#ffd866"),rare)
	path.flash(tile,Color("#fff0a4"))
	_celebrate()


func debug_start_effect() -> void:
	polish.start_burst(path.centers[0])
	hud.pop_stat("coins",0,1.3)


func debug_upgrade_effect(slot := 0) -> void:
	var model: Node3D = village.models[slot]
	polish.upgrade_burst(model.global_position)
	hud.spark_at(camera,model.global_position + Vector3.UP*1.45,Color("#ffe992"))


func debug_crystal_pulse(ready := false) -> void:
	crystal_glow.pulse_now(1.5 if ready else 0.8)
	if ready:
		polish.crystal_burst()


# Dice choreography: the physics look is scripted towards the confirmed faces; these are only effects.

func _dice_hit(strength: float) -> void:
	var points := []
	for die in dice.faces:
		points.append(die.global_position)
	polish.dice_impact(points,strength)
	camera.kick(strength)


func _dice_settled() -> void:
	var points := []
	for die in dice.faces:
		points.append(die.global_position)
	polish.dice_settle(points)
	sounds.play_event("dice_settle")


## World boxes of the castle and the built houses, for the camera's line-of-sight check.
func _building_bounds() -> Array[AABB]:
	var boxes: Array[AABB] = []
	for node: Node3D in village.models + [$Castel]:
		if not node.visible:
			continue
		var merged := AABB()
		var first := true
		for mesh: MeshInstance3D in node.find_children("*","MeshInstance3D",true,false):
			var box := mesh.global_transform*mesh.get_aabb()
			merged = box if first else merged.merge(box)
			first = false
		if not first:
			boxes.append(merged.grow(-0.15))
	return boxes


# Pongo and Pufi cameos and the kingdom awakening. Visual only, never blocking.

func _cameo_running(who: String) -> bool:
	for node in get_children():
		if node is Cameo and node.character == who:
			return true
	return false


func spawn_cameo(who: String, clip: String, at: Vector3, look: Vector3, size := 1.0) -> Node:
	if not polish.special_active() or _cameo_running(who):
		return null
	var cameo := Cameo.new()
	cameo.name = "Cameo_" + who
	add_child(cameo)
	cameo.start(who,clip,at,look,size)
	cameo.event.connect(_cameo_event)
	return cameo


## Pongo hammers next to the building he just upgraded, overdoes the last hit and cheers.
func pongo_cameo(slot: int) -> Node:
	var model: Node3D = village.models[slot]
	var base := model.global_position
	var side := -signf(base.x) if absf(base.x) > 0.1 else 1.0
	return spawn_cameo("pongo","pongo_build",base + Vector3(side*1.15,0.02,0.95),camera.global_position,1.1)


## Pufi flies in beside Lerik, sneezes magic bubbles; Lerik jumps back in surprise.
func pufi_cameo() -> Node:
	var right := pawn.global_basis.x
	return spawn_cameo("pufi","pufi_sneeze",pawn.global_position + right*0.95 + Vector3(0,0,0.2),pawn.global_position,0.95)


func _cameo_event(name: String, at: Vector3) -> void:
	match name:
		"hit":
			polish.sparkle_burst(at + Vector3(0.4,-0.4,0.2),Color("#ffc36b"),0.35)
			sounds.play_event("hammer")
		"big_hit":
			polish.sparkle_burst(at + Vector3(0.4,-0.3,0.2),Color("#fff0a8"),0.8)
			polish.ring_burst(Vector3(at.x,0.05,at.z),Color("#ffd27a"),1.6,0.4)
			polish.plank_jump(at + Vector3(0.5,0.1,0.1))
			camera.kick(0.6)
			sounds.play_event("hammer_big")
		"cheer":
			polish.emote(at + Vector3.UP*0.9,"build_points")
			sounds.play_event("cheer")
		"sneeze":
			polish.bubble_burst(at + Vector3(0,0.1,0.25))
			sounds.play_event("sneeze")
			if at.distance_to(pawn.global_position) < 3.0 and not game.busy:
				animator.play("surprise")


## WOW: the kingdom wakes up when the Super Crystal is full. A wave of light runs out from
## the fountain over every tile, each building hops as it reaches it, the flags catch a gust
## and Pufi circles the crystal once and sneezes magic into it.
func awaken() -> void:
	crystal_glow.pulse_now(1.6)
	sounds.play_event("crystal_ready")
	if not polish.special_active():
		polish.crystal_burst()
		return
	var center := crystal_glow.crystal_center()
	polish.crystal_wave()
	polish.tile_wave(path.centers,center)
	$Ambient.blow(1.0)
	for slot in range(village.models.size()):
		var model: Node3D = village.models[slot]
		if not model.visible or construction_tweens.has(slot):
			continue
		var delay := 0.15 + Vector2(model.global_position.x,model.global_position.z).length()*0.07
		var hop := model.create_tween()
		hop.tween_interval(delay)
		hop.tween_property(model,"scale",Vector3(1.05,0.86,1.05),0.1).set_trans(Tween.TRANS_SINE)
		hop.tween_property(model,"scale",Vector3(0.97,1.08,0.97),0.14).set_trans(Tween.TRANS_SINE)
		hop.tween_property(model,"scale",Vector3.ONE,0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		hop.tween_callback(func() -> void: polish.sparkle_burst(model.global_position + Vector3.UP*1.6,Color("#fff0b0"),0.4))
	var pufi := spawn_cameo("pufi","pufi_orbit",center + Vector3(0,-0.8,1.9),center,0.85)
	if pufi:
		pufi.circle(Vector3(center.x,center.y - 0.9,center.z))
	if not game.busy:
		animator.play("wow")
