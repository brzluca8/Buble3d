# Insula 1, v4: jurnalul generării clădirilor (Inelul 2)

| Data | Ce | Rezultat | Credite |
|---|---|---|---|
| 2026-11-21 | Verificare: unelte MCP 3daistudio în sesiune (`get_credit_balance`, `list_available_models`) | **Nu sunt conectate** în această sesiune (nicio unealtă 3daistudio disponibilă). Conform regulii, nu am ocolit: nu am încercat alt acces la serviciu. | 0 |
| 2026-11-21 | Decupaje din `reference/insula_tinta.jpg` (1122 × 1402 px): castel, pod arcuit, piață, moară, atelier + debarcader, barcă, portal | Izolate de fundal (GrabCut, OpenCV), mărite x3 (Lanczos) și ascuțite; în `godot/assets/models/_decupaje/v4/` (transparent și pe alb). Foaia: `docs/shots/insula_v4_decupaje.png`. | 0 |
| 2026-11-21 | Clădirile ca piese separate (PLACEHOLDER) | Din insula veche: `Cladire_castel`, `_poduri`, `_piata`, `_moara`, `_atelier_debarcader`, `_portal`, cu ancora la bază în `godot/insula1/data/inel1.gd`. Un GLB pus în `godot/assets/models/cladiri/<nume>.glb` ia locul piesei fără cod. | 0 |

**Total credite cheltuite: 0** (plafon aprobat: 500).

## Ce urmează, când serviciul e conectat

1. `get_credit_balance`, apoi `list_available_models`; recomandat Hunyuan 3.1 (preț fix).
2. Ordinea: castel, poduri, piață, moară, atelier + debarcader, barcă, portal; din `_decupaje/v4/NN_nume_alb.png`.
3. Max 2 încercări pe obiect; ținta: ≤ 12.000 triunghiuri, o textură ≤ 2048 px, un material, origine la bază, metri,
   părți mobile separate. Estimare: 7 obiecte × ~40 = ~280 credite + materiale ~60.
4. Fiecare rezultat se trece aici (model, încercarea, credite, triunghiuri, px/m) și în `godot/assets/models/CREDITS.md`;
   se păstrează doar dacă în captura A/B arată clar mai bine (≥ 300 px/m).

## Calitatea decupajelor (cinstit)

- Bune pentru generare: castel, piață, moară, atelier + debarcader, barcă, portal (contur curat, detaliu clar).
- Slab: podul arcuit. În imaginea-țintă are doar 116 × 83 px; mărit x3 rămâne neclar și are tufe/felinare de pe mal
  în decupaj. Mai bine: un pod modelat procedural (arc + balustradă), sau decupajul curățat de mână.
