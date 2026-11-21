# Clădirile noi (Inelul 2), înlocuire fără cod

Pune aici GLB-urile generate (imagine → 3D din decupajele din `../_decupaje/v4/`), cu numele:

| Fișier | Ce înlocuiește | Mărimea piesei vechi (x, y, z în m) |
|---|---|---|
| `castel.glb` | `Cladire_castel` | 8,8 × 7,4 × 8,6 |
| `poduri.glb` | `Cladire_poduri` (toate podurile) | 9,4 × 3,3 × 11,2 |
| `piata.glb` | `Cladire_piata` | 4,5 × 2,5 × 4,9 |
| `moara.glb` | `Cladire_moara` (fără pale: palele sunt `Moara_pale`) | 9,7 × 5,3 × 6,0 |
| `atelier_debarcader.glb` | `Cladire_atelier_debarcader` | 6,5 × 5,9 × 5,8 |
| `portal.glb` | `Cladire_portal` (vârtejul rămâne din shader) | 3,4 × 2,6 × 3,9 |

Reguli: originea la bază (pe sol), scară în metri (Orion = 1,15 m), max 12.000 triunghiuri, o textură de max 2048 px,
un material, părțile care se mișcă separate (palele morii, pânza bărcii, steagurile). La pornire, `insula1/insula1.gd`
pune modelul la ancora din `insula1/data/inel1.gd` (`CLADIRI`) și ascunde piesa veche; rotația se potrivește în
`CLADIRI_ROTATIE` (grade), de ex. `{"castel": 90.0}`. Înlocuiește piesa doar dacă în captura A/B arată clar mai bine
(≥ 300 px/m).
