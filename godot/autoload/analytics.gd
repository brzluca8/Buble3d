extends Node
## Analiză (autoload „Analytics"). Interfață cu implementare înlocuibilă:
##   Analytics.log_event("spin", {"result": "sac", "mult": 2})
## Implicit: LocalBackend – scrie evenimentele în user://analytics.jsonl (nimic nu pleacă de pe telefon).
## Pentru Firebase / GameAnalytics: scrie o clasă cu metoda send(name, params) și apelează
## Analytics.set_backend(...) – restul jocului nu se schimbă. Vezi ANALYTICS.md.

const EVENTS := ["first_open", "session_start", "session_length", "spin", "level_up", "upgrade", "attack",
	"raid", "chest_open", "skill_unlock", "cosmetic_equip", "energy_empty", "debug_tool_used"]


class LocalBackend:
	var path := "user://analytics.jsonl"

	func send(name: String, params: Dictionary) -> void:
		var f := FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
		if f:
			f.seek_end()
			f.store_line(JSON.stringify({"t": int(Time.get_unix_time_from_system()), "e": name, "p": params}))


var backend = LocalBackend.new()
var enabled := true
var _session_start := 0.0
## Sesiune de test: după prima folosire a Instrumentelor de test, toate evenimentele sesiunii
## poartă "test": true, ca să poată fi excluse din statisticile reale.
var test_session := false


func _ready() -> void:
	if not FileAccess.file_exists("user://analytics_first_open"):
		FileAccess.open("user://analytics_first_open", FileAccess.WRITE)
		log_event("first_open", {})
	_session_start = Time.get_unix_time_from_system()
	log_event("session_start", {})


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		log_event("session_length", {"s": int(Time.get_unix_time_from_system() - _session_start)})


func set_backend(b) -> void:
	backend = b


func log_event(name: String, params := {}) -> void:
	if not enabled or backend == null:
		return
	if not name in EVENTS:
		push_warning("[Analytics] eveniment necunoscut: " + name)
	if test_session:
		params = params.duplicate()
		params["test"] = true
	backend.send(name, params)


## Marchează sesiunea curentă ca test (Instrumentele de test).
func mark_test_session() -> void:
	if not test_session:
		test_session = true
		log_event("session_start", {"marked_test": true})
