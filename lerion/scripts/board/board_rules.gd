@tool
extends Resource

@export_range(30,36) var tile_count: int = 36
@export var energy_cost: int = 1
@export var energy_max: int = 100
## Seconds per regeneration step (initial design value: 600 = +1 energy every 10 minutes).
@export var regeneration_seconds: int = 600
@export var regen_amount: int = 1
## Technical ceiling for prize energy (wheel, events). Regeneration never fills above energy_max.
@export var energy_hard_cap: int = 9999
## Offline clock guard: remember the latest time seen and never regenerate from an earlier one.
@export var clock_mark_enabled: bool = true
@export_range(1.5,2.5) var shortest_move: float = 1.5
@export_range(1.5,2.5) var longest_move: float = 2.5


func duration(steps: int) -> float:
	return lerpf(shortest_move, longest_move, (steps - 2) / 10.0)
