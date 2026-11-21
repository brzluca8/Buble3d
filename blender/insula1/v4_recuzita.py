"""
Insula 1, v4, Pasul 2: recuzita nouă a Inelului 1, procedurală (0 credite), în stilul „casual premium”:
forme rotunjite, normale netede, culori calde, gradient + zgomot pictat pe vârfuri, AO coaptă.

  palmier, arbore_roz, copac_mare (max 2.000 triunghiuri), tufa_0..2, iarba_smoc, floare, pietricica,
  gard (un segment de 1,2 m), felinar (pe stâlp, cu sticlă care luminează), butoi, lada, cristal_0..2

Convenții (le citește godot/insula1/shaders/recuzita.gdshader):
  COLOR.rgb = culoarea (liniară), COLOR.a = AO coaptă (Cycles, pe vârfuri)
  UV.x = cât luminează (sticla felinarului, cristalele), UV.y = cât se leagănă în vânt (0 la bază, 1 în vârf)
  originea la bază (pe sol), metri; Orion are 1,15 m.

    python blender/insula1/v4_recuzita.py

Scrie godot/assets/models/inel1/*.glb și docs/shots/insula_v4_recuzita.png (foaia de verificare, randare Cycles).
"""
import math
import os
import sys
import time

import bpy  # noqa: I001  (bpy înainte de bmesh)
import bmesh
import numpy as np
from mathutils import Matrix, Vector, noise

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "godot", "assets", "models", "inel1")
SHOTS = os.path.join(ROOT, "docs", "shots")
T0 = time.time()


def log(*a):
    print(f"[{time.time() - T0:7.1f}s]", *a, flush=True)


def lin(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return np.array([x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c])


def ss(e0, e1, x):
    t = min(max((x - e0) / (e1 - e0), 0.0), 1.0)
    return t * t * (3 - 2 * t)


class Piesa:
    """un bmesh cu culoare (RGB), emisie și vânt pe vârfuri (UV pe colțuri, din vârfuri, la final)"""

    def __init__(self, nume):
        self.nume = nume
        self.bm = bmesh.new()
        self.col = {}
        self.emi = {}
        self.vnt = {}
        self.netede = set()

    def v(self, p, c, e=0.0, w=0.0):
        vv = self.bm.verts.new(p)
        self.col[vv] = np.asarray(c, float)
        self.emi[vv] = e
        self.vnt[vv] = w
        return vv

    def f(self, vs):
        try:
            return self.bm.faces.new(vs)
        except ValueError:
            return None

    # --- forme de bază -------------------------------------------------------------------------------------------
    def revolutie(self, profil, seg, culoare, centru=Vector((0, 0, 0)), emisie=0.0, vant=None, capac_sus=True,
                  capac_jos=True, rot=Matrix.Identity(3), raza_ang=None):
        """profil [(raza, z)] de jos în sus; culoare(t_profil, unghi, punct) -> rgb"""
        inele = []
        n = len(profil)
        for k, (r, z) in enumerate(profil):
            inel = []
            for i in range(seg):
                a = 2 * math.pi * i / seg
                f_ = raza_ang(i, k) if raza_ang else 1.0
                p = centru + rot @ Vector((math.cos(a) * r * f_, math.sin(a) * r * f_, z))
                t = k / (n - 1)
                inel.append(self.v(p, culoare(t, a, p), emisie, vant(t) if vant else 0.0))
            inele.append(inel)
        for k in range(n - 1):
            for i in range(seg):
                j = (i + 1) % seg
                self.f([inele[k][i], inele[k][j], inele[k + 1][j], inele[k + 1][i]])
        if capac_jos and profil[0][0] > 1e-4:
            p = centru + rot @ Vector((0, 0, profil[0][1]))
            c = self.v(p, culoare(0.0, 0.0, p), emisie, vant(0.0) if vant else 0.0)
            for i in range(seg):
                self.f([inele[0][(i + 1) % seg], inele[0][i], c])
        if capac_sus and profil[-1][0] > 1e-4:
            p = centru + rot @ Vector((0, 0, profil[-1][1]))
            c = self.v(p, culoare(1.0, 0.0, p), emisie, vant(1.0) if vant else 0.0)
            for i in range(seg):
                self.f([inele[-1][i], inele[-1][(i + 1) % seg], c])
        return inele

    def sfera(self, c, r, culoare, seg=12, inele=8, turtire=1.0, vant=0.0, deformare=0.0, seed=0):
        """sferă UV netedă; culoare(sus01, punct) -> rgb; deformare: bulbi mici (zgomot)"""
        prof = []
        for k in range(inele + 1):
            t = math.pi * (inele - k) / inele  # de jos în sus
            prof.append((r * math.sin(t), r * math.cos(t) * turtire))

        def raza_ang(i, k):
            if not deformare:
                return 1.0
            a = 2 * math.pi * i / seg
            return 1.0 + deformare * noise.noise(Vector((math.cos(a) * 1.7 + seed, math.sin(a) * 1.7, k * 0.6)))

        prof[0] = (0.0, prof[0][1])
        prof[-1] = (0.0, prof[-1][1])
        # polii separat (vârf unic), ca să nu iasă fețe degenerate
        inele_v = []
        n = len(prof)
        jos = self.v(c + Vector((0, 0, prof[0][1])), culoare(0.0, c + Vector((0, 0, prof[0][1]))), 0.0, vant)
        sus = self.v(c + Vector((0, 0, prof[-1][1])), culoare(1.0, c + Vector((0, 0, prof[-1][1]))), 0.0, vant)
        for k in range(1, n - 1):
            r_, z_ = prof[k]
            inel = []
            for i in range(seg):
                a = 2 * math.pi * i / seg
                f_ = raza_ang(i, k)
                p = c + Vector((math.cos(a) * r_ * f_, math.sin(a) * r_ * f_, z_))
                inel.append(self.v(p, culoare(k / (n - 1), p), 0.0, vant))
            inele_v.append(inel)
        for i in range(seg):
            j = (i + 1) % seg
            self.f([inele_v[0][j], inele_v[0][i], jos])
            self.f([inele_v[-1][i], inele_v[-1][j], sus])
        for k in range(len(inele_v) - 1):
            for i in range(seg):
                j = (i + 1) % seg
                self.f([inele_v[k][i], inele_v[k][j], inele_v[k + 1][j], inele_v[k + 1][i]])

    def tub(self, puncte, raze, culoare, seg=8, vant=None, capac=True):
        """tub de-a lungul unei curbe (puncte), cu raze pe puncte; culoare(t, punct) -> rgb"""
        n = len(puncte)
        inele = []
        prev = None
        for k, p in enumerate(puncte):
            t_ = (puncte[min(k + 1, n - 1)] - puncte[max(k - 1, 0)]).normalized()
            if prev is None:
                ax = Vector((1, 0, 0)) if abs(t_.x) < 0.9 else Vector((0, 1, 0))
                u = t_.cross(ax).normalized()
            else:
                u = (prev - t_ * prev.dot(t_)).normalized()
            prev = u
            w = t_.cross(u).normalized()
            inel = []
            t = k / (n - 1)
            for i in range(seg):
                a = 2 * math.pi * i / seg
                q = p + (u * math.cos(a) + w * math.sin(a)) * raze[k]
                inel.append(self.v(q, culoare(t, q), 0.0, vant(t) if vant else 0.0))
            inele.append(inel)
        for k in range(n - 1):
            for i in range(seg):
                j = (i + 1) % seg
                self.f([inele[k][i], inele[k][j], inele[k + 1][j], inele[k + 1][i]])
        if capac:
            c0 = self.v(puncte[0], culoare(0.0, puncte[0]), 0.0, vant(0.0) if vant else 0.0)
            c1 = self.v(puncte[-1], culoare(1.0, puncte[-1]), 0.0, vant(1.0) if vant else 0.0)
            for i in range(seg):
                j = (i + 1) % seg
                self.f([inele[0][j], inele[0][i], c0])
                self.f([inele[-1][i], inele[-1][j], c1])
        return inele

    def cutie(self, c, dim, culoare, rot=0.0, tesit=0.02):
        """cutie cu muchii teșite (8 + fețe de teșire), culoare(punct, normala) -> rgb"""
        bm2 = bmesh.new()
        bmesh.ops.create_cube(bm2, size=1.0)
        bmesh.ops.scale(bm2, vec=Vector(dim), verts=bm2.verts)
        if tesit > 0:
            bmesh.ops.bevel(bm2, geom=list(bm2.edges), offset=tesit, segments=2, affect="EDGES", profile=0.5)
        bmesh.ops.rotate(bm2, cent=Vector((0, 0, 0)), matrix=Matrix.Rotation(rot, 3, "Z"), verts=bm2.verts)
        bmesh.ops.translate(bm2, vec=Vector(c), verts=bm2.verts)
        bm2.normal_update()
        mapv = {}
        for vv in bm2.verts:
            mapv[vv] = self.v(vv.co.copy(), culoare(vv.co, vv.normal))
        for ff in bm2.faces:
            self.f([mapv[vv] for vv in ff.verts])
        bm2.free()

    def banda(self, spina, latimi, culoare, pliu=0.0, vant=None, normala_sus=Vector((0, 0, 1))):
        """bandă curbă (frunză de palmier, fir de iarbă, petală): spina = puncte, latimi = lățimea pe puncte;
        pliu: cât se ridică marginile (frunza în „V” are volum). Trei vârfuri pe secțiune (margine, mijloc, margine)."""
        n = len(spina)
        rand = []
        for k, p in enumerate(spina):
            t_ = (spina[min(k + 1, n - 1)] - spina[max(k - 1, 0)]).normalized()
            lat = t_.cross(normala_sus)
            if lat.length < 1e-6:
                lat = Vector((1, 0, 0))
            lat.normalize()
            up = lat.cross(t_).normalized()
            t = k / (n - 1)
            w = latimi[k]
            st = self.v(p - lat * w + up * pliu * w, culoare(t, 1.0), 0.0, vant(t) if vant else 0.0)
            mj = self.v(p, culoare(t, 0.0), 0.0, vant(t) if vant else 0.0)
            dr = self.v(p + lat * w + up * pliu * w, culoare(t, 1.0), 0.0, vant(t) if vant else 0.0)
            rand.append((st, mj, dr))
        for k in range(n - 1):
            a, b = rand[k], rand[k + 1]
            self.f([a[0], a[1], b[1], b[0]])
            self.f([a[1], a[2], b[2], b[1]])

    # --- finalizare -----------------------------------------------------------------------------------------------
    def obiect(self, neted=True, unghi=50):
        bm = self.bm
        bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=1e-6)
        me = bpy.data.meshes.new(self.nume)
        uv_vals = {}
        cols = {}
        for vv in bm.verts:
            cols[vv.index] = self.col.get(vv, np.array([0.5, 0.5, 0.5]))
        bm.verts.index_update()
        lista_col = [self.col.get(vv, np.array([0.5, 0.5, 0.5])) for vv in bm.verts]
        lista_uv = [(self.emi.get(vv, 0.0), self.vnt.get(vv, 0.0)) for vv in bm.verts]
        bm.normal_update()
        bm.to_mesh(me)
        o = bpy.data.objects.new(self.nume, me)
        bpy.context.scene.collection.objects.link(o)
        a = me.color_attributes.new("Color", "FLOAT_COLOR", "POINT")
        a.data.foreach_set("color", np.concatenate([np.array(lista_col), np.ones((len(lista_col), 1))], 1).astype(np.float32).ravel())
        me.color_attributes.active_color = a
        uvl = me.uv_layers.new(name="UVMap")
        lv = np.empty(len(me.loops), np.int32)
        me.loops.foreach_get("vertex_index", lv)
        uvs = np.array(lista_uv, np.float32)[lv]
        uvs[:, 1] = 1.0 - uvs[:, 1]  # glTF/Godot întoarce V: în Godot UV.y = vântul
        uvl.data.foreach_set("uv", uvs.ravel())
        for p in me.polygons:
            p.use_smooth = neted
        if neted and unghi < 180:
            bpy.context.view_layer.objects.active = o
            o.select_set(True)
            bpy.ops.object.shade_smooth_by_angle(angle=math.radians(unghi))
            o.select_set(False)
        bm.free()
        return o


def zgomot(p, scara=3.0, seed=0.0):
    return noise.noise(Vector((p[0] * scara + seed, p[1] * scara - seed, p[2] * scara)))


def pictat(c, p, putere=0.08, scara=3.0, seed=0.0):
    """variație pictată: pete calde/reci mici, ca pe Orion"""
    n1 = zgomot(p, scara, seed)
    n2 = zgomot(p, scara * 3.1, seed + 7.3)
    k = 1.0 + putere * (n1 * 0.7 + n2 * 0.3) * 2
    return np.clip(c * k, 0, 1)


# ================================================================================================= vegetație
def palmier(seed=1):
    rng = np.random.default_rng(seed)
    P = Piesa("palmier")
    H = 3.9
    trunchi = [Vector((0.35 * (t ** 1.6), 0.08 * math.sin(t * 3), H * t)) for t in np.linspace(0, 1, 13)]
    raze = [0.17 * (1 - 0.4 * t) * (1.0 + 0.10 * (1 - abs(math.sin(t * math.pi * 7)))) for t in np.linspace(0, 1, 13)]
    raze[0] = 0.24
    BRUN, BRUN_D = lin("#9A6A43"), lin("#6E4A30")

    def c_tr(t, p):
        inel = 0.5 + 0.5 * math.sin(p.z * 9.5)
        return pictat(BRUN_D * (1 - inel) + BRUN * inel, p, 0.06)

    P.tub(trunchi, raze, c_tr, seg=8, vant=lambda t: 0.15 * t * t)
    varf = trunchi[-1]
    VERDE_D, VERDE, VERDE_L = lin("#3E8C2E"), lin("#5DB33A"), lin("#9BD54B")
    nf = 9
    for k in range(nf):
        a = 2 * math.pi * k / nf + rng.uniform(-0.15, 0.15)
        L = rng.uniform(1.6, 2.0)
        ridic = rng.uniform(0.25, 0.55)
        dirh = Vector((math.cos(a), math.sin(a), 0))
        spina = []
        for t in np.linspace(0, 1, 11):
            # arc: urcă puțin, apoi cade spre vârf
            spina.append(varf + dirh * (L * t) + Vector((0, 0, ridic * math.sin(t * math.pi * 0.8) - 0.9 * t ** 2.2)))
        lat = [0.05 + 0.26 * math.sin(min(t, 0.92) * math.pi) ** 0.8 * (1 - 0.35 * t) for t in np.linspace(0, 1, 11)]
        lat[-1] = 0.01

        def c_fr(t, e, k=k):
            base = VERDE_D * (1 - t) + VERDE * t
            base = base * (1 - ss(0.55, 1.0, t)) + VERDE_L * ss(0.55, 1.0, t)
            return np.clip(base * (0.85 + 0.25 * e) * (1 + 0.06 * math.sin(k * 2.1)), 0, 1)

        P.banda(spina, lat, c_fr, pliu=0.35, vant=lambda t: 0.3 + 0.7 * t)
    # nuci de cocos
    for k in range(3):
        a = 2 * math.pi * k / 3 + 0.4
        P.sfera(varf + Vector((math.cos(a) * 0.13, math.sin(a) * 0.13, -0.12)), 0.09,
                lambda t, p: lin("#7A5430") * (0.75 + 0.35 * t), seg=8, inele=5)
    return P


def coroana(P, centre, culori, seg=12, inele=8, seed=0, vant=0.35, flori=None):
    """o coroană din sfere netede; culori = (umbră, mijloc, lumină); flori: pete de altă culoare (pictat)"""
    jos_c, mij_c, sus_c = culori
    zmin = min(c[2] - r for c, r in centre)
    zmax = max(c[2] + r for c, r in centre)
    for k, (c, r) in enumerate(centre):
        def col(t, p, c=c, r=r):
            h = (p.z - zmin) / max(zmax - zmin, 1e-6)
            base = jos_c * (1 - ss(0.0, 0.55, h)) + mij_c * ss(0.0, 0.55, h)
            base = base * (1 - ss(0.55, 1.0, h)) + sus_c * ss(0.55, 1.0, h)
            # lumina cheie din stânga-sus-față (ca pe Orion): partea spre ea mai caldă
            dirl = Vector((-0.55, -0.35, 0.75)).normalized()
            nn = (p - Vector(c)).normalized()
            base = base * (0.86 + 0.22 * max(0.0, nn.dot(dirl)))
            if flori is not None and zgomot(p, 15.0, seed + 3) > 0.42:  # flori mici, nu pete mari
                base = flori * (0.9 + 0.2 * h)
            return pictat(base, p, 0.07, 4.0, seed)
        P.sfera(Vector(c), r, col, seg=seg, inele=inele, turtire=0.88, vant=vant, deformare=0.06, seed=seed + k)


def arbore_roz(seed=2):
    rng = np.random.default_rng(seed)
    P = Piesa("arbore_roz")
    TR = lin("#7C5A4A")

    def c_tr(t, p):
        return pictat(TR * (0.75 + 0.35 * t), p, 0.06)

    trunchi = [Vector((0.22 * math.sin(t * 2.2) * t, 0.05 * t, 1.7 * t)) for t in np.linspace(0, 1, 8)]
    P.tub(trunchi, [0.15 - 0.06 * t for t in np.linspace(0, 1, 8)], c_tr, seg=8, vant=lambda t: 0.1 * t)
    varf = trunchi[-1]
    ramuri = []
    for k in range(3):
        a = 2 * math.pi * k / 3 + 0.5
        d = Vector((math.cos(a), math.sin(a), 0))
        pts = [varf + d * (0.55 * t) + Vector((0, 0, 0.55 * t)) for t in np.linspace(0, 1, 5)]
        P.tub(pts, [0.07 - 0.03 * t for t in np.linspace(0, 1, 5)], c_tr, seg=6, vant=lambda t: 0.15 + 0.15 * t, capac=False)
        ramuri.append(pts[-1])
    centre = [((varf.x, varf.y, varf.z + 0.75), 0.75)]
    for r_ in ramuri:
        centre.append(((r_.x, r_.y, r_.z + 0.2), rng.uniform(0.55, 0.68)))
    for k in range(3):
        a = 2 * math.pi * k / 3 + 1.55
        centre.append(((varf.x + math.cos(a) * 0.55, varf.y + math.sin(a) * 0.55, varf.z + 0.95), rng.uniform(0.45, 0.55)))
    coroana(P, centre, (lin("#C9558F"), lin("#EE86B6"), lin("#FFC3DD")), seed=seed, flori=lin("#FFE3EF"))
    return P


def copac_mare(seed=3):
    rng = np.random.default_rng(seed)
    P = Piesa("copac_mare")
    TR = lin("#7A5638")

    def c_tr(t, p):
        return pictat(TR * (0.7 + 0.4 * t) * (0.9 + 0.1 * math.sin(math.atan2(p.y, p.x) * 6)), p, 0.07)

    # trunchi gros cu rădăcini evazate (raza mare jos), 4 ramuri groase
    prof = [(0.66, 0.0), (0.5, 0.1), (0.4, 0.28), (0.34, 0.6), (0.31, 1.0), (0.3, 1.4), (0.29, 1.8), (0.27, 2.1)]

    def r_ang(i, k):  # rădăcini evazate jos, scoarță ușor neregulată
        a = 2 * math.pi * i / 14
        rad = 0.22 * max(0.0, math.cos(a * 5)) ** 3 * max(0.0, 1 - k / 3)
        return 1.0 + rad + 0.05 * noise.noise(Vector((math.cos(a) * 2, math.sin(a) * 2, k * 0.7)))

    P.revolutie(prof, 14, lambda t, a, p: c_tr(t, p), capac_jos=False, capac_sus=False, raza_ang=r_ang)
    varf = Vector((0, 0, 2.1))
    ramuri = []
    for k in range(4):
        a = 2 * math.pi * k / 4 + 0.3
        d = Vector((math.cos(a), math.sin(a), 0))
        pts = [varf + d * (1.0 * t) + Vector((0, 0, 0.7 * t - 0.1 * t * t)) for t in np.linspace(0, 1, 6)]
        P.tub(pts, [0.2 - 0.1 * t for t in np.linspace(0, 1, 6)], c_tr, seg=7, vant=lambda t: 0.1 * t, capac=False)
        ramuri.append(pts[-1])
    centre = [((0, 0, 3.55), 1.15)]
    for r_ in ramuri:
        centre.append(((r_.x * 1.05, r_.y * 1.05, r_.z + 0.45), rng.uniform(0.85, 1.0)))
    for k in range(4):
        a = 2 * math.pi * k / 4 + 1.1
        centre.append(((math.cos(a) * 0.9, math.sin(a) * 0.9, 3.85), rng.uniform(0.7, 0.85)))
    coroana(P, centre, (lin("#2F7A33"), lin("#4FA43C"), lin("#9ED158")), seg=12, inele=8, seed=seed, vant=0.25)
    return P


def tufa(var=0, seed=4):
    rng = np.random.default_rng(seed + var * 11)
    P = Piesa("tufa_%d" % var)
    centre = []
    n = [4, 5, 3][var]
    for k in range(n):
        a = 2 * math.pi * k / n + rng.uniform(-0.3, 0.3)
        d = 0.0 if k == 0 else rng.uniform(0.22, 0.34)
        r = rng.uniform(0.26, 0.36) if k else 0.38
        centre.append(((math.cos(a) * d, math.sin(a) * d, r * 0.72 + (0.1 if k == 0 else 0.0)), r))
    cul = [(lin("#2F7F30"), lin("#4DA63A"), lin("#94CF55")), (lin("#356F2A"), lin("#5A9E35"), lin("#A7D15A")),
           (lin("#2E7A3A"), lin("#47A047"), lin("#88CC66"))][var]
    flori = [None, lin("#FFD45A"), lin("#FF8FC0")][var]
    coroana(P, centre, cul, seg=10, inele=7, seed=seed + var, vant=0.25, flori=flori)
    return P


def iarba_smoc(seed=5):
    rng = np.random.default_rng(seed)
    P = Piesa("iarba_smoc")
    D, M, L = lin("#3F8E2D"), lin("#6DB83A"), lin("#B4DB5A")
    for k in range(6):
        a = 2 * math.pi * k / 6 + rng.uniform(-0.3, 0.3)
        h = rng.uniform(0.2, 0.34)
        aplec = rng.uniform(0.05, 0.14)
        d = Vector((math.cos(a), math.sin(a), 0))
        baza = d * rng.uniform(0.0, 0.05)
        spina = [baza + d * (aplec * t * t) + Vector((0, 0, h * t)) for t in np.linspace(0, 1, 3)]
        lat = [0.024 * (1 - t) + 0.002 for t in np.linspace(0, 1, 3)]

        def c(t, e):
            b = D * (1 - ss(0.0, 0.6, t)) + M * ss(0.0, 0.6, t)
            return b * (1 - ss(0.6, 1.0, t)) + L * ss(0.6, 1.0, t)

        P.banda(spina, lat, c, pliu=0.25, vant=lambda t: t * t, normala_sus=Vector((-d.y, d.x, 0)).cross(d) if False else Vector((0, 0, 1)))
    return P


def floare(seed=6):
    P = Piesa("floare")
    VERDE = lin("#4C9A35")
    # tulpină
    pts = [Vector((0.01 * math.sin(t * 3), 0, 0.2 * t)) for t in np.linspace(0, 1, 3)]
    P.tub(pts, [0.008] * 3, lambda t, p: VERDE * (0.8 + 0.3 * t), seg=3, vant=lambda t: t, capac=False)
    c = pts[-1]
    # 5 petale albe (culoarea vine pe instanță, în Godot), mijloc galben
    for k in range(5):
        a = 2 * math.pi * k / 5
        d = Vector((math.cos(a), math.sin(a), 0))
        spina = [c + d * (0.075 * t) + Vector((0, 0, 0.018 * math.sin(t * math.pi))) for t in np.linspace(0, 1, 3)]
        lat = [0.012, 0.034, 0.012]
        P.banda(spina, lat, lambda t, e: np.array([1.0, 1.0, 1.0]) * (0.85 + 0.15 * t), pliu=0.2, vant=lambda t: 1.0)
    P.sfera(c + Vector((0, 0, 0.012)), 0.022, lambda t, p: lin("#FFD23F") * 0.6, seg=5, inele=3, vant=1.0)
    return P


def pietricica(seed=7):
    P = Piesa("pietricica")
    C = lin("#A79EB6")
    P.sfera(Vector((0, 0, 0.035)), 0.075, lambda t, p: pictat(C * (0.72 + 0.35 * t), p, 0.1, 18.0, seed),
            seg=9, inele=6, turtire=0.55, deformare=0.12, seed=seed)
    return P


# ================================================================================================= recuzita
LEMN, LEMN_D, LEMN_L = lin("#A0703F"), lin("#74502E"), lin("#C89A62")


def c_lemn(p, n, fibra=14.0):
    s = 0.5 + 0.5 * math.sin(p.x * fibra + zgomot(p, 2.0) * 3)
    c = LEMN_D * (1 - s) + LEMN * s
    if n.z > 0.6:
        c = c * 0.6 + LEMN_L * 0.4  # partea de sus prinde lumina
    return pictat(c, p, 0.06, 5.0)


def gard():
    P = Piesa("gard")
    L = 1.2
    for x in (0.0, L):
        P.cutie((x, 0, 0.42), (0.11, 0.11, 0.84), c_lemn, tesit=0.025)
        P.sfera(Vector((x, 0, 0.86)), 0.07, lambda t, p: LEMN * (0.8 + 0.3 * t), seg=8, inele=5)
    for z in (0.32, 0.64):
        P.cutie((L / 2, 0.0, z), (L + 0.06, 0.06, 0.1), lambda p, n: c_lemn(p, n, 10.0), tesit=0.018)
    return P


def felinar():
    P = Piesa("felinar")
    STALP = lin("#4B3A5E")
    AUR = lin("#E0A93C")

    def c_st(t, a, p):
        return pictat(STALP * (0.8 + 0.3 * t), p, 0.05)

    P.revolutie([(0.1, 0.0), (0.085, 0.08), (0.05, 0.12), (0.042, 1.15), (0.06, 1.2)], 8, c_st, capac_jos=False)
    # cutia felinarului: rame aurii, sticlă caldă care luminează (UV.x = 1)
    P.revolutie([(0.07, 1.2), (0.11, 1.24), (0.11, 1.27)], 8, lambda t, a, p: AUR * 0.9, capac_jos=True, capac_sus=False)
    P.revolutie([(0.085, 1.27), (0.1, 1.35), (0.1, 1.45), (0.085, 1.52)], 8, lambda t, a, p: lin("#FFD27A"),
                emisie=1.0, capac_jos=False, capac_sus=False)
    P.revolutie([(0.12, 1.52), (0.14, 1.55), (0.05, 1.66), (0.0, 1.70)], 8, lambda t, a, p: AUR * (0.8 + 0.3 * t),
                capac_jos=True, capac_sus=False)
    for k in range(4):  # 4 bare aurii pe colțuri
        a = 2 * math.pi * k / 4 + math.pi / 4
        x, y = math.cos(a) * 0.1, math.sin(a) * 0.1
        P.cutie((x, y, 1.395), (0.022, 0.022, 0.25), lambda p, n: AUR, tesit=0.006)
    return P


def butoi():
    P = Piesa("butoi")
    prof = [(0.25, 0.0), (0.285, 0.12), (0.305, 0.3), (0.285, 0.48), (0.25, 0.6)]

    def c(t, a, p):
        doaga = 0.5 + 0.5 * math.cos(a * 12)
        base = LEMN_D * (1 - doaga) * 0.9 + LEMN * doaga
        if abs(p.z - 0.12) < 0.035 or abs(p.z - 0.48) < 0.035:
            base = lin("#5E5A66")  # cercurile de metal
        return pictat(base, p, 0.05, 6.0)

    # mai multe inele, ca cercurile de metal să aibă margini curate
    zs = [0.0, 0.07, 0.085, 0.155, 0.17, 0.3, 0.43, 0.445, 0.515, 0.53, 0.6]
    prof2 = [(0.25 + 0.055 * math.sin(z / 0.6 * math.pi), z) for z in zs]
    P.revolutie(prof2, 16, c)
    return P


def lada():
    P = Piesa("lada")

    def c(p, n):
        scand = 0.5 + 0.5 * math.cos(p.z * 26)
        base = LEMN * (0.85 + 0.2 * scand)
        if abs(abs(p.x) - 0.25) < 0.04 or abs(abs(p.y) - 0.25) < 0.04:
            base = LEMN_D  # ramele mai închise
        return pictat(base, p, 0.06, 6.0)

    P.cutie((0, 0, 0.25), (0.5, 0.5, 0.5), c, tesit=0.03)
    return P


def cristal(var=0, seed=8):
    rng = np.random.default_rng(seed + var * 5)
    P = Piesa("cristal_%d" % var)
    cul = [(lin("#1FB4EE"), lin("#8FE6FF")), (lin("#8452F0"), lin("#CDB6FF")), (lin("#EE4FA6"), lin("#FFB3DA"))][var]
    n = [4, 3, 5][var]
    for k in range(n):
        a = 2 * math.pi * k / n + rng.uniform(-0.4, 0.4)
        incl = 0.0 if k == 0 else rng.uniform(0.25, 0.5)
        h = rng.uniform(0.45, 0.75) if k else rng.uniform(0.8, 1.0)
        r = h * 0.17
        rot = Matrix.Rotation(incl, 3, Vector((-math.sin(a), math.cos(a), 0)))
        baza = Vector((math.cos(a) * 0.12 * (k > 0), math.sin(a) * 0.12 * (k > 0), -0.05))
        P.revolutie([(r * 0.8, 0.0), (r, h * 0.12), (r, h * 0.72), (0.0, h)], 6,
                    lambda t, a_, p: cul[0] * (1 - t) + cul[1] * t, centru=baza, emisie=0.65, rot=rot, capac_sus=False)
    return P


# ================================================================================================= AO + export
def ao_coapta(o, distanta=0.6, esantioane=48):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = esantioane
    scene.render.bake.target = "VERTEX_COLORS"
    scene.world = scene.world or bpy.data.worlds.new("w")
    scene.world.light_settings.distance = distanta
    me = o.data
    col = me.color_attributes["Color"]
    vals = np.empty(len(col.data) * 4, np.float32)
    col.data.foreach_get("color", vals)
    ao_a = me.color_attributes.new("AO", "FLOAT_COLOR", "POINT")
    me.color_attributes.active_color = ao_a
    # un sol sub obiect, ca baza să se întunece (umbra de contact a piesei pe ea însăși)
    bpy.ops.mesh.primitive_plane_add(size=8, location=(0, 0, -0.002))
    sol = bpy.context.active_object
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.bake(type="AO")
    a = np.empty(len(ao_a.data) * 4, np.float32)
    ao_a.data.foreach_get("color", a)
    a = a.reshape(-1, 4)[:, 0]
    vals = vals.reshape(-1, 4)
    vals[:, 3] = np.clip(0.35 + 0.65 * a, 0, 1)
    col.data.foreach_set("color", vals.ravel())
    me.color_attributes.active_color = col
    me.color_attributes.remove(me.color_attributes["AO"])
    bpy.data.objects.remove(sol)
    return float(a.mean())


def export(o, ao=True):
    tri = sum(len(p.vertices) - 2 for p in o.data.polygons)
    a_ = ao_coapta(o) if ao else 1.0
    o.data.materials.append(bpy.data.materials.new(o.name))
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    path = os.path.join(OUT, o.name + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, use_selection=True, export_yup=True, export_vertex_color="ACTIVE",
                              export_normals=True, export_materials="PLACEHOLDER", export_texcoords=True)
    log("[%s] %d triunghiuri, AO medie %.2f -> %s" % (o.name, tri, a_, os.path.relpath(path, ROOT)))
    return tri


def main():
    os.makedirs(OUT, exist_ok=True)
    rap = {}
    piese = [(palmier, ()), (arbore_roz, ()), (copac_mare, ()), (tufa, (0,)), (tufa, (1,)), (tufa, (2,)), (iarba_smoc, ()),
             (floare, ()), (pietricica, ()), (gard, ()), (felinar, ()), (butoi, ()), (lada, ()), (cristal, (0,)),
             (cristal, (1,)), (cristal, (2,))]
    for fn, a in piese:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        P = fn(*a)
        neted = fn not in (lada, cristal)
        o = P.obiect(neted=neted, unghi=180 if fn in (palmier, arbore_roz, copac_mare, tufa, iarba_smoc, floare, pietricica) else 40)
        rap[o.name] = export(o, ao=fn not in (iarba_smoc, floare))
    log("[recuzită] triunghiuri:", rap)


if __name__ == "__main__":
    main()
