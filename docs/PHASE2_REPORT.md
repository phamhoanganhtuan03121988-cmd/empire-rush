# EMPIRE RUSH — Phase 2 Report: Visual Quality · Performance · Multiplayer Production · Playtest

| | |
|---|---|
| Date | 2026-10-18 |
| Engine | Godot 4.7.2-stable |
| Branch | **`claude/visual-performance-multiplayer`**, from `claude/master-visual-production-m3` @ `1493c25` (CI run #7 green) |
| Git | No merge, no PR. `main` and earlier branches were not touched |

**Not changed:**
- game rules and balance (`data/rules/*` untouched);
- the approved GDD;
- force-quit = no match recovery;
- the offline background-timer rule;
- the Public Release telemetry lock (CI `release-lock` green).

`GameState.from_dict` was **added** to the domain. It is a pure data restore, covered by a round-trip test, with no rule logic.

**Not claimed:**
- No iPhone, Mac or Xcode run. **No device FPS.** Every frame time in this report is from lavapipe (software rendering).
- No human playtest. No playtest data was created.
- Multiplayer is not finished. It now runs as separate processes over real WebSockets **on one machine**; no internet, TLS, hosting or phone client.

## 1. Commits (checkpoint per workstream)

| Commit | Workstream | CI |
|---|---|---|
| `d9f82c2` | A1/A2: benchmark tool + render optimisation | run #8 ✅ |
| `7ee4ce3` | C: multi-process multiplayer over WebSockets, disconnect policy, e2e in CI | run #9 ✅ (e2e step passed on the GitHub runner) |
| `a01ed74` | B: 15k-match batch, Python cross-check, replay record, playtest kit | pushed together with the next commit |
| `5c5c5e1` | A3/A4: pawn rings, upgrade/rent/auction text fixes + UI test | run #10 ✅ |
| `c7457b1` | A4/A5: landscape layout, before/after media | run #11 ✅ (full log: 199 / 93 scripts / 20 UI, NET_E2E PASS, no warnings) |
| final | D/E: docs (this report, benchmark procedure, art direction, asset register) | see the hand-off |

## 2. Tests (local, final tree)

| Suite | Result |
|---|---|
| `scripts/run_tests.sh` | **199 unit/integration** passed, 0 failed |
| UI suite | **20** passed |
| Script compile check (now also `res://tools`) | **93** scripts, 0 failed |
| `scripts/run_net_e2e.sh` (multi-process) | PASS in 5 local configurations; also PASS in CI |
| `aggregate_playtest.py --self-test` | PASS (data generated in memory only) |

New tests:
- dict/snapshot round trip;
- host restore from journal;
- bot takeover + reclaim under both policies;
- match replay record;
- upgrade-label lines fit their buttons (fails on the old text, verified);
- pawn rings;
- landscape tiles on screen and outside panels.

## 3. Workstream A — performance and visuals

### A1/A2 Benchmark and optimisation
Details: `docs/test-logs/phase2_perf/README.md`. Setup: lavapipe, 786×1704, fixed scene, 3 runs per side.

| Preset | p50 before → after (mean of 3) | GPU time | Triangles 3D / shadow |
|---|---|---|---|
| Low | 103.2 → **67.4 ms (−35%)** | 92 → 55 ms | 77k → 51k / 0 |
| Medium | 258.0 → **226.8 ms (−12%)** | 246 → 214 ms | 77k → 51k / 77k → 44k |
| High | 548.0 → **470.1 ms (−14%)** | 535 → 458 ms | 77k → 51k / 140k → 44k |

**How the cost was attributed first:** ablations showed the static board/props and the triplanar detail as the largest costs, then water. HUD (~8%) and buildings (~10%) were smaller. Render CPU is ~0.5 ms, so the frame is raster-bound.

**Changes:**
- non-shadow-casting ground mesh;
- orthogonal shadows (Medium) and 2 splits (High);
- windows as quads;
- lighter props;
- planar-UV ground materials;
- anisotropic filtering on High only;
- unshaded lite water with foam on Low.

**Visual check:** `docs/media/phase2/perf_before_after_presets.jpg`. No visible loss on Medium/High. Low water is flatter but keeps colour, ripples and foam.

### A3 Assets
- **Pawns:** each has a seat-colour ring; the active player's ring is opaque and pulses. See `pawns_zoom_before_after.jpg`.
- **Ground pieces:** use the new planar materials.
- **Kit geometry:** reduced (windows, trees, bollards, streetlights). The asset forge stays deterministic, and re-forging no longer churns `.import` uids.
- **Asset register:** new entries GEN-010..012. Fixed a pre-existing CSV error in EXT-001.
- **Not done:** no new buildings or sculpted detail. A visual review of the 21 buildings and the props sheet found no defect worth a change; a 3D artist pass is still the real upgrade.

### A4 UI (only verified issues)

| Issue (seen in screenshots) | Fix | Evidence |
|---|---|---|
| Upgrade buttons wrapped as "Bến Kênh → cấp / 2 / 27 RC" | Two explicit lines, non-breaking spaces | `upgrade_menu_zoom_before_after.jpg`; UI test fails on the old text |
| Rent line "cấp 1 126 · cấp 2 396" read as 1126 | "cấp 1: 126" | `buy_rent_line_zoom_before_after.jpg` |
| Auction with no bid showed "0 RC (—)" | "Chưa ai trả giá · giá khởi điểm 15 RC" | `auction_zoom_before_after.jpg` |
| Landscape board used 16% of the screen (smallest tile 31.7 px) | HUD moved to the right column → **29.2%, 40.8 px** | `landscape_*_before_after.jpg`; test checks every tile corner |

Safe area and touch-size tests are unchanged and green.

### A5 Screenshots
In `docs/media/phase2/`. All use the same scenario (`capture_scenarios.gd`, 4 players, seed 7).
- Portrait 786×1704 with notch, Medium: before = `1493c25`, after = this branch. Scenes: buy, auction, upgrade, results.
- Landscape 1704×786.
- Low/Medium/High.
- Close-ups at 1600×1000.

## 4. Workstream B — simulation and playtest

**B1 — tool verification** (`docs/test-logs/phase2_batch/ANALYSIS.md`):
- Reproducible: 600/600 matches in-process, and 600/600 rows identical when re-run in a separate process.
- 0 missing or duplicate matches.
- One rules fingerprint per row, so versions cannot mix.
- An independent Python recomputation matches the GDScript summary, including the M2.3 baseline (14.4 / 16.6 / 18.1 min).

**B2 — 3×5000 matches:**
- **Duration:** medians 14.5 / 16.6 / 18.2 min (95% CI ±0.07). 0 stuck, 0 invalid, 0 over 35 min.
- **Seat advantage confirmed:** with 4 players, 30.9% → 26.1% → 23.0% → 20.0% (χ² p ≈ 5×10⁻²⁸); mean final net worth follows the same order.
- **Hypotheses only, no balance change:** first-mover land access; possible compensations for the owner to choose (see ANALYSIS.md).
- **Auctions:** always sell with bots, which says nothing about how fun they are.

**B3 — playtest kit:**
- **Existing:** checklist and questions.
- **New:**
  - feedback form template;
  - bug reproduction (internal builds store a replay record; `tools/replay_match.gd` reproduced a real match exactly);
  - anonymous aggregation tool.
- **Not done:** no real playtest data exists. No session has been run.

## 5. Workstream C — multiplayer

- **C1 — what was verified before:** the M2.3 spike was in-process only (`LoopbackNetwork`, simulated time). It is still the fast deterministic test.
- **C2 — server runtime:** headless Godot 4.7.2 works as a WebSocket server (`TCPServer` + `WebSocketPeer`) with the unchanged domain engine.
  - Per match process: RSS ~107 MB (mostly engine baseline), about 1 s of CPU for a whole match.
  - Many matches per process and soak are **not** measured.
- **C3 — multi-process end-to-end** (`scripts/run_net_e2e.sh`, `docs/test-logs/phase2_net_e2e/`).
  - **Setup:** 1 server + 2–4 client processes. Each client's bot decides from its own snapshot view.
  - **Chaos injected:**
    - duplicate commands;
    - hostile frames (spoofed id, stale version, unknown type, 16 KiB+, wrong protocol, non-JSON);
    - faked client state;
    - a voluntary disconnect;
    - a **SIGKILL of the server with restart from a write-ahead journal**.
  - **Checks:** every client converges on the server hash; the journal replays deterministically (twice); invariants hold.
  - **Results:** 5/5 local runs PASS, and PASS in CI.
- **C4 — disconnect policy as configuration** (`DisconnectPolicy`):
  - `timers`: engine timers only.
  - `bot`: a server bot plays the seat after the hold time; the seat is reclaimed on reconnect.
  - `forfeit`: listed but not implemented, because it needs a rule.
  - **Test default proposed:** 60 s hold, then `bot`. Not a final rule.

## 6. Workstream D — CI and release

- **CI:** `tests` workflow, jobs `godot-tests` and `release-lock`. Actions are on checkout@v5, cache@v5 and upload-artifact@v6. The full `godot-tests` log of run #11 contains no warning or deprecation annotation.
- **New CI step:** `godot-tests` runs the multi-process e2e.
- **Godot binary and export template:** pinned and checked against SHA-512 (unchanged). `tools/` stays excluded from client exports, so the server code is not shipped in the app.
- **Branch protection:** `main` is still **not protected** (GitHub API `protected: false`). The available tools cannot change it. **Owner steps:**
  1. GitHub → repository **Settings → Branches → Add branch ruleset** (or *Add rule*) for `main`.
  2. Enable **Require a pull request before merging**.
  3. Enable **Require status checks to pass**, and add `godot-tests` and `release-lock` (workflow `tests`).
  4. Optionally enable **Require branches to be up to date** and **Block force pushes**.
- **Device measurement procedure:** `docs/device/PERFORMANCE_BENCHMARK.md`. It separates the desktop bench from the phone bench and lists the build, phone-state and run-order steps.

## 7. Done / not done / blocked

| Done (implemented, integrated, tested, with artifacts) | Not done | Blocked (needs owner or hardware) |
|---|---|---|
| Benchmark + ablations, −12…−35% lavapipe frame time | LOD meshes (little value at the fixed camera); HUD overdraw measured separately | iPhone FPS, thermal and memory (needs Mac + Xcode + iPhone) |
| UI fixes ×4 with tests; landscape layout | New/sculpted buildings | Human playtests (needs testers) |
| Pawn rings; planar materials; lite water | Client event projection (the test client re-fetches snapshots) | Hosting, TLS, accounts (paid services need approval) |
| 15k-match verified batch + Python statistics | `forfeit` policy (needs a rule) | Branch protection (owner setting) |
| Multi-process WebSocket e2e with server crash recovery, in CI | Many matches per server process, 24 h soak | |
| Replay record + replay tool; playtest form, guide, aggregator | | |

## 8. Decisions for the owner
1. **Seat-order advantage** (bots: 4-player seat 0 wins 31% vs seat 3 20%). Choose between accepting it (seats are random for people) or a compensation to simulate, for example start cash or offset start. ANALYSIS.md lists the options.
2. **Disconnect policy:** confirm or replace the test default (60 s hold, then bot). Decide whether `forfeit` should exist and what happens to the player's assets.
3. **Pass bar for device FPS** (proposal in the iPhone checklist).
4. **Hosting/TLS budget** before M3-4.
5. **Enable branch protection** on `main` (steps in §6).
