"""
Planșa de expresii a lui Orion: rulează orion_build.py o dată pentru fiecare expresie
(prim-plan pe față) și le pune pe un rând, cu etichete, ca în planșa de personaj.

    python orion_expresii.py --out out [--res 0.0075 --fur 420000 --samples 64 --size 900]
"""
import argparse
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
EXPR = [("happy", "Bucuros"), ("surprised", "Surprins"), ("laugh", "Râzând"), ("determined", "Determinat"),
        ("angry", "Furios"), ("wink", "Clipire / Wink")]

ap = argparse.ArgumentParser()
ap.add_argument("--out", default=os.path.join(HERE, "out"))
ap.add_argument("--res", default="0.0075")
ap.add_argument("--fur", default="420000")
ap.add_argument("--samples", default="64")
ap.add_argument("--size", type=int, default=900)
ap.add_argument("--only-compose", action="store_true")
a = ap.parse_args()

if not a.only_compose:
    for key, _ in EXPR:
        subprocess.run([sys.executable, os.path.join(HERE, "orion_build.py"), "--out", a.out, "--res", a.res,
                        "--fur", a.fur, "--samples", a.samples, "--size", str(a.size), "--expr", key,
                        "--render", "expr", "--no-blend", "--no-glb"], check=True)

from PIL import Image, ImageDraw, ImageFont  # noqa: E402

ims = [Image.open(os.path.join(a.out, f"orion_expr_{k}.png")).convert("RGB") for k, _ in EXPR]
w, h = ims[0].size
gap = w // 20
label_h = h // 7
sheet = Image.new("RGB", (len(ims) * (w + gap) + gap, h + label_h + gap * 2), (255, 255, 255))
d = ImageDraw.Draw(sheet)
font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", int(label_h * 0.36))
purple = (76, 29, 110)
for i, (im, (_, lab)) in enumerate(zip(ims, EXPR)):
    x = gap + i * (w + gap)
    sheet.paste(im, (x, gap))
    tw = d.textlength(lab, font=font)
    cx, y0, ph = x + w / 2, gap + h + label_h * 0.15, label_h * 0.6
    d.rounded_rectangle([cx - tw / 2 - ph * 0.6, y0, cx + tw / 2 + ph * 0.6, y0 + ph], radius=ph / 2, fill=purple)
    d.text((cx - tw / 2, y0 + ph * 0.13), lab, font=font, fill=(255, 255, 255))
path = os.path.join(a.out, "orion_expresii.png")
sheet.save(path)
for k, _ in EXPR:  # the single white-background images live on only inside the sheet (transparent/ keeps them)
    os.remove(os.path.join(a.out, f"orion_expr_{k}.png"))
print("[expresii]", path)
