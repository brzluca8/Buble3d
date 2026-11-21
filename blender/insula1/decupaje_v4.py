"""
Insula 1, v4, Pasul 3: decupajele clădirilor din imaginea-țintă (reference/insula_tinta.jpg), pregătite pentru
generarea imagine -> 3D: la rezoluția maximă a imaginii, izolate de fundal (GrabCut, OpenCV), mărite de 3 ori
(Lanczos) și ascuțite (unsharp mask). Ordinea e cea din cerință: castel, poduri, piață, moară, atelier + debarcader,
barcă, portal.

    python blender/insula1/decupaje_v4.py        (are nevoie de opencv-python-headless)

Scrie în godot/assets/models/_decupaje/v4/: NN_nume.png (fundal transparent) și NN_nume_alb.png (pe alb), plus
docs/shots/insula_v4_decupaje.png (foaia de verificare). Nu folosește credite și nu trimite nimic nicăieri.
"""
import os

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "reference", "insula_tinta.jpg")
OUT = os.path.join(ROOT, "godot", "assets", "models", "_decupaje", "v4")
SHOT = os.path.join(ROOT, "docs", "shots", "insula_v4_decupaje.png")
# cutiile (x0, y0, x1, y1) în pixelii imaginii-țintă (1122 x 1402)
# opțional: dreptunghiuri (relative la cutie, 0..1) care sigur sunt fundal / sigur sunt obiectul
CUTII = [
    ("castel", (384, 280, 746, 640), [(0.0, 0.0, 0.2, 0.5), (0.85, 0.0, 1.0, 0.3)], [(0.3, 0.45, 0.7, 0.95)]),
    ("pod_arcuit", (270, 418, 396, 510), [(0.0, 0.0, 1.0, 0.12)], [(0.12, 0.3, 0.88, 0.62)]),
    ("piata", (754, 435, 978, 580), [], []),
    ("moara", (170, 34, 375, 293), [], []),
    ("atelier_debarcader", (160, 832, 482, 1092), [], []),
    ("barca", (478, 936, 676, 1130), [(0.0, 0.0, 0.22, 0.55)], [(0.35, 0.55, 0.8, 0.85)]),
    ("portal", (850, 148, 1000, 310), [], []),
]
SCARA = 3


def main():
    os.makedirs(OUT, exist_ok=True)
    full = cv2.imread(SRC)
    H, W = full.shape[:2]
    foi = []
    for k, (nume, (x0, y0, x1, y1), fundal, obiect) in enumerate(CUTII, 1):
        # o margine în jur, ca GrabCut să aibă fundal cert pe toate laturile
        m = int(0.08 * max(x1 - x0, y1 - y0))
        X0, Y0, X1, Y1 = max(0, x0 - m), max(0, y0 - m), min(W, x1 + m), min(H, y1 + m)
        img = full[Y0:Y1, X0:X1].copy()
        mask = np.zeros(img.shape[:2], np.uint8)
        rect = (x0 - X0, y0 - Y0, x1 - x0, y1 - y0)
        bgd, fgd = np.zeros((1, 65), np.float64), np.zeros((1, 65), np.float64)
        if fundal or obiect:
            mask[:] = cv2.GC_BGD
            mask[rect[1]:rect[1] + rect[3], rect[0]:rect[0] + rect[2]] = cv2.GC_PR_FGD
            for lista, val in ((fundal, cv2.GC_BGD), (obiect, cv2.GC_FGD)):
                for (a0, b0, a1, b1) in lista:
                    mask[rect[1] + int(b0 * rect[3]):rect[1] + int(b1 * rect[3]),
                         rect[0] + int(a0 * rect[2]):rect[0] + int(a1 * rect[2])] = val
            cv2.grabCut(img, mask, None, bgd, fgd, 10, cv2.GC_INIT_WITH_MASK)
        else:
            cv2.grabCut(img, mask, rect, bgd, fgd, 8, cv2.GC_INIT_WITH_RECT)
        fg = np.where((mask == cv2.GC_FGD) | (mask == cv2.GC_PR_FGD), 255, 0).astype(np.uint8)
        # cea mai mare componentă + găurile mici umplute, margine moale
        n, lab, st, _ = cv2.connectedComponentsWithStats(fg)
        if n > 1:
            big = 1 + int(np.argmax(st[1:, cv2.CC_STAT_AREA]))
            fg = np.where(lab == big, 255, 0).astype(np.uint8)
        fg = cv2.morphologyEx(fg, cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8))
        rgb = Image.fromarray(cv2.cvtColor(img, cv2.COLOR_BGR2RGB))
        a = Image.fromarray(fg).filter(ImageFilter.GaussianBlur(1.2))
        big_rgb = rgb.resize((rgb.width * SCARA, rgb.height * SCARA), Image.LANCZOS)
        big_rgb = big_rgb.filter(ImageFilter.UnsharpMask(radius=2.0, percent=80, threshold=2))
        big_a = a.resize(big_rgb.size, Image.LANCZOS)
        rgba = big_rgb.copy()
        rgba.putalpha(big_a)
        bbox = big_a.point(lambda v: 255 if v > 16 else 0).getbbox()
        if bbox:
            pad = 24
            bbox = (max(0, bbox[0] - pad), max(0, bbox[1] - pad), min(rgba.width, bbox[2] + pad), min(rgba.height, bbox[3] + pad))
            rgba = rgba.crop(bbox)
        alb = Image.new("RGBA", rgba.size, (255, 255, 255, 255))
        alb.alpha_composite(rgba)
        base = os.path.join(OUT, "%02d_%s" % (k, nume))
        rgba.save(base + ".png")
        alb.convert("RGB").save(base + "_alb.png")
        foi.append((nume, alb.convert("RGB")))
        print("[decupaj] %02d %-20s %dx%d -> %dx%d" % (k, nume, x1 - x0, y1 - y0, rgba.width, rgba.height), flush=True)
    # foaia de verificare
    Hh = 360
    ims = [(n, im.resize((int(im.width * Hh / im.height), Hh), Image.LANCZOS)) for n, im in foi]
    Wt = sum(im.width for _, im in ims) + 14 * (len(ims) + 1)
    out = Image.new("RGB", (Wt, Hh + 70), (240, 240, 244))
    d = ImageDraw.Draw(out)
    f = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 18)
    f2 = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 15)
    x = 14
    for k, (n, im) in enumerate(ims, 1):
        out.paste(im, (x, 14))
        d.text((x, Hh + 20), "%d. %s" % (k, n), font=f, fill=(60, 30, 90))
        x += im.width + 14
    d.text((14, Hh + 46), "Decupaje din reference/insula_tinta.jpg, izolate (GrabCut), mărite x3 (Lanczos + ascuțire), "
           "pentru generarea imagine->3D. Nu s-au folosit credite.", font=f2, fill=(70, 70, 70))
    out.save(SHOT)
    print("ok", SHOT)


if __name__ == "__main__":
    main()
