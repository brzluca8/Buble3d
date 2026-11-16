# Buble – versiunea de test pentru adulți (v2)

Godot 4.7, Android, portret, interfață în română. Branch: `buble-v2`.

- **Ecran principal**: orașul din glob de sticlă + mașina de bule (`scenes/globe.tscn`).
- **Dirijabilul**: Observator (abilități), Garderobă, Atelier, Seră, Salon (`scenes/airship.tscn`).
- **Economie din date**: `data/*.json` (vezi `../BALANCE.md`, generat de `../tools/balance.py`).
- **Teste**: `godot --headless --path godot -s res://tests/smoke_v2.gd` · capturi: `tests/shot_v2.gd`.
- **Documente**: `TESTING.md` (instalare pe telefon), `MODELS_TODO.md` (sloturi GLB), `MONETIZARE_V2.md`
  (plăți dezactivate, plugin-uri, juridic), `GLOB.md` (scena globului).
- Codul vechi (insula cu zaruri, Buble Blast, varianta pictată, prototipul web) e în `../legacy/`.

---

# Buble 3D – Godot 4

> **Prezentare 2.5D cu modele 3D reale** (`scenes/main.tscn`): cameră cinematografică oblică (~33°, FOV
> orizontal 25°, rotație limitată la ±25°, zoom, apropiere pe clădirea selectată, buton ⟲ pentru vederea
> generală). Insula, piața, clădirile și mascota sunt modele 3D; cerul, norii și insulele îndepărtate sunt
> elemente 2D/prerandate (`art3d/`). Varianta pictată 2D rămâne în `scenes/main2d.tscn`.

Versiunea principală a jocului: Godot 4.7, renderer **Mobile** (Vulkan, cu fallback automat la OpenGL ES 3),
ecran portret, interfață în română.

## Deschidere și rulare

1. Instalează Godot 4.7 (gratuit): https://godotengine.org/download
2. Godot → **Import** → alege `godot/project.godot`.
3. **F5** rulează jocul. Fereastra de test are proporții de telefon (405×720); rotița = zoom, tragere = rotire.

Test automat (logică, fără grafică):

```bash
godot --headless --path godot -s res://tests/smoke_test.gd
```

## Export pe Android (APK de test)

1. În Godot: **Editor → Manage Export Templates → Download and Install**.
2. Instalează **Android Studio** (pentru SDK) și **JDK 17**; în **Editor Settings → Export → Android** setează căile.
3. **Project → Export → Add… → Android**:
   - *Package → Unique Name*: `ro.buble.buble3d` (sau domeniul tău, inversat; nu se mai poate schimba după publicare)
   - *Screen → Orientation*: Portrait (preluat din proiect)
   - *Architectures*: arm64-v8a (+ armeabi-v7a pentru telefoane vechi)
4. Conectează telefonul cu *USB debugging* activ și apasă iconița Android din colțul editorului (one-click deploy),
   sau **Export Project** → `.apk`. Pentru Google Play exportă `.aab` (Gradle build) și semnează cu un keystore de release.

Keystore-ul de release **nu** se pune în git (este în `.gitignore`). Păstrează-l în siguranță: fără el nu mai poți publica actualizări.

## Structură

```
project.godot          setări (portret, Mobile renderer, compresie ETC2/ASTC)
autoload/game.gd       stare, economie, salvare (user://save.json), venit pasiv/offline
autoload/monetization.gd  strat unic pentru reclame și cumpărături (acum DEMO)
autoload/sfx.gd        efecte sonore generate din cod (pornit/oprit din Setări)
scenes/main.tscn       scena principală → scripts/main.gd (mediu, lumini, insulă, cer)
scripts/proc.gd        geometria procedurală (palat, observator, turn, magazin, seră, mascotă, teren)
scripts/models.gd      încărcarea modelelor din models/*.glb cu fallback procedural
scripts/building.gd    clădire: nivel, felinare, animație upgrade, selectare
scripts/mascot.gd      mascota (procedurală sau GLB cu animații)
scripts/camera_rig.gd  orbită, zoom (2 degete / rotiță), atingere = selectare
scripts/ui/            HUD, ferestre (Album, Prieteni, Evenimente, Magazin, Setări), Buble Blast
shaders/waterfall.gdshader  cascade animate
models/                modelele GLB: insula, cele 5 clădiri și mascota (vezi models/README.md)
tests/                 test de fum + captură de ecran
```

## Calitate grafică

- **Înaltă**: glow (bloom), umbre 2048, MSAA 2×.
- **Scăzută**: fără glow, umbre 1024, randare 3D la 75%, mai puțini nori.
- Se schimbă din **⚙️ Setări**.

Monetizarea: vezi [MONETIZARE.md](MONETIZARE.md).

## Bucla principală: zaruri + traseu

- **Energie (🫧)**: maximum 50, se reface 1 la 2 minute (și cât timp aplicația e închisă).
- **ARUNCĂ**: două zaruri; mascota sare pe traseul de 24 de pietre din jurul insulei.
  Dubla = aruncare gratuită. Trecerea pe la Start dă bonus. Ține apăsat = aruncare automată.
- **Multiplicator ×1…×20**: costă tot atâtea bule și înmulțește recompensele.
- Căsuțe: 🪙 monede, 🎁 cufăr (monede / bule / cărți), 🔨 atac și 🕳️ jaf asupra lui
  Contele Furtună (personaj din poveste, nu jucători falși), 🛡️ scut, 🫧 Buble Blast, ⭐ eveniment.
- Monedele construiesc cele 5 clădiri; insula completă dă premii și deschide insula următoare
  (costurile și recompensele cresc cu fiecare insulă).
- **Album**: 3 seturi × 9 cărți; un set complet dă +25 🫧. **Turneul Norilor**: praguri cu premii.
- Toată logica e în `autoload/game.gd` (testată în `tests/smoke_test.gd`); interfața în
  `scripts/ui/play_ui.gd`; traseul 3D în `scripts/board.gd`.

## Moduri de vedere și clădiri pe niveluri

- **Joc**: traseul de zaruri se vede, camera arată tot inelul. **Insulă** (🏗️ sau atingerea unei clădiri):
  traseul dispare, camera se apropie de clădiri. ARUNCĂ trece automat înapoi în modul Joc.
- Fiecare clădire are 5 modele (`models/<id>_1..5.glb`, generate de `art/blender/buildings.py`):
  crește și își schimbă forma la fiecare upgrade; scara e fixată după nivelul 5.
- Traseul e discret: piatră cu un inel colorat; iconițe doar la căsuțele importante.
- Meniul ☰ adună Setări, Vederea generală și Buble Blast.

## Online (opțional)

`autoload/net.gd` se conectează la serverul din `server/` (vezi `server/README.md`): ținte reale pentru
atac și jaf, mesaje primite, salvare în cloud, prieteni, cadouri de cărți, echipe de 4. Adresa se pune în
⚙️ Setări. Test cu serverul: `tests/net_test.gd`. Fără server, totul merge offline.

## Insulele

Fiecare insulă are propria temă (cer, ceață, lumină, acoperișuri, iarbă, piatră): 6 teme în `scripts/main.gd`.
Atacurile și jafurile se joacă pe Fortăreața Furtunii (`scripts/rival_island.gd`), cu animații.
Economia: vezi `ECONOMIE.md`.

## Buble Blast

- Niveluri: fiecare victorie deblochează nivelul următor (mai multe rânduri și culori, mai multe mutări).
- 💣 **Bomba** sparge tot în jurul locului unde cade; o primești la o reacție în lanț de 3+ bule (și la începutul nivelurilor 3+).
- 🌈 **Curcubeul** ia culoarea celui mai mare grup vecin; îl primești la un grup de 6+ (sau rar, la întâmplare).
- Atinge bula mică din stânga („schimbă") ca să inversezi bula curentă cu următoarea.
- Bonus de scor pentru mutările rămase; monedele câștigate merg pe insulă.

## Modelele 3D

Modelele din `models/` sunt generate cu scripturile din `art/blender/` (vezi `art/README.md`).
