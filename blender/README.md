# Orion în Blender

`orion_build.py` construiește mascota Orion de la zero, după planșa de personaj (față, 3/4, profil, spate, expresii, accesorii, paletă), și o randează în Cycles.

## Fișiere rezultate (`out/`)
| Fișier | Ce este |
|---|---|
| `orion_sheet.png` | planșa în 4 vederi: Față, 3/4 Față, Profil (Lateral), Spate, plus înălțimea (≈ 1,2 m). Ca în concept, profilul are gura închisă, zâmbind |
| `orion_expresii.png` | cele 6 expresii: Bucuros, Surprins, Râzând, Determinat, Furios, Clipire |
| `orion_face.png`, `orion_hero.png` | prim-plan pe față și vedere 3/4 |
| `transparent/*.png` | aceleași vederi pe fundal transparent, pentru interfața jocului |
| `orion.blend` | scena completă: corp, blană (Hair Curves), accesorii, lumini, cameră (Blender 5.1+) |
| `orion_game.glb` | model ușor pentru joc: 1,2 m, fără blană, cu culori pe vârfuri |

## Cum e construit
1. **Corpul** este un câmp SDF transformat în mesh prin marching cubes. Componentele sunt:
   - capul (craniu, obraji, bot ușor ieșit în față);
   - urechile mari în formă de lacrimă: rotunde jos, ascuțite sus, cu vârful curbat în afară, scobite în față;
   - trunchiul, brațele cu pumni, picioarele cu labe mari și degete;
   - coada în spirală („C”).
2. **Culorile** sunt pictate pe vârfuri:
   - portocaliu-auriu, crem pe bot, obraji, piept și labe;
   - pete maro și marcaje-lacrimă pe frunte;
   - roz în urechi, mov pe jumătatea de sus a urechilor și pe arcul de sus al cozii;
   - marcaje turcoaz care strălucesc: spirala de pe coadă (pe fond indigo), stelele de pe coapse și brațe.
3. **Blana** are aproximativ 450.000 de fire Hair Curves, cu lungime, direcție și smocuri pe zone:
   - pe față e scurtă;
   - pe obraji formează un guler crem țepos;
   - coada e stufoasă;
   - vârfurile urechilor sunt flăcări mov: o limbă mare curbată în afară și două mai mici;
   - în interiorul urechilor e puf crem, ca niște pene.
   Sub haine blana se elimină automat: scriptul aruncă raze din piele și verifică ce acoperă accesoriile.
4. **Accesoriile**:
   - ochelari de aviator cu lentile albastre luminoase, nituri și curele pe cap;
   - eșarfă roșie cu pliuri și colț pe piept;
   - medalion-busolă cu stea luminoasă;
   - vestă de piele cu nituri, epoleți, centură cu cataramă aurie și borsetă;
   - curea peste piept;
   - brățări cu hexagon turcoaz și cristal;
   - rucsac mov moale (corp, clapă, buzunar), cu două curele cu catarame aurii, emblemă și mâner;
   - pe lateral: hartă rulată mare, hartă desfăcută cu roza vânturilor, felinar albastru și cristal verde.
5. **Fața** are ochi cu iris în gradient, pupilă și reflexii, gene groase cu „cat-eye”, nas, gură cu colți și limbă, mustăți. Expresiile se aleg cu `--expr`; ele schimbă pleoapele, sprâncenele, forma gurii și pupilele. Expresia `content` (gura închisă, zâmbind) se folosește pentru profilul din planșă.
6. **Lumina** imită planșa: fundal alb cu umbră, iar luminile se rotesc odată cu camera, deci fiecare vedere e luminată din față. Marcajele luminoase au bază albastru închis și emisie turcoaz, ca să rămână saturate. La final se aplică bloom pe ele.

## Rulare
```bash
python -m venv bvenv && ./bvenv/bin/pip install bpy==5.1.2 scikit-image pillow
./bvenv/bin/python orion_build.py --out out --render sheet,face,hero     # planșa + față + 3/4
./bvenv/bin/python orion_expresii.py --out out                         # planșa de expresii
# test rapid: --res 0.012 --fur 60000 --samples 16 --size 600 --no-blend --no-glb
```
Parametri:
- `--res`: finețea corpului;
- `--fur`: numărul de fire;
- `--samples`, `--size`: calitatea și mărimea randării;
- `--expr`: `happy`, `surprised`, `laugh`, `determined`, `angry`, `wink` sau `content`;
- `--side-expr`: expresia profilului din planșă (implicit `content`);
- `--render`: `sheet`, `face`, `hero`, `expr`; vederi de verificare: `front`, `ears`, `prof`, `pack`, `glow`, `facecmp`;
- `--stage body`: doar corpul, pentru verificarea rapidă a proporțiilor;
- `--light`, `--view`: lumina și transformarea de culoare.

## Ajustări rapide
- **Proporții**: fiecare formă din secțiunea `# 1. SDF body` are centru și raze.
  - urechile: `EAR_B`, `EAR_U`, `EAR_F`, `EAR_RB` (raza părții rotunde), `EAR_LEN` (până la vârf), `EAR_CURL`;
  - botul: `MUZ_DY`;
  - coada: `TAIL_C`, `TAIL_U`, `tail_spiral`;
  - ochii: `EYE_X`, `EYE_Z`, `EYE_S`.
- **Culorile** sunt constantele `C_*` din `# 2. colours`, iar materialele accesoriilor sunt `M_*`.
- **Blana** pe zone se reglează în `fur_params()`, iar flăcările urechilor în blocul „purple flame tips” din `build_fur()`.
- **Fiecare accesoriu** are funcția lui: `build_goggles`, `build_scarf`, `build_vest`, `build_backpack`…

## Pașii următori recomandați
- **Rig și animații**: Rigify sau Mixamo pe `Orion_Body`, cu accesoriile legate de oase. Blana se leagă prin *Surface* = `Orion_Body`. Expresiile pot deveni shape keys pe pleoape și sprâncene, iar gura se poate face ca înlocuire de mesh.
- **Pentru joc**: în `orion_game.glb` blana lipsește. Pentru aspect de blană pe telefon, se coace (bake) blana în texturi (Color + Normal + AO) pe un mesh retopologizat, plus 6–8 straturi de *shell fur* în Three.js.
- **Costume și skin-uri** (Pirat, Viking, Mag, Ametist, Aqua, Rubin): se schimbă constantele `C_*` și materialele `M_*`, iar costumele se adaugă ca funcții `build_*` noi.

## Modelul din Tripo (pentru joc)
`tripo/orion_tripo.glb` este modelul generat în Tripo Studio după planșă: un singur mesh texturat (188 de mii de triunghiuri, texturi 2048 px). Scriptul `tripo_prep.py` îl pregătește pentru joc.

Ce face scriptul:
1. Întoarce modelul cu fața spre cameră (în Tripo stătea rotit cu ~15°), îl așază cu tălpile pe sol și îl aduce la 1,2 m.
2. Face marcajele luminoase să emită lumină: spirala de pe coadă, stelele, cristalele, felinarul, lentilele și busola. Masca de emisie e calculată din textura de culoare (turcoaz și albastru saturat). Ochii sunt excluși.
3. Recolorează în mov materialul rucsacului, care în Tripo ieșise vișiniu. Curelele maro și eșarfa roșie rămân neschimbate. Recolorarea se oprește cu `--no-pack-purple`.
4. Păstrează metalul doar pe piesele de metal. Harta din Tripo făcea blana pe jumătate metalică și deci mai închisă la culoare.
5. Corectează privirea. Tripo pictase ambele irisuri trase spre nas, iar personajul părea că se uită încrucișat. Scriptul face următoarele:
   - găsește deschiderea fiecărui ochi din culorile pictate;
   - desenează un iris nou, centrat, cu pupilă și două reflexii;
   - pune ochii într-o textură separată (`orion_eyes`, 1024×512, de ~6 ori mai detaliată decât textura din Tripo), cu material propriu (`Orion_Tripo_Eyes`) pe fețele din jurul ochilor;
   - corectează ochii și în textura principală, ca rezervă.

   Corectura se oprește cu `--no-eye-fix`.
6. Exportă `orion_tripo_game.glb`: 1,2 m, 188 de mii de triunghiuri, cu texturi JPG compatibile cu Three.js r128 din `buble.html`. A trecut de validatorul glTF fără erori. Varianta redusă pentru telefon (`--lod 40000`) nu se mai face implicit, pentru că strica aspectul: blană zimțată, ochelari cu muchii, texturi întinse. Godot face singur variante mai ușoare pentru distanță.
7. Randează aceeași planșă ca modelul procedural: `tripo_sheet.png`, `tripo_face.png`, iar vederile transparente în `transparent/`.

Rezultatele sunt în `out_tripo/`.

```bash
./bvenv/bin/python tripo_prep.py --src tripo/orion_tripo.glb --out out_tripo --render sheet,face
```
Parametri: `--face-yaw` (rotația, implicit -15), `--glow` (intensitatea emisiei în randări), `--no-eye-fix`, `--no-pack-purple`, `--size`, `--samples`, `--lod N` (o variantă redusă la N triunghiuri, de calitate mai slabă; implicit nu se face).

**În joc:** în `buble.html`, din panoul „🧩 Modele 3D”, la mascotă, încarci `out_tripo/orion_tripo_game.glb`. Același model e și în proiectul Godot din `godot/`.

**Animație:** modelul e un singur mesh, fără oase. Pentru mers și sărit se poate face rig automat în Mixamo (corp umanoid). Coada și urechile au nevoie de oase adăugate în Blender.

**Licență:** verifică în planul tău Tripo dacă modelul poate fi folosit comercial.

## Insula 1 (pentru joc)
`tripo/insula1_tripo.glb` este insula generată în Tripo Studio după desenul cu castelul. Are un singur mesh, 196 de mii de triunghiuri și texturi de 2048 px. Scriptul `island_prep.py` o pregătește pentru joc.

Ce face scriptul:
1. **Găsește căsuțele drumului.** Desenează insula văzută de sus, cu culorile texturii, și caută discurile rotunde, plate și bej. A găsit 22. Două erau parțial ascunse, una sub un copac și una mai palidă, și sunt adăugate doar dacă umplu un gol din drum. Căsuțele sunt ordonate în buclă: START e căsuța din fața castelului, iar drumul merge spre dreapta, în jurul castelului.
2. **Scalează insula.** Distanța dintre două căsuțe vecine devine 1,9 m, iar o căsuță are ~1,5 m, cât să încapă Orion (1,2 m). Insula are astfel cam 19 × 23 × 13 m. START ajunge în origine, la înălțimea 0, iar drumul e centrat.
3. **Repară materialul:**
   - metal doar pe piesele de metal;
   - apă lucioasă;
   - lumină pe flăcările felinarelor, ferestre și portal.
4. **Exportă:**
   - `insula1.glb`: texturi JPG, trecut de validatorul glTF fără erori;
   - `insula1_casute.json` și `insula1_casute.gd`: pozițiile căsuțelor în metri, cu X spre dreapta, Y în sus și Z spre cameră, adică coordonatele din Godot și Three.js.
5. **Randează:**
   - `insula1_harta_numerotat.png`: harta drumului, cu căsuțele numerotate;
   - `insula1_vedere.png`: vedere 3/4;
   - `insula1_orion_start.png`: Orion pe START, pentru scară.

```bash
./bvenv/bin/python island_prep.py --src tripo/insula1_tripo.glb --out out_insula1 --name insula1 \
    --orion out_tripo/orion_tripo_game.glb --render map,hero,orion
```
Parametri:
- `--spacing`: distanța dintre căsuțe, implicit 1,9 m;
- `--yaw`: rotește insula, dacă fața nu e spre cameră;
- `--orion`: GLB-ul lui Orion, pus pe START în randări;
- `--render`: `map`, `hero`, `orion`;
- `--size`, `--samples`: mărimea și calitatea randărilor;
- `--glow`: intensitatea luminii în randări.

Pentru insulele următoare se schimbă doar `--src` și `--name`. Dacă drumul are altă formă sau alte culori, pragurile de detecție din `find_tiles()` se pot regla.

## Insula 1, îmbunătățită (`insula1/`)
Pornește de la insula pregătită mai sus (`out_insula1/insula1.glb`). Nu o reface, ci o îmbunătățește. Rezultatul merge direct în proiectul Godot. Detalii și cifre sunt în `docs/insula1_imbunatatita.md`.

| Script | Ce face |
|---|---|
| `insula1/upscale.py` | mărește textura originală de 4 ori cu Real-ESRGAN (ncnn, pe procesor), pe bucăți care se suprapun, ca să nu apară cusături |
| `insula1/imbunatateste.py` | separă apa (râul, laguna, iazurile) și cascadele din mesh, le dă UV-uri pentru curgere și culori de vârf pentru shaderul de apă, găsește portalul, pune textura mărită (4096 px) cu culori mai vii și masca de lumină; exportă `godot/assets/models/insula1/insula1.glb` și `godot/insula1/data/insula1_info.gd` |
| `insula1/texturi.py` | texturile mici de atmosferă: valurile apei, norul, raza de soare |
| `insula1/previzualizare.py` | randări „vechi” / „nou” cu aceleași cadre ca jocul (`--model`, `--frames`, `--aterizare`) |
| `insula1/compara.py` | imaginile de comparație din `docs/shots/` |

```bash
./bvenv/bin/python insula1/upscale.py textura_2048.png textura_8192.png modele/realesrgan-x4plus-anime
./bvenv/bin/python insula1/imbunatateste.py -- --textura textura_8192.png
./bvenv/bin/python insula1/previzualizare.py -- --model nou && ./bvenv/bin/python insula1/compara.py
```

`imbunatateste.py --fara-coacere` face doar clasificarea apei și a portalului. E util pentru verificări rapide.

Modelele Real-ESRGAN (`*.param`, `*.bin`) vin din arhiva oficială `realesrgan-ncnn-vulkan-20220424-ubuntu.zip`, versiunea v0.2.5.0, cu licența BSD-3-Clause. Nu sunt incluse în proiect.

## Insula 1, v4 (`insula1/`)
Inelul 1 (tot ce e la ≤ 8 m de drum) e refăcut procedural, fără credite; insula veche rămâne pentru clădiri, apă și
faleze. Raportul: `docs/insula_v4.md`.

| Script | Ce face |
|---|---|
| `insula1/v3_faza_a.py` | Faza A (v3), cu simplificarea mutată înaintea tăierii pe clase (fără fante); scrie `out_insula1/insula1_faza_a.glb` (intermediar, ignorat de git) |
| `insula1/v4_inel1.py` | harta de înălțimi (0,25 m) din insula veche, solul și clădirile recunoscute, terenul nou (`teren.glb`), tăierea a ce se înlocuiește, clădirile ca piese, pozițiile recuzitei și ale presăratelor (`godot/insula1/data/inel1.gd`), harta de verificare |
| `insula1/v4_recuzita.py` | recuzita nouă (copaci, tufe, iarbă, floare, pietricică, gard, felinar, butoi, ladă, cristale), cu AO coaptă |
| `insula1/texturi_teren.py` | texturile terenului, 1024 px pe 2 m (512 px/m) |
| `insula1/insulite.py` | insulițele din fundal, netede, cu normale verificate |
| `insula1/decupaje_v4.py` | decupajele clădirilor din imaginea-țintă, pentru generarea imagine→3D (OpenCV) |
| `insula1/previzualizare_v4.py` | randările de verificare (camera de joc, aproape, panoramă, aterizare, `--checker`) |
| `insula1/previzualizare_recuzita.py`, `insula1/compara_v4.py` | foaia recuzitei și imaginile de comparație |

```bash
./bvenv/bin/python insula1/v3_faza_a.py -- --fara-imagini
./bvenv/bin/python insula1/v4_recuzita.py && ./bvenv/bin/python insula1/texturi_teren.py
./bvenv/bin/python insula1/v4_inel1.py
./bvenv/bin/python insula1/previzualizare_v4.py -- --frames joc,aproape,panorama
```

