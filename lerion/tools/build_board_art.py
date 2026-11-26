"""Original trail-side planting and a replaceable, low-poly Lerik pawn."""
import math
import random
from pathlib import Path
import build_art as art
from build_art import Mesh, box, lathe, pebble, profile_solid

art.OUT = Path(__file__).resolve().parents[1] / 'assets' / 'board'


def pawn():
    m = Mesh()
    parts = {'Trunchi': m, 'Cap': Mesh()}
    for x, name in [(-.18,'PiciorStang'),(.18,'PiciorDrept')]:
        leg = parts[name] = Mesh()
        pebble(leg,x,0,.05,.17,.19,'765343',8,1.23)
        box(leg,x,.12,0,.19,.23,.23,'506b78')
    lathe(m,0,.29,0,[(0,.25,'8c644e'),(.09,.31,'59868b'),(.40,.28,'689fa1'),
                       (.49,.19,'e8aa5b')],10)
    pebble(m,0,.38,-.23,.28,.39,'9c6640',8,.67)
    box(m,0,.58,-.38,.32,.08,.08,'f4bd69')
    for x, name in [(-.32,'BratStang'),(.32,'BratDrept')]:
        arm = parts[name] = Mesh()
        pebble(arm,x,.40,.06,.14,.29,'e3a261',8)
    head = parts['Cap']
    pebble(head,0,.70,0,.42,.63,'eaa15a',12,.82)
    for sign in [-1,1]:
        x = sign*.27
        outline=[(x-.12,1.15),(x+.13,1.15),(x+sign*.105,1.52)]
        profile_solid(head,outline,.035,.15,'d38b50')
        tip=x+sign*.105
        profile_solid(head,[(tip-.045,1.43),(tip+.045,1.43),(tip+sign*.036,1.57)],.04,.08,'554645')
        pebble(head,sign*.25,.82,.22,.145,.18,'f2bf85',7)
        box(head,sign*.16,.965,.313,.075,.085,.048,'493f42',bevel=.018)
        box(head,sign*.158,1.18,.255,.24,.16,.10,'8f5b39',bevel=.045)
        box(head,sign*.158,1.21,.31,.175,.092,.06,'77c4cf',bevel=.024)
    pebble(head,0,.79,.31,.15,.15,'ffe4b5',10,.55)
    box(head,0,.918,.36,.11,.061,.05,'67484a',bevel=.021)
    box(head,0,1.23,.279,.14,.042,.08,'d19a58')
    lathe(m,0,.69,0,[(0,.25,'bc5c49'),(.11,.28,'e27856')],10)
    art.write_glb('lerik',parts)


def depth(z):
    return z * 1.32 if z > 0 else z


def garden():
    m=Mesh()
    for x,z,s,kind in [(-8.2,-7.9,1.12,'oak'),(8.4,-8.2,1.16,'pink'),(-8.2,-2.5,.97,'pine'),
            (8.5,-1.9,1.05,'pine'),(-8.4,3.5,1.20,'oak'),(8.1,4.4,1.00,'pine'),
            (-7.8,9.7,1.14,'pine'),(7.8,10.7,1.1,'oak'),(-4.6,13.0,.88,'pine'),(4.9,14.3,1.20,'pine'),
            (-1.55,4.5,.52,'pine'),(1.45,-3.88,.52,'pine')]:
        z=depth(z)
        if kind=='pine':
            art.conifer(m,x,art.hill(x,z),z,s)
        else:
            art.hardwood(m,x,art.hill(x,z),z,s,kind=='pink')
    for x,z,angle in [(-7.1,-8.0,-.28),(5.0,-8.15,.21),(-8.2,1.6,-.8),(7.8,1.9,-1.9),
                       (-6.6,9.5,.16),(5,9.6,-.15)]:
        z=depth(z)
        art.fence(m,x,z,angle,3)
    for x,z,s in [(-2.8,3.48,.63),(1.1,6.7,.49),(1.65,-2.3,.41),(-1.7,-4.9,.52),
                  (-7.3,-3.9,.59),(7.4,5.0,.57),(-2.5,11.4,.67),(.8,12.45,.37)]:
        z=depth(z)
        for dx,dz,r in [(0,0,s),(.52,.18,s*.57),(-.45,.25,s*.39)]:
            pebble(m,x+dx,0,z+dz,r,r*.94,'aba59f')
    for i,(x,z) in enumerate([(-1.40,.79),(1.40,.76),(1.37,-.71),(-1.45,-.66),
              (-2.4,3.73),(.85,5.34),(-1.84,6.4),(.94,-4.8),(-2.4,-3.38),
              (-5.08,-7.92),(5.70,-8.00),(-6.16,2.08),(6.19,2.16),(-4.82,9.15),(6.82,8.41),
              (-2.9,11.56),(.77,11.01),(2.78,10.64),(-7.6,4.25)]):
        z=depth(z)
        art.flowers(m,x,z,1.13,['fff0ae','f2acc9','dfbbe5'][i%3])
    for x,z in [(-1.72,4.15),(1.2,3.70),(-.18,-4.2),(-2.2,11.5),(1.55,11.1)]:
        z=depth(z)
        for dx,h in [(-.23,.34),(.09,.49),(.37,.31)]:
            pebble(m,x+dx,0,z,.30,h,'7db150')
    # Twin gold-tipped route pennants flank START, outside the walking surface.
    for x,z in [(-.67,13.11),(.67,11.18)]:
        lathe(m,x,0,z,[(0,.14,'ad8767'),(.15,.14,'dec599'),(.17,.052,'b67a49'),
                          (.96,.043,'ca914d'),(1.01,.085,'f8ca62'),(1.08,.01,'ffdd79')],8)
        profile_solid(m,[(x+.04,.70),(x+.43,.77),(x+.04,.94)],z+.02,.05,'458f90')
    box(m,1.12,0,12.96,.13,.61,.15,'a87143')
    box(m,1.12,.45,12.96,1.06,.40,.14,'3f7e78',bevel=.06)
    # Small planted islands and grasses sit in the open pockets of the S-bends.
    for x,z,r in [(-1.25,3.92,.42),(.84,4.40,.5),(1.24,-4.64,.40),(-1.48,-3.2,.43),
                  (-5.9,3.85,.48),(6.75,-4.24,.53),(-2.4,11.40,.55),(1.37,10.47,.47)]:
        z=depth(z)
        for dx,dz,fac in [(-.47,.07,.72),(.43,-.08,.76),(0,0,1.0)]:
            pebble(m,x+dx*r,0,z+dz*r,r*fac,r*fac,'77ab4b')
        for i in range(4):
            a=i*1.57
            pebble(m,x+.39*r*math.cos(a),r*.86,z+.39*r*math.sin(a),.053,.067,'efacc0',6)
    rng=random.Random(4431)
    for cx,cz,spread in [(0,2.8,1.7),(0,-2.9,1.8),(0,6.4,1.7),(0,10.8,1.75),
                         (-6.2,3.4,.75),(6.2,3.7,.72),(-7,-3.5,.7),(7,-3.8,.7)]:
        for i in range(46):
            x=cx+rng.uniform(-spread,spread)
            z=depth(cz)+rng.uniform(-.9,.9)
            for k in range(3):
                xx=x+k*.064
                m.face([(xx-.039,.002,z),(xx+.038,.002,z),(xx+.09*(k-1),rng.uniform(.09,.18),z-.02)],'8bb64f')
    art.write_glb('trail_garden',{'Poiana':m})


if __name__=='__main__':
    pawn()
    garden()
