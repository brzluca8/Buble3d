@tool
extends Resource
## Tile ids refer to the authored 36-tile layout. Shorter loops sample that layout.
@export var tile_types: PackedStringArray
@export var building_categories: Dictionary
@export var payouts: Dictionary
@export var start_coins := 100
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


func award(index: int, count: int, level: int, energy_room: int, rng: RandomNumberGenerator) -> Dictionary:
	if index == 0:
		return {}
	var type := kind(index, count)
	var options: Array = payouts[type].keys()
	var key: String = options[0] if options.size() == 1 else options[rng.randi_range(0, options.size() - 1)]
	var value := amount(type, key, level)
	if key == "energy":
		value = mini(value, energy_room)
	return {"resource":key, "amount":value}


func unit(key: String, value: int) -> String:
	return UNITS[key][0 if value == 1 else 1]


func describe(receipt: Dictionary) -> String:
	return "+%d %s" % [receipt.amount, unit(receipt.resource, int(receipt.amount))]


func preview(building: String, level: int) -> String:
	var type: String = building_categories[building]
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
