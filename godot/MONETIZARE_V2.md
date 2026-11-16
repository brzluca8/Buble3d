# Monetizare și analiză – stare și plugin-uri

## Stare în versiunea de test

- **Plăți reale: dezactivate.** `autoload/monetization.gd` are `ENABLED = false`; butoanele cu preț în lei arată
  doar un mesaj.
- **O singură monedă premium: Perle.** Se câștigă în joc (niveluri, cufere epice, serie, eveniment) și se pot
  cheltui în magazin (energie, cufăr rar, scut) – prețul fiecărui articol e afișat în perle.
- **Pachete de perle** cu preț întreg în lei, fără bonusuri ascunse (`data/shop.json`).
- **Șansele sunt vizibile**: ecranul „Șanse" (butonul ? de lângă Rotește și din Magazin) arată tabelul complet
  al mașinii și conținutul / șansele cuferelor.

## Plugin-uri Godot (de verificat la integrare – nu am putut accesa internetul pentru confirmare)

| Nevoie | Opțiune | Observații |
|---|---|---|
| Google Play Billing | `godotengine/godot-google-play-billing` (oficial) | Pentru Godot 4.2+ ca Android plugin v2; cere „Use Gradle Build". Achizițiile se verifică pe server (Google Play Developer API) înainte de acordarea perlelor. |
| Reclame cu recompensă | `poingstudios/godot-admob-plugin` | Android și iOS; cere consimțământ UMP în UE. Reclamele trebuie să fie opționale. |
| Analiză | GameAnalytics (SDK Godot oficial) sau Firebase Analytics (plugin-uri comunitare) | `autoload/analytics.gd` are o interfață: implementezi `send(name, params)` și apelezi `Analytics.set_backend()`. Recomand **GameAnalytics** (gratuit, are panouri pentru retenție și economie). |
| Notificări locale | plugin comunitar de notificări locale pentru Android | `autoload/notifier.gd` caută singletonul `LocalNotification`. |

## Juridic, înainte de lansare

- **Mașina de bule e un joc de noroc simulat** (fără bani reali, dar cu o monedă cumpărabilă): Google Play cere
  declararea în chestionarul de conținut; ratingul IARC va fi mai mare (de regulă 12+ sau 16+ / PEGI cu „simulated
  gambling"). Verifică politica Google Play „Real-Money Gambling, Games and Contests" și regulile pentru
  „simulated gambling".
- **Cutii cu premii (cufere) cumpărabile**: unele țări cer afișarea șanselor (făcut) sau le restricționează
  (ex. Belgia). Cuferele se pot cumpăra doar cu perle; dacă perlele devin cumpărabile, regulile se aplică.
- **Public adult (25–55)**: jocul nu țintește copii, dar trebuie declarat corect publicul țintă în Play Console.
- **Date personale**: analiza e locală acum; la integrarea unui serviciu de analiză: politică de confidențialitate,
  consimțământ (GDPR), formularul „Data safety".
