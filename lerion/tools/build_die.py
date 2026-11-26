"""Build the original rounded, inlaid die as a single vertex-painted mesh."""
import math
from pathlib import Path

import build_art as art

art.OUT = Path(__file__).resolve().parents[1] / "assets" / "board"
# Local right/up pairs cross towards the outward face normal; opposite faces sum to 7.
FACES = [
    ((1, 0, 0), (0, 1, 0)), ((0, 0, -1), (0, 1, 0)),
    ((1, 0, 0), (0, 0, -1)), ((1, 0, 0), (0, 0, 1)),
    ((0, 0, 1), (0, 1, 0)), ((-1, 0, 0), (0, 1, 0)),
]
PIPS = [
    [(0, 0)], [(-1, 1), (1, -1)], [(-1, 1), (0, 0), (1, -1)],
    [(-1, 1), (1, 1), (-1, -1), (1, -1)],
    [(-1, 1), (1, 1), (0, 0), (-1, -1), (1, -1)],
    [(x, y) for x in (-1, 1) for y in (-1, 0, 1)],
]


def build():
    mesh = art.Mesh()
    grid = [-.5, -.455, -.39, .39, .455, .5]
    for face, (right, up) in enumerate(FACES):
        normal = art.normal((0, 0, 0), right, up)

        def point(x, y, depth):
            return [x*r + y*u + depth*n for r, u, n in zip(right, up, normal)]

        def shell(x, y):
            p = point(x, y, .5)
            core = [max(-.39, min(.39, i)) for i in p]
            length = math.dist(p, core)
            return [c + (v-c)*.11/length for v, c in zip(p, core)]

        for x, xx in zip(grid, grid[1:]):
            for y, yy in zip(grid, grid[1:]):
                mesh.face([shell(x,y), shell(xx,y), shell(xx,yy), shell(x,yy)], "fff0cb")
        for x, y in PIPS[face]:
            def ring(radius, height):
                return [point(x*.233 + radius*math.cos(i*math.tau/16),
                              y*.233 + radius*math.sin(i*math.tau/16), height)
                        for i in range(16)]
            outer = ring(.111, .502)
            inner = ring(.087, .503)
            for i in range(16):
                j = (i+1) % 16
                mesh.face([outer[i],outer[j],inner[j],inner[i]], "bd935c")
            mesh.face(inner, "a13a36" if face == 0 else "25344d")
    art.write_glb("die", {"Zar":mesh})


if __name__ == "__main__":
    build()
