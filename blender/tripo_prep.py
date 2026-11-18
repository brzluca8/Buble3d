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
ap.add_argument("--no-pack-purple", dest="pack_purple", action="store_false",
                help="păstrează rucsacul în culoarea din Tripo (vișiniu)")
ap.add_argument("--lod", type=int, default=40000, help="triunghiuri pentru varianta de telefon (0 = fără)")
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
    low.data = high.data.copy()
    low.name = "Orion_Tripo_Mobile"
    scene.collection.objects.link(low)
    dec = low.modifiers.new("dec", "DECIMATE")
    dec.ratio = min(1.0, tris / max(len(high.data.polygons), 1))
    bpy.ops.object.select_all(action="DESELECT")
    low.select_set(True)
    bpy.context.view_layer.objects.active = low
    bpy.ops.object.modifier_apply(modifier="dec")
    log("[lod]", len(low.data.polygons), "faces")
    return low


if not args.no_glb:
    scene.cycles.samples = args.samples
    export_glb(body, os.path.join(args.out, f"orion_tripo_game{args.tag}.glb"))
    if args.lod > 0:
        low = decimate_lod(body, args.lod)
        export_glb(low, os.path.join(args.out, f"orion_tripo_mobile{args.tag}.glb"))
        if "lodsheet" in views:
            body.hide_render = True
            next(n for n in low.data.materials[0].node_tree.nodes
                 if n.type == "BSDF_PRINCIPLED").inputs["Emission Strength"].default_value = args.glow
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
