"""Bibliotecă comună pentru modelele Buble generate în Blender (4.x).

Convenții: Z în sus, fața modelului spre -Y (= +Z în Godot), baza pe z = 0.
Materialele cu nume „Piatra", „Soclu", „Pavaj", „AcoperisTurcoaz", „Stanca", „Iarba"
primesc în Godot texturi triplanare (vezi godot/scripts/models.gd), deci nu au nevoie de UV.
"""
import math
import sys

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector, noise

UP = Vector((0, 0, 1))


def args():
    return sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = 24


# ---------------------------------------------------------------- materiale
def _lin(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def rgb(h):
    return [_lin(int(h[i:i + 2], 16)) for i in (0, 2, 4)]


_MATS = {}


def mat(name, hexcol, rough=0.6, metal=0.0, emit=None, strength=1.0, alpha=1.0, coat=0.0):
    if name in _MATS:
        return _MATS[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*rgb(hexcol), 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    b.inputs["Coat Weight"].default_value = coat
    if emit:
        b.inputs["Emission Color"].default_value = (*rgb(emit), 1)
        b.inputs["Emission Strength"].default_value = strength
    if alpha < 1.0:
        b.inputs["Alpha"].default_value = alpha
        m.blend_method = "BLEND"
    _MATS[name] = m
    return m


def palette():
    """Paleta din imaginea de referință (turcoaz, violet, auriu, piatră caldă)."""
    return {
        "stone": mat("Piatra", "f1e6d2", 0.75),
        "stone_dk": mat("Soclu", "cdb898", 0.8),
        "paving": mat("Pavaj", "d9c7a3", 0.85),
        "roof": mat("AcoperisTurcoaz", "1f9e9c", 0.35, 0.25),
        "roof_dk": mat("TurcoazInchis", "157a7a", 0.4, 0.2),
        "gold": mat("Auriu", "f2b630", 0.25, 1.0),
        "violet": mat("Violet", "7442c8", 0.7),
        "violet_lt": mat("VioletDeschis", "9a68ea", 0.7),
        "glow": mat("Fereastra", "ffd27a", 0.4, emit="ffa840", strength=3.0),
        "glow_soft": mat("Lumina", "ffe2a8", 0.4, emit="ffc070", strength=1.5),
        "gem": mat("Cristal", "8ffff2", 0.1, emit="20d8c8", strength=3.0),
        "wood": mat("Lemn", "7a4a2a", 0.7),
        "wood_lt": mat("LemnDeschis", "a8703a", 0.65),
        "glass": mat("Sticla", "cfefff", 0.05, alpha=0.28),
        "leaf": mat("Frunze", "4f9e45", 0.8),
        "leaf_lt": mat("FrunzeDeschise", "6cbf55", 0.8),
        "pink": mat("Trandafir", "ff7fae", 0.7),
        "lilac": mat("Lavanda", "a77cf0", 0.7),
        "night": mat("CerInstelat", "1d1660", 0.3, emit="5b3fd0", strength=1.8),
        "rock": mat("Stanca", "8d7f92", 0.9),
        "grass": mat("Iarba", "6fbf4a", 0.9),
    }


# ---------------------------------------------------------------- obiecte
_parent = [None, False]   # (obiect părinte, coordonate locale?)


def set_parent(p, local=False):
    _parent[0] = p
    _parent[1] = local


class group:
    """Context: obiectele create înăuntru au coordonate LOCALE față de un empty nou."""

    def __init__(self, name, loc=(0, 0, 0), rot=(0, 0, 0)):
        self.g = empty(name, loc, rot)

    def __enter__(self):
        self.old = tuple(_parent)
        set_parent(self.g, True)
        return self.g

    def __exit__(self, *a):
        set_parent(*self.old)


def _done(o, m, smooth=True):
    if m is not None:
        o.data.materials.append(m)
    if smooth and o.type == "MESH":
        for p in o.data.polygons:
            p.use_smooth = True
    if _parent[0] is not None:
        if _parent[1]:
            o.parent = _parent[0]
        else:
            bpy.context.view_layer.update()
            w = o.matrix_world.copy()
            o.parent = _parent[0]
            o.matrix_world = w
    return o


def empty(name, loc=(0, 0, 0), rot=(0, 0, 0)):
    o = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(o)
    o.location = loc
    o.rotation_euler = rot
    return _done(o, None, False)


def box(size, loc, m, bevel=0.0, rot=(0, 0, 0), segs=2):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel > 0:
        b = o.modifiers.new("Bevel", "BEVEL")
        b.width = min(bevel, min(size) * 0.49)
        b.segments = segs
        b.limit_method = "NONE"
    return _done(o, m, smooth=bevel > 0)


def cyl(r, h, loc, m, seg=24, r2=None, rot=(0, 0, 0), smooth=True):
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=h, vertices=seg, location=loc, rotation=rot)
    else:
        bpy.ops.mesh.primitive_cone_add(radius1=r, radius2=r2, depth=h, vertices=seg, location=loc, rotation=rot)
    o = bpy.context.active_object
    if smooth:
        s = o.modifiers.new("Netezire", "EDGE_SPLIT")
        s.split_angle = math.radians(40)
    return _done(o, m, smooth)


def sphere(r, loc, m, scale=(1, 1, 1), seg=24, rings=12, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=rings, radius=r, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.scale = scale
    return _done(o, m)


def ico(r, loc, m, scale=(1, 1, 1), sub=1):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub, radius=r, location=loc)
    o = bpy.context.active_object
    o.scale = scale
    return _done(o, m, smooth=False)


def torus(R, r, loc, m, rot=(0, 0, 0), seg=40, sides=8, scale=(1, 1, 1), arc=None):
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, major_segments=seg, minor_segments=sides, location=(0, 0, 0))
    o = bpy.context.active_object
    if arc is not None:   # păstrează doar arcul de la +X spre +Y, de unghi `arc`
        keep(o, lambda c: math.atan2(c.y, c.x) >= -1e-3 and math.atan2(c.y, c.x) <= arc + 1e-3)
    o.location = loc
    o.rotation_euler = rot
    o.scale = scale
    return _done(o, m)


def lathe(pts, loc, m, seg=32, rot=(0, 0, 0), name="Rev", cap_bottom=False):
    """Suprafață de revoluție; pts = [(rază, z)] de jos în sus."""
    verts, faces = [], []
    for (r, z) in pts:
        for j in range(seg):
            a = 2 * math.pi * j / seg
            verts.append((math.cos(a) * r, math.sin(a) * r, z))
    for i in range(len(pts) - 1):
        for j in range(seg):
            a, b = i * seg + j, i * seg + (j + 1) % seg
            faces.append((a, b, b + seg, a + seg))
    if cap_bottom:
        faces.append(tuple(range(seg - 1, -1, -1)))
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.update()
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    o.location = loc
    o.rotation_euler = rot
    return _done(o, m)


def keep(o, pred):
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not pred(v.co)], context="VERTS")
    bm.to_mesh(o.data)
    bm.free()


def mesh_from(name, verts, faces, m, smooth=False):
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.update()
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    return _done(o, m, smooth)


# ---------------------------------------------------------------- piese de arhitectură
def onion(r, loc, P, rot=(0, 0, 0), seg=32, finial=True, mat_key="roof"):
    x, y, z = loc
    pts = [(r, 0), (r * 1.07, r * 0.3), (r * 0.98, r * 0.66), (r * 0.62, r * 0.98), (r * 0.25, r * 1.22), (0.0001, r * 1.42)]
    lathe(pts, loc, P[mat_key], seg=seg, rot=rot)
    torus(r * 1.0, r * 0.05, (x, y, z + 0.01), P["gold"], seg=seg)
    if finial:
        cyl(r * 0.05, r * 0.5, (x, y, z + r * 1.62), P["gold"], seg=8)
        sphere(r * 0.11, (x, y, z + r * 1.9), P["gold"], seg=12, rings=6)


def dome(r, loc, P, mat_key="roof", seg=32, ribs=0, h=1.0):
    x, y, z = loc
    pts = [(r * math.cos(t), r * math.sin(t) * h) for t in [i * math.pi / 2 / 10 for i in range(11)]]
    pts[-1] = (0.0001, r * h)
    lathe(pts, loc, P[mat_key], seg=seg)
    torus(r * 1.01, r * 0.045, (x, y, z + 0.01), P["gold"], seg=seg)
    for i in range(ribs):
        a = 2 * math.pi * i / ribs
        torus(r * 1.005, r * 0.022, (x, y, z), P["gold"], rot=(math.pi / 2, 0, a), seg=24, sides=5, arc=math.pi / 2, scale=(1, h, 1))


def arch_window(loc, w, h, P, face_angle=0.0, depth=0.08, glow="glow", frame=True, mullion=True):
    """Fereastră cu arc (luminată). `face_angle` rotește în jurul lui Z (0 = privește spre -Y)."""
    with group("Fereastra", loc, (0, 0, face_angle)) as g:
        box((w, depth, h - w / 2), (0, 0, -w / 4), P[glow])
        cyl(w / 2, depth, (0, 0, h / 2 - w / 2), P[glow], seg=16, rot=(math.pi / 2, 0, 0))
        if frame:
            t = 0.035
            for sx in (-1, 1):
                box((t, depth * 1.4, h - w / 2), (sx * (w / 2 + t / 2), -0.005, -w / 4), P["gold"])
            torus(w / 2 + t / 2, t * 0.6, (0, -depth * 0.55, h / 2 - w / 2), P["gold"], rot=(math.pi / 2, 0, 0), seg=16, sides=5, arc=math.pi)
            box((w + 0.12, depth * 1.8, 0.05), (0, -0.01, -h / 2), P["stone_dk"])
        if mullion:
            box((0.02, depth * 1.2, h - w / 2), (0, -depth * 0.2, -w / 4 + 0.02), P["gold"])
    return g


def door(loc, w, h, P, face_angle=0.0):
    """Ușă cu arc; `loc` = mijlocul pragului."""
    with group("Usa", loc, (0, 0, face_angle)) as g:
        box((w, 0.1, h - w / 2), (0, 0, (h - w / 2) / 2), P["wood_lt"], bevel=0.01)
        cyl(w / 2, 0.1, (0, 0, h - w / 2), P["wood_lt"], seg=16, rot=(math.pi / 2, 0, 0))
        box((w * 0.7, 0.12, h * 0.5), (0, -0.01, h * 0.33), P["glow_soft"])
        torus(w / 2 + 0.05, 0.04, (0, -0.06, h - w / 2), P["gold"], rot=(math.pi / 2, 0, 0), seg=18, sides=6, arc=math.pi)
        for sx in (-1, 1):
            box((0.08, 0.14, h - w / 2), (sx * (w / 2 + 0.04), -0.02, (h - w / 2) / 2), P["stone_dk"])
    return g


def banner(loc, w, h, P, face_angle=0.0):
    """Banner violet cu frunză aurie; `loc` = bara de sus."""
    with group("Banner", loc, (0, 0, face_angle)) as g:
        box((w, 0.03, h), (0, 0, -h / 2), P["violet"])
        mesh_from("VarfBanner", [(-w / 2, 0.015, -h), (w / 2, 0.015, -h), (0, 0.015, -h - w * 0.45), (-w / 2, -0.015, -h), (w / 2, -0.015, -h), (0, -0.015, -h - w * 0.45)],
                  [(0, 2, 1), (3, 4, 5), (0, 1, 4, 3), (1, 2, 5, 4), (2, 0, 3, 5)], P["violet"])
        cyl(0.025, w + 0.12, (0, 0, 0.02), P["gold"], seg=8, rot=(0, math.pi / 2, 0))
        leaf((0, -0.03, -h * 0.5), w * 0.32, P)
    return g


def leaf(loc, s, P, rot_y=0.0):
    x, y, z = loc
    sphere(s * 0.5, (x - s * 0.18, y, z), P["gold"], scale=(0.55, 0.12, 1.0), rot=(0, math.radians(30) + rot_y, 0), seg=12, rings=8)
    sphere(s * 0.42, (x + s * 0.2, y, z - s * 0.05), P["gold"], scale=(0.55, 0.12, 1.0), rot=(0, math.radians(-35) + rot_y, 0), seg=12, rings=8)


def flag(loc, P, h=0.9):
    x, y, z = loc
    cyl(0.025, h, (x, y, z + h / 2), P["gold"], seg=8)
    verts, faces = [], []
    n = 8
    for i in range(n + 1):
        u = i / n
        dz = math.sin(u * math.pi * 1.5) * 0.05
        verts += [(x + 0.03 + u * 0.55, y + dz * 0.3, z + h - 0.02 - dz), (x + 0.03 + u * 0.55, y + dz * 0.3, z + h - 0.3 + u * 0.06 - dz)]
    for i in range(n):
        faces.append((2 * i, 2 * i + 2, 2 * i + 3, 2 * i + 1))
    o = mesh_from("Steag", verts, faces, P["violet"])
    s = o.modifiers.new("Grosime", "SOLIDIFY")
    s.thickness = 0.015
    sphere(0.045, (x, y, z + h + 0.02), P["gold"], seg=10, rings=5)


def ivy(loc, P, n=7, spread=(0.5, 0.08, 0.8), seed=1):
    x, y, z = loc
    for i in range(n):
        rx = math.sin(seed * 12.9898 + i * 78.233) * 43758.5453 % 1
        ry = math.sin(seed * 39.346 + i * 11.135) * 24634.6345 % 1
        rz = math.sin(seed * 73.156 + i * 52.235) * 12345.6789 % 1
        ico(0.07 + 0.06 * rx, (x + (rx - 0.5) * spread[0], y - ry * spread[1], z - rz * spread[2]), P["leaf"] if i % 2 else P["leaf_lt"], sub=1)


def stairs(loc, w, steps, step_h, step_d, P, face_angle=0.0, rails=True):
    """Scări care coboară spre -Y de la `loc` (muchia treptei de sus)."""
    with group("Scari", loc, (0, 0, face_angle)) as g:
        for i in range(steps):
            box((w, step_d * (i + 1), step_h), (0, -step_d * (i + 1) / 2, -i * step_h - step_h / 2), P["stone"], bevel=0.01)
        if rails:
            L, H = steps * step_d, steps * step_h
            ang = math.atan2(H, L)
            for sx in (-1, 1):
                xr = sx * (w / 2 + 0.1)
                box((0.14, math.hypot(L, H), 0.09), (xr, -L / 2, -H / 2 + 0.38), P["stone"], bevel=0.02, rot=(-ang, 0, 0))
                for k in range(steps + 1):
                    cyl(0.03, 0.34, (xr, -k * step_d, -k * step_h + 0.17), P["stone"], seg=8, r2=0.045)
                for k in (0, steps):
                    box((0.22, 0.22, 0.5), (xr, -k * step_d, -k * step_h + 0.25), P["stone"], bevel=0.02)
                    sphere(0.08, (xr, -k * step_d, -k * step_h + 0.56), P["gold"], seg=10, rings=6)
    return g


def balustrade_line(a, b, P, h=0.36, n=None):
    a, b = Vector(a), Vector(b)
    d = b - a
    L = d.length
    ang = math.atan2(d.y, d.x)
    mid = (a + b) / 2
    box((L + 0.1, 0.12, 0.08), (mid.x, mid.y, mid.z + h), P["stone"], bevel=0.02, rot=(0, 0, ang))
    box((L + 0.1, 0.14, 0.08), (mid.x, mid.y, mid.z + 0.04), P["stone_dk"], bevel=0.02, rot=(0, 0, ang))
    n = n or max(2, int(L / 0.16))
    for i in range(n + 1):
        p = a + d * (i / n)
        cyl(0.03, h - 0.08, (p.x, p.y, p.z + h / 2), P["stone"], seg=8, r2=0.045)


def balustrade_ring(c, r, P, h=0.36, a0=0.0, a1=2 * math.pi, n=24):
    pts = [Vector((c[0] + math.cos(a0 + (a1 - a0) * i / n) * r, c[1] + math.sin(a0 + (a1 - a0) * i / n) * r, c[2])) for i in range(n + 1)]
    for p, q in zip(pts, pts[1:]):
        balustrade_line(p, q, P, h, n=2)


def bush(loc, r, P, flowers="pink", n=7, seed=1):
    x, y, z = loc
    for i in range(n):
        a = i * 2.39996 + seed
        d = r * 0.55 * math.sqrt((i + 0.5) / n)
        ico(r * (0.45 + 0.15 * (i % 3) / 2), (x + math.cos(a) * d, y + math.sin(a) * d, z + r * 0.45 + (i % 2) * r * 0.15), P["leaf"] if i % 2 else P["leaf_lt"], sub=1)
    if flowers:
        for i in range(n + 3):
            a = i * 2.39996 + seed * 1.7
            d = r * 0.7 * math.sqrt((i + 0.5) / (n + 3))
            sphere(r * 0.13, (x + math.cos(a) * d, y + math.sin(a) * d, z + r * 0.75 + (i % 3) * r * 0.08), P[flowers], seg=8, rings=5)


def cypress(loc, h, P):
    x, y, z = loc
    cyl(0.05 * h, 0.2 * h, (x, y, z + 0.1 * h), P["wood"], seg=6)
    lathe([(0.0001, 0.12 * h), (0.16 * h, 0.25 * h), (0.15 * h, 0.55 * h), (0.09 * h, 0.85 * h), (0.0001, 1.0 * h)], (x, y, z), P["leaf"], seg=10)


def lantern(loc, P, h=1.0):
    x, y, z = loc
    box((0.18, 0.18, 0.12), (x, y, z + 0.06), P["stone_dk"], bevel=0.02)
    cyl(0.04, h * 0.7, (x, y, z + 0.12 + h * 0.35), P["gold"], seg=8)
    cyl(0.1, 0.22, (x, y, z + h * 0.82 + 0.11), P["glow"], seg=6)
    cyl(0.14, 0.1, (x, y, z + h * 0.82 + 0.27), P["roof_dk"], seg=6, r2=0.02)
    sphere(0.03, (x, y, z + h * 0.82 + 0.34), P["gold"], seg=8, rings=4)


# ---------------------------------------------------------------- finalizare / export
def apply_and_join(root, name, keep_empties=()):
    """Aplică modificatorii și unește toate plasele de sub `root` într-una singură
    (mai puține apeluri de desenare pe telefon). Empty-urile din keep_empties rămân,
    iar plasele de sub ele se unesc separat (pentru animații)."""
    bpy.context.view_layer.update()
    groups = {root: []}
    for k in keep_empties:
        groups[k] = []

    def owner(o):
        p = o.parent
        while p is not None:
            if p in groups:
                return p
            p = p.parent
        return root

    for o in list(bpy.data.objects):
        if o.type == "MESH":
            groups[owner(o)].append(o)
    out = []
    for g, objs in groups.items():
        if not objs:
            continue
        bpy.ops.object.select_all(action="DESELECT")
        for o in objs:
            o.select_set(True)
        bpy.context.view_layer.objects.active = objs[0]
        bpy.ops.object.convert(target="MESH")
        objs = [o for o in bpy.context.selected_objects]
        bpy.context.view_layer.objects.active = objs[0]
        for o in objs:
            w = o.matrix_world.copy()
            o.parent = None
            o.matrix_world = w
        bpy.ops.object.join()
        j = bpy.context.view_layer.objects.active
        j.name = name if g is root else g.name + "_Plasa"
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        # reparentare păstrând poziția
        bpy.context.view_layer.update()
        if g is not root:
            inv = g.matrix_world.inverted()
            j.parent = g
            j.matrix_parent_inverse = inv
        else:
            j.parent = root
            j.matrix_parent_inverse = root.matrix_world.inverted()
        bm = bmesh.new()
        bm.from_mesh(j.data)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
        bm.to_mesh(j.data)
        bm.free()
        out.append(j)
    # empty-uri rămase fără rost
    for o in list(bpy.data.objects):
        if o.type == "EMPTY" and o is not root and o not in groups:
            bpy.data.objects.remove(o)
    return out


def tri_count():
    dg = bpy.context.evaluated_depsgraph_get()
    t = 0
    for o in bpy.data.objects:
        if o.type == "MESH":
            me = o.evaluated_get(dg).to_mesh()
            me.calc_loop_triangles()
            t += len(me.loop_triangles)
            o.evaluated_get(dg).to_mesh_clear()
    return t


def export_glb(path, animations=False):
    print("TRIUNGHIURI:", tri_count())
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        export_apply=True,
        export_animations=animations,
        export_animation_mode="NLA_TRACKS",
        export_force_sampling=True,
        export_optimize_animation_size=True,
        export_yup=True,
    )
    print("EXPORTAT:", path)


def preview(path, target=(0, 0, 1.0), cam_loc=(5, -9, 5), lens=50, res=640, bg=(0.5, 0.66, 0.95)):
    scene = bpy.context.scene
    t = bpy.data.objects.new("Tinta", None)
    bpy.context.collection.objects.link(t)
    t.location = target
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    bpy.context.collection.objects.link(cam)
    cam.location = cam_loc
    cam.data.lens = lens
    c = cam.constraints.new("TRACK_TO")
    c.target = t
    c.track_axis = "TRACK_NEGATIVE_Z"
    c.up_axis = "UP_Y"
    scene.camera = cam
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3.2
    sun.data.angle = math.radians(8)
    sun.rotation_euler = (math.radians(45), math.radians(-15), math.radians(-30))
    bpy.context.collection.objects.link(sun)
    world = bpy.data.worlds.new("W")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (*bg, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.9
    scene.world = world
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 40
    scene.cycles.use_denoising = False
    scene.render.resolution_x = res
    scene.render.resolution_y = res
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("PREVIZUALIZARE:", path)
