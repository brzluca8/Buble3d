"""
Insula 1 v2: clădirile mari (PLACEHOLDER-e marcate) și elementele mici (procedural, fără AI), plus pozițiile lor.

    python build_props.py          (după build_terrain.py)

Scrie:
  godot/assets/models/insula1_v2/props/<nume>.glb  - castel, moara (nodul „Panze” se rotește), portal (nodul „Vartej”
      primește shaderul de vârtej), piata, atelier, debarcader, barca (nodul „Panza”), pod, copac_mare.
      Fiecare are un nod „Marcaj_PLACEHOLDER” (inel magenta) care dispare când pui modelul generat în locul fișierului.
  godot/assets/models/insula1_v2/mici/<nume>.glb   - palmieri (3), copaci roz (2), tufă, iarbă, flori (3), gard,
      felinar, butoi, ladă, cristale (3), pietre (2), nufăr, grâu.
  godot/insula_v2/data/props.gd       - unde stau clădirile mari, pe faze
  godot/insula_v2/data/vegetatie.gd   - instanțele elementelor mici (x, y, z, rotație, scară), pe tip
Culori pe vârfuri (liniare) cu AO coaptă; alfa = greutatea pentru vânt (0 la bază, 1 în vârful frunzelor).
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy  # noqa: E402
import numpy as np  # noqa: E402
from mathutils import Vector  # noqa: E402

import layout  # noqa: E402
from common import OUT_DATA, OUT_MODELS, gd_vec3, log, tiles_blender  # noqa: E402
from meshkit import C, Part, bake_ao, export, tri_count  # noqa: E402

BUILD = os.path.join(os.path.dirname(os.path.abspath(__file__)), "_build")
PROPS_DIR = os.path.join(OUT_MODELS, "props")
MICI_DIR = os.path.join(OUT_MODELS, "mici")
os.makedirs(PROPS_DIR, exist_ok=True)
os.makedirs(MICI_DIR, exist_ok=True)
rng = np.random.default_rng(3)

STONE = "#EADCC6"
STONE_D = "#CBB89E"
BLUE = "#2F63D6"
BLUE_D = "#2348A8"
GOLD = "#F4C04E"
WOOD = "#B07A48"
WOOD_D = "#7E5232"
CREAM = "#F5ECD6"
WARM = "#FFC861"
GREEN = "#5DB534"
GREEN_D = "#3B8A2A"


def new_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def marker(r):
    """magenta ring on the ground: this asset is a PLACEHOLDER"""
    p = Part("Marcaj_PLACEHOLDER")
    n = 24
    for k in range(n):
        if k % 2:
            continue
        a0, a1 = 2 * math.pi * k / n, 2 * math.pi * (k + 1) / n
        p.poly([(r * math.cos(a0), r * math.sin(a0), 0.03), (r * math.cos(a1), r * math.sin(a1), 0.03),
                ((r - 0.12) * math.cos(a1), (r - 0.12) * math.sin(a1), 0.03),
                ((r - 0.12) * math.cos(a0), (r - 0.12) * math.sin(a0), 0.03)], color=C("#FF2BD6"))
    return p.to_object()


def finish(name, parts, folder, ao_ground=0.0, mark_r=None):
    obs = [p.to_object() if isinstance(p, Part) else p for p in parts]
    body = [o for o in obs if not o.name.startswith(("Lumina", "Vartej", "Cristal"))]
    bake_ao(body, ground_z=ao_ground)
    if mark_r:
        obs.append(marker(mark_r))
    path = os.path.join(folder, f"{name}.glb")
    export(obs, path)
    log(f"[glb] {name}: {tri_count(obs)} triangles, {len(obs)} parts")
    return tri_count(obs)


# ============================================================================= hero placeholders
def roof_cone(p, r, h, loc, color=BLUE, tip=True):
    p.cyl(r, 0.0, h, loc=loc, color=C(color), seg=14)
    if tip:
        x, y, z = loc
        p.cyl(0.07, 0.0, 0.45, loc=(x, y, z + h - 0.05), color=C(GOLD), seg=6)
        p.ball(0.07, loc=(x, y, z + h - 0.02), color=C(GOLD), subdiv=1)


def castel():
    new_scene()
    b, glow, flag = Part("Corp"), Part("Lumina"), Part("Steag")
    b.box((2.7, 2.0, 2.3), loc=(0, 0.25, 1.15), color=C(STONE))
    for x in np.linspace(-1.2, 1.2, 7):  # battlements
        b.box((0.24, 0.24, 0.26), loc=(x, -0.75, 2.42), color=C(STONE))
    for sx, sy in ((-1.35, -0.7), (1.35, -0.7), (-1.35, 1.2), (1.35, 1.2)):
        b.cyl(0.5, 0.48, 3.0, loc=(sx, sy, 0), color=C(STONE), seg=14)
        b.cyl(0.56, 0.56, 0.12, loc=(sx, sy, 2.95), color=C(GOLD), seg=14)
        roof_cone(b, 0.66, 1.5, (sx, sy, 3.05))
        glow.box((0.18, 0.04, 0.3), loc=(sx, sy - 0.5, 2.1), color=C(WARM))
    b.cyl(0.78, 0.74, 4.3, loc=(0, 0.45, 0), color=C(STONE), seg=16)
    b.cyl(0.84, 0.84, 0.14, loc=(0, 0.45, 4.25), color=C(GOLD), seg=16)
    roof_cone(b, 0.98, 2.2, (0, 0.45, 4.38))
    b.ball(0.16, loc=(0, 0.45, 7.05), color=C(GOLD), subdiv=1)
    for sx in (-0.75, 0.75):
        b.cyl(0.33, 0.32, 2.6, loc=(sx, -0.95, 0), color=C(STONE), seg=12)
        roof_cone(b, 0.42, 1.0, (sx, -0.95, 2.6), color=BLUE_D)
    b.box((0.95, 0.14, 1.35), loc=(0, -0.79, 0.68), color=C("#6A4328"))  # gate
    glow.box((0.75, 0.04, 1.1), loc=(0, -0.87, 0.6), color=C(WARM))
    for x in (-0.55, 0.0, 0.55):
        glow.box((0.16, 0.04, 0.32), loc=(x, -0.77, 1.75), color=C(WARM))
    for x in (-0.95, 0.95):  # banners
        b.box((0.32, 0.03, 0.8), loc=(x, -0.79, 1.55), color=C(BLUE))
        b.box((0.08, 0.035, 0.08), loc=(x, -0.8, 1.6), color=C(GOLD))
    for sx, sy in ((-1.35, -0.7), (1.35, 1.2)):  # pennants on two towers (wind)
        b.cyl(0.025, 0.025, 0.9, loc=(sx, sy, 4.5), color=C(GOLD), seg=5)
        flag.poly([(sx, sy, 5.35), (sx + 0.7, sy, 5.2), (sx, sy, 5.05)], color=C(BLUE),
                  sway_fn=lambda co, sx=sx: min(1.0, abs(co.x - sx) / 0.7))
    return finish("castel", [b, glow, flag], PROPS_DIR, mark_r=2.9)


def moara():
    new_scene()
    b, glow, sails = Part("Corp"), Part("Lumina"), Part("Panze")
    b.cyl(0.95, 0.95, 0.35, loc=(0, 0, 0), color=C(STONE_D), seg=16)
    b.cyl(0.85, 0.62, 3.0, loc=(0, 0, 0.3), color=C(STONE), seg=16)
    b.cyl(0.7, 0.7, 0.1, loc=(0, 0, 3.27), color=C(GOLD), seg=16)
    roof_cone(b, 0.82, 1.15, (0, 0, 3.32))
    b.box((0.5, 0.12, 0.85), loc=(0, -0.83, 0.72), color=C("#6A4328"))
    glow.box((0.22, 0.04, 0.3), loc=(0, -0.72, 2.0), color=C(WARM))
    b.cyl(0.13, 0.13, 0.5, loc=(0, -0.55, 2.95), rot=(90, 0, 0), color=C(WOOD_D), seg=8)
    # small house next to the mill
    b.box((1.4, 1.2, 1.05), loc=(1.35, 0.35, 0.52), color=C(STONE))
    b.poly([(0.6, -0.3, 1.05), (2.1, -0.3, 1.05), (1.35, -0.3, 1.75)], color=C(BLUE))
    b.poly([(2.1, 1.0, 1.05), (0.6, 1.0, 1.05), (1.35, 1.0, 1.75)], color=C(BLUE))
    b.box((1.6, 0.85, 0.06), loc=(1.35, 0.0, 1.43), rot=(43, 0, 0), color=C(BLUE))
    b.box((1.6, 0.85, 0.06), loc=(1.35, 0.7, 1.43), rot=(-43, 0, 0), color=C(BLUE))
    glow.box((0.28, 0.04, 0.28), loc=(1.05, -0.27, 0.62), color=C(WARM))
    # sails: own object with its origin at the hub, turning about the local y (forward) axis
    hub = Vector((0, -0.82, 2.95))
    for k in range(4):
        a = math.radians(45 + 90 * k)
        d = Vector((math.cos(a), 0, math.sin(a)))
        side = Vector((-math.sin(a), 0, math.cos(a)))
        sails.box((0.07, 0.06, 2.0), loc=tuple(d * 1.0), rot=(0, -math.degrees(a) + 90, 0), color=C(WOOD_D))
        p0, p1 = d * 0.35, d * 1.95
        q = side * 0.5
        sails.poly([tuple(p0 + Vector((0, -0.03, 0))), tuple(p1 + Vector((0, -0.03, 0))),
                    tuple(p1 + q + Vector((0, -0.03, 0))), tuple(p0 + q * 0.8 + Vector((0, -0.03, 0)))],
                   color=C(CREAM))
    sails.ball(0.16, color=C(GOLD), subdiv=1)
    ob_s = sails.to_object()
    ob_s.location = hub
    return finish("moara", [b, glow, ob_s], PROPS_DIR, mark_r=1.7)


def portal():
    new_scene()
    b, crys, vort = Part("Corp"), Part("Cristal"), Part("Vartej")
    for k, z in enumerate((0.0, 0.18, 0.36)):  # steps in front
        b.box((2.4 - 0.3 * k, 0.45, 0.18), loc=(0, -1.2 + 0.4 * k, z + 0.09), color=C(STONE_D))
    b.box((2.5, 1.2, 0.5), loc=(0, 0.15, 0.25), color=C(STONE_D))
    for sx in (-0.95, 0.95):
        b.box((0.46, 0.5, 2.1), loc=(sx, 0.15, 1.55), color=C("#EEE6DA"))
        b.box((0.56, 0.6, 0.14), loc=(sx, 0.15, 2.62), color=C(GOLD))
    n = 9
    for k in range(n):
        a = math.pi * (k + 0.5) / n
        x, z = 0.95 * math.cos(a), 2.62 + 0.95 * math.sin(a)
        b.box((0.42, 0.5, 0.36), loc=(x, 0.15, z), rot=(0, -math.degrees(a) + 90, 0), color=C("#EEE6DA"))
    b.box((0.3, 0.55, 0.36), loc=(0, 0.15, 3.62), color=C(GOLD))
    crys.ball(0.13, loc=(0, -0.15, 3.62), scale=(0.7, 0.5, 1.2), color=C("#58E6FF"), subdiv=1, smooth=False)
    # vortex disc (the shader makes it swirl): ellipse in the x-z plane, facing -y
    m = 28
    for k in range(m):
        a0, a1 = 2 * math.pi * k / m, 2 * math.pi * (k + 1) / m
        vort.poly([(0, 0.12, 1.75), (0.72 * math.cos(a0), 0.12, 1.75 + 1.05 * math.sin(a0)),
                   (0.72 * math.cos(a1), 0.12, 1.75 + 1.05 * math.sin(a1))], color=C("#9B5CFF"))
    for (x, y, h, c) in ((-1.45, -0.4, 0.9, "#7A5CFF"), (-1.25, -0.75, 0.55, "#58E6FF"), (1.4, -0.45, 1.0, "#58E6FF"),
                         (1.55, -0.1, 0.6, "#B07CFF"), (1.2, -0.85, 0.45, "#7A5CFF")):
        crys.cyl(0.13, 0.0, h, loc=(x, y, 0.45), rot=(rng.uniform(-12, 12), rng.uniform(-12, 12), 0), color=C(c), seg=6,
                 smooth=False)
    return finish("portal", [b, crys, vort], PROPS_DIR, mark_r=1.6)


def stall(p, x, y, colors):
    for sx in (-0.65, 0.65):
        for sy in (-0.4, 0.4):
            p.cyl(0.05, 0.05, 1.5, loc=(x + sx, y + sy, 0), color=C(WOOD_D), seg=6)
    p.box((1.5, 0.75, 0.75), loc=(x, y - 0.05, 0.38), color=C(WOOD))
    for k in range(6):  # striped awning, sloping to the front
        c = colors[k % 2]
        w = 1.6 / 6
        p.box((w, 1.0, 0.04), loc=(x - 0.8 + w * (k + 0.5), y - 0.05, 1.55), rot=(-14, 0, 0), color=C(c))
    for k in range(5):  # fruit
        p.ball(0.1, loc=(x - 0.5 + 0.25 * k, y - 0.25, 0.82), color=C(["#FF8A1F", "#E8332E", "#8BD43F", "#FFD23F", "#FF5C8A"][k]),
               subdiv=1)


def piata():
    new_scene()
    b, glow = Part("Corp"), Part("Lumina")
    b.box((2.3, 1.4, 1.6), loc=(0, 0.8, 0.8), color=C(WOOD))
    b.box((2.5, 0.9, 0.06), loc=(0, 0.42, 1.88), rot=(32, 0, 0), color=C(BLUE))
    b.box((2.5, 0.9, 0.06), loc=(0, 1.18, 1.88), rot=(-32, 0, 0), color=C(BLUE))
    b.box((0.7, 0.05, 0.3), loc=(0, 0.08, 1.35), color=C(GOLD))
    glow.box((0.3, 0.04, 0.35), loc=(-0.6, 0.08, 0.95), color=C(WARM))
    glow.box((0.3, 0.04, 0.35), loc=(0.6, 0.08, 0.95), color=C(WARM))
    stall(b, -0.85, -0.6, ("#E23A3A", "#FFF3E2"))
    stall(b, 0.95, -0.55, ("#2F63D6", "#FFD84D"))
    for k in range(4):
        b.box((0.4, 0.4, 0.32), loc=(-1.6 + 0.45 * k, -1.35, 0.16), rot=(0, 0, rng.uniform(-15, 15)), color=C(WOOD))
    return finish("piata", [b, glow], PROPS_DIR, mark_r=2.0)


def atelier():
    new_scene()
    b, glow = Part("Corp"), Part("Lumina")
    b.box((2.0, 1.6, 1.5), loc=(0, 0.2, 0.75), color=C(WOOD))
    b.box((2.2, 1.0, 0.06), loc=(0, -0.22, 1.72), rot=(34, 0, 0), color=C(BLUE))
    b.box((2.2, 1.0, 0.06), loc=(0, 0.62, 1.72), rot=(-34, 0, 0), color=C(BLUE))
    b.box((0.3, 0.3, 0.7), loc=(0.6, 0.5, 2.0), color=C(STONE_D))
    b.box((0.55, 0.08, 0.95), loc=(-0.3, -0.62, 0.48), color=C(WOOD_D))
    glow.box((0.32, 0.04, 0.3), loc=(0.45, -0.62, 0.95), color=C(WARM))
    b.box((1.2, 0.8, 0.05), loc=(0.2, -0.95, 1.25), rot=(-18, 0, 0), color=C(CREAM))
    for k in range(3):
        b.cyl(0.22, 0.22, 0.55, loc=(-1.25 + 0.48 * k, -0.95, 0), color=C("#A8703F"), seg=10)
        b.cyl(0.235, 0.235, 0.05, loc=(-1.25 + 0.48 * k, -0.95, 0.42), color=C(GOLD, 0.8), seg=10)
    return finish("atelier", [b, glow], PROPS_DIR, mark_r=1.8)


def debarcader():
    new_scene()
    b = Part("Corp")
    L = 3.2
    for k in range(12):
        y = -L / 2 + L * (k + 0.5) / 12
        b.box((1.3, L / 12 - 0.03, 0.08), loc=(0, y, 0.0), color=C(WOOD, rng.uniform(0.88, 1.08)))
    for sx in (-0.62, 0.62):
        for y in (-1.5, -0.5, 0.5, 1.5):
            b.cyl(0.08, 0.08, 1.6, loc=(sx, y, -1.25), color=C(WOOD_D), seg=8)
        b.cyl(0.03, 0.03, 3.2, loc=(sx, -1.6, 0.45), rot=(-90, 0, 0), color=C("#D9C39A"), seg=5)
    return finish("debarcader", [b], PROPS_DIR, ao_ground=-1.3, mark_r=1.4)


def barca():
    new_scene()
    b, sail = Part("Corp"), Part("Panza")
    rows = []
    n_l, n_c = 10, 9
    for i in range(n_l):
        u = i / (n_l - 1)
        y = -1.15 + 2.3 * u
        half = 0.42 * math.sin(math.pi * min(max(u, 0.02), 0.98)) ** 0.6
        depth = 0.42 * math.sin(math.pi * min(max(u, 0.05), 0.95)) ** 0.4
        row = []
        for j in range(n_c):
            v = j / (n_c - 1)
            a = math.pi * v
            row.append((half * math.cos(a), y, 0.32 - depth * math.sin(a) + 0.08 * abs(u - 0.5) ** 2 * 4))
        rows.append(row)
    b.strip(rows, lambda i, j: C(WOOD if abs(j - 4) > 1 else WOOD_D, 0.9 + 0.1 * (i % 2)))
    b.box((0.7, 1.7, 0.04), loc=(0, 0, 0.3), color=C("#C99A63"))
    b.cyl(0.045, 0.04, 2.2, loc=(0, 0.15, 0.3), color=C(WOOD_D), seg=6)
    b.box((0.04, 0.04, 1.3), loc=(0, 0.0, 0.95), rot=(90, 0, 0), color=C(WOOD_D))
    sail.poly([(0, 0.18, 2.4), (0, 0.18, 0.75), (0, -0.95, 0.75)], color=C(CREAM),
              sway_fn=lambda co: max(0.0, min(1.0, (0.18 - co.y) / 1.1)))
    sail.poly([(0, 0.18, 0.98), (0, 0.18, 0.82), (0, -0.75, 0.82), (0, -0.62, 0.98)], color=C(BLUE))
    b.poly([(0, 0.15, 2.5), (0.35, 0.15, 2.42), (0, 0.15, 2.34)], color=C(BLUE))
    return finish("barca", [b, sail], PROPS_DIR, ao_ground=-0.05, mark_r=1.3)


def pod():
    """arched stone bridge along x (span 3.8 m), deck 1.25 m wide, top ~0.45 m above its ends"""
    new_scene()
    b, glow = Part("Corp"), Part("Lumina")
    n = 14
    span = 3.8
    rows_top, rows_bot = [], []
    for i in range(n + 1):
        u = i / n
        x = -span / 2 + span * u
        z = 0.45 * math.sin(math.pi * u)
        zb = z - 0.32 - 1.25 * math.sin(math.pi * u) ** 0.5 * (1 if 0.12 < u < 0.88 else 0.0)
        rows_top.append([(x, -0.62, z), (x, 0.62, z)])
        rows_bot.append([(x, -0.62, min(zb, z - 0.32)), (x, 0.62, min(zb, z - 0.32))])
    b.strip(rows_top, lambda i, j: C("#DDD2C2"))
    for side in (-0.62, 0.62):  # side faces
        rows = [[(x, side, zb), (x, side, z)] for ((x, _, z), _), ((_, _, zb), _) in zip(rows_top, rows_bot)]
        b.strip(rows, lambda i, j: C(STONE_D))
    for side in (-0.58, 0.58):  # low parapets
        for i in range(n):
            (x0, _, z0), (x1, _, z1) = rows_top[i][0], rows_top[i + 1][0]
            b.box((abs(x1 - x0) + 0.02, 0.12, 0.28), loc=((x0 + x1) / 2, side, (z0 + z1) / 2 + 0.14),
                  rot=(0, -math.degrees(math.atan2(z1 - z0, x1 - x0)), 0), color=C("#E8DFD2"))
        for x in (-span / 2 + 0.1, span / 2 - 0.1):
            b.cyl(0.09, 0.09, 0.55, loc=(x, side, 0.0), color=C(GOLD), seg=8)
            glow.ball(0.08, loc=(x, side, 0.62), color=C(WARM), subdiv=1)
    return finish("pod", [b, glow], PROPS_DIR, ao_ground=-1.4, mark_r=None)


def copac_mare():
    new_scene()
    t, leaves = Part("Corp"), Part("Frunze")
    t.cyl(0.55, 0.32, 2.2, loc=(0, 0, 0), color=C("#8A5A36"), seg=10)
    for k in range(5):
        a = 2 * math.pi * k / 5
        t.cyl(0.16, 0.05, 1.1, loc=(0.35 * math.cos(a), 0.35 * math.sin(a), 0.0),
              rot=(math.degrees(math.sin(a)) * 50, -math.degrees(math.cos(a)) * 50, 0), color=C("#7A4E2E"), seg=6)
    for k in range(3):
        a = 2 * math.pi * k / 3 + 0.4
        t.cyl(0.2, 0.08, 1.4, loc=(0.2 * math.cos(a), 0.2 * math.sin(a), 1.9),
              rot=(math.degrees(math.sin(a)) * 40, -math.degrees(math.cos(a)) * 40, 0), color=C("#8A5A36"), seg=7)
    for k in range(11):
        a = 2 * math.pi * k / 11
        r = 1.15 if k % 2 else 0.6
        c = (r * math.cos(a), r * math.sin(a), 3.05 + rng.uniform(-0.25, 0.45))
        leaves.ball(rng.uniform(0.75, 1.0), loc=c, scale=(1.1, 1.1, 0.8), color=C("#5FAE3A", rng.uniform(0.85, 1.12)),
                    subdiv=2, sway=0.0, jitter=0.12, rng=rng, sway_fn=lambda co: min(1.0, max(0.0, (co.z - 2.2) / 2.0)) * 0.6)
    for k in range(14):  # small pink/white flowers on the canopy
        a = rng.uniform(0, 2 * math.pi)
        r = rng.uniform(0.6, 1.6)
        leaves.ball(0.1, loc=(r * math.cos(a), r * math.sin(a), rng.uniform(3.3, 3.9)), color=C("#FFC2DD"), subdiv=1,
                    sway=0.5)
    return finish("copac_mare", [t, leaves], PROPS_DIR, mark_r=None)


# ============================================================================= small elements (instanced)
def palm(name, h, lean, fronds):
    new_scene()
    t, fr = Part("Corp"), Part("Frunze")
    seg = 7
    pts = []
    for k in range(seg + 1):
        u = k / seg
        pts.append(Vector((lean * u ** 1.6, 0, h * u)))
    for k in range(seg):
        a, b_ = pts[k], pts[k + 1]
        d = b_ - a
        rot_y = math.degrees(math.atan2(d.x, d.z))
        t.cyl(0.17 - 0.06 * k / seg, 0.16 - 0.06 * (k + 1) / seg, d.length + 0.02, loc=tuple(a), rot=(0, rot_y, 0),
              color=C("#9C6A3E", 0.85 + 0.2 * (k % 2)), seg=8,
              sway_fn=lambda co, h=h: (co.z / h) ** 2 * 0.35)
    top = pts[-1]
    for k in range(fronds):
        a = 2 * math.pi * k / fronds + rng.uniform(-0.2, 0.2)
        L = rng.uniform(1.5, 2.0)
        droop = rng.uniform(0.6, 1.0)
        rows = []
        for i in range(7):
            u = i / 6
            r = L * u
            z = top.z + 0.25 * math.sin(math.pi * u * 0.8) - droop * u ** 2
            w = 0.32 * math.sin(math.pi * min(u * 1.1, 1.0)) + 0.02
            cx, cy = top.x + r * math.cos(a), top.y + r * math.sin(a)
            px, py = -math.sin(a) * w, math.cos(a) * w
            rows.append([(cx + px, cy + py, z - 0.08 * u), (cx, cy, z + 0.04), (cx - px, cy - py, z - 0.08 * u)])
        fr.strip(rows, lambda i, j: C("#5DBB3A" if j == 1 else "#3E9A2E", 0.9 + 0.1 * i / 6),
                 sway_fn=lambda co, top=top, L=L: min(1.0, 0.35 + 0.65 * (Vector((co.x, co.y, 0)) - Vector((top.x, top.y, 0))).length / L))
    for k in range(3):
        a = 2 * math.pi * k / 3
        t.ball(0.1, loc=(top.x + 0.13 * math.cos(a), top.y + 0.13 * math.sin(a), top.z - 0.12), color=C("#7A4B26"), subdiv=1,
               sway=0.35)
    return finish(name, [t, fr], MICI_DIR)


def blossom(name, h, color):
    new_scene()
    t, lv = Part("Corp"), Part("Frunze")
    t.cyl(0.18, 0.1, h, loc=(0, 0, 0), color=C("#7B4C2C"), seg=7)
    for k in range(3):
        a = 2 * math.pi * k / 3
        t.cyl(0.08, 0.03, 0.7, loc=(0, 0, h * 0.7), rot=(math.degrees(math.sin(a)) * 45, -math.degrees(math.cos(a)) * 45, 0),
              color=C("#7B4C2C"), seg=5)
    for k in range(7):
        a = 2 * math.pi * k / 7
        r = 0.55 if k else 0.0
        lv.ball(rng.uniform(0.45, 0.6), loc=(r * math.cos(a), r * math.sin(a), h + 0.35 + rng.uniform(-0.15, 0.25)),
                scale=(1, 1, 0.82), color=C(color, rng.uniform(0.9, 1.1)), subdiv=2, jitter=0.1, rng=rng,
                sway_fn=lambda co, h=h: min(1.0, max(0.0, (co.z - h * 0.6) / 1.2)) * 0.7)
    return finish(name, [t, lv], MICI_DIR)


def bush():
    new_scene()
    p = Part("Frunze")
    for (x, y, r) in ((0, 0, 0.42), (0.35, 0.1, 0.32), (-0.3, 0.12, 0.3), (0.05, -0.28, 0.3)):
        p.ball(r, loc=(x, y, r * 0.7), scale=(1, 1, 0.85), color=C("#4FA834", rng.uniform(0.85, 1.1)), subdiv=1, jitter=0.12,
               rng=rng, sway_fn=lambda co: min(1.0, co.z / 0.8) * 0.4)
    return finish("tufa", [p], MICI_DIR)


def grass_tuft():
    new_scene()
    p = Part("Frunze")
    for k in range(7):
        a = 2 * math.pi * k / 7 + rng.uniform(-0.3, 0.3)
        h = rng.uniform(0.22, 0.38)
        lean = rng.uniform(0.06, 0.14)
        x0, y0 = 0.05 * math.cos(a), 0.05 * math.sin(a)
        p.poly([(x0 - 0.025 * math.sin(a), y0 + 0.025 * math.cos(a), 0), (x0 + 0.025 * math.sin(a), y0 - 0.025 * math.cos(a), 0),
                (x0 + lean * math.cos(a), y0 + lean * math.sin(a), h)], color=C("#6CC23E", rng.uniform(0.85, 1.15)),
               sway_fn=lambda co, h=h: co.z / h)
    return finish("iarba", [p], MICI_DIR)


def flower(name, color):
    """low-poly flower clump: 5 stems (one triangle each) with a 4-petal cross on top (~25 triangles)"""
    new_scene()
    p = Part("Frunze")
    for k in range(5):
        a = 2 * math.pi * k / 5 + rng.uniform(-0.3, 0.3)
        r = rng.uniform(0.04, 0.12)
        x, y = r * math.cos(a), r * math.sin(a)
        h = rng.uniform(0.16, 0.28)
        p.poly([(x - 0.012, y, 0), (x + 0.012, y, 0), (x, y, h)], color=C("#4E9E30"), sway_fn=lambda co, h=h: co.z / h)
        s_ = 0.055
        for (dx, dy) in ((s_, 0), (-s_, 0), (0, s_), (0, -s_)):
            p.poly([(x, y, h + 0.01), (x + dx + dy * 0.6, y + dy - dx * 0.6, h + 0.02), (x + dx - dy * 0.6, y + dy + dx * 0.6, h + 0.02)],
                   color=C(color), sway=1.0)
    return finish(name, [p], MICI_DIR)


def fence():
    new_scene()
    p = Part("Corp")
    for x in (-0.6, 0.6):
        p.box((0.09, 0.09, 0.7), loc=(x, 0, 0.35), color=C(WOOD_D))
    for z in (0.28, 0.55):
        p.box((1.3, 0.05, 0.08), loc=(0, 0, z), color=C(WOOD))
    return finish("gard", [p], MICI_DIR)


def lantern():
    new_scene()
    p, glow = Part("Corp"), Part("Lumina")
    p.cyl(0.12, 0.1, 0.12, loc=(0, 0, 0), color=C(STONE_D), seg=8)
    p.cyl(0.04, 0.04, 1.1, loc=(0, 0, 0.1), color=C("#3F2D22"), seg=6)
    p.cyl(0.14, 0.14, 0.04, loc=(0, 0, 1.18), color=C(GOLD), seg=8)
    glow.cyl(0.1, 0.1, 0.24, loc=(0, 0, 1.22), color=C(WARM), seg=8)
    p.cyl(0.15, 0.0, 0.16, loc=(0, 0, 1.46), color=C(GOLD), seg=8)
    return finish("felinar", [p, glow], MICI_DIR)


def barrel():
    new_scene()
    p = Part("Corp")
    p.cyl(0.22, 0.24, 0.32, loc=(0, 0, 0), color=C("#A8703F"), seg=10)
    p.cyl(0.24, 0.22, 0.32, loc=(0, 0, 0.32), color=C("#A8703F"), seg=10)
    for z in (0.1, 0.52):
        p.cyl(0.245, 0.245, 0.04, loc=(0, 0, z), color=C("#5C4232"), seg=10)
    return finish("butoi", [p], MICI_DIR)


def crate():
    new_scene()
    p = Part("Corp")
    p.box((0.45, 0.45, 0.42), loc=(0, 0, 0.21), color=C(WOOD))
    for z in (0.05, 0.37):
        p.box((0.47, 0.47, 0.05), loc=(0, 0, z), color=C(WOOD_D))
    return finish("lada", [p], MICI_DIR)


def crystal(name, colors, n):
    new_scene()
    p = Part("Cristal")
    for k in range(n):
        a = 2 * math.pi * k / n
        h = rng.uniform(0.35, 0.8) * (1.3 if k == 0 else 1)
        p.cyl(0.08 + 0.03 * (k == 0), 0.0, h, loc=(0.1 * math.cos(a) * (k > 0), 0.1 * math.sin(a) * (k > 0), 0),
              rot=(rng.uniform(-25, 25) * (k > 0), rng.uniform(-25, 25) * (k > 0), 0), color=C(colors[k % len(colors)]),
              seg=6, smooth=False)
    obs = [p.to_object()]
    export(obs, os.path.join(MICI_DIR, f"{name}.glb"))
    log(f"[glb] {name}: {tri_count(obs)} triangles")


def rock_small(name, s):
    new_scene()
    p = Part("Corp")
    p.ball(0.3 * s, loc=(0, 0, 0.12 * s), scale=(1.2, 0.95, 0.7), color=C("#A99CA3"), subdiv=1, smooth=False, jitter=0.18,
           rng=rng)
    p.ball(0.18 * s, loc=(0.28 * s, 0.1 * s, 0.07 * s), scale=(1, 0.9, 0.7), color=C("#B5A89E"), subdiv=1, smooth=False,
           jitter=0.2, rng=rng)
    return finish(name, [p], MICI_DIR)


def lily():
    new_scene()
    p = Part("Frunze")
    n = 12
    for k in range(n - 1):
        a0, a1 = 2 * math.pi * k / n + 0.3, 2 * math.pi * (k + 1) / n + 0.3
        p.poly([(0, 0, 0.01), (0.22 * math.cos(a0), 0.22 * math.sin(a0), 0.01), (0.22 * math.cos(a1), 0.22 * math.sin(a1), 0.01)],
               color=C("#4FAF3F", 0.9 + 0.1 * (k % 2)), sway=0.2)
    p.ball(0.06, loc=(0.05, 0.03, 0.05), scale=(1, 1, 0.7), color=C("#FF9CC8"), subdiv=1, sway=0.2)
    return finish("nufar", [p], MICI_DIR)


def wheat():
    """wheat clump: 6 stalks (one triangle) with a two-triangle ear (~18 triangles)"""
    new_scene()
    p = Part("Frunze")
    for k in range(6):
        a = 2 * math.pi * k / 6
        x, y = 0.08 * math.cos(a), 0.08 * math.sin(a)
        h = rng.uniform(0.55, 0.75)
        p.poly([(x - 0.01, y, 0), (x + 0.01, y, 0), (x, y, h)], color=C("#D9B44A"), sway_fn=lambda co, h=h: co.z / h)
        p.poly([(x, y, h - 0.02), (x + 0.035, y, h + 0.06), (x, y, h + 0.16), (x - 0.035, y, h + 0.06)], color=C("#F2C94C"),
               sway=1.0)
    return finish("grau", [p], MICI_DIR)


# ============================================================================= placement
class Ground:
    """terrain surface queries (ray cast on the exported terrain mesh), masks from the terrain build"""

    def __init__(self):
        from mathutils.bvhtree import BVHTree
        T = np.load(os.path.join(BUILD, "teren.npz"))
        self.T = T
        V, F = T["V"], T["F"]
        self.top_faces = set()
        tc = int(T["top_count"])
        self.is_top_face = np.all(F < tc, axis=1)
        self.bvh = BVHTree.FromPolygons(V.tolist(), F.tolist())
        self.lo, self.hi = T["lo"], T["hi"]
        self.res = 20.0
        self.tiles, self.tile_r = tiles_blender()

    def px(self, x, y):
        return (x - self.lo[0]) * self.res, (self.hi[1] - y) * self.res

    def mask(self, name, x, y):
        from scipy import ndimage as ndi
        cx, cy = self.px(x, y)
        return float(ndi.map_coordinates(self.T[name].astype(np.float32), [[cy - 0.5], [cx - 0.5]], order=1, mode="nearest")[0])

    def hit(self, x, y):
        loc, n, fi, d = self.bvh.ray_cast(Vector((x, y, 20.0)), Vector((0, 0, -1)), 60)
        if loc is None or not self.is_top_face[fi]:
            return None
        return loc, n

    def free(self, x, y, clear_tiles=0.4, props=0.35, water=True, path_max=0.35, slope=0.86):
        h = self.hit(x, y)
        if h is None:
            return None
        loc, n = h
        if n.z < slope:
            return None
        if np.min(np.hypot(self.tiles[:, 0] - x, self.tiles[:, 1] - y)) < self.tile_r + clear_tiles:
            return None
        for p in layout.HERO:
            if math.hypot(p["x"] - x, p["y"] - y) < p["r"] + props:
                return None
        bt = layout.BIG_TREE
        if math.hypot(bt["x"] - x, bt["y"] - y) < 1.6:
            return None
        if math.hypot(layout.MOUND["x"] - x, layout.MOUND["y"] - y) < 3.6:
            return None
        if water and (self.mask("in_river", x, y) > 0.2 or self.mask("lagoon", x, y) > 0.2):
            return None
        if self.mask("path", x, y) > path_max:
            return None
        return loc


def scatter(G, count, tries, rule, min_dist, existing=None, region=None):
    pts = [] if existing is None else existing
    out = []
    lo, hi = G.lo, G.hi
    for _ in range(tries):
        if len(out) >= count:
            break
        if region is None:
            x, y = rng.uniform(lo[0], hi[0]), rng.uniform(lo[1], hi[1])
        else:
            cx, cy, r = region
            a, rr = rng.uniform(0, 2 * math.pi), r * math.sqrt(rng.uniform(0, 1))
            x, y = cx + rr * math.cos(a), cy + rr * math.sin(a)
        loc = rule(x, y)
        if loc is None:
            continue
        if any(math.hypot(px - x, py - y) < min_dist for (px, py, _z) in pts + out):
            continue
        out.append((x, y, loc.z))
    return out


def place_all():
    G = Ground()
    inst = {}
    tiles, tr = G.tiles, G.tile_r
    R_t = np.hypot(tiles[:, 0] - layout.MOUND["x"], tiles[:, 1] - layout.MOUND["y"])
    centre = np.array([layout.MOUND["x"], layout.MOUND["y"]])

    def outside_ring(x, y, extra):
        """beyond the tile ring (between the ring and the rim)"""
        d = np.hypot(tiles[:, 0] - x, tiles[:, 1] - y)
        i = int(np.argmin(d))
        return math.hypot(x - centre[0], y - centre[1]) > R_t[i] + extra

    def camera_side(x, y):
        """in front of the front tiles (between them and the default game camera): no tall trees there"""
        return y < -4.2 and -6.2 < x < 6.2

    rule_rim = lambda x, y: G.free(x, y, 0.55) if outside_ring(x, y, 0.9) and not camera_side(x, y) else None  # noqa: E731
    palms = scatter(G, 12, 6000, rule_rim, 2.6)
    inst["palmier"] = palms
    blos = scatter(G, 6, 6000, lambda x, y: None if camera_side(x, y) else G.free(x, y, 0.7), 3.5, existing=palms)
    inst["copac_roz"] = blos
    bushes = scatter(G, 46, 9000, lambda x, y: G.free(x, y, 0.3), 1.1, existing=palms + blos)
    inst["tufa"] = bushes
    big = palms + blos + bushes
    inst["iarba"] = scatter(G, 900, 30000, lambda x, y: G.free(x, y, 0.08, props=0.05, path_max=0.25), 0.32, existing=big)
    flowers = []
    for _ in range(26):  # flower clusters
        c = scatter(G, 1, 400, lambda x, y: G.free(x, y, 0.15), 0.1, existing=big)
        if not c:
            continue
        cx, cy, _ = c[0]
        flowers += scatter(G, 9, 300, lambda x, y: G.free(x, y, 0.1), 0.22, existing=big + flowers, region=(cx, cy, 0.9))
    inst["floare"] = flowers
    # lanterns: between every other pair of tiles, on the outer side of the ring
    lan = []
    for i in range(0, len(tiles), 2):
        a, b = tiles[i], tiles[(i + 1) % len(tiles)]
        m = (a[:2] + b[:2]) / 2
        out = m - centre
        out /= np.linalg.norm(out)
        for off in (1.0, 1.25, 0.8):
            x, y = m + out * off
            loc = G.free(x, y, 0.15, path_max=1.0)
            if loc is not None:
                lan.append((x, y, loc.z))
                break
    inst["felinar"] = lan
    # wheat field + fence near the windmill
    mill = next(p for p in layout.HERO if p["name"] == "moara")
    field = None
    for _ in range(4000):
        a = rng.uniform(0, 2 * math.pi)
        r = rng.uniform(2.3, 3.6)
        x, y = mill["x"] + r * math.cos(a), mill["y"] + r * math.sin(a)
        if all(G.free(x + 0.9 * math.cos(b), y + 0.9 * math.sin(b), 0.3) is not None for b in np.linspace(0, 2 * np.pi, 8, endpoint=False)) \
                and G.free(x, y, 0.3) is not None:
            field = (x, y)
            break
    if field:
        inst["grau"] = scatter(G, 45, 3000, lambda x, y: G.free(x, y, 0.15), 0.22, region=(field[0], field[1], 1.0))
        fences = []
        for k in range(8):
            a = 2 * math.pi * k / 8
            x, y = field[0] + 1.35 * math.cos(a), field[1] + 1.35 * math.sin(a)
            loc = G.free(x, y, 0.2)
            if loc is not None:
                fences.append((x, y, loc.z, a + math.pi / 2))
        inst["gard"] = fences
    # crystals around the portal (not in front of its steps)
    por = next(p for p in layout.HERO if p["name"] == "portal")
    fr = math.radians(por["rot"]) - math.pi / 2
    cr = []
    for _ in range(3000):
        if len(cr) >= 7:
            break
        a = rng.uniform(0, 2 * math.pi)
        if abs(math.atan2(math.sin(a - fr), math.cos(a - fr))) < 0.8:
            continue
        r = rng.uniform(1.6, 2.4)
        x, y = por["x"] + r * math.cos(a), por["y"] + r * math.sin(a)
        loc = G.free(x, y, 0.3, props=0.0, path_max=1.0)
        if loc is not None and all(math.hypot(x - q[0], y - q[1]) > 0.7 for q in cr):
            cr.append((x, y, loc.z))
    inst["cristal"] = cr
    # barrels and crates near the workshop, dock and market
    goods = []
    for name, n in (("atelier", 5), ("piata", 4), ("debarcader", 3)):
        p = next(q for q in layout.HERO if q["name"] == name)
        goods += scatter(G, n, 2000, lambda x, y: G.free(x, y, 0.3, props=-0.25, path_max=1.0), 0.55, existing=goods,
                         region=(p["x"], p["y"], p["r"] + 0.9))
    inst["butoi"] = goods[::2]
    inst["lada"] = goods[1::2]
    # rocks along the rim and the river banks
    inst["piatra"] = scatter(G, 34, 12000, lambda x, y: G.free(x, y, 0.25, slope=0.6, path_max=0.6, water=True)
                             if outside_ring(x, y, 1.3) else None, 1.0, existing=big)
    # lily pads on the river and the lagoon (water level, not on the terrain)
    lil = []
    rp = G.T["river_pts"]
    for k in range(18):
        i = int(rng.uniform(2, len(rp) - 2))
        d = rp[i + 1] - rp[i - 1]
        nrm = np.array([-d[1], d[0]]) / np.linalg.norm(d)
        x, y = rp[i] + nrm * rng.uniform(-0.55, 0.55)
        if all(math.hypot(x - q[0], y - q[1]) > 0.5 for q in lil) and \
                all(math.hypot(x - p["x"], y - p["y"]) > 1.0 for p in layout.HERO if p["name"] == "pod"):
            lil.append((x, y, -1.40))
    inst["nufar"] = lil
    return inst


def write_props(inst):
    G = Ground()
    lines = ["# Insula 1 v2: clădirile mari, pe faze (generat de blender/insula_v2/build_props.py).",
             "# poz = Vector3 Godot (metri), rot = grade în jurul verticalei. Faza 1 natură, 2 sat, 3 castel/port/portal.",
             "extends RefCounted", "", "const PROPS := ["]
    for p in layout.HERO:
        if p["name"] == "barca":
            z = -2.64  # floats on the lagoon
        elif p["name"] == "debarcader":
            z = -2.64 + 0.45
        elif p["name"] == "castel":
            z = 0.5
        elif p["name"] == "pod":
            z = 0.42
        else:
            h = G.hit(p["x"], p["y"])
            z = h[0].z if h else 0.0
        rot = p["rot"]
        if p["name"] == "pod":  # span along the radial direction of the moat
            rot = math.degrees(math.atan2(p["y"] - layout.MOUND["y"], p["x"] - layout.MOUND["x"]))
        lines.append(f'\t{{"id": "{p.get("id", p["name"])}", "fisier": "{p["name"]}", "poz": {gd_vec3((p["x"], p["y"], z))}, '
                     f'"rot": {rot:.1f}, "faza": {p["faza"]}}},')
    bt = layout.BIG_TREE
    h = G.hit(bt["x"], bt["y"])
    lines.append(f'\t{{"id": "copac_mare", "fisier": "copac_mare", "poz": {gd_vec3((bt["x"], bt["y"], h[0].z if h else 0.0))}, '
                 f'"rot": 20.0, "faza": 1}},')
    lines.append("]")
    with open(os.path.join(OUT_DATA, "props.gd"), "w") as f:
        f.write("\n".join(lines) + "\n")
    # instances
    lines = ["# Insula 1 v2: elementele mici, instanțiate cu MultiMesh (generat de blender/insula_v2/build_props.py).",
             "# Pentru fiecare tip: x, y, z (metri, Godot), rotație (radiani, în jurul verticalei), scară; câte 5 numere.",
             "extends RefCounted", "", "const INSTANTE := {"]
    variants = {"palmier": ["palmier_a", "palmier_b", "palmier_c"], "copac_roz": ["copac_roz_a", "copac_roz_b"],
                "floare": ["floare_roz", "floare_galbena", "floare_alba"], "cristal": ["cristal_a", "cristal_b", "cristal_c"],
                "piatra": ["piatra_a", "piatra_b"]}
    total = 0
    by_mesh = {}
    for kind, pts in inst.items():
        names = variants.get(kind, [kind])
        for k, q in enumerate(pts):
            x, y, z = q[:3]
            rot = q[3] if len(q) > 3 else rng.uniform(0, 2 * math.pi)
            sc = {"palmier": rng.uniform(0.85, 1.15), "copac_roz": rng.uniform(0.9, 1.2), "tufa": rng.uniform(0.7, 1.3),
                  "iarba": rng.uniform(0.7, 1.4), "floare": rng.uniform(0.8, 1.3), "piatra": rng.uniform(0.6, 1.6),
                  "cristal": rng.uniform(0.8, 1.4), "nufar": rng.uniform(0.7, 1.3), "grau": rng.uniform(0.85, 1.15)}.get(kind, 1.0)
            by_mesh.setdefault(names[k % len(names)], []).append((x, y, z, rot, sc))
    for mesh, pts in sorted(by_mesh.items()):
        flat = []
        for x, y, z, rot, sc in pts:
            flat += [round(x, 3), round(z, 3), round(-y, 3), round(rot, 3), round(sc, 3)]
        lines.append(f'\t"{mesh}": [' + ", ".join(str(v) for v in flat) + "],")
        total += len(pts)
    lines.append("}")
    with open(os.path.join(OUT_DATA, "vegetatie.gd"), "w") as f:
        f.write("\n".join(lines) + "\n")
    log("[data] props.gd, vegetatie.gd: %d instances in %d meshes" % (total, len(by_mesh)))
    return by_mesh


def main():
    tris = {}
    for fn in (castel, moara, portal, piata, atelier, debarcader, barca, pod, copac_mare):
        tris[fn.__name__] = fn()
    tris["palmier_a"] = palm("palmier_a", 3.4, 0.6, 8)
    tris["palmier_b"] = palm("palmier_b", 2.8, 0.9, 7)
    tris["palmier_c"] = palm("palmier_c", 4.0, 0.4, 9)
    tris["copac_roz_a"] = blossom("copac_roz_a", 1.7, "#FF9CC8")
    tris["copac_roz_b"] = blossom("copac_roz_b", 1.4, "#FFB3D9")
    tris["tufa"] = bush()
    tris["iarba"] = grass_tuft()
    tris["floare_roz"] = flower("floare_roz", "#FF7FB5")
    tris["floare_galbena"] = flower("floare_galbena", "#FFD23F")
    tris["floare_alba"] = flower("floare_alba", "#FFFFFF")
    tris["gard"] = fence()
    tris["felinar"] = lantern()
    tris["butoi"] = barrel()
    tris["lada"] = crate()
    crystal("cristal_a", ("#58E6FF", "#7A5CFF"), 5)
    crystal("cristal_b", ("#B07CFF", "#58E6FF"), 4)
    crystal("cristal_c", ("#58E6FF",), 3)
    tris["piatra_a"] = rock_small("piatra_a", 1.0)
    tris["piatra_b"] = rock_small("piatra_b", 0.7)
    tris["nufar"] = lily()
    tris["grau"] = wheat()
    inst = place_all()
    write_props(inst)


if __name__ == "__main__":
    main()
