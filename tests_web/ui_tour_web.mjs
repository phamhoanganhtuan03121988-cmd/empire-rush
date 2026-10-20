// Screen tour of the real web export at phone sizes (Chromium, touch): visits
// the title, every intro page, setup, the "how to play" dialog, settings, a
// tutorial match (coach card), the pause menu, the rules guide and the
// in-game settings, and at each screen runs the game's layout audit
// (erE2E.audit: buttons whose text does not fit on one line, buttons or
// panels outside the viewport). Screenshots of every screen are kept.
//   node tests_web/ui_tour_web.mjs build/web-public OUT_DIR
import fs from 'node:fs';
import path from 'node:path';
import { chromium } from './pw.mjs';
import { serve } from './serve.mjs';

const root = path.resolve(process.argv[2] || 'build/web-public');
const out = path.resolve(process.argv[3] || 'web-tour-out');
fs.mkdirSync(out, { recursive: true });
const PORT = 8767;
const SIZES = [['iphone_se', 375, 667], ['iphone_15', 393, 852], ['iphone_15_landscape', 852, 393]];
let failed = 0;
const lines = [];
function check(ok, name, detail = '') {
  if (!ok) failed += 1;
  const l = `${ok ? 'PASS' : 'FAIL'} ${name}${detail ? ' :: ' + detail : ''}`;
  lines.push(l);
  console.log(l);
}
const server = await serve(root, PORT);
const browser = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
for (const [name, w, h] of SIZES) {
  const ctx = await browser.newContext({ viewport: { width: w, height: h }, deviceScaleFactor: 1, isMobile: true, hasTouch: true });
  const page = await ctx.newPage();
  const errors = [];
  page.on('pageerror', (e) => errors.push(e.message));
  page.on('console', (m) => { if (m.type() === 'error' || /SCRIPT ERROR/.test(m.text())) errors.push(m.text()); });
  page.on('response', (r) => { if (r.status() >= 400) errors.push(`${r.status()} ${r.url()}`); });
  const call = async (fn, arg) => page.evaluate(([f, a]) => { window.erE2E[f](a); return window.erE2EResult; }, [fn, arg]);
  const rect = async (id) => { const r = await call('rect', id); return r && r !== 'null' ? JSON.parse(r) : null; };
  const tap = async (id, wait = 900) => {
    let r = null;
    const t0 = Date.now();
    while (!r && Date.now() - t0 < 30000) { r = await rect(id); if (!r) await page.waitForTimeout(250); }
    if (!r) return false;
    await page.touchscreen.tap((r[0] + r[2] / 2) * w, (r[1] + r[3] / 2) * h);
    await page.waitForTimeout(wait);
    return true;
  };
  const screen = async (label) => {
    await page.waitForTimeout(600);
    const a = JSON.parse(await call('audit'));
    check(a.problems.length === 0, `${name} ${label}: ${a.buttons} buttons, nothing cut or off screen`, a.problems.slice(0, 4).join(' | '));
    await page.screenshot({ path: path.join(out, `${name}_${label}.png`) });
  };
  try {
    await page.goto(`http://127.0.0.1:${PORT}/index.html?e2e=1&seed=4`);
    await page.waitForFunction(() => window.__empireRushStarted === true && window.erE2E, null, { timeout: 240000 });
    await page.waitForTimeout(2500);
    await page.evaluate(() => { const e = document.getElementById('install-hint'); if (e) e.remove(); });
    await screen('title');
    check(await tap('menu:title_intro'), `${name}: open GIỚI THIỆU`);
    for (let k = 0; k < 6; k += 1) {
      const st = JSON.parse(await call('state'));
      if (st.page !== 'intro') break;
      await screen(`intro_${k}`);
      if (!(await tap('menu:intro_next'))) break;
    }
    // The last intro page leads to setup.
    let st = JSON.parse(await call('state'));
    if (st.page !== 'setup') { await tap('menu:title_play'); await tap('menu:intro_skip'); }
    await page.waitForTimeout(1200);
    await screen('setup');
    if (await tap('menu:how_to')) {
      await screen('how_to');
      await tap('menu:how_to_close');
    }
    check(await tap('menu:setup_back'), `${name}: back to the title`);
    if (await tap('menu:title_settings')) {
      await screen('settings');
      await tap('menu:settings_back');
    }
    // Tutorial match: the coach card and the HUD.
    check(await tap('menu:title_tutorial', 2500), `${name}: start the step-by-step tutorial`);
    let t0 = Date.now();
    while (Date.now() - t0 < 60000) { st = JSON.parse(await call('state')); if (st.in_match && st.coach) break; await page.waitForTimeout(400); }
    check(st.in_match, `${name}: tutorial match started`, `coach=${st.coach}`);
    await screen('tutorial_coach');
    check(await tap('hud:pause'), `${name}: open the pause menu`);
    await screen('pause');
    if (await tap('pause:guide')) {
      await screen('rules_guide');
      await tap('pause:guide_back');
    }
    if (await tap('pause:settings')) {
      await screen('pause_settings');
      await tap('pause:settings_back');
    }
  } catch (e) {
    check(false, `${name}: crashed`, e.message);
  }
  const real = errors.filter((e) => !/favicon|Service worker/i.test(e));
  check(real.length === 0, `${name}: no console errors or failed requests (404)`, real.slice(0, 5).join(' | '));
  await ctx.close();
}
fs.writeFileSync(path.join(out, 'results.txt'), lines.join('\n') + '\n');
console.log(`WEB_TOUR ${failed === 0 ? 'PASS' : 'FAIL'} ${lines.length - failed}/${lines.length}`);
await browser.close();
server.close();
process.exit(failed === 0 ? 0 : 1);
