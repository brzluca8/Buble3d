# Buble 3D – predare v2 (direcția: Orașul din bulă)

## Decizie
Lumea jocului este un oraș într-un glob de sticlă, nu o insulă plutitoare.
- Se leagă de numele jocului (Buble) și de mini-jocul Buble Blast.
- Scena e compactă, deci mai ușor de adus la calitate premium decât o insulă mare cu stâncă, apă și vegetație.
- Prietenii sunt vizibili chiar în ecranul principal, ca bule mici în jurul globului tău. Acesta e motivul principal pentru retenție.

Motor: Godot 4 (proiectul existent, Android, portret, interfață în română). Nu pierde ce funcționează: economie, upgrade-uri, Buble Blast, salvare. Se schimbă doar lumea 3D și ecranul principal. Lucrează pe un branch separat.

## Fișiere de referință (pune-le în repository, în `reference/`)
- `render.png`: randarea inițială. De acolo păstrezi paleta (turcoaz, violet, auriu, albastru), arhitectura clădirilor și mascota.
- `lumi.html`: schiță 3D a direcției (deschide-l într-un browser). Arată compoziția: glob cu margine irizată, piedestal cu inele aurii, bule care urcă, bule de prieteni în jur. Este doar o schiță, nu finisajul final.
- `buble.html`: prototipul vechi cu insula. Util doar pentru logica de joc (cost de upgrade `bază * nivel^1.7`, venit pasiv, offline maxim 1 h).

## Lumea
- Glob de sticlă (rază ~6 unități). Înăuntru, același oraș: palat cu cupole turcoaz, observator, turn, magazin, seră, fântână, alei de piatră, copaci, flori, felinare, mascota.
- Sticla: shader cu efect Fresnel (margine luminoasă irizată, centru aproape transparent), fără refracție costisitoare. Reflexie falsă: un sprite luminos orientat mereu spre cameră.
- Piedestal violet cu inele aurii și rune turcoaz luminoase.
- Bule care urcă în glob (particule). La câștig în Buble Blast apar mai multe.
- Fundal: cer de amurg cu stele (indigo, violet, turcoaz).
- Cameră oblică, rotire limitată, zoom cu două degete, rotire lentă când nu atingi ecranul.
- Upgrade: clădirea crește și primește ornamente. Nivelul orașului deblochează un inel auriu pe glob și o treaptă de mărire.

## Stratul social (prioritate maximă)
Fiecare jucător este o bulă. Prietenii apar ca bule mai mici care plutesc în jurul globului tău, fiecare cu un mini-oraș înăuntru, în funcție de nivelul lui.

Interacțiuni, în ordinea implementării:
1. Atingi o bulă de prieten: camera se apropie și intri în bula lui (vizită). Vezi orașul lui și poți lăsa un cadou (monede sau o carte), o dată pe zi.
2. Semnale vizuale: bula pulsează sau primește un steag când un prieten te-a vizitat sau ți-a trimis un cadou.
3. Schimb de cărți din album: cartea duplicat pleacă într-o bulă mică spre prieten.
4. Dueluri Buble Blast asincrone: aceeași hartă, scoruri comparate.
5. Evenimente cooperative pentru 4: patru bule se unesc într-o bulă mare comună, care se umple în echipă.
6. Cluburi și clasamente: bulele unui club formează un roi.

Reguli obligatorii:
- Fără backend, nicio bulă nu reprezintă un jucător real. Ecranul arată sloturi goale cu „Invită un prieten", marcate DEMO. Nu simula prieteni.
- Problema pornirii: la lansare nu are cine să apară în jurul globului. Pentru primele versiuni, pregătește invitație prin link sau cod de prieten și o recompensă pentru invitație.
- Arhitectură: interfață `FriendsRepository` (list_friends, get_city, send_gift etc.), cu o implementare locală `LocalDemoRepository` (listă goală plus sloturi) și, mai târziu, una cu backend, fără să schimbi interfața grafică.
- Juridic: conturi, prieteni și mesaje, mai ales cu minori, cer verificare pentru protecția datelor copiilor (consimțământ parental, moderare). De făcut înainte de lansare.

## Calitate vizuală (cât mai aproape de randare)
- Lumină: glow pe ferestre, felinare, gema fântânii și cupole; tonemapping filmic; soare cald plus lumină albastră de umplere; umbre moi; ceață ușoară.
- Vegetație cu `MultiMeshInstance3D`: tufe de trandafiri, lavandă, hortensii, cipreși, iederă.
- Clădiri: modele GLB în `res://assets/models/{palat,observator,turn,magazin,sera,mascota,piedestal}.glb`, cu înlocuire automată a variantei procedurale dacă fișierul lipsește. Înălțimi țintă: palat 5.5, observator 4.5, turn 5.3, magazin 3, seră 3, mascotă 1.6. Maxim 30.000 de poligoane per model.
- Mascotă: ochi mari lucioși, cască de aviator din piele, ochelari cu lentile albastre, rucsac cu sul de hârtie, eșarfă violetă. Animații de stat, mers, salut, bucurie.
- Interfață ca în randare: logo, avatar, monede, scut de nivel, bară de progres, titlu, buton auriu „Buble Blast", bară de navigare jos. Totul în română.

## Bucla de lucru
1. Verifică ce renderer folosește proiectul (Mobile sau Forward+) și adaptează efectele.
2. Dacă Godot poate rula cu ecran, fă capturi și compară-le cu `reference/render.png` și cu `lumi.html`, apoi repară cele mai mari 3 diferențe pe rând. Dacă nu poate, lucrează din cod, fă commit după fiecare pas și spune-mi ce să testez pe telefon.
3. Țintă: 60 FPS pe un telefon Android de gamă medie. Niveluri de calitate (Mic, Mediu, Mare), cu Mediu implicit. Măsoară și raportează.

## Reguli
- Fără imagini statice în locul lumii 3D și fără randarea ca fundal sau textură.
- Doar asset-uri gratuite, cu licența notată. Fără plăți reale. Fără jucători simulați.
- Blender (opțional): dacă e instalat prin setup script, scripturi `blender -b -P` pot genera GLB-uri mai bune decât geometria din Godot. Dacă lipsește, spune-mi și continuă fără el.

## Decizii noi (v3)
- Public: adulți 25–55 de ani, ton elegant și matur.
- Sursa de monede: mașina de bule în stil Coin Master (nu mai e Buble Blast).
- Progres: 30 de niveluri = 3 globuri × 10 niveluri.
- Dirijabilul devine baza mascotei: abilități, aspect, însoțitor, trofee.
- Mascota: varianta „cască de bulă" din `reference/mascota.html`.
- Mașina de rotit = joc de noroc simulat: rating de vârstă mai mare și reguli Google Play de verificat înainte de lansare.

## Prompt complet pentru Code

```
# BUBLE – VERSIUNE DE TEST PENTRU ADULȚI (Godot 4, Android, portret, interfață în română)

## CONTEXT
Lucrezi în proiectul Godot existent. Citește întâi BUBLE_HANDOFF.md și fișierele din reference/ (render.png, lumi.html, mascota.html). Lucrează pe un branch nou, buble-v2, cu commit după fiecare etapă. Nu șterge cod vechi: mută ce nu mai folosești în legacy/.

## OBIECTIV
O versiune jucabilă și completă pentru un test real cu jucători adulți: bucla în stil Coin Master, 30 de niveluri de progres, orașul din glob de sticlă ca ecran principal și dirijabilul mascotei, cu abilități și aspect. Fără plăți reale și fără backend. Toată economia se reglează din fișiere de date, fără modificări de cod.

## PUBLIC
Adulți 25–55 de ani, jucători casual, sesiuni de 2–5 minute. Ton elegant și matur, fără elemente infantile. Texte scurte și directe.

## 1. BUCLA PRINCIPALĂ: MAȘINA DE BULE (înlocuiește Buble Blast)
- Trei role cu simboluri în formă de bule premium (monedă, sac de monede, energie, scut, pop/atac, raid, cufăr). O rotire costă 1 energie.
- Rezultatele vin dintr-un tabel de probabilități în data/spin_table.json: trei niveluri de monede, energie, scut (maxim 3), atac, raid, cufăr, carte de album.
- Multiplicator x1/x2/x3/x5, deblocat de la nivelul 5; consumă energie proporțional și înmulțește câștigul.
- Energie: plafon și ritm de refacere configurabile (pornește de la 50 și +1 la 10 minute). Peste plafon nu se mai acumulează.
- Atac: alegi o clădire a țintei și o avariezi; dacă ținta are scut, se consumă scutul.
- Raid: alegi 3 din 4 locuri și descoperi monedele ascunse.
- Ținte: fără backend, folosește doar ținte de antrenament etichetate vizibil „Țintă de antrenament – nu este un jucător real". Nu simula jucători reali. Fă o interfață TargetsRepository, ca să poată fi înlocuită ulterior cu un backend.
- Ecran „Șanse": arată probabilitățile din tabel.
- Senzație premium: rolele accelerează și frânează realist, cu sunet, vibrație și particule la câștiguri mari.

## 2. PROGRES: 30 DE NIVELURI
- 3 globuri tematice × 10 niveluri: „Grădina dintre nori", „Orașul de cristal", „Portul de amurg".
- Un glob are 5 clădiri; fiecare nivel cere 2–3 upgrade-uri. Costurile cresc și sunt definite în data/levels.json.
- Recompensă la fiecare nivel. La nivelul 10, 20 și 30 (glob terminat): cufăr mare, animație de finalizare și călătorie cu dirijabilul spre globul următor.
- Ritm țintă, de calibrat: nivelurile 1–5 în primele 15 minute, nivelul 30 după aproximativ două săptămâni de joc zilnic. Scrie în BALANCE.md cum ai calculat costurile.

## 3. ECRANUL PRINCIPAL: ORAȘUL DIN GLOB
- Respectă BUBLE_HANDOFF.md și reference/lumi.html: glob de sticlă cu margine irizată (shader Fresnel), piedestal, orașul cu 5 clădiri, fântână, vegetație, felinare.
- Upgrade: animație de construcție, clădirea crește vizibil și primește detalii noi.
- Bulele prietenilor sunt sloturi goale „Invită un prieten", marcate DEMO.
- Cameră oblică, rotire limitată, zoom cu două degete.

## 4. DIRIJABILUL MASCOTEI (ecran separat)
Pornește de la varianta dirijabil din reference/lumi.html: navă în secțiune, cu camere luminate.
- Observator → arbore de abilități desenat ca o hartă de constelații. Jucătorul primește 1 punct la fiecare nivel. 15 abilități în 3 ramuri, efecte din data/skills.json:
  - Noroc: mai multe monede din rotiri, cufere mai bogate, raiduri mai bune.
  - Constructor: upgrade-uri mai ieftine și mai rapide, producție mai mare.
  - Apărare: scut în plus, pierderi mai mici la atac, energie refăcută mai repede.
- Garderobă → aspectul mascotei: 10 piese (modele de cască-bulă, ochelari, eșarfă, culoarea corpului, efect la rotire), câștigate prin joc.
- Atelier → îmbunătățiri ale dirijabilului (motoare, baloane), care deblochează globurile.
- Seră → însoțitor care crește cu nivelul și dă un bonus pasiv mic.
- Salon → trofee, statistici și albumul de cărți.
- Mascota stă pe punte, cu animații de stat, salut și bucurie, și reacționează la câștigurile mari.

## 5. MASCOTA ȘI STILUL VIZUAL PENTRU ADULȚI
- Varianta mascotei: „cască de bulă" din reference/mascota.html. Corp crem rotunjit, eșarfă violetă cu frunză aurie, rucsac mic, cască transparentă de sticlă (dom cu margine irizată Fresnel, guler auriu, mică antenă aurie), fără ochelari de aviator. Proporții mai sobre, expresii mai fine, umor matur.
- Aspect mai realist: materiale PBR (piatră, lemn, metal auriu lustruit, sticlă), lumină cinematografică, umbre moi, glow controlat, culori bogate, dar rafinate.
- Pregătește sloturi GLB în res://assets/models/ cu variantă procedurală de rezervă. Scrie MODELS_TODO.md cu specificații și prompturi pentru generarea modelelor.
- Interfață premium: auriu, sticlă, fonturi clare; fără emoji ca pictograme.

## 6. MOTIVE DE REVENIRE
- Upgrade-uri cu timer.
- Rezervor de monede cu plafon.
- Energie cu plafon.
- Cufere cu timer, în 3 sloturi.
- Serie zilnică pe 7 zile, care se oprește, nu se resetează.
- Un eveniment de test cu durată fixă și premii pe etape.
- Notificări locale doar la cerere, maximum 2 pe zi, doar pentru lucruri reale.
Fără mesaje care culpabilizează și fără timere false de presiune.

## 7. ALBUM DE CĂRȚI
3 seturi a câte 9 cărți, legate de globuri. Recompensă la completarea unui set. Duplicatele sunt păstrate pentru schimburi viitoare (marcat DEMO).

## 8. ANALIZĂ
Interfață Analytics cu implementare înlocuibilă. Evenimente: first_open, session_start, session_length, spin (rezultat, multiplicator), level_up, upgrade, attack, raid, chest_open, skill_unlock, cosmetic_equip, energy_empty. Recomandă Firebase sau GameAnalytics și integrează-l dacă există un plugin Godot funcțional.

## 9. MONETIZARE (pregătită, dezactivată)
Structura magazinului, fără plăți reale. Prețuri afișate clar, o singură monedă premium, fără pachete care ascund prețul real, probabilități vizibile. Verifică și raportează ce plugin-uri Godot există pentru Google Play Billing și reclame cu recompensă.

## 10. CALITATE ȘI LIVRARE
- 60 FPS pe un telefon Android de gamă medie, cu niveluri de calitate Mic/Mediu/Mare (Mediu implicit).
- Construiește un APK de test și scrie TESTING.md cu pașii de instalare pe telefon.
- La final, raportează: ce funcționează, ce e DEMO, ce depinde de modele GLB, ce trebuie verificat juridic (jocuri de noroc simulate, rating de vârstă, cutii cu premii) și ce urmează pentru testul cu jucători.
```
