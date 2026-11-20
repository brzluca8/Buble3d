"""
Imaginile de comparație ale Fazei A (PIL), din capturile tale din Godot (reference/) și randările v3
(previzualizare_v3.py):
  insula_v3_A_inainte_dupa_1.png  captura ta 1 | v3 din același unghi
  insula_v3_A_inainte_dupa_2.png  captura ta 2 | v3 din același unghi
  insula_v3_A_orion_si_insula.png Orion și insula din jurul lui, mărite, înainte și după (aceeași scară)

    python blender/insula1/compara_v3.py
"""
import os

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
R = os.path.join(ROOT, "reference")
S = os.path.join(ROOT, "docs", "shots")
FONTS = "/usr/share/fonts/truetype/dejavu/"
F = ImageFont.truetype(FONTS + "DejaVuSans-Bold.ttf", 26)
F2 = ImageFont.truetype(FONTS + "DejaVuSans.ttf", 19)
MOV = (76, 29, 110)
NOTA = ("Stânga: captura ta din Godot (înainte). Dreapta: randare Blender a Fazei A, din același unghi (estimat), "
        "NU captură din Godot; apa, vântul și estomparea sunt statice sau lipsesc aici.")


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


def row(ims_labels, H, note):
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


def captura(i, nume):
    im = Image.open(os.path.join(R, f"captura_godot_{i}_{nume}.jpg")).convert("RGB")
    return im.crop((0, 120, im.width, im.height))  # fără bara de unelte a editorului


def main():
    for i, nume in [(1, "start"), (2, "aproape")]:
        a = captura(i, nume)
        b = Image.open(os.path.join(S, f"insula_v3_A_captura{i}.png")).convert("RGB")
        row([(a, "Înainte (Godot)"), (b, "Faza A (Blender)")], 980, NOTA).save(os.path.join(S, f"insula_v3_A_inainte_dupa_{i}.png"))
    # Orion și insula din jurul lui, la aceeași scară (decupaj din cadrul 2, mărit)
    a = captura(2, "aproape")
    b = Image.open(os.path.join(S, "insula_v3_A_captura2.png")).convert("RGB")
    a = a.resize(b.size, Image.LANCZOS)
    W, H = b.size
    box = (int(W * 0.30), int(H * 0.30), int(W * 0.95), int(H * 0.80))
    ca = a.crop(box)
    cb = b.crop(box)
    row([(ca, "Înainte (Godot)"), (cb, "Faza A (Blender)")], 700,
        "Orion și insula de lângă el, din același cadru, mărite la fel. Orion e modelul de referință pentru claritate. "
        + NOTA).save(os.path.join(S, "insula_v3_A_orion_si_insula.png"))
    print("ok")


if __name__ == "__main__":
    main()
