> Actualizare Etapa 2.8 — bonusurile clădirilor se aplică global pe categorie. Distribuția și regulile curente sunt în [ETAPA_2_8.md](docs/ETAPA_2_8.md). Descrierile zonelor locale de mai jos aparțin etapelor anterioare.

# Două zaruri, energie, recompense și construcții – reguli de prototip
## Zaruri
- DOUĂ zaruri standard uniforme și independente, fețe 1..6; `roll_total = die_a + die_b` (2..12).
- Cost inițial **1 energie per aruncare**, max 100; regen +1 la 5 minute, dacă se reutilizează economia din V2 (configurabil, compatibil cu starea actuală).
- Înainte de animație, generează și confirmă un singur rezultat; interfața arată cele 2 fețe și suma.
- Blocare dublu-tap, cancel, background/foreground: tranzacție o singură dată. Avansare vizuală 1,5–2,5 secunde (țintă), fast-forward opțional, fără a sări recompensele.
- Fără mecanica de păstrare/reamestecare a zarurilor la roll normal; poate fi evaluată ulterior ca eveniment rar.

## START
- Bonus prototip: +100 monede pentru trecerea peste START (inclusiv oprire exact pe 0), o dată per trecere.
- Tile `0` poate avea recompensă neutră `0` la aterizare, astfel încât să nu dubleze START; acest bonus NU este multiplicat de nivelul clădirilor sau de Super Cristal în V3.

## Recompense pe tipuri de tile – valori TEST
- `coin`: 100 monede.
- `crystal`: 5 fragmente (sau moneda/cristalele deja existente, fără dublă contabilizare).
- `construction`: 2 puncte de construcție.
- `energy`: +2 energie, plafon 100.
- `magic`: 1 premiu mic aleator pozitiv dintre +75 monede sau +2 fragmente, într-un tabel configurabil.
- `quest`: 1 jeton local de misiune (placeholder, fără social/server).
- Tipurile pot fi distribuite echilibrat; nu toate cele 36 trebuie să aibă valori distincte. Fiecare tile își cunoaște `type`, `zone`, `base_reward`.
- Inițial `building_influence`: multiplicator pe valoare; pentru jeton unic/energie folosește regulă explicită de rotunjire / bonus fix sau păstrează nemodificat până la test, dar nu permite bonusuri multiplicate zero din cauza rotunjirii.

## Construcții
- 6 clădiri cu nivele 0 (liber) / 1 / 2 / 3; castel/cristal în afara sloturilor.
- Costuri anterioare de prototip: 0→1: 1000 monede +10 puncte construcție; 1→2: 3000+25; 2→3: 8000+45. **Nu recalcula/reset nivelul curent al jucătorului**, ci păstrează economiile actuale dacă deja există.
- Schimbările de nivel se văd și pe harta 3D prin piese independente; fără model nou obligatoriu per nivel.
- `coin`/`crystal`/`build_points` și resursele salvate trebuie mapate din economia reală în mod explicit. Nu schimba interpretarea `gems` în `fragments` fără migrare.

## Feedback
- O singură popup scurtă pentru câștigul de la aterizare, cu indicarea clădirii care l-a mărit: `Mina Lv.2: +25%`.
- Efecte comice ocazionale 1–3 secunde, opționale sau skippable; să nu transforme fiecare roll într-o cutscene.
