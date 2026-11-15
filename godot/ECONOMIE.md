# Economia Buble – parametri și rezultatele simulării

Toți parametrii sunt în `autoload/game.gd`. Simularea: `godot --headless --path godot -s res://tests/economy_sim.gd -- 6 12`
(joacă automat cu multiplicator ×1, alege la întâmplare la atac/jaf și cumpără cel mai ieftin upgrade).

## Parametri

| Parametru | Valoare |
|---|---|
| Energie maximă | 50 bule |
| Refacere | 1 bulă / 2 minute (≈ 720 pe zi dacă joci non-stop; un jucător obișnuit ≈ 200/zi) |
| Multiplicatori | ×1, ×2, ×3, ×5, ×10, ×20 (costă și înmulțesc la fel) |
| Unitatea de recompensă | `20 × insulă × (1 + 0,04 × (niveluri − 5))` |
| Cost upgrade | `bază × nivel^1,7 × insulă^2` (bază: palat 150, observator 100, turn 100, magazin 80, seră 90) |
| Monede | 2–4 unități · Cufăr: 6 unități / 3 bule / cărți · Start: 3 unități |
| Atac | 8 unități (3 dacă scutul rivalului parează – 25%) |
| Jaf | 9 nori: 3 × 6–10 unități, 3 × 2–4 unități, 3 goi; alegi 3 |
| Insulă completă | 20 unități + 30 bule + 200 XP |
| Set album complet | +25 bule |
| Venit pasiv | **scos** – energia e resursa care se reface în timp |

## Rezultate (medie pe 12 rulări)

| Insula | Aruncări | Monede / aruncare | Cost total | Zile (≈200 aruncări/zi) |
|---|---|---|---|---|
| 1 | 84 | 133 | 11.064 | 0,4 |
| 2 | 152 | 287 | 44.258 | 0,8 |
| 3 | 238 | 414 | 99.581 | 1,2 |
| 4 | 323 | 543 | 177.035 | 1,6 |
| 5 | 404 | 679 | 276.616 | 2,0 |
| 6 | 461 | 856 | 398.326 | 2,3 |

Prima insulă se termină în prima sesiune (cârligul), apoi fiecare insulă cere tot mai mult – de aici vine
dorința de energie în plus (reclame, magazin, multiplicator).

## De urmărit la testele cu jucători

- Retenția din ziua 1 / 7 / 30 și câte sesiuni pe zi fac jucătorii (simularea presupune ~200 aruncări/zi).
- Dacă jucătorii renunță la insulele 3–4, coboară exponentul costului (`insulă^2` → `insulă^1,8`).
- Valoarea pachetelor din magazin trebuie raportată la „aruncări economisite”, nu doar la monede.
