# Proveniența asset-urilor

| Fișier | Unealtă | Data | Cont / plan | Licență / note |
|---|---|---|---|---|
| `orion.glb` | Tripo Studio (img→3D după planșa lui Orion) + `blender/tripo_prep.py` (orientare, scară 1,2 m, emisie, ochi corectați) | 2026-11-18 / 2026-11-19 | contul Tripo al utilizatorului; planul nu e cunoscut aici | De verificat în planul Tripo dacă permite folosirea comercială. Modelul exportat poartă marcajul „Created with Tripo Studio” doar în videoclipul de prezentare. |
| `insula1/insula1.glb` | Tripo Studio (img→3D după `reference/insula_tinta.jpg`, insula trimisă de utilizator) + `blender/island_prep.py` (scară, căsuțe) + `blender/insula1/imbunatateste.py` (apa și cascadele separate, portal, culori) + `blender/insula1/v3_faza_a.py` (clase, fețe inversate reparate, moara cu 4 pale, barca, vânt, AO, simplificare, textura ascuțită) | 2026-11-20 | idem | Textura e mărită x4 cu Real-ESRGAN, modelul `realesrgan-x4plus-anime`, rulat local cu ncnn. Modelele vin din versiunea oficială v0.2.5.0 (Xintao Wang și alții, licență BSD-3-Clause). Nu s-au folosit credite de generare 3D. Pentru Tripo: aceeași verificare de licență ca la Orion. |
| `fundal/insulita_cascada_*.glb` | procedural, Blender (`blender/insula1/insulite.py`) | 2026-11-20 | — | Fără AI. Înlocuiesc insulițele vechi `fundal/insulita_*.glb` (generate de `blender/insula_v2/build_extra.py`), care nu mai sunt folosite. |
| `casuta/casuta.glb` | procedural, Blender (`blender/insula_v2/build_extra.py`, din v2) | 2026-11-20 | — | Fără AI. |
| `insula1_v2/*` | insula v2, refăcută procedural (teren, clădiri PLACEHOLDER, elemente mici) | 2026-11-20 | — | Nu mai e folosită de joc; păstrată doar ca referință. |
| `../insula1/textures/*.png` | procedural, numpy (`blender/insula1/texturi.py`: valuri, nor, rază, detaliu; căsuța și iconițele din `blender/insula_v2/make_textures.py`) | 2026-11-20 | — | Fără AI. Faza A: 0 credite cheltuite. |
| `insula1/insula1.glb` (v4) | ca mai sus + `blender/insula1/v4_inel1.py`: din insula veche s-au scos solul, aleile, iarba, florile, frunzișul, pietrele mici, felinarele de pe stâlpi și cristalele de lângă drum; clădirile sunt piese separate (`Cladire_*`, PLACEHOLDER) | 2026-11-21 | — | Nu s-au folosit credite. |
| `insula1/teren.glb` | procedural, Blender (`blender/insula1/v4_inel1.py`): terenul nou pe harta de înălțimi coaptă din insula veche | 2026-11-21 | — | Fără AI. Texturile: `blender/insula1/texturi_teren.py` (+ generatorul v2 pentru pavaj, stâncă, mușchi). |
| `inel1/*.glb` | procedural, Blender (`blender/insula1/v4_recuzita.py`): palmier, arbore roz, copac mare, tufe, iarbă, floare, pietricică, gard, felinar, butoi, ladă, cristale | 2026-11-21 | — | Fără AI. |
| `_decupaje/v4/*.png` | decupaje din `reference/insula_tinta.jpg` (`blender/insula1/decupaje_v4.py`: GrabCut, Lanczos x3, unsharp) | 2026-11-21 | — | Pregătite pentru generarea imagine→3D; încă negenerate. |
| `cladiri/*.glb` | (gol) aici intră clădirile generate | — | — | Generarea n-a pornit: MCP-ul 3daistudio nu e conectat în sesiune. Credite cheltuite: 0 (plafon 500). Jurnal: `docs/insula_gen_log.md`. |

