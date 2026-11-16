"""Pune interfața paginii „Mașina de bule” peste randarea 3D (concept, PIL).

python3 art/concept/slot_ui.py <randare.png> <dosar_fonturi_ttf> <iesire.png>
Fonturile: Nunito (OFL), convertite din godot/assets/fonts în .ttf.
Icoanele: Lucide (ISC) din godot/assets/icons.
"""
import os
import sys

from fontTools.ttLib import TTFont
from PIL import Image, ImageDraw, ImageFilter, ImageFont

SRC, FONTS, OUT = sys.argv[1:4]
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ICONS = os.path.join(ROOT, "godot", "assets", "icons")

base = Image.open(SRC).convert("RGBA")
S = base.width / 720.0
W, H = base.size


def px(v):
    return int(round(v * S))


_F = {}
_CMAP = {}


def font(w, size):
    key = (w, size)
    if key not in _F:
        a = os.path.join(FONTS, "nunito-latin-%d-normal.ttf" % w)
        b = os.path.join(FONTS, "nunito-latin-ext-%d-normal.ttf" % w)
        _F[key] = (ImageFont.truetype(a, px(size)), ImageFont.truetype(b, px(size)))
        for p in (a, b):
            if p not in _CMAP:
                _CMAP[p] = set(TTFont(p).getBestCmap().keys())
        _F[key] += (_CMAP[a],)
    return _F[key]


def runs(text, w, size):
    fa, fb, ca = font(w, size)
    out = []
    for ch in text:
        f = fa if ord(ch) in ca or ch == " " else fb
        if out and out[-1][1] is f:
            out[-1][0] += ch
        else:
            out.append([ch, f])
    return out


def text_w(text, w, size):
    return sum(f.getlength(t) for t, f in runs(text, w, size))


def text(d, xy, s, w, size, fill, anchor="l", stroke=0, stroke_fill=None):
    x, y = px(xy[0]), px(xy[1])
    tw = text_w(s, w, size)
    if anchor == "c":
        x -= tw / 2
    elif anchor == "r":
        x -= tw
    for t, f in runs(s, w, size):
        d.text((x, y), t, font=f, fill=fill, anchor="lm", stroke_width=px(stroke), stroke_fill=stroke_fill)
        x += f.getlength(t)


def icon(img, name, xy, size, color=(255, 255, 255, 255)):
    ic = Image.open(os.path.join(ICONS, name + ".png")).convert("RGBA").resize((px(size), px(size)), Image.LANCZOS)
    tint = Image.new("RGBA", ic.size, color)
    tint.putalpha(ic.getchannel("A"))
    img.alpha_composite(tint, (px(xy[0] - size / 2), px(xy[1] - size / 2)))


def glass(img, box, r, fill=(40, 22, 90, 150), outline=(255, 255, 255, 90), blur=True):
    x0, y0, x1, y1 = [px(v) for v in box]
    if blur:
        reg = img.crop((x0, y0, x1, y1)).filter(ImageFilter.GaussianBlur(px(10)))
        m = Image.new("L", reg.size, 0)
        ImageDraw.Draw(m).rounded_rectangle((0, 0, reg.width - 1, reg.height - 1), px(r), fill=255)
        img.paste(reg, (x0, y0), m)
    lay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(lay).rounded_rectangle((x0, y0, x1, y1), px(r), fill=fill, outline=outline, width=max(1, px(1.5)))
    img.alpha_composite(lay)


def shadow(img, box, r, off=6, a=90):
    lay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    x0, y0, x1, y1 = [px(v) for v in box]
    ImageDraw.Draw(lay).rounded_rectangle((x0, y0 + px(off), x1, y1 + px(off)), px(r), fill=(30, 10, 60, a))
    img.alpha_composite(lay.filter(ImageFilter.GaussianBlur(px(8))))


def grad_rr(img, box, r, top, bot, outline=None, ow=2):
    x0, y0, x1, y1 = [px(v) for v in box]
    g = Image.new("RGBA", (x1 - x0, y1 - y0))
    gd = ImageDraw.Draw(g)
    for yy in range(g.height):
        t = yy / max(1, g.height - 1)
        gd.line([(0, yy), (g.width, yy)], fill=tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(4)))
    m = Image.new("L", g.size, 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, g.width - 1, g.height - 1), px(r), fill=255)
    img.paste(g, (x0, y0), m)
    if outline:
        ImageDraw.Draw(img).rounded_rectangle((x0, y0, x1, y1), px(r), outline=outline, width=px(ow))


img = base.copy()
# ușoară vignetă sus și jos ca textul să se citească
v = Image.new("RGBA", img.size, (0, 0, 0, 0))
vd = ImageDraw.Draw(v)
for yy in range(px(230)):
    vd.line([(0, yy), (W, yy)], fill=(36, 18, 84, int(150 * (1 - yy / px(230)) ** 1.6)))
for yy in range(px(380)):
    vd.line([(0, H - yy), (W, H - yy)], fill=(36, 18, 84, int(225 * (1 - yy / px(380)) ** 1.3)))
img.alpha_composite(v)
d = ImageDraw.Draw(img)

WHITE = (255, 255, 255, 255)
GOLD = (255, 205, 80, 255)
INK = (40, 22, 90, 255)

# ---------------- bara de sus: înapoi, titlu, șanse
for cx, ic in ((48, "house"), (672, "circle-help")):
    shadow(img, (cx - 30, 26, cx + 30, 86), 30, 4, 70)
    glass(img, (cx - 30, 26, cx + 30, 86), 30)
    icon(img, ic, (cx, 56), 28)
text(d, (360, 46), "Mașina de bule", 900, 34, WHITE, "c", 2, (60, 30, 120, 160))
text(d, (360, 78), "Grădina dintre nori · nivelul 7", 700, 17, (255, 230, 250, 230), "c")
text(d, (48, 100), "Oraș", 800, 14, (255, 255, 255, 220), "c")
text(d, (672, 100), "Șanse", 800, 14, (255, 255, 255, 220), "c")

# ---------------- resurse
def pill(x0, x1, ic, col, val, sub=None):
    shadow(img, (x0, 122, x1, 166), 22, 3, 60)
    glass(img, (x0, 122, x1, 166), 22)
    d.ellipse((px(x0 + 4), px(126), px(x0 + 40), px(162)), fill=col)
    icon(img, ic, (x0 + 22, 144), 22)
    text(d, (x0 + 50, 143 if not sub else 137), val, 900, 21, WHITE)
    if sub:
        text(d, (x0 + 50, 157), sub, 700, 11, (220, 210, 255, 255))


pill(110, 290, "coins", (240, 170, 30, 255), "18.540")
pill(302, 432, "gem", (255, 95, 168, 255), "12")
pill(444, 614, "zap", (53, 196, 106, 255), "42/50", "+1 în 07:12")

# ---------------- câștigul (fereastra rolelor e liberă)
lay = Image.new("RGBA", img.size, (0, 0, 0, 0))
ld = ImageDraw.Draw(lay)
ld.ellipse((px(170), px(205), px(550), px(300)), fill=(255, 200, 60, 120))
img.alpha_composite(lay.filter(ImageFilter.GaussianBlur(px(28))))
grad_rr(img, (200, 214, 520, 290), 38, (255, 228, 120, 255), (236, 150, 20, 255), (255, 250, 220, 255), 3)
d = ImageDraw.Draw(img)
text(d, (360, 238), "TREI MONEDE · ×3", 900, 17, (120, 50, 0, 255), "c")
icon(img, "coins", (262, 266), 30, (120, 50, 0, 255))
text(d, (375, 266), "+7.200", 900, 34, WHITE, "c", 3, (170, 80, 0, 255))

# ---------------- panoul de jos
glass(img, (24, 1004, 696, 1060), 28, (40, 22, 90, 170))
icon(img, "sparkles", (58, 1032), 24, GOLD)
text(d, (82, 1023), "Festivalul luminilor", 900, 17, WHITE)
text(d, (82, 1045), "etapa 3 din 8 · încă 4 zile", 700, 13, (220, 210, 255, 255))
d.rounded_rectangle((px(330), px(1025), px(600), px(1039)), px(7), fill=(255, 255, 255, 60))
d.rounded_rectangle((px(330), px(1025), px(330 + 270 * 0.62), px(1039)), px(7), fill=GOLD)
text(d, (612, 1032), "62%", 900, 15, WHITE)
icon(img, "gift", (668, 1032), 24, GOLD)

# multiplicator (stânga), buton mare (centru), automat (dreapta)
for cx, top, bot, label, sub in ((88, (154, 112, 255, 255), (98, 58, 200, 255), "×3", "pariu"),
                                 (632, (60, 210, 200, 255), (20, 140, 150, 255), "Auto", "oprit")):
    shadow(img, (cx - 54, 1092, cx + 54, 1200), 30, 5, 90)
    grad_rr(img, (cx - 54, 1092, cx + 54, 1200), 30, top, bot, (255, 255, 255, 140), 2)
    d = ImageDraw.Draw(img)
    text(d, (cx, 1136), label, 900, 32 if label.startswith("×") else 26, WHITE, "c", 2, (40, 20, 90, 120))
    text(d, (cx, 1174), sub, 800, 14, (255, 255, 255, 220), "c")

lay = Image.new("RGBA", img.size, (0, 0, 0, 0))
ImageDraw.Draw(lay).rounded_rectangle((px(170), px(1080), px(550), px(1222)), px(70), fill=(255, 120, 200, 140))
img.alpha_composite(lay.filter(ImageFilter.GaussianBlur(px(20))))
shadow(img, (170, 1080, 550, 1214), 64, 8, 120)
grad_rr(img, (170, 1080, 550, 1214), 64, (255, 140, 200, 255), (214, 52, 140, 255), (255, 235, 248, 255), 3)
# luciu de bulă pe buton
lay = Image.new("RGBA", img.size, (0, 0, 0, 0))
ImageDraw.Draw(lay).rounded_rectangle((px(196), px(1088), px(524), px(1130)), px(40), fill=(255, 255, 255, 70))
img.alpha_composite(lay)
d = ImageDraw.Draw(img)
text(d, (360, 1136), "ROTEȘTE", 900, 44, WHITE, "c", 3, (150, 20, 90, 200))
icon(img, "zap", (318, 1180), 20, (255, 240, 200, 255))
text(d, (334, 1180), "3 energie", 800, 17, (255, 240, 250, 255))
text(d, (360, 1252), "Ține apăsat pentru rotiri automate · Șansele sunt afișate integral", 700, 13, (230, 220, 255, 200), "c")

img.convert("RGB").save(OUT)
print("UI:", OUT)
