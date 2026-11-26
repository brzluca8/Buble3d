"""Six modular Godot props, using the approved map's low-poly art tools."""
import math
from pathlib import Path

import build_art as art
from build_art import Mesh, arch, box, crystal, lathe, pebble, profile_solid

art.OUT = Path(__file__).resolve().parents[1] / 'assets' / 'village'
WOOD, TRIM, GOLD, CREAM = '945d40', 'ce925b', 'ffcc62', 'f4d7a6'


def roof(mesh, x, y, z, width, depth, height, color):
    w = width / 2
    profile_solid(mesh, [(x-w,y),(x+w,y),(x+w,y+.09),(x+.08,y+height),
                         (x-.08,y+height),(x-w,y+.09)], z+depth/2, depth, color)
    box(mesh,x,y-.05,z+depth/2,width,.12,.12,TRIM)


def cottage(m, color, w=1.5):
    box(m,0,0,0,w+.09,.23,1.22,'b8a798')
    box(m,0,.2,0,w,1.03,1.12,CREAM)
    roof(m,0,1.20,0,w+.28,1.47,.69,color)
    for side in [-1,1]:
        box(m,side*(w/2-.05),.20,.58,.115,.99,.09,WOOD)
    arch(m,-.23,.14,.60,.44,.78,.06,WOOD)
    box(m,-.23,.18,.64,.29,.04,.04,TRIM)
    window(m,.36,.72,.59)


def window(m,x,y,z):
    arch(m,x,y,z,.32,.42,.07,WOOD)
    arch(m,x,y+.04,z+.012,.23,.32,.04,'79cbd2')
    box(m,x,y-.03,z+.01,.37,.07,.14,TRIM)


def barrel(m,x,z,r=.22):
    lathe(m,x,0,z,[(0,r*.85,WOOD),(.07,r,'5e5f6b'),(.28,r*1.08,TRIM),
                    (.36,r,'60616c'),(.41,r*.93,TRIM)],10)


def mine(a,b,c,d):
    for x,z,r,h in [(-.55,0,.54,1.19),(.52,-.05,.60,1.28),(0,-.29,.84,1.53)]:
        pebble(a,x,0,z,r,h,'938c9e',8)
    for x,y,z,r,h in [(-.32,1.12,-.03,.19,.6),(-.57,1.04,.00,.13,.39),(.72,.64,.08,.14,.54)]:
        crystal(a,x,y,z,r,h)
    arch(a,0,.10,.57,.92,1.11,.15,'413847')
    for sx in [-.45,.45]:
        box(a,sx,.08,.62,.18,1.0,.23,WOOD)
        box(a,sx,.22,.65,.20,.1,.25,TRIM)
    box(a,0,1.05,.62,1.18,.20,.27,TRIM)
    for x,z,r in [(-.77,.42,.18),(.65,.44,.16),(-.48,-.05,.15)]:
        crystal(a,x,.15,z,r,r*3.1)
    for x in [-.23,.23]:
        box(b,x,0,.79,.06,.08,.80,'737c8f')
    for z in [.67,.94,1.13]:
        box(b,0,0,z,.63,.045,.10,WOOD)
    box(b,.76,.16,.14,.52,.37,.54,'7c869b')
    for x in [.58,.94]:
        pebble(b,x,.045,.39,.091,.18,'4e525b',8,.51)
    box(b,.76,.45,.14,.58,.07,.60,'abb3c1')
    crystal(b,.76,.49,.14,.17,.42)
    box(c,-.68,0,.56,.10,1.43,.10,TRIM)
    box(c,-.48,1.40,.56,.50,.10,.12,WOOD)
    crystal(d,0,0,0,.19,.52)


def mill(a,b,c,d):
    lathe(a,0,0,0,[(0,.68,'c2a18a'),(.23,.71,'ccaa8d'),(.34,.64,CREAM),
                         (1.55,.43,CREAM),(1.66,.59,WOOD),(1.77,.61,'eb8752'),
                         (2.27,.11,'d75d40')],12)
    arch(a,0,.10,.67,.40,.62,.13,WOOD)
    for i in range(10):
        a0=i*math.tau/10
        if math.sin(a0) < .53:
            box(a,.62*math.cos(a0),.30,.62*math.sin(a0),.14,.08,.10,'c99577',-a0)
    # The four blades are one independent mesh with their pivot at the hub.
    for i in range(4):
        angle=i*math.pi/2+.36
        def turn(points):
            return [(x*math.cos(angle)-y*math.sin(angle),x*math.sin(angle)+y*math.cos(angle)) for x,y in points]
        profile_solid(d,turn([(-.036,0),(.036,0),(.036,.94),(-.036,.94)]),.02,.06,WOOD)
        profile_solid(d,turn([(.01,.31),(.27,.41),(.24,.92),(.01,.96)]),.07,.07,'ffda78')
        for h in [.55,.72,.87]:
            profile_solid(d,turn([(.02,h),(.22,h+.015),(.22,h+.04),(.02,h+.026)]),.081,.012,'bd8646')
    pebble(d,0,-.065,.09,.10,.16,GOLD)
    for x,z in [(-.65,.32),(-.62,-.1),(.7,.22)]:
        pebble(b,x,.0,z,.22,.42,'dfb978',8)
    box(c,.63,.02,-.22,.51,.83,.67,CREAM)
    roof(c,.63,.84,-.22,.69,.83,.40,'cf6949')


def workshop(a,b,c,d):
    cottage(a,'c95048')
    for dx in [-.55,-.28,.29,.55]:
        h=1.26+(.83-abs(dx))*.70
        box(a,dx,h,.62,.15,.07,.18,'e77756')
    box(a,-.63,.42,.64,.20,.18,.11,'d2ac81')
    box(a,.53,1.43,-.38,.27,.66,.28,'af806d')
    box(a,.53,2.02,-.38,.34,.13,.34,'d9ad96')
    box(a,.53,.16,.73,.38,.42,.28,WOOD)
    box(b,-.86,.35,.09,.48,.11,.84,TRIM)
    for z in [-.14,.32]:
        box(b,-.86,.0,z,.11,.35,.13,WOOD)
    barrel(b,.82,.22)
    box(b,-.86,.45,.14,.29,.12,.31,'636878')
    box(b,-.86,.56,.14,.44,.10,.29,'8b95a2')
    box(c,-.59,1.32,-.17,.31,.57,.34,'ce9579')
    roof(c,-.59,1.88,-.17,.43,.46,.23,'eb905b')
    box(c,0,1.25,.66,.60,.40,.14,'aa7750')
    box(d,0,-.10,0,.11,.82,.12,TRIM)
    box(d,0,.54,0,.59,.27,.22,'71758b')
    # A smaller fixed hammer also identifies the workshop before level three.
    box(a,.24,1.28,.73,.09,.43,.09,WOOD)
    box(a,.24,1.63,.74,.33,.16,.15,'778397')


def lab(a,b,c,d):
    lathe(a,0,0,0,[(0,.73,'a68c9f'),(.19,.75,'bda1ad'),(.29,.66,CREAM),
        (1.14,.64,CREAM),(1.20,.87,'72468f'),(1.31,.82,'a570c8'),
        (1.62,.47,'995fbd'),(1.65,.54,'8553a5'),(2.06,.12,'a66fc5'),(2.21,.04,GOLD)],12)
    arch(a,-.08,.15,.68,.45,.76,.16,'674978')
    window(a,.37,.59,.52)
    for x,y,z in [(-.26,1.50,.62),(.11,1.72,.46),(.34,1.43,.59)]:
        profile_solid(a,[(x,y-.09),(x+.056,y),(x,y+.09),(x-.056,y)],z,.045,GOLD)
    lathe(b,-.66,.03,.54,[(0,.23,'655477'),(.18,.33,'745d90'),(.39,.3,'735989'),(.44,.33,'9a8bb4'),(.45,.26,'79d9c2')],10)
    for x in [.62,.87]:
        crystal(c,x,0,.10,.16,.53+(x-.6))
    pebble(d,0,0,0,.16,.25,'cf93ed')


def market(a,b,c,d):
    box(a,0,-.022,0,1.84,.10,1.38,'cb9970')
    box(a,0,.06,0,1.75,.43,.87,TRIM)
    box(a,0,.47,0,1.84,.10,1.03,WOOD)
    for x in [-.78,.78]:
        for z in [-.33,.34]:
            box(a,x,.05,z,.09,1.19,.1,WOOD)
    for i in range(7):
        x=-.90+i*.26
        color='d85a53' if i%2==0 else 'ffebca'
        # A convex fabric bow and scalloped hem read cleanly from above.
        for za,zb,ya,yb in [(-.55,-.17,1.42,1.52),(-.17,.19,1.52,1.48),(.19,.57,1.48,1.30)]:
            a.face([(x-.13,ya,za),(x-.13,yb,zb),(x+.13,yb,zb),(x+.13,ya,za)],color)
        profile_solid(a,[(x-.13,1.22),(x-.075,1.16),(x+.075,1.16),(x+.13,1.22),(x+.13,1.31),(x-.13,1.31)],.57,.05,color)
    for i,col in enumerate(['efa550','a6c15f','dd7162']):
        for j in range(3):
            pebble(a,-.56+i*.49+j*.10,.54,.13,.095,.15,col)
    barrel(b,-.84,.53)
    box(b,.66,.03,.61,.51,.34,.39,TRIM)
    box(c,.95,.06,-.18,.09,1.65,.10,WOOD)
    box(c,.81,1.65,-.18,.4,.09,.10,TRIM)
    box(d,0,-.34,0,.36,.33,.09,'3a9192')
    crystal(d,0,-.30,.06,.07,.19)


def inn(a,b,c,d):
    cottage(a,'4e83b7',1.65)
    for x in [-.52,.52]:
        box(a,x,.30,.60,.26,.11,.06,'bc9b80')
    for z in [-.31,.08,.46]:
        box(a,0,1.85,z,.19,.09,.31,'75a2c5')
    box(a,-.70,.80,.716,.13,.15,.04,'f4dfae')
    box(a,.05,.11,.68,.71,.13,.32,'d9b38e')
    box(a,-.71,1.06,.66,.34,.12,.13,WOOD)
    box(a,-.73,.78,.67,.25,.27,.08,GOLD)
    box(b,-.70,.1,-.33,.65,.78,.81,CREAM)
    roof(b,-.69,.87,-.33,.80,.91,.39,'6d9ac3')
    barrel(b,.81,.48)
    box(c,.42,1.52,-.19,.29,.64,.31,'b98070')
    box(c,.42,2.10,-.19,.37,.12,.38,'d99f80')
    box(c,.88,1.15,.56,.48,.1,.11,WOOD)
    box(d,0,-.30,0,.23,.25,.18,'ffc669')
    box(d,0,-.085,0,.27,.08,.21,'73616b')


if __name__=='__main__':
    art.OUT.mkdir(exist_ok=True)
    for model in [mine,mill,workshop,lab,market,inn]:
        sections={name:Mesh() for name in ['Base','Upgrade2','Upgrade3','Accent']}
        model(*sections.values())
        art.write_glb(model.__name__,sections)
