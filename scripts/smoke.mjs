// Test de fum: pornește `vite preview`, deschide jocul la dimensiune de telefon, verifică erorile din consolă,
// că scena se desenează, selectarea unei clădiri, upgrade-ul și Buble Blast. Salvează capturi în smoke-*.png.
// Rulare: npm run build && npm run smoke
import { createRequire } from 'node:module';
import { spawn } from 'node:child_process';
const require = createRequire(import.meta.url);
const { chromium } = require('playwright');

const PORT = 4179;
const srv = spawn('npx', ['vite', 'preview', '--port', String(PORT), '--strictPort'], { stdio: 'pipe' });
await new Promise((r) => { srv.stdout.on('data', (d) => /Local/.test(d) && r()); setTimeout(r, 8000); });

const browser = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
const page = await browser.newPage({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 1, hasTouch: true });
const errors = [];
page.on('pageerror', (e) => errors.push(e.message));
page.on('console', (m) => { if (m.type() === 'error' || m.type() === 'warning') errors.push(`[${m.type()}] ${m.text()}`); });
const fail = async (msg) => { console.error('EȘEC:', msg, errors); await browser.close(); srv.kill(); process.exit(1); };

try {
  await page.goto(`http://localhost:${PORT}/`);
  await page.waitForFunction(() => window.renderer?.info.render.calls > 0, null, { timeout: 20000 });
  await page.waitForTimeout(1500);
  const info = await page.evaluate(() => ({ calls: renderer.info.render.calls, tris: renderer.info.render.triangles, geo: renderer.info.memory.geometries, tex: renderer.info.memory.textures }));
  await page.screenshot({ path: 'smoke-insula.png' });

  // atinge palatul: proiectăm poziția lui pe ecran
  const pos = await page.evaluate(() => {
    let p = null; scene.traverse((o) => { if (o.userData?.id === 'palat') p = o; });
    const v = p.getWorldPosition(p.position.clone()); v.y += 2; v.project(window.camera);
    return [Math.round((v.x + 1) / 2 * innerWidth), Math.round((1 - v.y) / 2 * innerHeight)];
  });
  await page.mouse.click(pos[0], pos[1]);
  await page.waitForTimeout(800);
  const sheet = await page.evaluate(() => !document.getElementById('sheet').hidden && document.getElementById('sheet').innerText);
  await page.screenshot({ path: 'smoke-selectie.png' });

  // Buble Blast
  await page.click('#blast');
  await page.waitForTimeout(400);
  for (let i = 0; i < 3; i++) { await page.mouse.click(120 + i * 70, 400); await page.waitForTimeout(700); }
  await page.screenshot({ path: 'smoke-blast.png' });
  const blast = await page.evaluate(() => document.getElementById('bc').width);
  await page.click('#bx');
  await page.waitForTimeout(300);

  // upgrade: primul nivel al palatului costă 150, iar jocul pornește cu 300 de monede
  await page.keyboard.press('Escape');
  await page.mouse.click(pos[0], pos[1]);
  await page.waitForTimeout(500);
  await page.click('#up');
  await page.waitForTimeout(1200);
  const upgraded = await page.evaluate(() => JSON.parse(localStorage.getItem('buble3d')).b.palat);
  if (upgraded !== 2) await fail('upgrade-ul nu a funcționat: nivel ' + upgraded);
  await page.screenshot({ path: 'smoke-upgrade.png' });

  // model GLB opțional (argument): se încarcă prin panoul „Modele 3D” pentru mascotă
  let glb = null;
  if (process.argv[2]) {
    await page.click('#mdl');
    await page.setInputFiles('input[data-k="mascot"]', process.argv[2]);
    await page.waitForTimeout(1000);
    glb = await page.evaluate(() => { let n = 0; scene.traverse((o) => { if (o.name === 'glb') n++; }); return n; });
    await page.click('#mx');
    await page.reload();
    await page.waitForFunction(() => window.renderer?.info.render.calls > 0, null, { timeout: 20000 });
    await page.waitForTimeout(1000);
    const after = await page.evaluate(() => { let n = 0; scene.traverse((o) => { if (o.name === 'glb') n++; }); return n; });
    if (glb !== 1 || after !== 1) await fail(`GLB: încărcat=${glb}, după reîncărcare=${after}`);
    await page.screenshot({ path: 'smoke-glb.png' });
  }

  console.log(JSON.stringify({ info, sheet, blastCanvas: blast, upgraded, glb, errors }, null, 2));
  if (errors.length) await fail('erori în consolă');
  if (!(info.calls > 0)) await fail('scena nu se desenează');
} catch (e) { await fail(e.message); }
await browser.close(); srv.kill();
