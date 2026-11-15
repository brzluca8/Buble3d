#!/usr/bin/env python3
"""Decupează fundalul unei imagini generate (magenta #FF00FF sau altă culoare plată).

    python3 tools/cutout.py intrare.png iesire.png [--culoare ff00ff] [--toleranta 80]

- Dacă imaginea are deja transparență, doar o taie la conținut.
- Altfel ia culoarea fundalului din colțuri (sau --culoare), o face transparentă cu margini
  netede, elimină tenta de fundal de pe margini și taie imaginea la conținut.
"""
import argparse

import numpy as np
from PIL import Image

ap = argparse.ArgumentParser()
ap.add_argument("intrare")
ap.add_argument("iesire")
ap.add_argument("--culoare", default=None, help="culoarea fundalului, ex. ff00ff (implicit: din colțuri)")
ap.add_argument("--toleranta", type=float, default=80.0)
ap.add_argument("--margine", type=float, default=40.0, help="lățimea tranziției moi")
a = ap.parse_args()

im = Image.open(a.intrare).convert("RGBA")
px = np.asarray(im).astype(np.float32)
rgb, alpha = px[..., :3], px[..., 3]

if alpha.min() < 250:
    out = px
else:
    if a.culoare:
        bg = np.array([int(a.culoare[i:i + 2], 16) for i in (0, 2, 4)], np.float32)
    else:
        h, w = alpha.shape
        k = max(4, min(h, w) // 40)
        corners = np.concatenate([rgb[:k, :k].reshape(-1, 3), rgb[:k, -k:].reshape(-1, 3), rgb[-k:, :k].reshape(-1, 3), rgb[-k:, -k:].reshape(-1, 3)])
        bg = np.median(corners, axis=0)
    d = np.linalg.norm(rgb - bg, axis=-1)
    a_new = np.clip((d - a.toleranta) / a.margine, 0.0, 1.0)
    # elimină tenta fundalului de pe pixelii semi-transparenți
    a3 = a_new[..., None]
    safe = np.maximum(a3, 1e-3)
    clean = np.clip((rgb - bg * (1 - a3)) / safe, 0, 255)
    rgb = np.where(a3 < 0.999, clean, rgb)
    out = np.dstack([rgb, a_new * 255.0])

res = Image.fromarray(out.astype(np.uint8), "RGBA")
bbox = res.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
if bbox:
    res = res.crop(bbox)
res.save(a.iesire)
print("salvat", a.iesire, res.size)
