#!/usr/bin/env python3
"""Generează texturile de nori (PNG cu transparență) pentru Godot: godot/art3d/cloud_<n>.png"""
import sys

import numpy as np
from PIL import Image, ImageFilter

OUT = sys.argv[1] if len(sys.argv) > 1 else "godot/art3d"
W, H = 512, 256
rng = np.random.default_rng(7)
yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)


def noise(scale, seed):
    r = np.random.default_rng(seed)
    small = r.random((H // scale + 2, W // scale + 2)).astype(np.float32)
    img = Image.fromarray((small * 255).astype(np.uint8)).resize((W, H), Image.BICUBIC)
    return np.asarray(img).astype(np.float32) / 255.0


for n in range(3):
    field = np.zeros((H, W), np.float32)
    base_y = H * 0.74
    count = 22 + n * 5
    for i in range(count):
        u = rng.random()
        cx = W * (0.18 + 0.64 * u)
        top = 1.0 - abs(u - 0.5) * 2.0                  # mai înalt la mijloc
        r = H * (0.07 + 0.08 * rng.random()) * (0.7 + 0.7 * top)
        cy = base_y - r * 0.4 - (H * 0.42) * top * rng.random() ** 0.7
        cy = max(cy, r * 1.6 + 6)
        field = np.maximum(field, np.exp(-(((xx - cx) ** 2 + (yy - cy) ** 2) / (2 * r * r))) * 1.25)
    field *= np.clip((base_y + 8 - yy) / 14.0, 0, 1)                  # bază plată
    field += (noise(14, n) - 0.5) * 0.18 + (noise(4, n + 10) - 0.5) * 0.08
    a = np.clip((field - 0.55) / 0.3, 0, 1)
    a = a * a * (3 - 2 * a)
    # umbrire: sus alb-cald, jos albăstrui, interior ușor mai luminos
    light = np.clip(1.0 - (yy - H * 0.2) / (H * 0.6), 0, 1)
    top_c = np.array([255, 252, 246], np.float32)
    bot_c = np.array([196, 206, 236], np.float32)
    rgb = bot_c + (top_c - bot_c) * light[..., None]
    rgb += (np.clip(field - 0.9, 0, 1) * 10)[..., None]
    img = Image.fromarray(np.dstack([np.clip(rgb, 0, 255), a * 255]).astype(np.uint8), "RGBA")
    img = img.filter(ImageFilter.GaussianBlur(1.2))
    img.save(f"{OUT}/cloud_{n}.png")
    print("salvat", f"{OUT}/cloud_{n}.png")
