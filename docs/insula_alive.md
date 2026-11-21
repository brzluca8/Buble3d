# Insula 1, v4: insula vie (Pasul 4)

Vântul Aliseron e un singur uniform global (`vant_directie`, `vant_putere`, setat în `godot/insula1/insula1.gd`): un
vânt constant + rafale periodice (două ritmuri care se suprapun rar). În shaderele recuzitei, rafala mai trece și ca
un val de zgomot peste insulă (iarba, florile și coroanele se apleacă împreună, pe rând, în direcția vântului).
Același vânt rotește moara mai repede în rafale și mută umbrele norilor.

| # | Element | Animația | Unde | Cost (pe telefon) | Mic | Mișcare redusă |
|---|---|---|---|---|---|---|
| 1 | Râul, șanțul, laguna | apa curge (normale și dungi în mișcare), luciri | `water_flow.gdshader` | 1 material, doar shader | da | încetinită |
| 2 | Cascadele | dungi care cad, spumă la buză | `water_flow.gdshader` | doar shader | da | încetinite |
| 3 | Ceața de la baza cascadelor | particule moi care urcă | `_ceata_cascade()` | 10–18 particule / cascadă, overdraw | **nu** | nu |
| 4 | Stropi la baza cascadelor | picături care sar și cad | `_viata_v4()` | 14 particule / cascadă | **nu** | nu |
| 5 | Moara | palele se rotesc, mai repede în rafale | `_process()` | o transformare / cadru | da | oprită |
| 6 | Barca | se leagănă (sus-jos, ruliu, tangaj) | `_process()` | o transformare / cadru | da | oprită |
| 7 | Valuri în jurul bărcii | 3 cercuri care pleacă la nesfârșit | `unde_apa.gdshader` | 1 pătrat, aditiv | da | stau pe loc |
| 8 | Iarba (smocuri) | se leagănă, valuri de rafală | `recuzita_comun.gdshaderinc` | 1 MultiMesh (≈360 bucăți) | jumătate | oprită |
| 9 | Florile | se leagănă cu iarba | idem | 1 MultiMesh (≈120) | jumătate | oprite |
| 10 | Palmierii, arborii roz, copacul mare, tufele | frunzele și coroanele în vânt | idem | 6 noduri + 3 MultiMesh | da | oprite |
| 11 | Frunzișul vechi, pânzele, baldachinele, steagurile | leagăn după înălțime (culoarea de vârf A) | `insula_comun.gdshaderinc` | doar shader | da (v4) | oprite |
| 12 | Norii | plutesc pe cer, marea de nori se rotește încet | `_process()` | 30 sprite-uri (14 la Mic) | da | opriți |
| 13 | Umbrele norilor | pete care trec peste teren, insulă și recuzită | `umbre_nori.gdshaderinc` | zgomot procedural în shader | da | stau pe loc |
| 14 | Insulițele din fundal | se leagănă sus-jos și se înclină puțin | `_process()` | 5 transformări / cadru | da | oprite |
| 15 | Cristalele (vechi și noi) | pulsează | shaderele insulei și recuzitei | doar shader | da | oprit |
| 16 | Portalul | vârtejul se rotește | `portal_vartej.gdshader` | 1 pătrat | da | încetinit |
| 17 | Felinarele (vechi, noi) + halourile | pâlpâie | shadere + `halou.gdshader` (1 MultiMesh) | doar shader | da | oprit |
| 18 | Fum din coșul atelierului | pufuri care urcă și se lățesc în vânt | `_viata_v4()` | 10 particule | **nu** | nu |
| 19 | Scântei / licurici | la portal și sub copacul mare | `_viata_v4()` | 26 particule aditive | **nu** | nu |
| 20 | Fluturi și păsări | fluturii lângă drum, păsările departe | `_viata()` | 6 + 3 obiecte mici (max 10) | da | opriți |
| 21 | Petale și frunze purtate de vânt | plutesc în direcția vântului | `_viata()` | 26 + 12 particule (max 40) | 13 + 6 | nu |
| 22 | Pești în lagună | sar din când în când (5–6 s), cu un val la ieșire și la intrare | `_misca_pesti()` | 2 obiecte + 2 pătrate | da | nu |
| 23 | Căsuțele speciale | inelul luminos pulsează; la aterizare: undă, aprindere, turtire | `casuta.gd`, `casuta_semn.gdshader` | doar shader | da | fără undă și turtire |

**Cadrele de verificare** (camera de joc nouă, aproape, panoramă): în fiecare se văd peste 8 dintre elementele de mai
sus mișcându-se continuu (iarba și florile în vânt, coroanele, felinarele, cristalele, norii și umbrele lor, petalele,
fluturii; în panoramă și apa, cascadele, moara, barca cu valurile ei, insulițele, portalul). Elementele 1, 2, 5–17 nu
se opresc niciodată, deci nu există interval de 2 secunde „înghețat”; peștii (22) se adaugă din câteva în câteva secunde.

**Particule în total** (Mediu/Mare): ceață ≈ 38, stropi ≈ 28, fum 10, scântei 26, petale + frunze 38, deci ≈ 140
(plafonul cerut: ~300). La Mic: doar petalele și frunzele, 19.

Notă: tabelul descrie ce face codul. Nu am putut rula Godot cu randare aici; numărul real de triunghiuri, apeluri de
desenare și FPS-ul le arată scena de test (`godot/test/test_insula.tscn`), sus, pe telefon.
