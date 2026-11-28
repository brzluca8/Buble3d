# AGENTS.md — LERION V3 (TRASEU + DOUĂ ZARURI)
> Actualizare Etapa 4.1 — cuferele se pot deschide și dau cărți colecționabile (36 de cărți, 6 colecții), salvare v7. Vezi [ETAPA_4_1_CUFERE_CARTI.md](docs/ETAPA_4_1_CUFERE_CARTI.md). Albumul complet și schimburile nu sunt implementate.
> Actualizare Etapa 3.5 — căsuțele nu mai acordă energie, regenerarea este +1 la 10 minute, Moara Trăsnită crește energia din evenimente, există evenimente temporare. Vezi [ETAPA_3_5_ENERGIE_EVENIMENTE.md](docs/ETAPA_3_5_ENERGIE_EVENIMENTE.md); suprascrie regulile de energie din documentele anterioare.
> Actualizare Etapa 3.0 — la cererea utilizatorului, Super Cristalul deschide Ruleta Magică (50, apoi 100 de aruncări) cu cufere salvate. Vezi [ETAPA_3_0_SUPER_CRISTAL.md](docs/ETAPA_3_0_SUPER_CRISTAL.md). Regula x2 pentru 3 aterizări și interdicția ruletei de mai jos sunt depășite pentru această mecanică.
## Prioritate
0. Instrucțiunile actuale ale utilizatorului și regulile de siguranță ale mediului.
1. `LERION_DECIZII_V3.md`, `TRASEU_LOOP_GEOMETRIE.md`, `REGULI_ZARURI_ECONOMIE.md`, `CLADIRI_ZONE_INFLUENTA.md`, `CRISTAL_SUPER_BONUS.md`, `MIGRARE_FARA_PIERDERI.md`.
2. `PLAN_CODEX_SI_TESTE.md`, configurația exemplu și capturile.
3. Codul funcțional al proiectului real; reutilizează ce este util, fără să presupui că versiunile vechi sunt adevărul de design.
4. Orice `AGENTS.md`/V2 mai vechi care spune că Cristalul Haotic cu 3 simboluri este gameplay-ul principal: **DEPĂȘIT pentru modul V3**.

## Principii ferme
- **Lerion** = joc Android portret, 3D cartoon low-poly propriu, vesel, cu umor scurt și simpatia lui Lerik, Pongo, Pufi. Nu copia elemente distincte, UI, artă sau branding din Monopoly GO/Dice Dreams/Coin Master.
- Păstrează **terenul continental actual**; fără insule, margini, cascade obligatorii, ocean.
- Păstrează **castelul** și **fântâna cu cristal**; nu consumă cele 6 sloturi.
- **Șase clădiri 0–3 niveluri**, poziționate aerisit: Mina de Cristale, Moara Trăsnită, Atelierul lui Pongo, Laboratorul lui Pufi, Piața Poznașă, Hanul Aventurierilor.
- **Traseu cu 36 de căsuțe (configurabil 30–36)**; o singură buclă netedă, fără auto-intersecții, fără scurtături/ramuri, drumul trece PE LÂNGĂ cele 6 clădiri, nu prin ele; zona cristalului nu e căsuță de traseu.
- **Două zaruri standard (1–6 fiecare)**, suma 2–12 = numărul de căsuțe parcurse. Număr aruncări consumă 1 energie/roll (configurabil, exemplu V3).
- **Recompensă doar la oprire**, START bonus la traversare; upgrade-urile clădirilor cresc bonusul căsuțelor asociate; Super Cristal charge 30, activare la alegere, x2 pentru următoarele 3 ATERIZĂRI.
- **Nu introduce** automat sistemele vechi 3 simboluri/catapulta/ruleta, multiplayer, IAP, Ads, server, turnee online sau trasee multiple în această etapă.
- Nu șterge progres salvat, niveluri, resurse, poziții curente fără migrare versionată și confirmare.

## Inginerie + livrare
- Creează branch/commit înainte de modificări; inspectează `project.godot`, scena curentă și resursele.
- Transformările/pozițiile pe hartă trebuie adaptate la coordonatele reale din scena existentă; fișierul SVG este o schiță, NU hartă 3D exportabilă.
- Separă `BoardPath/TileData`, `DiceRollService`, `RewardService`, `BuildingInfluenceService`, `CrystalChargeService`, `SaveGame` și HUD. API-uri testabile, configurabile, GDScript tipizat.
- Nu face roll suplimentar la reluarea animației, dublu tap sau restart. O singură tranzacție per aruncare.
- Android: input touch, portrait, layout responsiv/safe area, cameră 3D lizibilă, target 1,5–2,5 secunde pentru mutare normală, skip/fast-forward unde e posibil.
- Refolosește modele reale existente. Dacă lipsesc Lerik/animările, pune marker placeholder explicat și nu promite grafică neprodusă.
- Rulează Godot/tests când este disponibil; raportează exact ce a fost verificat versus ce trebuie testat pe telefon.
- Înainte să schimbi materialele sau harta, verifică capturile de referință: nu degrada stilul deja acceptat.
- Dacă proiectul Godot actual nu este disponibil, **nu crea alt joc nou din presupuneri**; cere acces la fișierele actuale.
