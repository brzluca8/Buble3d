# Lerion V3 – Etapa 1: traseu închis + două zaruri (prototip separat)

> **Important:** acesta este un **prototip Godot separat**, construit fără acces la proiectul
> real Lerion (nu era în niciun repository disponibil și nici pe calculator). Castelul, cristalul,
> cele 6 clădiri și Lerik sunt **modele low-poly procedurale** care imită captura
> `docs_v3/REFERINTE/02_PROTOTIP_GODOT_ACTUAL.jpg` – **nu** sunt modelele tale reale.
> Nivelurile clădirilor, monedele și cristalele din prototip sunt valori de test.
> Logica (traseu, zaruri, mutare, salvare) este separată de grafică, ca să poată fi mutată
> în proiectul real fără rescriere.

## Ce face etapa 1

| Cerință | Unde | Stare |
|---|---|---|
| 6 clădiri depărtate, 3 stânga / 3 dreapta, niveluri 0–3 | `scripts/world/building_visual.gd`, `board_config.gd` | ✅ |
| Castel albastru în spate, fântână cu cristal în centru, teren continental | `scripts/world/world_builder.gd` | ✅ |
| Drum șerpuit, **o singură buclă închisă**, 36 căsuțe, `35 → 0` | `scripts/board/board_path.gd` (nod `LoopPath` = `Path3D`) | ✅ |
| Trece pe lângă toate clădirile, nu intră pe platforme / cristal / castel | validare automată `BoardPath.validate_layout()` | ✅ (spațiu minim 0,51) |
| Buton **ARUNCĂ**: −1 energie, 2 zaruri 1–6, Lerik avansează exact suma | `scripts/main.gd`, `services/` | ✅ |
| Mutare fluidă 1,5–2,5 s, apăsare repetată = grăbire (nu a doua aruncare) | `scripts/characters/lerik.gd` | ✅ (măsurat 2,2 s la 9–10 pași) |
| Trecerea peste START detectată (mesaj „START!”) | `BoardMovement.start_passes` | ✅ (bonusul de monede vine în etapa 2) |
| Salvare: poziție, energie, niveluri, resurse; fără re-aruncare la repornire | `scripts/game/game_state.gd` (`user://lerion_v3_save.json`, mod `board_v3`) | ✅ |
| Energie +1 la 5 minute, maxim 100 | `GameState.update_energy_regen()` | ✅ |
| Recompense pe căsuțe, influența clădirilor, Super Cristal | – | ⏳ etapele 2 și 3 |

Ordinea zonelor pe traseu (de la START, în sensul de mers): Han → Laborator → Moară → Mină → Atelier → Piață.
Indicii căsuțelor se văd cu butonul **„# Căsuțe”** (activ implicit în această livrare).

## Cum testez pe telefon (fără PC)

### Varianta A – instalezi APK-ul (cel mai simplu)
1. Descarcă `lerion_v3/apk/Lerion_V3_etapa1_debug.apk` (din GitHub, branch-ul `ccr-eecdf985-0qwwm6`, butonul „Download raw file”).
2. Deschide fișierul pe telefon. Android cere permisiunea „Instalare aplicații necunoscute” pentru browser / Files – acord-o.
3. Pornește **Lerion V3**. E o versiune *debug* (arm64, Android 7.0+), semnată cu o cheie de test.

### Varianta B – în editorul Godot pentru Android
1. Pe GitHub: branch-ul `ccr-eecdf985-0qwwm6` → **Code → Download ZIP**, apoi dezarhivează.
2. În Godot 4.7 (Android) → **Import** → alege `lerion_v3/project.godot`.
3. Apasă ▶ (Play).

### Ce să verifici
- Apasă **ARUNCĂ**: zarurile se rostogolesc scurt, apoi Lerik sare din căsuță în căsuță exact cât suma.
- Apasă din nou în timpul mersului: butonul devine **» GRĂBEȘTE** – mersul se accelerează, energia scade o singură dată.
- **Zoom** (sau ciupire cu două degete): camera îl urmărește pe Lerik.
- Închide aplicația în timpul mersului și redeschide-o: Lerik e pe căsuța finală, energia nu scade de două ori.
- **+Energie (test)** reumple energia (există doar în versiunile debug).

## Teste automate (rulate în acest mediu, Godot 4.7.2)

```
godot --headless --path lerion_v3 --script res://tests/run_tests.gd
=== Rezultat: 46 trecute, 0 eșuate ===
```

Acoperă:
- **Traseu:** 36 căsuțe, pas uniform (inclusiv 35→0), fără auto-intersecții, nicio porțiune de drum prea aproape de alta, distanță ≥ 0,45 față de platforme, cristal (în interiorul buclei) și castel, ordinea zonelor, plus două teste negative (clădire pusă pe drum, traseu în formă de 8 – ambele respinse).
- **Zaruri:** 360.000 aruncări – fiecare zar 1–6, sume exact 2..12, distribuție triunghiulară (7 ≈ 6/36, 2 și 12 ≈ 1/36).
- **Mutare:** toate cele 36 × 11 combinații (pași consecutivi, fără salturi), trecerea 35→0, START la trecere și la oprire fix pe 0, nu la plecare, durata 1,5–2,5 s.
- **Tranzacție/salvare:** o singură aruncare la dublu-tap, recuperare după închidere în mijlocul mersului, păstrarea nivelurilor și resurselor, copie `.bak`, salvare coruptă păstrată ca `.corupt` (nu ștearsă), regenerarea energiei.
- **Scenă:** `LoopPath` există, 36 căsuțe, 6 clădiri, Lerik pornește pe START, se oprește exact pe căsuța calculată, durata reală a mersului.

Alte verificări făcute: import și rulare fără erori de parsare; editorul nu raportează avertismente;
capturi reale (randare software) în `capturi_etapa1/` – Mobile (Vulkan) și Compatibility (OpenGL);
export Android reușit: APK semnat (schema v2) și verificat.

## Ce NU am putut verifica
- **Pe un telefon real:** atingere, ciupire pentru zoom, zona sigură (notch), performanța (FPS), încălzirea. Capturile sunt făcute cu randare software, nu pe GPU de telefon.
- **Umbrele în timp real sunt dezactivate:** în randarea software se comportau imprevizibil și nu le-am putut verifica; sunt și costisitoare pe telefon. Lerik are o umbră simplă sub el. Se pot reactiva după un test pe telefon.
- **Proiectul tău real** (modelele, nivelurile salvate, codul vechi cu Cristalul Haotic cu 3 simboluri): nu exista în mediul meu, deci nimic din el nu a fost modificat sau migrat. Mecanica veche nu este în acest prototip; în proiectul real trebuie păstrată separat (mod / branch), conform `docs_v3/MIGRARE_FARA_PIERDERI.md`.
- **APK-ul** e semnat cu o cheie de test temporară: o versiune viitoare semnată cu altă cheie poate cere dezinstalarea celei vechi.

## Structura
```
lerion_v3/
  project.godot            portret 720×1280, randare Mobile (fallback automat la Compatibility)
  main.tscn / scripts/main.gd   leagă totul
  scripts/board/           BoardConfig (valori configurabile), LoopGeometry (geometrie pură),
                           BoardPath (Path3D + căsuțe + validare), BoardTile
  scripts/services/        DiceRollService, DiceRoll, BoardMovement, RollTransaction
  scripts/game/            GameState (energie, poziție, salvare versionată)
  scripts/world/           WorldBuilder, BuildingVisual (niveluri 0–3), MeshBuilder, Spinner
  scripts/characters/      Lerik (placeholder înlocuibil)
  scripts/ui/              Hud, DieFace, HudIcon
  scripts/camera/          CameraRig (ansamblu / urmărire, ciupire)
  tests/run_tests.gd       46 de teste automate
  tools/                   capture.gd (capturi), geom_report.gd (raport traseu)
  docs_v3/                 documentația V3 primită (specificația)
  capturi_etapa1/          capturi din această etapă
  apk/                     APK-ul de test
```

## Mutarea în proiectul real (când e disponibil)
1. Checkpoint Git în proiectul real.
2. Copiază `scripts/board/`, `scripts/services/`, `scripts/game/game_state.gd`, `scripts/characters/lerik.gd`, `scripts/ui/die_face.gd`.
3. Înlocuiește în `BoardConfig.create_default()` pozițiile clădirilor, cristalului și castelului cu coordonatele reale din scenă; rulează `tools/geom_report.gd` și testele până când validarea nu mai are erori.
4. Mută clădirile reale la noile poziții (nu le șterge); adaugă `BoardPath` ca nod separat.
5. Conectează `GameState` la salvarea existentă printr-o migrare versionată (resursele și nivelurile reale au prioritate).

## Următoarele etape
- **Etapa 2:** recompensa căsuței de oprire (monede, cristale, construcție, energie, magie, misiune), bonusul START +100, 2–3 căsuțe influențate de fiecare clădire (×1,10 / ×1,25 / ×1,50), popup scurt „Mina Nv.2: +25%”.
- **Etapa 3:** Super Cristal (+1 la fiecare aruncare, 30/30, ×2 pentru următoarele 3 opriri), reacții scurte Pongo / Pufi.
