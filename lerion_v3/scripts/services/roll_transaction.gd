class_name RollTransaction
extends RefCounted
## O aruncare confirmată: zarurile și mutarea sunt deja salvate în GameState
## înainte de animație. Animația doar le prezintă, deci reluarea sau
## dublu-tap-ul nu pot produce o a doua aruncare.

var id: String
var dice: DiceRoll
var move: BoardMovement


func _init(tx_id: String, roll: DiceRoll, mv: BoardMovement) -> void:
	id = tx_id
	dice = roll
	move = mv
