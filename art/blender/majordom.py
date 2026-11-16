"""Majordomul – automatul de alamă care îl înlocuiește pe vechea mascotă (direcția Art Deco, 18+).

Rulare:
    blender -b --factory-startup --python art/blender/majordom.py -- godot/assets/models/mascota.glb [preview.png]

Corp de alamă în formă de ou, vestă de lac negru cu nasturi aurii, papion, cap rotund cu un
singur ochi-lentilă luminos (chihlimbar), melon negru cu bandă, mănuși albe, picioare scurte
cu ghetre. Fața spre -Y (Blender) = +Z (Godot).
Animații: idle-loop, walk-loop, wave (ridică melonul), joy.
Noduri pentru garderobă (aceleași nume ca la mascota veche, ca jocul să le găsească):
„Casca" (melonul), „Esarfa" (papionul), „Corp"; materiale „Blana" (carcasa) și „Violet" (papionul).
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
    "brass": bk.mat("Blana", "c9a35c", 0.28, 0.9),
    "brass_dk": bk.mat("AlamaInchisa", "8a6a32", 0.35, 0.9),
    "lacquer": bk.mat("Lac", "14161c", 0.22, coat=1.0),
    "bow": bk.mat("Violet", "1e5a4c", 0.45, coat=0.4),
    "gold": bk.mat("Auriu", "e2b860", 0.2, 1.0),
    "lens": bk.mat("Lentila", "ffb347", 0.05, emit="ff9a2a", strength=4.0),
    "lens_ring": bk.mat("LentilaInel", "2a2016", 0.3, 0.6),
    "glove": bk.mat("Manusa", "f2eee6", 0.6),
    "spat": bk.mat("Ghetre", "e8e2d4", 0.7),
}

root = bk.empty("Mascota")
bk.set_parent(root)
body = bk.empty("Corp")
bk.set_parent(body)

# trunchi: ou de alamă, cu vesta de lac în față și nasturi aurii
sphere(0.44, (0, 0, 0.78), P["brass"], scale=(1.0, 0.86, 1.22), seg=40, rings=24)
sphere(0.4, (0, -0.13, 0.76), P["lacquer"], scale=(0.74, 0.7, 1.08), seg=32, rings=18)
for z in (0.92, 0.78, 0.64):
    sphere(0.035, (0, -0.41, z), P["gold"], seg=12, rings=6)
torus(0.43, 0.025, (0, 0, 0.5), P["gold"], seg=48, sides=8, scale=(1, 0.86, 1))
# angrenaje pe spate (doar decor)
torus(0.16, 0.03, (0, 0.37, 0.86), P["brass_dk"], rot=(math.radians(90), 0, 0), seg=24, sides=6)
for i in range(8):
    a = i / 8 * math.tau
    box((0.05, 0.04, 0.05), (math.cos(a) * 0.19, 0.38, 0.86 + math.sin(a) * 0.19), P["brass_dk"])
# gât și cap
cyl(0.09, 0.14, (0, 0, 1.3), P["gold"], seg=16)
sphere(0.3, (0, 0, 1.55), P["brass"], seg=32, rings=18)
torus(0.27, 0.02, (0, 0, 1.43), P["brass_dk"], seg=40, sides=6)
bk.set_parent(root)

# ochiul: o lentilă luminoasă (nod separat pentru clipit)
eye = bk.empty("OchiS", (0, -0.3, 1.57))
bk.set_parent(eye)
torus(0.1, 0.03, (0, -0.29, 1.57), P["lens_ring"], rot=(math.radians(90), 0, 0), seg=28, sides=8)
sphere(0.085, (0, -0.29, 1.57), P["lens"], scale=(1, 0.45, 1), seg=20, rings=10)
bk.set_parent(root)

# papionul („Esarfa" pentru garderobă)
esarfa = bk.empty("Esarfa", (0, -0.3, 1.22))
bk.set_parent(esarfa)
for s in (-1, 1):
    bpy.ops.mesh.primitive_cone_add(vertices=3, radius1=0.08, depth=0.14, location=(s * 0.075, -0.33, 1.22),
                                    rotation=(0, s * math.radians(-90), 0))
    o = bpy.context.active_object
    o.scale = (1, 0.45, 1)
    bk._done(o, P["bow"], smooth=False)
sphere(0.035, (0, -0.34, 1.22), P["bow"], seg=12, rings=6)
bk.set_parent(root)

# melonul („Casca")
casca = bk.empty("Casca", (0, 0, 1.78))
bk.set_parent(casca)
bpy.ops.mesh.primitive_uv_sphere_add(segments=36, ring_count=18, radius=0.24, location=(0, 0, 1.8))
crown = bpy.context.active_object
bk.keep(crown, lambda c: c.z >= -0.001)
crown.scale = (1, 1, 1.1)
bk._done(crown, P["lacquer"])
cyl(0.36, 0.025, (0, 0, 1.8), P["lacquer"], seg=40)
cyl(0.245, 0.06, (0, 0, 1.84), P["bow"], seg=36)
bk.set_parent(root)

# brațe cu mănuși albe (pivot la umăr)
arms = {}
for s in (-1, 1):
    a = bk.empty("Brat%s" % ("S" if s > 0 else "D"), (s * 0.42, 0, 1.02))
    old = bk._parent[:]
    bk.set_parent(a)
    sphere(0.08, (s * 0.44, 0, 1.02), P["gold"], seg=12, rings=6)
    cyl(0.045, 0.42, (s * 0.5, 0, 0.8), P["brass_dk"], seg=12, rot=(0, s * math.radians(-12), 0))
    sphere(0.1, (s * 0.55, -0.02, 0.56), P["glove"], scale=(0.9, 0.8, 1.1), seg=14, rings=8)
    bk.set_parent(old[0])
    arms[s] = a
# picioare scurte cu ghetre
feet = {}
for s in (-1, 1):
    f = bk.empty("Picior%s" % ("S" if s > 0 else "D"), (s * 0.16, 0, 0.25))
    old = bk._parent[:]
    bk.set_parent(f)
    cyl(0.07, 0.24, (s * 0.16, 0, 0.26), P["lacquer"], seg=12)
    sphere(0.11, (s * 0.16, -0.06, 0.07), P["spat"], scale=(0.9, 1.3, 0.6), seg=14, rings=8)
    bk.set_parent(old[0])
    feet[s] = f
bk.set_parent(None)

bk.apply_and_join(root, "MajordomCorp", keep_empties=[body, casca, esarfa, eye, arms[-1], arms[1], feet[-1], feet[1]])

# ---------------- animații ----------------
ANIM = [body, arms[-1], arms[1], feet[-1], feet[1], eye, casca, esarfa]
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


def upper(f, loc=(0, 0, 0), rot=(0, 0, 0)):
    """Capul, melonul, papionul și ochiul urmează trunchiul."""
    key(casca, f, loc=loc, rot=rot)
    key(esarfa, f, loc=loc)


def idle(f):
    t = (f - 1) / 72 * math.tau
    b = math.sin(t * 2)
    lift = (0, 0, 0.01 * b)
    key(body, f, loc=lift, rot=(0, 0, 0.03 * math.sin(t)))
    blink = 0.15 if 46 <= f <= 49 else 1.0
    key(eye, f, loc=lift, sc=(1, 1, blink))
    for s in (-1, 1):
        key(arms[s], f, loc=lift, rot=(0, s * 0.04 * math.sin(t), 0))
        key(feet[s], f)
    upper(f, lift)


def walk(f):
    t = (f - 1) / 16 * math.tau
    s = math.sin(t)
    lift = (0, 0, 0.03 * abs(s))
    key(body, f, loc=lift, rot=(0, 0.04 * s, 0))
    key(feet[-1], f, loc=(0, -0.08 * s, 0.05 * max(0.0, math.cos(t))))
    key(feet[1], f, loc=(0, 0.08 * s, 0.05 * max(0.0, -math.cos(t))))
    key(arms[-1], f, loc=lift, rot=(0.3 * s, 0, 0))
    key(arms[1], f, loc=lift, rot=(-0.3 * s, 0, 0))
    key(eye, f, loc=lift)
    upper(f, lift)


def wave(f):
    """Salut de majordom: ridică melonul cu mâna dreaptă și se înclină."""
    up = ease([(1, 0.0), (9, 1.0), (30, 1.0), (40, 0.0)], f)
    bow = ease([(1, 0.0), (12, 0.0), (18, 0.18), (26, 0.18), (32, 0.0)], f)
    key(body, f, rot=(bow, 0, 0))
    key(eye, f, loc=(0, -0.25 * bow, -0.08 * bow))
    key(arms[1], f, rot=(0, -2.3 * up, 0))
    key(arms[-1], f, rot=(0, 0.2 * bow, 0))
    for s in (-1, 1):
        key(feet[s], f)
    key(casca, f, loc=(0.25 * up, -0.05 * up, 0.22 * up), rot=(0, -0.3 * up, 0))
    key(esarfa, f, loc=(0, -0.2 * bow, -0.06 * bow))


def joy(f):
    up = ease([(1, 0.0), (5, -0.04), (12, 0.45), (18, 0.0), (26, 0.0)], f)
    spin = ease([(1, 0.0), (6, 0.0), (18, math.tau), (26, math.tau)], f)
    arm = ease([(1, 0.0), (6, 0.2), (11, -1.6), (19, -1.3), (24, 0.0), (26, 0.0)], f)
    lift = (0, 0, up)
    key(body, f, loc=lift, rot=(0, 0, spin))
    key(arms[-1], f, loc=lift, rot=(0, -arm, 0))
    key(arms[1], f, loc=lift, rot=(0, arm, 0))
    for s in (-1, 1):
        key(feet[s], f, loc=(0, 0, max(0.0, up - 0.04)))
    key(eye, f, loc=lift, sc=(1.3, 1.3, 1.3) if 9 <= f <= 20 else (1, 1, 1))
    key(casca, f, loc=(0, 0, up + 0.12 * max(0.0, up)), rot=(0, 0, spin))
    key(esarfa, f, loc=lift)


clip("idle-loop", range(1, 73), idle)
clip("walk-loop", range(1, 18), walk)
clip("wave", range(1, 41), wave)
clip("joy", range(1, 27), joy)
bk.export_glb(OUT, animations=True)

if PREVIEW:
    for o in ANIM:
        for tr in o.animation_data.nla_tracks:
            tr.mute = tr.name != "idle-loop"
    bpy.context.scene.frame_set(10)
    bk.preview(PREVIEW, target=(0, 0, 1.0), cam_loc=(1.4, -3.8, 1.7), lens=55, res=560, bg=(0.05, 0.07, 0.12))
