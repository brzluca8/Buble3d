extends SceneTree
## Captură de ecran a scenei principale (pentru verificare vizuală, nu face parte din joc).
## Utilizare: godot --path . --script res://tools/capture.gd -- <ieșire.png> [overview|zoom|roll] [indici:on|off]

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://captura.png"
	var mode := args[1] if args.size() > 1 else "overview"
	var indices := args[2] if args.size() > 2 else "on"
	var main: Node = load("res://main.tscn").instantiate()
	main.set("save_path", "user://capture_save.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://capture_save.json"))
	root.add_child(main)
	for i in 10:
		await process_frame
	main.board.set_debug_indices_visible(indices == "on")
	main.hud.set_indices_button(indices == "on")
	if mode == "zoom" or mode == "roll":
		if mode == "zoom":
			main.camera_rig.toggle_zoom()
		main._on_roll_pressed()
		await main.lerik.move_finished
	for i in 60:
		await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	img.save_png(out)
	print("Captură salvată: ", out, " ", img.get_size())
	quit()
