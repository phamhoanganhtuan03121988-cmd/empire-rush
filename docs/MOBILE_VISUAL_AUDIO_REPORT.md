# EMPIRE RUSH: mobile visual + audio pass (iPhone feedback)

Branch `claude/empire-rush-mobile-visual-audio`, from `claude/empire-rush-web-pwa-launch` @ `b8014b0` (the deployed web/PWA build).

Not changed: rules, economy, land prices, starting cash, win/lose conditions, AI and balance (`client/scripts/domain/` untouched; the 208 rules tests are unchanged and pass).

## 1. Sound: why the game was silent, and the fix

**Root cause (measured, not assumed).** The browser test played the real web export with a probe on the page's audio graph:
- an analyser on every connection to the speakers;
- a counter on every started source.

| | Before | After |
|---|---|---|
| AudioContext after the first tap | `running` | `running` |
| Godot started the music buffer (46.5 s) | yes | yes |
| Peak signal at the output | **0.000** | **0.16 – 0.27** |
| A test oscillator through the same probe | 1.0 | 1.0 |

So the context was unlocked and playing, but everything was multiplied by zero.

The game created its `Music` and `SFX` buses at run time (`AudioServer.add_bus()` in `AudioDirector.ensure_buses`). Godot's web build plays sounds as Web Audio "samples" and keeps a copy of every bus in the browser. Buses added at run time were mirrored with a gain of 0, so every sound and the music played into silence: on every browser, not only on iPhone.

**Fix.** `client/default_bus_layout.tres` declares `Music` and `SFX` (send to `Master`), so they exist from start-up. `ensure_buses()` now finds them and adds nothing. Desktop behaviour is unchanged.

**iPhone/iPad Safari specifics** (`client/web/shell.html`, loaded before the engine):
- **Unlock:** every `AudioContext` the page creates is tracked. On each tap, click or key press (a valid user gesture) a suspended context is resumed and one silent sample is played, which is what unlocks Web Audio on iOS. The same happens when returning from another app or the lock screen.
- **Silent switch:** `navigator.audioSession.type = "playback"` (iOS 17+). Without it, the ring/silent switch mutes all Web Audio. With it, the game plays like a media app and pauses other apps' music while it plays.
- **No silent failure:** if sound still cannot start 1.5 s after a tap, a banner says so and what to do.
- `window.erAudio.info()` reports the state (supported, contexts, state, gestures, session, last error).

**In the game:**
- **Sound button** in the HUD top bar (speaker / crossed speaker), next to the menu. It uses the same setting as Settings → "Tắt âm thanh" and is saved.
- **Settings page (web):** an audio status line ("Âm thanh đang hoạt động" / "đang chờ: chạm vào màn hình…" / "đang TẮT") and a **"Phát thử âm thanh"** (play a test sound) button; the volume sliders were already there.
- **Asset failures:** a missing or broken sound file costs that one sound (warning), never the game.
- **Overlap control** (pool of 8, minimum gap and maximum copies per sound) was already in place and is kept.

**Sounds wired to gameplay** (all already existed; now audible on the web):

| Moment | Sounds |
|---|---|
| UI | `ui_click`, `ui_confirm`, `ui_back`, `ui_hover` |
| Dice | `dice_roll`, `dice_bounce`, `dice_land`, `dice_result` |
| Pawn movement | `step` per tile |
| Purchases and upgrades | `buy`, `upgrade` |
| Money and auctions | `cash_gain`, `cash_loss`, `bid`, `auction` |
| Events | `card`, `choice`, `rescue`, `bankrupt`, `your_turn`, `win`, `lose` |

The browser e2e checks the dice, step, buy and cash sounds by name, and checks that the signal reaches the output.

Asset paths: the sounds are inside `index.pck`, loaded from the page's own folder, so they work under `/empire-rush/`. No separate audio request can 404, and the e2e fails on any failed request.

## 2. Board

| Problem from the iPhone screenshots | Cause | Change (`board_view.gd`) |
|---|---|---|
| Prices off-centre, crossing the band edge | The label sat on the inner colour band (0.32 m from the centre), straddling its edge | The price is on a navy plate with a rim in the district colour, at the **geometric centre** of the tile, turned to the camera yaw (45°) so it reads upright on all 4 sides. The band is narrower (0.14 m instead of 0.24 m) so the plate (0.56 × 0.28 m) never touches it |
| Ownership hard to read (thin frame, flat seal) | — | Owned tiles: a thicker frame in the owner's colour, the flag, and an **owner badge** (portrait in a ring of the owner's colour, dark outline, always facing the camera, drawn over buildings), floating over the tile's outer edge, below the pawn medallions. The price plate hides once the tile is owned |
| Flat, little depth | The web renderer (Compatibility) has no SSAO | **Contact shadows** (soft dark blobs) under centre buildings, trees, the landmark, planters, benches, every tile building as it is built, and every pawn. They are merged into the ground mesh, so no extra draw calls on the static board. Deeper walnut plinth (0.46 m) with a second brass inlay |
| Washed-out colours on the web | (previous pass) the Compatibility renderer ignores `vertex_color_is_srgb` | Kept: vertex colours converted for that renderer |
| Dice tray covered the board | The tray took 92 % of the board area | 76 % (dice stay ≥ 60 px wide on a 720 px canvas, tested); brass rim instead of bright UI gold |

**Tile info** (tap a tile) now lists, in order:
- name and district;
- **Giá mua** (purchase price);
- **Chủ sở hữu** (owner, "Bạn" for you) with the house level, or "chưa có";
- **Tiền thuê hiện tại** (rent due now, from `GameEngine.gross_rent`);
- the full rent ladder.

## 3. HUD and screens on iPhone

- **Player cards (3–4 players):** a compact card when a card is narrower than 280 px.
  - Line 1: avatar and name. Line 2: "Tài sản N" (net worth, without the role). Line 3: coin and cash in bold.
  - Name, net worth and cash shrink to fit (`UiTheme.fit_name`) and are never trimmed with "…".
  - Cash (coin icon, bold) and net worth (label "Tài sản") are clearly different numbers.
- **Buttons never break over two lines** (`UiTheme.fit_button`): the text shrinks to fit; the icon is dropped only as a last resort.
  - Fixes "CÁCH CHƠI" and "BẮT ĐẦU" on a 375 pt iPhone, "Doanh Nhân" and "Đàm Phán" in landscape, and the intro buttons.
  - The "Đồ họa Vừa" (graphics) button fits beside the new sound button and stays at ≥ 20 px (readability test).
- **In-game Settings scroll** when taller than the screen (landscape phone); before, the panel ran off the top of the screen.
- **Roll hint** on touch devices: "Chạm nút bên dưới…" (no Space key).
- **Safe areas:** unchanged from the launch, and verified again.
  - Safari keeps the page out of the notch, Dynamic Island and home indicator (no `viewport-fit=cover`).
  - The HUD also respects `safe_rect()`.
  - Every button and panel was checked to be inside the viewport (§4).

## 4. Tests

| Suite | Result |
|---|---|
| Godot rules/unit `tests/test_runner.gd` | 208 passed, 0 failed |
| Script compile check | 121 scripts, 0 failed |
| Godot UI flows | 61 passed, 0 failed (55 existing + 6 new in `test_mobile_visual_audio.gd`) |
| Browser e2e, real export, iPhone 390×844 touch (`tests_web/e2e_web.mjs`) | **58/58** at ×1 and **58/58** at ×3 pixel ratio (1170×2532, like an iPhone). Includes the audio probe (signal at the output after the first tap; dice/step/buy/cash sounds), the HUD sound button, the purchase, names/net worth/cash fit, save/reload/resume, service worker, offline reload, landscape, no console errors or 404 |
| Responsive, 5 sizes, 4 players (`tests_web/responsive_web.mjs`) | **30/30**: iPhone SE 375×667, 15 393×852, 15 Pro Max 430×932, 15 landscape 852×393, iPad mini 744×1133; CHƠI, roll and pause on screen, roll button ≥ 44 pt, names/net worth/cash fit, layout audit clean |
| Multi-process network e2e, release lock, repository readiness | PASS, OK, PASS |
| Screen tour with layout audit (`tests_web/ui_tour_web.mjs`) | **48/48** at 375×667, 393×852 and 852×393: title, every intro page, setup, "Cách chơi" dialog, settings, tutorial coach card, pause, rules guide, in-game settings |

**New tests in `test_mobile_visual_audio.gd`:**
- For each of the 21 property tiles on all 4 sides:
  - the plate sits at the tile centre in 3D and on screen (< 0.5 px);
  - its rotated footprint stays inside the tile and clear of the band;
  - the text faces the camera and fits its plate.
- Owner badge over its own tile, below the pawn medallions, removed with the owner; price back for the bank.
- 4 players in portrait: name, net worth and cash fit, never "…".
- Tile info shows price, owner and rent due now.
- `Music` and `SFX` buses exist at start-up from the layout file, sending to Master.
- Every sound in `AudioDirector.SPEC` has a file; an unknown sound is refused; the HUD sound toggle mutes and unmutes the buses.

**Layout audit** (`WebBridge.audit_layout`, runs on every e2e screenshot and every tour screen): every visible button whose text needs more than one line next to its icon, and every button or panel outside the viewport, is a failure. On its first run it found the problems listed in §3, which are now fixed.

**WebKit:** `.github/workflows/web-pwa.yml` gains a `webkit` job (`tests_web/webkit_smoke.mjs`, Playwright WebKit with the iPhone 13 profile): boot, WebGL 2, the AudioContext after a tap, CHƠI. It is informative (`continue-on-error`): Linux WebKit is Safari's engine, not iOS Safari on a phone. WebKit cannot be installed in this build environment; the result comes from the CI run.

**Before / after screenshots:** `docs/media/mobile/`
- `board_zoom.png` (2 players, after a purchase, both at ×3);
- `roll_ready_iphone.png`;
- `match_4p_iphone15.png`, `match_4p_iphone_se.png`, `landscape_iphone15.png`;
- `after_buy_iphone.png`, `setup_iphone_se.png`, `settings_landscape.png`.

## 5. Not verified on a real iPhone

- Sound on iOS Safari / the Home Screen app: the cause found and fixed affects every browser, and the iOS unlock and silent-switch handling follow WebKit's documented behaviour. **Not heard on a real device.**
- Touch feel, frame rate, heat and battery on a phone GPU.
- Text size with the iOS system font size set larger: the game draws its own text in the canvas, so iOS Dynamic Type does not change it (the game's own sizes are ≥ 20 px on a 720 px canvas, tested).

**Check on the phone:**
1. Open the game, tap once: music starts.
2. Flip the silent switch on: sound continues (iOS 17+).
3. Tap the speaker button: silence. Tap again: a confirm sound.
4. Settings → "Phát thử âm thanh".
