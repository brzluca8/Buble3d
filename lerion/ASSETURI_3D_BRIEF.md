# Brief vizual pentru Blender / 3D Valley / Godot

## Aspectul urmărit
- Cartoon 3D casual original: forme late, rotunjite, culori saturate, proporții jucăușe, texturi simple, umbre moi.
- **Referința de stil vizual:** `REFERINTE/01_MAPA_APROBATA_CONTINENTAL.png`; **modelul funcțional actual:** `02_JOC_ACTUAL.jpg`.
- `REFERINTE/04_CONCEPT_CRISTAL.png` este **inspirație pentru UI/efecte**, NU garanția că vom putea reconstrui întreaga imagine ca 3D.
- `REFERINTE/05_TRIO_PERSONAJE.png` este inspirație pentru Lerik/Pongo/Pufi, NU model animat.

## Asset-uri independente
- Castelul deja prezent rămâne; nu-l înlocui automat.
- Pentru cele 6 clădiri export `.glb` cu pivot la baza clădirii (sol), orientat către drumul adiacent, scale adaptabilă la platforma reală.
- Fără teren, cer, păduri sau fundal lipit de fiecare clădire. Fiecare model ușor de înlocuit la runtime.
- Păstrează stil coerent între modele, nume și materiale lizibile. Dacă se folosește 3D Valley, elimină geometriile parazite și validează materialele în Godot.
- Praguri de triunghiuri: stabilește-le DUPĂ măsurători reale pe telefon; ca țintă inițială practică urmărește câteva mii de triunghiuri per clădire și reutilizează materiale/mesh-uri. Nu sunt praguri rigide sau garanții de FPS.
- Evită transparențele complexe și multe shadow-casting lights; profilează GPU și CPU Android.
- Pentru niveluri, preferă variații modulare și `MultiMesh` doar unde aduce câștig.

## Cristalul
- Cristal 3D low-poly deja în hartă; nu crea altă insulă/obiect monolitic.
- Pulse luminoase cu AnimationPlayer/Tween + shader modest, 3 simboluri proiectate în HUD/3D billboard cu poziționare clară.
- Efectul normal foarte scurt, skip/auto posibil; reacțiile personajelor rare.

## Copyright / design
- Nu reproduce modele, palete de UI copiate pixel cu pixel, logo-uri, iconițe sau personaje din Dice Dreams, Monopoly GO ori Coin Master.
- Asemănarea de gen (cartoon, regat, recompense) este doar punct de pornire; păstrează identitatea Lerion.
