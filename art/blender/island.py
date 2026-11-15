"""Terenul insulei Buble (insula.glb): stâncă stratificată, iarbă, scări în față cu
balustrade, felinare, liane și cristale dedesubt.

Rulare:
    blender -b --factory-startup --python art/blender/island.py -- godot/models/insula.glb [preview.png]

Originea = nivelul ierbii (z = 0), diametrul = 14.4 (raza 7.2), fața spre -Y.
Piața, fântâna, copacii și clădirile rămân în joc (Godot), deasupra acestui teren.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bk  # noqa: E402
from bk import balustrade_line, box, cyl, ico, lantern, sphere, stairs  # noqa: E402
from mathutils import Vector, noise  # noqa: E402

A = bk.args()
OUT = A[0] if A else "insula.glb"
PREVIEW = A[1] if len(A) > 1 else None

bk.reset_scene()
P = bk.palette()
root = bk.empty("Insula")
bk.set_parent(root)

R = 7.2
SEG = 72
STAIR_W = 1.9          # lățimea scării din față (|x| < 0.95)
STAIR_IN = 6.95        # scara pornește de pe marginea ierbii, în afară


def n3(x, y, z, s=1.0):
    return noise.noise(Vector((x * s, y * s, z * s)))


# ---------------- iarba (disc cu margine neregulată)
def grass_top():
    rings = [0.0, 2.0, 4.0, 5.6, 6.6, 7.0]
    verts, faces = [(0, 0, 0)], []
    for ri, r in enumerate(rings[1:]):
        for j in range(SEG):
            a = 2 * math.pi * j / SEG
            rr = r * (1 + (0.012 * n3(math.cos(a), math.sin(a), ri, 3) if ri == len(rings) - 2 else 0))
            z = 0.03 * n3(math.cos(a) * rr, math.sin(a) * rr, 0, 0.5) if r < 6.8 else -0.02
            verts.append((math.cos(a) * rr, math.sin(a) * rr, z))
    for j in range(SEG):
        faces.append((0, 1 + j, 1 + (j + 1) % SEG))
    for i in range(len(rings) - 2):
        b0, b1 = 1 + i * SEG, 1 + (i + 1) * SEG
        for j in range(SEG):
            faces.append((b0 + j, b1 + j, b1 + (j + 1) % SEG, b0 + (j + 1) % SEG))
    # marginea ierbii coboară puțin (buza)
    edge0 = 1 + (len(rings) - 2) * SEG
    base = len(verts)
    for j in range(SEG):
        x, y, z = verts[edge0 + j]
        f = 1.03
        verts.append((x * f, y * f, -0.28 - 0.06 * abs(n3(x, y, 1, 0.8))))
    for j in range(SEG):
        faces.append((edge0 + j, base + j, base + (j + 1) % SEG, edge0 + (j + 1) % SEG))
    o = bk.mesh_from("Iarba", verts, faces, P["grass"], smooth=True)
    # crestătură pentru capul scării
    bk.keep(o, lambda c: not (abs(c.x) < STAIR_W / 2 + 0.1 and c.y < -6.8))
    return o


# ---------------- stânca (straturi, fețe plate)
def rock():
    levels = []
    z = -0.2
    # perete abrupt sub margine (ca în randare), apoi straturi care se îngustează spre vârf
    profile = [(-0.2, 7.35), (-1.3, 7.3), (-1.45, 7.05), (-2.7, 6.95), (-2.9, 6.55), (-4.1, 6.2), (-4.35, 5.5), (-5.4, 4.7), (-5.8, 3.8), (-6.8, 2.8), (-7.3, 1.8), (-8.1, 0.9), (-8.6, 0.3)]
    verts, faces = [], []
    seg = 40
    for li, (z, r) in enumerate(profile):
        for j in range(seg):
            a = 2 * math.pi * j / seg + li * 0.05
            k = 1 + 0.09 * n3(math.cos(a) * 2, math.sin(a) * 2, z * 0.6, 1.3)
            zz = z + (0.12 * n3(math.cos(a), math.sin(a), z, 2.0) if li > 0 else 0)
            verts.append((math.cos(a) * r * k, math.sin(a) * r * k, zz))
    for li in range(len(profile) - 1):
        b0, b1 = li * seg, (li + 1) * seg
        for j in range(seg):
            faces.append((b0 + j, b1 + j, b1 + (j + 1) % seg, b0 + (j + 1) % seg))
    tip = len(verts)
    verts.append((0.2, -0.1, -9.2))
    last = (len(profile) - 1) * seg
    for j in range(seg):
        faces.append((last + j, tip, last + (j + 1) % seg))
    o = bk.mesh_from("Stanca", verts, faces, P["rock"], smooth=False)
    return o


grass_top()
rock()

# ---------------- scările din față (taie marginea) + palier
stairs((0, -STAIR_IN, 0.0), STAIR_W, 5, 0.13, 0.2, P, rails=True)
box((STAIR_W + 0.6, 1.1, 0.25), (0, -STAIR_IN - 1.0 - 0.45, -0.65 - 0.125), P["stone"], bevel=0.03)
box((STAIR_W + 0.9, 1.3, 0.5), (0, -STAIR_IN - 1.0 - 0.4, -1.0), P["rock"])

# ---------------- balustrade pe marginea din față (lângă scări)
def arc_balustrade(a0, a1, r, n):
    pts = [Vector((math.sin(a0 + (a1 - a0) * i / n) * r, -math.cos(a0 + (a1 - a0) * i / n) * r, 0.0)) for i in range(n + 1)]
    for p, q in zip(pts, pts[1:]):
        balustrade_line(p, q, P, h=0.38, n=3)
    for p in (pts[0], pts[-1]):
        box((0.24, 0.24, 0.55), (p.x, p.y, 0.27), P["stone"], bevel=0.02)
        sphere(0.09, (p.x, p.y, 0.62), P["gold"], seg=10, rings=6)


for s in (-1, 1):
    a_in = s * math.asin((STAIR_W / 2 + 0.25) / 6.85)
    a_out = s * math.radians(30)
    arc_balustrade(a_in, a_out, 6.85, 4)

# felinare la capul scării și pe palier
for s in (-1, 1):
    lantern((s * 1.35, -STAIR_IN + 0.45, 0.0), P, h=1.1)
    lantern((s * 1.15, -STAIR_IN - 1.75, -0.65), P, h=0.9)

# ---------------- bolovani pe margine
for i in range(10):
    a = 2.39996 * i + 0.7
    if abs(math.sin(a)) < 0.35 and -math.cos(a) < 0:   # nu în fața scării
        continue
    if abs(abs(math.degrees(math.atan2(math.sin(a), -math.cos(a)))) - 40) < 10:   # nu la cascade
        continue
    ico(0.35 + 0.15 * (i % 3), (math.sin(a) * 6.75, -math.cos(a) * 6.75, 0.1), P["rock"], scale=(1.2, 1, 0.8), sub=1)

# ---------------- liane care atârnă pe stâncă
for i in range(26):
    a = 2 * math.pi * i / 26 + 0.11
    if abs(math.sin(a)) < 0.2 and math.cos(a) > 0:
        continue
    L = 0.8 + 1.4 * abs(math.sin(i * 7.3))
    x, y = math.sin(a) * 7.25, -math.cos(a) * 7.25
    cyl(0.03, L, (x, y, -0.25 - L / 2), P["leaf"], seg=5, r2=0.012)
    for k in range(3):
        ico(0.09, (x * 1.01, y * 1.01, -0.4 - k * L / 3), P["leaf_lt"] if k % 2 else P["leaf"], sub=1)

# ---------------- cristale sub insulă
for i in range(9):
    a = i * 0.7 + 0.3
    r = 1.0 + 1.6 * ((i * 37) % 10) / 10
    h = 0.8 + 0.7 * ((i * 53) % 10) / 10
    o = cyl(0.28, h, (math.cos(a) * r, math.sin(a) * r, -7.2 - h / 2 + 0.3 * math.sin(i)), P["gem"], seg=6, r2=0.0, rot=(math.pi, 0.15 * math.sin(i), 0.15 * math.cos(i)), smooth=False)

bk.set_parent(None)
bk.apply_and_join(root, "Insula")
bk.export_glb(OUT)
if PREVIEW:
    bk.preview(PREVIEW, target=(0, 0, -1.5), cam_loc=(9, -17, 8), lens=40, res=640)
