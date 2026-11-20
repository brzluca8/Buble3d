# Insula 1, versiunea 2: plan

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
Se completează la final, după construcție.
