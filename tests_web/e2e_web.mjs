// EMPIRE RUSH web/PWA end-to-end test on the REAL web export, in headless
// Chromium (WebGL 2 via SwiftShader), with an iPhone-sized touch viewport.
// Every action is a real touch tap on the canvas at a button's position
// (the game reports positions through its ?e2e=1 bridge; it never acts).
//
//   node tests_web/e2e_web.mjs build/web-public OUT_DIR
//
// Checks: boot without console errors, title -> intro -> setup -> match,
// roll + move + buy + owner updated, names not cut on the cards, settings
// and the match persist across a page reload (IndexedDB), resume, the PWA
// manifest + service worker, and a real offline reload (network cut).
// Exit code 0 only if every check passed. NOT a test on iPhone Safari.
import fs from 'node:fs';
import path from 'node:path';
import { chromium } from './pw.mjs';
import { serve } from './serve.mjs';

const root = path.resolve(process.argv[2] || 'build/web-public');
const out = path.resolve(process.argv[3] || 'web-e2e-out');
fs.mkdirSync(out, { recursive: true });
const PORT = 8765;
const URL = `http://127.0.0.1:${PORT}/index.html?e2e=1&seed=4`;
const results = [];
let failed = 0;
function check(ok, name, detail = '') {
  results.push({ ok: !!ok, name, detail });
  if (!ok) failed += 1;
  console.log(`${ok ? 'PASS' : 'FAIL'} ${name}${detail ? ' :: ' + detail : ''}`);
}

const server = await serve(root, PORT);
const browser = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
const iphone = { viewport: { width: 390, height: 844 }, deviceScaleFactor: 3, isMobile: true, hasTouch: true,
  userAgent: 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1' };
const ctx = await browser.newContext(iphone);
const page = await ctx.newPage();
const problems = [];
page.on('console', (m) => {
  const t = m.text();
  if (m.type() === 'error' || /SCRIPT ERROR|USER ERROR|GL_INVALID|WebGL: /.test(t)) problems.push(`${m.type()}: ${t}`);
});
page.on('pageerror', (e) => problems.push('pageerror: ' + e.message));
page.on('requestfailed', (r) => { if (!r.url().includes('favicon')) problems.push('requestfailed: ' + r.url()); });

async function boot(label) {
  const t0 = Date.now();
  await page.goto(URL);
  await page.waitForFunction(() => window.__empireRushStarted === true && window.erE2E, null, { timeout: 240000 });
  await page.waitForTimeout(1500);
  return Date.now() - t0;
}
const state = async () => JSON.parse(await page.evaluate(() => { window.erE2E.state(); return window.erE2EResult; }));
async function rectOf(id) {
  const r = await page.evaluate((i) => { window.erE2E.rect(i); return window.erE2EResult; }, id);
  if (!r || r === 'null') return null;
  const f = JSON.parse(r);
  const c = await page.evaluate(() => { const b = document.getElementById('canvas').getBoundingClientRect(); return [b.x, b.y, b.width, b.height]; });
  return { x: c[0] + (f[0] + f[2] / 2) * c[2], y: c[1] + (f[1] + f[3] / 2) * c[3], w: f[2] * c[2], h: f[3] * c[3] };
}
async function waitRect(id, ms = 60000) {
  const t0 = Date.now();
  while (Date.now() - t0 < ms) {
    const r = await rectOf(id);
    if (r) return r;
    await page.waitForTimeout(250);
  }
  return null;
}
async function tap(id, ms = 60000) {
  const r = await waitRect(id, ms);
  if (!r) return false;
  await page.touchscreen.tap(r.x, r.y);
  await page.waitForTimeout(700);
  return true;
}
async function waitState(pred, ms = 120000) {
  const t0 = Date.now();
  let s = null;
  while (Date.now() - t0 < ms) {
    s = await state();
    if (pred(s)) return s;
    await page.waitForTimeout(300);
  }
  return s;
}
async function closeCoach() {
  // Contextual tips may show over the board; the player reads and taps ĐÃ HIỂU.
  for (let i = 0; i < 3; i += 1) {
    if (!(await rectOf('coach:ok'))) return;
    await tap('coach:ok', 2000);
  }
}
const shot = (name) => page.screenshot({ path: path.join(out, name + '.png') });

try {
  // 1. Boot.
  const ms = await boot('first');
  check(true, 'web export boots in Chromium (iPhone viewport 390x844, touch)', `${ms} ms to the title`);
  await shot('01_title_portrait');
  const s0 = await state();
  check(s0.page === 'title', 'title screen shown', s0.page);
  check(await page.evaluate(() => !!document.createElement('canvas').getContext('webgl2')), 'WebGL 2 available');

  // 2. PWA files.
  const manifest = await (await page.request.get(`http://127.0.0.1:${PORT}/index.manifest.json`)).json();
  check(manifest.name === 'EMPIRE RUSH' && manifest.display === 'standalone', 'manifest: name EMPIRE RUSH, display standalone', JSON.stringify({ name: manifest.name, display: manifest.display, start_url: manifest.start_url }));
  check(manifest.icons.some((i) => i.sizes === '512x512') && manifest.icons.some((i) => i.sizes === '180x180'), 'manifest icons 180 and 512');
  const head = await page.evaluate(() => ({
    touch: !!document.querySelector('link[rel="apple-touch-icon"]'),
    manifest: !!document.querySelector('link[rel="manifest"]'),
    capable: document.querySelector('meta[name="apple-mobile-web-app-capable"]')?.content,
    hint: getComputedStyle(document.getElementById('install-hint')).display,
  }));
  check(head.touch && head.manifest && head.capable === 'yes', 'iOS meta: apple-touch-icon, manifest link, web-app-capable');
  check(head.hint === 'block', 'iOS Safari (not installed) sees the "Thêm vào MH chính" hint');
  await page.evaluate(() => document.getElementById('install-hint-close').click());

  // 3. Title -> intro -> setup (touch).
  check(await tap('menu:title_play'), 'tap CHƠI');
  let s = await state();
  if (s.page === 'intro') {
    await shot('02_intro');
    check(await tap('menu:intro_skip'), 'tap BỎ QUA on the intro');
  }
  s = await waitState((x) => x.page === 'setup', 20000);
  check(s.page === 'setup', 'setup page', s.page);
  await page.waitForTimeout(1500);  // page fade-in and layout settle, as a person would wait
  check(await tap('menu:persona_ha'), 'tap persona Thu Hà');
  check(await tap('menu:players_2'), 'tap 2 players');
  await shot('03_setup');
  s = await state();
  check(s.setup.persona === 'ha' && s.setup.players === 2, 'choices registered', JSON.stringify(s.setup));
  check(await tap('menu:start'), 'tap BẮT ĐẦU');
  s = await waitState((x) => x.in_match, 30000);
  check(s.in_match, 'match started');

  // 4. A real turn: roll, move, buy, owner.
  await closeCoach();
  check(!!(await waitRect('hud:RollDice', 90000)), 'roll button offered');
  await shot('04_roll_ready');
  const cash0 = s.cash[0];
  check(await tap('hud:RollDice'), 'tap ĐỔ XÚC XẮC');
  await page.waitForTimeout(600);
  await shot('05_dice');
  s = await waitState((x) => x.idle && x.seat === 0 && x.phase !== 'AwaitRoll', 60000);
  check(s.phase !== 'AwaitRoll', 'dice rolled and pawn moved', s.phase);
  await closeCoach();
  if (s.phase === 'AwaitBuyDecision') {
    await shot('06_buy_prompt');
    check(await tap('hud:BuyProperty'), 'tap MUA');
    s = await waitState((x) => x.owned_by_human.length > 0 && x.idle, 30000);
    check(s.owned_by_human.length === 1 && s.cash[0] < cash0 + 400, 'property bought: owner updated, cash paid', JSON.stringify({ owned: s.owned_by_human, cash: s.cash[0] }));
  } else {
    check(true, 'no buy on this landing', s.phase);
  }
  await closeCoach();
  await shot('07_after_buy');
  const names = s.cards.map((c) => `${c.name}:${c.fits ? 'fits' : 'CUT'}`);
  check(s.cards.every((c) => c.fits), 'player names fit their cards', names.join(', '));
  if (await waitRect('hud:EndTurn', 30000)) check(await tap('hud:EndTurn'), 'tap KẾT THÚC LƯỢT');
  s = await waitState((x) => x.seat === 0 && x.phase === 'AwaitRoll' && x.idle, 120000);
  check(s.seat === 0 && s.phase === 'AwaitRoll', "bot played; the human's turn again (autosave point)", `round ${s.round}`);
  const owned = s.owned_by_human;
  check(s.saved_match && s.saved_round === s.round, 'match autosaved at this turn', `saved round ${s.saved_round}, log ${s.saved_log}`);
  const savedLog = s.saved_log;
  // Godot copies user:// to IndexedDB asynchronously; measure how long the
  // newest save takes to land there (what a reload or a killed tab sees).
  const idbLog = () => page.evaluate(() => new Promise((res) => {
    const rq = indexedDB.open('/userfs');
    rq.onerror = () => res(-2);
    rq.onsuccess = () => {
      let n = -1;
      const st = rq.result.transaction('FILE_DATA').objectStore('FILE_DATA');
      st.openCursor().onsuccess = (e) => {
        const c = e.target.result;
        if (!c) { res(n); return; }
        if (String(c.key).endsWith('/saved_match.json')) {
          try { n = JSON.parse(new TextDecoder().decode(c.value.contents)).input_log.length; } catch (_) {}
        }
        c.continue();
      };
    };
  }));
  const tIdb = Date.now();
  let inIdb = await idbLog();
  while (inIdb !== savedLog && Date.now() - tIdb < 20000) { await page.waitForTimeout(250); inIdb = await idbLog(); }
  if (process.env.E2E_IDB_KEYS) console.log(JSON.stringify(await page.evaluate(eval(fs.readFileSync(process.env.E2E_IDB_KEYS, 'utf8')))));
  check(inIdb === savedLog, 'latest save written to IndexedDB', `${Date.now() - tIdb} ms after the turn became playable`);

  // 5. Persistence across a reload (IndexedDB-backed user://).
  await boot('reload');
  s = await state();
  check(s.setup.persona === 'ha', 'settings persisted across reload (persona)', s.setup.persona);
  check(s.saved_match && s.saved_log === savedLog, 'saved match persisted across reload (latest save)', `log ${s.saved_log} vs ${savedLog}`);
  await shot('08_title_with_resume');
  check(await tap('menu:title_resume'), 'tap TIẾP TỤC TRẬN');
  s = await waitState((x) => x.in_match, 30000);
  check(s.resumed && JSON.stringify(s.owned_by_human) === JSON.stringify(owned), 'match resumed with the same land', JSON.stringify({ resumed: s.resumed, owned: s.owned_by_human }));
  await page.waitForTimeout(1500);
  await shot('09_resumed');

  // 6. Service worker + real offline reload.
  const sw = await page.evaluate(async () => {
    const reg = await navigator.serviceWorker.getRegistration();
    const keys = await caches.keys();
    let n = 0;
    for (const k of keys) n += (await (await caches.open(k)).keys()).length;
    return { active: !!(reg && reg.active), controlled: !!navigator.serviceWorker.controller, caches: keys.length, entries: n };
  });
  check(sw.active, 'service worker active', JSON.stringify(sw));
  check(sw.entries >= 9, 'engine, data and page cached by the service worker', `${sw.entries} entries`);
  await ctx.setOffline(true);
  let offlineOk = false;
  try {
    await boot('offline');
    s = await state();
    offlineOk = s.page === 'title' || s.in_match;
  } catch (e) {
    problems.push('offline boot: ' + e.message);
  }
  check(offlineOk, 'game starts with the network cut (offline reload from the service-worker cache)');
  await shot('10_offline_title');
  if (offlineOk) {
    check(await tap('menu:title_resume', 20000), 'offline: tap TIẾP TỤC TRẬN');
    s = await waitState((x) => x.in_match, 30000);
    check(s.resumed, 'offline: saved match resumes');
  }
  await ctx.setOffline(false);

  // 7. Landscape phone.
  await page.setViewportSize({ width: 844, height: 390 });
  await page.waitForTimeout(2500);
  await shot('11_landscape');
  s = await state();
  check(s.cards ? s.cards.every((c) => c.fits) : true, 'landscape: names fit', (s.cards || []).map((c) => c.name).join(', '));
  check(!!(await rectOf('hud:pause')), 'landscape: pause button on screen');
} catch (e) {
  check(false, 'test crashed', e.stack || String(e));
}

const real = problems.filter((p) => !/favicon|Service worker registration|net::ERR_INTERNET_DISCONNECTED/.test(p));
check(real.length === 0, 'no console / page / WebGL errors', real.slice(0, 10).join(' | '));
fs.writeFileSync(path.join(out, 'results.json'), JSON.stringify({ results, problems }, null, 1));
console.log(`WEB_E2E ${failed === 0 ? 'PASS' : 'FAIL'} ${results.length - failed}/${results.length}`);
await browser.close();
server.close();
process.exit(failed === 0 ? 0 : 1);
