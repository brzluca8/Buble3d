"""Mascota Buble – varianta „cască de bulă" (reference/mascota.html), pentru publicul adult.

Rulare:
    blender -b --factory-startup --python art/blender/mascot_bula.py -- godot/assets/models/mascota.glb [preview.png]

Corp crem rotunjit, eșarfă violetă cu frunză aurie, rucsac mic, cască transparentă (dom de sticlă;
în joc primește shaderul Fresnel irizat), guler auriu, antenă aurie mică. Fără ochelari de aviator.
Proporții sobre, expresie fină. Fața spre -Y (Blender) = +Z (Godot).
Animații: idle-loop (respirație, clipit), walk-loop, wave (salut), joy (bucurie).
Noduri pentru garderobă: „Casca" (domul), „Esarfa", „Corp" (materiale Blana / Violet).
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bk  # noqa: E402
import bpy  # noqa: E402
from bk import box, cyl, sphere, torus  # noqa: E402
from mathutils import Vector  # noqa: E402

A = bk.args()
OUT = A[0] if A else "mascota.glb"
PREVIEW = A[1] if len(A) > 1 else None

bk.reset_scene()
bpy.context.scene.render.fps = 24
P = {
    "fur": bk.mat("Blana", "f4ead8", 0.55),
    "dark": bk.mat("Ochi", "1c1428", 0.08, coat=1.0),
    "hl": bk.mat("Sclipire", "ffffff", 0.2, emit="ffffff", strength=1.2),
    "blush": bk.mat("Obraji", "f0a8b4", 0.9),
    "mouth": bk.mat("Gura", "8a3040", 0.5),
    "scarf": bk.mat("Violet", "6a3fb8", 0.7),
    "gold": bk.mat("Auriu", "e8b040", 0.22, 1.0),
    "wood": bk.mat("Piele", "6e4a32", 0.6),
    "strap": bk.mat("PieleInchisa", "4a3022", 0.65),
    "glass": bk.mat("CascaSticla", "cdeeff", 0.05, alpha=0.18),
}

root = bk.empty("Mascota")
bk.set_parent(root)
body = bk.empty("Corp")
bk.set_parent(body)

# corp (sferă ușor turtită) și picioare
sphere(0.7, (0, 0, 0.75), P["fur"], scale=(1.0, 0.92, 0.95), seg=40, rings=24)
# ochi mai mici, cu două sclipiri (expresie fină)
eyes = []
for s in (-1, 1):
    e = bk.empty("Ochi%s" % ("S" if s > 0 else "D"), (s * 0.22, -0.58, 0.86))
    old = bk._parent[:]
    bk.set_parent(e)
    sphere(0.095, (s * 0.22, -0.58, 0.86), P["dark"], scale=(0.9, 0.5, 1.15), seg=20, rings=12)
    sphere(0.032, (s * 0.22 - 0.025, -0.625, 0.9), P["hl"], seg=8, rings=4)
    sphere(0.015, (s * 0.22 + 0.025, -0.62, 0.83), P["hl"], seg=6, rings=3)
    bk.set_parent(old[0])
    eyes.append(e)
    sphere(0.07, (s * 0.4, -0.52, 0.72), P["blush"], scale=(1.2, 0.3, 0.7), seg=12, rings=6)
# zâmbet discret (arc subțire)
torus(0.06, 0.013, (0, -0.645, 0.73), P["mouth"], rot=(math.radians(90), math.pi, 0), seg=16, sides=5, arc=math.pi)

# eșarfă cu frunză aurie
esarfa = bk.empty("Esarfa", (0, 0, 0.46))
old = bk._parent[:]
bk.set_parent(esarfa)
torus(0.56, 0.1, (0, 0, 0.46), P["scarf"], seg=40, sides=12, scale=(1, 0.95, 0.8))
box((0.2, 0.06, 0.48), (0.32, -0.52, 0.27), P["scarf"], bevel=0.02, rot=(0, 0, math.radians(-14)))
sphere(0.075, (0.0, -0.62, 0.41), P["gold"], scale=(0.55, 0.22, 1.0), rot=(0, math.radians(25), 0), seg=12, rings=8)
sphere(0.06, (0.06, -0.62, 0.39), P["gold"], scale=(0.55, 0.22, 1.0), rot=(0, math.radians(-30), 0), seg=12, rings=8)
bk.set_parent(old[0])

# rucsac mic
box((0.48, 0.24, 0.5), (0, 0.6, 0.66), P["wood"], bevel=0.07)
box((0.5, 0.1, 0.2), (0, 0.66, 0.84), P["strap"], bevel=0.04)
box((0.08, 0.03, 0.08), (0, 0.72, 0.76), P["gold"], bevel=0.01)

# casca de bulă: dom de sticlă, guler auriu, antenă
casca = bk.empty("Casca", (0, 0, 0.85))
old = bk._parent[:]
bk.set_parent(casca)
bpy.ops.mesh.primitive_uv_sphere_add(segments=48, ring_count=28, radius=0.86, location=(0, 0, 0.85))
dome = bpy.context.active_object
bk.keep(dome, lambda c: c.z >= 0.86 * math.cos(math.pi * 0.62) - 0.001)
bk._done(dome, P["glass"])
torus(0.8, 0.05, (0, 0, 0.535), P["gold"], seg=48, sides=10)
cyl(0.018, 0.2, (0, 0, 1.78), P["gold"], seg=8)
sphere(0.055, (0, 0, 1.9), P["gold"], seg=12, rings=6)
bk.set_parent(old[0])

bk.set_parent(root)
arms = {}
for s in (-1, 1):
    a = bk.empty("Brat%s" % ("S" if s > 0 else "D"), (s * 0.62, 0, 0.62))
    old = bk._parent[:]
    bk.set_parent(a)
    sphere(0.16, (s * 0.8, -0.02, 0.5), P["fur"], scale=(1.35, 0.85, 0.85), rot=(0, s * math.radians(-35), 0), seg=16, rings=10)
    bk.set_parent(old[0])
    arms[s] = a
feet = {}
for s in (-1, 1):
    f = bk.empty("Picior%s" % ("S" if s > 0 else "D"), (s * 0.3, -0.05, 0.1))
    old = bk._parent[:]
    bk.set_parent(f)
    sphere(0.19, (s * 0.3, -0.08, 0.1), P["fur"], scale=(1, 1.15, 0.6), seg=16, rings=10)
    bk.set_parent(old[0])
    feet[s] = f
bk.set_parent(None)

bk.apply_and_join(root, "MascotaCorp", keep_empties=[body, casca, esarfa, eyes[0], eyes[1], arms[-1], arms[1], feet[-1], feet[1]])

# ---------------- animații ----------------
ANIM = [body, arms[-1], arms[1], feet[-1], feet[1], eyes[0], eyes[1], casca]
REST = {o.name: (o.location.copy(), o.rotation_euler.copy(), o.scale.copy()) for o in ANIM}


def reset():
    for o in ANIM:
        l, r, s = REST[o.name]
        o.location, o.rotation_euler, o.scale = l.copy(), r.copy(), s.copy()


def key(o, f, loc=(0, 0, 0), rot=(0, 0, 0), sc=(1, 1, 1)):
    l, r, s = REST[o.name]
    o.location = l + Vector(loc)
    o.rotation_euler = (r[0] + rot[0], r[1] + rot[1], r[2] + rot[2])
    o.scale = Vector((s[0] * sc[0], s[1] * sc[1], s[2] * sc[2]))
    for p in ("location", "rotation_euler", "scale"):
        o.keyframe_insert(p, frame=f)


def clip(name, frames, fn):
    for o in ANIM:
        o.animation_data_create()
        o.animation_data.action = bpy.data.actions.new("%s_%s" % (name, o.name))
    for f in frames:
        fn(f)
    for o in ANIM:
        act = o.animation_data.action
        tr = o.animation_data.nla_tracks.new()
        tr.name = name
        tr.strips.new(name, int(act.frame_range[0]), act)
        o.animation_data.action = None
    reset()


def ease(pts, f):
    for (f0, v0), (f1, v1) in zip(pts, pts[1:]):
        if f0 <= f <= f1:
            k = (f - f0) / max(f1 - f0, 1)
            k = k * k * (3 - 2 * k)
            return v0 + (v1 - v0) * k
    return pts[-1][1]


def idle(f):
    t = (f - 1) / 72 * math.tau
    b = math.sin(t * 2)
    key(body, f, loc=(0, 0, 0.008 * b), sc=(1 + 0.01 * b, 1 + 0.01 * b, 1 - 0.014 * b))
    blink = 0.12 if 40 <= f <= 43 else 1.0
    for e in eyes:
        key(e, f, sc=(1, 1, blink))
    for s in (-1, 1):
        key(arms[s], f, rot=(0, s * 0.05 * math.sin(t), 0))
        key(feet[s], f)
    key(casca, f, loc=(0, 0, 0.008 * b))


def walk(f):
    t = (f - 1) / 16 * math.tau
    s = math.sin(t)
    key(body, f, loc=(0, 0, 0.04 * abs(s)), rot=(0, 0.05 * s, 0))
    key(feet[-1], f, loc=(0, -0.1 * s, 0.06 * max(0.0, math.cos(t))))
    key(feet[1], f, loc=(0, 0.1 * s, 0.06 * max(0.0, -math.cos(t))))
    key(arms[-1], f, rot=(0.4 * s, 0, 0))
    key(arms[1], f, rot=(-0.4 * s, 0, 0))
    for e in eyes:
        key(e, f)
    key(casca, f, loc=(0, 0, 0.04 * abs(s)))


def wave(f):
    up = ease([(1, 0.0), (8, 1.0), (34, 1.0), (42, 0.0)], f)
    w = math.sin((f - 8) / 26 * 4 * math.pi) * 0.3 if 8 <= f <= 34 else 0.0
    key(body, f, rot=(0, -0.06 * up, 0))
    key(arms[1], f, rot=(0, (-1.7 + w) * up, 0))
    key(arms[-1], f)
    for s in (-1, 1):
        key(feet[s], f)
    for e in eyes:
        key(e, f, sc=(1, 1, 0.75 if 14 <= f <= 28 else 1.0))     # ochi zâmbitori
    key(casca, f)


def joy(f):
    sq = ease([(1, Vector((1, 1, 1))), (5, Vector((1.1, 1.1, 0.85))), (10, Vector((0.94, 0.94, 1.1))), (18, Vector((1, 1, 1))), (22, Vector((1.06, 1.06, 0.9))), (26, Vector((1, 1, 1)))], f)
    up = ease([(1, 0.0), (5, -0.05), (12, 0.6), (18, 0.0), (26, 0.0)], f)
    arm = ease([(1, 0.0), (6, 0.2), (11, -1.9), (19, -1.5), (24, 0.0), (26, 0.0)], f)
    key(body, f, loc=(0, 0, up), sc=tuple(sq))
    key(arms[-1], f, loc=(0, 0, up), rot=(0, -arm, 0))
    key(arms[1], f, loc=(0, 0, up), rot=(0, arm, 0))
    for s in (-1, 1):
        key(feet[s], f, loc=(0, 0, max(0.0, up - 0.05)))
    for e in eyes:
        key(e, f, loc=(0, 0, up), sc=(1, 1, 0.6 if 9 <= f <= 20 else 1.0))
    key(casca, f, loc=(0, 0, up), sc=tuple(sq))


clip("idle-loop", range(1, 73), idle)
clip("walk-loop", range(1, 18), walk)
clip("wave", range(1, 43), wave)
clip("joy", range(1, 27), joy)
bk.export_glb(OUT, animations=True)

if PREVIEW:
    for o in ANIM:
        for tr in o.animation_data.nla_tracks:
            tr.mute = tr.name != "wave"
    bpy.context.scene.frame_set(20)
    bk.preview(PREVIEW, target=(0, 0, 0.9), cam_loc=(1.3, -3.6, 1.6), lens=55, res=560, bg=(0.12, 0.09, 0.32))
