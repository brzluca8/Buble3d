"""
Orion – mascota Buble, construită procedural în Blender (Cycles) după planșa de personaj
(față / 3/4 / profil / spate, expresii, accesorii, paletă).

Rulare (Blender 5.1 ca modul Python, cu scikit-image și pillow instalate):
    python orion_build.py --out out --render sheet,face,hero
Test rapid:
    python orion_build.py --res 0.012 --fur 60000 --samples 24 --size 600 --render sheet --no-blend --no-glb
Expresii (prim-plan pe față):  --expr happy|surprised|laugh|determined|angry|wink --render face

Pași:
  1. Corpul este un câmp SDF (elipsoizi, conuri rotunjite, urechi în formă de frunză, coadă în spirală)
     transformat în mesh cu marching cubes.
  2. Culorile sunt pictate pe vârfuri: portocaliu-auriu, crem (bot, obraji, piept, labe), pete maro,
     marcaje pe frunte, mov pe urechi și în interiorul cozii, roz în urechi, marcaje turcoaz care strălucesc.
  3. Accesoriile: ochelari de aviator cu lentile luminoase și curele pe cap, eșarfă roșie, medalion-busolă,
     vestă de piele cu nituri, centură cu cataramă, curea peste piept, brățări cu cristale,
     rucsac mov cu hartă rulată și felinar.
  4. Blana (Hair Curves) are lungime, direcție și smocuri pe zone. Urechile au smocuri mov,
     în interiorul urechilor e puf crem, pe obraji e un guler de blană. Sub haine blana se elimină automat.
  5. Randarea se face pe fundal alb, cu umbră, iar luminile se rotesc odată cu camera.
     Rezultă planșa „Față / 3/4 / Profil / Spate”, un prim-plan pe față și o vedere 3/4.
  6. Se salvează orion.blend și orion_game.glb (1,2 m, fără blană).
"""
import argparse
import math
import os
import sys
import time

import bpy
import bmesh
import numpy as np
from mathutils import Vector, Matrix, Euler
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree

T0 = time.time()
HERE = os.path.dirname(os.path.abspath(__file__))
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
ap = argparse.ArgumentParser()
ap.add_argument("--out", default=os.path.join(HERE, "out"))
ap.add_argument("--res", type=float, default=0.0075)
ap.add_argument("--fur", type=int, default=420000)
ap.add_argument("--render", default="sheet,face,hero")
ap.add_argument("--samples", type=int, default=112)
ap.add_argument("--size", type=int, default=1300, help="latura unei vederi din planșă (px)")
ap.add_argument("--seed", type=int, default=7)
ap.add_argument("--expr", default="happy")
ap.add_argument("--stage", default="full", choices=["body", "props", "full"])
ap.add_argument("--tag", default="", help="sufix pentru numele fișierelor randate")
ap.add_argument("--light", type=float, default=0.6)
ap.add_argument("--view", default="Khronos PBR Neutral")
ap.add_argument("--look", default="")
ap.add_argument("--no-blend", action="store_true")
ap.add_argument("--no-glb", action="store_true")
args = ap.parse_args(argv)
os.makedirs(args.out, exist_ok=True)
rng = np.random.default_rng(args.seed)
DO_PROPS = args.stage in ("props", "full")
DO_FUR = args.stage == "full"


def log(*a):
    print(f"[{time.time() - T0:7.1f}s]", *a, flush=True)


bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
COL = scene.collection


def srgb(h):
    """hex sRGB -> linear rgb tuple"""
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


def lin(h):
    return np.array(srgb(h))


def link(obj):
    COL.objects.link(obj)
    return obj


def nrm(v):
    v = np.asarray(v, np.float64)
    return v / np.linalg.norm(v)


def norm(v):
    return np.sqrt(np.sum(v * v, axis=-1))


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def mix(a, b, t):
    t = np.asarray(t)[..., None] if np.ndim(t) else t
    return a * (1 - t) + b * t


# ----------------------------------------------------------------------------- expressions
# lid: height of the upper-lid cut on the unit eye (1 = wide open, "arc" = closed happy eye)
# low: lower-lid cut (-1 = none); tilt: lid tilt (deg, + = inner corner down -> angry)
EXPRS = {
    "happy": dict(mouth="smile", lid=(None, None), low=(-1, -1), tilt=0, brow=None, pupil=1.0),
    "surprised": dict(mouth="o", lid=(None, None), low=(-1, -1), tilt=-6, brow="up", pupil=0.78),
    "laugh": dict(mouth="grin", lid=("arc", "arc"), low=(-1, -1), tilt=0, brow=None, pupil=1.0),
    "determined": dict(mouth="closed", lid=(0.42, 0.42), low=(-0.62, -0.62), tilt=16, brow="angry",
                       pupil=1.0),
    "angry": dict(mouth="snarl", lid=(0.5, 0.5), low=(-0.66, -0.66), tilt=24, brow="angry", pupil=0.9),
    "wink": dict(mouth="smirk", lid=("arc", None), low=(-1, -1), tilt=0, brow=None, pupil=1.0),
}
EX = EXPRS[args.expr]


# ============================================================================= 1. SDF body
def rot_matrix(euler_deg):
    return np.array(Euler([math.radians(a) for a in euler_deg]).to_matrix(), dtype=np.float32)


def sd_ellipsoid(P, c, r, R=None):
    q = P - c
    if R is not None:
        q = q @ R
    k0 = norm(q / r)
    k1 = norm(q / (r * r))
    return k0 * (k0 - 1.0) / np.maximum(k1, 1e-6)


def sd_round_cone(P, a, b, r1, r2):
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


def smin(a, b, k):
    if k <= 0:
        return np.minimum(a, b)
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0, 1)
    return b + (a - b) * h - k * h * (1 - h)


def smax(a, b, k):
    return -smin(-a, -b, k)


PRIMS = []


def ell(c, r, rot=None):
    c = np.asarray(c, np.float32)
    r = np.asarray(r, np.float32)
    R = rot_matrix(rot) if rot is not None else None
    m = float(r.max())
    return (lambda P: sd_ellipsoid(P, c, r, R)), c - m, c + m


def cone(a, b, r1, r2):
    a = np.asarray(a, np.float32)
    b = np.asarray(b, np.float32)
    m = max(r1, r2)
    return (lambda P: sd_round_cone(P, a, b, r1, r2)), np.minimum(a, b) - m, np.maximum(a, b) + m


def add(name, region, shape, k=0.05, op="add"):
    fn, lo, hi = shape
    pad = k + 0.04
    PRIMS.append(dict(name=name, region=region, fn=fn, k=k, op=op,
                      lo=np.asarray(lo, np.float32) - pad, hi=np.asarray(hi, np.float32) + pad))


def mirror(builder, name, region, k=0.05, op="add"):
    for s, side in ((1, "L"), (-1, "R")):
        add(f"{name}_{side}", region, builder(s), k, op)


# --- head: round cranium, wide face, cheek ruff, small muzzle (chibi, ~1/3 of the height)
HEAD_C = np.array([0.0, 0.04, 1.79])
add("cranium", "head", ell((0, 0.05, 1.79), (0.41, 0.37, 0.29)), 0.0)
add("face", "head", ell((0, -0.07, 1.62), (0.40, 0.33, 0.27)), 0.12)
mirror(lambda s: ell((s * 0.25, -0.12, 1.51), (0.21, 0.19, 0.15), rot=(0, s * 25, 0)), "cheek", "cheek", 0.10)
add("muzzle", "muzzle", ell((0, -0.385, 1.53), (0.145, 0.095, 0.09)), 0.06)
mirror(lambda s: ell((s * 0.078, -0.43, 1.515), (0.088, 0.072, 0.064)), "puff", "muzzle", 0.04)
add("chin", "chin", ell((0, -0.32, 1.39), (0.115, 0.09, 0.068)), 0.06)

# --- ears: big leaf-shaped lynx ears, cupped, with a hollow front
EAR_B = np.array([0.30, 0.07, 1.90])
EAR_U = np.array([0.36, 0.05, 1.0])
EAR_F = np.array([0.9, -1.0, 0.1])
EAR_R, EAR_D = 0.53, 0.32
EAR_LEN = math.sqrt(EAR_R ** 2 - EAR_D ** 2)


def ear_frame(s):
    B = EAR_B * [s, 1, 1]
    U = nrm(EAR_U * [s, 1, 1])
    F = nrm(EAR_F * [s, 1, 1])
    F = nrm(F - U * (F @ U))
    W = s * np.cross(U, F)  # outward
    return B, U, F, W


def ear_local(P, s):
    B, U, F, W = ear_frame(s)
    q = np.asarray(P, np.float64) - B
    return q @ W, q @ U, q @ F


def ear_shape(w, h):
    leaf = np.maximum(np.sqrt((w - EAR_D) ** 2 + h ** 2) - EAR_R, np.sqrt((w + EAR_D) ** 2 + h ** 2) - EAR_R)
    hn = np.clip((h + 0.1) / (EAR_LEN + 0.1), 0, 1)
    t = 0.085 * (1 - hn) + 0.026 * hn
    bend = 0.55 * w * w - 0.30 * np.clip(h, 0, None) ** 2
    return leaf, t, bend


def ear_sdf(s):
    def f(P):
        w, h, c = ear_local(P, s)
        leaf, t, bend = ear_shape(w, h)
        d = smax(leaf, np.abs(c - bend) - t / 2, 0.015)
        cav = np.maximum(leaf + 0.055, (bend - t / 2 + 0.022) - c)
        d = smax(d, -cav, 0.02)
        d = np.maximum(d, -(h + 0.30))
        return d.astype(np.float32)

    B, U, F, W = ear_frame(s)
    corners = np.array([B + W * a + U * b + F * c for a in (-0.32, 0.32) for b in (-0.32, EAR_LEN + 0.04)
                        for c in (-0.2, 0.2)])
    return f, corners.min(0), corners.max(0)


mirror(ear_sdf, "ear", "ear", 0.06)

# --- torso
add("neck", "neck", ell((0, 0.02, 1.30), (0.19, 0.17, 0.12)), 0.08)
add("chest", "chest", ell((0, 0.01, 1.08), (0.27, 0.21, 0.22)), 0.10)
add("belly", "belly", ell((0, -0.02, 0.83), (0.29, 0.24, 0.24)), 0.10)
add("hips", "hips", ell((0, 0.04, 0.61), (0.28, 0.23, 0.16)), 0.10)


# --- arms with fists
def SH(s): return np.array([s * 0.27, 0.02, 1.14])
def EL(s): return np.array([s * 0.40, 0.0, 0.92])
def WR(s): return np.array([s * 0.47, -0.06, 0.745])
def FIST(s): return np.array([s * 0.485, -0.085, 0.655])


mirror(lambda s: cone(SH(s), EL(s), 0.118, 0.104), "uparm", "arm", 0.06)
mirror(lambda s: cone(EL(s), WR(s), 0.104, 0.094), "forearm", "arm", 0.03)
mirror(lambda s: ell(FIST(s), (0.122, 0.124, 0.118)), "fist", "paw", 0.04)
for _s, _side in ((1, "L"), (-1, "R")):
    _c = FIST(_s)
    for _i, _dx in enumerate((-0.06, -0.02, 0.02, 0.06)):
        add(f"finger{_i}_{_side}", "paw", ell(_c + [_s * _dx * 1.15, -0.098, -0.045], (0.04, 0.04, 0.041)), 0.025)
    add(f"thumb_{_side}", "paw", ell(_c + [-_s * 0.088, -0.062, 0.04], (0.038, 0.045, 0.038)), 0.025)


# --- legs with big round paws
def HIP(s): return np.array([s * 0.165, 0.03, 0.56])
def KNEE(s): return np.array([s * 0.205, -0.02, 0.33])
def ANK(s): return np.array([s * 0.235, 0.0, 0.16])
def FOOT(s): return np.array([s * 0.27, -0.085, 0.098])


FOOT_ROT = 18
mirror(lambda s: cone(HIP(s), KNEE(s), 0.175, 0.148), "thigh", "leg", 0.08)
mirror(lambda s: cone(KNEE(s), ANK(s), 0.148, 0.13), "shin", "leg", 0.05)
mirror(lambda s: ell(FOOT(s), (0.205, 0.235, 0.115), rot=(0, 0, s * FOOT_ROT)), "foot", "foot", 0.05)


def foot_local(s, v):
    R = np.array(Euler((0, 0, math.radians(s * FOOT_ROT))).to_matrix())
    return FOOT(s) + R @ np.asarray(v)


for _s, _side in ((1, "L"), (-1, "R")):
    for _i, _dx in enumerate((-0.122, -0.041, 0.041, 0.122)):
        add(f"toe{_i}_{_side}", "foot", ell(foot_local(_s, (_dx, -0.2, -0.035)), (0.066, 0.064, 0.058)), 0.03)

# --- tail: thick curl (fiddlehead) behind, to the character's right (image left in front view)
TAIL_C = np.array([-0.68, 0.58, 0.56])
TAIL_U = nrm([-0.78, 0.62, 0.0])
TAIL_V = np.array([0.0, 0.0, 1.0])
TAIL_N = np.cross(TAIL_U, TAIL_V)
TAIL_PHI = 1.75 * np.pi
TAIL_SU = 1.0


def tail_spiral(phi):
    phi = np.asarray(phi, np.float64)
    rho = 0.26 + (0.06 - 0.26) * (phi / TAIL_PHI)
    return TAIL_C + rho[:, None] * (TAIL_SU * np.sin(phi)[:, None] * TAIL_U - np.cos(phi)[:, None] * TAIL_V)


def bezier3(p0, p1, p2, p3, t):
    t = np.asarray(t)[:, None]
    return (1 - t) ** 3 * p0 + 3 * (1 - t) ** 2 * t * p1 + 3 * (1 - t) * t ** 2 * p2 + t ** 3 * p3


_TS = tail_spiral([0.0])[0]
_TR0 = np.array([-0.04, 0.22, 0.50])
_root = bezier3(_TR0, _TR0 + [0, 0.16, -0.10], _TS - 0.22 * TAIL_U, _TS, np.linspace(0, 1, 7))
_phi = np.linspace(0, TAIL_PHI, 26)
TAIL_P = np.concatenate([_root[:-1], tail_spiral(_phi)], 0).astype(np.float32)
TAIL_R = np.concatenate([np.linspace(0.085, 0.12, 7)[:-1],
                         np.interp(_phi, [0, 0.5 * np.pi, np.pi, 1.5 * np.pi, TAIL_PHI],
                                   [0.12, 0.14, 0.125, 0.09, 0.04])])
TAIL_PHIS = np.concatenate([np.full(6, -1.0), _phi])
for _i in range(len(TAIL_P) - 1):
    add(f"tail{_i}", "tail", cone(TAIL_P[_i], TAIL_P[_i + 1], float(TAIL_R[_i]), float(TAIL_R[_i + 1])),
        0.09 if _i == 0 else 0.03)

# --- subtractions: eye sockets and the mouth
EYE_X, EYE_Z = 0.172, 1.665
EYE_C = {s: np.array([s * EYE_X, -0.345, EYE_Z]) for s in (1, -1)}
EYE_S = np.array([0.114, 0.066, 0.104])
mirror(lambda s: ell((s * EYE_X, -0.42, EYE_Z), (0.122, 0.075, 0.112)), "socket", "head", 0.03, op="sub")
MOUTH_C = np.array([0.0, -0.43, 1.44])


def mouth_shape(kind):
    if kind in ("smile", "grin"):
        big = kind == "grin"
        c = MOUTH_C + [0, 0, -0.016 if big else -0.008]
        r = np.array((0.2, 0.135, 0.095) if big else (0.19, 0.13, 0.08), np.float32)
        top = 1.462 if big else 1.457
        bend = 2.0

        def f(P):
            Q = P.copy()
            Q[:, 2] = P[:, 2] - bend * P[:, 0] ** 2  # smile: corners curve upward
            lip = top + 0.02 * np.exp(-(P[:, 0] / 0.035) ** 2)
            return np.maximum(sd_ellipsoid(Q, c, r), Q[:, 2] - lip)
        m = float(r.max()) + 0.06
        return f, c - m, c + m
    if kind == "o":
        return ell(MOUTH_C + [0, 0, -0.012], (0.055, 0.09, 0.064))
    if kind == "snarl":
        e, lo, hi = ell(MOUTH_C + [0, 0, -0.004], (0.13, 0.10, 0.066))
        return (lambda P: np.maximum(e(P), P[:, 2] - 1.48)), lo, hi
    return None


MOUTH = mouth_shape(EX["mouth"])
if MOUTH:
    add("mouth", "mouth", MOUTH, 0.015, op="sub")


def subset_sdf(names):
    sel = [p for p in PRIMS if p["name"] in names]

    def f(P):
        P = np.asarray(P, np.float32)
        d = None
        for p in sel:
            di = p["fn"](P)
            d = di if d is None else smin(d, di, p["k"])
        return d
    return f


TORSO_SDF = subset_sdf({"neck", "chest", "belly", "hips"})
HEAD_SDF = subset_sdf({"cranium", "face"})


def body_volume(h):
    lo = np.array([-1.30, -0.72, -0.02], np.float32)
    hi = np.array([0.86, 1.16, 2.50], np.float32)
    n = np.ceil((hi - lo) / h).astype(int) + 1
    axes = [lo[i] + np.arange(n[i], dtype=np.float32) * h for i in range(3)]
    vol = np.full(tuple(n), 10.0, np.float32)
    for p in PRIMS:
        i0 = np.clip(np.floor((p["lo"] - lo) / h).astype(int), 0, n)
        i1 = np.clip(np.ceil((p["hi"] - lo) / h).astype(int) + 1, 0, n)
        if np.any(i1 <= i0):
            continue
        X, Y, Z = np.meshgrid(axes[0][i0[0]:i1[0]], axes[1][i0[1]:i1[1]], axes[2][i0[2]:i1[2]], indexing="ij")
        P = np.stack([X.ravel(), Y.ravel(), Z.ravel()], 1)
        sub = vol[i0[0]:i1[0], i0[1]:i1[1], i0[2]:i1[2]]
        di = np.asarray(p["fn"](P), np.float32).reshape(sub.shape)
        if p["op"] == "add":
            sub[...] = smin(sub, di, p["k"])
        else:
            sub[...] = smax(sub, -di, p["k"])
    vol = np.maximum(vol, -axes[2][None, None, :])  # flat soles
    return vol, lo, n


def build_body():
    from skimage.measure import marching_cubes
    h = args.res
    vol, lo, n = body_volume(h)
    verts, faces, _, _ = marching_cubes(vol, 0.0, spacing=(h, h, h))
    verts = verts + lo
    log(f"[body] grid {n.tolist()} -> {len(verts)} verts")
    me_ = bpy.data.meshes.new("OrionBody")
    me_.vertices.add(len(verts))
    me_.vertices.foreach_set("co", verts.astype(np.float32).ravel())
    me_.loops.add(len(faces) * 3)
    me_.loops.foreach_set("vertex_index", faces.astype(np.int32).ravel())
    me_.polygons.add(len(faces))
    me_.polygons.foreach_set("loop_start", np.arange(0, len(faces) * 3, 3, dtype=np.int32))
    me_.update(calc_edges=True)
    me_.validate()
    bm = bmesh.new()
    bm.from_mesh(me_)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=h * 0.05)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me_)
    bm.free()
    ob = link(bpy.data.objects.new("Orion_Body", me_))
    mod = ob.modifiers.new("smooth", "SMOOTH")
    mod.factor = 0.6
    mod.iterations = 4
    dg = bpy.context.evaluated_depsgraph_get()
    me2 = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    ob.modifiers.clear()
    ob.data = me2
    bpy.data.meshes.remove(me_)
    me2.name = "OrionBody"
    for p in me2.polygons:
        p.use_smooth = True
    return ob


body = build_body()
me = body.data
NV = len(me.vertices)
V = np.empty(NV * 3, np.float32)
me.vertices.foreach_get("co", V)
V = V.reshape(-1, 3).astype(np.float64)
N = np.empty(NV * 3, np.float32)
me.vertices.foreach_get("normal", N)
N = N.reshape(-1, 3).astype(np.float64)
BVH = BVHTree.FromObject(body, bpy.context.evaluated_depsgraph_get())


def ray_surface(o, d):
    hit, n, i, dist = BVH.ray_cast(Vector(tuple(o)), Vector(tuple(d)).normalized())
    return hit, n


# region per vertex = closest additive primitive
_names, _regions, _d = [], [], []
for p in PRIMS:
    if p["op"] == "add":
        _names.append(p["name"])
        _regions.append(p["region"])
        _d.append(np.asarray(p["fn"](V.astype(np.float32)), np.float32))
_d = np.stack(_d, 1)
REG = np.array(_regions)[np.argmin(_d, 1)]
del _d


def rmask(*r):
    return np.isin(REG, r)


# --- tail parametrisation (arc length along the centre line)
_seg = np.linalg.norm(np.diff(TAIL_P, axis=0), axis=1)
_cum = np.concatenate([[0], np.cumsum(_seg)])
TAIL_LEN = _cum[-1]


def tail_param(P):
    best = np.full(len(P), 1e9)
    s_out = np.zeros(len(P))
    c_out = np.zeros_like(P)
    t_out = np.zeros_like(P)
    p_out = np.zeros(len(P))
    for i in range(len(TAIL_P) - 1):
        a, b = TAIL_P[i].astype(np.float64), TAIL_P[i + 1].astype(np.float64)
        ab = b - a
        t = np.clip(((P - a) @ ab) / (ab @ ab), 0, 1)
        c = a + t[:, None] * ab
        d = norm(P - c)
        m = d < best
        best[m] = d[m]
        s_out[m] = (_cum[i] + t[m] * _seg[i]) / TAIL_LEN
        c_out[m] = c[m]
        t_out[m] = ab / np.linalg.norm(ab)
        p_out[m] = TAIL_PHIS[i] + t[m] * (TAIL_PHIS[i + 1] - TAIL_PHIS[i])
    return s_out, c_out, t_out, p_out


# ============================================================================= 2. colours
C_FUR = lin("#FDA828")
C_FUR_HI = lin("#FFCB55")
C_FUR_DEEP = lin("#EE820E")
C_CREAM = lin("#FDE8D2")
C_SPOT = lin("#8E3E0E")
C_MARK = lin("#6E260A")
C_PURPLE = lin("#8E2F8E")
C_PURPLE_D = lin("#5C1868")
C_PINK = lin("#F59DA5")
C_MOUTH = lin("#5E101C")
C_GLOW = lin("#1AA4FF")
C_DOT = lin("#C9875A")

col = np.tile(C_FUR, (NV, 1))
lit = smoothstep(0.1, 0.9, N[:, 2]) * 0.55 + smoothstep(-0.1, -0.8, N[:, 1]) * 0.45
col = mix(col, C_FUR_HI, lit * 0.55)
col = mix(col, C_FUR_DEEP, smoothstep(0.1, 0.9, N[:, 1]) * 0.4)

ear = rmask("ear")
EW, EH, EC = np.zeros(NV), np.zeros(NV), np.zeros(NV)
EARF = np.zeros(NV)
EARU = np.zeros((NV, 3))
for _s in (1, -1):
    _m = np.sign(V[:, 0]) == _s
    EW[_m], EH[_m], EC[_m] = ear_local(V[_m], _s)
    _B, _U, _F, _W = ear_frame(_s)
    EARF[_m] = N[_m] @ _F
    EARU[_m] = _U
LEAF, _, _ = ear_shape(EW, EH)
eh = EH / EAR_LEN

# --- cream areas
headish = rmask("head", "cheek", "muzzle", "chin")
ang = np.arctan2(V[:, 0], -(V[:, 1] - 0.03))  # 0 = facing front
zline = 1.607 - 0.11 * smoothstep(0.5, 2.0, np.abs(ang)) + 0.012 * np.sin(np.abs(ang) * 9.0)
cream = headish * smoothstep(zline + 0.015, zline - 0.02, V[:, 2])
cream = np.maximum(cream, rmask("muzzle", "chin").astype(float))
for _s in (1, -1):
    _d = norm((V - EYE_C[_s] - [0, 0, -0.055]) * [1, 1, 1.5])
    cream = np.maximum(cream, 0.55 * smoothstep(0.12, 0.07, _d) * (V[:, 1] < -0.2))
torso = rmask("neck", "chest", "belly", "hips")
half_w = 0.19 - 0.04 * smoothstep(1.0, 1.3, V[:, 2])
cream = np.maximum(cream, torso * smoothstep(half_w + 0.035, half_w - 0.02, np.abs(V[:, 0]))
                   * smoothstep(0.05, -0.25, N[:, 1]))
cream = np.maximum(cream, rmask("leg") * smoothstep(0.17, 0.11, np.abs(V[:, 0])) * smoothstep(0.62, 0.46, V[:, 2])
                   * smoothstep(0.3, -0.2, N[:, 1]) * 0.85)
cream = np.maximum(cream, rmask("paw", "foot").astype(float))
col = mix(col, C_CREAM, cream)

# --- ears: pink hollow, purple tips
inner_ear = ear * smoothstep(0.05, 0.45, EARF) * smoothstep(-0.025, -0.06, LEAF)
ear_purple = ear * smoothstep(0.35, 0.7, eh)
col = mix(col, C_PINK, inner_ear)
col = mix(col, C_PURPLE, ear_purple * (1 - 0.55 * inner_ear))
col = mix(col, C_PURPLE_D, ear * smoothstep(0.82, 1.0, eh) * (1 - inner_ear))

# --- tail: orange outside, purple inside the curl, glowing spiral on the flanks
tail = rmask("tail")
ts, tcen, ttan, tphi = tail_param(V)
_rel = V - TAIL_C
ta = (_rel @ TAIL_U) / TAIL_SU
tb = _rel @ TAIL_V
rho_p = np.sqrt(ta ** 2 + tb ** 2)
_relc = tcen - TAIL_C
rho_c = np.sqrt(((_relc @ TAIL_U) / TAIL_SU) ** 2 + (_relc @ TAIL_V) ** 2)
side_face = smoothstep(0.3, 0.75, np.abs(N @ TAIL_N))
inner_side = smoothstep(0.03, -0.05, rho_p - rho_c)
tail_purple = tail * smoothstep(0.4 * np.pi, 0.62 * np.pi, tphi) * (0.75 + 0.25 * smoothstep(-0.05, 0.05, rho_p - rho_c))
col = mix(col, C_PURPLE, tail_purple * 0.92)

# --- spots
orange = (1 - cream) * (1 - inner_ear) * (1 - ear_purple) * (1 - tail_purple)
spot_ok = (orange > 0.92) & ~rmask("paw", "foot") & ~((REG == "head") & (V[:, 1] < -0.15) & (np.abs(V[:, 0]) < 0.24)) \
    & ~(tail & (ts > 0.3))
_cand = np.where(spot_ok)[0]
_spot_idx = rng.choice(_cand, size=min(330, len(_cand)), replace=False)
_spot_r = rng.uniform(0.02, 0.04, size=len(_spot_idx))
_kd = KDTree(len(_spot_idx))
for _i, _vi in enumerate(_spot_idx):
    _kd.insert(V[_vi], _i)
_kd.balance()
spot = np.zeros(NV)
for _vi in _cand:
    _co, _i, _dd = _kd.find(V[_vi])
    spot[_vi] = smoothstep(_spot_r[_i], _spot_r[_i] * 0.65, _dd)
col = mix(col, C_SPOT, spot * 0.85)

# --- forehead marks (teardrops between the eyes and the goggles) and whisker dots
for (x, z), r, st in [((0.0, 1.81), 0.024, 2.6), ((0.07, 1.815), 0.019, 2.0), ((-0.07, 1.815), 0.019, 2.0),
                      ((0.13, 1.825), 0.015, 1.8), ((-0.13, 1.825), 0.015, 1.8), ((0.035, 1.74), 0.009, 1.3),
                      ((-0.035, 1.74), 0.009, 1.3)]:
    hit, n = ray_surface((x, 0.0, z), (0, -1, 0))
    if hit is None:
        continue
    _d = norm((V - np.array(hit)) * [1, 1, 1 / st])
    col = mix(col, C_MARK, 0.9 * smoothstep(r * 1.45, r * 0.8, _d) * (V[:, 1] < -0.1))
for _s in (1, -1):
    for x, z in ((0.055, 1.532), (0.085, 1.52), (0.11, 1.535), (0.075, 1.503), (0.10, 1.505)):
        hit, n = ray_surface((_s * x, 0.0, z), (0, -1, 0))
        if hit is not None:
            col = mix(col, C_DOT, 0.85 * smoothstep(0.0065, 0.004, norm(V - np.array(hit))))

# --- mouth interior
MOUTH_MASK = np.zeros(NV)
if MOUTH:
    MOUTH_MASK = smoothstep(0.008, -0.002, np.asarray(MOUTH[0](V.astype(np.float32)), np.float64))
    col = mix(col, C_MOUTH, MOUTH_MASK)

# --- glow: tail spiral, thigh and arm stars
glow = np.zeros(NV)
_phi_p = np.arctan2(ta, -tb)
_best = np.full(NV, 9.0)
_b = 0.2 / (2.2 * 2 * np.pi)
for _k in range(-1, 4):
    _th = -_phi_p + 2 * np.pi * _k
    _rs = 0.012 + _b * _th
    _best = np.minimum(_best, np.where(_th > -0.4, np.abs(rho_p - _rs), 9))
_spiral = smoothstep(0.026, 0.009, _best) * smoothstep(0.25, 0.18, rho_p)
_core = smoothstep(0.06, 0.0, rho_p)
glow = np.maximum(glow, tail * side_face * np.clip(_spiral + _core, 0, 1) * smoothstep(0.25, 0.4, ts))


def star_mask(center, normal, R, p=0.55, up=(0, 0, 1.0)):
    n = nrm(normal)
    up = np.asarray(up, np.float64)
    a = nrm(up - n * (up @ n))
    b = np.cross(n, a)
    rel = V - center
    x, y = rel @ b, rel @ a
    q = (np.abs(x) / R) ** p + (np.abs(y) / R) ** p
    fill = smoothstep(1.0, 0.75, q)
    edge = smoothstep(0.16, 0.02, np.abs(q - 0.88))
    near = smoothstep(0.07, 0.035, np.abs(rel @ n))
    return near * np.clip(fill * 0.6 + edge, 0, 1)


STAR_SPOTS = []
for _s in (1, -1):
    for o, d, R, reg in (((_s * 0.18, 0.0, 0.45), (_s * 0.6, -1.0, 0.02), 0.096, "leg"),
                         ((_s * 0.17, 0.0, 0.335), (_s * 0.25, -1.0, -0.05), 0.04, "leg"),
                         ((_s * 0.335, 0.01, 1.03), (_s * 0.45, -1.0, 0.1), 0.056, "arm")):
        hit, n = ray_surface(o, d)
        if hit is not None:
            glow = np.maximum(glow, rmask(reg) * star_mask(np.array(hit), np.array(n), R))
            STAR_SPOTS.append((np.array(hit), np.array(n), R))
col = mix(col, C_GLOW, glow * 0.9)

ca = me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
ca.data.foreach_set("color", np.concatenate([col, np.ones((NV, 1))], 1).astype(np.float32).ravel())
ga = me.attributes.new("glow", "FLOAT", "POINT")
ga.data.foreach_set("value", glow.astype(np.float32))
log("[body] colours done")


# ============================================================================= materials
def new_mat(name):
    m = bpy.data.materials.new(name)
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(bsdf.outputs[0], out.inputs[0])
    return m, nt, bsdf


def simple_mat(name, color, rough=0.5, metal=0.0, emit=None, emit_str=0.0, coat=0.0, trans=0.0, ior=1.45,
               sss=0.0, sheen=0.0):
    m, nt, b = new_mat(name)
    c = srgb(color) if isinstance(color, str) else tuple(color)
    b.inputs["Base Color"].default_value = (*c, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    b.inputs["Coat Weight"].default_value = coat
    b.inputs["Transmission Weight"].default_value = trans
    b.inputs["IOR"].default_value = ior
    if sheen:
        b.inputs["Sheen Weight"].default_value = sheen
        b.inputs["Sheen Roughness"].default_value = 0.4
    if sss:
        b.inputs["Subsurface Weight"].default_value = sss
        b.inputs["Subsurface Radius"].default_value = (0.3, 0.12, 0.06)
        b.inputs["Subsurface Scale"].default_value = 0.05
    if emit:
        b.inputs["Emission Color"].default_value = (*srgb(emit), 1)
        b.inputs["Emission Strength"].default_value = emit_str
    return m


def mnode(nt, op, a=None, b=None, va=None, vb=None, clamp=False):
    n = nt.nodes.new("ShaderNodeMath")
    n.operation = op
    n.use_clamp = clamp
    for i, (lnk, val) in enumerate(((a, va), (b, vb))):
        if lnk is not None:
            nt.links.new(lnk, n.inputs[i])
        elif val is not None:
            n.inputs[i].default_value = val
    return n.outputs[0]


def textured_mat(name, color, scale=14.0, var=0.22, bump=0.25, rough=0.5, coat=0.15, sheen=0.0, coords="Object"):
    """leather / fabric: noise-varied colour + small bump"""
    m, nt, b = new_mat(name)
    tc = nt.nodes.new("ShaderNodeTexCoord")
    nz = nt.nodes.new("ShaderNodeTexNoise")
    nz.inputs["Scale"].default_value = scale
    nz.inputs["Detail"].default_value = 8.0
    nt.links.new(tc.outputs[coords], nz.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    c = np.array(srgb(color))
    ramp.color_ramp.elements[0].position = 0.3
    ramp.color_ramp.elements[0].color = (*(c * (1 - var)), 1)
    ramp.color_ramp.elements[1].position = 0.7
    ramp.color_ramp.elements[1].color = (*np.minimum(c * (1 + var), 1), 1)
    nt.links.new(nz.outputs["Fac"], ramp.inputs[0])
    nt.links.new(ramp.outputs[0], b.inputs["Base Color"])
    bp = nt.nodes.new("ShaderNodeBump")
    bp.inputs["Strength"].default_value = bump
    bp.inputs["Distance"].default_value = 0.004
    nt.links.new(nz.outputs["Fac"], bp.inputs["Height"])
    nt.links.new(bp.outputs["Normal"], b.inputs["Normal"])
    b.inputs["Roughness"].default_value = rough
    b.inputs["Coat Weight"].default_value = coat
    if sheen:
        b.inputs["Sheen Weight"].default_value = sheen
        b.inputs["Sheen Roughness"].default_value = 0.35
        b.inputs["Sheen Tint"].default_value = (1, 1, 1, 1)
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
    nt.links.new(a.outputs["Color"], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.6
    b.inputs["Subsurface Weight"].default_value = 0.05
    b.inputs["Subsurface Radius"].default_value = (0.4, 0.15, 0.08)
    b.inputs["Subsurface Scale"].default_value = 0.03
    b.inputs["Emission Color"].default_value = (*C_GLOW, 1)
    nt.links.new(mnode(nt, "MULTIPLY", g.outputs["Fac"], vb=3.0), b.inputs["Emission Strength"])
    return m


def fur_material():
    m, nt, b = new_mat("Orion_Fur")
    a = attr_node(nt, "fcol")
    g = attr_node(nt, "glow", y=-300)
    info = nt.nodes.new("ShaderNodeHairInfo")
    ramp = nt.nodes.new("ShaderNodeMapRange")
    nt.links.new(info.outputs["Intercept"], ramp.inputs["Value"])
    ramp.inputs["To Min"].default_value = 0.62
    ramp.inputs["To Max"].default_value = 1.1
    mul = nt.nodes.new("ShaderNodeMix")
    mul.data_type = "RGBA"
    mul.blend_type = "MULTIPLY"
    mul.inputs["Factor"].default_value = 1.0
    nt.links.new(a.outputs["Color"], mul.inputs[6])
    comb = nt.nodes.new("ShaderNodeCombineColor")
    for i in range(3):
        nt.links.new(ramp.outputs[0], comb.inputs[i])
    nt.links.new(comb.outputs[0], mul.inputs[7])
    nt.links.new(mul.outputs[2], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.5
    b.inputs["Specular IOR Level"].default_value = 0.3
    b.inputs["Subsurface Weight"].default_value = 0.1
    b.inputs["Subsurface Radius"].default_value = (0.5, 0.25, 0.1)
    b.inputs["Subsurface Scale"].default_value = 0.01
    b.inputs["Emission Color"].default_value = (*C_GLOW, 1)
    nt.links.new(mnode(nt, "MULTIPLY", g.outputs["Fac"], vb=3.6), b.inputs["Emission Strength"])
    return m


body.data.materials.append(skin_material())

# ----------------------------------------------------------------------------- prop materials
M_GOLD = simple_mat("Gold", "#F4B43C", rough=0.24, metal=1.0)
M_GOLD_D = simple_mat("GoldDark", "#B9781C", rough=0.35, metal=1.0)
M_LEATHER = textured_mat("Leather", "#8B4A22", scale=16, var=0.2, bump=0.3, rough=0.48, coat=0.2)
M_LEATHER_D = textured_mat("LeatherDark", "#5A2B12", scale=16, var=0.2, bump=0.3, rough=0.5, coat=0.15)
M_STRAP_P = textured_mat("StrapPurple", "#4C1E46", scale=16, var=0.18, bump=0.3, rough=0.5, coat=0.15)
M_BAG = textured_mat("BagPurple", "#7B2C8A", scale=22, var=0.14, bump=0.35, rough=0.75, sheen=0.5)
M_BAG_D = textured_mat("BagPurpleDark", "#61206F", scale=22, var=0.14, bump=0.35, rough=0.75, sheen=0.5)
M_SCARF = textured_mat("Scarf", "#D9121B", scale=26, var=0.12, bump=0.2, rough=0.72, sheen=0.7)
def lens_material():
    m, nt, b = new_mat("GoggleLens")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Object"], sep.inputs[0])
    x, y = sep.outputs[0], sep.outputs[1]
    r = mnode(nt, "SQRT", mnode(nt, "ADD", mnode(nt, "MULTIPLY", x, x), mnode(nt, "MULTIPLY", y, y)))
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    nt.links.new(r, ramp.inputs[0])
    cr = ramp.color_ramp
    cr.elements[0].position, cr.elements[0].color = 0.0, (*srgb("#7FEBFF"), 1)
    cr.elements[1].position, cr.elements[1].color = 1.0, (*srgb("#0630A8"), 1)
    e = cr.elements.new(0.42)
    e.color = (*srgb("#0E8CFF"), 1)
    b.inputs["Base Color"].default_value = (*srgb("#0D47D9"), 1)
    nt.links.new(ramp.outputs[0], b.inputs["Emission Color"])
    b.inputs["Emission Strength"].default_value = 1.5
    b.inputs["Roughness"].default_value = 0.2
    b.inputs["Specular IOR Level"].default_value = 0.15
    b.inputs["Coat Weight"].default_value = 0.0
    return m


M_LENS = lens_material()
M_GLOWM = simple_mat("GlowCyan", "#7FE6FF", rough=0.3, emit="#1FC4FF", emit_str=6.0)
M_STARM = simple_mat("StarGlow", "#E8FFFF", rough=0.3, emit="#7FF4FF", emit_str=9.0)
M_GEM_BLUE = simple_mat("GemBlue", "#123C9E", rough=0.04, coat=1.0, emit="#1F5BFF", emit_str=0.6)
M_GEM_DARK = simple_mat("GemDark", "#2A0F30", rough=0.06, coat=1.0)
M_GEM_GREEN = simple_mat("GemGreen", "#25C35E", rough=0.05, coat=1.0, emit="#28E070", emit_str=1.2)
M_LANTERN = simple_mat("LanternGlass", "#1438B0", rough=0.08, trans=0.2, emit="#1E5BFF", emit_str=2.2, coat=0.2)
M_SPARK = simple_mat("Sparkle", "#FFFFFF", emit="#C8FBFF", emit_str=45.0)
M_NOSE = simple_mat("Nose", "#D0303F", rough=0.28, coat=0.8, sss=0.2)
M_TONGUE = simple_mat("Tongue", "#F07385", rough=0.35, coat=0.4, sss=0.3)
M_TOOTH = simple_mat("Tooth", "#FFFDF8", rough=0.25, coat=0.5)
M_LASH = simple_mat("Lash", "#1A100C", rough=0.45)
M_BROW = simple_mat("Brow", "#4A1C08", rough=0.6)
M_WHISK = simple_mat("Whisker", "#FFFFFF", rough=0.3)
M_HILITE = simple_mat("EyeHighlight", "#FFFFFF", rough=0.2, emit="#FFFFFF", emit_str=8.0)
M_CLAW = simple_mat("Claw", "#1C1614", rough=0.3, coat=0.6)


def make_textures():
    """parchment map with a compass rose (PIL) -> Blender image"""
    from PIL import Image, ImageDraw, ImageFilter
    S = 1024
    r = np.random.default_rng(3)
    base = np.ones((S, S, 3)) * np.array([236, 214, 164]) / 255
    noise = r.normal(0, 1, (S // 16, S // 16))
    nimg = Image.fromarray(((noise - noise.min()) / np.ptp(noise) * 255).astype(np.uint8)).resize((S, S),
                                                                                                Image.BICUBIC)
    nz = np.asarray(nimg) / 255.0
    yy, xx = np.mgrid[0:S, 0:S] / S
    edge = np.minimum(np.minimum(xx, 1 - xx), np.minimum(yy, 1 - yy))
    shade = 1 - 0.18 * (nz - 0.5) - 0.35 * smoothstep(0.12, 0.0, edge)
    img = Image.fromarray((np.clip(base * shade[..., None], 0, 1) * 255).astype(np.uint8))
    d = ImageDraw.Draw(img)
    cx, cy = S * 0.5, S * 0.47
    red, brown = (176, 52, 30), (110, 62, 30)
    for k in range(8):
        a = k * math.pi / 4
        L = S * (0.2 if k % 2 == 0 else 0.11)
        w = S * 0.035
        tip = (cx + math.cos(a) * L, cy + math.sin(a) * L)
        l1 = (cx + math.cos(a + math.pi / 2) * w, cy + math.sin(a + math.pi / 2) * w)
        l2 = (cx + math.cos(a - math.pi / 2) * w, cy + math.sin(a - math.pi / 2) * w)
        d.polygon([l1, tip, (cx, cy)], fill=red)
        d.polygon([l2, tip, (cx, cy)], fill=(214, 120, 70))
    d.ellipse([cx - S * 0.13, cy - S * 0.13, cx + S * 0.13, cy + S * 0.13], outline=brown, width=5)
    d.ellipse([cx - S * 0.02, cy - S * 0.02, cx + S * 0.02, cy + S * 0.02], fill=brown)
    for i in range(14):  # dashed route
        x0 = S * (0.12 + i * 0.055)
        y0 = S * (0.8 - 0.1 * math.sin(i * 0.5))
        d.line([x0, y0, x0 + S * 0.03, y0 - S * 0.01], fill=brown, width=5)
    d.line([S * 0.78, S * 0.72, S * 0.84, S * 0.78], fill=red, width=7)
    d.line([S * 0.84, S * 0.72, S * 0.78, S * 0.78], fill=red, width=7)
    img = img.filter(ImageFilter.GaussianBlur(1.2))
    path = os.path.join(args.out, "_tex_map.png")
    img.save(path)
    im = bpy.data.images.load(path)
    im.pack()
    return im


def paper_material():
    m, nt, b = new_mat("Parchment")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = make_textures()
    uv = nt.nodes.new("ShaderNodeUVMap")
    nt.links.new(uv.outputs[0], tex.inputs[0])
    nt.links.new(tex.outputs[0], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.7
    b.inputs["Subsurface Weight"].default_value = 0.1
    return m


def scroll_end_material():
    """spiral of a rolled map seen from its end (object coords of a disc)"""
    m, nt, b = new_mat("ScrollEnd")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Object"], sep.inputs[0])
    x, y = sep.outputs[0], sep.outputs[1]
    r = mnode(nt, "SQRT", mnode(nt, "ADD", mnode(nt, "MULTIPLY", x, x), mnode(nt, "MULTIPLY", y, y)))
    a = mnode(nt, "DIVIDE", mnode(nt, "ARCTAN2", y, x), vb=2 * math.pi)
    f = mnode(nt, "FRACT", mnode(nt, "ADD", mnode(nt, "MULTIPLY", r, vb=4.5), a))
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    nt.links.new(f, ramp.inputs[0])
    cr = ramp.color_ramp
    cr.elements[0].position = 0.0
    cr.elements[0].color = (*srgb("#7A4A1E"), 1)
    cr.elements[1].position = 0.22
    cr.elements[1].color = (*srgb("#E8C27A"), 1)
    e = cr.elements.new(0.85)
    e.color = (*srgb("#D9A956"), 1)
    nt.links.new(ramp.outputs[0], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.6
    return m


def eye_material(name, pupil=1.0):
    m, nt, b = new_mat(name)
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Object"], sep.inputs[0])
    x, y, z = sep.outputs[0], sep.outputs[1], sep.outputs[2]
    zc = mnode(nt, "SUBTRACT", z, vb=-0.03)
    r = mnode(nt, "SQRT", mnode(nt, "ADD", mnode(nt, "MULTIPLY", x, x), mnode(nt, "MULTIPLY", zc, zc)))
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    nt.links.new(r, ramp.inputs[0])
    cr = ramp.color_ramp
    cr.interpolation = "EASE"
    pp = 0.43 * pupil
    stops = [(0.0, "#03050C"), (pp, "#03050C"), (pp + 0.03, "#0A2F8C"), (0.6, "#0D5ED6"), (0.72, "#1C86EA"),
             (0.775, "#2A9CF0"), (0.805, "#08307E"), (0.835, "#F3F5FA"), (1.0, "#F3F5FA")]
    cr.elements[0].position, cr.elements[0].color = stops[0][0], (*srgb(stops[0][1]), 1)
    cr.elements[1].position, cr.elements[1].color = stops[-1][0], (*srgb(stops[-1][1]), 1)
    for p, c in stops[1:-1]:
        e = cr.elements.new(p)
        e.color = (*srgb(c), 1)
    # lighter lower half of the iris
    low = mnode(nt, "MULTIPLY", mnode(nt, "MULTIPLY", zc, vb=-0.55, clamp=True),
                mnode(nt, "MULTIPLY", mnode(nt, "GREATER_THAN", r, vb=pp + 0.04),
                      mnode(nt, "LESS_THAN", r, vb=0.79)))
    lmix = nt.nodes.new("ShaderNodeMix")
    lmix.data_type = "RGBA"
    lmix.blend_type = "SCREEN"
    nt.links.new(low, lmix.inputs["Factor"])
    nt.links.new(ramp.outputs[0], lmix.inputs[6])
    lmix.inputs[7].default_value = (*srgb("#5CC8FF"), 1)
    front = mnode(nt, "LESS_THAN", y, vb=0.0)
    mix_ = nt.nodes.new("ShaderNodeMix")
    mix_.data_type = "RGBA"
    nt.links.new(front, mix_.inputs["Factor"])
    mix_.inputs[6].default_value = (*srgb("#F3F5FA"), 1)
    nt.links.new(lmix.outputs[2], mix_.inputs[7])
    nt.links.new(mix_.outputs[2], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.05
    b.inputs["Coat Weight"].default_value = 1.0
    b.inputs["Coat Roughness"].default_value = 0.02
    b.inputs["Emission Color"].default_value = (*srgb("#2AB8FF"), 1)
    iris = mnode(nt, "MULTIPLY", mnode(nt, "GREATER_THAN", r, vb=pp + 0.02), mnode(nt, "LESS_THAN", r, vb=0.78))
    nt.links.new(mnode(nt, "MULTIPLY", mnode(nt, "MULTIPLY", iris, front), vb=0.35), b.inputs["Emission Strength"])
    return m


# ============================================================================= helpers for props
def sdf_hits(sdf, O, D, tmax=1.2, n=260):
    """first exit point of rays O + t*D (origin inside the shape) and the surface normal"""
    D = np.asarray(D, np.float64)
    O = np.broadcast_to(np.asarray(O, np.float64), D.shape)
    ts = np.linspace(0, tmax, n)
    P = O[:, None, :] + D[:, None, :] * ts[None, :, None]
    d = np.asarray(sdf(P.reshape(-1, 3).astype(np.float32)), np.float64).reshape(len(D), n)
    idx = np.argmax(d > 0, axis=1)
    i0 = np.maximum(idx - 1, 0)
    rr = np.arange(len(D))
    d0, d1 = d[rr, i0], d[rr, idx]
    f = np.clip(d0 / np.minimum(d0 - d1, -1e-9), 0, 1)
    t = ts[i0] + f * (ts[idx] - ts[i0])
    hit = O + D * t[:, None]
    e = 1e-3
    g = np.stack([np.asarray(sdf((hit + o).astype(np.float32)), np.float64)
                  - np.asarray(sdf((hit - o).astype(np.float32)), np.float64)
                  for o in (np.array([e, 0, 0]), np.array([0, e, 0]), np.array([0, 0, e]))], 1)
    return hit, g / np.maximum(norm(g), 1e-9)[:, None]


def plane_ring(sdf, center, normal, ref, count, offset):
    n = nrm(normal)
    ref = np.asarray(ref, np.float64)
    u = nrm(ref - n * (ref @ n))
    v = np.cross(n, u)
    a = np.linspace(0, 2 * np.pi, count, endpoint=False)
    dirs = np.cos(a)[:, None] * u + np.sin(a)[:, None] * v
    hit, nn = sdf_hits(sdf, center, dirs)
    return hit + nn * offset, nn, n


def project(sdf, origin, hints, offset):
    """project hint points onto a SDF surface along rays from origin"""
    hints = np.asarray(hints, np.float64)
    dirs = hints - origin
    dirs /= norm(dirs)[:, None]
    hit, nn = sdf_hits(sdf, origin, dirs)
    return hit + nn * offset, nn


def resample(pts, n):
    pts = np.asarray(pts, np.float64)
    seg = norm(np.diff(pts, axis=0))
    cum = np.concatenate([[0], np.cumsum(seg)])
    t = np.linspace(0, cum[-1], n)
    return np.stack([np.interp(t, cum, pts[:, i]) for i in range(3)], 1)


def mesh_from(name, verts, faces, mat=None, smooth=True, uvs=None):
    bm = bmesh.new()
    vs = [bm.verts.new(tuple(v)) for v in verts]
    fl = []
    for f in faces:
        try:
            fl.append(bm.faces.new([vs[i] for i in f]))
        except ValueError:
            fl.append(None)
    if uvs is not None:
        lay = bm.loops.layers.uv.new()
        for face, uvf in zip(fl, uvs):
            if face is None:
                continue
            for loop, uv in zip(face.loops, uvf):
                loop[lay].uv = uv
    me_ = bpy.data.meshes.new(name)
    bm.to_mesh(me_)
    bm.free()
    for p in me_.polygons:
        p.use_smooth = smooth
    ob = link(bpy.data.objects.new(name, me_))
    if mat:
        me_.materials.append(mat)
    return ob


def grid_faces(nr, nc, closed_c=False):
    faces = []
    for i in range(nr - 1):
        for j in range(nc if closed_c else nc - 1):
            j1 = (j + 1) % nc
            faces.append((i * nc + j, i * nc + j1, (i + 1) * nc + j1, (i + 1) * nc + j))
    return faces


def add_mods(ob, solid=None, offset=1.0, sub=1, bevel=None):
    if bevel:
        b = ob.modifiers.new("bevel", "BEVEL")
        b.width = bevel
        b.segments = 3
    if solid:
        s = ob.modifiers.new("solid", "SOLIDIFY")
        s.thickness = solid
        s.offset = offset
    if sub:
        m = ob.modifiers.new("sub", "SUBSURF")
        m.levels = m.render_levels = sub
    return ob


def band_mesh(name, pts, outs, axis, width, thick, mat, closed=True, subdiv=1):
    """rectangular strap through pts; outs = outward normals; axis = width direction (one or per point)"""
    pts = np.asarray(pts, np.float64)
    outs = np.asarray(outs, np.float64)
    axis = np.asarray(axis, np.float64)
    if axis.ndim == 1:
        axis = np.tile(axis, (len(pts), 1))
    verts = []
    for p, o, ax in zip(pts, outs, axis):
        o = nrm(o)
        ax = nrm(ax - o * (ax @ o))
        verts += [p + ax * width / 2, p + ax * width / 2 + o * thick, p - ax * width / 2 + o * thick,
                  p - ax * width / 2]
    n = len(pts)
    faces = []
    for i in range(n if closed else n - 1):
        a, b = i * 4, ((i + 1) % n) * 4
        for k in range(4):
            faces.append((a + k, a + (k + 1) % 4, b + (k + 1) % 4, b + k))
    if not closed:
        faces.append((3, 2, 1, 0))
        faces.append(((n - 1) * 4, (n - 1) * 4 + 1, (n - 1) * 4 + 2, (n - 1) * 4 + 3))
    ob = mesh_from(name, verts, faces, mat)
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(ob.data)
    bm.free()
    if subdiv:
        add_mods(ob, sub=subdiv)
    return ob


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
    sp.order_u = min(4, len(pts))
    ob = link(bpy.data.objects.new(name, cu))
    cu.materials.append(mat)
    return ob


def prim(kind, name, loc, scale=(1, 1, 1), rot=(0, 0, 0), mat=None, smooth=True, subdiv=0, quat=None, **kw):
    fn = {"sphere": bpy.ops.mesh.primitive_uv_sphere_add, "cyl": bpy.ops.mesh.primitive_cylinder_add,
          "torus": bpy.ops.mesh.primitive_torus_add, "cube": bpy.ops.mesh.primitive_cube_add,
          "cone": bpy.ops.mesh.primitive_cone_add, "ico": bpy.ops.mesh.primitive_ico_sphere_add}[kind]
    if kind == "sphere":
        kw.setdefault("segments", 40)
        kw.setdefault("ring_count", 20)
    if kind == "cyl":
        kw.setdefault("vertices", 48)
    if kind == "torus":
        kw.setdefault("major_segments", 64)
        kw.setdefault("minor_segments", 14)
    fn(location=tuple(loc), rotation=[math.radians(a) for a in rot], **kw)
    ob = bpy.context.active_object
    ob.name = name
    ob.scale = scale if not np.isscalar(scale) else (scale, scale, scale)
    if quat is not None:
        ob.rotation_mode = "QUATERNION"
        ob.rotation_quaternion = quat
    if smooth:
        for p in ob.data.polygons:
            p.use_smooth = True
    if mat:
        ob.data.materials.append(mat)
    if subdiv:
        m = ob.modifiers.new("sub", "SUBSURF")
        m.levels = m.render_levels = subdiv
    return ob


def rbox(name, center, half, mat, bevel=0.04, sub=1, quat=None):
    """rounded box with a real-size bevel"""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=2.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * half[0], v.co.y * half[1], v.co.z * half[2]))
    me_ = bpy.data.meshes.new(name)
    bm.to_mesh(me_)
    bm.free()
    ob = link(bpy.data.objects.new(name, me_))
    ob.location = tuple(center)
    if quat is not None:
        ob.rotation_mode = "QUATERNION"
        ob.rotation_quaternion = quat
    me_.materials.append(mat)
    b = ob.modifiers.new("bevel", "BEVEL")
    b.width = bevel
    b.segments = 4
    if sub:
        m = ob.modifiers.new("sub", "SUBSURF")
        m.levels = m.render_levels = sub
    for p in me_.polygons:
        p.use_smooth = True
    return ob


def quat_z(axis, up=(0, 0, 1)):
    """quaternion that points local +Z along axis (local +Y as close to `up` as possible)"""
    return Vector(tuple(nrm(axis))).to_track_quat("Z", "Y")


def square_ring(name, loc, axis, w, h, thick, mat, spin=0.0):
    """rectangular buckle frame (octagonal tube in the plane perpendicular to axis)"""
    q = quat_z(axis)
    q.rotate(Quaternion_from_axis(axis, spin))
    r = min(w, h) * 0.2
    loc2d = [(w / 2 - r, h / 2), (w / 2, h / 2 - r), (w / 2, -h / 2 + r), (w / 2 - r, -h / 2), (-w / 2 + r, -h / 2),
             (-w / 2, -h / 2 + r), (-w / 2, h / 2 - r), (-w / 2 + r, h / 2)]
    pts = [Vector(tuple(loc)) + q @ Vector((x, y, 0)) for x, y in loc2d]
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = thick
    cu.bevel_resolution = 3
    sp = cu.splines.new("POLY")
    sp.points.add(len(pts) - 1)
    for i, p in enumerate(pts):
        sp.points[i].co = (p.x, p.y, p.z, 1)
    sp.use_cyclic_u = True
    ob = link(bpy.data.objects.new(name, cu))
    cu.materials.append(mat)
    return ob


def Quaternion_from_axis(axis, angle):
    from mathutils import Quaternion
    return Quaternion(Vector(tuple(nrm(axis))), angle)


# ============================================================================= 3. face
EYES = {}


def build_face():
    lid_mat_cache = {}
    for s in (1, -1):
        c = EYE_C[s]
        closed_eye = EX["lid"][0 if s > 0 else 1] == "arc"
        eye = prim("sphere", f"Eye_{'L' if s > 0 else 'R'}", c + np.array([0, 0.02 if closed_eye else 0, 0]),
                   scale=tuple(EYE_S * [1, 0.6 if closed_eye else 1, 1]),
                   mat=eye_material(f"Eye_{s}", EX["pupil"]), segments=48, ring_count=24)
        eye.rotation_euler = (0, 0, math.radians(s * 7))
        bpy.context.view_layer.update()
        mw = eye.matrix_world.copy()
        EYES[s] = eye
        lid = EX["lid"][0 if s > 0 else 1]
        closed = lid == "arc"
        # fur-coloured eyelid shells (upper; lower for squint)
        near = norm(V - (c + [0, -0.03, 0.10])) < 0.06
        lcol = col[near].mean(0) if near.any() else C_FUR
        if s not in lid_mat_cache:
            lid_mat_cache[s] = simple_mat(f"Lid_{s}", tuple(lcol), rough=0.65)
        tilt = math.radians(EX["tilt"]) * s

        def lid_shell(cut, upper, name):
            bm = bmesh.new()
            bmesh.ops.create_uvsphere(bm, u_segments=40, v_segments=20, radius=1.0)
            nrm_ = Vector((math.sin(tilt) * (1 if upper else -1) * -1, 0, math.cos(tilt))) if upper else \
                Vector((0, 0, -1))
            co = nrm_ * cut if upper else Vector((0, 0, cut))
            geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
            bmesh.ops.bisect_plane(bm, geom=geom, plane_co=co, plane_no=nrm_ if upper else Vector((0, 0, 1)),
                                   clear_inner=upper, clear_outer=not upper)
            ys = 0.6 if closed else 1.0
            for v in bm.verts:
                v.co = Vector((v.co.x * EYE_S[0] * 1.03, v.co.y * EYE_S[1] * ys * 1.05, v.co.z * EYE_S[2] * 1.03))
            m_ = bpy.data.meshes.new(name)
            bm.to_mesh(m_)
            bm.free()
            o = link(bpy.data.objects.new(name, m_))
            o.matrix_world = Matrix.Translation(mw.to_translation()) @ mw.to_3x3().normalized().to_4x4()
            for p in m_.polygons:
                p.use_smooth = True
            m_.materials.append(lid_mat_cache[s])
            return o

        def lid_line(cut, upper, a0, a1, n=20):
            """points along the lid edge on the front of the eye (local unit sphere)"""
            pts = []
            rad = math.sqrt(max(1 - cut * cut, 1e-4))
            for a in np.linspace(a0, a1, n):
                p = Vector((math.cos(a) * rad, -math.sin(a) * rad, cut))
                if upper:
                    p = Matrix.Rotation(-tilt, 3, "Y") @ p
                pts.append(p)
            return pts

        def to_world(p, k=1.05):
            return mw @ Vector((p.x * k, p.y * k * 1.04, p.z * k))

        if closed:
            # closed happy eye: full lid + arched lash (^)
            lid_shell(-0.98, True, f"LidUp_{s}")
            arc = [mw @ Vector((x * 1.02, -1.2, -0.12 + 0.5 * (1 - x * x))) for x in np.linspace(-0.95, 0.95, 15)]
            curve_tube(f"LashArc_{s}", arc, 0.013, M_LASH, taper=list(np.interp(np.linspace(0, 1, 15),
                                                                                [0, .2, .8, 1], [.3, 1, 1, .3])))
        else:
            if lid is None:  # wide-open eye: the lash hugs the top contour of the eye
                lash = [mw @ Vector((math.cos(q_) * 1.0, -0.62, math.sin(q_) * 0.93 - 0.02))
                        for q_ in np.linspace(math.radians(4), math.radians(176), 22)]
            else:
                lid_shell(lid, True, f"LidUp_{s}")
                lash = [to_world(p) for p in lid_line(lid, True, math.radians(8), math.radians(172), 20)]
            outer_i = 0 if s > 0 else -1
            o = lash[outer_i]
            flick = [o + Vector((s * 0.028, 0.008, 0.012)), o + Vector((s * 0.052, 0.016, 0.026))]
            lash = (flick[::-1] + lash) if s > 0 else (lash + flick)
            tp = np.interp(np.linspace(0, 1, len(lash)), [0, 0.1, 0.3, 0.7, 1], [0.15, 1.0, 1.05, 0.8, 0.3])
            curve_tube(f"Lash_{s}", lash, 0.02 if lid is None else 0.016, M_LASH, taper=list(tp if s > 0 else tp[::-1]))
            base = lash[3] if s > 0 else lash[-4]
            for k, (dx, dz) in enumerate(((0.05, 0.03), (0.05, 0.004))):
                curve_tube(f"LashSpike_{s}{k}", [base, base + Vector((s * dx * 0.6, 0.01, dz * 0.8)),
                                                 base + Vector((s * dx, 0.016, dz))], 0.0065, M_LASH,
                           taper=[1.0, 0.6, 0.05], res=2)
            # thin lower lash line
            low = [mw @ Vector((math.cos(q_) * 1.02, -0.45, math.sin(q_) * 1.03))
                   for q_ in np.linspace(math.radians(200), math.radians(340), 12)]
            curve_tube(f"LowLash_{s}", low, 0.0045, M_BROW, taper=list(np.interp(np.linspace(0, 1, 12),
                                                                                [0, .5, 1], [.2, 1, .2])))
            # catch-lights (upper-left big, upper-right small)
            prim("sphere", "EyeHL", mw @ Vector((-0.3, -0.93, 0.26)), scale=(0.024, 0.011, 0.026), mat=M_HILITE,
                 segments=16, ring_count=8)
            prim("sphere", "EyeHL2", mw @ Vector((0.2, -0.95, 0.32)), scale=(0.013, 0.006, 0.013), mat=M_HILITE,
                 segments=12, ring_count=6)
        low_cut = EX["low"][0 if s > 0 else 1]
        if low_cut > -1 and not closed:
            lid_shell(low_cut, False, f"LidLow_{s}")
        # brows
        if EX["brow"] == "angry":
            pts = [mw @ Vector((x * 1.1, -0.75, 1.22 + (s * x) * 0.32)) for x in np.linspace(-0.9, 0.9, 8)]
            curve_tube(f"Brow_{s}", pts, 0.017, M_BROW, taper=list(np.interp(np.linspace(0, 1, 8),
                                                                            [0, .3, 1], [1.2, 1, .35])[::s]))
        elif EX["brow"] == "up":
            pts = [mw @ Vector((x, -0.6, 1.55 + 0.2 * (1 - x * x))) for x in np.linspace(-0.7, 0.7, 7)]
            curve_tube(f"Brow_{s}", pts, 0.01, M_BROW, taper=[.3, .8, 1, 1, 1, .8, .3])

    # nose: rounded inverted triangle
    hit, n = ray_surface((0, 0.0, 1.598), (0, -1, 0))
    nose = prim("sphere", "Nose", hit + Vector((0, 0.004, 0.0)), mat=M_NOSE, segments=40, ring_count=20)
    for v in nose.data.vertices:
        z = v.co.z
        v.co.x *= 0.074 * (1 + 0.55 * z) if z < 0 else 0.074 * (1 + 0.12 * z)
        v.co.y *= 0.055
        v.co.z *= 0.048
    nose.rotation_euler = (math.radians(-12), 0, 0)
    prim("sphere", "NoseHL", hit + Vector((-0.022, -0.043, 0.019)), scale=(0.014, 0.004, 0.007), mat=M_HILITE,
         segments=12, ring_count=6)
    # philtrum / mouth line
    top = hit + Vector((0, -0.02, -0.03))
    kind = EX["mouth"]
    if kind in ("closed", "smirk"):
        lip_z = 1.488

        def on_face(x, z, off=0.012):
            h, n_ = ray_surface((x, 0.0, z), (0, -1, 0))
            return h + n_ * off

        curve_tube("Philtrum", [top, on_face(0, lip_z + 0.03), on_face(0, lip_z)], 0.0065, M_LASH)
        for s in (1, -1):
            up = 0.04 if (kind == "smirk" and s < 0) else (0.014 if kind == "smirk" else 0.004)
            pts = [on_face(0, lip_z), on_face(s * 0.04, lip_z - 0.022), on_face(s * 0.085, lip_z - 0.014 + up * 0.5),
                   on_face(s * 0.125, lip_z + up)]
            curve_tube(f"MouthLine_{s}", pts, 0.0068, M_LASH, taper=[1, 1, .85, .35])
    else:
        curve_tube("Philtrum", [top, top + Vector((0, -0.006, -0.03)), top + Vector((0, -0.004, -0.06))], 0.0055,
                   M_LASH)
    if MOUTH:
        if kind == "o":
            prim("sphere", "Tongue", Vector(MOUTH_C) + Vector((0, 0.06, -0.04)), scale=(0.035, 0.03, 0.014),
                 mat=M_TONGUE)
        else:
            big = 1.15 if kind == "grin" else 1.0
            prim("sphere", "Tongue", Vector((0, -0.405, 1.388 - 0.01 * (big - 1))), scale=(0.09 * big, 0.05, 0.017),
                 mat=M_TONGUE)
            fl = 0.05 if kind != "snarl" else 0.058
            for s in (1, -1):
                f = prim("cone", "Fang", Vector((s * 0.088, -0.43, 1.474)), scale=(0.017, 0.014, fl),
                         rot=(180 - 8, s * 6, 0), mat=M_TOOTH, vertices=16, depth=1.0, radius1=1.0, radius2=0.05)
                prim("cone", "FangLow", Vector((s * 0.08, -0.43, 1.383)), scale=(0.011, 0.01, 0.026),
                     rot=(8, 0, 0), mat=M_TOOTH, vertices=12, depth=1.0, radius1=1.0, radius2=0.05)
    # whiskers
    for s in (1, -1):
        for k, (dz, angd) in enumerate(((0.025, 10), (0.0, 0), (-0.025, -10))):
            start = Vector((s * 0.14, -0.43, 1.53 + dz))
            pts = [start + Vector((s * math.cos(math.radians(angd)) * r, 0.05 * r * r,
                                   math.sin(math.radians(angd)) * r - 0.05 * r * r)) for r in np.linspace(0, 0.32, 6)]
            curve_tube("Whisker", pts, 0.0024, M_WHISK, taper=[1, 0.9, 0.7, 0.5, 0.3, 0.1], res=2)


if DO_PROPS:
    build_face()
    log("[face] done")


# ============================================================================= 4. accessories
def build_goggles():
    for s in (1, -1):
        hit, n = ray_surface((s * 0.215, 0.2, 2.0), (0, -1, 0))
        axis = nrm((s * 0.24, -1.0, 0.9))
        base = np.array(hit) + np.array(n) * 0.008
        q = quat_z(axis)

        def at(lx, ly, lz):
            return Vector(tuple(base)) + q @ Vector((lx, ly, lz))

        prim("torus", "GogglePad", at(0, 0, 0.012), quat=q, mat=M_LEATHER_D, major_radius=0.142, minor_radius=0.036)
        prim("cyl", "GoggleCup", at(0, 0, 0.055), quat=q, mat=M_GOLD, radius=0.148, depth=0.085)
        prim("torus", "GoggleRim", at(0, 0, 0.098), quat=q, mat=M_GOLD, major_radius=0.146, minor_radius=0.032)
        prim("torus", "GoggleRimIn", at(0, 0, 0.104), quat=q, mat=M_GOLD_D, major_radius=0.118, minor_radius=0.01)
        prim("sphere", "GoggleLens", at(0, 0, 0.095), quat=q, scale=(0.122, 0.122, 0.04), mat=M_LENS)
        for a in np.linspace(0, 2 * np.pi, 12, endpoint=False):
            prim("sphere", "Rivet", at(math.cos(a) * 0.146, math.sin(a) * 0.146, 0.128), scale=0.0095, mat=M_GOLD,
                 segments=10, ring_count=6)
        g = prim("sphere", "LensGlint", at(-0.045, 0.045, 0.136), quat=q, scale=(0.04, 0.013, 0.004),
                 mat=M_HILITE, segments=16, ring_count=8)
        g.rotation_quaternion = q @ Quaternion_from_axis((0, 0, 1), math.radians(40))
        # side hinge block where the strap attaches
        prim("cube", "GoggleHinge", at(s * 0.165, -0.01, 0.045), quat=q, scale=(0.022, 0.03, 0.03), mat=M_GOLD,
             subdiv=1)
        EYES[f"gog{s}"] = (base, axis, q)
    # bridge + small ring
    bl, al, ql = EYES["gog1"]
    br, ar, qr = EYES["gog-1"]
    pl = Vector(tuple(bl)) + ql @ Vector((-0.145, 0.0, 0.07))
    pr = Vector(tuple(br)) + qr @ Vector((0.145, 0.0, 0.07))
    mid = (pl + pr) / 2 + Vector((0, -0.04, 0.035))
    curve_tube("GoggleBridge", [pl, mid, pr], 0.016, M_GOLD)
    prim("torus", "BridgeRing", mid + Vector((0, -0.005, 0.03)), rot=(80, 0, 0), mat=M_GOLD, major_radius=0.022,
         minor_radius=0.006)
    prim("cube", "BridgePad", mid + Vector((0, 0.045, -0.02)), scale=(0.05, 0.02, 0.035), rot=(-40, 0, 0),
         mat=M_LEATHER, subdiv=2)
    # head strap: tilted ring (forehead -> nape)
    pts, outs, ax = plane_ring(HEAD_SDF, (0, 0.06, 1.79), (0, 0.40, 0.92), (1, 0, 0), 120, 0.012)
    band_mesh("GoggleStrap", pts, outs, ax, 0.092, 0.022, M_LEATHER)
    # side buckles on the strap
    for s in (1, -1):
        i = int(np.argmin(norm(pts - np.array([s * 0.45, 0.02, 1.8]))))
        square_ring("StrapBuckle", pts[i] + outs[i] * 0.022, outs[i], 0.075, 0.06, 0.009, M_GOLD,
                    spin=math.radians(-30 * s))
    # harness over the crown: front -> crown -> back, then splitting into a V down to the strap
    o = HEAD_C + [0, 0, -0.05]
    crown, cn = project(HEAD_SDF, o, resample([(0, -0.15, 2.05), (0, 0.08, 2.12), (0, 0.30, 2.02), (0, 0.42, 1.74)],
                                              18), 0.014)
    band_mesh("HarnessTop", crown, cn, (1, 0, 0), 0.07, 0.02, M_LEATHER, closed=False)
    for k in (5, 10):
        prim("sphere", "HarnessRivet", crown[k] + cn[k] * 0.022, scale=0.014, mat=M_GOLD)


def build_scarf():
    zc = 1.225
    a = np.linspace(0, 2 * np.pi, 140, endpoint=False)
    dirs = np.stack([np.sin(a), -np.cos(a), np.zeros_like(a)], 1)
    hit, nn = sdf_hits(TORSO_SDF, np.array([0, 0.02, zc]), dirs)
    front = np.cos(a)
    centers = hit + dirs * (0.075 + 0.02 * np.clip(front, 0, 1))[:, None] + np.array([0, 0, 1.0]) * (
        -0.05 * np.clip(front, 0, 1) ** 2)[:, None]
    M = 28
    th = np.linspace(0, 2 * np.pi, M, endpoint=False)
    r2 = np.random.default_rng(11)
    folds = r2.uniform(0, 2 * np.pi, 24)
    fdepth = r2.uniform(0.12, 0.34, 24)
    fwid = r2.uniform(0.03, 0.07, 24)
    verts = []
    for i in range(len(a)):
        rt = 0.065 + 0.015 * np.clip(front[i], 0, 1)
        rh = 0.1 + 0.02 * np.clip(front[i], 0, 1)
        for t in th:
            w = 1 + 0.06 * math.sin(5 * t + 3 * a[i]) + 0.04 * math.sin(11 * a[i] + 2 * t)
            for f, fd, fw in zip(folds, fdepth, fwid):
                da = math.atan2(math.sin(a[i] - f + 0.25 * math.sin(t)), math.cos(a[i] - f + 0.25 * math.sin(t)))
                w -= fd * math.exp(-(da / fw) ** 2) * max(math.cos(t), 0.25)
            p = centers[i] + (dirs[i] * math.cos(t) * rt + np.array([0, 0, 1.0]) * math.sin(t) * rh) * w \
                + np.array([0, 0, 1.0]) * 0.018 * math.sin(3 * a[i] + 1.0)
            verts.append(p)
    faces = []
    for i in range(len(a)):
        i1 = (i + 1) % len(a)
        for j in range(M):
            j1 = (j + 1) % M
            faces.append((i * M + j, i * M + j1, i1 * M + j1, i1 * M + j))
    ob = mesh_from("Scarf", verts, faces, M_SCARF)
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(ob.data)
    bm.free()
    add_mods(ob, sub=1)
    # bandana point on the chest
    rows = []
    zs = np.linspace(1.17, 0.99, 7)
    for k, z in enumerate(zs):
        t = k / (len(zs) - 1)
        hw = 0.23 * (1 - t) + 0.014
        xs = np.linspace(-hw, hw, 9)
        hints = np.stack([xs, np.full_like(xs, -0.6), np.full_like(xs, z)], 1)
        p, n = project(TORSO_SDF, np.array([0, 0.02, z]), hints, 0.09 + 0.012 * (1 - t))
        p = p + np.array([0, -1.0, 0]) * (0.012 * np.sin(xs * 38 + k * 0.8) * (1 - 0.5 * t))[:, None]
        rows.append(p)
    drape = mesh_from("ScarfDrape", np.concatenate(rows), grid_faces(len(zs), 9), M_SCARF)
    add_mods(drape, solid=0.022, offset=0, sub=2)
    # loose end over the right shoulder, falling on the back
    st = centers[int(len(a) * 0.62)]
    path = [st, st + np.array([-0.06, 0.06, -0.04]), st + np.array([-0.10, 0.10, -0.13]),
            st + np.array([-0.12, 0.12, -0.22])]
    rows = []
    for k, p in enumerate(path):
        t = np.array([0.6, 0.6, -1.0])
        side = nrm(np.cross(t, [0.3, -1, 0.2]))
        w = [0.06, 0.075, 0.07, 0.05][k]
        rows += [p + side * w * f + nrm([-1, 1, 0.3]) * 0.012 * math.sin(f * 3 + k) for f in np.linspace(-1, 1, 5)]
    tail = mesh_from("ScarfEnd", rows, grid_faces(len(path), 5), M_SCARF)
    add_mods(tail, solid=0.02, offset=0, sub=2)
    return centers, dirs


def build_medallion(scarf_c):
    i = int(np.argmin(scarf_c[:, 1]))
    top = scarf_c[i] + np.array([0, -0.03, -0.075])
    hit, n = ray_surface((0, 0.0, 0.98), (0, -1, 0))
    cen = np.array(hit) + np.array([0, -0.105, 0.0])
    axis = nrm((0, -1.0, 0.18))
    q = quat_z(axis)

    def at(x, y, z):
        return Vector(tuple(cen)) + q @ Vector((x, y, z))

    prim("cyl", "Medallion", at(0, 0, 0), quat=q, mat=M_GOLD, radius=0.095, depth=0.028)
    prim("torus", "MedallionRim", at(0, 0, 0.014), quat=q, mat=M_GOLD, major_radius=0.094, minor_radius=0.014)
    prim("cyl", "MedallionFace", at(0, 0, 0.012), quat=q, mat=M_GOLD_D, radius=0.078, depth=0.006)
    for k in range(16):  # tick marks
        a = k * math.pi / 8
        prim("cube", "Tick", at(math.cos(a) * 0.07, math.sin(a) * 0.07, 0.017), quat=q,
             scale=(0.004, 0.004, 0.003), mat=M_GOLD)
    # 8-point compass star (faceted, glowing)
    verts = [(0, 0, 0.012)]
    ring = []
    for k in range(16):
        a = k * math.pi / 8 + math.pi / 2
        r = 0.072 if k % 4 == 0 else (0.042 if k % 2 == 0 else 0.016)
        ring.append((math.cos(a) * r, math.sin(a) * r, 0.0))
    verts += ring
    faces = [(0, 1 + k, 1 + (k + 1) % 16) for k in range(16)]
    star = mesh_from("CompassStar", verts, faces, M_STARM, smooth=False)
    star.rotation_mode = "QUATERNION"
    star.rotation_quaternion = q
    star.location = at(0, 0, 0.017)
    prim("sphere", "StarCore", at(0, 0, 0.03), scale=0.01, mat=M_GOLD)
    # loop + chain up to the scarf
    loop = at(0, 0.1, 0.0)
    prim("torus", "MedLoop", loop, rot=(0, 90, 0), mat=M_GOLD, major_radius=0.02, minor_radius=0.0065)
    chain = resample([loop + Vector((0, 0, 0.02)), Vector(tuple(top))], 4)
    for k, p in enumerate(chain[1:]):
        prim("torus", "ChainLink", p, rot=(0, 90 if k % 2 else 0, 90), mat=M_GOLD, major_radius=0.016,
             minor_radius=0.0055)
    return cen


def wrap_rows(sdf, axis_y, zs, edge_x, offset, ncols=72):
    """surface rows around the torso, open at the front where |x| < edge_x(z)"""
    rows = []
    for z in zs:
        a_f = np.linspace(0, np.pi, 240)
        dirs = np.stack([np.sin(a_f), -np.cos(a_f), np.zeros_like(a_f)], 1)
        hit, _ = sdf_hits(sdf, np.array([0, axis_y, z]), dirs)
        ex = edge_x(z)
        k = int(np.argmax(hit[:, 0] >= ex))
        a0 = a_f[max(k, 1)]
        a = np.linspace(a0, 2 * np.pi - a0, ncols)
        dirs = np.stack([np.sin(a), -np.cos(a), np.zeros_like(a)], 1)
        hit, nn = sdf_hits(sdf, np.array([0, axis_y, z]), dirs)
        rows.append(hit + nn * offset)
    return np.array(rows)


def build_vest():
    zs = np.linspace(0.835, 1.235, 18)
    rows = wrap_rows(TORSO_SDF, 0.02, zs, lambda z: 0.165 - 0.05 * (z - 0.835) / 0.4, 0.014)
    nr, nc = rows.shape[:2]
    vest = mesh_from("Vest", rows.reshape(-1, 3), grid_faces(nr, nc), M_LEATHER)
    add_mods(vest, solid=0.022, offset=1.0, sub=1)
    # piping (front edges + hem) and rivets
    out = lambda p: p + nrm(np.array([p[0], p[1] - 0.02, 0])) * 0.024
    for j in (0, nc - 1):
        edge = [out(rows[i, j]) for i in range(nr)]
        curve_tube("VestPiping", edge, 0.011, M_LEATHER_D)
        for i in range(1, nr - 2, 3):
            p = rows[i, j + (2 if j == 0 else -2)]
            prim("sphere", "VestRivet", out(p) + np.array([0, -0.004, 0]), scale=0.011, mat=M_GOLD, segments=12,
                 ring_count=6)
    hem = [out(rows[0, j]) + np.array([0, 0, -0.004]) for j in range(nc)]
    curve_tube("VestHem", hem, 0.011, M_LEATHER_D)
    return rows


def build_belt():
    pts, outs, ax = plane_ring(TORSO_SDF, (0, 0.02, 0.78), (0, 0.06, 1.0), (1, 0, 0), 110, 0.028)
    band_mesh("Belt", pts, outs, ax, 0.09, 0.03, M_LEATHER_D)
    i = int(np.argmin(pts[:, 1]))
    c = pts[i] + outs[i] * 0.036
    square_ring("BeltBuckle", c, outs[i], 0.13, 0.105, 0.016, M_GOLD)
    prim("cyl", "BuckleBar", c + np.array([0, -0.005, 0]), rot=(0, 0, 0), mat=M_GOLD, radius=0.008, depth=0.1)
    # belt keepers + pouch on the left hip
    for s in (1, -1):
        j = int(np.argmin(norm(pts - np.array([s * 0.17, -0.25, 0.78]))))
        band_mesh("BeltKeeper", [pts[j] + outs[j] * 0.03 + np.array([0, 0, dz]) for dz in (-0.055, 0.055)],
                  [outs[j]] * 2, np.cross(outs[j], [0, 0, 1]), 0.025, 0.01, M_LEATHER, closed=False, subdiv=0)
    j = int(np.argmin(norm(pts - np.array([0.27, -0.12, 0.78]))))
    pc = pts[j] + outs[j] * 0.07 + np.array([0, 0, -0.04])
    q = quat_z(outs[j])
    rbox("Pouch", pc, (0.07, 0.065, 0.035), M_LEATHER, bevel=0.022, quat=q)
    rbox("PouchFlap", Vector(tuple(pc)) + q @ Vector((0, 0.03, 0.036)), (0.074, 0.04, 0.01), M_LEATHER_D,
         bevel=0.008, quat=q)
    prim("sphere", "PouchButton", Vector(tuple(pc)) + q @ Vector((0, 0.0, 0.05)), scale=0.012, mat=M_GOLD)
    return pts, outs


def build_cross_strap():
    pts, outs, ax = plane_ring(TORSO_SDF, (-0.03, 0.02, 1.0), (0.68, 0.0, -0.73), (0, -1, 0), 110, 0.044)
    band_mesh("CrossStrap", pts, outs, ax, 0.068, 0.022, M_LEATHER)
    for zq in (1.06, 0.9):
        front = [i for i in range(len(pts)) if pts[i][1] < -0.1]
        i = min(front, key=lambda k: abs(pts[k][2] - zq))
        square_ring("StrapBuckleF", pts[i] + outs[i] * 0.026, outs[i], 0.06, 0.08, 0.008, M_GOLD,
                    spin=math.radians(45))


def build_shoulder_straps():
    o = np.array([0, 0.02, 1.0])
    for s in (1, -1):
        hints = resample([(s * 0.15, 0.32, 1.10), (s * 0.19, 0.20, 1.29), (s * 0.20, 0.0, 1.34),
                          (s * 0.19, -0.18, 1.22), (s * 0.185, -0.22, 1.10)], 14)
        p, n = project(TORSO_SDF, o, hints, 0.05)
        side = np.cross(n, np.gradient(p, axis=0))
        band_mesh("ShoulderStrap", p, n, side, 0.08, 0.024, M_STRAP_P, closed=False)
        prim("sphere", "StrapRivet", p[-2] + n[-2] * 0.03, scale=0.012, mat=M_GOLD)


def build_pauldrons():
    for s in (1, -1):
        c = SH(s) + np.array([s * 0.04, 0.0, 0.02])
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=36, v_segments=18, radius=1.0)
        bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=(0, 0, -0.2),
                               plane_no=(0, 0, 1), clear_inner=True)
        for v in bm.verts:
            v.co = Vector((v.co.x * 0.15, v.co.y * 0.145, v.co.z * 0.075))
        m_ = bpy.data.meshes.new("Pauldron")
        bm.to_mesh(m_)
        bm.free()
        ob = link(bpy.data.objects.new("Pauldron", m_))
        ob.location = tuple(c)
        ob.rotation_euler = (0, math.radians(s * 42), 0)
        for p in m_.polygons:
            p.use_smooth = True
        m_.materials.append(M_LEATHER_D)
        add_mods(ob, solid=0.02, offset=1.0, sub=1)
        bpy.context.view_layer.update()
        mw = ob.matrix_world
        for a in np.linspace(-0.6, 0.6, 3):
            prim("sphere", "PauldronRivet", mw @ Vector((math.cos(a) * 0.17, math.sin(a) * 0.16, 0.035)), scale=0.011,
                 mat=M_GOLD, segments=10, ring_count=6)


def build_bracers():
    for s in (1, -1):
        a, b = EL(s), WR(s)
        ax = nrm(b - a)
        Lx = np.linalg.norm(b - a)
        e1 = nrm(np.cross(ax, [0, 1.0, 0]))
        e2 = np.cross(ax, e1)
        ts_ = np.linspace(0.06, 0.98, 12)
        th = np.linspace(0, 2 * np.pi, 40, endpoint=False)
        verts = []
        for t in ts_:
            r = 0.104 + (0.094 - 0.104) * t + 0.03 + 0.008 * (smoothstep(0.25, 0.0, t) + smoothstep(0.8, 1.0, t))
            c = a + ax * Lx * t
            for q_ in th:
                verts.append(c + (e1 * math.cos(q_) + e2 * math.sin(q_)) * r)
        ob = mesh_from("Bracer", verts, grid_faces(len(ts_), len(th), closed_c=True), M_LEATHER)
        bm = bmesh.new()
        bm.from_mesh(ob.data)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(ob.data)
        bm.free()
        add_mods(ob, solid=0.022, offset=-1.0, sub=1)
        for t in (0.09, 0.95):
            c = a + ax * Lx * t
            r = 0.104 + (0.094 - 0.104) * t + 0.042
            for q_ in np.linspace(0, 2 * np.pi, 14, endpoint=False):
                prim("sphere", "BracerRivet", c + (e1 * math.cos(q_) + e2 * math.sin(q_)) * r, scale=0.009,
                     mat=M_GOLD, segments=10, ring_count=6)
        outd = nrm(np.array([s * 1.0, -0.55, 0.05]) - ax * (np.array([s * 1.0, -0.55, 0.05]) @ ax))
        c = a + ax * Lx * 0.52 + outd * 0.152
        q = quat_z(outd)
        hx = prim("torus", "BracerHex", c, quat=q, mat=M_GLOWM, major_segments=6, minor_segments=8,
                  major_radius=0.047, minor_radius=0.0095, smooth=False)
        prim("torus", "BracerHexGold", Vector(tuple(c)) - q @ Vector((0, 0, 0.006)), quat=q, mat=M_GOLD,
             major_segments=6, minor_segments=8, major_radius=0.06, minor_radius=0.007, smooth=False)
        prim("sphere", "BracerGem", Vector(tuple(c)) + q @ Vector((0, 0, 0.004)), quat=q, scale=(0.028, 0.028, 0.016),
             mat=M_GEM_BLUE)


def build_backpack():
    M_PAPER = paper_material()
    M_SPIRAL = scroll_end_material()
    rbox("Backpack", (0, 0.44, 0.95), (0.3, 0.19, 0.32), M_BAG, bevel=0.12)
    rbox("BackpackBottom", (0, 0.46, 0.73), (0.31, 0.2, 0.11), M_BAG, bevel=0.1)
    rbox("BackpackFlap", (0, 0.45, 1.17), (0.315, 0.21, 0.15), M_BAG_D, bevel=0.09)
    rbox("Pocket", (0, 0.66, 0.80), (0.21, 0.045, 0.12), M_BAG, bevel=0.035)
    rbox("PocketFlap", (0, 0.695, 0.895), (0.215, 0.028, 0.048), M_BAG_D, bevel=0.02)
    prim("sphere", "PocketButton", (0, 0.724, 0.87), scale=0.015, mat=M_GOLD)
    for x in (-0.145, 0.145):
        path = np.array([(x, 0.30, 1.32), (x, 0.46, 1.33), (x, 0.62, 1.31), (x, 0.665, 1.23),
                         (x, 0.668, 1.04), (x, 0.64, 1.0), (x, 0.635, 0.95), (x, 0.71, 0.92), (x, 0.712, 0.82),
                         (x, 0.69, 0.70)])
        outs = np.array([(0, 0, 1), (0, 0.2, 1), (0, 0.6, 0.8), (0, 1, 0.1), (0, 1, 0), (0, 1, 0), (0, 1, 0),
                         (0, 1, 0), (0, 1, 0), (0, 1, -0.3)], np.float64)
        band_mesh("PackStrap", path, outs, (1, 0, 0), 0.062, 0.014, M_LEATHER, closed=False)
        square_ring("PackBuckle", (x, 0.69, 1.05), (0, 1, 0), 0.075, 0.065, 0.01, M_GOLD)
    # emblem clasp
    q = quat_z((0, 1, 0))
    prim("cyl", "Emblem", (0, 0.668, 1.08), quat=q, scale=(1.25, 1, 1), mat=M_GOLD, radius=0.045, depth=0.016)
    prim("sphere", "EmblemGem", (0, 0.68, 1.08), quat=q, scale=(0.022, 0.022, 0.012), mat=M_GEM_DARK)
    curve_tube("PackHandle", [(-0.1, 0.45, 1.31), (-0.06, 0.45, 1.40), (0.06, 0.45, 1.40), (0.1, 0.45, 1.31)],
               0.018, M_LEATHER)
    # rolled map (horizontal) on the right side
    rc = np.array([-0.43, 0.48, 1.12])
    rax = nrm((0.87, 0.5, 0.0))
    prim("cyl", "MapRoll", rc, rot=(0, 90, 30), mat=M_PAPER, radius=0.085, depth=0.34)
    for k in (-1, 1):
        prim("cyl", "MapRollEnd", rc + rax * k * 0.171, rot=(0, 90, 30), mat=M_SPIRAL, radius=0.084, depth=0.004)
    e1 = np.cross(rax, [0, 0, 1.0])
    ring = [rc + (e1 * math.cos(a) + np.array([0, 0, 1.0]) * math.sin(a)) * 0.09 for a in
            np.linspace(0, 2 * np.pi, 24, endpoint=False)]
    band_mesh("MapTie", ring, [p - rc for p in ring], rax, 0.03, 0.006, M_LEATHER_D)
    # partly unrolled map: a cone of parchment sticking up and out
    A = np.array([-0.33, 0.49, 1.16])
    B = np.array([-0.47, 0.56, 1.54])
    ax = nrm(B - A)
    e1 = nrm(np.cross(ax, [0, 0, 1.0]))
    e2 = np.cross(ax, e1)
    nu, nv = 14, 40
    verts, uvs = [], []
    for i in range(nu):
        u = i / (nu - 1)
        for j in range(nv):
            v = j / (nv - 1)
            th = 0.9 + v * math.radians(300)
            r = (0.045 + 0.085 * u ** 1.3) * (1 + 0.22 * v)
            verts.append(A + ax * np.linalg.norm(B - A) * u + (e1 * math.cos(th) + e2 * math.sin(th)) * r)
            uvs.append((v, u))
    faces = grid_faces(nu, nv)
    face_uvs = [[uvs[k] for k in f] for f in faces]
    cone_ob = mesh_from("MapSheet", verts, faces, M_PAPER, uvs=face_uvs)
    add_mods(cone_ob, solid=0.005, offset=0, sub=1)
    # lantern hanging from the right side
    lc = np.array([-0.50, 0.32, 0.80])
    hook = np.array([-0.36, 0.35, 1.0])
    curve_tube("LanternChain", [hook, hook + np.array([-0.0375, 0, -0.0750]), lc + np.array([0, 0, 0.1625])], 0.0075,
               M_GOLD)
    prim("torus", "LanternRing", lc + np.array([0, 0, 0.1562]), rot=(90, 0, 0), mat=M_GOLD, major_radius=0.0275,
         minor_radius=0.0075)
    prim("cone", "LanternRoof", lc + np.array([0, 0, 0.1187]), mat=M_GOLD, radius1=0.0775, radius2=0.0225, depth=0.0562,
         vertices=32)
    prim("cyl", "LanternTop", lc + np.array([0, 0, 0.0875]), mat=M_GOLD, radius=0.0725, depth=0.0250)
    prim("cyl", "LanternBase", lc + np.array([0, 0, -0.1000]), mat=M_GOLD, radius=0.0775, depth=0.0350)
    for a in np.linspace(0, 2 * np.pi, 4, endpoint=False) + math.pi / 4:
        prim("cyl", "LanternBar", lc + np.array([math.cos(a) * 0.0700, math.sin(a) * 0.0700, -0.0063]), mat=M_GOLD,
             radius=0.0075, depth=0.1875, vertices=10)
    prim("sphere", "LanternGlass", lc, scale=(0.0650, 0.0650, 0.0850), mat=M_LANTERN)
    prim("sphere", "LanternCore", lc, scale=0.0175, mat=M_SPARK)
    for rot in ((0, 0, 0), (0, 0, 90)):
        prim("sphere", "LanternRay", lc + np.array([0, -0.0000, 0]), rot=rot, scale=(0.0562, 0.0050, 0.0050),
             mat=M_SPARK, segments=12, ring_count=6)
    prim("sphere", "LanternRayV", lc, scale=(0.0050, 0.0050, 0.0625), mat=M_SPARK, segments=12, ring_count=6)
    L = bpy.data.lights.new("LanternLight", "POINT")
    L.color = srgb("#6FB6FF")
    L.energy = 14
    L.shadow_soft_size = 0.03
    lo = link(bpy.data.objects.new("LanternLight", L))
    lo.location = tuple(lc)
    # green crystal charm
    gc = np.array([-0.40, 0.46, 0.90])
    curve_tube("CharmChain", [np.array([-0.36, 0.48, 0.98]), gc + np.array([0, 0, 0.04])], 0.004, M_GOLD)
    prim("ico", "GreenCrystal", gc, scale=(0.022, 0.022, 0.042), mat=M_GEM_GREEN, subdivisions=1, smooth=False)


def build_claws():
    for s in (1, -1):
        for dx in (-0.122, -0.041, 0.041, 0.122):
            p = foot_local(s, (dx, -0.272, -0.05))
            d = foot_local(s, (dx, -1.0, -0.6)) - FOOT(s)
            q = quat_z(d)
            prim("cone", "Claw", p, quat=q, scale=(0.017, 0.014, 0.048), mat=M_CLAW, vertices=12, depth=1.0,
                 radius1=1.0, radius2=0.05)


if DO_PROPS:
    build_goggles()
    log("[props] goggles")
    SCARF_C, _ = build_scarf()
    MED_C = build_medallion(SCARF_C)
    build_vest()
    build_belt()
    build_cross_strap()
    build_shoulder_straps()
    build_pauldrons()
    build_bracers()
    build_backpack()
    build_claws()
    log("[props] done")


# ============================================================================= 5. fur
def props_bvh():
    dg = bpy.context.evaluated_depsgraph_get()
    allv, allt, off = [], [], 0
    for ob in scene.objects:
        if ob.type != "MESH" or ob.name in ("Orion_Body", "Ground") or ob.name.startswith("Eye_X"):
            continue
        ev = ob.evaluated_get(dg)
        m_ = ev.to_mesh()
        if len(m_.vertices) == 0:
            ev.to_mesh_clear()
            continue
        co = np.empty(len(m_.vertices) * 3, np.float32)
        m_.vertices.foreach_get("co", co)
        M = np.array(ob.matrix_world)
        co = co.reshape(-1, 3) @ M[:3, :3].T + M[:3, 3]
        m_.calc_loop_triangles()
        tri = np.empty(len(m_.loop_triangles) * 3, np.int32)
        m_.loop_triangles.foreach_get("vertices", tri)
        allv.append(co)
        allt.append(tri.reshape(-1, 3) + off)
        off += len(co)
        ev.to_mesh_clear()
    return BVHTree.FromPolygons(np.concatenate(allv).tolist(), np.concatenate(allt).tolist())


def fur_params():
    L = np.full(NV, 0.021)
    D = np.ones(NV)
    lift = np.full(NV, 0.35)
    clump = np.full(NV, 0.45)
    head = rmask("head")
    L[head] = 0.016
    face = head & (V[:, 1] < -0.22)
    L[face] = 0.009
    lift[face] = 0.25
    # ruff: long spiky cream tufts on the lower cheeks / sides of the face
    cheek = rmask("cheek")
    side = smoothstep(0.12, 0.42, np.abs(V[:, 0]))
    L[cheek] = (0.045 + 0.09 * side)[cheek]
    lift[cheek] = 0.3
    clump[cheek] = 0.92
    low_side = head & (V[:, 2] < 1.64) & (np.abs(V[:, 0]) > 0.24)
    L[low_side] = np.maximum(L[low_side], 0.065)
    clump[low_side] = 0.88
    L[rmask("muzzle")] = 0.008
    L[rmask("chin")] = 0.032
    clump[rmask("chin")] = 0.75
    # ears
    L[ear] = 0.03 + 0.035 * smoothstep(0.3, 0.9, eh[ear])
    lift[ear] = 0.22
    clump[ear] = 0.7
    rim = ear & (LEAF > -0.03)
    L[rim] = np.maximum(L[rim], 0.075)
    clump[rim] = 0.75
    hollow = ear & (inner_ear > 0.5)
    L[hollow] = 0.006
    D[hollow] = 0.35
    # body
    L[rmask("neck", "chest", "belly")] = 0.032
    clump[rmask("neck", "chest", "belly")] = 0.6
    L[rmask("hips")] = 0.026
    L[rmask("arm")] = 0.019
    L[rmask("paw")] = 0.012
    L[rmask("foot")] = 0.008
    L[rmask("leg")] = 0.022
    L[tail] = (0.042 + 0.022 * smoothstep(0.0, 0.3, ts))[tail]
    D[tail] = 1.7
    lift[tail] = 0.4
    clump[tail] = 0.86
    # glowing marks keep their shape
    gl = glow > 0.15
    L[gl & ~tail] = np.minimum(L[gl & ~tail], 0.01)
    L[gl & tail] = np.minimum(L[gl & tail], 0.022)
    D *= 1 - MOUTH_MASK
    D *= smoothstep(0.0, 0.025, V[:, 2])
    for s in (1, -1):
        D *= smoothstep(0.115, 0.14, norm((V - EYE_C[s]) / [1.0, 1.0, 0.92]))
    return L, D, lift, clump


def flow_dir(P, Nn, reg, tt, eu):
    f = np.tile(np.array([0, 0.2, -1.0]), (len(P), 1))
    m = reg == "head"
    f[m] = P[m] - np.array([0, -0.80, 1.62])
    low = m & (P[:, 2] < 1.64) & (np.abs(P[:, 0]) > 0.24)
    m2 = (reg == "cheek") | low
    f[m2] = np.stack([np.sign(P[m2, 0]), np.full(m2.sum(), 0.3), np.full(m2.sum(), -0.6)], 1)
    m = np.isin(reg, ["muzzle", "chin"])
    f[m] = P[m] - np.array([0, -0.62, 1.58])
    m = reg == "ear"
    f[m] = eu[m]
    m = reg == "tail"
    f[m] = tt[m]
    m = np.isin(reg, ["arm", "paw", "leg", "foot"])
    f[m] = [0, 0.05, -1.0]
    f = f - Nn * np.sum(f * Nn, 1)[:, None]
    return f / np.maximum(norm(f)[:, None], 1e-6)


def clump_pull(P0, pts, cl, frac):
    count = len(P0)
    if count < 50:
        return pts
    nclump = max(count // frac, 10)
    ci = rng.choice(count, nclump, replace=False)
    kdc = KDTree(nclump)
    for i, j in enumerate(ci):
        kdc.insert(P0[j], i)
    kdc.balance()
    nearest = np.empty(count, np.int64)
    for i in range(count):
        nearest[i] = ci[kdc.find(P0[i])[1]]
    npts = pts.shape[1]
    t = np.linspace(0, 1, npts)
    tgt = pts[nearest]
    blend = (t ** 1.3)[None, :, None] * (cl * rng.uniform(0.75, 1.1, count))[:, None, None]
    out = pts + (tgt - pts) * np.clip(blend, 0, 1)
    out[:, 0, :] = pts[:, 0, :]
    return out


def bezier_pts(p0, p1, p2, p3, npts):
    t = np.linspace(0, 1, npts)[None, :, None]
    return ((1 - t) ** 3 * p0[:, None] + 3 * (1 - t) ** 2 * t * p1[:, None] + 3 * (1 - t) * t ** 2 * p2[:, None]
            + t ** 3 * p3[:, None])


def build_fur(count):
    Lv, Dv, Liftv, Clv = fur_params()
    if DO_PROPS:
        cov = props_bvh()
        lim = np.full(NV, 9.0)
        skip_near = rmask("cheek") | (rmask("head") & (V[:, 2] < 1.64))
        for i in range(NV):
            o = Vector(tuple(V[i] + N[i] * 0.002))
            hit = cov.ray_cast(o, Vector(tuple(N[i])), 0.08)
            if hit[0] is not None:
                if hit[3] < 0.05:
                    Dv[i] = 0.0
                    continue
                lim[i] = hit[3] * 0.8
            if not skip_near[i]:
                loc, _n, _idx, dd = cov.find_nearest(o, 0.035)
                if loc is not None:
                    lim[i] = min(lim[i], max(dd * 0.9, 0.004))
        Lv = np.minimum(Lv, lim)
        log(f"[fur] covered by props: {(Dv == 0).mean() * 100:.1f}% of skin")
    me.calc_loop_triangles()
    tris = np.empty(len(me.loop_triangles) * 3, np.int32)
    me.loop_triangles.foreach_get("vertices", tris)
    tris = tris.reshape(-1, 3)
    a, b, c = V[tris[:, 0]], V[tris[:, 1]], V[tris[:, 2]]
    area = 0.5 * norm(np.cross(b - a, c - a))
    w = area * Dv[tris].min(1)
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
    clv = np.einsum("ij,ij->i", bc, Clv[tv])
    C = np.einsum("ij,ijk->ik", bc, col[tv])
    G = np.einsum("ij,ij->i", bc, glow[tv])
    vi = tv[np.arange(count), np.argmax(bc, 1)]
    reg = REG[vi]
    _s, _c, t_t, _p = tail_param(P0)
    F = flow_dir(P0, Nn, reg, t_t, EARU[vi])
    d = Nn * lift[:, None] + F * (1 - lift[:, None])
    d /= norm(d)[:, None]
    j = rng.normal(0, 1.0, (count, 3)) * np.where(reg == "tail", 0.07, 0.12)[:, None]
    d = d + j - Nn * np.sum(j * Nn, 1)[:, None]
    d /= norm(d)[:, None]
    groups = []
    for long_ in (False, True):
        m = (L >= 0.04) if long_ else (L < 0.04)
        if not m.any():
            continue
        npts = 8 if long_ else 4
        t = np.linspace(0, 1, npts)
        root = P0[m] - Nn[m] * 0.002
        Lm = L[m][:, None, None]
        pts = root[:, None, :] + d[m][:, None, :] * (Lm * t[None, :, None])
        droop = 0.22 if long_ else 0.15
        pts += np.array([0, 0, -1.0])[None, None, :] * (droop * Lm * (t ** 2)[None, :, None])
        pts += F[m][:, None, :] * (0.3 * Lm * (t ** 2)[None, :, None])
        pts = clump_pull(P0[m], pts, clv[m], 18 if long_ else 24)
        groups.append((pts, C[m], G[m], L[m]))
    # --- purple flame tufts: locks rising past the ear tip and curling outward
    for s in (1, -1):
        B, U, F_, W = ear_frame(s)
        sel = np.where((np.sign(V[:, 0]) == s) & ear & (eh > 0.45) & (inner_ear < 0.6))[0]
        n_t = 12000
        roots = V[rng.choice(sel, n_t)] + rng.normal(0, 0.003, (n_t, 3))
        rh = np.clip(((roots - B) @ U) / EAR_LEN, 0, 1)
        tip = B + U * EAR_LEN
        # flame spine: rises above the ear tip, then hooks outward and down
        sp0, sp1 = tip - U * 0.15, tip + U * 0.2 - W * 0.02
        sp2, sp3 = tip + U * 0.3 + W * 0.04, tip + U * 0.17 + W * 0.25 - F_ * 0.05

        def spine(tau):
            tau = tau[:, None]
            return (1 - tau) ** 3 * sp0 + 3 * (1 - tau) ** 2 * tau * sp1 + 3 * (1 - tau) * tau ** 2 * sp2 \
                + tau ** 3 * sp3

        u = rng.random(n_t)
        tau = 0.25 + 0.75 * u ** 0.55
        width = 0.18 * (1 - tau) ** 1.1 + 0.012
        lat = rng.uniform(-1, 1, n_t)
        dep = rng.uniform(-1, 1, n_t)
        end = spine(tau) + W * (lat * width)[:, None] + F_ * (dep * width * 0.5)[:, None]
        mid = spine(tau * 0.6) + W * (lat * width * 1.3)[:, None] + F_ * (dep * width * 0.6)[:, None]
        p1 = roots + U[None] * (0.07 + 0.04 * u)[:, None]
        pts = bezier_pts(roots, p1, mid, end, 10)
        pts = clump_pull(roots, pts, np.full(n_t, 0.65), 150)
        ccol = mix(np.tile(C_FUR, (n_t, 1)), np.tile(C_PURPLE, (n_t, 1)), smoothstep(0.35, 0.6, rh))
        ccol = mix(ccol, C_PURPLE_D, rng.random(n_t) * 0.35) * rng.uniform(0.85, 1.1, (n_t, 1))
        groups.append((pts, ccol, np.zeros(n_t), np.full(n_t, 0.2)))
        # cream fluff coming out of the ear hollow
        sel = np.where((np.sign(V[:, 0]) == s) & ear & (inner_ear > 0.4) & (eh < 0.35) & (EW < 0.06))[0]
        if len(sel):
            n_f = 900
            roots = V[rng.choice(sel, n_f)]
            Lf = rng.uniform(0.07, 0.14, n_f)[:, None]
            p3 = roots + U * Lf * 0.85 + F_ * Lf * 0.5 + W * Lf * 0.15
            p1 = roots + F_ * Lf * 0.35
            p2 = p3 - U * Lf * 0.3
            pts = bezier_pts(roots, p1, p2, p3, 8)
            pts = clump_pull(roots, pts, np.full(n_f, 0.9), 60)
            groups.append((pts, np.tile(C_CREAM, (n_f, 1)), np.zeros(n_f), Lf[:, 0]))
    # assemble
    sizes, allp, allc, allg, allr = [], [], [], [], []
    for pts, cc, gg, ll in groups:
        k, npts = pts.shape[:2]
        sizes += [npts] * k
        allp.append(pts.reshape(-1, 3))
        allc.append(cc)
        allg.append(gg)
        prof = np.interp(np.linspace(0, 1, npts), [0, 0.5, 1], [0.0031, 0.0021, 0.0003])
        allr.append((prof[None, :] * np.clip(ll / 0.03, 0.85, np.where(ll >= 0.18, 2.3, 1.7))[:, None]).ravel())
    cv = bpy.data.hair_curves.new("OrionFur")
    cv.add_curves(sizes)
    cv.position_data.foreach_set("vector", np.concatenate(allp).astype(np.float32).ravel())
    rad = cv.attributes.get("radius") or cv.attributes.new("radius", "FLOAT", "POINT")
    rad.data.foreach_set("value", np.concatenate(allr).astype(np.float32))
    cc = np.concatenate(allc)
    fc = cv.attributes.new("fcol", "FLOAT_COLOR", "CURVE")
    fc.data.foreach_set("color", np.concatenate([cc, np.ones((len(cc), 1))], 1).astype(np.float32).ravel())
    gl = cv.attributes.new("glow", "FLOAT", "CURVE")
    gl.data.foreach_set("value", np.concatenate(allg).astype(np.float32))
    ob = link(bpy.data.objects.new("Orion_Fur", cv))
    ob.data.materials.append(fur_material())
    log(f"[fur] {len(sizes)} strands")
    return ob


fur = build_fur(args.fur) if DO_FUR else None

root = link(bpy.data.objects.new("Orion", None))
for ob in list(COL.objects):
    if ob is not root and ob.parent is None:
        ob.parent = root


# ============================================================================= 6. stage, lights, camera
def area_light(name, loc, target, power, color, size, parent, shadow=True):
    L = bpy.data.lights.new(name, "AREA")
    L.energy = power
    L.color = color
    L.size = size
    L.use_shadow = shadow
    o = link(bpy.data.objects.new(name, L))
    o.location = loc
    d = Vector(target) - Vector(loc)
    o.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    o.parent = parent
    return o


LIGHT_SCALE = args.light


def setup_white_stage():
    w = bpy.data.worlds.new("World")
    scene.world = w
    nt = w.node_tree
    bg = nt.nodes.get("Background") or nt.nodes.new("ShaderNodeBackground")
    bg.inputs[0].default_value = (1, 1, 1, 1)
    bg.inputs[1].default_value = 0.35 * LIGHT_SCALE
    out = nt.nodes.get("World Output") or nt.nodes.new("ShaderNodeOutputWorld")
    nt.links.new(bg.outputs[0], out.inputs[0])
    rig = link(bpy.data.objects.new("LightRig", None))
    k = LIGHT_SCALE
    area_light("Key", (-3.0, -4.2, 4.2), (0, 0, 1.2), 520 * k, srgb("#FFF0DC"), 3.2, rig)
    area_light("Fill", (3.6, -3.2, 1.8), (0, 0, 1.1), 170 * k, srgb("#E4ECFF"), 3.5, rig, shadow=False)
    area_light("RimL", (-2.8, 3.0, 3.0), (0, 0, 1.2), 380 * k, srgb("#FFFFFF"), 2.0, rig, shadow=False)
    area_light("RimR", (3.0, 2.8, 2.6), (0, 0, 1.1), 340 * k, srgb("#F2EEFF"), 2.0, rig, shadow=False)
    area_light("Top", (0, 0.4, 5.5), (0, 0, 1.0), 170 * k, srgb("#FFF8EE"), 3.0, rig)
    bpy.ops.mesh.primitive_plane_add(size=14, location=(0, 0, 0))
    g = bpy.context.active_object
    g.name = "Ground"
    g.is_shadow_catcher = True
    return rig


RIG = setup_white_stage()
cam_data = bpy.data.cameras.new("Cam")
cam = link(bpy.data.objects.new("Cam", cam_data))
scene.camera = cam


def place_camera(angle_deg, ortho=None, lens=85, dist=7.5, height=1.3, target=(0, 0.1, 1.2)):
    a = math.radians(angle_deg)
    if ortho:
        cam_data.type = "ORTHO"
        cam_data.ortho_scale = ortho
    else:
        cam_data.type = "PERSP"
        cam_data.lens = lens
    cam.location = (target[0] + math.sin(a) * dist, target[1] - math.cos(a) * dist, height)
    d = Vector(target) - cam.location
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    RIG.rotation_euler = (0, 0, a)


scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = args.samples
scene.cycles.use_denoising = True
scene.cycles.max_bounces = 6
scene.cycles.transparent_max_bounces = 16
scene.render.film_transparent = True
scene.render.image_settings.color_mode = "RGBA"
try:
    scene.view_settings.view_transform = args.view
    if args.look:
        scene.view_settings.look = args.look
except TypeError as e:
    log("view transform:", e)
scene.view_settings.exposure = 0.0


def finish(path, bloom=True):
    """composite RGBA render over white + soft bloom from bright/glowing pixels"""
    from PIL import Image, ImageFilter
    im = Image.open(path).convert("RGBA")
    a = np.asarray(im).astype(np.float32) / 255
    rgb, al = a[..., :3], a[..., 3:4]
    lum0 = (rgb @ np.array([0.2126, 0.7152, 0.0722]))[..., None]
    rgb = np.clip(0.5 + ((lum0 + (rgb - lum0) * 1.18) - 0.5) * 1.08, 0, 1)  # gentle saturation/contrast
    out = rgb * al + (1 - al)
    if bloom:
        lum = rgb @ np.array([0.2126, 0.7152, 0.0722])
        sat = rgb.max(-1) - rgb.min(-1)
        blue = smoothstep(0.0, 0.18, rgb[..., 2] - rgb[..., 0])
        bright = rgb * (smoothstep(0.55, 0.9, lum) * smoothstep(0.2, 0.45, sat) * blue * (al[..., 0] > 0.5))[..., None]
        bimg = Image.fromarray((np.clip(bright, 0, 1) * 255).astype(np.uint8))
        acc = np.zeros_like(rgb)
        sc = im.width / 1000
        for r, wgt in ((3, 0.55), (10, 0.5), (28, 0.35)):
            acc += np.asarray(bimg.filter(ImageFilter.GaussianBlur(r * sc))).astype(np.float32) / 255 * wgt
        out = 1 - (1 - out) * (1 - np.clip(acc, 0, 1))
    res = Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8))
    fpath = path.replace(".png", "_w.png")
    res.save(fpath)
    return fpath


def render(name, angle, size=(1000, 1000), **kw):
    place_camera(angle, **kw)
    scene.render.resolution_x, scene.render.resolution_y = size
    path = os.path.join(args.out, f"{name}{args.tag}.png")
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    log("[render]", path)
    return path


def compose_sheet(raw, fin, labels, out_path):
    from PIL import Image, ImageDraw, ImageFont
    alphas = [np.asarray(Image.open(p).convert("RGBA"))[..., 3] for p in raw]
    boxes = [np.argwhere(a > 8) for a in alphas]
    top = min(b[:, 0].min() for b in boxes)
    bot = max(b[:, 0].max() for b in boxes)
    crops = []
    for p, b, a in zip(fin, boxes, alphas):
        im = Image.open(p).convert("RGB")
        x0, x1 = b[:, 1].min(), b[:, 1].max()
        pad = int(im.width * 0.03)
        crops.append(im.crop((max(x0 - pad, 0), max(top - pad, 0), min(x1 + pad, im.width), min(bot + pad, im.height))))
    H = crops[0].height
    gap = int(H * 0.04)
    label_h = int(H * 0.12)
    W = sum(c.width for c in crops) + gap * (len(crops) + 1) + int(H * 0.34)
    sheet = Image.new("RGB", (W, H + label_h + gap * 2), (255, 255, 255))
    d = ImageDraw.Draw(sheet)
    fb = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
    font = ImageFont.truetype(fb, int(label_h * 0.32))
    purple = (76, 29, 110)
    x = gap
    for c, lab in zip(crops, labels):
        sheet.paste(c, (x, gap))
        tw = d.textlength(lab, font=font)
        cx = x + c.width / 2
        y0 = gap + H + label_h * 0.18
        ph = label_h * 0.55
        d.rounded_rectangle([cx - tw / 2 - ph * 0.6, y0, cx + tw / 2 + ph * 0.6, y0 + ph], radius=ph / 2, fill=purple)
        d.text((cx - tw / 2, y0 + ph * 0.14), lab, font=font, fill=(255, 255, 255))
        x += c.width + gap
    bx = x + int(H * 0.04)
    t0, t1 = gap + pad, gap + H - pad
    d.line([bx, t0, bx, t1], fill=purple, width=max(3, H // 300))
    for yy, sg in ((t0, 1), (t1, -1)):
        d.polygon([(bx - 12, yy + sg * 22), (bx + 12, yy + sg * 22), (bx, yy)], fill=purple)
    f2 = ImageFont.truetype(fb, int(label_h * 0.3))
    d.text((bx + 16, gap + H / 2 - 20), "≈ 1,2 m", font=f2, fill=purple)
    sheet.save(out_path)
    log("[sheet]", out_path)


views = [v for v in args.render.split(",") if v]
S = args.size
if "sheet" in views:
    raw, fin = [], []
    for name, ang in (("front", 0), ("q34", -40), ("side", -90), ("back", 180)):
        p = render(f"orion_{name}", ang, size=(S, S), ortho=2.85, target=(-0.12 if name == "front" else 0, 0.15,
                                                                           1.22), height=2.2)
        raw.append(p)
        fin.append(finish(p))
    compose_sheet(raw, fin, ["Față", "3/4 Față", "Profil (Lateral)", "Spate"],
                  os.path.join(args.out, f"orion_sheet{args.tag}.png"))
if "face" in views:
    p = render(f"orion_face_{args.expr}", 0, size=(S, S), lens=135, dist=6.8, height=1.85, target=(0, -0.1, 1.82))
    finish(p)
if "ears" in views:
    for nm, ang in (("ears_front", 0), ("ears_back", 180), ("ears_side", -90)):
        p = render(nm, ang, size=(600, 600), ortho=1.6, height=2.3, target=(0, 0.05, 2.1))
        finish(p)
if "expr" in views:
    p = render(f"orion_expr_{args.expr}", 0, size=(S, int(S * 1.1)), lens=135, dist=6.9, height=1.95,
               target=(0, -0.1, 1.9))
    finish(p)
if "facecmp" in views:
    p = render(f"orion_facecmp_{args.expr}", 0, size=(480, 660), ortho=1.09, height=1.74, target=(0, -0.1, 1.735))
    finish(p)
if "hero" in views:
    p = render("orion_hero", -32, size=(S, int(S * 1.2)), lens=70, dist=7.6, height=1.55, target=(-0.08, 0.1, 1.2))
    finish(p)

# ----------------------------------------------------------------------------- save
if not args.no_blend:
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(args.out, "orion.blend"), compress=True)
    log("[save] orion.blend")
if not args.no_glb:
    if fur:
        fur.hide_render = True
    for ob in scene.objects:
        ob.select_set(ob.type in ("MESH", "CURVE") and ob.name != "Ground")
    dec = body.modifiers.new("dec", "DECIMATE")
    dec.ratio = 0.12
    root.scale = (0.5, 0.5, 0.5)  # 2.4 units -> 1.2 m
    bpy.context.view_layer.update()
    bpy.ops.export_scene.gltf(filepath=os.path.join(args.out, "orion_game.glb"), use_selection=True,
                              export_apply=True, export_yup=True)
    root.scale = (1, 1, 1)
    body.modifiers.remove(dec)
    log("[save] orion_game.glb")
