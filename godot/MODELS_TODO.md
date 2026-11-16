# MODELS_TODO – modelele 3D (sloturi GLB)

Jocul încarcă automat fișierele din `res://assets/models/`. Dacă un fișier lipsește, folosește varianta
procedurală (rezervă). Modelele se scalează automat la înălțimea țintă, deci dimensiunea din export nu contează.

| Fișier | Ce e | Înălțime țintă | Poligoane max |
|---|---|---|---|
| `palat.glb`, `palat_1…5.glb` | Palatul, 5 etape | 5,5 | 30.000 |
| `observator.glb`, `observator_1…5.glb` | Observatorul | 4,5 | 30.000 |
| `turn.glb`, `turn_1…5.glb` | Turnul | 5,3 | 30.000 |
| `magazin.glb`, `magazin_1…5.glb` | Magazinul | 3 | 30.000 |
| `sera.glb`, `sera_1…5.glb` | Sera | 3 | 30.000 |
| `mascota.glb` | Nox, asistentul robot (Neon noir), cu animații; generat de `art/blender/asistent.py` | 1,6 | 15.000 |
| `mecanism.glb` | Automatul de rotiri (fără role), noduri „Maneta” și „Roata0..2”; `art/blender/mecanism.py`. Unități reale, fereastra rolelor la (0, 2.05), 2,6 × 1,44 | 4,6 | 20.000 |
| `piedestal.glb` | Piedestalul globului | – (coordonate fixe, rază ~5) | 15.000 |
| `plaza.glb` | Piața și vegetația orașului | – (coordonate fixe) | 25.000 |

Acum toate sunt generate cu scripturile din `art/blender/` (Blender 4, licență proprie a proiectului).

## Reguli de export (Blender → glTF 2.0, .glb)

- Z în sus în Blender, fața spre −Y (în joc devine +Z). Baza pe z = 0, centrat pe X/Y.
- Etapa N trebuie să arate clar mai mare / mai bogată decât N−1 (scara e fixată după etapa 5).
- Nume de materiale cu efect special în joc: `Piatra`, `Soclu`, `Pavaj`, `AcoperisTurcoaz`, `Iarba`, `Stanca`
  (primesc texturi triplanare și culorile temei globului), `CascaSticla` (devine sticlă Fresnel).
- Mascota: animații numite `idle`, `walk`, `wave`, `joy` (opțional `-loop` la sfârșit pentru repetare).
  Noduri cu nume fixe pentru garderobă: `Casca` (domul), `Corp`, `Esarfa`; materiale `Blana` (corpul) și `Violet` (eșarfa).
- Texturi maximum 1024², fără lumini/camere în fișier. Lumina coaptă (AO) se poate pune în `occlusionTexture`.
- Licență: doar modele proprii sau gratuite cu licență compatibilă comercial (CC0 / Royalty Free); notează sursa aici.

## Prompturi pentru generare (artist sau generator 3D)

Stil comun: *stylized premium fantasy, elegant, adult-friendly, cream limestone, turquoise domes, discreet gold trim,
violet banners with a golden leaf emblem, warm glowing windows, clean PBR materials, game-ready low/mid poly.*

- **Palat, etapa 1→5**: „small limestone pavilion with one turquoise dome" → „with arched door and steps" →
  „with two side towers with onion domes" → „large ribbed central dome on a drum, crystal above the door" →
  „gold lantern on top, violet flags, ivy and roses".
- **Observator**: „round limestone tower with conical violet roof" → „…with balcony and balustrade" →
  „ribbed violet dome with a starry opening" → „large brass telescope, glowing stars".
- **Turn**: „slender limestone tower" → „taller with banner" → „balcony and turquoise dome" → „gold spire".
- **Magazin**: „wooden market stall with violet awning" → „small stone shop with arched windows" →
  „scalloped violet awning with gold leaf" → „lit shelves, flower pots, turquoise pyramid roof".
- **Seră**: „gold frame with a few plants" → „small glass greenhouse" → „octagonal glass greenhouse with dome" →
  „lush plants and warm light" → „gold ribs, pink and violet flowers".
- **Mascota (cască de bulă)**: „round cream bean-shaped character, small glossy dark eyes with highlights, subtle smile,
  rosy cheeks, violet scarf with a gold leaf, small leather backpack, transparent glass dome helmet with gold collar
  and a tiny gold antenna, mature and refined proportions, no aviator goggles".
- **Piedestal**: „stepped violet pedestal with gold rings and glowing turquoise runes, for a glass snow globe".
