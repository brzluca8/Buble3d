"""Rebuild Lerion's original, vertex-painted GLBs with Python 3 (no dependencies).

Coordinates use metres, Y up, with the player looking towards negative Z.
Parts in each GLB share a matte material. Repeated plots instance the same GLB.
"""
import json
import math
import random
import struct
from collections import defaultdict
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / "assets" / "kingdom"
TAU = math.tau
sin, cos, pi = math.sin, math.cos, math.pi
rng = random.Random(4307)


def rgb(hex_value):
    return tuple(int(hex_value[i:i + 2], 16) / 255 for i in (0, 2, 4))


def mix(a, b, t):
    return tuple(x + (y - x) * t for x, y in zip(a, b))


def linear(c):
    return c / 12.92 if c < .04045 else ((c + .055) / 1.055) ** 2.4


def normal(a, b, c):
    u = [v - w for v, w in zip(b, a)]
    v = [v - w for v, w in zip(c, a)]
    n = (u[1]*v[2]-u[2]*v[1], u[2]*v[0]-u[0]*v[2], u[0]*v[1]-u[1]*v[0])
    length = math.sqrt(sum(x*x for x in n))
    return tuple(x / length for x in n) if length else (0, 1, 0)


class Mesh:
    def __init__(self):
        self.points, self.indices, self.lookup = [], [], {}

    def face(self, points, color, colors=None):
        if isinstance(color, str):
            color = rgb(color)
        n = tuple(round(v, 5) for v in normal(*points[:3]))
        ids = []
        for i, point in enumerate(points):
            tint = colors[i] if colors else color
            key = (tuple(round(v, 5) for v in point), n, tuple(round(linear(v)*255) for v in tint))
            if key not in self.lookup:
                self.lookup[key] = len(self.points)
                self.points.append(key)
            ids.append(self.lookup[key])
        for i in range(1, len(ids)-1):
            self.indices.extend((ids[0], ids[i], ids[i+1]))


def write_glb(name, groups):
    data = bytearray()
    views, accessors, meshes, nodes = [], [], [], []

    def array(values, fmt, component, kind, **extra):
        while len(data) % 4:
            data.append(0)
        start = len(data)
        pack = struct.Struct('<' + fmt).pack
        for value in values:
            data.extend(pack(*value))
        views.append(dict(buffer=0, byteOffset=start, byteLength=len(data)-start))
        accessors.append(dict(bufferView=len(views)-1, componentType=component, count=len(values), type=kind, **extra))
        return len(accessors)-1

    for label, mesh in groups.items():
        if not mesh.points:
            continue
        pos, norm, col = zip(*mesh.points)
        axes = list(zip(*pos))
        p = array(pos, '3f', 5126, 'VEC3', min=list(map(min, axes)), max=list(map(max, axes)))
        n = array(norm, '3f', 5126, 'VEC3')
        c = array([(*v, 255) for v in col], '4B', 5121, 'VEC4', normalized=True)
        small = len(pos) < 65536
        idx = array([(i,) for i in mesh.indices], 'H' if small else 'I', 5123 if small else 5125, 'SCALAR')
        nodes.append(dict(name=label, mesh=len(meshes)))
        meshes.append(dict(name=label, primitives=[dict(attributes=dict(POSITION=p, NORMAL=n, COLOR_0=c), indices=idx, material=0)]))
    while len(data) % 4:
        data.append(0)
    doc = dict(asset=dict(version='2.0', generator='Lerion'), scene=0, scenes=[dict(nodes=list(range(len(nodes))))],
               nodes=nodes, meshes=meshes, materials=[dict(name='Pigment', pbrMetallicRoughness=dict(metallicFactor=0, roughnessFactor=.92))],
               accessors=accessors, bufferViews=views, buffers=[dict(byteLength=len(data))])
    header = json.dumps(doc, separators=(',', ':')).encode()
    header += b' ' * (-len(header) % 4)
    body = struct.pack('<I4s', len(header), b'JSON') + header + struct.pack('<I4s', len(data), b'BIN\0') + data
    (OUT / (name + '.glb')).write_bytes(struct.pack('<4sII', b'glTF', 2, 12 + len(body)) + body)


def lathe(m, x, y, z, profile, count=12, phase=0, stretch=1):
    """Stack bevelled rings. Each row describes height, radius and band colour."""
    prev = None
    for height, radius, color in profile:
        ring = [(x + radius*cos(phase+i*TAU/count), y+height, z + stretch*radius*sin(phase+i*TAU/count)) for i in range(count)]
        if prev:
            for i in range(count):
                j = (i+1) % count
                if radius < .00001:
                    m.face([prev[j], prev[i], ring[i]], color)
                else:
                    m.face([prev[j], prev[i], ring[i], ring[j]], color)
        prev = ring
    if radius > 0:
        m.face(list(reversed(prev)), color)


def box(m, x, y, z, w, h, d, color, yaw=0, bevel=.045):
    b = min(bevel, w*.22, d*.22, h*.3)
    w, d = w/2, d/2
    outline = [(-w+b,-d),(w-b,-d),(w,-d+b),(w,d-b),(w-b,d),(-w+b,d),(-w,d-b),(-w,-d+b)]
    rings = []
    for height, inset in [(0,b),(b,0),(h-b,0),(h,b)]:
        ring = []
        for xx, zz in outline:
            xx, zz = xx*(1-inset/w), zz*(1-inset/d)
            ring.append((x + xx*cos(yaw)-zz*sin(yaw), y+height, z+xx*sin(yaw)+zz*cos(yaw)))
        if rings:
            for i in range(8):
                j=(i+1)%8
                m.face([rings[-1][j],rings[-1][i],ring[i],ring[j]], color)
        rings.append(ring)
    m.face(rings[-1][::-1], color)


def pebble(m, x, y, z, r, h, color, sides=7, stretch=.92):
    phase = rng.random()*TAU
    lathe(m,x,y,z,[(0,r*.7,color),(h*.23,r,color),(h*.67,r*.9,color),(h*.92,r*.55,color),(h,r*.26,color)],sides,phase,stretch)


def profile_solid(m, outline, z, depth, color):
    """Extruded ornament facing the camera. Outline is CCW in the XY plane."""
    front = [(x,y,z) for x,y in outline]
    back = [(x,y,z-depth) for x,y in outline]
    m.face(front,color)
    for i in range(len(front)):
        j=(i+1)%len(front)
        m.face([back[i],back[j],front[j],front[i]],color)


def arch(m,x,y,z,w,h,depth,color):
    r=w/2
    arc=[(x+r*cos(i*pi/12), y+h-r+r*sin(i*pi/12)) for i in range(13)]
    profile_solid(m,[(x-r,y),(x+r,y)]+arc,z,depth,color)


def flag(m,cloth,x,y,z,s):
    lathe(m,x,y,z,[(0,.05*s,'e8a744'),(1.18*s,.042*s,'ffcc64')],8)
    pebble(m,x,y+1.14*s,z,.085*s,.16*s,'ffdc74')
    for i,(dx,dy,dz) in enumerate([(0,0,0),(.34,.07,.12),(.71,-.05,.03)]):
        ex,ey,ez=[(.34,.07,.12),(.71,-.05,.03),(1.02,.01,-.09)][i]
        p=[(x+dx*s,y+(.65+dy)*s,z+dz*s),(x+ex*s,y+(.65+ey+.22*(i==2))*s,z+ez*s),
           (x+ex*s,y+(1.06+ey-.12*(i==2))*s,z+ez*s),(x+dx*s,y+(1.06+dy)*s,z+dz*s)]
        cloth.face(p,['ed554c','dc4248','f06345'][i])
        cloth.face(p[::-1],'d44145')


def castle():
    m=Mesh()
    groups={'Castel':m}
    stone='f2d19b'
    # Gatehouse and its stepped, cobalt central spire.
    box(m,0,0,0,4.1,2.76,2.12,'e9bd90',bevel=.18)
    box(m,0,.13,0,4.29,.35,2.26,'cc997e',bevel=.10)
    box(m,0,2.54,0,4.28,.28,2.32,stone,bevel=.09)
    for i in range(7):
        box(m,(i-3)*.61,2.75,.93,.38,.39,.39,stone)
    def tower(x,z,r,h,roof):
        lathe(m,x,0,z,[(0,r*1.12,stone),(.27,r*1.14,'d3a58a'),(.42,r,stone),(h-.43,r*.90,stone),
            (h-.29,r*1.13,'cf9b7a'),(h-.11,r*1.17,stone),(h,r*1.13,'ffe2ad')],12,pi/12)
        for band in range(3):
            br=r*(1.34-.35*band)
            by=h+band*roof*.30
            lathe(m,x,by,z,[(0,br,'254d99'),(.09,br,'315cb0'),(.15,br*.97,'548ee7'),
                (roof*.32, max(.06,br-r*.42),['397aca','4688dc','417ccb'][band])],12,pi/12)
        lathe(m,x,h+roof*.89,z,[(0,r*.29,'345bb1'),(.13,r*.22,'ffce55'),(.25,.055,'f4aa35')],10)
        cloth=Mesh()
        groups['Steag'+str(len(groups))]=cloth
        flag(m,cloth,x,h+roof*.89+.22,z,r*.91)
        arch(m,x,h*.55,z+r*.92,.38*r,.7*r,.2,'be9478')
        arch(m,x,h*.55+.05,z+r*.94,.25*r,.54*r,.04,'415275')
    tower(0,-.44,1.16,4.01,2.03)
    # A recessed lancet and gilded sill remain visible above the battlements.
    arch(m,0,2.99,.674,.51,.83,.14,'c2926b')
    arch(m,0,3.06,.696,.35,.63,.045,'426486')
    box(m,0,2.98,.69,.56,.11,.21,'f8db9c')
    box(m,0,3.07,.705,.038,.51,.035,'f6c576',bevel=.007)
    for side in (-1,1):
        tower(side*1.97,.61,.77,2.75,1.45)
    # Concentric arch, amber double doors, strap hinges and individual voussoirs.
    arch(m,0,.11,1.27,1.63,2.30,.29,'c99169')
    arch(m,0,.12,1.32,1.35,2.09,.15,'704336')
    arch(m,0,.13,1.35,1.15,1.91,.08,'b76a39')
    box(m,0,.13,1.365,.034,1.86,.035,'75482e',bevel=.009)
    for side in (-1,1):
        for y in (.54,1.12):
            box(m,side*.34,y,1.38,.42,.085,.055,'edab50')
        for row in range(4):
            box(m,side*.78,.15+.30*row,1.34,.23,.27,.23,'f9d9a1')
    for i in range(9):
        a=i*pi/9+.018
        b=(i+1)*pi/9-.018
        points=[(r*cos(t),1.43+r*sin(t)) for r,t in [(.69,a),(.90,a),(.90,b),(.69,b)]]
        profile_solid(m,points,1.43,.21,'ffe4b2' if i%2==0 else stone)
    for i in range(4):
        box(m,0,.012,1.42+i*.24,1.60+i*.12,(4-i)*.095,.43,'eac9a1')
        box(m,0,(4-i)*.095+.016,1.42+i*.24,.80,.025,.36,'c84a47',bevel=.008)
    # A diamond-cut sun on a raspberry heraldic shield.
    for s,z,c in [(1,1.53,'ffd36a'),(.80,1.56,'b62f55')]:
        profile_solid(m,[(0,2.47-.58*s),(.48*s,2.47-.19*s),(.48*s,2.47+.36*s),(-.48*s,2.47+.36*s),(-.48*s,2.47-.19*s)],z,.11,c)
    profile_solid(m,[(0,2.15),(.17,2.44),(0,2.7),(-.17,2.44)],1.59,.03,'ffe58a')
    for side in (-1,1):
        for j,(bx,by) in enumerate([(1.55,.49),(1.36,.74),(1.52,2.32),(.89,2.35)]):
            box(m,side*bx,by,1.067,.19+.07*(j%2),.10,.035,'d4aa86',bevel=.014)
        x=side*1.19
        box(m,x,.85,1.15,.36,1.10,.10,'87428d')
        box(m,x,1.90,1.18,.51,.10,.17,'f7c456')
        profile_solid(m,[(x,.98),(x+.095,1.24),(x,1.46),(x-.095,1.24)],1.22,.02,'ffdc73')
    return groups


def crystal(m,x,y,z,r,h):
    bottom=(x,y,z)
    tip=(x+.07*r,y+h,z)
    ring=[(x+r*cos(i*TAU/6),y+h*(.42+.035*(i%2)),z+r*sin(i*TAU/6)) for i in range(6)]
    crown=[(x+.64*r*cos(i*TAU/6),y+h*.74,z+.64*r*sin(i*TAU/6)) for i in range(6)]
    blues=['1bb6ec','46e3ff','9bf6ff','2bd0fa','267ed5','168adf']
    for i in range(6):
        j=(i+1)%6
        m.face([bottom,ring[i],ring[j]],blues[(i+2)%6])
        m.face([ring[j],ring[i],crown[i],crown[j]],blues[i])
        m.face([crown[j],crown[i],tip],blues[(i+1)%6])


def fountain():
    m=Mesh()
    lathe(m,0,0,0,[(0,1.55,'aa9583'),(.12,1.61,'d4b397'),(.25,1.47,'ffe1ac'),(.30,1.36,'d5ae97'),
        (.46,1.28,'845584'),(.54,1.48,'ae7a92'),(.67,1.48,'ffe0a2'),(.73,1.33,'f3c173'),(.66,1.18,'a96e53'),
        (.60,1.13,'6edce5')],24)
    lathe(m,0,.60,0,[(0,.67,'5897ad'),(.15,.58,'7788bb'),(.24,.82,'d29a42'),(.38,.85,'ffda64'),(.43,.70,'fff098')],16)
    gem=Mesh()
    crystal(gem,0,.97,0,.56,1.67)
    # Four stylised water jets. The closed octagonal tubes use opaque aqua
    # facets, keeping the basin legible without alpha sorting on mobile.
    for i in range(4):
        a=(i+.5)*TAU/4
        previous=None
        for step in range(13):
            t=step/12
            radius=.62+.52*t
            y=1.01+.82*t-1.21*t*t
            ring=[]
            for j in range(6):
                angle=j*TAU/6
                w=.030*(1+.18*t)
                ring.append((radius*cos(a)-w*sin(a)*cos(angle), y+w*sin(angle), radius*sin(a)+w*cos(a)*cos(angle)))
            if previous:
                for j in range(6):
                    k=(j+1)%6
                    m.face([previous[j],previous[k],ring[k],ring[j]],'95e6ed' if j%3 else 'baf1f2')
            previous=ring
        pebble(m,radius*cos(a),.605,radius*sin(a),.082,.057,'b2eff4',7)
    for i in range(4):
        a=(i+.40)*TAU/4
        crystal(m,.59*cos(a),.75,.59*sin(a),.12,.38)
    for i in range(10):
        a=i*TAU/10
        pebble(m,1.405*cos(a),.39,1.405*sin(a),.11,.14,'ffd571',6)
    return {'Fantana':m,'CristalCentral':gem}


def plot():
    m=Mesh()
    lathe(m,0,.01,0,[(0,1.48,'b98857'),(.10,1.49,'ca9c65'),(.15,1.44,'e0ad72')],32)
    for i in range(20):
        a=i*TAU/20
        b=(i+1)*TAU/20
        color=rng.choice(['f6d39c','f1ca94','e8bd88','ffe0ac'])
        # Bevelled wedge stones separated by fine mortar joints.
        last=None
        for h, inset in [(.025,.02),(.085,0),(.235,0),(.287,.032)]:
            footprint=[(1.59-inset,a+.008+inset*.18),(1.59-inset,b-.008-inset*.18),
                       (1.31+inset,b-.008-inset*.18),(1.31+inset,a+.008+inset*.18)]
            ring=[(r*cos(t),h,r*sin(t)) for r,t in footprint]
            if last:
                for k in range(4):
                    j=(k+1)%4
                    m.face([last[j],last[k],ring[k],ring[j]],color)
            last=ring
        m.face(last[::-1],color)
    # A sparse scattering of flat ochre pebbles gives the earth a sense of scale.
    for _ in range(16):
        a=rng.random()*TAU
        r=rng.uniform(.67,1.24)
        pebble(m,r*cos(a),.148,r*sin(a),rng.uniform(.023,.061),.015,rng.choice(['d9a56f','ecc18a']),5,.58)
    # A raised ivory inlay; both arms share the same top surface.
    box(m,0,.158,0,.79,.09,.24,'fff0bd')
    box(m,0,.158,-.259,.24,.09,.28,'fff0bd')
    box(m,0,.158,.259,.24,.09,.28,'fff0bd')
    return m


def hill(x,z):
    # The clearing is level. Smooth low ridges rise along the sides and horizon.
    ridges=[(-16,-12,5,8,9),(16,-15,6,10,9),(-8,-28,4.7,12,8),(11,-33,4.9,13,10),
            (-32,-51,9,18,12),(1,-58,7,16,9),(32,-62,11,15,13),(-51,-77,20,18,10)]
    height=sum(h*math.exp(-((x-cx)/w)**2-((z-cz)/d)**2) for cx,cz,h,w,d in ridges)
    blend=max(0,min(1,max((abs(x)-7)/5,(-z-12)/6)))
    return height*blend*blend*(3-2*blend)


def terrain():
    m=Mesh()
    # Extend the outer rows beyond the camera's far plane; concentrate vertices
    # around the clearing and ridges where their colour and shape are visible.
    cells=[-240]+list(range(-84,-31,4))+list(range(-30,31,2))+list(range(32,85,4))+[240]
    depths=[-240]+list(range(-116,-43,4))+list(range(-42,29,2))+[34,46,240]
    rows=[]
    for z in depths:
        row=[]
        for x in cells:
            xx,zz=x+rng.uniform(-.42,.42),z+rng.uniform(-.42,.42)
            y=hill(xx,zz)
            variation=.45+.21*sin(xx*.43+zz*.23)+.15*cos(zz*.71-xx*.14)+.10*rng.random()
            tint=mix(rgb('82b54b'),rgb('b3cf62'),variation)
            tint=mix(tint,rgb('79ad70'),min(.82,y*.085))
            tint=mix(tint,rgb('91c9c0'),min(.90,max(0,(-zz-19)/64)))
            row.append(((xx,y-.035,zz),tint))
        rows.append(row)
    for r in range(len(rows)-1):
        for c in range(len(cells)-1):
            corners=[rows[r][c], rows[r+1][c], rows[r+1][c+1], rows[r][c+1]]
            for ids in [(0,1,2),(0,2,3)]:
                m.face([corners[i][0] for i in ids],None,[corners[i][1] for i in ids])
    return m


PLOTS=[(-4.1,-4.55),(4.1,-4.55),(-4.70,.85),(4.70,.85),(-3.48,6.30),(3.48,6.30)]
roads=[]


def path(m, ctrl, width, y):
    old=None
    for step in range(31):
        t=step/30
        s=1-t
        x,z=[s**3*a+3*s*s*t*b+3*s*t*t*c+t**3*d for a,b,c,d in zip(*ctrl)]
        dx,dz=[3*s*s*(b-a)+6*s*t*(c-b)+3*t*t*(d-c) for a,b,c,d in zip(*ctrl)]
        size=math.hypot(dx,dz)
        nx,nz=dz/size,-dx/size
        r=width*(1+.035*sin(t*pi))
        row=[(x+nx*r*f,y+lift,z+nz*r*f) for f,lift in [(-1,0),(-.94,.012),(.94,.012),(1,0)]]
        if old:
            for i,c in enumerate(['ceab74','f1cb8b','ceab74']):
                m.face([old[i],row[i],row[i+1],old[i+1]],c)
        roads.append((x,z,r))
        old=row


def paths():
    m=Mesh()
    # Broad sandy plaza and three curved links on each side.
    lathe(m,0,.006,0,[(0,2.24,'d0ae77'),(.018,2.22,'eec88b')],44)
    for i,(x,z) in enumerate(PLOTS):
        side=math.copysign(1,x)
        start=(side*(1.05 if i//2!=1 else 1.7),(-1.65,.14,1.65)[i//2])
        path(m,[start,(side*2.45,start[1]+z*.10),(x*.68,z*.94),(x,z)],.46,.031+i*.003)
    path(m,[(0,-1.55),(.32,-4.1),(-.38,-6.4),(0,-8.6)],.63,.042)
    path(m,[(0,1.6),(.76,5.2),(-.3,7.1),(-1.42,9.3)],.67,.047)
    path(m,[(-1.42,9.3),(-3.55,13.5),(3.3,13.0),(1.75,23)],.68,.049)
    for x,z,s in [(-1.69,10.18,.71),(-1.78,10.58,.56),(-1.82,10.92,.39),(.25,4.48,.39),(-.04,-6.05,.37)]:
        for dx,dz,r in [(-.26,0,.23),(.20,.14,.16),(.03,-.24,.12)]:
            pebble(m,x+dx*s,.071,z+dz*s,r*s,.034*s,'e3bb84',6,.63)
    return m


def conifer(m,x,y,z,s,far=False):
    lathe(m,x,y,z,[(0,s*.14,'a07448'),(.64*s,.11*s,'95643e')],6)
    for i in range(2 if far else 3):
        by=(.39+i*.52)*s
        r=(.86-.17*i)*s
        color=['318550','3a9958','51a963'][i]
        lathe(m,x,y+by,z,[(0,r*.82,'26754c'),(.10*s,r,color),(.31*s,r*.88,color),
                            ((1.44 if far else 1.21)*s,0,color)],7,.29*i)


def hardwood(m,x,y,z,s,pink=False):
    lathe(m,x,y,z,[(0,.38*s,'98724d'),(.45*s,.23*s,'9b754a'),(1.47*s,.19*s,'a88259')],7)
    for dx,dz,h,r in [(-.57,.06,1.14,.70),(.54,.1,1.24,.72),(0,-.38,1.4,.78),(-.12,.12,1.74,.69),(-.31,.56,1.35,.58),(.36,.47,1.53,.53)]:
        c=rng.choice(['f594ae','f8a5bd','ec8da9'] if pink else ['79b34a','91c350','a5c950','82bb53'])
        pebble(m,x+dx*s,y+h*s,z+dz*s,r*s,r*1.41*s,c,8)


def flowers(m,x,z,s,color):
    for dx,dz in [(-.23,.08),(.16,-.16),(.27,.18),(0,.14)]:
        xx,zz=x+dx*s,z+dz*s
        y=hill(xx,zz)+.035
        pebble(m,xx,y,zz,.15*s,.12*s,'70a748',5)
        for i in range(5):
            a=i*TAU/5
            lathe(m,xx+.077*s*cos(a),y+.11*s,zz+.077*s*sin(a),[(0,.05*s,color),(.04*s,.070*s,color),(.07*s,.044*s,color)],5)
        pebble(m,xx,y+.148*s,zz,.052*s,.054*s,'f8bb42',6)


def fence(m,x,z,angle,count):
    for i in range(count):
        xx,zz=x+i*.85*cos(angle),z+i*.85*sin(angle)
        y=hill(xx,zz)
        box(m,xx,y,zz,.16,.73,.18,'b7804a',angle)
        box(m,xx,y+.68,zz,.20,.09,.21,'e3ac71',angle)
        if i<count-1:
            for h in (.26,.51):
                box(m,xx+.425*cos(angle),y+h,zz+.425*sin(angle),.93,.12,.095,'d59a5a',angle)


def dressing():
    groups=defaultdict(Mesh)
    def patch(x,z):
        size=16 if z < -19 else 9
        return groups[f'Poiana_{size}_{math.floor(x/size)+20}_{math.floor(z/size)+20}']
    # Hazy blue mountain silhouettes and small banks of clouds on the horizon.
    far=groups['Culmi']
    for x,z,r,h in [(-42,-92,25,9),(-22,-90,17,7.8),(-8,-94,19,5.8),(12,-96,16,8.2),(29,-91,18,7.4),(46,-93,16,9.5)]:
        lathe(far,x,-1,z,[(0,r,'80a6aa'),(h*.37,r*.61,'83aab6'),(h*.70,r*.33,'8eafbf'),(h,r*.06,'a8c5cd')],7,rng.random(),.53)
    clouds=groups['Nori']
    for x,z,y,s in [(-15,-72,9.3,1.05),(9,-74,10.1,.89),(31,-78,10.6,1.22),(-36,-82,11.0,.72)]:
        for dx,dy,r in [(-2.4,0,1.43),(-.65,.02,2.0),(.70,.14,1.72),(2.22,-.08,1.28)]:
            pebble(clouds,x+dx*s,y+dy*s,z,r*s,r*.84*s,'e3eded',12,.69)
    # Hand-framed clearing, with open sight lines between the front row and gate.
    for x,z,s,kind in [(-6.5,-8.1,1.30,'oak'),(7.2,-7.0,1.16,'pink'),(-7.1,-3,1,'pine'),
            (7.7,-2.1,1.03,'pine'),(-7.4,2.3,1.13,'oak'),(7.35,3.5,1.08,'pine'),
            (-5.95,7.7,1.06,'pine'),(5.8,8.9,1.20,'oak'),(-4.9,11.4,.78,'pine'),
            (3.94,12.55,1.17,'pine'),(-4.62,13.0,.98,'oak'),(-5.5,-11.4,.85,'pine'),(5.55,-11.0,1.0,'pine')]:
        if kind=='pine':
            conifer(patch(x,z),x,hill(x,z),z,s)
        else:
            hardwood(patch(x,z),x,hill(x,z),z,s,kind=='pink')
    # Various scales and deliberate gaps keep the distant hills legible.
    for _ in range(590):
        x,z=rng.uniform(-52,52),rng.uniform(-70,19)
        if abs(x)<9 and z>-14 or abs(x)<3.6 and z>-22:
            continue
        if rng.random()>.60+.26*sin(x*.42+z*.11):
            continue
        conifer(patch(x,z),x,hill(x,z)-.24,z,rng.uniform(.64,1.38),z<-25)
    for x,z,a,n in [(-6.28,-6.30,-.42,3),(4.58,-7.8,.42,3),(-7,4.0,-.73,3),(6.35,5.7,.82,3),
                    (-5.4,9.5,.37,3),(2.6,10.6,-.27,3)]:
        fence(patch(x,z),x,z,a,n)
    for x,z,s in [(-5.9,-.9,.67),(6.35,-4.6,.59),(-2.9,-7.85,.48),(5.26,4.5,.45),
                  (1.62,8.4,.57),(-4.18,10.3,.51),(-6.25,5.1,.44)]:
        for dx,dz,r in [(0,0,s),(.58,.07,s*.56),(-.38,.23,s*.39)]:
            xx,zz=x+dx*s*1.5,z+dz*s
            pebble(patch(x,z),xx,hill(xx,zz),zz,r,1.09*r,rng.choice(['aba7a7','b9b2a5','a5a3ab']))
    for x,z in [(-2.5,-6.1),(3.0,-7.2),(-5.65,-2.5),(5.8,-2.0),(-2.65,-.75),(2.64,-.93),
                (-6.24,2.65),(5.63,3.05),(-5.2,5.15),(4.83,7.75),(-1.82,7.67),(2.48,8.52),
                (-4.09,9.70),(.05,11.05),(-1.37,-.86),(1.52,.57),(1.45,-.75),(-1.48,.68)]:
        flowers(patch(x,z),x,z,rng.uniform(.85,1.31),rng.choice(['fff2c6','fff6dc','f3a0bb','c0a3df']))
    # Low rounded bushes bring colour and volume to the ground around the well.
    for x,z,s in [(-1.33,.83,.37),(1.41,.63,.36),(-1.53,-.39,.34),(1.45,-.64,.31),
                  (-2.35,-2.5,.38),(3.49,3.57,.36),(-4.3,8.7,.47),(3.06,10.39,.56),
                  (1.1,12.3,.43),(-6.41,-4.5,.56),(5.8,-.9,.48),(-4.25,-7.3,.48)]:
        m=patch(x,z)
        for dx,dz,r,h in [(-.59,.0,.73,.80),(.52,.1,.76,.86),(.0,-.17,.97,1.12)]:
            xx,zz=x+dx*s,z+dz*s
            pebble(m,xx,hill(xx,zz),zz,s*r,s*h,rng.choice(['66a748','75ae49','88b953']),8)
        for i in range(5):
            a=i*TAU/5+.3
            xx,zz=x+.57*s*cos(a),z+.50*s*sin(a)
            yy=hill(x,z)+s*(.87+.065*cos(a))
            pebble(m,xx,yy,zz,.10*s,.095*s,'f6b3c6',5)
    # Small grass blades in clumps, avoiding roads, plots and the courtyard.
    for _ in range(950):
        x,z=rng.uniform(-12,12),rng.uniform(-13,17)
        if x*x+z*z<5 or abs(x)<3 and z<-7.3:
            continue
        if any(math.hypot(x-px,z-pz)<1.68 for px,pz in PLOTS):
            continue
        if any(abs(x-px)<r+.15 and abs(z-pz)<r+.15 for px,pz,r in roads):
            continue
        y=hill(x,z)
        for i in range(3):
            xx,zz=x+.073*i,z+rng.uniform(-.06,.06)
            h=rng.uniform(.08,.19)
            p=[(xx-.035,y-.015,zz),(xx+.039,y-.015,zz),(xx+(i-1)*.072,y+h,zz-.018)]
            patch(x,z).face(p,rng.choice(['93bb56','89b657','a6c45a']))
    return groups


if __name__=='__main__':
    OUT.mkdir(parents=True,exist_ok=True)
    write_glb('castle',castle())
    write_glb('fountain',fountain())
    write_glb('plot',{'Parcela':plot()})
    write_glb('meadow',{'Pajiste':terrain(),'Alei':paths()})
    write_glb('groves',dressing())
