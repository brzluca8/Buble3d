"""
Insula 1, v4, Pasul 2: INELUL 1 (tot ce e la ≤ 8 m de drumul căsuțelor) refăcut procedural, 0 credite.
Pornește de la insula din Faza A (blender/out_insula1/insula1_faza_a.glb, din v3_faza_a.py):

  1. coace o hartă pe grilă de 0,25 m (raze verticale pe mesh-ul vechi, pe clase): înălțimea, normala, culoarea
     pictată, apa;
  2. estimează solul (din iarbă și alei plate) și recunoaște clădirile, apa, podurile, malurile; regiunea nouă =
     platoul de lângă drum, fără castel (rămâne cu curtea lui), fără poduri, apă și lagună;
  3. construiește terenul nou pe aceeași hartă (relieful rămâne): grilă netezită, căsuțele pe platforme, margine
     rotunjită cu fustă în jos; culori pe vârfuri: R = AO (raze + umbre de contact false sub recuzită și căsuțe),
     G = pavaj, B = pământ, A = mușchi (măștile vin din culorile pictate pe insula veche);
  4. scoate din mesh-ul vechi ce se înlocuiește: iarba, aleile, florile, frunzișul, pietrele mici, felinarele de pe
     stâlpi și cristalele din regiune, plus resturile mici rămase (trunchiuri, stâlpi);
  5. pune recuzita nouă la locurile celei vechi (3 palmieri, 2 arbori cu flori roz, 1 copac mare, tufe, felinare,
     cristale, garduri, butoaie, lăzi) și presară iarbă, flori și pietricele (MultiMesh în Godot).

    python blender/insula1/v4_inel1.py -- [--src ...] [--raza 8.5]

Ieșiri: godot/assets/models/insula1/insula1.glb (mesh-ul vechi, tăiat), godot/assets/models/insula1/teren.glb,
godot/insula1/data/inel1.gd (pozițiile, în coordonatele Godot), docs/shots/insula_v4_inel1_harta.png (verificare).
"""
import argparse
import io
import json
import math
import os
import re
import sys
import time

import bpy  # noqa: I001  (bpy înainte de bmesh)
import bmesh
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage as ndi
from scipy.cluster.hierarchy import fcluster, linkage
from scipy.sparse import coo_matrix
from scipy.sparse.csgraph import connected_components
from scipy.spatial import cKDTree

Image.MAX_IMAGE_PIXELS = None
T0 = time.time()
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
ap = argparse.ArgumentParser()
ap.add_argument("--src", default=os.path.join(ROOT, "blender/out_insula1/insula1_faza_a.glb"))
ap.add_argument("--out", default=os.path.join(ROOT, "godot/assets/models/insula1/insula1.glb"))
ap.add_argument("--teren", default=os.path.join(ROOT, "godot/assets/models/insula1/teren.glb"))
ap.add_argument("--data", default=os.path.join(ROOT, "godot/insula1/data/inel1.gd"))
ap.add_argument("--info", default=os.path.join(ROOT, "godot/insula1/data/insula1_info.gd"))
ap.add_argument("--shots", default=os.path.join(ROOT, "docs/shots"))
ap.add_argument("--raza", type=float, default=8.5, help="metri de la drumul căsuțelor")
ap.add_argument("--pas", type=float, default=0.25)
ap.add_argument("--seed", type=int, default=7)
ap.add_argument("--fara-export", action="store_true", help="doar analiza și imaginea de verificare")
args = ap.parse_args(argv)
rng = np.random.default_rng(args.seed)
scene = bpy.context.scene

TILES = json.load(open(os.path.join(ROOT, "blender", "out_insula1", "insula1_casute.json")))["casute"]
TB = np.array([[t["x"], -t["z"], t["y"]] for t in TILES])  # căsuțele în coordonatele Blender
NT = len(TB)
CASTEL = np.array([0.25, 0.55])  # centrul castelului (Blender x, y), ca în v3_faza_a.py
CASTEL_R = 4.2                   # insula castelului (cu scări, curte, chiparoși) rămâne piesa castelului
RAZA_CASUTA = 0.84               # raza căsuței noi (0,76 m x 1,1)
CLASE_SOL = ["Insula_restul", "Insula_stanci", "Insula_iarba"]


def log(*a):
    print(f"[{time.time() - T0:7.1f}s]", *a, flush=True)


def ss(e0, e1, x):
    t = np.clip((np.asarray(x, float) - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def gd(p):  # Blender (x, y, z) -> Godot Vector3(x, z, -y)
    return "Vector3(%.3f, %.3f, %.3f)" % (p[0], p[2], -p[1])


# ============================================================================= 1. import + coacere
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
bpy.ops.import_scene.gltf(filepath=args.src)
OB = {o.name: o for o in scene.objects if o.type == "MESH"}
log("[import]", {k: len(o.data.polygons) for k, o in OB.items()})
img = next(n.image for n in OB["Insula_restul"].data.materials[0].node_tree.nodes
           if n.type == "TEX_IMAGE" and "albedo" in n.image.name)
ALB = np.asarray(Image.open(io.BytesIO(img.packed_file.data)).convert("RGB")).astype(np.float32) / 255.0
AH, AW = ALB.shape[:2]


class Plasa:
    """mesh-ul unui obiect în coordonate de lume: BVH, centrele, normalele și culoarea fețelor"""

    def __init__(self, o):
        self.o = o
        bm = bmesh.new()
        bm.from_mesh(o.data)
        bm.transform(o.matrix_world)
        bm.faces.ensure_lookup_table()
        self.bm = bm
        self.bvh = BVHTree.FromBMesh(bm)
        self.uv = bm.loops.layers.uv.active

    def culoare(self, idx, loc):
        f = self.bm.faces[idx]
        if self.uv is None or len(f.loops) != 3:
            return np.zeros(3)
        a, b, c = [lp.vert.co for lp in f.loops]
        v0, v1, v2 = b - a, c - a, loc - a
        d00, d01, d11, d20, d21 = v0.dot(v0), v0.dot(v1), v1.dot(v1), v2.dot(v0), v2.dot(v1)
        den = d00 * d11 - d01 * d01
        if abs(den) < 1e-14:
            return np.zeros(3)
        v = (d11 * d20 - d01 * d21) / den
        w = (d00 * d21 - d01 * d20) / den
        u = 1 - v - w
        uv = f.loops[0][self.uv].uv * u + f.loops[1][self.uv].uv * v + f.loops[2][self.uv].uv * w
        return ALB[int(np.clip((1 - uv.y) * AH, 0, AH - 1)), int(np.clip(uv.x * AW, 0, AW - 1))]


P = {k: Plasa(o) for k, o in OB.items()}
X = np.arange(-9.5, 11.0 + 1e-6, args.pas)
Y = np.arange(-12.5, 12.0 + 1e-6, args.pas)
NX, NY = len(X), len(Y)
XX, YY = np.meshgrid(X, Y)
jos = Vector((0.0, 0.0, -1.0))
zt = np.full((NY, NX), -99.0)
ci = np.full((NY, NX), -1)
nz = np.zeros((NY, NX))
col = np.zeros((NY, NX, 3))
zw = np.full((NY, NX), np.nan)
for j in range(NY):
    for i in range(NX):
        o_ = Vector((X[i], Y[j], 40.0))
        for k, nume in enumerate(CLASE_SOL):
            loc, nrm, idx, _ = P[nume].bvh.ray_cast(o_, jos)
            if loc is not None and loc.z > zt[j, i]:
                zt[j, i] = loc.z
                ci[j, i] = k
                fn = P[nume].bm.faces[idx].normal
                nz[j, i] = fn.z
                col[j, i] = P[nume].culoare(idx, loc)
        loc, _, _, _ = P["Apa"].bvh.ray_cast(o_, jos)
        if loc is not None:
            zw[j, i] = loc.z
log("[harta] grilă %d x %d (%.2f m), celule cu sol %d, cu apă %d" % (NX, NY, args.pas, int((ci >= 0).sum()),
                                                                     int(np.isfinite(zw).sum())))

# ============================================================================= 2. solul, clădirile, apa, regiunea


def dist_drum(px, py):
    d = np.full(np.shape(px), 1e9)
    for i in range(NT):
        a, b = TB[i, :2], TB[(i + 1) % NT, :2]
        ab = b - a
        t = np.clip(((px - a[0]) * ab[0] + (py - a[1]) * ab[1]) / (ab @ ab), 0, 1)
        d = np.minimum(d, np.hypot(px - a[0] - t * ab[0], py - a[1] - t * ab[1]))
    return d


def nconv(vals, w, sigma):
    num = ndi.gaussian_filter(np.where(w > 0, vals * w, 0.0), sigma)
    den = ndi.gaussian_filter(w.astype(float), sigma)
    return num / np.maximum(den, 1e-6), den


DP = dist_drum(XX, YY)
are = ci >= 0
apa = np.isfinite(zw) & (~are | (zw > zt - 0.08))
# poduri: o punte joasă peste apa șanțului (nivel -1,2...-1,7). Platoul care trece pe deasupra lagunei (apa e cu
# 2-3 m mai jos, sub stâncă) nu e pod: fiecare clasă e lovită separat de rază, deci apa de dedesubt se vede mereu.
pod = np.isfinite(zw) & are & ~apa & (zw > -1.95) & (zt - zw < 2.5)
sol = are & ~apa & ~pod
iarba = sol & (ci == 2) & (nz > 0.6)
Hg, den = nconv(np.where(sol, zt, 0.0), iarba.astype(float), 4.0)
S = iarba | (sol & (nz > 0.55) & (np.abs(zt - Hg) < 0.5) & (den > 0.02))
for _ in range(2):
    Hs, den = nconv(np.where(sol, zt, 0.0), S.astype(float), 2.0)
    S = iarba | (sol & (nz > 0.5) & (np.abs(zt - Hs) < 0.45) & (den > 0.02))
H, den = nconv(np.where(S, zt, 0.0), S.astype(float), 1.2)
Hlarg, den_l = nconv(np.where(S, zt, 0.0), S.astype(float), 6.0)
H = np.where(den > 0.05, H, Hlarg)
H = np.where(S, 0.6 * zt + 0.4 * H, H)
obiect = sol & ~S & (zt > H + 0.35)          # clădiri, ziduri, stânci mari, copaci (vârful lor)
cadere = sol & ~S & (zt < H - 0.5)           # maluri și faleze: sub nivelul platoului
# găurile mici (discurile căsuțelor vechi scoase, golurile de sub flori și copaci) nu sunt maluri
lab_c, n_c = ndi.label(cadere | (~are & ~apa & ~pod))
if n_c:
    mar_c = ndi.sum(np.ones_like(lab_c), lab_c, range(1, n_c + 1))
    margini_grila = set(np.unique(np.concatenate([lab_c[0], lab_c[-1], lab_c[:, 0], lab_c[:, -1]])))
    gaura = np.isin(lab_c, [k + 1 for k in range(n_c) if mar_c[k] < 70 and (k + 1) not in margini_grila])
    cadere &= ~gaura
valid = (den > 0.05) | ((den_l > 0.02) & obiect)
castel = np.hypot(XX - CASTEL[0], YY - CASTEL[1]) < CASTEL_R
reg = valid & ~apa & ~ndi.binary_dilation(pod, iterations=2) & ~castel & (H >= -0.9) & (DP <= args.raza) & ~cadere
reg = ndi.binary_closing(reg, iterations=1) & ~apa & ~castel & valid
reg = ndi.binary_opening(reg, iterations=1)
lab, nlab = ndi.label(reg)
if nlab:
    marimi = ndi.sum(np.ones_like(lab), lab, range(1, nlab + 1))
    reg = np.isin(lab, [k + 1 for k in range(nlab) if marimi[k] >= 40])
reg = ndi.binary_fill_holes(reg) & ~apa & ~castel
log("[regiune] celule: sol %d, eșantioane %d, obiecte %d, maluri %d, poduri %d -> regiunea nouă %d (%.0f m2)" % (
    int(sol.sum()), int(S.sum()), int(obiect.sum()), int(cadere.sum()), int(pod.sum()), int(reg.sum()),
    reg.sum() * args.pas ** 2))

# măștile de culoare din pictura veche (pe celulele de sol): pavaj (piatră deschisă), pământ (bej-maro), iarbă
rgb = col.copy()
mx, mn = rgb.max(-1), rgb.min(-1)
val = mx
sat = np.where(mx > 1e-6, (mx - mn) / np.maximum(mx, 1e-6), 0)
hue = np.zeros_like(mx)
d_ = np.maximum(mx - mn, 1e-6)
r_, g_, b_ = rgb[..., 0], rgb[..., 1], rgb[..., 2]
hue = np.where(mx == r_, ((g_ - b_) / d_) % 6, np.where(mx == g_, (b_ - r_) / d_ + 2, (r_ - g_) / d_ + 4)) * 60
verde = (hue > 55) & (hue < 170) & (sat > 0.22)
pav = ~verde & (((sat < 0.30) & (val > 0.5)) | ((hue >= 18) & (hue <= 58) & (sat < 0.42) & (val > 0.62)))
pam = ~verde & ~pav & (hue >= 12) & (hue <= 55) & (sat >= 0.25) & (val > 0.3)
sursa = S | (sol & ~obiect)
m_pav, _ = nconv(pav.astype(float), sursa.astype(float), 1.0)
m_pam, _ = nconv(pam.astype(float), sursa.astype(float), 1.0)
m_pav = ss(0.35, 0.7, m_pav)
m_pam = ss(0.35, 0.7, m_pam) * (1 - m_pav)
# mușchi: lângă maluri, apă și baza clădirilor/stâncilor
lang = ndi.binary_dilation(cadere | apa, iterations=2).astype(float) + 0.4 * ndi.binary_dilation(obiect, iterations=1)
m_mus = ss(0.25, 0.75, ndi.gaussian_filter(np.clip(lang, 0, 1), 1.0)) * (1 - m_pav) * 0.85

# înălțimile terenului: netezite ușor (scoate „hârtia boțită”), căsuțele pe platforme
Hr = ndi.gaussian_filter(np.where(valid, H, 0.0), 0.8) / np.maximum(ndi.gaussian_filter(valid.astype(float), 0.8), 1e-6)
Hr = np.where(valid, Hr, H)
for t in TB:
    d = np.hypot(XX - t[0], YY - t[1])
    w = ss(1.55, 0.95, d)
    Hr = Hr * (1 - w) + (t[2] - 0.03) * w
    m_pav *= 1 - ss(1.25, 0.9, d) * 0.6  # sub căsuță nu contează pavajul; în jur rămâne cum era
# margine: puțin peste suprafața veche care rămâne dincolo (fără fante), fusta coboară sub ea
interior = ndi.binary_erosion(reg, iterations=1)
margine = reg & ~interior
Hr = np.where(margine & sol, np.maximum(Hr, zt + 0.02), Hr)

# ============================================================================= 3. recuzita: unde stătea cea veche


def bilin(A, x, y):
    fx = np.clip((np.asarray(x) - X[0]) / args.pas, 0, NX - 1.001)
    fy = np.clip((np.asarray(y) - Y[0]) / args.pas, 0, NY - 1.001)
    i0, j0 = np.floor(fx).astype(int), np.floor(fy).astype(int)
    tx, ty = fx - i0, fy - j0
    return (A[j0, i0] * (1 - tx) * (1 - ty) + A[j0, i0 + 1] * tx * (1 - ty) + A[j0 + 1, i0] * (1 - tx) * ty +
            A[j0 + 1, i0 + 1] * tx * ty)


def in_reg(x, y, R=None):
    R = reg if R is None else R
    i = np.clip(np.round((np.asarray(x) - X[0]) / args.pas).astype(int), 0, NX - 1)
    j = np.clip(np.round((np.asarray(y) - Y[0]) / args.pas).astype(int), 0, NY - 1)
    ok = (np.asarray(x) >= X[0]) & (np.asarray(x) <= X[-1]) & (np.asarray(y) >= Y[0]) & (np.asarray(y) <= Y[-1])
    return R[j, i] & ok


def fete(nume):
    """centrele, normalele, ariile și culorile fețelor (coordonate de lume)"""
    bm = P[nume].bm
    c = np.array([f.calc_center_median()[:] for f in bm.faces])
    n = np.array([f.normal[:] for f in bm.faces])
    a = np.array([f.calc_area() for f in bm.faces])
    return c, n, a


reg_larg = ndi.binary_dilation(reg, iterations=2) & ~castel
# copacii și tufele vechi: harta înălțimii coroanelor (frunziș + flori) deasupra terenului, apoi vârfurile locale
coroana = np.zeros((NY, NX))
coroana_roz = np.zeros((NY, NX))  # doar florile (clasa roz): coroanele arborilor înfloriți
a_roz = np.zeros((NY, NX))
a_verde = np.zeros((NY, NX))
for nume in ("Insula_frunzis", "Insula_flori"):
    c, n, a = fete(nume)
    m = in_reg(c[:, 0], c[:, 1], reg_larg)
    h = c[m, 2] - bilin(Hr, c[m, 0], c[m, 1])
    ii_ = np.clip(np.round((c[m, 0] - X[0]) / args.pas).astype(int), 0, NX - 1)
    jj_ = np.clip(np.round((c[m, 1] - Y[0]) / args.pas).astype(int), 0, NY - 1)
    np.maximum.at(coroana, (jj_, ii_), np.clip(h, 0, 8))
    if nume == "Insula_flori":
        np.maximum.at(coroana_roz, (jj_, ii_), np.clip(h, 0, 8))
    np.add.at(a_roz if nume == "Insula_flori" else a_verde, (jj_, ii_), a[m])
# florile roz de pe arbori sunt și ele pictate pe frunziș: culoarea fețelor contează, nu doar clasa
cor_n = ndi.gaussian_filter(ndi.maximum_filter(coroana, 3), 1.0)
roz_n = ndi.gaussian_filter(a_roz, 2.0) / np.maximum(ndi.gaussian_filter(a_roz + a_verde, 2.0), 1e-6)
grupuri = []
for prag, fer, tip_g in ((1.6, 9, "copac"), (0.35, 5, "tufa")):
    vf = (cor_n == ndi.maximum_filter(cor_n, fer)) & (cor_n > prag) & reg_larg
    for j, i in zip(*np.where(vf)):
        h = float(cor_n[j, i])
        if tip_g == "tufa" and h > 1.6:
            continue
        zona = cor_n[max(0, j - 8):j + 9, max(0, i - 8):i + 9] > h * 0.5
        grupuri.append(dict(c=np.array([X[i], Y[j]]), h=h, raza=float(np.sqrt(zona.sum() / np.pi) * args.pas),
                            roz=float(roz_n[j, i]), tip=tip_g, arie=float(zona.sum() * args.pas ** 2)))
# arborii roz: vârfurile coroanelor de flori (peste 1,1 m), cât mai mari
cr_n = ndi.gaussian_filter(ndi.maximum_filter(coroana_roz, 3), 1.0)
vf = (cr_n == ndi.maximum_filter(cr_n, 11)) & (cr_n > 1.1) & reg_larg
ROZ_VECHI = []
for j, i in zip(*np.where(vf)):
    zona = cr_n[max(0, j - 8):j + 9, max(0, i - 8):i + 9] > cr_n[j, i] * 0.5
    ROZ_VECHI.append(dict(c=np.array([X[i], Y[j]]), h=float(cr_n[j, i]), raza=float(np.sqrt(zona.sum() / np.pi) * args.pas),
                          roz=1.0, tip="copac", arie=float(zona.sum() * args.pas ** 2)))
ROZ_VECHI.sort(key=lambda g: -g["arie"])
log("[recuzită] coroane roz vechi (arbori înfloriți): %s" % [(np.round(g["c"], 1).tolist(), round(g["h"], 1)) for g in ROZ_VECHI[:5]])
grupuri.sort(key=lambda g: -g["arie"])
log("[recuzită] vârfuri de coroană vechi în regiune: copaci %d, tufe %d (copaci: %s)" % (
    sum(g["tip"] == "copac" for g in grupuri), sum(g["tip"] == "tufa" for g in grupuri),
    [(round(g["h"], 1), round(g["raza"], 1), round(g["roz"], 2)) for g in grupuri if g["tip"] == "copac"][:12]))


def departe_de_casute(p, dmin):
    """împinge punctul p (x, y) în afara cercurilor căsuțelor (dmin de la centru)"""
    p = np.array(p, float)
    for _ in range(4):
        d = np.hypot(TB[:, 0] - p[0], TB[:, 1] - p[1])
        k = int(np.argmin(d))
        if d[k] >= dmin:
            break
        v = p - TB[k, :2]
        if np.linalg.norm(v) < 1e-3:
            v = np.array([1.0, 0.0])
        p = TB[k, :2] + v / np.linalg.norm(v) * dmin
    return p


ocupat = []  # (x, y, raza): recuzita pusă deja (nu se suprapune)


obiect_larg = ndi.binary_dilation(obiect, iterations=2)


def liber(p, r):
    if in_reg(p[0], p[1], obiect_larg):
        return False
    return all(np.hypot(p[0] - q[0], p[1] - q[1]) >= r + q[2] for q in ocupat) and \
        np.hypot(TB[:, 0] - p[0], TB[:, 1] - p[1]).min() >= RAZA_CASUTA + r * 0.6


COPACI = []  # (tip, x, y, z, rot, scară)
cand = [g for g in grupuri if g["tip"] == "copac"]
roz_c = ROZ_VECHI[:2]
verzi = [g for g in cand if all(np.hypot(*(g["c"] - r["c"])) > 1.5 for r in roz_c)]
mare = verzi[:1]
rest_v = sorted(verzi[1:], key=lambda g: -np.hypot(*(g["c"] - CASTEL)))  # palmierii stau spre margini
palmieri = sorted(rest_v[:5], key=lambda g: -g["h"])[:3]
def departe_de_cladiri(p, r=0.5):
    """dacă trunchiul ar intra într-o clădire, îl mutăm în cea mai apropiată celulă liberă (cel mult 1,6 m)"""
    if not in_reg(p[0], p[1], obiect_larg) and in_reg(p[0], p[1]):
        return p
    lib = reg & ~obiect_larg
    jj, ii = np.where(lib)
    d = np.hypot(X[ii] - p[0], Y[jj] - p[1])
    k = int(np.argmin(d))
    return np.array([X[ii[k]], Y[jj[k]]]) if d[k] < 1.6 else p


for tip, lista, r in (("copac_mare", mare, 1.5), ("arbore_roz", roz_c, 1.1), ("palmier", palmieri, 0.9)):
    for g in lista:
        p = departe_de_cladiri(departe_de_casute(g["c"], RAZA_CASUTA + r * 0.8))
        z = float(bilin(Hr, p[0], p[1]))
        sc = float(np.clip(g["h"] / {"copac_mare": 4.2, "arbore_roz": 3.2, "palmier": 4.0}[tip], 0.8, 1.25))
        COPACI.append((tip, p[0], p[1], z, float(rng.uniform(0, 2 * np.pi)), sc))
        ocupat.append((p[0], p[1], r * 0.7))
# dacă lipsesc (n-au fost găsite destule în model), completăm pe margini, departe de drum
nevoie = {"copac_mare": 1, "arbore_roz": 2, "palmier": 3}
rezerva = {"arbore_roz": [13, 4], "palmier": [16, 2, 10], "copac_mare": [8]}
for tip, n_ in nevoie.items():
    while sum(1 for c_ in COPACI if c_[0] == tip) < n_:
        prefer = list(rezerva[tip])
        for incercare in range(400):
            k = prefer.pop(0) if prefer and incercare % 40 == 0 else rng.integers(NT)
            v = TB[k, :2] - CASTEL
            p = TB[k, :2] + v / np.linalg.norm(v) * rng.uniform(1.8, 3.2)
            if in_reg(p[0], p[1], ndi.binary_erosion(reg, iterations=3)) and liber(p, 1.0):
                break
        COPACI.append((tip, p[0], p[1], float(bilin(Hr, p[0], p[1])), float(rng.uniform(0, 2 * np.pi)), 1.0))
        ocupat.append((p[0], p[1], 0.8))
TUFE = []  # (x, y, z, rot, scară, varianta)
for g in sorted(grupuri, key=lambda g: (g["tip"] != "tufa", -g["arie"])):
    if len(TUFE) >= 16:
        break
    if any(np.hypot(*(g["c"] - np.array(c_[1:3]))) < 1.4 for c_ in COPACI):
        continue
    p = departe_de_casute(g["c"], RAZA_CASUTA + 0.5)
    if not in_reg(p[0], p[1]) or not liber(p, 0.45):
        continue
    sc = float(np.clip(0.7 + g["raza"] * 0.5, 0.75, 1.35))
    TUFE.append((p[0], p[1], float(bilin(Hr, p[0], p[1])), float(rng.uniform(0, 2 * np.pi)), sc, int(rng.integers(3))))
    ocupat.append((p[0], p[1], 0.45 * sc))
log("[recuzită] copaci %s, tufe %d" % ([c_[0] for c_ in COPACI], len(TUFE)))

# felinarele vechi de pe stâlpi (stau pe sol, în regiune): componente din clasa felinare
FEL_SCOASE = []
c, n, a = fete("Insula_felinare")
bm = P["Insula_felinare"].bm
vi = {v: k for k, v in enumerate(bm.verts)}
co = np.array([v.co[:] for v in bm.verts])
fv = [[vi[v] for v in f.verts] for f in bm.faces]
_, w = np.unique(np.round(co / 1e-4).astype(np.int64), axis=0, return_inverse=True)
w = w.ravel()
e = np.array([[w[f[k]], w[f[(k + 1) % len(f)]]] for f in fv for k in range(len(f))])
g_ = coo_matrix((np.ones(len(e)), (e[:, 0], e[:, 1])), shape=(w.max() + 1, w.max() + 1))
_, labw = connected_components(g_, directed=False)
flab = np.array([labw[w[f[0]]] for f in fv])
FELINARE = []
for k in np.unique(flab):
    m = flab == k
    pz = co[np.unique(np.concatenate([np.array(fv[q]) for q in np.where(m)[0]]))]
    cen = pz.mean(0)
    base = float(bilin(Hr, cen[0], cen[1]))
    if in_reg(cen[0], cen[1]) and pz[:, 2].min() < base + 0.6 and pz[:, 2].max() - pz[:, 2].min() > 0.25:
        FEL_SCOASE.append(k)
        p = departe_de_casute(cen[:2], RAZA_CASUTA + 0.3)
        if all(np.hypot(p[0] - q[0], p[1] - q[1]) > 1.4 for q in FELINARE):
            FELINARE.append((p[0], p[1], float(bilin(Hr, p[0], p[1]))))
fel_scoase = np.isin(flab, FEL_SCOASE)
# completăm felinare de-a lungul drumului (ca în imaginea-țintă: cam la fiecare 3 căsuțe, pe partea dinspre margine)
for k in range(0, NT, 3):
    v = TB[k, :2] - CASTEL
    v /= np.linalg.norm(v)
    nxt = TB[(k + 1) % NT, :2] - TB[k, :2]
    p = (TB[k, :2] + TB[(k + 1) % NT, :2]) / 2 + v * 1.15
    if in_reg(p[0], p[1]) and all(np.hypot(p[0] - q[0], p[1] - q[1]) > 2.2 for q in FELINARE) and liber(p, 0.2):
        FELINARE.append((p[0], p[1], float(bilin(Hr, p[0], p[1]))))
for p in FELINARE:
    ocupat.append((p[0], p[1], 0.2))
log("[recuzită] felinare pe stâlpi: %d vechi scoase, %d noi" % (len(FEL_SCOASE), len(FELINARE)))

# cristalele vechi din regiune -> grupuri noi (3 variante)
c, n, a = fete("Insula_cristale")
m = in_reg(c[:, 0], c[:, 1], reg_larg)
CRISTALE = []
if m.sum() > 1:
    lab_c = fcluster(linkage(c[m, :2], "single"), 0.6, "distance")
    for k in np.unique(lab_c):
        q = c[m][lab_c == k]
        p = departe_de_casute(q[:, :2].mean(0), RAZA_CASUTA + 0.35)
        CRISTALE.append((p[0], p[1], float(bilin(Hr, p[0], p[1])), float(rng.uniform(0, 2 * np.pi)),
                         float(np.clip(0.8 + a[m][lab_c == k].sum() * 0.6, 0.8, 1.5)), int(rng.integers(3))))
log("[recuzită] cristale: %d grupuri" % len(CRISTALE))

# garduri: pe partea dinspre margine a drumului, unde platoul continuă (ca la moară și lângă copacul mare)
GARDURI = []
for k0, k1 in ((8, 11), (13, 15), (1, 3)):
    puncte = []
    for k in range(k0, k1 + 1):
        v = TB[k % NT, :2] - CASTEL
        v /= np.linalg.norm(v)
        puncte.append(TB[k % NT, :2] + v * 1.55)
    for a_, b_ in zip(puncte[:-1], puncte[1:]):
        L = np.hypot(*(b_ - a_))
        nseg = max(1, int(round(L / 1.2)))
        for s in range(nseg):
            p0 = a_ + (b_ - a_) * s / nseg
            p1 = a_ + (b_ - a_) * (s + 1) / nseg
            pm = (p0 + p1) / 2
            if in_reg(pm[0], pm[1], ndi.binary_erosion(reg, iterations=1)) and liber(pm, 0.3):
                GARDURI.append((p0[0], p0[1], float(bilin(Hr, *p0)), p1[0], p1[1], float(bilin(Hr, *p1))))
for gq in GARDURI:
    ocupat.append(((gq[0] + gq[3]) / 2, (gq[1] + gq[4]) / 2, 0.45))
log("[recuzită] segmente de gard: %d" % len(GARDURI))

# butoaie și lăzi: lângă clădiri (piață, moară, atelier), nu pe drum
lang_cladire = ndi.binary_dilation(obiect & ~castel, iterations=4) & ~ndi.binary_dilation(obiect, iterations=1) & \
    ndi.binary_erosion(reg, iterations=1)
jj, ii = np.where(lang_cladire)
ordine = rng.permutation(len(jj))
BUTOAIE, LAZI = [], []
for q in ordine:
    if len(BUTOAIE) >= 5 and len(LAZI) >= 5:
        break
    p = np.array([X[ii[q]], Y[jj[q]]]) + rng.uniform(-0.1, 0.1, 2)
    if np.hypot(TB[:, 0] - p[0], TB[:, 1] - p[1]).min() < RAZA_CASUTA + 0.55 or not liber(p, 0.35):
        continue
    z = float(bilin(Hr, p[0], p[1]))
    if len(BUTOAIE) <= len(LAZI) and len(BUTOAIE) < 5:
        BUTOAIE.append((p[0], p[1], z, float(rng.uniform(0, 2 * np.pi)), float(rng.uniform(0.9, 1.1))))
    elif len(LAZI) < 5:
        LAZI.append((p[0], p[1], z, float(rng.uniform(0, 2 * np.pi)), float(rng.uniform(0.85, 1.1))))
    else:
        continue
    ocupat.append((p[0], p[1], 0.35))
    # a doua piesă alături, ca grupurile din imaginea-țintă
    p2 = p + rng.uniform(-0.55, 0.55, 2)
    if liber(p2, 0.3) and in_reg(p2[0], p2[1]) and np.hypot(TB[:, 0] - p2[0], TB[:, 1] - p2[1]).min() > RAZA_CASUTA + 0.5:
        (LAZI if len(LAZI) < len(BUTOAIE) else BUTOAIE).append(
            (p2[0], p2[1], float(bilin(Hr, *p2)), float(rng.uniform(0, 2 * np.pi)), float(rng.uniform(0.8, 1.0))))
        ocupat.append((p2[0], p2[1], 0.3))
log("[recuzită] butoaie %d, lăzi %d" % (len(BUTOAIE), len(LAZI)))

# presărate: iarbă (smocuri), flori, pietricele
d_cas = np.min([np.hypot(XX - t[0], YY - t[1]) for t in TB], axis=0)
loc_iarba = interior & (m_pav < 0.35) & (m_pam < 0.45) & (d_cas > RAZA_CASUTA + 0.12) & \
    ~ndi.binary_dilation(obiect, iterations=1)
flori_vechi = np.zeros((NY, NX))
c, n, a = fete("Insula_flori")
m = in_reg(c[:, 0], c[:, 1], reg_larg)
if m.any():
    ii_ = np.clip(np.round((c[m, 0] - X[0]) / args.pas).astype(int), 0, NX - 1)
    jj_ = np.clip(np.round((c[m, 1] - Y[0]) / args.pas).astype(int), 0, NY - 1)
    np.add.at(flori_vechi, (jj_, ii_), a[m])
flori_vechi = ss(0.0, 0.08, ndi.gaussian_filter(flori_vechi, 1.5))


def presara(masca, densitate, jitter=0.5):
    out = []
    jj, ii = np.where(masca)
    for j, i in zip(jj, ii):
        k = densitate[j, i] if np.ndim(densitate) else densitate
        nn = rng.poisson(k * args.pas ** 2)
        for _ in range(nn):
            x = X[i] + rng.uniform(-jitter, jitter) * args.pas
            y = Y[j] + rng.uniform(-jitter, jitter) * args.pas
            if any(np.hypot(x - q[0], y - q[1]) < q[2] * 0.8 for q in ocupat):
                continue
            out.append((x, y))
    return np.array(out).reshape(-1, 2)


dens_iarba = 4.5 + 5.0 * ss(0.2, 0.8, ndi.gaussian_filter(rng.random((NY, NX)), 3.0) * 4 - 1.5)
IARBA = presara(loc_iarba, dens_iarba)
loc_flori = interior & (d_cas > RAZA_CASUTA + 0.1) & (m_pav < 0.5) & ~ndi.binary_dilation(obiect, iterations=1)
FLORI = presara(loc_flori, 0.6 + 9.0 * flori_vechi + 1.6 * ss(1.7, 1.0, d_cas))
loc_piet = interior & (d_cas > RAZA_CASUTA + 0.05) & ~ndi.binary_dilation(obiect, iterations=1)
PIETRE = presara(loc_piet, 0.35 + 2.0 * ss(0.4, 0.9, m_pam + m_mus * 0.5) + 1.4 * ss(1.3, 0.95, d_cas))
log("[presărate] smocuri de iarbă %d, flori %d, pietricele %d" % (len(IARBA), len(FLORI), len(PIETRE)))
# locurile peștilor care sar: apă deschisă în laguna bărcii (la nivelul ei), departe de mal și de barcă
info_txt = open(args.info).read()
barca = [float(v) for v in re.search(r"BARCA_PIVOT := Vector3\(([^)]*)\)", info_txt).group(1).split(",")]
bx_, by_, bz_ = barca[0], -barca[2], barca[1]
lac = apa & (np.abs(np.nan_to_num(zw, nan=-99) - bz_) < 0.12)
lac_int = ndi.binary_erosion(lac, iterations=1)
log("[viață] celule de lagună: %d, în interior: %d (nivel %.2f)" % (int(lac.sum()), int(lac_int.sum()), bz_))
jj, ii = np.where(lac_int)
PESTI = []
for k in rng.permutation(len(jj)):
    x_, y_ = X[ii[k]], Y[jj[k]]
    if np.hypot(x_ - bx_, y_ - by_) > 1.0 and all(np.hypot(x_ - q[0], y_ - q[1]) > 1.2 for q in PESTI):
        PESTI.append((x_, y_, float(zw[jj[k], ii[k]])))
    if len(PESTI) >= 2:
        break
log("[viață] locuri pentru pești în lagună: %d" % len(PESTI))

# ============================================================================= 4. tăierea mesh-ului vechi
reg_scos = ndi.binary_erosion(reg, iterations=1)  # pe margine rămâne suprafața veche, sub marginea terenului nou
scoase = {}
for nume in ["Insula_iarba", "Insula_restul", "Insula_stanci", "Insula_flori", "Insula_frunzis", "Insula_felinare",
             "Insula_cristale"]:
    c, n, a = fete(nume)
    h = c[:, 2] - bilin(Hr, c[:, 0], c[:, 1])
    ir = in_reg(c[:, 0], c[:, 1], reg_scos)
    if nume == "Insula_iarba":
        m = ir & (h < 0.6)
    elif nume == "Insula_restul":
        m = ir & (n[:, 2] > 0.5) & (h < 0.3)
    elif nume == "Insula_stanci":
        m = ir & (h < 0.35)
    elif nume in ("Insula_flori", "Insula_frunzis", "Insula_cristale"):
        m = in_reg(c[:, 0], c[:, 1], reg_larg) & (h < 6.0)
    else:  # felinare: doar cele de pe stâlpi
        m = fel_scoase.copy()
    scoase[nume] = m
log("[tăiere] fețe de scos: %s" % {k: int(v.sum()) for k, v in scoase.items()})


def sterge_fete(nume, masca):
    o = OB[nume]
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bm.faces.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[bm.faces[i] for i in np.where(masca)[0]], context="FACES")
    bm.to_mesh(o.data)
    bm.free()
    o.data.update()


for nume, m in scoase.items():
    sterge_fete(nume, m)


# resturile mici rămase în regiune (trunchiuri, stâlpi, bucăți de gard și de pietre): componente mici, scoase
def curata(nume, arie_max=1.6):
    o = OB[nume]
    me = o.data
    if not len(me.polygons):
        return 0
    co = np.array([o.matrix_world @ v.co for v in me.vertices])
    fv = [list(p.vertices) for p in me.polygons]
    _, w = np.unique(np.round(co / 1e-4).astype(np.int64), axis=0, return_inverse=True)
    w = w.ravel()
    e = np.array([[w[f[k]], w[f[(k + 1) % len(f)]]] for f in fv for k in range(len(f))])
    g_ = coo_matrix((np.ones(len(e)), (e[:, 0], e[:, 1])), shape=(w.max() + 1, w.max() + 1))
    _, labw = connected_components(g_, directed=False)
    flab = np.array([labw[w[f[0]]] for f in fv])
    area = np.array([p.area for p in me.polygons])
    cen = np.array([np.mean(co[f], 0) for f in fv])
    A = np.bincount(flab, area)
    cx = np.bincount(flab, cen[:, 0] * area) / np.maximum(A, 1e-9)
    cy = np.bincount(flab, cen[:, 1] * area) / np.maximum(A, 1e-9)
    mici = (A < arie_max) & in_reg(cx, cy, reg_scos)
    m = mici[flab]
    if m.any():
        sterge_fete(nume, m)
    return int(m.sum())


log("[tăiere] resturi mici scoase: restul %d, stânci %d, felinare %d" % (
    curata("Insula_restul"), curata("Insula_stanci", 0.9), curata("Insula_felinare", 0.5)))
# flăcările rămase (halourile felinarelor care n-au fost înlocuite)
info = open(args.info).read()
fl = [[float(v) for v in t.split(",")] for t in re.findall(r"Vector3\(([^)]*)\)", re.search(r"FLACARI[^=]*= \[(.*?)\n\]", info, re.S).group(1))]
FLACARI_RAMASE = []
for p in fl:
    bx, by, bz = p[0], -p[2], p[1]
    if not in_reg(bx, by, reg_larg) or bz > float(bilin(Hr, bx, by)) + 2.2:
        FLACARI_RAMASE.append((bx, by, bz))
log("[tăiere] flăcări (halouri) rămase pe clădiri: %d din %d" % (len(FLACARI_RAMASE), len(fl)))

# ============================================================================= 5. terenul nou
idx = -np.ones((NY, NX), int)
jj, ii = np.where(reg)
idx[jj, ii] = np.arange(len(jj))
V = np.stack([X[ii], Y[jj], Hr[jj, ii]], 1)
F = []
for j in range(NY - 1):
    for i in range(NX - 1):
        a_, b_, c_, d_ = idx[j, i], idx[j, i + 1], idx[j + 1, i + 1], idx[j + 1, i]
        if min(a_, b_, c_, d_) < 0:
            continue
        if abs(V[a_, 2] - V[c_, 2]) <= abs(V[b_, 2] - V[d_, 2]):
            F += [(a_, b_, c_), (a_, c_, d_)]
        else:
            F += [(a_, b_, d_), (b_, c_, d_)]
F = np.array(F)
folosit = np.unique(F)
remap = -np.ones(len(V), int)
remap[folosit] = np.arange(len(folosit))
V = V[folosit]
F = remap[F]
# marginea: muchii folosite de o singură față
E = np.sort(np.concatenate([F[:, [0, 1]], F[:, [1, 2]], F[:, [2, 0]]]), 1)
ek, cnt = np.unique(E, axis=0, return_counts=True)
bord = ek[cnt == 1]
vec = {}
for a_, b_ in bord:
    vec.setdefault(a_, []).append(b_)
    vec.setdefault(b_, []).append(a_)
V0 = V.copy()
for _ in range(3):  # rotunjim conturul în trepte al celulelor
    nou = V.copy()
    for v, nb in vec.items():
        nou[v, :2] = V[v, :2] + 0.5 * (V[nb, :2].mean(0) - V[v, :2])
    V = nou
# fără triunghiuri întoarse: unde netezirea a împins un vârf de margine peste vecinii lui, îl punem la loc
for _ in range(6):
    A3 = V[F]
    nzf = np.cross(A3[:, 1] - A3[:, 0], A3[:, 2] - A3[:, 0])[:, 2]
    rele = np.unique(F[nzf <= 1e-4].ravel())
    rele = [v for v in rele if v in vec]
    if not rele:
        break
    V[rele, :2] = V0[rele, :2]
for v in vec:
    V[v, 2] = max(float(bilin(Hr, V[v, 0], V[v, 1])), V[v, 2] - 0.01)
# culori pe vârfuri
Mpav = bilin(m_pav, V[:, 0], V[:, 1])
Mpam = bilin(m_pam, V[:, 0], V[:, 1])
Mmus = bilin(m_mus, V[:, 0], V[:, 1])
bm = bmesh.new()
bv = [bm.verts.new(p) for p in V]
for f in F:
    try:
        bm.faces.new([bv[k] for k in f])
    except ValueError:
        pass
bm.verts.ensure_lookup_table()
bm.normal_update()
# fusta: coboară 0,45 m sub fiecare muchie de margine, puțin în afară
fusta = {}
fusta_sus = {}
for v in vec:
    nb = vec[v]
    t_ = V[nb[0], :2] - V[nb[-1], :2]
    out = np.array([t_[1], -t_[0]])
    out /= max(np.linalg.norm(out), 1e-9)
    # sensul spre exterior: departe de centrul fețelor vecine
    fc = np.mean([np.mean([V[k.index] for k in f_.verts], 0)[:2] for f_ in bv[v].link_faces], 0)
    if np.dot(out, V[v, :2] - fc) < 0:
        out = -out
    fusta[v] = bm.verts.new((V[v, 0] + out[0] * 0.04, V[v, 1] + out[1] * 0.04, V[v, 2] - 0.45))
    fusta_sus[v] = bm.verts.new(tuple(V[v]))  # vârf separat: fusta își are normalele ei (orizontale), muchie vie sus
# fața de fustă de sub muchia u->v (în sensul feței de sus, care e trigonometric privit de sus) e [v, u, u', v']:
# extrudarea în jos a marginii, cu normala spre exterior, fără să mai ghicim sensul
dirijate = {}
for f in F:
    for k in range(3):
        dirijate[(int(f[k]), int(f[(k + 1) % 3]))] = True
n_fusta = 0
for a_, b_ in bord:
    u, v = (int(a_), int(b_)) if (int(a_), int(b_)) in dirijate else (int(b_), int(a_))
    try:
        bm.faces.new([fusta_sus[v], fusta_sus[u], fusta[u], fusta[v]])
        n_fusta += 1
    except ValueError:
        continue
bm.verts.ensure_lookup_table()
bm.verts.index_update()
bm.normal_update()
fusta_idx = {v: fv_.index for v, fv_ in fusta.items()}
fusta_sus_idx = {v: fv_.index for v, fv_ in fusta_sus.items()}
me = bpy.data.meshes.new("Teren")
bm.to_mesh(me)
bm.free()
teren = bpy.data.objects.new("Teren", me)
scene.collection.objects.link(teren)
for p in me.polygons:
    p.use_smooth = True
log("[teren] %d vârfuri, %d triunghiuri + %d fețe de fustă" % (len(V), len(F), n_fusta))

# AO: raze pe emisferă (mesh-ul vechi rămas + terenul), apoi umbre de contact false sub căsuțe și recuzită
lume = []
for nume, o in OB.items():
    if nume in ("Apa", "Cascade"):
        continue
    b2 = bmesh.new()
    b2.from_mesh(o.data)
    b2.transform(o.matrix_world)
    lume.append(BVHTree.FromBMesh(b2))
    b2.free()
b2 = bmesh.new()
b2.from_mesh(me)
lume.append(BVHTree.FromBMesh(b2))
b2.free()
dirs = rng.standard_normal((20, 3))
dirs /= np.linalg.norm(dirs, axis=1, keepdims=True)
nv = len(me.vertices)
co_t = np.array([v.co[:] for v in me.vertices])
no_t = np.array([v.normal[:] for v in me.vertices])
ao = np.ones(nv)
for k in range(nv):
    n_ = Vector(no_t[k])
    o_ = Vector(co_t[k]) + n_ * 0.04
    hit = 0
    for d in dirs:
        dd = Vector(d)
        if dd.dot(n_) < 0:
            dd = -dd
        dd = (dd + n_).normalized()
        for t_ in lume:
            if t_.ray_cast(o_, dd, 2.2)[0] is not None:
                hit += 1
                break
    ao[k] = 1.0 - 0.8 * hit / len(dirs)
umbre = [(t[0], t[1], RAZA_CASUTA + 0.05, 0.42, "inel") for t in TB]
umbre += [(c_[1], c_[2], {"copac_mare": 1.6, "arbore_roz": 1.2, "palmier": 0.8}[c_[0]] * c_[5], 0.38, "disc") for c_ in COPACI]
umbre += [(t[0], t[1], 0.55 * t[4], 0.36, "disc") for t in TUFE]
umbre += [(p[0], p[1], 0.22, 0.4, "disc") for p in FELINARE]
umbre += [(p[0], p[1], 0.42, 0.35, "disc") for p in BUTOAIE + LAZI]
umbre += [(p[0], p[1], 0.4 * p[4], 0.3, "disc") for p in CRISTALE]
umbre += [((g[0] + g[3]) / 2, (g[1] + g[4]) / 2, 0.55, 0.22, "disc") for g in GARDURI]
for x_, y_, r_, k_, fel in umbre:
    d = np.hypot(co_t[:, 0] - x_, co_t[:, 1] - y_)
    if fel == "inel":  # o margine moale de umbră chiar sub buza căsuței
        f_ = np.exp(-((d - r_) / 0.22) ** 2) * (d > r_ - 0.25)
    else:
        f_ = np.exp(-(d / r_) ** 2 * 1.6)
    ao *= 1 - k_ * f_
ao = np.clip(ao, 0.25, 1.0)
rgba = np.stack([ao, np.zeros(nv), np.zeros(nv), np.zeros(nv)], 1)
nb_ = len(V)
rgba[:nb_, 1] = np.clip(Mpav, 0, 1)
rgba[:nb_, 2] = np.clip(Mpam, 0, 1)
rgba[:nb_, 3] = np.clip(Mmus, 0, 1)
for v, k_ in fusta_idx.items():  # fusta: mușchi și stâncă (e abruptă, shaderul pune stâncă)
    rgba[k_, 1:] = [0.0, 0.0, 0.6]
    rgba[k_, 0] = ao[v] * 0.7
    rgba[fusta_sus_idx[v]] = [ao[v], 0.0, 0.0, 0.6]
attr = me.color_attributes.new("Color", "FLOAT_COLOR", "POINT")
attr.data.foreach_set("color", rgba.astype(np.float32).ravel())
me.color_attributes.active_color = attr
log("[teren] AO: medie %.2f, 10%% sub %.2f; pavaj %.0f%%, pământ %.0f%%, mușchi %.0f%%" % (
    ao.mean(), np.percentile(ao, 10), 100 * (rgba[:, 1] > 0.5).mean(), 100 * (rgba[:, 2] > 0.5).mean(),
    100 * (rgba[:, 3] > 0.5).mean()))

# ============================================================================= 6. imaginea de verificare (de sus)
S_ = 7
im = np.ones((NY, NX, 3))
hh = np.clip((Hr + 1.5) / 3.5, 0, 1)
im[valid] = np.stack([hh, hh, hh], -1)[valid] * 0.6 + 0.4
im[reg] = np.stack([0.45 + 0.3 * hh, 0.72 + 0.2 * hh, 0.35 + 0.2 * hh], -1)[reg]
im[reg & (m_pav > 0.5)] = [0.86, 0.78, 0.62]
im[reg & (m_pam > 0.5)] = [0.78, 0.62, 0.42]
im[obiect & ~reg] = [0.75, 0.3, 0.3]
im[obiect & reg] = [0.62, 0.42, 0.36]
im[apa] = [0.25, 0.5, 0.95]
im[pod] = [0.55, 0.45, 0.35]
im[castel & valid] = im[castel & valid] * 0.6 + np.array([0.3, 0.2, 0.4])
pil = Image.fromarray((im[::-1] * 255).astype(np.uint8)).resize((NX * S_, NY * S_), Image.NEAREST)
dr = ImageDraw.Draw(pil)


def px(x, y):
    return ((x - X[0]) / args.pas + 0.5) * S_, ((Y[-1] - y) / args.pas + 0.5) * S_


for x_, y_ in IARBA[::3]:
    a_, b_ = px(x_, y_)
    dr.point((a_, b_), fill=(40, 120, 30))
for x_, y_ in FLORI:
    a_, b_ = px(x_, y_)
    dr.ellipse([a_ - 1.5, b_ - 1.5, a_ + 1.5, b_ + 1.5], fill=(255, 120, 190))
for x_, y_ in PIETRE:
    a_, b_ = px(x_, y_)
    dr.point((a_, b_), fill=(120, 110, 140))
for k, t in enumerate(TB):
    a_, b_ = px(t[0], t[1])
    r_ = RAZA_CASUTA / args.pas * S_
    dr.ellipse([a_ - r_, b_ - r_, a_ + r_, b_ + r_], outline=(150, 90, 20), width=3, fill=(236, 222, 196))
    dr.text((a_ - 6, b_ - 7), str(k), fill=(90, 50, 10))
cul = {"copac_mare": (20, 110, 40), "arbore_roz": (240, 110, 170), "palmier": (90, 170, 40)}
for c_ in COPACI:
    a_, b_ = px(c_[1], c_[2])
    r_ = {"copac_mare": 1.5, "arbore_roz": 1.1, "palmier": 1.0}[c_[0]] * c_[5] / args.pas * S_
    dr.ellipse([a_ - r_, b_ - r_, a_ + r_, b_ + r_], outline=cul[c_[0]], width=4)
for t in TUFE:
    a_, b_ = px(t[0], t[1])
    r_ = 0.5 * t[4] / args.pas * S_
    dr.ellipse([a_ - r_, b_ - r_, a_ + r_, b_ + r_], outline=(30, 130, 50), width=2)
for p in FELINARE:
    a_, b_ = px(p[0], p[1])
    dr.rectangle([a_ - 4, b_ - 4, a_ + 4, b_ + 4], fill=(255, 200, 40), outline=(90, 60, 0))
for p in CRISTALE:
    a_, b_ = px(p[0], p[1])
    dr.polygon([(a_, b_ - 7), (a_ + 5, b_), (a_, b_ + 7), (a_ - 5, b_)], fill=(90, 230, 255), outline=(20, 80, 120))
for g in GARDURI:
    dr.line([px(g[0], g[1]), px(g[3], g[4])], fill=(130, 80, 40), width=4)
for p in BUTOAIE:
    a_, b_ = px(p[0], p[1])
    dr.ellipse([a_ - 5, b_ - 5, a_ + 5, b_ + 5], fill=(150, 90, 40))
for p in LAZI:
    a_, b_ = px(p[0], p[1])
    dr.rectangle([a_ - 5, b_ - 5, a_ + 5, b_ + 5], fill=(190, 140, 80))
FONT = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 15)
leg = Image.new("RGB", (pil.width, 92), "white")
dl = ImageDraw.Draw(leg)
dl.text((10, 6), "Inelul 1 (v4), văzut de sus: verde = terenul nou (bej = pavaj, maro = pământ), roșu = clădiri vechi "
        "păstrate, albastru = apă, mov = insula castelului (rămâne).", font=FONT, fill=(40, 40, 40))
dl.text((10, 30), "Cercuri: copac mare (verde închis), arbori roz, palmieri (verde), tufe; pătrate galbene = felinare; "
        "romburi = cristale; linii maro = garduri;", font=FONT, fill=(40, 40, 40))
dl.text((10, 54), "puncte: iarbă (verde), flori (roz), pietricele (gri). Sus = spatele insulei (Godot -Z), "
        "START (0) jos.", font=FONT, fill=(40, 40, 40))
tot = Image.new("RGB", (pil.width, pil.height + leg.height), "white")
tot.paste(pil, (0, 0))
tot.paste(leg, (0, pil.height))
os.makedirs(args.shots, exist_ok=True)
tot.save(os.path.join(args.shots, "insula_v4_inel1_harta.png"))
log("[verificare]", os.path.join(args.shots, "insula_v4_inel1_harta.png"))
if args.fara_export:
    sys.exit(0)

# ============================================================================= 6b. clădirile, piese separate (Inelul 2)
# Castelul, podurile, piața, moara, portalul, atelierul cu debarcaderul: fețele clasei „restul” din amprenta fiecăreia
# devin un obiect „Cladire_<nume>”, cu ancora la bază. În Godot: se estompează lin când acoperă pe Orion și pot fi
# înlocuite fără cod: un GLB nou în godot/assets/models/cladiri/<nume>.glb (originea la bază, metri) ia locul piesei.
lab_o, n_o = ndi.label(ndi.binary_dilation(obiect & ~castel, iterations=2))
cen_o = ndi.center_of_mass(np.ones_like(lab_o), lab_o, range(1, n_o + 1)) if n_o else []
cen_o = [(X[0] + c[1] * args.pas, Y[0] + c[0] * args.pas) for c in cen_o]
c_portal = fete("Insula_portal")[0].mean(0) if len(OB["Insula_portal"].data.polygons) else np.array([5.0, 8.5, 1.0])
ANCORE = {"piata": (6.3, 0.8), "moara": (-3.0, 7.6), "portal": (c_portal[0], c_portal[1]), "atelier_debarcader": (-4.6, -8.6)}
amprente = {"castel": castel.copy(), "poduri": ndi.binary_dilation(pod, iterations=2)}
for nume, (ax, ay) in ANCORE.items():
    if not n_o:
        break
    d = [np.hypot(cx - ax, cy - ay) for cx, cy in cen_o]
    k = int(np.argmin(d))
    if d[k] < 3.5:
        amprente[nume] = ndi.binary_dilation(lab_o == k + 1, iterations=3)
amprente["atelier_debarcader"] = amprente.get("atelier_debarcader", np.zeros_like(reg)) | \
    ((XX < -1.5) & (YY < -6.8) & (np.hypot(XX - ANCORE["atelier_debarcader"][0], YY - ANCORE["atelier_debarcader"][1]) < 3.2))
def fete_acum(nume):
    """centrele fețelor din mesh-ul de acum (după tăieri), în coordonate de lume"""
    o = OB[nume]
    me_ = o.data
    co = np.array([o.matrix_world @ v.co for v in me_.vertices])
    return np.array([co[list(p.vertices)].mean(0) for p in me_.polygons])


c = fete_acum("Insula_restul")
alocat = np.zeros(len(c), bool)
CLADIRI = {}
for nume in ("castel", "poduri", "portal", "moara", "piata", "atelier_debarcader"):
    if nume not in amprente:
        continue
    m = ~alocat & in_reg(c[:, 0], c[:, 1], amprente[nume])
    if m.sum() < 30:
        continue
    alocat |= m
    o = OB["Insula_restul"]
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bm.faces.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[bm.faces[i] for i in np.where(~m)[0]], context="FACES")
    me_c = bpy.data.meshes.new("Cladire_" + nume)
    bm.to_mesh(me_c)
    bm.free()
    for mat in o.data.materials:
        me_c.materials.append(mat)
    ob_c = bpy.data.objects.new("Cladire_" + nume, me_c)
    ob_c.matrix_world = o.matrix_world
    scene.collection.objects.link(ob_c)
    P_ = np.array([ob_c.matrix_world @ v.co for v in me_c.vertices])
    lo, hi = P_.min(0), P_.max(0)
    CLADIRI[nume] = dict(baza=((lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, float(lo[2])), marime=(hi - lo).tolist(),
                         fete=int(m.sum()))
    OB["Cladire_" + nume] = ob_c
sterge_fete("Insula_restul", alocat)
log("[clădiri] piese separate: %s" % {k: v["fete"] for k, v in CLADIRI.items()})

# ============================================================================= 7. export
# culorile pe vârfuri ale insulei vechi: importul le dă pe colțuri (BYTE_COLOR); le trecem pe vârfuri, ca float,
# cu același nume „Color” (altfel exportul pierde alfa: legănarea în vânt, modul apei)
for o in list(OB.values()):
    m_ = o.data
    if not m_.color_attributes:
        continue
    src = m_.color_attributes[0]
    vals = np.empty(len(src.data) * 4, np.float32)
    src.data.foreach_get("color", vals)
    vals = vals.reshape(-1, 4)
    if src.domain == "CORNER":
        lv = np.empty(len(m_.loops), np.int32)
        m_.loops.foreach_get("vertex_index", lv)
        per_v = np.ones((len(m_.vertices), 4), np.float32)
        per_v[lv] = vals
    else:
        per_v = vals
    m_.color_attributes.remove(src)
    dst = m_.color_attributes.new("Color", "FLOAT_COLOR", "POINT")
    dst.data.foreach_set("color", per_v.ravel())
    m_.color_attributes.active_color = dst
MAT_APA = bpy.data.materials.new("apa")
for nume in ("Apa", "Cascade"):
    OB[nume].data.materials.clear()
    OB[nume].data.materials.append(MAT_APA)
os.makedirs(os.path.dirname(args.out), exist_ok=True)
bpy.ops.object.select_all(action="DESELECT")
for o in OB.values():
    o.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.abspath(args.out), use_selection=True, export_apply=True, export_yup=True,
                          export_image_format="JPEG", export_jpeg_quality=92, export_vertex_color="ACTIVE",
                          export_normals=True)
log("[glb] insula veche tăiată:", args.out, "%.1f MB" % (os.path.getsize(args.out) / 1e6),
    {k: len(o.data.polygons) for k, o in OB.items()})
bpy.ops.object.select_all(action="DESELECT")
teren.data.materials.append(bpy.data.materials.new("teren"))
teren.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.abspath(args.teren), use_selection=True, export_yup=True,
                          export_vertex_color="ACTIVE", export_normals=True, export_materials="PLACEHOLDER")
log("[glb] teren:", args.teren)


# ============================================================================= 8. datele pentru Godot
def lista_puncte(nume, P_, z_fn, cu_rot=True):
    rows = []
    for x_, y_ in P_:
        rows.append("%.3f, %.3f, %.3f, %.2f, %.2f" % (x_, float(z_fn(x_, y_)), -y_, rng.uniform(0, 6.283),
                                                      rng.uniform(0.75, 1.25)))
    return "## %s: x, y, z, rotație, scară (câte 5 numere pe bucată)\nconst %s := [\n%s\n]\n" % (
        nume.lower(), nume, ",\n".join("\t" + r for r in rows))


def z_teren(x_, y_):
    return bilin(Hr, x_, y_)


with open(args.data, "w") as f:
    f.write("# Inelul 1 (v4): recuzita nouă și presăratele, generate de blender/insula1/v4_inel1.py (metri, Y în sus).\n")
    f.write("# Pozițiile vin din insula veche (unde stăteau copacii, felinarele, cristalele, florile), mutate de pe căsuțe.\n")
    f.write("extends RefCounted\n\n")
    f.write("## copaci: [tip, poziție, rotație, scară] (tip: palmier, arbore_roz, copac_mare)\nconst COPACI := [\n")
    for c_ in COPACI:
        f.write('\t["%s", %s, %.2f, %.2f],\n' % (c_[0], gd((c_[1], c_[2], c_[3])), c_[4], c_[5]))
    f.write("]\n## tufe: [poziție, rotație, scară, varianta 0-2]\nconst TUFE := [\n")
    for t in TUFE:
        f.write("\t[%s, %.2f, %.2f, %d],\n" % (gd(t[:3]), t[3], t[4], t[5]))
    f.write("]\n## felinare pe stâlpi (poziția bazei)\nconst FELINARE: Array[Vector3] = [\n")
    for p in FELINARE:
        f.write("\t%s,\n" % gd(p))
    f.write("]\n## cristale: [poziție, rotație, scară, varianta 0-2]\nconst CRISTALE := [\n")
    for p in CRISTALE:
        f.write("\t[%s, %.2f, %.2f, %d],\n" % (gd(p[:3]), p[3], p[4], p[5]))
    f.write("]\n## garduri: segmente [capăt, capăt]\nconst GARDURI := [\n")
    for g in GARDURI:
        f.write("\t[%s, %s],\n" % (gd(g[:3]), gd(g[3:])))
    f.write("]\n## butoaie și lăzi: [poziție, rotație, scară]\nconst BUTOAIE := [\n")
    for p in BUTOAIE:
        f.write("\t[%s, %.2f, %.2f],\n" % (gd(p[:3]), p[3], p[4]))
    f.write("]\nconst LAZI := [\n")
    for p in LAZI:
        f.write("\t[%s, %.2f, %.2f],\n" % (gd(p[:3]), p[3], p[4]))
    f.write("]\n## peștii care sar din laguna bărcii (punctul de la suprafața apei)\nconst PESTI: Array[Vector3] = [\n")
    for p in PESTI:
        f.write("\t%s,\n" % gd(p))
    f.write("]\n## flăcările felinarelor rămase pe clădirile vechi (halouri)\nconst FLACARI_RAMASE: Array[Vector3] = [\n")
    for p in FLACARI_RAMASE:
        f.write("\t%s,\n" % gd(p))
    f.write("]\n")
    f.write("## clădirile ca piese separate (Cladire_<nume> în insula1.glb): ancora la bază (centrul amprentei, cel mai\n")
    f.write("## de jos punct) și mărimea (x, y, z în metri). Un GLB nou în res://assets/models/cladiri/<nume>.glb, cu originea\n")
    f.write("## la bază, se pune aici și ascunde piesa veche (rotația o potrivești în CLADIRI_ROTATIE, în grade).\n")
    f.write("const CLADIRI := {\n")
    for nume, d in CLADIRI.items():
        mx, my, mz = d["marime"]
        f.write('\t"%s": [%s, Vector3(%.2f, %.2f, %.2f)],\n' % (nume, gd(d["baza"]), mx, mz, my))
    f.write("}\nconst CLADIRI_ROTATIE := {}\n")
    f.write(lista_puncte("IARBA", IARBA, z_teren))
    f.write(lista_puncte("FLORI", FLORI, z_teren))
    f.write(lista_puncte("PIETRICELE", PIETRE, z_teren))
log("[date]", args.data)
log("gata")
