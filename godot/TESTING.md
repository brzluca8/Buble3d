# TESTING – instalarea versiunii de test pe telefon (Android)

## 1. Instalare APK

Fișierul: `buble-test.apk` (versiunea 0.2.0-test, pachet `ro.buble.test`, arm64, semnat cu cheie de test).

1. Copiază APK-ul pe telefon (cablu USB, Google Drive, e-mail).
2. Deschide-l din aplicația **Fișiere**. Android cere permisiunea „Instalează aplicații necunoscute" pentru
   aplicația din care îl deschizi: **Setări → Permite din această sursă**.
3. Apasă **Instalează**. Dacă Play Protect avertizează (aplicație de test, nesemnată pentru Magazin Play),
   alege **Instalează oricum**.
4. Pornește **Buble**. Prima pornire durează câteva secunde (compilarea shaderelor).

Cu cablu și „Depanare USB" activată: `adb install -r buble-test.apk`.

Cerințe: Android 8+ cu procesor pe 64 de biți (arm64). Randarea folosește Vulkan, cu trecere automată pe OpenGL ES 3.

## 2. Ce să testezi (5–10 minute)

1. **Mașina de bule**: Rotește de 20–30 de ori. Rolele accelerează și frânează? Sunet și vibrație? La câștiguri mari
   apar scântei? Butonul **?** arată șansele?
2. **Atac și raid**: când pică ciocanul / lopata, se deschide orașul țintei. Eticheta roșie „Țintă de antrenament –
   nu este un jucător real" trebuie să fie vizibilă. Atinge o clădire (atac) sau 3 locuri (raid).
3. **Construcție**: atinge o clădire din glob → **Construiește**. Fundația devine clădire, cu animație.
   De la nivelul 6 apar schele și timer.
4. **Nivelurile 1–5** ar trebui atinse în prima sesiune; multiplicatorul (×1…×5) se deblochează la nivelul 5.
5. **Cufere** (cele 3 sloturi sus), **rezervorul** (iconița portofel), **seria zilnică** (calendarul).
6. **Dirijabilul** (meniul de jos): Observator (abilități), Garderobă (poartă o piesă), Atelier, Seră, Salon.
7. **Setări**: Calitate Mic / Mediu / Mare – notează diferența de fluiditate; sunet, vibrație, notificări.

## 3. Ce să notezi

- Fluiditate (FPS) pe Mediu și pe Mic. Activează în Opțiuni dezvoltator „Afișează rata de reîmprospătare"
  sau folosește un contor de FPS. Ținta: 60 pe Mediu.
- Încălzirea telefonului după 10 minute, bateria.
- Texte tăiate sau suprapuse, butoane prea mici.
- Momentul în care ți se pare că jocul devine lent (nivel, minut).

## 4. Datele de analiză (local)

Jocul scrie evenimentele în `user://analytics.jsonl` (pe Android: `/data/data/ro.buble.test/files/analytics.jsonl`,
accesibil cu `adb shell run-as ro.buble.test cat files/analytics.jsonl`). Nimic nu pleacă de pe telefon.

## 5. Construirea APK-ului (pe calculator)

1. Godot 4.7 → **Editor → Manage Export Templates → Download and Install**.
2. **Editor Settings → Export → Android**: calea spre Android SDK (din Android Studio) și JDK 17,
   plus un keystore de debug (Godot îl poate genera).
3. **Project → Export → Android (test) → Export Project** (presetul e în `export_presets.cfg`).

Pentru Magazin Play: export `.aab` cu „Use Gradle Build", keystore de release (nu se pune în git) și versiune nouă.

## 6. Notificări locale

Opțiunea din Setări calculează notificările (energie plină, cufăr gata, max. 2 pe zi), dar pe Android afișarea
cere un plugin de notificări locale (Android plugin v2, cu Gradle build). Fără plugin nu apare nimic.
