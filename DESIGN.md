# Joc nou (nume de stabilit) – document de design

Deciziile se adaugă aici pas cu pas, după discuție. Codul se scrie doar după ce documentul e aprobat.

## Pasul 1 – Conceptul

| Subiect | Decizie | Stare |
|---|---|---|
| Nume | ~~Buble~~ renunțăm; joc nou de la capăt, nume de stabilit | ⏳ |
| Publicare | Google Play (public) | ✅ |
| Personaj principal | **Orion – Exploratorul Lumilor** (râs cu ochelari de aviator, ochi albaștri, coadă cu spirale luminoase, busolă, felinar cu cristal, eșarfă roșie) | ✅ |
| Personalitate | vesel, curios, loial, plin de energie | ✅ |
| Dragonul | nu, deocamdată | ✅ |
| Costume (Pirat, Viking, Constructor, Mag, Spațial) | se câștigă în joc, nu se cumpără | ✅ |
| Culori alternative (Ametist, Aqua, Rubin) | de discutat | ⏳ |
| Puterea „Aura Aventurii” | o bară care se umple la fiecare aruncare; plină → Orion „se aprinde”: următoarele aruncări dau recompense duble + un bonus (aruncări gratuite sau cufăr). Cifrele la Pasul 4 | ✅ |
| Simbolul monedei | busolă aurie | ✅ |
| Titlu | odată cu numele noului joc | ⏳ |
| Durata unei sesiuni | scurte și dese: aruncări de zar limitate care se reîncarcă în timp (tip Monopoly GO) | ✅ |

### De reținut pentru Google Play
- Mecanicile pot semăna cu alte jocuri, dar numele, simbolurile, personajele și aspectul trebuie să fie originale.
- Imaginile generate cu AI: de verificat dreptul de folosire comercială.
- Recompense aleatorii plătite cu bani reali → șansele trebuie afișate.
- Politică de confidențialitate și clasificare pe vârste obligatorii.

## Din imaginea de concept (notat, de confirmat când vin detaliile)
- **Bucla:** aruncă zarurile → mergi pe tablă → primești recompense → construiești și faci upgrade → progresezi în univers → repeți cu obiective noi.
- **Insulele cresc în 3 etape:**
  - Faza 1 – Avanpost: 24 de căsuțe, 3 clădiri, progres rapid.
  - Faza 2 – Așezare: 32–36 de căsuțe, 5–6 clădiri, cartier nou.
  - Faza 3 – Regat: 40–48 de căsuțe, hub regional, rute către alte insule.
- **Universul Aliseron:** arhipelag de insule conectate în jurul unui cristal central: Aurora (verde), Glacia (gheață), Volkaris (vulcan), Celestia (nori/roz), Eldora (junglă/temple), Noctra (întuneric/violet).
- **Progres pe termen lung:** insule și cartiere, univers persistent (rute noi), Orion se dezvoltă (nivel, costume, abilități, relicve), colecții (cărți, fragmente, comori), evenimente, parte socială (prieteni, vizite, raiduri, clasamente).
- De corectat în imagini: logo-ul „Buble” → numele nou; coroana de pe zar → busolă.

## Mascota – Orion (fișă de design, în lucru)

| Subiect | Propunere | Stare |
|---|---|---|
| Specie | râs tânăr | ✅ |
| Proporții | chibi: cap mare (~40% din înălțime), ~2,5 capete înălțime | ⏳ |
| Siluetă ușor de recunoscut | urechi mari cu smocuri negre + ochelari de aviator + coadă stufoasă cu spirale | ⏳ |
| Ochi | albaștri, mari, cu reflexe | ✅ |
| Accesorii | ochelari de aviator din alamă (pe frunte), eșarfă roșie, rucsac cu hartă rulată, felinar cu cristal, medalion-busolă la piept (= simbolul monedei), brățară cu cristal | ⏳ |
| Semne magice | spirale cyan pe coadă și romburi pe brațe; strălucesc mai tare când Aura e activă | ⏳ |
| Expresii | fericit, încântat (inimioare), surprins, hotărât, somnoros + propuse: trist, triumf | ⏳ |
| Animații în joc | idle, salut, aruncă zarul, sare pe tablă, aterizare, bucurie, dezamăgire, Aura activă, doarme (fără zaruri) | ⏳ |
| Costume (se câștigă) | Pirat, Viking, Constructor, Mag, Spațial | ✅ |
| Culori alternative | Ametist, Aqua, Rubin | ⏳ |

Paletă propusă:

| Element | Culoare |
|---|---|
| Blană | auriu-portocaliu `#E8A44A` |
| Bot, piept, burtă | crem `#FFF1DC` |
| Pete | maro `#8A5A2B` |
| Vârfuri de urechi | negru `#2A1D14` |
| Ochi | albastru `#3BA7FF` |
| Spirale magice | cyan `#4FE3FF` |
| Eșarfă | roșu `#D8322F` |
| Curele, rucsac | maro piele `#6B3E1E` |
| Metal | alamă `#C9923A` |

### Cum va exista Orion în joc
- ✅ **Model 3D** (un singur model → toate unghiurile, animațiile, costumele și culorile alternative).
- ⏳ Cine face modelul: AI (imagine → 3D), artist 3D, sau combinat.
- ⏳ Folosire în joc: 3D în timp real, sau imagini randate din model (decis la Pasul 8/9).
- Cerințe tehnice propuse pentru telefon:
  - 10–20 mii de triunghiuri;
  - 1–2 texturi de 1024–2048 px;
  - format `.glb`;
  - schelet care include coada, urechile și eșarfa;
  - costumele ca piese separate care se schimbă pe model.
