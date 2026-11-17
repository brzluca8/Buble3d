# Modele 3D

Pune aici fișierele `.glb` și adaugă numele lor (fără extensie) în `manifest.json`, de ex.
`["palat", "mascot"]`. Nume acceptate: `palat`, `obs`, `turn`, `mag`, `sera`, `mascot`.

Fiecare model este scalat automat la înălțimea țintă (palat 5.5, observator 4.5, turn 5.3,
magazin 3, seră 3, mascotă 1.6), centrat și așezat pe sol. Dacă fișierul lipsește, rămâne
varianta procedurală. Un model încărcat din jocul („🧩 Modele 3D”) are prioritate.

Pentru telefon: comprimă cu `npx gltf-transform optimize in.glb out.glb --compress meshopt
--texture-compress webp` (Meshopt e deja suportat; Draco nu).
