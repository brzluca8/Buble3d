#!/usr/bin/env python3
"""Generează godot/data/levels.json (30 de niveluri) și verifică ritmul printr-o simulare.

    python3 tools/balance.py            # scrie levels.json și afișează raportul (folosit în BALANCE.md)

Metoda:
1. Ținta de ritm: rotiri cumulate necesare pentru a termina nivelul L:  S(L) = A · L^P,
   ancorată la S(5) ≈ 125 rotiri (≈ 15 minute în prima sesiune) și S(30) ≈ 2300 rotiri (≈ 14 zile).
2. Valoarea așteptată (EV) a unei rotiri, în unități de pariu, se calculează din spin_table.json.
3. Costul nivelului L = EV_monede · bet_unit(L) · (S(L) − S(L−1)), împărțit pe cele 2–3 upgrade-uri.
4. Simulare Monte Carlo (sesiuni realiste, energie cu plafon) → zilele reale până la nivelurile 5/10/20/30.
"""
import json
import math
import os
import random
import statistics

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "godot", "data")
spin = json.load(open(os.path.join(DATA, "spin_table.json"), encoding="utf-8"))
cfg = json.load(open(os.path.join(DATA, "config.json"), encoding="utf-8"))

BUILDINGS = ["palat", "obs", "turn", "mag", "sera"]
GLOBES = [
    {"id": 1, "name": "Grădina dintre nori"},
    {"id": 2, "name": "Orașul de cristal"},
    {"id": 3, "name": "Portul de amurg"},
]
SPLIT = [2, 2, 2, 2, 3, 3, 3, 3, 2, 3]  # upgrade-uri pe nivel într-un glob (total 25 = 5 clădiri × 5 etape)
S5, S30 = 140.0, 3000.0
P = math.log(S30 / S5) / math.log(30 / 5)
A = S5 / 5 ** P


def S(level):
    return A * level ** P if level > 0 else 0.0


def bet_unit(level):
    return int(round(20 * 1.16 ** (level - 1)))


# ---------------- valoarea așteptată a unei rotiri ----------------
outs = spin["outcomes"]
W = sum(o["weight"] for o in outs)
kinds = cfg["chests"]["kinds"]
KW = sum(k["weight"] for k in kinds.values())
chest_units = sum(k["weight"] * k["units"] for k in kinds.values()) / KW
chest_energy = sum(k["weight"] * k["energy"] for k in kinds.values()) / KW


def ev(shield_full_share=0.5, block_share=0.3):
    coins = energy = 0.0
    for o in outs:
        p = o["weight"] / W
        t = o["type"]
        if t == "coins":
            coins += p * o["units"]
        elif t == "energy":
            energy += p * o["amount"]
        elif t == "shield":
            coins += p * shield_full_share * o["units_if_full"]
        elif t == "attack":
            coins += p * ((1 - block_share) * o["units"] + block_share * o["units_blocked"])
        elif t == "raid":
            s = o["spots_units"]
            coins += p * sum(s) * o["picks"] / len(s)
        elif t == "chest":
            coins += p * chest_units
            energy += p * chest_energy
    return coins, energy


EV_COINS, EV_ENERGY = ev()


def round_nice(x):
    if x < 100:
        return int(round(x / 5) * 5)
    mag = 10 ** (len(str(int(x))) - 2)
    return int(round(x / mag) * mag)


def build_time(level):
    if level <= 5:
        return 0
    if level <= 10:
        return 60 * (level - 5)              # 1–5 min
    if level <= 20:
        return 300 + 90 * (level - 10)       # 5–20 min
    return 1200 + 240 * (level - 20)         # 20–60 min


levels = []
lvl = 0
for g in GLOBES:
    order = [(b, st) for st in range(1, 6) for b in BUILDINGS]
    k = 0
    for n in SPLIT:
        lvl += 1
        ups = order[k:k + n]
        k += n
        total = EV_COINS * bet_unit(lvl) * (S(lvl) - S(lvl - 1))
        weights = [1.0 + 0.15 * st for (_, st) in ups]
        costs = [round_nice(total * w / sum(weights)) for w in weights]
        levels.append({
            "level": lvl, "globe": g["id"], "bet_unit": bet_unit(lvl),
            "spins_target": round(S(lvl) - S(lvl - 1), 1),
            "upgrades": [{"building": b, "stage": st, "cost": c, "time_s": build_time(lvl)} for (b, st), c in zip(ups, costs)],
            "reward": {"units": 5 + lvl // 3, "energy": 10 if lvl % 10 else 25, "perle": 1 if lvl % 5 == 0 else 0,
                       "chest": "epic" if lvl % 10 == 0 else ""},
        })

json.dump({"_info": "Generat de tools/balance.py – modifică parametrii acolo sau direct aici.", "globes": GLOBES, "levels": levels},
          open(os.path.join(DATA, "levels.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)


# ---------------- simulare ----------------
def simulate(seed, sessions_per_day=4, awake_h=16):
    rnd = random.Random(seed)
    energy = cfg["energy"]["start"]
    cap = cfg["energy"]["cap"]
    regen = cfg["energy"]["regen_s"]
    level, done_in_level, coins = 1, 0, 0.0
    spins, t = 0, 0.0
    reached = {}
    gap = awake_h * 3600 / sessions_per_day
    chests = []
    while level <= 30 and t < 40 * 86400:
        # o sesiune: rotește până se termină energia, construiește ce se poate
        while energy > 0 and level <= 30:
            energy -= 1
            spins += 1
            r = rnd.uniform(0, W)
            for o in outs:
                r -= o["weight"]
                if r <= 0:
                    break
            u = bet_unit(level)
            ty = o["type"]
            if ty == "coins":
                coins += o["units"] * u
            elif ty == "energy":
                energy += o["amount"]
            elif ty == "shield":
                coins += 0.5 * o["units_if_full"] * u
            elif ty == "attack":
                coins += (o["units"] if rnd.random() > 0.3 else o["units_blocked"]) * u
            elif ty == "raid":
                s = o["spots_units"][:]
                rnd.shuffle(s)
                coins += sum(s[:o["picks"]]) * u
            elif ty == "chest":
                kk = rnd.choices(list(kinds.values()), [x["weight"] for x in kinds.values()])[0]
                coins += kk["units"] * u
                energy += kk["energy"]
            # construiește
            L = levels[level - 1]
            while level <= 30 and done_in_level < len(L["upgrades"]) and coins >= L["upgrades"][done_in_level]["cost"]:
                coins -= L["upgrades"][done_in_level]["cost"]
                done_in_level += 1
                if done_in_level == len(L["upgrades"]):
                    coins += L["reward"]["units"] * L["bet_unit"]
                    energy += L["reward"]["energy"]
                    reached[level] = t
                    level += 1
                    done_in_level = 0
                    if level <= 30:
                        L = levels[level - 1]
            t += 3  # o rotire ≈ 3 secunde
        # pauză până la sesiunea următoare (noaptea: 8 h)
        nxt = gap if (t % 86400) < awake_h * 3600 - gap else 86400 - (t % 86400) + rnd.uniform(0, 1800)
        t += nxt
        energy = min(cap, energy + int(nxt / regen))
    return reached, spins


def report():
    lines = []
    lines.append(f"EV pe rotire: {EV_COINS:.2f} unități de monede, {EV_ENERGY:.2f} energie înapoi")
    lines.append(f"Curba țintă: S(L) = {A:.2f} · L^{P:.3f}  (S(5)={S(5):.0f}, S(10)={S(10):.0f}, S(20)={S(20):.0f}, S(30)={S(30):.0f} rotiri)")
    runs = [simulate(s) for s in range(200)]
    for L in (1, 2, 3, 4, 5, 10, 20, 30):
        ts = [r[0][L] for r in runs if L in r[0]]
        if ts:
            med = statistics.median(ts)
            lines.append(f"Nivelul {L:2d} terminat: mediana {med / 60:.0f} min ({med / 86400:.1f} zile), {len(ts)}/{len(runs)} jucători simulați")
    return "\n".join(lines)


if __name__ == "__main__":
    print(report())
    print("\nNivel | glob | unitate | rotiri țintă | cost total | timp construcție")
    for L in levels:
        print(f"{L['level']:5d} | {L['globe']:4d} | {L['bet_unit']:7d} | {L['spins_target']:12.0f} | {sum(u['cost'] for u in L['upgrades']):10d} | {L['upgrades'][0]['time_s'] // 60:3d} min")
