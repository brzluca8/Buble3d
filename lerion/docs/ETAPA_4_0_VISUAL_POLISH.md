# Etapa 4.0 — Visual polish

Numai prezentare: nicio regulă, probabilitate, economie, salvare, zar, cameră sau geometrie a traseului nu s-a schimbat. Un test rulează 10 aruncări cu efectele pornite și oprite și compară starea: este identică.

## Ce s-a îmbunătățit

| Zonă | Schimbări | Fișiere |
|---|---|---|
| Atmosferă | licurici (8/16/24), praf în lumină (0/10/16), frunze (0/4/6), scântei în jurul cristalului (4/6/8), sclipiri discrete pe clădirile construite, baliză pulsantă la START | `board/polish.gd` |
| Culoare și lumină | grad de culoare ușor (contrast 1,08, saturație 1,12), bloom discret (ecran, prag înalt: afectează doar elemente emisive și aditive), lumină de contur caldă pe clădiri pentru siluetă | `polish.gd`, `board_game.gd` |
| Apă, steaguri, moară | 4/6/8 jeturi la fântână; steaguri cu rafale lente și flutur mai natural; palele morii cu viteză variabilă (unghi acumulat, fără salt) | `board_ambient.gd`, `village.gd` |
| Cristal | puls la fiecare punct de încărcare, explozie când devine gata și la activare | `crystal_glow.gd`, `board_game.gd` |
| Traseu | culoare proprie pe categorie (monede, cristale, construcție, magie, jetoane), contur închis, contur întunecat sub pictograme, baliză START | `loop_path.gd`, `polish.gd` |
| Lerik | umbră mai definită, pată de lumină aurie în timpul mersului, praf la pași, inel + praf + pictogramă care urcă (emote) la aterizare | `board_game.gd`, `polish.gd`, `contact_shadow.gdshader` |
| Ruletă | borduri colorate pe premiu, luciu fix de sticlă, scântei pe felia de aur, felia câștigătoare luminată pulsant, halou care crește cu viteza, inel de lumină și revenire elastică la oprire, indicator mai mare cu oscilație la oprire | `magic_wheel.gd`, `wheel_screen.gd` |
| Câștig | particule diferite pentru energie, lemn, argint, aur; aurul: blitz, raze, a doua explozie, tremur scurt; cardul de rezultat apare cu overshoot; cufărul câștigat este același desen ca la deschidere | `wheel_screen.gd`, `prize_fx.gd` |
| Cufere | trei desene distincte: lemn (scânduri, fier), argint (teșit, luciu care trece, emblemă), aur (nestemate, coroană, aură, sclipiri); apariție cu cădere și praf; deschidere cu lumină și efecte pe tier; cărțile rare au aură și luciu | `chest_art.gd`, `result_art.gd`, `chest_screen.gd`, `card_view.gd` |
| HUD | contoarele pulsează la creștere, cu «+N» care urcă, se scufundă la energie cheltuită; ARUNCĂ cu lumină care trece periodic, contur auriu și umbră; toate butoanele au apăsare cu scufundare/revenire și stare focus; pop-up de câștig cu pictogramă, culoare pe resursă și apariție animată | `board_hud.gd`, `reward_burst.gd` |

## Feedback pe acțiuni

| Acțiune | Efect |
|---|---|
| ARUNCĂ | scufundare buton, scântei, inel sub Lerik |
| Rotirea ruletei | scântei pe buton, halou și inel care cresc cu viteza, tic-uri la indicator |
| Premiu | efect pe tip, pictogramă/cufăr, panou cu overshoot |
| Upgrade clădire | inel auriu, scântei, pop, pulsul contoarelor |
| START | inel + scântei la START, puls monede |
| Aterizare | inel în culoarea categoriei, praf, pictogramă de resursă, flash pe dală |
| Cristal | puls la încărcare, explozie la gata și la activare |
| Resurse în HUD | puls contor, «+N», cometă existentă spre contor |

## Final și provizoriu

- **Final (cod):** grad de culoare, bloom, particule ambientale, inele și praf, HUD, butoane, pop-up-uri, ruletă, efecte de câștig.
- **Provizoriu:** cufere și cărți sunt desenate vectorial din cod, nu modele 3D și nu artă finală; ilustrațiile cărților rămân marcate «PROVIZORIE». Lerik folosește același model, doar cu efecte în jur.
- **Sunet:** structura este gata (`BoardAudio.play_event(nume)`, 24 de evenimente, fiecare cu un sunet existent ca rezervă). Pentru sunete noi se atribuie `event_streams[nume]`; apelurile din cod nu se schimbă.

## Calitate și performanță pe Android

- Trei niveluri (Redus / Mediu / Ridicat) din setările existente; «Efecte vizuale reduse» oprește bloom, ambient, inele, particule, emote, scântei și animațiile de pop.
- Ambientul este format din 5 MultiMesh-uri (5 apeluri de desenare) actualizate la 20–30 Hz; efectele scurte sunt CPUParticles3D unice, limitate (8–22 particule) și inele limitate (2–4 simultane); fără lumini dinamice noi; bloom doar pe Mediu și Ridicat.
- Măsurătoare (randare software llvmpipe, 720×1280, calitate Medie fixată, 3 serii; costuri relative, nu performanța unui telefon): toate efectele oprite ≈ 61–66 ms/cadru; + ambient ≈ +2–5%; + bloom și grad de culoare ≈ +15–20%; toate pornite ≈ +15–20% față de oprite. Efectele speciale nu costă nimic în repaus (apar numai scurt, după evenimente). Costul dominant este bloom-ul (o trecere de post-procesare, legată de fill-rate), care este oprit pe calitatea Redusă și cu «Efecte vizuale reduse». Estimare pe telefon: ambientul este neglijabil (5 apeluri de desenare, sub 70 de quad-uri aditive mici); bloom-ul este singurul element care poate conta pe dispozitive vechi și poate fi oprit din setări sau din Developer Panel.
- Pe telefon trebuie verificat: bloom pe dispozitive mai vechi, fluiditatea ecranului de cufăr și numărul de particule pe calitatea Ridicată.

## Developer Panel (pagina «Efecte vizuale», numai DEBUG)

Comutatoare ambient / speciale / bloom și grad de culoare / scântei HUD; calitate efecte pe sesiune; test ruletă cu premiu ales; test cufăr lemn/argint/aur; test câștig resurse (monede, cristale, energie, puncte; numai vizual); test aterizare (obișnuită și rară), START, upgrade, puls cristal și cristal gata. Starea afișează FPS, efecte active și calitatea.

## Teste

```sh
XDG_DATA_HOME=/tmp/lerion-vis godot --headless --fixed-fps 60 --script tools/check_visual.gd
```
