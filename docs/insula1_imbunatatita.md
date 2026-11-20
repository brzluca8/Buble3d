# Insula 1, îmbunătățită

Ramura `orion-insula-v2`.

Insula din joc este **insula trimisă de tine**: modelul din Tripo, pregătit pentru joc cu `blender/island_prep.py`. Aceeași formă, aceleași clădiri, aceleași 22 de căsuțe, pe aceleași poziții. Nu am refăcut nimic de la zero. Am îmbunătățit textura, culorile, apa, luminile și atmosfera.

Versiunea v2, refăcută de la zero după specificația „versiunea 2”, nu mai e folosită de joc (vezi secțiunea 8).

## 1. Ce am măsurat la insula ta

**Mesh:** 196.447 de triunghiuri, un singur mesh și o singură textură de 2048 × 2048 px.

**Suprafață:** 3.008 m² în total. Asta include clădirile, copacii, stâncile, partea de dedesubt și fețele întoarse în jos.

**Densitatea texturii:** 28 px/m, aceeași peste tot. Tripo împarte pixelii după arie. Prin comparație, Orion are ~416 px/m.

**Cum sunt împărțiți pixelii:**

| Zonă | Arie | Pixeli din textură |
|---|---:|---:|
| sus, fețe spre cer (iarbă, drum, căsuțe, acoperișuri) — ce vede cel mai mult camera de joc | 312 m² | 10,6% |
| sus, pereți (clădiri, copaci, ziduri) | 972 m² | 32% |
| stânci laterale | 583 m² | 19% |
| dedesubt | 725 m² | 24% |
| fețe întoarse în jos | — | 18,5% (nu se văd niciodată de sus) |

**Apa** era pictată în textură, deci statică, cu un singur material lucios. **Cascadele** erau și ele pictate, nemișcate.

## 2. Ce am făcut

### 2.1 Textura: mărită cu AI, de 2 ori mai mulți pixeli pe metru
- Textura originală (2048 px, direct din GLB-ul Tripo) e mărită de 4 ori cu **Real-ESRGAN**, modelul `realesrgan-x4plus-anime`. A rulat local, pe procesor (biblioteca ncnn), în ~5 minute, cu modelele din versiunea oficială v0.2.5.0. Scriptul este `blender/insula1/upscale.py`.
- Am încercat trei modele pe aceeași bucată. „anime” a dat cele mai curate margini pentru stilul desenat al insulei: crăpăturile din stâncă și marginile clădirilor devin linii nete, iar petele de compresie dispar.
- Imaginea de 8192 px e redusă la **4096 px** (Lanczos) și pusă pe **aceleași UV-uri** ca originalul. Rezultatul: **56 px/m** față de 28 și margini mult mai curate. Un 4096 merge pe un telefon mediu, un 8192 nu.
- **Încercat și abandonat:** un atlas nou, cu mai mulți pixeli pe partea de sus. Împachetatorul din Blender umple doar 20–44% din atlas cu cele ~21.000 de insule UV ale lui Tripo, față de 57% în atlasul original. Partea de sus ar fi câștigat doar ~35%, cu risc de cusături vizibile.
- **Culori:** saturație mai mare, mai ales pe culorile șterse (media 0,28 → 0,34), și contrast cu 7% mai mare. Nuanțele rămân aceleași.

### 2.2 Apa care curge și cascadele (forma originală)
Apa este chiar apa din modelul tău. Fețele ei sunt găsite după culoare și orientare, apoi separate în obiecte proprii. Forma rămâne cea originală: doar suprafața e netezită, iar marginile rămân lipite de mal.

**Râul din jurul castelului:**
- 22,6 m de curgere, în sens invers acelor de ceasului, privit de sus;
- UV.x pe lățime și UV.y pe lungime, ca shaderul să-l facă să curgă;
- spumă sub cele 2 poduri, găsite automat: ceva acoperă râul pe toată lățimea.

**Laguna, marginea ei și cele 2 iazuri din cascada mare:** apă de lac, cu adâncimea calculată de la mal și spumă la mal.

**3 cascade** (dungi care cad, spumă la buză și la bază, ceață la bază):

| Cascadă | Înălțime | Lățime |
|---|---:|---:|
| cea mare, din față-dreapta (cade în gol) | 6,3 m | 2,1 m |
| a lagunei | 2,6 m | 1,2 m |
| cea de pe deal | 1,4 m | 0,5 m |

**Shaderul:** un singur shader pentru toată apa (`godot/insula1/shaders/water_flow.gdshader`). E opac și nu folosește textura de adâncime, care e scumpă pe rendererul Mobile. Culorile sunt cele ale apei pictate pe insula ta, puțin mai luminoase.

### 2.3 Lumini, portal, aterizare
- **Felinare, ferestre, cristale:** o mască de lumină, calculată din textură, e pusă în canalul R al texturii ORM. Flăcările și ferestrele calde pâlpâie, fiecare în ritmul ei. Cristalele reci pulsează încet.
- **Portalul:** în arcada aurie apare un vârtej cyan-violet care se rotește. Panoul din arcadă e găsit automat, după culoare și orientare.
- **Aterizarea pe o căsuță:** căsuța se aprinde scurt și din marginea ei pleacă o undă aurie (0,9 s). Folosește `on_landed(i)`, chemat deja de joc.

### 2.4 Atmosferă și viață
- **Cer și lumină:** cer în gradient albastru, ton ACES, glow moderat, saturație +8%, ceață de distanță. Un soare cald din sus-stânga-față, cu umbre în 2 trepte, plus un contur cyan discret din spate.
- **Nori și raze:** o mare de nori sub insulă, nori departe și raze de soare false.
- **Fundal:** 5 insulițe care plutesc ușor.
- **Viață:**
  - 36 de petale purtate de vânt;
  - 6 fluturi pe lângă drum;
  - ceață la baza cascadelor (50 de particule).
- **Calitate Mic / Mediu / Mare și „mișcare redusă”:** vezi `godot/README.md`.

## 3. Ce nu am făcut și de ce
- **Moara de vânt nu se rotește, iar barca nu se leagănă.** Fac parte din același mesh cu restul insulei. În modelul Tripo, „pânzele” morii au ieșit ca două panouri strâmbe, nu ca o cruce de pânze. Ca să se rotească, ar trebui decupate și refăcute. Pot face asta dacă vrei.
- **Vegetația nu se mișcă în vânt,** din același motiv: un singur mesh. Petalele și fluturii aduc mișcarea.
- **Fazele** (clădirile care apar pe rând: natură, sat, castel): pe un singur mesh nu se pot ascunde clădiri fără să le decupez. Se poate face, la fel ca la moară.
- **Căsuțe speciale** (Cufăr, Zar bonus, Eveniment, Carte), cu iconițe: insula ta nu le are, iar jocul nu are încă tipuri de căsuțe. Nu le-am adăugat.
- **Numărul de triunghiuri nu s-a schimbat:** 196 de mii la insulă, plus 188 de mii la Orion. Dacă pe telefon nu se ține 60 FPS, pot face o variantă simplificată a insulei (de exemplu ~100 de mii), cu aceeași textură.

## 4. Buget (calculat din fișiere, nu măsurat pe GPU)

| Componentă | Triunghiuri | Apeluri de desenare (trecerea principală) |
|---|---:|---:|
| insula (mesh-ul tău) | 194.156 | 1 |
| apa + cascadele (tot din mesh-ul tău) | 2.291 | 2 |
| portal, efect de aterizare (doar cât ține) | 2 + 2×3 | 1 + ≤3 |
| insulițe în fundal | 1.910 | 5 |
| nori + raze | 66 | 33 |
| particule (ceață 50, petale 36) | 172 | 4 |
| fluturi | 24 | 6 |
| Orion (înainte de LOD-ul automat din Godot) | 188.474 | 2 |
| **Total** | **~387.000** | **~55** |

- **Umbre:** obiectele care aruncă umbră (insula, Orion) se mai desenează o dată pentru fiecare treaptă de umbră, la calitatea Mediu și Mare.
- **Materiale unice:** 10:
  - insula, apa, portalul, aterizarea;
  - particulele, culorile pe vârfuri, norii, razele;
  - Orion (2).
- **Texturi:**
  - insula: albedo 4096² și ORM 2048²; Godot le comprimă la import (ETC2/ASTC), cam 21 MB + 5 MB în memoria video;
  - apa: valuri, 512²;
  - nori și raze: 256².
- **FPS:** nu am putut măsura. Pentru cifre reale, pune `buble/debug/statistici=true` în `project.godot`. Pe ecran apar FPS-ul, triunghiurile și apelurile de desenare, citite chiar din Godot.

## 5. Verificare: ce s-a putut verifica și ce nu
- **Godot n-a putut fi rulat** aici: pornirea programului Godot descărcat a fost blocată de sistemul de permisiuni. Nu există capturi din Godot și nici FPS măsurat.
- **Imaginile din `docs/shots/` sunt randate în Blender** (Cycles), cu aceleași modele și aceleași cadre ca jocul: camera de joc lângă START, cadru mediu, panoramă. Materialele aproximează shaderele din Godot. Apa e statică în randări, iar în joc curge.
- **GLB-ul insulei** a trecut de validatorul glTF de la Khronos: 0 erori, 0 avertismente.
- **Scripturile GDScript** trec de analizorul sintactic `gdparse` (gdtoolkit 4). Asta nu verifică tipurile sau numele de metode la rulare.
- **Shaderele `.gdshader` n-au putut fi compilate** aici. La prima deschidere în Godot, eventualele erori apar în panoul **Output**.
- **Puncte de urmărit în Godot:**
  - uniformele `instance uniform` din efectul de aterizare;
  - tangentele apei, pe care Godot le generează la import;
  - texturile luate din materialul importat al GLB-ului: `albedo_texture` și `roughness_texture`, care sunt textura ORM.

Imaginile:

| Fișier | Ce arată |
|---|---|
| `docs/shots/compara_panorama.png` | ținta, înainte și după |
| `docs/shots/compara_aproape.png` | camera de joc: înainte, după, după cu efectul de aterizare |
| `docs/shots/compara_claritate.png` | aceeași bucată din cadrul de joc, mărită, înainte și după |
| `docs/shots/insula1_vechi_*.png`, `docs/shots/insula1_nou_*.png` | cadrele separate |

## 6. Cum se reface
Cu modulul `bpy` al Blender 5.1, plus `numpy`, `scipy` și `pillow`.

Pentru mărire, `ncnn` și modelele Real-ESRGAN din arhiva oficială `realesrgan-ncnn-vulkan-20220424-ubuntu.zip` (versiunea v0.2.5.0). Din arhivă se folosesc doar fișierele `.param` și `.bin`, nu și programul.

```bash
python blender/insula1/upscale.py textura_2048.png textura_8192.png modele/realesrgan-x4plus-anime
python blender/insula1/imbunatateste.py -- --textura textura_8192.png      # GLB-ul + datele pentru Godot
python blender/insula1/texturi.py                                          # valuri, nor, rază de soare
python blender/insula1/previzualizare.py -- --model nou                    # previzualizări (și --model vechi)
python blender/insula1/compara.py                                          # imaginile de comparație
```

Textura de 2048 px se extrage din `blender/tripo/insula1_tripo.glb`, imaginea `baseColorTexture`.

## 7. Credite
Nu am folosit credite de generare 3D: 0 cheltuite.

Real-ESRGAN (Xintao Wang și colaboratorii) are licența BSD-3-Clause. Detaliile sunt în `godot/assets/models/CREDITS.md`.

## 8. Insula v2 (refăcută de la zero)
Specificația „versiunea 2” cerea să nu mai folosim GLB-ul ca insulă și să construim terenul și clădirile separat. Așa a apărut v2: teren procedural, iar clădirile sunt PLACEHOLDER-e. Ți-ai dorit însă insula ta, îmbunătățită, nu refăcută, așa că jocul a revenit la ea.

Fișierele v2 au rămas în proiect, dar **nu sunt folosite**:
- `godot/insula_v2/`
- `godot/assets/models/insula1_v2/`
- `blender/insula_v2/`
- `docs/insula_v2_plan.md`

Le pot șterge dacă vrei. Rămân oricum în istoricul git.
