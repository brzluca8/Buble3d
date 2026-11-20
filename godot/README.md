# Buble în Godot 4

Proiect Godot 4 cu primele piese ale jocului Buble:
- **Insula 1** (scena principală, `insula.tscn`): Orion stă pe START, iar la „Aruncă zarul” sare din căsuță în căsuță pe drumul de 22 de căsuțe. Insula este **insula trimisă de tine** (din Tripo), adusă la **v3, Faza A** în `insula1/`:
  - modelul e tăiat pe clase, cu petele negre reparate și triunghiurile aproape înjumătățite;
  - textura e mărită cu AI, cu strat de detaliu și culori mai apropiate de Orion;
  - apa curge, cu direcția vizibilă, iar cascadele se topesc în nori;
  - moara se rotește, barca se leagănă, vântul mișcă frunzișul și florile;
  - portalul și cristalele pulsează, felinarele pâlpâie;
  - 22 de căsuțe noi, cu iconițe și efect la aterizare;
  - cer, insulițe cu cascade, umbre vizibile;
  - ce ajunge între cameră și Orion se estompează.

  Detalii în `docs/insula_v3_faza_a.md` și `docs/insula_v3_audit.md`.
- **Orion** (`main.tscn`): previzualizarea mascotei, cu rotire, zoom și săritură.
- **Scena de test** (`test/test_insula.tscn`, se pornește cu F6):
  - cadre fixe;
  - moduri de verificare: tablă de șah, clase, AO, normale;
  - calitate și comutatoare;
  - cifrele din Godot pe ecran.

Modelele sunt pregătite în Blender:
- Orion (din Tripo) cu `blender/tripo_prep.py`;
- insula cu `blender/island_prep.py` (scară, căsuțe), `blender/insula1/imbunatateste.py` (textură, apă, cascade, portal), apoi `blender/insula1/v3_faza_a.py` (clase, reparații, moară, barcă, vânt, AO, simplificare).

## Cum îl deschizi
1. Instalează **Godot 4.3 sau mai nou**, varianta standard, nu .NET. E gratuit, de pe https://godotengine.org/download.
2. Dezarhivează `buble_godot.zip`.
3. În Godot apasă **Import**, alege fișierul `project.godot` din folder, apoi **Import & Edit**. La prima deschidere Godot importă modelele, ceea ce durează câteva secunde.
4. Apasă **▶** (sau F5).

Pe telefon sau tabletă cu Android există și editorul Godot pentru Android („Godot Engine 4” în Google Play), care deschide același folder.

## Ce poți face
**Pe insulă:**
- **Aruncă zarul:** iese un număr de la 1 la 6, iar Orion sare atâtea căsuțe pe drum. Când trece de START, se numără o tură.
- **Camera:** tragi ca să rotești, ciupești sau folosești rotița pentru zoom. Camera îl urmărește pe Orion, iar de departe arată toată insula.
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
