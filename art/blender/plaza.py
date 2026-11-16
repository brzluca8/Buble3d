"""Piața centrală și vegetația insulei (plaza.glb), după randarea de referință.

Rulare:
    blender -b --factory-startup --python art/blender/plaza.py -- godot/assets/models/plaza.glb [preview.png]

Coordonatele sunt cele ale insulei din joc: Godot (x, z) = Blender (x, -y); fără scalare la import.
Fântâna: centrul în Godot (0, 0.3), cristalul din vârf la înălțimea FOUNTAIN_TOP (îl adaugă jocul).
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bk  # noqa: E402
from bk import balustrade_line, box, bush, cyl, cypress, ico, lantern, lathe, sphere, torus  # noqa: E402

A = bk.args()
OUT = A[0] if A else "plaza.glb"
PREVIEW = A[1] if len(A) > 1 else None

bk.reset_scene()
P = bk.palette()
P["hedge"] = bk.mat("GardViu", "3f8a3c", 0.85)
P["water"] = bk.mat("Apa", "7fd8ff", 0.05, emit="2aa0d0", strength=0.6, alpha=0.85)
P["lav"] = bk.mat("LavandaFlori", "9b7ce8", 0.7)
P["leaf_dk"] = bk.mat("FrunzeInchise", "2f6e35", 0.85)
root = bk.empty("Piata")
bk.set_parent(root)


def G(x, z, y=0.0):
    """Godot (x, z) → Blender (x, -z, y)."""
    return (x, -z, y)


FC = (0.0, 0.3)          # centrul fântânii (Godot x, z)
PR = 3.05                # raza pieței

# ---------------- pavaj
lathe([(PR, 0.0), (PR, 0.05), (0.0001, 0.05)], G(*FC), P["paving"], seg=64)
torus(PR + 0.02, 0.09, G(*FC, 0.05), P["stone_dk"], seg=72, sides=8, scale=(1, 1, 0.6))
# alee spre scări și spre palat
box((1.9, 4.1, 0.05), G(0, 5.0, 0.025), P["paving"])
for sx in (-1, 1):
    box((0.12, 4.1, 0.08), G(sx * 1.0, 5.0, 0.04), P["stone_dk"])
box((2.2, 0.9, 0.05), G(0, -2.95, 0.025), P["paving"])
# alei laterale spre observator / magazin / seră / turn
for (x, z, ang, L) in ((-2.9, 1.9, 25, 2.2), (-3.0, -0.9, -15, 1.6), (2.9, -0.9, 15, 1.5), (3.4, 1.5, -30, 2.2)):
    box((L, 1.1, 0.045), G(x, z, 0.022), P["paving"], rot=(0, 0, math.radians(ang)))

# ---------------- fântâna pe trei niveluri
fx, fz = FC
lathe([(1.45, 0.0), (1.5, 0.12), (1.45, 0.42), (1.3, 0.45), (1.25, 0.2)], G(fx, fz), P["stone"], seg=48)
torus(1.42, 0.06, G(fx, fz, 0.45), P["stone_dk"], seg=48)
cyl(1.28, 0.06, G(fx, fz, 0.36), P["water"], seg=48)
cyl(0.2, 0.9, G(fx, fz, 0.8), P["stone"], seg=16, r2=0.16)
lathe([(0.12, 0.0), (0.75, 0.18), (0.82, 0.3), (0.72, 0.32)], G(fx, fz, 1.18), P["stone"], seg=40)
cyl(0.7, 0.04, G(fx, fz, 1.47), P["water"], seg=40)
cyl(0.12, 0.45, G(fx, fz, 1.68), P["stone"], seg=12)
lathe([(0.08, 0.0), (0.38, 0.1), (0.42, 0.18), (0.36, 0.2)], G(fx, fz, 1.88), P["stone"], seg=32)
cyl(0.35, 0.03, G(fx, fz, 2.06), P["water"], seg=32)
for i in range(6):
    a = i * math.tau / 6
    sphere(0.06, G(fx + math.cos(a) * 1.43, fz + math.sin(a) * 1.43, 0.5), P["gold"], seg=8, rings=4)

# ---------------- gard viu în jurul pieței (cu deschideri spre alei)
def hedge_arc(a0, a1, r=PR + 0.35):
    n = max(2, int(abs(a1 - a0) * r / 0.5))
    for i in range(n):
        a = a0 + (a1 - a0) * (i + 0.5) / n
        x, z = FC[0] + math.cos(a) * r, FC[1] + math.sin(a) * r
        box((0.55, 0.42, 0.42), G(x, z, 0.21), P["hedge"], bevel=0.12, rot=(0, 0, -a))


deg = math.radians
for a0, a1 in ((deg(28), deg(62)), (deg(118), deg(152)), (deg(170), deg(195)), (deg(345), deg(370)), (deg(212), deg(248)), (deg(292), deg(328))):
    hedge_arc(a0, a1)

# ---------------- bănci și felinare
for sx in (-1, 1):
    with bk.group("Banca", G(sx * 2.05, 2.55), (0, 0, math.atan2(-2.25, sx * -2.05) + math.pi / 2)):
        for k in range(3):
            box((0.9, 0.09, 0.04), (0, -0.06 + k * 0.1, 0.4), P["wood_lt"], bevel=0.01)
        box((0.9, 0.04, 0.3), (0, 0.17, 0.62), P["wood_lt"], bevel=0.01)
        for xx in (-0.38, 0.38):
            box((0.05, 0.3, 0.4), (xx, 0.05, 0.2), P["gold"], bevel=0.01)
for (x, z) in ((-2.25, 3.2), (2.25, 3.2), (-2.8, -1.9), (2.8, -2.0)):
    lantern(G(x, z), P, h=1.35)

# ---------------- vegetație
for (x, z, c) in ((-2.7, 4.6, "pink"), (2.8, 4.4, "pink"), (1.9, -2.6, "pink"), (-1.9, -2.7, "pink"), (6.3, -0.4, "pink"), (2.2, 6.2, "pink"), (-6.4, 3.3, "pink")):
    bush(G(x, z), 0.5, P, c, n=8, seed=int(x * 7 + z * 3))


def lavender(x, z, n=11, seed=1):
    for i in range(n):
        a = i * 2.39996 + seed
        d = 0.32 * math.sqrt((i + 0.5) / n)
        px, pz = x + math.cos(a) * d, z + math.sin(a) * d
        h = 0.5 + 0.18 * ((i * 37 + seed) % 7) / 7
        cyl(0.012, h, G(px, pz, h / 2), P["leaf"], seg=4)
        cyl(0.045, h * 0.45, G(px, pz, h * 0.78), P["lav"], seg=6, r2=0.012)
    ico(0.28, G(x, z, 0.12), P["leaf_dk"], scale=(1.2, 1.2, 0.5), sub=1)


for (x, z, s) in ((-3.9, 5.3, 1), (-5.4, 4.8, 2), (-3.0, 6.0, 3), (4.2, 4.3, 4), (-6.3, 1.4, 5)):
    lavender(x, z, seed=s)

# câțiva chiparoși înalți, ca accente (nu o pădure)
for (x, z, h) in ((-2.6, -6.2, 2.8), (2.7, -6.2, 2.9), (6.4, -3.6, 2.4), (-6.5, -3.4, 2.5)):
    cypress(G(x, z), h, P)


def round_tree(x, z, s=1.0, seed=1):
    cyl(0.1 * s, 1.0 * s, G(x, z, 0.5 * s), P["wood"], seg=7, r2=0.07 * s)
    for i in range(5):
        a = i * 2.39996 + seed
        d = 0.35 * s * (i > 0)
        ico(0.55 * s * (1.0 if i == 0 else 0.7), G(x + math.cos(a) * d, z + math.sin(a) * d, 1.35 * s + 0.25 * s * (i % 2)), P["leaf"] if i % 2 else P["leaf_lt"], sub=2)


for (x, z, s, k) in ((-6.4, 0.2, 1.0, 1), (6.6, 0.4, 0.95, 4)):
    round_tree(x, z, s, k)

# brâu de vegetație pe marginea insulei (tufe, trandafiri, lavandă), cu goluri la scări și cascade
for i in range(16):
    a = i / 16 * math.tau + 0.05 * math.sin(i * 3.1)
    x, z = math.sin(a) * 6.55, math.cos(a) * 6.55 + 0.0
    deg_front = math.degrees(math.atan2(x, z))
    if abs(deg_front) < 17 or abs(abs(deg_front) - 40) < 7:
        continue
    near_b = any(math.hypot(x - bx, z - bz) < br for (bx, bz, br) in ((0, -4.3, 3.4), (-4.7, -1.5, 2.0), (5.2, 1.7, 1.1), (-4.4, 2.5, 2.0), (3.7, -1.6, 1.8)))
    if near_b:
        continue
    kind = i % 3
    if kind == 0:
        bush(G(x, z), 0.42, P, "pink", n=7, seed=i)
    elif kind == 1:
        lavender(x, z, n=9, seed=i)
    else:
        bush(G(x, z), 0.36, P, "lilac", n=6, seed=i)

# flori mici răsfirate prin iarbă
cols = ["pink", "lilac", "glow_soft", "pink", "lilac"]
k = 0
for i in range(60):
    a = (math.sin(i * 12.9898) * 43758.5453) % 1.0 * math.tau
    r = 3.5 + 3.4 * math.sqrt((math.sin(i * 78.233) * 24634.6345) % 1.0)
    x, z = math.cos(a) * r, math.sin(a) * r + 0.3
    if abs(x) < 1.3 and z > 2.8:
        continue
    if math.hypot(x, z) > 6.85:
        continue
    near_b = False
    for (bx, bz, br) in ((0, -4.3, 3.6), (-4.7, -1.5, 2.2), (5.2, 1.7, 1.2), (-4.4, 2.5, 2.2), (3.7, -1.6, 2.0)):
        if math.hypot(x - bx, z - bz) < br:
            near_b = True
    if near_b:
        continue
    sphere(0.085, G(x, z, 0.1), P[cols[k % len(cols)]], seg=6, rings=3)
    k += 1

bk.set_parent(None)
bk.apply_and_join(root, "Piata")
bk.export_glb(OUT)
if PREVIEW:
    bk.preview(PREVIEW, target=(0, 0, 0.5), cam_loc=(0, -16, 11), lens=35, res=640)
