"""
Previzualizări în Blender (Cycles) pentru insula 1, v3 (Faza A). Aproximează scena din Godot (insula1/insula1.gd):
clasele cu AO, nuanțarea și stratul de detaliu, apa, căsuțele noi (cu iconițe și inele), halourile felinarelor,
vârtejul portalului, insulițele cu cascade, marea de nori, Orion pe START, soarele din stânga.
NU sunt capturi din Godot: materialele de aici imită shaderele jocului, iar apa, vântul și luminile sunt statice.

    python blender/insula1/previzualizare_v3.py -- --frames aproape,captura1,captura2,mediu,panorama --out docs/shots
    python blender/insula1/previzualizare_v3.py -- --cam -0.9,0.5,11 --tag _test       (cadru liber: yaw, pitch, dist)

Cadrele urmează camera din joc (insula.gd): focus = Orion + 0,7 m, direcția (sin yaw cos pitch, sin pitch,
cos yaw cos pitch) în coordonatele Godot, FOV vertical 40°.
"""
import argparse
import json
import math
import os
import re
import sys
import time

import bpy
import numpy as np
from mathutils import Vector

T0 = time.time()
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
GODOT = os.path.join(ROOT, "godot")
TEX = os.path.join(GODOT, "insula1", "textures")
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
ap = argparse.ArgumentParser()
ap.add_argument("--frames", default="aproape,mediu,panorama")
ap.add_argument("--cam", default="", help="cadru liber: yaw,pitch,dist (ca în insula.gd)")
ap.add_argument("--size", type=int, default=1100)
ap.add_argument("--samples", type=int, default=48)
ap.add_argument("--out", default=os.path.join(ROOT, "docs", "shots"))
ap.add_argument("--tag", default="")
ap.add_argument("--prefix", default="insula_v3_A_", help="începutul numelui capturii (v4: insula_v4_)")
ap.add_argument("--fara-casute", action="store_true")
args = ap.parse_known_args(argv)[0]  # v4: previzualizare_v4.py îl importă, cu argumentele lui
os.makedirs(args.out, exist_ok=True)
TILES = json.load(open(os.path.join(ROOT, "blender", "out_insula1", "insula1_casute.json")))
INFO = open(os.path.join(GODOT, "insula1", "data", "insula1_info.gd")).read()
TIPURI = {0: "start", 4: "cufar", 8: "zar", 11: "eveniment", 15: "carte", 18: "cufar"}
CULORI = {"start": (1.0, 0.82, 0.3), "cufar": (1.0, 0.62, 0.22), "zar": (0.35, 0.9, 1.0), "eveniment": (0.78, 0.45, 1.0),
          "carte": (0.45, 1.0, 0.65)}
ICONITA = {"start": 0, "cufar": 1, "zar": 2, "eveniment": 3, "carte": 4}
# clasele: detaliu (0 fără, 1 stâncă, 2 iarbă, 3 granulație), lumină proprie
CLASE = {"Insula_restul": (3, 0.0), "Insula_stanci": (1, 0.0), "Insula_iarba": (2, 0.0), "Insula_frunzis": (2, 0.0),
         "Insula_flori": (3, 0.0), "Insula_panze": (0, 0.0), "Insula_cristale": (0, 0.55), "Insula_felinare": (0, 0.0),
         "Insula_portal": (3, 0.0), "Barca": (3, 0.0), "Moara_pale": (3, 0.0)}


def log(*a):
    print(f"[{time.time() - T0:7.1f}s]", *a, flush=True)


def lin(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


def srgb2lin(c):
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


def g2b(v):  # Godot (x, y, z) -> Blender (x, -z, y)
    return Vector((v[0], -v[2], v[1]))


def vec3s(name):
    m = re.search(name + r"[^=]*= \[(.*?)\n\]", INFO, re.S)
    return [[float(x) for x in t.split(",")] for t in re.findall(r"Vector3\(([^)]*)\)", m.group(1))] if m else []


def vec3(name):
    m = re.search(name + r" := Vector3\(([^)]*)\)", INFO)
    return [float(x) for x in m.group(1).split(",")]


def import_glb(path):
    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    return [o for o in bpy.context.scene.objects if o not in before]


def node_mat(name):
    m = bpy.data.materials.new(name)
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    b = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(b.outputs[0], out.inputs[0])
    return m, nt, b, out


def mnode(nt, op, a, b=None, clamp=False):
    n = nt.nodes.new("ShaderNodeMath")
    n.operation = op
    n.use_clamp = clamp
    for i, v in enumerate((a, b)):
        if v is None:
            continue
        if isinstance(v, (int, float)):
            n.inputs[i].default_value = v
        else:
            nt.links.new(v, n.inputs[i])
    return n.outputs[0]


def vnode(nt, op, a, b=None, scale=None):
    n = nt.nodes.new("ShaderNodeVectorMath")
    n.operation = op
    for i, v in enumerate((a, b)):
        if v is None:
            continue
        if isinstance(v, tuple):
            n.inputs[i].default_value = v
        else:
            nt.links.new(v, n.inputs[i])
    if scale is not None:
        n.inputs[3].default_value = scale
    return n.outputs[0]


def mix_rgb(nt, fac, a, b):
    mx = nt.nodes.new("ShaderNodeMix")
    mx.data_type = "RGBA"
    mx.clamp_factor = True
    for sock, v in ((mx.inputs[0], fac), (mx.inputs[6], a), (mx.inputs[7], b)):
        if isinstance(v, (tuple, int, float)):
            sock.default_value = v
        else:
            nt.links.new(v, sock)
    return mx.outputs[2]


def image(name, non_color=False):
    im = bpy.data.images.load(os.path.join(TEX, name), check_existing=True)
    if non_color:
        im.colorspace_settings.name = "Non-Color"
    return im


# ----------------------------------------------------------------------------- scena: cer, soare, contur
def stage():
    sc = bpy.context.scene
    w = bpy.data.worlds.new("Cer")
    sc.world = w
    nt = w.node_tree
    bg = nt.nodes["Background"]
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Generated"], sep.inputs[0])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    nt.links.new(sep.outputs[2], ramp.inputs[0])
    cr = ramp.color_ramp
    # ca în cer.gdshader: dedesubt alb-albăstrui (marea de nori), orizont luminos, sus albastru adânc
    cr.elements[0].position, cr.elements[0].color = 0.3, (*srgb2lin((0.86, 0.92, 1.0)), 1)
    cr.elements[1].position, cr.elements[1].color = 0.92, (*srgb2lin((0.13, 0.40, 0.88)), 1)
    e = cr.elements.new(0.52)
    e.color = (*srgb2lin((0.70, 0.86, 1.0)), 1)
    nt.links.new(ramp.outputs[0], bg.inputs[0])
    bg.inputs[1].default_value = 1.05
    sun = bpy.data.lights.new("Soare", "SUN")
    sun.energy = 4.0
    sun.angle = math.radians(3)
    sun.color = lin("#FFE7C4")
    so = bpy.data.objects.new("Soare", sun)
    sc.collection.objects.link(so)
    d = Vector((0, 0, 0)) - g2b((-14.0, 12.0, 6.0))  # ca în insula1.gd: soarele vine din stânga-sus-față
    so.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    rim = bpy.data.lights.new("Contur", "SUN")
    rim.energy = 0.6
    rim.color = lin("#7FE6FF")
    rim.use_shadow = False
    ro = bpy.data.objects.new("Contur", rim)
    sc.collection.objects.link(ro)
    ro.rotation_euler = (Vector((0, 0, 0)) - g2b((4.0, 8.0, -12.0))).to_track_quat("-Z", "Y").to_euler()
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.use_denoising = True
    sc.view_settings.view_transform = "Khronos PBR Neutral"
    cd = bpy.data.cameras.new("Cam")
    cam = bpy.data.objects.new("Cam", cd)
    sc.collection.objects.link(cam)
    sc.camera = cam
    return cam, cd


# ----------------------------------------------------------------------------- materiale
def island_material(alb, orm, detaliu, lumina):
    """insula.gdshader: gama 1.08, saturație 1.18, contrast 1.1, AO din culoarea de vârf (R), detaliu triplanar"""
    m, nt, b, out = node_mat(f"insula_{detaliu}_{lumina}")
    ta = nt.nodes.new("ShaderNodeTexImage")
    ta.image = alb
    to = nt.nodes.new("ShaderNodeTexImage")
    to.image = orm
    orm.colorspace_settings.name = "Non-Color"
    so = nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(to.outputs[0], so.inputs[0])
    g = nt.nodes.new("ShaderNodeGamma")
    g.inputs[1].default_value = 1.08
    nt.links.new(ta.outputs[0], g.inputs[0])
    hs = nt.nodes.new("ShaderNodeHueSaturation")
    hs.inputs["Saturation"].default_value = 1.18
    nt.links.new(g.outputs[0], hs.inputs["Color"])
    c = vnode(nt, "SUBTRACT", hs.outputs[0], (0.18, 0.18, 0.18))
    c = vnode(nt, "SCALE", c, scale=1.1)
    c = vnode(nt, "ADD", c, (0.18, 0.18, 0.18))
    c = vnode(nt, "MAXIMUM", c, (0.0, 0.0, 0.0))
    if detaliu:
        td = nt.nodes.new("ShaderNodeTexImage")
        td.image = image("detaliu.png", non_color=True)
        td.projection = "BOX"
        td.projection_blend = 0.3
        tc = nt.nodes.new("ShaderNodeTexCoord")
        mp = nt.nodes.new("ShaderNodeMapping")
        mp.inputs["Scale"].default_value = (1 / 1.6, 1 / 1.6, 1 / 1.6)
        nt.links.new(tc.outputs["Object"], mp.inputs[0])
        nt.links.new(mp.outputs[0], td.inputs[0])
        sd = nt.nodes.new("ShaderNodeSeparateColor")
        nt.links.new(td.outputs[0], sd.inputs[0])
        dv = sd.outputs[detaliu - 1]
        k = mnode(nt, "ADD", mnode(nt, "MULTIPLY", mnode(nt, "SUBTRACT", dv, 0.5), 2 * 0.22), 1.0)
        c = vnode(nt, "SCALE", c, scale=None)
        sc_ = nt.nodes[-1]
        nt.links.new(k, sc_.inputs[3])
    at = nt.nodes.new("ShaderNodeAttribute")
    at.attribute_name = "Color"
    sa = nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(at.outputs["Color"], sa.inputs[0])
    sm = nt.nodes.new("ShaderNodeMapRange")
    sm.interpolation_type = "SMOOTHSTEP"
    sm.inputs["From Min"].default_value = 0.0
    sm.inputs["From Max"].default_value = 0.85
    nt.links.new(sa.outputs[0], sm.inputs["Value"])
    ao = mnode(nt, "ADD", mnode(nt, "MULTIPLY", sm.outputs[0], 0.55), 0.45)
    alb_ao = vnode(nt, "SCALE", c, scale=None)
    nt.links.new(ao, nt.nodes[-1].inputs[3])
    nt.links.new(alb_ao, b.inputs["Base Color"])
    nt.links.new(so.outputs[1], b.inputs["Roughness"])
    nt.links.new(so.outputs[2], b.inputs["Metallic"])
    nt.links.new(c, b.inputs["Emission Color"])
    em = mnode(nt, "ADD", mnode(nt, "MULTIPLY", so.outputs[0], 2.4), lumina)
    nt.links.new(em, b.inputs["Emission Strength"])
    return m


def water_material():
    """water_flow.gdshader, static: râu (A=0), lac (A=0.5, R = adâncime), cascadă (A=1, dungi; R=1 se topește jos)"""
    m, nt, b, out = node_mat("apa")
    at = nt.nodes.new("ShaderNodeAttribute")
    at.attribute_name = "Color"
    sep = nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(at.outputs["Color"], sep.inputs[0])
    mode = at.outputs["Alpha"]
    uv = nt.nodes.new("ShaderNodeUVMap")
    suv = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(uv.outputs[0], suv.inputs[0])
    w_ = mnode(nt, "SUBTRACT", mnode(nt, "MULTIPLY", suv.outputs[0], 2.0), 1.0)
    d_rau = mnode(nt, "SUBTRACT", 1.0, mnode(nt, "MULTIPLY", w_, w_))
    is_lake = mnode(nt, "GREATER_THAN", mode, 0.25)
    depth = mix_rgb(nt, is_lake, d_rau, sep.outputs[0])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position, ramp.color_ramp.elements[0].color = 0.05, (*srgb2lin((0.36, 0.84, 0.82)), 1)
    ramp.color_ramp.elements[1].position, ramp.color_ramp.elements[1].color = 0.85, (*srgb2lin((0.04, 0.38, 0.60)), 1)
    nt.links.new(depth, ramp.inputs[0])
    sm = nt.nodes.new("ShaderNodeMapRange")
    sm.inputs["From Min"].default_value = 0.12
    sm.inputs["From Max"].default_value = 0.0
    sm.interpolation_type = "SMOOTHSTEP"
    nt.links.new(sep.outputs[0], sm.inputs["Value"])
    shore = mnode(nt, "MULTIPLY", is_lake, mnode(nt, "MULTIPLY", sm.outputs[0], 0.75))
    fn = nt.nodes.new("ShaderNodeTexNoise")
    fn.inputs["Scale"].default_value = 5.0
    fr = nt.nodes.new("ShaderNodeMapRange")
    fr.inputs["From Min"].default_value = 0.3
    fr.inputs["From Max"].default_value = 0.7
    fr.interpolation_type = "SMOOTHSTEP"
    nt.links.new(fn.outputs[0], fr.inputs["Value"])
    foam = mnode(nt, "MAXIMUM", mnode(nt, "MULTIPLY", sep.outputs[1], fr.outputs[0]), shore)
    c = mix_rgb(nt, foam, ramp.outputs[0], (0.92, 1.0, 1.0, 1))
    mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (2.2, 0.35, 1.0)
    nt.links.new(uv.outputs[0], mp.inputs["Vector"])
    nz = nt.nodes.new("ShaderNodeTexNoise")
    nz.inputs["Scale"].default_value = 4.0
    nt.links.new(mp.outputs[0], nz.inputs["Vector"])
    streak = nt.nodes.new("ShaderNodeMapRange")
    streak.inputs["From Min"].default_value = 0.42
    streak.inputs["From Max"].default_value = 0.62
    streak.interpolation_type = "SMOOTHSTEP"
    nt.links.new(nz.outputs[0], streak.inputs["Value"])
    fall = mix_rgb(nt, streak.outputs[0], (*srgb2lin((0.55, 0.88, 0.96)), 1), (0.95, 1.0, 1.0, 1))
    fall = mix_rgb(nt, mnode(nt, "MAXIMUM", sep.outputs[1], mnode(nt, "MULTIPLY", sep.outputs[2], 0.6)), fall, (1.0, 1.0, 1.0, 1))
    is_fall = mnode(nt, "GREATER_THAN", mode, 0.75)
    col = mix_rgb(nt, is_fall, c, fall)
    nt.links.new(col, b.inputs["Base Color"])
    nt.links.new(col, b.inputs["Emission Color"])
    b.inputs["Emission Strength"].default_value = 0.2
    rough = mix_rgb(nt, is_fall, (0.12, 0.12, 0.12, 1), (0.35, 0.35, 0.35, 1))
    nt.links.new(rough, b.inputs["Roughness"])
    wn = nt.nodes.new("ShaderNodeTexNoise")
    wn.inputs["Scale"].default_value = 2.5
    bp = nt.nodes.new("ShaderNodeBump")
    bp.inputs["Strength"].default_value = 0.18
    nt.links.new(wn.outputs[0], bp.inputs["Height"])
    nt.links.new(bp.outputs[0], b.inputs["Normal"])
    # cascadele care cad în gol se topesc spre bază (în joc: destrămare în puncte)
    fade = mnode(nt, "MULTIPLY", mnode(nt, "MULTIPLY", is_fall, mnode(nt, "GREATER_THAN", sep.outputs[0], 0.5)),
                 mnode(nt, "POWER", sep.outputs[2], 1.5))
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    ms = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(fade, ms.inputs[0])
    nt.links.new(b.outputs[0], ms.inputs[1])
    nt.links.new(tr.outputs[0], ms.inputs[2])
    nt.links.new(ms.outputs[0], out.inputs[0])
    return m


def vc_material():
    m, nt, b, out = node_mat("culori_varf")
    a = nt.nodes.new("ShaderNodeAttribute")
    a.attribute_name = "Color"
    nt.links.new(a.outputs["Color"], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.85
    return m


def emit_material(name, col, strength, alpha=None):
    m, nt, b, out = node_mat(name)
    b.inputs["Base Color"].default_value = (*col, 1)
    b.inputs["Emission Color"].default_value = (*col, 1)
    b.inputs["Emission Strength"].default_value = strength
    return m


def sprite_material(name, tex, strength=0.6):
    m, nt, b, out = node_mat(name)
    t = nt.nodes.new("ShaderNodeTexImage")
    t.image = image(tex)
    nt.links.new(t.outputs["Color"], b.inputs["Base Color"])
    nt.links.new(t.outputs["Color"], b.inputs["Emission Color"])
    b.inputs["Emission Strength"].default_value = strength
    nt.links.new(t.outputs["Alpha"], b.inputs["Alpha"])
    return m


def billboard(mat, loc, sx, sy, cam):
    bpy.ops.mesh.primitive_plane_add(size=1.0, location=loc)
    o = bpy.context.active_object
    o.scale = (sx, sy, 1)
    o.data.materials.append(mat)
    c = o.constraints.new("TRACK_TO")
    c.target = cam
    c.track_axis = "TRACK_Z"
    c.up_axis = "UP_Y"
    o.visible_shadow = False
    return o


# ----------------------------------------------------------------------------- scena
def build(cam, flacari=None):
    obs = import_glb(os.path.join(GODOT, "assets", "models", "insula1", "insula1.glb"))
    wm = water_material()
    alb = orm = None
    for o in obs:
        if o.type == "MESH" and not o.name.startswith(("Apa", "Cascade")):
            imgs = [n.image for n in o.data.materials[0].node_tree.nodes if n.type == "TEX_IMAGE"]
            alb = next(i for i in imgs if "albedo" in i.name)
            orm = next(i for i in imgs if "orm" in i.name)
            break
    cache = {}
    for o in obs:
        if o.type != "MESH":
            continue
        if o.name.startswith(("Apa", "Cascade")):
            o.data.materials.clear()
            o.data.materials.append(wm)
            o.visible_shadow = False
            continue
        key = next((k for k in CLASE if o.name.startswith(k)), "Insula_restul")
        d, l_ = CLASE[key]
        if (d, l_) not in cache:
            cache[(d, l_)] = island_material(alb, orm, d, l_)
        o.data.materials.clear()
        o.data.materials.append(cache[(d, l_)])
    # vârtejul din portal (static)
    c, n = vec3("PORTAL_CENTRU"), vec3("PORTAL_NORMALA")
    s = [float(x) for x in re.search(r"PORTAL_MARIME := Vector2\(([^)]*)\)", INFO).group(1).split(",")]
    cb, nb = g2b(c), g2b(n).normalized()
    bpy.ops.mesh.primitive_plane_add(size=1.0, location=cb + nb * 0.04)
    q = bpy.context.active_object
    q.scale = (s[0], s[1], 1)
    q.rotation_euler = nb.to_track_quat("Z", "Y").to_euler()
    m, nt, b, out = node_mat("portal")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Location"].default_value = (-1.0, -1.0, 0)
    mp.inputs["Scale"].default_value = (2.0, 2.0, 1.0)
    nt.links.new(tc.outputs["UV"], mp.inputs["Vector"])
    gr = nt.nodes.new("ShaderNodeTexGradient")
    gr.gradient_type = "SPHERICAL"
    nt.links.new(mp.outputs[0], gr.inputs["Vector"])
    wv = nt.nodes.new("ShaderNodeTexWave")
    wv.wave_type = "RINGS"
    wv.inputs["Scale"].default_value = 3.0
    wv.inputs["Distortion"].default_value = 6.0
    nt.links.new(mp.outputs[0], wv.inputs["Vector"])
    col = mix_rgb(nt, wv.outputs["Fac"], (*srgb2lin((0.30, 0.55, 1.0)), 1), (*srgb2lin((0.45, 0.95, 1.0)), 1))
    col = mix_rgb(nt, mnode(nt, "POWER", gr.outputs["Fac"], 3.0), col, (1.0, 1.0, 1.0, 1))
    nt.links.new(col, b.inputs["Emission Color"])
    nt.links.new(col, b.inputs["Base Color"])
    b.inputs["Emission Strength"].default_value = 3.0
    mk = nt.nodes.new("ShaderNodeMapRange")
    mk.inputs["From Min"].default_value = 0.0
    mk.inputs["From Max"].default_value = 0.28
    mk.interpolation_type = "SMOOTHSTEP"
    nt.links.new(gr.outputs["Fac"], mk.inputs["Value"])
    nt.links.new(mk.outputs[0], b.inputs["Alpha"])
    q.data.materials.append(m)
    q.visible_shadow = False
    # halourile felinarelor (puncte calde)
    hm = emit_material("halou", srgb2lin((1.0, 0.70, 0.32)), 6.0)
    for p in (vec3s("FLACARI") if flacari is None else flacari):
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.07, segments=10, ring_count=6, location=g2b(p) + Vector((0, 0, 0.05)))
        h = bpy.context.active_object
        h.data.materials.append(hm)
        h.visible_shadow = False
    # ceață la baza cascadelor
    mist = sprite_material("ceata", "nor.png", 0.9)
    for mm in re.finditer(r"\[Vector3\(([^)]*)\), Vector3\(([^)]*)\), ([\d.]+)\]", INFO):
        baza = g2b([float(x) for x in mm.group(2).split(",")])
        w_ = float(mm.group(3))
        k = 2.4 if baza.z < -4.0 else 1.0
        billboard(mist, baza + Vector((0, 0, 0.5 if k > 1 else 0.25)), w_ * 1.3 * k, w_ * 0.9 * k, cam)
    # căsuțele noi (Casuta.tscn): piatră, chenar auriu, iconiță și inel la cele speciale
    if not args.fara_casute:
        tm, tnt, tb, _ = node_mat("casuta")
        ti = tnt.nodes.new("ShaderNodeTexImage")
        ti.image = image("casuta_albedo.png")
        at = tnt.nodes.new("ShaderNodeAttribute")
        at.attribute_name = "Color"
        sp = tnt.nodes.new("ShaderNodeSeparateColor")
        tnt.links.new(at.outputs["Color"], sp.inputs[0])
        stone = vnode(tnt, "SCALE", ti.outputs[0], scale=None)
        tnt.links.new(sp.outputs[1], tnt.nodes[-1].inputs[3])
        cc = mix_rgb(tnt, sp.outputs[0], stone, (*srgb2lin((0.98, 0.76, 0.30)), 1))
        tnt.links.new(cc, tb.inputs["Base Color"])
        tnt.links.new(sp.outputs[0], tb.inputs["Metallic"])
        tb.inputs["Roughness"].default_value = 0.88  # v4: piatră mată (casuta.gdshader)
        tn = tnt.nodes.new("ShaderNodeTexImage")
        tn.image = image("casuta_normal.png", non_color=True)
        nm_ = tnt.nodes.new("ShaderNodeNormalMap")
        nm_.inputs["Strength"].default_value = 1.7  # adâncimea gravurii din casuta.gdshader
        tnt.links.new(tn.outputs["Color"], nm_.inputs["Color"])
        tnt.links.new(nm_.outputs["Normal"], tb.inputs["Normal"])
        cs = TILES["casute"]
        n_ = len(cs)
        atlas = image("iconite_casute.png")
        for i, t in enumerate(cs):
            pos = g2b((t["x"], t["y"], t["z"])) + Vector((0, 0, 0.04))
            nxt = cs[(i + 1) % n_]
            yaw = math.atan2(nxt["x"] - t["x"], nxt["z"] - t["z"])
            for o in import_glb(os.path.join(GODOT, "assets", "models", "casuta", "casuta.glb")):
                if o.parent is None:
                    o.location = pos
                    o.rotation_euler = (o.rotation_euler[0], o.rotation_euler[1], yaw)
                    o.scale = (1.1, 1.1, 1.1)
                if o.type == "MESH":
                    o.data.materials.clear()
                    o.data.materials.append(tm)
            tip = TIPURI.get(i)
            if tip:
                col = srgb2lin(CULORI[tip])
                bpy.ops.mesh.primitive_torus_add(major_radius=0.865 * 1.1, minor_radius=0.055 * 1.1, major_segments=48,
                                                 minor_segments=6, location=pos + Vector((0, 0, -0.044)))
                ring = bpy.context.active_object
                ring.data.materials.append(emit_material("inel_" + tip, col, 2.4))
                ring.visible_shadow = False
                bpy.ops.mesh.primitive_plane_add(size=0.98 * 1.1, location=pos + Vector((0, 0, 0.016)))
                ic = bpy.context.active_object
                ic.rotation_euler = (0, 0, yaw)
                im_, int_, ib, _ = node_mat("iconita_" + tip)
                tcc = int_.nodes.new("ShaderNodeTexCoord")
                mpp = int_.nodes.new("ShaderNodeMapping")
                mpp.inputs["Scale"].default_value = (0.2, 1.0, 1.0)
                mpp.inputs["Location"].default_value = (0.2 * ICONITA[tip], 0.0, 0.0)
                int_.links.new(tcc.outputs["UV"], mpp.inputs[0])
                tx = int_.nodes.new("ShaderNodeTexImage")
                tx.image = atlas
                int_.links.new(mpp.outputs[0], tx.inputs[0])
                int_.links.new(tx.outputs["Color"], ib.inputs["Base Color"])
                int_.links.new(tx.outputs["Color"], ib.inputs["Emission Color"])
                ib.inputs["Emission Strength"].default_value = 0.22
                int_.links.new(tx.outputs["Alpha"], ib.inputs["Alpha"])
                ic.data.materials.append(im_)
                ic.visible_shadow = False
    # insulițele cu cascade (pozițiile din insula1.gd)
    vc = vc_material()
    for p, nm, sc_, rot in [((-34.0, 3.0, -30.0), "a", 1.3, 0.4), ((38.0, -2.0, -26.0), "c", 1.2, 2.1),
                            ((-26.0, -6.0, -52.0), "b", 1.8, 4.0), ((30.0, 7.0, -58.0), "a", 2.0, 1.2),
                            ((-44.0, 1.0, 6.0), "c", 1.3, 5.2)]:
        for o in import_glb(os.path.join(GODOT, "assets", "models", "fundal", f"insulita_cascada_{nm}.glb")):
            if o.parent is None:
                o.location = g2b(p)
                o.scale = (sc_, sc_, sc_)
                o.rotation_euler = (o.rotation_euler[0], o.rotation_euler[1], rot)
            if o.type == "MESH":
                o.data.materials.clear()
                o.data.materials.append(wm if o.name.startswith("Cascada") else vc)
                o.visible_shadow = False
    # Orion pe START
    cs = TILES["casute"]
    start = g2b((cs[0]["x"], cs[0]["y"], cs[0]["z"]))
    for o in import_glb(os.path.join(GODOT, "assets", "models", "orion.glb")):
        if o.parent is None:
            o.location = start + o.location + Vector((0, 0, 0.04))
    log("[scena] gata")


def clouds(cam):
    m = sprite_material("nor", "nor.png", 0.6)
    r = np.random.default_rng(21)
    for i in range(22):
        a = r.uniform(0, 2 * math.pi)
        rad = r.uniform(10.0, 28.0)
        z = r.uniform(-14.0, -9.0)
        s_ = r.uniform(7.0, 13.0)
        billboard(m, (math.cos(a) * rad, math.sin(a) * rad, z), s_ * 1.6, s_, cam)


def yaw_drum(i=0, n=6):
    """ca în insula.gd: camera în spatele lui Orion, privind spre mijlocul următoarelor n căsuțe"""
    cs = TILES["casute"]
    m = np.mean([[cs[(i + j) % len(cs)]["x"], cs[(i + j) % len(cs)]["z"]] for j in range(1, n + 1)], 0)
    d = m - np.array([cs[i]["x"], cs[i]["z"]])
    d /= np.linalg.norm(d)
    return math.atan2(-d[0], -d[1])


def frame(cam, cd, name, yaw, pitch, dist, focus=None, wh=None, inainte=0.0):
    cd.type = "PERSP"
    cd.sensor_fit = "VERTICAL"
    cd.angle = math.radians(40)
    cs = TILES["casute"]
    if yaw == "drum":
        yaw = yaw_drum()
    start = (cs[0]["x"] - math.sin(yaw) * inainte, cs[0]["y"] + 0.7, cs[0]["z"] - math.cos(yaw) * inainte)
    f = g2b(focus or start)
    d = g2b((math.sin(yaw) * math.cos(pitch), math.sin(pitch), math.cos(yaw) * math.cos(pitch)))
    eye = f + d * dist
    cam.location = eye
    cam.rotation_euler = (f - eye).to_track_quat("-Z", "Y").to_euler()
    w, h = wh or (args.size * 720 // 1000, args.size)
    sc = bpy.context.scene
    sc.render.resolution_x, sc.render.resolution_y = w, h
    sc.cycles.samples = args.samples
    sc.render.filepath = os.path.join(args.out, f"{args.prefix}{name}{args.tag}.png")
    bpy.ops.render.render(write_still=True)
    log("[render]", sc.render.filepath)


# cadrele: aproape = camera de joc implicită; captura1/2 = unghiurile din capturile tale (estimate după mărimea
# lui Orion și ce se vede în ele); mediu; panorama (ca imaginea-țintă)
SQ = None


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    cam, cd = stage()
    build(cam)
    clouds(cam)
    sq = (args.size * 953 // 1000, args.size)  # capturile tale: fereastra jocului din editor, aproape pătrată
    cadre = {"aproape": (0.0, 0.85, 16.0, None, None), "captura1": (0.0, 0.30, 13.5, None, sq),
             "captura2": (1.25, 0.38, 8.5, None, sq),
             "mediu": (0.0, 0.85, 28.0, None, None),
             "panorama": (0.0, 0.92, 47.0, (0.6, -2.4, -0.2), (args.size * 1122 // 1402, args.size)),
             # v4 (D4): camera de joc veche și cea nouă (în spatele lui Orion pe drum, ~50°, privește 3 m înainte),
             # cadrul apropiat de la aterizare; format portret, ca pe telefon
             "joc_vechi": (0.0, 0.85, 16.0, None, None), "joc_nou": ("drum", 0.87, 16.0, None, None),
             "aterizare": ("drum", 0.55, 6.0, None, None)}
    inainte = {"joc_nou": 3.0}
    if args.cam:
        y_, p_, d_ = [float(v) for v in args.cam.split(",")]
        frame(cam, cd, "cadru", y_, p_, d_, wh=sq)
    for fr in [f for f in args.frames.split(",") if f and not args.cam]:
        y_, p_, d_, foc, wh = cadre[fr]
        if fr == "mediu":
            cs = TILES["casute"]
            s0 = Vector((cs[0]["x"], cs[0]["y"] + 0.7, cs[0]["z"]))
            foc = tuple(s0.lerp(Vector((0.0, -1.0 + 0.7, 0.0)), 0.45))
        frame(cam, cd, fr, y_, p_, d_, foc, wh, inainte.get(fr, 0.0))


if __name__ == "__main__":
    main()
