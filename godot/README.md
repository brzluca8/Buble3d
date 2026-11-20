# Buble în Godot 4

Proiect Godot 4 cu primele piese ale jocului Buble:
- **Insula 1** (scena principală, `insula.tscn`): Orion stă pe START, iar la „Aruncă zarul” sare din căsuță în căsuță pe drumul de 22 de căsuțe. Insula este **insula trimisă de tine** (din Tripo), îmbunătățită în `insula1/`:
  - textură mărită cu AI (4096 px, culori mai vii);
  - apa ei curge acum: râul din jurul castelului, laguna, iazurile;
  - cascadele ei au dungi care cad și ceață la bază;
  - portalul are un vârtej;
  - felinarele pâlpâie, iar cristalele pulsează;
  - căsuța se aprinde la aterizare;
  - cer, nori, insulițe în fundal, petale și fluturi.

  Detalii în `docs/insula1_imbunatatita.md`.
- **Orion** (`main.tscn`): previzualizarea mascotei, cu rotire, zoom și săritură.

Modelele sunt pregătite în Blender:
- Orion (din Tripo) cu `blender/tripo_prep.py`;
- insula cu `blender/island_prep.py` (scară, căsuțe), apoi cu `blender/insula1/imbunatateste.py` (textură, apă, cascade, portal).

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
| `insula1/insula1.gd` (+ `.tscn`) | tot vizualul insulei: cer, lumini, insula, apa, ceața cascadelor, portalul, efectul de aterizare, nori, insulițe, petale, fluturi, calitate |
| `insula1/shaders/*.gdshader` | insula (textura + lumini care pâlpâie), apa (`water_flow`: râu, lac, cascadă), vârtejul portalului, aterizarea |
| `insula1/data/insula1_info.gd` | date generate din Blender: nivelurile apei, cascadele, portalul |
| `assets/models/insula1/insula1.glb` | insula ta îmbunătățită: obiectele `Insula`, `Apa`, `Cascade` (cu texturile incluse) |
| `assets/models/fundal/*.glb` | insulițele din fundal |
| `main.tscn`, `main.gd` | previzualizarea lui Orion |
| `assets/models/orion.glb` | Orion (1,2 m) |
| `data/insula1_casute.gd` | pozițiile celor 22 de căsuțe, în ordine, de la START (generat din model) |
| `project.godot` | setările: ecran portret 720×1280, randare „Mobile”, texturi comprimate pentru Android |

Setări în `project.godot` (secțiunea `[buble]`):
- `grafica/calitate`: -1 automat, 0 Mic, 1 Mediu, 2 Mare;
- `accesibilitate/miscare_redusa`: oprește animațiile;
- `debug/statistici`: arată FPS, triunghiuri și apeluri de desenare.

Aceleași două setări (`calitate`, `miscare_redusa`) se pot regla și în inspector, pe nodul `Insula1` din scena `insula1/insula1.tscn`.

| | Mic | Mediu | Mare |
|---|---|---|---|
| umbre (o lumină, 2 trepte) | nu | 32 m | 45 m |
| apă cu al doilea strat de valuri, spumă cu zgomot, sclipiri | nu | da | da |
| ceață la cascade, petale, fluturi | nu | da | da |
| glow | nu | da | da |
| nori | 14 | 30 | 30 |

**Mișcare redusă** oprește pâlpâitul, pulsul, petalele, fluturii și ceața. Apa și vârtejul merg foarte încet, iar norii stau pe loc.

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
