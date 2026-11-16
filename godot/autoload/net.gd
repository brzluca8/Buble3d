extends Node
## Conectarea la serverul Buble (server/buble_server.py). Autoload „Net".
## Fără adresă de server, jocul rămâne complet offline (rivalul e Contele Furtună).
## Cu server: ținte reale (prieteni, apoi jucători activi), atacuri și jafuri primite,
## salvare în cloud, cadouri de cărți și echipe de 4 pentru evenimente.

signal status_changed(online: bool)
signal friends_changed

const CFG := "user://net.cfg"
const SYNC_EVERY_S := 30.0

var base_url := ""
var token := ""
var player_id := -1
var code := ""
var player_name := "Jucător"
var device_id := ""
var online := false
var last_error := ""
var friends: Array = []
var team: Variant = null
var _timer: Timer


func _ready() -> void:
	_load_cfg()
	_timer = Timer.new()
	_timer.wait_time = SYNC_EVERY_S
	_timer.timeout.connect(sync)
	add_child(_timer)
	Game.event_points.connect(_on_event_points)
	if base_url != "":
		connect_server()


# ---------------- configurare ----------------
func _load_cfg() -> void:
	var c := ConfigFile.new()
	c.load(CFG)
	base_url = c.get_value("net", "url", "")
	device_id = c.get_value("net", "device", "")
	player_name = c.get_value("net", "name", "Jucător")
	if device_id == "":
		device_id = "%016x%016x" % [randi() << 32 | randi(), randi() << 32 | randi()]
		_save_cfg()


func _save_cfg() -> void:
	var c := ConfigFile.new()
	c.set_value("net", "url", base_url)
	c.set_value("net", "device", device_id)
	c.set_value("net", "name", player_name)
	c.save(CFG)


func set_server(url: String, name_ := "") -> bool:
	base_url = url.strip_edges().trim_suffix("/")
	if name_.strip_edges() != "":
		player_name = name_.strip_edges().left(24)
	_save_cfg()
	if base_url == "":
		_set_online(false)
		return false
	return await connect_server()


func _set_online(v: bool) -> void:
	online = v
	if v:
		_timer.start()
	else:
		_timer.stop()
	status_changed.emit(v)


# ---------------- HTTP ----------------
## Cerere JSON. Întoarce {"_code": cod, ...răspuns} sau {"_code": 0} dacă serverul nu răspunde.
func request(method: int, path: String, body: Variant = null) -> Dictionary:
	if base_url == "":
		return {"_code": 0}
	var http := HTTPRequest.new()
	http.timeout = 8.0
	add_child(http)
	var headers := PackedStringArray(["Content-Type: application/json"])
	if token != "":
		headers.append("Authorization: Bearer " + token)
	var err := http.request(base_url + path, headers, method, "" if body == null else JSON.stringify(body))
	if err != OK:
		http.queue_free()
		return {"_code": 0}
	var res: Array = await http.request_completed
	http.queue_free()
	var out: Dictionary = {}
	var parsed = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8()) if res[0] == HTTPRequest.RESULT_SUCCESS else null
	if typeof(parsed) == TYPE_DICTIONARY:
		out = parsed
	out["_code"] = res[1] if res[0] == HTTPRequest.RESULT_SUCCESS else 0
	return out


# ---------------- sesiune ----------------
func connect_server() -> bool:
	var r := await request(HTTPClient.METHOD_POST, "/v1/auth", {"device_id": device_id, "name": player_name})
	if r._code != 200:
		last_error = "Serverul nu răspunde" if r._code == 0 else str(r.get("error", r._code))
		_set_online(false)
		return false
	token = r.token
	player_id = int(r.player_id)
	code = r.code
	last_error = ""
	_set_online(true)
	await sync()
	return true


## Trimite starea insulei, salvarea și citește mesajele primite.
func sync() -> void:
	if not online:
		return
	var r := await request(HTTPClient.METHOD_PUT, "/v1/island", {
		"island": Game.globe, "levels": Game.levels, "shields": Game.shields,
		"coins": int(Game.coins), "name": player_name})
	if r._code == 0:
		_set_online(false)
		last_error = "Conexiune pierdută"
		return
	await request(HTTPClient.METHOD_PUT, "/v1/save", {"data": Game.save_dict()})
	await pull_inbox()


func pull_inbox() -> void:
	var r := await request(HTTPClient.METHOD_GET, "/v1/inbox")
	for m in r.get("messages", []):
		Game.apply_remote(m.kind, m.data)


# ---------------- prieteni și ținte ----------------
func add_friend(friend_code: String) -> Dictionary:
	var r := await request(HTTPClient.METHOD_POST, "/v1/friends", {"code": friend_code.strip_edges().to_upper()})
	if r._code == 200:
		await load_friends()
	return r


func load_friends() -> void:
	var r := await request(HTTPClient.METHOD_GET, "/v1/friends")
	friends = r.get("friends", [])
	friends_changed.emit()


## O țintă reală pentru atac / jaf: un prieten dacă există, altfel un jucător activ.
func pick_target() -> Dictionary:
	var r := await request(HTTPClient.METHOD_GET, "/v1/targets")
	var ts: Array = r.get("targets", [])
	if ts.is_empty():
		return {}
	var fr := ts.filter(func(t): return t.get("friend", false))
	var pool: Array = fr if not fr.is_empty() and randf() < 0.7 else ts
	return pool[randi() % pool.size()]


func attack(target_id: int, building: String, mult: int) -> Dictionary:
	return await request(HTTPClient.METHOD_POST, "/v1/attack", {"target_id": target_id, "building": building, "mult": mult})


func raid_start(target_id: int, mult: int) -> Dictionary:
	return await request(HTTPClient.METHOD_POST, "/v1/raid/start", {"target_id": target_id, "mult": mult})


func raid_pick(cell: int) -> Dictionary:
	return await request(HTTPClient.METHOD_POST, "/v1/raid/pick", {"cell": cell})


func gift_card(to_id: int, card_key: String) -> Dictionary:
	return await request(HTTPClient.METHOD_POST, "/v1/cards/gift", {"to_id": to_id, "card": card_key})


# ---------------- echipe ----------------
func team_join() -> void:
	var r := await request(HTTPClient.METHOD_POST, "/v1/team/join")
	team = r.get("team")


func _on_event_points(pts: int) -> void:
	if online and team != null:
		var r := await request(HTTPClient.METHOD_POST, "/v1/team/points", {"points": pts})
		team = r.get("team", team)
