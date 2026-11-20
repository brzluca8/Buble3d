# Proveniența asset-urilor

| Fișier | Unealtă | Data | Cont / plan | Licență / note |
|---|---|---|---|---|
| `orion.glb` | Tripo Studio (img→3D după planșa lui Orion) + `blender/tripo_prep.py` (orientare, scară 1,2 m, emisie, ochi corectați) | 2026-11-18 / 2026-11-19 | contul Tripo al utilizatorului; planul nu e cunoscut aici | De verificat în planul Tripo dacă permite folosirea comercială. Modelul exportat poartă marcajul „Created with Tripo Studio” doar în videoclipul de prezentare. |
| `_vechi/insula1_tripo_v1.glb` | Tripo Studio (img→3D după `reference/insula_tinta.jpg`) + `blender/island_prep.py` | 2026-11-20 | idem | Doar referință pentru poziții. Nu se mai folosește ca insulă de joc. |
| `_decupaje/*.png` | decupaje din `reference/insula_tinta.jpg` (Python/PIL) | 2026-11-20 | — | Imaginea țintă e a utilizatorului. |
| `insula1_v2/teren.glb` | generat procedural în Blender 5.1 headless (`blender/insula_v2/build_terrain.py`) | 2026-11-20 | — | Fără AI. |
| `insula1_v2/props/*.glb` | PLACEHOLDER-e procedurale, Blender (`blender/insula_v2/build_props.py`) | 2026-11-20 | — | De înlocuit cu modele generate (vezi `docs/insula_v2_plan.md`, secțiunea 7). |
| `insula1_v2/mici/*.glb` | procedural, Blender (`blender/insula_v2/build_props.py`) | 2026-11-20 | — | Fără AI. |
| `../insula_v2/textures/*.png` | procedural, numpy (`blender/insula_v2/make_textures.py`) | 2026-11-20 | — | Fără AI. |
