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

## Prompt scurt pentru Code
> Citește `BUBLE_HANDOFF.md` și fișierele din `reference/`. Schimbă lumea jocului din insulă plutitoare în orașul din glob de sticlă, păstrând economia, upgrade-urile, Buble Blast și salvarea. Implementează întâi globul, orașul, bulele de prieteni (sloturi DEMO) și interfața de pe ecranul principal. Rulează proiectul, repară erorile și spune-mi la sfârșit ce seamănă cu referința și ce depinde de modelele GLB.
