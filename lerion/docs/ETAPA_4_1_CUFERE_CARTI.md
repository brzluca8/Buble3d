# Etapa 4.1 — Cufere și cărți colecționabile

Cuferele câștigate la Ruleta Magică (sau adăugate din Developer Panel) se pot deschide. Fiecare deschidere dă cărți salvate în inventar, inclusiv duplicatele. Ruleta, probabilitățile ei, zarurile, camera, traseul și economia nu au fost modificate.

## Cufere

| Cufăr | Cărți | Comune | Neobișnuite | Rare |
|---|---:|---:|---:|---:|
| Lemn | 3 | 80% | 17% | 3% |
| Argint | 4 | 45% | 42% | 13% |
| Aur | 5 | 20% | 45% | 35% |

Ponderile sunt în `CONFIG/cards.json` (`chests.<tip>.rarity_weights`) și sunt valori de proiectare, nevalidate cu jucători. Fiecare carte se extrage independent: întâi raritatea (după ponderi), apoi o carte uniformă din acea raritate. Duplicatele în același cufăr sunt posibile. Nu există garanții (pity) în această etapă.

## Primul album

36 de cărți, 6 colecții a câte 6 (3 comune, 2 neobișnuite, 1 rară fiecare): Aventurile lui Lerik, Atelierul lui Pongo, Magia lui Pufi, Clădirile Regatului, Cristalul și Castelul, Drumul Trăsniților. Fiecare carte are identificator stabil (`c1_01` … `c6_06`), nume, colecție, raritate și `art`.

**Ilustrațiile sunt provizorii.** `art.status = "placeholder"`: cartea se desenează din cod cu pictograme existente (Lerik, Pongo, Pufi, cufăr, monedă, cristal…) și afișează „ILUSTRAȚIE PROVIZORIE”. Pentru arta finală se schimbă `art` (ex. `{"status":"final","texture":"res://..."}`) și `card_view.gd`; identificatorii nu se modifică. Identificatorii fac parte din formatul salvării și nu se refolosesc.

## Salvare v7

Câmpuri noi: `cards {id: exemplare}`, `chests_opened`, `last_open` (chitanța ultimei deschideri: `id`, `chest`, `cards`, `new`, `counts`, `presented`). Salvările v3–v6 se încarcă fără rescriere (valori neutre în memorie); prima tranzacție scrie v7. Cărțile cu id necunoscut (retrase din catalog) rămân valide.

## Tranzacție

`BoardSave.open_chest(kind)`: conținutul se extrage o singură dată, apoi consumul cufărului, toate cărțile și chitanța se scriu într-un singur fișier. Animația primește chitanța deja salvată.

- Dublul tap: butonul se dezactivează înainte de cerere, iar salvarea refuză o a doua deschidere cât timp chitanța nu a fost confirmată.
- Închidere în timpul animației: la repornire, `pending_open()` găsește chitanța neconfirmată și ecranul afișează cărțile confirmate, fără alte modificări; „Continuă” apelează `acknowledge_open(id)` care schimbă numai `presented`.
- Omiterea sau accelerarea schimbă numai prezentarea.

## Pregătire pentru server

`scripts/economy/card_service.gd` are doi pași separați: `draw_contents(rng, tip, raritate_forțată)` (partea aleatoare, care va deveni autoritatea serverului) și `open(stare, tip, ids)` (schimbare deterministă a stării, cu validare: tip, existența cufărului, numărul și existența cărților). Un server poate returna lista de cărți, iar clientul aplică același `open`. Nu există backend în această etapă.

## Interfață

- **Cum deschizi:** Sac → rândul „Cufere” (Lemn / Argint / Aur ×N), sau butonul „Deschide acum” când câștigi un cufăr la ruletă.
- **Animație** (`chest_screen.gd`): cufărul în centru, tremur, capac care se ridică, lumină și particule, cărțile zboară din cufăr și se dezvăluie pe rând cu răsucire. NOUĂ! pe carte nouă, ×N pe duplicate. „Accelerează” (×2,5), „Sari” (arată totul imediat), atingere pentru următoarea carte. „Efecte vizuale reduse” scurtează animația.
- **Inventar** (`cards_screen.gd`, „Cărțile mele” din Sac): cele 6 colecții, exemplare pe carte, cărți nedescoperite ascunse. Nu este albumul complet (fără recompense de colecție, fără schimburi).

## Developer Panel (pagina „Cufere”, numai profilul DEBUG)

Adăugare cufere (+1/+10/+100 pe tip), deschidere reală cu animație, raritate forțată, simulare 10/100/1000 de cufere pe copie izolată (distribuția rarităților observată față de configurată, cărți unice, duplicate, exemplare, progres pe colecții, verificare contabilă și a dublei deschideri), test de salvare și redeschidere (memorie față de disc), test de restart în timpul deschiderii, resetare selectivă „Cărți și deschideri”. Funcțiile nu există în salvarea normală.

## Teste

```sh
XDG_DATA_HOME=/tmp/lerion-cards godot --headless --fixed-fps 60 --script tools/check_cards.gd
```
