# LERION — decizii actuale și identitate

## Jocul
- Nume: **Lerion**; subtitlu de lucru: **Regatul Trăsniților**.
- Public: joc casual Android în format portret, familie/public larg, prietenos, fără forțarea microtranzacțiilor.
- Ton: personaje drăgălașe + **umor haotic** cu episoade scurte, evitând glumele repetitive la fiecare activare.
- Buget total discutat: **500–1.000 €** incluzând dezvoltare/promo; lucrul efectiv este în Godot 4, ajutat de Codex și eventual Blender/3D Valley.

## Hartă / stare deja acceptată
- **Nu este insulă plutitoare.** Utilizatorul a respins marginile vizibile. Regatul este pe un teren continuu cu dealuri/păduri în depărtare, aproximativ ca `REFERINTE/01_MAPA_APROBATA_CONTINENTAL.png`.
- `REFERINTE/02_JOC_ACTUAL.jpg` (screenshot real) este dovada unui prototip nou cu teren continental și castel realizat. **Acesta trebuie conservat**.
- Castelul este vizibil chiar de la prima intrare. Fântâna cu cristal albastru este deja în centru.
- Există exact 6 parcele dispuse stânga/dreapta pe trei rânduri; drumuri bej, copaci low-poly, flori, pietre; zoom și deplasare limitată.
- Modelele 3D trebuie să fie independente ca să permitem upgrade fără refacerea terenului.
- Fără camere ce dezvăluie marginile; fără imitație de elemente specifice unui joc comercial.

## Personaje oficiale
- **Lerik**: râs portocaliu biped, ochelari de aviator, rucsac; lider/aventurier, optimist și stângaci.
- **Pongo**: constructor goblin verde, cască galbenă și unelte; comic, neîndemânatic. *Numele anterior „Bubu” este abandonat.*
- **Pufi**: dragon mic, mov-roz, rotunjor; foc și efecte magice amuzante.
- Personajele sunt parte a brandului Lerion, dar modelele finale animate nu trebuie inventate ca fiind deja gata.

## Gameplay aprobat pentru PROTOTIPUL URMĂTOR
- **Cristalul Haotic**: buton ACTIVEAZĂ -> 3 simboluri proiectate de cristal -> recompense -> construcții.
- Rulări rapide, circa 1–1,5 secunde pentru animația obișnuită, cu auto-activare ulterioară și feedback clar.
- Castelul rămâne punctul de reper al regatului; toate cele 6 clădiri sunt construibile în 3 etape vizuale.
- După finalizarea tuturor clădirilor, trecere către alt regat este un PLAN ULTERIOR; nu o implementa în MVP.

## Priorități
1. Stabilitate și import Godot; fără erori de parser.
2. Gameplay minim funcțional, clar, energic și distractiv, fără a crea grafica imposibilă din randări.
3. Calitate coerentă a clădirilor și efectelor, folosind geometrie simplă și materiale reușite.
4. Testare pe Android înainte de monetizare.

## Ce nu mai este planul activ
- Traseul serpuit în buclă cu Lerik, 18–30 de căsuțe tip Monopoly; este **varianta B de testat doar după cristal**, nu cod activ.
- Zarurile ca mecanism principal, catapulta, roata norocului și ouăle nu sunt planul următoarei iterații.
- Insula GLB `101433.glb`, apa/cascadele și vechile arhive Godot nu reprezintă harta actuală.
- Numele Bubu este greșit; orice referință la el în cod/text nou trebuie actualizată la **Pongo**.
