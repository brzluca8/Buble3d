# Etapa 4.2 — Premium visual & animation overhaul

Numai prezentare. Economia, probabilitățile, zarurile, recompensele, salvările, traseul și amplasarea clădirilor nu s-au schimbat. Un test rulează aceeași aruncare cu toate efectele pornite și oprite și compară starea: identică. Auditul de pornire este în [`ETAPA_4_2_AUDIT.md`](ETAPA_4_2_AUDIT.md).

## Direcția artistică aplicată
Regatul rămâne cel aprobat; ierarhia vizuală este: lumea calmă și lizibilă în repaus, momentele importante (aterizare, cristal plin, ruletă, cufăr de aur) spectaculoase și scurte. Accente turcoaz și auriu pentru magie și recompense, violet pentru Pufi, verde pentru Pongo. Fiecare personaj are reacții comice scurte, rare, care nu întârzie următoarea aruncare.

## Ce s-a schimbat (pe componente)

| Componentă | Fișier | Ce face |
|---|---|---|
| Modele noi și segmentate | `tools/build_characters.py` → `assets/board/lerik.glb`, `pongo.glb`, `pufi.glb`, `chest_*.glb` | Lerik împărțit în 14 piese (urechi, ochi, ochelari, rucsac, coadă, capăt de eșarfă); Pongo și Pufi noi; trei cufere 3D cu capac separat, lacăt, interior luminos |
| Rig din piese rigide | `scripts/board/part_rig.gd`, `lerik_pose.gd`, `cameo_rig.gd` | `apply(pose)` cu articulații numite; fără schelet |
| Character Animation Controller | `scripts/board/lerik_animator.gd` | stări Repaus / Privește zarurile / Aleargă; clipuri cu chei (date); arcuri amortizate pentru rucsac, urechi, coadă, eșarfă; clipire |
| Dice Presentation | `ground_dice.gd`, `polish.gd`, `board_game.gd` | urmă de sclipiri, inel și praf la fiecare contact, impuls de cameră, marcaj auriu la oprire, Lerik reacționează la sumă |
| Camera Director | `kingdom_camera.gd` | 5 cadre (Overview, Dice, Follow, Reward, Return) + Crystal; rotire limitată în direcția mersului; ridicare automată când o clădire acoperă personajul; reward focus ținut 0,75 s; setare „Mișcare cameră” Completă / Ușoară / Fixă |
| Reward VFX | `polish.gd`, `board_hud.gd` | inel în culoarea categoriei, pictograma resursei deasupra lui Lerik, pop-up cu pictogramă, contoare cu pop și „+N” |
| Chest Presentation | `scripts/crystal/chest_stage.gd` | cufăr 3D real într-un SubViewport, coregrafie diferită pe tip; același cufăr în rezultatul ruletei |
| Environment Animation | `scripts/board/environment_life.gd`, `assets/fx/*.gdshader` | briză pe coroane și iarbă, apă animată, fum din coșuri, bule la laborator, felinare, scântei la atelier, făină la moară, păsări peste castel |
| Cameo-uri | `scripts/board/cameo.gd` | Pongo și Pufi apar contextual, joacă un clip, emit evenimente, dispar singuri |
| Tranziție | `scripts/crystal/facet_transition.gd`, `assets/fx/facet_transition.gdshader` | fațete de cristal spre ruletă |
| UI | `card_view.gd`, `cards_screen.gd`, `ui_kit.gd`, `board_hud.gd`, `map_hud.gd` | cărți cu întoarcere în perspectivă și dezvăluire progresivă, ornamente pe raritate, contur pentru carte nouă, selecție cu detalii; intrare unificată a panourilor; cifre îngroșate |
| Audio Event Manager | `board_audio.gd`, `tools/build_fx_audio.py` | 20 de sunete originale sintetizate, interval minim și variație de ton pe sunet, 4 voci |
| Developer Panel | `developer_panel.gd` | pagina „Animații și momente” |

## Animații noi și îmbunătățite
- **Lerik:** respirație și privire; gesturi de repaus aleatorii după 5–13 s (privește în jur, trage ochelarii peste ochi, își potrivește rucsacul, se întinde cu ochii închiși); postură de așteptare cu ochii pe zaruri; reacție la sumă (≥10 „wow”, ≤3 nedumerire, altfel aprobare); alergare cu pași sincronizați cu distanța (fără alunecare vizibilă), aplecare în față și înclinare în curbe; săritură pe ultima căsuță (pregătire, desprindere, zbor cu picioarele strânse); aterizare cu comprimare și revenire; bucurie mare cu rotire completă pentru premii rare; aplauze scurte la trecerea prin START; reacții comice (dublu 1: nedumerire; dublu 6: surpriză; uneori pierde echilibrul și și-l recapătă).
- **Mișcare secundară:** rucsacul, urechile, coada și eșarfa reacționează la accelerația reală a corpului (arcuri amortizate, limitate).
- **Pongo:** la fiecare upgrade apare lângă clădire, lovește de două ori, a treia lovitură e prea tare (scântei, o scândură sare în aer), țopăie pe un picior, apoi se bucură și dispare.
- **Pufi:** uneori (30%) la aterizarea pe magie zboară lângă Lerik, inspiră, strănută bule colorate, e aruncat înapoi, face o tumbă; Lerik sare speriat.
- **Cufere:** lemn (balans, săritură, capac aruncat cu rebound), argint (plutește, se rotește complet, capacul se deschide magic, vârtej de sclipiri), aur (vezi momentul 3).
- **Cărți:** ridicare, întoarcere în adâncime, dezvăluire a ilustrației de sus în jos (mai lentă la rare), aură și sclipire la rare.

## Cele trei momente „WOW”
1. **Trezirea regatului** — când Super Cristalul se umple (după aterizare): un val de lumină pornește din fântână și aprinde pe rând toate cele 36 de căsuțe, fiecare clădire sare când valul o atinge, steagurile prind o rafală, Pufi face un cerc în jurul cristalului și strănută magie în el, Lerik spune „wow”. Apoi cristalul se rotește, emite inele și afișează „ATINGE!”.
2. **Scufundarea în cristal** — la activare: camera se apropie, energia este trasă din jur în cristal, un val dublu pleacă din fântână, apoi ecranul este acoperit de fațete de cristal care se sparg în ordinea distanței și dezvăluie ruleta. Ruleta este deja deschisă în spate, deci starea și intrările rămân consecvente.
3. **Ceremonia cufărului de aur** — trei nestemate se aprind pe rând cu ton urcător, cufărul tremură tot mai tare, lacătul sare, capacul se deschide brusc, o coloană de lumină aurie și o ploaie de monede 3D; cărțile urmează.

## Calitate și performanță
- Low: fără vânt, păsări, fum și scântei de atelier, fără MSAA în cufere, bule și particule reduse; Medium și High păstrează tot, cu bugetele din Etapa 4.0. „Efecte vizuale reduse” oprește ambientul, cameo-urile, tranziția și gesturile de repaus; „Mișcare cameră: Fixă” păstrează vederea generală.
- **Măsurat** aici (randare software llvmpipe fără GPU, 720×1280, calitate Medie, aceeași scenă și aceeași aruncare, `--rendering-driver opengl3`): Etapa 4.0 vs 4.2 — repaus 72–74 vs 75–76 ms/cadru; aruncare + mers 68–73 vs 73–77; ecranul cufărului de aur 83 vs 87. Cost relativ ≈ +3–7%. **Nu este FPS de telefon**; pe dispozitiv trebuie măsurat.
- Cost estimat pe telefon: arcurile, rig-ul și clipurile sunt calcule CPU mici (14 transformări pe cadru); vântul este un shader de vârf ieftin; SubViewport-ul cuferelor există doar cât ecranul e deschis.

## Limitări și asset-uri necesare
- **Fără schelet:** Lerik, Pongo și Pufi sunt rig-uri din piese rigide; nu există deformare, genunchi sau coate. Pentru animație profesională este nevoie de modele cu schelet (Blender) care păstrează numele pieselor; clipurile din `lerik_animator.gd` și `cameo.gd` pot servi drept referință de timing.
- **Modele:** Pongo, Pufi și cuferele sunt modele low-poly generate procedural, în stilul existent, nu artă finală. Ilustrațiile cărților rămân provizorii (marcate).
- **Audio:** sunetele sunt sintetizate original; un sound designer ar trebui să le înlocuiască prin `event_streams` sau fișierele `fx_*.wav`, fără schimbarea codului.
- **Mediu:** fără GPU și fără telefon; performanța și lizibilitatea trebuie verificate pe dispozitiv.

## Teste
`tools/check_animation.gd` (140 de verificări) + cele 12 suite existente, toate trecute. Comandă:
```sh
XDG_DATA_HOME=$(mktemp -d) godot --headless --fixed-fps 60 --script tools/check_animation.gd
```
Mutații verificate: eliminarea protecției contra dublării cameo-urilor și a privirii spre zaruri sunt detectate.

## Verificare manuală în Godot
1. Deschide `project.godot` (Godot 4.7.2), F5. Așteaptă câteva secunde în repaus: Lerik clipește, privește în jur, uneori își trage ochelarii; copacii se leagănă, fumul iese din coșuri.
2. Apasă ARUNCĂ: Lerik privește zarurile, zarurile lasă urme și inele, Lerik aleargă, sare pe ultima căsuță și aterizează.
3. Panou ⚒ → profil DEBUG → „Animații și momente”: rulează pe rând momentele 1, 2, 3, „Upgrade + Pongo”, „Pufi strănută”, clipurile lui Lerik.
4. Comută „Mișcare cinematică a camerei”, „Sunete”, Low / Medium / High și verifică diferențele.
5. În Sac: „Mișcare cameră” și „Efecte vizuale reduse”.
