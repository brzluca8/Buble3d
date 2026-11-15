extends SceneTree
## Captură de ecran: godot --path godot -s res://tests/screenshot.gd -- <fișier.png> [selecteaza|-] [distanta_camera]

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://shot.png"
	root.size = Vector2i(720, 1280)
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
	elif args.size() > 1 and args[1] != "-":
		root.get_node("Game").select(args[1])
	if args.size() > 2:
		if main.cam is Camera2D:
			main.cam.zoom = Vector2.ONE * float(args[2])
			if args.size() > 4:
				main.cam.position = Vector2(float(args[3]), float(args[4]))
		else:
			main.cam.dist = float(args[2])
			main.cam.target = Vector3(0, 0.8, 3.5)
	for i in 60:
		await process_frame
	root.get_texture().get_image().save_png(out)
	print("saved ", out)
	quit()
