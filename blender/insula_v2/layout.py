"""Island 1 v2 layout: where things are (Blender coordinates: x right, y back, z up; metres).
Positions were measured on the v1 island (blender/out_insula1/insula1.glb, same frame as the board tiles)."""

# hero props: name, glb, (x, y), rotation about z in degrees (0 = facing the camera / -y), footprint radius, phase
HERO = [
    dict(name="castel", x=0.25, y=0.55, rot=0, r=3.0, faza=3),
    dict(name="moara", x=-3.1, y=7.75, rot=-20, r=1.6, faza=2),
    dict(name="portal", x=6.7, y=5.8, rot=-35, r=1.5, faza=3),
    dict(name="piata", x=5.4, y=0.3, rot=-90, r=1.9, faza=2),
    dict(name="atelier", x=-5.3, y=-7.1, rot=30, r=1.7, faza=2),
    dict(name="debarcader", x=-2.8, y=-8.0, rot=10, r=1.6, faza=3),
    dict(name="barca", x=-0.55, y=-9.3, rot=-80, r=1.2, faza=3),
    dict(name="pod", x=-2.15, y=3.3, rot=-34, r=1.5, faza=1, id="pod_sus"),
    dict(name="pod", x=-3.66, y=-1.7, rot=28, r=1.5, faza=1, id="pod_jos"),
]

# big single trees (not instanced: one each)
BIG_TREE = dict(x=5.0, y=6.9, r=2.2)
HILL = dict(x=1.1, y=9.6, r=2.6)  # rocky hill with the waterfall (terrain)

# castle mound (round raised plateau with a stone wall) and the moat around it
MOUND = dict(x=0.15, y=0.6, r=4.3)

# waterfalls: top (x, y), drop direction (dx, dy) in the plane, width; "nori" = falls off the island into the clouds
WATERFALLS = [
    dict(name="deal", x=0.6, y=8.0, dx=0.0, dy=-1.0, w=1.1),           # from the hill into the river
    dict(name="dreapta_fata", x=5.2, y=-8.6, dx=0.55, dy=-0.85, w=1.6, nori=True),  # big one off the front edge
    dict(name="laguna", x=-0.2, y=-10.9, dx=0.0, dy=-1.0, w=1.2, nori=True),       # lagoon overflow
]
