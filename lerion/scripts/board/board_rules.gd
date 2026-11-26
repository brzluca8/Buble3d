@tool
extends Resource

@export_range(30,36) var tile_count: int = 36
@export var energy_cost: int = 1
@export var energy_max: int = 100
@export var regeneration_seconds: int = 300
@export_range(1.5,2.5) var shortest_move: float = 1.5
@export_range(1.5,2.5) var longest_move: float = 2.5


func duration(steps: int) -> float:
	return lerpf(shortest_move, longest_move, (steps - 2) / 10.0)
