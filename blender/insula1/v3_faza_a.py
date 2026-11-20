"""
Insula 1, v3, Faza A: pornește de la insula îmbunătățită (blender/out_insula1/insula1_imbunatatita.glb, din
imbunatateste.py) și o pregătește pentru joc, fără credite și fără să-i schimbe forma:

  A1  întoarce fețele la care normala din fișier e opusă sensului de desenare (în Godot ieșeau pete negre pe frunze,
      flori și muchii) și scoate triunghiurile degenerate;
  A2  ascute ușor textura (unsharp mask);
  A3  clasifică fiecare față după culoarea texturii, poziție și normală (stânci, iarbă, frunziș, flori, pânze, cristale,
      portal, felinare aurii, căsuțe, barcă, palele morii, nuferi, restul); întâi face imaginile de verificare
      (o culoare pe clasă), abia apoi taie mesh-ul în obiecte pe clase;
  A4  nuferii separați (plutesc), barca separată cu pivot (se leagănă);
  A6  pozițiile flăcărilor (halouri calde care pâlpâie) și ale cristalelor;
  A7  greutatea de legănare în vânt pe vârfuri (înălțimea față de sol), palele morii separate, cu pivot și ax,
      completate la 4 pale (Tripo a făcut doar 2, în „V”);
  A8  discurile căsuțelor coapte în model sunt scoase (le înlocuiesc căsuțele Tile.tscn din joc);
  A9  ocluzie ambientală (AO) coaptă în culorile de vârf;
  perf: simplificare pe clase (stâncile și dedesubtul mai mult), ca să intre în bugetul de triunghiuri.

    python blender/insula1/v3_faza_a.py -- [--doar-clase] [--fara-simplificare]

Ieșiri: godot/assets/models/insula1/insula1.glb, godot/insula1/data/insula1_info.gd,
docs/shots/insula_v3_A_clase_*.png (verificarea clasificării).
"""
import argparse
import json
import math
import os
import re
import sys
import time

import bpy  # noqa: I001  (bpy înainte de bmesh)
import bmesh
import numpy as np
from mathutils import Matrix, Vector
from PIL import Image, ImageFilter
from scipy import ndimage as ndi
from scipy.sparse import coo_matrix
from scipy.sparse.csgraph import connected_components
from scipy.spatial import cKDTree

Image.MAX_IMAGE_PIXELS = None
T0 = time.time()
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
ap = argparse.ArgumentParser()
ap.add_argument("--src", default=os.path.join(ROOT, "blender/out_insula1/insula1_imbunatatita.glb"))
ap.add_argument("--info", default=os.path.join(ROOT, "blender/out_insula1/insula1_imbunatatita_info.gd"))
ap.add_argument("--out", default=os.path.join(ROOT, "godot/assets/models/insula1/insula1.glb"))
ap.add_argument("--data", default=os.path.join(ROOT, "godot/insula1/data/insula1_info.gd"))
ap.add_argument("--shots", default=os.path.join(ROOT, "docs/shots"))
ap.add_argument("--doar-clase", action="store_true", help="doar clasificarea și imaginile de verificare")
ap.add_argument("--fara-simplificare", action="store_true")
ap.add_argument("--fara-ao", action="store_true")
args = ap.parse_args(argv)
TILES = json.load(open(os.path.join(ROOT, "blender", "out_insula1", "insula1_casute.json")))

CASTEL = np.array([0.25, 0.55])
# (nume, culoare de verificare); ordinea = prioritatea la clasificare (cele de jos o suprascriu pe cele de sus)
CLASE = [("restul", (0.62, 0.62, 0.62)), ("stanci", (0.45, 0.36, 0.55)), ("iarba", (0.55, 0.85, 0.25)),
         ("frunzis", (0.05, 0.45, 0.12)), ("flori", (1.0, 0.45, 0.75)), ("panze", (1.0, 0.55, 0.0)),
         ("cristale", (0.3, 0.95, 1.0)), ("felinare", (1.0, 0.85, 0.1)), ("portal", (0.6, 0.2, 1.0)),
         ("casute", (1.0, 1.0, 1.0)), ("barca", (0.55, 0.3, 0.1)), ("moara", (1.0, 0.1, 0.1)),
         ("nuferi", (0.0, 0.5, 0.5))]
CI = {n: i for i, (n, _) in enumerate(CLASE)}


def log(*a):
    print(f"[{time.time() - T0:7.1f}s]", *a, flush=True)


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def hsv(a):
    mx, mn = a.max(-1), a.min(-1)
    d = np.maximum(mx - mn, 1e-4)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    h = np.where(mx == r, ((g - b) / d) % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) * 60
    return h, (mx - mn) / np.maximum(mx, 1e-4), mx


def img_np(img):
    w, h = img.size
    a = np.empty(w * h * img.channels, np.float32)
    img.pixels.foreach_get(a)
    return a.reshape(h, w, img.channels)[::-1]


def arrays(me):
    n = len(me.polygons)
    co = np.empty(len(me.vertices) * 3, np.float32)
    me.vertices.foreach_get("co", co)
    fv = np.empty(n * 3, np.int32)
    me.polygons.foreach_get("vertices", fv)
    ls = np.empty(n, np.int32)
    me.polygons.foreach_get("loop_start", ls)
    uv = np.empty(len(me.loops) * 2, np.float32)
    me.uv_layers.active.data.foreach_get("uv", uv)
    return co.reshape(-1, 3), fv.reshape(-1, 3), ls, uv.reshape(-1, 2)


def gd_vec(p):  # Blender (x, y, z) -> Godot (x, z, -y)
    return "Vector3(%.3f, %.3f, %.3f)" % (p[0], p[2], -p[1])


def read_info(path):
    t = open(path).read()
    vec = lambda s: [float(x) for x in s.split(",")]  # noqa: E731
    info = {"text": t}
    m = re.search(r"NIVEL_RAU := ([-\d.]+)", t)
    info["nivel_rau"] = float(m.group(1)) if m else None
    info["lacuri"] = [(float(a), vec(b)) for a, b in re.findall(r"\[([-\d.]+), Vector3\(([^)]*)\)\]", t)]
    info["cascade"] = [(vec(a), vec(b), float(c)) for a, b, c in re.findall(r"\[Vector3\(([^)]*)\), Vector3\(([^)]*)\), ([\d.]+)\]", t)]
    for k in ("PORTAL_CENTRU", "PORTAL_NORMALA"):
        info[k] = vec(re.search(k + r" := Vector3\(([^)]*)\)", t).group(1))
    info["PORTAL_MARIME"] = vec(re.search(r"PORTAL_MARIME := Vector2\(([^)]*)\)", t).group(1))
    return info


def g2b(v):  # Godot -> Blender
    return np.array([v[0], -v[2], v[1]])


# ============================================================================= import
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
bpy.ops.import_scene.gltf(filepath=os.path.abspath(args.src))
for o in [o for o in scene.objects if o.type == "EMPTY"]:
    for c in o.children:
        c.parent = None
    bpy.data.objects.remove(o)
OB = {o.name.split(".")[0]: o for o in scene.objects if o.type == "MESH"}
ob = OB["Insula"]
me = ob.data
INFO = read_info(args.info)
mat0 = me.materials[0]
ALB_IMG = next(n.image for n in mat0.node_tree.nodes if n.type == "TEX_IMAGE" and "albedo" in n.image.name)
ORM_IMG = next(n.image for n in mat0.node_tree.nodes if n.type == "TEX_IMAGE" and "orm" in n.image.name)
log("[import]", {k: len(o.data.polygons) for k, o in OB.items()})

# ============================================================================= A1: fețe cu normala opusă, degenerate
co, fv, ls, uv = arrays(me)
nf = len(fv)
P = co[fv]
cr = np.cross(P[:, 1] - P[:, 0], P[:, 2] - P[:, 0])
area = 0.5 * np.linalg.norm(cr, axis=1)
fn = cr / np.maximum(2 * area[:, None], 1e-20)
cn = np.array([c.vector[:] for c in me.corner_normals], np.float32)
vn = cn[ls] + cn[ls + 1] + cn[ls + 2]
inv = (np.einsum("ij,ij->i", vn, fn) < 0) & (area > 1e-12)
deg = area < 1e-9
log("[A1] fețe cu normala opusă sensului de desenare: %d (%.1f m2); degenerate: %d" % (inv.sum(), area[inv].sum(), deg.sum()))
bm = bmesh.new()
bm.from_mesh(me)
bm.faces.ensure_lookup_table()
# păstrăm normalele din fișier pe fiecare (față, vârf) și le punem la loc după întoarcere
keep_n = {}
for f in np.where(inv)[0]:
    for k in range(3):
        keep_n[(int(f), int(fv[f, k]))] = cn[ls[f] + k]
bmesh.ops.reverse_faces(bm, faces=[bm.faces[int(i)] for i in np.where(inv)[0]])
bm.to_mesh(me)
bm.free()
me.update()
new_cn = np.array([c.vector[:] for c in me.corner_normals], np.float32)  # după to_mesh: normale recalculate
loop_v = np.empty(len(me.loops), np.int32)
me.loops.foreach_get("vertex_index", loop_v)
for f in np.where(inv)[0]:
    s0 = me.polygons[int(f)].loop_start
    for k in range(3):
        new_cn[s0 + k] = keep_n[(int(f), int(loop_v[s0 + k]))]
# pentru celelalte fețe, normalele din fișier rămân cele vechi (ordinea colțurilor nu s-a schimbat)
ok = ~inv
for k in range(3):
    new_cn[ls[ok] + k] = cn[ls[ok] + k]
me.normals_split_custom_set(new_cn.tolist())
if deg.any():
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.faces.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[bm.faces[int(i)] for i in np.where(deg)[0]], context="FACES_ONLY")
    bm.to_mesh(me)
    bm.free()
    me.update()
co, fv, ls, uv = arrays(me)
nf = len(fv)
P = co[fv]
cr = np.cross(P[:, 1] - P[:, 0], P[:, 2] - P[:, 0])
area = 0.5 * np.linalg.norm(cr, axis=1)
fn = cr / np.maximum(2 * area[:, None], 1e-20)
cn = np.array([c.vector[:] for c in me.corner_normals], np.float32)
vn = cn[ls] + cn[ls + 1] + cn[ls + 2]
log("[A1] după reparație: fețe cu normala opusă %d" % int((np.einsum("ij,ij->i", vn, fn) < 0).sum()))

# ============================================================================= A3: clasificarea
alb = img_np(ALB_IMG)[..., :3]
TH, TW = alb.shape[:2]


def sample(u):
    x = np.clip((u[:, 0] * TW).astype(int), 0, TW - 1)
    y = np.clip(((1 - u[:, 1]) * TH).astype(int), 0, TH - 1)
    return alb[y, x]


U3 = np.stack([uv[ls + k] for k in range(3)], 1)
col = (2 * sample(U3.mean(1)) + sample(U3[:, 0]) + sample(U3[:, 1]) + sample(U3[:, 2])) / 5
h, s, v = hsv(col)
cen = P.mean(1)
x, y, z = cen[:, 0], cen[:, 1], cen[:, 2]
up = fn[:, 2]

# solul: înălțimea maximă văzută de sus, „deschisă” morfologic (scoate copacii, stâlpii, steagurile)
RES = 8.0
lo, hi = co.min(0), co.max(0)
Wg, Hg = int((hi[0] - lo[0]) * RES) + 2, int((hi[1] - lo[1]) * RES) + 2
gx = np.clip(((x - lo[0]) * RES).astype(int), 0, Wg - 1)
gy = np.clip(((y - lo[1]) * RES).astype(int), 0, Hg - 1)
top = np.full((Hg, Wg), -50.0, np.float32)
np.maximum.at(top, (gy, gx), z)
top = ndi.grey_closing(top, size=3)
sol = ndi.grey_opening(top, footprint=(lambda r: (np.hypot(*np.mgrid[-r:r + 1, -r:r + 1]) <= r))(int(1.4 * RES)))
sol = ndi.gaussian_filter(sol, 1.0)


def peste_sol(p):
    ix = np.clip(((p[:, 0] - lo[0]) * RES).astype(int), 0, Wg - 1)
    iy = np.clip(((p[:, 1] - lo[1]) * RES).astype(int), 0, Hg - 1)
    return p[:, 2] - sol[iy, ix]


hag = peste_sol(cen)
cls = np.zeros(nf, np.int32)
verde = (h > 55) & (h < 170) & (s > 0.28) & (v > 0.22)
orm = img_np(ORM_IMG)[..., :3]
OH, OW = orm.shape[:2]
um = U3.mean(1)
metal = orm[np.clip(((1 - um[:, 1]) * OH).astype(int), 0, OH - 1), np.clip((um[:, 0] * OW).astype(int), 0, OW - 1), 2]
roz = ((h >= 300) | (h <= 22)) & (s > 0.25) & (v > 0.45)
cls[(s < 0.34) & (v < 0.78) & ((h > 195) & (h < 335) | (s < 0.12)) & ((up < 0.55) | (z < -0.8))] = CI["stanci"]
# sub marginea insulei, tot ce nu e verde, roz sau apă e stâncă (faleze, partea de dedesubt)
cls[(z < -1.0) & (s < 0.42) & ~roz & ~((h > 55) & (h < 170) & (s > 0.28))] = CI["stanci"]
cls[verde & (hag < 0.3) & (up > 0.45)] = CI["iarba"]
cls[verde & ~((hag < 0.3) & (up > 0.45))] = CI["frunzis"]
cls[roz & (z > -1.2)] = CI["flori"]
# pânze: steagurile castelului (albastru, sus, în afara conului din mijloc) și copertina pieței (dungi roz-albe)
steag = (np.hypot(x - CASTEL[0], y - CASTEL[1]) < 2.6) & (z > 3.65) & (z < 4.7) & (h > 210) & (h < 265) & (s > 0.3) & \
    (np.hypot(x - 0.3, y - 0.55) > 0.5)
copertina = (x > 4.6) & (x < 6.4) & (y > -1.2) & (y < 1.6) & (z > 0.82) & (z < 1.32) & \
    ((((h >= 320) | (h <= 20)) & (s > 0.15)) | ((s < 0.18) & (v > 0.78)))
cls[steag | copertina] = CI["panze"]
cls[(h > 172) & (h < 240) & (s > 0.06) & (s < 0.5) & (v > 0.72) & (z > -1.0) & (up < 0.9)] = CI["cristale"]
# aurul adevărat (felinare, ornamente): metalic în harta ORM sau galben-auriu foarte saturat și luminos
aur = ((metal > 0.3) | ((h > 38) & (h < 56) & (s > 0.62) & (v > 0.68))) & (h > 25) & (h < 65) & (s > 0.3)
cls[aur & (z > -0.5)] = CI["felinare"]
pc = g2b(INFO["PORTAL_CENTRU"])
cls[np.linalg.norm(cen - pc, axis=1) < 1.25] = CI["portal"]
# căsuțele coapte: discurile bej de pe pozițiile din joc
cas = np.array([[t["x"], -t["z"], t["y"]] for t in TILES["casute"]])
R_CAS = TILES["raza_casuta"]
d_c, j_c = cKDTree(cas[:, :2]).query(cen[:, :2])
cls[(d_c < R_CAS * 1.02) & (np.abs(z - cas[j_c, 2]) < 0.3) & (s < 0.4)] = CI["casute"]
# barca: elipsă în jurul carenei, din apa lagunei până în vârful catargului
bc = np.array([-0.6, -9.25])
ax = np.array([0.82, -0.57])
ax /= np.linalg.norm(ax)
rel = cen[:, :2] - bc
along, across = rel @ ax, rel @ np.array([-ax[1], ax[0]])
barca = ((along / 1.35) ** 2 + (across / 0.62) ** 2 < 1.0) & (z > -2.72) & (z < 1.2)
cls[barca] = CI["barca"]
# palele morii: două panouri crem mari, cu două fețe, într-un plan vertical; butucul = unde se întâlnesc axele lor lungi
zona = (x > -4.9) & (x < -1.6) & (y > 5.6) & (y < 8.4) & (z > 2.6) & (z < 5.0)
panou = zona & (s < 0.3) & (v > 0.62) & (h > 20) & (h < 55) & (np.abs(up) < 0.4) & (area > 0.02)
MOARA_PLAN = None
if panou.sum() >= 4:
    pi_ = np.where(panou)[0]
    ref = fn[pi_[np.argmax(area[pi_])]]
    nn = fn[pi_] * np.sign(fn[pi_] @ ref)[:, None]
    n_pl = np.average(nn, axis=0, weights=area[pi_])
    n_pl /= np.linalg.norm(n_pl)
    if n_pl @ np.array([0.0, -1.0, 0.0]) < 0:  # spre fața morii
        n_pl = -n_pl
    d_pl = float(np.median(cen[pi_] @ n_pl))
    e1 = np.cross([0.0, 0.0, 1.0], n_pl)
    e1 /= np.linalg.norm(e1)
    e2 = np.cross(n_pl, e1)
    u2 = np.stack([cen[pi_] @ e1, cen[pi_] @ e2], 1)
    split = np.median(u2[:, 0])
    gap = np.sort(u2[:, 0])
    k_ = np.argmax(np.diff(gap))
    split = (gap[k_] + gap[k_ + 1]) / 2
    lines = []
    for side in (u2[:, 0] < split, u2[:, 0] >= split):
        w_ = area[pi_][side]
        c2 = np.average(u2[side], axis=0, weights=w_)
        ev_, evec_ = np.linalg.eigh(np.cov((u2[side] - c2).T, aweights=w_))
        lines.append((c2, evec_[:, 1]))
    (c1, d1), (c2_, d2) = lines
    A = np.array([d1, -d2]).T
    tt = np.linalg.lstsq(A, c2_ - c1, rcond=None)[0]
    hub2 = c1 + d1 * tt[0]
    hub = hub2[0] * e1 + hub2[1] * e2 + d_pl * n_pl
    MOARA_PLAN = dict(n=n_pl, d=d_pl, hub=hub)
    rel_h = cen - hub
    in_pl = np.abs(cen @ n_pl - d_pl) < 0.16
    raza = np.linalg.norm(rel_h - np.outer(rel_h @ n_pl, n_pl), axis=1)
    moara = zona & in_pl & (raza < 2.1) & ~verde & ~((h > 225) & (h < 300) & (s > 0.25))
    cls[moara] = CI["moara"]
    log("[A7] palele morii: plan cu normala %s, butuc %s, %d fețe" % (np.round(n_pl, 2).tolist(), np.round(hub, 2).tolist(), int(moara.sum())))
# nuferii: pete verzi sau roz chiar la nivelul râului, în albia lui
rau_lvl = INFO["nivel_rau"] or -1.41
nuf = (np.abs(z - rau_lvl) < 0.14) & (up > 0.7) & (verde | (((h >= 300) | (h <= 22)) & (s > 0.25))) & \
    (np.hypot(x - CASTEL[0], y - CASTEL[1]) > 2.5) & (np.hypot(x - CASTEL[0], y - CASTEL[1]) < 7.0)
cls[nuf] = CI["nuferi"]
cnt = np.bincount(cls, minlength=len(CLASE))
log("[A3] clase:", {n: int(cnt[i]) for i, (n, _) in enumerate(CLASE)})


# ============================================================================= imaginile de verificare (înainte de tăiere)
def render_clase(tag):
    sc = scene
    mats = []
    for n, c in CLASE:
        m = bpy.data.materials.new("dbg_" + n)
        nt = m.node_tree
        nt.nodes.clear()
        o_ = nt.nodes.new("ShaderNodeOutputMaterial")
        e = nt.nodes.new("ShaderNodeEmission")
        nt.links.new(e.outputs[0], o_.inputs[0])
        e.inputs[0].default_value = (*c, 1)
        mats.append(m)
    old = list(me.materials)
    me.materials.clear()
    for m in mats:
        me.materials.append(m)
    me.polygons.foreach_set("material_index", cls)
    me.update()
    hidden = []
    for k, o_ in OB.items():
        if k != "Insula":
            hidden.append((o_, list(o_.data.materials)))
            o_.data.materials.clear()
            m = bpy.data.materials.new("dbg_apa_" + k)
            nt = m.node_tree
            nt.nodes.clear()
            oo = nt.nodes.new("ShaderNodeOutputMaterial")
            e = nt.nodes.new("ShaderNodeEmission")
            nt.links.new(e.outputs[0], oo.inputs[0])
            e.inputs[0].default_value = (0.1, 0.35, 1.0, 1) if k == "Apa" else (0.75, 0.9, 1.0, 1)
            o_.data.materials.append(m)
    w = bpy.data.worlds.new("w_dbg")
    sc.world = w
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.93, 0.93, 0.93, 1)
    cam = bpy.data.objects.new("cam_dbg", bpy.data.cameras.new("cam_dbg"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.sensor_fit = "VERTICAL"
    cam.data.angle = math.radians(40)
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 4
    sc.cycles.device = "CPU"
    sc.cycles.use_denoising = False
    sc.view_settings.view_transform = "Standard"
    start = Vector((cas[0, 0], cas[0, 1], cas[0, 2]))
    outs = []
    for name, f, pitch, dist, wh in [("aproape", start + Vector((0, 0, 0.7)), 0.85, 16, (720, 1000)),
                                     ("panorama", Vector((0.6, 0.2, -2.4)), 0.92, 47, (800, 1000)),
                                     ("sus", Vector((0.6, -0.5, -1.0)), 1.5, 45, (800, 1000))]:
        eye = f + Vector((0, -math.cos(pitch), math.sin(pitch))) * dist
        cam.location = eye
        cam.rotation_euler = (f - eye).to_track_quat("-Z", "Y").to_euler()
        sc.render.resolution_x, sc.render.resolution_y = wh
        p = os.path.join(args.shots, f"insula_v3_A_clase_{name}{tag}.png")
        sc.render.filepath = p
        bpy.ops.render.render(write_still=True)
        outs.append(p)
    # legendă
    from PIL import ImageDraw, ImageFont
    F = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 18)
    ims = [Image.open(p).convert("RGB") for p in outs]
    Hh = 1000
    ims = [im.resize((int(im.width * Hh / im.height), Hh)) for im in ims]
    Wt = sum(im.width for im in ims) + 10 * (len(ims) - 1)
    leg_h = 34 * ((len(CLASE) + 2 + 4) // 5)
    out = Image.new("RGB", (Wt, Hh + leg_h + 10), "white")
    xx = 0
    for im in ims:
        out.paste(im, (xx, 0))
        xx += im.width + 10
    d = ImageDraw.Draw(out)
    items = [(n, c) for n, c in CLASE] + [("apa", (0.1, 0.35, 1.0)), ("cascade", (0.75, 0.9, 1.0))]
    for i, (n, c) in enumerate(items):
        cx = 12 + (i % 5) * (Wt // 5)
        cy = Hh + 10 + (i // 5) * 34
        d.rectangle([cx, cy, cx + 26, cy + 24], fill=tuple(int(255 * t) for t in c), outline=(0, 0, 0))
        d.text((cx + 34, cy + 2), f"{n} ({int(cnt[CI[n]]) if n in CI else len(OB[n.capitalize()].data.polygons)})", font=F, fill=(30, 30, 30))
    p = os.path.join(args.shots, f"insula_v3_A_clase{tag}.png")
    out.save(p)
    for q in outs:
        os.remove(q)
    me.materials.clear()
    for m in old:
        me.materials.append(m)
    me.polygons.foreach_set("material_index", np.zeros(nf, np.int32))
    me.update()
    for o_, ms in hidden:
        o_.data.materials.clear()
        for m in ms:
            o_.data.materials.append(m)
    log("[A3] imaginea de verificare:", p)
    return p


render_clase("")
if args.doar_clase:
    sys.exit(0)
# nuferii: modelul are doar câteva pete (sub 20 de fețe); nu merită un obiect separat
cls[cls == CI["nuferi"]] = CI["restul"]


# ============================================================================= A3: tăierea în obiecte pe clase
def separa(obj, mask, name):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_mode(type="FACE")
    bpy.ops.mesh.select_all(action="DESELECT")
    bm_ = bmesh.from_edit_mesh(obj.data)
    bm_.faces.ensure_lookup_table()
    for i in np.where(mask)[0]:
        bm_.faces[int(i)].select_set(True)
    bmesh.update_edit_mesh(obj.data)
    before = set(scene.objects)
    bpy.ops.mesh.separate(type="SELECTED")
    bpy.ops.object.mode_set(mode="OBJECT")
    new = [o_ for o_ in scene.objects if o_ not in before][0]
    new.name = name
    new.data.name = name
    return new


# discurile căsuțelor coapte se scot (le înlocuiesc căsuțele din joc, puțin mai mari)
attr = me.attributes.new("clasa", "INT", "FACE")
attr.data.foreach_set("value", cls)
gone = separa(ob, cls == CI["casute"], "casute_vechi")
bpy.data.objects.remove(gone)
cls = np.empty(len(me.polygons), np.int32)
me.attributes["clasa"].data.foreach_get("value", cls)

# ============================================================================= A9: AO coaptă în culorile de vârf (pe toată insula)
ao = None
if not args.fara_ao:
    col_a = me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    me.color_attributes.active_color = col_a
    try:
        me.color_attributes.render_color_index = me.color_attributes.active_color_index
    except AttributeError:
        pass
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 24
    scene.render.bake.target = "VERTEX_COLORS"
    scene.world = scene.world or bpy.data.worlds.new("w")
    scene.world.light_settings.distance = 1.6  # umbre de contact locale (sub clădiri, la margini), nu de la 10 m
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    t1 = time.time()
    bpy.ops.object.bake(type="AO")
    ao = np.empty(len(me.vertices) * 4, np.float32)
    col_a.data.foreach_get("color", ao)
    ao = ao.reshape(-1, 4)[:, 0].copy()
    log("[A9] AO coaptă pe %d vârfuri în %.0fs; medie %.2f, 10%% cele mai întunecate sub %.2f" % (
        len(ao), time.time() - t1, ao.mean(), np.percentile(ao, 10)))

# ============================================================================= A7: greutatea de legănare (înălțimea față de sol)
co_v = np.empty(len(me.vertices) * 3, np.float32)
me.vertices.foreach_get("co", co_v)
co_v = co_v.reshape(-1, 3)
hag_v = peste_sol(co_v)
fv_now = np.empty(len(me.polygons) * 3, np.int32)
me.polygons.foreach_get("vertices", fv_now)
fv_now = fv_now.reshape(-1, 3)
vcls = np.zeros(len(me.vertices), np.int32)
for c_ in (CI["frunzis"], CI["flori"], CI["panze"]):
    vcls[np.unique(fv_now[cls == c_].ravel())] = c_
fact = np.zeros(len(me.vertices), np.float32)
fact[vcls == CI["frunzis"]] = 1.0
fact[vcls == CI["flori"]] = 0.6
fact[vcls == CI["panze"]] = 0.8
sway = fact * smooth(0.15, 2.2, hag_v)
rgba = np.zeros((len(me.vertices), 4), np.float32)
rgba[:, 0] = ao if ao is not None else 1.0
rgba[:, 3] = sway
if "Col" not in me.color_attributes:
    me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
me.color_attributes["Col"].data.foreach_set("color", rgba.ravel())
me.color_attributes.active_color = me.color_attributes["Col"]
log("[A7] vârfuri care se leagănă: %d (greutate medie %.2f)" % (int((sway > 0.05).sum()), sway[sway > 0.05].mean() if (sway > 0.05).any() else 0))

# ============================================================================= A6: flăcările felinarelor (halouri), cristalele
orm_f = orm[np.clip(((1 - um[:, 1]) * OH).astype(int), 0, OH - 1), np.clip((um[:, 0] * OW).astype(int), 0, OW - 1), 0]
FLACARI = []
# (indicii vechi ai fețelor: centrele și culorile de dinainte de tăiere)
cald = (orm_f > 0.4) & (h > 25) & (h < 65)
if cald.sum() > 1:
    from scipy.cluster.hierarchy import fcluster, linkage
    pts = cen[cald]
    lab_f = fcluster(linkage(pts, "single"), 0.3, "distance")
    for k in np.unique(lab_f):
        g_ = pts[lab_f == k]
        if len(g_) >= 2:
            FLACARI.append(g_.mean(0))
log("[A6] flăcări (halouri calde): %d" % len(FLACARI))

# ============================================================================= separarea pe clase
objs = {}
for n, _ in CLASE:
    if n in ("casute", "nuferi", "restul"):
        continue
    mask = cls == CI[n]
    if not mask.any():
        continue
    o_ = separa(ob, mask, "Insula_" + n)
    objs[n] = o_
    cls = np.empty(len(me.polygons), np.int32)
    me.attributes["clasa"].data.foreach_get("value", cls)
ob.name = "Insula_restul"
ob.data.name = "Insula_restul"
objs["restul"] = ob
for o_ in objs.values():
    if "clasa" in o_.data.attributes:
        o_.data.attributes.remove(o_.data.attributes["clasa"])
log("[A3] obiecte:", {k: len(o_.data.polygons) for k, o_ in objs.items()})


def set_origin(o_, p):
    """mută originea obiectului în p (coordonate lume), fără să miște geometria"""
    d = Vector(p) - o_.location
    o_.data.transform(Matrix.Translation(-d))
    o_.location = Vector(p)


# ============================================================================= A7: moara cu 4 pale, pivot și ax
MOARA = None
if "moara" in objs:
    mo = objs["moara"]
    mo.name = mo.data.name = "Moara_pale"
    axa = MOARA_PLAN["n"]
    hub = MOARA_PLAN["hub"]
    MOARA = dict(pivot=hub, ax=axa)
    # completăm la 4 pale: copie rotită cu 180° în jurul axului
    bm_ = bmesh.new()
    bm_.from_mesh(mo.data)
    dup = bmesh.ops.duplicate(bm_, geom=list(bm_.faces) + list(bm_.edges) + list(bm_.verts))
    R = Matrix.Rotation(math.pi, 4, Vector(axa))
    T = Matrix.Translation(Vector(hub)) @ R @ Matrix.Translation(-Vector(hub))
    bmesh.ops.transform(bm_, matrix=T, verts=[e for e in dup["geom"] if isinstance(e, bmesh.types.BMVert)])
    bm_.to_mesh(mo.data)
    bm_.free()
    mo.data.update()
    set_origin(mo, hub)
    log("[A7] moara: pivot %s, ax %s, %d fețe (4 pale)" % (np.round(hub, 2).tolist(), np.round(axa, 2).tolist(), len(mo.data.polygons)))

# barca: pivot la mijlocul carenei, la nivelul apei
BARCA = None
if "barca" in objs:
    bo = objs["barca"]
    bo.name = bo.data.name = "Barca"
    lag = min(INFO["lacuri"], key=lambda l_: np.hypot(g2b(l_[1])[0] - bc[0], g2b(l_[1])[1] - bc[1]))[0] if INFO["lacuri"] else -2.6
    piv = np.array([bc[0], bc[1], lag])
    set_origin(bo, piv)
    BARCA = dict(pivot=piv, ax_lung=np.array([ax[0], ax[1], 0.0]))
    log("[A4] barca: pivot %s, %d fețe" % (np.round(piv, 2).tolist(), len(bo.data.polygons)))

# ============================================================================= perf: simplificare pe clase
RATIO = {"stanci": 0.35, "restul": 0.6, "iarba": 0.5, "frunzis": 0.6, "flori": 0.7}
tri_inainte = sum(len(o_.data.polygons) for o_ in scene.objects if o_.type == "MESH" and not o_.name.startswith(("Apa", "Cascade")))
if not args.fara_simplificare:
    for n, r in RATIO.items():
        o_ = objs.get(n)
        if o_ is None:
            continue
        bpy.ops.object.select_all(action="DESELECT")
        o_.select_set(True)
        bpy.context.view_layer.objects.active = o_
        # sudăm vârfurile (păstrând UV-urile pe colțuri), ca simplificarea să vadă cusăturile UV și să le păstreze
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.mesh.remove_doubles(threshold=1e-5)
        bpy.ops.object.mode_set(mode="OBJECT")
        n0 = len(o_.data.polygons)
        md = o_.modifiers.new("simplificare", "DECIMATE")
        md.decimate_type = "COLLAPSE"
        md.ratio = r
        md.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=md.name)
        log("[perf] %-8s %6d -> %6d triunghiuri" % (n, n0, len(o_.data.polygons)))
# normale netede, despărțite la muchiile ascuțite (simplificarea strică normalele salvate din fișier)
for o_ in scene.objects:
    if o_.type != "MESH" or o_.name.startswith(("Apa", "Cascade")):
        continue
    bpy.ops.object.select_all(action="DESELECT")
    o_.select_set(True)
    bpy.context.view_layer.objects.active = o_
    if o_.name.split("_")[-1] in RATIO or args.fara_simplificare is False:
        try:
            bpy.ops.mesh.customdata_custom_splitnormals_clear()
        except RuntimeError:
            pass
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(50))
tri_dupa = sum(len(o_.data.polygons) for o_ in scene.objects if o_.type == "MESH" and not o_.name.startswith(("Apa", "Cascade")))
log("[perf] insula: %d -> %d triunghiuri (fără apă și cascade)" % (tri_inainte, tri_dupa))

# ============================================================================= A2: textura ascuțită ușor
a = (img_np(ALB_IMG)[..., :3] * 255 + 0.5).clip(0, 255).astype(np.uint8)
im = Image.fromarray(a).filter(ImageFilter.UnsharpMask(radius=1.2, percent=45, threshold=2))
b = np.asarray(im, dtype=np.float32) / 255.0
rgba_t = np.concatenate([b, np.ones(b.shape[:2] + (1,), np.float32)], -1)[::-1]
ALB_IMG.pixels.foreach_set(rgba_t.ravel())
ALB_IMG.pack()
log("[A2] textura ascuțită (unsharp mask: raza 1.2 px, 45%)")

# ============================================================================= export + date
# apa: culorile de vârf (adâncime, spumă, modul apei în alfa) trec pe vârfuri, ca float; importul din GLB le pune ca
# BYTE_COLOR pe colțuri, iar exportul ar pierde alfa (modul apei: 0 râu, 0.5 lac, 1 cascadă)
for o_ in (OB["Apa"], OB["Cascade"]):
    m_ = o_.data
    src = m_.color_attributes[0]
    vals = np.empty(len(src.data) * 4, np.float32)
    src.data.foreach_get("color", vals)
    vals = vals.reshape(-1, 4)
    lv = np.empty(len(m_.loops), np.int32)
    m_.loops.foreach_get("vertex_index", lv)
    per_v = np.zeros((len(m_.vertices), 4), np.float32)
    per_v[lv] = vals if src.domain == "CORNER" else vals[lv]
    cv = np.empty(len(m_.vertices) * 3, np.float32)
    m_.vertices.foreach_get("co", cv)
    cv = cv.reshape(-1, 3) + np.array(o_.location)
    if o_.name.startswith("Apa"):
        # A4: inele de spumă în lacuri în jurul a tot ce iese din apă (stâlpii debarcaderului, pietre, barca)
        lac = np.abs(per_v[:, 3] - 0.5) < 0.2
        tris = []
        for oo in scene.objects:
            if oo.type != "MESH" or oo.name.startswith(("Apa", "Cascade")):
                continue
            c3, f3, _, _ = arrays(oo.data)
            c3 = c3 + np.array(oo.location)
            Pz = c3[f3][:, :, 2]
            tris.append(np.stack([c3[f3].mean(1)[:, 0], c3[f3].mean(1)[:, 1], Pz.min(1), Pz.max(1)], 1))
        tris = np.concatenate(tris)
        nsp = 0
        for lvl, _c in INFO["lacuri"]:
            sel = lac & (np.abs(cv[:, 2] - lvl) < 0.25)
            if not sel.any():
                continue
            lo_, hi_ = cv[sel, :2].min(0) - 0.5, cv[sel, :2].max(0) + 0.5
            cross = (tris[:, 2] < lvl + 0.04) & (tris[:, 3] > lvl - 0.04) & (tris[:, 0] > lo_[0]) & (tris[:, 0] < hi_[0]) & \
                (tris[:, 1] > lo_[1]) & (tris[:, 1] < hi_[1])
            if cross.sum() < 3:
                continue
            d, _ = cKDTree(tris[cross, :2]).query(cv[sel, :2])
            # doar obiectele din apă, nu malul: malul îl are deja canalul R (adâncimea), deci păstrăm spuma unde e adânc
            inel = np.clip(1.0 - d / 0.32, 0, 1) * (per_v[sel, 0] > 0.15)
            per_v[sel, 1] = np.maximum(per_v[sel, 1], inel)
            nsp += int((inel > 0.3).sum())
        log("[A4] inele de spumă în lacuri: %d vârfuri" % nsp)
    else:
        # A5: cascadele care cad în gol (baza sub insulă) se topesc spre bază în norii de dedesubt: R = 1 pe ele
        _, wv = np.unique(np.round(cv / 1e-4).astype(np.int64), axis=0, return_inverse=True)
        fvc = np.empty(len(m_.polygons) * 3, np.int32)
        m_.polygons.foreach_get("vertices", fvc)
        fvc = wv.ravel()[fvc.reshape(-1, 3)]
        e = np.concatenate([fvc[:, [0, 1]], fvc[:, [1, 2]]])
        g = coo_matrix((np.ones(len(e)), (e[:, 0], e[:, 1])), shape=(wv.max() + 1, wv.max() + 1))
        _, labv = connected_components(g, directed=False)
        labv = labv[wv.ravel()]
        for c_ in np.unique(labv):
            vv = labv == c_
            if cv[vv, 2].min() < -4.0:
                per_v[vv, 0] = 1.0
        log("[A5] cascade care cad în gol: %d vârfuri marcate" % int((per_v[:, 0] > 0.5).sum()))
    m_.color_attributes.remove(src)
    dst = m_.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    dst.data.foreach_set("color", per_v.ravel())
    m_.color_attributes.active_color = dst
os.makedirs(os.path.dirname(args.out), exist_ok=True)
bpy.ops.object.select_all(action="DESELECT")
for o_ in scene.objects:
    if o_.type == "MESH":
        o_.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.abspath(args.out), use_selection=True, export_apply=True, export_yup=True,
                          export_image_format="JPEG", export_jpeg_quality=92, export_vertex_color="ACTIVE",
                          export_normals=True)
log("[glb]", args.out, f"{os.path.getsize(args.out) / 1e6:.1f} MB")

with open(args.data, "w") as f:
    f.write("# Insula 1 (v3, Faza A): date generate de blender/insula1/v3_faza_a.py (metri, Y în sus).\n")
    f.write("extends RefCounted\n\n")
    body = INFO["text"].split("extends RefCounted", 1)[1].strip()
    body = re.sub(r"## densitatea texturii.*\n.*\n?", "", body)
    f.write(body.strip() + "\n\n")
    # constantele se scriu mereu (cu valori implicite), ca scriptul din Godot să compileze oricum
    f.write("## moara: pivotul palelor (butucul) și axul de rotație\n")
    f.write(f"const MOARA_PIVOT := {gd_vec(MOARA['pivot']) if MOARA else 'Vector3.ZERO'}\n")
    f.write(f"const MOARA_AX := {gd_vec(MOARA['ax']) if MOARA else 'Vector3.FORWARD'}\n")
    f.write("## barca: pivotul (mijlocul carenei, la nivelul apei) și direcția lungă a carenei\n")
    f.write(f"const BARCA_PIVOT := {gd_vec(BARCA['pivot']) if BARCA else 'Vector3.ZERO'}\n")
    f.write(f"const BARCA_AX := {gd_vec(BARCA['ax_lung']) if BARCA else 'Vector3.RIGHT'}\n")
    f.write("## flăcările felinarelor (halouri calde care pâlpâie)\n")
    f.write("const FLACARI: Array[Vector3] = [\n")
    for p_ in FLACARI:
        f.write(f"\t{gd_vec(p_)},\n")
    f.write("]\n")
    f.write("## obiectele insulei pe clase (numele din GLB), cu triunghiurile după simplificare\n")
    f.write("const CLASE := {%s}\n" % ", ".join(f'"{o_.name}": {len(o_.data.polygons)}' for o_ in scene.objects if o_.type == "MESH"))
log("[date]", args.data)
log("gata")
