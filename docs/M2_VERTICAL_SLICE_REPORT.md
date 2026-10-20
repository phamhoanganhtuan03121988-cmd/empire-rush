# M2 — Vertical Slice Report

Date: 2026-10-18 · Branch: `claude/m2-vertical-slice` (from `claude/m1-2-balance-v3` @ `1d59311`) · Engine: Godot 4.7.2-stable, **Mobile renderer**
Balance: v3 (technical baseline, not final). No seat compensation, net worth unchanged, Start 200 RC.
**Verdict:** a complete offline match is playable on desktop (human seat 0 vs 1–3 bots) with a 3D board, animated dice and tokens, and a portrait-first touch HUD. Not yet verified on any real device; no iOS build exists.

## 1. Gameplay flows that work
All of these were exercised through real HUD buttons in automated UI tests (§3) or in recorded autopilot sessions.

| Flow | Status | Notes |
|---|---|---|
| Start a match (2–4 players: you + bots) | ✅ | `--players=N`; seat 0 is human |
| Roll dice | ✅ | Big "ĐỔ XÚC XẮC" button. The dice animation always lands on the faces the **engine** rolled (tested). |
| Token movement | ✅ | Hop-per-tile animation, wraps past Start, Start reward pop-up |
| Buy property | ✅ | Card shows name, district, price and rent ladder (from the domain query `rent_ladder()`). BUY is disabled when unaffordable. |
| Pass → auction | ✅ | Auction panel with current bid and leader. Bid buttons use the domain query `min_next_bid()`. Bots bid. |
| Pay rent | ✅ | Coin flight from payer to owner; both balances update from the engine `CashChanged` events |
| Upgrade | ✅ | "NÂNG CẤP" opens a list of upgradable lots with engine quotes. Buildings grow (house → apartment → tower). |
| End turn | ✅ | |
| Event cards / Opportunity choices | ✅ | Option buttons; unaffordable options disabled; timeout → free default (engine) |
| Character ability | ✅ | "KỸ NĂNG" when `ability_available()` |
| Trade response | ✅ (receive only) | Accept / reject bot offers. **Proposing trades from the UI is not built** (out of M2 scope). |
| Rescue / liquidation / bankruptcy | ✅ | Liquidate buttons with engine liquidation values; "PHÁ SẢN" |
| Turn timer | ✅ | Bar driven by the engine deadline. Timeouts are applied by the engine (`advance()`), not by the UI. |
| Match end + results | ✅ | Winner / loser line, end reason, ranking by net worth, "CHƠI LẠI" restarts |
| Tap a tile for info | ✅ | Ray-pick on the board → info sheet (owner, level, rent ladder) |
| Quality presets | ✅ | Thấp / Vừa / Cao button (shadows, MSAA, glow, render scale) |
| Portrait + landscape | ✅ | Portrait-first. Landscape uses a two-column layout (tested for on-screen and non-overlapping panels). |

Run it (desktop): `godot --path client` (window 405×720 portrait).
Useful flags (after `--`):
- `--players=4 --seed=7`
- `--notch`: emulate the iPhone 14 Pro safe area
- `--autoplay`
- `--quality=low|medium|high`
- `--telemetry=PATH`
- `--shots=DIR --shot-every=S`
- `--stats=FRAMES`
- `--timescale=X`
- `--quit-on-end`

## 2. Architecture (rules / presentation / data kept separate)
```
client/scripts/domain/        M1 rules (unchanged except 2 pure read-only queries, see below)
client/scripts/presentation/  LocalMatch (authority wrapper), EventPresenter, BoardView, TokenView,
                              DiceView, CameraRig, QualitySettings, SessionTelemetry, ThemeData,
                              FrameClock, water.gdshader
client/scripts/ui/            GameHud (touch HUD), UiTheme, UiText (VI strings), HudAutopilot
client/data/presentation/     board_theme.json (colours/labels), strings_vi.json (DRAFT VI display text)
client/scenes/main.tscn       entry scene (scripts/main.gd)
```
- **One way in.** `LocalMatch.submit()` is the only path from UI to rules. The HUD reads engine state and queries only for display.
  - `test_presentation_boundary.gd` scans UI and presentation code and fails if it writes to `state.*`, calls `engine.submit` directly, or calls engine internals.
- **The presenter replays engine events.** The engine state is final immediately. Balances, positions, owners and levels shown on screen only change when their event is presented, so the HUD never shows a number before its animation.
  - Animation never changes or delays rules state, and engine deadlines keep running.
  - Bots wait for the presenter to be idle. This is pacing only, never rules.
- **Domain changes (minimal, explained):**
  - `GameEngine.rent_ladder(pid)` and `GameEngine.min_next_bid()` are pure read-only queries. They let the UI show rent and bid amounts without computing money itself.
  - The bid handler now reuses `min_next_bid()`. It is the same formula, so validation and UI cannot diverge.
  - Both queries have tests. No rules, data or balance values changed (`git diff` against M1.2 for `client/data/rules`, GDD and handoff docs is empty).
- **Presentation-only data.** Vietnamese display names for the DRAFT cards, characters and properties live in `data/presentation/strings_vi.json`. The rules data, which is still DRAFT English, is untouched; the UI falls back to it.

## 3. Tests actually run
`GODOT=/opt/godot/Godot_v4.7.2-stable_linux.x86_64 TEST_TIMEOUT_SECS=1200 scripts/run_tests.sh` → **exit 0** (log `docs/test-logs/m2/m2_tests.txt`):

| Stage | Result |
|---|---|
| Domain + integration tests | **RESULT: 169 passed, 0 failed.** 165 from M1.2 + `rent_ladder` + `min_next_bid` + 2 presentation-boundary guards. No existing test changed. |
| Compile check of all scripts (`tests/check_scripts.gd`) | **CHECKED 59 scripts, 0 failed** |
| UI flow tests (`tests/ui/`, real scene headless, real HUD buttons) | **UI RESULT: 9 passed, 0 failed** |

The UI flow tests:
1. Roll: the dice faces match `engine.last_roll`; the token sits on the engine position.
2. Buy: the engine owner and cash are updated, the HUD card shows the engine balance, and the ownership marker appears.
3. Pass opens the auction panel.
4. Rent: the engine charges the amount; both HUD balances match.
5. Upgrade through the sub-menu: exactly one level is built, the engine quote is charged, and the turn ends.
6. End turn.
7. Touch targets ≥ 88 px (≈ 48 pt) and inside the emulated iPhone safe area.
8. Landscape: both panels on screen and not overlapping.
9. A **full 2-player match** played by the HUD autopilot through buttons, ending on the results screen. Presented cash equals engine cash for every seat, and engine invariants are clean.

**Mutation checks** of the UI tests (run on a scratch copy):
- BUY button wired to PassProperty → 6 failures.
- Presenter ignores the receiver's balance → 2 failures.

`run_tests.sh` now runs three stages: domain, compile check, UI. Any `SCRIPT ERROR` in a log fails the run.

## 4. Screenshots and video
Rendered in this Linux container with Godot's **Mobile renderer on Mesa lavapipe** (software Vulkan) under Xvfb. They show layout and art, **not device performance**.

| File | What it shows |
|---|---|
| `docs/media/m2/portrait_buy_prompt.jpg` | 786×1704 (iPhone 14 Pro aspect, 2/3 res), emulated notch; buy card with v3 rent ladder |
| `docs/media/m2/portrait_bot_turn.jpg` | Bot turn, card toast, ability toast, high quality |
| `docs/media/m2/portrait_late_game.jpg` | 3-player match at round 25–30 with houses, apartments and towers |
| `docs/media/m2/portrait_results.jpg` | Results screen (round cap 30/30, 3 players) |
| `docs/media/m2/landscape_buy_prompt.jpg` | 1704×786 landscape two-column layout |
| `docs/media/m2/vertical_slice.mp4` | 60 s, 30 fps, 4-player autopilot session recorded with Godot Movie Maker (fixed 30 fps, so animation speed is real). Captured at 405×720 and upscaled to 810×1440. |

## 5. Timing measurements: measured vs assumed
Measured with the running build: headless, `--autoplay --timescale=4`, logs in `docs/test-logs/m2/telemetry_autopilot_{2,3,4}p.json`.
- Mean frame = 0.029 s of game time, so animations (≥ 0.16 s steps) are resolved to within about ±1 frame.
- An earlier run on lavapipe at ×12 speed produced 1.2 s frames and invalid (stretched) timings. It was discarded. This is why every telemetry file records frame resolution.

**Measured** in 3 autopilot sessions:

| | 2p (56 turns) | 3p (90 turns) | 4p (100 turns) |
|---|---|---|---|
| Presentation (animation) time per turn: mean / median / P90 | 2.79 / 2.82 / 3.31 s | 2.76 / 2.68 / 3.48 s | 2.75 / 2.81 / 3.36 s |
| Whole turn incl. automated decisions (bots + autopilot, 0.7–1.6 s per decision) | 5.6–6.1 s | 5.3–5.6 s | 5.3–5.5 s |
| Session length (game clock) | 5.4 min (elimination) | 8.2 min (round cap) | 9.0 min (round cap) |

**Not measured:** human decision time. No human has played the build. The table below is a **projection, not data**: turn ≈ 2.8 s measured presentation + D (total human decision time per turn) + about 0.5 s overhead. Average turns per match are from the M1.2 v3 simulations: 2p ≈ 73, 3p ≈ 89, 4p = 100.

| D (assumed) | 2p | 3p | 4p (all human) |
|---|---|---|---|
| 4 s per turn | ≈ 9 min | ≈ 11 min | ≈ 12 min |
| 8 s per turn | ≈ 14 min | ≈ 17 min | ≈ 19 min |
| 12 s per turn | ≈ 19 min | ≈ 23 min | ≈ 25 min |
| ≥ 15 s per turn | ≥ 22 min | ≥ 27 min | 30-min time cap starts to end matches |

Implications:
- **A solo match against bots will be much shorter than 20–30 min.** Bot turns take about 5 s, so a 4-player solo match with D = 8 s is about 11 min.
- The 20–30 min target can only be judged in real multiplayer playtests (M3+).
- Recommended: run human playtests with `--telemetry=PATH` (it records per-turn, per-seat timings).

## 6. Performance (not verified on device)
**No real-device build has been run. Nothing here claims 30 FPS on iPhone 14 Pro.**

Scene complexity measured on lavapipe (`--stats=30`, 590×1278, start of a 4-player match). These counts are hardware-independent proxies:

| Preset | Draw calls | Objects | Primitives (after optimization) | Primitives (before) |
|---|---|---|---|---|
| Thấp (low) | 165 | 290 | 11,030 | 113,142 |
| Vừa (medium) | 295 | 419 | 18,472 | 222,696 |
| Cao (high) | 295 | 419 | 18,472 | 222,696 |

- **Primitive count.** Found and fixed in M2: default sphere, torus and capsule tessellation was about 10× too high. Dice pips alone were about 170k triangles.
- **Draw calls remain high** for a mobile board game, because every box is its own mesh. Medium and high double the count because of the shadow pass. They grow further in the late game (each building adds 5–15 meshes).
- **Planned fix** with production art: merge static board geometry, use MultiMesh for windows, pips and trees, and use texture atlases. Targets to confirm on device: under ~150 draw calls and ≤ 100k triangles at medium.
- lavapipe FPS (1–11) is meaningless for the device and is not reported as performance.

## 7. Placeholders (everything visual is placeholder)
- **3D:** generated primitives with flat PBR colours: board, tiles, center city, trees, tokens, dice, buildings L1–L3. Plus a simple water shader and procedural sky. No external models, textures or audio. `reference_art/` is **not** imported (asset register GEN-001).
- **Font:** the Godot built-in font (asset register ENG-001). It renders Vietnamese correctly; it needs replacing with a licensed brand font.
- **Text:** DRAFT Vietnamese display text for cards, characters and property names (`strings_vi.json`). The rules data names are still DRAFT English.
- **No audio, no particles/VFX beyond pop-ups and coin flights, no character models.** Characters are coloured pawns.
- The top bar says "Bản thử nghiệm — đồ họa tạm" (test build — placeholder graphics) so screenshots are never mistaken for final art.

## 8. Issues to address
**UI / UX:**
- On 19.5:9 portrait the board diamond is limited by screen width. It uses only about a third of the height, leaving a large empty water band (see screenshots). Options: lower yaw (30–35°) for a wider fit, pinch-zoom and pan, or a taller board presentation. Needs an art-direction decision.
- Landscape works but the board is small. A narrower side panel would help.
- **No trade proposal UI**, and no settings screen beyond the quality toggle (no sound, language or reduced-motion options yet).
- Toasts are the only event log; there is no history panel.
- The tile-tap info sheet is functional but plain.
- The movie capture ignores `--resolution` (Movie Maker uses the project window size), so videos are 405×720 and upscaled.

**Graphics:**
- Everything is placeholder (§7).
- Tile labels on special tiles are small at phone size.
- The centre city reads as generic blocks.
- Lighting is decent (warm key, cool fill, glow), but no SSAO or post-processing tuning has been done for the Mobile renderer.

**Performance:**
- Draw-call count (§6).
- No LOD or batching.
- Untested on Metal / iOS.

**Balance (unchanged from M1.2; points to playtest):**
- **Tourism Boom and the 1,815 RC peak rent** (D5 level 3 + 50%) are flagged for playtest. The slice shows them as-is: rent pop-ups and the rent ladder, with modifiers excluded from the ladder.
- **Seat advantage:** not addressed (no compensation, by decision).
- **Net worth:** liquidation-based (GDD), unchanged.
- **Solo vs bots is short** (§5). Match length can only be judged with humans.

## 9. iOS build status
**Not built.** Godot's iOS export needs macOS + Xcode, and this environment is Linux. Done in M2:
- the Mobile renderer;
- portrait orientation (sensor);
- safe-area handling, which reads `DisplayServer.get_display_safe_area()`; on desktop and in tests it is emulated with `--notch` = 59 pt top, 34 pt bottom;
- touch input (`InputEventScreenTouch` for tile taps; buttons are standard Controls);
- touch targets ≥ 88 px at 720 px design width (≈ 48 pt).

**Remaining steps, on a Mac:**
1. Install Godot 4.7.2-stable + export templates, a current Xcode, and an Apple Developer team.
2. Add an iOS export preset: bundle ID, team ID, icons and launch screen, portrait plus landscape orientation as desired, Metal (default).
3. Export the Xcode project, sign it, and run on the iPhone 14 Pro.
4. Measure with Xcode Instruments and the Godot monitors at low, medium and high:
   - FPS and frame time (30 FPS target);
   - draw calls and memory;
   - thermals over a 20–30 min session;
   - the real safe area (Dynamic Island) and touch-target feel.
5. Run human playtests with `--telemetry` to measure real turn times (§5).

## 10. Files
**Added:**
- `client/scenes/main.tscn`, `client/scripts/main.gd`
- `client/scripts/presentation/*` (11 files)
- `client/scripts/ui/*` (4 files)
- `client/data/presentation/*`
- `client/tests/ui/*` (runner, base class, 9 tests)
- `client/tests/check_scripts.gd`
- `client/tests/unit/test_presentation_boundary.gd`
- `docs/media/m2/*`, `docs/test-logs/m2/*`, this report

**Modified:**
- `client/project.godot`: main scene; portrait design viewport 720×1280; desktop window 405×720.
- `client/scripts/domain/game_engine.gd`: 2 pure queries + reuse in bid validation.
- `client/tests/unit/test_balance_v3.gd`, `test_auction.gd`: tests for the new queries.
- `scripts/run_tests.sh`: compile + UI stages.
- `docs/ASSET_REGISTER.csv`: ENG-001, GEN-001.
- `README.md`, `docs/IMPLEMENTATION_PLAN.md`: status.

**Unchanged:** rules data (`client/data/rules/*`), GDD, handoff docs, reference art, all pre-existing tests.

## 11. Acceptance (CLAUDE_TASK_PROMPT M2) and owner checklist
| Item | Status |
|---|---|
| Runnable scene/build and screenshots | **PASS** (desktop scene, screenshots and video in `docs/media/m2/`) |
| UI readable on 9:16 / 19.5:9 portrait and 16:9 landscape | **PASS in emulation** (screenshots + UI tests). **Not verified on a real phone.** |
| Animation never blocks or changes authoritative state | **PASS** (event-replay presenter; boundary tests; presented cash == engine cash after a full match) |
| Placeholders clearly labelled | **PASS** (in-game tag + §7 + asset register) |
| Low / medium / high presets | **PASS** (in-game toggle; stats in §6) |
| Full offline match with clear win/lose | **PASS** (results screen; full-match UI test) |
| UI calls the M1 domain only; no UI money logic | **PASS** (`LocalMatch.submit()` only; boundary tests) |
| Domain tests re-run | **PASS** (169/169) |
| Real turn-time data | **PARTIAL.** Animation time measured; human decision time not measured (no human sessions). |
| 30 FPS on iPhone 14 Pro | **NOT VERIFIED.** No device build (§9). |
| iOS build | **BLOCKED in this environment** (needs macOS / Xcode) |

No PR created, nothing merged. Content was not expanded beyond the slice.
