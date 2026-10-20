# M2.2.1 — Offline Lifecycle & Release Readiness

Date: 2026-10-18 · Branch: `claude/m2-2-1-release-readiness` (from `claude/m2-2-device-validation` @ `f04a089`) · Engine: Godot 4.7.2-stable

**Unchanged:** domain rules (`client/scripts/domain/*`), rules/balance data, and every pre-existing test assertion. Gameplay and economy results in the foreground are identical; this is tested via event-log equality.

**Changed by decision:** the offline timer behaviour in the background (§1). The GDD got a one-paragraph note, and the full rule is in `docs/RULES_M1.md` "Offline lifecycle".

**Not claimed:** no iPhone, macOS or Xcode test was possible in this environment.

## Summary
| Item | Status | Evidence |
|---|---|---|
| A. Offline clock pauses in the background, resumes with remaining time | **Done**, 8 deterministic tests; a mutation check shows they catch the old behaviour | `client/tests/unit/test_offline_lifecycle.gd` |
| B. Device tools locked in public release builds | **Done**: code gate, preset split, config + UI tests, verified on exported Linux binaries and generated iOS Info.plists | `docs/test-logs/m2_2_1/` |
| C. CI (GitHub Actions) | **Done and run on GitHub: run #1 green** (184 / 69 / 17) | [run 39106251564](https://github.com/phamhoanganhtuan03121988-cmd/empire-rush/actions/runs/39106251564), `ci_github_run_1.txt` |
| Full `scripts/run_tests.sh` after the last commit | **exit 0:** RESULT 184 / 0 · CHECKED 69 / 0 · UI 17 / 0 | `docs/test-logs/m2_2_1/run_tests_final.txt` |

## 1. Offline timers: background, foreground, force quit
### 1.1 Design
- The domain already read time only through the injected `MatchClock`. In offline mode, `LocalMatch` advanced it by the frame delta. The new `LifecycleGate` (`client/scripts/presentation/lifecycle_gate.gd`) sits between them. No domain code changed.
- **Pause:**
  - On `NOTIFICATION_APPLICATION_PAUSED` (OS suspend) the gate holds a reason.
  - On phones only, `NOTIFICATION_APPLICATION_FOCUS_OUT` also holds one (Control Center, call banner, app switcher).
  - While any reason is held, `LocalMatch` does not advance the clock, does not call `engine.advance()` and does not let bots act.
  - Therefore no turn, auction, trade or rescue deadline moves, the 30-minute cap does not advance, and no timeout can fire.
- **Resume:** the clock continues from where it stopped, so the turn timer is neither reset nor reduced.
- **Background time cannot leak in:**
  - iOS can deliver the first frame after resume with the whole suspension in its delta, before or after the resume notice.
  - Frames that arrive while paused are discarded.
  - The first frame after the last reason is released counts only `min(delta, real time since resume × time_scale)`. Real time comes from an injectable monotonic source (`Time.get_ticks_usec` in the game, a fake in tests).
  - Cost: at most about one frame (~16 ms) of game time is lost per resume.
- **No duplicate timeouts:** timeouts are applied only by `engine.advance()` when the clock reaches a deadline. A frozen clock cannot reach one, and an applied timeout moves the phase on, so it is never applied again.
- **Animation / pending UI:**
  - The presenter's event queue is untouched.
  - If frames keep running while paused (focus loss on a phone), animations finish and buttons work.
  - Commands are validated against the frozen clock, so they are treated exactly as just before the pause.
  - On a real suspend, iOS stops frames, so nothing runs.
- **Desktop:** alt-tab does not pause (`pause_on_focus_loss = OS.has_feature("mobile")`). An app that stays in the foreground runs through the gate unchanged; `filter(delta)` returns `delta`, which is tested.
- **Telemetry:** `SessionTelemetry` uses the same gate, so turn and session times exclude the background. The summary now has `background_pauses` and `background_withheld_s`.
- **Scope:** offline only. Online play (M3) keeps server timers running and relies on reconnect plus snapshot (PROTOCOL.md). Nothing here assumes multiplayer.

### 1.2 Force quit
**There is no match recovery.** The offline match exists only in memory. If the app is force-quit, killed by iOS while suspended, or crashes:
- the match is lost;
- the next launch starts a new match;
- no result or telemetry summary is written for the lost match.

In internal test builds:
- the device report saved every 30 s and on suspend remains;
- the launch marker records the previous end: `background` means killed while suspended (expected for a force quit); `running` means it died in the foreground (a crash).

Recovery (save/restore) was **not** added, as instructed. It needs its own design. Documented in RULES_M1.md and the GDD note. Checklist D6 now tells testers to expect a fresh match.

### 1.3 Tests (all simulated time; no sleeps, no dependence on machine speed)
| # | Requirement | Test |
|---|---|---|
| 1 | Background with plenty of time | `test_background_with_time_left_keeps_remaining_time`: 35 s left → 5 min away → 34.9 s left (only the 0.1 s real resume frame counts), no timeout |
| 2 | Background near the deadline | `test_background_near_deadline_times_out_only_after_foreground_time`: 1 s left → 10 min away (big frame before the resume notice) → 0.9 s left; no timeout until 0.9 s of foreground, then exactly one |
| 3 + 4 | Many cycles; resume does not reset | `test_many_cycles_do_not_reset_or_drain_the_turn_timer`: 6 cycles (both frame orderings); remaining time checked after each pause and each foreground stretch |
| 5 | Timeout not fired twice | `test_timeout_fires_once_across_pause_resume`: the timeout count is unchanged by 5 later pauses; event log identical to a reference run |
| 6 | Match cap ignores the background | `test_time_cap_ignores_background_time`: 1 h away after 1000 s does not end the match; ends by `time_cap` on foreground time (1800–1920 s), identical to the reference |
| 7 | Foreground-only unchanged | `test_foreground_only_is_unchanged_and_desktop_focus_loss_does_not_pause`: clock equals plain frame time; desktop focus loss does not pause; event log equals a run with no lifecycle events, bots active |
| + | Bots and background together | `test_bots_and_background_match_reference`: 4 players, bots acting, 4 background periods: event log and state hash identical to the foreground-only reference |
| + | Gate unit | `test_gate_unit_behaviour`: overlapping reasons, cap after resume, time_scale |

**Mutation check:** I removed the gate from `LocalMatch` (the old behaviour) and ran the suite. **35 assertions failed, across 6 of the 8 new tests.** Test 7 (foreground only) and the gate unit test still passed, as they should. The gate was then restored.

## 2. Telemetry and device tools in release builds
- **`BuildFlavor`** (`client/scripts/presentation/build_flavor.gd`) is the single policy: device tools exist only when `OS.is_debug_build()` or the build has the custom feature tag `device_tools`. "Device tools" means `DeviceProbe` reports, `DevPanel` (overlay, benchmark, long press) and session telemetry files.
- **In a public release build:**
  - no probe or panel object is created;
  - `GameHud.dev_menu_enabled` stays false, so a long press is an ordinary press that cycles the preset;
  - the `--perf`, `--bench` and `--devpanel` flags do nothing;
  - no telemetry file is written.
- **Export presets** are now `iOS Internal Test`, `iOS Public Release`, `Linux Internal Test` and `Linux Public Release`:
  - internal presets carry `device_tools`;
  - public iOS has Files-app and iTunes file sharing **off**; internal has them on, so testers can pull reports.
- **`scripts/export_build.sh ios|linux internal|public [debug|release]`** (default release) **refuses a public debug build**, because any debug build enables the tools. Tested: exit 2.
- **Kept:** all measuring tools stay for internal test builds and debug runs.

| Check | Result |
|---|---|
| Config test `test_device_tools_only_in_internal_presets` | Public presets lack `device_tools` and (iOS) file sharing; every preset is either Internal Test or Public Release; one of each per platform |
| UI test `test_public_release_has_no_device_tools` | Forced public flavour: no probe, no panel, no autopilot from `--bench`, long press cycles the preset, no telemetry file |
| UI test `test_internal_build_writes_telemetry` | Internal flavour still writes telemetry |
| Exported Linux binaries (release, commit `8e26501`), started with `--perf --devpanel --bench=3 --telemetry=…` | Public: user data dir has no reports. Internal: `device_validation/run_*.json` written (`linux_flavor_runs.txt`) |
| Full autoplay match on the public Linux binary | exit 0, no telemetry file (`linux_public_full_match.log`) |
| Generated iOS Info.plists (Xcode projects exported on Linux) | Public: `UIFileSharingEnabled` false; internal: true. `device_tools` present only in the internal pck (`ios_plist_flavors.txt`) |

## 3. CI
- Workflow `.github/workflows/tests.yml`:
  - runs on push, pull_request and manual dispatch;
  - ubuntu-24.04, read-only permissions, 20-minute timeout;
  - Godot cached by version;
  - `scripts/run_tests.sh` runs with `TEST_TIMEOUT_SECS=600`;
  - the `logs/` artifact is uploaded even on failure.
- `scripts/ci/install_godot.sh` downloads **Godot 4.7.2-stable Linux x86_64** from the official GitHub release and verifies the SHA-512 pinned in the script (it matches the release's `SHA512-SUMS.txt`).
- **Dependencies:** none beyond `bash`, `curl`, `unzip` and `sha512sum` on the runner. There are no addons or GDExtensions, and no export templates or GPU are needed for tests.
- **No iOS / macOS steps:** an iOS build needs macOS + Xcode.
- **Fails when tests fail:** `run_tests.sh` exits non-zero on any failed test, any `SCRIPT ERROR` / `Parse Error` / failed `assert` in the logs, or a script that does not compile.
- **Reproduced locally first:**
  - fresh `git clone` with the CI-installed Godot: exit 0;
  - the same clone with one assertion deliberately broken: exit 1 (`ci_local_reproduction.txt`).
- **Ran on GitHub:**
  - [run #1 (39106251564)](https://github.com/phamhoanganhtuan03121988-cmd/empire-rush/actions/runs/39106251564) on `80fb078`: every step succeeded — RESULT 184 / 0, CHECKED 69 / 0, UI 17 / 0, logs artifact uploaded, cache saved.
  - The final commit's run is reported in the hand-off message, because its result does not exist yet when this file is committed.
- **Known warning:** GitHub forces the `@v4` actions (Node 20) onto Node 24 (non-fatal). Bump the action versions when v5 majors are adopted.
- No game behaviour changed for CI.

## 4. Still needs Mac / Xcode / a real iPhone
- Build, sign and install the **Internal Test** Xcode project (`IOS_BUILD_GUIDE.md`).
- Run the full device checklist, including the updated D5/D6 (background 10 s / 5 min / near deadline / during an auction / call / lock, then force quit). This confirms on real iOS the notification ordering the gate is built for.
- Verify the **Public Release** build on the phone: a long press only cycles the preset, and no Empire Rush folder appears in the Files app.
- FPS / frame time / memory / thermals per preset (unchanged from M2.2).

## 5. Conditions to meet before M3
| # | Condition | Status |
|---|---|---|
| 1 | Offline background/resume rule implemented and tested | **Met** (this milestone) |
| 2 | Release builds cannot expose device tools or write telemetry | **Met** (code + presets + tests; the device check of the public build is pending, §4) |
| 3 | CI runs the full suite on every push and blocks on failure | **Met** (green on GitHub). To make it *blocking* for merges, the owner must enable branch protection with the `tests / godot-tests` check required. Not done, as it is a repository setting |
| 4 | Device checklist run on iPhone 14 Pro (internal build), with the 30 FPS low/medium decision | **Open:** needs Mac + Team ID + device |
| 5 | Owner decision on offline force-quit recovery (keep "no recovery" for MVP, or design save/resume) | **Open:** documented as "no recovery" |
| 6 | M3 server-runtime spike plan agreed (IMPLEMENTATION_PLAN §4); online timers stay server-side | **Open** |
| 7 | Playtest sessions (1 human vs bots) with internal builds for real turn times | **Open** |

## 6. Files
- **Added:**
  - `client/scripts/presentation/lifecycle_gate.gd`, `client/scripts/presentation/build_flavor.gd`
  - `client/tests/unit/test_offline_lifecycle.gd`
  - `.github/workflows/tests.yml`, `scripts/ci/install_godot.sh`
  - `docs/test-logs/m2_2_1/*`, this report
- **Modified:**
  - `client/scripts/presentation/local_match.gd`: gate in `_process` and `_notification`
  - `client/scripts/presentation/session_telemetry.gd`: same gate; background fields
  - `client/scripts/main.gd`: BuildFlavor gate for probe, panel, flags and telemetry files
  - `client/scripts/ui/game_hud.gd`: `dev_menu_enabled`
  - `client/export_presets.cfg`: Internal/Public presets
  - `scripts/export_build.sh`: flavour argument; refuses public debug
  - `client/tests/unit/test_device_validation.gd`: iterates all presets; adds release-lock and policy tests
  - `client/tests/ui/test_device_tools.gd`: public/internal flavour tests
  - `docs/RULES_M1.md` (Offline lifecycle), `docs/GAME_RULES_AND_GDD.md` (one note in §3), `docs/device/IOS_BUILD_GUIDE.md`, `docs/device/IPHONE14PRO_TEST_CHECKLIST.md`
- **Commits:**
  - `8e26501`: lifecycle + release lock
  - `80fb078`: CI
  - the final commit adds docs and logs; its hash is in the hand-off message.
