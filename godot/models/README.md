# Modele 3D (GLB)

Pune aici fișiere `.glb`; Godot le importă automat la deschiderea proiectului.
Fiecare înlocuiește varianta procedurală. Dacă un fișier lipsește, jocul folosește geometria din cod.

| Fișier        | Piesă            | Scalare automată |
|---------------|------------------|------------------|
| `palat.glb`   | Palatul Norilor  | înălțime 5.5 |
| `obs.glb`     | Observatorul     | înălțime 4.5 |
| `turn.glb`    | Turnul Elegant   | înălțime 5.3 |
| `mag.glb`     | Magazinul        | înălțime 3 |
| `sera.glb`    | Sera de Cristal  | înălțime 3 |
| `mascot.glb`  | Mascota          | înălțime 1.6 |
| `insula.glb`  | Terenul insulei  | diametru 14.4; originea = nivelul ierbii (y = 0) |

- Clădiri și mascotă: centrate pe X/Z, baza pe y = 0, fața principală spre +Z.
- `insula.glb` înlocuiește doar stânca + iarba; piața, fântâna, copacii și cascadele rămân.
- Mascota: clipurile numite `idle`, `walk` (sau `run`) și `jump` sunt redate automat.
- Lumină coaptă: în Blender coace AO + lumina în textură (baked) sau folosește LightmapGI în Godot.
- Buget pentru telefon: ~15–30k triunghiuri pe clădire, texturi 1024² (max 2048²).
  În setările de import alege compresie VRAM (ETC2/ASTC, deja activă în proiect).
