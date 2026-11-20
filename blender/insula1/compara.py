"""
Imagini de comparație pentru docs/shots (PIL), din previzualizările făcute cu previzualizare.py:
  compara_panorama.png  ținta | înainte | după
  compara_aproape.png   înainte | după (camera de joc lângă START)
  compara_claritate.png aceeași bucată din cadrul „aproape”, mărită, înainte și după

    python blender/insula1/compara.py
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
NOTA = "Previzualizări randate în Blender (Cycles) cu modelele jocului, NU capturi din Godot; apa e statică aici."


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


def row(items, H, note=None):
    ims = []
    for path, label in items:
        im = Image.open(path).convert("RGB")
        ims.append((im.resize((int(im.width * H / im.height), H), Image.LANCZOS), label))
    W = sum(i.width for i, _ in ims) + 12 * (len(ims) + 1)
    d0 = ImageDraw.Draw(Image.new("RGB", (8, 8)))
    lines = wrap(d0, note, F2, W - 28) if note else []
    top = 52
    out = Image.new("RGB", (W, H + top + 14 + 26 * len(lines)), "white")
    d = ImageDraw.Draw(out)
    x = 12
    for im, lab in ims:
        out.paste(im, (x, top))
        tw = d.textlength(lab, font=F)
        d.rounded_rectangle([x + im.width / 2 - tw / 2 - 16, 8, x + im.width / 2 + tw / 2 + 16, 46], radius=19, fill=MOV)
        d.text((x + im.width / 2 - tw / 2, 12), lab, font=F, fill="white")
        x += im.width + 12
    for k, line in enumerate(lines):
        d.text((14, H + top + 8 + 26 * k), line, font=F2, fill=(60, 60, 60))
    return out


def main():
    row([(os.path.join(R, "insula_tinta.jpg"), "Ținta (desenul)"), (os.path.join(S, "insula1_vechi_panorama.png"), "Înainte"),
         (os.path.join(S, "insula1_nou_panorama.png"), "După")], 900, NOTA).save(os.path.join(S, "compara_panorama.png"))
    row([(os.path.join(S, "insula1_vechi_aproape.png"), "Înainte"), (os.path.join(S, "insula1_nou_aproape.png"), "După"),
         (os.path.join(S, "insula1_nou_aproape_aterizare.png"), "După + aterizare")], 900, NOTA).save(
        os.path.join(S, "compara_aproape.png"))
    # claritate: aceeași bucată (castelul, podul, căsuțele din fața lui Orion), mărită de 2 ori
    a = Image.open(os.path.join(S, "insula1_vechi_aproape.png")).convert("RGB")
    b = Image.open(os.path.join(S, "insula1_nou_aproape.png")).convert("RGB")
    W, H = a.size
    box = (int(W * 0.05), int(H * 0.08), int(W * 0.62), int(H * 0.40))
    ca = a.crop(box).resize(((box[2] - box[0]) * 2, (box[3] - box[1]) * 2), Image.LANCZOS)
    cb = b.crop(box).resize(((box[2] - box[0]) * 2, (box[3] - box[1]) * 2), Image.LANCZOS)
    tmp =os.path.join(S, "_tmp_claritate.png")
    ca.save(tmp)
    tmp2 = os.path.join(S, "_tmp_claritate2.png")
    cb.save(tmp2)
    row([(tmp, "Înainte (textura 2048, 28 px/m)"), (tmp2, "După (4096 din mărirea AI, 56 px/m)")], ca.height,
        "Aceeași bucată din cadrul de joc, mărită de 2 ori. " + NOTA).save(os.path.join(S, "compara_claritate.png"))
    os.remove(tmp)
    os.remove(tmp2)
    print("ok")


if __name__ == "__main__":
    main()
