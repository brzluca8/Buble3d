"""
Imaginile de comparație ale v4 (PIL), din randările Blender (previzualizare_v3.py / previzualizare_v4.py):
  insula_v4_camera_AB.png   camera de joc veche | camera de joc nouă (D4) | cadrul apropiat de la aterizare
  (alte panouri se adaugă cu --panou nume_iesire:imagine1|eticheta1,imagine2|eticheta2 ... --nota "text")

    python blender/insula1/compara_v4.py -- --src <dosarul cu randări> [--out docs/shots]
NU sunt capturi din Godot: randări Blender care imită shaderele jocului.
"""
import argparse
import os
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
FONTS = "/usr/share/fonts/truetype/dejavu/"
F = ImageFont.truetype(FONTS + "DejaVuSans-Bold.ttf", 26)
F2 = ImageFont.truetype(FONTS + "DejaVuSans.ttf", 19)
MOV = (76, 29, 110)
NOTA_BLENDER = "Randări Blender care imită shaderele din joc, NU capturi din Godot (apa, vântul și estomparea sunt statice aici)."


def wrap(d, text, font, width):
    lines, cur = [], ""
    for w in text.split(" "):
        t = (cur + " " + w).strip()
        if d.textlength(t, font=font) <= width:
            cur = t
        else:
            lines.append(cur)
            cur = w
    return lines + [cur]


def rand(ims_labels, H, note):
    ims = [(im.resize((int(im.width * H / im.height), H), Image.LANCZOS), lab) for im, lab in ims_labels]
    W = sum(i.width for i, _ in ims) + 12 * (len(ims) + 1)
    d0 = ImageDraw.Draw(Image.new("RGB", (8, 8)))
    lines = wrap(d0, note, F2, W - 28)
    out = Image.new("RGB", (W, H + 52 + 14 + 26 * len(lines)), "white")
    d = ImageDraw.Draw(out)
    x = 12
    for im, lab in ims:
        out.paste(im, (x, 52))
        tw = d.textlength(lab, font=F)
        d.rounded_rectangle([x + im.width / 2 - tw / 2 - 16, 8, x + im.width / 2 + tw / 2 + 16, 46], radius=19, fill=MOV)
        d.text((x + im.width / 2 - tw / 2, 12), lab, font=F, fill="white")
        x += im.width + 12
    for k, line in enumerate(lines):
        d.text((14, H + 60 + 26 * k), line, font=F2, fill=(60, 60, 60))
    return out


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True)
    ap.add_argument("--out", default=os.path.join(ROOT, "docs", "shots"))
    ap.add_argument("--camera", action="store_true", help="doar A/B-ul camerei (D4)")
    ap.add_argument("--panou", action="append", default=[])
    ap.add_argument("--nota", default="")
    ap.add_argument("--inaltime", type=int, default=900)
    a = ap.parse_args(argv)
    os.makedirs(a.out, exist_ok=True)
    if a.camera:
        p = lambda n: Image.open(os.path.join(a.src, n)).convert("RGB")  # noqa: E731
        rand([(p("insula_v4_p1_joc_vechi.png"), "Înainte: camera veche"),
              (p("insula_v4_p1_joc_nou.png"), "După: camera de joc (D4)"),
              (p("insula_v4_p1_aterizare.png"), "Aterizare: cadrul apropiat")], a.inaltime,
             "Același cadru de START, format portret ca pe telefon (720×1280). Camera nouă stă în spatele lui Orion, pe "
             "direcția drumului, la ~50°, și privește 3 m înainte: Orion ajunge în sfertul de jos al ecranului și se văd "
             "căsuțele următoare. La aterizare camera intră în cadrul apropiat (~2,6 s), apoi revine. " + NOTA_BLENDER
             ).save(os.path.join(a.out, "insula_v4_camera_AB.png"))
        print("ok camera")
    for spec in a.panou:
        nume, lista = spec.split(":", 1)
        ims = []
        for item in lista.split(","):
            cale, et = item.split("|")
            ims.append((Image.open(cale if os.path.isabs(cale) else os.path.join(a.src, cale)).convert("RGB"), et))
        rand(ims, a.inaltime, (a.nota + " " + NOTA_BLENDER).strip()).save(os.path.join(a.out, nume))
        print("ok", nume)


if __name__ == "__main__":
    main()
