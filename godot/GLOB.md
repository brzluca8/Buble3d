# Orașul din bulă (v2)

Ecranul principal este acum `scenes/globe.tscn` (`scripts/globe_world.gd`). Vechile scene rămân:
insula cu zaruri `scenes/main.tscn`, varianta pictată `scenes/main2d.tscn`.

## Ce e în scenă (totul 3D real)

| Element | Implementare |
|---|---|
| Glob de sticlă (rază 6) | `shaders/glass_globe.gdshader`: Fresnel, margine irizată, centru transparent, fără refracție; față + spate |
| Reflexii false | 2 sprite-uri luminoase care urmăresc camera |
| Piedestal | `models/piedestal.glb` (`art/blender/pedestal.py`): violet, inele aurii, 28 de rune turcoaz luminoase |
| Oraș | aceleași clădiri pe 5 niveluri, piața, fântâna, mascota (scara 0,64) |
| Bule care urcă | particule; o explozie de bule la upgrade și la victoria în Buble Blast |
| Cer de amurg | cer procedural indigo → violet → turcoaz, 420 de stele (MultiMesh, unul singur) |
| Nivelul orașului | la fiecare 4 niveluri de clădiri se aprinde un inel auriu pe baza globului și globul crește cu 3% |
| Cameră | oblică, rotire limitată ±25°, zoom cu două degete, rotire lentă după 4 s fără atingere |

## Prieteni (`scripts/social/`)

- `FriendsRepository`: `list_friends`, `get_city`, `send_gift`, `notify_visit`, `can_gift_today`, `invite_code`.
- `LocalDemoRepository` (fără server): listă goală → 6 sloturi „Invită” marcate **DEMO**. Nu se simulează jucători.
- `NetFriendsRepository` (cu serverul din `server/`): prieteni reali în bule (mini-oraș după nivelul lor).
- Vizită: atingi bula → camera intră în ea → globul arată orașul prietenului → cadou (monede sau o carte
  dublură), o dată pe zi → „Înapoi acasă”. Prietenul primește „ți-a vizitat orașul” / cadoul.
- Semnal: bula pulsează și primește un steag roz când prietenul te-a vizitat sau ți-a lăsat un cadou.
- Invitație: cod de prieten (Prieteni); +200 monede pentru fiecare prieten nou (primii 10).

## Calitate (⚙️ Setări): Mic / **Mediu** (implicit) / Mare

| | Mic | Mediu | Mare |
|---|---|---|---|
| Strălucire (glow) | nu | da | da |
| Umbre | nu | 1024 | 2048 |
| Rezoluție 3D | 75% | 90% | 100% |
| MSAA | nu | nu | 2× |
| Bule / stele | 12 / 200 | 26 / 320 | 44 / 420 |

Măsurat aici (randare OpenGL pe procesor, nu telefon): ~210–280 apeluri de desenare, 125.000–230.000 de
primitive pe cadru (nivel 1 → nivel 5). **60 FPS pe un telefon mediu nu e verificat** – trebuie măsurat pe telefon.

## Înainte de lansare (juridic)

Conturi, prieteni și mesaje – mai ales cu minori – cer verificare pentru protecția datelor copiilor
(consimțământ parental, moderarea numelor, politică de confidențialitate). De făcut înainte de publicare.
