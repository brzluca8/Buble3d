# Developer Panel

Panoul folosește scena separată `scenes/DeveloperPanel.tscn` și apare numai când `OS.is_debug_build()` este adevărat și setarea `lerion/developer_panel` este activată. Godot pornit din editor folosește această condiție DEBUG.

## Folosire

1. Pornește buildul DEBUG sau scena board.tscn din editor. Apasă butonul ⚒ din dreapta, imediat sub solduri.
2. Apasă „Intră în profilul de dezvoltare”. Aplicația încarcă o scenă cu progresul local de test și butonul „⚒ D”. Profilul pornește cu resursele inițiale configurate, separat de partida existentă.
3. Alege secțiunea din lista derulantă. Controalele numerice acceptă tastatura numerică și săgețile. Panourile lungi se derulează vertical. Butonul Închide rămâne în partea de sus.
4. Folosește „Înapoi la progresul normal” pentru revenirea la partida anterioară. La repornirea aplicației se deschide progresul normal. Reintrarea în profilul DEBUG reia salvarea sa.

Panoul se deschide după terminarea aruncării. Editările resurselor și nivelurilor refuză operațiile în timpul mersului. Schimbarea profilului așteaptă și încheierea sau anularea unei simulări.

## Comenzi implementate

- Monede — setează, adaugă, zero.
- Fragmente, energie, puncte de construcție și jetoane de aventură — setează și zero. Energia profilului este limitată la 100.
- Energie peste plafon — test separat pe o copie în memorie. Pornește cu 101–10000 energie și simulează perechea 1 + 1 de pe START, cu aterizare pe energie. Raportează energia inițială, finală și chitanța. O valoare de 150 devine 149, cu premiu efectiv zero. Profilul persistent rămâne intact.
- Zaruri — pregătește fiecare valoare 1–6 pentru o singură aruncare sau revine la aleatoriu. Perechea se consumă numai după salvarea reușită. La restart se revine la aleatoriu.
- Traseu — mutare la orice indice 0–35 fără premiu și fără tură nouă. Teste dedicate pentru 34 + 5 și 34 + 2 folosesc butonul normal de aruncare și aceeași tranzacție.
- Viteză — 1×, 3× sau instantaneu pentru anticiparea zarurilor și mers. Modul instantaneu folosește finalizarea existentă, comună cu Grăbește. Setarea este locală sesiunii.
- Clădiri — nivel 0–3 pentru fiecare clădire, actualizarea imediată a modelului și a bonusurilor globale. Panoul afișează premiile celor patru niveluri. „Testează upgrade-ul cu cost” folosește achiziția normală, inclusiv costul și efectul vizual. Resursele necesare se acordă din secțiunea Resurse.
- Salvări — salvare manuală, reîncărcare, checkpoint de test și restaurarea lui. Resetarea cere confirmare și afectează exclusiv profilul DEBUG.
- Diagnostic — starea completă, istoricul ultimelor 30 de aruncări cu chitanțe și solduri, plus export JSON cu ultima simulare.

## Izolare și salvare

Fișierele profilului sunt `user://lerion_developer/profile_board_v3.0.json` și `profile_board_v3.1.json`. Mecanismul existent scrie alternativ, prin fișier temporar și redenumire. Profilul folosește schema economică existentă și adaugă numai câmpurile locale de diagnostic `debug_history` și `debug_future`.

Checkpointul este `user://lerion_developer/checkpoint.json`. Exportul este `user://lerion_developer/diagnostic.json`. Mesajul după export arată calea efectivă pe dispozitiv. Pe desktop, folderul se deschide prin Project → Open User Data Folder. Pe Android, fișierul este în spațiul privat al aplicației și poate fi extras dintr-un build debuggable cu Android SDK, de exemplu prin `adb shell run-as com.lerion.regat`.

Fiecare scriere din profilul dezvoltator verifică DEBUG, configurarea și prefixul local fix. Redirecționarea către un prefix normal este refuzată. Operațiile folosesc salvări locale, fără apeluri de rețea sau API-uri de inventar. O integrare viitoare cu serverul trebuie să păstreze această implementare locală și separată.

## Simulări

Se pot rula 100, 1000 sau 10000 de aruncări. Două copii în memorie pornesc din starea de test, cu aceeași sămânță 2801. Prima folosește nivelurile curente, a doua nivelul 0 pentru toate clădirile. Ambele folosesc metoda normală de aruncare, calculul central al premiului și bonusul START.

Energia se reumple cu 100 doar când ajunge la zero. Raportul numără separat energia introdusă de simulator. Această alegere permite rularea întregului lot și păstrează plafonarea premiilor de energie.

Raportul conține numărul efectiv de aruncări, opririle pe categorii, recompensele pe resurse, energia consumată și câștigată, energia introdusă, traversările START și monedele de tură. Valorile `rewards` și `baseline_rewards` compară nivelurile curente cu nivelul 0. Lotul cedează controlul interfeței la fiecare 50 de aruncări și poate fi oprit.

## Funcții rezervate

Super Cristalul, ruleta, cuferele, cărțile și albumul încă nu au mecanici implementate în proiect.

În `scripts/developer/future_features.json` sunt pregătite pragurile 50 și 100, împreună cu identificatorii premiilor energie, lemn, argint și aur. Panoul poate salva încărcarea 0–100, tipul activării, premiul propus și starea pregătită în `debug_future`. Acestea sunt parametri de integrare, fără creditare de inventar sau progres al Super Cristalului. Butoanele de ruletă, cufere și album sunt dezactivate și afișează „indisponibil”.

## Export

Presetul Android produce buildul DEBUG de test. Pentru livrarea publică folosește presetul **Android Release** și configurează cheia proprie de semnare. Acest preset exclude `scripts/developer/*` și `scenes/DeveloperPanel.tscn`. Verificarea `OS.is_debug_build()` oprește și crearea panoului în orice runtime RELEASE.

APK-ul DEBUG livrat folosește aceeași cheie locală de debug ca livrările anterioare. Păstrarea progresului la instalarea peste alt APK necesită aceeași semnătură. Nu dezinstala aplicația cu progres valoros pentru a rezolva o nepotrivire de semnătură.

## Verificări executate

Checkpointul anterior implementării este `checkpoint-before-developer-panel`, la d9fccaf.

- Cele șapte suite existente au trecut înainte și după modificări, împreună cu pornirea scenei.
- Testul dezvoltator a trecut 119 verificări și acoperă resurse, forțarea zarurilor, reîncercarea după scriere eșuată, START, viteza 3× și instantanee, toate nivelurile, restaurare, reîncărcare, simulări de 100/1000/10000, resetarea cu confirmare și integritatea salvărilor normale.
- Layoutul celor șase pagini a fost verificat la 720×1280, 720×1600 și 768×1024. Au fost folosite evenimente InputEventScreenTouch pentru deschiderea și închiderea panoului.
- Capturile sunt randate efectiv în Godot cu panoul deschis.
- Pachetul Android Release de control a fost inspectat și nu conține resursele de dezvoltator.
- Un executabil Linux cu șablonul oficial RELEASE 4.7.2 a confirmat DEBUG fals, absența panoului și o aruncare normală finalizată fără schimbări suplimentare ale soldului.
- APK-ul DEBUG a trecut verificarea apksigner și zipalign la 16 KiB.

Testele automate se rulează într-un director de date temporar separat, deoarece creează și resetează propriul profil DEBUG.

```sh
XDG_DATA_HOME=/tmp/lerion-dev-tests godot --headless --fixed-fps 60 --script tools/check_developer.gd
```

Testarea pe telefon fizic, tastatura Android, zonele sigure reale și extragerea diagnosticului de pe telefon rămân de verificat pe dispozitiv. APK-ul RELEASE de control a fost exportat fără semnare într-o copie temporară, exclusiv pentru verificarea conținutului.
