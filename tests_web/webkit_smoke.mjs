// WebKit check of the real web export (Playwright's WebKit on Linux with the
// iPhone 13 device profile: Safari's engine, NOT iOS Safari on a phone).
// Boot, WebGL 2, a real tap, the AudioContext state after it, the sound
// helper, CHƠI -> setup, and a screenshot.
//   node tests_web/webkit_smoke.mjs build/web-public OUT_DIR
import fs from 'node:fs';
import path from 'node:path';
import { webkit, devices } from './pw.mjs';
import { serve } from './serve.mjs';

const root = path.resolve(process.argv[2] || 'build/web-public');
const out = path.resolve(process.argv[3] || 'web-webkit-out');
fs.mkdirSync(out, { recursive: true });
const PORT = 8768;
let failed = 0;
const lines = [];
function check(ok, name, detail = '') {
  if (!ok) failed += 1;
  const l = `${ok ? 'PASS' : 'FAIL'} ${name}${detail ? ' :: ' + detail : ''}`;
  lines.push(l);
  console.log(l);
}
const server = await serve(root, PORT);
const browser = await webkit.launch();
const ctx = await browser.newContext({ ...devices['iPhone 13'] });
const page = await ctx.newPage();
const errors = [];
page.on('pageerror', (e) => errors.push(e.message));
page.on('response', (r) => { if (r.status() >= 400) errors.push(`${r.status()} ${r.url()}`); });
try {
  check(await page.evaluate(() => !!document.createElement('canvas').getContext('webgl2')), 'WebKit: WebGL 2 available');
  const t0 = Date.now();
  await page.goto(`http://127.0.0.1:${PORT}/index.html?e2e=1&seed=4`);
  await page.waitForFunction(() => window.__empireRushStarted === true && window.erE2E, null, { timeout: 300000 });
  check(true, 'WebKit: game boots to the title', `${Date.now() - t0} ms`);
  await page.waitForTimeout(2000);
  const before = JSON.parse(await page.evaluate(() => window.erAudio.info()));
  check(before.contexts >= 1, 'WebKit: AudioContext created', JSON.stringify(before));
  const st = JSON.parse(await page.evaluate(() => { window.erE2E.state(); return window.erE2EResult; }));
  const r = JSON.parse(await page.evaluate(() => { window.erE2E.rect('menu:title_play'); return window.erE2EResult; }));
  const vp = page.viewportSize();
  await page.touchscreen.tap((r[0] + r[2] / 2) * vp.width, (r[1] + r[3] / 2) * vp.height);
  await page.waitForTimeout(2000);
  const after = JSON.parse(await page.evaluate(() => window.erAudio.info()));
  check(after.state === 'running', 'WebKit: AudioContext running after a tap', JSON.stringify(after));
  const st2 = JSON.parse(await page.evaluate(() => { window.erE2E.state(); return window.erE2EResult; }));
  check(st.page === 'title' && st2.page !== 'title', 'WebKit: tapping CHƠI leaves the title', `${st.page} -> ${st2.page}`);
  await page.screenshot({ path: path.join(out, 'webkit_iphone13.png') });
} catch (e) {
  check(false, 'WebKit: crashed', e.message);
}
check(errors.length === 0, 'WebKit: no page errors or failed requests', errors.slice(0, 5).join(' | '));
fs.writeFileSync(path.join(out, 'results.txt'), lines.join('\n') + '\n');
console.log(`WEB_WEBKIT ${failed === 0 ? 'PASS' : 'FAIL'} ${lines.length - failed}/${lines.length}`);
await browser.close();
server.close();
process.exit(failed === 0 ? 0 : 1);
