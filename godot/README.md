# Buble în Godot 4

Proiect Godot 4 cu primele piese ale jocului Buble:
- **Insula 1** (scena principală, `insula.tscn`): insula plutitoare cu castelul și drumul de 22 de căsuțe. Orion stă pe START, iar la „Aruncă zarul” sare din căsuță în căsuță.
- **Orion** (`main.tscn`): previzualizarea mascotei, cu rotire, zoom și săritură.

Modelele vin din Tripo și sunt pregătite în Blender: Orion cu `blender/tripo_prep.py` (ochi corectați, marcaje care strălucesc), insula cu `blender/island_prep.py` (scară, materiale, pozițiile căsuțelor).

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
| `insula.tscn`, `insula.gd` | insula: cer, nori, lumini, zarul, săriturile lui Orion, camera care îl urmărește |
| `main.tscn`, `main.gd` | previzualizarea lui Orion |
| `models/insula1.glb` | insula 1, scalată în metri (cam 19 × 23 m, căsuțe la 1,9 m una de alta) |
| `models/orion_tripo_game.glb` | Orion (1,2 m) |
| `data/insula1_casute.gd` | pozițiile celor 22 de căsuțe, în ordine, de la START (generat din model) |
| `project.godot` | setările: ecran portret 720×1280, randare „Mobile”, texturi comprimate pentru Android |

Ce poți regla în `insula.gd`:
- `HOP_TIME`, `HOP_HEIGHT`: viteza și înălțimea săriturilor;
- `DIST_MIN`, `DIST_MAX`: limitele de zoom;
- culorile cerului și norii din `_build_world()` și `_add_clouds()`.

Ce poți regla în `main.gd`:
- `GLOW_ENERGY`: cât de tare strălucesc marcajele;
- `TARGET_FAR` / `TARGET_NEAR`: unde se uită camera;
- `ZOOM_MIN` / `ZOOM_MAX`: limitele de zoom;
- `FIT_HEIGHT` / `FIT_WIDTH`: cât spațiu se vede în jurul lui Orion la zoom 1;
- culorile cerului din `_build_world()`.

Dacă Godot afișează vreo eroare, mesajul apare în panoul **Output** sau **Debugger**.
