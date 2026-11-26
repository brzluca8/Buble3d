# Prima lume: SATUL TRĂSNIȚILOR — șase clădiri

## Compoziție fixă
- **Castelul deja există** de la prima intrare; NU se construiește în cele 6 sloturi. Poate primi upgrade vizual DUPĂ completarea regatului, în etapă viitoare.
- **Fântâna/Cristalul Haotic** există și e centrul mecanicii principale, NU slot construibil.
- Exact 6 parcele, 3 la stânga, 3 la dreapta castelului/cristalului. Pozițiile sunt cele din scena curentă, NU reconstruim harta de la zero.
- Sloturile pot accepta modele GLB independente, câte o rădăcină Node3D per clădire; crește nivelul, nu se schimbă amplasamentul.

## Lista și amplasarea propusă
| Poziție | Nume oficial | Imagine cartoon nivel 1 | Utilitate pe termen lung |
|---|---|---|---|
| Stânga sus | **Mina de Cristale** | mică intrare de mină, cadru lemn, pietre și cristale cyan | fragmente/bonusuri |
| Dreapta sus | **Moara Trăsnită** | moară mică, crem, acoperiș portocaliu/roșu, 4 pale galbene | provizii/expediții viitoare |
| Stânga mijloc | **Atelierul lui Pongo** | căsuță mică, pereți crem, acoperiș roșu, ciocan supradimensionat, coș | construcții; prima clădire recomandată |
| Dreapta mijloc | **Laboratorul lui Pufi** | căsuță rotundă, acoperiș mov, cazan mic/lumină | magie/bonusuri viitoare |
| Stânga jos | **Piața Poznașă** | tarabă lemn, copertină dungi roșu/alb, câteva lăzi | schimburi/oferte viitoare |
| Dreapta jos | **Hanul Aventurierilor** | căsuță lemn/piatră, acoperiș albastru, ușă mare și firmă | misiuni/social viitor |

**Atenție:** numele corect este PONGO; nu folosi „Atelierul lui Bubu”.

## Trei stadii vizuale pentru fiecare clădire
- **Nivel 0:** platformă goală marcată +.
- **Nivel 1:** mică, curată, simpatică, forme mari, maximum 2–3 culori principale.
- **Nivel 2:** extindere compactă, decorațiuni, ferestre, semn/unealtă specifică.
- **Nivel 3:** piesă suplimentară, banner/coș/pale/cazan luminat și un efect animat mic, distinct.

Nu este necesar să generăm 18 clădiri întregi. Preferă `BaseMesh + UpgradePart_L2 + UpgradePart_L3` sau variații accesibile, pentru un total mic de geometrie.

## Costuri V1 de TEST (per clădire, configurabile)
| Upgrade | Monede | Puncte de construcție |
|---|---:|---:|
| 0 -> 1 | 1000 | 10 |
| 1 -> 2 | 3000 | 25 |
| 2 -> 3 | 8000 | 45 |

Pongo este prima clădire pe care vrem s-o demonstrăm în tutorial. Celelalte pot avea același sistem; **nu impune un arbore de blocări complexe** fără aprobare. Adaugă un comutator debug pentru a testa oricând upgrade-urile.

## Animații comice minimale
- Pongo apare când se construiește, ridică ciocanul, face o mică gafă și sărbătorește (folosește placeholder/sprite dacă personajul nu are animații 3D).
- Pufi declanșează un mic puf de magie la laborator sau combo special, nu la fiecare rundă.
- Lerik salută sau reacționează ocazional; să nu încetinească mecanica de 1–1,5 secunde.
- Nu programa șase sisteme economice complicate; **o economie comună de resurse** este suficientă în V1.

## Finalul regatului (încă NU implementa)
După nivelul 3 la toate cele 6 clădiri, jucătorul va putea debloca o altă temă de regat și reveni la cele vechi. Păstrează datele pregătite pentru multiple regate, fără să construiești acum conținutul viitor.
