extends SceneTree
## Captură de ecran: godot --path godot -s res://tests/screenshot.gd -- <fișier.png> [selecteaza|-] [distanta_camera]

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://shot.png"
	root.size = Vector2i(720, 1280)
	root.get_node("Game").save_path = "user://shot_save.json"
	root.get_node("Game").load_game()
	var main = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(main)
	for i in 30:
		await process_frame
	if args.size() > 1 and args[1] == "blast":
		var hud = main.get_children().filter(func(n): return n.has_method("show_toast"))[0]
		root.get_node("Game").blast_level = 4
		hud._open_blast()
		await process_frame
		hud.blast.nc = hud.blast.RAINBOW
		hud.blast.cc = hud.blast.BOMB
		hud.blast.mt = 0.0
	elif args.size() > 1 and args[1].begins_with("tema"):
		main.apply_theme(int(args[1].substr(4)))
	elif args.size() > 1 and args[1] in ["attack", "raid", "album", "noenergy"]:
		var hud = main.get_children().filter(func(n): return n.has_method("show_toast"))[0]
		var g = root.get_node("Game")
		g.add_cards(14)
		match args[1]:
			"attack":
				hud.play._attack_popup()
				for i in 40:
					await process_frame
				var btn = hud.play.popup.find_children("*", "Button", true, false)[0]
				btn.emit_signal("pressed")
				for i in 4:
					await process_frame
				root.get_texture().get_image().save_png(out.replace(".png", "_hit.png"))
			"raid":
				hud.play._raid_popup()
				await process_frame
				var bs = hud.play.popup.find_children("*", "Button", true, false)
				for i in 40:
					await process_frame
				bs = hud.play.popup.find_children("*", "Button", true, false)
				bs[1].emit_signal("pressed")
				for i in 30:
					await process_frame
				bs[4].emit_signal("pressed")
			"album": hud._open_modal("album")
			"noenergy": hud.play._no_energy()
	elif args.size() > 1 and args[1] != "-":
		root.get_node("Game").select(args[1])
	if args.size() > 2:
		if main.cam is Camera2D:
			main.cam.zoom = Vector2.ONE * float(args[2])
			if args.size() > 4:
				main.cam.position = Vector2(float(args[3]), float(args[4]))
		else:
			main.cam._t_dist = float(args[2])
			if args.size() > 5:
				main.cam._t_target = Vector3(float(args[3]), float(args[4]), float(args[5]))
	for i in 90:
		await process_frame
	print("STATISTICI: apeluri de desenare=%d, primitive=%d, obiecte=%d, FPS (mediu de test, nu telefon)=%d" % [
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		Performance.get_monitor(Performance.TIME_FPS)])
	root.get_texture().get_image().save_png(out)
	print("saved ", out)
	quit()
