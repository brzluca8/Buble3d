"""
Insula 1 v2: texturi pictate procedural (fără AI), tileable, 1024 px pe 2 m (512 px/m).

    python make_textures.py

Scrie în godot/insula_v2/textures/:
  iarba, muschi, stanca, piatra (pavaj), nisip: *_albedo.png (+ *_normal.png pentru stâncă și pavaj)
  apa_normal.png (valuri, tileable), nor.png (sprite de nor), raze.png (rază de soare)
  casuta_albedo.png / casuta_normal.png (piatra căsuței, cu gravura în romb), iconite_casute.png (5 iconițe)
  checker_1024.png (debug: densitatea texelilor; un pătrat = 25 cm = 128 px)
Normal maps în convenția OpenGL (Y+), cum le așteaptă Godot.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np  # noqa: E402
from PIL import Image, ImageDraw, ImageFilter, ImageFont  # noqa: E402
from scipy import ndimage as ndi  # noqa: E402

from common import OUT_TEX, hexc, log  # noqa: E402

N = 1024
os.makedirs(OUT_TEX, exist_ok=True)
rng = np.random.default_rng(5)


def noise(sigma, n=N, seed=None):
    """periodic smooth noise in [0, 1] (gaussian-filtered white noise with wrap-around)"""
    r = np.random.default_rng(seed) if seed is not None else rng
    a = ndi.gaussian_filter(r.standard_normal((n, n)), sigma, mode="wrap")
    a -= a.min()
    return a / max(a.max(), 1e-9)


def fbm(sigmas, weights, n=N, seed=None):
    r = np.random.default_rng(seed) if seed is not None else rng
    out = np.zeros((n, n))
    for s, w in zip(sigmas, weights):
        out += w * ndi.gaussian_filter(r.standard_normal((n, n)), s, mode="wrap") * s ** 0.5
    out -= out.min()
    return out / out.max()


def ss(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def mix(a, b, t):
    t = np.asarray(t)[..., None] if np.ndim(t) == 2 else t
    return a * (1 - t) + b * t


def pal(*hexes):
    return [hexc(h) for h in hexes]


def ramp(v, stops):
    """map v in [0,1] through colour stops [(pos, rgb), ...]"""
    out = np.zeros(v.shape + (3,))
    pos = [p for p, _ in stops]
    for k in range(3):
        out[..., k] = np.interp(v, pos, [c[k] for _, c in stops])
    return out


def save_rgb(name, a):
    Image.fromarray((np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8)).save(os.path.join(OUT_TEX, name))


def save_normal(name, h, strength):
    """height (periodic) -> OpenGL normal map"""
    gx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5 * strength
    gy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5 * strength
    n = np.dstack([-gx, gy, np.ones_like(h)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    save_rgb(name, n * 0.5 + 0.5)


def stamp_strokes(canvas, xs, ys, angles, lengths, widths, values):
    """add soft elongated strokes (wrap-around) into canvas"""
    H, W = canvas.shape
    for x, y, a, L, w, v in zip(xs, ys, angles, lengths, widths, values):
        r = int(L / 2 + w + 2)
        oy, ox = np.mgrid[-r:r + 1, -r:r + 1]
        ca, sa = math.cos(a), math.sin(a)
        u = ox * ca + oy * sa
        q = -ox * sa + oy * ca
        f = np.clip(1 - (u / (L / 2)) ** 2 - (q / w) ** 2, 0, 1) ** 0.6
        yy = (int(y) + oy) % H
        xx = (int(x) + ox) % W
        np.add.at(canvas, (yy, xx), f * v)


# ----------------------------------------------------------------------------- grass
def grass():
    big = fbm([90, 40, 16], [1, 0.6, 0.35], seed=1)
    clump = noise(7, seed=2)
    base = ramp(big, [(0.0, hexc("#3E9A2C")), (0.45, hexc("#5DB534")), (0.8, hexc("#7CC83C")), (1.0, hexc("#93D24A"))])
    # clumps: lighter on their upper-left (key light), darker lower-right
    sh = np.roll(clump, (3, 3), (0, 1)) - clump
    base *= (1 + 0.22 * (clump - 0.5) - 0.35 * sh)[..., None]
    # blade strokes
    lum = np.zeros((N, N))
    n_bl = 26000
    stamp_strokes(lum, rng.uniform(0, N, n_bl), rng.uniform(0, N, n_bl), rng.uniform(0, np.pi, n_bl),
                  rng.uniform(7, 15, n_bl), rng.uniform(1.0, 1.8, n_bl), rng.choice([-1, 1], n_bl) * rng.uniform(0.3, 1, n_bl))
    lum = ndi.gaussian_filter(lum, 0.6, mode="wrap")
    base *= (1 + 0.09 * np.tanh(lum))[..., None]
    base = mix(base, base * hexc("#F3FF9A") * 1.25, ss(0.55, 0.95, noise(3, seed=3)) * 0.18)
    # tiny flowers (white, yellow, pink) here and there
    fl = np.zeros((N, N, 3))
    for col, cnt in ((hexc("#FFFFFF"), 150), (hexc("#FFE45C"), 110), (hexc("#FF9CC8"), 90)):
        xs, ys = rng.uniform(0, N, cnt).astype(int), rng.uniform(0, N, cnt).astype(int)
        for x, y in zip(xs, ys):
            for dx, dy in ((0, 0), (2, 0), (-2, 0), (0, 2), (0, -2)):
                fl[(y + dy) % N, (x + dx) % N] = col
    m = ndi.gaussian_filter((fl.sum(2) > 0).astype(float), 0.7, mode="wrap")[..., None]
    base = base * (1 - m * 0.85) + fl * 0.85
    save_rgb("iarba_albedo.png", base)
    save_normal("iarba_normal.png", ndi.gaussian_filter(clump * 2 + np.tanh(lum) * 0.2, 1, mode="wrap"), 6.0)


def moss():
    v = fbm([30, 10, 3], [1, 0.7, 0.4], seed=11)
    base = ramp(v, [(0.0, hexc("#2F6E2A")), (0.5, hexc("#4C9A30")), (1.0, hexc("#86C447"))])
    spk = ss(0.8, 0.95, noise(1.2, seed=12))
    base = mix(base, hexc("#B7E36A"), spk * 0.35)
    save_rgb("muschi_albedo.png", base)


# ----------------------------------------------------------------------------- rock (layered blocks)
def voronoi(n, cell_w, cell_h, aniso, seed, jit=0.8):
    """periodic anisotropic Voronoi: nearest-cell index, distance to the border (px)"""
    r = np.random.default_rng(seed)
    pts = []
    for gy in range(int(n / cell_h)):
        off = r.uniform(0, cell_w)
        for gx in range(int(n / cell_w)):
            pts.append(((gx * cell_w + off + r.uniform(-jit, jit) * cell_w * 0.5) % n,
                        (gy + 0.5 + r.uniform(-jit, jit) * 0.45) * cell_h))
    pts = np.array(pts)
    yy, xx = np.mgrid[0:n, 0:n]
    d1 = np.full((n, n), 1e9)
    d2 = np.full((n, n), 1e9)
    idx = np.zeros((n, n), int)
    for i, (px, py) in enumerate(pts):
        dx = ((xx - px + n / 2) % n - n / 2) / aniso
        dy = (yy - py + n / 2) % n - n / 2
        d = np.hypot(dx, dy)
        m = d < d1
        d2 = np.where(m, d1, np.minimum(d2, d))
        idx = np.where(m, i, idx)
        d1 = np.where(m, d, d1)
    return idx, (d2 - d1) / 2, len(pts)


def rock():
    """natural layered rock: chunky cells stretched sideways (strata), rounded, painted light from upper-left"""
    warp = (fbm([28, 8], [1, 0.5], seed=24) - 0.5) * 46
    idx, edge, npts = voronoi(N, 256, 128, 2.3, seed=23)  # big chunks: reads as natural cliff, not masonry
    idx = ndi.map_coordinates(idx.astype(float), np.mgrid[0:N, 0:N] + warp[None] * np.array([1, 0.6])[:, None, None],
                              order=0, mode="wrap").astype(int)
    edge = ndi.map_coordinates(edge, np.mgrid[0:N, 0:N] + warp[None] * np.array([1, 0.6])[:, None, None],
                               order=1, mode="wrap")
    det = fbm([14, 5, 1.6], [1, 0.6, 0.35], seed=21)
    bulge = ss(1.5, 26, edge) ** 0.55
    lift = np.random.default_rng(25).uniform(0.75, 1.2, npts)[idx]
    H = bulge * lift + 0.22 * det
    cols = pal("#B3A79F", "#C4B6A8", "#A0949C", "#CDBEAD", "#9A8E97", "#BBAEA2")
    alb = np.array(cols)[np.random.default_rng(26).integers(len(cols), size=npts)][idx]
    alb *= np.random.default_rng(27).uniform(0.9, 1.08, npts)[idx][..., None]
    gy = np.roll(H, 2, 0) - np.roll(H, -2, 0)
    gx = np.roll(H, 2, 1) - np.roll(H, -2, 1)
    light = np.clip(0.5 + 1.5 * (gy * 0.9 + gx * 0.4), 0, 1)  # brighter where the surface faces up-left
    alb *= (0.7 + 0.55 * light)[..., None]
    alb *= (0.86 + 0.24 * det)[..., None]
    alb = mix(alb, hexc("#4E4258"), ss(4.0, 0.5, edge) * 0.8)  # dark cracks
    tint = noise(70, seed=22)
    alb = mix(alb, alb * hexc("#C9B4FF") * 1.06, (1 - tint) * 0.28)  # lavender shadows like the target
    alb = mix(alb, alb * hexc("#FFE2BC") * 1.06, tint * 0.25)
    save_rgb("stanca_albedo.png", alb)
    save_normal("stanca_normal.png", ndi.gaussian_filter(H, 1.2, mode="wrap"), 16.0)


# ----------------------------------------------------------------------------- cobblestone
def cobble():
    pts = []
    cell = 92
    for gy in range(N // cell):
        for gx in range(N // cell):
            pts.append(((gx + rng.uniform(0.15, 0.85)) * cell, (gy + rng.uniform(0.15, 0.85)) * cell))
    pts = np.array(pts)
    yy, xx = np.mgrid[0:N, 0:N]
    d1 = np.full((N, N), 1e9)
    d2 = np.full((N, N), 1e9)
    idx = np.zeros((N, N), int)
    for i, (px, py) in enumerate(pts):
        dx = (xx - px + N / 2) % N - N / 2
        dy = (yy - py + N / 2) % N - N / 2
        d = np.hypot(dx * rng.uniform(0.9, 1.1), dy)
        m = d < d1
        d2 = np.where(m, d1, np.minimum(d2, d))
        idx = np.where(m, i, idx)
        d1 = np.where(m, d, d1)
    edge = (d2 - d1) / 2  # distance to the cell border
    stone = ss(2.5, 11, edge)
    H = stone ** 0.6 + 0.08 * fbm([6, 2], [1, 0.5], seed=31)
    cols = pal("#D9C7A6", "#C8B38F", "#E3D3B4", "#BFA98A", "#D2BC98")
    ci = np.array([cols[i % len(cols)] * rng.uniform(0.92, 1.06) for i in range(len(pts))])
    alb = ci[idx]
    gy = np.roll(H, 2, 0) - np.roll(H, -2, 0)
    gx = np.roll(H, 2, 1) - np.roll(H, -2, 1)
    light = np.clip(0.5 + 2.2 * (-gy * 0.8 - gx * 0.4), 0, 1)
    alb *= (0.78 + 0.42 * light)[..., None]
    alb = mix(alb, hexc("#7A6650"), (1 - stone) * 0.85)
    grass_in = ss(0.62, 0.8, noise(18, seed=32)) * (1 - stone)
    alb = mix(alb, hexc("#5DAE36"), grass_in * 0.7)
    save_rgb("piatra_albedo.png", alb)
    save_normal("piatra_normal.png", ndi.gaussian_filter(H, 1.0, mode="wrap"), 10.0)


def sand():
    v = fbm([40, 8, 1.2], [1, 0.5, 0.4], seed=41)
    alb = ramp(v, [(0.0, hexc("#D9BE86")), (0.5, hexc("#E9D3A0")), (1.0, hexc("#F6E6BE"))])
    peb = ss(0.86, 0.95, noise(2.5, seed=42))
    alb = mix(alb, hexc("#B49B7A"), peb * 0.6)
    save_rgb("nisip_albedo.png", alb)


# ----------------------------------------------------------------------------- water, clouds, sun rays
def water_normal():
    n = 512
    h = np.zeros((n, n))
    for s, w in ((22, 1.0), (9, 0.6), (3.5, 0.3)):
        r = np.random.default_rng(int(s * 10))
        h += w * ndi.gaussian_filter(r.standard_normal((n, n)), s, mode="wrap") * s
    h = (h - h.min()) / (h.max() - h.min())
    gx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5 * 40
    gy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5 * 40
    nn = np.dstack([-gx, gy, np.ones_like(h)])
    nn /= np.linalg.norm(nn, axis=2, keepdims=True)
    Image.fromarray(((nn * 0.5 + 0.5) * 255 + 0.5).astype(np.uint8)).save(os.path.join(OUT_TEX, "apa_normal.png"))


def cloud():
    n = 256
    yy, xx = np.mgrid[0:n, 0:n] / n
    a = np.zeros((n, n))
    for cx, cy, r in ((0.5, 0.58, 0.3), (0.32, 0.62, 0.22), (0.68, 0.62, 0.22), (0.42, 0.45, 0.2), (0.6, 0.47, 0.2),
                      (0.2, 0.7, 0.14), (0.8, 0.7, 0.14)):
        a = np.maximum(a, ss(r, r * 0.55, np.hypot(xx - cx, (yy - cy) * 1.15)))
    a *= ss(0.86, 0.72, yy)  # flatter bottom
    a = ndi.gaussian_filter(a, 2.5)
    shade = np.clip(1.0 - 0.45 * ss(0.3, 0.85, yy) + 0.1 * (noise(6, n, seed=51) - 0.5), 0, 1)
    rgb = mix(np.ones((n, n, 3)) * hexc("#C9DDF5"), np.ones((n, n, 3)), shade)
    Image.fromarray((np.dstack([rgb, a]) * 255).astype(np.uint8), "RGBA").save(os.path.join(OUT_TEX, "nor.png"))


def sun_rays():
    n = 256
    yy, xx = np.mgrid[0:n, 0:n] / n
    a = ss(0.5, 0.0, np.abs(xx - 0.5)) * ss(1.0, 0.0, yy) ** 1.5 * 0.9
    rgb = np.ones((n, n, 3)) * hexc("#FFF1C9")
    Image.fromarray((np.dstack([rgb, a]) * 255).astype(np.uint8), "RGBA").save(os.path.join(OUT_TEX, "raze.png"))


# ----------------------------------------------------------------------------- board tile stone (disc UV 0..1)
def tile_stone():
    n = 1024
    yy, xx = (np.mgrid[0:n, 0:n] + 0.5) / n - 0.5
    r = np.hypot(xx, yy) * 2  # 1 at the disc edge
    v = fbm([60, 14, 3], [1, 0.5, 0.35], n=n, seed=61)
    alb = ramp(v, [(0.0, hexc("#E2CFAE")), (0.5, hexc("#EEDDC0")), (1.0, hexc("#F8EBD3"))])
    # subtle rings of the stone + darker rim
    alb *= (1 - 0.1 * ss(0.78, 0.98, r))[..., None]
    alb *= (1 + 0.012 * np.sin(r * 22 + v * 9))[..., None]
    alb *= (1 + 0.06 * (0.5 - r))[..., None]
    # engraved diamond (rhombus) in the middle, like the target
    d = np.abs(xx) + np.abs(yy)  # L1 distance: rhombus
    engr = ss(0.012, 0.0, np.abs(d - 0.16)) + ss(0.008, 0.0, np.abs(d - 0.105)) * 0.7
    star = np.maximum(ss(0.006, 0.0, np.abs(xx)) * ss(0.12, 0.05, np.abs(yy)),
                      ss(0.006, 0.0, np.abs(yy)) * ss(0.12, 0.05, np.abs(xx)))
    engr = np.clip(engr + star * 0.8, 0, 1)
    alb = mix(alb, hexc("#B79C76"), engr * 0.8)
    H = 1 - ss(0.86, 1.0, r) * 0.6 - engr * 0.5 + 0.06 * v
    save_rgb("casuta_albedo.png", alb)
    save_normal("casuta_normal.png", ndi.gaussian_filter(H, 1.0), 14.0)


def icons():
    """5 icons in a 5x1 atlas (RGBA): start, cufar, zar, eveniment, carte"""
    s = 256
    im = Image.new("RGBA", (s * 5, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    W, G, D_ = (255, 255, 255, 255), (255, 214, 92, 255), (90, 50, 20, 255)
    # START: flag
    x = 0
    d.rectangle([x + 92, 40, x + 108, 220], fill=W)
    d.polygon([(x + 108, 44), (x + 200, 80), (x + 108, 118)], fill=G)
    # cufar: chest
    x = s
    d.rounded_rectangle([x + 50, 110, x + 206, 210], radius=14, fill=G)
    d.pieslice([x + 50, 50, x + 206, 170], 180, 360, fill=G)
    d.rectangle([x + 50, 108, x + 206, 124], fill=D_)
    d.rectangle([x + 116, 100, x + 140, 140], fill=W)
    # zar: dice
    x = 2 * s
    d.rounded_rectangle([x + 58, 58, x + 198, 198], radius=26, fill=W)
    for px, py in ((96, 96), (160, 160), (128, 128), (96, 160), (160, 96)):
        d.ellipse([x + px - 13, py - 13, x + px + 13, py + 13], fill=(70, 40, 120, 255))
    # eveniment: star
    x = 3 * s
    pts = []
    for k in range(10):
        a = -math.pi / 2 + k * math.pi / 5
        rr = 96 if k % 2 == 0 else 40
        pts.append((x + 128 + rr * math.cos(a), 132 + rr * math.sin(a)))
    d.polygon(pts, fill=G)
    # carte: book
    x = 4 * s
    d.polygon([(x + 40, 70), (x + 126, 88), (x + 126, 210), (x + 40, 192)], fill=W)
    d.polygon([(x + 216, 70), (x + 130, 88), (x + 130, 210), (x + 216, 192)], fill=W)
    d.line([(x + 60, 110), (x + 110, 120)], fill=(120, 90, 160, 255), width=6)
    d.line([(x + 60, 140), (x + 110, 150)], fill=(120, 90, 160, 255), width=6)
    d.line([(x + 146, 120), (x + 196, 110)], fill=(120, 90, 160, 255), width=6)
    im = im.filter(ImageFilter.GaussianBlur(0.8))
    im.save(os.path.join(OUT_TEX, "iconite_casute.png"))


def checker():
    n = 1024
    yy, xx = np.mgrid[0:n, 0:n]
    sq = ((xx // 128 + yy // 128) % 2).astype(float)
    a = np.dstack([0.9 - 0.5 * sq, 0.55 + 0.1 * sq, 0.2 + 0.6 * sq])
    grid = ((xx % 128) < 3) | ((yy % 128) < 3)
    a[grid] = 1.0
    im = Image.fromarray((a * 255).astype(np.uint8))
    d = ImageDraw.Draw(im)
    f = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 22)
    for gy in range(8):
        for gx in range(8):
            d.text((gx * 128 + 10, gy * 128 + 8), f"{gx}{gy}", font=f, fill=(255, 255, 255))
    im.save(os.path.join(OUT_TEX, "checker_1024.png"))


if __name__ == "__main__":
    for fn in (grass, moss, rock, cobble, sand, water_normal, cloud, sun_rays, tile_stone, icons, checker):
        fn()
        log("[tex]", fn.__name__)
