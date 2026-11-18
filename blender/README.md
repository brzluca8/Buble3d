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
5. Exportă:
   - `orion_tripo_game.glb`: modelul complet;
   - `orion_tripo_mobile.glb`: aceleași texturi, redus la 40 de mii de triunghiuri pentru telefon.

   Ambele sunt la 1,2 m, cu texturi JPG compatibile cu Three.js r128 din `buble.html`. Au trecut de validatorul glTF fără erori.
6. Randează aceeași planșă ca modelul procedural: `tripo_sheet.png`, `tripo_mobile_sheet.png`, `tripo_face.png`, iar vederile transparente în `transparent/`.

Rezultatele sunt în `out_tripo/`.

```bash
./bvenv/bin/python tripo_prep.py --src tripo/orion_tripo.glb --out out_tripo --render sheet,face,lodsheet
```
Parametri: `--face-yaw` (rotația, implicit -15), `--lod` (triunghiuri pentru telefon, implicit 40000), `--glow` (intensitatea emisiei în randări), `--no-pack-purple`, `--size`, `--samples`.

**În joc:** în `buble.html`, din panoul „🧩 Modele 3D”, la mascotă, încarci `out_tripo/orion_tripo_mobile.glb`.

**Animație:** modelul e un singur mesh, fără oase. Pentru mers și sărit se poate face rig automat în Mixamo (corp umanoid). Coada și urechile au nevoie de oase adăugate în Blender.

**Licență:** verifică în planul tău Tripo dacă modelul poate fi folosit comercial.
