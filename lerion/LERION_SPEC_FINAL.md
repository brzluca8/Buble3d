# LERION — SPECIFICAȚIE FINALĂ APROBATĂ

**Status:** decizii confirmate prin conversație, 23 noiembrie 2026.

## 1. Identitatea jocului
- Nume: **Lerion** (titlu de lucru: „Lerion – Regatul Trăsniților”).
- Platformă: Android, Godot 4 cu GDScript, buget total pentru dezvoltare și promovare **500–1.000 €**.
- Atmosferă: fantasy vesel, personaje drăgălașe și umor haotic, prietenos pentru public larg.
- Personaje propuse: **Lerik** (râs aventurier cu ochelari și rucsac), **Bubu** (constructor comic verde), **Pufi** (dragon mic și caraghios). Nu trebuie modelate/animațe acum, doar păstrat planul.
- Inspirație generală: accesibilitatea jocurilor casual 3D de succes, culori puternice, forme simple; **fără imitație** de Dice Dreams.

## 2. DECIZIE VIZUALĂ FINALĂ — foarte important
Referința definitivă este `assets/reference/REGATUL_LERION_APROBAT.png`.
- Harta trebuie să fie **teren continental continuu**, nu insulă. **FĂRĂ** apă în jur, cascade la margini, stânci suspendate, margini vizibile sau perimetru de insulă.
- Fundal cu dealuri verzi și pădure, cer albastru, copaci cartoon cu geometrii simple, iarbă, flori, pietre și garduri discrete.
- Castelul albastru cu turnuri mici din partea superioară/centrală este un reper decorativ permanent, **nu unul dintre cele șase sloturi** (poate fi înlocuit ulterior cu GLB separat).
- În centrul zonei jucabile se află o **fântână/monument cu cristal albastru luminos** (decor, nu slot).
- În jur sunt **exact șase terenuri/sloturi de construcție**, 3 pe stânga și 3 pe dreapta. Fiecare are contur de piatră, pământ și un simbol simplu "+". Legături prin drumuri bej curbe.
- Harta să fie spațioasă, clară, nu aglomerată; arată stilizat și profesionist fără realism fizic și fără exagerare cu detaliile.
- Camera: oblică/isometrică, zoom prin pinch pe mobil și deplasare controlată; să nu dezvăluie marginile scenei. UI se suprapune separat pe ecran.
- Nu necesită o lume infinită reală; se poate limita mecanic zona jucabilă și prelungi decorul în exterior.

## 3. Construcțiile și arhitectura
- Șase locuri de construcție sunt suficiente pentru un regat. Clădirile vor fi modele 3D GLB **independente**, nu lipite de o singură hartă.
- Un obiect GLB separat pentru fiecare clădire, la cerere, ușor de înlocuit; de exemplu: atelier, mină, moară, laborator, magazin, altă clădire, cu mici variații vizuale de nivel.
- Se va putea selecta un slot și ulterior construi și îmbunătăți clădirea.
- Evită să modelezi toate clădirile acum: primele teste trebuie făcute cu 6 sloturi goale.

## 4. Gameplay — direcție ulterioară, NU implementa în faza 1
- Aruncări de zaruri cu simboluri, recompense, construcții, progres; jucătorul să poată lua decizii, nu doar să primească premii automate.
- Întâmplări comice scurte prin Bubu/Pufi/Lerik, animații reutilizabile.
- Eventual prieteni, sprijin între jucători și competiții **asincrone**, abia după ce mecanica principală este plăcută.
- Monetizare ulterioară: reclame opționale recompensate și personalizări; fără mecanici pay-to-win. Nu integra SDK-uri acum.

## 5. Ce este depășit și nu trebuie reactivat
- Toate proiectele vechi cu insule plutitoare, apă în jur și margini abrupte.
- Imagine statică animată ca soluție finală; faza actuală urmărește un teren 3D simplu dar real.
- Scenele Godot anterioare sunt doar prototipuri. Scripturile vechi cu erori nu au prioritate față de noua specificație.
- Încercarea de a crea întreaga lume ca **un singur GLB** în 3D Valley; 3D Valley este util în schimb pentru clădiri individuale.
- Realism/cinematic 3D și randări spectaculoase imposibil de reprodus cu bugetul disponibil.

## 6. Criterii de acceptare, FAZA 1 (rezultatul următor)
- Proiect Godot 4 importabil și care pornește fără erori de parser/import pe sistemul unde este testat.
- Scenă jucabilă 3D continentală, fără contur de insulă, inspirată de referința vizuală furnizată.
- Castelul și fântâna centrală recognoscibile (pot fi versiuni geometrice stilizate temporare).
- 6/6 platforme goale, cu +, clic/touch selectabil și feedback vizual.
- Cameră oblică cu zoom și pan limitat, configurată pentru ecran portret Android, fără să se vadă marginile terenului.
- Iluminare blândă, materiale colorate, umbre prudente și scene mobile-friendly.
- Un README în română cu instrucțiuni pentru import și verificare Android, plus limitările testării.
- Nu include ca livrabil obligatoriu zaruri, economie, cumpărături, multiplayer și personaje 3D în acest pas.
