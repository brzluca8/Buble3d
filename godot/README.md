# Buble în Godot 4

Proiect Godot 4 cu primele piese ale jocului Buble:
- **Insula 1** (scena principală, `insula.tscn`): Orion stă pe START, iar la „Aruncă zarul” sare din căsuță în căsuță pe drumul de 22 de căsuțe. Insula este **insula trimisă de tine** (din Tripo), adusă la **v4** în `insula1/`:
  - **Inelul 1 e nou, procedural** (tot ce e lângă drum): terenul pe același relief, cu texturi de 512 px/m pe triplanar (iarbă, pavaj, pământ, stâncă, mușchi), AO și umbre de contact; palmieri, arbori roz, copacul mare, tufe, felinare, cristale, garduri, butoaie, lăzi; iarbă, flori și pietricele presărate;
  - **clădirile sunt piese separate** (castel, poduri, piață, moară, portal, atelier cu debarcader), deocamdată din insula veche (PLACEHOLDER); un GLB pus în `assets/models/cladiri/<nume>.glb` ia locul piesei fără cod;
  - **camera de joc** stă în spatele lui Orion, pe drum, la ~50°, și arată căsuțele următoare; la zoom maxim și după aterizare intră în cadrul apropiat;
  - fără puncte de estompare (obiectele care acoperă pe Orion devin transparente lin), fără fante negre între clase, fără fețe întoarse pe insulițe; căsuțele nu se mai ard în alb;
  - **insula vie**: vânt cu rafale (iarbă, flori, frunze, pânze, moară), umbre de nori, apă și cascade cu ceață și stropi, barca cu valuri, pești, fum, scântei, fluturi, păsări, petale (`docs/insula_alive.md`).

  Detalii: `docs/insula_v4.md` (raportul v4), `docs/insula_v3_faza_a.md`, `docs/insula_v3_audit.md`.
- **Orion** (`main.tscn`): previzualizarea mascotei, cu rotire, zoom și săritură.
- **Scena de test** (`test/test_insula.tscn`, se pornește cu F6):
  - cadre fixe: camera de joc nouă (D4) și cea veche (A/B), cadrul de aterizare, capturile tale, mediu, panoramă;
  - moduri de verificare: tablă de șah (pe terenul nou: un pătrat = 25 cm = 128 px, adică 512 px/m), clase, AO, normale;
  - calitate (Mic / Mediu / Mare), umbre, estompare, mișcare redusă, aterizare, **DOF fundal** (oprit implicit);
  - cifrele din Godot pe ecran: FPS, triunghiuri, apeluri de desenare, obiecte, materiale.

Modelele sunt pregătite în Blender:
- Orion (din Tripo) cu `blender/tripo_prep.py`;
- insula cu `blender/island_prep.py` (scară, căsuțe), `blender/insula1/imbunatateste.py` (textură, apă, cascade, portal), `blender/insula1/v3_faza_a.py` (clase, reparații, moară, barcă, vânt, AO, simplificare), apoi `blender/insula1/v4_inel1.py` (Inelul 1 nou, clădirile ca piese) și `blender/insula1/v4_recuzita.py` (recuzita).

## Cum îl deschizi
1. Instalează **Godot 4.3 sau mai nou**, varianta standard, nu .NET. E gratuit, de pe https://godotengine.org/download.
2. Dezarhivează `buble_godot.zip`.
3. În Godot apasă **Import**, alege fișierul `project.godot` din folder, apoi **Import & Edit**. La prima deschidere Godot importă modelele, ceea ce durează câteva secunde.
4. Apasă **▶** (sau F5).

Pe telefon sau tabletă cu Android există și editorul Godot pentru Android („Godot Engine 4” în Google Play), care deschide același folder.

## Ce poți face
**Pe insulă:**
- **Aruncă zarul:** iese un număr de la 1 la 6, iar Orion sare atâtea căsuțe pe drum. Când trece de START, se numără o tură.
- **Camera:** tragi ca să rotești, ciupești sau folosești rotița pentru zoom, ca înainte. Cât sare Orion, camera se rotește lin în spatele lui, pe direcția drumului (până tragi tu de ea); la zoom maxim și după aterizare arată cadrul apropiat. Valorile implicite sunt sus în `insula.gd` (`CAM_*`, `APROAPE_*`).
- **Orion:** butonul deschide previzualizarea mascotei.

**În previzualizarea lui Orion:**
- tragi ca să rotești, ciupești sau folosești rotița pentru zoom, iar dacă îl atingi, sare;
- **Fundal:** cer sau alb;
- **Rotire:** automată sau oprită;
- **Insula:** te întorci pe insulă.

## Modelul lui Orion
Proiectul folosește doar **modelul complet**, cu 188 de mii de triunghiuri. O variantă redusă la 40 de mii arăta vizibil mai rău: blană zimțată, ochelari cu muchii, texturi întinse. Nu e nevoie de ea în Godot, care face singur, la import, variante mai ușoare (LOD) ale modelului. Le folosește doar când Orion e mic pe ecran, așa că diferența nu se vede, iar pe telefon merge repede.

Modelul nu are încă oase. „Respirația” și săritura mișcă tot modelul, sunt doar pentru previzualizare. Pentru mers și alte animații, modelul se poate pregăti cu oase automat în Mixamo, apoi se importă aici.

## Fișiere
| Fișier | Ce este |
|---|---|
| `insula.tscn`, `insula.gd` | jocul pe insulă: zarul, săriturile lui Orion, camera care îl urmărește, interfața |
| `insula1/insula1.gd` (+ `.tscn`) | tot vizualul insulei: cer, lumini, insula pe clase, apa, moara, barca, halouri, portal, căsuțe, nori, insulițe, petale, fluturi, păsări, estompare, calitate |
| `insula1/shaders/insula.gdshader` | un singur material pentru toate clasele insulei: AO, detaliu, vânt, lumini, nuanțare, estompare, moduri de verificare |
| `insula1/shaders/water_flow.gdshader` | apa: râu, lac, cascadă |
| `insula1/shaders/cer.gdshader` | cerul |
| `insula1/shaders/halou.gdshader`, `portal_vartej.gdshader` | felinarele, portalul |
| `insula1/shaders/casuta*.gdshader`, `unda.gdshader` | căsuțele |
| `insula1/casuta/Casuta.tscn`, `casuta.gd` | căsuța nouă: piatră, chenar auriu, iconiță și inel la cele speciale, aprindere, undă, turtire la aterizare |
| `insula1/data/insula1_info.gd` | date generate din Blender: apa, cascadele, portalul, moara, barca, flăcările |
| `insula1/data/tipuri_casute.gd` | tipurile căsuțelor, doar pentru aspect (propunere) |
| `assets/models/insula1/insula1.glb` | insula ta, pe clase (`Insula_*`, `Barca`, `Moara_pale`, `Apa`, `Cascade`), cu texturile incluse |
| `assets/models/casuta/casuta.glb`, `assets/models/fundal/*.glb` | căsuța nouă, insulițele din fundal |
| `test/test_insula.tscn`, `test_insula.gd` | scena de test pentru telefon |
| `main.tscn`, `main.gd` | previzualizarea lui Orion |
| `assets/models/orion.glb` | Orion (1,2 m) |
| `data/insula1_casute.gd` | pozițiile celor 22 de căsuțe, în ordine, de la START (generat din model) |
| `project.godot` | setările: ecran portret 720×1280, randare „Mobile”, texturi comprimate pentru Android |

Setări în `project.godot` (secțiunea `[buble]`):
- `grafica/calitate`: -1 automat, 0 Mic, 1 Mediu, 2 Mare;
- `accesibilitate/miscare_redusa`: oprește animațiile;
- `debug/statistici`: arată FPS, triunghiuri și apeluri de desenare;
- `debug/mod_insula`: 0 normal, 1 tablă de șah, 2 clase, 3 AO, 4 normale.

Aceleași două setări (`calitate`, `miscare_redusa`) se pot regla și în inspector, pe nodul `Insula1` din scena `insula1/insula1.tscn`.

| | Mic | Mediu | Mare |
|---|---|---|---|
| umbre (o lumină, 2 trepte) | nu | 30 m | 45 m |
| vânt în shader, strat de detaliu, apă cu straturi și dungi de curent | nu | da | da |
| ceață la cascade, petale, fluturi, păsări | nu | da | da |
| glow | nu | da | da |
| nori | 14 | 30 | 30 |

**Mișcare redusă** oprește:
- vântul, pâlpâitul și pulsul;
- moara și barca;
- petalele, fluturii, păsările și ceața.

Apa și vârtejul merg foarte încet, iar norii stau pe loc.

Insula refăcută de la zero (v2) a rămas în `insula_v2/` și `assets/models/insula1_v2/`, dar jocul nu o mai folosește.

Ce poți regla în `insula.gd`:
- `HOP_TIME`, `HOP_HEIGHT`: viteza și înălțimea săriturilor;
- `DIST_MIN`, `DIST_MAX`: limitele de zoom;
- cerul, lumina și norii sunt în `insula1/insula1.gd` (`_mediu()`, `_atmosfera()`), iar culorile apei în `_materiale()`.

Ce poți regla în `main.gd`:
- `GLOW_ENERGY`: cât de tare strălucesc marcajele;
- `TARGET_FAR` / `TARGET_NEAR`: unde se uită camera;
- `ZOOM_MIN` / `ZOOM_MAX`: limitele de zoom;
- `FIT_HEIGHT` / `FIT_WIDTH`: cât spațiu se vede în jurul lui Orion la zoom 1;
- culorile cerului din `_build_world()`.

Dacă Godot afișează vreo eroare, mesajul apare în panoul **Output** sau **Debugger**.
