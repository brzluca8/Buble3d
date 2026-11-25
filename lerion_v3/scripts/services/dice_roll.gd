class_name DiceRoll
extends RefCounted
## Rezultatul unei aruncări cu două zaruri.

var die_a: int
var die_b: int
var total: int


func _init(a: int = 1, b: int = 1) -> void:
	die_a = a
	die_b = b
	total = a + b
