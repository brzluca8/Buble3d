class_name MeshBuilder
extends RefCounted
## Combină primitive low-poly (cutii, cilindri, conuri, sfere) într-un singur ArrayMesh,
## cu umbrire plată și culoare pe vârf. Un mesh + un material = puține draw call-uri,
## ceea ce contează pe telefoanele Android.

var _verts := PackedVector3Array()
var _norms := PackedVector3Array()
var _cols := PackedColorArray()

static var _vc_material: StandardMaterial3D


## Materialul comun pentru toate mesh-urile cu culoare pe vârf.
static func vertex_color_material() -> StandardMaterial3D:
	if _vc_material == null:
		_vc_material = StandardMaterial3D.new()
		_vc_material.vertex_color_use_as_albedo = true
		# Culorile sunt convertite în spațiu liniar la adăugare (vezi add()), identic în
		# randerele Mobile și Compatibility.
		_vc_material.vertex_color_is_srgb = false
		_vc_material.roughness = 0.88
	return _vc_material


static func xf(pos: Vector3, rot_deg: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> Transform3D:
	var b := Basis.from_euler(Vector3(deg_to_rad(rot_deg.x), deg_to_rad(rot_deg.y), deg_to_rad(rot_deg.z)))
	return Transform3D(b.scaled(scl), pos)


func is_empty() -> bool:
	return _verts.is_empty()


## Adaugă o primitivă transformată, cu o singură culoare.
func add(mesh: PrimitiveMesh, t: Transform3D, color: Color) -> MeshBuilder:
	var arr: Array = mesh.get_mesh_arrays()
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = PackedInt32Array()
	if arr[Mesh.ARRAY_INDEX] != null:
		idx = arr[Mesh.ARRAY_INDEX]
	var count: int = idx.size() if not idx.is_empty() else v.size()
	var nb: Basis = t.basis.inverse().transposed()
	var lin := color.srgb_to_linear()
	for i in range(0, count - 2, 3):
		var i0: int = idx[i] if not idx.is_empty() else i
		var i1: int = idx[i + 1] if not idx.is_empty() else i + 1
		var i2: int = idx[i + 2] if not idx.is_empty() else i + 2
		var a: Vector3 = t * v[i0]
		var b: Vector3 = t * v[i1]
		var c: Vector3 = t * v[i2]
		var fn: Vector3 = (b - a).cross(c - a)
		if fn.length_squared() < 1e-12:
			continue
		fn = fn.normalized()
		var on: Vector3 = nb * (n[i0] + n[i1] + n[i2])
		if fn.dot(on) < 0.0:
			fn = -fn
		_verts.append(a)
		_verts.append(b)
		_verts.append(c)
		for _k in 3:
			_norms.append(fn)
			_cols.append(lin)
	return self


func box(size: Vector3, pos: Vector3, color: Color, rot_deg: Vector3 = Vector3.ZERO) -> MeshBuilder:
	var m := BoxMesh.new()
	m.size = size
	return add(m, xf(pos, rot_deg), color)


func cyl(r_top: float, r_bottom: float, h: float, pos: Vector3, color: Color, seg: int = 10, rot_deg: Vector3 = Vector3.ZERO) -> MeshBuilder:
	var m := CylinderMesh.new()
	m.top_radius = r_top
	m.bottom_radius = r_bottom
	m.height = h
	m.radial_segments = seg
	m.rings = 1
	return add(m, xf(pos, rot_deg), color)


func cone(r: float, h: float, pos: Vector3, color: Color, seg: int = 10, rot_deg: Vector3 = Vector3.ZERO) -> MeshBuilder:
	return cyl(0.0, r, h, pos, color, seg, rot_deg)


func sphere(r: float, pos: Vector3, color: Color, scl: Vector3 = Vector3.ONE, seg: int = 10, rings: int = 6) -> MeshBuilder:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = seg
	m.rings = rings
	return add(m, xf(pos, Vector3.ZERO, scl), color)


func prism(size: Vector3, pos: Vector3, color: Color, rot_deg: Vector3 = Vector3.ZERO) -> MeshBuilder:
	var m := PrismMesh.new()
	m.size = size
	return add(m, xf(pos, rot_deg), color)


func commit() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if _verts.is_empty():
		return mesh
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _verts
	arrays[Mesh.ARRAY_NORMAL] = _norms
	arrays[Mesh.ARRAY_COLOR] = _cols
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Creează un MeshInstance3D cu materialul comun (sau cu un material dat).
func make_instance(node_name: String, material: Material = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = commit()
	mi.material_override = material if material != null else vertex_color_material()
	return mi
