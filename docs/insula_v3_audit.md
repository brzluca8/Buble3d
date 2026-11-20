# Insula 1, v3: audit (Pasul 0, fără modificări)

Ramura `orion-insula-v3`, pornită din `orion-insula-v2`.

Măsurat pe:
- `godot/assets/models/insula1/insula1.glb`, insula din jocul pe care l-ai rulat;
- `godot/assets/models/orion.glb`.

Scripturile sunt `blender/insula1/audit.py` (cifrele) și `blender/insula1/audit_checker.py` (captura).

Capturile tale din Godot sunt în `reference/captura_godot_1_start.jpg` și `reference/captura_godot_2_aproape.jpg`. Ele arată ce NU vrem.

**Godot n-a putut fi pornit aici.** Am descărcat versiunea oficială 4.7.1, cu suma de control verificată, dar sistemul de permisiuni a blocat rularea (motiv: „Undermining Oversight”). Toate cifrele de mai jos vin din fișiere, iar capturile mele sunt randate în Blender. Cifrele din Godot (triunghiuri, apeluri de desenare, FPS) vin din scena de test pe care o rulezi tu pe telefon.

## Texturi și densitate

| | Insula | Orion |
|---|---|---|
| texturi | albedo 4096² (JPEG), ORM 2048² (JPEG); apa și cascadele n-au texturi în GLB (shaderul de apă folosește `apa_normal.png`, 512²) | culoare 2048², metal/rugozitate 2048², emisie 2048², ochi 1024×512 (culoare + metal/rugozitate) |
| dimensiuni | 18,9 × 23,1 m, 12,7 m înălțime | 0,9 × 1,08 m, 1,2 m înălțime |
| suprafață totală (toate fețele) | 3.011 m² | 12,7 m² |
| **px/m după formula ta** (latura texturii ÷ mărimea modelului) | 4096 ÷ 23,1 m ≈ **177** | 2048 ÷ 1,2 m ≈ **1.707** (cu 1,15 m: 1.781) |
| **px/m pe suprafață** (√(pixeli din textură ÷ m² de suprafață), ponderat cu aria) | **56,5** | **463** |

Estimarea ta se confirmă: după formula ta, Orion are ~1.800 px/m, iar insula sub 200. Raportul e de **~10 ori**.

Pe suprafața efectivă, raportul e de **8,2 ori**, pentru că Orion are puțină suprafață pe care să-și întindă textura.

Insula originală din Tripo avea 28 px/m pe suprafață. Textura mărită cu AI a dublat valoarea.

**Cum sunt împărțiți pixelii insulei** (măsurat pe textura originală, cu aceleași UV-uri):
- 10,6% merg pe fețele de sus spre cer, ce vede camera;
- 32% pe pereți;
- 19% pe stânci;
- 24% pe partea de dedesubt;
- 18,5% pe fețe întoarse în jos.

Atlasul are **20.913 insule UV** și folosește 55,4% din textură.

## Geometrie

| | Insula | Apa | Cascade | Orion |
|---|---:|---:|---:|---:|
| triunghiuri | 194.156 | 1.215 | 1.076 | 188.474 |
| vârfuri (sudate pe poziție) | 206.033 (92.616) | 961 | 685 | 176.525 (89.130) |
| materiale | 1 (`insula1`) | 1 (`apa`) | același | 2 |
| componente conectate (după sudare) | 165, din care 100 sub 20 de triunghiuri; cea mai mare are 188.072 (97%) | 11 | 8 | 120 |
| triunghiuri degenerate (arie ~0) | 4 | 0 | 0 | 17 |
| **fețe cu normala opusă sensului de desenare** | **4.804 (16,9 m²)** | 0 | 0 | 4.709 (0,04 m², foarte mici) |

**Total insulă:** 196.447 de triunghiuri, 3 mesh-uri, 2 materiale. **Cu Orion:** ~385 de mii. Asta e peste ținta de ~250 de mii.

**Concluzie pentru segmentare:** aproape tot e o singură bucată conectată, inclusiv clădiri, copaci, barcă și moară. Părțile nu se pot separa după componente. Trebuie clasificate după culoarea texturii, poziție și normală (A3).

## Indicii pentru artefactele negre (A1)
- **Fețele cu normala inversată:**
  - sunt 4.804;
  - 89% sunt pe partea de sus a insulei;
  - sunt mici: 0,0035 m² în medie, față de 0,015 m² la toate fețele;
  - stau pe frunze (1.160), flori (241), muchii de stâncă (1.059) și altele.

  Insula se desenează pe ambele fețe. Pentru o față văzută „din spate” după sensul de desenare, Godot întoarce normala. Dacă normala din fișier era deja spre cameră, după întoarcere ajunge cu spatele la lumină, deci fața iese întunecată.

  Harta lor, colorate cu roșu din camera de joc, se potrivește cu petele negre din captura ta: margini de acoperiș, frunze, flori. Imaginea e `docs/shots/insula_v3_audit_fete_inversate.png`.
- **Spațiile dintre insulele UV** nu sunt întunecate: luminozitatea medie e 0,47 și 0% din pixeli sunt aproape negri. Deci culoarea nu se scurge din margini.
- **Triunghiuri degenerate:** doar 4.
- **Umbra pe propria suprafață** (shadow acne) n-o pot verifica fără Godot. Scena de test are un comutator pentru umbre.

## Setări (din proiect și cele implicite din Godot)
- **Proiect** (`project.godot`):
  - randare „mobile” (Vulkan);
  - MSAA 3D 2×;
  - compresie ETC2/ASTC la import, activă;
  - filtrare anizotropă: valoarea implicită din Godot (4×), pentru că proiectul nu o setează.
- **Shaderul insulei** citește textura cu `filter_linear_mipmap_anisotropic`, adică folosește mipmap-uri și nivelul anizotrop din proiect.
- **Texturile din GLB:** Godot le extrage la primul import, ca fișiere separate, cu setările implicite: mipmap-uri, compresie pentru 3D. În repository nu există fișiere `.import`, așa că telefonul le creează la prima deschidere.

## Captura cu tablă de șah
`docs/shots/insula_v3_audit_checker.png` e randată în Blender, nu în Godot. Pe ambele modele, fiecare pătrat are 32 px din textura proprie.
- Pe insulă, un pătrat are cam 0,6 m; pe Orion, câțiva centimetri.
- Pe stânci și pe margini, pătratele sunt alungite sau forfecate, adică textura e întinsă.
- Pe ambele modele se vede că atlasul e făcut din bucăți mici.
