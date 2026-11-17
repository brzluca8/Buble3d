# Buble 3D

Joc mobil 3D (portret, Android): insulă plutitoare cu clădiri de dezvoltat, mascotă și mini-jocul Buble Blast.
Vite + three.js r187, JavaScript simplu, fără framework.

## Pornire

```bash
npm install
npm run dev        # http://localhost:5173 și adresa din rețeaua locală (deschide-o pe telefon, aceeași Wi-Fi)
npm run build      # build de producție în dist/
npm run smoke      # test automat în browser (după build): erori din consolă, randare, selectare, upgrade, Buble Blast
```

## Structură

| Fișier | Conținut |
|---|---|
| `src/state.js` | economie, salvare în LocalStorage (cu validare), venit offline |
| `src/world.js` | scena 3D: insula, clădirile, mascota, texturi pictate, glow, nori, lumini |
| `src/merge.js` | combinarea geometriei statice (reduce draw call-urile pentru telefon) |
| `src/main.js` | camera orbitală, selectare, upgrade, ecrane, bucla de joc |
| `src/blast.js` | mini-jocul Buble Blast (canvas 2D) |
| `src/models.js` | modele GLB: încărcate de jucător (IndexedDB) sau din `public/models/` |
| `legacy/buble.html` | versiunea inițială într-un singur fișier (three r128), păstrată ca referință |

Modele 3D: vezi `public/models/README.md`.

Skill-urile din `.claude/skills/` (awesome-gamedev-agent-skills, Apache-2.0) ghidează agentul de programare.
