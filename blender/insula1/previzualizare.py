"""
Previzualizări în Blender (Cycles) pentru insula 1: „vechi” (insula pregătită inițial, blender/out_insula1/insula1.glb)
și „nou” (insula îmbunătățită, godot/assets/models/insula1/insula1.glb + apa, portalul, insulițele, norii).
Aceeași lumină și aceleași cadre ca în joc, ca să se poată compara direct.
NU sunt capturi din Godot: materialele de aici aproximează shaderele jocului (apa e statică, fără animație).

    python blender/insula1/previzualizare.py -- --model nou --frames aproape,mediu,panorama --out docs/shots

Cadre: aproape (camera de joc lângă START: Orion + 0,7 m, înclinare 0,85 rad, 16 m, FOV vertical 40°),
mediu (28 m), panorama (ca imaginea-țintă).
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
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
ap = argparse.ArgumentParser()
ap.add_argument("--model", choices=["nou", "vechi"], default="nou")
ap.add_argument("--frames", default="aproape,mediu,panorama")
ap.add_argument("--size", type=int, default=1100)
ap.add_argument("--samples", type=int, default=48)
ap.add_argument("--out", default=os.path.join(ROOT, "docs", "shots"))
ap.add_argument("--aterizare", action="store_true", help="arată efectul de aterizare pe START (la 35% din animație)")
ap.add_argument("--tag", default="")
args = ap.parse_args(argv)
os.makedirs(args.out, exist_ok=True)
GODOT = os.path.join(ROOT, "godot")
TILES = json.load(open(os.path.join(ROOT, "blender", "out_insula1", "insula1_casute.json")))
TEX = os.path.join(GODOT, "insula1", "textures")


def log(*a):
    print(f"[{time.time() - T0:7.1f}s]", *a, flush=True)


def lin(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


def g2b(v):  # Godot / glTF (x, y, z) -> Blender (x, -z, y)
    return Vector((v[0], -v[2], v[1]))


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
    return m, nt, b


def math_node(nt, op, a, b=None, clamp=False):
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


def mix_rgb(nt, fac, a, b):
    mx = nt.nodes.new("ShaderNodeMix")
    mx.data_type = "RGBA"
    mx.clamp_factor = True
    for sock, v in ((mx.inputs[0], fac), (mx.inputs[6], a), (mx.inputs[7], b)):
        if isinstance(v, tuple):
            sock.default_value = v
        elif isinstance(v, (int, float)):
            sock.default_value = v
        else:
            nt.links.new(v, sock)
    return mx.outputs[2]


# ----------------------------------------------------------------------------- scenă: cer, soare, contur cyan
def stage():
    sc = bpy.context.scene
    w = bpy.data.worlds.new("Sky")
    sc.world = w
    nt = w.node_tree
    bg = nt.nodes["Background"]
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Generated"], sep.inputs[0])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    nt.links.new(sep.outputs[2], ramp.inputs[0])
    cr = ramp.color_ramp
    cr.elements[0].position, cr.elements[0].color = 0.25, (*lin("#8CCBFF"), 1)
    cr.elements[1].position, cr.elements[1].color = 0.85, (*lin("#2A78E0"), 1)
    e = cr.elements.new(0.5)
    e.color = (*lin("#BFE3FF"), 1)
    nt.links.new(ramp.outputs[0], bg.inputs[0])
    bg.inputs[1].default_value = 0.9
    sun = bpy.data.lights.new("Sun", "SUN")
    sun.energy = 3.4
    sun.angle = math.radians(4)
    sun.color = lin("#FFE9C8")
    so = bpy.data.objects.new("Sun", sun)
    sc.collection.objects.link(so)
    so.rotation_euler = (math.radians(48), 0, math.radians(-38))
    rim = bpy.data.lights.new("Rim", "SUN")
    rim.energy = 0.6
    rim.color = lin("#7FE6FF")
    rim.use_shadow = False
    ro = bpy.data.objects.new("Rim", rim)
    sc.collection.objects.link(ro)
    ro.rotation_euler = (math.radians(70), 0, math.radians(160))
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.use_denoising = True
    sc.view_settings.view_transform = "Khronos PBR Neutral"
    cd = bpy.data.cameras.new("Cam")
    cam = bpy.data.objects.new("Cam", cd)
    sc.collection.objects.link(cam)
    sc.camera = cam
    return cam, cd


# ----------------------------------------------------------------------------- materiale (aproximează shaderele din Godot)
def island_material(albedo, orm):
    """insula.gdshader: albedo, ORM (R lumină, G rugozitate, B metal), lumina = albedo x R x 2.4"""
    m, nt, b = node_mat("insula_preview")
    ta = nt.nodes.new("ShaderNodeTexImage")
    ta.image = albedo
    to = nt.nodes.new("ShaderNodeTexImage")
    to.image = orm
    orm.colorspace_settings.name = "Non-Color"
    sep = nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(to.outputs[0], sep.inputs[0])
    nt.links.new(ta.outputs[0], b.inputs["Base Color"])
    nt.links.new(sep.outputs[1], b.inputs["Roughness"])
    nt.links.new(sep.outputs[2], b.inputs["Metallic"])
    nt.links.new(ta.outputs[0], b.inputs["Emission Color"])
    nt.links.new(math_node(nt, "MULTIPLY", sep.outputs[0], 2.4), b.inputs["Emission Strength"])
    return m


def water_material():
    """water_flow.gdshader, static: râu (A=0, adâncimea din UV.x), lac (A=0.5, adâncimea din R), cascadă (A=1, dungi)"""
    m, nt, b = node_mat("apa_preview")
    at = nt.nodes.new("ShaderNodeAttribute")
    at.attribute_name = "Color"  # COLOR_0 din glTF
    sep = nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(at.outputs["Color"], sep.inputs[0])
    mode = at.outputs["Alpha"]
    uv = nt.nodes.new("ShaderNodeUVMap")
    suv = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(uv.outputs[0], suv.inputs[0])
    # adâncimea râului: 1 - (2u - 1)^2
    w_ = math_node(nt, "SUBTRACT", math_node(nt, "MULTIPLY", suv.outputs[0], 2.0), 1.0)
    d_rau = math_node(nt, "SUBTRACT", 1.0, math_node(nt, "MULTIPLY", w_, w_))
    is_lake = math_node(nt, "GREATER_THAN", mode, 0.25)
    depth = mix_rgb(nt, is_lake, d_rau, sep.outputs[0])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position, ramp.color_ramp.elements[0].color = 0.05, (*lin("#5CD1CC"), 1)
    ramp.color_ramp.elements[1].position, ramp.color_ramp.elements[1].color = 0.85, (*lin("#0D6694"), 1)
    nt.links.new(depth, ramp.inputs[0])
    # spumă: sub poduri (G), la mal pe lacuri (ca în shader: smoothstep(0.12, 0.0, adâncime) * 0.75)
    sm = nt.nodes.new("ShaderNodeMapRange")
    sm.inputs["From Min"].default_value = 0.12
    sm.inputs["From Max"].default_value = 0.0
    sm.interpolation_type = "SMOOTHSTEP"
    nt.links.new(sep.outputs[0], sm.inputs["Value"])
    shore = math_node(nt, "MULTIPLY", is_lake, math_node(nt, "MULTIPLY", sm.outputs[0], 0.75))
    fn = nt.nodes.new("ShaderNodeTexNoise")  # ca în shader: spuma de la poduri e pătată de zgomot
    fn.inputs["Scale"].default_value = 5.0
    fr = nt.nodes.new("ShaderNodeMapRange")
    fr.inputs["From Min"].default_value = 0.3
    fr.inputs["From Max"].default_value = 0.7
    fr.interpolation_type = "SMOOTHSTEP"
    nt.links.new(fn.outputs[0], fr.inputs["Value"])
    foam = math_node(nt, "MAXIMUM", math_node(nt, "MULTIPLY", sep.outputs[1], fr.outputs[0]), shore)
    c = mix_rgb(nt, foam, ramp.outputs[0], (0.92, 1.0, 1.0, 1))
    # cascadă: dungi întinse pe verticală (UV.y = metri de la buză)
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
    fall = mix_rgb(nt, streak.outputs[0], (*lin("#8CE0F2"), 1), (0.95, 1.0, 1.0, 1))
    fall = mix_rgb(nt, math_node(nt, "MAXIMUM", sep.outputs[1], sep.outputs[2]), fall, (1.0, 1.0, 1.0, 1))
    is_fall = math_node(nt, "GREATER_THAN", mode, 0.75)
    col = mix_rgb(nt, is_fall, c, fall)
    nt.links.new(col, b.inputs["Base Color"])
    nt.links.new(col, b.inputs["Emission Color"])
    b.inputs["Emission Strength"].default_value = 0.22
    rough = mix_rgb(nt, is_fall, (0.06, 0.06, 0.06, 1), (0.35, 0.35, 0.35, 1))
    nt.links.new(rough, b.inputs["Roughness"])
    wn = nt.nodes.new("ShaderNodeTexNoise")
    wn.inputs["Scale"].default_value = 3.5
    bp = nt.nodes.new("ShaderNodeBump")
    bp.inputs["Strength"].default_value = 0.25
    nt.links.new(wn.outputs[0], bp.inputs["Height"])
    nt.links.new(bp.outputs[0], b.inputs["Normal"])
    return m


def vc_material():
    m, nt, b = node_mat("culori_varf")
    a = nt.nodes.new("ShaderNodeAttribute")
    a.attribute_name = "Color"
    nt.links.new(a.outputs["Color"], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.8
    return m


def sprite_material(name, tex, strength=0.6):
    m, nt, b = node_mat(name)
    t = nt.nodes.new("ShaderNodeTexImage")
    t.image = bpy.data.images.load(os.path.join(TEX, tex), check_existing=True)
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
def build(cam):
    info = open(os.path.join(GODOT, "insula1", "data", "insula1_info.gd")).read() if args.model == "nou" else ""
    if args.model == "vechi":
        obs = import_glb(os.path.join(ROOT, "blender", "out_insula1", "insula1.glb"))
        for o in obs:
            if o.type == "MESH":
                for m in o.data.materials:
                    bsdf = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
                    if bsdf:
                        bsdf.inputs["Emission Strength"].default_value = 2.0  # GLOW_ISLAND din jocul vechi
    else:
        obs = import_glb(os.path.join(GODOT, "assets", "models", "insula1", "insula1.glb"))
        wm = water_material()
        for o in obs:
            if o.type != "MESH":
                continue
            if o.name.startswith(("Apa", "Cascade")):
                o.data.materials.clear()
                o.data.materials.append(wm)
                o.visible_shadow = False
            else:
                src = o.data.materials[0]
                imgs = [n.image for n in src.node_tree.nodes if n.type == "TEX_IMAGE"]
                alb = next(i for i in imgs if "albedo" in i.name)
                orm = next(i for i in imgs if "orm" in i.name)
                o.data.materials.clear()
                o.data.materials.append(island_material(alb, orm))
        # vârtejul din portal (static): spirală cyan-violet, margine moale
        c = re.search(r"PORTAL_CENTRU := Vector3\(([^)]*)\)", info).group(1)
        n = re.search(r"PORTAL_NORMALA := Vector3\(([^)]*)\)", info).group(1)
        s = re.search(r"PORTAL_MARIME := Vector2\(([^)]*)\)", info).group(1)
        c, n, s = [float(x) for x in c.split(",")], [float(x) for x in n.split(",")], [float(x) for x in s.split(",")]
        cb, nb = g2b(c), g2b(n).normalized()
        bpy.ops.mesh.primitive_plane_add(size=1.0, location=cb + nb * 0.04)
        q = bpy.context.active_object
        q.scale = (s[0], s[1], 1)
        q.rotation_euler = nb.to_track_quat("Z", "Y").to_euler()
        m, nt, b = node_mat("portal_preview")
        tc = nt.nodes.new("ShaderNodeTexCoord")
        mp = nt.nodes.new("ShaderNodeMapping")
        mp.inputs["Location"].default_value = (-0.5, -0.5, 0)
        nt.links.new(tc.outputs["UV"], mp.inputs["Vector"])
        gr = nt.nodes.new("ShaderNodeTexGradient")
        gr.gradient_type = "SPHERICAL"
        mp2 = nt.nodes.new("ShaderNodeMapping")
        mp2.inputs["Scale"].default_value = (2.0, 2.0, 1.0)
        nt.links.new(mp.outputs[0], mp2.inputs["Vector"])
        nt.links.new(mp2.outputs[0], gr.inputs["Vector"])
        wv = nt.nodes.new("ShaderNodeTexWave")
        wv.wave_type = "RINGS"
        wv.inputs["Scale"].default_value = 3.0
        wv.inputs["Distortion"].default_value = 6.0
        nt.links.new(mp2.outputs[0], wv.inputs["Vector"])
        col = mix_rgb(nt, wv.outputs["Fac"], (*lin("#9E6BFF"), 1), (*lin("#80EBFF"), 1))
        col = mix_rgb(nt, math_node(nt, "POWER", gr.outputs["Fac"], 3.0), col, (1.0, 1.0, 1.0, 1))
        nt.links.new(col, b.inputs["Emission Color"])
        nt.links.new(col, b.inputs["Base Color"])
        b.inputs["Emission Strength"].default_value = 3.0
        mask = nt.nodes.new("ShaderNodeMapRange")
        mask.inputs["From Min"].default_value = 0.0
        mask.inputs["From Max"].default_value = 0.28
        mask.interpolation_type = "SMOOTHSTEP"
        nt.links.new(gr.outputs["Fac"], mask.inputs["Value"])
        nt.links.new(mask.outputs[0], b.inputs["Alpha"])
        q.data.materials.append(m)
        q.visible_shadow = False
        # ceață la baza cascadelor
        mist = sprite_material("ceata", "nor.png", 0.9)
        for m_ in re.finditer(r"\[Vector3\(([^)]*)\), Vector3\(([^)]*)\), ([\d.]+)\]", info):
            baza = g2b([float(x) for x in m_.group(2).split(",")])
            w_ = float(m_.group(3))
            k = 2.2 if baza.z < -4.0 else 1.0
            billboard(mist, baza + Vector((0, 0, 0.3)), w_ * 1.2 * k, w_ * 0.8 * k, cam)
        # insulițe în fundal (pozițiile din insula1.gd, Godot -> Blender)
        vc = vc_material()
        for p, nm, sc_ in [((-34.0, 3.0, -30.0), "insulita_a", 1.6), ((38.0, -2.0, -26.0), "insulita_c", 1.4),
                           ((-26.0, -6.0, -52.0), "insulita_b", 2.2), ((30.0, 7.0, -58.0), "insulita_a", 2.4),
                           ((-44.0, 1.0, 6.0), "insulita_b", 1.5)]:
            for o in import_glb(os.path.join(GODOT, "assets", "models", "fundal", nm + ".glb")):
                if o.parent is None:
                    o.location = g2b(p)
                    o.scale = (sc_, sc_, sc_)
                if o.type == "MESH":
                    o.data.materials.clear()
                    o.data.materials.append(vc)
    # Orion pe START
    cs = TILES["casute"]
    start = g2b((cs[0]["x"], cs[0]["y"], cs[0]["z"]))
    for o in import_glb(os.path.join(GODOT, "assets", "models", "orion.glb")):
        if o.parent is None:
            o.location = start + o.location
            if len(cs) > 1:
                d = g2b((cs[1]["x"], cs[1]["y"], cs[1]["z"])) - start
                o.rotation_euler = (o.rotation_euler[0], o.rotation_euler[1], math.atan2(d.y, d.x) + math.pi / 2)
    if args.aterizare:
        r = TILES["raza_casuta"]
        bpy.ops.mesh.primitive_plane_add(size=2 * r / 0.42, location=start + Vector((0, 0, 0.1)))
        q = bpy.context.active_object
        m, nt, b = node_mat("aterizare")
        tc = nt.nodes.new("ShaderNodeTexCoord")
        mp = nt.nodes.new("ShaderNodeMapping")  # Mapping scalează întâi, apoi adună: 2 * uv - 1
        mp.inputs["Location"].default_value = (-1.0, -1.0, 0)
        mp.inputs["Scale"].default_value = (2.0, 2.0, 1.0)
        nt.links.new(tc.outputs["UV"], mp.inputs["Vector"])
        ln = nt.nodes.new("ShaderNodeVectorMath")
        ln.operation = "LENGTH"
        nt.links.new(mp.outputs[0], ln.inputs[0])
        pr = 0.35
        rr = ln.outputs["Value"]
        ring = math_node(nt, "MULTIPLY", math_node(nt, "SUBTRACT", 1.0, math_node(nt, "MULTIPLY", math_node(
            nt, "ABSOLUTE", math_node(nt, "SUBTRACT", rr, 0.42 + (0.96 - 0.42) * pr)), 1 / 0.07), clamp=True), 1 - pr)
        disc = math_node(nt, "MULTIPLY", math_node(nt, "LESS_THAN", rr, 0.4), (1 - pr) ** 2 * 0.45)
        a = math_node(nt, "ADD", ring, disc, clamp=True)
        b.inputs["Base Color"].default_value = (*lin("#FFDB80"), 1)
        b.inputs["Emission Color"].default_value = (*lin("#FFDB80"), 1)
        b.inputs["Emission Strength"].default_value = 3.0
        nt.links.new(a, b.inputs["Alpha"])
        q.data.materials.append(m)
        q.visible_shadow = False
    log(f"[scena] {args.model}: {len(obs)} obiecte")


def clouds(cam):
    m = sprite_material("nor", "nor.png", 0.6)
    r = np.random.default_rng(21)
    for i in range(22):
        a = r.uniform(0, 2 * math.pi)
        rad = r.uniform(10.0, 26.0)
        z = r.uniform(-14.0, -9.0)
        s_ = r.uniform(7.0, 13.0)
        billboard(m, (math.cos(a) * rad, math.sin(a) * rad, z), s_ * 1.6, s_, cam)


def frame(cam, cd, name):
    cd.type = "PERSP"
    cd.sensor_fit = "VERTICAL"
    cd.angle = math.radians(40)  # = Camera3D.fov (vertical) în joc
    cs = TILES["casute"]
    start = g2b((cs[0]["x"], cs[0]["y"], cs[0]["z"]))
    if name == "aproape":
        f = start + Vector((0, 0, 0.7))
        eye = f + Vector((0, -math.cos(0.85), math.sin(0.85))) * 16
        w, h = args.size * 720 // 1000, args.size
    elif name == "mediu":
        f = start.lerp(Vector((0, 0, -1.0)), 0.45) + Vector((0, 0, 0.7))
        eye = f + Vector((0, -math.cos(0.85), math.sin(0.85))) * 28
        w, h = args.size * 720 // 1000, args.size
    else:
        f = Vector((0.6, 0.2, -2.4))
        eye = f + Vector((0, -math.cos(0.92), math.sin(0.92))) * 47
        w, h = args.size * 1122 // 1402, args.size
    cam.location = eye
    cam.rotation_euler = (f - eye).to_track_quat("-Z", "Y").to_euler()
    sc = bpy.context.scene
    sc.render.resolution_x, sc.render.resolution_y = w, h
    sc.cycles.samples = args.samples
    sc.render.filepath = os.path.join(args.out, f"insula1_{args.model}_{name}{args.tag}.png")
    bpy.ops.render.render(write_still=True)
    log("[render]", sc.render.filepath)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    cam, cd = stage()
    build(cam)
    clouds(cam)
    for fr in [f for f in args.frames.split(",") if f]:
        frame(cam, cd, fr)


if __name__ == "__main__":
    main()
