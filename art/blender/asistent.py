"""Nox – asistentul robot (direcția Neon noir, 18+). Înlocuiește mascota în glob și în Mecanism.

Rulare:
    blender -b --factory-startup --python art/blender/asistent.py -- godot/assets/models/mascota.glb [preview.png]

Robot mic care plutește: carcasă albă lucioasă în formă de ou, cap rotunjit cu vizor de sticlă
neagră și doi ochi LED turcoaz, inel de lumină la gât (culoarea se schimbă din garderobă),
antenă cu vârf luminos, brațe-aripioare care plutesc, disc de propulsie sub corp.
Fără gură, fără obraji – expresia vine doar din ochi. Fața spre -Y (Blender) = +Z (Godot).
Animații: idle-loop, walk-loop, wave, joy.
Noduri pentru garderobă (aceleași nume ca înainte): „Casca" (antena), „Esarfa" (inelul de lumină),
„Corp"; materiale „Blana" (carcasa) și „Violet" (lumina inelului, emisivă).
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bk  # noqa: E402
import bpy  # noqa: E402
from bk import cyl, sphere, torus  # noqa: E402
from mathutils import Vector  # noqa: E402

A = bk.args()
OUT = A[0] if A else "mascota.glb"
PREVIEW = A[1] if len(A) > 1 else None

bk.reset_scene()
bpy.context.scene.render.fps = 24
P = {
    "shell": bk.mat("Blana", "eef0f6", 0.18, 0.0, coat=1.0),
    "dark": bk.mat("Grafit", "1a1c24", 0.35, 0.6),
    "visor": bk.mat("Vizor", "05060a", 0.05, 0.2, coat=1.0),
    "eye": bk.mat("OchiLED", "7ff6ff", 0.2, emit="37e8f5", strength=6.0),
    "ring": bk.mat("Violet", "ff3fa4", 0.3, emit="ff3fa4", strength=4.0),
    "thrust": bk.mat("Propulsie", "9ff8ff", 0.3, emit="37e8f5", strength=5.0),
}

root = bk.empty("Mascota")
bk.set_parent(root)
body = bk.empty("Corp")
bk.set_parent(body)
# corpul: ou alb, cu o cusătură grafit și disc de propulsie dedesubt
sphere(0.42, (0, 0, 0.72), P["shell"], scale=(1.0, 0.95, 1.12), seg=40, rings=24)
torus(0.418, 0.012, (0, 0, 0.68), P["dark"], seg=48, sides=6, scale=(1, 0.95, 1))
sphere(0.2, (0, 0, 0.3), P["dark"], scale=(1, 1, 0.45), seg=24, rings=12)
cyl(0.13, 0.02, (0, 0, 0.21), P["thrust"], seg=24)
# capul: sferă turtită, vizor negru lucios
sphere(0.36, (0, 0, 1.38), P["shell"], scale=(1.12, 1.0, 0.86), seg=40, rings=24)
sphere(0.3, (0, -0.15, 1.38), P["visor"], scale=(1.1, 0.8, 0.64), seg=36, rings=20)
bk.set_parent(root)

# ochii LED (nod separat pentru clipit)
eye = bk.empty("OchiS", (0, -0.39, 1.4))
bk.set_parent(eye)
for s in (-1, 1):
    sphere(0.06, (s * 0.12, -0.392, 1.4), P["eye"], scale=(1.0, 0.35, 0.62), seg=16, rings=8)
bk.set_parent(root)

# inelul de lumină de la gât („Esarfa")
esarfa = bk.empty("Esarfa", (0, 0, 1.1))
bk.set_parent(esarfa)
torus(0.25, 0.035, (0, 0, 1.1), P["ring"], seg=40, sides=8)
cyl(0.2, 0.08, (0, 0, 1.1), P["dark"], seg=24)
bk.set_parent(root)

# antena („Casca")
casca = bk.empty("Casca", (0, 0, 1.66))
bk.set_parent(casca)
cyl(0.015, 0.22, (0.08, 0, 1.76), P["dark"], seg=8)
sphere(0.04, (0.08, 0, 1.89), P["eye"], seg=12, rings=6)
bk.set_parent(root)

# brațe-aripioare (pivot la umăr)
arms = {}
for s in (-1, 1):
    a = bk.empty("Brat%s" % ("S" if s > 0 else "D"), (s * 0.46, 0, 0.88))
    old = bk._parent[:]
    bk.set_parent(a)
    sphere(0.13, (s * 0.52, 0, 0.72), P["shell"], scale=(0.45, 0.75, 1.35), seg=20, rings=12,
           rot=(0, s * math.radians(-10), 0))
    sphere(0.035, (s * 0.47, 0, 0.88), P["dark"], seg=10, rings=6)
    bk.set_parent(old[0])
    arms[s] = a
bk.set_parent(None)

bk.apply_and_join(root, "NoxCorp", keep_empties=[body, casca, esarfa, eye, arms[-1], arms[1]])

# ---------------- animații ----------------
ANIM = [body, arms[-1], arms[1], eye, casca, esarfa]
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


def all_up(f, lift, rot=(0, 0, 0), eye_sc=(1, 1, 1)):
    key(body, f, loc=lift, rot=rot)
    key(eye, f, loc=lift, sc=eye_sc)
    key(casca, f, loc=lift)
    key(esarfa, f, loc=lift)


def idle(f):
    t = (f - 1) / 72 * math.tau
    lift = (0, 0, 0.05 * math.sin(t * 2))          # plutire
    blink = 0.1 if 50 <= f <= 53 else 1.0
    all_up(f, lift, rot=(0, 0, 0.04 * math.sin(t)), eye_sc=(1, 1, blink))
    for s in (-1, 1):
        key(arms[s], f, loc=lift, rot=(0, s * 0.08 * math.sin(t * 2 + 1), 0))


def walk(f):
    """Alunecă înainte, ușor aplecat, cu aripioarele în spate."""
    t = (f - 1) / 16 * math.tau
    lift = (0, 0, 0.03 * math.sin(t * 2))
    all_up(f, lift, rot=(-0.12, 0, 0))
    for s in (-1, 1):
        key(arms[s], f, loc=lift, rot=(-0.35, s * 0.1, 0))


def wave(f):
    up = ease([(1, 0.0), (8, 1.0), (32, 1.0), (40, 0.0)], f)
    w = math.sin((f - 8) / 24 * 4 * math.pi) * 0.35 if 8 <= f <= 32 else 0.0
    happy = (1, 1, 0.55) if 12 <= f <= 28 else (1, 1, 1)   # ochi „zâmbitori"
    all_up(f, (0, 0, 0.03 * up), rot=(0, -0.1 * up, 0), eye_sc=happy)
    key(arms[1], f, loc=(0, 0, 0.03 * up), rot=(0, (-2.2 + w) * up, 0))
    key(arms[-1], f, loc=(0, 0, 0.03 * up))


def joy(f):
    up = ease([(1, 0.0), (6, 0.5), (14, 0.5), (24, 0.0), (26, 0.0)], f)
    spin = ease([(1, 0.0), (5, 0.0), (19, math.tau), (26, math.tau)], f)
    arm = ease([(1, 0.0), (6, -1.4), (18, -1.4), (24, 0.0), (26, 0.0)], f)
    lift = (0, 0, up)
    all_up(f, lift, rot=(0, 0, spin), eye_sc=(1.25, 1, 0.5) if 6 <= f <= 22 else (1, 1, 1))
    key(arms[-1], f, loc=lift, rot=(0, -arm, spin))
    key(arms[1], f, loc=lift, rot=(0, arm, spin))


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
    bk.preview(PREVIEW, target=(0, 0, 1.0), cam_loc=(1.4, -3.8, 1.6), lens=55, res=560, bg=(0.03, 0.03, 0.06))
