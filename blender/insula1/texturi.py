"""
Texturi mici pentru atmosfera insulei (procedural, fără AI): valurile apei, norul și raza de soare.

    python blender/insula1/texturi.py

Scrie în godot/insula1/textures/: apa_normal.png (hartă de normale tileable, convenția OpenGL, cum o vrea Godot),
nor.png (sprite de nor, RGBA), raze.png (rază de soare, RGBA), detaliu.png (stratul de detaliu fin al insulei,
tileable: R stâncă cu crăpături, G iarbă în fire, B granulație; media 0.5, deci nu schimbă culoarea medie).
"""
import os

import numpy as np
from PIL import Image
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


if __name__ == "__main__":
    for fn in (water_normal, cloud, sun_rays, detail):
        fn()
        print("[tex]", fn.__name__)
