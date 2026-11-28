"""Original low-poly characters and props for Etapa 4.2, built with the in-house GLB pipeline.

Every part is its own node so the game can pivot it about a joint (rigid-part rig).
There is no skeleton: Godot animates the parts procedurally and through keyframe clips
(see scripts/board/lerik_animator.gd). A skinned model can replace these files later as long
as it keeps the node names.

    python3 tools/build_characters.py
"""
import math
import random
from pathlib import Path
import build_art as art
from build_art import Mesh, box, lathe, pebble, profile_solid

art.OUT = Path(__file__).resolve().parents[1] / 'assets' / 'board'


def slab(m, outline, z, depth, color):
    """Extruded flat shape visible from both sides (ears, wings, scarf ends)."""
    profile_solid(m, outline, z, depth, color)
    m.face([(x, y, z) for x, y in outline][::-1], color)
    m.face([(x, y, z - depth) for x, y in outline], color)
    m.face([(x, y, z - depth) for x, y in outline][::-1], color)


def quad2(m, points, color):
    """A quad visible from both sides."""
    m.face(points, color)
    m.face(points[::-1], color)


def lerik():
    """Lerik, same silhouette as the Etapa 2 pawn, split into animatable parts."""
    art.rng = random.Random(9101)
    parts = {name: Mesh() for name in ['Trunchi', 'Cap', 'Ochi', 'Ochelari', 'UrecheStanga', 'UrecheDreapta',
                                        'Rucsac', 'Coada', 'Esarfa', 'CapatEsarfa',
                                        'PiciorStang', 'PiciorDrept', 'BratStang', 'BratDrept']}
    m = parts['Trunchi']
    for x, name in [(-.18, 'PiciorStang'), (.18, 'PiciorDrept')]:
        leg = parts[name]
        pebble(leg, x, 0, .05, .17, .19, '765343', 8, 1.23)
        box(leg, x, .12, 0, .19, .23, .23, '506b78')
        box(leg, x, .02, .07, .17, .07, .1, '5a3a2c', bevel=.02)          # boot toe
    lathe(m, 0, .29, 0, [(0, .25, '8c644e'), (.09, .31, '59868b'), (.40, .28, '689fa1'), (.49, .19, 'e8aa5b')], 10)
    box(m, 0, .36, .02, .5, .05, .5, '6b4a33', bevel=.02)                 # belt
    box(m, 0, .355, .27, .09, .065, .03, 'e8c05a', bevel=.012)            # buckle
    # Backpack with a bedroll on top.
    pack = parts['Rucsac']
    pebble(pack, 0, .38, -.23, .28, .39, '9c6640', 8, .67)
    box(pack, 0, .58, -.38, .32, .08, .08, 'f4bd69')
    box(pack, 0, .66, -.32, .40, .11, .13, '6f9a4a', bevel=.05)
    box(pack, -.1, .45, -.47, .08, .12, .04, '7a4f30', bevel=.015)
    box(pack, .1, .45, -.47, .08, .12, .04, '7a4f30', bevel=.015)
    for x in (-.17, .17):
        art.box(pack, x, .32, -.02, .035, .36, .05, '6b4a33', bevel=.012)  # straps over the chest
    for x, name in [(-.32, 'BratStang'), (.32, 'BratDrept')]:
        arm = parts[name]
        pebble(arm, x, .40, .06, .14, .29, 'e3a261', 8)
        pebble(arm, x, .36, .07, .08, .08, 'f2c48c', 6)                  # paw
    head = parts['Cap']
    pebble(head, 0, .70, 0, .42, .63, 'eaa15a', 12, .82)
    for sign, ear in [(-1, 'UrecheStanga'), (1, 'UrecheDreapta')]:
        x = sign*.27
        outline = [(x-.12, 1.15), (x+.13, 1.15), (x+sign*.105, 1.52)]
        slab(parts[ear], outline, .035, .15, 'd38b50')
        tip = x+sign*.105
        slab(parts[ear], [(tip-.045, 1.43), (tip+.045, 1.43), (tip+sign*.036, 1.57)], .04, .08, '554645')
        slab(parts[ear], [(x-.06, 1.19), (x+.07, 1.19), (x+sign*.08, 1.42)], .045, .02, 'f6c99a')
        pebble(head, sign*.25, .82, .22, .145, .18, 'f2bf85', 7)
        box(parts['Ochi'], sign*.16, .965, .313, .075, .085, .048, '493f42', bevel=.018)
        box(parts['Ochi'], sign*.145, 1.02, .337, .022, .022, .01, 'ffffff', bevel=.005)
        box(parts['Ochelari'], sign*.158, 1.18, .255, .24, .16, .10, '8f5b39', bevel=.045)
        box(parts['Ochelari'], sign*.158, 1.21, .31, .175, .092, .06, '77c4cf', bevel=.024)
    pebble(head, 0, .79, .31, .15, .15, 'ffe4b5', 10, .55)
    box(head, 0, .918, .36, .11, .061, .05, '67484a', bevel=.021)
    box(parts['Ochelari'], 0, 1.23, .279, .14, .042, .08, 'd19a58')
    # Short lynx tail and a red scarf with a loose end.
    pebble(parts['Coada'], 0, .22, -.30, .085, .2, 'c98a52', 7)
    pebble(parts['Coada'], 0, .39, -.30, .06, .08, '554645', 6)
    lathe(parts['Esarfa'], 0, .69, 0, [(0, .25, 'bc5c49'), (.11, .28, 'e27856')], 10)
    slab(parts['CapatEsarfa'], [(.04, .46), (.2, .5), (.18, .75), (.07, .75)], -.22, .04, 'd2604c')
    art.write_glb('lerik', parts)


def pongo():
    """Pongo, the green builder: round body, yellow helmet with a gear, blue overalls, big hammer."""
    art.rng = random.Random(9202)
    parts = {name: Mesh() for name in ['Trunchi', 'Cap', 'Casca', 'Ochi', 'UrecheStanga', 'UrecheDreapta',
                                        'BratStang', 'BratDrept', 'Ciocan', 'PiciorStang', 'PiciorDrept']}
    body = parts['Trunchi']
    for x, name in [(-.15, 'PiciorStang'), (.15, 'PiciorDrept')]:
        pebble(parts[name], x, 0, .05, .14, .16, '5b3b2a', 8, 1.25)
        box(parts[name], x, .1, 0, .16, .16, .18, '3e63a8')
    lathe(body, 0, .22, 0, [(0, .22, '3e63a8'), (.12, .3, '4a74bd'), (.32, .27, '7fc35a'), (.42, .17, '7fc35a')], 12)
    box(body, 0, .3, .23, .26, .16, .06, '3e63a8', bevel=.02)            # bib
    box(body, 0, .2, .26, .42, .07, .08, '8a5a32', bevel=.02)            # tool belt
    box(body, .12, .18, .3, .07, .1, .05, 'c9cfd6', bevel=.01)
    for x, name in [(-.3, 'BratStang'), (.3, 'BratDrept')]:
        pebble(parts[name], x, .3, .04, .11, .25, '7fc35a', 8)
    head = parts['Cap']
    pebble(head, 0, .6, 0, .33, .46, '86cc5f', 12, .9)
    pebble(head, 0, .73, .27, .09, .1, '9bd876', 8)                       # round nose
    box(head, 0, .66, .29, .16, .04, .03, '5a2f2f', bevel=.012)          # grin
    box(head, 0, .645, .305, .06, .035, .02, 'e56b7a', bevel=.008)        # tongue
    for sign, ear in [(-1, 'UrecheStanga'), (1, 'UrecheDreapta')]:
        slab(parts[ear], [(sign*.3, .76), (sign*.3, .92), (sign*.58, .86)], .03, .06, '7fc35a')
        box(parts['Ochi'], sign*.12, .83, .27, .085, .095, .04, '2f2b30', bevel=.02)
        box(parts['Ochi'], sign*.105, .87, .29, .025, .025, .01, 'ffffff', bevel=.006)
    lathe(parts['Casca'], 0, .9, 0, [(0, .36, 'f3c33b'), (.05, .35, 'f3c33b'), (.18, .3, 'ffd65a'), (.27, .18, 'ffd65a'), (.31, 0, 'ffe07a')], 12)
    box(parts['Casca'], 0, .9, .27, .5, .04, .16, 'e7b22c', bevel=.015)   # brim
    lathe(parts['Casca'], 0, 1.04, .26, [(0, .07, 'ffffff'), (.03, .07, 'ffffff')], 8)  # gear badge
    ham = parts['Ciocan']
    box(ham, .42, .18, .06, .05, .55, .05, '8b5a33', bevel=.015)         # handle
    box(ham, .42, .7, .06, .26, .14, .16, '8e98a5', bevel=.035)          # head
    art.write_glb('pongo', parts)


def pufi():
    """Pufi, the small purple dragon: round belly, little wings, horns, curled tail."""
    art.rng = random.Random(9303)
    parts = {name: Mesh() for name in ['Trunchi', 'Cap', 'Ochi', 'AripaStanga', 'AripaDreapta', 'Coada',
                                        'BratStang', 'BratDrept', 'PiciorStang', 'PiciorDrept']}
    body = parts['Trunchi']
    lathe(body, 0, .12, 0, [(0, .2, 'a76bd6'), (.12, .3, 'b47de0'), (.32, .26, 'b47de0'), (.44, .14, 'a76bd6')], 12)
    lathe(body, 0, .16, .17, [(0, .12, 'ffe2b0'), (.16, .16, 'ffe8bf'), (.28, .09, 'ffe2b0')], 10, 0, .55)
    for x, name in [(-.15, 'PiciorStang'), (.15, 'PiciorDrept')]:
        pebble(parts[name], x, 0, .05, .11, .16, '9a5fca', 8, 1.2)
    for x, name in [(-.26, 'BratStang'), (.26, 'BratDrept')]:
        pebble(parts[name], x, .3, .1, .07, .15, 'b47de0', 7)
    head = parts['Cap']
    pebble(head, 0, .52, .02, .3, .4, 'b985e4', 12, .95)
    pebble(head, 0, .62, .25, .14, .12, 'c99af0', 10, .7)               # snout
    for sign in (-1, 1):
        pebble(head, sign*.05, .69, .33, .022, .03, '5a3478', 5)          # nostrils
        lathe(head, sign*.13, .86, -.03, [(0, .055, 'fff0c8'), (.16, 0, 'ffe39a')], 6)  # horns
        box(parts['Ochi'], sign*.12, .73, .23, .085, .1, .04, '2d2333', bevel=.02)
        box(parts['Ochi'], sign*.105, .77, .25, .025, .025, .01, 'ffffff', bevel=.006)
    for sign, wing in [(-1, 'AripaStanga'), (1, 'AripaDreapta')]:
        outline = [(sign*.2, .24), (sign*.62, .3), (sign*.5, .4), (sign*.66, .56), (sign*.4, .52), (sign*.24, .42)]
        slab(parts[wing], outline, -.1, .025, 'f39ac6')
        slab(parts[wing], [(sign*.24, .4), (sign*.62, .54), (sign*.6, .58), (sign*.22, .44)], -.08, .02, 'c26aa0')
    tail = parts['Coada']
    for i in range(5):
        a = i*.5
        pebble(tail, math.sin(a)*.12, .12+i*.03, -.24-i*.07, .08-i*.012, .12, 'a76bd6', 6)
    lathe(tail, math.sin(2.5)*.12, .27, -.6, [(0, .06, 'f0a0c8'), (.1, 0, 'f0a0c8')], 4)
    art.write_glb('pufi', parts)


def chest(kind):
    """A stylised 3D chest for the opening screen. Parts: Corp, Capac (lid, hinged at the back),
    Lacat, Interior (glow surface), and tier decorations on the lid so they move with it."""
    art.rng = random.Random({'wood': 9401, 'silver': 9402, 'gold': 9403}[kind])
    tone = {
        'wood':   dict(base='b5733a', light='d69455', dark='6a3a16', metal='7f8791', trim='8b919b'),
        'silver': dict(base='c8d7e6', light='f1f7ff', dark='5f7690', metal='5fe0cf', trim='9db1c6'),
        'gold':   dict(base='f4b52f', light='ffe08a', dark='a8690c', metal='d88a12', trim='fff0a8'),
    }[kind]
    parts = {name: Mesh() for name in ['Corp', 'Capac', 'Lacat', 'Interior']}
    body, lid = parts['Corp'], parts['Capac']
    W, D, H = 1.3, .86, .6
    box(body, 0, 0, 0, W, H, D, tone['base'], bevel=.07)
    box(body, 0, -.02, 0, W+.06, .09, D+.06, tone['dark'], bevel=.03)     # plinth
    for x in (-.43, .43):
        box(body, x, -.01, 0, .14, H+.02, D+.04, tone['metal'], bevel=.025)  # vertical bands
    if kind == 'wood':
        for y in (.17, .34, .5):
            box(body, 0, y, D/2-.02, W-.08, .02, .04, tone['dark'], bevel=.006)   # plank seams
    else:
        box(body, 0, .44, D/2-.01, W-.12, .05, .04, tone['light'], bevel=.012)    # bevel highlight
    box(parts['Interior'], 0, H-.06, 0, W-.14, .05, D-.14, 'ffe9a8', bevel=.02)
    # Arched lid: hinge line at the back top edge (z = -D/2, y = H). Built as stacked slabs.
    steps = 7
    for i in range(steps):
        a0, a1 = math.pi*i/steps, math.pi*(i+1)/steps
        z0, z1 = -math.cos(a0)*D/2, -math.cos(a1)*D/2
        y0, y1 = H + math.sin(a0)*.32, H + math.sin(a1)*.32
        color = tone['light'] if i in (2, 3, 4) else tone['base']
        quad2(lid, [(-W/2, y0, z0), (-W/2, y1, z1), (W/2, y1, z1), (W/2, y0, z0)], color)
        quad2(lid, [(-W/2, H, z0), (-W/2, y0, z0), (-W/2, y1, z1), (-W/2, H, z1)], tone['dark'])
        quad2(lid, [(W/2, H, z0), (W/2, y0, z0), (W/2, y1, z1), (W/2, H, z1)], tone['dark'])
    for x in (-.43, .43):
        for i in range(steps):
            a0, a1 = math.pi*i/steps, math.pi*(i+1)/steps
            z0, z1 = -math.cos(a0)*(D/2+.025), -math.cos(a1)*(D/2+.025)
            y0, y1 = H + math.sin(a0)*.345, H + math.sin(a1)*.345
            quad2(lid, [(x-.07, y0, z0), (x-.07, y1, z1), (x+.07, y1, z1), (x+.07, y0, z0)], tone['metal'])
    box(lid, 0, H-.03, D/2-.02, W+.02, .07, .06, tone['dark'], bevel=.02)  # lid rim
    lock = parts['Lacat']
    box(lock, 0, .25, D/2+.02, .24, .3, .07, tone['trim'], bevel=.04)
    box(lock, 0, .3, D/2+.06, .07, .1, .03, tone['dark'], bevel=.01)
    if kind == 'silver':
        for x in (-.2, .2):
            box(lid, x, H+.27, .05, .08, .08, .08, tone['metal'], bevel=.03)      # turquoise studs
        box(lid, 0, H+.31, 0, .22, .05, .22, tone['metal'], bevel=.02)
    if kind == 'gold':
        for x, c in [(-.25, 'ff4d6d'), (0, '4dd0ff'), (.25, '6bf08f')]:
            box(lid, x, H+.3, .02, .13, .09, .13, c, bevel=.04)                    # gems
        lathe(lid, 0, H+.34, -.02, [(0, .09, 'fff0a8'), (.08, .11, 'ffd65a'), (.16, .0, 'ffe07a')], 5)  # crown spike
        for x in (-.55, .55):
            box(body, x, .2, .3, .1, .1, .1, 'ff4d6d', bevel=.04)
    art.write_glb('chest_' + kind, parts)


if __name__ == '__main__':
    lerik()
    pongo()
    pufi()
    for k in ('wood', 'silver', 'gold'):
        chest(k)
