"""Island 1 v2 terrain: a clean heightfield built from the v1 island (props removed, water carved, tiles flat),
a triangulated top surface inside a smoothed outline, layered cliff walls and a conical bottom.
Coordinates: Blender (x right, y back, z up), metres; same frame as the board tiles."""
import math

import numpy as np
from scipy import ndimage as ndi

from common import V1_GLB, hsv, log, smooth, tiles_blender
import layout

RES = 20.0  # raster pixels per metre


# ----------------------------------------------------------------------------- v1 raster (top view)
def raster_v1():
    """import the v1 island and rasterise it from above: colour, height, up-normal"""
    import bpy
    from scipy.ndimage import map_coordinates
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=V1_GLB)
    ob = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
    M = np.array(ob.matrix_world)
    me = ob.data
    co = np.empty(len(me.vertices) * 3, np.float32)
    me.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3) @ M[:3, :3].T + M[:3, 3]
    fv = np.empty(len(me.polygons) * 3, np.int32)
    me.polygons.foreach_get("vertices", fv)
    fv = fv.reshape(-1, 3)
    ls = np.empty(len(me.polygons), np.int32)
    me.polygons.foreach_get("loop_start", ls)
    uv = np.empty(len(me.loops) * 2, np.float32)
    me.uv_layers.active.data.foreach_get("uv", uv)
    uv = uv.reshape(-1, 2)
    img = next(n.image for n in me.materials[0].node_tree.nodes if n.type == "TEX_IMAGE"
               and any(l.to_socket.name == "Base Color" for l in n.outputs[0].links))
    w, h = img.size
    tex = np.empty(w * h * img.channels, np.float32)
    img.pixels.foreach_get(tex)
    tex = tex.reshape(h, w, img.channels)[::-1, :, :3]
    P = co[fv]
    lo, hi = co.min(0), co.max(0)
    Wp, Hp = int((hi[0] - lo[0]) * RES) + 2, int((hi[1] - lo[1]) * RES) + 2
    zb = np.full((Hp, Wp), -1e9, np.float32)
    col = np.zeros((Hp, Wp, 3), np.float32)
    for f in range(len(fv)):
        P3 = P[f]
        S = np.stack([(P3[:, 0] - lo[0]) * RES, (hi[1] - P3[:, 1]) * RES], 1)
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
        U = B @ np.stack([uv[ls[f] + k] for k in range(3)])
        col[yy, xx] = np.stack([map_coordinates(tex[..., k], [(1 - U[:, 1]) * h - 0.5, U[:, 0] * w - 0.5],
                                                order=1, mode="nearest") for k in range(3)], -1)
        zb[yy, xx] = z
    log("[terrain] v1 raster", Wp, "x", Hp)
    return dict(col=col, zb=zb, lo=lo, hi=hi)


class Grid:
    """maps between metres (x, y) and raster pixels (col, row)"""

    def __init__(self, lo, hi, shape):
        self.lo, self.hi, self.shape = lo, hi, shape

    def px(self, x, y):
        return (np.asarray(x) - self.lo[0]) * RES, (self.hi[1] - np.asarray(y)) * RES

    def xy(self, cx, cy):
        return self.lo[0] + np.asarray(cx) / RES, self.hi[1] - np.asarray(cy) / RES

    def dist_map(self, x, y):
        H, W = self.shape
        cy, cx = np.mgrid[0:H, 0:W]
        X, Y = self.xy(cx + 0.5, cy + 0.5)
        return np.hypot(X - x, Y - y)

    def sample(self, img, x, y, order=1):
        scalar = np.ndim(x) == 0
        cx, cy = self.px(np.atleast_1d(x), np.atleast_1d(y))
        out = ndi.map_coordinates(img, [cy - 0.5, cx - 0.5], order=order, mode="nearest")
        return out[0] if scalar else out


def disk(r_m):
    r = int(round(r_m * RES))
    yy, xx = np.mgrid[-r:r + 1, -r:r + 1]
    return (xx * xx + yy * yy) <= r * r


def inpaint(img, mask, iters=400):
    """fill masked pixels by diffusion from their surroundings"""
    out = img.copy()
    known = ~mask
    if not mask.any():
        return out
    idx = ndi.distance_transform_edt(mask, return_distances=False, return_indices=True)
    out[mask] = img[idx[0][mask], idx[1][mask]]
    for _ in range(iters):
        blur = ndi.uniform_filter(out, 5)
        out[mask] = blur[mask]
    out[known] = img[known]
    return out


# ----------------------------------------------------------------------------- heightfield and masks
def build_fields(r):
    col, zb = r["col"], r["zb"]
    g = Grid(r["lo"], r["hi"], zb.shape)
    valid = zb > -1e8
    hue, sat, val = hsv(col)
    water = valid & (hue > 165) & (hue < 215) & (sat > 0.28) & (val > 0.3)
    water = ndi.binary_opening(water, iterations=2)
    # island outline: drop thin overhangs (palm fronds), fill holes, keep the main body, round it off
    body = ndi.binary_fill_holes(ndi.binary_opening(valid, structure=disk(0.55)))
    lab, n = ndi.label(body)
    body = lab == (np.argmax(np.bincount(lab.ravel())[1:]) + 1)
    body = ndi.gaussian_filter(body.astype(np.float32), 0.35 * RES) > 0.5
    # ground: remove narrow bumps (trees, lanterns) by a grey opening, big props by masking + inpainting
    idx = ndi.distance_transform_edt(~valid, return_distances=False, return_indices=True)
    zf = zb[idx[0], idx[1]]
    fp = disk(1.1)
    ground = ndi.grey_dilation(ndi.grey_erosion(zf, footprint=fp), footprint=fp)
    props = np.zeros(zb.shape, bool)
    for p in layout.HERO:
        props |= g.dist_map(p["x"], p["y"]) < p["r"] + 0.3
    props |= g.dist_map(layout.BIG_TREE["x"], layout.BIG_TREE["y"]) < layout.BIG_TREE["r"]
    ground = inpaint(ground, props & ~water)
    # water: each body of water is flat in v1; carve a bed under it
    wlab, wn = ndi.label(water)
    bodies = []
    for i in range(1, wn + 1):
        m = wlab == i
        area = m.sum() / RES ** 2
        if area < 2.0:
            water[m] = False
            continue
        level = float(np.median(zb[m]))
        bodies.append(dict(mask=m, level=level, area=area))
    water_level = np.full(zb.shape, np.nan, np.float32)
    bed = ground.copy()
    for b in bodies:
        d = ndi.distance_transform_edt(b["mask"]) / RES
        depth = 0.08 + 0.55 * smooth(0.0, 0.9, d)
        bed = np.where(b["mask"], b["level"] - depth, bed)
        water_level[b["mask"]] = b["level"]
    hf = ndi.gaussian_filter(bed, 0.3 * RES)
    # keep the water edges crisp: under water use the carved bed, just slightly softened
    soft_bed = ndi.gaussian_filter(bed, 0.12 * RES)
    any_w = water.copy()
    hf = np.where(ndi.binary_dilation(any_w, iterations=2), soft_bed, hf)
    # tiles: flat seats just under each tile (the tile stone is 0.12 m thick, its top is the board height)
    tiles, tr = tiles_blender()
    seat = np.zeros(zb.shape, np.float32)
    target = np.zeros(zb.shape, np.float32)
    for t in tiles:
        d = g.dist_map(t[0], t[1])
        w = smooth(tr + 0.55, tr + 0.1, d)
        upd = w > seat
        target[upd] = t[2] - 0.1
        seat = np.maximum(seat, w)
    hf = hf * (1 - seat) + target * seat
    # material masks (0..1): cobblestone path / plaza, sand near water, moss handled by slope + rim
    beige = valid & (sat < 0.3) & (val > 0.55) & ~water
    for t in tiles:
        beige &= g.dist_map(t[0], t[1]) > tr + 0.1
    path = ndi.gaussian_filter(ndi.binary_opening(beige, iterations=2).astype(np.float32), 0.15 * RES)
    near_w = ndi.distance_transform_edt(~water) / RES
    sand = smooth(0.7, 0.15, near_w) * (1 - smooth(0.0, 0.4, hf - np.nan_to_num(water_level, nan=-99) - 0.3))
    sand = np.clip(np.where(water, 1.0, sand), 0, 1)
    log("[terrain] water bodies:", ", ".join(f"{b['area']:.0f} m2 @ {b['level']:.2f} m" for b in bodies))
    return dict(grid=g, height=hf, body=body, water=water, bodies=bodies, path=np.clip(path, 0, 1), sand=sand,
                col=col, props=props)
