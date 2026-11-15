# Monetizare – plan

Tot codul de reclame și plăți trece prin `autoload/monetization.gd`. Acum `DEMO = true`:
nu există SDK, nu se plătește nimic, iar reclama cu recompensă este un ecran de test marcat „RECLAMĂ DEMO".

## Ce e pregătit în joc

| Sursă de venit | Unde apare | Stare |
|---|---|---|
| Reclamă cu recompensă (opțională) | „🎬 Dublează monedele" după Buble Blast | flux complet, reclamă DEMO |
| Pachete de monede (consumabile) | Magazin | catalog + buton, plăți dezactivate |
| Fără reclame (o singură dată) | Magazin | catalog, plăți dezactivate |
| Abonament VIP | Magazin | catalog, plăți dezactivate |
| Season Pass | Magazin | catalog, plăți dezactivate |

ID-urile produselor (`coins_small`, `no_ads`, `vip_month`...) și prețurile orientative sunt în `PRODUCTS`.
Prețurile reale se stabilesc în Google Play Console; jocul trebuie să le citească de acolo, nu să le afișeze din cod.

## Pași până la bani reali

1. **Cont Google Play Console** (taxă unică 25 USD) și profil de plăți. Pentru venituri, discută cu un contabil
   forma juridică potrivită (persoană fizică / PFA / SRL) și impozitarea.
2. **Politică de confidențialitate** publicată (URL), formularul *Data safety* și clasificarea de vârstă (IARC).
   Dacă jocul țintește copii, se aplică regulile *Families*, care limitează reclamele.
3. **Reclame**: cont AdMob + plugin AdMob pentru Godot (Android). În UE este obligatoriu consimțământul
   (Google UMP / GDPR) înainte de reclame personalizate.
4. **Cumpărături**: plugin-ul Google Play Billing pentru Godot; produsele create în Play Console cu aceleași ID-uri.
5. **Verificare pe server**: achizițiile se validează pe un server (Google Play Developer API) înainte de a acorda
   monede/VIP; altfel sunt ușor de fraudat. Același backend va servi conturile, prietenii și evenimentele.
6. **Salvare în cloud** legată de cont, ca jucătorii plătitori să nu-și piardă progresul la schimbarea telefonului.
7. Setează `DEMO = false` și completează cele două `TODO(monetizare)` din `monetization.gd`.

## Principii (ca jocul să fie și plăcut, și profitabil)

- Reclamele sunt **opționale și recompensate**; fără reclame forțate în mijlocul jocului.
- Economia trebuie echilibrată înainte de prețuri: cât durează un upgrade, cât aduce o rundă, cât aduce o reclamă.
- Măsoară (analytics fără date personale) retenția zilei 1/7/30 înainte de a investi în reclame plătite.
