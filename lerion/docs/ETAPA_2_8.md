> Etapa 3.5 a eliminat căsuțele de energie și a redistribuit tipurile; vezi [ETAPA_3_5_ENERGIE_EVENIMENTE.md](ETAPA_3_5_ENERGIE_EVENIMENTE.md). Tabelele de mai jos rămân valabile pentru celelalte categorii.

# Etapa 2.8 — Categorii distribuite și bonusuri globale

Această etapă înlocuiește asocierile locale din documentația V3 anterioară. Configurația executată este în `assets/board/economy.tres`. Fișierul JSON din CONFIG oferă exemplul corespunzător.

## Distribuția propusă și implementată

Cele 35 de premii se împart în șase categorii. Cinci categorii au câte șase dale, iar jetoanele au cinci. Diferența de o dală permite păstrarea START la zero. Tipurile sunt enumerate explicit, fără generare aleatorie. Indicii și pozițiile fizice provin din circuitul existent.

| Categorie | Indici | Număr |
|---|---|---|
| START | 0 | 1 |
| Monede | 1, 7, 13, 19, 26, 32 | 6 |
| Fragmente | 4, 8, 14, 20, 29, 33 | 6 |
| Construcție | 5, 9, 16, 21, 24, 34 | 6 |
| Energie | 2, 11, 15, 22, 27, 31 | 6 |
| Magie | 6, 10, 18, 23, 28, 35 | 6 |
| Jetoane locale | 3, 12, 17, 25, 30 | 5 |

Tipurile consecutive sunt diferite pe întregul circuit, inclusiv magia de la 35, START și monedele de la 1.

## Valori pe nivel

| Clădire și premiu | Nivel 0 | Nivel 1 | Nivel 2 | Nivel 3 |
|---|---:|---:|---:|---:|
| Piața — monede | 100 | 110 | 125 | 150 |
| Mina — fragmente | 5 | 6 | 7 | 8 |
| Atelierul — puncte de construcție | 2 | 3 | 4 | 5 |
| Moara — energie | 2 | 3 | 4 | 5 |
| Hanul — jetoane | 1 | 2 | 3 | 4 |
| Laboratorul — alternativa în monede | 75 | 83 | 94 | 113 |
| Laboratorul — alternativa în fragmente | 2 | 3 | 4 | 5 |

Se folosește valoarea întreagă din tabel, indexată cu nivelul clădirii asociate categoriei. Funcția centrală `amount` este apelată atât de previzualizare, cât și de acordare. Tabelele sunt cele deja implementate și nu necesită rotunjire la rulare. Costurile rămân cele din CONFIG_PROTOTIP.json, respectiv 1000/3000/8000 monede și 10/25/45 puncte.

Pe magie se alege uniform o singură alternativă, monede sau fragmente, fiecare cu probabilitate 50%. Numai nivelul Laboratorului îi determină valoarea. Piața și Mina nu multiplică această alternativă. Alegerea și valoarea sunt confirmate o singură dată în tranzacție înainte de animație.

Pentru energie, premiul efectiv este minimul dintre valoarea tabelului și spațiul până la 100 după debitarea aruncării. Interfața prezintă valoarea efectivă din chitanță. START acordă 100 de monede exclusiv la traversarea 35 → 0. Oprirea pe START are chitanță de aterizare goală.

## Salvări și interfață

Salvarea V3 versiunea 4 conține nivelurile, resursele, energia, poziția, turele și chitanța aruncării. Asocierile locale erau în resursa de configurare. Înlocuirea acesteia nu cere o versiune nouă a salvării. Chitanțele vechi păstrează categoria și suma acordate înaintea redistribuirii, inclusiv când căsuța are acum alt tip. Migrarea existentă din versiunea 3 și păstrarea biletelor sunt acoperite de teste.

Selectarea unei clădiri evidențiază toate dalele categoriei, afișează nivelul, valoarea actuală, valoarea următoare și costul. La nivelul 3 apare „Nivel maxim”. Marcajele de nivel și efectul de upgrade folosesc aceeași selecție globală. Deselectarea șterge evidențierea.

## Verificare executată

Checkpointul Git este `checkpoint-v3-global-before-2.8`, la commitul `3e80b9f`. Toate cele șapte suite au trecut înaintea modificărilor.

După modificare, Godot 4.7.2 a importat proiectul și a pornit scena. Suitele au raportat zero erori.

- Circuit și zaruri — 1529 verificări.
- Economie — 9939 verificări. Fiecare clădire, nivel și dală este verificată prin tranzacția reală, cu celelalte clădiri la nivelul 3 pentru detectarea bonusurilor încrucișate.
- Prezentare — 323 verificări, inclusiv Grăbește, dublu tap, suspendare și restart.
- Camera Premium și preferințe — 329 verificări.
- V2 — 70 verificări.
- Fluxul satului — 47 verificări.
- Hartă — șase parcele în trei formate și gesturi, zero erori.

Testul de compatibilitate încarcă o salvare anterioară cu o chitanță de jetoane pe indicele 4, devenit acum fragmente, și compară toate câmpurile și fișierele salvării. Testele de magie verifică ambele alternative, suspendarea și restartul cu premiul confirmat. Testele de energie compară soldul plafonat și textul +1 energie.

## Verificare Android

Deschide proiectul în Godot 4.7.2 și exportă cu presetul Android. Actualizarea unei instalări existente cere aceeași cheie de semnare pentru păstrarea progresului. APK-ul de test este semnat cu aceeași cheie de debug folosită la livrarea Premium.

1. Verifică soldurile, nivelurile, poziția și turele la prima deschidere a unei partide existente.
2. Selectează Piața. Indicii 1, 7, 13, 19, 26, 32 trebuie evidențiați. În Sac se poate activa afișarea indicilor în buildul debug.
3. La nivelul 1, verifică previzualizarea 110 → 125 și costul de 3000 monede plus 25 puncte. Confirmă upgrade-ul. Oricare dintre cele șase dale acordă 125 la nivelul 2.
4. Selectează Mina, Moara, Atelierul, Laboratorul și Hanul. Compară dalele cu tabelul de mai sus. Deselectează și verifică dispariția evidențierii.
5. Rulează mai multe ture, folosește Grăbește, treci aplicația în fundal în mers și redeschide-o. Verifică soldul și poziția confirmate.
6. Verifică pe telefon lizibilitatea panoului pe două linii și încadrarea camerei.

Testarea pe telefon fizic rămâne de efectuat. Distribuția echilibrată în număr de dale este o propunere de prototip. Veniturile globale cresc odată cu upgrade-urile și necesită evaluare cu jucători.
