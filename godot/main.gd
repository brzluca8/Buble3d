extends Node3D
## Orion, mascota Buble: previzualizare în Godot 4.
## Trage (deget sau mouse) ca să rotești, ciupește sau folosește rotița pentru zoom, atinge ca Orion să sară.
## Totul (cer, lumini, platformă, cameră, butoane) e construit din cod, scena main.tscn are doar acest script.

# modelul complet; Godot îi face singur variante mai ușoare (LOD) când e mic pe ecran, deci merge și pe telefon
const MODEL_PATH := "res://models/orion_tripo_game.glb"
const GLOW_ENERGY := 2.2  # cât de tare strălucesc marcajele turcoaz
const TARGET_FAR := Vector3(0.0, 0.6, 0.0)  # privire de departe: tot corpul
const TARGET_NEAR := Vector3(0.0, 0.98, 0.0)  # zoom mare: fața
const FIT_HEIGHT := 1.95  # cât de înaltă e zona văzută la zoom 1 (Orion are 1,2 m: încape între titlu și butoane)
const FIT_WIDTH := 1.35  # și cât de lată (coada și rucsacul ies în lateral când se rotește)
const ZOOM_MIN := 0.3
const ZOOM_MAX := 1.6
const PURPLE := Color(0.3, 0.11, 0.43)

var holder: Node3D
var cam: Camera3D
var rig: Node3D
var env: Environment
var sky_mode := true

var yaw := 0.0
var pitch := 0.1
var zoom := 1.0  # 1 = tot corpul încadrat; mai mic = mai aproape
var auto_rotate := true
var last_input_ms := -100000
var touches := {}
var pinch_dist := 0.0
var press_pos := Vector2.ZERO
var press_ms := 0
var dragged := false
var hop_t := -1.0
var t := 0.0

var btn_bg: Button
var btn_rot: Button
var info: Label


func _ready() -> void:
	_build_world()
	_build_ui()
	_load_model()


# --------------------------------------------------------------------------- lume: cer, lumini, platformă, cameră
func _build_world() -> void:
	env = Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.22, 0.42, 0.86)
	sky_mat.sky_horizon_color = Color(0.72, 0.84, 0.97)
	sky_mat.ground_horizon_color = Color(0.78, 0.76, 0.92)
	sky_mat.ground_bottom_color = Color(0.36, 0.3, 0.55)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_strength = 1.0
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 0.95
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	_apply_background()
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	# luminile se rotesc odată cu camera (pe orizontală), ca Orion să fie mereu luminat din față
	rig = Node3D.new()
	add_child(rig)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-42.0, -28.0, 0.0)
	key.light_energy = 1.25
	key.light_color = Color(1.0, 0.95, 0.88)
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 16.0
	rig.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15.0, 60.0, 0.0)
	fill.light_energy = 0.35
	fill.light_color = Color(0.85, 0.9, 1.0)
	rig.add_child(fill)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-25.0, 165.0, 0.0)
	rim.light_energy = 0.8
	rim.light_color = Color(0.92, 0.86, 1.0)
	rig.add_child(rim)

	# platformă de iarbă (culoarea insulei din joc)
	var ground := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.05
	cyl.bottom_radius = 0.95
	cyl.height = 0.16
	cyl.radial_segments = 64
	ground.mesh = cyl
	ground.position = Vector3(0.0, -0.08, 0.0)
	var grass := StandardMaterial3D.new()
	grass.albedo_color = Color(0.43, 0.73, 0.33)
	grass.roughness = 0.9
	ground.material_override = grass
	add_child(ground)

	cam = Camera3D.new()
	cam.fov = 30.0
	add_child(cam)
	cam.make_current()


func _apply_background() -> void:
	if sky_mode:
		env.background_mode = Environment.BG_SKY
		env.background_energy_multiplier = 1.0
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.ambient_light_energy = 1.0
	else:  # fundal alb, ca în planșa de personaj
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(1.0, 1.0, 1.0)
		env.background_energy_multiplier = 3.0  # rămâne alb și după tonemapping
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(1.0, 1.0, 1.0)
		env.ambient_light_energy = 0.55


# --------------------------------------------------------------------------- modelul
func _load_model() -> void:
	var packed := load(MODEL_PATH) as PackedScene
	if packed == null:
		info.text = "Nu găsesc %s" % MODEL_PATH
		return
	holder = Node3D.new()
	add_child(holder)
	var model := packed.instantiate()
	holder.add_child(model)
	_boost_emission(model)


func _boost_emission(n: Node) -> void:
	# marcajele turcoaz (spirala, stelele, felinarul, lentilele) strălucesc mai tare, ca să prindă glow
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh:
			for i in mi.mesh.get_surface_count():
				var mat := mi.get_active_material(i)
				if mat is BaseMaterial3D and (mat as BaseMaterial3D).emission_enabled:
					var boosted := (mat as BaseMaterial3D).duplicate() as BaseMaterial3D
					boosted.emission_energy_multiplier = GLOW_ENERGY
					mi.set_surface_override_material(i, boosted)
	for c in n.get_children():
		_boost_emission(c)


# --------------------------------------------------------------------------- interfață
func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	var title := _label("Orion", 60, 16)
	_place(title, 0.0, 34.0, 120.0)
	root.add_child(title)
	var sub := _label("mascota Buble", 26, 8)
	_place(sub, 0.0, 112.0, 150.0)
	root.add_child(sub)
	info = _label("", 22, 6)
	_place(info, 0.0, 160.0, 200.0)
	root.add_child(info)

	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 12)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(bar, 1.0, -170.0, -92.0)
	root.add_child(bar)
	btn_bg = _button("Fundal: cer", bar, _on_bg)
	btn_rot = _button("Rotire: auto", bar, _on_rot)
	_button("Insula", bar, _on_island)

	var hint := _label("trage ca să rotești · ciupește sau rotița pentru zoom\natinge-l ca să sară", 20, 6)
	_place(hint, 1.0, -84.0, -20.0)
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


func _button(text: String, parent: Control, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(212.0, 72.0)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 23)
	for state in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		var c := PURPLE.lightened(0.15 if state == "hover" else 0.0).darkened(0.2 if state == "pressed" else 0.0)
		c.a = 0.9
		sb.bg_color = c
		sb.set_corner_radius_all(36)
		sb.content_margin_left = 14.0
		sb.content_margin_right = 14.0
		b.add_theme_stylebox_override(state, sb)
	b.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	b.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	b.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0))
	b.pressed.connect(callback)
	parent.add_child(b)
	return b


func _on_island() -> void:
	get_tree().change_scene_to_file("res://insula.tscn")


func _on_bg() -> void:
	sky_mode = not sky_mode
	_apply_background()
	btn_bg.text = "Fundal: " + ("cer" if sky_mode else "alb")


func _on_rot() -> void:
	auto_rotate = not auto_rotate
	btn_rot.text = "Rotire: " + ("auto" if auto_rotate else "oprită")


# --------------------------------------------------------------------------- control: rotire, zoom, săritură
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
			dragged = true  # a pinch is not a tap
			var d := _touch_spread()
			if pinch_dist > 0.0 and d > 0.0:
				zoom = clampf(zoom * pinch_dist / d, ZOOM_MIN, ZOOM_MAX)
			pinch_dist = d
			_touched()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			zoom = clampf(zoom * 0.9, ZOOM_MIN, ZOOM_MAX)
			_touched()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			zoom = clampf(zoom * 1.1, ZOOM_MIN, ZOOM_MAX)
			_touched()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				press_pos = mb.position
				press_ms = Time.get_ticks_msec()
				dragged = false
			elif not dragged and touches.size() < 2 and Time.get_ticks_msec() - press_ms < 350:
				_hop()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0 and touches.size() < 2:
			if mm.position.distance_to(press_pos) > 8.0:
				dragged = true
			yaw -= mm.relative.x * 0.0085
			pitch = clampf(pitch + mm.relative.y * 0.0085, -0.15, 1.1)
			_touched()
	elif event is InputEventMagnifyGesture:
		var mg := event as InputEventMagnifyGesture
		zoom = clampf(zoom / mg.factor, ZOOM_MIN, ZOOM_MAX)
		_touched()


func _touch_spread() -> float:
	if touches.size() < 2:
		return 0.0
	var pts := touches.values()
	return (pts[0] as Vector2).distance_to(pts[1] as Vector2)


func _touched() -> void:
	last_input_ms = Time.get_ticks_msec()


func _hop() -> void:
	if hop_t < 0.0:
		hop_t = 0.0


func _process(delta: float) -> void:
	t += delta
	if auto_rotate and Time.get_ticks_msec() - last_input_ms > 2500:
		yaw += delta * 0.35

	# camera pe orbită: la zoom 1 încape tot corpul, oricare ar fi forma ecranului; la zoom mare se uită spre față
	var vs := get_viewport().get_visible_rect().size
	var aspect := vs.x / maxf(vs.y, 1.0)
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	var view := 2.0 * tan(deg_to_rad(cam.fov * 0.5))  # înălțimea văzută la 1 m distanță
	var fit := maxf(FIT_HEIGHT / view, FIT_WIDTH / (view * aspect))
	var dist := fit * zoom
	var target := TARGET_NEAR.lerp(TARGET_FAR, smoothstep(0.3, 0.8, zoom))
	var dir := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	cam.position = target + dir * dist
	cam.look_at(target, Vector3.UP)
	rig.rotation.y = yaw

	# „respirație” ușoară + săritură la atingere (modelul nu are oase încă)
	if holder:
		var y := 0.0
		var sy := 1.0 + 0.012 * sin(t * 2.4)
		if hop_t >= 0.0:
			hop_t += delta
			var p := hop_t / 0.6
			if p >= 1.0:
				hop_t = -1.0
			else:
				y = 0.32 * 4.0 * p * (1.0 - p)
				sy *= 1.0 + 0.06 * sin(p * PI)
		holder.position.y = y
		var sx := 1.0 / sqrt(sy)
		holder.scale = Vector3(sx, sy, sx)
