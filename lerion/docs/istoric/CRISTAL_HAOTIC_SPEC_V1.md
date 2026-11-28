# Mecanica „CRISTALUL HAOTIC” — specificație de prototip V1
Status: **concept agreat pentru test**, nu economie validată cu jucători. Valorile numerice sunt propuneri configurabile, nu promisiuni de retenție/venit.

## 1. Bucla de gameplay
1. Jucătorul are energie și apasă butonul mare **ACTIVEAZĂ**.
2. Se consumă 1 energie (dacă există); la momentul apăsării se calculează și se salvează atomizat un singur rezultat de 3 simboluri, înaintea animației.
3. Cristalul central pulsează și proiectează 3 simboluri vizibile (UI billboard/CanvasLayer, nu e necesar model 3D complex), în circa 1–1,5 secunde.
4. Se acordă recompensele de bază, apoi maximum **un bonus de combinație** (triplă > combo mixt > pereche).
5. Se actualizează monedele/ciocanele/fragmentele/biletele și energia acumulată pentru Super Cristal; jocul permite imediat următoarea activare.
6. Folosim resursele pentru construirea/îmbunătățirea celor 6 clădiri. Personajele reacționează comic **ocazional**, nu la fiecare activare.

## 2. Cele 6 simboluri — șanse pe fiecare simbol (generate independent)
| Simbol | Cheie recomandată | Probabilitate | Premiu de bază |
|---|---|---:|---|
| 🪙 | coin | 36% | +50 monede |
| 🔨 | hammer | 24% | +1 punct construcție |
| 💎 | crystal | 16% | +2 fragmente |
| 🎁 | chest | 12% | +100–200 monede (aleator, echilibrat ulterior) |
| ⚔️ | challenge | 8% | +1 bilet de provocare; fără sistem online încă |
| ✨ | chaos | 4% | bonus aleatoriu MIC, mereu pozitiv; de configurat |
Total 100%. Fiecare slot este generat independent. NU promite că trei simboluri rare apar frecvent.

Pentru a putea testa simbolul `chaos` fără UI suplimentară, se poate folosi **provizoriu** +75 monede sau +2 fragmente (50/50); această regulă nu a fost validată încă de utilizator și trebuie păstrată configurabilă.

## 3. Recompense de combinație (în PLUS față de recompensele de bază)
- 3 × `coin`: +500 monede.
- 3 × `hammer`: +5 puncte construcție.
- 3 × `crystal`: +12 fragmente.
- 3 × `chest`: un cufăr suplimentar cu +250–600 monede.
- 3 × `challenge`: +5 bilete de provocare.
- 3 × `chaos`: o recompensă pozitivă specială dintr-un tabel configurabil + animație comică rară (definiția exactă se testează ulterior).
- Exact 2 simboluri identice: +încă o recompensă de bază a acelui simbol (NU și în cazul unei triple; gestionare explicită pentru `chest`/`chaos`).
- Combinația mixtă `coin`+`hammer`+`chest`, în orice ordine: **+150 monede și +2 puncte construcție**.
- Prioritate: triplă, mixtă, pereche, nimic; se aplică **maximum un** bonus de combinație.

## 4. Energie, Super Cristal, ritm
- Energie: max 100; activare obișnuită: 1; regenerare: +1 la 5 minute, până la max, numai când energia nu este maximă.
- Pentru prototip: regen offline bazată pe timp local salvat; nu este anti-cheat (timpul telefonului poate fi schimbat).
- Super Cristal: +1 progres după fiecare activare obișnuită, maximum 30/30; la 30 jucătorul **alege** când îl activează.
- Dacă a fost armat Super Cristal, următoarea activare costă tot 1 energie, oferă x2 la monedele și punctele de construcție obținute din acea activare (bază + bonusuri) și **un cufăr suplimentar**. Apoi progresul Super Cristal revine la 0/30; nu se mai adaugă punct pentru acea activare specială.
- Super Cristal NU dublează fragmentele/biletele, cel puțin în V1. Nu permite armarea multiplă sau exploatarea prin dublu tap.
- Auto 10 / 25 / 50 activări doar DUPĂ ce sistemul normal este stabil; oprește la energie 0, interacțiune user sau recompensă specială care cere alegere. Include stop clar.
- Animație normală țintă 1–1,5 secunde; bonusurile comice țintă 2–3 secunde, opționale/skip. Fără flash agresiv.

## 5. UI și explicație pentru utilizator
- HUD: monede, energie, fragmente, progres Super Cristal; materiale construcție și bilete într-un panou accesibil.
- Buton **ACTIVEAZĂ** mare, sub scenă; 3 simboluri ieșind din cristal, feedback la câștig clar și instant.
- Construcțiile se selectează din cele 6 platforme, afișează costul și rezultatul upgrade-ului înainte de confirmare.
- Efectele vizuale trebuie să fie precise și rapide; să nu mărească nejustificat costul GPU pe telefon.

## 6. Configurare și integritate
- Mută probabilitățile/premiile/costurile din script într-un fișier Resource/JSON configurabil, cu validare (ponderi însumate la 100%). `CONFIG_PROTOTIP.json` este un exemplu de transfer, nu e importat automat.
- Generatorul de rezultate primește o sursă RNG pentru teste și este separat de animație/UI.
- Fiecare activare consumă energia și produce recompensa **o singură dată**, indiferent de skip, pauză sau tap repetat.
- Salvează state versionat în `user://` cu recuperare la fișiere invalide; fără reset de progres la hot reload. Pentru economie online reală ar trebui ulterior server autoritar.
- Pentru testare adaugă, doar în debug/development, posibilitatea de a modifica resursele și a forța un anumit rezultat.

## 7. Riscuri de echilibru
- Cu ponderi independente, triplele rare sunt **foarte rare**: 3 × `chaos` = 0,04³ ≈ 0,0064% (aprox. 1 din 15.625 activări). NU prezenta această combinație ca bonus obișnuit.
- Costurile și durata de progres nu sunt calibrate. Rulează simulări (de ex. 100k+ activări), măsoară câte activări trebuie pentru o clădire, apoi ajustează după teste reale.
- Evită presiunea de a cumpăra energii/bonusuri înainte să existe retenție. **Fără SDK reclame/IAP acum**.
