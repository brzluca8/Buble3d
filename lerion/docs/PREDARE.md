# Predare — stare curentă și pași rămași

Ramura de lucru: `ccr-b40a0280-sp0hf6` (proiectul Godot este în subfolderul `lerion/` al repository-ului).

## Etapa 4.2 — progres
| Fază | Stare | Commit |
|---|---|---|
| A — audit, documentație, checkpoint `checkpoint-before-etapa-4-2` | gata | (acest commit) |
| B — Lerik (model segmentat, rig, animator), zaruri, cameră | gata | faza B |
| C — cristal, ruletă, cufere 3D | în lucru | — |
| D — regatul viu, Pongo și Pufi | de făcut | — |
| E — UI, cărți, audio | de făcut | — |
| F — momente WOW, calitate, panou, teste | de făcut | — |

## Comenzi
```sh
godot --headless --import                                   # reimport după schimbarea asset-urilor
XDG_DATA_HOME=$(mktemp -d) godot --headless --fixed-fps 60 --script tools/check_board.gd
# suitele: check_board, check_board_polish, check_board_rewards, check_crystal, check_developer,
# check_map, check_premium, check_village_flow, check_super_crystal, check_energy_events,
# check_cards, check_visual (+ cele noi din Etapa 4.2)
python3 tools/build_characters.py   # regenerează Lerik, Pongo, Pufi și cuferele 3D (Etapa 4.2)
python3 tools/build_board_audio.py  # regenerează sunetele
```
Capturile din joc se fac cu `xvfb-run -a godot --rendering-driver opengl3 --script <script>` (randare software).
