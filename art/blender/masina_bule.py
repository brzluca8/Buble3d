"""Mașina de bule – automatul paginii de rotiri, în stilul original Buble (fără role: rolele le face jocul).

Rulare:
    blender -b --factory-startup --python art/blender/masina_bule.py -- godot/assets/models/mecanism.glb [preview.png]

Corp de catifea violet pe soclu în trepte, coloane de alamă cu capete turcoaz, placă violet
deschis cu fereastra rolelor (ramă de alamă, becuri calde, săgeți aurii pe linia de câștig),
panou crem cu fanta pentru monede, tavă aurie, dom de sticlă cu cristalul roz și bule mici,
manetă cu bulă roz. După randarea de concept art/concept/pagina_rotiri.png.
Unități reale (nu se scalează în joc). Fața spre -Y (Blender) = +Z (Godot).
Fereastra rolelor: centrul (0, 2.05) în Godot (x, y), lățime 2.6, înălțime 1.44; rolele stau la z = 0.02.
Noduri animate în joc: „Maneta" (pivot, se rotește pe X), „Roata0..2" (bulele din dom, se rotesc).
Materialul „CascaSticla" primește în joc sticla irizată (shaders/glass_globe.gdshader).
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bk  # noqa: E402
import bpy  # noqa: E402
from bk import box, cyl, sphere, torus  # noqa: E402

A = bk.args()
OUT = A[0] if A else "mecanism.glb"
PREVIEW = A[1] if len(A) > 1 else None
random.seed(7)

bk.reset_scene()
M = {
    "brass": bk.mat("Alama", "e9b54a", 0.22, 1.0),
    "brass_dk": bk.mat("AlamaInchisa", "b9822c", 0.3, 1.0),
    "velvet": bk.mat("Catifea", "4a2a8e", 0.85),
    "velvet_lt": bk.mat("CatifeaDeschisa", "6a44c0", 0.75),
    "enamel": bk.mat("EmailTurcoaz", "1fb2ab", 0.25, coat=0.6),
    "cream": bk.mat("Crem", "f6ecd8", 0.5, coat=0.3),
    "bulb": bk.mat("Bec", "fff1c8", 0.3, emit="ffc56a", strength=6.0),
    "shadow": bk.mat("Interior", "2a1850", 0.9),
    "arrow": bk.mat("Sageata", "ffd24a", 0.2, 1.0, emit="ffb020", strength=2.0),
    "gem": bk.mat("CristalJackpot", "ff9bd8", 0.05, emit="ff4fb0", strength=3.0),
    "pink": bk.mat("MiezRoz", "ff5fa8", 0.2, emit="ff3f98", strength=2.5),
    "glass": bk.mat("CascaSticla", "cdeeff", 0.05, alpha=0.18),
}
WZ = 2.05
FY = -0.76

root = bk.empty("Mecanism")
bk.set_parent(root)

# soclu în trepte
box((3.8, 2.0, 0.3), (0, 0.2, 0.15), M["velvet_lt"], bevel=0.06)
box((3.5, 1.8, 0.26), (0, 0.2, 0.42), M["brass_dk"], bevel=0.05)
# corp
box((3.3, 0.5, 2.6), (0, 0.55, 1.85), M["velvet"], bevel=0.08)
for s in (-1, 1):
    box((0.36, 1.5, 2.6), (s * 1.47, 0.0, 1.85), M["velvet"], bevel=0.08)
box((3.3, 1.5, 0.8), (0, 0.0, 0.95), M["velvet"], bevel=0.08)
box((3.3, 1.5, 0.4), (0, 0.0, 2.95), M["velvet"], bevel=0.08)
box((2.6, 0.1, 1.4), (0, 0.45, WZ), M["shadow"])
# placa din față (4 bucăți în jurul ferestrei)
box((3.1, 0.06, 0.34), (0, FY, WZ + 0.72 + 0.17 + 0.02), M["velvet_lt"], bevel=0.02)
box((3.1, 0.06, 0.08), (0, FY, WZ - 0.72 - 0.04), M["velvet_lt"], bevel=0.01)
for s in (-1, 1):
    box((0.25, 0.06, 1.44), (s * 1.425, FY, WZ), M["velvet_lt"], bevel=0.01)
# coloane de alamă cu capete turcoaz
for x in (-1.72, 1.72):
    cyl(0.13, 2.6, (x, -0.62, 1.85), M["brass"], seg=24)
    for z in (0.62, 3.1):
        cyl(0.19, 0.12, (x, -0.62, z), M["brass_dk"], seg=24)
    sphere(0.2, (x, -0.62, 3.32), M["enamel"], seg=24, rings=12)
# rama ferestrei
for z in (WZ - 0.72, WZ + 0.72):
    cyl(0.07, 2.74, (0, -0.8, z), M["brass"], seg=16, rot=(0, math.pi / 2, 0))
for x in (-1.3, 1.3):
    cyl(0.07, 1.5, (x, -0.8, WZ), M["brass"], seg=16)
for x in (-0.43, 0.43):
    cyl(0.03, 1.4, (x, -0.62, WZ), M["brass_dk"], seg=10)
# becuri
for i in range(13):
    x = -1.3 + i * (2.6 / 12)
    for z in (WZ - 0.86, WZ + 0.86):
        sphere(0.045, (x, -0.82, z), M["bulb"], seg=10, rings=6)
for i in range(1, 6):
    z = WZ - 0.72 + i * (1.44 / 6)
    for x in (-1.44, 1.44):
        sphere(0.045, (x, -0.82, z), M["bulb"], seg=10, rings=6)
# săgeți pe linia de câștig
for s in (-1, 1):
    bpy.ops.mesh.primitive_cone_add(vertices=3, radius1=0.12, depth=0.05, location=(s * 1.2, -0.86, WZ),
                                    rotation=(math.pi / 2, 0, -s * math.pi / 2))
    bk._done(bpy.context.active_object, M["arrow"], smooth=False)
# panou crem cu fanta, tava
box((2.7, 0.08, 0.62), (0, -0.8, 0.95), M["cream"], bevel=0.04)
torus(0.32, 0.05, (0, -0.86, 1.05), M["brass"], rot=(math.pi / 2, 0, 0), seg=40, sides=10)
cyl(0.3, 0.02, (0, -0.85, 1.05), M["shadow"], seg=32, rot=(math.pi / 2, 0, 0))
box((2.2, 0.7, 0.16), (0, -1.05, 0.62), M["brass"], bevel=0.05)
box((2.0, 0.55, 0.1), (0, -1.05, 0.67), M["brass_dk"], bevel=0.02)
for i in range(30):
    x = random.uniform(-0.9, 0.9)
    y = -1.05 + random.uniform(-0.2, 0.2)
    cyl(0.085, 0.022, (x, y, 0.74 + random.uniform(0, 0.06)), M["brass"], seg=12,
        rot=(random.uniform(-0.4, 0.4), random.uniform(-0.4, 0.4), 0), smooth=False)
# domul de deasupra: guler, cristal, sticlă
cyl(0.95, 0.22, (0, 0.1, 3.25), M["brass"], seg=48)
torus(0.92, 0.05, (0, 0.1, 3.36), M["brass_dk"], seg=48, sides=10)
cyl(0.16, 0.25, (0, 0.1, 3.5), M["brass"], seg=16)
bk.ico(0.3, (0, 0.1, 3.85), M["gem"], scale=(1, 1, 1.35))
bpy.ops.mesh.primitive_uv_sphere_add(segments=48, ring_count=24, radius=0.9, location=(0, 0.1, 3.36))
dome = bpy.context.active_object
bk.keep(dome, lambda c: c.z >= -0.02)
bk._done(dome, M["glass"])
cyl(0.07, 0.2, (0, 0.1, 4.33), M["brass"], seg=12)
# bule mici în dom, în trei grupuri care se rotesc în joc
gears = []
for gi in range(3):
    g = bk.empty("Roata%d" % gi, (0, 0.1, 3.36))
    old = bk._parent[:]
    bk.set_parent(g)
    for k in range(5):
        a = random.uniform(0, math.tau)
        rr = random.uniform(0.35, 0.68)
        z = random.uniform(3.45, 3.95)
        sphere(random.uniform(0.05, 0.1), (math.cos(a) * rr, 0.1 + math.sin(a) * rr, z), M["glass"], seg=12, rings=8)
    bk.set_parent(old[0])
    gears.append(g)
# maneta cu bulă roz
cyl(0.16, 0.22, (1.78, 0.0, 1.7), M["brass"], seg=24, rot=(0, math.pi / 2, 0))
lever = bk.empty("Maneta", (1.84, 0.0, 1.7))
old = bk._parent[:]
bk.set_parent(lever)
cyl(0.05, 1.15, (1.95, 0.0, 2.25), M["brass"], seg=12)
sphere(0.13, (1.95, 0.0, 2.86), M["pink"], seg=20, rings=10)
sphere(0.24, (1.95, 0.0, 2.86), M["glass"], seg=24, rings=12)
bk.set_parent(old[0])
bk.set_parent(None)

bk.apply_and_join(root, "MasinaCorp", keep_empties=[lever] + gears)
bk.export_glb(OUT)

if PREVIEW:
    bk.preview(PREVIEW, target=(0, 0, 2.2), cam_loc=(1.5, -8.5, 3.2), lens=40, res=640, bg=(0.55, 0.45, 0.75))
