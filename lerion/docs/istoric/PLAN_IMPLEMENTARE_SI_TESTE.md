# Plan concret de implementare Codex și criterii de acceptare

## FAZA A — AUDIT ȘI BACKUP (obligatorie)
- Confirmă repo-ul / folderul real care conține jocul funcțional din `REFERINTE/02_JOC_ACTUAL.jpg`.
- Inspectează `project.godot`, scena principală, toate scripturile și resursele existente. Raportează versiunea Godot, renderer, erorile și câmpurile actuale.
- Creează ramură/commit/snapshot. Fără ștergere/înlocuire în masă. Nu utiliza insula GLB din prototipuri vechi.
- Dacă lipsește proiectul actual, oprește implementarea și cere acces; pachetul este doar specificație + referințe.

## FAZA B — ECONOMIE + RECOMPENSE, FĂRĂ UI NOU
- Resurse de stat: monede, energie/max și regen, fragmente, puncte construcții, bilete, încărcare Super Cristal, 6 clădiri x nivel.
- Motor 3 simboluri cu ponderi configurabile și reguli exacte; validare configurație; seed controlat pentru test.
- O apăsare consumă o energie și produce exact o tranzacție; previne double tap.
- Persistență user://, teste de încărcare/recuperare.
- Debug panel (doar dezvoltare) pentru resurse și rezultate forțate.

## FAZA C — CRISTAL ȘI UI INTERACTIV
- Integrat în scena existentă: click ACTIVEAZĂ, impuls cristal, 3 simboluri, numere recompense, indicator energie și Super Cristal.
- Efect normal circa 1–1,5s; permite skip; nu blochează jocul la conversie.
- Este permis placeholder 2D pentru simboluri; finisajul 3D poate veni mai târziu.

## FAZA D — 6 CLĂDIRI / PROGRES
- 6 parcele asociate clădirilor nominalizate, sloturi independente, clar vizibile și selectabile.
- Niveluri 0–3, costuri configurabile, refuz dacă resurse insuficiente, actualizare după confirmare, progres salvat.
- Prima demonstrație: Atelierul lui Pongo; efect comic scurt placeholder e ok.
- Clădiri GLB sau mesh-uri simple înlocuibile: nu recrea întreaga hartă dacă modelul lipsește.

## FAZA E — VALIDARE ANDROID
- Deschide proiectul în Godot și rulează import + parser. Dacă ai executabil, rulează și headless; verifică animații/salvare cu test scene.
- Pe telefon: verifică portret, touch pe toate cele 6 sloturi, zoom, comportament la pauză/revenire, memoria și fluiditatea.
- Nu pretinde FPS sau framerate garantat fără profilare pe dispozitiv.
- La final: listă fișiere modificate, screenshot din scena REALĂ (dacă posibil), teste executate, erori/limitări.

## TESTE MINIME
1. Suma ponderilor = 100, pentru cel puțin 100.000 de simboluri distribuție apropiată de ponderi.
2. Triple: toate cele 6, `coin+hammer+chest` în toate 6 permutările, perechi, trei diferite.
3. Recompense de bază + un singur combo, fără dublare.
4. Energie 0 / 100, regenerare limitată la max, închiderea aplicației și revenirea.
5. Super Crystal 29->30, armare, consum o dată, reset 0, recâștigare progres ulterior.
6. Dublu tap, pauză/alt-tab, rotație/deconectare în mijlocul animației: niciun premiu dublu.
7. Construire 0->1->2->3, resurse insuficiente, max level, salvat după restart.
8. Fiecare din 6 platforme activează clădirea corectă, nu există al șaptelea slot.
9. La import: 0 erori parser; la gameplay: UI responsive și 3D cartoon păstrat.

## Ce NU implementăm în această etapă
- Traseu Monopoly/loop, multiplayer, social, chat, clasamente pe server, reclame, plăți, loot box comercial, noi regiuni și modele 3D ultra-detaliate.
