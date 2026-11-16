"""Mecanismul – automatul Neon noir al paginii de rotiri (fără role: rolele le face jocul).

Rulare:
    blender -b --factory-startup --python art/blender/mecanism.py -- godot/assets/models/mecanism.glb [preview.png]

Dulap de grafit mat cu colțuri rotunjite, muchii de crom, benzi LED magenta pe laterale,
fereastra rolelor încadrată de un tub de neon turcoaz, panou de sticlă neagră cu fanta
pentru monede (inel chihlimbar), tavă de crom, deasupra un „halou” – un inel de neon cu
inele holografice care se rotesc – și o manetă de crom cu sferă magenta.
Unități reale (nu se scalează în joc). Fața spre -Y (Blender) = +Z (Godot).
Fereastra rolelor: centrul (0, 2.05) în Godot (x, y), lățime 2.6, înălțime 1.44; rolele stau la z = 0.02.
Noduri animate în joc: „Maneta" (pivot, se rotește pe X), „Roata0..2" (arce holografice, pe axa ferestrei).
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
    "grafit": bk.mat("Grafit", "15161d", 0.45, 0.3),
    "lac": bk.mat("LacNegru", "08090d", 0.12, 0.2, coat=1.0),
    "crom": bk.mat("Crom", "d8dde6", 0.12, 1.0),
    "cyan": bk.mat("NeonTurcoaz", "9ff8ff", 0.3, emit="37e8f5", strength=5.0),
    "pink": bk.mat("NeonMagenta", "ffb0dc", 0.3, emit="ff3fa4", strength=5.0),
    "amber": bk.mat("NeonChihlimbar", "ffe0a0", 0.3, emit="ffb43a", strength=4.0),
    "sticla": bk.mat("SticlaNeagra", "0c0e16", 0.05, 0.1, coat=1.0),
    "interior": bk.mat("Interior", "040508", 0.9),
}
WZ = 2.05
FY = -0.76

root = bk.empty("Mecanism")
bk.set_parent(root)

# ---------------- soclu cu bandă LED
box((3.8, 2.0, 0.42), (0, 0.2, 0.21), M["grafit"], bevel=0.12, segs=4)
box((3.5, 0.02, 0.04), (0, -0.81, 0.12), M["cyan"])
box((3.9, 2.1, 0.03), (0, 0.2, 0.43), M["crom"], bevel=0.01)

# ---------------- corpul: o singură carcasă rotunjită, cu fereastra „decupată” din panouri
box((0.5, 1.6, 2.8), (-1.5, 0.05, 1.85), M["grafit"], bevel=0.22, segs=6)
box((0.5, 1.6, 2.8), (1.5, 0.05, 1.85), M["grafit"], bevel=0.22, segs=6)
box((3.0, 0.4, 2.8), (0, 0.65, 1.85), M["grafit"], bevel=0.1)
box((2.62, 0.05, 1.5), (0, 0.5, WZ), M["interior"])
box((2.8, 0.1, 0.42), (0, FY + 0.05, WZ + 0.72 + 0.21), M["lac"], bevel=0.03)
box((2.8, 0.1, 0.8), (0, FY + 0.05, 0.9), M["lac"], bevel=0.03)
for s in (-1, 1):
    box((0.12, 0.1, 1.5), (s * 1.37, FY + 0.05, WZ), M["lac"], bevel=0.02)
# benzi LED magenta pe laterale (verticale) și muchii de crom
for s in (-1, 1):
    box((0.03, 0.03, 2.3), (s * 1.62, -0.76, 1.9), M["pink"])
    box((0.04, 1.4, 0.04), (s * 1.76, 0.05, 3.2), M["crom"], bevel=0.015)
    box((0.04, 1.4, 0.04), (s * 1.76, 0.05, 0.55), M["crom"], bevel=0.015)

# ---------------- fereastra: tub de neon turcoaz + filet magenta, săgeți pe linia de câștig
def tube(a, b, m, r=0.028):
    a, b = list(a), list(b)
    mid = [(a[i] + b[i]) / 2 for i in range(3)]
    dx, dz = b[0] - a[0], b[2] - a[2]
    length = math.hypot(dx, dz)
    cyl(r, length, mid, m, seg=10, rot=(0, math.atan2(dx, dz), 0))


x0, x1, z0, z1, y = -1.32, 1.32, WZ - 0.77, WZ + 0.77, FY - 0.03
for a, b in [((x0, y, z0), (x1, y, z0)), ((x0, y, z1), (x1, y, z1)), ((x0, y, z0), (x0, y, z1)), ((x1, y, z0), (x1, y, z1))]:
    tube(a, b, M["cyan"])
for c in [(x0, y, z0), (x1, y, z0), (x0, y, z1), (x1, y, z1)]:
    sphere(0.028, c, M["cyan"], seg=10, rings=6)
for z in (z0 - 0.08, z1 + 0.08):
    box((2.0, 0.02, 0.018), (0, FY - 0.02, z), M["pink"])
for x in (-0.43, 0.43):
    box((0.025, 0.05, 1.44), (x, -0.62, WZ), M["crom"])
for s in (-1, 1):
    bpy.ops.mesh.primitive_cone_add(vertices=3, radius1=0.08, depth=0.03, location=(s * 1.22, FY - 0.07, WZ),
                                    rotation=(math.pi / 2, 0, -s * math.pi / 2))
    bk._done(bpy.context.active_object, M["pink"], smooth=False)

# ---------------- panoul de jos: sticlă neagră, fanta cu inel chihlimbar, tavă de crom
box((2.4, 0.04, 0.5), (0, FY - 0.01, 1.0), M["sticla"], bevel=0.02)
torus(0.17, 0.022, (0, FY - 0.05, 1.02), M["amber"], rot=(math.pi / 2, 0, 0), seg=40, sides=8)
box((0.22, 0.03, 0.035), (0, FY - 0.05, 1.02), M["interior"])
for s in (-1, 1):
    for i in range(4):
        box((0.06, 0.02, 0.2 - i * 0.03), (s * (0.5 + i * 0.12), FY - 0.04, 1.0), M["cyan" if i == 0 else "grafit"])
box((2.0, 0.6, 0.1), (0, FY - 0.32, 0.6), M["crom"], bevel=0.04)
box((1.84, 0.46, 0.05), (0, FY - 0.32, 0.65), M["lac"])
box((1.9, 0.02, 0.02), (0, FY - 0.63, 0.6), M["amber"])

# ---------------- haloul de deasupra: inel de neon, sticlă neagră, arce holografice
box((3.0, 1.5, 0.22), (0, 0.1, 3.36), M["grafit"], bevel=0.08)
box((3.0, 0.02, 0.025), (0, -0.66, 3.3), M["cyan"])
HZ = 4.05
HY = -0.05
cyl(0.62, 0.12, (0, HY + 0.08, HZ), M["grafit"], seg=48, rot=(math.pi / 2, 0, 0))
cyl(0.58, 0.02, (0, HY - 0.0, HZ), M["sticla"], seg=48, rot=(math.pi / 2, 0, 0))
torus(0.6, 0.035, (0, HY - 0.03, HZ), M["cyan"], rot=(math.pi / 2, 0, 0), seg=64, sides=8)
torus(0.66, 0.015, (0, HY + 0.0, HZ), M["crom"], rot=(math.pi / 2, 0, 0), seg=64, sides=6)
box((0.5, 0.5, 0.42), (0, 0.15, 3.6), M["grafit"], bevel=0.08)


def arc_ring(name, R, r, arc, m, rot0):
    g = bk.empty(name, (0, HY - 0.05, HZ))
    old = bk._parent[:]
    bk.set_parent(g)
    for k in range(2):
        o = torus(R, r, (0, HY - 0.05, HZ), m, rot=(math.pi / 2, rot0 + k * math.pi, 0), seg=48, sides=6, arc=arc)
    bk.set_parent(old[0])
    return g


gears = [arc_ring("Roata0", 0.48, 0.018, math.radians(110), M["pink"], 0.0),
         arc_ring("Roata1", 0.38, 0.014, math.radians(70), M["cyan"], 0.6),
         arc_ring("Roata2", 0.27, 0.012, math.radians(140), M["amber"], 1.2)]
sphere(0.1, (0, HY - 0.06, HZ), M["pink"], seg=20, rings=10)

# ---------------- maneta de crom cu sferă magenta (pivot pe dreapta)
cyl(0.16, 0.24, (1.82, 0.0, 1.75), M["grafit"], seg=24, rot=(0, math.pi / 2, 0))
torus(0.16, 0.02, (1.95, 0.0, 1.75), M["cyan"], rot=(0, math.pi / 2, 0), seg=32, sides=6)
lever = bk.empty("Maneta", (1.9, 0.0, 1.75))
old = bk._parent[:]
bk.set_parent(lever)
cyl(0.04, 1.05, (1.95, 0.0, 2.27), M["crom"], seg=12)
sphere(0.15, (1.95, 0.0, 2.86), M["pink"], seg=24, rings=12)
bk.set_parent(old[0])
bk.set_parent(None)

bk.apply_and_join(root, "MecanismCorp", keep_empties=[lever] + gears)
bk.export_glb(OUT)

if PREVIEW:
    bk.preview(PREVIEW, target=(0, 0, 2.2), cam_loc=(1.5, -8.5, 3.2), lens=40, res=640, bg=(0.02, 0.02, 0.04))
