"""Mascota Buble – model + animații, generate în Blender (4.x).

Rulare:
    blender -b --factory-startup --python art/blender/mascot.py -- godot/models/mascot.glb [preview.png]

După imaginea de referință: corp moale alb-lavandă în formă de bob, picioare scurte,
ochi mari lucioși, gură deschisă veselă, cască de aviator maro cu creștet violet,
ochelari de aviator aurii cu lentile albastre, fular violet cu frunză aurie, ghiozdan
de piele cu pătură rulată și hărți, curea în diagonală cu cataramă aurie.

Fața privește spre -Y în Blender (= +Z în glTF / Godot). Animații: idle-loop (face cu
mâna), walk-loop, jump. Sufixul „-loop" face ca Godot să le repete automat.
"""
import math
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = argv[0] if argv else "mascot.glb"
PREVIEW = argv[1] if len(argv) > 1 else None

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.fps = 24


# ================================================================ materiale
def lin(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def rgb(h):
    return [lin(int(h[i:i + 2], 16)) for i in (0, 2, 4)]


def mat(name, hexcol, rough=0.5, metal=0.0, emit=None, strength=1.0, coat=0.0):
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
    return m


M = {
    "fur": mat("Blana", "f7f4ff", 0.5),
    "eye": mat("Ochi", "16101f", 0.05, coat=1.0),
    "shine": mat("Sclipire", "ffffff", 0.2, emit="ffffff", strength=1.5),
    "blush": mat("Obraji", "ffb0c2", 0.9),
    "mouth": mat("Gura", "7a1c2c", 0.5),
    "tongue": mat("Limba", "ff7f96", 0.5),
    "leather": mat("Piele", "6e4128", 0.6),
    "leather_dk": mat("PieleInchisa", "4a2a1a", 0.65),
    "leather_lt": mat("PieleDeschisa", "9a6238", 0.6),
    "purple": mat("Violet", "7d47d6", 0.75),
    "purple_lt": mat("VioletDeschis", "9a68ea", 0.75),
    "gold": mat("Auriu", "f2b630", 0.25, 1.0),
    "lens": mat("Lentila", "2f8fff", 0.04, 0.2, emit="1a5cc0", strength=0.5, coat=1.0),
    "paper": mat("Hartie", "efe4cc", 0.8),
    "paper_dk": mat("HartieInchisa", "b9a888", 0.8),
}


# ================================================================ forma corpului
BODY_C, BODY_H, DS = 0.82, 0.70, 0.88   # centru, semi-înălțime, adâncime (Y)


def body_t(z):
    return math.acos(max(-1.0, min(1.0, (BODY_C - z) / BODY_H)))


def body_r(z):
    t = body_t(z)
    w = 0.62 + 0.03 * math.sin(t) - 0.08 * (1 - math.cos(t)) / 2
    return w * max(math.sin(t), 0.0) ** 0.8


def normal(p):
    e = 1e-3
    dr = (body_r(p.z + e) - body_r(p.z - e)) / (2 * e)
    n = Vector((p.x, p.y / (DS * DS), -body_r(p.z) * dr))
    return n.normalized()


def surf(az, z, off=0.0):
    """Punct pe corp: az = unghi de la față (-Y) spre +X (stânga personajului), în grade."""
    a = math.radians(az)
    r = body_r(z)
    p = Vector((math.sin(a) * r, -math.cos(a) * r * DS, z))
    return p + normal(p) * off


def lathe_mesh(name, scale=1.0, rings=40, seg=56):
    verts, faces = [(0, 0, BODY_C - BODY_H)], []
    for i in range(1, rings):
        t = math.pi * i / rings
        z = BODY_C - BODY_H * math.cos(t)
        r = body_r(z) * scale
        zc = BODY_C + (z - BODY_C) * scale
        for j in range(seg):
            a = 2 * math.pi * j / seg
            verts.append((math.sin(a) * r, -math.cos(a) * r * DS, zc))
    verts.append((0, 0, BODY_C + BODY_H * scale))
    top = len(verts) - 1
    for j in range(seg):
        faces.append((0, 1 + (j + 1) % seg, 1 + j))
    for i in range(rings - 2):
        b0 = 1 + i * seg
        b1 = b0 + seg
        for j in range(seg):
            faces.append((b0 + j, b0 + (j + 1) % seg, b1 + (j + 1) % seg, b1 + j))
    last = 1 + (rings - 2) * seg
    for j in range(seg):
        faces.append((last + j, last + (j + 1) % seg, top))
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.update()
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    smooth(o)
    return o


# ================================================================ ajutoare
def smooth(o):
    for p in o.data.polygons:
        p.use_smooth = True


def finish(o, name, m, parent=None, local=False):
    o.name = name
    o.data.materials.append(M[m])
    if parent is not None:
        if local:
            o.parent = parent
        else:
            bpy.context.view_layer.update()
            w = o.matrix_world.copy()
            o.parent = parent
            o.matrix_world = w
    return o


def align_rot(n):
    return Vector((0, 0, 1)).rotation_difference(n).to_euler()


def sphere(name, r, loc, m, scale=(1, 1, 1), rot=(0, 0, 0), parent=None, seg=32, rings=16, local=False):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=rings, radius=r, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.scale = scale
    smooth(o)
    return finish(o, name, m, parent, local)


def torus(name, R, r, loc, m, rot=(0, 0, 0), scale=(1, 1, 1), parent=None, seg=48, sides=12, local=False):
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, major_segments=seg, minor_segments=sides, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.scale = scale
    smooth(o)
    return finish(o, name, m, parent, local)


def cylinder(name, r, depth, loc, m, rot=(0, 0, 0), parent=None, seg=24, local=False):
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=depth, vertices=seg, location=loc, rotation=rot)
    o = bpy.context.active_object
    b = o.modifiers.new("Bevel", "BEVEL")
    b.width = min(r * 0.3, 0.02)
    b.segments = 2
    b.limit_method = "ANGLE"
    smooth(o)
    return finish(o, name, m, parent, local)


def rbox(name, size, loc, m, bevel=0.05, rot=(0, 0, 0), parent=None, local=False):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    b = o.modifiers.new("Bevel", "BEVEL")
    b.width = min(bevel, min(size) * 0.49)
    b.segments = 4
    b.limit_method = "NONE"
    smooth(o)
    return finish(o, name, m, parent, local)


def empty(name, loc, parent=None, rot=(0, 0, 0)):
    o = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(o)
    o.location = loc
    o.rotation_euler = rot
    if parent is not None:
        bpy.context.view_layer.update()
        w = o.matrix_world.copy()
        o.parent = parent
        o.matrix_world = w
    bpy.context.view_layer.update()
    return o


def keep_verts(o, pred):
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not pred(v.co)], context="VERTS")
    bm.to_mesh(o.data)
    bm.free()


def solidify(o, t):
    s = o.modifiers.new("Grosime", "SOLIDIFY")
    s.thickness = t
    s.offset = 1


def strip(name, pts, width_dirs, width, m, parent, thick=0.025):
    """Fâșie (capătul fularului): puncte pe axă + direcții de lățime."""
    verts, faces = [], []
    for p, w in zip(pts, width_dirs):
        verts += [p - w * width / 2, p + w * width / 2]
    for i in range(len(pts) - 1):
        faces.append((2 * i, 2 * i + 1, 2 * i + 3, 2 * i + 2))
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    solidify(o, thick)
    sub = o.modifiers.new("Netezire", "SUBSURF")
    sub.levels = 1
    sub.render_levels = 1
    smooth(o)
    return finish(o, name, m, parent)


# ================================================================ personaj
root = empty("Mascota", (0, 0, 0))
body = empty("Corp", (0, 0, 0), root)
finish(lathe_mesh("Trunchi"), "Trunchi", "fur", body)

# ---- față
EYE_Z = 1.0
UP = Vector((0, 0, 1))
for s, side in ((-1, "D"), (1, "S")):
    p = surf(s * 22, EYE_Z)
    n = normal(p)
    right = n.cross(UP).normalized()
    sphere("Ochi" + side, 0.105, p + n * 0.01, "eye", scale=(0.95, 1.22, 0.55), rot=align_rot(n), parent=body, seg=28, rings=14)
    sphere("Sclipire" + side, 0.042, p + n * 0.06 + UP * 0.045 + right * 0.03, "shine", rot=align_rot(n), scale=(1, 1, 0.5), parent=body, seg=14, rings=7)
    sphere("SclipireMica" + side, 0.018, p + n * 0.055 - UP * 0.045 - right * 0.035, "shine", parent=body, seg=8, rings=4)
    pb = surf(s * 42, 0.9)
    sphere("Obraz" + side, 0.085, pb + normal(pb) * 0.005, "blush", scale=(1.25, 0.8, 0.22), rot=align_rot(normal(pb)), parent=body, seg=18, rings=9)

pm = surf(0, 0.86)
nm = normal(pm)
bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16, radius=0.14, location=(0, 0, 0))
mouth = bpy.context.active_object
keep_verts(mouth, lambda c: c.y <= 0.01)      # jumătatea de jos: „D" cu latura dreaptă sus
mouth.rotation_euler = (math.radians(90), 0, 0)
mouth.scale = (1.0, 0.85, 0.28)
mouth.location = pm + nm * 0.004 + Vector((0, 0, 0.05))
smooth(mouth)
finish(mouth, "Gura", "mouth", body)
sphere("Limba", 0.07, pm + nm * 0.035 - Vector((0, 0, 0.035)), "tongue", scale=(0.95, 0.3, 0.45), parent=body, seg=18, rings=9)

# ---- cască de aviator
cap = lathe_mesh("Casca", scale=1.045, rings=44, seg=60)
keep_verts(cap, lambda c: c.z + 0.42 * c.y > 1.17)
solidify(cap, 0.03)
finish(cap, "Casca", "leather", body)
crown = lathe_mesh("Crestet", scale=1.075, rings=44, seg=60)
keep_verts(crown, lambda c: c.z > 1.44)
solidify(crown, 0.02)
finish(crown, "Crestet", "purple", body)
ZC = 1.44
torus("TivCrestet", body_r(ZC) * 1.065, 0.022, (0, 0, BODY_C + (ZC - BODY_C) * 1.07), "leather_dk", scale=(1, DS, 1), parent=body, seg=60, sides=8)
sphere("Mot", 0.05, (0, 0, BODY_C + BODY_H * 1.075 + 0.01), "purple_lt", parent=body, seg=16, rings=8)
for s, side in ((-1, "D"), (1, "S")):
    p = surf(s * 82, 1.05, 0.03)
    sphere("Clapa" + side, 0.2, p, "leather", scale=(0.95, 1.2, 0.25), rot=align_rot(normal(p)), parent=body, seg=24, rings=12)
    q = surf(s * 80, 0.9, 0.035)
    nq = normal(q)
    cb = rbox("Curea" + side, (0.07, 0.025, 0.3), q, "leather_dk", bevel=0.01, parent=body)
    cb.rotation_euler = (Matrix.Rotation(math.atan2(nq.x, -nq.y), 4, "Z") @ Matrix.Rotation(math.radians(-8), 4, "X")).to_euler()
    pc = surf(s * 80, 0.8, 0.05)
    torus("Catarama" + side, 0.045, 0.012, pc, "gold", rot=align_rot(normal(pc)), parent=body, seg=4, sides=6)

# ---- ochelari de aviator pe frunte
GZ = 1.33
goggles = empty("Ochelari", tuple(surf(0, GZ, 0.05)), body)
torus("CureaOchelari", body_r(GZ) * 1.06 + 0.02, 0.04, (0, 0, GZ), "leather_dk", scale=(1, DS * 1.02, 0.55), parent=body, seg=64, sides=10)
for s, side in ((-1, "D"), (1, "S")):
    p = surf(s * 22, GZ, 0.07)
    n = normal(p)
    rt = n.cross(UP).normalized()
    torus("Rama" + side, 0.14, 0.048, p, "gold", rot=align_rot(n), parent=goggles, seg=36, sides=12)
    cylinder("Cupa" + side, 0.125, 0.09, p - n * 0.04, "gold", rot=align_rot(n), parent=goggles, seg=32)
    sphere("Lentila" + side, 0.12, p + n * 0.01, "lens", scale=(1, 1, 0.4), rot=align_rot(n), parent=goggles, seg=28, rings=14)
    sphere("Reflex" + side, 0.035, p + n * 0.06 + UP * 0.05 + rt * 0.04, "shine", scale=(1, 1, 0.4), rot=align_rot(n), parent=goggles, seg=12, rings=6)
cylinder("Punte", 0.03, 0.14, surf(0, GZ, 0.09), "gold", rot=(0, math.radians(90), 0), parent=goggles, seg=12)

# ---- fular
SZ = 0.66
torus("Fular", body_r(SZ) + 0.05, 0.085, (0, 0, SZ), "purple", rot=(math.radians(6), 0, 0), scale=(1, DS * 1.04, 0.7), parent=body, seg=56, sides=16)
torus("FularPliu", body_r(SZ + 0.06) + 0.05, 0.055, (0, -0.01, SZ + 0.07), "purple_lt", rot=(math.radians(6), 0, 0), scale=(1, DS * 1.05, 0.75), parent=body, seg=56, sides=10)
knot = surf(28, SZ - 0.02, 0.12)
sphere("Nod", 0.1, knot, "purple", scale=(1, 0.75, 0.85), parent=body, seg=20, rings=10)
tail = empty("CapatFular", tuple(knot), body)
pts, ws = [], []
start = knot + Vector((0.03, -0.02, -0.05))
for i in range(13):
    u = i / 12
    pts.append(start + Vector((0.42 * u + 0.05 * math.sin(u * 3), -0.1 * u - 0.03 * math.sin(u * 6), -0.5 * u)))
    ws.append(Vector((0.85, -0.1, 0.5)).normalized())
strip("Capat", pts, ws, 0.22, "purple", tail)
end = pts[-1]
for k in range(7):
    f = end + ws[-1] * (k / 6 - 0.5) * 0.2 + Vector((0.01, -0.005, -0.04))
    cylinder("Franj%d" % k, 0.008, 0.07, f, "purple_lt", rot=(0, math.radians(25), 0), parent=tail, seg=6)
leaf_c = pts[8] + Vector((0, -0.035, 0))
for k, a in enumerate((-30, 30)):
    sphere("Frunza%d" % k, 0.05, leaf_c + Vector((math.sin(math.radians(a)) * 0.03, 0, 0.015)), "gold", scale=(0.55, 0.25, 1.0), rot=(0, math.radians(a), 0), parent=tail, seg=12, rings=8)

# ---- curea în diagonală cu cataramă
# planul curelei e înclinat: sus la umărul drept/spate, jos în față-stânga
sn = Vector((0.36, -0.36, 0.86)).normalized()
strap = torus("CureaPiept", 0.62, 0.028, (0, 0.02, 0.8), "leather", rot=align_rot(sn), scale=(1, 0.95, 2.2), parent=body, seg=72, sides=8)
bpy.context.view_layer.update()
best = max((strap.matrix_world @ Vector((0.62 * math.cos(a), 0.62 * math.sin(a), 0)) for a in [i * math.tau / 72 for i in range(72)]), key=lambda v: -v.y + 0.35 * v.x)
torus("CataramaPiept", 0.065, 0.016, best + normal(best) * 0.03, "gold", rot=align_rot(normal(best)), parent=body, seg=4, sides=6)

# ---- ghiozdan (spate-dreapta)
AZ = -115
pack_pos = surf(AZ, 0.78, 0.26)
outward = normal(surf(AZ, 0.8))
pack = empty("Ghiozdan", tuple(pack_pos), body, rot=(0, 0, math.atan2(-outward.x, outward.y)))
rbox("Sac", (0.52, 0.3, 0.56), (0, 0, 0), "leather", bevel=0.1, parent=pack, local=True)
rbox("ClapaSac", (0.54, 0.12, 0.3), (0, 0.14, 0.16), "leather_lt", bevel=0.05, rot=(math.radians(-12), 0, 0), parent=pack, local=True)
rbox("Buzunar", (0.34, 0.1, 0.24), (0, 0.17, -0.12), "leather_lt", bevel=0.05, parent=pack, local=True)
rbox("Inchizatoare", (0.06, 0.03, 0.12), (0, 0.235, 0.04), "gold", bevel=0.01, parent=pack, local=True)
rbox("InchizatoareBuz", (0.05, 0.03, 0.08), (0, 0.225, -0.08), "gold", bevel=0.01, parent=pack, local=True)
cylinder("Patura", 0.1, 0.62, (0, 0.0, 0.36), "leather_lt", rot=(0, math.radians(90), 0), parent=pack, local=True, seg=28)
for s in (-1, 1):
    torus("Spirala%d" % s, 0.06, 0.018, (s * 0.31, 0, 0.36), "leather", rot=(0, math.radians(90), 0), parent=pack, local=True, seg=24, sides=6)
    rbox("CureaPatura%d" % s, (0.035, 0.24, 0.24), (s * 0.17, 0, 0.36), "leather_dk", bevel=0.01, parent=pack, local=True)
for k, (x, tilt) in enumerate(((-0.14, 14), (0.02, -8))):
    cylinder("Harta%d" % k, 0.06, 0.48, (x, -0.06, 0.52), "paper", rot=(math.radians(-12), math.radians(tilt), 0), parent=pack, local=True, seg=20)
    torus("Rola%d" % k, 0.057, 0.012, (x + math.sin(math.radians(tilt)) * 0.24, -0.01, 0.755), "paper_dk", rot=(math.radians(-12), math.radians(tilt), 0), parent=pack, local=True, seg=20, sides=6)

# ---- brațe (pivot la umăr) și picioare
arms = {}
for s, side in ((-1, "D"), (1, "S")):
    sh = surf(s * 88, 0.74, -0.06)
    a = empty("Brat" + side, tuple(sh), body)
    sphere("Mana" + side, 0.15, sh + Vector((s * 0.1, -0.03, -0.13)), "fur", scale=(0.82, 0.82, 1.3), rot=(0, s * math.radians(-28), 0), parent=a, seg=24, rings=12)
    arms[s] = a
feet = {}
for s, side in ((-1, "D"), (1, "S")):
    f = empty("Picior" + side, (s * 0.22, -0.02, 0.12), root)
    sphere("Talpa" + side, 0.15, (s * 0.22, -0.04, 0.11), "fur", scale=(1, 1.15, 0.95), parent=f, seg=24, rings=12)
    feet[s] = f


# ================================================================ animații
ANIMATED = [body, arms[-1], arms[1], feet[-1], feet[1], tail, goggles]
REST = {o.name: (o.location.copy(), o.rotation_euler.copy(), o.scale.copy()) for o in ANIMATED}


def reset():
    for o in ANIMATED:
        loc, rot, sc = REST[o.name]
        o.location, o.rotation_euler, o.scale = loc.copy(), rot.copy(), sc.copy()


def key(o, frame, loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1)):
    l0, r0, s0 = REST[o.name]
    o.location = l0 + Vector(loc)
    o.rotation_euler = (r0[0] + rot[0], r0[1] + rot[1], r0[2] + rot[2])
    o.scale = Vector((s0[0] * scale[0], s0[1] * scale[1], s0[2] * scale[2]))
    for p in ("location", "rotation_euler", "scale"):
        o.keyframe_insert(p, frame=frame)


def bake_clip(name, frames, fn):
    for o in ANIMATED:
        o.animation_data_create()
        o.animation_data.action = bpy.data.actions.new("%s_%s" % (name, o.name))
    for f in frames:
        fn(f)
    for o in ANIMATED:
        act = o.animation_data.action
        tr = o.animation_data.nla_tracks.new()
        tr.name = name
        tr.strips.new(name, int(act.frame_range[0]), act)
        o.animation_data.action = None
    reset()


def ease(points, f):
    for (f0, v0), (f1, v1) in zip(points, points[1:]):
        if f0 <= f <= f1:
            k = (f - f0) / max(f1 - f0, 1)
            k = k * k * (3 - 2 * k)
            return v0 + (v1 - v0) * k
    return points[-1][1]


IDLE_N = 72


def idle(f):
    t = (f - 1) / (IDLE_N - 1) * math.tau
    b = math.sin(t * 2)
    key(body, f, loc=(0, 0, 0.01 * b), scale=(1 + 0.012 * b, 1 + 0.012 * b, 1 - 0.018 * b))
    # brațul stâng se ridică, face de două ori cu mâna, apoi coboară
    up = ease([(1, 0.0), (10, 1.0), (44, 1.0), (54, 0.0), (IDLE_N, 0.0)], f)
    wave = math.sin((f - 10) / 34 * 4 * math.pi) * 0.35 if 10 <= f <= 44 else 0.0
    key(arms[1], f, rot=(0, (-1.8 + wave) * up, 0))
    key(arms[-1], f, rot=(0, 0.08 * math.sin(t), 0))
    key(feet[-1], f)
    key(feet[1], f)
    key(tail, f, rot=(0.08 * math.sin(t * 2 + 1.0), 0.05 * math.sin(t * 2), 0))
    key(goggles, f)


def walk(f):
    t = (f - 1) / 16.0 * math.tau
    s = math.sin(t)
    key(body, f, loc=(0, 0, 0.05 * abs(math.sin(t))), rot=(0, 0.07 * s, 0), scale=(1, 1, 1 - 0.03 * math.cos(2 * t)))
    key(feet[-1], f, loc=(0, -0.12 * s, 0.07 * max(0.0, math.cos(t))))
    key(feet[1], f, loc=(0, 0.12 * s, 0.07 * max(0.0, -math.cos(t))))
    key(arms[-1], f, rot=(0.5 * s, 0, 0))
    key(arms[1], f, rot=(-0.5 * s, 0, 0))
    key(tail, f, rot=(0.3 + 0.12 * math.sin(2 * t), 0.1 * s, 0))
    key(goggles, f, loc=(0, 0, 0.008 * math.sin(2 * t)))


def jump(f):
    sq = ease([(1, Vector((1, 1, 1))), (4, Vector((1.12, 1.12, 0.82))), (8, Vector((0.92, 0.92, 1.12))), (14, Vector((1, 1, 1))), (18, Vector((1.1, 1.1, 0.86))), (22, Vector((1, 1, 1)))], f)
    arm = ease([(1, 0.0), (4, 0.3), (8, -1.6), (14, -1.1), (18, 0.2), (22, 0.0)], f)
    tuck = ease([(1, 0.0), (6, 0.0), (9, 0.1), (15, 0.04), (18, 0.0), (22, 0.0)], f)
    key(body, f, scale=tuple(sq))
    key(arms[-1], f, rot=(0, -arm, 0))
    key(arms[1], f, rot=(0, arm, 0))
    key(feet[-1], f, loc=(0, 0, tuck))
    key(feet[1], f, loc=(0, 0, tuck))
    key(tail, f, rot=(-arm * 0.25, 0, 0))
    key(goggles, f, loc=(0, 0, -0.015 * (sq.z - 1)))


bake_clip("idle-loop", range(1, IDLE_N + 1), idle)
bake_clip("walk-loop", range(1, 18), walk)
bake_clip("jump", range(1, 23), jump)

# ================================================================ export
dg = bpy.context.evaluated_depsgraph_get()
tris = 0
for o in bpy.data.objects:
    if o.type == "MESH":
        me = o.evaluated_get(dg).to_mesh()
        me.calc_loop_triangles()
        tris += len(me.loop_triangles)
        o.evaluated_get(dg).to_mesh_clear()
print("TRIUNGHIURI:", tris)

bpy.ops.export_scene.gltf(
    filepath=OUT,
    export_format="GLB",
    export_apply=True,
    export_animations=True,
    export_animation_mode="NLA_TRACKS",
    export_force_sampling=True,
    export_optimize_animation_size=True,
    export_yup=True,
)
print("EXPORTAT:", OUT)

# ================================================================ previzualizare
if PREVIEW:
    reset()
    # poza din referință: doar animația „idle", la mijlocul salutului
    for o in ANIMATED:
        for tr in o.animation_data.nla_tracks:
            tr.mute = tr.name != "idle-loop"
    scene.frame_set(27)
    target = empty("Tinta", (0, 0, 0.85))
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    bpy.context.collection.objects.link(cam)
    cam.location = (1.25, -3.7, 1.55)
    cam.data.lens = 52
    c = cam.constraints.new("TRACK_TO")
    c.target = target
    c.track_axis = "TRACK_NEGATIVE_Z"
    c.up_axis = "UP_Y"
    scene.camera = cam
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3.2
    sun.rotation_euler = (math.radians(45), math.radians(-15), math.radians(-30))
    bpy.context.collection.objects.link(sun)
    world = bpy.data.worlds.new("W")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.5, 0.65, 0.95, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.9
    scene.world = world
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 48
    scene.cycles.use_denoising = False
    scene.render.resolution_x = 640
    scene.render.resolution_y = 640
    scene.render.filepath = PREVIEW
    bpy.ops.render.render(write_still=True)
    print("PREVIZUALIZARE:", PREVIEW)
