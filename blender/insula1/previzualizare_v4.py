"""
Previzualizări în Blender (Cycles) pentru insula 1, v4: insula veche tăiată (clădirile, apa, falezele) + Inelul 1
nou (terenul cu texturi de 512 px/m pe triplanar, recuzita, iarba, florile și pietricelele presărate), căsuțele,
insulițele, Orion pe START. Refolosește previzualizare_v3.py (cer, soare, apă, clase, portal, căsuțe, insulițe).
NU sunt capturi din Godot: materialele imită shaderele jocului, iar apa, vântul și luminile sunt statice.

    python blender/insula1/previzualizare_v4.py -- --frames joc,aproape,captura1,panorama [--checker] [--out docs/shots]

Cadrele: joc = camera de joc nouă (D4) pe START, portret; aproape = ca a doua captură a ta; captura1 = ca prima;
panorama. Cu --checker, terenul nou arată tabla de verificare (un pătrat = 25 cm = 128 px, deci 512 px/m),
iar insula veche tabla ei în UV (32 px pe pătrat), ca să se vadă diferența de densitate.
"""
import math
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import previzualizare_v3 as v3  # noqa: E402

import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ap = v3.argparse.ArgumentParser()
ap.add_argument("--frames", default="joc,aproape,panorama")
ap.add_argument("--size", type=int, default=1100)
ap.add_argument("--samples", type=int, default=40)
ap.add_argument("--out", default=os.path.join(v3.ROOT, "docs", "shots"))
ap.add_argument("--tag", default="")
ap.add_argument("--prefix", default="insula_v4_")
ap.add_argument("--checker", action="store_true")
ap.add_argument("--fara-inel1", action="store_true", help="doar insula veche (pentru „înainte”)")
A = ap.parse_args(argv)
v3.args.samples = A.samples
v3.args.size = A.size
v3.args.out = A.out
v3.args.tag = A.tag
v3.args.prefix = A.prefix
GODOT = v3.GODOT
TEX_T = os.path.join(GODOT, "insula1", "textures", "teren")
DATA = open(os.path.join(GODOT, "insula1", "data", "inel1.gd")).read()
lin, g2b, node_mat, mnode, vnode, mix_rgb = v3.lin, v3.g2b, v3.node_mat, v3.mnode, v3.vnode, v3.mix_rgb


def bloc(nume):
    m = re.search(r"const " + nume + r"[^=]*= \[(.*?)\n\]", DATA, re.S)
    return m.group(1) if m else ""


def vecs(text):
    return [[float(x) for x in t.split(",")] for t in re.findall(r"Vector3\(([^)]*)\)", text)]


def randuri(nume):
    """[[Vector3, numere...], ...] din liniile unui bloc"""
    out = []
    for line in bloc(nume).strip().split("\n"):
        line = line.strip().rstrip(",")
        if not line:
            continue
        vv = vecs(line)
        rest = re.sub(r"Vector3\([^)]*\)", "", line).strip("[] ")
        nums = [float(x) for x in re.findall(r"-?\d+\.\d+|-?\d+", rest)]
        tip = re.findall(r'"([^"]+)"', line)
        out.append((tip[0] if tip else None, vv, nums))
    return out


def numere(nume):
    return [float(x) for x in re.findall(r"-?\d+\.\d+", bloc(nume))]


def img(nume, non_color=False):
    im = bpy.data.images.load(os.path.join(TEX_T, nume), check_existing=True)
    if non_color:
        im.colorspace_settings.name = "Non-Color"
    return im


def tex_box(nt, im, coord, scara=0.5):
    mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (scara, scara, scara)
    nt.links.new(coord, mp.inputs[0])
    t = nt.nodes.new("ShaderNodeTexImage")
    t.image = im
    t.projection = "BOX"
    t.projection_blend = 0.25
    nt.links.new(mp.outputs[0], t.inputs[0])
    return t.outputs[0]


def teren_material(checker):
    """teren.gdshader: iarbă / mușchi / pământ / pavaj din măștile de pe vârfuri, stâncă pe abrupt, AO, pete mari"""
    m, nt, b, out = node_mat("teren")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    co = tc.outputs["Object"]  # terenul stă în origine: coordonatele obiectului sunt ale lumii
    vc = nt.nodes.new("ShaderNodeVertexColor")
    vc.layer_name = "Color"
    sep = nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(vc.outputs["Color"], sep.inputs[0])
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    sn = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(geo.outputs["Normal"], sn.inputs[0])

    def sm(x, a, b_):
        r = nt.nodes.new("ShaderNodeMapRange")
        r.interpolation_type = "SMOOTHSTEP"
        r.inputs["From Min"].default_value = a
        r.inputs["From Max"].default_value = b_
        nt.links.new(x, r.inputs["Value"])
        return r.outputs[0]

    abrupt = sm(sn.outputs[2], 0.78, 0.56)
    pavaj = mnode(nt, "MULTIPLY", sm(sep.outputs[1], 0.3, 0.7), mnode(nt, "SUBTRACT", 1.0, abrupt))
    pamant = mnode(nt, "MULTIPLY", sm(sep.outputs[2], 0.3, 0.7), mnode(nt, "SUBTRACT", 1.0, abrupt))
    muschi = mnode(nt, "MINIMUM", mnode(nt, "ADD", vc.outputs["Alpha"],
                                         mnode(nt, "MULTIPLY", sm(sn.outputs[2], 0.95, 0.8), 0.6)), 1.0)
    if checker:
        c = tex_box(nt, img("checker_1024.png"), co)
    else:
        ia = tex_box(nt, img("iarba_albedo.png"), co)
        # pete mari calde/reci (zgomot în lume, ca în shader)
        nz = nt.nodes.new("ShaderNodeTexNoise")
        nz.inputs["Scale"].default_value = 0.11
        nt.links.new(co, nz.inputs["Vector"])
        cald = sm(nz.outputs[0], 0.45, 0.7)
        ia = mix_rgb(nt, mnode(nt, "MULTIPLY", cald, 0.32), ia, vnode(nt, "MULTIPLY", ia, (1.16, 1.08, 0.72)))
        c = mix_rgb(nt, mnode(nt, "MULTIPLY", muschi, 0.75), ia, tex_box(nt, img("muschi_albedo.png"), co, 0.65))
        c = mix_rgb(nt, pamant, c, tex_box(nt, img("pamant_albedo.png"), co))
        c = mix_rgb(nt, pavaj, c, tex_box(nt, img("piatra_albedo.png"), co))
        c = mix_rgb(nt, abrupt, c, tex_box(nt, img("stanca_albedo.png"), co))
    c = vnode(nt, "SCALE", c, scale=None)
    nt.links.new(sep.outputs[0], nt.nodes[-1].inputs[3])
    nt.links.new(c, b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.92
    b.inputs["Specular IOR Level"].default_value = 0.25
    if not checker:
        tn = nt.nodes.new("ShaderNodeTexImage")
        tn.image = img("piatra_normal.png", True)
        tn.projection = "BOX"
        mp = nt.nodes.new("ShaderNodeMapping")
        mp.inputs["Scale"].default_value = (0.5, 0.5, 0.5)
        nt.links.new(co, mp.inputs[0])
        nt.links.new(mp.outputs[0], tn.inputs[0])
        nm = nt.nodes.new("ShaderNodeNormalMap")
        nt.links.new(tn.outputs[0], nm.inputs["Color"])
        nt.links.new(pavaj, nm.inputs["Strength"])
        nt.links.new(nm.outputs[0], b.inputs["Normal"])
    return m


def recuzita_material():
    m, nt, b, out = node_mat("recuzita")
    vc = nt.nodes.new("ShaderNodeVertexColor")
    vc.layer_name = "Color"
    oi = nt.nodes.new("ShaderNodeObjectInfo")
    c = vnode(nt, "MULTIPLY", vc.outputs["Color"], oi.outputs["Color"])
    alb = vnode(nt, "SCALE", c, scale=None)
    nt.links.new(vc.outputs["Alpha"], nt.nodes[-1].inputs[3])
    nt.links.new(alb, b.inputs["Base Color"])
    uv = nt.nodes.new("ShaderNodeUVMap")
    sx = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(uv.outputs[0], sx.inputs[0])
    nt.links.new(c, b.inputs["Emission Color"])
    nt.links.new(mnode(nt, "MULTIPLY", sx.outputs[0], 2.4), b.inputs["Emission Strength"])
    b.inputs["Roughness"].default_value = 0.8
    return m


def inel1(checker):
    obs = v3.import_glb(os.path.join(GODOT, "assets", "models", "insula1", "teren.glb"))
    mt = teren_material(checker)
    for o in obs:
        if o.type == "MESH":
            o.data.materials.clear()
            o.data.materials.append(mt)
    mr = recuzita_material()
    plase = {}

    def plasa(nume):
        if nume not in plase:
            for o in v3.import_glb(os.path.join(GODOT, "assets", "models", "inel1", nume + ".glb")):
                if o.type == "MESH":
                    o.data.materials.clear()
                    o.data.materials.append(mr)
                    plase[nume] = o.data
                bpy.data.objects.remove(o)
        return plase[nume]

    def pune(nume, poz, rot=0.0, scara=(1.0, 1.0, 1.0), culoare=None, umbra=True):
        o = bpy.data.objects.new(nume, plasa(nume))
        bpy.context.scene.collection.objects.link(o)
        o.location = g2b(poz)
        o.rotation_euler = (0, 0, rot)
        o.scale = scara
        if culoare is not None:
            o.color = (*culoare, 1.0)
        o.visible_shadow = umbra
        return o

    for tip, vv, nums in randuri("COPACI"):
        pune(tip, vv[0], nums[0], (nums[1],) * 3)
    for _, vv, nums in randuri("TUFE"):
        pune("tufa_%d" % int(nums[2]), vv[0], nums[0], (nums[1],) * 3)
    for p in vecs(bloc("FELINARE")):
        pune("felinar", p)
    for _, vv, nums in randuri("CRISTALE"):
        pune("cristal_%d" % int(nums[2]), vv[0], nums[0], (nums[1],) * 3)
    for nume, bl in (("butoi", "BUTOAIE"), ("lada", "LAZI")):
        for _, vv, nums in randuri(bl):
            pune(nume, vv[0], nums[0], (nums[1],) * 3)
    for _, vv, nums in randuri("GARDURI"):
        a, b_ = vv
        d = (b_[0] - a[0], b_[2] - a[2])
        L = math.hypot(*d)
        pune("gard", (a[0], min(a[1], b_[1]), a[2]), math.atan2(-d[1], d[0]), (L / 1.2, 1, 1))
    culori = [(1.0, 0.54, 0.76), (1.0, 0.85, 0.3), (1, 1, 1), (0.78, 0.61, 1.0), (1.0, 0.48, 0.36), (0.56, 0.83, 1.0)]
    for nume, bl, col in (("iarba_smoc", "IARBA", None), ("floare", "FLORI", culori), ("pietricica", "PIETRICELE", None)):
        nn = numere(bl)
        for k in range(0, len(nn) - 4, 5):
            cc = None
            if col is not None:
                cc = tuple(v3.srgb2lin(col[(k // 5) % len(col)]))
            pune(nume, nn[k:k + 3], nn[k + 3], (nn[k + 4],) * 3, cc, umbra=False)
    v3.log("[inel1] teren + recuzită: %d obiecte" % len(bpy.context.scene.objects))


def flacari():
    out = vecs(bloc("FLACARI_RAMASE"))
    for p in vecs(bloc("FELINARE")):
        out.append([p[0], p[1] + 1.36, p[2]])
    return out


def checker_insula():
    """insula veche: tabla de șah în UV (128 x 128 pătrate pe textura de 4096 px = 32 px pe pătrat), ca mod_debug 1"""
    m, nt, b, out = node_mat("checker_uv")
    ch = nt.nodes.new("ShaderNodeTexChecker")
    ch.inputs["Scale"].default_value = 128.0
    ch.inputs["Color1"].default_value = (*v3.srgb2lin((0.95, 0.55, 0.1)), 1)
    ch.inputs["Color2"].default_value = (*v3.srgb2lin((0.15, 0.45, 0.9)), 1)
    uv = nt.nodes.new("ShaderNodeUVMap")
    nt.links.new(uv.outputs[0], ch.inputs["Vector"])
    nt.links.new(ch.outputs["Color"], b.inputs["Base Color"])
    for o in bpy.context.scene.objects:
        if o.type == "MESH" and o.name.startswith(("Insula_", "Barca", "Moara")):
            o.data.materials.clear()
            o.data.materials.append(m)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    cam, cd = v3.stage()
    v3.build(cam, flacari=None if A.fara_inel1 else flacari())
    if not A.fara_inel1:
        inel1(A.checker)
    if A.checker:
        checker_insula()
    v3.clouds(cam)
    sq = (A.size * 953 // 1000, A.size)
    cadre = {"joc": ("drum", 0.87, 16.0, None, None, 3.0), "aproape": (1.25, 0.38, 8.5, None, sq, 0.0),
             "captura1": (0.0, 0.30, 13.5, None, sq, 0.0), "aterizare": ("drum", 0.55, 6.0, None, None, 0.0),
             "panorama": (0.0, 0.92, 47.0, (0.6, -2.4, -0.2), (A.size * 1122 // 1402, A.size), 0.0)}
    for fr in [f for f in A.frames.split(",") if f]:
        y_, p_, d_, foc, wh, ina = cadre[fr]
        v3.frame(cam, cd, fr + ("_checker" if A.checker else ""), y_, p_, d_, foc, wh, ina)


if __name__ == "__main__":
    main()
