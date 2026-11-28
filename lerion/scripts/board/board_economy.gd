@tool
extends Resource
## Tile ids refer to the authored 36-tile layout. Shorter loops sample that layout.
@export var tile_types: PackedStringArray
@export var building_categories: Dictionary
@export var payouts: Dictionary
@export var start_coins := 100
const EVENTS := preload("res://scripts/economy/event_service.gd")
## Tiles never pay energy. "energy" stays a known unit only so that old receipts keep loading.
const UNITS := {"coins":["monedă","monede"], "fragments":["fragment","fragmente"],
	"build_points":["punct de construcție","puncte de construcție"],
	"energy":["energie","energie"], "quest_tokens":["jeton local","jetoane locale"]}


func authored_id(index: int, count: int) -> int:
	return roundi(float(index) * tile_types.size() / count)


func owner(index: int, count: int) -> String:
	var type := kind(index,count)
	for building: String in building_categories:
		if type != "start" and building_categories[building] == type:
			return building
	return ""


func kind(index: int, count: int) -> String:
	return tile_types[authored_id(index,count)]


func tiles_for(building: String, count: int) -> PackedInt32Array:
	var tiles := PackedInt32Array()
	for index in range(1, count):
		if owner(index, count) == building:
			tiles.append(index)
	return tiles


func amount(type: String, resource: String, level: int) -> int:
	return int(payouts[type][resource][level])


func award(index: int, count: int, level: int, rng: RandomNumberGenerator) -> Dictionary:
	if index == 0:
		return {}
	var type := kind(index, count)
	var options: Array = payouts[type].keys()
	var key: String = options[0] if options.size() == 1 else options[rng.randi_range(0, options.size() - 1)]
	return {"resource":key, "amount":amount(type, key, level)}


func unit(key: String, value: int) -> String:
	return UNITS[key][0 if value == 1 else 1]


func describe(receipt: Dictionary) -> String:
	return "+%d %s" % [receipt.amount, unit(receipt.resource, int(receipt.amount))]


func preview(building: String, level: int) -> String:
	var type: String = building_categories[building]
	if type == "event_energy":
		var heading_event := "Nivel maxim" if level == 3 else "Nivel %d → %d" % [level, level + 1]
		var now_percent := EVENTS.mill_percent(level)
		var change := "+%d%%" % now_percent if level == 3 else "+%d%% → +%d%%" % [now_percent, EVENTS.mill_percent(level + 1)]
		return "%s\nEnergia din evenimente · %s" % [heading_event, change]
	var options := PackedStringArray()
	for key: String in payouts[type]:
		var current := amount(type, key, level)
		var value := amount(type, key, mini(3, level + 1))
		var change := str(current) if level == 3 else "%d → %d" % [current, value]
		options.append("%s %s" % [change, unit(key, value)])
	var heading := "Nivel maxim" if level == 3 else "Nivel %d → %d" % [level, level + 1]
	var category: String = {"coin":"monede","crystal":"fragmente","construction":"construcție",
		"energy":"energie","magic":"magie","quest":"jetoane"}[type]
	return "%s\nToate căsuțele cu %s · %s" % [heading,category," sau ".join(options)]


# Presentation helpers (Etapa 4.3). They only read the configured tables above.

const CATEGORY_TILES := {"coin":"monede","crystal":"cristale","construction":"ciocan","magic":"magie","quest":"aventură"}


## "7 monede", "20 de monede", "1 monedă": Romanian counts take "de" from 20 upwards (and at 100, 200…).
static func count_text(value: int, one: String, many: String) -> String:
	if value == 1:
		return "1 " + one
	var rest := absi(value) % 100
	return "%d %s%s" % [value,"de " if rest >= 20 or (rest == 0 and value != 0) else "",many]


func amount_text(key: String, value: int) -> String:
	return count_text(value,UNITS[key][0],UNITS[key][1])


## Bonus paid by every tile of this building's category at `level`, e.g. "+3 puncte de construcție".
func bonus_text(building: String, level: int) -> String:
	var type: String = building_categories[building]
	if type == "event_energy":
		var percent := EVENTS.mill_percent(level)
		return "+%d%% energie din evenimente" % percent if percent > 0 else "Fără bonus de energie"
	var options := PackedStringArray()
	for key: String in payouts[type]:
		options.append("+" + amount_text(key,amount(type,key,level)))
	return " sau ".join(options)


## Where the bonus applies, read from the 36-tile layout.
func scope_text(building: String, count: int) -> String:
	var type: String = building_categories[building]
	if type == "event_energy":
		return "Se aplică energiei primite din recompensele evenimentelor."
	var tiles := tiles_for(building,count).size()
	return "Se aplică tuturor celor %d căsuțe cu %s de pe traseu." % [tiles,CATEGORY_TILES.get(type,type)]
