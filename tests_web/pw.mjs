// Loads Playwright from the project (npm i) or, failing that, the global install.
import { createRequire } from 'node:module';
import { execSync } from 'node:child_process';
const require = createRequire(import.meta.url);
let mod;
try {
  mod = require('playwright');
} catch {
  mod = require(execSync('npm root -g').toString().trim() + '/playwright');
}
export const { chromium } = mod;
