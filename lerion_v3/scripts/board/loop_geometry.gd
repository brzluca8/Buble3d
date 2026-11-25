class_name LoopGeometry
extends RefCounted
## Funcții pure (fără noduri) pentru bucla închisă: netezire, eșantionare uniformă
## și verificări geometrice. Folosite atât de scenă cât și de teste.


## Spline Catmull-Rom centripet închis. Returnează o polilinie densă; primul punct = points[0].
static func catmull_rom_closed(points: PackedVector2Array, samples_per_segment: int = 16, alpha: float = 0.5) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := points.size()
	if n < 3:
		return out
	for i in n:
		var p0: Vector2 = points[(i - 1 + n) % n]
		var p1: Vector2 = points[i]
		var p2: Vector2 = points[(i + 1) % n]
		var p3: Vector2 = points[(i + 2) % n]
		var t0 := 0.0
		var t1 := t0 + pow(p0.distance_to(p1), alpha)
		var t2 := t1 + pow(p1.distance_to(p2), alpha)
		var t3 := t2 + pow(p2.distance_to(p3), alpha)
		for s in samples_per_segment:
			var t := lerpf(t1, t2, float(s) / float(samples_per_segment))
			var a1 := p0 * ((t1 - t) / (t1 - t0)) + p1 * ((t - t0) / (t1 - t0))
			var a2 := p1 * ((t2 - t) / (t2 - t1)) + p2 * ((t - t1) / (t2 - t1))
			var a3 := p2 * ((t3 - t) / (t3 - t2)) + p3 * ((t - t2) / (t3 - t2))
			var b1 := a1 * ((t2 - t) / (t2 - t0)) + a2 * ((t - t0) / (t2 - t0))
			var b2 := a2 * ((t3 - t) / (t3 - t1)) + a3 * ((t - t1) / (t3 - t1))
			out.append(b1 * ((t2 - t) / (t2 - t1)) + b2 * ((t - t1) / (t2 - t1)))
	return out


## Lungimile cumulate (închis): rezultat de mărime n+1, ultimul = lungimea totală.
static func cumulative_lengths(poly: PackedVector2Array) -> PackedFloat32Array:
	var acc := PackedFloat32Array()
	acc.append(0.0)
	var n := poly.size()
	var total := 0.0
	for i in n:
		total += poly[i].distance_to(poly[(i + 1) % n])
		acc.append(total)
	return acc


static func loop_length(poly: PackedVector2Array) -> float:
	var acc := cumulative_lengths(poly)
	return acc[acc.size() - 1]


## Eșantionează `count` puncte echidistante (după lungimea arcului) pe bucla închisă.
## Returnează {"positions": PackedVector2Array, "tangents": PackedVector2Array}.
static func sample_evenly(poly: PackedVector2Array, count: int) -> Dictionary:
	var acc := cumulative_lengths(poly)
	var total: float = acc[acc.size() - 1]
	var n := poly.size()
	var positions := PackedVector2Array()
	var tangents := PackedVector2Array()
	var seg := 0
	for k in count:
		var target := total * float(k) / float(count)
		while seg < n - 1 and acc[seg + 1] < target:
			seg += 1
		var a: Vector2 = poly[seg]
		var b: Vector2 = poly[(seg + 1) % n]
		var seg_len: float = acc[seg + 1] - acc[seg]
		var f := 0.0 if seg_len <= 0.0 else (target - acc[seg]) / seg_len
		positions.append(a.lerp(b, f))
		tangents.append((b - a).normalized())
	return {"positions": positions, "tangents": tangents}


## Numărul de auto-intersecții între segmente neadiacente ale buclei.
static func count_self_intersections(poly: PackedVector2Array) -> int:
	var n := poly.size()
	var hits := 0
	for i in n:
		var a1: Vector2 = poly[i]
		var a2: Vector2 = poly[(i + 1) % n]
		for j in range(i + 2, n):
			if i == 0 and j == n - 1:
				continue  # segmente adiacente prin închiderea buclei
			var b1: Vector2 = poly[j]
			var b2: Vector2 = poly[(j + 1) % n]
			if Geometry2D.segment_intersects_segment(a1, a2, b1, b2) != null:
				hits += 1
	return hits


## Distanța minimă de la bucla închisă la un punct.
static func distance_to_point(poly: PackedVector2Array, p: Vector2) -> float:
	var n := poly.size()
	var best := INF
	for i in n:
		var c := Geometry2D.get_closest_point_to_segment(p, poly[i], poly[(i + 1) % n])
		best = minf(best, c.distance_to(p))
	return best


## Distanța minimă de la buclă la un dreptunghi aliniat la axe (centru + jumătăți).
static func distance_to_rect(poly: PackedVector2Array, center: Vector2, half: Vector2) -> float:
	var n := poly.size()
	var best := INF
	for i in n:
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % n]
		for s in 5:
			var p := a.lerp(b, float(s) / 4.0)
			var d := ((p - center).abs() - half).max(Vector2.ZERO)
			best = minf(best, d.length())
	return best


## Cea mai mică distanță dintre două porțiuni ale drumului aflate la cel puțin `min_arc_gap`
## una de alta pe traseu. Dacă e mică, drumul „se atinge” vizual cu el însuși (ambiguu).
static func min_non_local_distance(poly: PackedVector2Array, min_arc_gap: float) -> float:
	var acc := cumulative_lengths(poly)
	var total: float = acc[acc.size() - 1]
	var n := poly.size()
	var best := INF
	for i in n:
		for j in range(i + 1, n):
			var arc: float = absf(acc[j] - acc[i])
			arc = minf(arc, total - arc)
			if arc < min_arc_gap:
				continue
			best = minf(best, poly[i].distance_to(poly[j]))
	return best
