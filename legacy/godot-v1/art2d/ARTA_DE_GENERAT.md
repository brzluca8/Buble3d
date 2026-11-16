# Arta de generat pentru Buble (stil 2.5D pictat)

Jocul afișează acum randarea ta ca înlocuitor temporar și pune peste ea animații (apă, nori,
lumini, scântei, mascota care respiră). Ca **upgrade-urile să schimbe clădirile** și **mascota să
se miște liber**, am nevoie de imaginile de mai jos, separate pe straturi.

## Reguli pentru toate imaginile

1. **Același stil și același unghi** ca randarea ta: vedere 3/4 de sus (~40°), lumină caldă de
   după-amiază din stânga-sus, paleta turcoaz / violet / auriu / piatră crem.
   Dacă generatorul are „style reference” / „image prompt”, dă-i randarea ta ca referință la fiecare imagine.
2. **Piesele separate pe fundal magenta plat `#FF00FF`** (sau PNG transparent, dacă generatorul știe).
   Fără umbră pe fundal, fără podea, fără text, obiectul întreg în cadru, cu puțin spațiu în jur.
3. Rezoluție: fundalul minimum **2048 px** lățime; clădirile ~**1024 px**; mascota ~**1024 px**.
4. Mi le trimiți aici în chat (sau le pui în folderele de mai jos). Eu le decupez cu
   `tools/cutout.py`, le potrivesc pe insulă și le verific în joc.

## Bloc de stil (lipește-l la începutul fiecărui prompt)

```
Cozy fantasy mobile game art, stylized 3D render, soft global illumination, warm afternoon
light from the top-left, pastel sky, cream limestone, turquoise domes, violet banners with a
golden leaf emblem, polished gold trim, lush flowers, high detail, clean silhouette,
3/4 top-down view at about 40 degrees, no text, no watermark
```

## 1. Fundalul insulei, fără clădiri și fără mascotă → `art2d/scene.png`

```
[STIL] A floating sky island seen from above in 3/4 view, portrait composition. A cobblestone
plaza with a round tiered fountain in the center, a grand stone staircase descending to the
front edge with balustrades and golden lanterns, two waterfalls pouring off the front cliffs,
layered rocky underside with hanging vines, flower beds with lavender and pink roses, cypress
trees. FIVE EMPTY BUILDING PLOTS: flat round or square stone foundations with nothing built on
them: back center (large), left back, left front, right middle (round), far right (round tower
base). Small floating islands with waterfalls in the far top corners, soft clouds below.
No buildings, no characters.
```

## 2. Clădirile, câte 5 niveluri → `art2d/buildings/<id>_<nivel>.png`

Pentru fiecare clădire generezi 5 imagini (nivelul 1 → 5), pe fundal `#FF00FF`.
Prompt: `[STIL] Single isolated building, centered, full building visible, on a flat solid
magenta (#FF00FF) background, no ground, no shadow. ` + descrierea de mai jos.

| Fișier | Descriere (nivel 1 → 5) |
|---|---|
| `palat_1..5` | **Palatul Norilor**. 1: mic pavilion de piatră cu o cupolă turcoaz simplă. 2: corp central cu ușă cu arc luminată și scări. 3: + două turnuri laterale cu cupole ceapă. 4: + cupolă centrală mare cu nervuri aurii, bannere violet, cristal turcoaz deasupra ușii. 5: ca în randare, cu steaguri violet, lanternă aurie în vârf, iederă și trandafiri. |
| `obs_1..5` | **Observatorul**. 1: turn rotund scund cu acoperiș violet. 2: + ferestre luminate și ușă. 3: + balcon cu balustradă. 4: + cupolă violet cu nervuri aurii și deschizătură cu cer înstelat. 5: + telescop auriu mare, stele luminoase, iederă. |
| `turn_1..5` | **Turnul Elegant**. 1: turn de piatră scund. 2: mai înalt, ușă de lemn. 3: + banner violet cu frunză aurie. 4: + balcon și cupolă turcoaz. 5: foarte înalt, cupolă cu vârf auriu, ferestre luminate. |
| `mag_1..5` | **Magazinul**. 1: tarabă de lemn cu copertină violet. 2: căsuță de piatră cu vitrină. 3: + copertină violet festonată cu frunză aurie. 4: + rafturi luminate, ghivece cu flori. 5: magazin elegant cu acoperiș turcoaz, ferestre aurii, lanterne. |
| `sera_1..5` | **Sera de Cristal**. 1: ramă aurie mică cu câteva plante. 2: seră mică de sticlă. 3: seră octogonală cu cupolă de sticlă. 4: + plante luxuriante și lumini calde. 5: seră mare cu nervuri aurii, flori roz și violet, lumină caldă înăuntru. |

## 3. Mascota → `art2d/mascot/<poză>.png`

Prompt: `[STIL] Cute round white bean-shaped mascot with big glossy black eyes, open happy smile,
rosy cheeks, brown leather aviator cap with a purple top and big golden aviator goggles with
blue lenses, purple scarf with a golden leaf emblem, brown leather backpack with rolled maps,
small stubby legs and arms. Full body, centered, on a flat solid magenta (#FF00FF) background,
no ground, no shadow. ` + poza:

| Fișier | Poză |
|---|---|
| `idle.png` | stă, zâmbește, privește spre noi (3/4 din față) |
| `wave.png` | face cu mâna (ca în randare) |
| `jump.png` | sare de bucurie, brațele sus |
| `walk1.png`, `walk2.png` | pași de mers, profil 3/4, piciorul stâng / drept în față |
| `cheer.png` | foarte fericit, ochii închiși de bucurie, confetti |

## 4. Opțional

- `art2d/sky/sky.png` – doar cer cu nori pufoși, portret 1080×2400, fără insule.
- Iconițe pentru interfață (monedă, nivel, album, prieteni, trofeu, magazin) pe `#FF00FF`.

## Licență

Înainte de publicarea în magazin, verifică în termenii generatorului AI că imaginile pot fi
folosite comercial (de regulă necesită un plan plătit) și păstrează o copie a termenilor.
