> Actualizare Etapa 2.8 — bonusurile clădirilor se aplică global pe categorie. Distribuția și regulile curente sunt în [ETAPA_2_8.md](docs/ETAPA_2_8.md). Descrierile zonelor locale de mai jos aparțin etapelor anterioare.

# Decizii aprobate pentru LERION V3 – 24 noiembrie 2026
## Direcție
- Se testează în prim-plan **varianta cu 2 zaruri + Lerik pe traseu**. Cristalul Haotic cu 3 simboluri a fost **prototipul precedent**; îl putem păstra în branch/feature flag, nu îl combinăm cu V3.
- Imaginea de referință preferată: `REFERINTE/01_HARTA_PREFERATA_TRASEU.png`, care arată 6 platforme depărtate și un drum șerpuit, în culori cartoon 3D. **Corecție obligatorie față de orice imagine**: drumul trebuie să fie închis matematic și să treacă numai PE LÂNGĂ clădiri.
- Să fie mai distractiv decât versiunea cu recompense automate; personaje comice, reacții foarte scurte la evenimente rare.

## Elemente fixe
- Teren verde CONTINENTAL, fără pereți de insulă; coline/păduri la orizont, cameră orientată spre castel.
- Castel cu acoperiș albastru existent în spate; cristal/fântână centrale permanente.
- ȘASE platforme de clădiri, distanțate mai mult pentru a încăpea drumul; trei în stânga, trei în dreapta.
- CLĂDIRI: stânga sus Mina; dreapta sus Moara; stânga mijloc Atelier Pongo; dreapta mijloc Laborator Pufi; stânga jos Piața; dreapta jos Hanul.
- Personaje: Lerik=râs aventurier biped cu ochelari/rucsac; Pongo=constructor verde (niciodată Bubu); Pufi=dragon mov simpatic.
- Buget discutat 500–1.000 € total de dezvoltare + promovare; fără asset-uri plătite sau cloud cu costuri implicite fără aprobare.

## Bucla de joc V3
- Apeși **ARUNCĂ**, 2 zaruri 1–6; Lerik avansează cu suma lor pe loop.
- La căsuța de oprire primește premiul acelei căsuțe, ajustat cu bonusul clădirii aferente.
- Trecerea peste START acordă bonus de tură; numai o dată per traversare, chiar dacă aterizezi fix pe START.
- Progresul clădirilor îmbunătățește recompensele din 2–3 căsuțe vecine și arată vizual mai bine.
- Fiecare aruncare încarcă cristalul central, până la prag; la alegerea jucătorului, bonus temporar x2 la 3 aterizări.
- Îmbunătățești clădirile, completezi regatul; salvare și posibilitatea de a vedea regate precedente = plan viitor, nu MVP.

## Ce nu e definitiv încă
- Economia și numerele precise (36 căsuțe, premii, multiplicatori, 30 aruncări pentru cristal): **valori recomandate pentru primul test**, ușor configurabile, nu au fost validate cu jucători.
- Numărul exact de animații, tipurile secundare de căsuțe și valoarea bonusului START se pot ajusta după prototip.
