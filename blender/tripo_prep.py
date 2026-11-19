"""
Orion din Tripo Studio -> model pregătit pentru joc + aceeași planșă ca în orion_build.py.

    python tripo_prep.py --src orion_tripo.glb --out out_tripo --render sheet

Pași:
  1. importă GLB-ul din Tripo (un singur mesh texturat), îl întoarce cu fața spre -Y (spre cameră),
     îl așază cu tălpile pe sol și îl scalează la 1,2 m (în scenă: 2,4 unități, ca modelul procedural);
  2. adaugă emisie pe marcajele luminoase (spirala de pe coadă, stelele, cristalele, felinarul, lentilele):
     o mască calculată din textura de culoare (pixeli turcoaz/albaștri saturați și luminoși), fără ochi;
  3. randează pe fundalul alb al planșei: Față / 3/4 / Profil / Spate;
  4. exportă orion_tripo_game.glb (1,2 m) și, opțional, o variantă redusă pentru telefon.
"""
import argparse
import math
import os
import sys
import time

import bpy
import numpy as np
from mathutils import Vector

T0 = time.time()
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
ap = argparse.ArgumentParser()
ap.add_argument("--src", required=True)
ap.add_argument("--out", default="out_tripo")
ap.add_argument("--render", default="sheet")
ap.add_argument("--size", type=int, default=1200)
ap.add_argument("--samples", type=int, default=64)
ap.add_argument("--face-yaw", type=float, default=-15.0,
                help="rotație în jurul verticalei (grade); modelul din Tripo stă întors ~15° spre stânga lui")
ap.add_argument("--light", type=float, default=0.6)
ap.add_argument("--tag", default="")
ap.add_argument("--glow", type=float, default=1.6, help="intensitatea emisiei în randări (în GLB rămâne 1)")
ap.add_argument("--no-glb", action="store_true")
ap.add_argument("--no-eye-fix", dest="eye_fix", action="store_false",
                help="păstrează ochii pictați de Tripo (irisurile lor sunt trase spre nas: privire încrucișată)")
ap.add_argument("--no-pack-purple", dest="pack_purple", action="store_false",
                help="păstrează rucsacul în culoarea din Tripo (vișiniu)")
ap.add_argument("--lod", type=int, default=0,
                help="o variantă redusă la atâtea triunghiuri (0 = fără; reducerea strică aspectul blănii și al ochelarilor)")
args = ap.parse_args(argv)
os.makedirs(args.out, exist_ok=True)


def log(*a):
    print(f"[{time.time() - T0:7.1f}s]", *a, flush=True)


bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
bpy.ops.import_scene.gltf(filepath=os.path.abspath(args.src))
meshes = [o for o in scene.objects if o.type == "MESH"]
body = meshes[0]
log("[import]", body.name, len(body.data.vertices), "verts", len(body.data.polygons), "faces")

# --- normalise: apply transforms, face -Y, feet on z=0, height 2.4 units (= 1.2 m at export scale 0.5)
bpy.ops.object.select_all(action="DESELECT")
for o in scene.objects:
    if o.type == "EMPTY":
        for c in o.children:
            c.parent = None
for o in [o for o in scene.objects if o.type == "EMPTY"]:
    bpy.data.objects.remove(o)
body.select_set(True)
bpy.context.view_layer.objects.active = body
body.rotation_euler = (0, 0, math.radians(args.face_yaw))
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
co = np.empty(len(body.data.vertices) * 3, np.float32)
body.data.vertices.foreach_get("co", co)
co = co.reshape(-1, 3)
lo, hi = co.min(0), co.max(0)
H = 2.4
k = H / (hi[2] - lo[2])
co = (co - [(lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, lo[2]]) * k
body.data.vertices.foreach_set("co", co.ravel())
body.data.update()
log("[normalise] scale", round(float(k), 3), "size", (co.max(0) - co.min(0)).round(3))



# ============================================================================= textures: glow mask, metal mask
def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def img_np(img):
    """Blender image -> float array HxWxC, top row first"""
    w, h = img.size
    a = np.empty(w * h * img.channels, np.float32)
    img.pixels.foreach_get(a)
    return a.reshape(h, w, img.channels)[::-1]


def np_img(name, arr, colorspace="sRGB"):
    h, w = arr.shape[:2]
    rgba = np.concatenate([arr[..., :3], np.ones((h, w, 1), np.float32)], -1)[::-1]
    img = bpy.data.images.new(name, w, h, alpha=False)
    img.colorspace_settings.name = colorspace
    img.pixels.foreach_set(rgba.ravel())
    img.pack()
    return img


src_mat = body.data.materials[0]
tex_nodes = [n for n in src_mat.node_tree.nodes if n.type == "TEX_IMAGE"]
base_img = next(n.image for n in tex_nodes if any(l.to_socket.name == "Base Color" for l in n.outputs[0].links))
mr_img = next(n.image for n in tex_nodes if n.image is not base_img)
base = img_np(base_img)[..., :3]
mr = img_np(mr_img)[..., :3]
TH, TW = base.shape[:2]

# glowing marks = saturated, bright cyan/blue paint (tail spiral, stars, crystals, lantern, lenses, compass)
mx, mn = base.max(-1), base.min(-1)
sat = (mx - mn) / np.maximum(mx, 1e-4)
d = np.maximum(mx - mn, 1e-4)
r_, g_, b_ = base[..., 0], base[..., 1], base[..., 2]
hue = np.where(mx == r_, ((g_ - b_) / d) % 6, np.where(mx == g_, (b_ - r_) / d + 2, (r_ - g_) / d + 4)) * 60
glow = smooth(165, 182, hue) * smooth(252, 236, hue) * smooth(0.3, 0.55, sat) * smooth(0.35, 0.7, mx)
# white-hot centres next to the blue paint
from PIL import Image, ImageDraw, ImageFilter
near = np.asarray(Image.fromarray((glow * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(9))).astype(np.float32) / 255
glow = np.maximum(glow, near * smooth(0.78, 0.95, mx) * smooth(0.35, 0.1, sat))

# ...but not the eyes: drop texels that belong to faces in the eye band of the head
me = body.data
nf = len(me.polygons)
cen = np.empty(nf * 3, np.float32)
me.polygons.foreach_get("center", cen)
cen = cen.reshape(-1, 3)
nor = np.empty(nf * 3, np.float32)
me.polygons.foreach_get("normal", nor)
nor = nor.reshape(-1, 3)
ls = np.empty(nf, np.int32)
me.polygons.foreach_get("loop_start", ls)
uv = np.empty(len(me.loops) * 2, np.float32)
me.uv_layers.active.data.foreach_get("uv", uv)
uv = uv.reshape(-1, 2)
eye_band = (cen[:, 2] > 1.42) & (cen[:, 2] < 1.66) & (nor[:, 1] < 0.2)
excl = Image.new("L", (TW, TH), 0)
dr = ImageDraw.Draw(excl)
for f in np.where(eye_band)[0]:
    tri = [(float(uv[ls[f] + k, 0] * TW), float((1 - uv[ls[f] + k, 1]) * TH)) for k in range(3)]
    dr.polygon(tri, fill=255)
excl = np.asarray(excl.filter(ImageFilter.MaxFilter(5))).astype(np.float32) / 255
glow *= 1 - excl
emis = base * glow[..., None]
lum = emis.max(-1, keepdims=True)
emis = np.clip(emis * 1.15 + (lum ** 3) * 0.15, 0, 1)  # a touch brighter, whiter in the hot centres
log("[glow] texels", int((glow > 0.5).sum()), "eye faces excluded", int(eye_band.sum()))

# backpack fabric: Tripo painted it burgundy, the concept has it purple -> rotate that hue on the bag only
if args.pack_purple:
    # the bag sits behind the torso (its side panels reach forward to y ~ -0.2); the scarf ring around the
    # neck ends at y ~ -0.15 at the back, so it stays red
    scarf = (cen[:, 2] > 1.1) & (cen[:, 1] < -0.12)
    bag = (cen[:, 1] > -0.25) & (cen[:, 2] > 0.5) & (cen[:, 2] < 1.75) & ~scarf
    bag_mask = Image.new("L", (TW, TH), 0)
    dr = ImageDraw.Draw(bag_mask)
    for f in np.where(bag)[0]:
        dr.polygon([(float(uv[ls[f] + k, 0] * TW), float((1 - uv[ls[f] + k, 1]) * TH)) for k in range(3)], fill=255)
    bag_mask = np.asarray(bag_mask).astype(np.float32) / 255
    # decide in sRGB, where burgundy (hue < 10 deg) and brown leather (16..34 deg) separate cleanly
    srgb_ = np.where(base <= 0.0031308, base * 12.92, 1.055 * np.power(np.maximum(base, 1e-8), 1 / 2.4) - 0.055)
    smx, smn = srgb_.max(-1), srgb_.min(-1)
    ssat = (smx - smn) / np.maximum(smx, 1e-4)
    sd = np.maximum(smx - smn, 1e-4)
    shue = np.where(smx == srgb_[..., 0], ((srgb_[..., 1] - srgb_[..., 2]) / sd) % 6,
                    np.where(smx == srgb_[..., 1], (srgb_[..., 2] - srgb_[..., 0]) / sd + 2,
                             (srgb_[..., 0] - srgb_[..., 1]) / sd + 4)) * 60
    red = (smooth(0.28, 0.4, ssat) * np.maximum(smooth(300, 318, shue), smooth(13, 7, shue))
           * smooth(0.12, 0.22, smx) * bag_mask)
    # same sRGB value, hue 285 deg (purple), slightly less saturated -> back to linear
    v, s_ = smx, ssat * 0.9
    f6 = 285 / 60 - 4
    pp, tt = v * (1 - s_), v * (1 - s_ * (1 - f6))
    purple_s = np.stack([tt, pp, v], -1)  # HSV sector 4 (240..300 deg)
    purple = np.where(purple_s <= 0.04045, purple_s / 12.92, ((purple_s + 0.055) / 1.055) ** 2.4)
    base = base * (1 - red[..., None]) + purple * red[..., None]
    log("[bag] recoloured texels", int((red > 0.5).sum()))
    BASE_REPLACED = True
else:
    BASE_REPLACED = False

# metal only where the map is strongly metallic (gold, buckles); fur and cloth stay dielectric
mr_new = mr.copy()
mr_new[..., 0] = 1.0
mr_new[..., 2] = smooth(0.55, 0.85, mr[..., 2])
EMIS_IMG = np_img("orion_emissive", emis)
MR_IMG = np_img("orion_metal_rough", mr_new, "Non-Color")
if BASE_REPLACED:
    BASE_IMG = np_img("orion_basecolor", base)
else:
    BASE_IMG = base_img
    BASE_IMG.name = "orion_basecolor"


def build_material(glow_strength):
    m = bpy.data.materials.new("Orion_Tripo")
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    b = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(b.outputs[0], out.inputs[0])
    tb = nt.nodes.new("ShaderNodeTexImage")
    tb.image = BASE_IMG
    nt.links.new(tb.outputs[0], b.inputs["Base Color"])
    tm = nt.nodes.new("ShaderNodeTexImage")
    tm.image = MR_IMG
    sep = nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(tm.outputs[0], sep.inputs[0])
    nt.links.new(sep.outputs[1], b.inputs["Roughness"])
    nt.links.new(sep.outputs[2], b.inputs["Metallic"])
    te = nt.nodes.new("ShaderNodeTexImage")
    te.image = EMIS_IMG
    nt.links.new(te.outputs[0], b.inputs["Emission Color"])
    b.inputs["Emission Strength"].default_value = glow_strength
    return m


body.data.materials.clear()
body.data.materials.append(build_material(args.glow))
PRISTINE_MESH = body.data.copy()  # before the eye fix: the phone version is decimated from this


# ============================================================================= eyes: centred irises
# Tripo painted both irises shifted towards the nose (a cross-eyed look). The eye area is repainted in a
# front-projected texture (1600 px/unit, ~6x the original density): openings found from the painted colours,
# new irises centred in them. The faces around the eyes get their own material with planar UVs into it.
EYE_RES = 1600


def mesh_arrays(me_):
    n = len(me_.polygons)
    c3 = np.empty(len(me_.vertices) * 3, np.float32)
    me_.vertices.foreach_get("co", c3)
    f3 = np.empty(n * 3, np.int32)
    me_.polygons.foreach_get("vertices", f3)
    nr = np.empty(n * 3, np.float32)
    me_.polygons.foreach_get("normal", nr)
    l0 = np.empty(n, np.int32)
    me_.polygons.foreach_get("loop_start", l0)
    u2 = np.empty(len(me_.loops) * 2, np.float32)
    me_.uv_layers.active.data.foreach_get("uv", u2)
    return c3.reshape(-1, 3), f3.reshape(-1, 3), nr.reshape(-1, 3), l0, u2.reshape(-1, 2)


def raster_front(me_, win, textures=()):
    """front orthographic z-buffer raster of the mesh inside win=(x0, x1, z0, z1): frontmost face id per pixel,
    optionally the textures sampled through the mesh UVs; plus, per face, pixels covered / pixels frontmost"""
    from scipy.ndimage import map_coordinates
    x0w, x1w, z0w, z1w = win
    Wp, Hp = int(round((x1w - x0w) * EYE_RES)), int(round((z1w - z0w) * EYE_RES))
    co_, fv_, nr_, ls_, uv_ = mesh_arrays(me_)
    cen_ = co_[fv_].mean(1)
    cand = np.where((cen_[:, 0] > x0w - 0.05) & (cen_[:, 0] < x1w + 0.05) & (cen_[:, 2] > z0w - 0.05)
                    & (cen_[:, 2] < z1w + 0.05) & (nr_[:, 1] < 0.0))[0]
    zb = np.full((Hp, Wp), 1e9, np.float32)
    fid_ = np.full((Hp, Wp), -1, np.int64)
    outs = [np.zeros((Hp, Wp, 3), np.float32) for _ in textures]
    cover = {}
    for f in cand:
        P3 = co_[fv_[f]]
        S = np.stack([(P3[:, 0] - x0w) * EYE_RES, (z1w - P3[:, 2]) * EYE_RES], 1)
        bx0, by0 = np.floor(S.min(0)).astype(int)
        bx1, by1 = np.ceil(S.max(0)).astype(int)
        bx0, by0, bx1, by1 = max(bx0, 0), max(by0, 0), min(bx1, Wp - 1), min(by1, Hp - 1)
        if bx1 < bx0 or by1 < by0:
            continue
        xs, ys = np.meshgrid(np.arange(bx0, bx1 + 1) + 0.5, np.arange(by0, by1 + 1) + 0.5)
        v0, v1 = S[1] - S[0], S[2] - S[0]
        den = v0[0] * v1[1] - v1[0] * v0[1]
        if abs(den) < 1e-12:
            continue
        wx, wy = xs - S[0, 0], ys - S[0, 1]
        b1 = (wx * v1[1] - v1[0] * wy) / den
        b2 = (v0[0] * wy - wx * v0[1]) / den
        b0 = 1 - b1 - b2
        ins = (b0 >= -1e-4) & (b1 >= -1e-4) & (b2 >= -1e-4)
        if not ins.any():
            continue
        B = np.stack([b0[ins], b1[ins], b2[ins]], 1)
        dep = B @ P3[:, 1]
        yy_, xx_ = np.floor(ys[ins]).astype(int), np.floor(xs[ins]).astype(int)
        cover[f] = (yy_, xx_, dep)
        closer = dep < zb[yy_, xx_]
        if not closer.any():
            continue
        yy_, xx_, B, dep = yy_[closer], xx_[closer], B[closer], dep[closer]
        zb[yy_, xx_] = dep
        fid_[yy_, xx_] = f
        if textures:
            U = B @ np.stack([uv_[ls_[f] + k] for k in range(3)])
            for t_img, o_img in zip(textures, outs):
                th_, tw_ = t_img.shape[:2]
                tu, tv = U[:, 0] * tw_ - 0.5, (1 - U[:, 1]) * th_ - 0.5
                o_img[yy_, xx_] = np.stack([map_coordinates(t_img[..., k], [tv, tu], order=1, mode="nearest")
                                            for k in range(3)], -1)
    stats = {f: (len(v[0]), int((fid_[v[0], v[1]] == f).sum())) for f, v in cover.items()}
    return fid_, outs, stats, (co_, fv_, nr_, ls_)


def find_eye_window():
    """bounding box (front view) of the sclera/iris-coloured faces on the front of the head, plus a margin"""
    co_, fv_, nr_, ls_, uv_ = mesh_arrays(body.data)
    fuv_ = (uv_[ls_] + uv_[ls_ + 1] + uv_[ls_ + 2]) / 3
    c = base[np.clip(((1 - fuv_[:, 1]) * TH).astype(int), 0, TH - 1), np.clip((fuv_[:, 0] * TW).astype(int), 0, TW - 1)]
    cmx, cmn = c.max(1), c.min(1)
    csat = (cmx - cmn) / np.maximum(cmx, 1e-4)
    cd = np.maximum(cmx - cmn, 1e-4)
    chue = np.where(cmx == c[:, 0], ((c[:, 1] - c[:, 2]) / cd) % 6,
                    np.where(cmx == c[:, 1], (c[:, 2] - c[:, 0]) / cd + 2, (c[:, 0] - c[:, 1]) / cd + 4)) * 60
    cen_ = co_[fv_].mean(1)
    head = (cen_[:, 2] > 1.25) & (cen_[:, 2] < 1.85) & (nr_[:, 1] < -0.3)
    eyeish = head & (((chue > 188) & (chue < 250) & (csat > 0.28) & (cmx > 0.2))
                     | ((cmx > 0.6) & (csat < 0.25) & (c[:, 2] >= c[:, 0] - 0.035)))
    # keep the largest cluster around the face (drop the goggle lenses: they sit higher and further forward)
    p = cen_[eyeish]
    zmed = np.median(p[:, 2])
    p = p[np.abs(p[:, 2] - zmed) < 0.12]
    m = 0.11
    return (float(p[:, 0].min() - m), float(p[:, 0].max() + m), float(p[:, 2].min() - m), float(p[:, 2].max() + m))


def paint_eyes(img_, fid_):
    """find the two eye openings in the front-view colour image, paint centred irises; returns image, opening mask"""
    from scipy import ndimage as ndi
    from skimage import measure, morphology
    Hh, Ww = fid_.shape
    imx, imn = img_.max(-1), img_.min(-1)
    isat = (imx - imn) / np.maximum(imx, 1e-4)
    idd = np.maximum(imx - imn, 1e-4)
    ir, ig, ib = img_[..., 0], img_[..., 1], img_[..., 2]
    ihue = np.where(imx == ir, ((ig - ib) / idd) % 6, np.where(imx == ig, (ib - ir) / idd + 2, (ir - ig) / idd + 4)) * 60
    cool = ib >= ir - 0.035
    scl_ = (imx > 0.55) & (isat < 0.3) & cool & (fid_ >= 0)
    iri = (ihue > 188) & (ihue < 250) & (isat > 0.28) & (imx > 0.12) & (fid_ >= 0)
    brt = (imx > 0.85) & (isat < 0.12) & cool & (fid_ >= 0)
    eyeish = morphology.remove_small_objects(scl_ | iri | brt, max_size=200)
    lab = measure.label(ndi.binary_closing(eyeish, iterations=2))
    regs = sorted(measure.regionprops(lab), key=lambda p: -p.area)[:2]
    if len(regs) < 2:
        raise RuntimeError("eye fix: could not find two eye openings")
    yy_, xx_ = np.mgrid[0:Hh, 0:Ww].astype(np.float32)
    openings = []
    for p in sorted(regs, key=lambda p: p.centroid[1]):
        op = morphology.convex_hull_image(lab == p.label)
        ys_, xs_ = np.nonzero(op)
        cov = np.cov(np.stack([xs_, ys_]))
        major = np.linalg.eigh(cov)[1][:, 1]
        minor = np.array([-major[1], major[0]])
        pm = (xs_ - xs_.mean()) * major[0] + (ys_ - ys_.mean()) * major[1]
        pn = (xs_ - xs_.mean()) * minor[0] + (ys_ - ys_.mean()) * minor[1]
        openings.append(dict(op=op, cx=xs_.mean(), cy=ys_.mean(), w=pm.max() - pm.min(), h=pn.max() - pn.min()))
    allop = openings[0]["op"] | openings[1]["op"]
    irs = iri & allop & (imx > 0.2)
    pal = {k: np.percentile(img_[irs], q, axis=0) for k, q in (("dark", 12), ("mid", 50), ("light", 88))}
    concept = {"dark": np.array([11, 42, 128]) / 255, "mid": np.array([18, 112, 216]) / 255,
               "light": np.array([63, 192, 245]) / 255}
    pal = {k: 0.5 * pal[k] + 0.5 * concept[k] for k in pal}  # halfway to the concept's vivid blue
    sclc = np.median(img_[scl_ & allop], axis=0)
    out_ = img_.copy()
    mask = np.zeros((Hh, Ww), np.float32)
    for e in openings:
        op = e["op"]
        R = 0.58 * e["h"]
        cx, cy = e["cx"], e["cy"] + 0.04 * e["h"]
        dx, dy = xx_ - cx, yy_ - cy
        rr = np.hypot(dx, dy) / R
        th = np.arctan2(dy, dx)
        top = np.nonzero(op)[0].min()
        t = np.clip((yy_ - top) / (0.55 * e["h"]), 0, 1)
        side = np.clip(np.abs(dx) / (0.5 * e["w"]), 0, 1)
        eye = sclc[None, None] * (0.72 + 0.28 * smooth(0.0, 1.0, t))[..., None] * (1 - 0.12 * side ** 3)[..., None]
        streak = 1 + 0.08 * np.sin(th * 23 + 2.0 * np.sin(th * 7)) * smooth(0.45, 0.6, rr) * smooth(0.95, 0.8, rr)
        k1 = smooth(0.75, 0.5, rr)[..., None]
        ic = pal["light"][None, None] * k1 + pal["mid"][None, None] * (1 - k1)
        k2 = smooth(0.78, 0.98, rr)[..., None]
        ic = ic * (1 - k2) + pal["dark"][None, None] * k2
        ic = ic * streak[..., None] * (0.78 + 0.22 * smooth(0.0, 1.0, (dy / R + 1) / 1.6))[..., None]
        a_ = smooth(1.0, 0.985, rr)[..., None]
        eye = eye * (1 - a_) + ic * a_
        a_ = smooth(0.52, 0.48, rr)[..., None]
        eye = eye * (1 - a_) + np.array([0.03, 0.05, 0.1]) * a_
        for ox, oy, rad, kk in ((-0.36, -0.36, 0.2, 1.0), (0.34, 0.3, 0.085, 0.95)):
            a_ = (smooth(1.0, 0.82, np.hypot(dx / R - ox, dy / R - oy) / rad) * kk)[..., None]
            eye = eye * (1 - a_) + a_
        eye = np.stack([ndi.gaussian_filter(eye[..., k], 0.9) for k in range(3)], -1)
        m_ = ndi.gaussian_filter(ndi.binary_dilation(op, iterations=3).astype(np.float32), 1.2)
        out_ = out_ * (1 - m_[..., None]) + eye * m_[..., None]
        mask = np.maximum(mask, m_)
        log("[eyes] opening %.0f x %.0f px, new iris radius %.0f px" % (e["w"], e["h"], R))
    return out_, mask


def eye_material(col_img, mr_img):
    m = bpy.data.materials.new("Orion_Tripo_Eyes")
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    b = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(b.outputs[0], out.inputs[0])
    tc = nt.nodes.new("ShaderNodeTexImage")
    tc.image = col_img
    nt.links.new(tc.outputs[0], b.inputs["Base Color"])
    tm = nt.nodes.new("ShaderNodeTexImage")
    tm.image = mr_img
    sep = nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(tm.outputs[0], sep.inputs[0])
    nt.links.new(sep.outputs[1], b.inputs["Roughness"])
    nt.links.new(sep.outputs[2], b.inputs["Metallic"])
    b.inputs["Emission Color"].default_value = (0, 0, 0, 1)  # eyes do not glow
    b.inputs["Emission Strength"].default_value = 0.0
    return m


def apply_eyes(obj):
    """give the faces around the eyes the eye material, with planar front UVs into the eye textures"""
    x0w, x1w, z0w, z1w = EYE_WIN
    fid_, _, stats, (co_, fv_, nr_, ls_) = raster_front(obj.data, EYE_WIN)
    from scipy import ndimage as ndi
    near = ndi.binary_dilation(EYE_MASK > 0.01, iterations=12)
    sel = set(np.unique(fid_[near]).tolist()) - {-1}
    sel = [f for f in sel if stats.get(f, (0, 0))[0] > 0 and stats[f][1] >= 0.97 * stats[f][0] and nr_[f, 1] < -0.2]
    P = co_[fv_[sel]]
    inside = ((P[..., 0] > x0w) & (P[..., 0] < x1w) & (P[..., 2] > z0w) & (P[..., 2] < z1w)).all(1)
    sel = np.array(sel)[inside]
    me_ = obj.data
    if EYE_MAT.name not in [m.name for m in me_.materials if m]:
        me_.materials.append(EYE_MAT)
    slot = [m.name if m else "" for m in me_.materials].index(EYE_MAT.name)
    mi = np.zeros(len(me_.polygons), np.int32)
    me_.polygons.foreach_get("material_index", mi)
    mi[sel] = slot
    me_.polygons.foreach_set("material_index", mi)
    uvd = me_.uv_layers.active.data
    uv_all = np.empty(len(me_.loops) * 2, np.float32)
    uvd.foreach_get("uv", uv_all)
    uv_all = uv_all.reshape(-1, 2)
    lv = np.empty(len(me_.loops), np.int32)
    me_.loops.foreach_get("vertex_index", lv)
    for f in sel:
        for k in range(3):
            li = ls_[f] + k
            v = co_[lv[li]]
            uv_all[li] = ((v[0] - x0w) / (x1w - x0w), (v[2] - z0w) / (z1w - z0w))
    uvd.foreach_set("uv", uv_all.ravel())
    me_.update()
    log("[eyes]", obj.name, len(sel), "faces use the eye texture")


def set_img(img, arr):
    """write an HxWx3 array (top row first) into a Blender image"""
    h, w = arr.shape[:2]
    rgba = np.concatenate([arr[..., :3], np.ones((h, w, 1), np.float32)], -1)[::-1]
    img.pixels.foreach_set(rgba.astype(np.float32).ravel())
    img.update()
    if img.packed_file:
        img.pack()


def repaint_main_texture(eye_img, fid_):
    """also correct the eyes in the main texture (at its own, lower resolution): every texel of a face that is
    frontmost in the eye area takes the colour of the new eye image at its front-view position"""
    from scipy import ndimage as ndi
    from scipy.ndimage import map_coordinates
    x0w, x1w, z0w, z1w = EYE_WIN
    Hh, Ww = fid_.shape
    soft = np.stack([ndi.gaussian_filter(eye_img[..., k], 2.5) for k in range(3)], -1)  # ~ one texel footprint
    m = ndi.gaussian_filter(ndi.binary_dilation(EYE_MASK > 0.01, iterations=6).astype(np.float32), 2.0)
    co_, fv_, nr_, ls_, uv_ = mesh_arrays(body.data)
    faces = np.unique(fid_[m > 0.01])
    faces = faces[faces >= 0]
    n = 0
    per_face = []
    for f in faces:
        P3 = co_[fv_[f]]
        T = np.stack([uv_[ls_[f] + k] for k in range(3)]) * [TW, TH]
        T[:, 1] = TH - T[:, 1]
        bx0, by0 = np.floor(T.min(0)).astype(int)
        bx1, by1 = np.ceil(T.max(0)).astype(int)
        xs, ys = np.meshgrid(np.arange(bx0, bx1 + 1) + 0.5, np.arange(by0, by1 + 1) + 0.5)
        v0, v1 = T[1] - T[0], T[2] - T[0]
        den = v0[0] * v1[1] - v1[0] * v0[1]
        if abs(den) < 1e-12:
            continue
        wx, wy = xs - T[0, 0], ys - T[0, 1]
        b1 = (wx * v1[1] - v1[0] * wy) / den
        b2 = (v0[0] * wy - wx * v0[1]) / den
        b0 = 1 - b1 - b2
        ins = (b0 >= -0.02) & (b1 >= -0.02) & (b2 >= -0.02)  # a hair outside too: bilinear reads neighbours
        if not ins.any():
            continue
        B = np.stack([b0[ins], b1[ins], b2[ins]], 1)
        p3 = B @ P3
        sx = (p3[:, 0] - x0w) * EYE_RES - 0.5
        sy = (z1w - p3[:, 2]) * EYE_RES - 0.5
        ok = (sx >= 0) & (sx < Ww - 1) & (sy >= 0) & (sy < Hh - 1)
        # only texels this face shows from the front (not hidden behind another surface)
        fr = fid_[np.clip(np.round(sy).astype(int), 0, Hh - 1), np.clip(np.round(sx).astype(int), 0, Ww - 1)] == f
        ok &= fr
        if not ok.any():
            continue
        tx = np.clip(np.floor(xs[ins][ok]).astype(int), 0, TW - 1)
        ty = np.clip(np.floor(ys[ins][ok]).astype(int), 0, TH - 1)
        a_ = map_coordinates(m, [sy[ok], sx[ok]], order=1)[:, None]
        c = np.stack([map_coordinates(soft[..., k], [sy[ok], sx[ok]], order=1) for k in range(3)], -1)
        base[ty, tx] = base[ty, tx] * (1 - a_) + c * a_
        n += int(ok.sum())
        per_face.append(int(ok.sum()))
    set_img(BASE_IMG, base)
    log("[eyes] main texture: %d texels repainted on %d faces (max %d per face)"
        % (n, len(per_face), max(per_face) if per_face else 0))


if args.eye_fix:
    EYE_WIN = find_eye_window()
    fid0, (scr_col, scr_mr), _, _ = raster_front(body.data, EYE_WIN, textures=(base, mr_new))
    eye_col, EYE_MASK = paint_eyes(scr_col, fid0)
    scr_mr[..., 1] = scr_mr[..., 1] * (1 - EYE_MASK) + 0.3 * EYE_MASK  # glossy eyes
    scr_mr[..., 2] = scr_mr[..., 2] * (1 - EYE_MASK)

    def to_img(name, arr, cs):
        from PIL import Image as PImage
        im8 = PImage.fromarray((np.clip(arr, 0, 1) * 255 + 0.5).astype(np.uint8)).resize((1024, 512), PImage.LANCZOS)
        return np_img(name, np.asarray(im8).astype(np.float32) / 255, cs)

    EYE_MAT = eye_material(to_img("orion_eyes", eye_col, "sRGB"), to_img("orion_eyes_metal_rough", scr_mr, "Non-Color"))
    repaint_main_texture(eye_col, fid0)  # first: it needs the faces' original UVs
    apply_eyes(body)


# ============================================================================= stage (same as orion_build.py)

def srgb(h):
    """hex sRGB -> linear rgb tuple"""
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


def link(obj):
    scene.collection.objects.link(obj)
    return obj


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


LIGHT_SCALE = args.light


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
    bg.inputs[1].default_value = 0.27 * LIGHT_SCALE
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
scene.render.film_transparent = True
scene.render.image_settings.color_mode = "RGBA"
scene.view_settings.view_transform = "Khronos PBR Neutral"


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
        bright = rgb * (smoothstep(0.42, 0.8, lum) * smoothstep(0.2, 0.45, sat) * blue * (al[..., 0] > 0.5))[..., None]
        bimg = Image.fromarray((np.clip(bright, 0, 1) * 255).astype(np.uint8))
        acc = np.zeros_like(rgb)
        sc = im.width / 1000
        for r, wgt in ((3, 0.4), (10, 0.35), (28, 0.28)):
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



def publish(raw_path, name, keep_white=True):
    """white-background image in out/, the transparent one in out/transparent/ (same layout as orion_build.py)"""
    tdir = os.path.join(args.out, "transparent")
    os.makedirs(tdir, exist_ok=True)
    white = raw_path.replace(".png", "_w.png")
    os.replace(raw_path, os.path.join(tdir, f"{name}{args.tag}.png"))
    if keep_white:
        os.replace(white, os.path.join(args.out, f"{name}{args.tag}.png"))
    else:
        os.remove(white)


S = args.size
views = [v for v in args.render.split(",") if v]
SHEET_VIEWS = (("front", 0), ("q34", -40), ("side", -84), ("back", 180))
if "sheet" in views:
    raw, fin_ = [], []
    for name, ang in SHEET_VIEWS:
        p = render(f"tripo_{name}", ang, size=(S, S), ortho=2.85, target=(0, 0.0, 1.22), height=2.2)
        raw.append(p)
        fin_.append(finish(p))
    compose_sheet(raw, fin_, ["Față", "3/4 Față", "Profil (Lateral)", "Spate"],
                  os.path.join(args.out, f"tripo_sheet{args.tag}.png"))
    for (name, _), p in zip(SHEET_VIEWS, raw):
        publish(p, f"tripo_{name}", keep_white=False)
if "face" in views:
    p = render("tripo_face", 0, size=(S, S), lens=135, dist=6.8, height=1.85, target=(0, -0.1, 1.82))
    finish(p)
    publish(p, "tripo_face")
if "yaw" in views:  # debug: which way is "front"? front views for several extra yaw angles
    for yaw in (0, -15, -25, -35, -45):
        RIG.rotation_euler = (0, 0, 0)
        p = render(f"tripo_yaw{-yaw:02d}", -yaw, size=(500, 500), ortho=2.85, target=(0, 0.0, 1.22), height=2.2)
        finish(p)
if "top" in views:  # debug: from above
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = 2.6
    cam.location = (0, 0, 6)
    cam.rotation_euler = (0, 0, 0)
    scene.render.resolution_x = scene.render.resolution_y = 500
    scene.render.filepath = os.path.join(args.out, "tripo_top.png")
    bpy.ops.render.render(write_still=True)


# ============================================================================= game exports
def export_glb(obj, path, emission=1.0):
    """export one object at 1,2 m (scene units are 2,4 high), Y-up, emission strength 1 (plain glTF)"""
    for m in obj.data.materials:
        b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        if b.inputs["Emission Color"].is_linked:  # only materials with an emission texture
            b.inputs["Emission Strength"].default_value = emission
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    old = tuple(obj.scale)
    obj.scale = (0.5, 0.5, 0.5)
    bpy.context.view_layer.update()
    bpy.ops.export_scene.gltf(filepath=path, use_selection=True, export_apply=True, export_yup=True,
                              export_image_format="JPEG", export_jpeg_quality=90)
    obj.scale = old
    bpy.context.view_layer.update()
    log("[glb]", path, f"{os.path.getsize(path) / 1e6:.1f} MB", len(obj.data.polygons), "faces")


def decimate_lod(high, tris):
    """lighter copy for phones: collapse-decimated, same UVs and textures (no re-bake needed)"""
    low = high.copy()
    low.data = PRISTINE_MESH.copy()
    low.name = "Orion_Tripo_Mobile"
    scene.collection.objects.link(low)
    dec = low.modifiers.new("dec", "DECIMATE")
    dec.ratio = min(1.0, tris / max(len(high.data.polygons), 1))
    if args.eye_fix:  # keep the small triangles around the eyes (weight 0 = not collapsed)
        x0w, x1w, z0w, z1w = EYE_WIN
        vco = np.empty(len(low.data.vertices) * 3, np.float32)
        low.data.vertices.foreach_get("co", vco)
        vco = vco.reshape(-1, 3)
        keep = (vco[:, 0] > x0w) & (vco[:, 0] < x1w) & (vco[:, 2] > z0w) & (vco[:, 2] < z1w) & (vco[:, 1] < -0.3)
        vg = low.vertex_groups.new(name="decimate")
        vg.add(np.where(~keep)[0].tolist(), 1.0, "REPLACE")
        vg.add(np.where(keep)[0].tolist(), 0.0, "REPLACE")
        dec.vertex_group = "decimate"
        dec.vertex_group_factor = 1.0
    bpy.ops.object.select_all(action="DESELECT")
    low.select_set(True)
    bpy.context.view_layer.objects.active = low
    bpy.ops.object.modifier_apply(modifier="dec")
    for vg_ in list(low.vertex_groups):
        low.vertex_groups.remove(vg_)
    log("[lod]", len(low.data.polygons), "faces")
    if args.eye_fix:
        apply_eyes(low)
    return low


if not args.no_glb:
    scene.cycles.samples = args.samples
    export_glb(body, os.path.join(args.out, f"orion_tripo_game{args.tag}.glb"))
    if args.lod > 0:
        low = decimate_lod(body, args.lod)
        export_glb(low, os.path.join(args.out, f"orion_tripo_mobile{args.tag}.glb"))
        if "lodsheet" in views:
            body.hide_render = True
            for m in low.data.materials:
                bs = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
                if bs.inputs["Emission Color"].is_linked:
                    bs.inputs["Emission Strength"].default_value = args.glow
            scene.cycles.samples = args.samples
            scene.cycles.use_denoising = True
            raw, fin_ = [], []
            for name, ang in SHEET_VIEWS:
                p = render(f"tripo_mobile_{name}", ang, size=(S, S), ortho=2.85, target=(0, 0.0, 1.22), height=2.2)
                raw.append(p)
                fin_.append(finish(p))
            compose_sheet(raw, fin_, ["Față", "3/4 Față", "Profil (Lateral)", "Spate"],
                          os.path.join(args.out, f"tripo_mobile_sheet{args.tag}.png"))
            for p in raw:
                os.remove(p)
                os.remove(p.replace(".png", "_w.png"))
