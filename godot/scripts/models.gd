class_name Models
extends RefCounted
## Modele GLB din res://assets/models/<nume>.glb (vezi MODELS_TODO.md). Godot le importă
## automat; dacă un fișier lipsește, piesa rămâne procedurală (rezervă).

const HEIGHT := {"palat": 8.0, "obs": 5.8, "turn": 6.6, "mag": 4.1, "sera": 3.7, "mascot": 2.7}
const ISLAND_DIAMETER := 14.4
const UNSCALED := ["plaza", "piedestal"]


## Id-urile interne → numele fișierelor din handoff.
const FILE := {"obs": "observator", "mag": "magazin", "mascot": "mascota"}

static func path(k: String) -> String:
	var base := k
	var suffix := ""
	var i := k.rfind("_")
	if i > 0 and k.substr(i + 1).is_valid_int():
		base = k.substr(0, i)
		suffix = k.substr(i)
	return "res://assets/models/%s%s.glb" % [FILE.get(base, base), suffix]


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
	if k in UNSCALED:
		pass   # modelat direct în coordonatele insulei (piața, decorurile)
	elif k == "insula":
		# insula: scalată după lățime (X); originea modelului rămâne centrul insulei,
		# ca scările sau alte piese ieșite în față să nu o deplaseze.
		model.scale *= ISLAND_DIAMETER / maxf(bb.size.x, 0.001)
	else:
		model.scale *= HEIGHT.get(k, 1.0) / maxf(bb.size.y, 0.001)
		bb = subtree_aabb(model, Transform3D.IDENTITY)
		var c := bb.get_center()
		model.position -= Vector3(c.x, bb.position.y, c.z)
	_apply_textures(model)
	return wrap


## Materialele cu nume cunoscute din Blender primesc texturile triplanare ale jocului
## (piatră, pavaj, acoperiș, stâncă, iarbă), deci modelele nu au nevoie de UV-uri.
const TEXTURED := {"Piatra": "cream", "Soclu": "ped", "Pavaj": "stone", "AcoperisTurcoaz": "teal", "Stanca": "rock", "Iarba": "grass"}
## Nuanțe calde (ca în randare): piatra crem mai caldă, iarba mai bogată, stânca mai adâncă.
const TINT := {"Piatra": Color(0.95, 0.88, 0.78), "Soclu": Color(0.9, 0.82, 0.7), "Pavaj": Color(0.92, 0.84, 0.72), "Iarba": Color(0.72, 0.9, 0.55), "Stanca": Color(0.82, 0.76, 0.8), "AcoperisTurcoaz": Color(0.95, 1.0, 1.0)}

## Materialele create pe categorii (pentru temele insulelor): cheie -> [material...]
static var registry := {}

static func register(key: String, m: BaseMaterial3D) -> void:
	m.set_meta("base", m.albedo_color)
	if not registry.has(key):
		registry[key] = []
	registry[key].append(m)


static func _apply_textures(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh:
			for i in mi.mesh.get_surface_count():
				var m := mi.mesh.surface_get_material(i)
				if m == null:
					continue
				var key := m.resource_name.get_slice(".", 0)
				if key == "CascaSticla":
					# domul mascotei: aceeași sticlă Fresnel irizată ca globul
					var gm := ShaderMaterial.new()
					gm.shader = load("res://shaders/glass_globe.gdshader")
					gm.set_shader_parameter("rim_power", 2.0)
					gm.set_shader_parameter("base_alpha", 0.05)
					gm.render_priority = 2
					mi.set_surface_override_material(i, gm)
					mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				elif TEXTURED.has(key):
					var base: StandardMaterial3D = Proc.M(TEXTURED[key])
					var src := m as BaseMaterial3D
					if src:
						var copy := base.duplicate() as StandardMaterial3D
						copy.albedo_color = src.albedo_color * TINT.get(key, Color.WHITE)
						copy.roughness = src.roughness
						copy.metallic = src.metallic
						mi.set_surface_override_material(i, copy)
						register(key, copy)
					else:
						mi.set_surface_override_material(i, base)
	for c in n.get_children():
		_apply_textures(c)


## Modelul clădirii `id` la nivelul `lvl` (res://models/<id>_<lvl>.glb), la aceeași scară ca
## nivelul 5 – astfel clădirea chiar crește de la un nivel la altul. Null dacă lipsește.
static var _level_fit := {}

static func instance_level(id: String, lvl: int) -> Node3D:
	var key := "%s_%d" % [id, clampi(lvl, 1, 5)]
	if not has(key):
		return instance(id)
	if not _level_fit.has(id):
		var ref_key := "%s_5" % id if has("%s_5" % id) else id
		var ref: Node3D = (load(path(ref_key)) as PackedScene).instantiate()
		var bb := subtree_aabb(ref, Transform3D.IDENTITY)
		ref.free()
		var sc: float = HEIGHT.get(id, 1.0) / maxf(bb.size.y, 0.001)
		_level_fit[id] = [sc, bb.get_center() * sc, bb.position.y * sc]
	var fit: Array = _level_fit[id]
	var model: Node3D = (load(path(key)) as PackedScene).instantiate()
	var wrap := Node3D.new()
	wrap.name = "GLB"
	wrap.add_child(model)
	model.scale *= fit[0]
	model.position -= Vector3(fit[1].x, fit[2], fit[1].z)
	_apply_textures(model)
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
