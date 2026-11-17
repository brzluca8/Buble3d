# Orion în Blender

`orion_build.py` construiește mascota Orion de la zero și o randează în Cycles.

## Fișiere rezultate (`out/`)
| Fișier | Ce este |
|---|---|
| `orion.blend` | scena completă: corp, blană (Hair Curves), accesorii, lumini, cameră. Se deschide în **Blender 5.1+** |
| `orion_hero.png` | randare 3/4, ca în prezentare |
| `orion_face.png` | prim-plan pe față |
| `orion_turn_0..3.png` | vederi 360° (față, lateral, spate, lateral) |
| `orion_game.glb` | model ușor pentru joc (fără blană, culori pe vârfuri) |

## Cum e construit
1. **Corpul**: un câmp SDF (elipsoizi și conuri rotunjite unite lin) transformat în mesh prin marching cubes. Așa se obțin forme organice, ca sculptate, nu sfere lipite.
2. **Culorile**: pictate pe vârfuri: auriu cu spate mai închis, alb pe bot, obraji, piept și interiorul urechilor, pete, vârfuri negre la urechi și coadă, gură. Atributul `glow` marchează spirala turcoaz de pe coadă și emblemele de pe brațe.
3. **Blana**: aproximativ 260.000 de fire Hair Curves, cu lungime și direcție pe zone (obraji lungi și răsfirați, față scurtă, coadă stufoasă) și smocuri (clumping). Pe vârful urechilor sunt smocuri negre de râs.
4. **Fața**: ochi cu iris în gradient și pupilă (shader procedural), reflexii, gene, sprâncene, nas, gură deschisă cu colți, mustăți.
5. **Accesoriile**: ochelari de aviator din alamă, curea pe cap, eșarfă roșie cu nod și pelerină, medalion-busolă, centură, brățări cu cristale, rucsac cu hartă rulată, felinar cu lumină turcoaz.
6. **Lumina**: lumină principală caldă, lumini de contur reci în spate, Cycles cu denoising și bloom.

## Rulare
```bash
python -m venv bvenv && ./bvenv/bin/pip install bpy==5.1.2 scikit-image pillow
./bvenv/bin/python orion_build.py --out out --render hero,face,turn
# test rapid: --res 0.012 --fur 50000 --samples 24 --size 512
```
Parametri: `--res` (finețea corpului), `--fur` (număr de fire), `--samples`, `--size`, `--render hero,face,turn`, `--no-blend`, `--no-glb`.

## Ajustări rapide
Proporțiile sunt în secțiunea `# --- head` / `body` / `tail`: fiecare formă are centru și raze. Ca să schimbi mărimea urechilor, modifici `EAR_BASE`, `EAR_TIP` și raza `0.175`. Culorile sunt la `C_GOLD`, `C_SPOT` și restul constantelor din `# 2. colors`. Lungimea blănii pe zone se reglează în `fur_params()`.

## Pașii următori recomandați
- **Rig și animații**: în `orion.blend`, Rigify sau Mixamo pe `Orion_Body`, cu accesoriile legate de oase. Blana se leagă de corp prin *Surface* (Hair Curves → Surface = Orion_Body).
- **Pentru joc**: în `orion_game.glb` blana lipsește. Pentru aspect de blană pe telefon, se coace (bake) blana în texturi (Color + Normal + AO) pe un mesh retopologizat, plus 6–8 straturi de *shell fur* în Three.js.
- **Costume și skin-uri** (Pirat, Viking, Mag, Ametist, Aqua, Rubin): skin-urile se fac schimbând constantele de culoare și regenerând. Costumele sunt obiecte noi adăugate în secțiunea de accesorii.
