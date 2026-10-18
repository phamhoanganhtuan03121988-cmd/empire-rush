# EMPIRE RUSH — Phase 3 Report: Visual Polish · Network Hardening · Gameplay Validation · Release Preparation

| | |
|---|---|
| Date | 2026-10-18 |
| Engine | Godot 4.7.2-stable |
| Branch | **`claude/phase3-production-hardening`**, from `claude/visual-performance-multiplayer` @ `633961b` (the newest commit; CI #12 green) |
| Git | No merge, no PR. `main` and earlier branches were not touched |

**Not changed:**
- game rules and balance (`client/data/rules/*`, fingerprint `d5e3a9a877afe932`);
- the GDD;
- force quit = no match recovery;
- the offline background-timer rule;
- the Public Release telemetry lock (CI `release-lock` green).

**Not claimed:**
- No iPhone, Mac or Xcode run. **No device FPS.**
- No Internet, real LAN, public TLS certificate or hosting.
- No human playtest. No playtest data was created.

Every network result below comes from processes on **one machine**.

## 1. Commits (one checkpoint per workstream)

| Commit | Content | CI |
|---|---|---|
| `42c4e8d` | B: RoomServer, hardening, 9-scenario multi-process e2e, test runner traps runtime errors | run #13 ✅ |
| `c973a60` | A: render −27/−28% (Medium/High), UI review fixes, seat-experiment knobs, readiness check in CI | run #14 ✅ |
| `ecc092f` | A4/D: building level heights, iOS export re-check | run #15 ✅ |
| `73e2fb9` | C: seat experiments (63k matches), scroll-hint fix, final media | run #16 ✅ |
| final | D/E: this report, docs, final e2e logs and benchmark | see the hand-off |

## 2. Tests

| Suite | Local result (final tree) |
|---|---|
| `scripts/run_tests.sh` (unit + integration) | **205** passed, 0 failed (Phase 2: 199) |
| UI suite | **21** passed (Phase 2: 20) |
| Script compile check | 97 scripts, 0 failed |
| Multi-process e2e (`scripts/run_net_e2e.sh`, 9 scenarios) | **9/9 PASS** in one final run (§4). CI runs `chaos` + `concurrent` on every push |
| Static readiness (`scripts/ci/check_repo_readiness.py`) | 26/26 PASS; in CI (`release-lock` job) |
| Clean clone of the baseline before any change | 199 / 93 scripts / 20 UI passed |

**Test-harness defect fixed.**
- A test that hit a runtime script error half-way (for example a missing dictionary key) was reported as **PASS**, because the remaining asserts never ran.
- Both runners now install a `Logger` (`tests/helpers/script_error_trap.gd`). Any runtime script error during a test fails that test.
- Verified with a deliberately crashing probe test, which FAILs. No existing test was hiding such an error.

## 3. Workstream A — visual polish and performance

### A1/A2 Benchmark (lavapipe software renderer, 786×1704, same scene; `docs/test-logs/phase3_perf/`)
**Bottlenecks** (ablations): sampling the static board/props textures (world triplanar = 3 fetches per texture), then water, then shadows. Render CPU is ~0.5 ms, so the frame is raster-bound.

| p50 ms | Low | Medium | High |
|---|---|---|---|
| Phase 2 end (`42c4e8d`, 3 runs) | 67.2 | 232.8 | 481.3 |
| Phase 3 final (3 runs) | 69.0 (68, 70, 69): unchanged, within noise | **167.3** (166, 173, 162): **−28%** | **352.6** (350, 363, 345): **−27%** |

Changes, each with before/after numbers and images:

| Change | Effect | Images |
|---|---|---|
| UV-baked triplanar for static merged meshes (one fetch instead of three; tangents correct) | Medium −17.5%, High −23% | `docs/media/phase3/closeup_*_uvbake_before_after.jpg` (no visible change) |
| Shadow atlas 2048 explicit for Medium/High | Within noise (−5% / −2%); video memory −23 MB. **Config alignment:** Godot's default is 4096 on desktop but 2048 on iOS/Android, so desktop benchmarks used to measure a heavier shadow pass than phones run | — |
| Water no longer receives shadows | Medium −9% | `water_shadow_before_after.jpg`: the removed shadows were blotchy artifacts |

Load time is now recorded by the benchmark (`meta.load_ms`): scene load + instantiate 170–232 ms, first frame 718–988 ms (lavapipe).

### A3 UI review
**New capture scenes:** incoming trade, opportunity choice, tile info, rescue. All are captured in portrait and landscape, at Low/Medium/High, together with the existing buy / auction / upgrade / results scenes.

| Verified issue | Fix | Evidence |
|---|---|---|
| Rescue: "BÁN Phố Đèn / Lồng / +60 RC" broke over 3 lines; the list cut a row in half; the bankruptcy button was hidden with no sign that the list scrolls | Label "name / BÁN +N RC". The list ends after a whole row, with a "▼ Kéo để xem thêm (N lựa chọn)" hint. Shorter body text. Re-measured after layout (wrapping buttons only know their height then). The hint is removed when everything fits (landscape) | `rescue_panel_before_after.jpg`, `landscape_08_rescue_before_after.jpg`; UI test `test_rescue_list_scrolls_by_whole_rows_with_hint` |

No other defects were found in the trade, choice, tile-info, auction, upgrade or results screens in either orientation. Those screens were not reworked.

### A4 Assets
**Measured in-game issue:** building levels did not follow the art-direction height bands. For example D4 L2 was 0.59 m and D4 L3 0.61 m (almost identical), D1 L3 0.79 m and D4 L1 0.18 m.

**Fix:**
- Re-massed D1 L3, D3 L2, D4 L1/L2/L3, D5 L1/L2 and D7 L1/L2, keeping each district's architectural family.
- A new test enforces the bands (L1 0.30–0.45, L2 0.60–0.80, L3 1.00–1.30 m) and the steps between levels.
- The forge stays deterministic (verified with two identical runs).
- Evidence: `buildings_levels_before_after.jpg`, `portrait_*_before_after.jpg`.
- Asset register updated (GEN-005 note, GEN-013). No new external assets.

## 4. Workstream B — multiplayer hardening

**B1 — verified first:**
- the server is authoritative;
- identity comes from the session;
- duplicate commands are deduplicated;
- journal replay is deterministic;
- the client view is built from the snapshot only.

Two defects found and fixed while building the multi-room server:
- an ended room's journal was reopened in write mode and truncated (caught by the e2e checker);
- server counters were lost across a restart.

**B2/B3 — `RoomServer`** (PROTOCOL.md §11):
- private rooms by code; many concurrent, isolated matches per process;
- 128-bit session tokens stored only as SHA-256; one live link per seat;
- per-link rate limit, handshake timeout, room/link limits;
- per-room write-ahead journals and crash recovery;
- optional TLS (`wss://`) with certificate verification.

**Multi-process scenarios** (separate OS processes over real sockets; logs in `docs/test-logs/phase3_net_e2e/`):

| Scenario | Result |
|---|---|
| chaos — 4 clients; duplicates, hostile frames, a 1000-frame flood, faked state, drop > hold (bot takeover + reclaim), **server kill -9 + restart** | PASS — 239 state versions; 12 duplicates deduplicated; rejected STALE_STATE 4 / NOT_OWNER 1 / WRONG_PHASE 1 / BAD_REQUEST 1; malformed frames refused (oversize 2, wrong protocol 2, bad 1); 78 flood frames rate limited; bot took over (6 moves) then the player reclaimed; 1 restart from journals; 6 reconnects; server RSS ≤ 110 MB |
| concurrent — 3 rooms (2/3/4 players) at once, isolation via per-room replay | PASS — rooms of 3/2/4 players ended (round cap / last solvent / round cap); every room replays alone to its final hash |
| sequential — 3 matches back to back; object count and memory after each | PASS — object count 1497 → 1497 → 1497, static memory 25.4 MB each time; rooms and links back to 0 |
| client_restart — a client **process** killed with kill -9 and restarted, resumes its seat from its session token | PASS — the restarted process resumed its seat and the 3 clients converged |
| abandon — the player never returns; the bot plays to a normal end; no forfeit | PASS — 1 takeover, the bot made 83 moves, the match ended on the round cap, 0 reclaims (as intended) |
| tls / tls_bad_ca — verified `wss://`; a wrong CA and plain `ws://` are refused | PASS — verified `wss://` match completed; the negative test (wrong CA, plain ws) gave up after 3 attempts each and created no room |
| netem — local proxy: 40–200 ms latency, every connection cut after 6–14 s | PASS — 36 of 39 connections cut by the proxy; 36 reconnects; converged |
| lan — server on 0.0.0.0; clients via 127.0.0.2, 127.0.0.3 and the host IP (same machine) | PASS — 3 clients on 3 different addresses converged |

**B4 — disconnect policy:**
- It is configuration, not a rule.
- Test default: hold the seat 60 s, then a bot takes over; the player reclaims the seat on reconnect; no forfeit and no change to how assets are distributed.
- **Tested in-process and multi-process:**
  - no takeover inside the 60 s hold;
  - takeover after it;
  - reclaim on reconnect;
  - the match ends while the player is away;
  - a server restart during a takeover (the takeover resumes).

**B5 — LAN/Internet:**
- Not possible here: the container has one host and no public endpoint.
- **Prepared:** `docs/SERVER_DEPLOYMENT.md`: run flags, TLS options, a systemd sketch, what is still missing.
- **Owner needs to provide:** host, domain, certificate.

## 5. Workstream C — gameplay and balance evidence (`docs/test-logs/phase3_balance/ANALYSIS.md`)

**C1 — Phase 2 data:**
- The rules fingerprint in all 15,000 rows matches the current rules.
- Characters are balanced across seats, and the seat advantage holds within each character.
- An independent Python recomputation matches the GDScript summary.

**C2 — experiment P3-SEAT-v1/v1b** (named, experiment-only options; `balance.json` unchanged):
- 63,000 paired-seed matches, 0 stuck or invalid.
- Seat spread (best seat − worst seat, pp) for 2p / 3p / 4p:

| Variant | Spread 2p / 3p / 4p | Side effects |
|---|---|---|
| V0 baseline | 5.1 / 10.7 / 11.9 | — |
| V2 zero-sum ±50/±80/±90 | 0.1 / 6.5 / 6.3 | none (length, bankruptcy and net worth within noise) |
| **V5 zero-sum ±50 / ±130 / −150,−50,+50,+150** | **0.1 / 3.3 / 3.0** | none (length 14.47 / 16.48 / 18.22 min vs 14.46 / 16.50 / 18.23) |
| V3 later seats +30 each (budget grows) | 3.5 / 9.1 / 9.3 | +1–3% money in the game |
| V4 staggered start squares | 6.9 / 5.5 / 5.6 | 2p worse; 4p bankruptcies 30.9 → 32.9% |

**C3 — playtest kit:**
- **Complete:** checklist, feedback form, bug reproduction, replay tool, anonymous aggregation (Phase 2).
- **No human sessions have been run,** so game feel is **unverified**.

## 6. Workstream D — mobile readiness (iPhone 14 Pro)

| Item | Status |
|---|---|
| Export presets | Internal Test (`device_tools`) and Public Release (no tools) |
| Team ID | Empty in the repo; injected from `IOS_TEAM_ID` into a temporary copy |
| Bundle ID | Placeholder `com.example.empirerush`, overridable with `IOS_BUNDLE_ID` |
| Signing files | None committed (checked in CI) |
| Xcode project export on Linux | Ran for **both flavours** (fake Team ID, throw-away worktree). Verified: Info.plist orientations (portrait + landscape), Files access only in Internal, privacy manifest present with tracking = false, iOS 16, iPhone only, no `tests/` or `tools/` in the `.pck` (`docs/device/IOS_BUILD_GUIDE.md` §3) |
| Safe area / orientation | UI tests: notch safe area, touch sizes, landscape panels and tiles |
| Telemetry | On in Internal (with replay record), off in Public (CI `release-lock`) |
| Benchmark JSON retrieval and FPS / frame-time / memory / thermal checklist | `IOS_BUILD_GUIDE.md` §5, `IPHONE14PRO_TEST_CHECKLIST.md`, `PERFORMANCE_BENCHMARK.md` |
| **Not done** | Signing, building the `.ipa`, installing, measuring. **Needs a Mac + Xcode + the iPhone.** The 30 FPS target remains unverified |

## 7. Workstream E — CI and repository

- `godot-tests` runs the unit/UI suites and the multi-process e2e (`chaos` + `concurrent`).
- `release-lock` runs the export lock check and the new static readiness check (presets, orientation, secret scan, asset-register coverage).
- Actions are on checkout@v5, cache@v5 and upload-artifact@v6. No warning or deprecation annotations in the logs read.
- No secrets in the repo:
  - committed e2e logs exclude session files and the throw-away TLS keys;
  - tokens are never logged.
- **Branch protection on `main`:** still **not enabled** (GitHub API: `protected: false`). The tools in this session cannot change it. **Owner steps:**
  1. Settings → Branches → Add branch ruleset for `main`.
  2. Turn on *Require a pull request*.
  3. Turn on *Require status checks*: `godot-tests` and `release-lock`.
  4. Turn on *Block force pushes*.

## 8. Real blockers
1. **iPhone measurements:** need a Mac with Xcode, an Apple account, the Team ID and the iPhone 14 Pro.
2. **Internet / TLS / hosting:** need an owner decision (provider, budget), a domain and a certificate. No paid service has been chosen.
3. **Human playtests:** need testers.
4. **Branch protection:** needs the repository owner.

## 9. Decisions only the owner can make
1. **Seat advantage:** keep the rules as they are (seat order drawn at random), or approve a zero-sum start-cash offset like V5 for a human playtest. Nothing changes until then.
2. **Disconnect policy:** confirm or change the test default (60 s hold, then bot, reclaim on return). Decide whether a forfeit rule should exist.
3. **Hosting/TLS:** provider and budget.
4. **iOS identity:** Team ID (environment variable only), final bundle ID, app icon.
