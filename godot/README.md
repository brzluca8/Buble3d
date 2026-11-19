# Orion în Godot 4

Proiect Godot 4 pentru previzualizarea lui Orion, mascota jocului Buble. Folosește modelul din Tripo, pregătit în Blender cu `blender/tripo_prep.py`: ochii sunt corectați, marcajele turcoaz strălucesc, rucsacul e mov.

## Cum îl deschizi
1. Instalează **Godot 4.3 sau mai nou**, varianta standard, nu .NET. E gratuit, de pe https://godotengine.org/download.
2. Dezarhivează `orion_godot.zip`.
3. În Godot apasă **Import**, alege fișierul `project.godot` din folder, apoi **Import & Edit**. La prima deschidere Godot importă modelele, ceea ce durează câteva secunde.
4. Apasă **▶** (sau F5).

Pe telefon sau tabletă cu Android există și editorul Godot pentru Android („Godot Engine 4” în Google Play), care deschide același folder.

## Ce poți face
- **Rotire:** tragi cu degetul sau cu mouse-ul. Dacă nu atingi nimic 2–3 secunde, Orion se rotește singur.
- **Zoom:** ciupești cu două degete sau folosești rotița mouse-ului. De aproape, camera se uită la față.
- **Săritură:** atingi sau dai clic, iar Orion sare.
- **Butoane:**
  - **Fundal:** comuți între cer și alb, ca în planșa de personaj;
  - **Rotire:** pornești sau oprești rotirea automată.

La zoom 1, Orion încape întreg pe orice formă de ecran, între titlu și butoane.

## Modelul
Proiectul folosește doar **modelul complet**, cu 188 de mii de triunghiuri. O variantă redusă la 40 de mii arăta vizibil mai rău: blană zimțată, ochelari cu muchii, texturi întinse. Nu e nevoie de ea în Godot, care face singur, la import, variante mai ușoare (LOD) ale modelului. Le folosește doar când Orion e mic pe ecran, așa că diferența nu se vede, iar pe telefon merge repede.

Modelul nu are încă oase. „Respirația” și săritura mișcă tot modelul, sunt doar pentru previzualizare. Pentru mers și alte animații, modelul se poate pregăti cu oase automat în Mixamo, apoi se importă aici.

## Fișiere
| Fișier | Ce este |
|---|---|
| `main.gd` | tot codul: cerul, luminile, platforma, camera pe orbită, butoanele, controlul tactil |
| `main.tscn` | scena principală, care are doar scriptul de mai sus |
| `models/orion_tripo_game.glb` | modelul (1,2 m) |
| `project.godot` | setările: ecran portret 720×1280, randare „Mobile”, texturi comprimate pentru Android |

Ce poți regla în `main.gd`:
- `GLOW_ENERGY`: cât de tare strălucesc marcajele;
- `TARGET_FAR` / `TARGET_NEAR`: unde se uită camera;
- `ZOOM_MIN` / `ZOOM_MAX`: limitele de zoom;
- `FIT_HEIGHT` / `FIT_WIDTH`: cât spațiu se vede în jurul lui Orion la zoom 1;
- culorile cerului din `_build_world()`.

Dacă Godot afișează vreo eroare, mesajul apare în panoul **Output** sau **Debugger**.
