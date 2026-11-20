"""helpers shared by the island v2 build scripts (Blender 5.1 as a Python module)"""
import math
import os
import time

import numpy as np

T0 = time.time()
REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
GODOT = os.path.join(REPO, "godot")
V1_GLB = os.path.join(GODOT, "assets", "models", "_vechi", "insula1_tripo_v1.glb")
TILES_JSON = os.path.join(REPO, "blender", "out_insula1", "insula1_casute.json")
OUT_MODELS = os.path.join(GODOT, "assets", "models", "insula1_v2")
OUT_DATA = os.path.join(GODOT, "insula_v2", "data")
OUT_TEX = os.path.join(GODOT, "insula_v2", "textures")


def log(*a):
    print(f"[{time.time() - T0:7.1f}s]", *a, flush=True)


def smooth(e0, e1, x):
    t = np.clip((np.asarray(x, np.float64) - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def hsv(a):
    mx, mn = a.max(-1), a.min(-1)
    d = np.maximum(mx - mn, 1e-4)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    h = np.where(mx == r, ((g - b) / d) % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) * 60
    return h, (mx - mn) / np.maximum(mx, 1e-4), mx


def srgb_to_lin(c):
    c = np.asarray(c, np.float64)
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def hexc(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)])


def tiles_blender():
    """board tiles in Blender coordinates (x right, y back, z up), metres"""
    import json
    with open(TILES_JSON) as f:
        board = json.load(f)
    t = np.array([[c["x"], -c["z"], c["y"]] for c in board["casute"]], np.float64)
    return t, float(board["raza_casuta"])


def gd_vec3(p):
    """Blender (x, y, z) -> Godot Vector3 literal (x, z, -y)"""
    return f"Vector3({p[0]:.3f}, {p[2]:.3f}, {-p[1]:.3f})"
