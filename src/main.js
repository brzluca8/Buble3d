// Punctul de intrare: camera orbitală, selectarea clădirilor, interfața și bucla de joc.
import * as THREE from 'three';
import { $, B, S, MAX_LVL, save, sum, cost, toast, upd, offlineIncome } from './state.js';
import { R, sc, cam, isl, GB, bg, gem, dg, dp, ms, mouth, sr, sp, burst, clouds, far, applyLvl, mas } from './world.js';
import { initBlast, stepBlast, blastOpen } from './blast.js';
import { initModels } from './models.js';

// ---------- camera orbitală: tragere = rotire, ciupire/rotiță = zoom, atingere = selectare ----------
let th = .15, ph = .95, dist = innerWidth < innerHeight ? 34 : 26;
const tg = new THREE.Vector3(0, .5, 0);
const P = new Map();
let dr = 0, pd = 0;
const cv = $('c');
const pdist = () => { const a = [...P.values()]; return Math.hypot(a[0][0] - a[1][0], a[0][1] - a[1][1]); };
const clampDist = (d) => Math.max(16, Math.min(52, d));
cv.addEventListener('pointerdown', (e) => { cv.setPointerCapture(e.pointerId); P.set(e.pointerId, [e.clientX, e.clientY]); dr = 0; if (P.size === 2) pd = pdist(); });
cv.addEventListener('pointermove', (e) => {
  const o = P.get(e.pointerId); if (!o) return;
  const dx = e.clientX - o[0], dy = e.clientY - o[1];
  P.set(e.pointerId, [e.clientX, e.clientY]);
  if (P.size === 1) { th -= dx * .006; ph = Math.max(.6, Math.min(1.3, ph - dy * .004)); dr += Math.abs(dx) + Math.abs(dy); }
  else if (P.size === 2) { const d = pdist(); if (d > 0) dist = clampDist(dist * pd / d); pd = d; dr += 9; }
});
cv.addEventListener('pointerup', (e) => { if (P.size === 1 && dr < 8) pick(e.clientX, e.clientY); P.delete(e.pointerId); });
cv.addEventListener('pointercancel', (e) => P.delete(e.pointerId));
cv.addEventListener('wheel', (e) => { e.preventDefault(); dist = clampDist(dist * (1 + e.deltaY * .001)); }, { passive: false });

// ---------- selectare + upgrade ----------
const rc = new THREE.Raycaster();
let sel = null;
function pick(x, y) {
  rc.setFromCamera(new THREE.Vector2(x / innerWidth * 2 - 1, -(y / innerHeight) * 2 + 1), cam);
  const h = rc.intersectObjects(bg, true);
  sel = null;
  if (h.length) { let o = h[0].object; while (o && !o.userData.id) o = o.parent; if (o) sel = B.find((b) => b.id === o.userData.id); }
  sr.visible = !!sel;
  if (sel) { sr.position.set(sel.x, .1, sel.z); mas.t.set(sel.x + (sel.x > 0 ? -1.9 : 1.9), 0, sel.z + 2.5); mas.j = .5; }
  showSheet();
}
function showSheet() {
  const sh = $('sheet');
  $('title').style.opacity = sel ? 0 : 1;
  if (!sel) { sh.hidden = true; return; }
  const l = S.b[sel.id], cs = cost(sel), lack = S.coins < cs;
  sh.hidden = false;
  sh.innerHTML = `<div class="sh1"><b>${sel.n}</b><span>Nivel ${l}/${MAX_LVL}</span></div><div class="pips">${'●'.repeat(l)}${'○'.repeat(MAX_LVL - l)}</div>` +
    (l >= MAX_LVL ? '<div class="mx">✨ Nivel maxim atins</div>'
      : `<button id="up" class="${lack ? 'dis' : ''}">Îmbunătățește · 🪙 ${cs}</button>` + (lack ? `<small>Îți mai trebuie ${Math.ceil(cs - S.coins)} monede. Joacă Buble Blast!</small>` : ''));
  const u = $('up'); if (u) u.onclick = upgrade;
}
function upgrade() {
  const b = sel; if (!b) return;
  const cs = cost(b);
  if (S.b[b.id] >= MAX_LVL || S.coins < cs) return;
  S.coins -= cs; S.b[b.id]++; S.xp += 40; S.mis.up = 1;
  const g = GB[b.id]; applyLvl(g, b.id); g.userData.a = 0;
  burst(b.x, b.z); mas.j = 1;
  toast(b.n + ' a ajuns la nivelul ' + S.b[b.id] + ' ✨');
  save(); upd(); showSheet();
}

// ---------- ecrane ----------
$('mis').onclick = () => toast(`${S.mis.up ? '✅' : '⬜'} Îmbunătățește o clădire  •  ${S.mis.blast ? '✅' : '⬜'} Joacă Buble Blast`, 3500);
const MD = {
  album: '<h2>Album</h2><span class="demo">DEMO – fără server</span><p>Colecția de cărți se va debloca din Buble Blast și evenimente. Schimburile necesită conturi online.</p><div class="grid">' + '<div>🔒</div>'.repeat(12) + '</div>',
  friends: '<h2>Prieteni</h2><span class="demo">DEMO – fără server</span><p>Prietenii, vizitarea insulelor și duelurile necesită cont și backend. În această versiune nu există alți jucători.</p><div class="row"><span>Invită un prieten</span><span>În curând</span></div><div class="row"><span>Vizitează o insulă</span><span>În curând</span></div>',
  events: '<h2>Evenimente</h2><span class="demo">DEMO – fără server</span><p>Expediția celor patru: eveniment cooperativ pentru 4 persoane.</p><div class="grid">' + '<div style="font-size:12px">Liber</div>'.repeat(4) + '</div><div class="row"><span>Clasament cluburi</span><span>În curând</span></div>',
  shop: '<h2>Magazin</h2><span class="demo">DEMO – plăți dezactivate</span><div class="row"><span>🪙 Pachete de monede</span><span>În curând</span></div><div class="row"><span>👑 Abonament VIP</span><span>În curând</span></div><div class="row"><span>🎟️ Season Pass</span><span>În curând</span></div>',
};
const navs = document.querySelectorAll('nav button');
const setNav = (i) => navs.forEach((x, j) => x.classList.toggle('on', j === i));
navs.forEach((b, i) => b.onclick = () => { setNav(i); const m = b.dataset.m; $('md').hidden = m === 'home'; if (m !== 'home') $('mb').innerHTML = MD[m]; });
$('mx').onclick = () => { $('md').hidden = true; setNav(0); };

initBlast(() => { mas.j = 1; showSheet(); });
initModels();

// ---------- bucla de joc ----------
const timer = new THREE.Timer();
timer.connect(document); // fără salt uriaș de timp după ce tab-ul revine
let T = 0;
const v3 = new THREE.Vector3();
R.setAnimationLoop(() => {
  timer.update();
  const dt = Math.min(Math.max(timer.getDelta(), 0), .05);
  T += dt;
  if (blastOpen()) { stepBlast(dt); return; } // insula nu se randează cât timp mini-jocul e deschis

  cam.position.set(tg.x + dist * Math.sin(ph) * Math.sin(th), tg.y + dist * Math.cos(ph), tg.z + dist * Math.sin(ph) * Math.cos(th));
  cam.lookAt(tg);
  isl.position.y = Math.sin(T * .8) * .15;
  gem.rotation.y = T; gem.position.y = 2 + Math.sin(T * 2) * .08;
  clouds.forEach((c) => { c.position.x += dt * .5; if (c.position.x > 40) c.position.x = -40; });
  far.forEach((f, i) => { f.position.y += Math.sin(T + i) * .003; });

  // fântână (k=0) și cascade (k=1)
  const pa = dg.attributes.position;
  dp.forEach((d, i) => {
    if (d.k === 0) { const u = (T * .5 + d.p) % 1; pa.setXYZ(i, Math.cos(d.a) * 1.25 * u, 1.95 + 2.2 * u * (1 - u) - 1.4 * u * u, .3 + Math.sin(d.a) * 1.25 * u); }
    else { const u = (T * .9 + d.p) % 1; pa.setXYZ(i, d.x, .05 - 4.4 * u, d.z); }
  });
  pa.needsUpdate = true;

  // animație elastică la upgrade
  bg.forEach((g) => {
    const u = g.userData; if (u.a >= 1) return;
    u.a = Math.min(1, u.a + dt / .9);
    const t = u.a - 1, e = 1 + 2.7 * t ** 3 + 1.7 * t * t;
    g.scale.set(u.base * (.8 + .2 * e), u.base * (.5 + .5 * e), u.base * (.8 + .2 * e));
  });
  for (let i = sp.length - 1; i >= 0; i--) {
    const m = sp[i];
    m.v.y -= 9 * dt; m.position.addScaledVector(m.v, dt); m.l -= dt * 1.2; m.scale.setScalar(Math.max(m.l, 0));
    if (m.l <= 0) { isl.remove(m); sp.splice(i, 1); }
  }
  if (sr.visible) sr.scale.setScalar(1 + Math.sin(T * 4) * .05);

  // mascota merge spre clădirea aleasă și sare
  v3.subVectors(mas.t, ms.position); v3.y = 0;
  const mv = v3.length() > .1, k = Math.min(1, dt * 2.2);
  ms.position.x += v3.x * k; ms.position.z += v3.z * k;
  const wantR = mv ? Math.atan2(v3.x, v3.z) : 0;
  let dR = wantR - mas.ry; dR = Math.atan2(Math.sin(dR), Math.cos(dR)); // cel mai scurt drum
  mas.ry += dR * Math.min(1, dt * 5); ms.rotation.y = mas.ry;
  let y = mv ? Math.abs(Math.sin(T * 10)) * .12 : Math.sin(T * 2) * .03;
  if (mas.j > 0) { y += Math.sin((1 - mas.j) * Math.PI) * 1.2; mas.j -= dt * 1.4; }
  ms.position.y = y; mouth.scale.y = .5 + Math.max(mas.j, 0) * 1.5;

  R.render(sc, cam);
});

// ---------- economie ----------
setInterval(() => { S.coins += sum(); upd(); save(); }, 10000);
const ga = offlineIncome();
if (ga) setTimeout(() => toast('Bine ai revenit! Insula a produs 🪙 ' + ga), 600);
addEventListener('visibilitychange', () => { if (document.hidden) save(); });
upd(); save();

Object.assign(window, { renderer: R, scene: sc, camera: cam }); // pentru testul automat și depanare în consolă
