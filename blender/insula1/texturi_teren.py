"""
Insula 1, v4: texturile terenului nou (Inelul 1), pictate procedural, tileable, 1024 px pe 2 m = 512 px/m.

  iarba   - iarbă caldă, pictată: smocuri luminate din stânga-sus, fire, pete galben-verzi și verzi-reci (nou în v4)
  pamant  - cărare de pământ bej-cald cu pietricele (nou în v4)
  piatra  - pavaj (din generatorul v2, blender/insula_v2/make_textures.py)
  stanca  - stâncă în straturi, lila-gri, pentru pantele abrupte (v2)
  muschi  - mușchi (v2)
  checker - tabla de verificare a densității (un pătrat = 25 cm = 128 px)
  zgomot  - zgomot periodic mic, pentru variația mare de culoare din shader (în coordonatele lumii)

    python blender/insula1/texturi_teren.py

Scrie în godot/insula1/textures/teren/: *_albedo.png și *_normal.png (convenția OpenGL, Y+, cum le vrea Godot).
"""
import os
import sys

import numpy as np
from scipy import ndimage as ndi

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "blender", "insula_v2"))
import make_textures as mt  # noqa: E402

OUT = os.path.join(ROOT, "godot", "insula1", "textures", "teren")
os.makedirs(OUT, exist_ok=True)
mt.OUT_TEX = OUT
N = mt.N
hexc = mt.hexc
rng = np.random.default_rng(41)


def iarba():
    # variația mare (pete calde/reci) o face shaderul în coordonatele lumii, la 9 și 23 m: aici, puțină, ca textura
    # repetată la 2 m să nu se vadă în grilă
    mare = mt.fbm([110, 45], [1, 0.5], seed=101)
    baza = mt.ramp(mare, [(0.0, hexc("#62AA3B")), (0.5, hexc("#78BA40")), (1.0, hexc("#8CC646"))])
    cald = mt.ss(0.55, 0.85, mt.noise(60, seed=102))
    baza = mt.mix(baza, baza * hexc("#FFF2A6") * 1.12, cald * 0.15)
    # smocuri: celule moi de câțiva cm, luminate din stânga-sus (lumina cheie a lui Orion), umbrite jos-dreapta
    smoc = mt.ss(0.3, 0.8, mt.noise(13, seed=104))
    gy = np.roll(smoc, 5, 0) - np.roll(smoc, -5, 0)
    gx = np.roll(smoc, 5, 1) - np.roll(smoc, -5, 1)
    lum = np.clip(0.5 + 1.6 * (gy * 0.8 + gx * 0.5), 0, 1)
    baza *= (0.88 + 0.24 * lum)[..., None]
    baza *= (0.94 + 0.1 * smoc)[..., None]
    # fire de iarbă: tușe de 3-5 cm, mai deschise și mai închise
    fire = np.zeros((N, N))
    n_f = 16000
    mt.stamp_strokes(fire, rng.uniform(0, N, n_f), rng.uniform(0, N, n_f), rng.uniform(0, np.pi, n_f),
                     rng.uniform(14, 26, n_f), rng.uniform(1.4, 2.4, n_f),
                     rng.choice([-1, 1], n_f) * rng.uniform(0.3, 1, n_f))
    fire = ndi.gaussian_filter(fire, 0.8, mode="wrap")
    baza *= (1 + 0.07 * np.tanh(fire))[..., None]
    mt.save_rgb("iarba_albedo.png", baza)
    mt.save_normal("iarba_normal.png", ndi.gaussian_filter(smoc * 1.2 + np.tanh(fire) * 0.12, 1.5, mode="wrap"), 4.0)


def pamant():
    v = mt.fbm([60, 14, 3], [1, 0.45, 0.3], seed=111)
    alb = mt.ramp(v, [(0.0, hexc("#C29A66")), (0.5, hexc("#D3AE7A")), (1.0, hexc("#E2C493"))])
    pet = np.zeros((N, N))
    culp = np.zeros((N, N, 3))
    yy, xx = np.mgrid[0:N, 0:N]
    for _ in range(240):
        cx, cy = rng.uniform(0, N, 2)
        r = rng.uniform(5, 13)
        d = np.hypot(((xx - cx + N / 2) % N - N / 2) * rng.uniform(0.8, 1.0), (yy - cy + N / 2) % N - N / 2)
        m = mt.ss(r, r * 0.55, d)
        if not m.any():
            continue
        c = hexc("#E9DFCD") if rng.random() < 0.7 else hexc("#BDB2C2")
        pet = np.maximum(pet, m)
        culp = np.where((m > 0.01)[..., None], culp * (1 - m[..., None]) + c * rng.uniform(0.88, 1.04) * m[..., None], culp)
    gy = np.roll(pet, 2, 0) - np.roll(pet, -2, 0)
    gx = np.roll(pet, 2, 1) - np.roll(pet, -2, 1)
    lum = np.clip(0.5 + 1.6 * (gy * 0.8 + gx * 0.5), 0, 1)
    alb = mt.mix(alb, culp * (0.8 + 0.35 * lum)[..., None], pet * 0.92)
    umbra = mt.ss(0.0, 0.6, np.roll(pet, (3, 3), (0, 1)) - pet)
    alb *= (1 - 0.18 * umbra)[..., None]
    mt.save_rgb("pamant_albedo.png", alb)
    mt.save_normal("pamant_normal.png", ndi.gaussian_filter(pet + 0.25 * v, 1.0, mode="wrap"), 8.0)


def zgomot():
    """zgomot periodic mic (256 px) pentru variația mare din shader: R la 1, G la 1/3, B la 1/9 din repetare"""
    n = 256
    ch = []
    for k, sig in enumerate((26, 10, 4)):
        a = ndi.gaussian_filter(np.random.default_rng(130 + k).standard_normal((n, n)), sig, mode="wrap")
        a = (a - a.min()) / (a.max() - a.min())
        ch.append(a)
    from PIL import Image
    Image.fromarray((np.dstack(ch) * 255 + 0.5).astype(np.uint8)).save(os.path.join(OUT, "zgomot.png"))


if __name__ == "__main__":
    doar = sys.argv[1:]  # ex.: python texturi_teren.py iarba pamant
    for fn in (iarba, pamant, zgomot, mt.cobble, mt.rock, mt.moss, mt.checker):
        if doar and fn.__name__ not in doar:
            continue
        fn()
        print("[tex]", fn.__name__, flush=True)
    # numele din v2 -> numele din v4 (piatra = pavaj, stanca = stâncă)
    print("ok", OUT)
