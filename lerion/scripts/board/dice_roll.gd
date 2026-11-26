extends RefCounted

static func draw(rng: RandomNumberGenerator) -> Vector2i:
	return Vector2i(rng.randi_range(1,6), rng.randi_range(1,6))


static func walk(origin: int, dice: Vector2i, count: int) -> PackedInt32Array:
	var stops := PackedInt32Array()
	for step in range(1, dice.x + dice.y + 1):
		stops.append((origin + step) % count)
	return stops
