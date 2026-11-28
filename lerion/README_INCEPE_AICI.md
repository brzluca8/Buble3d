# LERION – PACHET CODEX V3: TRASEU ÎN LOOP + DOUĂ ZARURI
> **Istoric (pachetul inițial V3).** Regulile active sunt în `AGENTS.md`; documentele depășite au fost mutate în `docs/istoric/`.
**Data deciziei:** 24.11.2026. **Statut:** specificație pentru noul prototip principal de test, nu joc final sau cod Godot gata de executat.

## Ce trebuie să știe Codex din primul minut
1. **Proiectul curent este harta continentală Godot 4 deja funcțională**, ca în `REFERINTE/02_PROTOTIP_GODOT_ACTUAL.jpg`, cu castel, cristal și cele 6 clădiri. Lucrează în acel repository, NU în prototipurile mai vechi din ZIP-uri cu insule.
2. **Prototipul nou înlocuiește mecanica principală cu trei simboluri din cristal cu două zaruri și Lerik care parcurge un drum închis.** Nu șterge codul funcțional al vechii variante; arhivează-l sau separă-l prin mod, fără a-l executa în modul nou.
3. `REFERINTE/01_HARTA_PREFERATA_TRASEU.png` este **referință ARTISTICĂ**, nu geometrie perfectă. Traseul implementat trebuie să fie **un unic circuit închis real**, fără bifurcații, fără intrare prin clădiri, cu 30–36 căsuțe (pornire V3: 36).
4. Cele 6 clădiri upgradeabile rămân la distanță, câte 3 pe fiecare latură. Castelul (fundal) și cristalul (centru) există de la început, NU sunt din cele 6 parcele.
5. **Fiecare clădire ridică valoarea recompenselor unui grup de 2–3 căsuțe din vecinătate**; doar căsuța pe care Lerik ATERIZEAZĂ dă recompensă, iar trecerea peste START dă bonus de tură.
6. **Cristalul central câștigă +1 energie de încărcare per aruncare**, până la 30/30; jucătorul alege când să declanșeze x2 recompense pentru următoarele **3 aterizări**, nu pentru căsuțe traversate.
7. Nu inventa modele profesionale 3D; păstrează stilul 3D low-poly cartoon curent și optimizează pentru Android portret.

## Conținutul pachetului
- `AGENTS.md` — reguli prioritare noi pentru Codex.
- `LERION_DECIZII_V3.md` — proiectul și distincția V2/V3.
- `TRASEU_LOOP_GEOMETRIE.md` — circuit, ordine, păstrarea căsuțelor și cameră.
- `REGULI_ZARURI_ECONOMIE.md` — două zaruri, energie, START, recompense, construcții.
- `docs/istoric/CLADIRI_ZONE_INFLUENTA.md` — (istoric) 6 clădiri și multiplicatori de test.
- `docs/istoric/CRISTAL_SUPER_BONUS.md` — (istoric) încărcare și activare specială.
- `docs/istoric/PLAN_CODEX_SI_TESTE.md` — (istoric) sarcini incrementale și acceptanță.
- `MIGRARE_FARA_PIERDERI.md` — păstrare progres / evitarea conflictelor cu V2.
- `CONFIG/lerion_board_v3.example.json` — exemplu de configurare, **nu se importă automat în Godot**.
- `REFERINTE/01_HARTA_PREFERATA_TRASEU.png` — imagine furnizată și aleasă de utilizator.
- `REFERINTE/02_PROTOTIP_GODOT_ACTUAL.jpg` — captură a jocului funcțional cu clădiri.
- `REFERINTE/03_SCHEMA_CIRCUIT.svg` — schiță tehnică, intenționat mai simplă decât randarea.
- `docs/istoric/PROMPT_CODEX.md` — (istoric) mesajul gata de copiat.

**Acest ZIP NU include cea mai recentă sursă Godot** — ea există în proiectul/repository-ul utilizatorului. Capturile de ecran nu înlocuiesc fișierele `project.godot` și `*.gd`. Dacă nu ai acces la proiectul real, OPREȘTE-TE și solicită-l.
