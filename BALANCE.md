# BALANCE – cum sunt calculate costurile

Totul se generează cu `python3 tools/balance.py` (scrie `godot/data/levels.json` și afișează raportul de mai jos).
Valorile se pot schimba direct în fișierele din `godot/data/`, fără cod; după o schimbare de tabel sau
de parametri, rulează din nou scriptul ca să vezi noul ritm.

## Ținte (din predare)

- Nivelurile 1–5 în primele ~15 minute.
- Nivelul 30 după aproximativ două săptămâni de joc zilnic.

## Metoda

1. **Valoarea unei rotiri.** Din `spin_table.json` se calculează valoarea așteptată (EV) a unei rotiri, în
   „unități de pariu": monede directe, atac (cu 30% șansă ca ținta să aibă scut), raid (3 din 4 locuri),
   scut când plafonul e plin, cufere (medie pe tipuri). Rezultă **3,23 unități de monede** și
   **0,29 energie înapoi** pe rotire.
2. **Unitatea de pariu** crește cu nivelul: `bet_unit(L) = 20 · 1,16^(L−1)` (20 la nivelul 1, 1.480 la nivelul 30).
   Astfel recompensele țin pasul cu costurile.
3. **Curba de ritm.** Numărul de rotiri cumulate necesar pentru a termina nivelul L:
   `S(L) = 8,92 · L^1,71` (ancorată la S(5) = 140 și S(30) = 3.000 de rotiri).
4. **Costul nivelului L** = `EV · bet_unit(L) · (S(L) − S(L−1))`, împărțit pe cele 2–3 construcții ale nivelului
   (etapele mai înalte cântăresc mai mult), rotunjit la valori „curate".
5. **Timpul de construcție**: 0 la nivelurile 1–5, 1–5 min la 6–10, 5–20 min la 11–20, 20–60 min la 21–30.
   Un singur constructor la început (al doilea din abilitatea „Al doilea constructor").
6. **Verificare prin simulare**: 200 de jucători simulați, 4 sesiuni pe zi în 16 ore de veghe, fiecare sesiune
   consumă toată energia (plafon 50, +1 la 10 minute), construiește cât poate, primește recompensele de nivel.

## Rezultat

```
EV pe rotire: 3.23 unități de monede, 0.29 energie înapoi
Curba țintă: S(L) = 8.92 · L^1.710  (S(5)=140, S(10)=458, S(20)=1499, S(30)=3000 rotiri)
Nivelul  1 terminat: mediana 0 min (0.0 zile), 200/200 jucători simulați
Nivelul  2 terminat: mediana 1 min (0.0 zile), 200/200 jucători simulați
Nivelul  3 terminat: mediana 3 min (0.0 zile), 200/200 jucători simulați
Nivelul  4 terminat: mediana 5 min (0.0 zile), 200/200 jucători simulați
Nivelul  5 terminat: mediana 247 min (0.2 zile), 200/200 jucători simulați
Nivelul 10 terminat: mediana 2182 min (1.5 zile), 200/200 jucători simulați
Nivelul 20 terminat: mediana 9391 min (6.5 zile), 200/200 jucători simulați
Nivelul 30 terminat: mediana 20419 min (14.2 zile), 200/200 jucători simulați

Nivel | glob | unitate | rotiri țintă | cost total | timp construcție
    1 |    1 |      20 |            9 |        580 |   0 min
    2 |    1 |      23 |           20 |       1500 |   0 min
    3 |    1 |      27 |           29 |       2600 |   0 min
    4 |    1 |      31 |           37 |       3800 |   0 min
    5 |    1 |      36 |           44 |       5200 |   0 min
    6 |    1 |      42 |           51 |       6900 |   1 min
    7 |    1 |      49 |           58 |       9000 |   2 min
    8 |    1 |      57 |           64 |      11700 |   3 min
    9 |    1 |      66 |           70 |      14800 |   4 min
   10 |    1 |      76 |           76 |      18600 |   5 min
   11 |    2 |      88 |           81 |      24000 |   6 min
   12 |    2 |     102 |           86 |      28000 |   8 min
   13 |    2 |     119 |           92 |      36000 |   9 min
   14 |    2 |     138 |           97 |      44000 |  11 min
   15 |    2 |     160 |          102 |      53000 |  12 min
   16 |    2 |     185 |          107 |      63000 |  14 min
   17 |    2 |     215 |          112 |      78000 |  15 min
   18 |    2 |     249 |          117 |      93000 |  17 min
   19 |    2 |     289 |          121 |     114000 |  18 min
   20 |    2 |     336 |          126 |     138000 |  20 min
   21 |    3 |     389 |          130 |     164000 |  24 min
   22 |    3 |     451 |          135 |     196000 |  28 min
   23 |    3 |     524 |          139 |     240000 |  32 min
   24 |    3 |     608 |          144 |     280000 |  36 min
   25 |    3 |     705 |          148 |     340000 |  40 min
   26 |    3 |     817 |          152 |     390000 |  44 min
   27 |    3 |     948 |          157 |     470000 |  48 min
   28 |    3 |    1100 |          161 |     570000 |  52 min
   29 |    3 |    1276 |          165 |     680000 |  56 min
   30 |    3 |    1480 |          169 |     810000 |  60 min
```

Prima sesiune duce jucătorul până la nivelul 5 în ~5 minute (nivelul 5 se termină în a doua sesiune);
nivelul 30 se atinge în ~14 zile cu 4 sesiuni pe zi.

## Ce nu intră în simulare (de urmărit la test)

- Abilitățile (ex. +15% monede, upgrade-uri −15%) și însoțitorul (+1…5%) accelerează jocul cu ~10–20% spre final.
- Cuferele se deschid cu întârziere (timer); simularea le dă imediat.
- Rezervorul de monede (plafon 4 ore de producție) și seria zilnică adaugă puțin.
- Jucătorii reali nu consumă toată energia la fiecare sesiune.

Dacă testul arată abandon la globul 2–3, coboară exponentul curbei (`S30`) sau `1,16` din `bet_unit`.
