> Actualizare Etapa 2.8 — bonusurile clădirilor se aplică global pe categorie. Distribuția și regulile curente sunt în [ETAPA_2_8.md](docs/ETAPA_2_8.md). Descrierile zonelor locale de mai jos aparțin etapelor anterioare.

# Traseul Lerik – geometrie și reguli (MVP)
## 1. Topologie, nu doar aspect
- Un **singur ciclu orientat**, cu 36 tile-uri numerotate `0..35` și `tile[35] -> tile[0]` explicit; fără ramificații, noduri moarte, scurtături sau răscruci care schimbă traseul.
- Traseu sinuos pe suprafața verde; vizual „șerpuiește” printre clădiri, dar **fiecare clădire stă ÎN AFARA suprafeței drumului**, cu spațiu liber între mesh și marginea căsuțelor.
- Pentru prototip: 3 clădiri pe latura stângă și 3 pe dreapta, distribuite de sus până jos. Traseul urcă pe o latură, traversează în spatele zonei de joc (dar NU prin castel) și coboară pe cealaltă, apoi se reconectează în partea de jos. Curbe în S pe fiecare latură; marcaje clare pe căsuțe.
- **Nu porni ramuri separată de la castel / cristal** care să pară parte din traseu. Accesul pietonal decorativ poate exista, dar să fie vizual distinct și să nu fie navigabil pentru Lerik.
- Nu trasează prin fântână/cristal; cristalul rămâne în interiorul circuitului, selectabil separat pentru bonus.
- Din cauza perspectivei 3D, folosește traseu cu `Curve3D`/`Path3D`, plus **lista discretă de poziții tile** și orientările Lerik; pozițiile 3D trebuie să fie reproductibile, nu extrase din screenshot.
- Dacă drumul desenează o intersecție vizuală ambiguă, reproiectează-l. Camera trebuie să permită vederea întregii hărți și un zoom util fără a expune marginile terenului.

## 2. Ordine logică de traversare (exemplu de pornire)
- Indice `0`: START în partea de jos a circuitului.
- `1..5`: latura dreapta-jos, zona **Hanului**.
- `6..11`: dreapta-mijloc, zona **Laboratorului**.
- `12..17`: dreapta-sus, zona **Morii**.
- `18..23`: stânga-sus, zona **Minei**.
- `24..29`: stânga-mijloc, zona **Atelierului Pongo**.
- `30..35`: stânga-jos, zona **Pieței**.
- Drumul închide din `35` în `0`. În fiecare grup sunt 2–3 căsuțe marcate ca `influence_building_id`, restul pot oferi alte premii neutre. Ordinea reală este determinată de geometrie și trebuie validată în scena 3D; nicio clădire nu se poate omite.

## 3. Reguli tile
- Lerik începe pe START (index 0). După roll `steps`, poziția devine `(current_index + steps) % 36`.
- Mutarea traversează exact `steps` poziții consecutive (inclusiv trecerea 35→0), fără salturi sau teleportări.
- Recompensă de tile **numai pentru `landing_tile`**, nu pentru cele traversate. Regula este identică la roll normal, roll accelerat și auto.
- `START` acordă bonus când segmentul de mișcare trece prin indexul 0 (inclusiv când se oprește fix pe 0). Nu acorda bonus doar pentru faptul că jucătorul începe sesiunea pe 0.
- Pentru orice număr de pași valid, `new_index` aparține `[0,35]` și după 36 de pași cumulați de la START s-a traversat startul o singură dată; nu introduce duble premii la animații/reload.
- Rezultatele 2 zaruri au distribuție triunghiulară: 7 apare 6/36, 2 și 12 fiecare 1/36; testează recompensele și pe termen lung, nu doar frecvența căsuțelor.

## 4. Sistem vizual
- Dimensiunea căsuțelor și contrastul simbolurilor trebuie să fie lizibile în portret, iar drumul să nu ocupe tot ecranul.
- Folosește 2–3 tonuri de căsuțe plus accent pentru evenimente; NU copia modelele grafice de la Monopoly GO.
- Render: casuțe mesh-uri simple + decal/icoane 2D/texturi, repetate eficient; noile 36 piese trebuie să fie ușoare pe GPU.
- Lerik: dacă nu există încă model animat, folosește o reprezentare temporară bipedă sau marker și un `AnimationPlayer/Tween` pentru mutare, apoi înlocuiește fără rescrierea logicii.

## 5. Schița inclusă
`REFERINTE/03_SCHEMA_CIRCUIT.svg` prezintă o buclă închisă și poziția clădirilor. Este schematică, fără coordonate în unități Godot. Poziția exactă se adaptează scenei actuale și aspectului preferat din screenshot.
