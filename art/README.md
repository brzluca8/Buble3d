# Artă 3D (Blender)

Scripturi care construiesc modelele jocului în Blender 4.x și le exportă ca GLB în `godot/models/`.

```bash
# clădirile (toate sau doar unele: palat obs turn mag sera)
blender -b --factory-startup --python art/blender/buildings.py -- godot/models
# terenul insulei
blender -b --factory-startup --python art/blender/island.py -- godot/models/insula.glb
# mascota (cu animații idle / walk / jump)
blender -b --factory-startup --python art/blender/mascot.py -- godot/models/mascot.glb
```

Opțional, o imagine de previzualizare: `buildings.py -- godot/models --preview DOSAR`,
iar pentru `island.py` / `mascot.py` un al doilea argument `previzualizare.png`.

- `bk.py` – piese comune: cupole, ferestre cu arc, bannere, scări, balustrade, tufe, felinare.
- Plasele fiecărui model sunt unite (puține apeluri de desenare pe telefon).
- Materialele numite `Piatra`, `Soclu`, `Pavaj`, `AcoperisTurcoaz`, `Stanca`, `Iarba` primesc în joc
  texturi triplanare, deci modelele nu au nevoie de UV-uri.
- Poți înlocui oricând un model cu unul făcut manual (același nume de fișier în `godot/models/`).
