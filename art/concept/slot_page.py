"""Randare de concept: pagina separată „Mașina de bule”.

blender -b -P art/concept/slot_page.py -- <iesire.png> [samples] [lățime]
Scena: mașina de alamă și sticlă pe o platformă din nori, cu 3 role de bule,
dom cu bule deasupra, manetă cu bulă, tavă cu monede și mascota alături.
Interfața (bara de sus, butonul ROTEȘTE) se pune peste randare cu slot_ui.py.
"""
import math
import os
import random
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "blender"))
import bk  # noqa: E402

A = bk.args()
OUT = A[0] if A else "/tmp/slot.png"
SAMPLES = int(A[1]) if len(A) > 1 else 64
W = int(A[2]) if len(A) > 2 else 720
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ICONS = os.path.join(ROOT, "godot", "assets", "icons")
random.seed(7)

bk.reset_scene()
sc = bpy.context.scene
col = sc.collection


def link(o):
    if o.name not in col.objects:
        col.objects.link(o)
    return o


def setmat(o, m):
    o.data.materials.clear()
    o.data.materials.append(m)
    return o


def smooth(o):
    for p in o.data.polygons:
        p.use_smooth = True
    return o


def bevel(o, w=0.04, seg=3):
    md = o.modifiers.new("b", "BEVEL")
    md.width = w
    md.segments = seg
    md.limit_method = "ANGLE"
    return o


def box(name, loc, size, m, bev=0.04):
    bpy.ops.mesh.primitive_cube_add(location=loc)
    o = bpy.context.object
    o.name = name
    o.scale = (size[0] / 2, size[1] / 2, size[2] / 2)
    bpy.ops.object.transform_apply(scale=True)
    if bev:
        bevel(o, bev)
    return setmat(o, m)


def cyl(name, loc, r, h, m, rot=(0, 0, 0), verts=48, bev=0.0):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=h, location=loc, rotation=rot)
    o = bpy.context.object
    o.name = name
    if bev:
        bevel(o, bev, 2)
    smooth(o)
    return setmat(o, m)


def sph(name, loc, r, m, seg=48):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=seg // 2, radius=r, location=loc)
    o = bpy.context.object
    o.name = name
    smooth(o)
    return setmat(o, m)


def torus(name, loc, R, r, m, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(location=loc, rotation=rot, major_radius=R, minor_radius=r,
                                     major_segments=64, minor_segments=16)
    o = bpy.context.object
    o.name = name
    smooth(o)
    return setmat(o, m)


# ---------------------------------------------------------------- materiale
P = bk.palette()
brass = bk.mat("Alama", "e9b54a", 0.22, 1.0)
brass_dk = bk.mat("AlamaInchisa", "b9822c", 0.3, 1.0)
velvet = bk.mat("Catifea", "4a2a8e", 0.85)
velvet_lt = bk.mat("CatifeaDeschisa", "6a44c0", 0.75)
enamel = bk.mat("EmailTurcoaz", "1fb2ab", 0.25, 0.0, coat=0.6)
cream = bk.mat("Crem", "f6ecd8", 0.5, coat=0.3)
bulb = bk.mat("Bec", "fff1c8", 0.3, emit="ffc56a", strength=9.0)
reel_bg = bk.mat("FundalRola", "f3e9d6", 0.6)
shadow_in = bk.mat("InteriorUmbra", "3a2470", 0.9)


def glass(name, tint="eaf8ff", ior=1.12, rough=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*bk.rgb(tint), 1)
    b.inputs["Transmission Weight"].default_value = 1.0
    b.inputs["Roughness"].default_value = rough
    b.inputs["IOR"].default_value = ior
    return m


def bubble_mat(name, edge_a="7ff3ff", edge_b="ff9ce6"):
    """Bulă de săpun: transparentă în centru, reflexie irizată spre margine."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    m.blend_method = "BLEND"
    nt = m.node_tree
    for n in list(nt.nodes):
        if n.type != "OUTPUT_MATERIAL":
            nt.nodes.remove(n)
    out = nt.nodes["Material Output"]
    lw = nt.nodes.new("ShaderNodeLayerWeight")
    lw.inputs["Blend"].default_value = 0.3
    cr = nt.nodes.new("ShaderNodeValToRGB")
    e = cr.color_ramp.elements
    e[0].position = 0.0
    e[0].color = (1, 1, 1, 1)
    e[1].position = 0.6
    e[1].color = (*bk.rgb(edge_a), 1)
    x = e.new(0.95)
    x.color = (*bk.rgb(edge_b), 1)
    nt.links.new(lw.outputs["Facing"], cr.inputs["Fac"])
    gl = nt.nodes.new("ShaderNodeBsdfGlossy")
    gl.inputs["Roughness"].default_value = 0.02
    nt.links.new(cr.outputs["Color"], gl.inputs["Color"])
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Strength"].default_value = 0.5
    nt.links.new(cr.outputs["Color"], em.inputs["Color"])
    add = nt.nodes.new("ShaderNodeAddShader")
    nt.links.new(gl.outputs[0], add.inputs[0])
    nt.links.new(em.outputs[0], add.inputs[1])
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    pw = nt.nodes.new("ShaderNodeMath")
    pw.operation = "POWER"
    pw.inputs[1].default_value = 2.2
    nt.links.new(lw.outputs["Facing"], pw.inputs[0])
    mx = nt.nodes.new("ShaderNodeMath")
    mx.operation = "MULTIPLY_ADD"
    mx.inputs[1].default_value = 0.85
    mx.inputs[2].default_value = 0.0
    nt.links.new(pw.outputs[0], mx.inputs[0])
    mix = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(mx.outputs[0], mix.inputs["Fac"])
    nt.links.new(tr.outputs[0], mix.inputs[1])
    nt.links.new(add.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs["Surface"])
    return m


BUB = bubble_mat("Bula")
GLASS = glass("SticlaFata", "f4fbff", 1.05)


_ICON = {}


def icon_mat(icon, hexcol="ffffff", strength=1.6):
    key = icon + hexcol
    if key in _ICON:
        return _ICON[key]
    m = bpy.data.materials.new("Icon_" + icon)
    m.use_nodes = True
    m.blend_method = "CLIP"
    nt = m.node_tree
    for n in list(nt.nodes):
        if n.type != "OUTPUT_MATERIAL":
            nt.nodes.remove(n)
    out = nt.nodes["Material Output"]
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(os.path.join(ICONS, icon + ".png"))
    emi = nt.nodes.new("ShaderNodeEmission")
    emi.inputs["Color"].default_value = (*bk.rgb(hexcol), 1)
    emi.inputs["Strength"].default_value = strength
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    mix = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(tex.outputs["Alpha"], mix.inputs["Fac"])
    nt.links.new(tr.outputs[0], mix.inputs[1])
    nt.links.new(emi.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs["Surface"])
    _ICON[key] = m
    return m


# simbolurile din spin_table.json: icoană + culoarea jetonului
SYM = {
    "monede": ("coins", "ff9f00"),
    "sac": ("hand-coins", "e08a1e"),
    "jackpot": ("crown", "ff5fa8"),
    "energie": ("zap", "35c46a"),
    "scut": ("shield", "1fb2ab"),
    "atac": ("hammer", "e5484d"),
    "raid": ("shovel", "8a5cf0"),
    "cufar": ("package", "a8703a"),
    "carte": ("layers", "3d7be0"),
}
TOKEN = {k: bk.mat("Jeton_" + k, v[1], 0.35, 0.0, emit=v[1], strength=0.6, coat=0.8) for k, v in SYM.items()}


def symbol_bubble(kind, loc, normal, r=0.2):
    """Bulă de sticlă cu jeton colorat și icoană albă, orientată după normală."""
    n = Vector(normal).normalized()
    s = sph("BulaSimbol", loc, r, BUB, 32)
    rot = n.to_track_quat("Z", "Y").to_euler()
    t = cyl("Jeton", Vector(loc) - n * 0.02, r * 0.72, r * 0.16, TOKEN[kind], verts=40, bev=0.02)
    t.rotation_euler = rot
    rim = torus("JetonMargine", Vector(loc) - n * 0.02, r * 0.72, r * 0.07, brass)
    rim.rotation_euler = rot
    bpy.ops.mesh.primitive_plane_add(size=r * 1.1, location=Vector(loc) + n * (r * 0.1))
    ic = bpy.context.object
    ic.rotation_euler = rot
    setmat(ic, icon_mat(SYM[kind][0], "ffffff", 3.0))
    return s


# ---------------------------------------------------------------- lume
W_ = sc.world = bpy.data.worlds.new("Cer")
W_.use_nodes = True
nt = W_.node_tree
bg = nt.nodes["Background"]
tc = nt.nodes.new("ShaderNodeTexCoord")
sep = nt.nodes.new("ShaderNodeSeparateXYZ")
ramp = nt.nodes.new("ShaderNodeValToRGB")
e = ramp.color_ramp.elements
e[0].position = 0.5
e[0].color = (*bk.rgb("ffc9a0"), 1)
e[1].position = 0.8
e[1].color = (*bk.rgb("5b46c8"), 1)
mid = e.new(0.6)
mid.color = (*bk.rgb("ff9fcf"), 1)
mid2 = e.new(0.68)
mid2.color = (*bk.rgb("b07ef0"), 1)
mp = nt.nodes.new("ShaderNodeMapRange")
mp.inputs["From Min"].default_value = -1.0
nt.links.new(tc.outputs["Generated"], sep.inputs[0])
nt.links.new(sep.outputs["Z"], mp.inputs["Value"])
nt.links.new(mp.outputs["Result"], ramp.inputs["Fac"])
nt.links.new(ramp.outputs["Color"], bg.inputs["Color"])
bg.inputs["Strength"].default_value = 1.4

# platforma plutitoare
cyl("Platforma", (0, 0.6, -0.25), 4.2, 0.5, cream, bev=0.08)
torus("PlatformaInel", (0, 0.6, 0.0), 4.2, 0.08, brass)
cyl("Covor", (0, 0.4, 0.02), 3.2, 0.04, velvet, verts=64)
torus("CovorInel", (0, 0.4, 0.04), 3.2, 0.035, brass)
for i in range(16):
    a = i / 16 * math.tau
    box("Dala", (math.cos(a) * 3.7, 0.6 + math.sin(a) * 3.7, 0.01), (0.5, 0.5, 0.04), enamel, 0.03).rotation_euler.z = a

# ---------------------------------------------------------------- mașina
# soclu în trepte
box("Soclu1", (0, 0.2, 0.15), (3.8, 2.0, 0.3), velvet_lt, 0.06)
box("Soclu2", (0, 0.2, 0.42), (3.5, 1.8, 0.26), brass_dk, 0.05)
# corp: două jumătăți și o ramă, lăsând fereastra rolelor deschisă
CZ0, CZ1 = 0.55, 3.15
box("CorpSpate", (0, 0.55, (CZ0 + CZ1) / 2), (3.3, 0.5, CZ1 - CZ0), velvet, 0.08)
box("CorpStanga", (-1.47, 0.0, (CZ0 + CZ1) / 2), (0.36, 1.5, CZ1 - CZ0), velvet, 0.08)
box("CorpDreapta", (1.47, 0.0, (CZ0 + CZ1) / 2), (0.36, 1.5, CZ1 - CZ0), velvet, 0.08)
box("CorpJos", (0, 0.0, 0.95), (3.3, 1.5, 0.8), velvet, 0.08)
box("CorpSus", (0, 0.0, 2.95), (3.3, 1.5, 0.4), velvet, 0.08)
box("Interior", (0, 0.45, 2.05), (2.6, 0.1, 1.4), shadow_in, 0)
# placa din față, crem, cu fereastra decupată
plate = box("Placa", (0, -0.76, 2.2), (3.1, 0.06, 1.9), velvet_lt, 0.02)
hole = box("Gaura", (0, -0.76, 2.05), (2.6, 0.4, 1.44), cream, 0)
bm_ = plate.modifiers.new("gaura", "BOOLEAN")
bm_.object = hole
bm_.operation = "DIFFERENCE"
hole.hide_render = True
# coloane de alamă pe laterale
for x in (-1.72, 1.72):
    cyl("Coloana", (x, -0.62, 1.85), 0.13, 2.6, brass, bev=0.02)
    for z in (0.62, 3.1):
        cyl("ColoanaInel", (x, -0.62, z), 0.19, 0.12, brass_dk, bev=0.03)
    sph("ColoanaVarf", (x, -0.62, 3.32), 0.2, enamel)
# rama ferestrei
WZ = 2.05
torus  # (doar ca să fie importat)
for z in (WZ - 0.72, WZ + 0.72):
    cyl("RamaOriz", (0, -0.74, z), 0.07, 2.74, brass, rot=(0, math.pi / 2, 0))
for x in (-1.3, 1.3):
    cyl("RamaVert", (x, -0.74, WZ), 0.07, 1.5, brass)
for x in (-0.43, 0.43):
    cyl("Separator", (x, -0.62, WZ), 0.03, 1.4, brass_dk)
# becuri în jurul ferestrei
for i in range(13):
    x = -1.3 + i * (2.6 / 12)
    for z in (WZ - 0.86, WZ + 0.86):
        sph("Bec", (x, -0.83, z), 0.045, bulb, 16)
for i in range(1, 6):
    z = WZ - 0.72 + i * (1.44 / 6)
    for x in (-1.44, 1.44):
        sph("Bec", (x, -0.83, z), 0.045, bulb, 16)
# linia de câștig: săgeți aurii
for s in (-1, 1):
    bpy.ops.mesh.primitive_cone_add(vertices=3, radius1=0.12, depth=0.05, location=(s * 1.2, -0.85, WZ),
                                    rotation=(math.pi / 2, 0, -s * math.pi / 2))
    setmat(bpy.context.object, bk.mat("Sageata", "ffd24a", 0.2, 1.0, emit="ffb020", strength=2.0))
# sticla din față

# rolele: cilindri pe axa X cu bule de simboluri pe circumferință
REEL_R = 0.62
REEL_Y = -0.02
REELS = [
    ["monede", "energie", "scut", "atac", "jackpot", "cufar", "raid", "scut"],
    ["monede", "atac", "raid", "carte", "sac", "monede", "energie", "scut"],
    ["monede", "sac", "atac", "jackpot", "energie", "scut", "raid", "carte"],
]
for ri, x in enumerate((-0.86, 0.0, 0.86)):
    cyl("Rola", (x, REEL_Y, WZ), REEL_R - 0.05, 0.78, reel_bg, rot=(0, math.pi / 2, 0), verts=64)
    for side in (-1, 1):
        cyl("RolaMargine", (x + side * 0.4, REEL_Y, WZ), REEL_R - 0.01, 0.03, brass_dk, rot=(0, math.pi / 2, 0), verts=64)
    for k in range(8):
        a = -k * (math.tau / 8)  # 0 = spre cameră (−Y)
        n = Vector((0, -math.cos(a), math.sin(a)))
        if n.y > 0.1:
            continue
        loc = Vector((x, REEL_Y, WZ)) + n * REEL_R
        symbol_bubble(REELS[ri][k], loc, n, 0.235)

# panoul de jos: fanta pentru monede și tava
box("Panou", (0, -0.78, 0.95), (2.7, 0.08, 0.62), cream, 0.04)
torus("FantaInel", (0, -0.84, 1.05), 0.32, 0.05, brass, rot=(math.pi / 2, 0, 0))
cyl("Fanta", (0, -0.83, 1.05), 0.3, 0.02, shadow_in, rot=(math.pi / 2, 0, 0))
box("Tava", (0, -1.05, 0.62), (2.2, 0.7, 0.16), brass, 0.05)
box("TavaInterior", (0, -1.05, 0.67), (2.0, 0.55, 0.1), brass_dk, 0.02)
coin = bk.mat("Moneda", "ffc93c", 0.18, 1.0)
for i in range(46):
    x = random.uniform(-0.9, 0.9)
    y = -1.05 + random.uniform(-0.22, 0.22)
    z = 0.74 + random.uniform(0, 0.08) * (1 - abs(x))
    c = cyl("Moneda", (x, y, z), 0.085, 0.022, coin, verts=24)
    c.rotation_euler = (random.uniform(-0.4, 0.4), random.uniform(-0.4, 0.4), 0)
# monede care țâșnesc din fantă (momentul câștigului)
for i in range(18):
    side = -1 if i % 2 else 1
    t = (i // 2) / 8
    x = side * (0.45 + t * 1.9) + random.uniform(-0.08, 0.08)
    z = 0.95 + math.sin(t * math.pi * 0.9) * 0.45 + random.uniform(-0.06, 0.1)
    c = cyl("MonedaZbor", (x, -1.35 - random.uniform(0, 0.35), z), 0.1, 0.025, coin, verts=24)
    c.rotation_euler = (random.uniform(0, math.pi), random.uniform(0, math.pi), 0)
# monede pe covor
for i in range(14):
    a = random.uniform(-2.4, -0.6)
    rr = random.uniform(1.3, 2.4)
    c = cyl("MonedaJos", (math.cos(a) * rr, 0.4 + math.sin(a) * rr, 0.06), 0.085, 0.022, coin, verts=24)
    c.rotation_euler = (random.uniform(-0.2, 0.2), 0, 0)

# coroana: dom de sticlă cu bule și cristalul „jackpot”
cyl("Guler", (0, 0.1, 3.25), 0.95, 0.22, brass, bev=0.04)
torus("GulerInel", (0, 0.1, 3.36), 0.92, 0.05, brass_dk)
dome = sph("Dom", (0, 0.1, 3.36), 0.9, bubble_mat("BulaDom", "8ff7ff", "ffb6f0"), 64)
for v in dome.data.vertices:
    if v.co.z < -0.02:
        v.co.z = -0.02
gem = bk.mat("CristalJackpot", "ff9bd8", 0.05, 0.0, emit="ff4fb0", strength=4.0)
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.3, location=(0, 0.1, 3.85))
g = bpy.context.object
g.scale.z = 1.35
g.rotation_euler = (0.2, 0.3, 0.1)
setmat(g, gem)
cyl("SuportCristal", (0, 0.1, 3.5), 0.16, 0.25, brass, bev=0.02)
for i in range(16):
    a = random.uniform(0, math.tau)
    rr = random.uniform(0.25, 0.7)
    z = random.uniform(3.5, 4.05)
    if Vector((math.cos(a) * rr, math.sin(a) * rr, z - 3.36)).length < 0.82:
        sph("BulaMica", (math.cos(a) * rr, 0.1 + math.sin(a) * rr, z), random.uniform(0.05, 0.12), BUB, 24)
# bule care ies prin vârf
cyl("Teava", (0, 0.1, 4.33), 0.07, 0.2, brass)
for i, (dx, dz, r) in enumerate([(0.15, 0.55, 0.12), (-0.25, 0.95, 0.18), (0.3, 1.35, 0.1), (-0.05, 1.6, 0.22)]):
    sph("BulaZbor", (dx, 0.1, 4.3 + dz), r, BUB, 32)

# maneta
cyl("ManetaBaza", (1.78, 0.0, 1.7), 0.16, 0.22, brass, rot=(0, math.pi / 2, 0), bev=0.02)
bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=0.05, depth=1.2, location=(1.98, -0.15, 2.25),
                                    rotation=(-0.35, 0.15, 0))
setmat(smooth(bpy.context.object), brass)
sph("ManetaBula", (2.05, -0.36, 2.86), 0.24, bubble_mat("BulaManeta", "ff8fc8", "ffd36a"), 48)
sph("ManetaMiez", (2.05, -0.36, 2.86), 0.13, bk.mat("MiezRoz", "ff5fa8", 0.2, emit="ff3f98", strength=2.5), 32)

# ---------------------------------------------------------------- mascota
try:
    bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, "godot", "assets", "models", "mascota.glb"))
    objs = bpy.context.selected_objects
    roots = [o for o in objs if o.parent is None]
    pts = [o.matrix_world @ Vector(c) for o in objs if o.type == "MESH" for c in o.bound_box]
    h = max(p.z for p in pts) - min(p.z for p in pts)
    s = 0.95 / h
    for r_ in roots:
        r_.scale *= s
        r_.location = (-1.12, -0.25, 3.15)
        r_.rotation_euler.z += math.radians(-12)
except Exception as ex:  # fără mascotă scena rămâne validă
    print("mascota lipsește:", ex)

# ---------------------------------------------------------------- nori și bule în fundal
cloud = bk.mat("Nor", "ffffff", 1.0, emit="ffe6f0", strength=0.25)
def cloud_puff(cx, cy, cz, sc_, n=9):
    for i in range(n):
        sph("Nor", (cx + random.uniform(-1.6, 1.6) * sc_, cy + random.uniform(-0.4, 0.4) * sc_,
                    cz + random.uniform(-0.2, 0.5) * sc_), random.uniform(0.6, 1.1) * sc_, cloud, 24)
cloud_puff(-5.5, 6, -1.0, 1.6)
cloud_puff(6.0, 7, -0.6, 1.8)
cloud_puff(0.5, 12, -2.5, 2.6)
cloud_puff(-7.5, 14, 4.5, 1.4)
cloud_puff(8.5, 16, 6.5, 1.5)
cloud_puff(-3.0, -3.0, -2.6, 1.0)
cloud_puff(4.0, -2.0, -2.9, 1.1)
for i in range(22):
    x = random.uniform(-5, 5)
    z = random.uniform(0.5, 7.5)
    y = random.uniform(-2.5, 6)
    if abs(x) < 2.3 and z < 5 and y < 2:
        continue
    sph("BulaFundal", (x, y, z), random.uniform(0.08, 0.35), BUB, 32)
# scântei
spark = bk.mat("Scanteie", "ffffff", 0.2, emit="fff0b0", strength=14)
for i in range(30):
    a = random.uniform(0, math.tau)
    rr = random.uniform(1.0, 2.6)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=random.uniform(0.015, 0.04),
                                          location=(math.cos(a) * rr, -1.0 + random.uniform(-0.3, 0.3), 2.2 + math.sin(a) * rr * 0.9))
    setmat(bpy.context.object, spark)

# ---------------------------------------------------------------- lumini și cameră
def light(name, kind, loc, energy, color, size=1.0, rot=None, target=None):
    d = bpy.data.lights.new(name, kind)
    d.energy = energy
    d.color = bk.rgb(color)
    if kind == "AREA":
        d.size = size
    if kind == "SUN":
        d.angle = math.radians(size)
    o = bpy.data.objects.new(name, d)
    o.location = loc
    link(o)
    if target is not None:
        tr = o.constraints.new("TRACK_TO")
        e_ = bpy.data.objects.new(name + "_t", None)
        e_.location = target
        link(e_)
        tr.target = e_
        tr.track_axis = "TRACK_NEGATIVE_Z"
        tr.up_axis = "UP_Y"
    return o


light("Soare", "SUN", (5, -4, 8), 3.2, "ffe2b8", 3.0, target=(0, 0, 1.5))
light("Cheie", "AREA", (-4.5, -5.5, 5.5), 900, "fff0dc", 4.0, target=(0, 0, 2.0))
light("Umplere", "AREA", (5, -4, 1.5), 380, "c8b4ff", 3.0, target=(0, 0, 2.0))
light("Contur", "AREA", (0, 4.5, 6.0), 700, "8ff3ff", 4.0, target=(0, 0, 2.5))
light("Fereastra", "AREA", (0, -1.6, 2.6), 45, "fff0d8", 2.6, target=(0, 0, 2.0))
light("Dom", "POINT", (0, 0.1, 3.85), 40, "ff8fd0")

cam_d = bpy.data.cameras.new("Cam")
cam_d.lens = 40
cam_d.sensor_fit = "VERTICAL"
cam_d.sensor_height = 36
cam_d.dof.use_dof = True
cam_d.dof.aperture_fstop = 2.8
cam = bpy.data.objects.new("Cam", cam_d)
cam.location = (0.2, -9.6, 3.0)
link(cam)
foc = bpy.data.objects.new("Focus", None)
foc.location = (0, -0.7, 2.25)
link(foc)
t = cam.constraints.new("TRACK_TO")
t.target = foc
t.track_axis = "TRACK_NEGATIVE_Z"
t.up_axis = "UP_Y"
cam_d.dof.focus_object = foc
sc.camera = cam

# ---------------------------------------------------------------- randare
r = sc.render
r.engine = "CYCLES"
r.resolution_x = W
r.resolution_y = int(W * 16 / 9)
r.film_transparent = False
sc.cycles.samples = SAMPLES
sc.cycles.use_denoising = False
sc.cycles.max_bounces = 12
sc.cycles.transmission_bounces = 12
sc.cycles.transparent_max_bounces = 16
sc.cycles.caustics_reflective = False
sc.cycles.caustics_refractive = False
sc.cycles.blur_glossy = 1.0
sc.view_settings.view_transform = "AgX"
try:
    sc.view_settings.look = "AgX - Punchy"
except TypeError:
    pass
r.filepath = OUT
bpy.ops.render.render(write_still=True)
print("RANDARE:", OUT)
