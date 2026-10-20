// Responsive check of the real web export at several phone sizes (Chromium,
// touch, not Safari): the title's main button is on screen and centred, and
// in a match the HUD cards, the roll button and the pause button fit inside
// the viewport with names not cut.
//   node tests_web/responsive_web.mjs build/web-public OUT_DIR
import fs from 'node:fs';
import path from 'node:path';
import { chromium } from './pw.mjs';
import { serve } from './serve.mjs';

const root = path.resolve(process.argv[2] || 'build/web-public');
const out = path.resolve(process.argv[3] || 'web-responsive-out');
fs.mkdirSync(out, { recursive: true });
const PORT = 8766;
const SIZES = [
  ['iphone_se', 375, 667], ['iphone_15', 393, 852], ['iphone_15_pro_max', 430, 932],
  ['iphone_15_landscape', 852, 393], ['ipad_mini', 744, 1133],
];
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
  const call = async (fn, arg) => page.evaluate(([f, a]) => { window.erE2E[f](a); return window.erE2EResult; }, [fn, arg]);
  const rect = async (id) => { const r = await call('rect', id); return r && r !== 'null' ? JSON.parse(r) : null; };
  const inside = (r) => r && r[0] >= -0.001 && r[1] >= -0.001 && r[0] + r[2] <= 1.001 && r[1] + r[3] <= 1.001;
  try {
    await page.goto(`http://127.0.0.1:${PORT}/index.html?e2e=1&seed=4`);
    await page.waitForFunction(() => window.__empireRushStarted === true && window.erE2E, null, { timeout: 240000 });
    await page.waitForTimeout(2500);
    await page.evaluate(() => { const e = document.getElementById('install-hint'); if (e) e.remove(); });
    const play = await rect('menu:title_play');
    check(inside(play), `${name} ${w}x${h}: CHƠI on screen`, JSON.stringify(play));
    await page.screenshot({ path: path.join(out, `${name}_title.png`) });
    // Start a match from the title (touch), skip the intro, defaults.
    const tap = async (id) => { const r = await rect(id); if (!r) return false; await page.touchscreen.tap((r[0] + r[2] / 2) * w, (r[1] + r[3] / 2) * h); await page.waitForTimeout(700); return true; };
    await tap('menu:title_play');
    await tap('menu:intro_skip');
    await page.waitForTimeout(1500);
    await tap('menu:start');
    const t0 = Date.now();
    let s = {};
    while (Date.now() - t0 < 60000) { s = JSON.parse(await call('state')); if (s.in_match) break; await page.waitForTimeout(300); }
    check(s.in_match, `${name}: match started by touch`);
    for (let i = 0; i < 3 && (await rect('coach:ok')); i += 1) await tap('coach:ok');
    let roll = null;
    const t1 = Date.now();
    while (!roll && Date.now() - t1 < 60000) { roll = await rect('hud:RollDice'); if (!roll) await page.waitForTimeout(300); }
    check(inside(roll) && roll[3] * h >= 44, `${name}: roll button on screen, ≥44 pt tall`, roll ? `${Math.round(roll[3] * h)} pt` : 'missing');
    check(inside(await rect('hud:pause')), `${name}: pause button on screen`);
    s = JSON.parse(await call('state'));
    check(s.cards.every((c) => c.fits), `${name}: names fit`, s.cards.map((c) => c.name).join(', '));
    await page.screenshot({ path: path.join(out, `${name}_match.png`) });
  } catch (e) {
    check(false, `${name}: crashed`, e.message);
  }
  await ctx.close();
}
fs.writeFileSync(path.join(out, 'results.txt'), lines.join('\n') + '\n');
console.log(`WEB_RESPONSIVE ${failed === 0 ? 'PASS' : 'FAIL'} ${lines.length - failed}/${lines.length}`);
await browser.close();
server.close();
process.exit(failed === 0 ? 0 : 1);
