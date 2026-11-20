# Insula 1, versiunea 2: plan

> **Înlocuit.** Jocul nu mai folosește această insulă refăcută. Folosește insula trimisă de utilizator, îmbunătățită: vezi `docs/insula1_imbunatatita.md`. Fișierele v2 (`godot/insula_v2/`, `blender/insula_v2/`, `godot/assets/models/insula1_v2/`) au rămas în proiect, dar nu sunt folosite.


Ramura `orion-insula-v2`. Documentul se completează pe măsură ce se construiește; secțiunea 8 (verificare) e la final.

## 1. Ce am găsit în proiect

**Scena de joc** este `godot/insula.tscn` + `godot/insula.gd` (scena principală). Totul se construiește din cod:
- `_build_world()` face cerul procedural, soarele, lumina de umplere, norii (pete albe) și camera;
- `_load_models()` încarcă GLB-ul insulei (`ISLAND_PATH`) și pe Orion (`ORION_PATH`), apoi îl pune pe Orion pe `tiles[0]`;
- datele căsuțelor sunt în `godot/data/insula1_casute.gd`:
  - `CASUTE`: 22 de `Vector3`, în metri, cu Y în sus și Z spre cameră, ordonate de la START;
  - `RAZA` = 0,76 m;
  - `PAS` = 1,9 m.

  Le-a generat `blender/island_prep.py` din GLB-ul v1.
- **Mutarea:** `_on_roll()` → `_update_roll()` (zarul 1–6) → `_start_hop()` / `_update_hop()`. Săritura e o parabolă între căsuțe, cu turtire la aterizare (`land_t = 0.0` la sosirea pe căsuță). Mai sunt `_update_info()` și `_flash()`.
- **Camera:** orbită în jurul lui Orion (`yaw`, `pitch`, `dist`), urmărire lină și zoom. De departe se uită la `ISLAND_CENTRE`.

**Diferențe față de cerere:**
- **Tipuri de căsuțe nu există în proiect.** Singura convenție e START = căsuța 0. Nu pot „păstra tipurile existente”. Propun o listă de tipuri **doar vizuală**, în `godot/insula_v2/data/tipuri_casute.gd`, pe care o poți schimba. Logica jocului nu o citește.
- **Orion are 1,2 m** în proiect, ca în planșa de personaj. În cerere scrie 1,15 m. Păstrez 1,2 m și dimensionez props-urile față de el.
- **Fișierele de referință cerute nu existau în repo.** Am creat `reference/` cu:
  - `insula_tinta.jpg`: desenul insulei pe care mi l-ai trimis;
  - `insula_v1_aproape_generat.jpg` și `insula_v1_panorama_generat.jpg`: starea v1, randată de mine în Three.js, nu capturi din Godot;
  - `orion_render.png`: randarea fețelor lui Orion, din `blender/out_tripo/tripo_face.png`.
- **`assets/models/orion.glb`** era `godot/models/orion_tripo_game.glb`. L-am mutat în `godot/assets/models/orion.glb` și am actualizat cele două căi (`insula.gd`, `main.gd`).
- **Folderele `assets/...`** din cerere sunt în proiectul Godot (`godot/assets/...`), pentru că Godot vede doar ce e sub `godot/`. Documentele sunt în `docs/`, iar referințele în `reference/`, la rădăcina repo-ului.
- **GLB-ul v1** al insulei e acum în `godot/assets/models/_vechi/insula1_tripo_v1.glb`. Se folosește doar ca referință pentru poziții, nu mai e insula de joc.

## 2. Diagnostic (verificat, cu măsurători)

| # | Problemă | Verificare |
|---|---|---|
| 1 | Densitate de texeli mică | Am măsurat pe fiecare triunghi √(texeli UV / aria 3D), ponderat cu aria. **Insula v1: ~28 px/m** (p10 27, p90 30): o textură de 2048 px pe ~3000 m² de suprafață. **Orion: ~416 px/m** (p10 405, p90 436). Insula e de **~15× mai încețoșată** decât Orion. Densitatea e uniformă, dar uniform mică. |
| 2 | Stânci cu UV-uri întinse, geometrie zgomotoasă | Confirmat vizual în randările v1: pereți „topiți”, texturi întinse pe verticală. |
| 3 | Apă plată, cascadă fără mișcare | Confirmat: apa e doar culoare în textură (am făcut-o lucioasă în v1, dar nu curge), iar cascadele sunt pictate pe pereți. |
| 4 | Căsuțe netede, fără gravură | Confirmat: gravura există doar în textură, la 28 px/m, deci practic nu se vede. Geometria e un disc. |
| 5 | Artefacte de generare | În vederea de sus se văd panouri mari albastre pe moară și pe piață, plus geometrie lipită între obiecte (palmieri, felinare). |
| 6 | Culori pastel, spălate | Am măsurat textura de culoare. **Saturația mediană: insula 0,24, Orion 0,84.** **Contrastul** (abaterea standard a luminanței): insula 0,12, Orion 0,21. |

## 3. Arhitectura v2 (modulară)

Totul e în `godot/insula_v2/`, iar modelele în `godot/assets/models/insula1_v2/`.

| Piesă | Fișiere | Cum |
|---|---|---|
| Nodul insulei | `insula_v2.tscn`, `insula_v2.gd` | Construiește tot vizualul: mediu, lumini, teren, apă, props, vegetație, căsuțe, atmosferă. Expune `calitate` (0 Mic, 1 Mediu, 2 Mare), `miscare_redusa` și `on_landed(i)`. |
| Teren și stânci | `assets/models/insula1_v2/teren.glb`, `shaders/teren_triplanar.gdshader`, `textures/*` | Generat în Blender headless, cu harta de înălțimi din v1 curățată. Shader triplanar în spațiul lumii: iarbă pe plat, stâncă pe abrupt, mușchi la tranziție, cărare/nisip din măștile din culorile de vârf, AO coaptă în culorile de vârf. |
| Apă | `shaders/water_flow.gdshader`, `water_ribbon.gd`, `data/apa.gd` | Râul e o panglică dintr-un `Path3D` (UV.y = curgerea), laguna o suprafață cu același shader, cascadele panglici verticale, iar ceața un `GPUParticles3D`. |
| Hero props | `assets/models/insula1_v2/props/*.glb`, `data/props.gd` | Acum sunt **PLACEHOLDER-e** (forme simple, marcate), la pozițiile din v1, pe faze. Înlocuirea înseamnă doar copierea GLB-ului generat peste fișier. |
| Elemente mici | `assets/models/insula1_v2/mici/*.glb`, `data/vegetatie.gd` | Generate procedural în Blender (low-poly, culori de vârf cu AO), instanțiate cu `MultiMeshInstance3D` și `visibility_range`. |
| Căsuțe | `Tile.tscn`, `tile.gd`, `data/tipuri_casute.gd` | Piatră bej, chenar auriu teșit și gravură în romb (normal map). Căsuțele speciale au iconiță și inel luminos. La aterizare: undă și o scurtă aprindere. |
| Vânt | `project.godot` → `[shader_globals]` `vant_directie`, `vant_putere` | Uniforme globale citite de vegetație, steaguri și nori, plus de scripturi (moara, barca). |

`insula.gd` (jocul) se schimbă minimal:
- în loc de GLB-ul v1, instanțiază `insula_v2.tscn`, care își face singur mediul și luminile;
- la aterizare cheamă `on_landed(i)`.

Zarul, mutarea, datele căsuțelor, UI-ul și camera rămân neschimbate.

## 4. Plan de asset-uri și credite

**Conectorul 3D AI Studio nu e disponibil în această sesiune**: nu apare printre unelte, iar rețeaua mediului a blocat anterior `3daistudio.com`. Nu am ocolit nimic, **nu s-au cheltuit credite**, iar `get_credit_balance` și `list_available_models` nu au putut fi rulate. Pentru costul unei generări nu am o sursă, așa că bugetul e calculat cu o necunoscută **C** (credite pe generare imagine→3D), pe care o citești din `list_available_models`.

| Grup | Asset | Metodă | Limită | Credite estimate | Stare |
|---|---|---|---|---|---|
| A | teren + stânci | Blender procedural | ~25k tris | 0 | **făcut** (sec. 5) |
| A | materiale: iarbă, stâncă, cărare, mușchi, nisip, scândură, piatră de căsuță | procedural (zgomot, pictat în numpy) | 1024 px, tileable | 0 (cu conectorul: 7 × ~10 = 70) | **făcut**, procedural |
| B | castel | Hunyuan 3.1, decupaj `castel.png` | 12k tris, 2048 | ≤ 2C | PLACEHOLDER |
| B | moară de vânt (pânzele nod separat) | idem, `moara_de_vant.png` | 12k | ≤ 2C | PLACEHOLDER |
| B | portal cu cristale | idem, `portal_cristale.png` | 12k | ≤ 2C | PLACEHOLDER |
| B | piață (standuri) | idem, `piata_standuri.png` | 12k | ≤ 2C | PLACEHOLDER |
| B | atelier | idem, `atelier_debarcader.png` (partea stângă) | 12k | ≤ 2C | PLACEHOLDER |
| B | debarcader | idem (partea dreaptă) | 12k | ≤ 2C | PLACEHOLDER |
| B | barcă cu pânză (pivot în centrul carenei) | idem, `barca.png` | 12k | ≤ 2C | PLACEHOLDER |
| B | pod arcuit (de 2 ori) | idem, `pod_arcuit.png` | 12k | ≤ 2C | PLACEHOLDER |
| C | palmieri ×3, arbori roz ×2, copac mare, tufe, gard, felinar, butoi, ladă, cristale ×3, pietre, flori, iarbă, nuferi | Blender procedural | ≤ 2k tris fiecare | 0 | **făcut**, procedural |

Cu bugetul de **500**: materialele AI (70) plus 8 props × 2 încercări × C ≤ 500 înseamnă **C ≤ 26**. Dacă o generare costă mai mult, prioritatea e castel → moară → portal → piață → barcă → atelier → debarcader → pod (sec. 7).

## 5. Decizii tehnice
- **Lumina:** aceeași direcție ca la Orion în randări: cheie caldă sus-stânga-față, ambient din cer, plus un rim cyan discret din spate.
- **Umbre:** o singură `DirectionalLight3D`, 2 cascade (`SHADOW_PARALLEL_2_SPLITS`), distanță limitată la 45 m.
- **Densitatea de texeli pe teren:** texturi tileable de 1024 px pe 2 m, mapate triplanar în spațiul lumii, deci **512 px/m peste tot, uniform**. Nu depinde de UV-uri, așa că nu se poate întinde nimic.
- **Ocluzia ambientală:**
  - `LightmapGI` nu se poate coace aici, pentru că Godot nu poate fi rulat în acest mediu;
  - **am ales AO coaptă în culorile de vârf** în Blender, prin raze pe BVH, pentru teren (incluzând props-urile la locul lor), props și vegetație;
  - plus umbre de contact false: discuri moi întunecate sub clădiri și sub copaci.
- **Apa:** fără textura de adâncime, pentru că pe rendererul Mobile citirea adâncimii e scumpă. Gradientul de adâncime vine din UV: malurile (UV.x lângă 0 sau 1) sunt turcoaz deschis, centrul albastru adânc. Spuma vine din UV și zgomot, iar laguna folosește distanța până la mal, coaptă în culoarea de vârf.
- **Mișcare redusă:** opțiunea `miscare_redusa` din nodul insulei oprește vântul, particulele și rotațiile. Proiectul nu are o setare globală de accesibilitate.

## 6. Faze (propunere)
Props-urile au câmpul `faza` în `data/props.gd`:
- **faza 1:** natura, ruinele și tabăra;
- **faza 2:** satul (moara, câmpul, piața, atelierul);
- **faza 3:** castelul, portul și portalul.

`insula_v2.gd` arată tot până la `faza_curenta` (implicit 3), iar ce apare face un „pop” scurt. Tabăra din faza 1 (cort, foc, telescop) nu e în țintă; e doar propusă, nu e construită.

## 7. De generat manual (prioritizat), cu decupajele din `godot/assets/models/_decupaje/`
1. `castel.png`: elementul central, cel mai vizibil.
2. `moara_de_vant.png`: generează moara fără pânze sau separă pânzele într-un nod `Panze` cu pivotul pe ax.
3. `portal_cristale.png`: arcada; vârtejul e shader, deci arcada trebuie să rămână goală la mijloc.
4. `piata_standuri.png`
5. `barca.png`: pivotul în centrul carenei, iar pânza nod separat (`Panza`).
6. `atelier_debarcader.png`: atelierul și debarcaderul, ca două asset-uri.
7. `pod_arcuit.png`

Pentru fiecare asset: max. 12.000 de triunghiuri, textură de max. 2048 px, un singur material, originea la bază, scara în metri (Orion = 1,2 m). Decupajele sunt mici (225–561 px), pentru că imaginea țintă are 1122×1402 px. Dacă serviciul o cere, mărește-le la 1024 px înainte. Fundalul nu e scos: remove_background nu a fost disponibil.

## 8. Verificare

### Ce s-a putut verifica și ce nu
- **Godot n-a putut fi rulat** în mediul în care s-a lucrat: pornirea programului Godot descărcat a fost blocată de sistemul de permisiuni. De aceea **nu există capturi din Godot** și nici FPS măsurat.
- **Imaginile din `docs/shots/` sunt previzualizări randate în Blender (Cycles).** Folosesc aceleași modele și date ca jocul: teren, clădiri, elemente mici, căsuțe, poziții, apă. Materialele aproximează shaderele din Godot, deci în joc culorile și lumina vor ieși puțin altfel.
- **GDScript:** toate scripturile trec de analizorul sintactic `gdparse` (gdtoolkit 4): `insula.gd`, `main.gd`, `insula_v2/*.gd`, `insula_v2/data/*.gd`. Asta nu verifică numele de metode sau tipurile la rulare.
- **Shaderele (`.gdshader`) n-au putut fi compilate.** Le-am scris cu funcții standard din Godot 4. La prima deschidere în Godot, panoul **Output** arată orice eroare de compilare. Ce merită urmărit:
  - uniformele globale `vant_directie` și `vant_putere` (definite în `project.godot` > `[shader_globals]`);
  - uniformele `instance uniform` (căsuță, semne, undă), care merg pe rendererele Forward+ și Mobile;
  - `NORMAL_MAP` pe plasele de apă (tangente din `SurfaceTool.generate_tangents()`);
  - `sampler2D` ca parametru de funcție (shaderul de teren).
- **Modelele GLB** sunt generate cu exportatorul glTF din Blender 5.1.

### Densitatea texelilor (măsurată)
- **Teren și stânci:** 512 px/m peste tot, prin construcție (texturi de 1024 px pe 2 m, mapate triplanar în spațiul lumii, fără UV-uri). Imaginea `docs/shots/densitate_checker.png` arată textura de verificare: un pătrat = 25 cm = 128 px, la fel de mare peste tot.
- **Căsuțele:** 1024 px pe 1,56 m, adică ~656 px/m.
- **Pentru comparație:**
  - insula v1: ~28 px/m (măsurat pe fiecare triunghi, ponderat cu aria);
  - Orion: ~416 px/m.
- **Clădirile placeholder și elementele mici n-au texturi**, doar culori pe vârfuri cu AO coaptă. Nu sunt încețoșate, dar nici nu au detaliu pictat; e diferența principală față de Orion care rămâne.

### Buget (din fișiere, nu măsurat pe GPU)
| Componentă | Triunghiuri | Draw calls (trecerea principală) |
|---|---:|---:|
| teren + platou | 27.114 | 2 |
| clădiri (placeholder, fără marcaje) | 6.520 | 22 |
| elemente mici (MultiMesh) | 22.004 | 27 |
| căsuțe (22) + iconițe/inele speciale | 16.668 | 34 |
| apă: râu, lagună, iaz, 4 cascade | 1.402 | 7 |
| insulițe fundal (5) | 1.910 | 5 |
| nori + raze (dreptunghiuri) | 66 | 2 |
| particule: ceață 4 + frunze/petale 1 | 216 | 3 |
| fluturi (6) | 24 | 6 |
| Orion (model complet, înainte de LOD-ul automat) | 188.474 | 1 |
| **Total** | **264.398** | **109** |

- **Insula fără Orion:** ~76.000 de triunghiuri, ~108 apeluri de desenare în trecerea principală.
- **Umbre:** obiectele care aruncă umbră se mai desenează o dată pentru fiecare din cele 2 cascade de umbră, la calitatea Mediu și Mare. La Mic, umbrele sunt oprite.
- **Orion are 188 de mii de triunghiuri.** Godot îi face automat LOD-uri la import, iar la distanța de joc se desenează mai puține. Cât de puține nu pot spune fără să rulez Godot.
- **Materiale unice:**
  - teren, apă (unul singur pentru râu, lac și cascade), vegetație, cristal, portal;
  - culori pe vârfuri (clădiri, obiecte, fluturi), lumini;
  - căsuță, semne (iconiță și inel), undă;
  - nori, raze, particule;
  - Orion (2).

  În total 15, plus 1 pentru marcajele magenta cât sunt placeholder-e.
- **Particule:** ~120 în total (ceață 4 × 14–22, frunze și petale 36). Fluturii (6) sunt mișcați din script.
- **Pentru măsurători reale:** pune `buble/debug/statistici=true` în `project.godot`. Pe ecran apar FPS-ul, triunghiurile, apelurile de desenare și obiectele, citite din Godot (`RenderingServer.get_rendering_info`).

### Calitate Mic / Mediu / Mare
Se alege automat (Mediu pe telefon, Mare pe calculator) sau din `buble/grafica/calitate`.

| | Mic | Mediu | Mare |
|---|---|---|---|
| umbre (o lumină, 2 cascade) | nu | 32 m | 45 m |
| hărți normale (teren, căsuțe) | nu | da | da |
| apă avansată (al doilea strat de valuri, spumă cu zgomot, sclipiri) | nu | da | da |
| vânt în shader | nu | da | da |
| particule (ceață, frunze/petale) și fluturi | nu | da | da |
| glow | nu | da | da |
| nori | 14 | 30 | 30 |

**Mișcare redusă** (`buble/accesibilitate/miscare_redusa`) oprește:
- vântul, frunzele, fluturii și ceața;
- rotația morii și leagănul bărcii;
- pulsul cristalelor și al inelelor, unda de la aterizare;
- curgerea apei, care devine foarte lentă.

### Ce din țintă e prezent, ce e PLACEHOLDER, ce diferă

**Prezent, construit nou (nu AI):**
- teren cu inel de iarbă, platoul castelului cu zid și scări, piață pavată;
- stânci în straturi, con dedesubt cu cristal;
- râul în jurul castelului (curge, spumă sub poduri), lagună, iaz pe deal, 4 cascade cu ceață;
- 22 de căsuțe cu chenar auriu și gravură în romb; cele speciale au iconiță și inel;
- felinare care pâlpâie;
- palmieri, copaci cu flori roz, copac mare, tufe, iarbă, flori, câmp de grâu cu gard, butoaie, lăzi, cristale, pietre, nuferi;
- vânt, petale, fluturi, nori, raze de soare, 5 insulițe în fundal.

**PLACEHOLDER (forme simple, marcate cu inel magenta și etichetă):** castelul, moara (pânzele se rotesc), portalul (vârtejul e shader, merge și acum), piața, atelierul, debarcaderul, barca, podurile. Le înlocuiești copiind GLB-ul generat peste fișierul din `godot/assets/models/insula1_v2/props/`, cu aceleași nume de piese. Vezi secțiunea 7.

**Diferă față de țintă:**
- **Detaliul clădirilor:** placeholder-ele sunt mult mai simple decât desenul, fără texturi pictate.
- **Numărul de căsuțe:** 22 (ca în joc), față de ~28 în desen. Căsuțele sunt mai mici față de insulă decât în desen, pentru că distanța dintre ele (1,9 m) e fixată de joc.
- **Vegetația** e low-poly, cu culori pe vârfuri, fără frunze pictate. Palmierii sunt mai puțini decât în desen și lipsesc din fața camerei, ca să nu acopere căsuțele.
- **Stâncile** au plăci mari în straturi; în desen sunt bolovani mai rotunjiți și mai variați.
- **Apa** e opacă (fără transparență); se văd fundul și pietrele doar ca nuanță mai deschisă la mal.
- **Cascadele** sunt panglici cu dungi; în desen sunt mai voluminoase.
- **Lumina:** fără `LightmapGI` (nu se poate coace fără Godot). AO e coaptă în culorile de vârf și există umbre de contact false sub clădiri, din AO.
- **Faza 1 (tabăra cu cort, foc, telescop)** nu e construită: e doar propusă.
- **Tipurile de căsuțe** sunt o propunere vizuală (`insula_v2/data/tipuri_casute.gd`); jocul nu are încă tipuri.

### Imagini
- `docs/shots/insula_v2_aproape.png`, `insula_v2_mediu.png`, `insula_v2_panorama.png`: cele trei cadre (previzualizare Blender).
- `docs/shots/compara_panorama.png`: ținta, v2 și v1.
- `docs/shots/compara_aproape.png`: v1 aproape, v2 aproape și v2 mediu.
- `docs/shots/compara_claritate.png`: Orion lângă căsuțe, la aceeași scară, în v1 și v2.
- `docs/shots/densitate_checker.png`: densitatea texelilor.
- `docs/shots/insula_v2_panorama_marcaje.png`: aceeași panoramă, cu marcajele placeholder-elor.
