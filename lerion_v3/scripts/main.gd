extends Node3D
## Lerion V3 – etapa 1: clădiri depărtate, traseu închis de 36 de căsuțe,
## două zaruri și deplasarea lui Lerik. Recompensele, influența clădirilor și
## Super Cristalul vin în etapele 2–3 (vezi docs_v3/PLAN_CODEX_SI_TESTE.md).

## Poate fi schimbat înainte de _ready (teste) pentru a nu atinge salvarea reală.
@export var save_path: String = "user://lerion_v3_save.json"

var config: BoardConfig
var state: GameState
var dice: DiceRollService
var world: WorldBuilder
var board: BoardPath
var lerik: Lerik
var camera_rig: CameraRig
var hud: Hud

var _busy := false
var _regen_timer: Timer


func _ready() -> void:
	config = BoardConfig.create_default()
	state = GameState.new(save_path, config)
	state.load_or_create(_now())
	dice = DiceRollService.new(-1, config.dice_faces)

	world = WorldBuilder.new()
	world.name = "World"
	add_child(world)
	world.build(config, state.building_levels)

	board = BoardPath.new()
	board.name = "BoardPath"
	add_child(board)
	board.build(config)
	var errors := board.validate()
	for e in errors:
		push_error("Traseu invalid: " + e)

	lerik = Lerik.new()
	add_child(lerik)
	lerik.place_at(board.get_tile(state.board_position_index))
	lerik.stepped.connect(_on_lerik_stepped)

	camera_rig = CameraRig.new()
	add_child(camera_rig)
	camera_rig.follow_target = lerik

	hud = Hud.new()
	add_child(hud)
	hud.roll_pressed.connect(_on_roll_pressed)
	hud.zoom_pressed.connect(camera_rig.toggle_zoom)
	hud.debug_indices_toggled.connect(board.set_debug_indices_visible)
	hud.debug_refill_pressed.connect(_on_debug_refill)
	# Prima livrare: indicii căsuțelor sunt vizibili pentru verificare (butonul „# Căsuțe”).
	board.set_debug_indices_visible(true)
	hud.set_indices_button(true)

	_regen_timer = Timer.new()
	_regen_timer.wait_time = 1.0
	_regen_timer.autostart = true
	_regen_timer.timeout.connect(_on_regen_tick)
	add_child(_regen_timer)

	_refresh_hud()
	hud.set_info("Căsuța %d / %d" % [state.board_position_index, board.tile_count()])
	if state.recovered_pending_roll:
		hud.show_toast("Aruncarea întreruptă a fost păstrată")


func _now() -> int:
	return int(Time.get_unix_time_from_system())


func _refresh_hud() -> void:
	hud.set_resources(state.coins, state.crystals, state.energy, state.energy_max)
	hud.set_regen_seconds(state.seconds_to_next_energy(_now()))


func _on_roll_pressed() -> void:
	if _busy:
		lerik.fast_forward()  # a doua apăsare doar grăbește, nu aruncă din nou
		return
	var tx := state.try_begin_roll(dice, board.tile_count(), _now())
	if tx == null:
		if state.last_error == "no_energy":
			hud.show_toast("Nu mai ai energie! +1 la fiecare 5 minute")
		return
	_busy = true
	hud.set_rolling(true)
	_refresh_hud()
	await hud.animate_dice(tx.dice.die_a, tx.dice.die_b)
	var points := PackedVector3Array()
	for i in tx.move.path:
		points.append(board.get_tile(i).position)
	lerik.move_along(tx.move.path, points, BoardMovement.duration_for_steps(tx.move.steps, config.move_duration_min, config.move_duration_max))
	await lerik.move_finished
	state.finish_roll(tx.id)
	_busy = false
	hud.set_rolling(false)
	hud.set_info("%d + %d = %d  •  Căsuța %d / %d" % [tx.dice.die_a, tx.dice.die_b, tx.dice.total, tx.move.to_index, board.tile_count()])
	_refresh_hud()


func _on_lerik_stepped(tile_index: int) -> void:
	if tile_index == config.start_index:
		hud.show_toast("START! Tur complet (bonusul vine în etapa 2)", 1.2)


func _on_regen_tick() -> void:
	if state.update_energy_regen(_now()):
		state.save()
	_refresh_hud()


func _on_debug_refill() -> void:
	state.energy = state.energy_max
	state.save()
	_refresh_hud()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if state != null:
			state.save()
