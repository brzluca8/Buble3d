"""
Insulițele plutitoare din fundal (procedural, fără AI): con de stâncă neregulat, cu straturi, iarbă deasupra cu
margine care atârnă, 1-2 copaci rotunzi și o cascadă care cade de pe margine și se topește în nori.

    python blender/insula1/insulite.py

Scrie godot/assets/models/fundal/insulita_cascada_{a,b,c}.glb, fiecare cu două obiecte:
  Corp    - stânca, iarba, copacii; culorile pe vârfuri (liniare) sunt chiar culoarea suprafeței
  Cascada - apa: UV.x = 0..1 pe lățime, UV.y = metri de la buză în jos; COLOR ca în water_flow.gdshader
            (A = 1 cascadă, G = spumă la buză, B = crește spre bază, R = 1: cade în gol și se destramă)
"""
import math
import os

import bpy  # noqa: I001  (bpy înainte de bmesh)
import bmesh
import numpy as np
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "godot", "assets", "models", "fundal")


def lin(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return np.array([x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c])


STANCA = [lin("#8E86A6"), lin("#6E6688"), lin("#A79FB8")]
IARBA = [lin("#8CCB3F"), lin("#6FB236"), lin("#A8D84E")]
TRUNCHI = lin("#7A5233")
COROANA = [lin("#4E9E3A"), lin("#3F8A33"), lin("#62B347")]
ROZ = lin("#F08CB8")


class Part:
    def __init__(self):
        self.bm = bmesh.new()
        self.col = self.bm.verts.layers.float_color.new("Col")

    def vert(self, p, c):
        v = self.bm.verts.new(p)
        v[self.col] = (*c, 1.0)
        return v

    def face(self, vs):
        try:
            return self.bm.faces.new(vs)
        except ValueError:
            return None


def islet(seed, R, H, n_trees, fall_side):
    rng = np.random.default_rng(seed)
    p = Part()
    N = 18
    ang = np.linspace(0, 2 * np.pi, N, endpoint=False)
    rad = R * (1 + 0.18 * np.sin(ang * 3 + rng.random() * 6) + 0.1 * rng.standard_normal(N))
    # inelele conului de stâncă, de sus în jos (se strâng spre vârf)
    levels = [0.0, -0.25, -0.9, -1.7, -2.6, -3.5]
    levels = [lv * H / 3.5 for lv in levels]
    rings = []
    for k, lv in enumerate(levels):
        f = 1.0 - (k / (len(levels) - 1)) ** 1.25 * 0.9
        ring = []
        for i in range(N):
            jit = 1 + 0.12 * rng.standard_normal()
            r_ = rad[i] * f * jit
            x, y = math.cos(ang[i]) * r_, math.sin(ang[i]) * r_
            z = lv + 0.15 * rng.standard_normal() * (k > 0)
            c = STANCA[(k + i) % 3] * (0.85 + 0.25 * rng.random()) * (1.0 - 0.06 * k)
            if k == 0:
                c = IARBA[i % 3] * 0.95  # marginea de iarbă care atârnă
            ring.append(p.vert((x, y, z), c))
        rings.append(ring)
    tip = p.vert((rng.normal(0, 0.2), rng.normal(0, 0.2), levels[-1] - 0.9 * H / 3.5), STANCA[1] * 0.7)
    for k in range(len(rings) - 1):
        a, b = rings[k], rings[k + 1]
        for i in range(N):
            j = (i + 1) % N
            p.face([a[i], b[i], b[j], a[j]])
    for i in range(N):
        p.face([rings[-1][i], tip, rings[-1][(i + 1) % N]])
    # vârful cu iarbă: un mic dom
    top = []
    for i in range(N):
        x, y = math.cos(ang[i]) * rad[i] * 0.98, math.sin(ang[i]) * rad[i] * 0.98
        top.append(p.vert((x, y, 0.05), IARBA[(i + 1) % 3]))
    mid = [p.vert((math.cos(a_) * r_ * 0.55, math.sin(a_) * r_ * 0.55, 0.22), IARBA[2]) for a_, r_ in zip(ang, rad)]
    ctr = p.vert((0, 0, 0.3), IARBA[0])
    for i in range(N):
        j = (i + 1) % N
        p.face([top[i], top[j], mid[j], mid[i]])
        p.face([mid[i], mid[j], ctr])
    # copacii: trunchi și 2-3 bile de coroană
    for t in range(n_trees):
        a_ = rng.random() * 2 * np.pi
        d_ = rng.uniform(0.0, 0.45) * R
        base = Vector((math.cos(a_) * d_, math.sin(a_) * d_, 0.2))
        h_ = rng.uniform(1.4, 2.2)
        res = bmesh.ops.create_cone(p.bm, cap_ends=True, segments=6, radius1=0.16, radius2=0.1, depth=h_,
                                    matrix=__import__("mathutils").Matrix.Translation(base + Vector((0, 0, h_ / 2))))
        for v in res["verts"]:
            v[p.col] = (*TRUNCHI, 1.0)
        for b_ in range(3):
            off = Vector((rng.normal(0, 0.35), rng.normal(0, 0.35), h_ + rng.uniform(-0.1, 0.4)))
            rr = rng.uniform(0.55, 0.85)
            res = bmesh.ops.create_icosphere(p.bm, subdivisions=1, radius=rr,
                                             matrix=__import__("mathutils").Matrix.Translation(base + off))
            cc = COROANA[b_ % 3] if (t + b_) % 4 else ROZ
            for v in res["verts"]:
                v.co.z = base.z + off.z + (v.co.z - base.z - off.z) * 0.8
                v[p.col] = (*(cc * (0.85 + 0.3 * (v.co.z - base.z - off.z + rr) / (2 * rr))), 1.0)
    me = bpy.data.meshes.new("Corp")
    p.bm.normal_update()
    bmesh.ops.recalc_face_normals(p.bm, faces=p.bm.faces)
    p.bm.to_mesh(me)
    p.bm.free()
    corp = bpy.data.objects.new("Corp", me)
    bpy.context.scene.collection.objects.link(corp)
    corp.data.color_attributes.active_color = corp.data.color_attributes["Col"]
    corp.data.shade_flat()
    # cascada: panglică de pe margine, bombată în afară, ~1.4 x înălțimea insulei
    a0 = fall_side
    r0 = R * 0.95
    lip = Vector((math.cos(a0) * r0, math.sin(a0) * r0, 0.05))
    out = Vector((math.cos(a0), math.sin(a0), 0))
    side = Vector((-math.sin(a0), math.cos(a0), 0))
    L = H * 1.5
    rows = 12
    w = 0.55
    bm2 = bmesh.new()
    col = bm2.verts.layers.float_color.new("Col")
    uvl = bm2.loops.layers.uv.new("UVMap")
    grid = []
    for i in range(rows + 1):
        s = i / rows
        d = s * L
        pos = lip + out * (0.25 * math.sin(min(s * 3, 1) * math.pi / 2) + 0.15 * s) + Vector((0, 0, -d))
        row = []
        for j in range(3):
            u = j / 2
            v = bm2.verts.new(pos + side * (u - 0.5) * w * (1 + 0.5 * s))
            v[col] = (1.0, max(0.0, 1.0 - d / 0.3), s, 1.0)
            row.append((v, u, d))
        grid.append(row)
    for i in range(rows):
        for j in range(2):
            a, b, c, d_ = grid[i][j], grid[i][j + 1], grid[i + 1][j + 1], grid[i + 1][j]
            f = bm2.faces.new([a[0], b[0], c[0], d_[0]])
            for loop, (_, u, dd) in zip(f.loops, [a, b, c, d_]):
                loop[uvl].uv = (u, 1.0 - dd)  # glTF/Godot întoarce V: UV.y = metri de la buză
    me2 = bpy.data.meshes.new("Cascada")
    bm2.to_mesh(me2)
    bm2.free()
    casc = bpy.data.objects.new("Cascada", me2)
    bpy.context.scene.collection.objects.link(casc)
    casc.data.color_attributes.active_color = casc.data.color_attributes["Col"]
    return corp, casc


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, seed, R, H, nt, side in [("a", 3, 2.4, 3.2, 2, 0.6), ("b", 11, 1.8, 2.6, 1, 2.4), ("c", 23, 2.9, 3.8, 2, 4.1)]:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        corp, casc = islet(seed, R, H, nt, side)
        bpy.ops.object.select_all(action="DESELECT")
        corp.select_set(True)
        casc.select_set(True)
        path = os.path.join(OUT, f"insulita_cascada_{name}.glb")
        bpy.ops.export_scene.gltf(filepath=path, use_selection=True, export_yup=True, export_vertex_color="ACTIVE",
                                  export_materials="PLACEHOLDER", export_normals=True)
        print("[insulita]", name, len(corp.data.polygons), "+", len(casc.data.polygons), "fețe ->", path)


if __name__ == "__main__":
    main()
