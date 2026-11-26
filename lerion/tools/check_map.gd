extends SceneTree
## Run after import with godot --headless --script tools/check_map.gd.

var failures := 0
var taps := 0

func _initialize() -> void:
	call_deferred("_check_map")


func _check(condition: bool, description: String) -> void:
	if not condition:
		push_error(description)
		failures += 1


func _touch(id: int, pos: Vector2, down: bool, canceled := false) -> void:
	var e := InputEventScreenTouch.new()
	e.index = id
	e.position = pos
	e.pressed = down
	e.canceled = canceled
	root.push_input(e, true)


func _drag(id: int, start: Vector2, finish: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = id
	e.position = finish
	e.relative = finish - start
	root.push_input(e, true)


func _mouse(pos: Vector2, down: bool, button: MouseButton) -> void:
	var e := InputEventMouseButton.new()
	e.position = pos
	e.button_index = button
	e.pressed = down
	root.push_input(e, true)


func _check_map() -> void:
	var map := preload("res://scenes/main.tscn").instantiate()
	map.save_prefix = "user://map_check_%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()]
	root.add_child(map)
	current_scene = map
	await process_frame
	await process_frame
	var camera = map.get_node("Camera")
	camera.map_tapped.connect(func(_point: Vector2) -> void: taps += 1)
	var plots := map.get_node("Parcele")
	var hud := map.get_node("Interfata/Bara/Mesaj") as Label
	var first_focus: Vector3 = camera.focus
	_check(plots.get_child_count() == 6, "Numărul de parcele diferă de șase.")
	for ratio in [Vector2i(720, 1280), Vector2i(720, 1600), Vector2i(768, 1024)]:
		root.size = ratio
		await process_frame
		var viewport_size := root.get_visible_rect().size
		_check(is_equal_approx(viewport_size.aspect(), Vector2(ratio).aspect()), "Raportul de ecran diferă.")
		for plot: Node3D in plots.get_children():
			var center := plot.global_position + Vector3.UP * 0.21
			var pos: Vector2 = camera.unproject_position(center)
			for side in [-1.60, 1.60]:
				var edge: Vector2 = camera.unproject_position(center + Vector3.RIGHT * float(side))
				_check(root.get_visible_rect().has_point(edge), "Contur exterior tăiat: " + plot.name)
			_touch(0, pos, true)
			_touch(0, pos, false)
			_check(map.selected_plot == plot.get_index() and map.highlight.visible, "Atingere ratată: " + plot.name)
			_check(hud.text.contains(str(plot.get_index() + 1)), "Mesaj greșit: " + plot.name)
	var outside: Vector2 = camera.unproject_position(Vector3.ZERO)
	_mouse(outside, true, MOUSE_BUTTON_LEFT)
	_mouse(outside, false, MOUSE_BUTTON_LEFT)
	_check(map.selected_plot == -1 and not map.highlight.visible, "Fântâna trebuie să anuleze selecția.")
	var pos: Vector2 = camera.unproject_position(plots.get_child(1).position + Vector3.UP * 0.21)
	_mouse(pos, true, MOUSE_BUTTON_LEFT)
	_mouse(pos, false, MOUSE_BUTTON_LEFT)
	_check(map.selected_plot == 1, "Click ratat.")
	var taps_before_gestures := taps
	var start := pos + Vector2(12, 80)
	_touch(0, start, true)
	_drag(0, start, pos)
	_touch(0, pos, false)
	_check(not first_focus.is_equal_approx(camera.focus) and map.selected_plot == 1, "Pan sau selecție accidentală după pan.")
	var distance_before: float = camera.distance
	var center: Vector2 = root.get_visible_rect().size * 0.5
	var a := center - Vector2(70, 0)
	var b := center + Vector2(70, 0)
	_touch(2, a, true)
	_touch(4, b, true)
	_drag(4, b, b + Vector2(90, 0))
	_check(camera.distance < distance_before, "Depărtarea degetelor nu a apropiat camera.")
	_drag(4, b + Vector2(90, 0), b + Vector2(40, 0))
	_check(camera.distance > camera.MIN_DISTANCE and camera.distance < distance_before, "Apropierea degetelor nu a depărtat camera.")
	_touch(4, b + Vector2(40, 0), false)
	_touch(2, a, false)
	_check(camera.distance < distance_before and map.selected_plot == 1, "Pinch sau selecție accidentală după pinch.")
	_touch(0, outside, true)
	_touch(0, outside, false, true)
	_check(map.selected_plot == 1 and taps == taps_before_gestures, "Pan, pinch sau anulare a emis un tap.")
	for button in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		for i in range(35):
			_mouse(center, true, button)
		var expected: float = camera.MIN_DISTANCE if button == MOUSE_BUTTON_WHEEL_UP else camera.MAX_DISTANCE
		_check(is_equal_approx(camera.distance, expected), "Limită zoom incorectă.")
	for direction in [-1.0, 1.0]:
		var end := center + Vector2(85, 75) * float(direction)
		for i in range(40):
			_touch(0, center, true)
			_drag(0, center, end)
			_touch(0, end, false)
		_check(is_equal_approx(absf(camera.focus.x), 3.2), "Limita laterală nu a fost atinsă.")
		_check(is_equal_approx(camera.focus.z, -4.2) or is_equal_approx(camera.focus.z, 3.5), "Limita longitudinală nu a fost atinsă.")
	print("Verificare hartă: %d erori (6 parcele × 3 formate, click, pan, pinch, anulare, limite)." % failures)
	quit(1 if failures else 0)
