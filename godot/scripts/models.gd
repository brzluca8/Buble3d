class_name Models
extends RefCounted
## Modele GLB din res://models/<id>.glb. Godot le importă automat; dacă un fișier
## lipsește, piesa rămâne procedurală.

const HEIGHT := {"palat": 5.5, "obs": 4.5, "turn": 5.3, "mag": 3.0, "sera": 3.0, "mascot": 1.6}
const ISLAND_DIAMETER := 14.4


static func path(k: String) -> String:
	return "res://models/%s.glb" % k


static func has(k: String) -> bool:
	return ResourceLoader.exists(path(k))


## Returnează modelul scalat și centrat (sau null). Clădiri/mascotă: după înălțime,
## cu baza pe y = 0. Insula: după diametru, originea modelului = nivelul ierbii.
static func instance(k: String) -> Node3D:
	if not has(k):
		return null
	var res = load(path(k))
	if not (res is PackedScene):
		push_warning("[Buble] %s nu este o scenă validă, folosesc varianta procedurală" % path(k))
		return null
	var model: Node = res.instantiate()
	if not (model is Node3D):
		model.queue_free()
		return null
	var wrap := Node3D.new()
	wrap.name = "GLB"
	wrap.add_child(model)
	var bb := subtree_aabb(model, Transform3D.IDENTITY)
	if bb.size == Vector3.ZERO:
		return wrap
	var s: float
	if k == "insula":
		s = ISLAND_DIAMETER / maxf(maxf(bb.size.x, bb.size.z), 0.001)
	else:
		s = HEIGHT.get(k, 1.0) / maxf(bb.size.y, 0.001)
	model.scale *= s
	bb = subtree_aabb(model, Transform3D.IDENTITY)
	var c := bb.get_center()
	model.position -= Vector3(c.x, 0.0 if k == "insula" else bb.position.y, c.z)
	return wrap


## AABB al tuturor plaselor dintr-un subarbore, în spațiul părintelui lui `n`.
static func subtree_aabb(n: Node, parent_xf: Transform3D) -> AABB:
	var xf := parent_xf
	if n is Node3D:
		xf = parent_xf * (n as Node3D).transform
	var out := AABB()
	var first := true
	if n is VisualInstance3D and not (n is Light3D):
		out = xf * (n as VisualInstance3D).get_aabb()
		first = false
	for c in n.get_children():
		var a := subtree_aabb(c, xf)
		if a.size == Vector3.ZERO and a.position == Vector3.ZERO:
			continue
		out = a if first else out.merge(a)
		first = false
	return out


## Primul AnimationPlayer din model (pentru clipurile mascotei).
static func find_anim(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var a := find_anim(c)
		if a:
			return a
	return null
