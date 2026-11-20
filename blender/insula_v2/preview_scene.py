"""
Insula 1 v2: asamblează scena în Blender (aceleași modele, poziții și date ca jocul) și o randează în Cycles,
ca previzualizare: NU e o captură din Godot. Materialele aproximează shaderele Godot.

    python preview_scene.py --out ../../docs/shots [--checker] [--marcaje] [--size 1100] [--samples 48]

Cadre: aproape (camera de joc lângă START), mediu, panoramă (ca ținta). Cu --checker: textura de verificare
pe teren și stânci (un pătrat = 25 cm; o textură de 1024 px pe 2 m = 512 px/m).
"""
import argparse
import json
import math
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy  # noqa: E402
import numpy as np  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import preview_lib as P  # noqa: E402
from common import GODOT, OUT_MODELS, TILES_JSON, log  # noqa: E402

ap = argparse.ArgumentParser()
ap.add_argument("--out", default=os.path.join(os.path.dirname(__file__), "..", "..", "docs", "shots"))
ap.add_argument("--checker", action="store_true")
ap.add_argument("--marcaje", action="store_true", help="arată inelele magenta ale placeholder-elor")
ap.add_argument("--size", type=int, default=1100)
ap.add_argument("--samples", type=int, default=48)
ap.add_argument("--frames", default="aproape,mediu,panorama")
ap.add_argument("--tag", default="")
args = ap.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:])
os.makedirs(args.out, exist_ok=True)
DATA = os.path.join(GODOT, "insula_v2", "data")


def g2b(v):
    """Godot (x, y, z) -> Blender (x, -z, y)"""
    return Vector((v[0], -v[2], v[1]))


def parse_vec3s(text):
    return [tuple(float(x) for x in m.groups()) for m in re.finditer(r"Vector3\(([-\d.e]+), ([-\d.e]+), ([-\d.e]+)\)", text)]


def gd_const(name, text):
    m = re.search(rf"const {name}[^=]*= (.*?)(?=\nconst |\n# |\Z)", text, re.S)
    return m.group(1) if m else ""


def import_glb(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    for o in new:
        o.select_set(False)
    return new


def mat_vc(name="vc", rough=0.78):
    return P.simple_material(name, (1, 1, 1), rough=rough, vertex_color=True)


def mat_emit(name, col, strength):
    return P.simple_material(name, col, rough=0.4, emit=col, strength=strength)


MATS = {}


def materials():
    MATS["vc"] = mat_vc()
    MATS["lumina"] = mat_emit("lumina", P.lin("#FFC861"), 6.0)
    MATS["cristal"] = mat_emit("cristal", P.lin("#58E6FF"), 4.0)
    MATS["marcaj"] = mat_emit("marcaj", P.lin("#FF2BD6"), 1.0)
    m = bpy.data.materials.new("vartej")
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    gr = nt.nodes.new("ShaderNodeTexGradient")
    gr.gradient_type = "SPHERICAL"
    mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Location"].default_value = (0, -0.12, -1.75)
    mp.inputs["Scale"].default_value = (1 / 0.72, 1, 1 / 1.05)
    nt.links.new(tc.outputs["Object"], mp.inputs[0])
    nt.links.new(mp.outputs[0], gr.inputs[0])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = (*P.lin("#7A3CFF"), 1)
    ramp.color_ramp.elements[1].color = (1, 1, 1, 1)
    e = ramp.color_ramp.elements.new(0.5)
    e.color = (*P.lin("#38D8FF"), 1)
    nt.links.new(gr.outputs[0], ramp.inputs[0])
    nt.links.new(ramp.outputs[0], em.inputs[0])
    em.inputs[1].default_value = 4.0
    nt.links.new(em.outputs[0], out.inputs[0])
    MATS["vartej"] = m
    MATS["teren"] = P.terrain_material(checker=args.checker)
    MATS["apa"] = water_material()
    MATS["casuta"] = tile_material()


def water_material():
    m = bpy.data.materials.new("apa")
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    b = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(b.outputs[0], out.inputs[0])
    at = nt.nodes.new("ShaderNodeAttribute")
    at.attribute_name = "apa"
    sep = nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(at.outputs["Color"], sep.inputs[0])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = (*P.lin("#66EDE0"), 1)
    ramp.color_ramp.elements[1].color = (*P.lin("#0870CC"), 1)
    ramp.color_ramp.elements[0].position = 0.05
    ramp.color_ramp.elements[1].position = 0.85
    nt.links.new(sep.outputs[0], ramp.inputs[0])
    foam = nt.nodes.new("ShaderNodeMix")
    foam.data_type = "RGBA"
    nt.links.new(sep.outputs[1], foam.inputs[0])
    nt.links.new(ramp.outputs[0], foam.inputs[6])
    foam.inputs[7].default_value = (0.95, 1.0, 1.0, 1)
    nt.links.new(foam.outputs[2], b.inputs["Base Color"])
    nt.links.new(foam.outputs[2], b.inputs["Emission Color"])
    b.inputs["Emission Strength"].default_value = 0.22
    b.inputs["Roughness"].default_value = 0.06
    nz = nt.nodes.new("ShaderNodeTexNoise")
    nz.inputs["Scale"].default_value = 3.5
    bp = nt.nodes.new("ShaderNodeBump")
    bp.inputs["Strength"].default_value = 0.25
    nt.links.new(nz.outputs[0], bp.inputs["Height"])
    nt.links.new(bp.outputs[0], b.inputs["Normal"])
    return m


def tile_material():
    m = bpy.data.materials.new("casuta")
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    b = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(b.outputs[0], out.inputs[0])
    t = nt.nodes.new("ShaderNodeTexImage")
    t.image = P.image("casuta_albedo.png")
    at = nt.nodes.new("ShaderNodeAttribute")
    at.attribute_name = "Color"
    sep = nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(at.outputs["Color"], sep.inputs[0])
    mx = nt.nodes.new("ShaderNodeMix")
    mx.data_type = "RGBA"
    nt.links.new(sep.outputs[0], mx.inputs[0])
    nt.links.new(t.outputs[0], mx.inputs[6])
    mx.inputs[7].default_value = (*P.lin("#FAC24D"), 1)
    nt.links.new(mx.outputs[2], b.inputs["Base Color"])
    nt.links.new(sep.outputs[0], b.inputs["Metallic"])
    b.inputs["Roughness"].default_value = 0.55
    nb = nt.nodes.new("ShaderNodeTexImage")
    nb.image = P.image("casuta_normal.png")
    if nb.image:
        nb.image.colorspace_settings.name = "Non-Color"
    nm = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(nb.outputs[0], nm.inputs["Color"])
    nt.links.new(nm.outputs[0], b.inputs["Normal"])
    return m


def set_material(obs, kind_fn):
    for o in obs:
        if o.type != "MESH":
            continue
        k = kind_fn(o.name)
        if k is None:
            o.hide_render = True
            continue
        o.data.materials.clear()
        o.data.materials.append(MATS[k])


def part_kind(name):
    n = name.split(".")[0]
    if n.startswith("Lumina"):
        return "lumina"
    if n.startswith("Vartej"):
        return "vartej"
    if n.startswith("Cristal"):
        return "cristal"
    if n.startswith("Marcaj"):
        return "marcaj" if args.marcaje else None
    return "vc"


# ----------------------------------------------------------------------------- water meshes (same as insula_v2.gd)
def ribbon_mesh(name, rows, attrs):
    me = bpy.data.meshes.new(name)
    verts = [v for r in rows for v in r]
    cols = len(rows[0])
    faces = []
    for i in range(len(rows) - 1):
        for j in range(cols - 1):
            k = i * cols + j
            faces.append((k, k + 1, k + cols + 1, k + cols))
    me.from_pydata(verts, [], faces)
    a = me.color_attributes.new("apa", "FLOAT_COLOR", "POINT")
    a.data.foreach_set("color", np.array(attrs, np.float32).ravel())
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    me.materials.append(MATS["apa"])
    for p in me.polygons:
        p.use_smooth = True
    return ob


def build_water(info_text, bridges):
    pts = [g2b(p) for p in parse_vec3s(gd_const("RAU_PUNCTE", info_text))]
    widths = [float(x) for x in re.findall(r"[-\d.]+", gd_const("RAU_LATIME", info_text))]
    rows, attrs = [], []
    for i, p in enumerate(pts):
        a, b = pts[max(i - 1, 0)], pts[min(i + 1, len(pts) - 1)]
        t = (b - a)
        t.z = 0
        t.normalize()
        lat = Vector((-t.y, t.x, 0))
        w = widths[min(i, len(widths) - 1)]
        foam = max([max(0.0, 1 - (Vector((p.x, p.y)) - Vector((q.x, q.y))).length / 1.3) for q in bridges] + [0.0])
        row = []
        for j in range(5):
            u = j / 4
            row.append(tuple(p + lat * (u - 0.5) * w))
            edge = abs(u * 2 - 1)
            attrs.append((1 - edge * edge, max(foam * 0.8, 1.0 if edge > 0.95 else 0.0), 0, 1))
        rows.append(row)
    ribbon_mesh("Rau", rows, attrs)
    for nm, key, lvl in (("Laguna", "LAGUNA_CONTUR", None), ):
        cont = [g2b(p) for p in parse_vec3s(gd_const(key, info_text))]
        c = sum(cont, Vector()) / len(cont)
        rows, attrs = [], []
        for f in (1.0, 0.8, 0.58, 0.36, 0.15, 0.0):
            rows.append([tuple(c.lerp(q, f)) for q in cont + [cont[0]]])
            attrs += [((1 - f) ** 0.6, 0, 0, 1)] * (len(cont) + 1)
        ribbon_mesh(nm, rows, attrs)
    pool_c = g2b(parse_vec3s(gd_const("IAZ_DEAL", info_text))[0])
    pool_r = float(re.findall(r"[\d.]+", gd_const("IAZ_DEAL_RAZA", info_text))[0])
    rows, attrs = [], []
    for f in (1.0, 0.6, 0.25, 0.0):
        rows.append([tuple(pool_c + Vector((math.cos(a), math.sin(a), 0)) * pool_r * f) for a in np.linspace(0, 2 * np.pi, 21)])
        attrs += [((1 - f) ** 0.6, 0, 0, 1)] * 21
    ribbon_mesh("IazDeal", rows, attrs)
    # waterfalls
    for m in re.finditer(r'\["(\w+)", (Vector3\([^)]*\)), (Vector3\([^)]*\)), ([\d.]+)\]', info_text):
        top = g2b(parse_vec3s(m.group(2))[0])
        bot = g2b(parse_vec3s(m.group(3))[0])
        w = float(m.group(4))
        fwd = Vector((bot.x - top.x, bot.y - top.y, 0))
        if fwd.length < 0.05:
            fwd = Vector((0, -1, 0))
        fwd.normalize()
        lat = Vector((-fwd.y, fwd.x, 0))
        rows, attrs = [], []
        pts_f = [top - fwd * 0.3 + Vector((0, 0, 0.02))]
        for i in range(17):
            s = i / 16
            pts_f.append(top.lerp(bot, s) + fwd * 0.45 * math.sin(min(s * 4, 1) * math.pi / 2))
        for i, p in enumerate(pts_f):
            ww = w * (1 + 0.35 * i / len(pts_f))
            rows.append([tuple(p + lat * (u - 0.5) * ww) for u in (0, 0.5, 1)])
            attrs += [(0.15, 0.85 if i % 3 == 0 or i <= 1 else 0.45, 0, 1)] * 3
        ribbon_mesh("Cascada_" + m.group(1), rows, attrs)


# ----------------------------------------------------------------------------- scene
def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    materials()
    obs = import_glb(os.path.join(OUT_MODELS, "teren.glb"))
    set_material(obs, lambda n: "teren")
    props_text = open(os.path.join(DATA, "props.gd")).read()
    bridges = []
    for m in re.finditer(r'"id": "(\w+)", "fisier": "(\w+)", "poz": (Vector3\([^)]*\)), "rot": ([-\d.]+), "faza": (\d)', props_text):
        pid, fis, poz, rot = m.group(1), m.group(2), g2b(parse_vec3s(m.group(3))[0]), float(m.group(4))
        if fis == "pod":
            bridges.append(poz)
        new = import_glb(os.path.join(OUT_MODELS, "props", f"{fis}.glb"))
        root = bpy.data.objects.new(pid, None)
        bpy.context.scene.collection.objects.link(root)
        for o in new:
            if o.parent is None:
                o.parent = root
        root.location = poz
        root.rotation_euler = (0, 0, math.radians(rot))
        set_material(new, part_kind)
    info_text = open(os.path.join(DATA, "teren_info.gd")).read()
    build_water(info_text, bridges)
    # small elements: linked duplicates (the game uses MultiMesh)
    veg_text = open(os.path.join(DATA, "vegetatie.gd")).read()
    n_inst = 0
    for m in re.finditer(r'"(\w+)": \[([^\]]*)\]', veg_text):
        name = m.group(1)
        vals = [float(x) for x in m.group(2).split(",") if x.strip()]
        src = import_glb(os.path.join(OUT_MODELS, "mici", f"{name}.glb"))
        set_material(src, part_kind)
        meshes = [o for o in src if o.type == "MESH"]
        for k in range(len(vals) // 5):
            x, y, z, rot, sc = vals[5 * k:5 * k + 5]
            M = Matrix.LocRotScale(g2b((x, y, z)), Matrix.Rotation(rot, 3, "Z").to_quaternion(), (sc, sc, sc))
            for o in meshes:
                d = bpy.data.objects.new(f"{name}_{k}", o.data)
                bpy.context.scene.collection.objects.link(d)
                d.matrix_world = M @ o.matrix_world
            n_inst += 1
        for o in src:
            o.hide_render = True
    # tiles
    with open(TILES_JSON) as f:
        board = json.load(f)
    src = import_glb(os.path.join(OUT_MODELS, "casuta.glb"))
    set_material(src, lambda n: "casuta")
    tmesh = [o for o in src if o.type == "MESH"][0]
    cs = board["casute"]
    for i, c in enumerate(cs):
        nx = cs[(i + 1) % len(cs)]
        rot = math.atan2(nx["x"] - c["x"], nx["z"] - c["z"])
        d = bpy.data.objects.new(f"Casuta_{i}", tmesh.data)
        bpy.context.scene.collection.objects.link(d)
        d.matrix_world = Matrix.LocRotScale(g2b((c["x"], c["y"], c["z"])), Matrix.Rotation(rot, 3, "Z").to_quaternion(), (1, 1, 1)) @ tmesh.matrix_world
    tmesh.hide_render = True
    # Orion on START
    orion = import_glb(os.path.join(GODOT, "assets", "models", "orion.glb"))
    roots = [o for o in orion if o.parent is None]
    for r in roots:
        r.location = g2b((cs[0]["x"], cs[0]["y"], cs[0]["z"]))
        r.rotation_euler = (0, 0, math.atan2(cs[1]["x"] - cs[0]["x"], cs[1]["z"] - cs[0]["z"]))
    log(f"[scena] {n_inst} instanțe mici, {len(cs)} căsuțe, {len(bridges)} poduri")


def frame(cam, cd, name):
    cd.type = "PERSP"
    cd.sensor_fit = "VERTICAL"
    cd.angle = math.radians(40)  # = Camera3D.fov (vertical) in the game
    cs = json.load(open(TILES_JSON))["casute"]
    start = g2b((cs[0]["x"], cs[0]["y"], cs[0]["z"]))
    if name == "aproape":  # the game camera: focus Orion + 0.7 m, pitch 0.85 rad, distance 16 m
        f = start + Vector((0, 0, 0.7))
        eye = f + Vector((0, -math.cos(0.85), math.sin(0.85))) * 16
        w, h = args.size * 720 // 1000, args.size
    elif name == "mediu":
        f = start.lerp(Vector((0, 0, -1.0)), 0.45) + Vector((0, 0, 0.7))
        eye = f + Vector((0, -math.cos(0.85), math.sin(0.85))) * 28
        w, h = args.size * 720 // 1000, args.size
    else:  # overview, like the target picture
        f = Vector((0.6, 0.2, -2.4))
        eye = f + Vector((0, -math.cos(0.92), math.sin(0.92))) * 47
        w, h = args.size * 1122 // 1402, args.size
    P.look_at(cam, eye, f)
    path = os.path.join(args.out, f"insula_v2_{name}{args.tag}.png")
    P.render(path, w, h, args.samples)
    log("[render]", path)


def clouds(cam):
    """cloud sea under the island (the game uses billboard sprites with the same texture)"""
    m = bpy.data.materials.new("nor")
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    b = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(b.outputs[0], out.inputs[0])
    t = nt.nodes.new("ShaderNodeTexImage")
    t.image = P.image("nor.png")
    nt.links.new(t.outputs["Color"], b.inputs["Base Color"])
    nt.links.new(t.outputs["Color"], b.inputs["Emission Color"])
    b.inputs["Emission Strength"].default_value = 0.6
    nt.links.new(t.outputs["Alpha"], b.inputs["Alpha"])
    r = np.random.default_rng(21)
    for i in range(22):
        a = r.uniform(0, 2 * math.pi)
        rad = r.uniform(9.0, 26.0)
        z = r.uniform(-13.0, -8.0)
        s_ = r.uniform(7.0, 13.0)
        bpy.ops.mesh.primitive_plane_add(size=1.0, location=(math.cos(a) * rad, math.sin(a) * rad, z))
        o = bpy.context.active_object
        o.scale = (s_ * 1.6, s_, 1)
        o.data.materials.append(m)
        c = o.constraints.new("TRACK_TO")
        c.target = cam
        c.track_axis = "TRACK_Z"
        c.up_axis = "UP_Y"
        uv = o.data.uv_layers
        if not uv:
            o.data.uv_layers.new()


def main():
    build()
    cam, cd = P.stage(sky_strength=0.9, sun_energy=3.4)
    clouds(cam)
    for fr in args.frames.split(","):
        frame(cam, cd, fr)


if __name__ == "__main__":
    main()
