extends "res://scripts/main.gd"

const CONSTRUCTION_PUFF := preload("res://scenes/construction_puff.tscn")
const BoardSave := preload("res://scripts/board/board_save.gd")
const RULES := preload("res://assets/board/rules.tres")
const LoopPath := preload("res://scripts/board/loop_path.gd")
const Crystal := preload("res://scripts/crystal/super_crystal_service.gd")
const CrystalGlow := preload("res://scripts/board/crystal_glow.gd")
const WheelScreen := preload("res://scripts/crystal/wheel_screen.gd")
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
	for group in [village,$Castel]:
		for part in group.find_children("*","MeshInstance3D",true,false):
			part.material_override = enamel
	hud.preferences_changed.connect(apply_preferences)
	hud.control_touched.connect(sounds.click)
	dice.ground_hit.connect(sounds.impact)
	apply_preferences()
	hud.roll_requested.connect(_roll)
	hud.indices_requested.connect(path.toggle_indices)
	crystal_glow = CrystalGlow.new()
	crystal_glow.name = "SuperCristal"
	add_child(crystal_glow)
	crystal_glow.setup($Ambient.gem,glow)
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
	dice.play(Vector2i(roll.a,roll.b),camera,hud.map_window())
	camera.frame_throw(dice.global_position)
	if joy:
		joy.kill()
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
	_refresh()


func _anticipate(t: float) -> void:
	var ready_to_jump := smoothstep(0.55,0.88,t)*(1.0-smoothstep(0.88,1.0,t))
	body.pose(0.0,ready_to_jump,0.0)
	body.position.y = 0.02
	body.scale = rest_scale*Vector3(1.0+0.08*ready_to_jump,1.0-0.13*ready_to_jump,1.0+0.08*ready_to_jump)
	body.rotation = Vector3(0.12*ready_to_jump,0,0)


func _pose(step: float) -> void:
	var here := path.at_step(step)
	var direction := path.at_step(step+0.18) - path.at_step(step-0.10)
	var next_direction := path.at_step(step+0.50) - here
	var bank := clampf(direction.signed_angle_to(next_direction,Vector3.UP),-0.40,0.40)
	var phase := fposmod(step,1.0)
	var hop := 4.0*phase*(1.0-phase)
	if game.busy and not hud.throwing:
		camera.track_path(here,path.at_step(step+3.7))
	var stride := sin(PI*step)
	body.pose(stride,0.0,0.0,bank)
	pawn.position = here + Vector3.UP * 0.038
	pawn.rotation.y = lerp_angle(launch_yaw,atan2(direction.x,direction.z),smoothstep(0.0,0.70,step-launch_step))
	body.position.y = 0.02 + 0.29 * hop
	body.rotation = Vector3(0.13 * hop,0.08*stride,0.10*stride - bank*0.27)
	var stretch := hop * 0.09
	body.scale = rest_scale * Vector3(1.0-stretch*0.4,1.0+stretch,1.0-stretch*0.4)
	shade.scale = Vector3.ONE * (1.0 - 0.20 * hop)
	visual_tile = posmod(roundi(step),RULES.tile_count)


func _arrived(index: int) -> void:
	walked_steps += 1
	sounds.step(index)
	if index == 0:
		_show_lap()
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
		hud.show_landing(text,camera,pawn.global_position + Vector3.UP * 2.13)


func _show_lap() -> void:
	hud.lap_revealed = true
	if game.busy:
		_refresh()
	_camera_lift(0.085)
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


func _celebrate() -> void:
	if joy:
		joy.kill()
	joy = create_tween()
	joy.tween_method(_joy_pose,0.0,1.0,0.54)


func _joy_pose(t: float) -> void:
	var lift := clampf((t-0.19)/0.68,0.0,1.0)
	var jump := sin(PI*lift)
	var flourish := sin(TAU*lift)*jump if rare_joy else 0.0
	var squash := 0.17*sin(PI*clampf(t/0.19,0.0,1.0)) + 0.08*sin(PI*clampf((t-0.87)/0.13,0.0,1.0))
	body.pose(flourish*0.65,squash/0.17,jump,flourish*0.33)
	body.position.y = 0.02 + (0.53 if rare_joy else 0.30) * jump
	body.scale = rest_scale * Vector3(1.0+squash,1.0-squash,1.0+squash)
	body.rotation = Vector3(-0.12*jump,flourish*0.55,0.15*sin(TAU*t))
	shade.scale = Vector3.ONE * (1.0-0.18*jump)


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
	if game.busy or (joy and joy.is_running()):
		return
	idle_age += delta
	body.idle(idle_age)

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
	if crystal_glow:
		crystal_glow.configure(tier,hud.prefs.reduced)
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
	crystal_glow.set_progress(float(Crystal.charge(s))/Crystal.target(s),Crystal.is_ready(s))


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
	crystal_glow.burst()
	sounds.magic()
	message.text = "Ruleta Magică"
	wheel.open()


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
