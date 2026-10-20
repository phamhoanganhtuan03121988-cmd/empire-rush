# EMPIRE RUSH: iOS web/PWA test report

Date: 2026-10-20 · Branch `claude/empire-rush-web-pwa-launch`

## 0. Read this first: what was and was not tested
| | |
|---|---|
| Real iPhone | **Not tested.** No iPhone or Mac was available to this work |
| Safari / WebKit | **Not tested.** WebKit is not installed in the build environment, and the iOS Simulator needs macOS |
| What ran | The **real web export** in **headless Chromium**, WebGL 2 through SwiftShader (CPU), with an iPhone viewport: 390×844 pt, ×3 pixel ratio, touch input, iPhone Safari user agent |
| Offline | Tested for real: the browser context was switched offline (network cut) and the page reloaded |

Passing in Chromium does **not** prove that iPhone Safari works. The checks in §4 have to be done once on the phone.

## 1. Web compatibility review
| Item | Finding |
|---|---|
| C#, GDExtension, native plugins | None: pure GDScript, so the web export is possible |
| Threads | The web build is single-threaded (`variant/thread_support=false`). It needs no SharedArrayBuffer, no COOP/COEP headers and no cross-origin isolation, so it runs on GitHub Pages and in Safari |
| Renderer | Compatibility / WebGL 2 on the web; desktop keeps Mobile (Vulkan). WebGL 2 is in Safari since iOS 15 |
| Renderer difference found and fixed | Compatibility ignores the materials' `vertex_color_is_srgb`, which made tiles almost white on the web. Vertex colours are now converted for that renderer (`mesh_merger.gd`). The web board now matches desktop (screenshots in `docs/media/web/`) |
| Fonts, textures, audio | All in the `.pck`, loaded from the same origin. Audio starts after the first tap (browser autoplay rule). The engine's audio worklets are included |
| Saving | `user://` maps to IndexedDB. Persistence across a reload was verified (below) |
| Size | wasm 39.5 MB (≈10 MB gzipped) + pck 6.9 MB (≈5.5 MB gzipped); total download about 15 MB on the first visit |
| Boot time (CPU-rendered Chromium, files local) | 7.1–9.3 s to the title. A phone GPU should be faster; network time adds to it |

## 2. Automated tests: results
### 2.1 Browser end-to-end on the real web export: `tests_web/e2e_web.mjs` → **37/37 PASS**
Run locally at ×3 pixel ratio (37/37). CI (`.github/workflows/web-pwa.yml`) runs the same test at ×1, same 390×844 layout, because the runner renders WebGL on its CPU and ×3 frames are too slow there.
Every action is a real **touch tap** on the canvas at the position of the on-screen button.

1. Boot without errors; WebGL 2 available.
2. Manifest: name EMPIRE RUSH, `display: standalone`, icons 180 and 512.
3. iOS meta tags: `apple-touch-icon`, manifest link, `apple-mobile-web-app-capable`.
4. The "Thêm vào MH chính" banner shows for iPhone Safari while the game is not installed.
5. Title → **CHƠI** → intro **BỎ QUA** → choose character (Thu Hà) and 2 players → **BẮT ĐẦU**.
6. A real turn:
   - **ĐỔ XÚC XẮC**: the dice are rolled and the pawn moves;
   - **MUA**: the tile becomes the player's and 90 RC is paid;
   - **KẾT THÚC LƯỢT**: the bot plays, then it is the human's turn again.
7. Player names fit their HUD cards. Before the fix they were cut ("Tuấn" → "Tu").
8. The match is autosaved at the new turn, and that save reaches **IndexedDB** before the reload.
9. **Page reload**:
   - the chosen character persisted;
   - the saved match persisted;
   - **TIẾP TỤC TRẬN** resumes it with the same land owned.
10. Service worker active and controlling the page; 9 files cached (engine, data, page, icons).
11. **Network cut** (browser offline):
    - reload → the game starts from the cache;
    - **TIẾP TỤC TRẬN** resumes the saved match offline.
12. Landscape 844×390: names fit; the pause button is on screen.
13. No console, page or WebGL errors during the whole run.

### 2.2 Responsive: `tests_web/responsive_web.mjs` → **25/25 PASS**
Sizes:
- iPhone SE 375×667
- iPhone 15 393×852
- iPhone 15 Pro Max 430×932
- iPhone 15 landscape 852×393
- iPad mini 744×1133

Checked at every size:
- CHƠI is on screen;
- a match starts by touch;
- the roll button is on screen and at least 44 pt tall (58–117 pt);
- the pause button is on screen;
- 4 player names fit.

### 2.3 Godot suites (desktop engine, headless)
| Suite | Result |
|---|---|
| Unit/gameplay `tests/test_runner.gd` | 208 passed, 0 failed |
| Script compile check | 120 scripts, 0 failed |
| UI flows `tests/ui/ui_test_runner.gd` | 55 passed, 0 failed. New: resume rebuilds the same match, a broken save is discarded, the title offers resume only with a save, names fit at 2/3/4 players in portrait and landscape |
| Multi-process network e2e | PASS (chaos + concurrent) |
| Release lock: the public build has no device tools | OK |
| Repository readiness (incl. secret scan) | PASS |

Gameplay rules, economy and balance were not changed. The save replays the engine's own command log and must reach the same state hash.

## 3. Known limits
- **Save latency:** Godot writes `user://` to IndexedDB asynchronously after each save. In this CPU-rendered test browser it took 2–75 s, depending on how slow frames were, because the write waits for the page's event loop.
  - On a phone GPU, frames take milliseconds, but this was **not measured on an iPhone**.
  - Worst case if iOS kills the app right after a turn starts: the previous turn's save is used. The save file itself is never corrupted, because it is written to a temporary file and renamed.
- **iOS storage rules:**
  - The Home Screen app has its own storage, separate from the Safari tab: progress made in the tab does not carry over to the icon.
  - Removing the icon deletes its data.
  - iOS may clear website data that is not used for weeks.
- **Updates** reach an installed app one launch late (service worker), see `WEB_PWA_DEPLOYMENT.md`.
- **Battery and heat:** the game renders 3D at the phone's full pixel density. Not measured on a device; the in-game "Đồ họa" setting (Thấp/Vừa/Cao) is there to lower it.

## 4. Checklist for the first real iPhone test (≈5 minutes)
1. Open the link in Safari. Expected:
   - the loading bar, then the title screen;
   - the "Thêm vào MH chính" banner.
2. Share → Thêm vào MH chính → open the **EMPIRE RUSH** icon. Expected:
   - full screen, no address bar;
   - nothing under the notch or the home indicator.
3. Play one turn: roll, buy, end turn. Check the HUD names and that buttons respond to taps.
4. Press the Home button or swipe away, then open the app again. Expected: the match continues, or the title shows TIẾP TỤC TRẬN.
5. Turn on Airplane mode, close the app from the app switcher and open it. Expected: the game starts and TIẾP TỤC TRẬN works.
6. Lock the phone during a match, unlock. Expected: the game resumes, and the turn timer is paused while it was hidden.

Screenshots of the automated run: `docs/media/web/`.
