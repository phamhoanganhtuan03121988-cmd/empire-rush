# EMPIRE RUSH: Web/PWA build and deployment (iPhone Safari)

Goal: play on iPhone from an HTTPS link in Safari, add it to the Home Screen,
open it full screen like an app, keep progress, and play offline after the
first load. No App Store, no native iOS build, no Mac, no paid service.

## 1. What the web build is

| | |
|---|---|
| Engine | Godot 4.7.2-stable, official web export template `web_nothreads_release.zip` |
| Preset | `Web Public Release` (`client/export_presets.cfg`, preset.6) |
| Renderer | Compatibility (WebGL 2) on the web only (`renderer/rendering_method.web`); desktop/Linux/Windows keep the Mobile renderer |
| Threads | Single-threaded: no SharedArrayBuffer, so no COOP/COEP headers. Any static host works (GitHub Pages cannot send those headers) |
| C# / GDExtension / native plugins | None (pure GDScript). Checked before choosing the export |
| Size | 45 MB on disk: `index.wasm` 39.5 MB (≈10 MB gzipped), `index.pck` 6.9 MB, plus JS/icons |
| Save data | Godot `user://` on the web = IndexedDB (`/userfs`), per site origin |

### PWA pieces
- `index.manifest.json`: name and short name **EMPIRE RUSH**, `display: standalone`, `lang: vi`, colours `#060a12`, icons 144/180/512. Patched by `scripts/web/postprocess_web.py`.
- Icons: `client/assets/branding/` (SVG source by `scripts/art/gen_app_icon.py`, PNGs rendered by `client/tools/web/render_icons.gd`). The 180 px icon is the iPhone `apple-touch-icon`.
- Service worker `index.service.worker.js` (Godot's). The post-process step:
  - precaches `index.wasm` and `index.pck` at install, so the game works offline after the **first** visit (by default Godot only cached them on the second visit);
  - matches cached files ignoring the URL query.
- `client/web/shell.html`: the page around the canvas.
  - Vietnamese loading screen with the icon and a progress bar.
  - Vietnamese error message with a "Thử lại" (retry) button, offline-aware.
  - iOS meta tags: `apple-mobile-web-app-capable`, status bar style, title.
  - The "Thêm vào Màn hình chính" banner, shown only in iPhone Safari when the game is not yet installed.
  - Disables pinch, double-tap zoom and page scrolling.
- `client/web/offline.html`: shown if the game was never loaded and the network is down.

### Saving progress (new, web and desktop)
`client/scripts/ui/saved_match.gd`. The match in progress is saved:
- at the start of every turn;
- when the app goes to the background (switching apps, locking the phone, closing the tab).

What is saved: the seed, the seats, the player identities and the engine's command log. The title screen then offers **TIẾP TỤC TRẬN**, which replays the log through the rules engine and checks the state hash. Nothing is edited by hand, so the rules cannot be bent by a save.

Safety:
- Writes go to a temporary file first and are then renamed, so a half-written save never replaces a good one.
- A broken save is discarded, and the game still opens.
- Settings (name, character, sound…) persist the same way (`user://settings.cfg`).

Note: Godot copies `user://` to IndexedDB asynchronously after each write. If the app is killed within a moment of a save, the previous save is used. At worst one turn is lost, never the file.

## 2. Build locally

```bash
GODOT=/path/to/Godot_v4.7.2-stable_linux.x86_64
scripts/ci/install_templates.sh web           # official templates, SHA-512 checked
GODOT=$GODOT scripts/export_build.sh web public  # -> build/web-public/
```

Try it: `node tests_web/serve.mjs` style server or `python3 -m http.server -d build/web-public 8080`, then open `http://localhost:8080/`. A service worker needs HTTPS or localhost.

Browser test (Chromium with an iPhone-sized touch viewport, not Safari):
```bash
cd tests_web && npm install --no-save --no-package-lock playwright@1.56.1 && npx playwright install chromium && cd ..
node tests_web/e2e_web.mjs build/web-public web-e2e   # prints WEB_E2E PASS n/n
```
`?e2e=1` in the URL turns on a read-only test bridge (button positions and game state). The test taps the real buttons with touch events. `&seed=N` fixes the dice, and only in that test mode. Normal players never see either.

## 3. Deploy (GitHub Pages, free)

`.github/workflows/web-pwa.yml` runs on every push to `main` and `claude/empire-rush-web-pwa-launch`, on pull requests and on demand. It:
1. exports the web build;
2. runs the browser e2e test;
3. uploads the screenshots and the Pages artifact;
4. deploys to GitHub Pages if Pages is enabled. If it is not, the deploy job says so in the run summary and stays green.

Link once deployed: **https://phamhoanganhtuan03121988-cmd.github.io/empire-rush/**

GitHub Pages is free for **public** repositories. A private repository needs a paid plan, so the repository must be public.

The secret scan was done before the move to public (§5).

One-time steps for the repository owner (each needs owner permission, so they cannot be done from the build):
1. **Settings → General → Danger Zone → Change repository visibility → Public.**
2. **Settings → Pages → Build and deployment → Source: GitHub Actions.**
3. **Settings → Environments → `github-pages` → Deployment branches.** Add `claude/empire-rush-web-pwa-launch`, or simply deploy from `main` after merging the PR. When Pages is turned on, GitHub may limit this environment to the default branch.
4. **Actions → web-pwa → Re-run all jobs** on the latest run of the branch, or push any commit. The run summary prints the link.

### Updating the game
Push to the branch (or `main`). The workflow rebuilds and redeploys.

Each export writes a new `CACHE_VERSION` into the service worker, so a phone with the game installed picks up the update in two steps:
1. The next time it is opened online, it downloads the new files.
2. The update applies from the launch after that.

To force it: close the app from the app switcher and open it again while online.

## 4. Install on iPhone (Thêm vào Màn hình chính)
1. Mở **Safari** (cách chắc chắn nhất; trình duyệt khác trên iPhone chỉ hỗ trợ từ iOS 16.4) và vào link ở trên.
2. Chờ game tải xong lần đầu (cần mạng; khoảng 10–15 MB tải về).
3. Bấm nút **Chia sẻ** (ô vuông có mũi tên lên) → **Thêm vào MH chính** → **Thêm**.
4. Mở game bằng biểu tượng **EMPIRE RUSH** trên màn hình chính: game chạy toàn màn hình, không có thanh địa chỉ.
5. Sau lần tải đầu, có thể chơi khi không có mạng. Trận đang chơi được tự lưu; mở lại sẽ thấy nút **TIẾP TỤC TRẬN**.

Lưu ý: dữ liệu lưu thuộc về biểu tượng đã cài (iOS tách dữ liệu của app trên màn hình chính khỏi tab Safari). Xoá biểu tượng thì mất dữ liệu đã lưu. iOS cũng có thể tự xoá dữ liệu web của trang không được mở trong nhiều tuần.

## 5. Secret scan (before making the repository public)
All branches and all history were searched (`git log --all -p`):
- Search patterns: AWS keys, GitHub tokens, `sk-` keys, Slack tokens, private-key blocks, Google API keys, passwords, URLs with credentials, keystore passwords, Apple Team IDs, e-mail addresses.
- Result: **no match**.
- Files whose names contain "token" are pawn models (`pawn_*.res`, `token_view.gd`).
- The iOS presets have an empty Team ID, and no signing data is in the repository.
- All commits are authored `Claude <noreply@anthropic.com>`.
- `scripts/ci/check_repo_readiness.py` repeats a secret scan in CI.

## 6. Troubleshooting
| Symptom | Cause / fix |
|---|---|
| "Trình duyệt này thiếu tính năng cần để chạy game" | WebGL 2 is off or unsupported. iOS 15+ Safari has it; update iOS |
| Stuck loading on first visit | Slow network: the engine is ≈10 MB compressed. The "Thử lại" button reloads |
| 404 at the link | Pages not enabled, or the deploy job was skipped (see the run summary of `web-pwa`) |
| Deploy job: "Branch … is not allowed to deploy to github-pages" | Step 3 of §3 |
| Old version keeps opening | See "Updating the game" above: close and reopen online twice |
| Offline does not start | The game must have finished loading once online (that is when it is cached) |
| Progress gone | Different origin (another URL), the Home Screen icon was removed, or iOS cleared site data |
