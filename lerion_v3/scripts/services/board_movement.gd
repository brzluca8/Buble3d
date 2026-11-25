class_name BoardMovement
extends RefCounted
## Calculul unei mutări pe bucla închisă: căsuțele parcurse, căsuța de oprire,
## trecerile peste START. Fără noduri, ușor de testat.

var from_index: int = 0
var steps: int = 0
var to_index: int = 0
## Căsuțele vizitate în ordine, FĂRĂ cea de plecare; ultima = to_index.
var path := PackedInt32Array()
## De câte ori s-a trecut peste START (inclusiv oprirea fix pe START).
var start_passes: int = 0


static func compute(from: int, step_count: int, tile_count: int, start_index: int = 0) -> BoardMovement:
	assert(tile_count > 0 and step_count >= 0)
	var m := BoardMovement.new()
	m.from_index = posmod(from, tile_count)
	m.steps = step_count
	for s in range(1, step_count + 1):
		var idx := (m.from_index + s) % tile_count
		m.path.append(idx)
		if idx == start_index:
			m.start_passes += 1
	m.to_index = (m.from_index + step_count) % tile_count
	return m


func crossed_start() -> bool:
	return start_passes > 0


## Durata animației: 1,5 s pentru 2 pași … 2,5 s pentru 12 pași.
static func duration_for_steps(step_count: int, min_d: float = 1.5, max_d: float = 2.5) -> float:
	return clampf(1.2 + 0.11 * float(step_count), min_d, max_d)
