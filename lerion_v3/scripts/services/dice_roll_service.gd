class_name DiceRollService
extends RefCounted
## Două zaruri standard, uniforme și independente (1..faces fiecare).
## Rezultatul se generează O SINGURĂ DATĂ, înainte de animație.

var faces: int = 6
var _rng := RandomNumberGenerator.new()


## seed_value >= 0 → rezultate reproductibile (teste); altfel aleator.
func _init(seed_value: int = -1, face_count: int = 6) -> void:
	faces = face_count
	if seed_value >= 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()


func roll() -> DiceRoll:
	return DiceRoll.new(_rng.randi_range(1, faces), _rng.randi_range(1, faces))
