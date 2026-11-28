# Etapa 4.3 — Claritatea resurselor, interfață și rafinări vizuale

Numai prezentare și unelte DEBUG. Economia, traseul de 36 de căsuțe, regulile zarurilor, nivelurile clădirilor, probabilitățile și formatul salvării (v7) nu s-au schimbat.

## Bug-ul „nu primesc puncte de construcție”: investigație
Raportul a fost verificat cu cod și teste (`tools/check_construction.gd`), nu presupus.

**Ce funcționează corect (confirmat):** la aterizarea pe o căsuță cu ciocan, `board_save.gd::roll()` adaugă în wallet +2 / +3 / +4 / +5 puncte la nivelurile 0–3 ale Atelierului lui Pongo, în aceeași tranzacție cu aruncarea. Valorile sunt salvate și reîncărcate, iar upgrade-ul deduce costul exact. Un restart în timpul mersului nu dublează premiul. Calculul economic **nu** avea defect.

**Cauzele reale, toate în prezentare și în panoul DEBUG:**
1. **Nu exista niciun indicator permanent.** Soldul apărea doar în Sac, iar la aterizare se vedea un cip temporar „Puncte · N” lângă Sac. Câștigurile mici (2–5 puncte) erau ușor de ratat.
2. **Efectul demonstrativ „Puncte” din panoul DEBUG** (pagina „Efecte vizuale”) afișa „+5 puncte de construcție” și un cip „Puncte · 0” (soldul era transmis ca 0), fără să modifice nimic. Arăta ca un câștig real urmat de un sold zero.
3. **Confirmarea din panoul DEBUG era ștearsă imediat.** `result()` scria „Profil DEBUG actualizat.”, apoi `refresh_data()` o înlocuia în același cadru cu linia de stare. După Setează sau Zero nu se vedea nicio confirmare.
4. **Câmpul numeric `SpinBox` folosea ultima valoare confirmată:** cifrele tastate fără Enter nu erau aplicate. Am verificat în Godot 4.7.2 că `value` rămâne vechi până la `apply()`.
5. **Butonul „Adaugă” exista doar pentru monede.**

**Reparații:**
- indicator permanent cu ciocan în HUD, cu valoarea ascunsă până la aterizare, ca la celelalte resurse;
- indicator animat „+X puncte de construcție” pornit de schimbarea reală a soldului;
- demonstrațiile din DEBUG sunt marcate „Demonstrație · soldul nu se schimbă” și nu mai declanșează contoare;
- pagina Resurse are Setează / Adaugă / Zero pentru toate resursele, „Sold actual” și o confirmare persistentă („✔ Puncte de construcție: setat la 777 · sold 24 → 777 · salvat în profilul DEBUG”), respectiv „✖ …” la refuz;
- cifrele tastate fără Enter sunt aplicate.

## Ce s-a schimbat
| Zonă | Fișiere | Ce face |
|---|---|---|
| Bara de sus | `board_hud.gd`, `assets/crystal/bag.svg` | 4 contoare (monede, cristale, energie, puncte de construcție) + Sac ca pictogramă; fără suprapuneri sau text tăiat la 720×1080–1080×1920; peste 99 999 valorile sunt prescurtate prin trunchiere (123,4k, 999,9M), iar valoarea exactă rămâne în numele accesibil |
| Fereastra „Puncte de construcție” | `build_points_screen.gd` | sold, ciocan mare, utilizare, costuri pe nivel, surse (numărul de căsuțe citit din traseu), recompensa după nivelul Atelierului și cea următoare, mențiunea bonusului global; intrare și ieșire animate, închidere prin buton sau atingere în afară; se actualizează la orice schimbare de sold |
| Panou de upgrade (toate cele 6 clădiri) | `board_hud.gd`, `board_economy.gd` | nume, Nivel N → N+1, bonus actual și după upgrade, „Monede: 2108 / 3000 — insuficient”, „Construcție: 1000 / 25 — suficient”, mesaj exact („Îți lipsesc 892 de monede.”, „… și 1 punct de construcție.”), MAXIM + bonus final fără buton; mențiunea că bonusul se aplică tuturor căsuțelor din categorie |
| Feedback recompense | `board_hud.gd` | insignă cu pictogramă sub contor pentru orice câștig real, așezată sub rândul de butoane, ca să nu fie acoperită |
| Developer Panel | `developer_panel.gd`, `board_game.gd` | vezi mai sus |
| Lumină | `board.tscn`, `board_ambient.gd`, `polish.gd` | soare mai cald (0,68 → 0,80), umbre mai clare (opacitate 0,39 → 0,52), mai puțină ceață (0,0044 → 0,0024) și mai puțină lumină ambientală (0,49 → 0,41); contrast și saturație echilibrate |
| Lerik | `lerik_animator.gd`, `board_game.gd` | trecere lină de 0,22 s între repaus, așteptare și alergare; înclinare în curbe filtrată; arcuri cu sub-pași fixe (mișcare secundară independentă de FPS); intrarea și ieșirea clipurilor proporționale cu durata; viraj pe traseu amortizat și limitat la 10 rad/s (înainte: până la 0,35 rad într-un singur cadru); întoarcerea spre cameră la oprire durează 0,42 s, nu 0,24 s |
| Zaruri | `die_face.gd` | comprimare scurtă la fiecare contact cu solul; la oprire, scara e uniformă și fața raportată rămâne cea a tranzacției |
| Cameră | `kingdom_camera.gd` | ritm separat pe cadru (urmărire 6,5, recompensă 5,0, revenire 5,8, în loc de 8 pentru toate); revenirea se încheie fără salt de rotație |
| Cristal central | `crystal_glow.gd` | respirație luminoasă discretă și când e gol (oprită la „Efecte vizuale reduse”) |
| Atingere | `board_hud.gd`, `event_screen.gd` | butoanele Super Cristal, eveniment și revendicare au acum minimum 56 px |

## Ce nu s-a schimbat
- Cuferele, ruleta și Super Cristalul: prezentările din Etapa 4.2 au fost verificate prin teste (fără dublarea premiilor la întrerupere, premii identice), dar nu am modificat timing-ul lor.
- Apa, copacii, fumul și păsările au rămas cum erau; s-a schimbat doar lumina care cade pe ele.

## Limitări
- **Fără schelet:** Lerik, Pongo și Pufi rămân rig-uri din piese rigide, fără deformare, genunchi sau coate. Rafinările sunt procedurale.
- **Mediu de testare:** am testat fără GPU și fără telefon. Capturile sunt făcute cu randare software, deci nu am măsurat FPS pe dispozitiv.
- **Mărimi de text:** nu am refăcut sistematic scala de text (sunt 17 mărimi folosite). Componentele noi folosesc scara existentă: 16–21 pentru text, 26–34 pentru titluri, 46 pentru cifra principală.

## Teste
`tools/check_construction.gd` (240 de verificări) + cele 13 suite existente, toate trecute. Comandă:
```sh
XDG_DATA_HOME=$(mktemp -d) godot --headless --fixed-fps 60 --script tools/check_construction.gd
```
În `check_board_rewards.gd`, cinci verificări citesc acum câmpurile noi ale panoului de upgrade (bonus actual / următor, costuri, MAXIM) în loc de blocul de text vechi. Intenția fiecărei verificări a rămas aceeași.

Mutațiile sunt detectate: valoarea dezvăluită prea devreme în HUD, cifrele tastate fără Enter ignorate, indicatorul acoperit de butoane.

## Checklist pe telefon
1. Bara de sus: patru contoare și Sacul, nimic tăiat. Atingerea ciocanului deschide fereastra, iar „Închide” și atingerea în afară o închid.
2. Aterizează pe o căsuță cu ciocan: contorul crește doar la aterizare, apare „+X puncte de construcție”, iar Sacul arată același sold.
3. Atinge fiecare clădire: verifică nivelurile, bonusurile, rândurile disponibil / necesar, mesajul de lipsă și ecranul MAXIM.
4. Fă un upgrade: ambele contoare scad cu costul exact.
5. În ⚒ → DEBUG → Resurse: Setează, Adaugă și Zero pe „Puncte de construcție”. Confirmarea rămâne vizibilă, iar HUD-ul se schimbă. Revino la profilul normal și verifică dacă soldul normal a rămas neatins.
6. Repornește aplicația în timpul mersului: punctele apar o singură dată.
7. Urmărește trecerile lui Lerik (zaruri → alergare → aterizare) și revenirea camerei: fără salturi.
8. Verifică lizibilitatea luminii în exterior și FPS-ul pe Redus / Mediu / Ridicat.
