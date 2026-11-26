LERION V3 · REGATUL TRĂSNIȚILOR
Etapa 2.6 · Zaruri pe teren și tură animată

PORNIRE
Dezarhivează Lerion și importă project.godot în Godot 4.7.2. F5 pornește
scenes/board.tscn. ARUNCĂ folosește o energie pentru două zaruri independente.
Lerik parcurge suma lor în 1,5–2,5 secunde. Grăbește încheie imediat animația.
Glisează pentru cameră și apropie două degete pentru zoom. În buildul de debug,
Sac → Indici traseu afișează numerele dalelor.

PREZENTAREA ARUNCĂRII
Zarurile se rostogolesc pe pajiștea din interiorul circuitului. La zoom sau
deplasare, jocul alege un loc vizibil. Aruncarea durează 1,17 s în total.
După 0,74 s zarurile sunt stabile și Lerik pornește. Rezultatul rămâne pe
teren încă 0,26 s, apoi zarurile se retrag în 0,17 s. Adunarea rămâne în HUD.
Grăbește încheie prezentarea și așază pionul la poziția salvată.

Lerik își îndoaie corpul înainte de salt, alternează brațele și picioarele,
se lasă pe picioare la aterizare și ridică brațele la premiu. Camera îl
însoțește ușor pe orizontală. La aterizare, dala pulsează și suma apare
deasupra lui. Pictograma se ridică printre sclipiri, apoi zboară spre sold.
Punctele de construcție și jetoanele locale au un indicator temporar lângă Sac.
La cumpărare, modelul are un scurt recul elastic, apar praf și scântei, iar
dalele influențate pulsează. Mesajul arată diferența cumpărată, panoul arată
următoarea îmbunătățire sau „Nivel maxim”.

Palele morii, cele trei steaguri, cristalul, fluturii și cele patru jeturi
ale fântânii se mișcă discret. La baza fiecărui jet apare un cerc pe apă.
Sunetele provizorii sunt sintetizate în avans pentru rostogolire, pas,
aterizare, monedă, cristal și construcție. Fișierele WAV pot fi înlocuite în
assets/board/audio. Pe telefon, încearcă o aruncare la zoom minim și maxim,
apoi apasă Grăbește în timpul rostogolirii și redeschide jocul în timpul mersului.

CE PRIMEȘTI
Pictograma căsuței finale stabilește premiul. Dala se luminează, iar suma
creditată apare lângă Lerik. La energie 100, aruncarea consumă o unitate. Dacă
aterizezi pe energie, mai încape o unitate și apare „+1 energie”.
La fiecare pas 35 → START primești 100 de monede și începe turul următor.
De pe 34, suma 5 trece prin START și se oprește pe 3, cu premiul Hanului.
De pe 34, suma 2 înseamnă exact 100 de monede. Pornirea de pe START și
redeschiderea jocului păstrează soldul deja confirmat.

CONSTRUCȚII ȘI BALANSUL PROTOTIPULUI
Atinge o clădire sau parcela ei liberă pentru a vedea costul, dalele marcate
și valorile înainte/după. După confirmare, modelul, marcajele și panoul se
actualizează. Punctele mici de pe marginea dalelor indică nivelul clădirii.
La nivelul 3, panoul afișează „Nivel maxim” și premiul actual.

Clădire                Indici       Resursă             Nivel 0 / 1 / 2 / 3
Mina de Cristale       20, 21, 22   fragmente               5 / 6 / 7 / 8
Moara Trăsnită         14, 15, 16   energie                 2 / 3 / 4 / 5
Atelierul lui Pongo    24, 25, 26   puncte de construcție   2 / 3 / 4 / 5
Laboratorul lui Pufi   10, 11, 12   monede               75 / 83 / 94 / 113
                                    SAU fragmente           2 / 3 / 4 / 5
Piața Poznașă          31, 32, 33   monede             100 / 110 / 125 / 150
Hanul Aventurierilor    3,  4,  5   jetoane locale          1 / 2 / 3 / 4

Valorile întregi sunt provizorii și se citesc direct din assets/board/economy.tres.
Magia alege o singură alternativă, cu probabilitate egală. Dalele fără clădire
folosesc nivelul 0. Resursa conține tipurile de bază și zonele cu identificatori
stabili. Regulile de mișcare și plafonul energiei sunt în assets/board/rules.tres.
Costurile din CONFIG_PROTOTIP.json sunt 1000 + 10, 3000 + 25 și 8000 + 45
(monede + puncte de construcție). Sacul arată separat biletele și jetoanele.

SALVĂRI ȘI COMPATIBILITATE
Scena V3 păstrează două generații locale, în
user://satul_trasnitilor_board_v3.{0,1}.json. Înaintea primei migrări de la
schema 3, salvează ultima generație validă în satul_trasnitilor_board_v3.stage1.bak.
Schema 4 adaugă jetoanele și rezultatul economic al aruncării. La trecerea din
etapa 1 se păstrează poziția, turul, ultima pereche de zaruri, resursele,
momentul regenerării și cele șase niveluri. Premiile încep cu prima aruncare
nouă. Pentru revenirea manuală la etapa 1, cu aplicația închisă, păstrează
separat ambele generații actuale, apoi copiază fișierul .stage1.bak în slotul
satul_trasnitilor_board_v3.N.json, unde N este seq modulo 2 din copie.
Rollbackul reia progresul de la momentul migrării.

La prima trecere direct din V2, jocul citește salvarea V2, preia inventarul și
nivelurile și începe traseul la START. Modul Cristal Haotic poate fi rulat
separat cu F6 pe scenes/main.tscn și folosește propriile fișiere.
În V3 costul, zarurile, destinația, turul, bonusul START și premiul efectiv
intră în aceeași scriere înainte de mișcare. Reluarea citește rezultatul salvat.

TEST PE ANDROID
1. În editorul Godot pentru Android, importă proiectul extras, pornește Run
   Project și ține telefonul în portret. Pentru un APK, folosește presetul
   Android în editorul desktop, șabloanele Godot 4.7.2, OpenJDK 17 și Android
   SDK configurat în Editor Settings → Export → Android.
2. Pentru actualizarea unei instalări existente păstrează datele, identificatorul
   com.lerion.regat și cheia de semnare. Cu depanarea USB autorizată, instalează
   APK-ul prin adb install -r Lerion-V3-debug.apk. Editorul Android și APK-ul
   pot folosi directoare de date diferite.
3. Cu Piața la nivelul 1 și cel puțin 3000 de monede și 25 de puncte, atinge
   Piața din stânga jos. Verifică indicii 31, 32 și 33 și „110 → 125 monede”.
   Confirmă, închide panoul și aruncă până ajungi pe una dintre aceste dale.
   Compară mesajul +125 cu soldul. Dintr-o salvare nouă poți folosi bugetul
   inițial pentru a construi Piața și obține restul resurselor jucând.
4. Verifică pasul 35 → 0, oprirea pe START, dublul tap și Grăbește. În timpul
   mersului, trimite jocul în fundal, apoi repetă închizând și redeschizându-l.
   Compară poziția și resursele cu aruncarea confirmată. Încearcă selecția și
   zoomul pe ecranul telefonului.

TESTE GODOT
    godot --headless --editor --import
    godot --headless --quit-after 120
    godot --headless --script tools/check_board.gd
    godot --headless --script tools/check_board_rewards.gd
    godot --headless --fixed-fps 60 --script tools/check_board_polish.gd
    godot --headless --script tools/check_map.gd
    godot --headless --script tools/check_crystal.gd
    godot --headless --script tools/check_village_flow.gd

Testele creează profiluri locale de probă. Suita economiei reproduce achiziția
Pieței și aterizarea pe 32, apoi verifică toate clădirile, dalele neutre,
magia, START, plafonul energiei, migrarea, reluarea și scrierea eșuată.
