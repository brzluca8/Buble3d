"""
Insula din Tripo Studio -> insulă pregătită pentru joc (Godot / Three.js) + harta drumului de căsuțe.

    python island_prep.py --src tripo/insula1_tripo.glb --out out_insula1 --name insula1

Pași:
  1. importă GLB-ul din Tripo (un singur mesh texturat);
  2. găsește căsuțele rotunde bej ale drumului (vedere de sus, după culoare, formă și planeitate),
     le ordonează în buclă, pornind din fața castelului, spre dreapta;
  3. scalează insula ca distanța dintre căsuțe să fie ~1,9 m (o căsuță ~1,6 m; Orion are 1,2 m)
     și o mută cu prima căsuță în origine (înălțimea 0) și centrul drumului pe verticala originii;
  4. repară materialul: metal doar pe piesele de metal, apa lucioasă, lumină pe felinare, ferestre,
     portal și cristale;
  5. exportă <name>.glb (texturi JPG, merge în Three.js r128 și în Godot 4) și <name>_casute.json
     (pozițiile căsuțelor în coordonatele jocului: X dreapta, Y sus, Z spre cameră);
  6. randează harta drumului (vedere de sus, căsuțe numerotate) și o vedere 3/4 cu Orion pe start.
"""
import argparse
import json
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
ap.add_argument("--out", default="out_insula1")
ap.add_argument("--name", default="insula1")
ap.add_argument("--spacing", type=float, default=1.9, help="distanța dorită între două căsuțe vecine (m)")
ap.add_argument("--yaw", type=float, default=0.0, help="rotație în jurul verticalei (grade), dacă fața nu e spre cameră")
ap.add_argument("--orion", default="", help="GLB-ul lui Orion, pus pe căsuța de start în randări (pentru scară)")
ap.add_argument("--render", default="map,hero")
ap.add_argument("--size", type=int, default=1400)
ap.add_argument("--samples", type=int, default=64)
ap.add_argument("--glow", type=float, default=1.5, help="intensitatea luminii în randări (în GLB rămâne 1)")
ap.add_argument("--no-glb", action="store_true")
args = ap.parse_args(argv)
os.makedirs(args.out, exist_ok=True)


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


# ============================================================================= import
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
bpy.ops.import_scene.gltf(filepath=os.path.abspath(args.src))
body = [o for o in scene.objects if o.type == "MESH"][0]
for o in [o for o in scene.objects if o.type == "EMPTY"]:
    for c in o.children:
        c.parent = None
    bpy.data.objects.remove(o)
bpy.ops.object.select_all(action="DESELECT")
body.select_set(True)
bpy.context.view_layer.objects.active = body
body.rotation_euler = (0, 0, math.radians(args.yaw))
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
body.name = args.name
me = body.data
log("[import]", len(me.vertices), "verts", len(me.polygons), "faces")


def mesh_arrays():
    n = len(me.polygons)
    co_ = np.empty(len(me.vertices) * 3, np.float32)
    me.vertices.foreach_get("co", co_)
    fv_ = np.empty(n * 3, np.int32)
    me.polygons.foreach_get("vertices", fv_)
    fn_ = np.empty(n * 3, np.float32)
    me.polygons.foreach_get("normal", fn_)
    ls_ = np.empty(n, np.int32)
    me.polygons.foreach_get("loop_start", ls_)
    uv_ = np.empty(len(me.loops) * 2, np.float32)
    me.uv_layers.active.data.foreach_get("uv", uv_)
    return co_.reshape(-1, 3), fv_.reshape(-1, 3), fn_.reshape(-1, 3), ls_, uv_.reshape(-1, 2)


def img_np(img):
    w, h = img.size
    a = np.empty(w * h * img.channels, np.float32)
    img.pixels.foreach_get(a)
    return a.reshape(h, w, img.channels)[::-1]


def np_img(name, arr, colorspace="sRGB"):
    h, w = arr.shape[:2]
    rgba = np.concatenate([arr[..., :3], np.ones((h, w, 1), np.float32)], -1)[::-1]
    img = bpy.data.images.new(name, w, h, alpha=False)
    img.colorspace_settings.name = colorspace
    img.pixels.foreach_set(rgba.astype(np.float32).ravel())
    img.pack()
    return img


src_mat = me.materials[0]
tex_nodes = [n for n in src_mat.node_tree.nodes if n.type == "TEX_IMAGE"]
base_img = next(n.image for n in tex_nodes if any(l.to_socket.name == "Base Color" for l in n.outputs[0].links))
mr_img = next(n.image for n in tex_nodes if n.image is not base_img)
base = img_np(base_img)[..., :3].copy()  # stored sRGB values
mr = img_np(mr_img)[..., :3].copy()
TH, TW = base.shape[:2]


# ============================================================================= 2. board tiles (top view)
def raster_top(res):
    """top-down z-buffer raster of the albedo: colour, height and up-normal per pixel"""
    from scipy.ndimage import map_coordinates
    co_, fv_, fn_, ls_, uv_ = mesh_arrays()
    lo, hi = co_.min(0), co_.max(0)
    Wp, Hp = int((hi[0] - lo[0]) * res) + 2, int((hi[1] - lo[1]) * res) + 2
    zb = np.full((Hp, Wp), -1e9, np.float32)
    col = np.zeros((Hp, Wp, 3), np.float32)
    nz = np.zeros((Hp, Wp), np.float32)
    for f in range(len(fv_)):
        P3 = co_[fv_[f]]
        S = np.stack([(P3[:, 0] - lo[0]) * res, (hi[1] - P3[:, 1]) * res], 1)
        x0, y0 = np.floor(S.min(0)).astype(int)
        x1, y1 = np.ceil(S.max(0)).astype(int)
        xs, ys = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
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
        z = B @ P3[:, 2]
        yy = np.clip(np.floor(ys[ins]).astype(int), 0, Hp - 1)
        xx = np.clip(np.floor(xs[ins]).astype(int), 0, Wp - 1)
        up = z > zb[yy, xx]
        if not up.any():
            continue
        yy, xx, B, z = yy[up], xx[up], B[up], z[up]
        U = B @ np.stack([uv_[ls_[f] + k] for k in range(3)])
        tu, tv = U[:, 0] * TW - 0.5, (1 - U[:, 1]) * TH - 0.5
        col[yy, xx] = np.stack([map_coordinates(base[..., k], [tv, tu], order=1, mode="nearest") for k in range(3)], -1)
        zb[yy, xx] = z
        nz[yy, xx] = fn_[f, 2]
    return col, zb, nz, lo, hi


def find_tiles(col, zb, nz, res):
    """round, flat, beige discs; strong ones first, then partly hidden ones that fill a gap in the loop"""
    from scipy import ndimage as ndi
    from skimage import morphology, feature
    H, W = zb.shape
    hue, sat, val = hsv(col)
    beige = (hue > 22) & (hue < 52) & (sat > 0.08) & (sat < 0.34) & (val > 0.72) & (zb > -1e8) & (nz > 0.93)
    beige = morphology.opening(beige, morphology.disk(3))
    beige = ndi.binary_fill_holes(morphology.closing(beige, morphology.disk(4)))
    dt = ndi.distance_transform_edt(beige)
    k = res / 2000.0  # thresholds below were set at 2000 px per model unit
    peaks = feature.peak_local_max(dt, min_distance=int(40 * k), threshold_abs=28 * k)
    yy, xx = np.mgrid[0:H, 0:W]
    cands = []
    for py, px in peaks:
        R = dt[py, px]
        y0, y1, x0, x1 = max(py - int(110 * k), 0), min(py + int(110 * k), H), max(px - int(110 * k), 0), min(px + int(110 * k), W)
        sub = beige[y0:y1, x0:x1]
        rr = np.hypot(yy[y0:y1, x0:x1] - py, xx[y0:y1, x0:x1] - px)
        z = zb[y0:y1, x0:x1][rr < 0.8 * R]
        cands.append(dict(px=float(px), py=float(py), R=float(R), inner=float(sub[rr < 0.9 * R].mean()),
                          ring=float(sub[(rr > 1.15 * R) & (rr < 1.45 * R)].mean()), zstd=float(z.std()),
                          z=float(np.median(z))))
    ok = lambda c: c["inner"] > 0.95 and c["ring"] < 0.6 and c["zstd"] < 0.004  # noqa: E731
    strong = [c for c in cands if 38 * k <= c["R"] <= 82 * k and ok(c)]
    weak = [c for c in cands if 28 * k <= c["R"] < 38 * k and ok(c)]
    loop = order_loop(strong)
    sp = np.median([np.hypot(a["px"] - b["px"], a["py"] - b["py"]) for a, b in zip(loop, loop[1:] + loop[:1])])
    for c in weak:  # insert into a gap of the loop if it sits on the line between two neighbours
        best = None
        for i in range(len(loop)):
            a, b = loop[i], loop[(i + 1) % len(loop)]
            ab = np.array([b["px"] - a["px"], b["py"] - a["py"]])
            L = np.linalg.norm(ab)
            if L < 1.5 * sp:
                continue
            ac = np.array([c["px"] - a["px"], c["py"] - a["py"]])
            t = float(ac @ ab) / L ** 2
            dist = abs(ac[0] * ab[1] - ac[1] * ab[0]) / L
            if 0.2 < t < 0.8 and dist < 0.35 * sp and (best is None or dist < best[0]):
                best = (dist, i)
        if best:
            loop.insert(best[1] + 1, c)
    return loop, sp


def order_loop(tiles):
    """order around the centroid (the ring is star-shaped around it)"""
    cx = np.mean([t["px"] for t in tiles])
    cy = np.mean([t["py"] for t in tiles])
    return sorted(tiles, key=lambda t: math.atan2(t["py"] - cy, t["px"] - cx))


RES = 2000
col_top, zb_top, nz_top, LO, HI = raster_top(RES)
loop, spacing_px = find_tiles(col_top, zb_top, nz_top, RES)
# start: the front-centre tile (front = bottom of the top view), then go right (counter-clockwise from above)
cx_tiles = np.mean([t["px"] for t in loop])
front = max(t["py"] for t in loop)
i0 = min(range(len(loop)), key=lambda i: abs(loop[i]["px"] - cx_tiles) + 2.0 * (front - loop[i]["py"]))
loop = loop[i0:] + loop[:i0]
if loop[1]["px"] < loop[0]["px"]:  # make the first step go to the right
    loop = [loop[0]] + loop[1:][::-1]
log("[tiles] %d tiles on the loop, spacing %.0f px" % (len(loop), spacing_px))

# model units -> game metres
SCALE = args.spacing / (spacing_px / RES)
tile_m = np.array([[LO[0] + t["px"] / RES, HI[1] - t["py"] / RES, t["z"]] for t in loop])  # Blender coords (model)
centre = tile_m[:, :2].mean(0)
OFFSET = np.array([-centre[0], -centre[1], -tile_m[0, 2]])  # start tile on the ground plane, loop centred
co, fv, fn, ls, uv = mesh_arrays()
me.vertices.foreach_set("co", ((co + OFFSET) * SCALE).astype(np.float32).ravel())
me.update()
tiles_b = (tile_m + OFFSET) * SCALE  # Blender coords, metres
log("[scale] x%.2f -> island %.1f x %.1f x %.1f m" % (SCALE, *((co.max(0) - co.min(0)) * SCALE)))

# game coordinates (glTF / Godot / Three.js, Y up): X = x, Y = z, Z = -y
tile_r = float(np.median([t["R"] for t in loop]) / RES * SCALE / 0.72)  # the beige top is ~72% of the disc
board = {
    "insula": args.name,
    "unitati": "metri; X dreapta, Y sus, Z spre cameră (glTF)",
    "distanta_casute": round(args.spacing, 3),
    "raza_casuta": round(tile_r, 3),
    "start": 0,
    "sens": "de la start spre dreapta, apoi în jurul castelului (invers acelor de ceas, privit de sus)",
    "casute": [{"i": i, "x": round(float(p[0]), 3), "y": round(float(p[2]), 3), "z": round(float(-p[1]), 3)}
               for i, p in enumerate(tiles_b)],
}
with open(os.path.join(args.out, f"{args.name}_casute.json"), "w") as f:
    json.dump(board, f, ensure_ascii=False, indent=1)
# the same data as a GDScript constant, so Godot exports it with the game without extra export filters
with open(os.path.join(args.out, f"{args.name}_casute.gd"), "w") as f:
    f.write(f"# Căsuțele drumului de pe {args.name} (generat de blender/island_prep.py): metri, Y în sus, Z spre cameră.\n")
    f.write("extends RefCounted\n\n")
    f.write(f"const RAZA := {tile_r:.3f}  # raza unei căsuțe\n")
    f.write(f"const PAS := {args.spacing:.3f}  # distanța obișnuită dintre două căsuțe vecine\n")
    f.write("const CASUTE: Array[Vector3] = [\n")
    for t in board["casute"]:
        f.write(f"\tVector3({t['x']:.3f}, {t['y']:.3f}, {t['z']:.3f}),\n")
    f.write("]\n")
log("[tiles] saved", f"{args.name}_casute.json", f"{args.name}_casute.gd")


# ============================================================================= 4. material: metal, water, lights
hue, sat, val = hsv(base)
# lights: very bright warm yellow (lantern flames, lit windows, the castle door) and the violet portal / crystals
warm = smooth(32, 40, hue) * smooth(62, 54, hue) * smooth(0.3, 0.45, sat) * smooth(0.9, 0.97, val)
violet = smooth(255, 268, hue) * smooth(305, 292, hue) * smooth(0.35, 0.5, sat) * smooth(0.5, 0.7, val)
glow = np.clip(np.maximum(warm, violet), 0, 1)
from scipy import ndimage as _ndi  # noqa: E402
glow = _ndi.gaussian_filter(glow, 0.7)
emis = base * glow[..., None]
# water: cyan / turquoise -> glossy
water = smooth(168, 178, hue) * smooth(208, 198, hue) * smooth(0.3, 0.45, sat) * smooth(0.35, 0.5, val)
mr_new = mr.copy()
mr_new[..., 0] = 1.0
mr_new[..., 1] = mr[..., 1] * (1 - water) + 0.12 * water  # roughness
mr_new[..., 2] = smooth(0.55, 0.85, mr[..., 2]) * (1 - water)  # metal only where strongly metallic
log("[material] glow texels %d, water texels %d" % (int((glow > 0.5).sum()), int((water > 0.5).sum())))
BASE_IMG = np_img(f"{args.name}_basecolor", base)
MR_IMG = np_img(f"{args.name}_metal_rough", mr_new, "Non-Color")
EMIS_IMG = np_img(f"{args.name}_emissive", emis)


def build_material(glow_strength):
    m = bpy.data.materials.new(f"{args.name}_mat")
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


me.materials.clear()
ISLAND_MAT = build_material(args.glow)
me.materials.append(ISLAND_MAT)


def set_glow(strength):
    b = next(n for n in ISLAND_MAT.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Emission Strength"].default_value = strength


# ============================================================================= 5. export
def export_glb(path):
    set_glow(1.0)
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.export_scene.gltf(filepath=path, use_selection=True, export_apply=True, export_yup=True,
                              export_image_format="JPEG", export_jpeg_quality=90)
    set_glow(args.glow)
    log("[glb]", path, f"{os.path.getsize(path) / 1e6:.1f} MB", len(me.polygons), "faces")


if not args.no_glb:
    export_glb(os.path.join(args.out, f"{args.name}.glb"))


# ============================================================================= 6. previews
def setup_stage():
    w = bpy.data.worlds.new("Sky")
    scene.world = w
    nt = w.node_tree
    bg = nt.nodes["Background"]
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Generated"], sep.inputs[0])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    nt.links.new(sep.outputs[2], ramp.inputs[0])
    cr = ramp.color_ramp
    cr.elements[0].position, cr.elements[0].color = 0.45, (0.62, 0.8, 0.95, 1)
    cr.elements[1].position, cr.elements[1].color = 0.75, (0.18, 0.45, 0.85, 1)
    nt.links.new(ramp.outputs[0], bg.inputs[0])
    bg.inputs[1].default_value = 0.9
    sun = bpy.data.lights.new("Sun", "SUN")
    sun.energy = 3.2
    sun.angle = math.radians(3)
    sun.color = (1.0, 0.96, 0.9)
    so = bpy.data.objects.new("Sun", sun)
    scene.collection.objects.link(so)
    so.rotation_euler = (math.radians(42), math.radians(-12), math.radians(-35))
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = args.samples
    scene.cycles.use_denoising = True
    scene.view_settings.view_transform = "Khronos PBR Neutral"
    cd = bpy.data.cameras.new("Cam")
    cam = bpy.data.objects.new("Cam", cd)
    scene.collection.objects.link(cam)
    scene.camera = cam
    return cam, cd


def add_orion(path, pos):
    before = set(scene.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(path))
    new = [o for o in scene.objects if o not in before]
    roots = [o for o in new if o.parent is None]
    for r in roots:
        r.location = Vector(pos) + r.location
    log("[orion] placed on the start tile")
    return new


def project(cam, pts):
    from bpy_extras.object_utils import world_to_camera_view
    res = []
    for p in pts:
        v = world_to_camera_view(scene, cam, Vector(p))
        res.append((v.x * scene.render.resolution_x, (1 - v.y) * scene.render.resolution_y))
    return res


def label_tiles(path, pix):
    from PIL import Image, ImageDraw, ImageFont
    im = Image.open(path).convert("RGB")
    d = ImageDraw.Draw(im)
    fs = max(16, int(im.width / 42))
    f = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", fs)
    for i, (x, y) in enumerate(pix):
        t = "START" if i == 0 else str(i)
        tw = d.textlength(t, font=f)
        pad = fs * 0.35
        d.rounded_rectangle([x - tw / 2 - pad, y - fs * 0.62, x + tw / 2 + pad, y + fs * 0.62], radius=fs * 0.6,
                            fill=(76, 29, 110))
        d.text((x - tw / 2, y - fs * 0.6), t, font=f, fill=(255, 255, 255))
    out = path.replace(".png", "_numerotat.png")
    im.save(out)
    return out


views = [v for v in args.render.split(",") if v]
if views:
    cam, cd = setup_stage()
    if args.orion and os.path.exists(args.orion):
        add_orion(args.orion, tiles_b[0])
    co, fv, fn, ls, uv = mesh_arrays()
    lo3, hi3 = co.min(0), co.max(0)
    if "map" in views:  # top view of the board, tiles numbered
        cd.type = "ORTHO"
        cd.ortho_scale = float(max(hi3[0] - lo3[0], hi3[1] - lo3[1]) * 1.06)
        cx, cy = (lo3[0] + hi3[0]) / 2, (lo3[1] + hi3[1]) / 2
        cam.location = (cx, cy, hi3[2] + 30)
        cam.rotation_euler = (0, 0, 0)
        asp = (hi3[0] - lo3[0]) / (hi3[1] - lo3[1])
        scene.render.resolution_y = args.size
        scene.render.resolution_x = int(args.size * asp * 1.0)
        cd.sensor_fit = "VERTICAL"
        p = os.path.join(args.out, f"{args.name}_harta.png")
        scene.render.filepath = p
        bpy.ops.render.render(write_still=True)
        log("[render]", label_tiles(p, project(cam, tiles_b + np.array([0, 0, 0.05]))))
    if "hero" in views:  # 3/4 from the front and above, as in the concept
        cd.type = "PERSP"
        cd.lens = 50
        cd.sensor_fit = "AUTO"
        el, az, dist = math.radians(46), math.radians(-18), 46.0
        tgt = Vector((0.0, -0.5, -2.5))
        cam.location = tgt + Vector((math.sin(az) * math.cos(el), -math.cos(az) * math.cos(el), math.sin(el))) * dist
        cam.rotation_euler = (tgt - cam.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.resolution_x, scene.render.resolution_y = args.size, int(args.size * 1.15)
        p = os.path.join(args.out, f"{args.name}_vedere.png")
        scene.render.filepath = p
        bpy.ops.render.render(write_still=True)
        log("[render]", p)
    if "orion" in views:  # close-up of Orion on the start tile (scale check)
        cd.type = "PERSP"
        cd.lens = 50
        t0 = Vector(tiles_b[0]) + Vector((0, 0, 0.7))
        cam.location = t0 + Vector((-2.2, -5.5, 3.0))
        cam.rotation_euler = (t0 - cam.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.resolution_x, scene.render.resolution_y = args.size, int(args.size * 0.75)
        p = os.path.join(args.out, f"{args.name}_orion_start.png")
        scene.render.filepath = p
        bpy.ops.render.render(write_still=True)
        log("[render]", p)
