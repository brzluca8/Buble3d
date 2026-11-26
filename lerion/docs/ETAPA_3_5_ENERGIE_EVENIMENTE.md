# Etapa 3.5 — Reechilibrarea energiei, evenimente și Developer Panel extins

Această etapă înlocuiește regulile de energie din `ETAPA_2_8.md` (căsuțele de energie) și din documentele V3 anterioare (regenerare la 5 minute). Super Cristalul și Ruleta Magică (Etapa 3.0) sunt neschimbate; ele sunt singura sursă permanentă de energie-premiu, alături de evenimente.

## 1. Audit: de unde venea energia aproape infinită

| Sursă / consum | Înainte | Acum |
|---|---|---|
| Cost aruncare | 1 | 1 (configurabil, `rules.tres`) |
| Căsuțe de energie | 6 din 35 (≈ 17% din aterizări), +2/+3/+4/+5 după nivelul Morii | **0** |
| Regenerare | +1 la 5 minute (12/oră) | +1 la **10 minute** (6/oră) |
| Ruletă Magică | +10/+20/+30, 56% din rotiri, la 50 apoi 100 de aruncări | neschimbat |
| Evenimente | inexistente | Festivalul lui Pufi: până la 170 energie / 48 h (221 cu Moara nivel 3) |

Valoarea așteptată a căsuțelor de energie era 0,34 energie pe aruncare la Moara 0 și ≈ 0,86 la Moara 3. Cu regenerarea, costul net al unei aruncări scădea spre zero: energie practic nelimitată. Acum nicio aterizare nu mai creditează energie.

Estimare de ritm (valori de proiectare, nevalidate cu jucători):
- numai regenerare: 144 aruncări / zi;
- cu ruleta (≈ 0,094 energie pe aruncare în ciclurile de 100): ≈ 159 / zi;
- plus un festival complet la 48 h (170–221 energie): ≈ +85…110 / zi.

## 2. Distribuția căsuțelor (36, START la 0)

Cele 6 poziții de energie (2, 11, 15, 22, 27, 31) au fost redistribuite. Restul indicilor nu s-a modificat; geometria traseului nu a fost atinsă.

| Categorie | Indici | Număr |
|---|---|---:|
| START | 0 | 1 |
| Monede | 1, 7, **11**, 13, 19, 26, 32 | 7 |
| Cristale | **2**, 4, 8, 14, 20, 29, 33 | 7 |
| Construcție | 5, 9, 16, 21, 24, **27**, 34 | 7 |
| Magie | 6, 10, 18, 23, 28, **31**, 35 | 7 |
| Jetoane | 3, 12, **15**, 17, **22**, 25, 30 | 7 |

(Indicii cu aldine sunt cei mutați.) Două căsuțe vecine nu au niciodată același tip, inclusiv 35 → 0, deci nu pot exista nici trei consecutive. Tipurile rămân în `assets/board/economy.tres` (`tile_types`). Bonusurile globale ale clădirilor funcționează ca înainte; Piața acoperă acum 7 căsuțe (nu 6).

## 3. Moara Trăsnită

Moara nu mai deține căsuțe (`building_categories.right_top = "event_energy"`). Rolul ei: **procent din energia primită ca recompensă de eveniment**, aplicat la revendicare.

| Nivel Moară | Bonus energie din evenimente | Energie totală în Festivalul lui Pufi |
|---:|---:|---:|
| 0 | +0% | 170 |
| 1 | +10% | 187 |
| 2 | +20% | 204 |
| 3 | +30% | 221 |

Bonusul nu se aplică cuferelor, ruletei sau căsuțelor și nu poate crea energie în afara evenimentelor: câștigul maxim este limitat de pragurile evenimentului (finit, în timp). Valorile sunt în `CONFIG/events.json` (`mill_event_energy_bonus_percent`) și sunt provizorii; efectul cumulat la 221 energie / 48 h reprezintă ≈ +51 energie față de nivelul 0 și trebuie reevaluat după testare. Chitanța de revendicare păstrează suma de bază, procentul și suma finală.

## 4. Regenerarea energiei

Reguli în `scripts/economy/energy_service.gd` (funcții pure, cu `now` ca parametru), valori în `assets/board/rules.tres`:

- capacitate normală 100, cost 1, `regeneration_seconds = 600`, `regen_amount = 1`, plafon tehnic de premii 9999;
- sub 100: pași întregi de 600 s, restul se păstrează (`tick` avansează cu pașii consumați);
- la 100 sau peste: regenerarea este suspendată; cronometrul repornește la prima cheltuială;
- după repornire, energia se calculează din `tick` salvat și timpul curent (idempotent, fără rotunjiri).

**Protecție la schimbarea orei (prototip offline):** se salvează cel mai recent timp văzut (`clock_mark`). Un ceas dat înapoi nu regenerează și nu mută cronometrul înapoi. Un ceas dat înainte NU poate fi detectat offline; efectul este limitat de plafonul de 100 și de faptul că timpul avansat rămâne avansat (nu se poate repeta mutând ceasul înapoi). **În versiunea online, timpul, energia, premiile și revendicările trebuie validate de server.**

## 5. Evenimente

Configurare: `CONFIG/events.json`. Primul eveniment: „Festivalul lui Pufi”, 48 h, `autostart: false` (pornit din Developer Panel; schimbi în `true` pentru lansare automată la prima deschidere).

- Puncte numai la **aterizare**: Cristale +2, Construcție +3, Magie +5, în plus față de premiul căsuței. Trecerea peste căsuță, START, monedele și jetoanele nu dau puncte.
- Praguri provizorii: 50 → +20 energie, 150 → +50 energie, 350 → cufăr de lemn, 700 → +100 energie, 1200 → cufăr de argint.
- Faze: `active` (puncte + revendicări) → `claiming` (12 h, `claim_grace_hours`, numai revendicări) → `closed` (arhivat în `event_history`, maximum 10).
- Revendicarea este o tranzacție: identificatorul pragului și recompensa se salvează împreună; a doua revendicare este refuzată, inclusiv după repornire.
- Interfață originală (violet și turcoaz): `scripts/crystal/event_screen.gd`. Conține numele, timpul rămas, bara cu praguri, categoriile care dau puncte, următoarea recompensă, butoane „Revendică”, bonusul Morii. Butonul din HUD pulsează când există o recompensă gata.

## 6. Arhitectură pentru server

| Responsabilitate | Fișier | Dependențe |
|---|---|---|
| Calcul recompense căsuțe | `board_economy.gd` (`award`, `amount`) | resursa economică |
| Energie | `economy/energy_service.gd` | niciuna (pure) |
| Evenimente | `economy/event_service.gd` | configurație |
| Ruletă | `crystal/super_crystal_service.gd` | configurație |
| Stocare | `board_save.gd` (tranzacții `roll`, `spin_wheel`, `claim_event_reward`) | serviciile de mai sus |
| Interfață | `board_hud.gd`, `event_screen.gd`, `wheel_screen.gd` | citesc starea, cer tranzacții |

Un server poate rula aceleași funcții și returna aceleași chitanțe; clientul înlocuiește doar apelurile din `board_save.gd`. Singurul loc care citește ceasul dispozitivului este `BoardSave.clock()`.

## 7. Salvare v6

Câmpuri noi: `event`, `event_history`, `clock_mark`; `last_roll.event_points` opțional. Salvările v3–v5 se încarcă fără rescriere (valori neutre în memorie); prima tranzacție scrie v6. O versiune mai veche a jocului nu va citi v6.

## 8. Teste

```sh
XDG_DATA_HOME=/tmp/lerion-ee godot --headless --fixed-fps 60 --script tools/check_energy_events.gd
```
Suita acoperă: absența energiei pe traseu, cele 36 de căsuțe, regenerarea la 600 s (inclusiv repornire și ceas dat înapoi), energia peste 100, punctele doar la aterizare, revendicarea unică, bonusul Morii, perioada de revendicare, salvare/migrare v5, compatibilitatea cu ruleta, funcțiile DEBUG și izolarea profilului, fluxul din scenă.
