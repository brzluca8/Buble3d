class_name TargetsRepository
extends RefCounted
## Ținte pentru atac și raid. Interfața grafică folosește doar aceste metode, deci implementarea
## de antrenament se poate înlocui cu una cu backend fără s-o schimbi.
##
## O țintă: {"id": int, "name": String, "levels": {clădire: etapă 0..5}, "shields": int,
##           "training": bool, "label": String}


## Ținta pentru un atac sau un raid (async).
func pick_target() -> Dictionary:
	return {}


## Lovește o clădire (async): {"blocked": bool, "levels": {...}}.
func hit(_id: int, _building: String) -> Dictionary:
	return {}
