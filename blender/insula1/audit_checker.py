"""
Captură de audit: tablă de șah în spațiul UV pe insulă și pe Orion, cu pătrate de 32 px din textura proprie a fiecărui
model. Pătrate mari = puțini pixeli pe metru; pătrate alungite = textură întinsă. Randare Blender (Cycles), nu Godot.

    python blender/insula1/audit_checker.py -- --out docs/shots/insula_v3_audit_checker.png
"""
import json
import math
import os
import sys

import bpy
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = argv[argv.index("--out") + 1] if "--out" in argv else os.path.join(ROOT, "docs", "shots", "insula_v3_audit_checker.png")


def checker_mat(name, squares_u, squares_v, c1, c2):
    m = bpy.data.materials.new(name)
    nt = m.node_tree
    nt.nodes.clear()
    o = nt.nodes.new("ShaderNodeOutputMaterial")
    e = nt.nodes.new("ShaderNodeEmission")
    nt.links.new(e.outputs[0], o.inputs[0])
    uv = nt.nodes.new("ShaderNodeUVMap")
    mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (squares_u / 2.0, squares_v / 2.0, 1.0)  # Checker Texture: 2 pătrate pe unitate
    nt.links.new(uv.outputs[0], mp.inputs[0])
    ck = nt.nodes.new("ShaderNodeTexChecker")
    ck.inputs["Scale"].default_value = 2.0
    ck.inputs["Color1"].default_value = c1
    ck.inputs["Color2"].default_value = c2
    nt.links.new(mp.outputs[0], ck.inputs["Vector"])
    nt.links.new(ck.outputs["Color"], e.inputs[0])
    return m


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    before = set(sc.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, "godot", "assets", "models", "insula1", "insula1.glb"))
    isl = [o for o in sc.objects if o not in before]
    for o in isl:
        if o.type == "MESH":
            if o.name.startswith(("Apa", "Cascade")):
                o.hide_render = True
                continue
            o.data.materials.clear()
            o.data.materials.append(checker_mat("ck_insula", 4096 / 32, 4096 / 32, (0.95, 0.55, 0.1, 1), (0.15, 0.45, 0.9, 1)))
    cs = json.load(open(os.path.join(ROOT, "blender", "out_insula1", "insula1_casute.json")))["casute"]
    start = Vector((cs[0]["x"], -cs[0]["z"], cs[0]["y"]))
    before = set(sc.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, "godot", "assets", "models", "orion.glb"))
    for o in [o for o in sc.objects if o not in before]:
        if o.parent is None:
            o.location = start + o.location
        if o.type == "MESH":
            mats = []
            for m in o.data.materials:
                eyes = "Eyes" in m.name
                w, h = (1024, 512) if eyes else (2048, 2048)
                mats.append(checker_mat("ck_" + m.name, w / 32, h / 32, (0.95, 0.95, 0.95, 1), (0.85, 0.1, 0.5, 1)))
            for i, m in enumerate(mats):
                o.data.materials[i] = m
    w = bpy.data.worlds.new("w")
    sc.world = w
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.8, 0.85, 0.95, 1)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.sensor_fit = "VERTICAL"
    cam.data.angle = math.radians(40)
    f = start + Vector((0, 0, 0.7))
    eye = f + Vector((0, -math.cos(0.6), math.sin(0.6))) * 9
    cam.location = eye
    cam.rotation_euler = (f - eye).to_track_quat("-Z", "Y").to_euler()
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 16
    sc.cycles.device = "CPU"
    sc.view_settings.view_transform = "Standard"
    sc.render.resolution_x, sc.render.resolution_y = 900, 1000
    sc.render.filepath = OUT
    bpy.ops.render.render(write_still=True)
    print("saved", OUT)


if __name__ == "__main__":
    main()
