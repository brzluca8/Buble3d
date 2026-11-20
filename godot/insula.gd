extends Node3D
## Insula 1 din Buble: Orion merge pe drumul de căsuțe din jurul castelului.
## „Aruncă zarul” -> Orion sare din căsuță în căsuță. Trage ca să rotești camera, ciupește sau rotița pentru zoom.
## Totul (cer, nori, lumini, cameră, interfață) e construit din cod; pozițiile căsuțelor vin din
## data/insula1_casute.gd, generat de blender/island_prep.py.

const ISLAND_PATH := "res://insula1/insula1.tscn"  # insula 1 îmbunătățită: tot vizualul (cer, lumini, apă, efecte)
const ORION_PATH := "res://assets/models/orion.glb"
const Board := preload("res://data/insula1_casute.gd")
const GLOW_ORION := 2.2
const PURPLE := Color(0.3, 0.11, 0.43)
const HOP_TIME := 0.34  # secunde pe o săritură între căsuțe vecine
const HOP_HEIGHT := 0.7  # metri
const DIST_MIN := 5.0
const DIST_MAX := 55.0
const ISLAND_CENTRE := Vector3(0.0, -1.5, 0.0)

var tiles: Array[Vector3] = []
var orion: Node3D
var cam: Camera3D
var insula: Node3D
var rng := RandomNumberGenerator.new()

# joc
var tile_index := 0
var steps_left := 0
var hop_t := 0.0
var hop_dur := HOP_TIME
var land_t := -1.0
var laps := 0
var roll_t := -1.0
var roll_value := 0
var roll_tick := 0.0
var flash_t := -1.0

# cameră
var yaw := 0.0
var pitch := 0.85
var dist := 16.0
var focus := Vector3.ZERO
var touches := {}
var pinch_dist := 0.0
var last_input_ms := -100000

# interfață
var btn_roll: Button
var dice: Label
var info: Label
var flash: Label


func _ready() -> void:
	rng.randomize()
	tiles = Board.CASUTE
	_build_world()
	_load_models()
	_build_ui()
	focus = _orion_focus()
	_update_info()


# --------------------------------------------------------------------------- lume
func _build_world() -> void:
	# cerul, luminile, ceața și norii sunt în scena insulei (insula1/insula1.gd); aici rămâne doar camera
	cam = Camera3D.new()
	cam.fov = 40.0
	cam.far = 400.0
	add_child(cam)
	cam.make_current()


func _load_models() -> void:
	var island_scene := load(ISLAND_PATH) as PackedScene
	if island_scene:
		insula = island_scene.instantiate() as Node3D
		add_child(insula)
	var orion_scene := load(ORION_PATH) as PackedScene
	if orion_scene and not tiles.is_empty():
		orion = Node3D.new()
		add_child(orion)
		var model := orion_scene.instantiate()
		orion.add_child(model)
		_boost_emission(model, GLOW_ORION)
		orion.position = tiles[0]


func _boost_emission(n: Node, energy: float) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh:
			for i in mi.mesh.get_surface_count():
				var mat := mi.get_active_material(i)
				if mat is BaseMaterial3D and (mat as BaseMaterial3D).emission_enabled:
					var boosted := (mat as BaseMaterial3D).duplicate() as BaseMaterial3D
					boosted.emission_energy_multiplier = energy
					mi.set_surface_override_material(i, boosted)
	for c in n.get_children():
		_boost_emission(c, energy)


# --------------------------------------------------------------------------- interfață
func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	var title := _label("Insula 1", 54, 14)
	_place(title, 0.0, 30.0, 110.0)
	root.add_child(title)
	info = _label("", 24, 8)
	_place(info, 0.0, 104.0, 144.0)
	root.add_child(info)
	dice = _label("", 120, 22)
	_place(dice, 0.0, 170.0, 330.0)
	root.add_child(dice)
	flash = _label("", 44, 12)
	_place(flash, 0.0, 330.0, 400.0)
	root.add_child(flash)

	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 14)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(bar, 1.0, -190.0, -96.0)
	root.add_child(bar)
	btn_roll = _button("Aruncă zarul", bar, _on_roll, Vector2(330.0, 94.0), 34)
	_button("Orion", bar, _on_orion, Vector2(170.0, 94.0), 26)

	var hint := _label("trage ca să rotești · ciupește sau rotița pentru zoom", 20, 6)
	_place(hint, 1.0, -72.0, -30.0)
	root.add_child(hint)


func _label(text: String, size: int, outline: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	l.add_theme_color_override("font_outline_color", PURPLE)
	l.add_theme_constant_override("outline_size", outline)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _place(c: Control, anchor_y: float, top: float, bottom: float) -> void:
	# bandă pe toată lățimea, ancorată sus (anchor_y = 0) sau jos (anchor_y = 1)
	c.anchor_left = 0.0
	c.anchor_right = 1.0
	c.anchor_top = anchor_y
	c.anchor_bottom = anchor_y
	c.offset_left = 0.0
	c.offset_right = 0.0
	c.offset_top = top
	c.offset_bottom = bottom


func _button(text: String, parent: Control, callback: Callable, min_size: Vector2, font: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", font)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		var c := PURPLE.lightened(0.15 if state == "hover" else 0.0).darkened(0.2 if state == "pressed" else 0.0)
		c.a = 0.45 if state == "disabled" else 0.92
		sb.bg_color = c
		sb.set_corner_radius_all(int(min_size.y / 2.0))
		sb.content_margin_left = 16.0
		sb.content_margin_right = 16.0
		b.add_theme_stylebox_override(state, sb)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
		b.add_theme_color_override(key, Color(1.0, 1.0, 1.0))
	b.pressed.connect(callback)
	parent.add_child(b)
	return b


func _update_info() -> void:
	var where := "START" if tile_index == 0 else "căsuța %d" % tile_index
	info.text = "%s din %d · ture: %d" % [where, tiles.size(), laps]


func _on_orion() -> void:
	get_tree().change_scene_to_file("res://main.tscn")


func _on_roll() -> void:
	if roll_t >= 0.0 or steps_left > 0 or orion == null:
		return
	roll_t = 0.0
	roll_tick = 0.0
	roll_value = rng.randi_range(1, 6)
	btn_roll.disabled = true


# --------------------------------------------------------------------------- joc: zar, sărituri
func _update_roll(delta: float) -> void:
	if roll_t < 0.0:
		return
	roll_t += delta
	roll_tick -= delta
	if roll_t < 0.7:
		if roll_tick <= 0.0:  # cifrele se schimbă repede, ca un zar care se rostogolește
			dice.text = str(rng.randi_range(1, 6))
			roll_tick = 0.07
		return
	dice.text = str(roll_value)
	roll_t = -1.0
	steps_left = roll_value
	_start_hop()


func _start_hop() -> void:
	hop_t = 0.0
	var a := tiles[tile_index]
	var b := tiles[(tile_index + 1) % tiles.size()]
	hop_dur = HOP_TIME * clampf(a.distance_to(b) / Board.PAS, 1.0, 1.8)


func _update_hop(delta: float) -> void:
	if orion == null:
		return
	if land_t >= 0.0:  # mică turtire la aterizare
		land_t += delta / 0.16
		var sq := 1.0 - 0.12 * sin(clampf(land_t, 0.0, 1.0) * PI)
		orion.scale = Vector3(1.0 / sqrt(sq), sq, 1.0 / sqrt(sq))
		if land_t >= 1.0:
			land_t = -1.0
			orion.scale = Vector3.ONE
	if steps_left <= 0:
		# între aruncări, Orion se întoarce încet cu fața spre cameră
		if Time.get_ticks_msec() - last_input_ms > 300:
			orion.rotation.y = lerp_angle(orion.rotation.y, yaw, minf(1.0, delta * 3.0))
		return
	var a := tiles[tile_index]
	var b := tiles[(tile_index + 1) % tiles.size()]
	var d := b - a
	orion.rotation.y = lerp_angle(orion.rotation.y, atan2(d.x, d.z), minf(1.0, delta * 16.0))
	hop_t += delta / hop_dur
	if hop_t >= 1.0:
		tile_index = (tile_index + 1) % tiles.size()
		orion.position = tiles[tile_index]
		steps_left -= 1
		land_t = 0.0
		if insula and insula.has_method("on_landed"):
			insula.on_landed(tile_index)
		if tile_index == 0:
			laps += 1
			_flash("Tur complet!")
		_update_info()
		if steps_left > 0:
			_start_hop()
		else:
			btn_roll.disabled = false
		return
	var p := hop_t
	orion.position = a.lerp(b, p) + Vector3.UP * ((HOP_HEIGHT + maxf(0.0, d.y)) * 4.0 * p * (1.0 - p))


func _flash(text: String) -> void:
	flash.text = text
	flash_t = 0.0


# --------------------------------------------------------------------------- cameră
func _orion_focus() -> Vector3:
	if orion:
		return orion.position + Vector3(0.0, 0.7, 0.0)
	return ISLAND_CENTRE


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			touches[st.index] = st.position
		else:
			touches.erase(st.index)
		pinch_dist = _touch_spread()
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		touches[sd.index] = sd.position
		if touches.size() >= 2:
			var d := _touch_spread()
			if pinch_dist > 0.0 and d > 0.0:
				dist = clampf(dist * pinch_dist / d, DIST_MIN, DIST_MAX)
			pinch_dist = d
			last_input_ms = Time.get_ticks_msec()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			dist = clampf(dist * 0.9, DIST_MIN, DIST_MAX)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			dist = clampf(dist * 1.1, DIST_MIN, DIST_MAX)
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0 and touches.size() < 2:
			yaw -= mm.relative.x * 0.006
			pitch = clampf(pitch + mm.relative.y * 0.004, 0.3, 1.35)
			last_input_ms = Time.get_ticks_msec()
	elif event is InputEventMagnifyGesture:
		var mg := event as InputEventMagnifyGesture
		dist = clampf(dist / mg.factor, DIST_MIN, DIST_MAX)


func _touch_spread() -> float:
	if touches.size() < 2:
		return 0.0
	var pts := touches.values()
	return (pts[0] as Vector2).distance_to(pts[1] as Vector2)


func _process(delta: float) -> void:
	_update_roll(delta)
	_update_hop(delta)
	if flash_t >= 0.0:
		flash_t += delta
		flash.modulate = Color(1.0, 1.0, 1.0, clampf(2.0 - flash_t, 0.0, 1.0))
		if flash_t > 2.0:
			flash_t = -1.0
			flash.text = ""
	# camera urmărește lin pe Orion; de departe se uită la toată insula
	var z := clampf((dist - DIST_MIN) / (DIST_MAX - DIST_MIN), 0.0, 1.0)
	var want := _orion_focus().lerp(ISLAND_CENTRE, smoothstep(0.35, 0.9, z))
	focus = focus.lerp(want, minf(1.0, delta * 4.0))
	var dir := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	cam.position = focus + dir * dist
	cam.look_at(focus, Vector3.UP)
