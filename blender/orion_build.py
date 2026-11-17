"""
Orion – mascota Buble, generată procedural pentru Blender (Cycles).

Rulare (Blender ca modul Python, cu scikit-image instalat):
    python orion_build.py --out ./out [--res 0.0075] [--fur 260000] [--render hero,turn] [--samples 96]

Ce face:
  1. Sculptează corpul ca un câmp SDF (sfere/elipsoizi/conuri rotunjite unite lin)
     și îl transformă în mesh cu marching cubes – forme organice, nu primitive lipite.
  2. Pictează culorile pe vârfuri (portocaliu-auriu, alb pe bot/piept, pete, vârfuri negre,
     spirală turcoaz care strălucește pe coadă).
  3. Crește blană reală (Hair Curves) cu lungime/direcție pe zone și smocuri (clumping).
  4. Adaugă ochi, ochelari de aviator, eșarfă + pelerină, rucsac cu hartă, felinar, curele.
  5. Pune lumina de studio (cheie caldă + contur rece), randează în Cycles și adaugă bloom.
  6. Salvează orion.blend (cu blană) și orion_game.glb (fără blană, pentru joc).
"""
import argparse
import math
import os
import sys

import bpy
import bmesh
import numpy as np
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree

# ----------------------------------------------------------------------------- args
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
ap = argparse.ArgumentParser()
ap.add_argument("--out", default=os.path.join(os.path.dirname(os.path.abspath(__file__)), "out"))
ap.add_argument("--res", type=float, default=0.0075)
ap.add_argument("--fur", type=int, default=260000)
ap.add_argument("--render", default="hero")
ap.add_argument("--samples", type=int, default=96)
ap.add_argument("--size", type=int, default=1024)
ap.add_argument("--seed", type=int, default=7)
ap.add_argument("--no-blend", action="store_true")
ap.add_argument("--no-glb", action="store_true")
args = ap.parse_args(argv)
os.makedirs(args.out, exist_ok=True)
rng = np.random.default_rng(args.seed)

# ----------------------------------------------------------------------------- scene reset
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
COL = scene.collection


def srgb(h):
    """hex sRGB -> linear rgb tuple"""
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


def link(obj):
    COL.objects.link(obj)
    return obj


# ============================================================================= 1. SDF body
def norm(v):
    return np.sqrt(np.sum(v * v, axis=-1))


def rot_matrix(euler_deg):
    from mathutils import Euler
    return np.array(Euler([math.radians(a) for a in euler_deg]).to_matrix(), dtype=np.float32)


def sd_ellipsoid(P, c, r, rot=None):
    q = P - np.asarray(c, np.float32)
    if rot is not None:
        q = q @ rot_matrix(rot)
    r = np.asarray(r, np.float32)
    k0 = norm(q / r)
    k1 = norm(q / (r * r))
    return k0 * (k0 - 1.0) / np.maximum(k1, 1e-6)


def sd_round_cone(P, a, b, r1, r2):
    a = np.asarray(a, np.float32)
    b = np.asarray(b, np.float32)
    ba = b - a
    l2 = float(ba @ ba)
    rr = r1 - r2
    a2 = l2 - rr * rr
    il2 = 1.0 / l2
    pa = P - a
    y = pa @ ba
    z = y - l2
    w = pa * l2 - y[:, None] * ba[None, :]
    x2 = np.sum(w * w, axis=1)
    y2 = y * y * l2
    z2 = z * z * l2
    k = np.sign(rr) * rr * rr * x2
    d3 = (np.sqrt(np.maximum(x2 * a2 * il2, 0)) + y * rr) * il2 - r1
    d1 = np.sqrt(x2 + z2) * il2 - r2
    d2 = np.sqrt(x2 + y2) * il2 - r1
    return np.where(np.sign(z) * a2 * z2 > k, d1, np.where(np.sign(y) * a2 * y2 < k, d2, d3))


def flatten(P, origin, axis, factor):
    """scales the component of P along axis (around origin) by factor -> thinner shape"""
    axis = np.asarray(axis, np.float32)
    axis = axis / np.linalg.norm(axis)
    t = (P - np.asarray(origin, np.float32)) @ axis
    return P + ((factor - 1.0) * t)[:, None] * axis[None, :]


def smin(a, b, k):
    if k <= 0:
        return np.minimum(a, b)
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0, 1)
    return b + (a - b) * h - k * h * (1 - h)


def smax(a, b, k):
    return -smin(-a, -b, k)


PRIMS = []  # (name, region, fn(P)->d, k, op)


def add(name, region, fn, k=0.05, op="add"):
    PRIMS.append((name, region, fn, k, op))


def mirror(fn_builder, name, region, k=0.05, op="add"):
    for s, side in ((1, "L"), (-1, "R")):
        add(f"{name}_{side}", region, fn_builder(s), k, op)


# --- head
add("head", "head", lambda P: sd_ellipsoid(P, (0, 0.02, 1.45), (0.47, 0.42, 0.40)), 0.0)
add("cranium", "head", lambda P: sd_ellipsoid(P, (0, 0.05, 1.57), (0.39, 0.36, 0.29)), 0.08)
mirror(lambda s: (lambda P: sd_ellipsoid(P, (s * 0.31, -0.08, 1.31), (0.24, 0.20, 0.19), rot=(0, s * 20, 0))),
       "cheek", "cheek", 0.10)
add("muzzle", "muzzle", lambda P: sd_ellipsoid(P, (0, -0.31, 1.34), (0.19, 0.15, 0.13)), 0.06)
mirror(lambda s: (lambda P: sd_ellipsoid(P, (s * 0.085, -0.405, 1.315), (0.105, 0.085, 0.085))),
       "puff", "muzzle", 0.04)
add("chin", "chin", lambda P: sd_ellipsoid(P, (0, -0.30, 1.19), (0.13, 0.11, 0.085)), 0.06)

EAR_BASE = (0.26, 0.06, 1.70)
EAR_TIP = (0.47, 0.09, 2.19)


def ear_fn(s):
    a = (s * EAR_BASE[0], EAR_BASE[1], EAR_BASE[2])
    b = (s * EAR_TIP[0], EAR_TIP[1], EAR_TIP[2])
    thick_axis = (s * -0.15, 1.0, 0.05)

    def f(P):
        Q = flatten(P, a, thick_axis, 2.6)
        d = sd_round_cone(Q, a, b, 0.175, 0.012)
        # hollow on the front (inner ear)
        hole = sd_ellipsoid(P, (s * 0.355, -0.04, 1.93), (0.095, 0.055, 0.19), rot=(10, 0, s * -24))
        return smax(d, -hole, 0.02)
    return f


mirror(ear_fn, "ear", "ear", 0.07)

# --- body
add("neck", "neck", lambda P: sd_ellipsoid(P, (0, 0.0, 1.07), (0.21, 0.19, 0.16)), 0.08)
add("chest", "chest", lambda P: sd_ellipsoid(P, (0, -0.04, 0.88), (0.30, 0.25, 0.26)), 0.10)
add("belly", "belly", lambda P: sd_ellipsoid(P, (0, -0.03, 0.66), (0.31, 0.27, 0.27)), 0.10)
add("hips", "hips", lambda P: sd_ellipsoid(P, (0, 0.03, 0.47), (0.30, 0.25, 0.20)), 0.10)

# --- arms (short chibi arms, paws a bit forward)
mirror(lambda s: (lambda P: sd_round_cone(P, (s * 0.27, -0.01, 0.96), (s * 0.40, -0.11, 0.64), 0.115, 0.088)),
       "arm", "arm", 0.06)
mirror(lambda s: (lambda P: sd_ellipsoid(P, (s * 0.425, -0.14, 0.565), (0.11, 0.115, 0.10), rot=(0, 0, 0))),
       "paw", "paw", 0.04)

# --- legs
mirror(lambda s: (lambda P: sd_ellipsoid(P, (s * 0.17, -0.01, 0.33), (0.16, 0.17, 0.17))), "thigh", "leg", 0.08)
mirror(lambda s: (lambda P: sd_round_cone(P, (s * 0.18, -0.03, 0.28), (s * 0.19, -0.05, 0.10), 0.12, 0.10)),
       "shin", "leg", 0.05)
mirror(lambda s: (lambda P: sd_ellipsoid(P, (s * 0.20, -0.12, 0.075), (0.135, 0.19, 0.085))), "foot", "foot", 0.05)

# --- tail: big fluffy curl behind, to the character's right (image left)
TAIL_P = np.array([(-0.02, 0.22, 0.44), (-0.08, 0.42, 0.42), (-0.18, 0.58, 0.54), (-0.27, 0.67, 0.77),
                   (-0.32, 0.67, 1.01), (-0.31, 0.58, 1.22), (-0.26, 0.47, 1.34), (-0.20, 0.38, 1.38)],
                  np.float32)
TAIL_R = [0.075, 0.12, 0.16, 0.185, 0.185, 0.155, 0.11, 0.05]
for i in range(len(TAIL_P) - 1):
    add(f"tail{i}", "tail",
        (lambda a, b, r1, r2: (lambda P: sd_round_cone(P, a, b, r1, r2)))(TAIL_P[i], TAIL_P[i + 1], TAIL_R[i],
                                                                         TAIL_R[i + 1]),
        0.09 if i == 0 else 0.04)

# --- subtractions: eye sockets and open mouth
EYE_C = {s: np.array((s * 0.165, -0.41, 1.465)) for s in (1, -1)}
mirror(lambda s: (lambda P: sd_ellipsoid(P, (s * 0.165, -0.49, 1.465), (0.105, 0.07, 0.12))), "socket", "head",
       0.035, op="sub")
MOUTH_C = np.array((0, -0.455, 1.245))
add("mouth", "mouth", lambda P: np.maximum(sd_ellipsoid(P, MOUTH_C + [0, 0, 0.03], (0.115, 0.08, 0.08)),
                                           P[:, 2] - (MOUTH_C[2] + 0.028)), 0.015, op="sub")


def body_sdf(P):
    d = None
    for name, region, fn, k, op in PRIMS:
        di = fn(P)
        if d is None:
            d = di
        elif op == "add":
            d = smin(d, di, k)
        else:
            d = smax(d, -di, k)
    d = np.maximum(d, -P[:, 2])  # flat soles
    return d


def build_body():
    from skimage.measure import marching_cubes
    h = args.res
    lo = np.array([-0.78, -0.68, -0.02], np.float32)
    hi = np.array([0.78, 0.98, 2.22], np.float32)
    n = np.ceil((hi - lo) / h).astype(int) + 1
    xs = lo[0] + np.arange(n[0]) * h
    ys = lo[1] + np.arange(n[1]) * h
    zs = lo[2] + np.arange(n[2]) * h
    vol = np.empty((n[0], n[1], n[2]), np.float32)
    X, Y = np.meshgrid(xs, ys, indexing="ij")
    X = X.ravel().astype(np.float32)
    Y = Y.ravel().astype(np.float32)
    step = 16
    for z0 in range(0, n[2], step):
        zz = zs[z0:z0 + step]
        P = np.stack([np.tile(X, len(zz)), np.tile(Y, len(zz)), np.repeat(zz, len(X))], 1).astype(np.float32)
        d = body_sdf(P).reshape(len(zz), n[0], n[1])
        vol[:, :, z0:z0 + len(zz)] = np.moveaxis(d, 0, 2)
    verts, faces, _, _ = marching_cubes(vol, 0.0, spacing=(h, h, h))
    verts = verts + lo
    print(f"[body] grid {n.tolist()} -> {len(verts)} verts, {len(faces)} tris")
    me = bpy.data.meshes.new("OrionBody")
    me.vertices.add(len(verts))
    me.vertices.foreach_set("co", verts.astype(np.float32).ravel())
    me.loops.add(len(faces) * 3)
    me.loops.foreach_set("vertex_index", faces.astype(np.int32).ravel())
    me.polygons.add(len(faces))
    me.polygons.foreach_set("loop_start", np.arange(0, len(faces) * 3, 3, dtype=np.int32))
    me.update(calc_edges=True)
    me.validate()
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=h * 0.05)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    ob = link(bpy.data.objects.new("Orion_Body", me))
    mod = ob.modifiers.new("smooth", "SMOOTH")
    mod.factor = 0.6
    mod.iterations = 4
    dg = bpy.context.evaluated_depsgraph_get()
    me2 = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    ob.modifiers.clear()
    ob.data = me2
    bpy.data.meshes.remove(me)
    me2.name = "OrionBody"
    for p in me2.polygons:
        p.use_smooth = True
    return ob


body = build_body()
me = body.data
NV = len(me.vertices)
V = np.empty(NV * 3, np.float32)
me.vertices.foreach_get("co", V)
V = V.reshape(-1, 3)
N = np.empty(NV * 3, np.float32)
me.vertices.foreach_get("normal", N)
N = N.reshape(-1, 3)

# region per vertex = closest additive primitive
names, regions, dists = [], [], []
for name, region, fn, k, op in PRIMS:
    if op != "add":
        continue
    names.append(name)
    regions.append(region)
    dists.append(fn(V))
dists = np.stack(dists, 1)
REG = np.array(regions)[np.argmin(dists, 1)]
PRIM = np.array(names)[np.argmin(dists, 1)]


def rmask(*r):
    return np.isin(REG, r)


# ----------------------------------------------------------------------------- tail axis param
seg_len = np.linalg.norm(np.diff(TAIL_P, axis=0), axis=1)
cum = np.concatenate([[0], np.cumsum(seg_len)])
TAIL_LEN = cum[-1]


def tail_param(P):
    """returns (s in [0,1], closest axis point, tangent) for points P"""
    best = np.full(len(P), 1e9)
    s_out = np.zeros(len(P))
    c_out = np.zeros_like(P)
    t_out = np.zeros_like(P)
    for i in range(len(TAIL_P) - 1):
        a, b = TAIL_P[i], TAIL_P[i + 1]
        ab = b - a
        t = np.clip(((P - a) @ ab) / (ab @ ab), 0, 1)
        c = a + t[:, None] * ab
        d = norm(P - c)
        m = d < best
        best[m] = d[m]
        s_out[m] = (cum[i] + t[m] * seg_len[i]) / TAIL_LEN
        c_out[m] = c[m]
        t_out[m] = ab / np.linalg.norm(ab)
    return s_out, c_out, t_out


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


# ============================================================================= 2. colors
C_GOLD = np.array(srgb("#F29A22"))
C_GOLD_DEEP = np.array(srgb("#C9600E"))
C_CREAM = np.array(srgb("#FFF4E2"))
C_SPOT = np.array(srgb("#5A2408"))
C_BLACK = np.array(srgb("#2A1A14"))
C_MOUTH = np.array(srgb("#6E1E2A"))
C_INNER_EAR = np.array(srgb("#FFE6E0"))
C_GLOW = np.array(srgb("#12D6FF"))

col = np.tile(C_GOLD, (NV, 1))
# darker richer back/top, lighter sides toward front
back = smoothstep(-0.1, 0.8, N[:, 1]) * 0.7 + smoothstep(0.3, 1.0, N[:, 2]) * 0.3
col = col * (1 - back[:, None] * 0.55) + C_GOLD_DEEP * (back[:, None] * 0.55)

white = np.zeros(NV)
white = np.maximum(white, rmask("muzzle", "chin").astype(float))
# cheeks: front-lower part cream (lynx ruff)
cheek = rmask("cheek")
white = np.maximum(white, cheek * smoothstep(1.42, 1.28, V[:, 2]) * smoothstep(0.15, -0.25, V[:, 1]))
# belly/chest
torso = rmask("chest", "belly", "neck")
white = np.maximum(white, torso * smoothstep(-0.05, -0.45, N[:, 1]) * smoothstep(0.26, 0.14, np.abs(V[:, 0])))
# around eyes (lighter mask)
for s in (1, -1):
    d = norm(V - EYE_C[s])
    white = np.maximum(white, 0.35 * smoothstep(0.19, 0.13, d) * (V[:, 1] < -0.2))
# paws/toes
white = np.maximum(white, rmask("paw") * smoothstep(-0.12, -0.22, V[:, 1]))
white = np.maximum(white, rmask("foot") * smoothstep(-0.16, -0.27, V[:, 1]))
# inner ear
ear = rmask("ear")
inner_ear = ear * smoothstep(-0.1, -0.6, N[:, 1])
white = np.maximum(white, inner_ear)
col = col * (1 - white[:, None]) + C_CREAM * white[:, None]
col = np.where(inner_ear[:, None] > 0.5, col * 0.6 + C_INNER_EAR * 0.4, col)

# spots (KD-tree over random surface spots)
spot_ok = (white < 0.2) & ~rmask("ear", "paw", "foot") & ~((REG == "head") & (V[:, 1] < -0.25))
cand = np.where(spot_ok)[0]
spot_idx = rng.choice(cand, size=230, replace=False)
spot_r = rng.uniform(0.025, 0.05, size=len(spot_idx))
kd = KDTree(len(spot_idx))
for i, vi in enumerate(spot_idx):
    kd.insert(V[vi], i)
kd.balance()
spot = np.zeros(NV)
for vi in cand:
    co, i, d = kd.find(V[vi])
    spot[vi] = smoothstep(spot_r[i], spot_r[i] * 0.7, d)
col = col * (1 - 0.8 * spot[:, None]) + C_SPOT * (0.8 * spot[:, None])

# black: ear tips & ear back rim, tail tip
ear_t = np.zeros(NV)
eb, et = np.array(EAR_BASE), np.array(EAR_TIP)
for s in (1, -1):
    b = eb * [s, 1, 1]
    t = et * [s, 1, 1]
    ax = t - b
    ear_t = np.maximum(ear_t, ear * (((V - b) @ ax) / (ax @ ax)) * (np.sign(V[:, 0]) == s))
black = ear * smoothstep(0.62, 0.75, ear_t)
black = np.maximum(black, ear * smoothstep(0.2, 0.7, N[:, 1]) * smoothstep(0.45, 0.6, ear_t))
ts, tc, tt = tail_param(V)
tail = rmask("tail")
black = np.maximum(black, tail * smoothstep(0.86, 0.92, ts))
col = col * (1 - black[:, None]) + C_BLACK * black[:, None]

# mouth interior
mouth = smoothstep(0.125, 0.10, norm((V - MOUTH_C - [0, 0, 0.02]) * [1, 1, 1.1])) * (V[:, 1] > -0.53) * (V[:, 2] < MOUTH_C[2] + 0.04)
col = col * (1 - mouth[:, None]) + C_MOUTH * mouth[:, None]

# glow: helix on tail + spiral emblem on upper arms
glow = np.zeros(NV)
# tail frame (reference axis world X projected)
ref = np.array([1.0, 0, 0])
rel = V - tc
u = ref - tt * (tt @ ref)[:, None]
u /= np.maximum(norm(u)[:, None], 1e-6)
w = np.cross(tt, u)
theta = np.arctan2(np.sum(rel * w, 1), np.sum(rel * u, 1))
band = np.cos(theta - ts * 2 * np.pi * 2.6)
glow = np.maximum(glow, tail * smoothstep(0.86, 0.95, band) * smoothstep(0.08, 0.14, ts) * smoothstep(0.86, 0.8, ts))


def spiral_emblem(center, nrm, scale):
    nrm = nrm / np.linalg.norm(nrm)
    a = np.cross(nrm, [0, 0, 1.0])
    a /= np.linalg.norm(a)
    b = np.cross(nrm, a)
    rel = V - center
    x, y = rel @ a, rel @ b
    r = np.sqrt(x * x + y * y) / scale
    ang = np.arctan2(y, x) / (2 * np.pi)
    f = np.abs(((ang + r * 2.6) % 1.0) - 0.5)
    m = smoothstep(0.30, 0.42, f) * smoothstep(1.0, 0.85, r) * (np.abs(rel @ nrm) < 0.06)
    return m


for s in (1, -1):
    glow = np.maximum(glow, rmask("arm") * spiral_emblem(np.array([s * 0.36, -0.02, 0.86]),
                                                         np.array([s * 1.0, -0.2, 0.1]), 0.065))
col = col * (1 - glow[:, None] * 0.7) + C_GLOW * (glow[:, None] * 0.7)

ca = me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
ca.data.foreach_set("color", np.concatenate([col, np.ones((NV, 1))], 1).astype(np.float32).ravel())
ga = me.attributes.new("glow", "FLOAT", "POINT")
ga.data.foreach_set("value", glow.astype(np.float32))

BVH = BVHTree.FromObject(body, bpy.context.evaluated_depsgraph_get())


# ============================================================================= 3. fur
def fur_params():
    """per-vertex fur length, density, lift (how much it stands up)"""
    L = np.full(NV, 0.02)
    D = np.ones(NV)
    lift = np.full(NV, 0.35)
    L[rmask("head")] = 0.018
    face = rmask("head") & (V[:, 1] < -0.25)
    L[face] = 0.012
    L[rmask("cheek")] = 0.075
    lift[rmask("cheek")] = 0.25
    L[rmask("muzzle")] = 0.012
    L[rmask("chin")] = 0.03
    L[rmask("ear")] = 0.012
    L[inner_ear > 0.5] = 0.055
    lift[inner_ear > 0.5] = 0.55
    L[rmask("neck", "chest")] = 0.036
    L[rmask("belly")] = 0.028
    L[rmask("hips")] = 0.024
    L[rmask("arm")] = 0.022
    L[rmask("paw", "foot")] = 0.012
    L[rmask("leg")] = 0.02
    L[tail] = (0.045 + 0.025 * np.sin(ts * np.pi))[tail]
    lift[tail] = 0.4
    # bald zones: eyes, mouth, nose, soles
    for s in (1, -1):
        D *= smoothstep(0.125, 0.16, norm(V - EYE_C[s]))
    D *= 1 - mouth
    D *= smoothstep(0.0, 0.02, V[:, 2])
    D[rmask("ear") & (ear_t > 0.92)] = 0.0
    return L, D, lift


def flow_dir(P, Nn, reg, s_t, t_t):
    f = np.tile(np.array([0, 0.25, -1.0]), (len(P), 1))
    m = np.isin(reg, ["head", "ear"])
    f[m] = P[m] - np.array([0, -0.65, 1.40])
    m = np.isin(reg, ["muzzle", "chin"])
    f[m] = P[m] - np.array([0, -0.52, 1.34])
    m = reg == "cheek"
    f[m] = np.stack([np.sign(P[m, 0]) * 1.0, np.full(m.sum(), 0.35), np.full(m.sum(), -0.55)], 1)
    m = np.isin(reg, ["arm", "paw", "leg", "foot"])
    f[m] = [0, 0.1, -1.0]
    m = reg == "tail"
    f[m] = t_t[m]
    f = f - Nn * np.sum(f * Nn, 1)[:, None]
    return f / np.maximum(norm(f)[:, None], 1e-6)


def build_fur(count):
    Lv, Dv, Liftv = fur_params()
    tris = np.empty(len(me.loop_triangles) * 3, np.int32) if me.loop_triangles else None
    me.calc_loop_triangles()
    tris = np.empty(len(me.loop_triangles) * 3, np.int32)
    me.loop_triangles.foreach_get("vertices", tris)
    tris = tris.reshape(-1, 3)
    a, b, c = V[tris[:, 0]], V[tris[:, 1]], V[tris[:, 2]]
    area = 0.5 * norm(np.cross(b - a, c - a))
    w = area * Dv[tris].mean(1)
    w /= w.sum()
    ti = rng.choice(len(tris), size=count, p=w)
    r1, r2 = rng.random(count), rng.random(count)
    sq = np.sqrt(r1)
    bc = np.stack([1 - sq, sq * (1 - r2), sq * r2], 1)
    tv = tris[ti]
    P0 = np.einsum("ij,ijk->ik", bc, V[tv])
    Nn = np.einsum("ij,ijk->ik", bc, N[tv])
    Nn /= norm(Nn)[:, None]
    L = np.einsum("ij,ij->i", bc, Lv[tv]) * rng.uniform(0.75, 1.2, count)
    lift = np.einsum("ij,ij->i", bc, Liftv[tv])
    C = np.einsum("ij,ijk->ik", bc, col[tv])
    G = np.einsum("ij,ij->i", bc, glow[tv])
    reg = REG[tv[np.arange(count), np.argmax(bc, 1)]]
    s_t, _, t_t = tail_param(P0)
    F = flow_dir(P0, Nn, reg, s_t, t_t)
    d = Nn * lift[:, None] + F * (1 - lift[:, None])
    d /= norm(d)[:, None]
    jitter = rng.normal(0, 0.18, (count, 3))
    d = d + jitter - Nn * np.sum(jitter * Nn, 1)[:, None]
    d /= norm(d)[:, None]
    seg = 5
    t = np.linspace(0, 1, seg)
    root = P0 - Nn * 0.002
    pts = root[:, None, :] + d[:, None, :] * (L[:, None, None] * t[None, :, None])
    # droop with gravity + curl toward flow at tips
    pts += (np.array([0, 0, -1.0]) * 0.18 + 0)[None, None, :] * (L[:, None, None] * (t ** 2)[None, :, None])
    pts += F[:, None, :] * (L[:, None, None] * 0.25 * (t ** 2)[None, :, None])
    # clumping: pull tips toward clump centre tips -> stylised tufts
    nclump = count // 22
    ci = rng.choice(count, nclump, replace=False)
    kdc = KDTree(nclump)
    for i, j in enumerate(ci):
        kdc.insert(P0[j], i)
    kdc.balance()
    nearest = np.empty(count, np.int64)
    for i in range(count):
        nearest[i] = ci[kdc.find(P0[i])[1]]
    tgt = pts[nearest]
    cl = rng.uniform(0.45, 0.8, count)
    blend = (t ** 1.3)[None, :, None] * cl[:, None, None]
    pts = pts + (tgt - pts) * blend
    pts[:, 0, :] = root
    # lynx ear tufts: long black strands continuing past the ear tips, gathered to a point
    tufts, tcol, tL = [], [], []
    for s in (1, -1):
        base = np.array(EAR_TIP) * [s, 1, 1]
        axis = (np.array(EAR_TIP) - np.array(EAR_BASE)) * [s, 1, 1]
        axis /= np.linalg.norm(axis)
        tip = base + axis * 0.2 + np.array([s * 0.03, 0.02, 0.0])
        for i in range(260):
            r0 = base - axis * rng.uniform(0.0, 0.06) + rng.normal(0, 0.012, 3)
            tt = tip + rng.normal(0, 0.012, 3) - axis * rng.uniform(0, 0.06)
            mid = (r0 + tt) / 2 + np.array([s * 0.015, 0, 0]) * rng.uniform(0.5, 1.5)
            tufts.append([r0 + (mid - r0) * f * 2 if f <= 0.5 else mid + (tt - mid) * (f - 0.5) * 2
                          for f in t])
            tcol.append(C_BLACK)
            tL.append(0.03)
    pts = np.concatenate([pts, np.array(tufts)], 0)
    C = np.concatenate([C, np.array(tcol)], 0)
    G = np.concatenate([G, np.zeros(len(tufts))])
    L = np.concatenate([L, np.array(tL)])
    count = len(pts)
    cv = bpy.data.hair_curves.new("OrionFur")
    cv.add_curves([seg] * count)
    cv.position_data.foreach_set("vector", pts.astype(np.float32).ravel())
    rad = cv.attributes.get("radius") or cv.attributes.new("radius", "FLOAT", "POINT")
    rr = (np.array([0.0032, 0.0028, 0.0021, 0.0012, 0.0003])[None, :] * np.clip(L / 0.03, 0.8, 1.6)[:, None])
    rad.data.foreach_set("value", rr.astype(np.float32).ravel())
    fc = cv.attributes.new("fcol", "FLOAT_COLOR", "CURVE")
    fc.data.foreach_set("color", np.concatenate([C, np.ones((count, 1))], 1).astype(np.float32).ravel())
    gl = cv.attributes.new("glow", "FLOAT", "CURVE")
    gl.data.foreach_set("value", G.astype(np.float32))
    ob = link(bpy.data.objects.new("Orion_Fur", cv))
    print(f"[fur] {count} strands")
    return ob


# ============================================================================= materials
def new_mat(name):
    m = bpy.data.materials.new(name)
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(bsdf.outputs[0], out.inputs[0])
    return m, nt, bsdf


def simple_mat(name, color, rough=0.5, metal=0.0, emit=None, emit_str=0.0, coat=0.0, alpha=1.0, trans=0.0,
               ior=1.45, sss=0.0):
    m, nt, b = new_mat(name)
    b.inputs["Base Color"].default_value = (*srgb(color), 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    b.inputs["Coat Weight"].default_value = coat
    b.inputs["Transmission Weight"].default_value = trans
    b.inputs["IOR"].default_value = ior
    if sss:
        b.inputs["Subsurface Weight"].default_value = sss
        b.inputs["Subsurface Radius"].default_value = (0.3, 0.12, 0.06)
        b.inputs["Subsurface Scale"].default_value = 0.05
    if emit:
        b.inputs["Emission Color"].default_value = (*srgb(emit), 1)
        b.inputs["Emission Strength"].default_value = emit_str
    if alpha < 1:
        b.inputs["Alpha"].default_value = alpha
    return m


def attr_node(nt, name, x=-600, y=0):
    a = nt.nodes.new("ShaderNodeAttribute")
    a.attribute_name = name
    a.location = (x, y)
    return a


def skin_material():
    m, nt, b = new_mat("Orion_Skin")
    a = attr_node(nt, "Col")
    g = attr_node(nt, "glow", y=-300)
    mul = nt.nodes.new("ShaderNodeMix")
    mul.data_type = "RGBA"
    mul.blend_type = "MULTIPLY"
    mul.inputs["Factor"].default_value = 1.0
    nt.links.new(a.outputs["Color"], mul.inputs[6])
    mul.inputs[7].default_value = (0.8, 0.78, 0.76, 1)
    nt.links.new(mul.outputs[2], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.6
    b.inputs["Subsurface Weight"].default_value = 0.15
    b.inputs["Subsurface Radius"].default_value = (0.4, 0.15, 0.08)
    b.inputs["Subsurface Scale"].default_value = 0.03
    b.inputs["Emission Color"].default_value = (*C_GLOW, 1)
    em = nt.nodes.new("ShaderNodeMath")
    em.operation = "MULTIPLY"
    em.inputs[1].default_value = 2.5
    nt.links.new(g.outputs["Fac"], em.inputs[0])
    nt.links.new(em.outputs[0], b.inputs["Emission Strength"])
    return m


def fur_material():
    m, nt, b = new_mat("Orion_Fur")
    a = attr_node(nt, "fcol")
    g = attr_node(nt, "glow", y=-300)
    info = nt.nodes.new("ShaderNodeHairInfo")
    ramp = nt.nodes.new("ShaderNodeMapRange")
    nt.links.new(info.outputs["Intercept"], ramp.inputs["Value"])
    ramp.inputs["To Min"].default_value = 0.55
    ramp.inputs["To Max"].default_value = 1.08
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.blend_type = "MULTIPLY"
    mix.inputs["Factor"].default_value = 1.0
    nt.links.new(a.outputs["Color"], mix.inputs[6])
    comb = nt.nodes.new("ShaderNodeCombineColor")
    for i in range(3):
        nt.links.new(ramp.outputs[0], comb.inputs[i])
    nt.links.new(comb.outputs[0], mix.inputs[7])
    nt.links.new(mix.outputs[2], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.45
    b.inputs["Specular IOR Level"].default_value = 0.25
    b.inputs["Subsurface Weight"].default_value = 0.12
    b.inputs["Subsurface Radius"].default_value = (0.5, 0.25, 0.1)
    b.inputs["Subsurface Scale"].default_value = 0.01
    b.inputs["Emission Color"].default_value = (*C_GLOW, 1)
    em = nt.nodes.new("ShaderNodeMath")
    em.operation = "MULTIPLY"
    em.inputs[1].default_value = 3.0
    nt.links.new(g.outputs["Fac"], em.inputs[0])
    nt.links.new(em.outputs[0], b.inputs["Emission Strength"])
    return m


body.data.materials.append(skin_material())


# ============================================================================= helpers for props
def ray_surface(origin, direction):
    o = Vector(origin)
    d = Vector(direction).normalized()
    hit, n, idx, dist = BVH.ray_cast(o, d)
    return hit, n


def ring_points(center, normal, count=72, offset=0.03, ref=(1, 0, 0), arc=None, max_dist=None):
    c = Vector(center)
    nv = Vector(normal).normalized()
    u = Vector(ref)
    u = (u - nv * u.dot(nv)).normalized()
    v = nv.cross(u)
    pts, outs = [], []
    a0, a1 = arc if arc else (0, 2 * math.pi)
    closed = arc is None
    rng_a = np.linspace(a0, a1, count, endpoint=not closed)
    for a in rng_a:
        d = u * math.cos(a) + v * math.sin(a)
        hit, n = ray_surface(c, d)
        if hit is None or (max_dist and (hit - c).length > max_dist):
            if max_dist:
                hit = c + d * max_dist * 0.8
            else:
                continue
        pts.append(hit + d * offset)
        outs.append(d)
    return pts, outs, nv


def curve_tube(name, pts, radius, mat, cyclic=False, taper=None, res=4):
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = radius
    cu.bevel_resolution = res
    cu.use_fill_caps = True
    sp = cu.splines.new("NURBS")
    sp.points.add(len(pts) - 1)
    for i, p in enumerate(pts):
        sp.points[i].co = (p[0], p[1], p[2], 1)
        if taper is not None:
            sp.points[i].radius = taper[i]
    sp.use_cyclic_u = cyclic
    sp.use_endpoint_u = not cyclic
    sp.order_u = 4
    ob = link(bpy.data.objects.new(name, cu))
    cu.materials.append(mat)
    return ob


def band_mesh(name, pts, outs, axis, width, thick, mat, closed=True, subdiv=2):
    """rectangular strap following pts; axis = strap width direction (Vector or per point)"""
    bm = bmesh.new()
    rings = []
    for i, p in enumerate(pts):
        o = outs[i]
        ax = axis[i] if isinstance(axis, list) else axis
        ax = (ax - o * ax.dot(o)).normalized()
        q = [p + ax * width / 2, p + ax * width / 2 + o * thick, p - ax * width / 2 + o * thick, p - ax * width / 2]
        rings.append([bm.verts.new(x) for x in q])
    n = len(rings)
    for i in range(n if closed else n - 1):
        r0, r1 = rings[i], rings[(i + 1) % n]
        for k in range(4):
            bm.faces.new([r0[k], r0[(k + 1) % 4], r1[(k + 1) % 4], r1[k]])
    if not closed:
        bm.faces.new(rings[0][::-1])
        bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me_ = bpy.data.meshes.new(name)
    bm.to_mesh(me_)
    bm.free()
    for p in me_.polygons:
        p.use_smooth = True
    ob = link(bpy.data.objects.new(name, me_))
    me_.materials.append(mat)
    if subdiv:
        m = ob.modifiers.new("sub", "SUBSURF")
        m.levels = m.render_levels = subdiv
    return ob


def prim(kind, name, loc, scale=(1, 1, 1), rot=(0, 0, 0), mat=None, smooth=True, subdiv=0, **kw):
    fn = {"sphere": bpy.ops.mesh.primitive_uv_sphere_add, "cyl": bpy.ops.mesh.primitive_cylinder_add,
          "torus": bpy.ops.mesh.primitive_torus_add, "cube": bpy.ops.mesh.primitive_cube_add,
          "cone": bpy.ops.mesh.primitive_cone_add, "ico": bpy.ops.mesh.primitive_ico_sphere_add}[kind]
    if kind == "sphere":
        kw.setdefault("segments", 48)
        kw.setdefault("ring_count", 24)
    if kind == "cyl":
        kw.setdefault("vertices", 48)
    if kind == "torus":
        kw.setdefault("major_segments", 64)
        kw.setdefault("minor_segments", 16)
    fn(location=loc, rotation=[math.radians(a) for a in rot], **kw)
    ob = bpy.context.active_object
    ob.name = name
    ob.scale = scale
    if smooth:
        for p in ob.data.polygons:
            p.use_smooth = True
    if mat:
        ob.data.materials.append(mat)
    if subdiv:
        m = ob.modifiers.new("sub", "SUBSURF")
        m.levels = m.render_levels = subdiv
    return ob


def look_rot(direction, up=(0, 0, 1)):
    """rotation matrix with local -Y facing `direction`"""
    d = Vector(direction).normalized()
    return (-d).to_track_quat("Y", "Z").to_euler()


# ----------------------------------------------------------------------------- props materials
M_BRASS = simple_mat("Brass", "#D9A441", rough=0.28, metal=1.0)
M_LEATHER = simple_mat("Leather", "#6B3B1E", rough=0.55, coat=0.15)
M_LEATHER_D = simple_mat("LeatherDark", "#4A2612", rough=0.6)
M_RED = simple_mat("ScarfRed", "#E8322E", rough=0.7, sss=0.2)
M_GLASS = simple_mat("GogglesGlass", "#7FE9FF", rough=0.05, emit="#5FE6FF", emit_str=0.6, coat=1.0)
M_GLOWORB = simple_mat("GlowOrb", "#B9FBFF", rough=0.2, emit="#4FF0FF", emit_str=18.0)
M_PAPER = simple_mat("Parchment", "#EED9A8", rough=0.75)
M_NOSE = simple_mat("Nose", "#F28FA6", rough=0.3, coat=0.6, sss=0.3)
M_TONGUE = simple_mat("Tongue", "#F0708A", rough=0.35, coat=0.4, sss=0.3)
M_TOOTH = simple_mat("Tooth", "#FFFDF8", rough=0.25, coat=0.5)
M_LASH = simple_mat("Lash", "#241510", rough=0.5)
M_WHISK = simple_mat("Whisker", "#FFFFFF", rough=0.3)
M_HILITE = simple_mat("EyeHighlight", "#FFFFFF", rough=0.2, emit="#FFFFFF", emit_str=6.0)
M_GEM = simple_mat("Gem", "#7FF6FF", rough=0.05, emit="#38E8FF", emit_str=5.0, coat=1.0)


def eye_material():
    m, nt, b = new_mat("Eye")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Object"], sep.inputs[0])
    # radial distance in the front plane (x,z) of a unit sphere looking -Y
    vx = nt.nodes.new("ShaderNodeMath"); vx.operation = "SUBTRACT"; vx.inputs[1].default_value = 0.0
    nt.links.new(sep.outputs[0], vx.inputs[0])
    vz = nt.nodes.new("ShaderNodeMath"); vz.operation = "SUBTRACT"; vz.inputs[1].default_value = 0.05
    nt.links.new(sep.outputs[2], vz.inputs[0])
    comb = nt.nodes.new("ShaderNodeCombineXYZ")
    nt.links.new(vx.outputs[0], comb.inputs[0])
    nt.links.new(vz.outputs[0], comb.inputs[1])
    ln = nt.nodes.new("ShaderNodeVectorMath"); ln.operation = "LENGTH"
    nt.links.new(comb.outputs[0], ln.inputs[0])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    nt.links.new(ln.outputs["Value"], ramp.inputs[0])
    cr = ramp.color_ramp
    cr.interpolation = "EASE"
    stops = [(0.0, "#05070F"), (0.30, "#05070F"), (0.335, "#0B5BB8"), (0.50, "#1FA2F0"), (0.66, "#7FE3FF"),
             (0.74, "#0A3E8A"), (0.775, "#FFFFFF"), (1.0, "#F2F4FA")]
    cr.elements[0].position, cr.elements[0].color = stops[0][0], (*srgb(stops[0][1]), 1)
    cr.elements[1].position, cr.elements[1].color = stops[-1][0], (*srgb(stops[-1][1]), 1)
    for p, c in stops[1:-1]:
        e = cr.elements.new(p)
        e.color = (*srgb(c), 1)
    # only front hemisphere shows iris
    front = nt.nodes.new("ShaderNodeMath"); front.operation = "LESS_THAN"; front.inputs[1].default_value = 0.0
    nt.links.new(sep.outputs[1], front.inputs[0])
    mix = nt.nodes.new("ShaderNodeMix"); mix.data_type = "RGBA"
    nt.links.new(front.outputs[0], mix.inputs["Factor"])
    mix.inputs[6].default_value = (*srgb("#F2F4FA"), 1)
    nt.links.new(ramp.outputs[0], mix.inputs[7])
    nt.links.new(mix.outputs[2], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.05
    b.inputs["Coat Weight"].default_value = 1.0
    b.inputs["Coat Roughness"].default_value = 0.02
    # glow in iris a little
    b.inputs["Emission Color"].default_value = (*srgb("#2AB8FF"), 1)
    im = nt.nodes.new("ShaderNodeMapRange")
    nt.links.new(ln.outputs["Value"], im.inputs["Value"])
    im.inputs["From Min"].default_value = 0.4
    im.inputs["From Max"].default_value = 0.68
    im.inputs["To Min"].default_value = 0.0
    im.inputs["To Max"].default_value = 0.6
    im2 = nt.nodes.new("ShaderNodeMath"); im2.operation = "MULTIPLY"
    lt = nt.nodes.new("ShaderNodeMath"); lt.operation = "LESS_THAN"; lt.inputs[1].default_value = 0.72
    nt.links.new(ln.outputs["Value"], lt.inputs[0])
    nt.links.new(im.outputs[0], im2.inputs[0])
    nt.links.new(lt.outputs[0], im2.inputs[1])
    im3 = nt.nodes.new("ShaderNodeMath"); im3.operation = "MULTIPLY"
    nt.links.new(im2.outputs[0], im3.inputs[0])
    nt.links.new(front.outputs[0], im3.inputs[1])
    nt.links.new(im3.outputs[0], b.inputs["Emission Strength"])
    return m


M_EYE = eye_material()

# ============================================================================= 4. face
for s in (1, -1):
    c = EYE_C[s]
    direction = Vector((s * 0.22, -1.0, 0.02)).normalized()
    hit, n = ray_surface(Vector((c[0], 0.0, c[2])), (0, -1, 0))
    centre = Vector((c[0], hit.y + 0.045, c[2])) if hit else Vector(c)
    eye = prim("sphere", f"Eye_{'L' if s > 0 else 'R'}", centre, scale=(0.122, 0.078, 0.142), mat=M_EYE)
    eye.rotation_euler = (0, 0, math.radians(s * 14))
    eye.rotation_euler.rotate_axis("Y", math.radians(s * 8))
    bpy.context.view_layer.update()
    mw = eye.matrix_world
    # catch-lights
    prim("sphere", "EyeHL1", mw @ Vector((-0.25 * s + 0.0, -0.93, 0.38)), scale=(0.02, 0.012, 0.024),
         mat=M_HILITE, segments=16, ring_count=8)
    prim("sphere", "EyeHL2", mw @ Vector((0.28 * s, -0.95, -0.22)), scale=(0.009, 0.006, 0.009),
         mat=M_HILITE, segments=12, ring_count=6)
    # upper lash line (thick dark arc over the top of the eye with an outer flick)
    lash = []
    for a in np.linspace(math.radians(8), math.radians(172), 18):
        p = Vector((math.cos(a) * 1.04, -0.55, math.sin(a) * 1.04 - 0.02))
        lash.append(mw @ p)
    outer = lash[0] if s > 0 else lash[-1]
    flick = outer + Vector((s * 0.05, 0.01, 0.035))
    if s > 0:
        lash = [flick] + lash
    else:
        lash = lash + [flick]
    taper = np.interp(np.linspace(0, 1, len(lash)), [0, 0.15, 0.5, 0.85, 1], [0.2, 0.9, 1.0, 0.8, 0.3])
    if s < 0:
        taper = taper[::-1]
    curve_tube(f"Lash_{s}", lash, 0.012, M_LASH, taper=list(taper))
    # brow tuft (cream) – small arc above eye
    brow = [mw @ Vector((x, -0.5, 1.45 + 0.15 * (1 - x * x))) for x in np.linspace(-0.6, 0.6, 7)]
    curve_tube(f"Brow_{s}", brow, 0.014, M_LASH, taper=[0.3, 0.8, 1, 1, 0.9, 0.6, 0.2])

# nose
hit, n = ray_surface((0, 0, 1.385), (0, -1, 0))
nose = prim("sphere", "Nose", hit + Vector((0, -0.005, 0.0)), scale=(0.052, 0.04, 0.032), mat=M_NOSE)
nose.rotation_euler = (math.radians(-15), 0, 0)
# philtrum
curve_tube("Philtrum", [hit + Vector((0, -0.01, -0.03)), hit + Vector((0, -0.015, -0.06)),
                        hit + Vector((0, -0.012, -0.085))], 0.006, M_LASH)
# mouth: tongue + fangs inside cavity
prim("sphere", "Tongue", Vector(MOUTH_C) + Vector((0, 0.075, -0.012)), scale=(0.05, 0.045, 0.018), mat=M_TONGUE)
for s in (1, -1):
    prim("cone", "Fang", Vector(MOUTH_C) + Vector((s * 0.05, -0.01, 0.022)), scale=(0.014, 0.014, 0.026),
         rot=(180, 0, 0), mat=M_TOOTH, vertices=16, depth=1.0, radius1=1.0, radius2=0.0)
# whiskers
for s in (1, -1):
    for k, (dz, ang) in enumerate(((0.03, 8), (0.0, -2), (-0.03, -12))):
        start = Vector((s * 0.15, -0.44, 1.325 + dz))
        pts = [start + Vector((s * math.cos(math.radians(ang)) * r, 0.04 * r * r, math.sin(math.radians(ang)) * r
                               - 0.04 * r * r)) for r in np.linspace(0, 0.28, 6)]
        curve_tube("Whisker", pts, 0.0028, M_WHISK, taper=[1, 0.9, 0.7, 0.5, 0.3, 0.1], res=2)

# ============================================================================= 5. accessories
# --- goggle strap around head
pts, outs, nrm = ring_points((0, 0.06, 1.56), (0, 0.42, 0.91), count=90, offset=0.03)
band_mesh("GoggleStrap", pts, outs, nrm, 0.06, 0.018, M_LEATHER)
# --- goggles on forehead
for s in (1, -1):
    d = Vector((s * 0.36, -1.0, 0.62)).normalized()
    hit, n = ray_surface((0, 0.02, 1.48), d)
    base = hit + n * 0.05
    rot = look_rot(n * -1 + Vector((0, 0, 0)))
    face_dir = (n + Vector((0, -0.25, 0.1))).normalized()
    q = face_dir.to_track_quat("Z", "Y")
    rim = prim("torus", "GoggleRim", base, mat=M_BRASS, major_radius=0.105, minor_radius=0.03)
    rim.rotation_mode = "QUATERNION"
    rim.rotation_quaternion = q
    cup = prim("cyl", "GoggleCup", base - face_dir * 0.03, mat=M_BRASS, radius=0.1, depth=0.06)
    cup.rotation_mode = "QUATERNION"
    cup.rotation_quaternion = q
    lens = prim("sphere", "GoggleLens", base + face_dir * 0.004, scale=(0.088, 0.088, 0.03), mat=M_GLASS)
    lens.rotation_mode = "QUATERNION"
    lens.rotation_quaternion = q
    # rivets
    for a in np.linspace(0, 2 * math.pi, 8, endpoint=False):
        lp = Vector((math.cos(a) * 0.105, math.sin(a) * 0.105, 0.03))
        prim("sphere", "Rivet", base + q @ lp, scale=(0.011, 0.011, 0.011), mat=M_BRASS, segments=10, ring_count=6)
bridge_l = ray_surface((0, 0.02, 1.48), Vector((0.12, -1.0, 0.62)).normalized())[0]
bridge_r = ray_surface((0, 0.02, 1.48), Vector((-0.12, -1.0, 0.62)).normalized())[0]
mid = ray_surface((0, 0.02, 1.48), Vector((0, -1.0, 0.62)).normalized())[0]
curve_tube("GoggleBridge", [bridge_l + Vector((0, -0.05, 0)), mid + Vector((0, -0.06, 0.01)),
                            bridge_r + Vector((0, -0.05, 0))], 0.018, M_BRASS)

# --- scarf ring + knot + tails
pts, outs, nrm = ring_points((0, 0.0, 1.045), (0, 0.25, 1.0), count=72, offset=0.03)
pts = [p + Vector((0, 0, 0.012 * math.sin(i * 0.7))) for i, p in enumerate(pts)]
band_mesh("Scarf", pts, outs, [ (nrm + o * 0.0).normalized() for o in outs ], 0.12, 0.05, M_RED)
knot_hit = ray_surface((0, 0, 0.99), (0, -1, -0.2))[0]
knot = prim("sphere", "ScarfKnot", knot_hit + Vector((0.0, -0.08, 0.0)), scale=(0.085, 0.065, 0.075), mat=M_RED,
            subdiv=1)


def cloth_strip(name, path, widths, normal_hint, thick=0.022, mat=M_RED):
    """flat cloth strip following a path (list of Vectors) with widths; folded slightly"""
    bm = bmesh.new()
    rows = []
    for i, p in enumerate(path):
        t = (path[min(i + 1, len(path) - 1)] - path[max(i - 1, 0)]).normalized()
        side = t.cross(Vector(normal_hint)).normalized()
        w = widths[i]
        nn = side.cross(t).normalized()
        row = []
        for j, f in enumerate(np.linspace(-1, 1, 5)):
            sag = (1 - f * f) * 0.015 * math.sin(i * 1.3)
            row.append(p + side * f * w + nn * sag)
        rows.append([bm.verts.new(x) for x in row])
    for i in range(len(rows) - 1):
        for j in range(4):
            bm.faces.new([rows[i][j], rows[i][j + 1], rows[i + 1][j + 1], rows[i + 1][j]])
    me_ = bpy.data.meshes.new(name)
    bm.to_mesh(me_)
    bm.free()
    for p in me_.polygons:
        p.use_smooth = True
    ob = link(bpy.data.objects.new(name, me_))
    me_.materials.append(mat)
    so = ob.modifiers.new("solid", "SOLIDIFY")
    so.thickness = thick
    so.offset = 0
    sd = ob.modifiers.new("sub", "SUBSURF")
    sd.levels = sd.render_levels = 2
    return ob


k0 = knot.location
for s in (1, -1):
    path = [k0 + Vector((s * 0.02, -0.01, -0.02)), k0 + Vector((s * 0.07, -0.04, -0.10)),
            k0 + Vector((s * 0.10, -0.04, -0.19)), k0 + Vector((s * 0.12, -0.02, -0.27))]
    cloth_strip("ScarfTail", path, [0.03, 0.05, 0.06, 0.035], (0, -1, 0))

# --- cape over the back (conformed to body, offset over fur)
cape_rows = []
for z in np.linspace(1.04, 0.52, 9):
    t = (1.04 - z) / 0.52
    span = 0.75 + 0.55 * t
    row = []
    for a in np.linspace(-span, span, 13):
        d = Vector((math.sin(a), math.cos(a), 0.05))
        hit = ray_surface((0, 0.0, z), d)[0]
        if hit is None:
            hit = Vector((0, 0, z)) + d * 0.3
        off = 0.06 + 0.07 * t + 0.015 * math.sin(a * 5 + t * 3) * t
        row.append(hit + d.normalized() * off)
    cape_rows.append(row)
bm = bmesh.new()
grid = [[bm.verts.new(p) for p in r] for r in cape_rows]
for i in range(len(grid) - 1):
    for j in range(len(grid[0]) - 1):
        bm.faces.new([grid[i][j], grid[i][j + 1], grid[i + 1][j + 1], grid[i + 1][j]])
cme = bpy.data.meshes.new("Cape")
bm.to_mesh(cme)
bm.free()
for p in cme.polygons:
    p.use_smooth = True
cape = link(bpy.data.objects.new("Cape", cme))
cme.materials.append(M_RED)
so = cape.modifiers.new("solid", "SOLIDIFY"); so.thickness = 0.02
sd = cape.modifiers.new("sub", "SUBSURF"); sd.levels = sd.render_levels = 2

# --- belt
pts, outs, nrm = ring_points((0, 0.02, 0.555), (0, 0.08, 1.0), count=80, offset=0.03)
band_mesh("Belt", pts, outs, nrm, 0.055, 0.02, M_LEATHER_D)
bk = ray_surface((0, 0.0, 0.555), (0, -1, 0))[0]
prim("cube", "Buckle", bk + Vector((0, -0.045, 0)), scale=(0.045, 0.012, 0.035), mat=M_BRASS, subdiv=2)

# --- compass pendant under the scarf knot
mh, mn = ray_surface((0, 0.0, 0.86), Vector((0.0, -1.0, 0.0)).normalized())
med_q = (mn + Vector((0, -0.2, 0.1))).normalized().to_track_quat("Z", "Y")
med = prim("cyl", "Medallion", mh + mn * 0.06, mat=M_BRASS, radius=0.06, depth=0.025)
med.rotation_mode = "QUATERNION"; med.rotation_quaternion = med_q
mf = prim("cyl", "MedallionFace", mh + mn * 0.075, mat=M_GEM, radius=0.042, depth=0.01)
mf.rotation_mode = "QUATERNION"; mf.rotation_quaternion = med_q
mr = prim("torus", "MedallionRim", mh + mn * 0.074, mat=M_BRASS, major_radius=0.06, minor_radius=0.012)
mr.rotation_mode = "QUATERNION"; mr.rotation_quaternion = med_q

# --- bracers
for s in (1, -1):
    a = Vector((s * 0.27, -0.01, 0.96))
    b = Vector((s * 0.40, -0.11, 0.64))
    c = a.lerp(b, 0.68)
    pts, outs, nrm = ring_points(c, b - a, count=40, offset=0.025, max_dist=0.14)
    band_mesh("Bracer", pts, outs, nrm, 0.07, 0.02, M_LEATHER)
    gh, gn = ray_surface(c, Vector((s * 1.0, -0.6, 0.0)).normalized())
    gem = prim("ico", "BracerGem", gh + gn * 0.05, scale=(0.026, 0.026, 0.026), mat=M_GEM, subdivisions=1,
               smooth=False)

# --- backpack + scroll map
bp_hit = ray_surface((0, 0, 0.84), (0, 1, 0))[0]
bp_c = bp_hit + Vector((0, 0.13, 0.0))
pack = prim("cube", "Backpack", bp_c, scale=(0.20, 0.11, 0.22), mat=M_LEATHER, subdiv=0)
bev = pack.modifiers.new("bevel", "BEVEL"); bev.width = 0.05; bev.segments = 4
sub = pack.modifiers.new("sub", "SUBSURF"); sub.levels = sub.render_levels = 1
flap = prim("cube", "BackpackFlap", bp_c + Vector((0, 0.10, 0.10)), scale=(0.205, 0.025, 0.13), mat=M_LEATHER_D)
bev = flap.modifiers.new("bevel", "BEVEL"); bev.width = 0.02; bev.segments = 3
prim("cube", "PackBuckle", bp_c + Vector((0, 0.13, 0.0)), scale=(0.03, 0.01, 0.03), mat=M_BRASS, subdiv=2)
scroll = prim("cyl", "MapScroll", bp_c + Vector((0, 0.0, 0.29)), rot=(0, 90, 0), mat=M_PAPER, radius=0.075,
              depth=0.62)
for s in (1, -1):
    prim("torus", "ScrollTie", bp_c + Vector((s * 0.16, 0, 0.29)), rot=(0, 90, 0), mat=M_RED,
         major_radius=0.078, minor_radius=0.012)
    prim("cyl", "ScrollCap", bp_c + Vector((s * 0.315, 0, 0.29)), rot=(0, 90, 0), mat=M_LEATHER_D, radius=0.05,
         depth=0.02)

# --- lantern hanging from the belt (character's left = +X)
lh = ray_surface((0, 0.02, 0.53), Vector((1.0, 0.25, 0)).normalized())[0]
lc = lh + Vector((0.07, 0.03, -0.13))
prim("cyl", "LanternTop", lc + Vector((0, 0, 0.075)), mat=M_BRASS, radius=0.05, depth=0.025)
prim("cone", "LanternRoof", lc + Vector((0, 0, 0.105)), mat=M_BRASS, radius1=0.05, radius2=0.012, depth=0.04,
     vertices=24)
prim("cyl", "LanternBase", lc + Vector((0, 0, -0.075)), mat=M_BRASS, radius=0.05, depth=0.025)
for a in np.linspace(0, 2 * math.pi, 4, endpoint=False):
    prim("cyl", "LanternBar", lc + Vector((math.cos(a) * 0.042, math.sin(a) * 0.042, 0)), mat=M_BRASS,
         radius=0.008, depth=0.15, vertices=8)
prim("sphere", "LanternOrb", lc, scale=(0.035, 0.035, 0.05), mat=M_GLOWORB)
curve_tube("LanternRing", [lh + Vector((0.01, 0.0, -0.01)), lh + Vector((0.05, 0.02, -0.04)),
                           lc + Vector((0, 0, 0.12))], 0.008, M_BRASS)
ll = bpy.data.lights.new("LanternLight", "POINT")
ll.color = srgb("#5FF0FF")
ll.energy = 6
ll.shadow_soft_size = 0.03
lo = link(bpy.data.objects.new("LanternLight", ll))
lo.location = lc

# ============================================================================= fur last (needs final colors)
fur = build_fur(args.fur)
fur.data.materials.append(fur_material())

# parent everything to an empty for easy handling
root = link(bpy.data.objects.new("Orion", None))
for ob in list(COL.objects):
    if ob is not root and ob.parent is None and ob.type != "LIGHT" or ob.name == "LanternLight":
        if ob is not root:
            ob.parent = root


# ============================================================================= 6. stage, lights, camera
def world_gradient():
    w = bpy.data.worlds.new("World")
    scene.world = w
    w.use_nodes = True
    nt = w.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputWorld")
    bg = nt.nodes.new("ShaderNodeBackground")
    lp = nt.nodes.new("ShaderNodeLightPath")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Generated"], sep.inputs[0])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    nt.links.new(sep.outputs[2], ramp.inputs[0])
    ramp.color_ramp.elements[0].position = 0.35
    ramp.color_ramp.elements[0].color = (*srgb("#0B1640"), 1)
    ramp.color_ramp.elements[1].position = 0.75
    ramp.color_ramp.elements[1].color = (*srgb("#4A6FD8"), 1)
    # camera sees a flat studio gradient; lighting uses a soft sky
    cam_bg = nt.nodes.new("ShaderNodeTexCoord")
    sep2 = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(cam_bg.outputs["Window"], sep2.inputs[0])
    ramp2 = nt.nodes.new("ShaderNodeValToRGB")
    nt.links.new(sep2.outputs[1], ramp2.inputs[0])
    ramp2.color_ramp.elements[0].color = (*srgb("#0E1A52"), 1)
    ramp2.color_ramp.elements[1].color = (*srgb("#22357E"), 1)
    mix = nt.nodes.new("ShaderNodeMix"); mix.data_type = "RGBA"
    nt.links.new(lp.outputs["Is Camera Ray"], mix.inputs["Factor"])
    nt.links.new(ramp.outputs[0], mix.inputs[6])
    nt.links.new(ramp2.outputs[0], mix.inputs[7])
    nt.links.new(mix.outputs[2], bg.inputs[0])
    bg.inputs[1].default_value = 0.6
    nt.links.new(bg.outputs[0], out.inputs[0])


def area_light(name, loc, target, power, color, size):
    L = bpy.data.lights.new(name, "AREA")
    L.energy = power
    L.color = color
    L.size = size
    o = link(bpy.data.objects.new(name, L))
    o.location = loc
    d = Vector(target) - Vector(loc)
    o.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    return o


world_gradient()
area_light("Key", (-2.6, -3.4, 3.6), (0, 0, 1.2), 650, srgb("#FFE2B8"), 2.5)
area_light("Fill", (3.2, -2.6, 1.4), (0, 0, 1.0), 150, srgb("#BFD4FF"), 3.0)
area_light("RimL", (-2.4, 2.8, 2.6), (0, 0, 1.2), 650, srgb("#9FC4FF"), 1.5)
area_light("RimR", (2.6, 2.6, 2.2), (0, 0, 1.1), 550, srgb("#B4AEFF"), 1.5)
area_light("Top", (0, 0.5, 5.0), (0, 0, 1.0), 250, srgb("#FFF4E6"), 2.0)

# pedestal like the turntable sheet
M_PED = simple_mat("Pedestal", "#3550C8", rough=0.35, coat=0.5)
M_PEDRIM = simple_mat("PedestalRim", "#7FD6FF", rough=0.3, emit="#5FC8FF", emit_str=2.5)
prim("cyl", "Pedestal", (0, -0.02, -0.04), mat=M_PED, radius=0.95, depth=0.08, vertices=96)
prim("torus", "PedestalRim", (0, -0.02, -0.004), mat=M_PEDRIM, major_radius=0.95, minor_radius=0.012,
     major_segments=128)

cam_data = bpy.data.cameras.new("Cam")
cam_data.lens = 70
cam = link(bpy.data.objects.new("Cam", cam_data))
scene.camera = cam


def place_camera(angle_deg, dist=5.9, height=1.75, target=(0, 0.05, 1.08)):
    a = math.radians(angle_deg)
    cam.location = (math.sin(a) * dist, -math.cos(a) * dist, height)
    d = Vector(target) - cam.location
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()


# ----------------------------------------------------------------------------- render settings
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = args.samples
scene.cycles.use_denoising = True
scene.cycles.max_bounces = 6
scene.cycles.transparent_max_bounces = 16
scene.render.resolution_x = args.size
scene.render.resolution_y = int(args.size * 1.15)
scene.render.film_transparent = False
try:
    scene.view_settings.view_transform = "Khronos PBR Neutral"
except TypeError:
    pass
scene.view_settings.exposure = 0.0


def bloom(path):
    from PIL import Image, ImageFilter
    im = Image.open(path).convert("RGB")
    a = np.asarray(im).astype(np.float32) / 255
    lum = a @ np.array([0.2126, 0.7152, 0.0722])
    bright = a * smoothstep(0.72, 1.0, lum)[..., None]
    acc = np.zeros_like(a)
    bimg = Image.fromarray((bright * 255).astype(np.uint8))
    for r, wgt in ((4, 0.5), (12, 0.45), (32, 0.35)):
        acc += np.asarray(bimg.filter(ImageFilter.GaussianBlur(r))).astype(np.float32) / 255 * wgt
    out = 1 - (1 - a) * (1 - np.clip(acc, 0, 1))  # screen blend
    Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8)).save(path)


def render(name, angle, **kw):
    place_camera(angle, **kw)
    path = os.path.join(args.out, f"{name}.png")
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    bloom(path)
    print("[render]", path)
    return path


views = [v for v in args.render.split(",") if v]
if "hero" in views:
    render("orion_hero", -28)
if "face" in views:
    render("orion_face", -18, dist=4.2, height=1.6, target=(0, -0.1, 1.45))
if "turn" in views:
    for i, ang in enumerate((0, 90, 180, 270)):
        render(f"orion_turn_{i}", ang)

# ----------------------------------------------------------------------------- save
if not args.no_blend:
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(args.out, "orion.blend"), compress=True)
    print("[save] orion.blend")
if not args.no_glb:
    fur.hide_render = True
    for ob in scene.objects:
        ob.select_set(ob.type == "MESH" and not ob.name.startswith("Pedestal") or ob.type == "CURVE")
    dec = body.modifiers.new("dec", "DECIMATE")
    dec.ratio = 0.12
    bpy.ops.export_scene.gltf(filepath=os.path.join(args.out, "orion_game.glb"), use_selection=True,
                              export_apply=True, export_yup=True)
    body.modifiers.remove(dec)
    print("[save] orion_game.glb")
