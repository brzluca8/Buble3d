LERION V2 – REGATUL TRĂSNIȚILOR
Godot 4 · Android portret · GL Compatibility

PRIMA SESIUNE
Deschide project.godot în Godot 4, așteaptă importul și rulează proiectul cu F5.
Pe harta continentală, atinge parcela din stânga fântânii. Vezi numele Atelierul
lui Pongo, aspectul următorului nivel și prețul. Apasă Construiește. Soldul inițial
de test este 1.000 de monede și 10 ciocane, suficient pentru orice primă clădire.
Poți selecta ulterior atât clădirea, cât și parcela de sub ea.

Apasă ACTIVEAZĂ pentru trei simboluri, proiectate din cristal timp de 1,25 s.
Sari animația încheie efectul imediat. Sub hartă apar combinația și câștigul.
Sacul din dreapta sus afișează monedele, fragmentele, ciocanele și biletele.
Pan cu un deget și pinch pentru zoom. Pe desktop poți folosi glisarea și rotița.

REGULILE PROTOTIPULUI
• Fiecare dintre cele trei extrageri este independentă. Șansele sunt 36% monedă,
  24% ciocan, 16% cristal, 12% cufăr, 8% provocare și 4% haos.
• Recompensele de bază se adună. Se acordă maximum un bonus: triplă, combinația
  monedă + ciocan + cufăr în orice ordine sau pereche. Premiile variabile pentru
  cufăr și haos sunt extrase înainte de începerea animației.
• O activare consumă o energie. Capacitatea este 100, iar o unitate se regenerează
  la 5 minute, inclusiv în timpul absenței. Calculul folosește ceasul telefonului.
• La 30/30 poți păstra încărcarea sau poți apăsa Armează. Următoarea activare
  armată dublează monedele și ciocanele, inclusiv bonusul combinației, apoi
  adaugă un cufăr de 100–200 monede. Bara revine la zero.
• Nivelurile 1, 2 și 3 costă, pe rând, 1.000/10, 3.000/25 și 8.000/45
  monede/ciocane. Toate parcelele sunt disponibile de la început.
• Configurația activă se află în CONFIG_PROTOTIP.json. Pentru deciziile încă
  deschise, am ales un sold de start pentru prima construcție și două bonusuri
  posibile pentru tripla haos: 400 monede + 4 fragmente sau 5 ciocane +
  8 fragmente, cu șanse egale. Echilibrul economiei este provizoriu.
• Salvarea versionată alternează între user://satul_trasnitilor.0.json și .1.json.
  Energia, cele trei simboluri, premiul și progresul Super se confirmă împreună
  pe disc. La pornire se alege cea mai nouă generație validă. Dacă ambele salvări
  lipsesc sau sunt invalide, se aplică soldul inițial. Ștergerea datelor aplicației
  elimină progresul. Testele automate scriu în fișiere proprii.

CLĂDIRI ȘI ARTĂ
De sus în jos, pe perechi: Mina de Cristale și Moara Trăsnită, Atelierul lui Pongo
și Laboratorul lui Pufi, Piața Poznașă și Hanul Aventurierilor. Fiecare dispune
de trei stadii vizuale și de un detaliu animat la nivelul 3. Referințele se află
în REFERINTE/. Cele șase GLB-uri sunt modele originale de prototip cu pivot la bază
și piese Base, Upgrade2, Upgrade3 și Accent. Pozițiile accentelor sunt în village.gd.
Pentru regenerarea exclusivă a clădirilor rulează python3 tools/build_village.py.
Castelul, fântâna, terenul, vegetația și geometria celor șase parcele provin din V1.
Personajele folosesc portrete vectoriale provizorii și animații scurte de interfață.
Pongo ridică ciocanul la construcții, Pufi suflă magie, iar Lerik reacționează la
combinații. Modelele rigged, vocile și animațiile de personaj 3D sunt etape viitoare.

TESTARE PE TELEFON
1. Dezarhivează ZIP-ul într-un director în care poți scrie. În Godot Editor pentru
   Android, alege Import, selectează project.godot și pornește jocul în portret.
   Versiunea verificată pe Linux este Godot 4.7.2 stabil.
2. Construiește atelierul, apoi încearcă o a doua clădire fără resurse suficiente.
   Activează cristalul, apasă rapid de două ori și verifică o singură energie consumată.
3. Într-o versiune de dezvoltare, Sac > Unelte de test permite adăugarea resurselor
   și umplerea barei Super. Alege trei simboluri și apasă Fixează următoarele simboluri.
   Încearcă pereche, triplă și monedă + ciocan + cufăr. Verifică apoi Super armat.
   Sumele din cufere rămân aleatorii. Uneltele sunt ascunse în versiunea release.
4. Construiește cele șase clădiri până la nivelul 3. Verifică zoomul, selecția prin
   atingere și lizibilitatea HUD-ului pe telefon, inclusiv în zona decupajului.
5. Minimizează jocul în animație, revino, apoi închide și redeschide aplicația.
   Compară energia, soldul, nivelurile și ultimul rezultat. Pentru regenerare,
   consumă energie și revino după cel puțin cinci minute.

APK DEBUG DIN EDITORUL DESKTOP
Instalează șabloanele de export pentru versiunea exactă de Godot, OpenJDK 17 și
Android SDK cu platforma și Build Tools indicate de acea versiune. Configurează
căile Java SDK și Android SDK în Editor Settings > Export > Android. În Project >
Export selectează Android, bifează Export With Debug și salvează APK-ul într-un
director existent. Conectează telefonul prin USB, autorizează depanarea și rulează:

    adb devices
    adb install -r Lerion-V2-debug.apk

Pachetul de test este com.lerion.regat (ARMv7 și ARM64). Ghidul de configurare:
https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html

VERIFICĂRI EXECUTATE
Proiectul de bază și testul hărții au fost rulate înainte de modificări. Checkpoint
Git local checkpoint-harta-aprobata-v1, commit ad6dcf6. Dezvoltarea V2 este pe
ramura cristal-haotic-v2. Comenzi reproductibile din directorul cu project.godot:

    godot --headless --editor --import
    godot --headless --quit-after 120
    godot --headless --script tools/check_map.gd
    godot --headless --script tools/check_crystal.gd
    godot --headless --script tools/check_village_flow.gd

• Godot 4.7.2 pe Linux. Harta a trecut selecția celor 6 parcele și gesturile în
  3 formate portret. Scena a fost randată la 720×1280 cu GL Compatibility/Mesa.
• Economia: 70 verificări, 0 erori. Simularea cu seed fix a rulat 100.000 de
  activări. Din 300.000 de simboluri au rezultat 108.297 monede, 72.058 ciocane,
  47.738 cristale, 35.902 cufere, 23.946 provocări și 12.059 haos.
• Fluxul scenei: 47 verificări, 0 erori. Selecție, confirmare, variantele modelelor,
  butoane și touch simulat, Super, skip, revenire/redimensionare, întrerupere în
  timpul efectului și restaurarea modelelor după redeschidere.
• Pachetul de resurse al presetului Android a fost pornit separat pe Linux. Au fost
  încărcate cele șase modele și s-a executat o activare. Vechiul model de insulă
  și imaginile de referință sunt excluse din pachetul jocului.
• În mediul de test lipsesc Android SDK Build Tools și telefonul fizic. Nu s-a
  generat un APK și nu s-au măsurat FPS, memorie, autonomie sau latență pe Android.
  Driverul grafic virtual a avertizat că nu poate schimba modul V-Sync.

FIȘIERE DE DEZVOLTARE V2
• project.godot, export_presets.cfg, scenes/main.tscn, scenes/map_hud.tscn,
  scripts/main.gd și scripts/map_camera.gd — integrare incrementală în jocul existent.
• CONFIG_PROTOTIP.json și scripts/crystal/{rewards,progress,map_hud,projection}.gd
  — reguli, tranzacții locale, interfață și efectul de proiecție.
• assets/village/{mine,mill,workshop,lab,market,inn}.glb, scripts/village.gd,
  tools/build_village.py — modele, niveluri, selecție și animații.
• assets/crystal/*.svg — simboluri, energie, portrete și metadate de import Godot.
• tools/{check_map,check_crystal,check_village_flow}.gd — verificările reproductibile.
• AGENTS.md, documentele și referințele din transferul V2, README_RO.txt și
  CITESTE_MAI_INTAI.txt — direcție, instrucțiuni și rezultate de test.
