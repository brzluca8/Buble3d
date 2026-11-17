// Modele GLB: înlocuiesc piesele procedurale. Ordinea: fișier încărcat de jucător (IndexedDB)
// > public/models/<id>.glb > varianta procedurală.
import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { MeshoptDecoder } from 'three/addons/libs/meshopt_decoder.module.js';
import { $, toast } from './state.js';
import { GB, ms } from './world.js';

const GL = new GLTFLoader().setMeshoptDecoder(MeshoptDecoder); // Meshopt: fără fișiere decoder externe
export const HT = { palat: 5.5, obs: 4.5, turn: 5.3, mag: 3, sera: 3, mascot: 1.6 }; // înălțimi țintă
const NM = { palat: 'Palat', obs: 'Observator', turn: 'Turn', mag: 'Magazin', sera: 'Seră', mascot: 'Mascotă' };
const FILE = { palat: 'palat', obs: 'obs', turn: 'turn', mag: 'mag', sera: 'sera', mascot: 'mascot' };

// ---- IndexedDB ----
let dbp = null;
const idb = () => dbp ||= new Promise((r) => {
  try { const q = indexedDB.open('buble3d', 1); q.onupgradeneeded = () => q.result.createObjectStore('m'); q.onsuccess = () => r(q.result); q.onerror = () => r(null); }
  catch { r(null); }
});
async function idbSet(k, v) { const d = await idb(); if (d) try { d.transaction('m', 'readwrite').objectStore('m').put(v, k); } catch { /* ignorat */ } }
async function idbDel(k) { const d = await idb(); if (d) try { d.transaction('m', 'readwrite').objectStore('m').delete(k); } catch { /* ignorat */ } }
async function idbGet(k) {
  const d = await idb(); if (!d) return null;
  return new Promise((r) => { try { const q = d.transaction('m').objectStore('m').get(k); q.onsuccess = () => r(q.result); q.onerror = () => r(null); } catch { r(null); } });
}

const target = (k) => (k === 'mascot' ? ms : GB[k]);
const isGlb = (buf) => buf && buf.byteLength > 12 && new TextDecoder().decode(new Uint8Array(buf, 0, 4)) === 'glTF';

function applyModel(k, buf, silent) {
  if (!isGlb(buf)) { if (!silent) toast('Fișier GLB invalid'); return Promise.resolve(false); }
  return new Promise((res) => GL.parse(buf, '', (gl) => {
    const t = target(k), m = gl.scene;
    const bb = new THREE.Box3().setFromObject(m), sz = bb.getSize(new THREE.Vector3());
    m.scale.setScalar(HT[k] / Math.max(sz.y, .001));
    bb.setFromObject(m);
    const c = bb.getCenter(new THREE.Vector3());
    m.position.set(-c.x, -bb.min.y, -c.z); // centrat, așezat pe sol
    m.traverse((o) => { if (o.isMesh) o.castShadow = o.receiveShadow = true; });
    const w = new THREE.Group(); w.name = 'glb'; w.add(m);
    const old = t.getObjectByName('glb'); if (old) t.remove(old);
    t.children.forEach((o) => { if (o !== t.ex) o.visible = false; });
    t.add(w);
    res(true);
  }, () => { if (!silent) toast('Fișier GLB invalid'); res(false); }));
}

async function resetModel(k) {
  const t = target(k), old = t.getObjectByName('glb');
  if (old) t.remove(old);
  t.children.forEach((o) => { o.visible = true; });
  await idbDel(k);
  await loadDefault(k);
  toast(NM[k] + ': model implicit restabilit');
}

// public/models/<id>.glb, doar dacă este trecut în public/models/manifest.json
// (evită cereri 404 pentru modelele care încă nu există).
let manifest = null;
const getManifest = () => manifest ||= fetch('./models/manifest.json', { cache: 'no-cache' })
  .then((r) => (r.ok ? r.json() : [])).then((a) => new Set(Array.isArray(a) ? a : [])).catch(() => new Set());
async function loadDefault(k) {
  if (!(await getManifest()).has(FILE[k])) return false;
  try {
    const r = await fetch(`./models/${FILE[k]}.glb`);
    if (r.ok) return applyModel(k, await r.arrayBuffer(), true);
  } catch { /* lipsă: rămâne varianta procedurală */ }
  return false;
}

export function initModels() {
  $('mdl').onclick = () => {
    $('md').hidden = false;
    $('mb').innerHTML = '<h2>Modele 3D</h2><p>Alege un fișier .glb pentru fiecare piesă. Modelul înlocuiește varianta procedurală și rămâne salvat pe telefon.</p>' +
      Object.keys(NM).map((k) => `<div class="row"><span>${NM[k]}</span><span><input type="file" accept=".glb,model/gltf-binary" data-k="${k}"> <button data-r="${k}" aria-label="Resetează ${NM[k]}">↺</button></span></div>`).join('');
    $('mb').querySelectorAll('input').forEach((i) => i.onchange = async () => {
      const f = i.files[0]; if (!f) return;
      const b = await f.arrayBuffer(), k = i.dataset.k;
      if (await applyModel(k, b)) { idbSet(k, b); toast(NM[k] + ': model încărcat'); }
    });
    $('mb').querySelectorAll('[data-r]').forEach((b) => b.onclick = () => resetModel(b.dataset.r));
  };
  Object.keys(NM).forEach(async (k) => {
    const b = await idbGet(k);
    if (!(b && await applyModel(k, b, true))) await loadDefault(k);
  });
}
