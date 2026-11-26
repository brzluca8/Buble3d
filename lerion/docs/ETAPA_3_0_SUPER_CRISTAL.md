# Etapa 3.0 — Super Cristalul și Ruleta Magică

Această etapă înlocuiește, la cererea explicită a utilizatorului, regula „Super Cristal 30 aruncări → x2 la 3 aterizări” din `CRISTAL_SUPER_BONUS.md`. Câmpul `super_crystal_remaining_landings` rămâne în salvare cu valoarea 0, pentru compatibilitate; efectul x2 nu este implementat.

## Reguli implementate

- Fiecare aruncare validă (energie debitată și salvată) adaugă +1 la `crystal_charge`.
- Prima rotire: 50 de aruncări. Următoarele: 100 de aruncări (`crystal_activations > 0`).
- Încărcarea se oprește la prag și rămâne acolo până la rotirea efectivă. „Mai târziu” nu consumă nimic.
- Atingerea cristalului (sau a butonului „Super Cristal” din stânga sus) deschide ruleta numai când este încărcat. Altfel se afișează progresul `x/50` sau `x/100`.

Configurația este în `CONFIG/super_crystal.json` (inclusă explicit în ambele presetări de export).

| Premiu | Pondere | Felie pe roată |
|---|---:|---:|
| +10 energie | 28 | 100,8° |
| Cufăr de lemn | 24 | 86,4° |
| +20 energie | 18 | 64,8° |
| Cufăr de argint | 15 | 54° |
| +30 energie | 10 | 36° |
| Cufăr de aur | 5 | 18° |

Unghiul fiecărei felii este proporțional cu ponderea, deci aria vizibilă este exact șansa. Ecranul afișează și procentele.

## Tranzacție și siguranță

- `BoardSave.spin_wheel()` extrage premiul o singură dată și scrie împreună: încărcarea consumată, `crystal_activations + 1`, premiul (energie sau cufăr) și chitanța `last_spin = {id, prize, kind, amount, chest, presented:false}`.
- Animația primește chitanța deja salvată. Roata se oprește exact pe felia premiului.
- Dublul tap: butonul se dezactivează înainte de cerere, iar a doua cerere este refuzată de salvare (cristalul nu mai este încărcat și există o chitanță neconfirmată).
- Închiderea în timpul animației: la redeschidere, `pending_spin()` găsește chitanța neconfirmată și ecranul afișează „Premiu confirmat”, fără a acorda nimic.
- „Continuă” apelează `acknowledge_spin(id)`, care schimbă numai `presented`. A doua apelare este refuzată.
- Poziția lui Lerik, nivelurile, monedele și celelalte solduri nu sunt modificate de rotire.

## Energie specială

- Premiile de energie ale ruletei pot depăși 100 (exemplu: 90 + 30 = 120), cu o limită tehnică de 9999.
- Regenerarea automată este suspendată la 100 sau peste (regula existentă `_regen`).
- Dalele de energie de pe traseu păstrează plafonul: de la 120, o dală de energie acordă 0.

## Salvare v5

- Câmpuri noi: `crystal_activations`, `chests {wood, silver, gold}`, `last_spin`.
- O salvare v4 se încarcă fără rescriere: câmpurile noi primesc valori neutre în memorie, iar prima tranzacție reală scrie v5. Migrarea v3 existentă scrie direct v5.
- Chitanțele cu premii retrase din configurație rămân valide.

## Cufere și pregătirea albumului

Cuferele sunt stocate ca număr pe tip. Configurația conține pentru fiecare tip numărul de cărți și ponderile de raritate (`common/uncommon/rare`), rezervate pentru album. Deschiderea cuferelor, cărțile, albumul și schimburile nu sunt implementate.

## Arhitectură pentru server

`scripts/crystal/super_crystal_service.gd` conține regulile pure (prag, încărcare, extragere ponderată, aplicare, validare), fără noduri și fără fișiere. Un server viitor poate aplica aceleași reguli și returna aceeași chitanță; clientul trebuie doar să înlocuiască `spin_wheel()` cu cererea de rețea. Prezentarea (`wheel_screen.gd`, `magic_wheel.gd`, `prize_fx.gd`, `crystal_glow.gd`) nu decide și nu acordă premii.

## Efecte

- Cristal: emisie progresivă după încărcare, halo billboard, pulsare, 10 particule orbitale (5 la calitate redusă), lumina `Fantana/Sclipire` numai când este încărcat (calitate medie/ridicată), inel la activare.
- Cameră: cadru nou `Shot.CRYSTAL`, revenire cu `return_home()`. Dezactivat la „Efecte vizuale reduse”.
- Roată: accelerare 0,55 s, decelerare cubică 3,75 s, viteză continuă, 5 ture complete, indicator care „sare” la fiecare felie, becuri pe ramă. Atingerea ecranului în timpul rotirii grăbește numai animația.
- Premiu: animații separate pentru energie (contor), lemn (cădere cu ricoșeu), argint (rotire și stele), aur (flash, raze, confeti).

## Teste

```sh
XDG_DATA_HOME=/tmp/lerion-sc godot --headless --fixed-fps 60 --script tools/check_super_crystal.gd
```
