# PROMPT PENTRU CODEX – LERION V3

Lucrează în **repository-ul curent al jocului Godot 4 LERION, cel cu teren continental, castel albastru, fântână/cristal și șase clădiri deja funcționale**. Nu porni de la proiectele vechi cu insulă și nu crea alt joc din zero.

Am adăugat în proiect un nou pachet de documentație. **Citește integral `AGENTS.md`, `README_INCEPE_AICI.md`, `LERION_DECIZII_V3.md`, `TRASEU_LOOP_GEOMETRIE.md`, `REGULI_ZARURI_ECONOMIE.md`, `CLADIRI_ZONE_INFLUENTA.md`, `CRISTAL_SUPER_BONUS.md`, `MIGRARE_FARA_PIERDERI.md` și `PLAN_CODEX_SI_TESTE.md` înainte să scrii cod.** Consultă `REFERINTE/01_HARTA_PREFERATA_TRASEU.png` pentru aspect și `REFERINTE/02_PROTOTIP_GODOT_ACTUAL.jpg` pentru proiectul real anterior.

**Noua mecanică principală:** două zaruri normale (1–6) indică 2–12 pași; personajul **Lerik** se mișcă pe un **singur drum șerpuit în CIRCUIT ÎNCHIS (36 căsuțe configurabile), fără ramuri, fără auto-intersecții, fără a intra în platforme sau clădiri**. Drumul trece PE LÂNGĂ toate cele șase clădiri și se întoarce continuu la START. Oprirea acordă recompensa tile-ului, trecerea peste START acordă bonus de tură. Nu acorda bonus pentru tile-uri doar traversate.

**Clădirile** (Mina, Moara, Atelierul lui Pongo, Laboratorul lui Pufi, Piața Poznașă, Hanul Aventurierilor) se depărtează și rămân independent upgradeabile nivel 0–3. Fiecare influențează 2–3 căsuțe din zonă și le mărește premiile odată cu upgrade-ul. Castelul și cristalul rămân fixe, NU sunt locuri construibile.

**Cristalul central** primește +1 încărcare per aruncare validă până la 30; la activare de către jucător oferă **x2 recompensele următoarelor 3 aterizări**, apoi revine la încărcarea obișnuită. Nu este generator de 3 simboluri în această variantă. Păstrează separat codul prototipului anterior pentru eventuale teste, dar nu îl porni în V3.

**Important:** Lucrează incremental și păstrează save-urile/resursele existente. Creează checkpoint Git. Începe cu geometria drumului, camera, zarurile și mersul Lerik, nu cu o rescriere totală sau cu noi grafici. Refolosește modele existente; dacă Lerik nu are model animat, folosește temporar un marker care se mișcă pe traseu și declară-l ca placeholder. Menține stilul cartoon 3D acceptat, Android portret și timpul de mișcare vizat 1,5–2,5 s.

**PRIMA LIVRARE:** harta actuală cu 6 clădiri mai distanțate, un traseu real închis de 36 căsuțe, două zaruri funcționale și un Lerik/marker care avansează exact suma. Verifică importul/parsing-ul Godot dacă mediul permite; documentează fișierele modificate, testele executate, erorile și cum testez eu pe Android. După confirmarea primei livrări continuăm cu recompensele, influența clădirilor și Super Cristal.

Dacă nu ai acces la sursa Godot din repository-ul curent, oprește-te și cere fișierele. **Acest ZIP este documentație + referințe, NU include proiectul actual Godot.**
