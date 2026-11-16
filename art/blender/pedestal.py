"""Piedestalul globului de sticlă (piedestal.glb): bază violet în trepte, inele aurii, rune turcoaz luminoase.

Rulare:
    blender -b --factory-startup --python art/blender/pedestal.py -- godot/assets/models/piedestal.glb [preview.png]

Originea = centrul bazei, partea de sus a piedestalului la z = TOP (globul stă deasupra). Raza ~5.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bk  # noqa: E402
from bk import box, cyl, lathe, sphere, torus  # noqa: E402

A = bk.args()
OUT = A[0] if A else "piedestal.glb"
PREVIEW = A[1] if len(A) > 1 else None

bk.reset_scene()
P = bk.palette()
P["pedestal"] = bk.mat("Piedestal", "5a3aa8", 0.35, 0.15)
P["pedestal_dk"] = bk.mat("PiedestalInchis", "3a2478", 0.4, 0.1)
P["rune"] = bk.mat("Rune", "6ff0e8", 0.2, emit="2fe0d0", strength=4.0)
root = bk.empty("Piedestal")
bk.set_parent(root)

# profil în trepte (rază, înălțime), de jos în sus
prof = [(4.9, 0.0), (5.0, 0.12), (5.0, 0.42), (4.75, 0.5), (4.5, 0.62), (4.35, 1.05), (4.55, 1.2), (4.6, 1.32), (4.3, 1.42), (0.0001, 1.42)]
lathe(prof, (0, 0, 0), P["pedestal"], seg=96)
# inele aurii
for z, r, t in ((0.44, 4.82, 0.07), (0.64, 4.52, 0.05), (1.22, 4.6, 0.07), (1.4, 4.32, 0.05)):
    torus(r, t, (0, 0, z), P["gold"], seg=96, sides=10)
# bandă întunecată cu rune luminoase
lathe([(4.37, 0.68), (4.37, 1.0)], (0, 0, 0), P["pedestal_dk"], seg=96)
for i in range(28):
    a = math.tau * i / 28
    x, y = math.cos(a) * 4.4, math.sin(a) * 4.4
    with bk.group("Runa", (x, y, 0.84), (0, 0, a + math.pi / 2)):
        k = i % 4
        if k == 0:
            box((0.05, 0.03, 0.22), (0, 0, 0), P["rune"])
            box((0.16, 0.03, 0.05), (0, 0, 0.06), P["rune"])
        elif k == 1:
            box((0.05, 0.03, 0.22), (-0.05, 0, 0), P["rune"])
            box((0.05, 0.03, 0.16), (0.05, 0, 0.03), P["rune"], rot=(0, 0.6, 0))
        elif k == 2:
            torus(0.07, 0.018, (0, 0, 0), P["rune"], rot=(math.pi / 2, 0, 0), seg=12, sides=4)
            box((0.03, 0.03, 0.22), (0, 0, 0), P["rune"])
        else:
            box((0.16, 0.03, 0.04), (0, 0, -0.08), P["rune"])
            box((0.04, 0.03, 0.2), (0, 0, 0.02), P["rune"], rot=(0, -0.5, 0))
# patru picioare aurii
for i in range(4):
    a = math.tau * i / 4 + math.pi / 4
    sphere(0.35, (math.cos(a) * 4.5, math.sin(a) * 4.5, 0.05), P["gold"], scale=(1, 1, 0.55), seg=20, rings=10)

bk.set_parent(None)
bk.apply_and_join(root, "Piedestal")
bk.export_glb(OUT)
if PREVIEW:
    bk.preview(PREVIEW, target=(0, 0, 0.7), cam_loc=(0, -12, 5), lens=45, res=480, bg=(0.15, 0.12, 0.35))
