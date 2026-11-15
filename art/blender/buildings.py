"""Clădirile insulei Buble, după imaginea de referință.

Rulare (toate sau una):
    blender -b --factory-startup --python art/blender/buildings.py -- godot/models [palat|obs|turn|mag|sera] [--preview DIR]

Fiecare clădire se exportă ca godot/models/<id>.glb, cu plasele unite (puține apeluri de desenare).
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bk  # noqa: E402
from bk import (arch_window, balustrade_ring, banner, box, bush, cyl, cypress, dome, door, flag,  # noqa: E402
                ico, ivy, leaf, onion, sphere, stairs, torus, group, lathe)

A = bk.args()
OUT_DIR = A[0] if A else "."
PREVIEW = None
if "--preview" in A:
    PREVIEW = A[A.index("--preview") + 1]
    A = A[:A.index("--preview")]
ONLY = A[1:] if len(A) > 1 else ["palat", "obs", "turn", "mag", "sera"]
TAU = 2 * math.pi


def facing(a):
    """Unghiul face_angle pentru un obiect de pe un cerc, la unghiul a, orientat spre exterior."""
    return a + math.pi / 2


def ring_windows(r, z, n, w, h, P, a0=0.0, skip=(), depth=0.08):
    for i in range(n):
        if i in skip:
            continue
        a = a0 + TAU * i / n
        arch_window((math.cos(a) * r, math.sin(a) * r, z), w, h, P, face_angle=facing(a), depth=depth)


# ================================================================ PALAT
def build_palat(P):
    box((5.8, 3.3, 0.3), (0, 0.05, 0.15), P["stone_dk"], bevel=0.03)
    # corpul central
    box((3.0, 2.0, 2.4), (0, 0.15, 1.5), P["stone"], bevel=0.03)
    box((3.12, 2.12, 0.08), (0, 0.15, 2.72), P["gold"])
    box((3.25, 2.25, 0.16), (0, 0.15, 2.84), P["stone_dk"], bevel=0.03)
    for sx in (-1, 1):
        box((0.18, 0.12, 2.4), (sx * 1.42, -0.88, 1.5), P["stone_dk"], bevel=0.02)
    # portal cu arc auriu, ușă luminată și cristal
    box((1.6, 0.45, 2.55), (0, -0.98, 1.57), P["stone"], bevel=0.04)
    box((1.7, 0.5, 0.12), (0, -1.0, 2.88), P["gold"])
    arch_window((0, -1.22, 1.32), 0.95, 1.7, P, mullion=False)
    door((0, -1.24, 0.3), 0.7, 1.3, P)
    g = ico(0.17, (0, -1.27, 2.55), P["gem"], scale=(0.8, 0.5, 1.15), sub=1)
    torus(0.24, 0.03, (0, -1.25, 2.55), P["gold"], rot=(math.pi / 2, 0, math.pi / 4), seg=4, sides=6)
    stairs((0, -1.25, 0.3), 1.7, 3, 0.1, 0.22, P, rails=False)
    for sx in (-1, 1):
        banner((sx * 1.05, -0.88, 2.45), 0.36, 0.8, P)
        arch_window((sx * 1.05, -0.86, 1.15), 0.34, 0.65, P)
        ivy((sx * 1.35, -0.92, 2.5), P, n=8, spread=(0.45, 0.1, 1.1), seed=3 + sx)
    # tambur, cupolă mare cu nervuri, lanternă
    cyl(1.05, 0.9, (0, 0.15, 3.37), P["stone"], seg=40)
    torus(1.06, 0.05, (0, 0.15, 3.0), P["gold"], seg=48)
    ring_windows(1.05, 3.4, 10, 0.2, 0.45, P, a0=-math.pi / 2)
    with group("CupolaMare", (0, 0.15, 3.82)):
        dome(1.18, (0, 0, 0), P, ribs=10, h=1.0, seg=48)
        cyl(0.26, 0.4, (0, 0, 1.38), P["stone"], seg=16)
        ring_windows(0.26, 1.38, 6, 0.1, 0.24, P, a0=-math.pi / 2, depth=0.05)
        onion(0.32, (0, 0, 1.58), P, seg=24)
        flag((0, 0, 2.2), P, h=0.8)
    # turnuri laterale
    for sx in (-1, 1):
        x = sx * 2.2
        cyl(0.66, 3.1, (x, 0.15, 1.85), P["stone"], seg=32)
        for z in (1.0, 2.2, 3.35):
            torus(0.67, 0.045, (x, 0.15, z), P["gold"], seg=40)
        cyl(0.74, 0.14, (x, 0.15, 3.45), P["stone_dk"], seg=32)
        for z in (1.6, 2.75):
            arch_window((x, 0.15 - 0.66, z), 0.26, 0.55, P)
        arch_window((x - sx * 0.47, 0.15 - 0.47, 1.6), 0.22, 0.48, P, face_angle=-sx * math.pi / 4)
        onion(0.7, (x, 0.15, 3.52), P, seg=32)
        flag((x, 0.15, 4.55), P, h=0.7)
        ivy((x + sx * 0.3, -0.42, 1.3), P, n=6, spread=(0.4, 0.1, 0.9), seed=7 + sx)
        bush((sx * 2.3, -1.15, 0.3), 0.42, P, "pink", n=6, seed=sx)
        cypress((sx * 2.95, 0.9, 0.3), 1.9, P)


# ================================================================ OBSERVATOR
def build_obs(P):
    cyl(1.6, 0.3, (0, 0, 0.15), P["stone_dk"], seg=40)
    cyl(1.35, 1.45, (0, 0, 1.02), P["stone"], seg=40)
    for z in (0.32, 1.72):
        torus(1.36, 0.05, (0, 0, z), P["gold"], seg=48)
    ring_windows(1.35, 1.05, 8, 0.32, 0.62, P, a0=-math.pi / 2, skip=(0,))
    door((0, -1.36, 0.3), 0.55, 1.0, P)
    stairs((0, -1.5, 0.3), 0.8, 3, 0.1, 0.18, P, rails=False)
    # balcon cu balustradă
    cyl(1.58, 0.14, (0, 0, 1.8), P["stone_dk"], seg=40)
    balustrade_ring((0, 0, 1.87), 1.5, P, h=0.3, n=20)
    cyl(1.1, 0.95, (0, 0, 2.35), P["stone"], seg=40)
    ring_windows(1.1, 2.38, 8, 0.24, 0.48, P, a0=-math.pi / 2 + 0.4)
    torus(1.11, 0.05, (0, 0, 2.82), P["gold"], seg=48)
    with group("Cupola", (0, 0, 2.84)):
        dome(1.15, (0, 0, 0), P, mat_key="violet", ribs=12, h=0.98, seg=48)
        # deschizătura cu cerul înstelat
        box((0.5, 0.2, 1.0), (0.32, -0.92, 0.55), P["night"], rot=(math.radians(-38), 0, math.radians(-18)))
        for i in range(10):
            a = i * 2.4
            sphere(0.025, (0.3 + math.cos(a) * 0.15, -1.02, 0.5 + math.sin(a) * 0.35), P["glow"], seg=6, rings=3)
        sphere(0.12, (0, 0, 1.15), P["gold"], seg=12, rings=6)
        # telescopul auriu
        with group("Telescop", (0.25, -0.55, 0.7), (math.radians(-55), 0, math.radians(-25))):
            cyl(0.2, 1.9, (0, 0, 0.5), P["gold"], seg=24, r2=0.27)
            for z in (-0.2, 0.5, 1.2):
                torus(0.25 + z * 0.02, 0.035, (0, 0, z), P["gold"], seg=24)
            cyl(0.24, 0.05, (0, 0, 1.46), P["night"], seg=24)
            cyl(0.12, 0.4, (0, 0, -0.55), P["gold"], seg=16)
    ivy((-1.2, -0.6, 1.5), P, n=8, spread=(0.4, 0.1, 1.0), seed=5)
    bush((1.4, -1.2, 0.3), 0.35, P, "lilac", n=5, seed=2)


# ================================================================ TURN
def build_turn(P):
    cyl(1.0, 0.3, (0, 0, 0.15), P["stone_dk"], seg=8)
    cyl(0.72, 3.6, (0, 0, 2.1), P["stone"], seg=32, r2=0.68)
    for z in (0.32, 1.5, 2.7):
        torus(0.72, 0.045, (0, 0, z), P["gold"], seg=40)
    door((0, -0.71, 0.3), 0.45, 0.95, P)
    stairs((0, -1.0, 0.3), 0.7, 3, 0.1, 0.12, P, rails=False)
    for z in (1.9, 3.1):
        arch_window((0, -0.69, z), 0.26, 0.55, P)
    for a in (0.0, math.pi):
        arch_window((math.cos(a) * 0.7, math.sin(a) * 0.7, 2.5), 0.22, 0.48, P, face_angle=facing(a))
    banner((0, -0.72, 3.65), 0.42, 1.0, P)
    cyl(0.88, 0.14, (0, 0, 3.95), P["stone_dk"], seg=32)
    balustrade_ring((0, 0, 4.02), 0.82, P, h=0.26, n=14)
    cyl(0.6, 0.55, (0, 0, 4.3), P["stone"], seg=32)
    ring_windows(0.6, 4.3, 6, 0.14, 0.3, P, a0=-math.pi / 2)
    torus(0.61, 0.04, (0, 0, 4.57), P["gold"], seg=40)
    with group("Cupola", (0, 0, 4.58)):
        dome(0.72, (0, 0, 0), P, ribs=8, h=0.95, seg=40)
        cyl(0.06, 0.25, (0, 0, 0.78), P["gold"], seg=10)
        sphere(0.15, (0, 0, 0.98), P["gold"], seg=16, rings=8)
        cyl(0.03, 0.3, (0, 0, 1.25), P["gold"], seg=8, r2=0.0)
    ivy((0.45, -0.5, 2.3), P, n=8, spread=(0.3, 0.1, 1.2), seed=9)
    bush((-0.85, -0.85, 0.3), 0.3, P, "pink", n=5, seed=4)


# ================================================================ MAGAZIN
def build_mag(P):
    box((3.2, 2.4, 0.22), (0, 0, 0.11), P["stone_dk"], bevel=0.03)
    box((2.9, 2.1, 1.75), (0, 0.05, 1.1), P["stone"], bevel=0.03)
    box((3.05, 2.25, 0.14), (0, 0.05, 2.03), P["stone_dk"], bevel=0.03)
    # acoperiș în patru ape, turcoaz
    cyl(2.15, 1.05, (0, 0.05, 2.62), P["roof"], seg=4, r2=0.25, rot=(0, 0, math.pi / 4), smooth=False)
    box((0.42, 0.42, 0.12), (0, 0.05, 3.16), P["gold"], bevel=0.02)
    sphere(0.12, (0, 0.05, 3.3), P["gold"], seg=12, rings=6)
    # vitrine luminate cu rafturi
    for sx in (-1, 1):
        x = sx * 0.78
        box((0.85, 0.08, 0.95), (x, -1.02, 0.95), P["glow"])
        for z in (0.68, 0.95, 1.22):
            box((0.85, 0.12, 0.04), (x, -1.06, z), P["wood"])
        for k in range(4):
            box((0.12, 0.08, 0.14), (x - 0.3 + k * 0.2, -1.1, 0.77 + (k % 2) * 0.27), P["pink"] if k % 2 else P["lilac"])
        box((0.95, 0.14, 0.06), (x, -1.06, 0.45), P["stone_dk"])
        for xx in (-0.45, 0.45):
            box((0.05, 0.12, 1.0), (x + xx, -1.06, 0.95), P["gold"])
        box((0.95, 0.12, 0.05), (x, -1.06, 1.45), P["gold"])
    door((0, -1.06, 0.22), 0.5, 1.15, P)
    # copertina violet cu festoane și frunză aurie
    box((3.1, 0.95, 0.06), (0, -1.38, 1.78), P["violet"], rot=(math.radians(22), 0, 0))
    for i in range(8):
        x = -1.36 + i * 0.39
        cyl(0.195, 0.05, (x, -1.82, 1.6), P["violet_lt"] if i % 2 else P["violet"], seg=16, rot=(math.pi / 2, 0, 0))
    box((3.12, 0.06, 0.06), (0, -1.82, 1.62), P["gold"])
    leaf((0, -1.86, 1.5), 0.28, P)
    for sx in (-1, 1):
        cyl(0.03, 0.5, (sx * 1.5, -1.6, 1.55), P["gold"], seg=8, rot=(math.radians(60), 0, 0))
        cyl(0.2, 0.3, (sx * 1.25, -1.45, 0.37), P["wood_lt"], seg=12, r2=0.15)
        bush((sx * 1.25, -1.45, 0.45), 0.3, P, "pink" if sx < 0 else "lilac", n=5, seed=sx + 3)
    box((0.4, 0.35, 0.35), (1.55, -0.6, 0.4), P["wood"], bevel=0.02)
    ivy((-1.45, -0.6, 1.9), P, n=7, spread=(0.15, 0.6, 1.0), seed=11)


# ================================================================ SERĂ
def build_sera(P):
    cyl(1.45, 0.32, (0, 0, 0.16), P["stone_dk"], seg=8, rot=(0, 0, math.pi / 8))
    with group("Pereti", (0, 0, 0.32), (0, 0, math.pi / 8)):
        cyl(1.3, 1.1, (0, 0, 0.55), P["glass"], seg=8, smooth=False)
        for i in range(8):
            a = TAU * i / 8
            cyl(0.035, 1.12, (math.cos(a) * 1.3, math.sin(a) * 1.3, 0.56), P["gold"], seg=6)
        for z in (0.02, 0.55, 1.1):
            torus(1.3, 0.03, (0, 0, z), P["gold"], seg=8, sides=5)
    with group("Bolta", (0, 0, 1.42)):
        pts = [(1.25 * math.cos(t), 0.95 * math.sin(t)) for t in [i * math.pi / 2 / 8 for i in range(9)]]
        pts[-1] = (0.0001, 0.95)
        lathe(pts, (0, 0, 0), P["glass"], seg=16)
        for i in range(8):
            torus(1.25, 0.028, (0, 0, 0), P["gold"], rot=(math.pi / 2, 0, TAU * i / 8), seg=20, sides=5, arc=math.pi / 2, scale=(1, 0.76, 1))
        torus(0.75, 0.025, (0, 0, 0.75), P["gold"], seg=24, sides=5)
        cyl(0.18, 0.18, (0, 0, 1.0), P["gold"], seg=8)
        sphere(0.1, (0, 0, 1.15), P["gold"], seg=12, rings=6)
    # plante și lumină caldă înăuntru
    sphere(0.22, (0, 0.1, 1.0), P["glow_soft"], seg=12, rings=6)
    for i in range(6):
        a = i * TAU / 6 + 0.3
        bush((math.cos(a) * 0.7, math.sin(a) * 0.7, 0.32), 0.33, P, "pink" if i % 2 else "lilac", n=5, seed=i)
    cypress((0.0, 0.35, 0.32), 1.2, P)
    # intrare
    with group("Intrare", (0, -1.28, 0.32)):
        box((0.62, 0.1, 0.9), (0, 0, 0.45), P["glass"])
        torus(0.33, 0.035, (0, -0.02, 0.9), P["gold"], rot=(math.pi / 2, 0, 0), seg=16, sides=5, arc=math.pi)
        for sx in (-1, 1):
            cyl(0.035, 0.9, (sx * 0.33, -0.02, 0.45), P["gold"], seg=6)
    stairs((0, -1.35, 0.32), 0.7, 2, 0.16, 0.18, P, rails=False)


BUILDERS = {"palat": build_palat, "obs": build_obs, "turn": build_turn, "mag": build_mag, "sera": build_sera}

for bid in ONLY:
    bk.reset_scene()
    bk._MATS.clear()
    P = bk.palette()
    root = bk.empty(bid.capitalize())
    bk.set_parent(root)
    BUILDERS[bid](P)
    bk.set_parent(None)
    bk.apply_and_join(root, bid.capitalize())
    bk.export_glb(os.path.join(OUT_DIR, bid + ".glb"))
    if PREVIEW:
        H = {"palat": 5.5, "obs": 4.5, "turn": 5.3, "mag": 3.3, "sera": 2.6}[bid]
        bk.preview(os.path.join(PREVIEW, bid + ".png"), target=(0, 0, H * 0.45), cam_loc=(H * 0.9, -H * 2.0, H * 1.05), lens=50, res=560)
