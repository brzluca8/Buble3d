"""Mecanismul – automatul Art Deco al paginii de rotiri (fără role: rolele le face jocul).

Rulare:
    blender -b --factory-startup --python art/blender/mecanism.py -- godot/assets/models/mecanism.glb [preview.png]

Dulap de nuc și lac negru, filete și pilaștri cu caneluri aurii, coroană în trepte cu
evantai (sunburst) și hublou cu roți dințate, două aplice de sticlă mată, fereastra rolelor
cu ramă de alamă, placă de fildeș cu fanta pentru monede, tavă și manetă cu mâner de fildeș.
Unități reale (nu se scalează în joc). Fața spre -Y (Blender) = +Z (Godot).
Fereastra rolelor: centrul (0, 2.05) în Godot (x, y), lățime 2.6, înălțime 1.44; rolele stau la z = 0.02.
Noduri animate în joc: „Maneta" (pivot, se rotește pe X), „Roata0..2" (se rotesc pe axa fereastrei).
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bk  # noqa: E402
import bpy  # noqa: E402
from bk import box, cyl, sphere, torus  # noqa: E402

A = bk.args()
OUT = A[0] if A else "mecanism.glb"
PREVIEW = A[1] if len(A) > 1 else None

bk.reset_scene()
M = {
    "lac": bk.mat("Lac", "101218", 0.18, coat=1.0),
    "nuc": bk.mat("Nuc", "4a2a1a", 0.42, coat=0.6),
    "aur": bk.mat("Auriu", "d9b56c", 0.22, 1.0),
    "aur_dk": bk.mat("AlamaInchisa", "8a6a32", 0.32, 1.0),
    "fildes": bk.mat("Fildes", "efe6d2", 0.4, coat=0.4),
    "smarald": bk.mat("Smarald", "1e5a4c", 0.3, coat=0.8),
    "lampa": bk.mat("Lampa", "fff1d6", 0.5, emit="ffcf8a", strength=3.5),
    "sticla": bk.mat("Hublou", "a8b8c0", 0.08, alpha=0.25),
    "interior": bk.mat("Interior", "07080c", 0.9),
}
WZ = 2.05            # centrul ferestrei
FY = -0.76           # fața plăcii frontale

root = bk.empty("Mecanism")
bk.set_parent(root)

# ---------------- soclu în trepte
box((3.9, 2.0, 0.22), (0, 0.2, 0.11), M["lac"], bevel=0.03)
box((3.96, 2.06, 0.03), (0, 0.2, 0.235), M["aur"])
box((3.6, 1.8, 0.24), (0, 0.2, 0.37), M["lac"], bevel=0.03)
box((3.66, 1.86, 0.025), (0, 0.2, 0.5), M["aur"])

# ---------------- corpul: laterale de nuc, spate, interior întunecat
box((0.42, 1.6, 2.7), (-1.5, 0.05, 1.85), M["nuc"], bevel=0.04)
box((0.42, 1.6, 2.7), (1.5, 0.05, 1.85), M["nuc"], bevel=0.04)
box((3.0, 0.3, 2.7), (0, 0.7, 1.85), M["nuc"], bevel=0.03)
box((2.62, 0.05, 1.5), (0, 0.5, WZ), M["interior"])
# placa frontală din lac, în jurul ferestrei (4 bucăți)
box((3.0, 0.08, 0.38), (0, FY + 0.04, WZ + 0.72 + 0.19 + 0.02), M["lac"], bevel=0.01)
box((3.0, 0.08, 0.8), (0, FY + 0.04, 0.5 + 0.4), M["lac"], bevel=0.01)
for s in (-1, 1):
    box((0.2, 0.08, 1.5), (s * 1.4, FY + 0.04, WZ), M["lac"], bevel=0.01)
# pilaștri cu caneluri aurii
for s in (-1, 1):
    x = s * 1.72
    box((0.12, 0.12, 2.7), (x, -0.62, 1.85), M["lac"], bevel=0.01)
    for k in (-1, 0, 1):
        cyl(0.012, 2.5, (x + k * 0.035, -0.69, 1.85), M["aur"], seg=6)
    box((0.2, 0.18, 0.08), (x, -0.62, 0.55), M["aur"], bevel=0.01)
    box((0.2, 0.18, 0.08), (x, -0.62, 3.15), M["aur"], bevel=0.01)

# ---------------- rama ferestrei, linia de câștig
for z in (WZ - 0.76, WZ + 0.76):
    box((2.76, 0.1, 0.08), (0, FY - 0.02, z), M["aur"], bevel=0.015)
for x in (-1.34, 1.34):
    box((0.08, 0.1, 1.6), (x, FY - 0.02, WZ), M["aur"], bevel=0.015)
for x in (-0.43, 0.43):
    box((0.03, 0.06, 1.44), (x, -0.62, WZ), M["aur_dk"])
for s in (-1, 1):
    bpy.ops.mesh.primitive_cone_add(vertices=3, radius1=0.09, depth=0.04, location=(s * 1.24, FY - 0.08, WZ),
                                    rotation=(math.pi / 2, 0, -s * math.pi / 2))
    bk._done(bpy.context.active_object, M["aur"], smooth=False)
# filet orizontal sub și peste fereastră (motiv în trepte)
for i, w in enumerate((2.2, 1.6, 1.0)):
    box((w, 0.02, 0.025), (0, FY - 0.01, WZ + 0.86 + i * 0.06), M["aur"])

# ---------------- placa de fildeș, fanta pentru monede, tava
box((2.5, 0.06, 0.62), (0, FY - 0.02, 0.98), M["fildes"], bevel=0.02)
box((2.6, 0.04, 0.03), (0, FY - 0.05, 1.3), M["aur"])
box((2.6, 0.04, 0.03), (0, FY - 0.05, 0.66), M["aur"])
torus(0.2, 0.035, (0, FY - 0.06, 1.0), M["aur"], rot=(math.pi / 2, 0, 0), seg=40, sides=8)
box((0.26, 0.04, 0.045), (0, FY - 0.06, 1.0), M["interior"])
for s in (-1, 1):
    for i in range(3):
        box((0.42 - i * 0.12, 0.02, 0.018), (s * (0.62 + i * 0.06), FY - 0.06, 0.88 + i * 0.12), M["aur_dk"])
box((2.1, 0.62, 0.12), (0, FY - 0.33, 0.6), M["aur"], bevel=0.03)
box((1.94, 0.5, 0.06), (0, FY - 0.33, 0.66), M["aur_dk"])

# ---------------- coroana în trepte, cu evantai și hublou
box((3.2, 1.7, 0.16), (0, 0.05, 3.28), M["lac"], bevel=0.02)
box((3.26, 1.76, 0.03), (0, 0.05, 3.37), M["aur"])
box((2.5, 1.3, 0.2), (0, 0.15, 3.48), M["lac"], bevel=0.02)
box((2.56, 1.36, 0.025), (0, 0.15, 3.59), M["aur"])
box((1.7, 0.9, 0.18), (0, 0.25, 3.68), M["lac"], bevel=0.02)
# evantaiul (semidisc de lac cu raze aurii)
fan_y = -0.2
bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=1.05, depth=0.08, location=(0, fan_y, 3.77), rotation=(math.pi / 2, 0, 0))
fan = bpy.context.active_object
bk.keep(fan, lambda c: c.z >= -0.001)
bk._done(fan, M["lac"], smooth=False)
torus(1.05, 0.03, (0, fan_y - 0.04, 3.77), M["aur"], rot=(math.pi / 2, 0, 0), seg=48, sides=6, arc=math.pi)
for i in range(13):
    a = math.pi * (i + 0.5) / 13
    box((0.025, 0.02, 0.62), (math.cos(a) * 0.68, fan_y - 0.05, 3.77 + math.sin(a) * 0.68), M["aur"],
        rot=(0, -(a - math.pi / 2), 0))
# hublou cu roți dințate
HZ = 3.98
torus(0.34, 0.05, (0, fan_y - 0.08, HZ), M["aur"], rot=(math.pi / 2, 0, 0), seg=40, sides=8)
cyl(0.33, 0.02, (0, fan_y + 0.06, HZ), M["interior"], seg=32, rot=(math.pi / 2, 0, 0))
cyl(0.32, 0.01, (0, fan_y - 0.09, HZ), M["sticla"], seg=32, rot=(math.pi / 2, 0, 0))


def gear(name, r, teeth, loc, m):
    g = bk.empty(name, loc)
    old = bk._parent[:]
    bk.set_parent(g)
    cyl(r, 0.04, loc, m, seg=32, rot=(math.pi / 2, 0, 0))
    for k in range(teeth):
        a = k / teeth * math.tau
        box((0.045, 0.04, 0.06), (loc[0] + math.cos(a) * (r + 0.02), loc[1], loc[2] + math.sin(a) * (r + 0.02)), m,
            rot=(0, -a, 0))
    cyl(r * 0.25, 0.06, (loc[0], loc[1] - 0.01, loc[2]), M["lac"], seg=16, rot=(math.pi / 2, 0, 0))
    bk.set_parent(old[0])
    return g


gears = [gear("Roata0", 0.15, 12, (-0.1, fan_y + 0.02, HZ + 0.06), M["aur"]),
         gear("Roata1", 0.1, 9, (0.15, fan_y + 0.0, HZ - 0.1), M["aur_dk"]),
         gear("Roata2", 0.07, 7, (0.06, fan_y - 0.02, HZ + 0.2), M["aur"])]
# vârful: o săgeată în trepte
box((0.1, 0.1, 0.3), (0, 0.25, 4.38), M["aur"])
sphere(0.08, (0, 0.25, 4.58), M["aur"], seg=16, rings=8)
# aplice de sticlă mată pe colțuri
for s in (-1, 1):
    cyl(0.12, 0.08, (s * 1.45, -0.3, 3.62), M["aur"], seg=20)
    cyl(0.1, 0.36, (s * 1.45, -0.3, 3.84), M["lampa"], seg=20, r2=0.07)
    cyl(0.08, 0.04, (s * 1.45, -0.3, 4.04), M["aur"], seg=20)

# ---------------- maneta (pivot pe dreapta)
cyl(0.17, 0.2, (1.8, 0.0, 1.75), M["aur"], seg=24, rot=(0, math.pi / 2, 0))
lever = bk.empty("Maneta", (1.86, 0.0, 1.75))
old = bk._parent[:]
bk.set_parent(lever)
cyl(0.045, 1.05, (1.92, 0.0, 2.27), M["aur"], seg=12)
torus(0.05, 0.015, (1.92, 0.0, 2.02), M["lac"], seg=16, sides=6)
sphere(0.16, (1.92, 0.0, 2.86), M["fildes"], seg=24, rings=12)
torus(0.1, 0.02, (1.92, 0.0, 2.74), M["aur"], seg=24, sides=6)
bk.set_parent(old[0])
bk.set_parent(None)

bk.apply_and_join(root, "MecanismCorp", keep_empties=[lever] + gears)
bk.export_glb(OUT)

if PREVIEW:
    bk.preview(PREVIEW, target=(0, 0, 2.2), cam_loc=(1.5, -8.5, 3.2), lens=40, res=640, bg=(0.04, 0.05, 0.08))
