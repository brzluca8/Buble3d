extends Node
## Strat de monetizare (autoload „Monetization").
##
## Tot jocul cere reclame și cumpărături DOAR prin acest fișier. Acum rulează în
## modul DEMO: nu există SDK, nu se plătește nimic, iar reclama este un ecran de
## test marcat clar „DEMO". Când activezi monetizarea reală, înlocuiești doar
## implementările de mai jos (vezi godot/MONETIZARE.md):
##   - reclame: plugin AdMob pentru Godot (Android) + consimțământ UMP/GDPR
##   - cumpărături: plugin-ul Google Play Billing pentru Godot
##   - verificarea achizițiilor pe server, înainte de a acorda bunuri plătite

signal rewarded_done(placement: String, ok: bool)
signal purchase_done(product_id: String, ok: bool)
signal demo_ad_requested(placement: String)   # interfața afișează ecranul DEMO

const DEMO := true

## Catalog (ID-urile trebuie să coincidă cu cele din Google Play Console).
const PRODUCTS := [
	{"id": "coins_small", "n": "Pungă de monede", "desc": "🪙 1.000", "price": "4,99 lei", "type": "consumable", "coins": 1000},
	{"id": "coins_medium", "n": "Cufăr de monede", "desc": "🪙 6.000", "price": "19,99 lei", "type": "consumable", "coins": 6000},
	{"id": "coins_large", "n": "Comoara norilor", "desc": "🪙 15.000", "price": "39,99 lei", "type": "consumable", "coins": 15000},
	{"id": "no_ads", "n": "Fără reclame", "desc": "Elimină reclamele dintre runde", "price": "14,99 lei", "type": "non_consumable"},
	{"id": "vip_month", "n": "Abonament VIP", "desc": "Venit pasiv ×2, recompense zilnice", "price": "24,99 lei / lună", "type": "subscription"},
	{"id": "season_pass", "n": "Season Pass", "desc": "Recompense premium pentru sezonul curent", "price": "29,99 lei", "type": "non_consumable"},
]

## Locuri unde jucătorul poate alege să vadă o reclamă cu recompensă.
const PLACEMENT_DOUBLE_BLAST := "double_blast"

var _pending := ""


func product(id: String) -> Dictionary:
	for p in PRODUCTS:
		if p.id == id:
			return p
	return {}


func can_show_rewarded(_placement: String) -> bool:
	return true


## Pornește o reclamă cu recompensă. Rezultatul vine prin `rewarded_done`.
func show_rewarded(placement: String) -> void:
	if _pending != "":
		return
	_pending = placement
	if DEMO:
		demo_ad_requested.emit(placement)   # interfața arată ecranul DEMO și apelează finish_demo_ad()
		return
	# TODO(monetizare): AdMob rewarded ad aici.


func finish_demo_ad(ok: bool) -> void:
	var p := _pending
	_pending = ""
	rewarded_done.emit(p, ok)


## Cumpărare. În DEMO plățile sunt dezactivate și nu se acordă nimic.
func purchase(product_id: String) -> void:
	if DEMO:
		Game.toast.emit("Plățile sunt dezactivate în versiunea DEMO")
		purchase_done.emit(product_id, false)
		return
	# TODO(monetizare): Google Play Billing, apoi verificare pe server și acordarea bunului.
