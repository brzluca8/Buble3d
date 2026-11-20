"""
Insula 1 v2: căsuța de joc (piatră + chenar auriu, UV pentru textura cu gravură) și insulițele din fundal.

    python build_extra.py

Scrie godot/assets/models/insula1_v2/casuta.glb (sus la y = 0, raza 0,76 m; COLOR.r = auriu, COLOR.g = AO)
și godot/assets/models/insula1_v2/insulita_a/b/c.glb (doar culori pe vârfuri, se văd de departe).
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy  # noqa: E402  (bpy first: it makes bmesh importable)
import bmesh  # noqa: E402
import numpy as np  # noqa: E402
from mathutils import Vector  # noqa: E402

from common import OUT_MODELS, log  # noqa: E402
from meshkit import C, Part, bake_ao, export, tri_count  # noqa: E402

R_TOP = 0.70   # stone top (UV disc)
R_RIM = 0.78   # gold rim
DEPTH = 0.26


def tile():
    """disc tile: rounded stone top with planar UV, a gold bevelled rim, stone side"""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    n = 40
    verts, faces, uvs, cols = [], [], [], []
    rings = [  # (radius, z, gold, ao)
        (0.0, 0.0, 0.0, 1.0),
        (0.35, 0.0, 0.0, 1.0),
        (0.62, -0.004, 0.0, 1.0),
        (R_TOP, -0.014, 0.0, 0.95),
        (R_TOP + 0.012, -0.03, 1.0, 0.9),   # gold rim: inner edge
        (R_RIM - 0.012, -0.022, 1.0, 1.0),  # gold rim: top
        (R_RIM, -0.05, 1.0, 0.9),           # gold rim: outer edge
        (R_RIM, -0.09, 0.0, 0.85),          # stone side
        (R_RIM - 0.03, -DEPTH, 0.0, 0.55),
    ]
    idx = []
    for k, (r, z, g, ao) in enumerate(rings):
        row = []
        cnt = 1 if r == 0 else n
        for i in range(cnt):
            a = 2 * math.pi * i / n
            x, y = r * math.cos(a), r * math.sin(a)
            row.append(len(verts))
            verts.append((x, y, z))
            # top: planar UV over the stone diameter; side: continues outward (texture edge colour)
            uvs.append((0.5 + x / (2 * R_RIM), 0.5 - y / (2 * R_RIM)))
            cols.append((g, ao, 0.0, 1.0))
        idx.append(row)
    for i in range(n):  # centre fan
        faces.append((idx[0][0], idx[1][i], idx[1][(i + 1) % n]))
    for k in range(1, len(rings) - 1):
        for i in range(n):
            a, b = idx[k][i], idx[k][(i + 1) % n]
            c, d = idx[k + 1][i], idx[k + 1][(i + 1) % n]
            faces.append((a, c, d))
            faces.append((a, d, b))
    me = bpy.data.meshes.new("Casuta")
    me.from_pydata(verts, [], faces)
    me.update()
    uv = me.uv_layers.new(name="UVMap")
    for poly in me.polygons:
        poly.use_smooth = True
        for li in poly.loop_indices:
            uv.data[li].uv = uvs[me.loops[li].vertex_index]
    ca = me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    ca.data.foreach_set("color", np.array(cols, np.float32).ravel())
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new("Casuta", me)
    bpy.context.scene.collection.objects.link(ob)
    me.materials.append(bpy.data.materials.new("Casuta_mat"))
    export([ob], os.path.join(OUT_MODELS, "casuta.glb"))
    log(f"[glb] casuta: {tri_count([ob])} triangles")


def islet(name, seed, size, palms):
    """small floating island for the background: grassy top, layered rock cone, a waterfall streak"""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    rng = np.random.default_rng(seed)
    p = Part("Corp")
    n = 22
    R = size * (1 + 0.18 * np.sin(np.arange(n) * 2 * math.pi / n * 3 + rng.uniform(0, 6)))
    top = [(R[i] * math.cos(2 * math.pi * i / n), R[i] * math.sin(2 * math.pi * i / n), 0.0) for i in range(n)]
    rows = [[(0, 0, 0.12 * size)] * (n + 1), top + [top[0]]]
    z = 0.0
    for k, (shrink, dz) in enumerate(((0.96, 0.25), (0.85, 0.55), (0.72, 0.6), (0.5, 0.75), (0.25, 0.7), (0.04, 0.6))):
        z -= dz * size
        jit = rng.uniform(0.9, 1.08, n)
        ring = [(R[i] * shrink * jit[i] * math.cos(2 * math.pi * i / n), R[i] * shrink * jit[i] * math.sin(2 * math.pi * i / n), z)
                for i in range(n)]
        rows.append(ring + [ring[0]])

    def colr(i, j):
        if i <= 1:
            return C("#62B83A", 0.95 + 0.1 * (j % 2))
        if i == 2:
            return C("#4E9A34")
        return C("#A79AA6" if (i + j) % 3 else "#968A98", 1.0 - 0.06 * i)
    p.strip(rows, colr, smooth=False)
    # waterfall streak down one side
    a = rng.uniform(0, 2 * math.pi)
    fx, fy = math.cos(a), math.sin(a)
    w = 0.18 * size
    p.poly([(fx * size * 0.98 - fy * w, fy * size * 0.98 + fx * w, 0.02), (fx * size * 0.98 + fy * w, fy * size * 0.98 - fx * w, 0.02),
            (fx * size * 1.05 + fy * w, fy * size * 1.05 - fx * w, -2.6 * size), (fx * size * 1.05 - fy * w, fy * size * 1.05 + fx * w, -2.6 * size)],
           color=C("#DFF7FF"))
    for k in range(palms):  # little palms
        aa = rng.uniform(0, 2 * math.pi)
        rr = rng.uniform(0.1, 0.55) * size
        x, y = rr * math.cos(aa), rr * math.sin(aa)
        h = rng.uniform(0.9, 1.3) * size * 0.8
        p.cyl(0.05 * size, 0.04 * size, h, loc=(x, y, 0), rot=(rng.uniform(-10, 10), rng.uniform(-10, 10), 0), color=C("#8E5E36"), seg=6)
        p.ball(0.42 * size, loc=(x, y, h), scale=(1.3, 1.3, 0.45), color=C("#4FAF36"), subdiv=1, smooth=False)
    ob = p.to_object()
    bake_ao([ob], ground_z=None, rays=12, dist=size)
    export([ob], os.path.join(OUT_MODELS, f"{name}.glb"))
    log(f"[glb] {name}: {tri_count([ob])} triangles")


if __name__ == "__main__":
    tile()
    islet("insulita_a", 1, 1.6, 2)
    islet("insulita_b", 2, 1.1, 1)
    islet("insulita_c", 3, 2.1, 3)
