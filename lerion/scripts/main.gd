extends Node3D

const PLOT_RADIUS := 1.60
const PLOT_HEIGHT := 0.21
const LOCATIONS := ["nord-vest", "nord-est", "vest", "est", "sud-vest", "sud-est"]
const DEFAULT_MESSAGE := "Atinge atelierul lui Pongo, în stânga fântânii"
const Progress := preload("res://scripts/crystal/progress.gd")
var save_prefix := "user://satul_trasnitilor"
@onready var game = _open_game()
@onready var hud = $Interfata
@onready var village = $Sat
@onready var glow: OmniLight3D = $Fantana/Sclipire
var pulse: Tween
var confirmed_result: Dictionary = {}
var elapsed := 0.0
var normal_rounds := 0

@onready var camera := $Camera as Camera3D
@onready var plots := $Parcele as Node3D
@onready var message := $Interfata/Bara/Mesaj as Label
var selected_plot := -1
@onready var highlight := MeshInstance3D.new()


func _ready() -> void:
	var rim := TorusMesh.new()
	rim.inner_radius = 1.59
	rim.outer_radius = 1.73
	rim.rings = 48
	rim.ring_segments = 8
	var enamel := StandardMaterial3D.new()
	enamel.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	enamel.albedo_color = Color("#fff19a")
	rim.material = enamel
	highlight.mesh = rim
	highlight.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	highlight.hide()
	add_child(highlight)
	$Camera.map_tapped.connect(_select_at)
	if game.state.is_empty():
		hud.dock.hide()
		hud.top.hide()
		message.text = game.error
		set_process(false)
		return
	village.populate(plots, game.state.levels)
	hud.upgrade_requested.connect(_upgrade)
	hud.deselect_requested.connect(_deselect)
	hud.skip_requested.connect(_finish)
	_connect_mode()
	message.text = game.recovery_notice if not game.recovery_notice.is_empty() else _last_message()
	_refresh()


func _select_at(screen_point: Vector2) -> void:
	if game.busy or game.state.is_empty():
		return
	var building: int = village.pick(camera, screen_point)
	var hit: Variant = Plane(Vector3.UP, PLOT_HEIGHT).intersects_ray(
		camera.project_ray_origin(screen_point), camera.project_ray_normal(screen_point))
	if hit == null:
		return
	var point: Vector3 = hit
	selected_plot = building
	if building < 0:
		for plot: Node3D in plots.get_children():
			var center := plot.global_position
			if Vector2(point.x - center.x, point.z - center.z).length_squared() <= PLOT_RADIUS * PLOT_RADIUS:
				selected_plot = plot.get_index()
				break
	highlight.visible = selected_plot >= 0
	if highlight.visible:
		highlight.global_position = plots.get_child(selected_plot).global_position + Vector3.UP * 0.13
		message.text = "Locul %d · %s" % [selected_plot + 1, LOCATIONS[selected_plot]]
	else:
		message.text = _last_message()
	_refresh()

func _last_message() -> String:
	if game.state.last.is_empty():
		return DEFAULT_MESSAGE if game.state.levels[2] == 0 else "Activează cristalul pentru resurse"
	return hud.describe(game.state.last)


func _refresh() -> void:
	hud.refresh(game, selected_plot)
	if not game.error.is_empty():
		message.text = game.error


func _deselect() -> void:
	selected_plot = -1
	highlight.hide()
	message.text = _last_message()
	_refresh()


func _activate() -> void:
	if game.busy or selected_plot >= 0 or hud.overlay.visible:
		return
	var result: Dictionary = game.activate()
	if result.is_empty():
		_refresh()
		return
	confirmed_result = result
	var timing: Array = game.cfg.activation.normal_animation_target_seconds
	var duration := (float(timing[0]) + float(timing[1])) * 0.5
	glow.show()
	pulse = create_tween()
	pulse.tween_property(glow,"light_energy",2.2,0.22)
	pulse.tween_property(glow,"light_energy",0.0,maxf(0.1,duration - 0.22))
	message.text = "Super Cristal" if result.super else "Cristalul Haotic"
	hud.present(result, camera, duration)
	_refresh()


func _finish() -> void:
	if not game.busy:
		return
	if pulse:
		pulse.kill()
	glow.light_energy = 0
	glow.hide()
	hud.finish_effect()
	game.busy = false
	message.text = hud.describe(confirmed_result)
	if confirmed_result.combo == "triple" and confirmed_result.symbols[0] == "chaos":
		hud.react("pufi", "Pufi  ·  Am strănutat magie!")
	elif confirmed_result.combo == "mixed":
		hud.react("lerik", "Lerik  ·  Exact cum am… improvizat!")
	else:
		normal_rounds += 1
		if normal_rounds % 12 == 0:
			hud.react("lerik", "Lerik  ·  Am prins toate trei!")
	_refresh()


func _arm() -> void:
	if game.arm():
		message.text = "Următoarea activare folosește Super Cristal"
	_refresh()


func _upgrade(slot: int, level: int) -> void:
	if slot != selected_plot or not game.upgrade(slot, level):
		_refresh()
		return
	village.set_level(slot, level + 1)
	_deselect()
	message.text = "%s  ·  Nivel %d" % [game.cfg.buildings.positions[slot].building,level + 1]
	if slot == 3:
		hud.react("pufi", "Pufi  ·  Doar un puf de poțiune!")
	else:
		hud.react("pongo", "Pongo  ·  Degetul meu! Gata, a ieșit!")


func _grant() -> void:
	game.debug_grant()
	_refresh()


func _force(keys: Array) -> void:
	if OS.is_debug_build() and not game.busy:
		game.forced = keys.duplicate()
		message.text = "Rezultat de test pregătit"


func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= 1.0:
		elapsed = 0.0
		var old_energy := int(game.state.energy)
		game.regenerate()
		if game.state.energy != old_energy or game.state.energy < game.cfg.activation.energy_cost or not game.error.is_empty():
			_refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED and is_node_ready() and not game.state.is_empty():
		game.regenerate()
		_finish()
		_refresh()

func _open_game() -> RefCounted:
	return Progress.new(save_prefix)


func _connect_mode() -> void:
	hud.activate_requested.connect(_activate)
	hud.arm_requested.connect(_arm)
	hud.grant_requested.connect(_grant)
	hud.force_requested.connect(_force)
