class_name FriendsRepository
extends RefCounted
## Interfața pentru prieteni (vezi BUBLE_HANDOFF_v2.md). Interfața grafică folosește doar
## aceste metode, deci se poate trece de la DEMO la server fără s-o schimbi.
##
## Un prieten: {"id": int, "name": String, "levels": {clădire: nivel}, "island": int,
##              "online": bool, "visited_me": bool, "gift_waiting": bool}

signal changed

## Câte locuri de bule sunt în jurul globului.
const SLOTS := 6


func is_demo() -> bool:
	return true


## Lista prietenilor (async). DEMO: listă goală – nu se simulează jucători.
func list_friends() -> Array:
	return []


## Orașul unui prieten (async): {"name", "levels", "island"} sau {} dacă nu se poate.
func get_city(_id: int) -> Dictionary:
	return {}


## Lasă un cadou (async), o dată pe zi pentru fiecare prieten. kind = "coins" | "card".
func send_gift(_id: int, _kind: String) -> Dictionary:
	return {"ok": false, "msg": "Cadourile merg doar cu prieteni reali (DEMO)"}


## Anunță prietenul că i-ai vizitat orașul (async).
func notify_visit(_id: int) -> void:
	pass


## Poți lăsa cadou azi acestui prieten?
func can_gift_today(id: int) -> bool:
	var day := int(Time.get_unix_time_from_system() / 86400.0)
	return int(Game.gift_days.get(str(id), -1)) != day


func mark_gift(id: int) -> void:
	Game.gift_days[str(id)] = int(Time.get_unix_time_from_system() / 86400.0)
	Game.save_game()


## Codul tău de prieten și textul de invitație (cod + link).
func invite_code() -> String:
	return ""


func invite_text() -> String:
	return "Joacă Buble cu mine! 🫧"
