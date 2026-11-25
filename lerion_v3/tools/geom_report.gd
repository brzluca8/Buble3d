extends SceneTree
## Raport rapid despre traseu: rulează cu  godot --headless --path . --script res://tools/geom_report.gd
func _initialize() -> void:
	var cfg := BoardConfig.create_default()
	var line := BoardPath.compute_centerline(cfg)
	var tiles := BoardPath.compute_tiles(cfg, line)
	print("Lungime buclă: %.2f  pas mediu: %.3f" % [LoopGeometry.loop_length(line), LoopGeometry.loop_length(line) / cfg.tile_count])
	for t in tiles:
		print("%2d  (%6.2f, %6.2f)  zona=%s d=%.2f" % [t.index, t.position.x, t.position.z, t.zone_building_id, t.zone_distance])
	for b in cfg.building_ids.size():
		print("spațiu %s: %.2f" % [cfg.building_ids[b], LoopGeometry.distance_to_point(line, cfg.building_positions[b]) - cfg.building_radius - cfg.road_half_width])
	print("spațiu cristal: %.2f" % (LoopGeometry.distance_to_point(line, cfg.crystal_position) - cfg.crystal_radius - cfg.road_half_width))
	print("spațiu castel: %.2f" % (LoopGeometry.distance_to_rect(line, cfg.castle_center, cfg.castle_half_extents) - cfg.road_half_width))
	print("distanța ne-locală minimă: %.2f" % LoopGeometry.min_non_local_distance(line, 4.0 * LoopGeometry.loop_length(line) / cfg.tile_count))
	print("secvența zonelor: ", BoardPath.zone_sequence(tiles))
	print("ERORI: ", BoardPath.validate_layout(cfg, line, tiles))
	quit()
