# Buble 3D

Joc mobil 3D casual (portret, interfață în română): insulă plutitoare cu clădiri de dezvoltat,
mascotă și mini-jocul Buble Blast. Vite + React + React Three Fiber + Drei + Zustand.

## Pornire

```bash
npm install
npm run dev        # http://localhost:5173 și adresa din rețeaua locală (pentru telefon)
npm run build      # build static în dist/ (căi relative, merge pe orice hosting static)
npm run preview    # servește dist/ în rețeaua locală
```

Pentru test pe Android: telefonul în aceeași rețea Wi-Fi, deschide adresa „Network" afișată de `npm run dev`.

## Structură

```
src/
  store.js            stare + salvare (Zustand, LocalStorage „buble3d", compatibil cu buble.html)
  data.js             clădiri, înălțimi țintă, nume modele
  App.jsx             venit pasiv / offline, încărcarea modelelor din IndexedDB
  three/
    World.jsx         Canvas, lumini, umbre, bloom real + tone mapping, calitate adaptivă
    Island.jsx        Terrain (insula.glb sau procedural), Plaza, Droplets, Waterfalls (3 straturi + ceață)
    Building.jsx      Building (GLB sau procedural, felinare pe nivel, animație upgrade), SelectionRing, Sparks
    Mascot.jsx        mascota (GLB cu animații sau procedurală)
    Sky.jsx           Clouds (drei, volumetrici, textură locală), FarIslands
    CameraRig.jsx     orbită: tragere = rotire, ciupire/rotiță = zoom, atingere = selectare
    ModelSlot.jsx     utilizator (IndexedDB) → public/models/<id>.glb → procedural
    models.js         încărcare/normalizare GLB, Draco + Meshopt locale, IndexedDB
    procedural.js     geometria procedurală portată din buble.html
    textures.js       texturi pictate pe canvas
  ui/                 HUD, foaia de upgrade, navigare, ecrane DEMO, panoul Modele 3D, Buble Blast
public/models/        modelele GLB (vezi README-ul de acolo)
buble.html            prototipul original (referință)
```

## Calitate grafică

- **Înaltă** (implicit): bloom real (`@react-three/postprocessing`, mipmapBlur, rezoluție 1/2), MSAA 4×, umbre 2048², DPR ≤ 2.
- **Scăzută**: fără post-procesare, umbre 1024², DPR ≤ 1.25, mai puțini nori.
- `PerformanceMonitor` trece automat pe setările reduse dacă FPS-ul scade.
- Setarea se schimbă din „🧩 Modele 3D".

## Reguli de proiect

Interfață exclusiv în română · tehnologii gratuite · lumea rămâne 3D · optimizat pentru telefoane ·
funcțiile sociale și plățile rămân DEMO până la existența unui backend (`api/` separat, mai târziu).
