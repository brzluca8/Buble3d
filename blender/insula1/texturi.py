"""
Texturi mici pentru atmosfera insulei (procedural, fără AI): valurile apei, norul și raza de soare.

    python blender/insula1/texturi.py

Scrie în godot/insula1/textures/: apa_normal.png (hartă de normale tileable, convenția OpenGL, cum o vrea Godot),
nor.png (sprite de nor, RGBA), raze.png (rază de soare, RGBA), detaliu.png (stratul de detaliu fin al insulei,
tileable: R stâncă cu crăpături, G iarbă în fire, B granulație; media 0.5, deci nu schimbă culoarea medie),
casuta_albedo.png / casuta_normal.png (piatra căsuței: bej cald, cel mult 0,82, ca să nu se „ardă” în alb sub soare;
gravura în romb adâncă și mai închisă, umbră spre margine) și iconite_casute.png (5 iconițe groase, cu contur închis).
"""
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage as ndi

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "godot", "insula1", "textures")
os.makedirs(OUT, exist_ok=True)


def ss(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def hexc(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])


def noise(sigma, n, seed):
    r = np.random.default_rng(seed)
    a = ndi.gaussian_filter(r.standard_normal((n, n)), sigma, mode="wrap")
    return (a - a.min()) / (a.max() - a.min())


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
    Image.fromarray(((nn * 0.5 + 0.5) * 255 + 0.5).astype(np.uint8)).save(os.path.join(OUT, "apa_normal.png"))


def cloud():
    n = 256
    yy, xx = np.mgrid[0:n, 0:n] / n
    a = np.zeros((n, n))
    for cx, cy, r in ((0.5, 0.58, 0.3), (0.32, 0.62, 0.22), (0.68, 0.62, 0.22), (0.42, 0.45, 0.2), (0.6, 0.47, 0.2),
                      (0.2, 0.7, 0.14), (0.8, 0.7, 0.14)):
        a = np.maximum(a, ss(r, r * 0.55, np.hypot(xx - cx, (yy - cy) * 1.15)))
    a *= ss(0.86, 0.72, yy)  # baza mai plată
    a = ndi.gaussian_filter(a, 2.5)
    shade = np.clip(1.0 - 0.45 * ss(0.3, 0.85, yy) + 0.1 * (noise(6, n, 51) - 0.5), 0, 1)
    rgb = np.ones((n, n, 3)) * hexc("#C9DDF5") * (1 - shade[..., None]) + shade[..., None]
    Image.fromarray((np.dstack([rgb, a]) * 255).astype(np.uint8), "RGBA").save(os.path.join(OUT, "nor.png"))


def sun_rays():
    n = 256
    yy, xx = np.mgrid[0:n, 0:n] / n
    a = ss(0.5, 0.0, np.abs(xx - 0.5)) * ss(1.0, 0.0, yy) ** 1.5 * 0.9
    rgb = np.ones((n, n, 3)) * hexc("#FFF1C9")
    Image.fromarray((np.dstack([rgb, a]) * 255).astype(np.uint8), "RGBA").save(os.path.join(OUT, "raze.png"))


def norm(a, std=0.16):
    a = (a - a.mean()) / max(a.std(), 1e-6)
    return np.clip(0.5 + a * std, 0, 1)


def detail():
    n = 512
    r = np.random.default_rng(77)
    # stâncă: celule Voronoi (crăpături întunecate la margini) + zgomot pe două scări
    pts = r.random((90, 2)) * n
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    d1 = np.full((n, n), 1e9, np.float32)
    d2 = np.full((n, n), 1e9, np.float32)
    for px, py in pts:
        for ox in (-n, 0, n):
            for oy in (-n, 0, n):
                d = np.hypot(xx - (px + ox), yy - (py + oy))
                m = d < d1
                d2 = np.where(m, d1, np.minimum(d2, d))
                d1 = np.where(m, d, d1)
    crapaturi = ss(0.0, 6.0, d2 - d1)
    rock = 0.55 * crapaturi + 0.3 * noise(10, n, 1) + 0.15 * noise(2.5, n, 2)
    # iarbă: fire scurte (zgomot alungit pe o direcție) + pete
    g = r.standard_normal((n, n))
    fire = ndi.gaussian_filter(g, (6.0, 0.8), mode="wrap")
    grass = 0.6 * norm(fire, 1) + 0.4 * noise(14, n, 3)
    # granulație fină, pentru restul (lemn, pietre, clădiri): foarte discretă
    grain = 0.6 * noise(1.2, n, 4) + 0.4 * noise(5, n, 5)
    rgb = np.dstack([norm(rock), norm(grass), norm(grain, 0.12)])
    Image.fromarray((rgb * 255 + 0.5).astype(np.uint8)).save(os.path.join(OUT, "detaliu.png"))


def save_normal(name, h, strength):
    gx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5 * strength
    gy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5 * strength
    nn = np.dstack([-gx, gy, np.ones_like(h)])
    nn /= np.linalg.norm(nn, axis=2, keepdims=True)
    Image.fromarray(((nn * 0.5 + 0.5) * 255 + 0.5).astype(np.uint8)).save(os.path.join(OUT, name))


def tile_stone():
    n = 1024
    yy, xx = (np.mgrid[0:n, 0:n] + 0.5) / n - 0.5
    r = np.hypot(xx, yy) * 2  # 1 la marginea discului
    v = 0.6 * noise(60, n, 61) + 0.25 * noise(14, n, 62) + 0.15 * noise(3, n, 63)
    lo, mid, hi = hexc("#B9A27E"), hexc("#CDB892"), hexc("#D9C6A2")  # bej cald, maxim ~0,85 înainte de umbre
    alb = np.where((v < 0.5)[..., None], lo + (mid - lo) * (v / 0.5)[..., None], mid + (hi - mid) * ((v - 0.5) / 0.5)[..., None])
    alb *= (1 - 0.22 * ss(0.72, 0.99, r))[..., None]          # umbră (AO) spre marginea teșită
    alb *= (1 + 0.015 * np.sin(r * 22 + v * 9))[..., None]
    d = np.abs(xx) + np.abs(yy)  # rombul
    engr = ss(0.016, 0.0, np.abs(d - 0.17)) + ss(0.011, 0.0, np.abs(d - 0.11)) * 0.8
    star = np.maximum(ss(0.008, 0.0, np.abs(xx)) * ss(0.13, 0.05, np.abs(yy)), ss(0.008, 0.0, np.abs(yy)) * ss(0.13, 0.05, np.abs(xx)))
    engr = np.clip(engr + star * 0.85, 0, 1)
    groove = hexc("#7E6646")
    alb = alb * (1 - engr[..., None] * 0.7) + groove * (engr[..., None] * 0.7)
    alb = np.clip(alb, 0, 0.82)
    Image.fromarray((alb * 255 + 0.5).astype(np.uint8)).save(os.path.join(OUT, "casuta_albedo.png"))
    H = 1 - ss(0.82, 1.0, r) * 0.7 - engr * 0.9 + 0.05 * v
    save_normal("casuta_normal.png", ndi.gaussian_filter(H, 1.2), 22.0)


def icons():
    """5 iconițe într-un atlas 5x1 (RGBA): start, cufăr, zar, eveniment, carte; forme groase cu contur închis"""
    s = 256
    im = Image.new("RGBA", (s * 5, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    W, G, D_, O = (255, 250, 238, 255), (255, 200, 60, 255), (110, 62, 24, 255), (52, 28, 70, 255)
    lw = 9  # contur
    # START: steag pe catarg
    x = 0
    d.rectangle([x + 78, 30, x + 104, 226], fill=W, outline=O, width=lw)
    d.polygon([(x + 104, 36), (x + 214, 82), (x + 104, 132)], fill=G, outline=O, width=lw)
    # cufăr
    x = s
    d.rounded_rectangle([x + 34, 108, x + 222, 220], radius=18, fill=G, outline=O, width=lw)
    d.pieslice([x + 34, 40, x + 222, 178], 180, 360, fill=G, outline=O, width=lw)
    d.rectangle([x + 38, 104, x + 218, 126], fill=D_)
    d.rounded_rectangle([x + 110, 96, x + 146, 150], radius=6, fill=W, outline=O, width=6)
    # zar
    x = 2 * s
    d.rounded_rectangle([x + 40, 40, x + 216, 216], radius=34, fill=W, outline=O, width=lw)
    for px, py in ((84, 84), (172, 172), (128, 128), (84, 172), (172, 84)):
        d.ellipse([x + px - 17, py - 17, x + px + 17, py + 17], fill=(70, 40, 120, 255))
    # eveniment: stea
    x = 3 * s
    pts = []
    for k in range(10):
        a = -math.pi / 2 + k * math.pi / 5
        rr = 112 if k % 2 == 0 else 48
        pts.append((x + 128 + rr * math.cos(a), 136 + rr * math.sin(a)))
    d.polygon(pts, fill=G, outline=O, width=lw)
    # carte deschisă
    x = 4 * s
    d.polygon([(x + 24, 64), (x + 124, 86), (x + 124, 222), (x + 24, 200)], fill=W, outline=O, width=lw)
    d.polygon([(x + 232, 64), (x + 132, 86), (x + 132, 222), (x + 232, 200)], fill=W, outline=O, width=lw)
    for (a_, b_) in (((50, 112), (106, 124)), ((50, 146), (106, 158)), ((150, 124), (206, 112)), ((150, 158), (206, 146))):
        d.line([(x + a_[0], a_[1]), (x + b_[0], b_[1])], fill=(120, 90, 160, 255), width=8)
    im = im.filter(ImageFilter.GaussianBlur(0.6))
    im.save(os.path.join(OUT, "iconite_casute.png"))


if __name__ == "__main__":
    for fn in (water_normal, cloud, sun_rays, detail, tile_stone, icons):
        fn()
        print("[tex]", fn.__name__)
