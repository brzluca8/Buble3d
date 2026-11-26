extends RefCounted
## Device preferences live outside the player's economy and journal.
var music := true
var sfx := true
var reduced := false
var quality := 1
var path := "user://lerion_presentation.cfg"

func read() -> void:
	var config := ConfigFile.new()
	if config.load(path) == OK:
		music = config.get_value("audio","music",true) == true
		sfx = config.get_value("audio","sfx",true) == true
		reduced = config.get_value("screen","reduced",false) == true
		var tier: Variant = config.get_value("screen","quality",1)
		quality = clampi(tier,0,2) if tier is int else 1

func write() -> Error:
	var config := ConfigFile.new()
	config.set_value("audio","music",music)
	config.set_value("audio","sfx",sfx)
	config.set_value("screen","reduced",reduced)
	config.set_value("screen","quality",quality)
	return config.save(path)
