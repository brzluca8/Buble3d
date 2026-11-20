# Insula 1, v3: Faza A (fără credite)

Ramura `orion-insula-v3`. Pornește de la auditul din `docs/insula_v3_audit.md`.

**Godot n-a putut fi rulat aici.** Sistemul de permisiuni a blocat pornirea lui, chiar și a binarului oficial 4.7.1 cu suma de control verificată. De aceea:
- toate capturile de mai jos sunt **randări Blender** cu aceleași modele și cadre ca jocul, nu capturi din Godot;
- shaderele n-au fost compilate;
- cifrele de performanță sunt calculate din fișiere.

Pentru verificare reală pe telefon există scena de test `godot/test/test_insula.tscn` (vezi la sfârșit). Ea afișează FPS-ul, triunghiurile, apelurile de desenare și materialele, citite din Godot.

Lanțul de lucru e același pentru toate fazele:
1. `blender/island_prep.py`: scară, căsuțe;
2. `blender/insula1/upscale.py`: textura mărită cu AI;
3. `blender/insula1/imbunatateste.py`: apa și cascadele separate;
4. `blender/insula1/v3_faza_a.py`: Faza A;
5. rezultatul: `godot/assets/models/insula1/insula1.glb`.

## Ce s-a făcut, punct cu punct

**A1. Petele negre.**
- **Cauza:** 4.802 fețe (16,9 m²) aveau normala din fișier opusă sensului în care erau desenate. Godot desenează insula pe ambele fețe. Pentru o față văzută „din spate” după sensul de desenare, întoarce normala, iar normala acestor fețe ajungea cu spatele la lumină, deci fața ieșea întunecată.
- **Unde erau:** fețe mici (0,0035 m² în medie), 89% sus, pe frunze, flori și muchii. Harta lor, colorate cu roșu, se potrivește cu petele din captura ta: `docs/shots/insula_v3_audit_fete_inversate.png`.
- **Verificate și excluse:**
  - spațiile dintre insulele UV: nu sunt întunecate (luminozitate medie 0,47), deci nu se scurge culoare din margini;
  - triunghiurile degenerate: doar 4, scoase și ele.
- **Reparația:** sensul de desenare e întors, iar normalele rămân. După reparație, sunt 0 fețe inversate.
- **Nu e confirmat în Godot.** Scena de test are comutator de umbre: dacă mai apar pete, umbrele pe propria suprafață (shadow acne) sunt următorul suspect.

**A2. Claritate.**
- filtrare anizotropă 16× pentru tot proiectul;
- mipmap-uri;
- ascuțire ușoară a texturii (unsharp mask: rază 1,2 px, 45%);
- un strat de detaliu fin, tileable, aplicat triplanar în coordonatele lumii (`insula1/textures/detaliu.png`):
  - pe canalul R, crăpături pentru stânci;
  - pe canalul G, fire pentru iarbă și frunziș;
  - pe canalul B, granulație fină pentru restul.

  Intensitatea se reglează din `putere_detaliu`, implicit 0,22, iar mărimea din `metri_detaliu`, implicit 1,6 m. Stratul e activ la Mediu și Mare.

Stratul de detaliu **nu adaugă detalii reale**. Doar scoate aspectul neted, de plastilină, de aproape. Textura de bază rămâne cea de 4096 px: 56 px/m, față de 463 la Orion.

**A3. Segmentarea.**
- Fiecare față e clasificată după:
  - culoarea texturii la centrul ei (HSV);
  - poziție;
  - normală;
  - înălțimea față de sol: un relief văzut de sus, din care o „deschidere” morfologică scoate copacii.
- Imaginea de verificare, cu o culoare pe clasă, a fost făcută **înainte de tăiere**: `docs/shots/insula_v3_A_clase.png`.

| Clasă | Fețe |
|---|---:|
| restul (castel, case, poteci) | 72.303 |
| stânci | 48.787 |
| frunziș | 46.745 |
| iarbă | 11.239 |
| flori | 6.399 |
| felinare și ornamente aurii | 2.412 |
| căsuțele vechi | 1.920 (scoase) |
| portal | 1.670 |
| barca | 1.562 |
| cristale | 423 |
| palele morii | 363 |
| pânze (steagurile castelului și o parte din copertina pieței) | 161 |
| apa | 1.368 |
| cascadele | 1.075 |

- **Nuferii** au doar 16 fețe în model, așa că nu i-am separat.
- **Copertina pieței:** regula mea a prins-o doar parțial (75 din cele 227 de vârfuri ale clasei „pânze”), pentru că dungile ei se confundă cu restul.
- Geometria nu se schimbă: e doar mutată în obiecte separate, câte unul pe clasă.

**A4. Apa.**
- **Textura veche de apă dispare.** O a doua trecere prinde și apa pictată mai închis, de sub poduri și de la margini, numai dacă e lipită de apa găsită și la același nivel.
- **Râul:**
  - două straturi de valuri cu viteze diferite pe direcția curgerii, plus dungi de curent care curg, ca să se vadă direcția;
  - culoare turcoaz la maluri, albastru adânc la mijloc;
  - spumă la maluri și în jurul celor 4 poduri.
- **Sclipirile:** acum sunt moi, nu puncte de un pixel care pâlpâie. Valurile sunt mai mari și mai liniștite; asta trata apa care arăta „pixelată”.
- **Laguna:**
  - unde mici;
  - inele de spumă în jurul a ce iese din apă: stâlpii debarcaderului, pietrele, barca;
  - **barca se leagănă**: e separată, cu pivotul la nivelul apei.

**A5. Cascadele.**
- dungi care curg repede;
- buză luminoasă;
- ceață la bază;
- cele două care cad în gol se destramă spre bază și se topesc în norii de dedesubt, sub un nor de ceață mai mare.

**A6. Lumini.**
- **Portalul:** vârtej cyan care se rotește și pulsează.
- **Cristalele:** strălucire proprie cyan care pulsează discret.
- **Felinarele:** 41 de flăcări cu halou cald care pâlpâie. E lumină falsă, într-un singur apel de desenare, deci ieftină pe telefon.

**A7. Vântul.**
- Două uniforme globale: `vant_directie` și `vant_putere`, cu rafale.
- Frunzișul, florile și steagurile se leagănă după greutatea de pe fiecare vârf: 0 la sol, 1 sus, calculată din înălțimea față de sol. Se leagănă 32.919 vârfuri.
- **Moara se rotește.**
  - Palele sunt găsite din cele două panouri crem; butucul e acolo unde se întâlnesc axele lor lungi.
  - Tripo făcuse doar 2 pale, în „V”, așa că le-am completat la 4, cu copii rotite cu 180°.
- Particule și animale: 36 de petale, 6 fluturi, 3 păsări.

**A8. Căsuțele.**
- Discurile coapte în model sunt scoase.
- Le înlocuiesc 22 de `insula1/casuta/Casuta.tscn`, în aceeași ordine și pe aceleași poziții:
  - piatră bej cu gravură în romb (hartă de normale);
  - chenar auriu teșit;
  - puțin mai mari decât discurile vechi, ca să le acopere marginea.
- **Căsuțele speciale** au iconiță și inel luminos în culoarea tipului: Start, Cufăr (4 și 18), Zar bonus (8), Eveniment (11), Carte (15).
  - Jocul n-avea tipuri de căsuțe, deci acestea sunt **doar o propunere vizuală**, în `insula1/data/tipuri_casute.gd`. Logica nu le citește.
- **La aterizare:** undă, căsuța se aprinde scurt și se turtește puțin (squash and stretch). Turtirea lui Orion exista deja în joc.

**A9. Lumină și culori.**
- **Lumina** e aceeași ca pe Orion:
  - cheie caldă sus-stânga;
  - ambient din cer;
  - contur cyan discret din spate.
- **Umbrele:** o singură lumină cu umbre reale, în 2 trepte, până la 30 m la Mediu și 45 m la Mare.
  - Soarele vine acum mai din stânga, ca umbrele să cadă spre dreapta și să se vadă din camera de joc. Înainte, lumina venea din față și umbrele cădeau în spatele obiectelor.
- **Nuanțarea**, măsurată pe captura ta din Godot:
  - insula avea luminozitatea medie 0,64 și saturația 0,23;
  - blana lui Orion are 0,57 și 0,55.

  În shaderul insulei: gama 1,08, saturație ×1,18, contrast ×1,10. Global, scena are doar +4% și +3%, ca Orion să nu se suprasatureze. Tonul e ACES, cu glow moderat.
- **AO:** am ales **AO coaptă în culorile de vârf**, pentru că pe Mobile nu există SSAO. Raza de 1,6 m dă umbre de contact sub clădiri și la marginea platoului. Factorul e 0,55.

**A10. Cer și fundal.**
- **Cerul** e un shader:
  - degradeu de albastru;
  - nori moi la orizont;
  - marea de nori dedesubt;
  - strălucirea soarelui.

  Nu folosește TIME, deci nu se recalculează în fiecare cadru.
- **Nori și ceață:** 30 de nori care se mișcă (14 la Mic), raze de soare false, ceață de distanță.
- **Insulițele:** prisma verde netexturată e înlocuită de 3 modele de insulițe cu stâncă, iarbă, copaci și o cascadă. Sunt refolosite de 5 ori și se leagănă încet.

**A11. Camera.** Nu am schimbat controlul camerei.
- Tot ce ajunge într-un con în jurul liniei cameră–Orion se destramă în puncte (dither). La fel, tot ce e la mai puțin de 2,4 m de cameră. Așa nimic nu-l mai acoperă pe Orion, nici catargul.
- Poziția lui Orion e doar citită din scena jocului.
- **Textul-hint de jos** face parte din interfață, pe care n-am atins-o. Interfața se desenează mereu peste decor. Dacă vrei o bandă discretă în spatele lui, ca să se citească mai ușor, e o schimbare de interfață și o fac doar cu OK-ul tău.

## Performanță (calculată din fișiere; cifrele reale le arată scena de test)

| | Triunghiuri | Apeluri de desenare (trecerea principală) |
|---|---:|---:|
| insula (11 obiecte pe clase) | 105.203 | 11 |
| apa + cascadele | 2.443 | 2 |
| 22 de căsuțe + 6 iconițe + 6 inele | 16.668 | 34 |
| insulițe (5) | 2.220 | 10 |
| portal, halouri, nori, raze, particule, fluturi, păsări | ~450 | ~55 |
| **Fără Orion** | **~127.000** | **~112** |
| Orion (înainte de LOD-ul automat din Godot) | 188.474 | 2 |

- **Umbre:** cele 13 obiecte care aruncă umbră (insula și Orion) se mai desenează o dată pe fiecare treaptă de umbră. Asta dă ~138 de apeluri la Mediu. Căsuțele, apa, norii și particulele nu aruncă umbră.
- **Materiale unice:** 14, sub limita de 15:
  - insula (unul pentru toate clasele), apa;
  - portal, halou, cer;
  - căsuță, semn, undă;
  - particule, culori pe vârfuri, nori, raze;
  - Orion (2).
- **Particule:** 82, sub limita de 300.
- **Triunghiuri:** insula a scăzut de la 196.447 la 107.646. Fără Orion, totalul vizibil e ~127 de mii.
  - Cu Orion întreg ar fi ~315 de mii, peste ținta de 250 de mii. Godot face însă singur LOD pentru Orion la import și îl folosește când Orion e mic pe ecran.
  - Cât rămâne de fapt arată scena de test pe telefon, în contorul „triunghiuri”.
- **Calitate Mic / Mediu / Mare:**

  | | Mic | Mediu | Mare |
  |---|---|---|---|
  | umbre | nu | 30 m | 45 m |
  | vânt în shader, strat de detaliu, apă cu straturi | nu | da | da |
  | ceață, petale, fluturi, păsări | nu | da | da |
  | glow | nu | da | da |
  | nori | 14 | 30 | 30 |

## Capturi (randări Blender, NU Godot)
- `docs/shots/insula_v3_A_aproape.png`: camera de joc implicită.
- `insula_v3_A_captura1.png`, `insula_v3_A_captura2.png`: aceleași unghiuri ca în capturile tale, estimate după mărimea lui Orion și ce se vede în ele.
- `insula_v3_A_mediu.png`, `insula_v3_A_panorama.png`.
- `insula_v3_A_inainte_dupa_1.png`, `insula_v3_A_inainte_dupa_2.png`: captura ta din Godot alături de randarea v3, din același unghi. Atenție: motoare de randare diferite.
- `insula_v3_A_orion_si_insula.png`: Orion și insula de lângă el, la aceeași scară, din același cadru.
- `insula_v3_A_clase.png`: clasificarea.
- `insula_v3_audit_checker.png`: densitatea texturii.

În Blender, apa, vântul, pâlpâitul și estomparea sunt statice sau lipsesc.

## Listă cinstită

**Reparat sau adăugat** (în cod și în model; ce se vede e verificat doar în Blender):
- petele negre, cu o cauză găsită și reparată;
- apa care curge, cu direcția vizibilă, fără textura veche;
- cascadele care curg și se topesc în nori;
- moara care se rotește, cu 4 pale;
- barca care se leagănă;
- portalul, cristalele, felinarele;
- vântul;
- căsuțele noi, cu iconițe și efect la aterizare;
- umbre vizibile și culori mai apropiate de Orion;
- cerul și insulițele;
- estomparea în fața lui Orion;
- triunghiurile insulei aproape înjumătățite.

**A rămas slab** (e geometria din Tripo; asta e Faza B):
- **Copacii și florile:** forme moi, „topite”; florile sunt bulgări roz.
- **Stâncile:** plăci cu textura întinsă. Stratul de detaliu ajută doar de aproape.
- **Podurile și castelul:** detaliu mic, muchii moi.
- **Moara:** palele sunt panouri plate, iar butucul e dezordonat de aproape, pentru că ramele sunt dublate.
- **Barca:** catargul și frânghiile sunt groase și moi.
- **Textura:** tot 56 px/m, față de 463 la Orion. De aproape, insula e mai moale decât el.

**Diferă de ce ai cerut:**
- nuferii (prea puțini în model);
- copertina pieței (separată doar parțial);
- hint-ul de jos (e interfață, n-am atins-o);
- verificarea în Godot (n-a fost posibilă aici).

## Scena de test (pe telefon)
1. În editorul Godot, deschide `test/test_insula.tscn` și apasă **Run Current Scene** (F6).
2. Butoanele:
   - **Cadru:** jocul, captura 1, captura 2, mediu, panoramă.
   - **Mod:** normal, tablă de șah, clase, AO, normale.
   - **Calitate:** Mic, Mediu, Mare.
   - **Umbre**, **Estompare**, **Mișcare redusă:** comutatoare.
   - **Aterizare pe START:** pornește efectul.
3. Sus apar cifrele din Godot: FPS, triunghiuri, apeluri de desenare, obiecte, materiale unice în insulă.
4. Trimite-mi capturi din fiecare cadru, plus cifrele pe Mediu. Dacă apare vreo eroare de shader, o vezi în panoul **Output**.

## Faza B (doar după OK-ul tău; costă credite)
**N-am început-o.** Am cheltuit 0 credite.

Ordinea propusă e cea din cererea ta:
1. vegetația;
2. stâncile și pereții;
3. moara;
4. podurile;
5. castelul;
6. piața, atelierul și debarcaderul;
7. barca.

Generatorul 3D (MCP-ul 3daistudio) **nu e conectat** în această sesiune. Fără el, pregătesc decupajele, iar tu generezi manual.
