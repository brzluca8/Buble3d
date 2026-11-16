# Modele 3D (GLB)

Pune aici fișiere `.glb` cu aceste nume. Fiecare înlocuiește automat varianta procedurală;
dacă fișierul lipsește sau e invalid, jocul folosește geometria din cod.

| Fișier        | Piesă            | Scalare automată             |
|---------------|------------------|------------------------------|
| `palat.glb`   | Palatul Norilor  | înălțime 5.5                 |
| `obs.glb`     | Observatorul     | înălțime 4.5                 |
| `turn.glb`    | Turnul Elegant   | înălțime 5.3                 |
| `mag.glb`     | Magazinul        | înălțime 3                   |
| `sera.glb`    | Sera de Cristal  | înălțime 3                   |
| `mascot.glb`  | Mascota          | înălțime 1.6                 |
| `insula.glb`  | Terenul insulei  | diametru 14.4, originea = nivelul ierbii (y = 0) |

Reguli:
- Clădirile și mascota sunt centrate pe X/Z, cu baza pe y = 0; fața principală spre +Z.
- `insula.glb` înlocuiește doar stânca + iarba; piața, fântâna, copacii și cascadele rămân.
- Mascota: clipurile de animație numite `idle`, `walk` (sau `run`) și `jump` sunt redate automat.
- Compresie acceptată: Draco și Meshopt (decodoare incluse local, fără CDN).
- Lumina coaptă: exportă din Blender cu textura baked în `emissive` sau ca `lightMap`/`occlusionTexture` (AO).
- Buget pentru telefon: ~15–30k triunghiuri pe clădire, texturi 1024² (max 2048²), KTX2 nu e activat încă.

Serverul de dezvoltare reîncarcă pagina automat când adaugi sau ștergi un fișier aici.
Din joc, butonul „🧩 Modele 3D" permite și încărcarea unui GLB direct de pe telefon (salvat în IndexedDB),
cu prioritate față de fișierele de aici.
