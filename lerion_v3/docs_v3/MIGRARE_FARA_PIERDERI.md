# Migrare în proiectul EXISTENT (fără să pierdem jocul deja funcțional)
- **Dacă nu ai repository-ul/proiectul Godot actual, nu face un joc de la zero!** Captura `02_PROTOTIP_GODOT_ACTUAL.jpg` arată harta actuală cu clădiri deja existente; codul acelui proiect trebuie folosit ca bază.
- Creează branch numit orientativ `feature/lerion-loop-dice`; commit/snapshot înainte de schimbări. Nu suprascrie `project.godot`, scene ori saves cu un proiect de demonstrație generat ad-hoc.
- Audit ce date sunt deja în save (monede, cristale, energie, 6 x niveluri, poziție). Păstrează resursele/upgrade-urile dacă se poate; fă **migrare versionată** dacă schema se schimbă, plus backup local și test rollback.
- Salvează jocul cu identificator mod `board_v3` și câmp nou `board_position_index` (implicit 0), `crystal_charge` și `super_crystal_remaining_landings`, plus `pending_roll_transaction_id` dacă e nevoie. Nu reutiliza `crystal_charge` V2 automat fără reguli explicite; inițializează charge V3 sigur, dar nu șterge cel vechi.
- Mod vechi Cristal Haotic: izolează în modul anterior / branch, ca să poată fi reactivat pentru test comparativ; **nu-l combina în același ecran ca mecanică principală V3**.
- Pe scenă, mută **clădirile mai depărtate, nu le distruge**; păstrează modele, materiale, nume și niveluri. Adaugă un LoopPath ca nod separat; nu muta castelul/cristalul fără nevoie.
- Actualizează scena în pași: geometrie loop cu 36 tile placeholders; test mers; doar apoi tile effects, recompense, bonusuri clădiri, cristal.
- Pentru utilizator, menține compatibilitate cu Godot 4.7.2 Android (după captura editorului). Dacă repo-ul real declară altă versiune, raportează compatibilitatea fără schimbare arbitrară a versiunei proiectului.
- Nu încerca să citești/folosești link-uri de conversație ca sursă tehnică în locul documentelor din pachet și fișierelor Godot reale.
