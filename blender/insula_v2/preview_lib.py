"""Blender preview helpers for island v2: stage, approximate Godot materials (triplanar textures), cameras.
These renders are previews of the assets in Blender (Cycles), not captures from Godot."""
import math
import os

import numpy as np

from common import GODOT, OUT_TEX

TEX = OUT_TEX


def lin(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


def stage(sky_strength=1.0, sun_energy=3.2):
    """sky gradient + warm key sun from upper-left-front + soft cyan rim, like Orion's renders"""
    import bpy
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
    # world "Generated" = view direction: z < 0 below the horizon (sea of sky under the island), z = 1 zenith
    cr.elements[0].position, cr.elements[0].color = 0.25, (*lin("#8CCBFF"), 1)
    cr.elements[1].position, cr.elements[1].color = 0.85, (*lin("#2A78E0"), 1)
    e = cr.elements.new(0.5)
    e.color = (*lin("#BFE3FF"), 1)
    nt.links.new(ramp.outputs[0], bg.inputs[0])
    bg.inputs[1].default_value = sky_strength
    sun = bpy.data.lights.new("Sun", "SUN")
    sun.energy = sun_energy
    sun.angle = math.radians(4)
    sun.color = lin("#FFE9C8")
    so = bpy.data.objects.new("Sun", sun)
    sc.collection.objects.link(so)
    # from upper-left-front: light travels towards +x, +y, -z
    so.rotation_euler = (math.radians(48), 0, math.radians(-38))
    rim = bpy.data.lights.new("Rim", "SUN")
    rim.energy = 0.6
    rim.color = lin("#7FE6FF")
    ro = bpy.data.objects.new("Rim", rim)
    sc.collection.objects.link(ro)
    ro.rotation_euler = (math.radians(70), 0, math.radians(160))
    rim.use_shadow = False
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.use_denoising = True
    sc.view_settings.view_transform = "Khronos PBR Neutral"  # keeps saturation (closer to the game's ACES + saturation)
    cd = bpy.data.cameras.new("Cam")
    cam = bpy.data.objects.new("Cam", cd)
    sc.collection.objects.link(cam)
    sc.camera = cam
    return cam, cd


def image(name):
    import bpy
    p = os.path.join(TEX, name)
    if not os.path.exists(p):
        return None
    im = bpy.data.images.load(p, check_existing=True)
    return im


def tri_tex(nt, name, scale, non_color=False):
    """box-projected (triplanar) image texture in object space at `scale` metres per tile"""
    tc = nt.nodes.new("ShaderNodeTexCoord")
    mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (1 / scale, 1 / scale, 1 / scale)
    nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
    t = nt.nodes.new("ShaderNodeTexImage")
    t.image = image(name)
    t.projection = "BOX"
    t.projection_blend = 0.25
    if non_color and t.image:
        t.image.colorspace_settings.name = "Non-Color"
    nt.links.new(mp.outputs[0], t.inputs[0])
    return t


def terrain_material(checker=False):
    """approximates teren_triplanar.gdshader: grass on flat, rock on steep, moss in between, cobble (G), sand (B), AO (R)"""
    import bpy
    m = bpy.data.materials.new("TerenPreview")
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    b = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(b.outputs[0], out.inputs[0])
    b.inputs["Roughness"].default_value = 0.85
    if checker:
        t = tri_tex(nt, "checker_1024.png", 2.0)
        nt.links.new(t.outputs[0], b.inputs["Base Color"])
        return m
    attr = nt.nodes.new("ShaderNodeAttribute")
    attr.attribute_name = "Color"  # glTF COLOR_0 imports as "Color"
    sepc = nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(attr.outputs["Color"], sepc.inputs[0])
    alpha = attr.outputs["Alpha"]  # A = moss mask
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    sepn = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(geo.outputs["Normal"], sepn.inputs[0])

    def mr(a, b_, fac):
        mx = nt.nodes.new("ShaderNodeMix")
        mx.data_type = "RGBA"
        mx.clamp_factor = True
        nt.links.new(fac, mx.inputs[0])
        nt.links.new(a, mx.inputs[6])
        nt.links.new(b_, mx.inputs[7])
        return mx.outputs[2]

    def rng(src, a, b_):
        r = nt.nodes.new("ShaderNodeMapRange")
        r.inputs["From Min"].default_value = a
        r.inputs["From Max"].default_value = b_
        r.interpolation_type = "SMOOTHSTEP"
        nt.links.new(src, r.inputs["Value"])
        return r.outputs[0]

    grass = tri_tex(nt, "iarba_albedo.png", 2.0).outputs[0]
    rock = tri_tex(nt, "stanca_albedo.png", 2.0).outputs[0]
    moss = tri_tex(nt, "muschi_albedo.png", 2.0).outputs[0]
    cobble = tri_tex(nt, "piatra_albedo.png", 2.0).outputs[0]
    sand = tri_tex(nt, "nisip_albedo.png", 2.0).outputs[0]
    steep = rng(sepn.outputs[2], 0.78, 0.55)  # 1 on steep slopes
    mossy = rng(sepn.outputs[2], 0.9, 0.7)
    c = mr(grass, moss, mossy)
    c = mr(c, cobble, rng(sepc.outputs[1], 0.35, 0.65))
    c = mr(c, sand, rng(sepc.outputs[2], 0.3, 0.7))
    c = mr(c, rock, steep)
    c = mr(c, moss, alpha)  # moss mask (A) -- on walls near the top
    ao = nt.nodes.new("ShaderNodeMix")
    ao.data_type = "RGBA"
    ao.blend_type = "MULTIPLY"
    ao.inputs[0].default_value = 1.0
    nt.links.new(c, ao.inputs[6])
    gamma = nt.nodes.new("ShaderNodeMath")
    gamma.operation = "POWER"
    gamma.inputs[1].default_value = 1.0
    nt.links.new(sepc.outputs[0], gamma.inputs[0])
    comb = nt.nodes.new("ShaderNodeCombineColor")
    for i in range(3):
        nt.links.new(gamma.outputs[0], comb.inputs[i])
    nt.links.new(comb.outputs[0], ao.inputs[7])
    nt.links.new(ao.outputs[2], b.inputs["Base Color"])
    return m


def simple_material(name, color, rough=0.6, metal=0.0, emit=None, strength=0.0, vertex_color=False):
    import bpy
    m = bpy.data.materials.new(name)
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    b = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(b.outputs[0], out.inputs[0])
    if vertex_color:
        a = nt.nodes.new("ShaderNodeAttribute")
        a.attribute_name = "Color"
        nt.links.new(a.outputs["Color"], b.inputs["Base Color"])
    else:
        b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if emit is not None:
        b.inputs["Emission Color"].default_value = (*emit, 1)
        b.inputs["Emission Strength"].default_value = strength
    return m


def look_at(cam, eye, target):
    from mathutils import Vector
    cam.location = Vector(eye)
    cam.rotation_euler = (Vector(target) - Vector(eye)).to_track_quat("-Z", "Y").to_euler()


def render(path, w, h, samples=32):
    import bpy
    sc = bpy.context.scene
    sc.render.resolution_x, sc.render.resolution_y = w, h
    sc.cycles.samples = samples
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    return path
