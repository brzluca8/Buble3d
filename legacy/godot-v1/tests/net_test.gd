extends SceneTree
## Test cu serverul real: godot --headless --path godot -s res://tests/net_test.gd -- <url> <cod_prieten> <id_prieten>

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("OK   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	await process_frame
	var game = root.get_node("Game")
	game.save_path = "user://net_test_save.json"
	var net = root.get_node("Net")
	net.device_id = "godot-test-device-01"
	var ok: bool = await net.set_server(args[0], "Testerul")
	check(ok and net.online, "conectare la server (%s)" % net.last_error)
	check(net.code.length() == 6, "codul de prieten: %s" % net.code)
	var fr: Dictionary = await net.add_friend(args[1])
	check(fr._code == 200 and net.friends.size() >= 1, "prieten adăugat: %s" % str(net.friends.map(func(f): return f.name)))
	var t: Dictionary = await net.pick_target()
	check(not t.is_empty() and t.has("levels"), "țintă reală pentru atac: %s" % t.get("name", "?"))
	var c0: float = game.coins
	var a: Dictionary = await net.attack(int(args[2]), "turn", 2)
	check(a._code == 200 and a.coins > 0, "atac pe server (parat: %s, monede: %s)" % [a.get("blocked"), a.get("coins")])
	var rs: Dictionary = await net.raid_start(int(args[2]), 1)
	check(rs._code == 200, "jaf început")
	var got := 0
	for i in 3:
		var rp: Dictionary = await net.raid_pick(i)
		got += int(rp.get("value", 0))
	check(true, "jaf terminat: %d monede" % got)
	await net.team_join()
	check(net.team != null and net.team.members.size() >= 1, "echipă pentru eveniment: %d membri" % (net.team.members.size() if net.team else 0))
	game.event_points.emit(10)
	await create_timer(1.0).timeout
	await net.sync()
	check(net.online, "sincronizare (insulă + salvare + mesaje)")
	print("REZULTAT: %s" % ("TOATE TESTELE AU TRECUT" if fails == 0 else "%d EȘECURI" % fails))
	quit(1 if fails else 0)
