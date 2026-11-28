# Etapa 4.2 — Audit tehnic și artistic (Faza A)

Audit făcut pe codul de la commitul `2aaf2d5` (Etapa 4.0), checkpoint `checkpoint-before-etapa-4-2`. Capturi „înainte” făcute cu același script ca cele „după” (`docs/PREDARE.md`).

## Configurație efectivă
- Godot 4.7.2, `renderer/rendering_method = gl_compatibility` (și pe mobil), MSAA 3D 2× doar pe calitatea Ridicată, umbre direcționale 2048 (1024 mobil), scara 3D 0,70 / 0,86 / 1,0, 30 FPS pe Redus.
- Disponibile în Compatibility: tonemap, ajustări, glow, CPUParticles, MultiMesh, shadere spatial simple, SubViewport. Indisponibile/nerecomandate: SDFGI, SSAO, SSR, volumetric fog, GPUParticles cu atractori.
- Mediul de lucru: fără Blender, fără GPU (randare software llvmpipe), fără acces la biblioteci de asset-uri. Există însă un pipeline propriu, reproductibil, de generare GLB în Python (`tools/build_art.py`, `build_board_art.py`) și unul de sinteză audio (`tools/build_board_audio.py`).

## 1. Ce există și funcționează
| Zonă | Implementare | Notă |
|---|---|---|
| Zaruri | `ground_dice.gd` + `die_face.gd`: rostogolire scriptată spre fața confirmată, 3 sărituri, umbre de contact, `dice_impacts.gd` (16 mote la 2 impacturi) | rezultatul vine din tranzacție, corect |
| Cameră | `kingdom_camera.gd`: OVERVIEW / DICE / TRACK / LAND / RETURN / CRYSTAL, netezire exponențială a poziției și a pitch-ului | nordul fixat (fără yaw) |
| Lerik | `lerik.glb` (6 piese rigide: Trunchi, Cap, 2 brațe, 2 picioare), `lerik_pose.gd` cu `pose(stride, crouch, cheer, glance)` și `idle()` | fără schelet, fără clipuri |
| Recompense | `polish.gd` (inel, praf, emote), `reward_burst.gd` (coroană 2D), `fly_prize` spre HUD, pop contoare | aceeași explozie pentru toate categoriile, cu altă culoare |
| Cristal | `crystal_glow.gd` (emisie, halo, mote, puls), zoom de cameră, inel | activarea = zoom + fade |
| Ruletă | `magic_wheel.gd` + `wheel_screen.gd`, 2D, felii proporționale | bun; tranziția hartă→ruletă este un fade |
| Cufere/cărți | `chest_art.gd` (vector 2D), `card_view.gd` (2D, întoarcere prin `scale.x`) | provizoriu |
| Ambient | licurici, praf, frunze, scântei, steaguri, moară, jeturi | vegetația și clădirile sunt statice |
| Audio | 9 WAV sintetizate + 24 de evenimente cu fallback | multe evenimente sună identic (tic ruletă = clic buton) |

## 2. Implementat, dar slab
- **Lerik se mișcă în „țopăieli” de iepure** pe fiecare căsuță (arc identic), fără ritm de alergare, fără înclinare în curbă, fără mișcare secundară (rucsac, urechi). Nu clipește. Nu privește zarurile.
- **Zarurile** nu lasă praf pe sol la fiecare săritură, nu au urmă magică, impactul nu se propagă vizual pe sol, oprirea nu e marcată; camera nu reacționează la impact.
- **Camera** se întoarce la vedere generală după 0,42 s de la aterizare, înainte ca premiul să fie „citit”; nu anticipează direcția; nu evită clădirile (doar înălțimea o salvează).
- **Recompense**: căsuța pulsează, dar premiul nu „apare” lângă Lerik ca obiect; START și premiile de eveniment nu au efect propriu; „Tur nou” și premiul se suprapun în aceeași zonă.
- **Activarea cristalului** nu are concentrare de energie sau tranziție proprie spre ruletă.
- **Cuferele** sunt desene 2D; deschiderea e aceeași coregrafie cu alte culori.
- **Cărțile** se întorc doar prin comprimare orizontală, fără perspectivă și fără dezvăluire progresivă.

## 3. Animații pur procedurale
Toate: Lerik (sinusoide pe piese rigide), zarurile (curbe scriptate), steaguri, moară, cristal, UI. Nu există `AnimationPlayer`, clipuri sau schelet în proiect.

## 4. Modele și materiale provizorii
- Cufere și ilustrațiile cărților: vector din cod (marcat).
- Pongo și Pufi: **nu există pe hartă** (doar pictograme SVG pentru portretele V2, nefolosite în V3).
- Lerik: model low-poly propriu, cu rucsacul, ochelarii și ochii lipiți de trunchi/cap — nu se pot anima separat.

## 5. Tranziții rigide sau incoerente
- Hartă → ruletă și hartă → cufăr: fade simplu.
- Aterizare → vedere generală: revenire prea rapidă.
- Mesajele de premiu și de tur nou concurează în aceeași zonă.

## 6. Îmbunătățiri mari cu cost mic
- Separarea pieselor lui Lerik (rucsac, ochelari, ochi, urechi, coadă, eșarfă) în generatorul existent → mișcare secundară cu arcuri amortizate și clipire, la cost zero de randare.
- Coregrafie de zaruri cu praf și unde pe sol prin CPUParticles scurte și inele reutilizate.
- Cameră cu yaw limitat, anticipare, puls la impact și ținere pe premiu.
- Pongo și Pufi ca modele low-poly în același pipeline, folosite contextual și rar.
- Cufere 3D generate în același pipeline, randate într-un SubViewport doar cât ecranul e deschis.
- Sunete noi sintetizate (tic de ruletă, deschidere de cufăr, carte rară, puls de cristal…) în generatorul audio existent.

## 7. Limitări tehnice
- Fără Blender și fără schelet: animațiile scheletice reale nu pot fi produse aici. Soluția este un **rig din piese rigide** (pivoturi pe articulații) cu un controler de animație în straturi și clipuri cu chei (date), compatibil cu înlocuirea ulterioară printr-un model cu schelet.
- Fără GPU: FPS-ul nu poate fi măsurat pentru telefon; se măsoară doar costuri relative în randare software.
- Fără biblioteci de sunete sau artă: tot ce e nou este generat procedural, original.

## Plan (faze cu commit separat)
- **B** Lerik (model segmentat + animator), coregrafia zarurilor, regizorul de cameră.
- **C** Activarea cristalului, ruleta, cufere 3D și ceremonia cufărului de aur.
- **D** Regatul viu (vânt în vegetație, fum, ferestre, castel), Pongo și Pufi.
- **E** UI unificat, cărți cu întoarcere în perspectivă, audio nou.
- **F** Momente „WOW”, niveluri de calitate, panou DEBUG, teste, documentație.
