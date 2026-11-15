# Buble 3D – predare către Claude Code

## Obiectiv
Joc mobil 3D (portret, Android, interfață în română), social și casual, cu aspect premium fantasy: insulă plutitoare cu palat turcoaz, observator, turn, magazin și seră, mascotă cu ochelari de aviator, mini-joc Buble Blast. Referința artistică este randarea cu „Grădina dintre nori" (turcoaz, albastru, violet, auriu). Gratuit; fără plăți reale; funcțiile sociale fără backend se marchează DEMO, fără jucători simulați.

## Starea actuală
Un singur fișier: `buble.html` (Three.js r128 prin CDN, JS simplu, fără build). Conține:
- Insulă 3D procedurală: 5 clădiri (palat, observator, turn, magazin, seră), fântână animată, cascade cu particule, vegetație, felinare, nori sprite, insule îndepărtate.
- Texturi generate pe canvas (piatră, solzi de acoperiș, iarbă, stâncă, pavaj) și glow cu sprite-uri aditive (bloom fals).
- Cameră orbitală proprie: tragere = rotire, ciupire = zoom, atingere = selectare clădire (raycast).
- Mascotă procedurală care merge spre clădirea aleasă și sare la upgrade.
- Economie: monede, upgrade pe clădire (nivel 1–5, cost `bază * nivel^1.7`), XP, nivel jucător, venit pasiv la 10 s și offline (maxim 1 h). Salvare în LocalStorage (`buble3d`).
- Buble Blast: canvas 2D, grilă hexagonală 8 coloane, 25 de mutări, grupuri de 3+, bule căzute (reacție în lanț), monede transferate în insulă.
- Panou „🧩 Modele 3D": încarcă `.glb` pentru palat, observator, turn, magazin, seră, mascotă; modelul înlocuiește piesa procedurală (scalat la înălțimi fixe) și se salvează în IndexedDB.
- Ecrane DEMO: Album, Prieteni, Evenimente, Magazin.

Codul nu a fost rulat sau verificat vizual până acum. Primul pas: deschide-l, repară erorile din consolă.

## Limita pe care o rezolvă Code
Pagina publicată nu poate încărca fișiere externe și are limită de 16 MB. Calitatea randării cere modele GLB sculptate, texturi pictate și lumină coaptă, nu doar geometrie din cod.

## Plan propus
1. **Proiect:** Vite + React + React Three Fiber + Drei + Zustand (stare + salvare). Portează scena din `buble.html` în componente (`Island`, `Building`, `Mascot`, `Clouds`, `Waterfalls`) și UI-ul în React/CSS.
2. **Pipeline de modele:** `public/models/{palat,obs,turn,mag,sera,mascot,insula}.glb`, încărcate cu `useGLTF`, cu înlocuire automată a variantei procedurale dacă fișierul lipsește. Înălțimi țintă: palat 5.5, observator 4.5, turn 5.3, magazin 3, seră 3, mascotă 1.6.
3. **Calitate:** bloom real (`@react-three/postprocessing`) cu buget pentru mobil, texturi baked (AO + lumină) pe GLB, nori volumetrici, cascade cu mai multe straturi.
4. **Test pe Android:** server de dezvoltare accesibil pe rețeaua locală sau deploy gratuit pentru previzualizare; ulterior ambalare ca aplicație (de ex. Capacitor).
5. **Buble Blast:** niveluri multiple, bule speciale, efecte sonore.
6. **Social (mai târziu):** conturi, prieteni, vizitarea insulelor, dueluri, albume cu schimburi, evenimente pentru 4 jucători, cluburi. Arhitectură cu un strat `api/` separat; până atunci, ecranele rămân DEMO.
7. **Monetizare (mai târziu):** reclame, VIP, Season Pass. Nu se implementează plăți acum.

## Reguli
- Interfață exclusiv în română.
- Tehnologii gratuite, fără servicii comerciale obligatorii.
- Nu înlocui lumea 3D cu imagini statice.
- Optimizează pentru telefoane (poligoane, texturi, număr de lumini).

## Prompt de lipit în Claude Code
> Citește `BUBLE_HANDOFF.md` și `buble.html`. Creează proiectul Vite + React + React Three Fiber, portează scena și UI-ul, păstrând toate funcțiile din starea actuală. Apoi pregătește folderul `public/models` cu încărcare GLB și fallback procedural. Rulează proiectul și repară erorile.
