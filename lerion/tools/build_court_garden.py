"""Small flower borders and heraldic lanterns for the six existing clearings."""
import math
from pathlib import Path

import build_art as art

art.OUT = Path(__file__).resolve().parents[1] / "assets" / "board"


def garden():
    plants = art.Mesh()
    pennants = art.Mesh()
    plots = [(-6.05, -6.45), (6.05, -6.45), (-6.30, .20),
             (6.30, .20), (-5.28, 9.37), (5.28, 9.37)]
    silks = ["59bccb", "f7ac54", "dc8555", "b389dc", "ea857e", "798fd4"]
    for index, (x, z) in enumerate(plots):
        side = math.copysign(1, x)
        for j in range(9):
            angle = (j - 4) * .22
            xx = x + side * 1.80 * math.cos(angle)
            zz = z + 1.80 * math.sin(angle)
            art.pebble(plants, xx, .026, zz, .19, .17, ["829e58", "97ad60"][j % 2], 6)
            if j % 2 == 0:
                for k in range(3):
                    a = 2.1 * k + j
                    art.pebble(plants, xx + .10 * math.cos(a), .17, zz + .09 * math.sin(a),
                               .076, .08, ["ffdd99", "f5b5c1", "f2e9cb"][k], 5)
        xx, zz = x + side * 1.71, z + .67
        art.lathe(pennants, xx, .02, zz, [(0,.16,"997c62"), (.15,.145,"d4b787"),
                  (.17,.064,"ba8755"), (1.00,.049,"c39260"), (1.04,.12,"865a59"),
                  (1.23,.10,"ffe3a1"), (1.29,.14,"476d80"), (1.43,.018,"6f96a0")], 8)
        art.box(pennants,xx - side*.16,.93,zz,.44,.055,.06,"e5b376")
        cloth = [(xx-side*.05,.93), (xx-side*.39,.93), (xx-side*.39,.58),
                 (xx-side*.23,.48), (xx-side*.05,.58)]
        if side < 0:
            cloth.reverse()
        art.profile_solid(pennants,cloth,zz+.028,.055,silks[index])
        art.pebble(pennants,xx-side*.22,.70,zz+.056,.065,.095,"ffdf8e",5,.35)
    art.write_glb("court_garden", {"Borduri": plants, "Felinare": pennants})


if __name__ == "__main__":
    garden()
