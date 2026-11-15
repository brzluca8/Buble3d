class_name NetFriendsRepository
extends FriendsRepository
## Implementarea cu serverul Buble (autoload Net + server/buble_server.py).


func is_demo() -> bool:
	return false


func list_friends() -> Array:
	await Net.load_friends()
	var out := []
	for f in Net.friends:
		var id := int(f.id)
		out.append({
			"id": id, "name": str(f.name), "levels": f.get("levels", {}), "island": int(f.get("island", 1)),
			"online": bool(f.get("online", false)),
			"visited_me": Game.friend_flags.get(str(id), {}).get("visit", false),
			"gift_waiting": Game.friend_flags.get(str(id), {}).get("gift", false),
		})
	return out


func get_city(id: int) -> Dictionary:
	for f in Net.friends:
		if int(f.id) == id:
			return {"name": str(f.name), "levels": f.get("levels", {}), "island": int(f.get("island", 1))}
	return {}


func send_gift(id: int, kind: String) -> Dictionary:
	if not can_gift_today(id):
		return {"ok": false, "msg": "Ai lăsat deja un cadou azi"}
	var body := {"to_id": id, "kind": kind}
	if kind == "card":
		var dup := ""
		for k in Game.cards:
			if Game.cards[k] >= 2:
				dup = k
				break
		if dup == "":
			return {"ok": false, "msg": "Nu ai cărți duble de dăruit"}
		body["card"] = dup
	var r: Dictionary = await Net.request(HTTPClient.METHOD_POST, "/v1/gift", body)
	if r._code != 200:
		return {"ok": false, "msg": str(r.get("error", "Cadoul nu a putut fi trimis"))}
	if kind == "card":
		Game.cards[body.card] -= 1
	mark_gift(id)
	return {"ok": true, "msg": "Cadou trimis! 🎁"}


func notify_visit(id: int) -> void:
	await Net.request(HTTPClient.METHOD_POST, "/v1/visit", {"target_id": id})


func invite_code() -> String:
	return Net.code


func invite_text() -> String:
	return "Hai în Buble! Codul meu de prieten: %s\n%s/invite/%s" % [Net.code, Net.base_url, Net.code]
