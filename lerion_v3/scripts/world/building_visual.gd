class_name BuildingVisual
extends Node3D
## O clădire pe platforma ei, cu piese care apar pe niveluri (0 = loc liber, 1..3).
## Modelele sunt low-poly procedurale care imită stilul capturii 02_PROTOTIP_GODOT_ACTUAL;
## în proiectul real se înlocuiesc cu modelele existente, fără a schimba logica.

const PLATFORM_TOP := 0.32

const WALL := Color("f3d9a4")
const WOOD := Color("8b5a2b")
const WOOD_DARK := Color("5e3b1e")
const WOOD_LIGHT := Color("c48a4e")
const RED := Color("d8423a")
const BLUE := Color("2f63c9")
const PURPLE := Color("7d4fc4")
const GOLD := Color("f4c542")
const STONE := Color("8d94a3")
const DARK := Color("2b2533")
const BRICK := Color("b5523b")
const WINDOW := Color("6fc3e8")

var building_id: String = ""
var display_name: String = ""
var level: int = 0
var radius: float = 2.3

var _label: Label3D


func setup(id: String, name_text: String, lvl: int, platform_radius: float) -> void:
	building_id = id
	display_name = name_text
	radius = platform_radius
	name = "Building_" + id
	set_level(lvl)


func set_level(lvl: int) -> void:
	level = clampi(lvl, 0, 3)
	for c in get_children():
		c.queue_free()
	_build()


func _build() -> void:
	var mb := MeshBuilder.new()
	# Platforma rotundă cu bordură (ca în captură).
	mb.cyl(radius, radius + 0.05, 0.3, Vector3(0, 0.15, 0), Color("f2c98a"), 20)
	mb.cyl(radius - 0.32, radius - 0.3, 0.32, Vector3(0, 0.16, 0), Color("e8955a"), 20)
	var model := Node3D.new()
	model.name = "Model"
	add_child(model)
	if level == 0:
		_build_empty_lot(mb)
	else:
		match building_id:
			"mina": _build_mina(mb, model)
			"moara": _build_moara(mb, model)
			"atelier": _build_atelier(mb, model)
			"laborator": _build_laborator(mb, model)
			"piata": _build_piata(mb, model)
			"han": _build_han(mb, model)
	var mi := mb.make_instance("Mesh")
	add_child(mi)
	move_child(mi, 0)

	_label = Label3D.new()
	_label.name = "Label"
	_label.text = "%s\nNivel %d/3" % [display_name, level]
	_label.font_size = 40
	_label.outline_size = 10
	_label.pixel_size = 0.013
	_label.modulate = Color("fff6dc")
	_label.outline_modulate = Color("1d2742")
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position = Vector3(0, 4.0, 0.4)
	_label.no_depth_test = true
	add_child(_label)


func _y(v: float) -> float:
	return PLATFORM_TOP + v


func _build_empty_lot(mb: MeshBuilder) -> void:
	mb.box(Vector3(0.12, 1.1, 0.12), Vector3(0, _y(0.55), 0.6), WOOD)
	mb.box(Vector3(0.95, 0.55, 0.08), Vector3(0, _y(1.05), 0.66), WOOD_LIGHT)
	mb.box(Vector3(0.42, 0.1, 0.04), Vector3(0, _y(1.05), 0.72), Color.WHITE)
	mb.box(Vector3(0.1, 0.42, 0.04), Vector3(0, _y(1.05), 0.72), Color.WHITE)
	for i in 3:
		mb.box(Vector3(1.3, 0.1, 0.24), Vector3(0.6, _y(0.05 + i * 0.1), -0.5 + i * 0.05), WOOD_LIGHT, Vector3(0, 10 * i, 0))


func _build_mina(mb: MeshBuilder, model: Node3D) -> void:
	mb.sphere(1.25, Vector3(0, _y(0.45), -0.3), STONE, Vector3(1.25, 0.95, 1.0), 9, 5)
	mb.sphere(0.75, Vector3(1.0, _y(0.3), -0.1), Color("7c8391"), Vector3.ONE, 8, 5)
	mb.sphere(0.6, Vector3(-1.05, _y(0.25), 0.0), Color("9aa1ae"), Vector3.ONE, 8, 5)
	mb.box(Vector3(0.9, 1.0, 0.25), Vector3(0, _y(0.5), 0.72), DARK)
	mb.box(Vector3(0.15, 1.25, 0.15), Vector3(-0.52, _y(0.62), 0.85), WOOD)
	mb.box(Vector3(0.15, 1.25, 0.15), Vector3(0.52, _y(0.62), 0.85), WOOD)
	mb.box(Vector3(1.35, 0.17, 0.2), Vector3(0, _y(1.28), 0.85), WOOD)
	if level >= 2:
		var cy := Color("5fd8ff")
		mb.cone(0.2, 0.7, Vector3(-0.75, _y(1.05), 0.25), cy, 6, Vector3(0, 0, 20))
		mb.cone(0.16, 0.55, Vector3(0.5, _y(1.35), 0.05), cy, 6, Vector3(0, 0, -15))
		mb.cone(0.18, 0.6, Vector3(1.1, _y(0.85), 0.35), cy, 6, Vector3(0, 0, -25))
		mb.box(Vector3(0.65, 0.35, 0.45), Vector3(1.15, _y(0.3), 1.1), WOOD)
		for sx in [-0.25, 0.25]:
			for sz in [-0.18, 0.18]:
				mb.cyl(0.11, 0.11, 0.06, Vector3(1.15 + sx, _y(0.11), 1.1 + sz), DARK, 8, Vector3(0, 0, 90))
	if level >= 3:
		mb.box(Vector3(0.07, 0.05, 1.4), Vector3(-0.25, _y(0.03), 1.45), STONE)
		mb.box(Vector3(0.07, 0.05, 1.4), Vector3(0.25, _y(0.03), 1.45), STONE)
		mb.box(Vector3(0.08, 1.2, 0.08), Vector3(-1.2, _y(0.6), 1.0), WOOD_DARK)
		mb.box(Vector3(0.22, 0.26, 0.22), Vector3(-1.2, _y(1.3), 1.0), GOLD)
		var gem := Spinner.new()
		gem.name = "BigGem"
		gem.degrees_per_second = 40.0
		gem.bob_height = 0.08
		gem.position = Vector3(0, _y(1.75), -0.3)
		var g := MeshBuilder.new()
		g.cone(0.3, 0.55, Vector3(0, 0.27, 0), Color("4fd8ff"), 6)
		g.cone(0.3, 0.4, Vector3(0, -0.2, 0), Color("2fb2e8"), 6, Vector3(180, 0, 0))
		gem.add_child(g.make_instance("Gem"))
		model.add_child(gem)


func _build_moara(mb: MeshBuilder, model: Node3D) -> void:
	mb.cyl(0.85, 1.15, 2.4, Vector3(0, _y(1.2), 0), WALL, 10)
	mb.cone(1.3, 1.2, Vector3(0, _y(3.0), 0), RED, 10)
	mb.box(Vector3(0.5, 0.8, 0.12), Vector3(0, _y(0.4), 1.08), WOOD_DARK, Vector3(-7, 0, 0))
	mb.box(Vector3(0.3, 0.35, 0.1), Vector3(0, _y(1.6), 0.93), WINDOW, Vector3(-7, 0, 0))
	if level >= 2:
		var blades := Spinner.new()
		blades.name = "Blades"
		blades.axis = Vector3.BACK
		blades.degrees_per_second = 70.0
		blades.position = Vector3(0, _y(2.3), 1.05)
		var b := MeshBuilder.new()
		b.sphere(0.18, Vector3.ZERO, WOOD_DARK)
		for k in 4:
			var ang := deg_to_rad(90.0 * k)
			var dir := Vector3(sin(ang), cos(ang), 0)
			b.box(Vector3(0.08, 1.6, 0.06), dir * 0.8, WOOD, Vector3(0, 0, -90.0 * k))
			b.box(Vector3(0.36, 1.1, 0.04), dir * 0.95 + Vector3(0, 0, 0.04), Color("f0d27a"), Vector3(0, 0, -90.0 * k))
		blades.add_child(b.make_instance("BladeMesh"))
		model.add_child(blades)
	if level >= 3:
		mb.cyl(0.03, 0.03, 0.8, Vector3(0, _y(3.9), 0), STONE, 6)
		mb.box(Vector3(0.45, 0.28, 0.04), Vector3(0.24, _y(4.15), 0), RED)
		for p in [Vector3(1.3, 0, 0.9), Vector3(-1.2, 0, 1.0), Vector3(-1.4, 0, 0.5)]:
			mb.sphere(0.24, Vector3(p.x, _y(0.2), p.z), Color("e8d3a0"), Vector3(1, 1.2, 1), 8, 4)
		for i in 4:
			mb.box(Vector3(0.08, 0.5, 0.08), Vector3(-1.6 + i * 0.35, _y(0.25), -1.3), WOOD)
		mb.box(Vector3(1.2, 0.07, 0.06), Vector3(-1.07, _y(0.38), -1.3), WOOD)


func _build_atelier(mb: MeshBuilder, _model: Node3D) -> void:
	mb.box(Vector3(1.9, 1.3, 1.6), Vector3(0, _y(0.65), 0), WALL)
	mb.prism(Vector3(2.2, 0.9, 1.8), Vector3(0, _y(1.75), 0), RED)
	mb.box(Vector3(0.5, 0.8, 0.08), Vector3(0, _y(0.4), 0.82), WOOD_DARK)
	mb.box(Vector3(0.35, 0.35, 0.06), Vector3(-0.6, _y(0.8), 0.82), WINDOW)
	if level >= 2:
		mb.box(Vector3(0.32, 0.8, 0.32), Vector3(0.55, _y(2.1), -0.3), BRICK)
		mb.box(Vector3(0.5, 0.2, 0.3), Vector3(1.3, _y(0.5), 0.9), Color("4a4f5c"))
		mb.box(Vector3(0.25, 0.3, 0.2), Vector3(1.3, _y(0.2), 0.9), WOOD_DARK)
		mb.box(Vector3(0.06, 0.06, 0.5), Vector3(1.3, _y(0.66), 0.95), WOOD, Vector3(0, 30, 0))
		mb.box(Vector3(0.18, 0.12, 0.12), Vector3(1.2, _y(0.66), 1.15), Color("3a5fa8"))
	if level >= 3:
		mb.cyl(0.3, 0.3, 0.6, Vector3(-1.25, _y(0.3), 0.75), WOOD, 8)
		mb.cyl(0.32, 0.32, 0.05, Vector3(-1.25, _y(0.45), 0.75), WOOD_DARK, 8)
		mb.cyl(0.35, 0.35, 0.06, Vector3(0, _y(1.35), 0.9), Color("5fbf4a"), 8, Vector3(90, 0, 0))
		mb.sphere(0.12, Vector3(0, _y(1.35), 0.95), GOLD)
		for i in 3:
			mb.box(Vector3(1.1, 0.08, 0.2), Vector3(1.0, _y(0.04 + i * 0.08), -0.9), WOOD_LIGHT, Vector3(0, 15 * i, 0))


func _build_laborator(mb: MeshBuilder, model: Node3D) -> void:
	mb.cyl(0.95, 1.0, 2.0, Vector3(0, _y(1.0), 0), Color("f1e0c0"), 10)
	mb.cone(1.35, 1.7, Vector3(0, _y(2.85), 0), PURPLE, 10)
	mb.box(Vector3(0.5, 0.8, 0.1), Vector3(0, _y(0.4), 0.95), Color("3d2a5c"))
	mb.box(Vector3(0.3, 0.3, 0.08), Vector3(0.5, _y(1.4), 0.82), WINDOW)
	if level >= 2:
		mb.sphere(0.42, Vector3(1.15, _y(0.32), 0.8), Color("2d2a3a"), Vector3(1, 0.8, 1))
		mb.cyl(0.33, 0.33, 0.05, Vector3(1.15, _y(0.6), 0.8), Color("7cf06a"), 10)
		for p in [Vector3(0.6, 2.5, 0.65), Vector3(-0.5, 2.9, 0.5), Vector3(0.1, 3.3, 0.45)]:
			mb.sphere(0.09, Vector3(p.x, _y(p.y), p.z), GOLD, Vector3.ONE, 6, 4)
	if level >= 3:
		mb.sphere(0.16, Vector3(0, _y(3.8), 0), GOLD)
		var orb := Spinner.new()
		orb.name = "MagicCrystal"
		orb.degrees_per_second = 60.0
		orb.bob_height = 0.15
		orb.bob_speed = 2.0
		orb.position = Vector3(-1.2, _y(1.4), 0.7)
		var g := MeshBuilder.new()
		g.cone(0.22, 0.4, Vector3(0, 0.2, 0), Color("c58cff"), 6)
		g.cone(0.22, 0.3, Vector3(0, -0.15, 0), Color("9a5ee0"), 6, Vector3(180, 0, 0))
		orb.add_child(g.make_instance("Orb"))
		model.add_child(orb)


func _build_piata(mb: MeshBuilder, _model: Node3D) -> void:
	mb.box(Vector3(2.0, 0.8, 0.9), Vector3(0, _y(0.4), 0.3), Color("a8693a"))
	for x in [-0.95, 0.95]:
		for z in [-0.2, 0.75]:
			mb.box(Vector3(0.12, 2.0, 0.12), Vector3(x, _y(1.0), z), WOOD)
	for i in 6:
		var c := RED if i % 2 == 0 else Color("fff6ea")
		mb.box(Vector3(0.36, 0.08, 1.35), Vector3(-0.9 + i * 0.36, _y(2.05), 0.3), c, Vector3(-14, 0, 0))
	mb.box(Vector3(2.0, 0.9, 0.08), Vector3(0, _y(1.45), -0.22), WOOD_DARK)
	if level >= 2:
		var cols := [Color("f28c28"), Color("6cc04a"), Color("e0443a")]
		for i in 3:
			var x := -0.6 + i * 0.6
			mb.box(Vector3(0.48, 0.25, 0.4), Vector3(x, _y(0.92), 0.4), WOOD_LIGHT)
			for k in 3:
				mb.sphere(0.1, Vector3(x - 0.12 + k * 0.12, _y(1.1), 0.4), cols[i], Vector3.ONE, 6, 4)
	if level >= 3:
		mb.cyl(0.3, 0.3, 0.6, Vector3(1.4, _y(0.3), 0.9), WOOD, 8)
		mb.cyl(0.32, 0.32, 0.05, Vector3(1.4, _y(0.45), 0.9), WOOD_DARK, 8)
		mb.cyl(0.03, 0.03, 1.6, Vector3(-1.4, _y(0.8), 0.9), WOOD_DARK, 6)
		mb.cone(0.7, 0.4, Vector3(-1.4, _y(1.75), 0.9), Color("ffd35a"), 8)
		mb.box(Vector3(0.6, 0.5, 0.5), Vector3(-1.2, _y(0.25), -0.7), WOOD_LIGHT)


func _build_han(mb: MeshBuilder, _model: Node3D) -> void:
	mb.box(Vector3(2.3, 1.5, 1.8), Vector3(0, _y(0.75), 0), WALL)
	mb.prism(Vector3(2.65, 1.0, 2.0), Vector3(0, _y(2.0), 0), BLUE)
	mb.box(Vector3(0.55, 0.9, 0.08), Vector3(0, _y(0.45), 0.92), WOOD_DARK)
	if level >= 2:
		mb.box(Vector3(0.35, 0.9, 0.35), Vector3(0.7, _y(2.4), -0.35), BRICK)
		mb.box(Vector3(0.4, 0.4, 0.06), Vector3(-0.7, _y(0.95), 0.92), WINDOW)
		mb.box(Vector3(0.4, 0.4, 0.06), Vector3(0.7, _y(0.95), 0.92), WINDOW)
		mb.box(Vector3(2.4, 0.1, 0.12), Vector3(0, _y(1.5), 0.92), WOOD)
	if level >= 3:
		for p in [Vector3(1.4, 0, 0.8), Vector3(1.45, 0, 0.2)]:
			mb.cyl(0.28, 0.28, 0.55, Vector3(p.x, _y(0.28), p.z), WOOD, 8)
			mb.cyl(0.3, 0.3, 0.05, Vector3(p.x, _y(0.42), p.z), WOOD_DARK, 8)
		mb.box(Vector3(0.1, 1.6, 0.1), Vector3(-1.45, _y(0.8), 0.9), WOOD_DARK)
		mb.box(Vector3(0.6, 0.08, 0.08), Vector3(-1.2, _y(1.55), 0.9), WOOD_DARK)
		mb.box(Vector3(0.5, 0.35, 0.05), Vector3(-1.1, _y(1.28), 0.9), GOLD)
		mb.box(Vector3(0.2, 0.25, 0.2), Vector3(0.0, _y(1.25), 1.05), Color("ffd35a"))
