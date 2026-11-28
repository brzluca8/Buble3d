> Actualizare Etapa 2.8 — bonusurile clădirilor se aplică global pe categorie. Distribuția și regulile curente sunt în [ETAPA_2_8.md](docs/ETAPA_2_8.md). Descrierile zonelor locale de mai jos aparțin etapelor anterioare.

# Plan executabil, incremental, cu verificări clare
## Etapa 0. Audit
- Verifică repository-ul curent, `project.godot`, scenă principală, scripts, modelele existente, salvare și camera. Identifică orice AGENTS.md V2 contradictoriu.
- Creează branch/snapshot. Nu șterge clădirile și nu reseta resursele (captura prototipului arată clădiri completate și bani/cristale acumulate).

## Etapa 1. Geometrie + camera – PRIMA LIVRARE
- Mărește distanța dintre cele 6 clădiri, păstrează castelul și cristalul.
- Construiește **o buclă unică** cu `Path3D/Curve3D` + 36 căsuțe, poziționate de-a lungul curbei, traseu clar și vizibil, fără coliziuni cu clădirile.
- Adaugă marker Lerik placeholder dacă nu există rig/GLB real. Poziția 0 START, următoarele 35 poziții ordonate, 35→0 este vecinătate fizică. Dovedește cu debug overlay indicele tile.
- În prima livrare: aruncă 2 zaruri, Lerik face exact 2..12 pași, se oprește, nu sunt recompense elaborate încă.

## Etapa 2. Economie și recompense
- Integrează 1 energie per roll, tile landing reward și bonus START; păstrează economia/salvările V2.
- Asociază 2–3 tile-uri per clădire, bonus de upgrade configurabil.
- HUD clar cu suma zarurilor, resurse, niveluri și feedback de recompensa.

## Etapa 3. Cristal + polish
- Adaugă încărcare 0–30 per roll, Super Cristal x2 la 3 aterizări, persistare și interfață clară.
- Animații scurte, mici reacții Lerik/Pongo/Pufi (placeholder acceptat), optimizează mobil.

## Etapa 4. Test Godot/Android
- Rulează import, parsare, scenă și unit tests sau GDScript script de validare. Pe Android testează camera/atingerea/zoom.
- Nu raporta teste inexistente; prezintă loguri și capturi reale, dacă poți.

## Acceptance criteria
1. Circuit închis unic, continuu, `tiles[35] -> tiles[0]`, fără bifurcații. Toate 6 clădirile se află pe lângă circuit, nu pe el.
2. Poți urmări 36 de tile-uri în ordinea cerută; LoopPath clar identificabil în scenă; niciun segment intră pe platforme/clădiri/cristal.
3. Zarurile 1–6 fiecare, sumă 2–12; 36 rezultate echiprobabile; 7 apare teoretic 6/36, 2 și 12 câte 1/36.
4. La fiecare roll, deplasarea face exact `steps` tile-uri, fără teleportări, permite wrap peste 35→0 și acordă START doar la crossing.
5. Recompensă doar la aterizare, fără premiu pentru căsuțele traversate; nu se acordă de două ori la dublu tap, skip, pause/reload.
6. Upgradeurile celor 6 clădiri cresc recompensa la tile-urile desemnate; nu influențează alte tile-uri, START sau energia negativă.
7. Cristalul crește +1 la roll valid până la 30; la alegere x2 pentru exact 3 aterizări, fără stacking și cu save/reload.
8. 6 clădiri cu nivelurile 0–3 păstrate (sau migrate explicit). Castelul și fântâna nu sunt în sloturi.
9. Funcționare mobil Android portret și 0 erori parser. Teste/documente care descriu limitele reale.

## Ce NU face acum
Nu implementa trasee alternative, multiplayer, reclame, IAP, chat, regate suplimentare, fizică realistă la zaruri sau upgrade complet al graficii din randarea artistică dacă asset-urile lipsesc.
