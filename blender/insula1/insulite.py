"""
Insulițele plutitoare din fundal (procedural, fără AI), v4: forme rotunjite și netede, nu prisme.
Corpul e o suprafață de revoluție închisă (dom de iarbă sus, buză de iarbă care atârnă, stâncă în trepte rotunjite
care se strânge spre un vârf), cu umbrire netedă și normale spre exterior pe toate fețele. Copacii au coroane din
sfere netede și trunchiuri curbate; câteva tufe rotunde; o cascadă cade de pe margine și se topește în nori.

v3 avea fețe întoarse (normala spre interior pe o parte din domul de sus și pe coroanele care se intersectau):
în Godot, cu materialul pe două fețe, ieșeau triunghiuri negre. Aici fiecare piesă e un corp închis, cu fețele
construite în același sens și verificate la final (0 fețe întoarse, altfel scriptul se oprește).

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
from mathutils import Matrix, Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "godot", "assets", "models", "fundal")


def lin(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return np.array([x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c])


# aceleași familii de culori ca insula mare: stâncă lila-gri în trepte, iarbă caldă, coroane verzi și roz
STANCA_SUS = lin("#B3A6C9")
STANCA = lin("#8F82AE")
STANCA_JOS = lin("#5E5482")
IARBA_SUS = lin("#9BD84A")
IARBA = lin("#73BF3C")
IARBA_MARGINE = lin("#5FA534")
TRUNCHI = lin("#8A5A35")
COROANA = [lin("#5DB246"), lin("#4C9F3D"), lin("#71C24F")]
ROZ = [lin("#F49AC4"), lin("#F7B3D2")]


def ss(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


class Part:
    """un bmesh cu culori pe vârfuri; fiecare piesă adăugată e un corp închis, cu fețele spre exterior"""

    def __init__(self):
        self.bm = bmesh.new()
        self.col = self.bm.verts.layers.float_color.new("Col")

    def revolutie(self, profil, culori, seg, raza_ang=None, centru=(0.0, 0.0, 0.0)):
        """profil: [(raza, z)] de sus în jos; primul și ultimul punct au raza 0 (polii). raza_ang(i, k) -> factor"""
        cx, cy, cz = centru
        rings = []
        poli = []
        for k, (r, z) in enumerate(profil):
            if r <= 1e-6:
                v = self.bm.verts.new((cx, cy, cz + z))
                v[self.col] = (*culori(k, 0), 1.0)
                poli.append((k, v))
                rings.append(None)
                continue
            ring = []
            for i in range(seg):
                a = 2 * math.pi * i / seg
                f = raza_ang(i, k) if raza_ang else 1.0
                v = self.bm.verts.new((cx + math.cos(a) * r * f, cy + math.sin(a) * r * f, cz + z))
                v[self.col] = (*culori(k, i), 1.0)
                ring.append(v)
            rings.append(ring)
        pol = dict(poli)
        for k in range(len(profil) - 1):
            a, b = rings[k], rings[k + 1]
            for i in range(seg):
                j = (i + 1) % seg
                if a is None:  # polul de sus: triunghiuri spre exterior (sens trigonometric privit de sus)
                    self.bm.faces.new([pol[k], b[i], b[j]])
                elif b is None:  # polul de jos
                    self.bm.faces.new([a[j], a[i], pol[k + 1]])
                else:
                    self.bm.faces.new([a[i], b[i], b[j], a[j]])

    def sfera(self, c, r, culoare_fn, seg=12, inele=8, turtire=1.0):
        prof = []
        for k in range(inele + 1):
            t = math.pi * k / inele
            prof.append((r * math.sin(t), r * math.cos(t) * turtire))
        self.revolutie(prof, lambda k, i: culoare_fn(k / inele), seg, centru=c)

    def trunchi(self, baza, h, r0, r1, curb, culoare, seg=8, n=5):
        """trunchi curbat: inele de-a lungul unei curbe; capac sus și jos (corp închis)"""
        def punct(t):
            return baza + Vector((curb[0] * t * t, curb[1] * t * t, h * t))
        verts = []
        for k in range(n + 1):
            t = k / n
            p = punct(t)
            r = r0 + (r1 - r0) * t
            ring = []
            for i in range(seg):
                a = 2 * math.pi * i / seg
                v = self.bm.verts.new(p + Vector((math.cos(a) * r, math.sin(a) * r, 0.0)))
                v[self.col] = (*(culoare * (0.8 + 0.25 * t)), 1.0)
                ring.append(v)
            verts.append(ring)
        for k in range(n):
            for i in range(seg):
                j = (i + 1) % seg
                self.bm.faces.new([verts[k][i], verts[k][j], verts[k + 1][j], verts[k + 1][i]])
        self.bm.faces.new(list(reversed(verts[0])))
        self.bm.faces.new(verts[n])
        return punct(1.0)


def zgomot_unghiular(rng, seg, amplitudini):
    faze = rng.random(len(amplitudini)) * 2 * np.pi
    a = np.linspace(0, 2 * np.pi, seg, endpoint=False)
    return 1.0 + sum(amp * np.sin(a * (f + 2) + ph) for f, (amp, ph) in enumerate(zip(amplitudini, faze)))


def islet(seed, R, H, n_copaci, latura_cascadei):
    rng = np.random.default_rng(seed)
    p = Part()
    SEG = 40
    # profilul corpului, de sus în jos: dom de iarbă, buza care atârnă, stânca în trepte rotunjite, vârful
    prof = [(0.0, 0.42), (R * 0.35, 0.38), (R * 0.65, 0.27), (R * 0.88, 0.13), (R * 0.99, 0.0), (R * 1.03, -0.12),
            (R * 0.98, -0.24)]
    n_sus = len(prof)
    trepte = 9
    for k in range(1, trepte + 1):
        t = k / trepte
        z = -0.24 - t * H
        treapta = 0.035 * math.sin(t * math.pi * 5.0)  # trepte rotunjite, nu muchii
        prof.append((R * (0.98 * (1 - t ** 1.6) + 0.06) * (1 + treapta), z))
    prof.append((0.0, -0.24 - H * 1.12))
    zg = zgomot_unghiular(rng, SEG, [0.07, 0.05, 0.03])
    zg_j = zgomot_unghiular(rng, SEG, [0.1, 0.06, 0.04])

    def raza_ang(i, k):
        if k < n_sus:
            return zg[i]
        t = (k - n_sus) / trepte
        return zg[i] * (1 - t) + zg_j[i] * t

    def culori(k, i):
        z = prof[k][1]
        if k <= 4:  # domul de iarbă: mai deschis spre mijloc
            return IARBA_SUS * (1 - k / 5) + IARBA * (k / 5)
        if k <= 6:  # buza care atârnă: iarbă mai închisă (umbra de sub ea vine din normale)
            return IARBA_MARGINE * (1.0 if k == 5 else 0.85)
        t = min(1.0, (-z - 0.24) / H)
        dungi = 0.92 + 0.1 * math.sin(z * 7.0 + i * 0.3) + 0.05 * math.sin(i * 1.7)
        c = STANCA_SUS * (1 - ss(0.0, 0.45, t)) + STANCA * ss(0.0, 0.45, t)
        c = c * (1 - ss(0.45, 1.0, t)) + STANCA_JOS * ss(0.45, 1.0, t)
        ao = 0.72 if k == 7 else 1.0  # sub buză
        return c * dungi * ao

    p.revolutie(prof, culori, SEG, raza_ang)

    # copaci: trunchi curbat, coroană din 3-4 sfere netede (verde sau roz), puțin turtite
    for t_ in range(n_copaci):
        a_ = rng.random() * 2 * np.pi
        d_ = rng.uniform(0.05, 0.42) * R
        baza = Vector((math.cos(a_) * d_, math.sin(a_) * d_, 0.3))
        h_ = rng.uniform(1.3, 2.0)
        varf = p.trunchi(baza, h_, 0.14, 0.08, (rng.normal(0, 0.25), rng.normal(0, 0.25)), TRUNCHI)
        roz = (t_ + seed) % 3 == 0
        for b_ in range(4):
            off = Vector((rng.normal(0, 0.32), rng.normal(0, 0.32), rng.uniform(0.05, 0.45)))
            rr = rng.uniform(0.45, 0.72) * (0.85 if b_ == 3 else 1.0)
            cc = ROZ[b_ % 2] if roz else COROANA[b_ % 3]
            p.sfera(varf + off, rr, lambda t, cc=cc: cc * (1.08 - 0.38 * t), seg=14, inele=9, turtire=0.86)
    # tufe rotunde, pe jumătate în iarbă
    for _ in range(3):
        a_ = rng.random() * 2 * np.pi
        d_ = rng.uniform(0.45, 0.75) * R
        c = Vector((math.cos(a_) * d_, math.sin(a_) * d_, 0.2))
        cc = COROANA[rng.integers(3)]
        p.sfera(c, rng.uniform(0.25, 0.38), lambda t, cc=cc: cc * (1.05 - 0.4 * t), seg=12, inele=7, turtire=0.75)

    me = bpy.data.meshes.new("Corp")
    bmesh.ops.recalc_face_normals(p.bm, faces=p.bm.faces)  # fiecare piesă e închisă: orientarea e sigură
    p.bm.to_mesh(me)
    p.bm.free()
    corp = bpy.data.objects.new("Corp", me)
    bpy.context.scene.collection.objects.link(corp)
    corp.data.color_attributes.active_color = corp.data.color_attributes["Col"]
    corp.data.shade_smooth()
    verifica_normale(corp)

    # cascada: panglică de pe margine, bombată în afară, ~1.5 x înălțimea insulei
    a0 = latura_cascadei
    r0 = R * 1.0
    buza = Vector((math.cos(a0) * r0, math.sin(a0) * r0, 0.02))
    afara = Vector((math.cos(a0), math.sin(a0), 0))
    lat = Vector((-math.sin(a0), math.cos(a0), 0))
    L = H * 1.5
    randuri = 16
    w = 0.6
    bm2 = bmesh.new()
    col = bm2.verts.layers.float_color.new("Col")
    uvl = bm2.loops.layers.uv.new("UVMap")
    grila = []
    for i in range(randuri + 1):
        s = i / randuri
        d = s * L
        pos = buza + afara * (0.3 * math.sin(min(s * 3, 1) * math.pi / 2) + 0.18 * s) + Vector((0, 0, -d))
        rand = []
        for j in range(4):
            u = j / 3
            v = bm2.verts.new(pos + lat * (u - 0.5) * w * (1 + 0.6 * s))
            v[col] = (1.0, max(0.0, 1.0 - d / 0.3), s, 1.0)
            rand.append((v, u, d))
        grila.append(rand)
    for i in range(randuri):
        for j in range(3):
            a, b, c, d_ = grila[i][j], grila[i][j + 1], grila[i + 1][j + 1], grila[i + 1][j]
            f = bm2.faces.new([a[0], b[0], c[0], d_[0]])
            for loop, (_, u, dd) in zip(f.loops, [a, b, c, d_]):
                loop[uvl].uv = (u, 1.0 - dd)  # glTF/Godot întoarce V: UV.y = metri de la buză
    # fața cascadei spre exterior (dinspre insulă spre cameră)
    bm2.normal_update()
    if sum(f.normal.dot(afara) for f in bm2.faces) < 0:
        bmesh.ops.reverse_faces(bm2, faces=list(bm2.faces))
    me2 = bpy.data.meshes.new("Cascada")
    bm2.to_mesh(me2)
    bm2.free()
    casc = bpy.data.objects.new("Cascada", me2)
    bpy.context.scene.collection.objects.link(casc)
    casc.data.color_attributes.active_color = casc.data.color_attributes["Col"]
    casc.data.shade_smooth()
    return corp, casc


def verifica_normale(o):
    """fiecare față trebuie să privească în afara corpului ei: centrul feței + normala iese din corp"""
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bm.normal_update()
    insule = []
    vazute = set()
    for f in bm.faces:
        if f.index in vazute:
            continue
        stiva, comp = [f], []
        vazute.add(f.index)
        while stiva:
            g = stiva.pop()
            comp.append(g)
            for e in g.edges:
                for h in e.link_faces:
                    if h.index not in vazute:
                        vazute.add(h.index)
                        stiva.append(h)
        insule.append(comp)
    rele = 0
    for comp in insule:
        # volumul cu semn al corpului închis: pozitiv dacă normalele privesc în afară
        vol = 0.0
        for f in comp:
            vs = [v.co for v in f.verts]
            for k in range(1, len(vs) - 1):
                vol += vs[0].dot(vs[k].cross(vs[k + 1])) / 6.0
        if vol <= 0:
            rele += len(comp)
        if any(not e.is_manifold for f in comp for e in f.edges):
            raise SystemExit(f"[insulita] corp deschis în {o.name}")
    bm.free()
    if rele:
        raise SystemExit(f"[insulita] {rele} fețe întoarse în {o.name}")
    print("[insulita] %s: %d corpuri închise, 0 fețe întoarse" % (o.name, len(insule)))


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, seed, R, H, nt, side in [("a", 3, 2.4, 3.0, 2, 0.6), ("b", 11, 1.8, 2.5, 1, 2.4), ("c", 23, 2.9, 3.6, 3, 4.1)]:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        corp, casc = islet(seed, R, H, nt, side)
        bpy.ops.object.select_all(action="DESELECT")
        corp.select_set(True)
        casc.select_set(True)
        path = os.path.join(OUT, f"insulita_cascada_{name}.glb")
        bpy.ops.export_scene.gltf(filepath=path, use_selection=True, export_yup=True, export_vertex_color="ACTIVE",
                                  export_materials="PLACEHOLDER", export_normals=True)
        tri = sum(len(f.vertices) - 2 for f in corp.data.polygons)
        print("[insulita]", name, tri, "triunghiuri +", len(casc.data.polygons) * 2, "(cascada) ->", path)


if __name__ == "__main__":
    main()
