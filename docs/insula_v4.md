# Insula 1, v4: runda finală de calitate (raport)

**Important:** n-am putut rula Godot cu randare aici. Capturile din `docs/shots/insula_v4_*.png` sunt **randări Blender
(Cycles)** care imită shaderele din joc: apa, vântul, umbrele norilor și estomparea sunt statice în ele. Cifrele reale
(FPS, triunghiuri, apeluri de desenare) le arată scena de test pe telefon: `godot/test/test_insula.tscn` (F6), sus.

Ramura: `orion-insula-v4`, câte un commit pe pas. Credite cheltuite: **0** (plafon 500).

## Pasul 1: defecte rapide

| Defect | Cauza reală | Ce am făcut | Dovada |
|---|---|---|---|
| Puncte (dither) pe vegetația din prim-plan | Estomparea din A11: `discard` după un zgomot pe ecran („interleaved gradient noise”) în `insula.gdshader`, pe un con între cameră și Orion și la < 2,4 m de cameră | Scoasă cu totul. Obiectele separate care pot acoperi pe Orion (copacii noi, barca, clădirile ca piese) trec lin în transparență (alfa pe instanță, 0,35 s), cu histerezis 0,5 s; variantele `insula_estompat` / `recuzita_estompat` | codul; nu mai există `discard` în shaderele insulei |
| Linii negre pe insulă | v3 simplifica fiecare clasă separat, **după** tăierea pe clase: marginile dintre clase se simplificau diferit pe cele două părți și rămâneau fante (p95 ~6 cm) prin care se vedea fundalul | Simplificarea se face o dată, pe tot mesh-ul sudat, **înainte** de tăiere. Vârfuri de margine cu fantă > 2 mm: restul 9.053 → 218, stânci 4.679 → 98, iarbă 3.087 → 21, frunziș 6.116 → 139 (p95: 0) | `blender/insula1/v3_faza_a.py`, măsurat pe GLB |
| Triunghiuri negre pe insulițele din fundal | Fețe cu normala spre interior (domul de sus și coroanele care se intersectau); cu materialul pe două fețe, Godot le umbrea negru | Insulițele refăcute ca corpuri închise, netede (revoluție, sfere, trunchiuri curbe); scriptul verifică 0 fețe întoarse | `insula_v4_*` (fundal), `insulite.py` |
| Dungi de umbră | Bias-ul umbrei micșorat în v3 (0,04 / 1,2) | Înapoi la valorile Godot (0,1 / 2,0) | `insula1.gd` |
| Căsuțe arse în alb, gravura invizibilă | Piatra avea albedo 0,89–0,97 (bej foarte deschis) și gravura tot bej deschis, la 80%; adâncimea normalelor 0,8 | Albedo ≤ 0,82 în textură și plafon 0,85 în shader, șanțul gravurii maro închis (70%), AO pe margine, adâncime 1,7, piatră mată; iconițe mai mari (0,98 m), cu contur, margini netede; inelul în culoarea tipului mai luminos | `insula_v4_aterizare.png`, `insula_v4_joc.png` |

**Camera (D4).** Pe ecran portret, cu FOV 40°, „Orion ≈ 22–26% din înălțimea ecranului” (ca mărime) și „cel puțin 6
căsuțe înainte” nu pot fi adevărate în același timp: 6 căsuțe înseamnă ~11 m de drum curb în jurul castelului, iar ca
să încapă, camera trebuie la ~16 m (Orion iese atunci ~6% din înălțime). Am ales ce servește jocul: **6 căsuțe înainte
(cât arată zarul cel mai mare) și ~50°**, cu Orion în **sfertul de jos al ecranului** (picioarele la ~24% de jos);
camera stă în spatele lui, pe direcția drumului, doar cât sare (dacă tragi de ea, rămâne cum ai pus-o). Cadrul apropiat
(Orion ~22% din înălțime) rămâne la zoom maxim și ~2,6 s după aterizare. Controalele sunt aceleași; valorile sunt sus
în `insula.gd` (`CAM_*`, `APROAPE_*`). A/B: `insula_v4_camera_AB.png`.

## Pasul 2: Inelul 1, procedural (0 credite)

- **Terenul** (`teren.glb`, 6.808 triunghiuri, 197 m²): pe harta de înălțimi coaptă din insula veche (raze verticale pe
  grilă de 0,25 m, pe clase), deci relieful e același; netezit ușor (scoate aspectul de hârtie boțită), căsuțele pe
  platforme, margine rotunjită cu fustă. Shader triplanar cu iarbă, pavaj, pământ, stâncă pe abrupt, mușchi; texturi
  tileable de **1024 px pe 2 m = 512 px/m**; pete mari calde/reci în coordonatele lumii (fără repetare vizibilă); AO pe
  vârfuri (raze) + umbre de contact false sub căsuțe și recuzită. Măștile (pavaj, pământ) vin din pictura veche.
- **Scos din insula veche** în regiune: iarba, aleile, florile, frunzișul, pietrele mici, felinarele de pe stâlpi,
  cristalele, resturile mici (trunchiuri, stâlpi) și buza boțită a platoului (fețele joase, departe de clădiri). Castelul cu curtea lui, podurile, clădirile, apa și falezele rămân.
- **Recuzita nouă** (`assets/models/inel1/`, forme rotunjite, normale netede, gradient + zgomot pictat, AO coaptă), la
  locurile celei vechi: 3 palmieri (760 triunghiuri), 2 arbori roz (1.448), copacul mare (1.988), 7 tufe, 12 felinare
  (copacii și felinarele se estompează lin când ajung între cameră și Orion),
  13 grupuri de cristale (3 variante, emisive), garduri, 5 butoaie, 5 lăzi; presărate: 357 smocuri de iarbă, 121 de
  flori, 51 de pietricele (MultiMesh). Foaia: `insula_v4_recuzita.png`; harta de sus: `insula_v4_inel1_harta.png`.
- **Falezele și iarba rămase** din insula veche iau luminozitatea fină din texturile terenului (512 px/m, triplanar);
  culoarea pictată rămâne.

## Pasul 3: clădirile (credite)

Uneltele MCP 3daistudio **nu sunt conectate** în această sesiune, deci n-am generat nimic și n-am ocolit (detalii în
`docs/insula_gen_log.md`). Am pregătit: decupajele din imaginea-țintă, izolate și mărite x3
(`godot/assets/models/_decupaje/v4/`, foaia `insula_v4_decupaje.png`), și clădirile ca **piese separate**
(`Cladire_castel`, `_poduri`, `_piata`, `_moara`, `_portal`, `_atelier_debarcader`), cu ancora la bază. Un GLB pus în
`godot/assets/models/cladiri/<nume>.glb` le înlocuiește fără cod (`CITESTE.md` acolo).

## Pasul 4: insula vie

23 de elemente în mișcare, cu costul fiecăruia: `docs/insula_alive.md`. Vântul Aliseron (constant + rafale, plus valuri
de rafală care trec peste insulă) mișcă iarba, florile, frunzele, pânzele și moara; umbrele norilor trec peste teren;
valuri la barcă, pești care sar, fum, scântei, stropi la cascade. La Mic pleacă doar particulele scumpe; „mișcare
redusă” oprește tot.

## Pasul 5: lumină, atmosferă

O singură lumină direcțională (soarele cald din stânga-sus-față, 2 trepte de umbră, distanță limitată), ambient din
cer, ACES, glow moderat, aceeași nuanțare ca înainte; conturul cyan discret de la Orion vine acum din shadere (fresnel
pe partea dinspre spate), nu dintr-o a doua lumină. Aer în depărtare (`fog_aerial_perspective`) pentru insulițe.
DOF: comutator în scena de test, oprit implicit, pentru că pe Mobile e o trecere în plus pe tot ecranul; **n-am putut
măsura** costul aici (fără Godot), deci rămâne la tine: FPS cu DOF da/nu.

## Criteriile de acceptare

| Criteriu | Stare | Dovada |
|---|---|---|
| a) zero puncte de dither, zero negru, zero trepte de pixeli | puncte: scoase din cod; negru: fante 9.053 → 218 vârfuri, insulițe 0 fețe întoarse, terenul 0 fețe întoarse; trepte: iarba și florile sunt geometrie netedă, iconițele au margini netede | capturile; verificarea pe telefon rămâne la tine |
| b) ≥ 512 px/m la ≤ 8 m de căsuțe; clădiri ≥ 300 px/m | terenul: 512 px/m peste tot (tabla de șah: un pătrat = 25 cm = 128 px); recuzita n-are texturi (culori pe vârfuri, deci fără neclaritate de textură); **clădirile vechi: tot ~100–200 px/m** (PLACEHOLDER) | `insula_v4_joc_checker.png`, `insula_v4_aproape_checker.png` |
| c) căsuțele nu sunt arse, gravura se vede | da | `insula_v4_aterizare.png`, `insula_v4_joc.png` |
| d) ≥ 8 elemente în mișcare per cadru | da, după tabel (în randări sunt statice) | `docs/insula_alive.md` |
| e) buget | static: 150.437 triunghiuri fără Orion (Orion complet: 188.474, cu LOD automat în Godot când e mic); ~185 apeluri de desenare estimate (≈ 120 în trecerea principală + ≈ 65 în cele 2 trepte de umbră); 16 materiale unice în scenă (+2 variante de estompare, doar cât timp un obiect acoperă pe Orion); ~140 particule (19 la Mic). **Nu sunt cifre din Godot.** | `insula_v4.md`, scena de test |
| f) Orion lângă insulă, fără diferență jenantă | aproape de drum, da (iarba, pavajul, recuzita sunt clare); clădirile vechi din spate încă mai moi decât Orion | `insula_v4_orion_si_insula.png` |

## Bugetul (numărat din fișiere, nu din Godot)

| Ce | Triunghiuri |
|---|---:|
| Insula veche (clădiri, apă, faleze, ce a rămas) | 60.319 |
| Terenul nou (Inelul 1) | 6.808 |
| Căsuțele (22) + semnele celor 6 speciale | 16.668 |
| Copacii (6) | 7.164 |
| Tufele (7) | 3.360 |
| Felinare (12), cristale (13), butoaie (5), lăzi (5), garduri (3) | 13.568 |
| Iarbă (357 smocuri), flori (121), pietricele (51) | 30.438 |
| Insulițele din fundal (5) | 11.926 |
| Nori, halouri, portal, unde, pești, fluturi, păsări | 186 |
| **Total fără Orion** | **150.437** |
| Orion, modelul complet (Godot îl reduce singur cu LOD când e mic pe ecran) | 188.474 |

Cât se vede într-un cadru e mai puțin (camera de joc vede cam jumătate din insulă). Dacă pe telefon totalul trece de
~250.000, primii pași ar fi: jumătate din iarbă (ca la Mic) și LOD mai agresiv pentru Orion.

## Lista cinstită

- **Curat:** terenul de lângă drum (iarbă, pavaj, pământ la 512 px/m), recuzita nouă, căsuțele, insulițele din fundal,
  apa, fără puncte de estompare, fără fante negre între clase, camera nouă.
- **Încă slab:** clădirile (castel, piață, moară, atelier, poduri, portal) sunt tot din insula veche, moi față de
  Orion; falezele de sub margine sunt vechi (doar cu detaliu suprapus); în câteva locuri, la marginea dintre terenul
  nou și insula veche se vede trecerea; podul arcuit are un decupaj prea mic pentru o generare bună.
- **PLACEHOLDER:** toate clădirile din Inelul 2 (piese separate, gata de înlocuit), până la generarea cu credite.

## Următorul pas

Conectează MCP-ul 3daistudio (sau adaugă-l în mediu), apoi: `get_credit_balance`, `list_available_models` și
generarea din `_decupaje/v4/`, în ordinea castel, poduri, piață, moară, atelier + debarcader, barcă, portal (max 2
încercări pe obiect, ~340 de credite estimate). Pe telefon: scena de test, cifrele din colț, DOF da/nu.
