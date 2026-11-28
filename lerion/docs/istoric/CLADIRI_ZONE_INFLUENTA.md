> Actualizare Etapa 2.8 — bonusurile clădirilor se aplică global pe categorie. Distribuția și regulile curente sunt în [ETAPA_2_8.md](docs/ETAPA_2_8.md). Descrierile zonelor locale de mai jos aparțin etapelor anterioare.

# Zonele de recompense pentru cele 6 clădiri
## Clădirile (poziții în harta nouă)
| Latura/poziție | Clădire | Zone/tile (conceptual) | Tip de bonus |
|---|---|---|---|
| Stânga sus | Mina de Cristale | 2–3 căsuțe adiacent traseului | `crystal` |
| Dreapta sus | Moara Trăsnită | 2–3 căsuțe adiacent traseului | `energy` |
| Stânga mijloc | Atelierul lui Pongo | 2–3 căsuțe adiacent traseului | `construction` |
| Dreapta mijloc | Laboratorul lui Pufi | 2–3 căsuțe adiacent traseului | `magic` |
| Stânga jos | Piața Poznașă | 2–3 căsuțe adiacent traseului | `coin` |
| Dreapta jos | Hanul Aventurierilor | 2–3 căsuțe adiacent traseului | `quest` |

## Exemplu multiplicatori V3 (NU confirmați prin teste)
- Nivel 0 (clădire neconstruită): **x1.00** (recompensă de bază).
- Nivel 1: **x1.10** (+10%).
- Nivel 2: **x1.25** (+25%).
- Nivel 3: **x1.50** (+50%).
- Prototip: păstrează ca multipliere pentru `coin`/`crystal`/`construction`; pentru `energy`, `quest`, `magic` aplică reguli explicite de bonus sau marchează ca TODO și menține `x1` temporar, fără a pretinde că sunt deja echilibrate.
- **Nu trebuie ca trecerea pe lângă clădire să dea automat un premiu.** Premiul apare numai dacă Lerik se oprește pe tile-ul activ.
- Zona este un atribut al tile-ului (`building_id`), nu rezultatul coliziunii cu mesh-ul clădirii. Așa upgrade-ul modifică economic jocul fără să depindă de distanța calculată de fizică.

## Structură recomandată
- `building_levels[id]` = 0..3, venit din economia existentă.
- `tile.building_id` = `none` sau clădirea unică asociată; max 1 clădire per tile în MVP, ca să evităm suprapuneri de bonus.
- `reward(tile)` = `floor(base_reward * multiplier[level])` sau rotunjire stabilă, definită înainte de implementare, cu minimum 1 pentru orice recompensă pozitivă.
- Arată vizual o marcă subtilă de culoare/pictogramă pe tile când clădirea e îmbunătățită (fără transformări GPU grele).

## Notă de balans
- 36 tiles, 18 în zonele celor 6 clădiri dacă alegem câte 3 fiecare; celelalte 18 au premii neutre/diverse. **Acesta este un punct de test**, nu un calcul de venituri real.
