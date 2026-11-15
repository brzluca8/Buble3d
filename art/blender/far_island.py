"""Prerandează o insulă îndepărtată (PNG cu fundal transparent) din modelele jocului.

Rulare:
    blender -b --factory-startup --python art/blender/far_island.py -- godot/models godot/art3d/far_island.png

Folosește insula, magazinul și turnul, micșorate, văzute din același unghi ca jocul (~40°).
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bk  # noqa: E402
import bpy  # noqa: E402

A = bk.args()
MODELS = A[0] if A else "godot/models"
OUT = A[1] if len(A) > 1 else "far_island.png"

bk.reset_scene()


def imp(name, loc, scale):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(MODELS, name + ".glb"))
    new = [o for o in bpy.data.objects if o not in before and o.parent is None]
    for o in new:
        o.location = loc
        o.scale = (scale, scale, scale)


imp("insula", (0, 0, 0), 1.0)
imp("mag", (-1.6, 0.8, 0), 1.25)
imp("turn", (1.8, 1.4, 0), 1.25)
imp("sera", (2.2, -1.6, 0), 1.1)

scene = bpy.context.scene
scene.render.film_transparent = True
bk.preview(OUT, target=(0, 0, -2.6), cam_loc=(0, -30, 7.5), lens=50, res=512)
