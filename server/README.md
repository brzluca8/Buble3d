# Serverul Buble

Backend gratuit, fără dependențe: Python 3.10+ (doar biblioteca standard) + SQLite (un singur fișier).

## Pornire

```bash
python3 server/buble_server.py --port 8080 --db buble.db
python3 -m unittest server/test_server.py      # teste
```

În joc: **⚙️ Setări → Server online** → adresa (ex. `https://buble.domeniul-tau.ro`) → **Conectează**.
Fără adresă, jocul rămâne offline, iar rivalul e personajul Contele Furtună.

## Ce face

| Rută | Rol |
|---|---|
| `POST /v1/auth` | cont pe dispozitiv (fără parolă), întoarce token + cod de prieten |
| `PUT /v1/island` | starea publică a insulei (niveluri, scuturi) – folosită de atacatori |
| `PUT/GET /v1/save` | salvare în cloud |
| `POST/GET /v1/friends` | prieteni după cod |
| `GET /v1/targets` | ținte reale pentru atac/jaf: prieteni, apoi jucători activi (doar jucători reali) |
| `POST /v1/attack` | atac: scutul țintei parează, altfel clădirea scade un nivel; ținta primește mesaj |
| `POST /v1/raid/start`, `/v1/raid/pick` | jaf cu 9 nori, 3 alegeri, valorile stau pe server |
| `GET /v1/inbox` | mesajele primite (atacuri, jafuri, cadouri, prieteni noi) |
| `POST /v1/cards/gift` | cadou de carte (doar prietenilor) |
| `POST /v1/team/join`, `/v1/team/points`, `GET /v1/team` | echipe de 4 pentru evenimentul săptămânal |
| `POST /v1/iap/verify` | verificarea plăților – **refuză** până la configurarea Google Play Developer API |

Recompensele de atac și jaf se calculează pe server. Limită: 240 de cereri pe minut per jucător.

## Găzduire gratuită sau ieftină

- **Calculatorul tău + Cloudflare Tunnel** (gratuit): `cloudflared tunnel --url http://localhost:8080` dă o adresă HTTPS publică.
- **Orice VPS** (de la ~4 €/lună) cu **Caddy** (gratuit) în față pentru HTTPS automat:
  ```
  buble.domeniul-tau.ro {
      reverse_proxy localhost:8080
  }
  ```
- Fă copii de rezervă ale fișierului `buble.db`.

Android permite implicit doar **HTTPS**. Pentru teste în rețeaua locală cu `http://`, activează în
exportul Android opțiunea *Use Cleartext Traffic*.

## Înainte de lansare

- Conturi legate de Google Play Games / e-mail (acum contul e legat de dispozitiv).
- Validare pe server a progresului (acum serverul are încredere în starea trimisă de joc, cu limite).
- Verificarea plăților cu Google Play Developer API (`purchases.products.get`) și cont de serviciu.
- Politică de confidențialitate: serverul stochează numele ales, nivelurile insulei și salvarea.
