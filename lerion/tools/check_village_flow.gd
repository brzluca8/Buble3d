extends SceneTree
## Uses an isolated save name, including for the restart check.
const Scene := preload("res://scenes/main.tscn")
var failures := 0
var checks := 0
var prefix := "user://flow_test_%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()]


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		push_error(description)
		failures += 1


func _start() -> Node:
	var scene := Scene.instantiate()
	scene.save_prefix = prefix
	root.add_child(scene)
	current_scene = scene
	return scene


func _click(target: Control) -> void:
	var pos := target.get_global_rect().get_center()
	for down in [true,false]:
		var e := InputEventMouseButton.new()
		e.position = pos
		e.global_position = pos
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		root.push_input(e,true)


func _tap(pos: Vector2) -> void:
	for down in [true,false]:
		var e := InputEventScreenTouch.new()
		e.index = 0
		e.position = pos
		e.pressed = down
		root.push_input(e,true)


func _native_button_tap(button: Control) -> void:
	var point := root.get_final_transform() * button.get_global_rect().get_center()
	for down in [true,false]:
		var touch := InputEventScreenTouch.new()
		touch.position = point
		touch.pressed = down
		Input.parse_input_event(touch)
		Input.flush_buffered_events()
		await process_frame


func _run() -> void:
	root.size = Vector2i(720,1280)
	var map = _start()
	await process_frame
	await process_frame
	var hud = map.hud
	var selected_pos: Vector2 = map.camera.unproject_position(map.plots.get_child(2).position + Vector3.UP * 0.21)
	_tap(selected_pos)
	await process_frame
	check(map.selected_plot == 2 and hud.confirm.visible and hud.title.text.contains("Atelierul lui Pongo"), "Prima construcție")
	_click(hud.confirm)
	await process_frame
	check(map.game.state.levels[2] == 1 and map.selected_plot == -1 and hud.reaction.visible and hud.prop.visible, "Confirmare și reacție Pongo")
	_click(hud.bag)
	check(hud.overlay.visible, "Deschidere inventar")
	_tap(selected_pos)
	check(map.selected_plot == -1, "Panoul blochează lumea")
	hud.overlay.hide()
	for slot in range(6):
		map._grant()
		for level in range(int(map.game.state.levels[slot]),3):
			var pos: Vector2 = map.camera.unproject_position(map.plots.get_child(slot).position + Vector3.UP * 0.66)
			_tap(pos)
			await process_frame
			check(map.selected_plot == slot and hud.confirm.visible and not hud.confirm.disabled, "Selecție nivel " + str(slot))
			_click(hud.confirm)
			await process_frame
			var model: Node3D = map.village.models[slot]
			check(model.visible and model.find_child("Upgrade2",true,false).visible == (level+1 >= 2) and model.find_child("Upgrade3",true,false).visible == (level+1 >= 3), "Module vizuale " + str(slot))
	check(map.game.state.levels == [3,3,3,3,3,3], "18 niveluri")
	_click(hud.arm)
	check(map.game.state.armed, "Buton armează")
	map._force(["coin","hammer","chest"])
	var before := int(map.game.state.energy)
	await _native_button_tap(hud.activate)
	_click(hud.activate)
	check(map.game.busy and map.game.state.energy == before-1 and map.game.state.last.super, "Buton, plată unică și Super")
	check(hud.cards.size() == 3 and hud.card_names[2].text == "Cufăr" and map.glow.visible, "Trei proiecții și puls")
	var seq := int(map.game.state.seq)
	root.size = Vector2i(720,1600)
	map.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	map.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	check(not map.game.busy and seq == map.game.state.seq, "Redimensionare/pauză în animație")
	await process_frame
	_click(hud.activate)
	await process_frame
	_click(hud.skip)
	check(not map.game.busy and map.game.state.energy == before-2, "Skip fără plată repetată")
	await process_frame
	_click(hud.activate)
	var wallet: Dictionary = map.game.state.wallet.duplicate()
	var symbols: Array = map.game.state.last.symbols.duplicate()
	map.free()
	map = _start()
	await process_frame
	check(not map.game.busy and map.game.state.wallet == wallet and map.game.state.last.symbols == symbols, "Reintrare în mijlocul animației")
	check(map.village.levels == [3,3,3,3,3,3], "Restaurarea modelelor")
	map._activate()
	await create_timer(1.45).timeout
	check(not map.game.busy and not map.glow.visible and not map.hud.effect.visible, "Final automat 1,25 s")
	map.free()
	for i in range(2):
		DirAccess.remove_absolute("%s.%d.json" % [prefix,i])
	print("Flux scenă: %d verificări, %d erori." % [checks,failures])
	quit(1 if failures else 0)
