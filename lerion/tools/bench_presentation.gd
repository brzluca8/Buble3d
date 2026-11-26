extends SceneTree
## Run graphically with --disable-vsync --script tools/bench_presentation.gd.
## Times include presentation and the active frame cap. Use the same window size for comparisons.
const BOARD := preload("res://scenes/board.tscn")
const Legacy := preload("res://scripts/crystal/progress.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Măsurarea necesită o fereastră cu randare 3D.")
		quit(1)
		return
	root.size = Vector2i(450,800)
	print("Renderer: ",RenderingServer.get_video_adapter_name()," · ",root.size)
	for tier in range(3):
		await _sample(tier)
	quit()

func _sample(tier: int) -> void:
	var prefix := "user://lerion_bench_%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()]
	var legacy := Legacy.new(prefix)
	legacy.debug_grant()
	for i in range(6):
		legacy.upgrade(i,0)
	var map := BOARD.instantiate()
	map.save_prefix = prefix
	root.add_child(map)
	map.hud.prefs.quality = tier
	map.hud.prefs.reduced = false
	map.hud.prefs.music = false
	map.hud.prefs.sfx = false
	map.apply_preferences()
	var fixture: Dictionary = map.game.state.duplicate(true)
	fixture.board_position_index = 25
	map.game._commit(fixture)
	map._pose(25)
	map.game.rng.seed = 4829
	var durations := PackedFloat64Array()
	var calls := PackedInt32Array()
	var primitives := PackedInt32Array()
	var sum_ms := 0.0
	for frame in range(76):
		if frame == 18 or frame == 56:
			map._roll()
		var start := Time.get_ticks_usec()
		await process_frame
		await RenderingServer.frame_post_draw
		if frame < 12:
			continue
		var ms := float(Time.get_ticks_usec()-start)/1000
		durations.append(ms)
		sum_ms += ms
		calls.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		primitives.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
	durations.sort()
	calls.sort()
	primitives.sort()
	print("%s · %.1f FPS · p50 %.1f ms · p95 %.1f ms · %d apeluri · %d primitive" % [
		["Redus","Mediu","Ridicat"][tier],64000.0/sum_ms,durations[32],durations[60],calls[32],primitives[32]])
	map.free()
	for i in range(2):
		DirAccess.remove_absolute(legacy._path(i))
		DirAccess.remove_absolute(prefix+"_board_v3.%d.json" % i)
