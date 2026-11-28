> Înlocuit în Etapa 3.0 de Ruleta Magică. Vezi [docs/ETAPA_3_0_SUPER_CRISTAL.md](docs/ETAPA_3_0_SUPER_CRISTAL.md).

# Cristalul din centru devine mecanism de bonus secundar
## Încărcare
- +1 progres pentru fiecare aruncare validă cu două zaruri, până la maximum `30/30`; nu contează suma zarurilor sau poziția pe hartă.
- Jucătorul poate lăsa cristalul la `30/30` și să aleagă când activează bonusul. Nu se resetează doar pentru că a depășit pragul.
- Când îl activează, starea trece în `active`, `charges_remaining=3`, apoi `charge=0`. Apăsarea repetată pe activare nu oferă charge-uri noi și nu consumă suplimentar.

## Super Cristal – V3
- **Următoarele 3 aterizări** pe tile-ul final după un roll primesc **x2 la recompensele acelei aterizări** (după bonusul clădirii). Nu dublează START, nu recompensele pentru căsuțe doar traversate și nu costul energiei.
- La fiecare aterizare validă: `charges_remaining -=1`. După 0, efectul dispare; încărcarea poate fi începută iar. Pentru MVP recomand să nu se încarce în paralel în timp ce efectul este activ (mai clar, fără stacking).
- Dacă roll-ul cade pe tile fără recompensă (`START` doar), consumă tot o aterizare; acest comportament trebuie indicat în UI sau schimbat în urma testelor.
- Dacă jocul se închide în mijlocul efectului, salvăm câte aterizări active mai sunt; nu se repetă premiile la reluare.
- Efecte vizuale limitate (glow discret, particule rare) și UI `Super Cristal 2/3`.

## Valori configurabile
- `charge_target = 30`, `roll_charge = 1`, `landing_multiplier = 2`, `landing_count = 3`.
- **Evită multiplicarea infinită / nesting-ul cu efecte viitoare**; fără stacking în V3.
