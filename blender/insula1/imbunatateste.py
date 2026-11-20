"""
Insula 1, îmbunătățită: pornește de la insula trimisă (GLB-ul din Tripo, pregătit cu blender/island_prep.py:
metri, căsuțele pe pozițiile din joc) și o face mai clară și mai vie, fără s-o refacă.

  1. textura de bază originală (2048 px) e mărită x4 cu Real-ESRGAN (upscale.py, rulat înainte);
  2. apa plată (râul, laguna, iazurile) și cascadele devin obiecte separate („Apa”, „Cascade”), cu UV-uri pentru
     curgere și culori de vârf pentru shaderul de apă din Godot; forma lor rămâne cea originală
     (doar suprafața apei e netezită, marginile rămân lipite de mal);
  3. textura insulei devine 4096 px (din imaginea mărită, pe aceleași UV-uri ca originalul): de 2 ori mai mulți
     pixeli pe metru și margini mult mai curate;
  4. culori puțin mai vii (saturație, contrast); luminile (felinare, ferestre, cristale) într-o mască (ORM.r);
  5. exportă godot/assets/models/insula1/insula1.glb (Insula, Apa, Cascade) cu texturile incluse și datele
     (nivelurile apei, cascadele, portalul) în godot/insula1/data/insula1_info.gd.

    python blender/insula1/imbunatateste.py -- --textura <baza_8192.png>    (cu modulul bpy al Blender 5.1)
"""
import argparse
import math
import os
import sys
import time

import bpy  # noqa: I001  (bpy înainte de bmesh)
import bmesh
import numpy as np
from mathutils import Vector
from PIL import Image
from scipy.cluster.hierarchy import fcluster, linkage
from scipy.sparse import coo_matrix
from scipy.sparse.csgraph import connected_components
from scipy.spatial import cKDTree

Image.MAX_IMAGE_PIXELS = None
T0 = time.time()
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
ap = argparse.ArgumentParser()
ap.add_argument("--src", default=os.path.join(ROOT, "blender/out_insula1/insula1.glb"))
ap.add_argument("--textura", required=True, help="textura de bază mărită x4 (din upscale.py)")
ap.add_argument("--atlas", type=int, default=4096)
ap.add_argument("--fara-coacere", action="store_true", help="doar clasificarea și apa, fără textură și export (verificări rapide)")
ap.add_argument("--out", default=os.path.join(ROOT, "blender/out_insula1/insula1_imbunatatita.glb"))  # intrarea pentru v3_faza_a.py
ap.add_argument("--data", default=os.path.join(ROOT, "blender/out_insula1/insula1_imbunatatita_info.gd"))  # intrare pentru v3_faza_a.py
ap.add_argument("--blend", default="", help="salvează și scena .blend (pentru previzualizări)")
args = ap.parse_args(argv)

CASTEL = np.array([0.25, 0.55])  # centrul castelului (coordonate Blender, metri)
PORTAL_APROX = np.array([7.4, 5.45, 1.6])


def log(*a):
    print(f"[{time.time() - T0:7.1f}s]", *a, flush=True)


def hsv(a):
    mx, mn = a.max(-1), a.min(-1)
    d = np.maximum(mx - mn, 1e-4)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    h = np.where(mx == r, ((g - b) / d) % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) * 60
    return h, (mx - mn) / np.maximum(mx, 1e-4), mx


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def img_np(img):
    w, h = img.size
    a = np.empty(w * h * img.channels, np.float32)
    img.pixels.foreach_get(a)
    return a.reshape(h, w, img.channels)[::-1]


def arrays(me, uv_name=None):
    n = len(me.polygons)
    co = np.empty(len(me.vertices) * 3, np.float32)
    me.vertices.foreach_get("co", co)
    fv = np.empty(n * 3, np.int32)
    me.polygons.foreach_get("vertices", fv)
    ls = np.empty(n, np.int32)
    me.polygons.foreach_get("loop_start", ls)
    lay = me.uv_layers[uv_name] if uv_name else me.uv_layers.active
    uv = np.empty(len(me.loops) * 2, np.float32)
    lay.data.foreach_get("uv", uv)
    return co.reshape(-1, 3), fv.reshape(-1, 3), ls, uv.reshape(-1, 2)


def face_pairs(fv, nv):
    """perechi de fețe vecine (au o muchie comună)"""
    e = np.concatenate([fv[:, [0, 1]], fv[:, [1, 2]], fv[:, [2, 0]]])
    e.sort(1)
    fid = np.tile(np.arange(len(fv)), 3)
    key = e[:, 0].astype(np.int64) * nv + e[:, 1]
    o = np.argsort(key, kind="stable")
    ks = key[o]
    same = ks[1:] == ks[:-1]
    return fid[o][:-1][same], fid[o][1:][same], key


def components(mask, A, B, n):
    m = mask[A] & mask[B]
    g = coo_matrix((np.ones(int(m.sum())), (A[m], B[m])), shape=(n, n))
    return connected_components(g, directed=False)[1]


def boundary_verts(fv, nv):
    e = np.concatenate([fv[:, [0, 1]], fv[:, [1, 2]], fv[:, [2, 0]]])
    e.sort(1)
    key = e[:, 0].astype(np.int64) * nv + e[:, 1]
    u, c = np.unique(key, return_counts=True)
    b = u[c == 1]
    return np.unique(np.concatenate([b // nv, b % nv]))


# ============================================================================= 1. import + clasificarea fețelor
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
bpy.ops.import_scene.gltf(filepath=os.path.abspath(args.src))
ob = [o for o in scene.objects if o.type == "MESH"][0]
for o in [o for o in scene.objects if o.type == "EMPTY"]:
    for c in o.children:
        c.parent = None
    bpy.data.objects.remove(o)
ob.name = "Insula"
me = ob.data
src_mat = me.materials[0]
nodes = src_mat.node_tree.nodes
tex_nodes = [n for n in nodes if n.type == "TEX_IMAGE"]
base_node = next(n for n in tex_nodes if any(l.to_socket.name == "Base Color" for l in n.outputs[0].links))
BASE_IMG = base_node.image
MR_IMG = next(n.image for n in tex_nodes if any(l.to_node.type == "SEPARATE_COLOR" for l in n.outputs[0].links))
base = img_np(BASE_IMG)[..., :3].copy()
TH, TW = base.shape[:2]
co, fv, ls, uv = arrays(me)
nf, nv = len(fv), len(co)
log("[import]", nv, "vârfuri", nf, "fețe", f"textura {TW}x{TH}")


def sample(img, u):
    h_, w_ = img.shape[:2]
    x = np.clip((u[:, 0] * w_).astype(int), 0, w_ - 1)
    y = np.clip(((1 - u[:, 1]) * h_).astype(int), 0, h_ - 1)
    return img[y, x]


U3 = np.stack([uv[ls + k] for k in range(3)], 1)
cols = (2 * sample(base, U3.mean(1)) + sample(base, U3[:, 0]) + sample(base, U3[:, 1]) + sample(base, U3[:, 2])) / 5
P = co[fv]
cr = np.cross(P[:, 1] - P[:, 0], P[:, 2] - P[:, 0])
area = 0.5 * np.linalg.norm(cr, axis=1)
nrm = cr / np.maximum(2 * area[:, None], 1e-12)
cen = P.mean(1)
h, s, v = hsv(cols)
up = nrm[:, 2]
zc = cen[:, 2]
rc = np.hypot(cen[:, 0] - CASTEL[0], cen[:, 1] - CASTEL[1])
A_, B_, _ = face_pairs(fv, nv)
# vecinătate pe vârfuri sudate (GLB-ul dublează vârfurile la cusăturile UV; apa nu trebuie ruptă de ele)
_, weld = np.unique(np.round(co / 1e-4).astype(np.int64), axis=0, return_inverse=True)
weld = weld.ravel()
Aw, Bw, _ = face_pairs(weld[fv], int(weld.max()) + 1)

apa_col = (h > 168) & (h < 214) & (s > 0.22) & (v > 0.26)
apa_pal = (h > 165) & (h < 218) & (s > 0.05) & (v > 0.70)
plat = apa_col & (up > 0.72) & (zc < -0.9)
# închidere pe graful fețelor: fețele înconjurate de apă devin apă (găuri mici din clasificare)
for _ in range(3):
    cnt = np.bincount(Aw[plat[Bw]], minlength=nf) + np.bincount(Bw[plat[Aw]], minlength=nf)
    plat = plat | ((cnt >= 2) & (up > 0.55) & (zc < -0.9))
lab = components(plat, Aw, Bw, nf)
keep = np.zeros(nf, bool)
for c in np.unique(lab[plat]):
    f = np.where((lab == c) & plat)[0]
    if area[f].sum() < 0.2:
        continue
    keep[f] = True
plat = keep
# a doua trecere (v3): apa pictată mai închisă (sub poduri, la margini) crește din apa găsită, la același nivel cu ea,
# ca textura veche de apă să dispară complet (pietrele albăstrui de pe mal sunt mai puțin saturate)
apa_inchisa = (h > 165) & (h < 230) & (s > 0.28) & (v > 0.06) & (up > 0.7) & (zc < -0.9)
extra = np.zeros(nf, bool)
if plat.any():
    wi = np.where(plat)[0]
    dxy, j = cKDTree(cen[wi, :2]).query(cen[:, :2])
    cand = apa_inchisa & (dxy < 0.6) & (np.abs(zc - zc[wi][j]) < 0.15) & ~plat
    for _ in range(10):
        vec = np.zeros(nf, bool)
        vec[Aw[plat[Bw]]] = True
        vec[Bw[plat[Aw]]] = True
        add = cand & vec & ~plat
        if not add.any():
            break
        extra |= add
        plat |= add
log("[apa] a doua trecere: +%d fețe de apă pictată mai închisă" % extra.sum())

cad = (apa_col | apa_pal) & (np.abs(up) < 0.7) & (zc < 2.6) & ~((rc < 3.4) & (zc > -1.0)) & ~plat
for _ in range(2):  # cascadele: vecinătatea nesudată (cu sudare se lipesc de cristalele palide din jur)
    cnt = np.bincount(A_[cad[B_]], minlength=nf) + np.bincount(B_[cad[A_]], minlength=nf)
    cad = cad | ((cnt >= 2) & (np.abs(up) < 0.8) & ((h > 160) & (h < 222)) & ~plat)
lab = components(cad, A_, B_, nf)
keep = np.zeros(nf, bool)
for c in np.unique(lab[cad]):
    f = np.where((lab == c) & cad)[0]
    if area[f].sum() < 0.15 or np.ptp(zc[f]) < 0.5 or np.average(s[f], weights=area[f]) < 0.12:
        continue
    keep[f] = True
cad = keep
log("[apa] apă plată %d fețe (%.1f m2), cascade %d fețe (%.1f m2)" % (plat.sum(), area[plat].sum(), cad.sum(), area[cad].sum()))

# portalul: panoul albastru-pal din arcada aurie, cu fața spre insulă
near = np.linalg.norm(cen - PORTAL_APROX, axis=1) < 0.9
pan = near & (h > 185) & (h < 235) & (s > 0.06) & (s < 0.55) & (v > 0.6) & (np.abs(up) < 0.35)
dirc = np.array([CASTEL[0], CASTEL[1], 0.0]) - PORTAL_APROX
dirc[2] = 0
dirc /= np.linalg.norm(dirc)
fata = pan & (nrm @ dirc > 0.4)
fp = np.where(fata)[0]
pn = np.average(nrm[fp], axis=0, weights=area[fp])
pn[2] = 0
pn /= np.linalg.norm(pn)
vp = np.unique(fv[fp].ravel())
lat = np.cross(Vector((0, 0, 1)), Vector(pn))
lat = np.array(lat) / np.linalg.norm(lat)
pts = co[vp]
pc = np.average(cen[fp], axis=0, weights=area[fp])
xs, zs = (pts - pc) @ lat, pts[:, 2]
# panoul găsit trece și pe după stâlpi și se oprește la capiteluri; deschiderea e mai îngustă și urcă în arc
PORTAL = dict(centru=[float(pc[0] + lat[0] * (xs.max() + xs.min()) / 2), float(pc[1] + lat[1] * (xs.max() + xs.min()) / 2),
                      float(zs.min() + 0.62 * (zs.max() - zs.min()))],
              normala=[float(pn[0]), float(pn[1]), 0.0], latime=float(0.56 * (xs.max() - xs.min())),
              inaltime=float(1.25 * (zs.max() - zs.min())))
log("[portal]", {k: (np.round(v_, 3).tolist() if isinstance(v_, list) else round(v_, 3)) for k, v_ in PORTAL.items()}, f"{len(fp)} fețe")

# ============================================================================= 2. separă apa și cascadele
tip = np.zeros(nf, np.int32)
tip[plat] = 1
tip[cad] = 2
attr = me.attributes.new("apa_tip", "INT", "FACE")
attr.data.foreach_set("value", tip)


def separa(obj, mask, name):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_mode(type="FACE")
    bpy.ops.mesh.select_all(action="DESELECT")
    bm = bmesh.from_edit_mesh(obj.data)
    bm.faces.ensure_lookup_table()
    for i in np.where(mask)[0]:
        bm.faces[int(i)].select_set(True)
    bmesh.update_edit_mesh(obj.data)
    before = set(scene.objects)
    bpy.ops.mesh.separate(type="SELECTED")
    bpy.ops.object.mode_set(mode="OBJECT")
    new = [o for o in scene.objects if o not in before][0]
    new.name = name
    new.data.name = name
    return new


def merge_doubles(obj, dist=1e-4):
    """vârfurile tăiate la cusăturile UV se lipesc la loc (apa primește UV-uri noi, continue)"""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=dist)
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()


apa = separa(ob, tip > 0, "Apa")
merge_doubles(apa)
t2 = np.empty(len(apa.data.polygons), np.int32)
apa.data.attributes["apa_tip"].data.foreach_get("value", t2)
casc = separa(apa, t2 == 2, "Cascade")
me = ob.data
log("[separare] Insula %d fețe, Apa %d, Cascade %d" % (len(me.polygons), len(apa.data.polygons), len(casc.data.polygons)))

# fețele insulei rămase (pentru podurile de deasupra râului)
co_i, fv_i, _, _ = arrays(me)


def set_colors(obj, rgba):
    m = obj.data
    a = m.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    a.data.foreach_set("color", rgba.astype(np.float32).ravel())
    m.color_attributes.active_color = a
    try:
        m.color_attributes.render_color_index = m.color_attributes.active_color_index
    except AttributeError:
        pass


def set_uv_from_verts(obj, uvv, name="UVMap"):
    m = obj.data
    for lay in list(m.uv_layers):
        m.uv_layers.remove(lay)
    lay = m.uv_layers.new(name=name)
    lv = np.empty(len(m.loops), np.int32)
    m.loops.foreach_get("vertex_index", lv)
    lay.data.foreach_set("uv", uvv[lv].astype(np.float32).ravel())


def clear_custom_normals(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    try:
        bpy.ops.mesh.customdata_custom_splitnormals_clear()
    except RuntimeError:
        pass
    obj.data.shade_smooth()


# --- apa plată: râul (curge în jurul castelului), laguna și iazurile (lacuri)
m = apa.data
co_a, fv_a, _, _ = arrays(m)
nva, nfa = len(co_a), len(fv_a)
A2, B2, _ = face_pairs(fv_a, nva)
labf = components(np.ones(nfa, bool), A2, B2, nfa)
bnd = np.zeros(nva, bool)
bnd[boundary_verts(fv_a, nva)] = True
rgba = np.zeros((nva, 4), np.float32)
uvv = np.zeros((nva, 2), np.float32)
LACURI, RAU = [], None
vlab = np.full(nva, -1)
for c in np.unique(labf):
    vlab[np.unique(fv_a[labf == c].ravel())] = c
riv_v = np.zeros(nva, bool)
for c in np.unique(labf):
    vi = np.where(vlab == c)[0]
    z = co_a[vi, 2]
    lvl = float(np.median(z[~bnd[vi]])) if (~bnd[vi]).any() else float(np.median(z))
    inner = vi[~bnd[vi]]
    co_a[inner, 2] = lvl
    rr = np.hypot(co_a[vi, 0] - CASTEL[0], co_a[vi, 1] - CASTEL[1])
    is_river = -1.8 < lvl < -1.05 and 1.2 < float(np.median(rr)) < 7.0
    if is_river:
        riv_v[vi] = True
    else:
        LACURI.append(dict(nivel=lvl, centru=co_a[vi].mean(0).tolist(), aria=0.0))
    # adâncimea (lacuri): distanța până la mal
    b = vi[bnd[vi]]
    if len(b):
        d, _ = cKDTree(co_a[b, :2]).query(co_a[vi, :2])
        rgba[vi, 0] = np.clip(d / 0.9, 0, 1)
    rgba[vi, 3] = 0.0 if is_river else 0.5
    if not is_river:
        uvv[vi, 0] = co_a[vi, 0]
        uvv[vi, 1] = 1.0 - co_a[vi, 1]  # glTF/Godot întoarce V: UV.y în Godot = 1 - v
m.vertices.foreach_set("co", co_a.astype(np.float32).ravel())
if riv_v.any():
    vi = np.where(riv_v)[0]
    x, y = co_a[vi, 0] - CASTEL[0], co_a[vi, 1] - CASTEL[1]
    th = np.degrees(np.arctan2(y, x)) % 360
    r = np.hypot(x, y)
    # tăietura unghiului în cea mai mare golire (râul nu face cercul complet)
    hs = np.sort(np.unique(np.round(th)))
    gaps = np.diff(np.concatenate([hs, [hs[0] + 360]]))
    cut = (hs[np.argmax(gaps)] + gaps.max() / 2) % 360
    th = (th - cut) % 360
    bins = np.clip((th / 4).astype(int), 0, 89)
    r_in = np.full(90, np.nan)
    r_out = np.full(90, np.nan)
    for b_ in np.unique(bins):
        rb = r[bins == b_]
        r_in[b_], r_out[b_] = np.percentile(rb, 3), np.percentile(rb, 97)
    ok = ~np.isnan(r_in)
    idx = np.arange(90)
    r_in = np.interp(idx, idx[ok], r_in[ok])
    r_out = np.interp(idx, idx[ok], r_out[ok])
    k = np.array([1, 2, 3, 2, 1], np.float32)
    k /= k.sum()
    r_in = np.convolve(np.pad(r_in, 2, mode="edge"), k, "valid")
    r_out = np.convolve(np.pad(r_out, 2, mode="edge"), k, "valid")
    fb = th / 4 - 0.5
    ri = np.interp(fb, idx, r_in)
    ro = np.interp(fb, idx, r_out)
    across = np.clip((r - ri) / np.maximum(ro - ri, 0.3), 0, 1)
    rmid = float(np.median(r))
    along = np.radians(th) * rmid  # metri pe direcția curgerii (invers acelor de ceas, privit de sus)
    uvv[vi, 0] = across
    uvv[vi, 1] = 1.0 - along
    # spumă sub poduri. Un pod = piese din insulă deasupra râului, la înălțimea unui pod (0,3-2 m peste apă), care
    # traversează albia de la un mal la altul. Apa de sub pod e pictată prea închis ca să fie găsită ca apă,
    # așa că spuma merge pe apa din jurul podului.
    lvl_r = float(np.median(co_a[vi, 2]))
    th_lo, th_hi = th.min(), th.max()
    ci = co_i[fv_i].mean(1)
    xi, yi = ci[:, 0] - CASTEL[0], ci[:, 1] - CASTEL[1]
    thi = ((np.degrees(np.arctan2(yi, xi)) % 360) - cut) % 360
    ri_ = np.hypot(xi, yi)
    fbi = thi / 4 - 0.5
    a_in = (ri_ - np.interp(fbi, idx, r_in)) / np.maximum(np.interp(fbi, idx, r_out) - np.interp(fbi, idx, r_in), 0.3)
    peste = (thi > th_lo) & (thi < th_hi) & (a_in > 0.05) & (a_in < 0.95) & (ci[:, 2] > lvl_r + 0.3) & (ci[:, 2] < lvl_r + 2.0)
    pod_c = []
    if peste.sum() > 1:
        fi = np.where(peste)[0]
        gl = fcluster(linkage(ci[fi, :2], "single"), 0.4, "distance")
        for g_ in np.unique(gl):
            ff = fi[gl == g_]
            if len(ff) >= 6 and np.ptp(a_in[ff]) >= 0.6:
                pod_c.append(ci[ff])
    if pod_c:
        d, _ = cKDTree(np.concatenate(pod_c)[:, :2]).query(co_a[vi, :2])
        rgba[vi, 1] = np.clip(1.0 - d / 1.0, 0, 1)
    PODURI = [c_.mean(0).round(2).tolist() for c_ in pod_c]
    log("[poduri]", PODURI)
    sub = rgba[vi, 1] > 0.5
    RAU = dict(nivel=lvl_r, raza=rmid, taietura=float(cut), poduri=int(sub.sum()))
    log("[râu] nivel %.2f, raza medie %.2f m, lungime %.1f m, %d vârfuri sub poduri" % (lvl_r, rmid, along.max(), sub.sum()))
set_colors(apa, rgba)
set_uv_from_verts(apa, uvv)
m.update()
clear_custom_normals(apa)
log("[lacuri]", [(round(l_["nivel"], 2), np.round(l_["centru"], 1).tolist()) for l_ in LACURI])

# --- cascadele: UV.x = 0..1 pe lățime, UV.y = metri de la buză în jos; spumă la buză (G) și la bază (B)
m = casc.data
co_c, fv_c, _, _ = arrays(m)
nvc, nfc = len(co_c), len(fv_c)
A3, B3, _ = face_pairs(fv_c, nvc)
labc = components(np.ones(nfc, bool), A3, B3, nfc)
cl = []
for c in np.unique(labc):
    cl.append((c, co_c[np.unique(fv_c[labc == c].ravel())].mean(0)))
cc = np.array([p for _, p in cl])
grp = fcluster(linkage(cc[:, :2], "single"), 1.2, "distance") if len(cc) > 1 else np.array([1])
rgba = np.zeros((nvc, 4), np.float32)
rgba[:, 3] = 1.0
uvv = np.zeros((nvc, 2), np.float32)
CASCADE = []
for g in np.unique(grp):
    comps_ = [cl[i][0] for i in range(len(cl)) if grp[i] == g]
    vi = np.unique(fv_c[np.isin(labc, comps_)].ravel())
    p = co_c[vi]
    buza, baza = float(np.percentile(p[:, 2], 99)), float(np.percentile(p[:, 2], 1))
    xy = p[:, :2] - p[:, :2].mean(0)
    ev, evec = np.linalg.eigh(np.cov(xy.T))
    e1 = evec[:, 1]
    pr = xy @ e1
    uvv[vi, 0] = (pr - pr.min()) / max(np.ptp(pr), 1e-3)
    uvv[vi, 1] = 1.0 - (buza - p[:, 2])
    rgba[vi, 1] = np.clip(1.0 - (buza - p[:, 2]) / 0.35, 0, 1)
    rgba[vi, 2] = np.clip(1.0 - (p[:, 2] - baza) / 0.6, 0, 1)
    top = p[p[:, 2] > buza - 0.3].mean(0)
    bot = p[p[:, 2] < baza + 0.3].mean(0)
    CASCADE.append(dict(buza=top.tolist(), baza=bot.tolist(), latime=float(np.ptp(pr)), inaltime=buza - baza))
CASCADE.sort(key=lambda d_: -d_["inaltime"])
set_colors(casc, rgba)
set_uv_from_verts(casc, uvv)
clear_custom_normals(casc)
log("[cascade]", [(np.round(d_["buza"], 2).tolist(), round(d_["inaltime"], 2), round(d_["latime"], 2)) for d_ in CASCADE])

for o_ in (apa, casc):
    o_.data.materials.clear()
mat_apa = bpy.data.materials.new("apa")
mat_apa.diffuse_color = (0.2, 0.7, 0.85, 1.0)
apa.data.materials.append(mat_apa)
casc.data.materials.append(mat_apa)
for o_ in (apa, casc, ob):
    if "apa_tip" in o_.data.attributes:
        o_.data.attributes.remove(o_.data.attributes["apa_tip"])


# ============================================================================= 3. textura: mărită x4 cu AI, păstrată pe UV-urile originale
# (am încercat și un atlas nou, cu mai mulți pixeli sus: împachetatorul din Blender umple doar 20-44% din atlas
#  cu cele ~21.000 de insule UV ale lui Tripo, față de 57% în atlasul original, deci câștigul era mic și riscant)
def np_img(name, arr, colorspace):
    hh_, ww_ = arr.shape[:2]
    rgba_ = np.concatenate([arr[..., :3], np.ones((hh_, ww_, 1), np.float32)], -1)[::-1]
    im = bpy.data.images.new(name, ww_, hh_, alpha=False)
    im.colorspace_settings.name = colorspace
    im.pixels.foreach_set(rgba_.astype(np.float32).ravel())
    im.pack()
    return im


def grade(rgb):
    """mai saturat (mai ales culorile șterse) și puțin mai mult contrast; nuanța rămâne aceeași"""
    hh, ss, vv = hsv(rgb)
    ss2 = 1.0 - (1.0 - ss) ** 1.32
    vv2 = np.clip(0.5 + (vv - 0.5) * 1.07, 0, 1)
    hp = (hh / 60.0) % 6

    def chan(nn):
        kk = (nn + hp) % 6
        return vv2 * (1 - ss2 * np.clip(np.minimum(kk, 4 - kk), 0, 1))
    return np.stack([chan(5), chan(3), chan(1)], -1).astype(np.float32)


DENS = {}
if not args.fara_coacere:
    t1 = time.time()
    big = Image.open(args.textura).convert("RGB")
    alb = np.asarray(big.resize((args.atlas, args.atlas), Image.LANCZOS), dtype=np.float32) / 255.0
    del big
    alb2 = grade(alb)
    # luminile: flăcări / ferestre calde, cristale reci (în shaderul din Godot: pâlpâie, respectiv pulsează)
    hh, ss, vv = hsv(alb2)
    cald = smooth(30, 40, hh) * smooth(64, 54, hh) * smooth(0.28, 0.45, ss) * smooth(0.88, 0.97, vv)
    rece = smooth(178, 188, hh) * smooth(232, 222, hh) * smooth(0.25, 0.4, ss) * smooth(0.86, 0.95, vv)
    from scipy import ndimage as ndi
    glow = ndi.gaussian_filter(np.clip(np.maximum(cald, 0.8 * rece), 0, 1), 1.0)
    mr = img_np(MR_IMG)[..., :3]
    sz = mr.shape[0]
    glow_s = np.asarray(Image.fromarray((glow * 255).astype(np.uint8)).resize((sz, sz), Image.BILINEAR), dtype=np.float32) / 255.0
    orm = np.stack([glow_s, mr[..., 1], mr[..., 2]], -1)  # R = lumină (mască), G = rugozitate, B = metal
    log("[textura] %dpx din imaginea mărită, saturație medie %.2f -> %.2f, texeli luminoși %.2f%% (%.0fs)" % (
        args.atlas, hsv(alb)[1].mean(), hsv(alb2)[1].mean(), 100 * (glow > 0.5).mean(), time.time() - t1))
    ALB = np_img("insula1_albedo", alb2, "sRGB")
    ORM = np_img("insula1_orm", orm, "Non-Color")
    # densitatea (aceeași peste tot, ca în original, dar de 2 ori mai mare)
    co_i, fv_i, ls_i, uv_i = arrays(me)
    T = np.stack([uv_i[ls_i + k] for k in range(3)], 1) * args.atlas
    a_uv = 0.5 * np.abs((T[:, 1, 0] - T[:, 0, 0]) * (T[:, 2, 1] - T[:, 0, 1]) - (T[:, 2, 0] - T[:, 0, 0]) * (T[:, 1, 1] - T[:, 0, 1]))
    P = co_i[fv_i]
    a3 = 0.5 * np.linalg.norm(np.cross(P[:, 1] - P[:, 0], P[:, 2] - P[:, 0]), axis=1)
    DENS["toata"] = float(np.sqrt(a_uv.sum() / a3.sum()))
    log("[densitate] %.0f px/m (înainte %.0f)" % (DENS["toata"], DENS["toata"] * TW / args.atlas))
    # materialul exportat (în Godot îl înlocuiește shaderul insulei, care ia aceleași texturi din el;
    # lumina se calculează din albedo x masca din ORM.r, deci nu mai e nevoie de o textură emisivă separată)
    mat = bpy.data.materials.new("insula1")
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    b = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(b.outputs[0], out.inputs[0])
    tb = nt.nodes.new("ShaderNodeTexImage")
    tb.image = ALB
    nt.links.new(tb.outputs[0], b.inputs["Base Color"])
    tm = nt.nodes.new("ShaderNodeTexImage")
    tm.image = ORM
    sep = nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(tm.outputs[0], sep.inputs[0])
    nt.links.new(sep.outputs[1], b.inputs["Roughness"])
    nt.links.new(sep.outputs[2], b.inputs["Metallic"])
    mat.use_backface_culling = False
    me.materials.clear()
    me.materials.append(mat)

# ============================================================================= 4. export + date pentru Godot
if args.blend:
    bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(args.blend))
if not args.fara_coacere:
    os.makedirs(os.path.dirname(args.out), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o_ in (ob, apa, casc):
        o_.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.abspath(args.out), use_selection=True, export_apply=True, export_yup=True,
                              export_image_format="JPEG", export_jpeg_quality=92, export_vertex_color="ACTIVE",
                              export_normals=True)
    log("[glb]", args.out, f"{os.path.getsize(args.out) / 1e6:.1f} MB")


def gd(p):  # Blender (x, y, z) -> Godot (x, z, -y)
    return "Vector3(%.3f, %.3f, %.3f)" % (p[0], p[2], -p[1])


os.makedirs(os.path.dirname(args.data), exist_ok=True)
with open(args.data, "w") as f:
    f.write("# Insula 1 îmbunătățită: date generate de blender/insula1/imbunatateste.py (metri, Y în sus).\n")
    f.write("extends RefCounted\n\n")
    if RAU:
        f.write(f"const NIVEL_RAU := {RAU['nivel']:.3f}\n")
    f.write("## lacurile (laguna, iazurile): [nivel, centru]\n")
    f.write("const LACURI := [\n")
    for l_ in LACURI:
        f.write(f"\t[{l_['nivel']:.3f}, {gd(l_['centru'])}],\n")
    f.write("]\n")
    f.write("## cascadele, cea mai înaltă prima: [buza, baza, lățimea]\n")
    f.write("const CASCADE := [\n")
    for c_ in CASCADE:
        f.write(f"\t[{gd(c_['buza'])}, {gd(c_['baza'])}, {c_['latime']:.2f}],\n")
    f.write("]\n")
    pn = PORTAL["normala"]
    f.write("## portalul: centrul panoului, direcția spre care privește, mărimea (lățime, înălțime)\n")
    f.write(f"const PORTAL_CENTRU := {gd(PORTAL['centru'])}\n")
    f.write(f"const PORTAL_NORMALA := {gd(pn)}\n")
    f.write(f"const PORTAL_MARIME := Vector2({PORTAL['latime']:.3f}, {PORTAL['inaltime']:.3f})\n")
    if DENS:
        f.write("## densitatea texturii (pixeli pe metru); originalul avea 28\n")
        f.write("const DENSITATE := {%s}\n" % ", ".join(f'"{k}": {v_:.0f}' for k, v_ in DENS.items()))
log("[date]", args.data)
log("gata")
