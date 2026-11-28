# AGENTS.md — Lerion: Regatul Trăsniților (reguli active)

Actualizat la Etapa 4.2. Versiunea anterioară, cu reguli V3 depășite, este în [`docs/istoric/AGENTS_V3_ISTORIC.md`](docs/istoric/AGENTS_V3_ISTORIC.md); indexul documentelor istorice este în [`docs/istoric/README.md`](docs/istoric/README.md).

## Prioritate
0. Instrucțiunile actuale ale utilizatorului și regulile de siguranță ale mediului.
1. Acest fișier și documentele de etapă din `docs/` (cea mai recentă etapă are prioritate la conflict).
2. `LERION_DECIZII_V3.md`, `TRASEU_LOOP_GEOMETRIE.md`, `REGULI_ZARURI_ECONOMIE.md` (cu actualizările din etape), `MIGRARE_FARA_PIERDERI.md`.
3. Codul funcțional și testele din `tools/` sunt adevărul despre comportamentul actual.

## Jocul, așa cum este acum
- Android portret, Godot 4.7.2, renderer **GL Compatibility**. Scena principală `scenes/board.tscn` (modul V3). Modul V2 (`scenes/main.tscn`, cristal cu 3 simboluri) rămâne în cod doar pentru migrare.
- Hartă continentală cu castel, fântână cu cristal central și **6 clădiri cu niveluri 0–3**: Mina de Cristale, Moara Trăsnită, Atelierul lui Pongo, Laboratorul lui Pufi, Piața Poznașă, Hanul Aventurierilor. Amplasarea și geometria traseului nu se schimbă fără cerere explicită.
- **Circuit închis cu 36 de căsuțe**, START la 0. **Două zaruri 1–6**; Lerik avansează cu suma. Premiu numai la aterizare; START +100 monede la traversare.
- Căsuțe: monede, cristale (fragmente), construcție, magie, jetoane — **nicio căsuță de energie** (Etapa 3.5). Bonusurile clădirilor sunt **globale pe categorie** (Etapa 2.8). Moara crește energia din evenimente (+0/10/20/30%).
- Energie: cost 1/aruncare, capacitate 100, regenerare +1 la 10 minute, oprită la ≥100; premiile pot depăși 100 (Etapa 3.5).
- **Super Cristal**: 50 aruncări prima dată, apoi 100; activare manuală → **Ruleta Magică** (energie 10/20/30, cufere lemn/argint/aur; probabilități în `CONFIG/super_crystal.json`) (Etapa 3.0).
- **Cufere și cărți**: 3/4/5 cărți, 36 de cărți în 6 colecții, inventar cu duplicate, salvare v7 (Etapa 4.1). Albumul complet și schimburile NU sunt implementate.
- **Evenimente**: „Festivalul lui Pufi” (puncte la aterizare, praguri cu revendicare unică) (Etapa 3.5).
- **Developer Panel**: numai în build DEBUG, profil separat `user://lerion_developer/`.
- Prezentare: Etapa 4.0 (polish) și Etapa 4.2 (animație, cameră, VFX, audio; vezi `docs/ETAPA_4_2_PREMIUM.md`) — **numai vizual**, fără efect asupra stării. Lerik, Pongo și Pufi sunt rig-uri din piese rigide (fără schelet); numele pieselor din GLB sunt contract pentru animație.

## Principii ferme
- Personaje originale: **Lerik** (râs aventurier cu ochelari, eșarfă, rucsac), **Pongo** (constructor verde, cască galbenă; niciodată „Bubu”), **Pufi** (dragon mic mov/roz). Nu copia artă, UI sau branding din alte jocuri.
- Nu modifica economia, probabilitățile, rezultatul zarurilor sau recompensele prin prezentare. Animațiile primesc chitanțe deja salvate și nu acordă nimic.
- O singură tranzacție per acțiune (aruncare, rotire, deschidere, revendicare). Dublu tap, Grăbește, închiderea aplicației și repornirea nu pot dubla sau pierde recompense.
- Nu șterge progres salvat; schimbările de schemă se fac prin migrare versionată, testată.
- Nu introduce backend, multiplayer, IAP, reclame sau mecanici noi fără cerere explicită.
- Nu prezenta placeholder-e drept artă finală; marchează-le (`art.status = "placeholder"`, documentație).
- Nu genera APK/AAB și nu rula export Android decât la cerere explicită.

## Arhitectură (pe scurt)
- Reguli pure, fără noduri: `scripts/economy/` (energie, evenimente, cărți), `scripts/crystal/super_crystal_service.gd`, `assets/board/economy.tres`, `rules.tres`.
- Tranzacții și salvare: `scripts/board/board_save.gd` (v7), profil DEBUG `scripts/developer/dev_profile.gd`.
- Orchestrare scenă: `scripts/board/board_game.gd` — leagă tranzacțiile de prezentare; nu adăuga aici efecte mari, folosește controlerele de prezentare (`polish.gd`, camera, animatorul lui Lerik, controlerul zarurilor, ecranele din `scripts/crystal/`).
- Prezentarea trebuie să poată fi întreruptă, accelerată sau oprită fără efect asupra stării; nodurile temporare se eliberează singure.

## Inginerie și livrare
- Lucrează pe ramură dedicată, cu checkpoint (tag) înainte de fiecare etapă și commit pe fază.
- Rulează suitele din `tools/check_*.gd` cu `XDG_DATA_HOME` separat (vezi `docs/PREDARE.md`); raportează exact ce a fost executat și ce rămâne de verificat pe telefon.
- Performanță: țintă 60 FPS pe telefoane compatibile, stabil la 30 FPS pe cele slabe; niveluri de calitate Redus/Mediu/Ridicat și „Efecte vizuale reduse”. Nu raporta estimări drept FPS măsurat pe telefon.
- Asset-urile 3D se generează reproductibil cu scripturile Python din `tools/` (`build_*.py`); nu edita GLB-urile manual.
