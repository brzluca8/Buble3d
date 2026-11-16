class_name Board
extends Node3D
## Traseul din jurul insulei: 24 de pietre plutitoare, fiecare cu tipul ei de căsuță.
## Căsuța 0 („Start") este palierul scărilor din fața insulei.
## Pietrele, stâncile și capacele colorate se desenează cu MultiMesh (puține apeluri de desenare).

const RX := 8.1
const RZ := 8.5
const Z0 := 0.25

var labels: Array[Label3D] = []
var _base_y: Array[float] = []
var _mm_stone: MultiMesh
var _mm_rock: MultiMesh
var _mm_caps := {}                 # tip -> MultiMesh
var _cap_index := {}               # căsuță -> [tip, index în MultiMesh]
var _hl := -1
var _mm_top: MultiMesh
var _mm_coin: MultiMesh
## Doar căsuțele importante au iconiță permanentă (restul: inel colorat / monedă aurie).
const LABELED := ["start", "attack", "raid", "chest", "blast", "event"]
var _t := 0.0


func _ready() -> void:
	name = "Board"
	var n := Game.BOARD.size()
	_mm_stone = _multimesh(Proc.cyl(0.55, 0.5, 0.2, 20), Proc.M("ped"), n - 1, true)
	_mm_rock = _multimesh(Proc.cyl(0.46, 0.05, 0.6, 7), Proc.M("rock"), n - 1, false)
	var counts := {}
	for i in n:
		var kind: String = Game.BOARD[i]
		_cap_index[i] = [kind, counts.get(kind, 0)]
		counts[kind] = counts.get(kind, 0) + 1
	# traseu discret: capac în ton de piatră, doar un inel subțire colorat arată tipul căsuței
	for kind in counts:
		var col: Color = Game.TILE_INFO[kind][2]
		_mm_caps[kind] = _multimesh(Proc.htor(0.4, 0.035, 24, 6), Proc.mat(col, {"emit": col, "energy": 0.25, "rough": 0.4}), counts[kind], false)
	_mm_top = _multimesh(Proc.cyl(0.47, 0.47, 0.04, 20), Proc.M("stone"), n, false)
	_mm_coin = _multimesh(Proc.cyl(0.16, 0.16, 0.05, 14), Proc.M("gold"), counts.get("coins", 0), false)
	for i in n:
		_base_y.append(tile_pos(i).y)
		var lbl := Label3D.new()
		lbl.text = Game.TILE_INFO[Game.BOARD[i]][0]
		lbl.visible = Game.BOARD[i] in LABELED
		lbl.font = UiKit.font(800)
		lbl.font_size = 64
		lbl.pixel_size = 0.0058
		lbl.outline_size = 10
		lbl.outline_modulate = Color(0.1, 0.05, 0.25, 0.8)
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(lbl)
		labels.append(lbl)
	_update(0.0)


func _multimesh(mesh: Mesh, mat: Material, count: int, shadow: bool) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = count
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mm


## Poziția căsuței i (în coordonatele insulei).
func tile_pos(i: int) -> Vector3:
	var a := TAU * i / Game.BOARD.size()
	var y := -0.62 if i == 0 else -0.15 + 0.12 * sin(i * 1.7)
	return Vector3(sin(a) * RX, y, Z0 + cos(a) * RZ)


## Punctul pe care stă mascota pe căsuța i.
func stand_pos(i: int) -> Vector3:
	return tile_pos(i) + Vector3(0, 0.06, 0)


## Pozițiile prin care trece mascota de la `from` la `to` (înainte, pe traseu).
func path(from: int, to: int) -> Array:
	var out := []
	var n := Game.BOARD.size()
	var i := from
	while i != to:
		i = (i + 1) % n
		out.append(stand_pos(i))
	return out


func highlight(i: int) -> void:
	if _hl >= 0 and _hl < labels.size():
		labels[_hl].visible = Game.BOARD[_hl] in LABELED
		labels[_hl].pixel_size = 0.0058
	_hl = i
	if i >= 0:
		labels[i].visible = true
		labels[i].pixel_size = 0.009


func _process(dt: float) -> void:
	_t += dt
	_update(_t)


func _update(t: float) -> void:
	var k := 0
	var kc := 0
	for i in Game.BOARD.size():
		var p := tile_pos(i)
		p.y = _base_y[i] + (0.0 if i == 0 else sin(t * 1.2 + i) * 0.05)
		var s := 1.0 + (0.12 * absf(sin(t * 5.0)) if i == _hl else 0.0)
		var b := Basis().scaled(Vector3.ONE * s)
		if i != 0:
			_mm_stone.set_instance_transform(k, Transform3D(b, p + Vector3(0, -0.12 * s, 0)))
			_mm_rock.set_instance_transform(k, Transform3D(b, p + Vector3(0, -0.6 * s, 0)))
			k += 1
		var ci: Array = _cap_index[i]
		(_mm_caps[ci[0]] as MultiMesh).set_instance_transform(ci[1], Transform3D(b, p + Vector3(0, 0.02 * s, 0)))
		_mm_top.set_instance_transform(i, Transform3D(b, p + Vector3(0, 0.0, 0)))
		if Game.BOARD[i] == "coins":
			_mm_coin.set_instance_transform(kc, Transform3D((Basis(Vector3.UP, t * 1.5 + i) * Basis(Vector3.RIGHT, PI / 2)).scaled(Vector3.ONE * s), p + Vector3(0, 0.3 + 0.04 * sin(t * 2.0 + i), 0)))
			kc += 1
		labels[i].position = p + Vector3(0, 0.5 * s, 0)
