extends Node3D
## Dirijabilul mascotei (ecran separat), după varianta din reference/lumi.html: navă în secțiune,
## cu camere luminate. Camerele se ating: Garderobă (jos-stânga), Salon (jos-dreapta),
## Seră (sus-stânga), Observator (sus-dreapta); Atelierul e la motoare (pupa).
## Mascota stă pe punte, salută și se bucură. Totul e 3D din cod; fără imagini statice.

const ROOMS := {
	"garderoba": Rect2(-3.75, 0.44, 3.0, 1.5),
	"salon": Rect2(-0.75, 0.44, 4.5, 1.5),
	"sera": Rect2(-3.75, 1.94, 3.0, 1.5),
	"observator": Rect2(-0.75, 1.94, 4.5, 1.5),
}

var env: Environment
var cam: CameraRig
var ship: Node3D
var mascot: Mascot
var props: Array[Node3D] = []
var companion: MeshInstance3D
var clouds: Array[Sprite3D] = []
var t := 0.0
var prop_speed := 14.0


func _ready() -> void:
	_environment()
	ship = Node3D.new()
	add_child(ship)
	_hull()
	_rooms()
	_deck()
	_balloon()
	_engines()
	_clouds()
	mascot = Mascot.new()
	ship.add_child(mascot)
	mascot.set_home(Vector3(0.95, 3.56, 1.1))
	mascot.scale = Vector3.ONE * 0.72
	cam = CameraRig.new()
	add_child(cam)
	cam.rival_mode = true
	cam.set_view(Vector3(0, 6.6, 0), 31.0, 4.0, -4.0, 24.0)
	cam.focus_dist = 14.0
	add_child(preload("res://scripts/ui/airship_ui.gd").new())
	Game.changed.connect(_refresh)
	_refresh()


func _environment() -> void:
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("1f4fc4")
	sm.sky_horizon_color = Color("9ccaff")
	sm.ground_horizon_color = Color("b8d8ff")
	sm.ground_bottom_color = Color("eaf5ff")
	var sky := Sky.new()
	sky.sky_material = sm
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = Game.quality != "mic"
	env.glow_intensity = 0.6
	env.glow_hdr_threshold = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color("cfe4ff")
	env.fog_density = 0.0012
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("fff0d0")
	sun.light_energy = 1.8
	sun.shadow_enabled = Game.quality != "mic"
	sun.shadow_blur = 2.0
	sun.directional_shadow_max_distance = 40.0
	add_child(sun)
	sun.look_at_from_position(Vector3(8, 14, 10), Vector3.ZERO)


func _m(c: String, o := {}) -> StandardMaterial3D:
	return Proc.mat(Color(c), o)


func _hull() -> void:
	var wood := Proc.M("brown")
	Proc.add(ship, Proc.box(7.5, 0.6, 3.3), wood, Vector3(0, 0.1, 0))
	Proc.add(ship, Proc.box(6.6, 0.45, 3.0), wood, Vector3(0, -0.4, 0))
	Proc.add(ship, Proc.box(4.4, 0.3, 2.6), wood, Vector3(0, -0.72, 0))
	Proc.add(ship, Proc.box(7.6, 0.08, 3.4), Proc.M("gold"), Vector3(0, 0.4, 0))
	# podea, tavan, pereți despărțitori
	Proc.add(ship, Proc.box(7.6, 0.12, 3.3), Proc.M("stone"), Vector3(0, 3.5, 0))
	Proc.add(ship, Proc.box(7.5, 0.12, 3.2), wood, Vector3(0, 1.94, 0))
	for x in [-3.75, -0.75, 3.75]:
		Proc.add(ship, Proc.box(0.1, 3.0, 3.2), Proc.M("cream"), Vector3(x, 1.97, 0))
	# balustrada punții
	for i in 10:
		Proc.add(ship, Proc.cyl(0.03, 0.03, 0.5, 5), Proc.M("gold"), Vector3(-3.6 + i * 0.8, 3.81, 1.65))
	Proc.add(ship, Proc.box(7.4, 0.04, 0.04), Proc.M("gold"), Vector3(0, 4.06, 1.65))


func _room_wall(r: Rect2, wall: String, glow: String) -> void:
	var c := r.get_center()
	Proc.add(ship, Proc.box(r.size.x, r.size.y, 0.1), _m(wall, {"emit": Color(glow), "energy": 0.55}), Vector3(c.x, c.y, -1.6))
	var body := StaticBody3D.new()
	body.collision_layer = RivalLayer.LAYER
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(r.size.x, r.size.y, 3.2)
	cs.shape = sh
	body.add_child(cs)
	body.position = Vector3(c.x, c.y, 0)
	ship.add_child(body)
	for k in ROOMS:
		if ROOMS[k] == r:
			body.set_meta("rival", "r:" + k)


func _rooms() -> void:
	_room_wall(ROOMS.garderoba, "d9a8ff", "9a5cff")
	_room_wall(ROOMS.salon, "ffe0b0", "ff9a40")
	_room_wall(ROOMS.sera, "b8f0c0", "40c070")
	_room_wall(ROOMS.observator, "40308a", "5a40d0")
	# Garderobă: rafturi cu piese, oglindă
	var cols := ["ff6fa8", "b07cff", "2bd4c8", "ffc83d", "7fa8ff"]
	for r in 3:
		var y: float = 0.9 + r * 0.4
		Proc.add(ship, Proc.box(2.6, 0.06, 0.4), Proc.M("brown"), Vector3(-2.25, y, -1.3))
		for i in 6:
			Proc.add(ship, Proc.box(0.28, 0.22, 0.22), _m(cols[(i + r) % 5]), Vector3(-3.3 + i * 0.42, y + 0.14, -1.3))
	Proc.add(ship, Proc.box(0.7, 1.1, 0.05), _m("cfe8ff", {"metal": 0.9, "rough": 0.05}), Vector3(-1.2, 1.1, -1.0))
	# Salon: fereastră caldă, covor, candelabru, trofee
	Proc.add(ship, Proc.box(1.4, 1.0, 0.06), Proc.M("warm"), Vector3(1.5, 1.2, -1.5))
	Proc.add(ship, Proc.box(2.6, 0.02, 1.4), Proc.M("vio"), Vector3(1.6, 0.51, 0.2))
	Proc.rot(Proc.add(ship, Proc.htor(0.4, 0.04, 24, 6), Proc.M("gold"), Vector3(1.5, 1.55, 0)), 0, 0, 0)
	for k in 6:
		Proc.add(ship, Proc.sph(0.06, 6, 4), Proc.M("warm"), Vector3(1.5 + cos(k * 1.05) * 0.4, 1.57, sin(k * 1.05) * 0.4))
	for i in 3:
		Proc.add(ship, Proc.cyl(0.12, 0.08, 0.3, 10), Proc.M("gold"), Vector3(2.6 + i * 0.35, 0.65, -1.2))
	# Seră: plante și însoțitorul
	for p in 8:
		Proc.add(ship, Proc.sph(0.26, 8, 6), Proc.M("leafA") if p % 2 else Proc.M("leafB"), Vector3(-3.3 + p * 0.3, 2.55 + (p % 3) * 0.1, 0.6))
		Proc.add(ship, Proc.sph(0.08, 6, 5), _m(cols[p % 5]), Vector3(-3.3 + p * 0.3, 2.85, 0.62))
	Proc.add(ship, Proc.box(2.6, 0.3, 0.8), Proc.M("brown"), Vector3(-2.25, 2.2, 0.6))
	companion = Proc.add(ship, Proc.sph(0.2, 16, 10), _m("bfffd8", {"emit": Color("60ffa8"), "energy": 2.5}), Vector3(-2.25, 2.85, -0.6))
	# Observator: stele și telescop
	for st in 26:
		Proc.add(ship, Proc.sph(0.035, 5, 4), Proc.M("warm"), Vector3(randf_range(-0.5, 3.5), randf_range(2.1, 3.3), -1.46))
	Proc.rot(Proc.add(ship, Proc.cyl(0.12, 0.16, 1.4, 12), Proc.M("gold"), Vector3(1.5, 2.75, 0.3)), -1.0, 0, 0.4)


func _deck() -> void:
	# seră de sticlă (stânga), turn cu cupolă ceapă (mijloc), observator violet (dreapta), turn înalt (spate)
	Proc.add(ship, Proc.cyl(1.15, 1.2, 0.25, 24), Proc.M("stone"), Vector3(-2.4, 3.69, 0))
	Proc.add(ship, Proc.hemi(1.05, 24, 10), Proc.M("glass"), Vector3(-2.4, 3.8, 0))
	Proc.add(ship, Proc.cyl(0.55, 0.6, 0.9, 20), Proc.M("cream"), Vector3(0, 4.0, 0))
	Proc.onion(ship, 0.7, 0, 4.46, 0)
	Proc.add(ship, Proc.cyl(0.95, 1.0, 0.7, 24), Proc.M("cream"), Vector3(2.5, 3.9, 0))
	Proc.add(ship, Proc.hemi(0.95, 24, 10), Proc.M("vio"), Vector3(2.5, 4.25, 0))
	Proc.rot(Proc.add(ship, Proc.cyl(0.13, 0.18, 1.5, 12), Proc.M("gold"), Vector3(2.9, 4.95, 0.5)), -0.9, 0, -0.4)
	Proc.add(ship, Proc.cyl(0.38, 0.42, 2.3, 16), Proc.M("cream"), Vector3(-3.3, 4.7, -1))
	Proc.onion(ship, 0.5, -3.3, 5.85, -1)
	Proc.flag(ship, -3.3, 6.9, -1)


func _balloon() -> void:
	var bal := Proc.add(ship, Proc.sph(1.0, 48, 24), Proc.M("teal"), Vector3(0, 9, 0))
	bal.scale = Vector3(4.6, 2.6, 2.6)
	for rb in range(-3, 4):
		var rx: float = rb * 1.2
		var rad: float = 2.6 * sqrt(1.0 - pow(rx / 4.6, 2))
		Proc.rot(Proc.add(ship, Proc.htor(rad + 0.02, 0.05, 48, 6), Proc.M("gold"), Vector3(rx, 9, 0)), 0, 0, PI / 2)
	for rx in [-2.3, 2.3]:
		var rad2: float = 2.6 * sqrt(1.0 - pow(rx / 4.6, 2))
		Proc.rot(Proc.add(ship, Proc.htor(rad2 + 0.03, 0.14, 48, 8), Proc.M("vio"), Vector3(rx, 9, 0)), 0, 0, PI / 2)
	Proc.add(ship, Proc.sph(0.2, 12, 8), Proc.M("gold"), Vector3(4.62, 9, 0))
	for f in [[0.0, 1.6, 0.6], [0.0, -1.6, -0.6]]:
		Proc.rot(Proc.add(ship, Proc.box(1.3, 1.3, 0.1), Proc.M("vio"), Vector3(-4.2, 9 + f[1], 0)), 0, 0, f[2])
	for x in [-3.0, -1.5, 0.0, 1.5, 3.0]:
		for z in [-1.2, 1.2]:
			var yb: float = 9.0 - 2.6 * sqrt(maxf(0.05, 1.0 - pow(x / 4.6, 2) - pow(z / 2.6, 2)))
			var L: float = yb - 3.56
			Proc.add(ship, Proc.cyl(0.025, 0.025, L, 5), Proc.M("brown"), Vector3(x, 3.56 + L / 2, z))


func _engines() -> void:
	for z in [-0.9, 0.9]:
		Proc.rot(Proc.add(ship, Proc.cyl(0.25, 0.3, 0.5, 12), Proc.M("gold"), Vector3(-3.95, 1.2, z)), 0, 0, PI / 2)
		var pr := Node3D.new()
		pr.position = Vector3(-4.3, 1.2, z)
		for b in 3:
			var bl := Node3D.new()
			bl.rotation.x = b * TAU / 3
			Proc.add(bl, Proc.box(0.05, 0.9, 0.2), Proc.M("gold"), Vector3(0, 0.5, 0))
			pr.add_child(bl)
		Proc.add(pr, Proc.sph(0.12, 8, 6), Proc.M("gold"))
		ship.add_child(pr)
		props.append(pr)
	# atelierul: zona motoarelor (pupa) se poate atinge
	var body := StaticBody3D.new()
	body.collision_layer = RivalLayer.LAYER
	body.collision_mask = 0
	body.set_meta("rival", "r:atelier")
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(1.4, 2.0, 3.2)
	cs.shape = sh
	body.add_child(cs)
	body.position = Vector3(-4.3, 1.2, 0)
	ship.add_child(body)


func _clouds() -> void:
	for i in 18:
		var s := Sprite3D.new()
		s.texture = load("res://art3d/cloud_%d.png" % (i % 3))
		s.pixel_size = (14.0 + randf() * 14.0) / 512.0
		s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		s.shaded = false
		s.modulate = Color(1, 1, 1, 0.75)
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if i < 10:
			s.position = Vector3(randf_range(-30, 30), randf_range(-6, -2), randf_range(-10, 14))
		else:
			s.position = Vector3(randf_range(-40, 40), randf_range(2, 12), randf_range(-44, -24))
		add_child(s)
		clouds.append(s)


func _refresh() -> void:
	var st := Game.companion_stage()
	var k := 0.6 + 0.25 * (Game.D.airship.companion.stages as Array).find(st)
	companion.scale = Vector3.ONE * k


## Plecare spre globul următor: elicele accelerează și nava pleacă.
func depart() -> void:
	prop_speed = 40.0
	mascot.joy()
	var tw := create_tween()
	tw.tween_property(ship, "position", Vector3(14, 3, 0), 1.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished


func _process(dt: float) -> void:
	t += dt
	ship.position.y = sin(t * 0.8) * 0.18 if prop_speed < 20.0 else ship.position.y
	ship.rotation.z = sin(t * 0.6) * 0.012
	for p in props:
		p.rotation.x += dt * prop_speed
	for c in clouds:
		c.position.x += dt * 0.4
		if c.position.x > 46:
			c.position.x = -46
	if companion:
		companion.position.y = 2.85 + sin(t * 2.0) * 0.08
