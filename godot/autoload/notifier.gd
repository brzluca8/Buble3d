extends Node
## Notificări locale (autoload „Notifier"): doar dacă jucătorul le-a cerut (Setări),
## maximum 2 pe zi, doar pentru lucruri reale (energie plină, cufăr gata). Fără presiune.
##
## Pe Android, afișarea cere un plugin de notificări locale (vezi TESTING.md). Fără plugin,
## planificarea se calculează și se scrie în jurnal, dar nu se afișează nimic.

var planned: Array = []          # [{"kind", "in_s", "text"}]
var _plugin = null


func _ready() -> void:
	for n in ["LocalNotification", "GodotNotifications"]:
		if Engine.has_singleton(n):
			_plugin = Engine.get_singleton(n)


## Calculează notificările pentru când aplicația intră în fundal.
func plan() -> void:
	planned.clear()
	if not Game.notif_enabled:
		return
	var max_n := int(Game.cfg("notifications.max_per_day", 2))
	var full := Game.energy_full_in()
	if full > 0:
		planned.append({"kind": "energie_plina", "in_s": full, "text": "Energia e plină. Poți roti din nou."})
	var i := Game.chest_unlocking()
	if i >= 0:
		var left := int(Game.chests[i].end - Time.get_unix_time_from_system())
		if left > 0:
			planned.append({"kind": "cufar_gata", "in_s": left, "text": "Cufărul tău e gata de deschis."})
	planned.sort_custom(func(a, b): return a.in_s < b.in_s)
	planned = planned.filter(func(p): return p.in_s < 86400).slice(0, max_n)
	if _plugin and _plugin.has_method("show"):
		for p in planned:
			_plugin.show(p.text, "Buble", p.in_s, planned.find(p))
