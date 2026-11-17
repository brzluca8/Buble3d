"""Orion – Exploratorul Lumilor: model 3D construit din cod (Blender 5.x, bpy).

Rulare:  python orion_build.py -- <folder_iesire> [--fast]
Produce: orion.blend, orion.glb și randări din 4 unghiuri + una 3/4.
Unități: 1 = ~40 cm la scara personajului; Z în sus, personajul privește spre -Y.
"""
import bpy, math, random, sys, os
from mathutils import Vector, Euler
from mathutils.bvhtree import BVHTree

args = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
OUT = os.path.abspath(args[0] if args else '.')
FAST = '--fast' in args
os.makedirs(OUT, exist_ok=True)
random.seed(7)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

# ---------------------------------------------------------------- materiale
def lin(h):
    h = h.lstrip('#')
    out = []
    for i in (0, 2, 4):
        c = int(h[i:i + 2], 16) / 255
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return out

def mat(name, col, rough=0.6, metal=0.0, emit=None, strength=0.0, coat=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = (*lin(col), 1)
    b.inputs['Roughness'].default_value = rough
    b.inputs['Metallic'].default_value = metal
    if coat:
        b.inputs['Coat Weight'].default_value = coat
    if emit:
        b.inputs['Emission Color'].default_value = (*lin(emit), 1)
        b.inputs['Emission Strength'].default_value = strength
    return m

M = {
    'fur':    mat('Blana', '#DE8A2E', 0.7),
    'cream':  mat('Crem', '#FFF1DC', 0.8),
    'spot':   mat('Pete', '#8A5A2B', 0.8),
    'black':  mat('Negru', '#2A1D14', 0.7),
    'pink':   mat('Roz', '#F59AA8', 0.5),
    'mouth':  mat('Gura', '#7A2430', 0.5),
    'white':  mat('Alb', '#FFFFFF', 0.15, coat=1.0),
    'iris':   mat('Iris', '#1E7FE0', 0.1, emit='#2E9BFF', strength=0.35, coat=1.0),
    'pupil':  mat('Pupila', '#0E1630', 0.1, coat=1.0),
    'scarf':  mat('Esarfa', '#D8322F', 0.65),
    'leather':mat('Piele', '#6B3E1E', 0.55),
    'brass':  mat('Alama', '#C9923A', 0.3, metal=1.0),
    'lens':   mat('Lentila', '#4FB8FF', 0.05, emit='#4FB8FF', strength=1.5, coat=1.0),
    'magic':  mat('Magie', '#4FE3FF', 0.3, emit='#4FE3FF', strength=6.0),
    'paper':  mat('Harta', '#F0DDB0', 0.85),
}

# ---------------------------------------------------------------- unelte
root = bpy.data.objects.new('Orion', None)
scene.collection.objects.link(root)

def _finish(o, name, m, smooth=True):
    o.name = name
    if m:
        o.data.materials.append(m)
    if smooth:
        for p in o.data.polygons:
            p.use_smooth = True
    o.parent = root
    return o

def sphere(name, loc, scale, m, rot=(0, 0, 0), seg=22):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=seg // 2, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.scale = scale
    return _finish(o, name, m)

def limb(name, a, b, r, m):
    a, b = Vector(a), Vector(b)
    d = b - a
    o = sphere(name, (a + b) / 2, (r, r, d.length / 2 + r * 0.5), m)
    o.rotation_mode = 'QUATERNION'
    o.rotation_quaternion = d.to_track_quat('Z', 'Y')
    return o

def cone(name, loc, r1, r2, depth, m, rot=(0, 0, 0), scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_cone_add(vertices=20, radius1=r1, radius2=r2, depth=depth, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.scale = scale
    return _finish(o, name, m)

def cyl(name, loc, r, depth, m, rot=(0, 0, 0), scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=r, depth=depth, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.scale = scale
    return _finish(o, name, m)

def torus(name, loc, R, r, m, rot=(0, 0, 0), scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_torus_add(major_segments=36, minor_segments=8, major_radius=R, minor_radius=r, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.scale = scale
    return _finish(o, name, m)

def box(name, loc, size, m, bevel=0.05, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    mod = o.modifiers.new('Bevel', 'BEVEL')
    mod.width = bevel
    mod.segments = 4
    return _finish(o, name, m)

def along(a, b, t):
    return Vector(a).lerp(Vector(b), t)

# ---------------------------------------------------------------- corp (se topește într-o singură plasă)
HEAD_C, HEAD_S = Vector((0, 0, 1.55)), Vector((0.62, 0.53, 0.5))
BODY_C, BODY_S = Vector((0, 0, 0.66)), Vector((0.40, 0.35, 0.48))
fuse = [
    sphere('Cap', HEAD_C, HEAD_S, M['fur'], seg=40),
    sphere('Trunchi', BODY_C, BODY_S, M['fur'], seg=40),
    sphere('Gat', (0, 0.02, 1.12), (0.27, 0.25, 0.22), M['fur']),
    # obraji/barbă de râs (smocuri laterale)
    cone('ObrazD', (0.5, -0.06, 1.36), 0.2, 0.02, 0.42, M['fur'], rot=(0, math.radians(115), math.radians(-12))),
    cone('ObrazS', (-0.5, -0.06, 1.36), 0.2, 0.02, 0.42, M['fur'], rot=(0, math.radians(-115), math.radians(12))),
]
SH = [(0.34, -0.02, 0.94), (-0.34, -0.02, 0.94)]
HD = [(0.50, -0.16, 0.56), (-0.50, -0.16, 0.56)]
for s, h, side in zip(SH, HD, 'DS'):
    fuse.append(limb('Brat' + side, s, h, 0.12, M['fur']))
    fuse.append(sphere('Laba' + side, Vector(h) + Vector((0, -0.02, -0.07)), (0.13, 0.13, 0.12), M['fur']))
for x, side in ((0.19, 'D'), (-0.19, 'S')):
    fuse.append(limb('Picior' + side, (x, 0, 0.42), (x, -0.06, 0.16), 0.14, M['fur']))
    fuse.append(sphere('Talpa' + side, (x * 1.05, -0.12, 0.12), (0.17, 0.24, 0.13), M['fur']))

# coada stufoasă, ridicată și curbată spre stânga
def tail_p(t):
    return Vector((-0.15 - 0.62 * t, 0.32 + 0.30 * t - 0.15 * t * t, 0.32 + 1.05 * t - 0.25 * t * t))
def tail_r(t):
    return 0.13 + 0.17 * math.sin(math.pi * min(1, t * 1.05))
for k in range(22):
    t = k / 21
    fuse.append(sphere(f'Coada{k}', tail_p(t), (tail_r(t),) * 3, M['fur'], seg=24))

bpy.ops.object.select_all(action='DESELECT')
for o in fuse:
    o.select_set(True)
bpy.context.view_layer.objects.active = fuse[0]
bpy.ops.object.join()
body = bpy.context.active_object
body.name = 'Orion_Corp'
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
rm = body.modifiers.new('Remesh', 'REMESH')
rm.mode = 'VOXEL'
rm.voxel_size = 0.022 if FAST else 0.014
rm.use_smooth_shade = True
bpy.ops.object.modifier_apply(modifier='Remesh')
sm = body.modifiers.new('Smooth', 'SMOOTH')
sm.factor, sm.iterations = 0.6, 6
bpy.ops.object.modifier_apply(modifier='Smooth')

# ---------------------------------------------------------------- pete pe blană (proiectate pe suprafață)
dg = bpy.context.evaluated_depsgraph_get()
bvh = BVHTree.FromObject(body, dg)
def project(center, d):
    d = Vector(d).normalized()
    hit = bvh.ray_cast(Vector(center) + d * 3, -d)
    return hit if hit[0] is not None else None
def spot(center, d, s):
    h = project(center, d)
    if not h:
        return
    loc, nrm = h[0], h[1]
    o = sphere('Pata', loc, (s, s * 0.75, s * 0.22), M['spot'], seg=12)
    o.rotation_mode = 'QUATERNION'
    o.rotation_quaternion = nrm.to_track_quat('Z', 'Y')
spots = 0
while spots < 46:
    d = Vector((random.uniform(-1, 1), random.uniform(-1, 1), random.uniform(-1, 1)))
    if d.length < 0.2:
        continue
    d.normalize()
    if spots < 16:  # cap: fără pete pe față
        if d.y < -0.25 or d.z < -0.2:
            continue
        spot(HEAD_C, d, random.uniform(0.025, 0.045))
    else:           # corp și brațe: fără pete pe burtă
        if d.y < -0.35 or abs(d.z) > 0.8:
            continue
        spot(BODY_C, d, random.uniform(0.025, 0.05))
    spots += 1

# ---------------------------------------------------------------- burtă și bot
sphere('Burta', (0, -0.19, 0.62), (0.29, 0.18, 0.36), M['cream'])
sphere('PieptBlana', (0, -0.2, 1.0), (0.24, 0.14, 0.16), M['cream'])
for x in (0.1, -0.1):
    sphere('Bot', (x, -0.47, 1.37), (0.15, 0.11, 0.115), M['cream'])
sphere('Barbie', (0, -0.42, 1.25), (0.13, 0.09, 0.08), M['cream'])
sphere('Nas', (0, -0.585, 1.45), (0.07, 0.04, 0.045), M['pink'])
sphere('Gura', (0, -0.53, 1.30), (0.075, 0.035, 0.055), M['mouth'])
sphere('Limba', (0, -0.545, 1.275), (0.045, 0.025, 0.03), M['pink'])
for side in (1, -1):
    for k, (dz, ang) in enumerate(((0.03, 8), (0.0, 0), (-0.03, -8))):
        a = Vector((side * 0.17, -0.55, 1.38 + dz))
        b = a + Vector((side * 0.38, 0.06, math.tan(math.radians(ang)) * 0.38))
        w = limb('Mustata', a, b, 0.006, M['white'])

# ---------------------------------------------------------------- ochi
for side in (1, -1):
    ex, ez = side * 0.215, 1.585
    rz = math.radians(-side * 18)
    sphere('AlbOchi', (ex, -0.47, ez), (0.165, 0.07, 0.19), M['white'], rot=(0, 0, rz), seg=32)
    sphere('Iris', (ex * 1.0, -0.505, ez - 0.005), (0.13, 0.06, 0.155), M['iris'], rot=(0, 0, rz), seg=32)
    sphere('Pupila', (ex * 0.98, -0.535, ez), (0.07, 0.035, 0.09), M['pupil'], rot=(0, 0, rz))
    sphere('Sclipire', (ex - side * 0.035 + 0.02, -0.565, ez + 0.06), (0.035, 0.015, 0.04), M['white'])
    sphere('Sclipire2', (ex + 0.035, -0.56, ez - 0.06), (0.016, 0.01, 0.018), M['white'])
    # sprâncene / pleoapă de sus
    limb('Spranceana', (ex - side * 0.11, -0.49, ez + 0.2), (ex + side * 0.09, -0.47, ez + 0.23), 0.022, M['black'])

# ---------------------------------------------------------------- urechi cu smocuri
for side in (1, -1):
    tilt = side * math.radians(22)
    base = Vector((side * 0.34, 0.03, 1.93))
    up = Euler((math.radians(-8), tilt, 0)).to_matrix() @ Vector((0, 0, 1))
    cone('Ureche', base + up * 0.22, 0.24, 0.02, 0.58, M['fur'], rot=(math.radians(-8), tilt, 0), scale=(1, 0.42, 1))
    cone('UrecheInt', base + up * 0.2 + Vector((0, -0.06, 0)), 0.16, 0.01, 0.42, M['pink'], rot=(math.radians(-8), tilt, 0), scale=(1, 0.3, 1))
    cone('VarfUreche', base + up * 0.42, 0.075, 0.01, 0.2, M['black'], rot=(math.radians(-8), tilt, 0), scale=(1, 0.5, 1))
    cone('Smoc', base + up * 0.6, 0.03, 0.002, 0.3, M['black'], rot=(math.radians(-8), tilt, 0))

# ---------------------------------------------------------------- ochelari de aviator pe frunte
torus('Curea', (0, 0.0, 1.86), 0.48, 0.04, M['leather'], rot=(math.radians(-6), 0, 0), scale=(1.0, 0.88, 1))
for side in (1, -1):
    gx = side * 0.2
    rot = (math.radians(68), 0, math.radians(side * 22))
    cyl('Ochelar', (gx, -0.36, 1.9), 0.135, 0.12, M['brass'], rot=rot)
    torus('RamaOchelar', (gx * 1.02, -0.405, 1.885), 0.13, 0.03, M['brass'], rot=rot)
    sphere('Lentila', (gx * 1.03, -0.415, 1.885), (0.11, 0.11, 0.035), M['lens'], rot=rot)
    sphere('SclipireLentila', (gx * 1.0 - 0.03, -0.45, 1.93), (0.03, 0.01, 0.02), M['white'], rot=rot)
cyl('Punte', (0, -0.42, 1.89), 0.025, 0.12, M['brass'], rot=(0, math.radians(90), 0))

# ---------------------------------------------------------------- eșarfă
torus('Esarfa', (0, -0.02, 1.13), 0.33, 0.1, M['scarf'], rot=(math.radians(8), 0, 0), scale=(1.05, 1, 0.85))
sphere('Nod', (0.16, -0.33, 1.06), (0.1, 0.08, 0.09), M['scarf'])
limb('CapatEsarfa1', (0.17, -0.34, 1.02), (0.3, -0.36, 0.78), 0.065, M['scarf'])
limb('CapatEsarfa2', (0.13, -0.35, 1.02), (0.12, -0.38, 0.82), 0.06, M['scarf'])

# ---------------------------------------------------------------- centură, medalion-busolă
torus('Centura', (0, 0.0, 0.47), 0.37, 0.035, M['leather'], scale=(1, 0.9, 1))
box('Catarama', (0, -0.335, 0.47), (0.11, 0.04, 0.09), M['brass'], bevel=0.015)
limb('CureaPiept', (0.3, -0.12, 1.02), (-0.28, -0.3, 0.6), 0.03, M['leather'])
med_rot = (math.radians(80), 0, 0)
cyl('Medalion', (-0.08, -0.37, 0.86), 0.1, 0.035, M['brass'], rot=med_rot)
cyl('CadranBusola', (-0.08, -0.392, 0.863), 0.075, 0.012, M['cream'], rot=med_rot)
cone('AcBusola', (-0.08, -0.4, 0.865), 0.02, 0.0, 0.11, M['magic'], rot=(math.radians(-10), 0, 0), scale=(1, 0.3, 1))

# ---------------------------------------------------------------- brățări cu cristal
for s, h, side in zip(SH, HD, (1, -1)):
    p = along(s, h, 0.7)
    d = (Vector(h) - Vector(s)).normalized()
    t = torus('Bratara', p, 0.1, 0.028, M['leather'])
    t.rotation_mode = 'QUATERNION'
    t.rotation_quaternion = d.to_track_quat('Z', 'Y')
    g = sphere('CristalBrat', p + Vector((side * 0.06, -0.09, 0)), (0.04, 0.03, 0.05), M['magic'], seg=8)

# ---------------------------------------------------------------- rucsac, hartă, felinar
box('Rucsac', (0, 0.42, 0.86), (0.6, 0.3, 0.58), M['leather'], bevel=0.08)
box('Buzunar', (0, 0.58, 0.76), (0.4, 0.06, 0.26), M['leather'], bevel=0.04)
box('Clapa', (0, 0.44, 1.12), (0.62, 0.32, 0.08), M['leather'], bevel=0.04)
cyl('Harta', (0.02, 0.42, 1.24), 0.11, 0.78, M['paper'], rot=(0, math.radians(90), math.radians(8)))
for x in (-0.25, 0.27):
    torus('LegaturaHarta', (x, 0.42, 1.24), 0.115, 0.018, M['leather'], rot=(0, math.radians(90), math.radians(8)))
for x in (0.24, -0.24):
    limb('BreteaRucsac', (x, 0.28, 1.12), (x * 1.15, -0.2, 1.0), 0.03, M['leather'])
cyl('BazaFelinar', (0.4, 0.42, 0.57), 0.08, 0.025, M['brass'])
for k in range(4):
    a = k * math.pi / 2 + math.pi / 4
    cyl('StalpFelinar', (0.4 + math.cos(a) * 0.065, 0.42 + math.sin(a) * 0.065, 0.66), 0.01, 0.18, M['brass'])
sphere('CristalFelinar', (0.4, 0.42, 0.66), (0.05, 0.05, 0.075), M['magic'], seg=12)
cone('CapacFelinar', (0.4, 0.42, 0.79), 0.09, 0.02, 0.08, M['brass'])

# ---------------------------------------------------------------- spirale magice pe coadă
for t in (0.38, 0.58, 0.78):
    p = tail_p(t)
    d = (tail_p(t + 0.02) - tail_p(t - 0.02)).normalized()
    o = torus('SpiralaCoada', p, tail_r(t) * 0.93, 0.03, M['magic'])
    o.rotation_mode = 'QUATERNION'
    o.rotation_quaternion = d.to_track_quat('Z', 'Y')
sphere('VarfCoada', tail_p(1.0) + Vector((-0.03, 0.01, 0.05)), (0.12, 0.12, 0.12), M['black'])

# ---------------------------------------------------------------- scenă de randare
world = bpy.data.worlds.new('Cer')
scene.world = world
world.use_nodes = True
world.node_tree.nodes['Background'].inputs['Color'].default_value = (*lin('#1B2A5E'), 1)
world.node_tree.nodes['Background'].inputs['Strength'].default_value = 0.7

bpy.ops.mesh.primitive_cylinder_add(radius=1.1, depth=0.06, location=(0, 0, -0.03))
ped = bpy.context.active_object
ped.name = 'Piedestal'
ped.data.materials.append(mat('Piedestal', '#2C3E7A', 0.4))

def light(name, kind, loc, energy, col='#FFFFFF', size=2.0, target=(0, 0, 1)):
    d = bpy.data.lights.new(name, kind)
    d.energy = energy
    d.color = lin(col)
    if kind == 'AREA':
        d.size = size
    o = bpy.data.objects.new(name, d)
    scene.collection.objects.link(o)
    o.location = loc
    o.rotation_mode = 'QUATERNION'
    o.rotation_quaternion = (Vector(target) - Vector(loc)).to_track_quat('-Z', 'Y')
light('Cheie', 'AREA', (2.5, -3.2, 3.2), 650, '#FFF1DC', 3)
light('Umplere', 'AREA', (-3.0, -2.0, 1.5), 300, '#BFD8FF', 3)
light('Contur', 'AREA', (-1.5, 3.0, 2.8), 700, '#7FD8FF', 2)

cam_d = bpy.data.cameras.new('Camera')
cam_d.lens = 70
cam = bpy.data.objects.new('Camera', cam_d)
scene.collection.objects.link(cam)
scene.camera = cam

scene.render.engine = 'CYCLES'
scene.cycles.device = 'CPU'
scene.cycles.samples = 24 if FAST else 96
scene.cycles.use_denoising = True
scene.render.resolution_x = scene.render.resolution_y = 600 if FAST else 1000
scene.render.film_transparent = False
scene.view_settings.view_transform = 'Standard'

def shoot(fname, loc, target=(0, 0, 1.05)):
    cam.location = loc
    cam.rotation_mode = 'QUATERNION'
    cam.rotation_quaternion = (Vector(target) - Vector(loc)).to_track_quat('-Z', 'Y')
    scene.render.filepath = os.path.join(OUT, fname)
    bpy.ops.render.render(write_still=True)

shoot('orion_3_4.png', (2.6, -6.2, 2.0))
for ang, nm in ((0, 'fata'), (90, 'profil'), (180, 'spate'), (-35, 'unghi')):
    root.rotation_euler = (0, 0, math.radians(ang))
    shoot(f'orion_{nm}.png', (0, -7.2, 1.25))
root.rotation_euler = (0, 0, 0)

# ---------------------------------------------------------------- salvare + export GLB (decimat pentru telefon)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, 'orion.blend'))
dec = body.modifiers.new('Decimate', 'DECIMATE')
dec.ratio = 0.08
bpy.ops.object.select_all(action='DESELECT')
for o in [root] + list(root.children):
    o.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, 'orion.glb'), use_selection=True, export_apply=True)
tris = 0
for o in root.children:
    if o.type == 'MESH':
        me = o.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh()
        tris += sum(len(p.vertices) - 2 for p in me.polygons)
print('TRIUNGHIURI_EXPORT', tris)
