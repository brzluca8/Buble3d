// Starea jocului (economie + salvare). Fără Three.js aici, ca să poată fi testată fără GPU.
export const $ = (id) => document.getElementById(id);

export const B = [
  { id: 'palat', n: 'Palatul Norilor', x: 0, z: -4, b: 150 },
  { id: 'obs', n: 'Observatorul', x: -4.6, z: -1.2, b: 100 },
  { id: 'turn', n: 'Turnul Elegant', x: 4.6, z: -1.2, b: 100 },
  { id: 'mag', n: 'Magazinul', x: -4, z: 2.6, b: 80 },
  { id: 'sera', n: 'Sera de Cristal', x: 4, z: 2.6, b: 90 },
];
export const MAX_LVL = 5;
const KEY = 'buble3d';
const VERSION = 1;

const fresh = () => ({ v: VERSION, coins: 300, xp: 0, b: { palat: 1, obs: 1, turn: 1, mag: 1, sera: 1 }, t: 0, mis: { up: 0, blast: 0 } });

// Încarcă și validează: o salvare stricată nu trebuie să blocheze jocul.
function load() {
  const S = fresh();
  try {
    const s = JSON.parse(localStorage.getItem(KEY));
    if (s && typeof s === 'object') {
      if (Number.isFinite(s.coins)) S.coins = Math.max(0, s.coins);
      if (Number.isFinite(s.xp)) S.xp = Math.max(0, s.xp);
      if (Number.isFinite(s.t)) S.t = s.t;
      for (const b of B) {
        const l = s.b?.[b.id];
        if (Number.isInteger(l)) S.b[b.id] = Math.min(MAX_LVL, Math.max(1, l));
      }
      if (s.mis) S.mis = { up: s.mis.up ? 1 : 0, blast: s.mis.blast ? 1 : 0 };
    }
  } catch { /* salvare coruptă: pornim de la zero */ }
  return S;
}

export const S = load();

export function save() {
  S.t = Date.now();
  try { localStorage.setItem(KEY, JSON.stringify(S)); } catch { /* stocare indisponibilă */ }
}

export const sum = () => Object.values(S.b).reduce((a, b) => a + b, 0);
export const cost = (b) => Math.round(b.b * Math.pow(S.b[b.id], 1.7));
export const playerLvl = () => 1 + Math.floor(S.xp / 100);

export function toast(m, ms = 2200) {
  const t = $('toast');
  t.textContent = m;
  t.classList.add('on');
  clearTimeout(toast.h);
  toast.h = setTimeout(() => t.classList.remove('on'), ms);
}

export function upd() {
  $('coins').textContent = Math.floor(S.coins).toLocaleString('ro-RO');
  $('lvl').textContent = playerLvl();
  $('prog').textContent = sum() + '/' + B.length * MAX_LVL;
  $('xpf').style.width = (S.xp % 100) + '%';
}

// Venit offline: maximum o oră, 1 monedă / nivel de clădire / 10 s.
export function offlineIncome() {
  if (!S.t) return 0;
  const el = Math.min((Date.now() - S.t) / 1000, 3600);
  if (el <= 30) return 0;
  const ga = Math.floor((el / 10) * sum());
  S.coins += ga;
  return ga;
}
