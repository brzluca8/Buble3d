# Buble 3D – Godot 4

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

## Buble Blast

- Niveluri: fiecare victorie deblochează nivelul următor (mai multe rânduri și culori, mai multe mutări).
- 💣 **Bomba** sparge tot în jurul locului unde cade; o primești la o reacție în lanț de 3+ bule (și la începutul nivelurilor 3+).
- 🌈 **Curcubeul** ia culoarea celui mai mare grup vecin; îl primești la un grup de 6+ (sau rar, la întâmplare).
- Atinge bula mică din stânga („schimbă") ca să inversezi bula curentă cu următoarea.
- Bonus de scor pentru mutările rămase; monedele câștigate merg pe insulă.

## Modelele 3D

Modelele din `models/` sunt generate cu scripturile din `art/blender/` (vezi `art/README.md`).
