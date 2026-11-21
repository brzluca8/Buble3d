"""
Foaia de verificare a recuzitei noi (Inelul 1, v4): toate piesele una lângă alta, randare Cycles cu materialul
care imită recuzita.gdshader (culoarea și AO de pe vârfuri, sticla care luminează din UV.x). Orion la scară.

    python blender/insula1/previzualizare_recuzita.py -- [--out docs/shots/insula_v4_recuzita.png]
NU e captură din Godot.
"""
import math
import os
import sys

import bpy
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
out = argv[argv.index("--out") + 1] if "--out" in argv else os.path.join(ROOT, "docs", "shots", "insula_v4_recuzita.png")
D = os.path.join(ROOT, "godot", "assets", "models", "inel1")


def mat_recuzita():
    m = bpy.data.materials.new("recuzita")
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    ca = nt.nodes.new("ShaderNodeVertexColor")
    ca.layer_name = "Color"
    sep = nt.nodes.new("ShaderNodeSeparateColor")
    mul = nt.nodes.new("ShaderNodeMix")
    mul.data_type = "RGBA"
    mul.blend_type = "MULTIPLY"
    mul.inputs[0].default_value = 1.0
    nt.links.new(ca.outputs["Color"], mul.inputs[6])
    nt.links.new(ca.outputs["Alpha"], sep.inputs[0]) if False else None
    ao = nt.nodes.new("ShaderNodeCombineColor")
    nt.links.new(ca.outputs["Alpha"], ao.inputs[0])
    nt.links.new(ca.outputs["Alpha"], ao.inputs[1])
    nt.links.new(ca.outputs["Alpha"], ao.inputs[2])
    nt.links.new(ao.outputs[0], mul.inputs[7])
    nt.links.new(mul.outputs[2], b.inputs["Base Color"])
    uv = nt.nodes.new("ShaderNodeUVMap")
    sx = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(uv.outputs[0], sx.inputs[0])
    em = nt.nodes.new("ShaderNodeMath")
    em.operation = "MULTIPLY"
    em.inputs[1].default_value = 3.0
    nt.links.new(sx.outputs[0], em.inputs[0])
    nt.links.new(ca.outputs["Color"], b.inputs["Emission Color"])
    nt.links.new(em.outputs[0], b.inputs["Emission Strength"])
    b.inputs["Roughness"].default_value = 0.8
    return m


bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
m = mat_recuzita()
piese = ["copac_mare", "arbore_roz", "palmier", "tufa_0", "tufa_1", "tufa_2", "felinar", "gard", "butoi", "lada",
         "cristal_0", "cristal_1", "cristal_2", "iarba_smoc", "floare", "pietricica"]
x = 0.0
lat = {"copac_mare": 4.4, "arbore_roz": 3.2, "palmier": 3.6, "tufa_0": 1.2, "tufa_1": 1.2, "tufa_2": 1.0, "felinar": 0.7,
       "gard": 1.6, "butoi": 0.8, "lada": 0.8, "cristal_0": 0.7, "cristal_1": 0.7, "cristal_2": 0.8, "iarba_smoc": 0.5,
       "floare": 0.4, "pietricica": 0.4}
for p in piese:
    x += lat[p] / 2
    bpy.ops.import_scene.gltf(filepath=os.path.join(D, p + ".glb"))
    for o in bpy.context.selected_objects:
        if o.type == "MESH":
            o.location.x += x - (0.6 if p == "gard" else 0)
            o.data.materials.clear()
            o.data.materials.append(m)
    x += lat[p] / 2 + 0.25
bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, "godot", "assets", "models", "orion.glb"))
for o in bpy.context.selected_objects:
    if o.parent is None:
        o.location = Vector((x + 0.5, 0, 0))
x += 1.2
bpy.ops.mesh.primitive_plane_add(size=80, location=(x / 2, 0, 0))
sol = bpy.context.active_object
ms = bpy.data.materials.new("sol")
ms.use_nodes = True
ms.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.42, 0.62, 0.28, 1)
sol.data.materials.append(ms)
w = bpy.data.worlds.new("w")
sc.world = w
w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.75, 1.0, 1)
w.node_tree.nodes["Background"].inputs[1].default_value = 0.8
bpy.ops.object.light_add(type="SUN", rotation=(math.radians(48), 0, math.radians(-35)))
bpy.context.object.data.energy = 3.2
bpy.context.object.data.color = (1.0, 0.92, 0.8)
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
sc.collection.objects.link(cam)
cam.data.type = "ORTHO"
cam.data.ortho_scale = x * 1.02
cam.location = (x / 2, -20, 2.75)
cam.rotation_euler = (math.radians(90), 0, 0)
sc.camera = cam
sc.render.engine = "CYCLES"
sc.cycles.samples = 48
sc.render.resolution_x, sc.render.resolution_y = 2400, int(2400 * 5.6 / x)
sc.view_settings.view_transform = "AgX"
sc.render.filepath = out
bpy.ops.render.render(write_still=True)
print("ok", out)
