class_name BoardConfig
extends Resource
## Configurația tabla V3 (traducere tipizată din docs_v3/CONFIG/lerion_board_v3.example.json).
## Coordonatele 2D sunt (x, z) pe teren: x spre dreapta ecranului, z spre cameră.
## Castelul este în spate (z negativ), START jos (z pozitiv).

@export_group("Traseu")
@export_range(30, 36) var tile_count: int = 36
@export var start_index: int = 0
## Puncte de control ale buclei închise (ordine = sensul de mers). Primul punct = START.
@export var control_points: PackedVector2Array
@export var road_half_width: float = 0.8
## Spațiu liber minim între marginea drumului și platforme / cristal / castel.
@export var min_clearance: float = 0.45
## Distanța maximă de la centrul clădirii la o căsuță din „zona” ei.
@export var zone_max_distance: float = 4.5

@export_group("Clădiri")
@export var building_ids: PackedStringArray
@export var building_names: PackedStringArray
@export var building_positions: PackedVector2Array
@export var building_radius: float = 2.3
## Ordinea în care traseul trebuie să treacă pe lângă clădiri, pornind de la START.
@export var expected_zone_order: PackedStringArray

@export_group("Obstacole fixe")
@export var crystal_position: Vector2 = Vector2.ZERO
@export var crystal_radius: float = 2.2
@export var castle_center: Vector2 = Vector2(0.0, -16.5)
@export var castle_half_extents: Vector2 = Vector2(5.8, 3.4)

@export_group("Zaruri și energie")
@export var dice_count: int = 2
@export var dice_faces: int = 6
@export var roll_energy_cost: int = 1
@export var energy_max: int = 100
@export var energy_regen_seconds: int = 300
## Folosit din etapa 2 (recompense). În etapa 1 doar se numără turele.
@export var start_pass_reward_coins: int = 100

@export_group("Deplasare")
@export var move_duration_min: float = 1.5
@export var move_duration_max: float = 2.5


static func create_default() -> BoardConfig:
	var c := BoardConfig.new()
	c.building_ids = PackedStringArray(["mina", "moara", "atelier", "laborator", "piata", "han"])
	c.building_names = PackedStringArray([
		"Mina de Cristale", "Moara Trăsnită", "Atelierul lui Pongo",
		"Laboratorul lui Pufi", "Piața Poznașă", "Hanul Aventurierilor",
	])
	# Trei clădiri pe stânga, trei pe dreapta, depărtate pentru a lăsa loc drumului.
	c.building_positions = PackedVector2Array([
		Vector2(-8.3, -7.0), Vector2(8.3, -7.0),
		Vector2(-8.3, 0.0), Vector2(8.3, 0.0),
		Vector2(-8.3, 7.0), Vector2(8.3, 7.0),
	])
	c.expected_zone_order = PackedStringArray(["han", "laborator", "moara", "mina", "atelier", "piata"])

	# Jumătatea dreaptă a buclei, de jos în sus. Drumul se apropie de fiecare clădire
	# (pe partea dinspre cristal) și iese în afară între clădiri → curbe în S.
	var right := PackedVector2Array([
		Vector2(2.9, 10.9), Vector2(4.5, 9.7), Vector2(4.0, 7.0),
		Vector2(6.0, 3.5), Vector2(3.9, 0.0), Vector2(6.0, -3.5),
		Vector2(4.0, -7.0), Vector2(4.5, -9.8), Vector2(2.7, -11.5),
	])
	var pts := PackedVector2Array([Vector2(0.0, 11.2)])
	pts.append_array(right)
	pts.append(Vector2(0.0, -11.8))
	for i in range(right.size() - 1, -1, -1):
		pts.append(Vector2(-right[i].x, right[i].y))
	c.control_points = pts
	return c


func building_index(id: String) -> int:
	return building_ids.find(id)


func building_position(id: String) -> Vector2:
	var i := building_index(id)
	return building_positions[i] if i >= 0 else Vector2.ZERO
