# EMPIRE RUSH — Master Execution Report

**M2.3 playtest automation · visual production vertical slice · M3 technical foundation · CI/release readiness**

> **Next:** Phase 2 (visual quality, performance, multi-process multiplayer, playtest kit) is reported in [`docs/PHASE2_REPORT.md`](PHASE2_REPORT.md), branch `claude/visual-performance-multiplayer`. This report stays as the M2.3 record.

Date: 2026-10-18 · Engine: Godot 4.7.2-stable · Branch: **`claude/master-visual-production-m3`** (from `claude/m2-2-1-release-readiness` @ `fa2f165`; no other branch touched, no merge, no PR)

**Not changed:**
- rules (`client/scripts/domain/*`);
- balance and rules data;
- the approved GDD content;
- MVP scope;
- the offline background-timer rule;
- force-quit = no recovery;
- the Public Release telemetry lock.

**Not claimed:**
- No iPhone, macOS or Xcode test.
- No iOS FPS figure. Every frame-time number here comes from Mesa lavapipe (software rendering).
- No playtest with people.
- Multiplayer is **not** complete. M3 has an architecture and a verified in-process spike only.

## 1. Baseline check
- **Repo state:**
  - `claude/m2-2-1-release-readiness` @ `fa2f165` was the newest commit on the remote.
  - The working tree was clean.
  - The branch `claude/master-visual-production-m3` did not exist and was created from that commit.
- **Baseline tests:** `scripts/run_tests.sh` = 184 / 69 / 17, as reported. CI on `fa2f165` was green.
- **Baseline screenshots:** captured from the baseline before any change, at the same resolutions and scenario as the "after" images.

## 2. Commits
| Commit | Content |
|---|---|
| `5ccf327` | Production kit (asset forge), board + HUD visual pass, VFX, playtest batch tool + 3,000-match batch |
| `09a48ae` | M3 spike: authoritative host, thin clients, loopback network, end-to-end test |
| `2cd6771` | CI: actions v5, release-lock job |
| `1190d2c` | Art direction doc, M3 architecture doc, corner-lot fix + test, playtest kit, upload-artifact v6 |
| final (see hand-off) | Low-preset material detail switch, evidence media / logs, this report |

## 3. Tests
| Where | Result |
|---|---|
| Local `scripts/run_tests.sh` after the last code change | **exit 0 — RESULT 195 passed / 0 failed · CHECKED 79 scripts / 0 failed · UI RESULT 18 / 0** |
| GitHub Actions, run #3 (`5ccf327`) | success |
| GitHub Actions, run #4 (`09a48ae`) | success |
| GitHub Actions, run #5 (`2cd6771`) | success — `godot-tests` and the new `release-lock` job (log: "public build: 0 files · internal build: 1 file · RELEASE LOCK OK") |
| GitHub Actions, run #6 (`1190d2c`) | success — both jobs; no Node 20 deprecation warning left after checkout@v5, cache@v5, upload-artifact@v6 |
| Final commit | reported in the hand-off (pushed last) |

**New tests (12 tests in 4 files; all pre-existing tests unchanged):**

| Test | What it checks |
|---|---|
| `unit/test_production_kit.gd` (5) | Every building level exists, uses only library materials, ≤ 8,000 triangles, fits the lot and the camera framing |
| | Levels grow in height (L3 ≥ L1 + 0.35 m) |
| | Districts differ (≥ 6 distinct L3 heights) |
| | Four distinct pawn silhouettes |
| | **Baked die faces match the rules mapping** (red pip up; 2–6 pips per face) |
| | Font has the Vietnamese glyphs |
| | Every icon the HUD and board use exists |
| `unit/test_playtest_batch.gd` (4) | CSV columns, turns-by-seat sum, same seed → same row, analysis shares, rules fingerprint |
| `integration/test_net_loopback.gd` (2) | See §8 |
| `ui/test_ui_readability.gd::test_lots_are_axis_aligned` | Corner-tile regression |

**Found and fixed by tests or review during the work:**
- **HUD panels overflowed the safe area** once icons were added (two existing UI tests failed). Fix: label widths now account for icons and badges.
- **The results sheet covered the board.** Fix: compact two-column ranking.
- **Buildings outside the lot and footprint budget** (kit test): D4 flowers, D5 palm, D6 spire too tall, D5 L2 lower than L1.
- **Corner property tiles were rotated 45°** (band, frame and building). Found in a close-up render; the new test fails on the old code.
- **Icons on gold buttons rendered as solid blobs.** Fix: icon details became mask cut-outs.
- **Water moiré at distance.**

## 4. Visual production — what is real and integrated
**Pipeline:**
- `client/tools/asset_forge/` (GDScript, run by `scripts/forge_assets.sh`) bakes real project assets.
- It is deterministic: a re-run produced 111/111 byte-identical files.
- The game loads only the baked files.
- Budgets and readability are enforced by tests.
- Design system: `docs/art_direction/ART_DIRECTION.md`.

| Asset set | Files | Integrated in |
|---|---|---|
| Typeface Be Vietnam Pro (OFL 1.1, external, licence bundled) | `client/assets/fonts/` (5 weights + OFL.txt) | `UiTheme`, all HUD text, 3D Start label |
| Tileable textures (9 detail + 7 normal + contact shadow) | `client/assets/textures/` | Material library |
| Material library (16 standard + window glow + contact shadow) | `client/assets/materials/` | Every kit model |
| **21 buildings** (7 architectural families × 3 levels) | `client/assets/models/buildings/d1_l1.res … d7_l3.res` | `BoardView.show_level` |
| Board, street and harbour kit (36 pieces: tile slab/top, lot pad, unit boxes, lamps, 5 tree types, bench, planter, bollard, boats, yacht, pier, fountain, landmark, 4 background blocks, owner flag) | `client/assets/models/kit/` | `BoardView.build` (one merged static mesh) |
| 4 pawns (crown, top hat, rook, gem) + rounded die | `client/assets/models/tokens/`, `dice/` | `TokenView`, `DiceView` |
| 13 HUD 9-slice skins | `client/assets/ui/skin/` | `UiTheme` buttons and panels |
| 29 SVG icons | `client/assets/ui/icons/` | Action buttons, titles, cards, toasts, special tiles, board markers |

**Scenes and scripts changed:**
- `main.tscn`, through `board_view.gd`, `token_view.gd`, `dice_view.gd`, `event_presenter.gd` (VFX, auction-lost feedback), `game_hud.gd`, `ui_theme.gd`, `quality.gd`, `water.gdshader`.
- New: `vfx.gd`.

**Board readability:**
- **Ownership:** coloured frame plus a flag; the tile is never flooded with colour.
- **District:** band with a gold trim.
- **Level:** building mass.
- **Auction:** amber gavel marker.
- **Upgradeable now:** green arrow marker.
- **Active tile:** glow frame.

**Effects:**
- Purchase, auction-win and upgrade bursts; construction dust; bankruptcy smoke.
- "Bạn đã thua đấu giá …" toast when the human was outbid.
- `--reduced-motion` turns the effects off.

**Media (all from real runs of the project at the named resolution, lavapipe, in `docs/media/m2_3/`):**

| File | Shows |
|---|---|
| `portrait_0{1..4}_*_before_after.jpg` | 786×1704 with notch, medium. Left = baseline `fa2f165`, right = this branch. Buy, auction, upgrade menu, results |
| `landscape_buy_before_after.jpg` | 1704×786: top = before, bottom = after |
| `landscape_results_after.jpg` | Landscape results |
| `after_presets_low_medium_high.jpg` | Same scene in all three presets |
| `closeup_a.jpg`, `closeup_b.jpg` | Close cameras on the same scene (art review; HUD hidden) |
| `asset_sheet_buildings.jpg`, `asset_sheet_props.jpg` | Every building level, kit piece, pawn and die |
| `one_turn_786x1704.mp4` | 30 s Movie Maker clip (fixed 30 fps, medium, notch emulation): one full round of 4 turns with the new board, pawns, dice, toasts and HUD. The human seat is played by the HUD autopilot, so no finger taps are shown |

**Layout is unchanged where it mattered:**

| | Before | After |
|---|---|---|
| Portrait ring share | 31.1% | 31.0% |
| Portrait smallest tile | 45.8 px | 45.8 px |
| Landscape ring share | 23.4% | 23.2% |
| Landscape smallest tile | 37.5 px | 37.3 px |

The top bar is slightly taller because of the avatar badges.

**What is still a sample, not final art:**
- Buildings and props are procedural (boxes, lathes, cylinders) with real materials. There is no sculpted detail, LOD or hand-painted texture.
- Character art is emblems, not illustrated characters.
- No audio.
- No pre-match setup or character-selection screen exists in the current flow, so none was redesigned.
- No trade-proposal UI.

## 5. Rendering cost (measured, lavapipe software renderer — NOT a device)
Capture scenario "buy prompt", 786×1704 portrait, same scene before and after (`docs/test-logs/m2_3_visual/`):

| Preset | Total draw calls before → after | 3D scene draw calls | Shadow draw calls | Primitives (frame) |
|---|---|---|---|---|
| Low | 71 → 91 | 37 → 38 | 0 → 0 | 18,136 → 81,818 |
| Medium | 101 → 119 | 37 → 38 | 30 → 28 | 31,610 → 158,946 |
| High | 101 → 119 | 37 → 38 | 30 → 28 | 40,502 → 222,084 |

- The 3D scene stays at about 38 draw calls (one merged static board, one mesh per building).
- The total grows by about 18–20, mostly from the richer HUD: icons, badges, skins.
- Triangles grew about 5.7× (3D scene: 13.5k → 77k) because of real windows, roofs and props.

**In-app benchmark** (DeviceProbe, 20 s per preset, 4 players, 786×1704, debug run, lavapipe):

| Preset | Before `fa2f165` | After, full-detail Low | After, Low without triplanar detail (final) |
|---|---|---|---|
| Low | 13.4 FPS · p95 95.9 ms | 7.5 FPS · p95 145.9 ms | **9.6 FPS · p95 126.4 ms** |
| Medium | 7.5* | 7.5* | 7.5* |
| High | 7.5* | 7.5* | 7.5* |

\* Godot limits a frame's delta to 8 physics steps (133 ms), so on this software renderer medium and high **saturate at 7.5 FPS before and after**. They cannot be compared here.

**Conclusions:**
- The new kit is heavier on a CPU rasteriser. The final Low preset turns off the triplanar detail and normal maps to claw part of it back.
- **Whether the iPhone 14 Pro holds 30 FPS is unknown** until the device checklist is run (`docs/device/IPHONE14PRO_TEST_CHECKLIST.md` §E).
- Load (engine start → first frame), lavapipe: 2.9 s → 3.8 s.
- Static memory peak: 59.9 → 63.3 MB.
- Reported VRAM: 203 → 212 MB.

## 6. Playtest automation (M2.3)
- **Tool:**
  - `scripts/run_playtest_batch.sh --out=/abs/dir [--players=2,3,4] [--matches=N] [--seed=S] [--mode=fast|debug] [--repro=K]`;
  - uses the real engine and the existing `BotPlayer` through `MatchSimulator`.
- **Output:**
  - `matches.csv` (30 columns per match: seed, characters, end reason, rounds, turns, turns by seat, game-clock duration, CPU ms, winners, bankruptcies, auctions, purchases, upgrades, trades, abilities, timeouts, stuck / invariant / rejection counts, state hash);
  - `batch.json` (meta: engine, SHA-256 of every rules file, balance status, args, time model; analysis);
  - `summary.md`.
  - Debug mode also writes every match's full event log.
- **Batch run** (`docs/test-logs/m2_3_playtest_batch/`): 3 × 1,000 matches, seeds 1–1000 per player count, 79.8 s CPU in total.
  - 0 stuck, 0 invariant errors, 0 rejected bot commands.
  - Reproducibility: 150 matches re-run with **0** state-hash mismatches.

| Players | Median match (game clock) | p90 | p95 | max | > 35 min | End reasons | Matches with a bankruptcy |
|---|---|---|---|---|---|---|---|
| 2 | 14.4 min | 17.1 | 17.9 | 20.6 | 0 | 44.4% last solvent, 55.6% round cap | 44.4% |
| 3 | 16.6 min | 19.0 | 19.8 | 23.5 | 0 | 7.0% / 93.0% | 41.3% |
| 4 | 18.1 min | 20.6 | 21.2 | 24.0 | 0 | 0.7% / 99.3% | 31.3% |

Seat win rates (±95% CI):

| Players | Seat 0 | Seat 1 | Seat 2 | Seat 3 |
|---|---|---|---|---|
| 2 | 54.7 ± 3.1 | 45.3 | | |
| 3 | 38.8 ± 3.0 | 31.7 | 29.5 | |
| 4 | 29.7 ± 2.8 | 27.3 | 23.9 | 19.1 ± 2.4 |

The first-seat advantage is still visible. No time-cap endings occurred.

**Limits:**
- Bots are scripted heuristics.
- Durations come from the M1 time model, not human play.
- **This does not replace human playtests.**
- The 4-player median of 18.1 min is still below the GDD target of 22–27 min. That needs human timing before any balance change; none was made.

**Playtest kit:** `docs/device/PLAYTEST_CHECKLIST.md` + `playtest_log_template.csv`, extended with:
- auction and upgrade appeal;
- unclear rules;
- the point where interest drops;
- a phase column.

No player data was invented.

## 7. Release readiness and CI
- **Workflow:**
  - `godot-tests`: full suite from a clean checkout.
  - `release-lock` (new):
    1. installs the pinned Godot plus only the Linux release export template, both SHA-512 verified (`scripts/ci/install_templates.sh`);
    2. exports **Linux Public Release** and **Internal Test**;
    3. runs both with every device-tool flag;
    4. fails if the public build writes any report or telemetry file, or if the internal build writes none.
  - Mutation-checked locally: forcing the tools on makes it fail.
- **Failure detection:** by exit code (proven on a clean clone in M2.2.1). There is no iOS build in CI (needs macOS + Xcode).
- **Actions:** checkout@v5, cache@v5, upload-artifact@v6. The Node 20 deprecation warning is gone (run #6 log).
- **Branch protection:** `main` is currently **not protected** (GitHub API: `protected: false`). The available GitHub tools cannot change repository protection rules, and it is an owner setting. **Not enabled. Owner action:** require the checks `tests / godot-tests` and `tests / release-lock` on `main`.

## 8. M3 technical foundation
- Architecture, decisions, milestones, modules and test strategy: **`docs/M3_ARCHITECTURE.md`**.
- **Spike** (`client/scripts/net/`, not used by the offline game):
  - `NetProtocol` (v1 frames, 16 KiB, version check, canonical state hash);
  - `MatchHost` (engine + server clock, session-to-seat binding, validation, ordered broadcast, snapshots);
  - `NetClient` (no rules; gap/duplicate checks; resync; same-id resend);
  - `LoopbackNetwork` (deterministic latency; a disconnect drops in-flight frames).
- **End-to-end test**, 4 clients, full match, with a mid-match disconnect and reconnect plus injected duplicates:
  - all clients converge on the server state hash and `state_version`;
  - 0 gaps;
  - the server state equals a replay of only the applied commands, so duplicates had no second effect;
  - rejected as expected: spoofed `player_id`, unknown token, oversized frame, wrong protocol version, stale state;
  - snapshot frame 1,394 bytes.
  - Last run: 285 commands, 35 duplicates, 1 dropped frame, 9 snapshots.
- **Test-harness shortcut:** the bots read the host engine to choose moves. Real clients need a view model (M3-2).

## 9. Done, prepared, blocked
| Area | Done (verified) | Prepared only | Blocked |
|---|---|---|---|
| Visual | Kit assets baked and integrated; new HUD; VFX; before/after media; tests | Art direction for a 3D artist to replace procedural models | Production-grade sculpted art: needs an artist / DCC pipeline |
| Playtest | Batch tool + 3,000-match analysis; kit updated | Human playtest sheet | Human sessions |
| M3 | Architecture + in-process spike with e2e test | Milestones M3-1…M3-5 | Hosting / runtime decisions (owner) |
| CI / release | Two CI jobs green on GitHub; public lock verified on exported builds | Branch-protection instructions | Enabling protection (owner setting) |
| Device | Internal / public export presets; checklists | — | Mac + Xcode + iPhone 14 Pro, Team ID |

## 10. Still needs a Mac / Xcode / a real iPhone
1. `IOS_TEAM_ID=… scripts/export_build.sh ios internal release`, then sign and run in Xcode (`docs/device/IOS_BUILD_GUIDE.md`).
2. Device checklist §E: FPS / frame time for Low, Medium and High with the **new kit**. This decides whether triangle or texture budgets must drop.
3. Safe area / Dynamic Island in portrait and landscape; readability of the new font and icons at arm's length.
4. Background / foreground / force-quit behaviour (D5 / D6).
5. Public build check: a long press does nothing extra, and no Files-app folder exists.

## 11. Decisions only the owner can make
1. **Art direction sign-off.** Approve the miniature-city direction, the palette and the district families in `ART_DIRECTION.md` and the media, or redirect, before paying for production art.
2. **Server runtime and hosting budget** (M3 D1–D2): headless Godot (recommended) vs a Node port; which provider / budget.
3. **Reconnect policy** (M3 D5): how long a disconnected seat is held and what happens next.
4. **Branch protection on `main`** with the two required checks.
5. **Pacing and seat advantage.** Bots show a 4-player median of 18.1 min (target 22–27) and a first-seat edge. Decide after human playtests; nothing was changed.
