# EMPIRE RUSH — Phase 4 Report: Playtest & Release Candidate

## 1. Baseline, branch, commits
| | |
|---|---|
| Date | 2026-10-19 |
| Engine | Godot 4.7.2-stable |
| Baseline | `claude/phase3-production-hardening` @ `f6a506e` (end of Phase 3, CI #17 green) |
| Branch | **`claude/phase4-playtest-release`** |
| Final commit | see §3 (CI on the final commit) |
| Git | No merge, no PR. `main` and earlier branches untouched |

**Not changed:**
- rules, starting cash, rents, upgrade costs, win conditions, balance (`client/data/rules/*`, fingerprint `d5e3a9a877afe932`, checked by `verify_v5.py`);
- V5 was **not** applied.

**Not claimed:**
- no human playtest has taken place, and no playtest data was invented;
- no iPhone, Mac, Xcode, IPA or signing;
- no device FPS;
- no Internet test, hosting or public port;
- no Windows or macOS run.

| Commit | Content |
|---|---|
| `601e1f7` | Start menu (players, character, graphics, reduced motion, how-to from rules data), MENU on results, one tap = one command, runners fail uncompilable test files |
| `5c16b0c` | Toasts explaining money changes, playtest package, collection script, privacy scanner, guide, bug form |
| `9eb3f54` | Runner counts, disconnect tests (trade / turn change), room limits, privacy gate, menu fixes, V5 re-check, security review |
| `82f0df7`, `962422e` | Godot uid; guide wording (flagged by the package privacy gate) |
| final | this report, final logs |

## 2. Issues: found / fixed / remaining
| # | Found by | Issue | Status |
|---|---|---|---|
| 1 | journey audit | A normal launch dropped straight into a 4-player match. Players, character, graphics and reduced motion needed command-line args; there was no rules screen | **Fixed:** start menu + how-to (`601e1f7`) |
| 2 | journey audit | Money changed without explanation: start reward, bot choices, delayed payouts, rent/upgrade modifiers | **Fixed:** toasts (`5c16b0c`) + `test_money_changes_are_explained` |
| 3 | rapid-tap test | A double tap could queue a second command (the engine rejected it silently) | **Fixed:** HUD disables all buttons on the first tap + `test_double_tap_sends_one_command` |
| 4 | runner probe | A test file with a parse error was skipped silently and the run said "0 failed" | **Fixed:** both runners fail uncompilable files and files with no tests, and print discovered counts |
| 5 | discovered counts | A helper named `test_…` in the UI base class ran as a test in every file (34 "tests", not 30) | **Fixed:** renamed. Counts now equal the `func test_` count on disk |
| 6 | screenshots | Menu: choosing a character with a longer description clipped the reduced-motion toggle (no re-measure) | **Fixed** + `test_menu_grows_when_the_ability_text_grows` (failed before the fix) |
| 7 | screenshots | Landscape how-to sheet spanned the full width (~200-character lines) | **Fixed:** centred 760 px column + `test_landscape_how_to_is_a_readable_column` (failed before the fix) |
| 8 | privacy | Token redaction broke the JSON; `/root` paths were not detected | **Fixed** + self-test cases |
| 9 | privacy | Missed iOS bundle paths / UUIDs, phone numbers, Windows user names with `\u` escapes (a partial name survived) | **Fixed** + self-test cases |
| 10 | real telemetry | UI tests wrote 45 non-replayable match records (forced ends) into `user://telemetry`, the folder testers collect | **Fixed:** tests write to `user://test_telemetry`; the UI runner fails if a test adds files to `user://telemetry` |
| 11 | security review | One link could create rooms repeatedly, or take several seats; unfilled rooms never expired → 64 rooms held = `SERVER_FULL` for everyone | **Fixed:** one room per link, 10-minute wait limit + `test_one_room_per_link_and_waiting_rooms_expire` (failed before the fix) |
| 12 | package gate | The guide contained literal example paths; the final-package scan blocked the package | **Fixed** (wording); the gate is working as intended |
| — | remaining | Plain `ws://` by default, room-code guessing, per-IP limits, 32-bit seed | Open: see §6 and `docs/PHASE4_SECURITY_REVIEW.md` |

## 3. Tests and CI
**Runner probes** (temporary files, removed afterwards; `git status` clean):

| Probe | Unit/integration runner | UI runner |
|---|---|---|
| Parse error | FAIL `failed to load`, exit 1 | FAIL `failed to load / compile`, exit 1 |
| Runtime error (missing dictionary key) | FAIL `runtime script error`, exit 1 | FAIL `runtime script error`, exit 1 |

**Final local run** (`scripts/run_tests.sh`; the runners support no skip marker, so "skipped" counts files left out by `--only`):

| Suite | Files found = on disk | Tests found = `func test_` on disk | Passed | Failed | Skipped |
|---|---|---|---|---|---|
| Unit + integration | 29 = 29 | 208 = 208 | 208 | 0 | 0 |
| UI (real scene, HUD buttons) | 4 = 4 | 30 = 30 | 30 | 0 | 0 |
| Script compile check | 101 scripts = 101 `.gd` | — | 101 | 0 | 0 |

Phase 3 had 205 / 21 UI / 97 scripts. Phase 4 added 3 unit/integration tests and 9 UI tests. No test was removed or weakened.

**Multi-process e2e:** pending (filled in by the final commit).

**Release lock:** pending.

**CI:** pending.

## 4. Playtest readiness: UI and gameplay
**Journey** (UI tests drive only on-screen buttons):
- menu → 2/3/4 players → characters → roll → buy → auction → rent → upgrade → events and opportunities → rescue → bankruptcy → results → CHƠI LẠI / MENU;
- `test_full_match_completes_with_results_screen` and `test_reduced_motion_full_match` play full matches;
- the full-match test writes real telemetry and asserts it has a replay and no token, password, home path or e-mail.

**Screenshots** (`client/tests/capture/capture_menu.gd`, xvfb + lavapipe, 786×1704 with a simulated notch and 1704×786):
- `docs/media/phase4/portrait_menu_choices_before_after.jpg` (issue 6);
- `docs/media/phase4/landscape_menu_howto_before_after.jpg` (issues 6, 7);
- `docs/media/phase4/portrait_menu_howto_toast_after.jpg`, `landscape_menu_toast_after.jpg`. The toast "Bạn qua Xuất phát: +200 RC" comes from a real ROLL command.

**Checked by tests:**
- every menu control is ≥ the touch minimum and START / CÁCH CHƠI are inside the safe area;
- START is pinned on screen in landscape;
- the how-to text is generated from the rules data (cash, start reward, rounds, timer, tax cap);
- double tap = one command;
- reduced motion reaches the match.

**Not checked:** real fingers on a phone and real testers (§7).

**Playtest package** (`scripts/make_playtest_package.sh`, built from the clean commit `962422e`):
1. refuses a dirty tree;
2. exports Linux Internal Test (release);
3. plays a full match **with the exported binary**;
4. replay MATCHES;
5. scans the input data, redacts a copy, **replays the redacted copy** (MATCHES);
6. scans the finished folder (CLEAN), then writes the `.tar.gz` (31 MB).

**Unpacked like a tester** (fresh folder, fresh user-data folder):
- `sha256sum -c` all OK;
- `./EmpireRush.x86_64` opens the start menu (screenshot checked);
- a 4-player match with the packaged binary ended normally (25 rounds, 100 turns);
- `./collect_playtest_data.sh` → `READY TO SHARE`;
- the collected record replays: `applied=236/236 … MATCHES`;
- raw and collected data: privacy scan CLEAN.

**Tested environment:**
- Linux x86_64 container (Ubuntu), Xvfb, Vulkan through lavapipe (CPU), no sound card;
- the ALSA `ERR_CANT_OPEN` lines come from the missing sound card;
- a brand-new user-data folder prints one "can't create shader cache folder" error on the very first launch only.

**Not run:** Windows, macOS, a Linux desktop with a real GPU, iPhone.

**Privacy of real data:**

| Data | Before | After redaction | Replay |
|---|---|---|---|
| UI full-match telemetry (2 players, 188 entries) | CLEAN | byte-identical | MATCHES before and after |
| This container's user-data folder (128 telemetry files, device reports, 5 logs) | 1 finding: a home path in a log | CLEAN; 132 JSON files all parse | 41/41 genuine matches MATCH. The 45 that did not were the test records of issue 10, removed |
| Package smoke data, final package folder | CLEAN | CLEAN | MATCHES |

Images cannot be scanned automatically. `collect_playtest_data.sh` returns `NOT READY` (exit 3) until a person has looked at them and re-runs with `--binaries-reviewed`. Free-text names not given with `--names` cannot be detected; the forms therefore use codes T01… only.

## 5. Benchmark
Pending (run after the e2e suite, never at the same time).

## 6. Multiplayer / security: remaining risks
Full table: `docs/PHASE4_SECURITY_REVIEW.md`.

**New tests:**
- the link drops exactly when a trade is pending:
  - recipient away 30 s → the trade **expires exactly once**;
  - proposer away → the recipient still answers;
- the link drops exactly at a turn change → bot after 60 s, player back at 70 s.

In every case the match ends, the journal replays to the same state and the clients converge.

| # | Risk | Severity (public server) |
|---|---|---|
| R1 | `ws://` is the default: token and room code in clear; a sniffer can take a seat | High (untrusted network) |
| R2 | Room-code guessing: ~10,000 guesses/s with no per-IP limit; ~23 min per hit with 64 waiting rooms; only free seats in waiting rooms | Medium |
| R3 | Link/room exhaustion from many connections (no per-IP limits) | Medium |
| R4 | 32-bit seed: a modified client could recover it from early dice and predict future dice and cards | Medium (online cheating) |
| R5–R8 | Plain token file on the client, single process, no Internet test, images/free text need a person | Low / — |

None of these affects the offline playtest build, which opens no network port.

## 7. Blockers
1. **Human playtest:** needs testers. The package and guide are ready; no session has taken place.
2. **iPhone:** Mac + Xcode + Apple account + Team ID + the device. No IPA, signing or device FPS.
3. **Internet:** host, domain, certificate (owner decision and budget). R1–R3 must be fixed before any public server.
4. **Branch protection on `main`:** `protected: false` (GitHub API, 2026-10-19). Only the owner can change it.

## 8. Owner actions, in priority order
1. **Run playtest round A** with the package (`docs/PHASE4_PLAYTEST_GUIDE.md`): 8–12 sessions, current rules, testers rotate seats.
2. **Protect `main`:**
   - Settings → Branches → ruleset for `main`;
   - require a pull request;
   - require status checks `godot-tests` and `release-lock`;
   - block force pushes.
3. **Decide on seat balance after round A** (`docs/PHASE4_BALANCE_COMPARISON.md`): keep the rules and draw seats at random, or approve a separate V5 test build (round B).
4. **Before any online test:** approve the fixes for R1 (TLS required off-localhost), R2/R3 (per-IP limits, longer codes) and R4 (wider seed / server dice). Choose host and domain.
5. **iPhone:** on a Mac, `scripts/export_build.sh ios internal release` with `IOS_TEAM_ID` set as an environment variable, then `docs/device/IPHONE14PRO_TEST_CHECKLIST.md`.
6. Confirm or change the disconnect policy (60 s hold → bot → reclaim) and the 10-minute room wait limit.
