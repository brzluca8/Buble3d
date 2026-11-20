@tool
extends Path3D
## Râul ca panglică generată dintr-un Path3D: UV.x = 0..1 pe lățime, UV.y = metri pe direcția curgerii (de la primul
## la ultimul punct al curbei). Lățimea se dă pe puncte (`latimi`, interpolată). Spumă sub poduri: `poduri` (poziții)
## ajung în COLOR.g. Curba se poate edita în editor; „Reconstruiește” refacere plasa.

@export var latimi: PackedFloat32Array = PackedFloat32Array()
@export var segmente_latime := 4
@export var pas := 0.35
@export var poduri: PackedVector3Array = PackedVector3Array()
@export var raza_spuma_pod := 1.3
@export var material: Material
@export var reconstruieste := false:
	set(v):
		if v:
			construieste()

var _mi: MeshInstance3D


func construieste() -> void:
	if curve == null or curve.point_count < 2:
		return
	var L := curve.get_baked_length()
	var n := maxi(2, int(L / pas))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols := segmente_latime + 1
	for i in n + 1:
		var d := L * float(i) / float(n)
		var p := curve.sample_baked(d, true)
		var a := curve.sample_baked(maxf(d - 0.1, 0.0), true)
		var b := curve.sample_baked(minf(d + 0.1, L), true)
		var tang := b - a
		tang.y = 0.0
		if tang.length() < 0.0001:
			tang = Vector3.FORWARD
		tang = tang.normalized()
		var lat := Vector3(-tang.z, 0.0, tang.x)
		var w := _latime(d / L)
		var spuma := 0.0
		for q in poduri:
			var dq := Vector2(q.x - p.x, q.z - p.z).length()
			spuma = maxf(spuma, clampf(1.0 - dq / raza_spuma_pod, 0.0, 1.0))
		for j in cols:
			var u := float(j) / float(segmente_latime)
			st.set_uv(Vector2(u, d))
			st.set_color(Color(0.0, spuma, 0.0, 1.0))
			st.set_normal(Vector3.UP)
			st.add_vertex(p + lat * (u - 0.5) * w)
	for i in n:
		for j in segmente_latime:
			var k := i * cols + j
			_quad(st, k, k + 1, k + cols + 1, k + cols)
	st.generate_tangents()
	if _mi == null:
		_mi = MeshInstance3D.new()
		_mi.name = "Panglica"
		_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_mi)
	_mi.mesh = st.commit()
	if material:
		_mi.material_override = material


func _latime(f: float) -> float:
	if latimi.is_empty():
		return 2.0
	var x := clampf(f, 0.0, 1.0) * float(latimi.size() - 1)
	var i := mini(int(x), latimi.size() - 2) if latimi.size() > 1 else 0
	if latimi.size() == 1:
		return latimi[0]
	return lerpf(latimi[i], latimi[i + 1], x - float(i))


# Godot desenează fața din față cu vârfurile în sensul acelor de ceas; pentru o suprafață orizontală văzută de sus,
# produsul vectorial (b - a) x (c - a) trebuie să fie în jos. Cu cull_disabled tot contează pentru normala folosită.
static func _quad(st: SurfaceTool, a: int, b: int, c: int, d: int) -> void:
	st.add_index(a)
	st.add_index(c)
	st.add_index(b)
	st.add_index(a)
	st.add_index(d)
	st.add_index(c)
