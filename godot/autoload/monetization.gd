extends Node
## Monetizare (autoload „Monetization") – PREGĂTITĂ, DEZACTIVATĂ în versiunea de test.
## Structura magazinului vine din res://data/shop.json: o singură monedă premium (Perle),
## prețuri afișate întreg, șanse vizibile. Nicio plată reală nu se poate face.
##
## Pentru lansare (vezi MONETIZARE_V2.md): plugin-ul oficial Google Play Billing pentru Godot
## (godotengine/godot-google-play-billing) și un plugin AdMob pentru reclame cu recompensă;
## verificarea achizițiilor pe server înainte de acordarea perlelor.

signal purchase_done(product_id: String, ok: bool)

const ENABLED := false


func shop() -> Dictionary:
	return Game.D.get("shop", {})


## Cumpără un articol cu perle (moneda din joc) – funcționează și în test, cu perlele câștigate.
func buy_with_perle(item_id: String) -> String:
	for it in shop().get("items", []):
		if it.id == item_id:
			if Game.perle < int(it.perle):
				return "Nu ai destule perle"
			Game.perle -= int(it.perle)
			var g: Dictionary = it.grant
			if g.has("energy"):
				Game.energy += int(g.energy)
			if g.has("shield"):
				Game.shields = mini(Game.shield_cap(), Game.shields + int(g.shield))
			if g.has("chest"):
				Game.add_chest(str(g.chest))
			Game.changed.emit()
			Game.save_game()
			return "Ai primit: %s" % it.name
	return ""


## Plăți reale: dezactivate.
func purchase(product_id: String) -> void:
	Game.toast.emit("Plățile sunt dezactivate în versiunea de test")
	purchase_done.emit(product_id, false)
