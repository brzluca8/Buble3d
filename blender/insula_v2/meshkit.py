"""Small mesh-building kit for island v2 props: bmesh primitives with per-vertex colour (linear RGB) and a
per-vertex wind weight in alpha, AO baked by rays, export to GLB with named parts."""
import math

import bmesh
import bpy
import numpy as np
from mathutils import Euler, Matrix, Vector

from common import hexc, srgb_to_lin


def C(h, k=1.0):
    """hex sRGB -> linear rgb tuple (optionally darkened/brightened)"""
    return tuple(np.clip(srgb_to_lin(hexc(h) * k), 0, 1))


class Part:
    """one named mesh object being built"""

    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.col = self.bm.verts.layers.float_color.new("Col")

    def _finish(self, geom, color, sway, smooth, sway_fn=None):
        verts = [g for g in geom if isinstance(g, bmesh.types.BMVert)]
        faces = {f for v in verts for f in v.link_faces}
        for v in verts:
            w = sway if sway_fn is None else sway_fn(v.co)
            v[self.col] = (*color, w)
        for f in faces:
            f.smooth = smooth
        return verts

    def _M(self, loc, rot, scale):
        return Matrix.LocRotScale(Vector(loc), Euler([math.radians(a) for a in rot]).to_quaternion(), Vector(scale))

    def cyl(self, r1, r2, h, loc=(0, 0, 0), rot=(0, 0, 0), color=(1, 1, 1), seg=12, sway=0.0, smooth=True, caps=True,
            sway_fn=None):
        """cylinder / cone standing on loc (base at loc, axis +z before rotation)"""
        M = self._M(loc, rot, (1, 1, 1)) @ Matrix.Translation((0, 0, h / 2))
        g = bmesh.ops.create_cone(self.bm, cap_ends=caps, segments=seg, radius1=r1, radius2=max(r2, 1e-4), depth=h,
                                  matrix=M)
        return self._finish(g["verts"], color, sway, smooth, sway_fn)

    def box(self, size, loc=(0, 0, 0), rot=(0, 0, 0), color=(1, 1, 1), sway=0.0, smooth=False):
        g = bmesh.ops.create_cube(self.bm, size=1.0, matrix=self._M(loc, rot, size))
        return self._finish(g["verts"], color, sway, smooth)

    def ball(self, r, loc=(0, 0, 0), scale=(1, 1, 1), color=(1, 1, 1), subdiv=2, sway=0.0, smooth=True, rot=(0, 0, 0),
             sway_fn=None, jitter=0.0, rng=None):
        M = self._M(loc, rot, (r * scale[0], r * scale[1], r * scale[2]))
        g = bmesh.ops.create_icosphere(self.bm, subdivisions=subdiv, radius=1.0, matrix=M)
        vs = self._finish(g["verts"], color, sway, smooth, sway_fn)
        if jitter > 0 and rng is not None:
            c = Vector(loc)
            for v in vs:
                d = (v.co - c)
                v.co += d * float(rng.uniform(-jitter, jitter))
        return vs

    def poly(self, pts, color=(1, 1, 1), sway=0.0, smooth=False, sway_fn=None):
        """a single face (or fan) from 3D points"""
        vs = [self.bm.verts.new(Vector(p)) for p in pts]
        self.bm.faces.new(vs)
        return self._finish(vs, color, sway, smooth, sway_fn)

    def strip(self, rows, color_fn, sway_fn=None, smooth=True):
        """quad strip from rows of points (rows[i] = list of points across); color_fn(i, j) -> rgb"""
        grid = []
        for i, row in enumerate(rows):
            grid.append([self.bm.verts.new(Vector(p)) for p in row])
        for i in range(len(grid) - 1):
            for j in range(len(grid[i]) - 1):
                f = self.bm.faces.new([grid[i][j], grid[i][j + 1], grid[i + 1][j + 1], grid[i + 1][j]])
                f.smooth = smooth
        for i, row in enumerate(grid):
            for j, v in enumerate(row):
                c = color_fn(i, j)
                w = 0.0 if sway_fn is None else sway_fn(v.co)
                v[self.col] = (*c, w)
        return [v for r in grid for v in r]

    def to_object(self):
        me = bpy.data.meshes.new(self.name)
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)
        self.bm.to_mesh(me)
        self.bm.free()
        ob = bpy.data.objects.new(self.name, me)
        bpy.context.scene.collection.objects.link(ob)
        me.materials.append(bpy.data.materials.new(self.name + "_mat"))
        return ob


def bake_ao(objects, ground_z=None, rays=20, dist=1.6, strength=0.85):
    """per-vertex AO (multiplied into the colour) from rays against all given objects (+ an optional ground plane)"""
    from mathutils.bvhtree import BVHTree
    allv, allf, off = [], [], 0
    for ob in objects:
        me = ob.data
        M = ob.matrix_world
        allv += [M @ v.co for v in me.vertices]
        allf += [[i + off for i in p.vertices] for p in me.polygons]
        off += len(me.vertices)
    if ground_z is not None:
        s = 60
        base = len(allv)
        allv += [Vector((-s, -s, ground_z)), Vector((s, -s, ground_z)), Vector((s, s, ground_z)), Vector((-s, s, ground_z))]
        allf.append([base, base + 1, base + 2, base + 3])
    bvh = BVHTree.FromPolygons(allv, allf)
    golden = math.pi * (3 - math.sqrt(5))
    dirs = []
    for i in range(rays):
        z = 1 - (i + 0.5) / rays
        r = math.sqrt(1 - z * z)
        dirs.append(Vector((math.cos(golden * i) * r, math.sin(golden * i) * r, z)))
    for ob in objects:
        me = ob.data
        me.calc_loop_triangles()
        M = ob.matrix_world
        N3 = M.to_3x3().inverted().transposed()
        col = me.color_attributes["Col"]
        for v in me.vertices:
            n = (N3 @ v.normal).normalized()
            up = Vector((0, 0, 1)) if abs(n.z) < 0.9 else Vector((1, 0, 0))
            tx = up.cross(n).normalized()
            ty = n.cross(tx)
            o = M @ v.co + n * 0.01
            occ = 0.0
            for d in dirs:
                w = tx * d.x + ty * d.y + n * d.z
                hit = bvh.ray_cast(o, w, dist)
                if hit[0] is not None:
                    occ += 1 - hit[3] / dist
            ao = 1 - strength * occ / rays
            c = col.data[v.index].color
            col.data[v.index].color = (c[0] * ao, c[1] * ao, c[2] * ao, c[3])


def export(objects, path):
    bpy.ops.object.select_all(action="DESELECT")
    for ob in objects:
        ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, use_selection=True, export_yup=True, export_apply=True,
                              export_vertex_color="ACTIVE", export_normals=True, export_materials="PLACEHOLDER")


def tri_count(objects):
    n = 0
    for ob in objects:
        ob.data.calc_loop_triangles()
        n += len(ob.data.loop_triangles)
    return n
