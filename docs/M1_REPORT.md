# M1 — Offline Rules Prototype: Report

Date: 2026-10-17 · Branch: `claude/m1-offline-game-rules` (from `main` @ `a83d7b7`) · Engine: Godot 4.7.2-stable (`4.7.2.stable.official.ed1daf0bf`, Linux headless)
Rules spec: `docs/RULES_M1.md` · Raw logs: `docs/test-logs/`

## 1. Summary
- The full MVP rule set is implemented as pure GDScript in `client/scripts/domain/`. It has no Node, scene, rendering, audio or transport dependency.
- Time comes from an injected `MatchClock` and randomness from one seeded `ErRng`. Same seed + same inputs ⇒ byte-identical state and event log.
- The same `submit(command)` / `advance()` API is meant to sit behind the M3 server.
- **144 automated tests pass** (0 failed).
- **4,100 simulated matches** across 2/3/4 players ran with invariants checked after every command and timeout. Results: 0 stuck matches, 0 invariant violations, 0 rejected bot commands.
- Balance values are a **simulation-tuned DRAFT**. The simulations show three things the owner needs to decide on (§7): a first-player advantage, matches shorter than the 20–30 min target under our time model, and rare bankruptcies in 2-player games.

## 2. Preflight (actually performed)
| Step | Result |
|---|---|
| `git fetch origin` | `main` exists on the remote |
| `git log origin/main` | `a83d7b7 M0: repository and design baseline`. All M0 files present: GDD, task prompt, audit report, plan, protocol, asset register, reference art, client skeleton, `scripts/run_tests.sh`. |
| Branch | `git checkout -b claude/m1-offline-game-rules origin/main` |
| Docs read | GDD, CLAUDE_TASK_PROMPT, M0_AUDIT_REPORT, IMPLEMENTATION_PLAN, PROTOCOL |
| Handoff docs / reference images | **Unmodified** (`git diff origin/main -- docs/GAME_RULES_AND_GDD.md docs/CLAUDE_TASK_PROMPT.md docs/handoff reference_art docs/ASSET_REGISTER.csv` is empty) |
| G1–G12 vs GDD conflicts | None found that required stopping. Interpretations needed where the GDD/decisions are silent are marked [REVIEW] in RULES_M1.md and listed in §7. |

## 3. Architecture
```
client/
  data/rules/            board.json, balance.json, events.json, characters.json, opportunities.json  (all DRAFT data)
  scripts/domain/        PURE RULES (extends RefCounted only)
    er_rng.gd            portable xorshift128 PRNG (golden values cross-checked with a Python port)
    match_clock.gd       injectable clock
    game_config.gd       JSON → validated config (28/21/7×3/12/3/4 counts, int-only money, effect ordering, free defaults)
    game_state.gd        plain data + canonical to_dict()/state_hash()
    er_command.gd        command types + error codes (PROTOCOL.md)
    game_engine.gd       submit()/advance(): validation → mutation → events → state_version++
  scripts/sim/           bot_player.gd, match_simulator.gd, invariants.gd (tooling, not shipped rules)
  tests/                 test_runner.gd, test_case.gd, helpers/er_fixture.gd, unit/ (18 files), integration/ (2), sim/run_simulation.gd
```
Key properties:
- **Validate-then-mutate.** Every handler finishes validating before it touches state. Tests assert the state hash is unchanged after every rejection, including a 1,500-command fuzz test.
- **Single ledger.** `_transfer()` is the only code that moves money. It refuses negative balances, assigns sequential `tx_id`s and keeps `bank_net_issued` so money conservation can be checked.
- **Deterministic timeouts.** Every waiting phase has a deadline, and `advance()` applies the safe default. An unanswered trade, auction or rescue can never block a match.
- **Structured logs.** `event_log` holds every event with `seq` and `state_version`. `input_log` holds every accepted command and advance with its timestamp. Replaying `input_log` reproduces the exact state hash (tested).
- **Hidden information.** `public_snapshot()` leaves out the RNG state, the seed and the deck order.
- **Data format choice.** Rules data is JSON, not `.tres`, so a non-Godot server (plan Option B) can load the identical files.

## 4. Files
**Added:**
- Rules data: `client/data/rules/*.json` (5 files)
- Domain: `client/scripts/domain/*.gd` (6 files)
- Simulation tooling: `client/scripts/sim/*.gd` (3 files)
- Tests: `client/tests/helpers/er_fixture.gd`, `client/tests/unit/test_*.gd` (17 new files), `client/tests/integration/test_*.gd` (2), `client/tests/sim/run_simulation.gd`, `client/tests/sim/smoke_one.gd`
- Scripts: `scripts/run_simulation.sh`
- Docs and logs: `docs/RULES_M1.md`, `docs/M1_REPORT.md`, `docs/test-logs/*`
- Godot `.uid` sidecar files for the new scripts

**Modified:**
- `client/tests/test_case.gd`: more assertion helpers.
- `scripts/run_tests.sh`: now fails on any `SCRIPT ERROR`, `Assertion failed` or `Parse Error` in the log. GDScript runtime errors do not stop the process, so without this a broken test could still be counted as PASS.
- `docs/PROTOCOL.md`, `docs/IMPLEMENTATION_PLAN.md`, `README.md`

**Not touched:** GDD, task prompt, handoff README, reference images, asset register (no new assets).

## 5. Commands executed and actual results
```
git fetch origin && git checkout -b claude/m1-offline-game-rules origin/main
GODOT=/opt/godot/Godot_v4.7.2-stable_linux.x86_64 scripts/run_tests.sh
  → RESULT: 144 passed, 0 failed   (exit 0; log: docs/test-logs/m1_tests.txt)
scripts/run_simulation.sh --matches=100  --players=2,3,4 --seed=1      --out=$PWD/docs/test-logs/m1_sim_100_mixed.json            → exit 0, failures 0
scripts/run_simulation.sh --matches=2000 --players=4     --seed=100000 --summary=1 --out=$PWD/docs/test-logs/m1_sim_2000_4p_summary.json → exit 0, failures 0
scripts/run_simulation.sh --matches=1000 --players=3     --seed=200000 --summary=1 --out=...m1_sim_1000_3p_summary.json  → exit 0, failures 0
scripts/run_simulation.sh --matches=1000 --players=2     --seed=300000 --summary=1 --out=...m1_sim_1000_2p_summary.json  → exit 0, failures 0
```
All four batches were run twice, before and after the last code change. The summaries were **identical**, which is a further determinism check.

### Test coverage (144 tests)
| Area | File | Tests |
|---|---|---|
| Config/data validation | test_config | 8 |
| RNG (determinism, golden values, uniformity) | test_rng | 6 |
| Movement, Start reward, doubles (G5) | test_movement | 6 |
| Buy / pass | test_purchase | 7 |
| Rent, district ×2, level rows, modifiers (G6) | test_rent | 9 |
| Upgrades, discounts, one action (G8) | test_upgrade | 9 |
| Auction (min bid, increments, anti-snipe, deadline, idempotency) | test_auction | 10 |
| Trade (atomic, reject, expire, invalidated, bounds) (G8) | test_trade | 10 |
| Rescue, liquidation, bankruptcy (G7) | test_rescue_bankruptcy | 11 |
| Wealth tax (G3) | test_tax | 5 |
| Event cards, modifier expiry, reshuffle (G10) | test_events | 13 |
| Opportunity (G4) | test_opportunity | 6 |
| Character abilities (G10) | test_abilities | 7 |
| Turn order, timers, timeouts, round/time caps (G9) | test_turns | 10 |
| Command envelope, stale versions, duplicates, fuzz | test_commands | 8 |
| Net worth, ranking, tie-breaks (G11) | test_endgame | 6 |
| Regressions | test_regressions | 4 |
| Replay / determinism | integration/test_replay | 4 |
| 100 + 10 full simulated matches | integration/test_simulation | 2 |
| M0 baseline | test_project_baseline | 3 |

**Mutation check.** Five bugs were injected one at a time into a scratch copy of the engine. All five were caught:
- rent ignores district completion → 5 failures
- doubles grant an extra roll → 154 failures, after the test was strengthened (see R3)
- no re-validation when a trade is accepted → 2 failures
- creditor receives liquidation proceeds on bankruptcy → 23 failures
- level rent stacks with ×2 → 16 failures

## 6. Defects found during M1 (all have regression tests)
| ID | Defect | Fix |
|---|---|---|
| R1 | Found by the simulation: after a Rescue settled with no turn time left, the next command arrived exactly at the deadline and was rejected. The engine behaved correctly, but the simulator mishandled the case. | Simulator now calls `advance()` first. A regression test proves the turn ends rather than sticking. |
| R2 | A trade proposed during Rescue and the Rescue itself can expire at the same instant | Resolution order is deterministic (trade first, then forced settlement). Tested. |
| R3 | Mutation testing showed the doubles test would pass against an engine that grants extra rolls, because it only checked an AwaitBuy landing | Test strengthened; dedicated regression test added |
| R4 | Godot's JSON parser returns every number as a float | Config normalizes integral floats to int and rejects fractional money. Tested. |

## 7. Simulation results (final DRAFT v2 balance)
**Time model.** This is an assumption, not a measurement. It stands in for the real UI until M2/M4 playtests:
- A decision takes 0.6–5 s.
- Dice and token animation take 1.8 s + 0.25 s per space.
- Auctions run to their 12 s timer.
- 3% of decisions are left to time out, which exercises the timeout defaults.
- Bots are heuristic (`scripts/sim/bot_player.gd`). They are not strong players, so the results describe the rules under simple play, not human balance.

| Metric | 2 players (1,000) | 3 players (1,000) | 4 players (2,000) |
|---|---|---|---|
| Duration, median / P90 (sim time) | 9.8 / 11.6 min | 14.2 / 16.5 min | 18.2 / 20.6 min |
| Rounds (mean) | 24.9 | 25.0 | 25.0 |
| End: round cap / last solvent / time cap | 97.1% / 2.9% / 0% | 99.4% / 0.6% / 0% | 99.95% / 0.05% / 0% |
| Matches with ≥1 bankruptcy | 2.9% | 10.2% | 20.5% |
| Bankruptcies per match | 0.03 | 0.11 | 0.24 |
| Median round of bankruptcy | 24 | 23 | 23 |
| Win % by seat (fair share) | 51.6 / 48.4 (50) | 38.2 / 35.0 / 26.8 (33.3) | 30.0 / 27.6 / 21.8 / 20.7 (25) |
| Win % by character (fair share) | INV 54.6, NEG 47.3, TYC 48.1 (50) | INV 38.3, NEG 30.2, TYC 31.5 (33.3) | INV 25.9, NEG 23.0, TYC 26.1 (25) |
| Avg cash per player, round 5 / 10 / 15 / 20 / 25 | 1202 / 1113 / 1025 / 965 / 965 | 1233 / 1203 / 1194 / 1230 / 1326 | 1251 / 1285 / 1344 / 1448 / 1596 |
| Avg properties per player at the last sample (100-match run) | 8.9 | 6.3 | 4.8 |
| Unowned properties at end | 3.8 | 2.4 | 1.7 |
| Winner's share of total net worth | 62% | 50% | 45% |
| Comeback (winner ≠ book-value leader at round 10; pure chance would be 50 / 67 / 75%) | 47.7% | 65.5% | 74.3% |
| Per match: upgrades / trades accepted (proposed) / auctions / rescues / timeouts | 13.3 / 1.4 (3.3) / 1.3 / 0.21 / 7.9 | 17.0 / 2.2 (5.0) / 1.4 / 0.47 / 10.8 | 16.8 / 2.2 (5.3) / 1.4 / 0.60 / 12.8 |
| Failures (stuck / invariant / rejected) | 0 / 0 / 0 | 0 / 0 / 0 | 0 / 0 / 0 |

The 100-match mixed run (`m1_sim_100_mixed.json`) also has 0 failures. **Don't use it for balance.** Its seeds advance in steps of 3 per player count, so in 2-player games the character is tied to the seat. The large runs do not have this problem.

### Conclusions and suspicious imbalances (verified with extra runs)
1. **First-mover advantage is real.** In 4-player games seat 0 wins 30.0% and seat 3 wins 20.7% (n = 2,000, standard error ≈ 1 pp). 3-player games show the same pattern. The likely cause is that early seats buy properties first.
   - Experiment, **not committed**: giving each later seat +50 RC of starting cash narrowed the gap to 27.4 / 26.9 / 24.2 / 21.6.
   - Owner decision needed: seat compensation, a smaller starting-cash spread, or accept it.
2. **Matches end almost entirely on the 25-round cap.**
   - The 30-minute cap never triggered under the time model. 4-player medians of 18 min are below the 22–27 min target, and 2-player matches take only about 10 min.
   - The pace depends on real UI and animation time, which only M2/M4 playtests can measure.
   - Options for the owner: per-player-count round caps (for example 2p = 35 rounds), or keep the cap and accept shorter 2-player matches.
3. **Bankruptcy is late and uncommon.** It happens in 20% of 4-player matches, around round 23. Average cash still rises late in the game for 3–4 players, which means Start income (200 RC per lap) outpaces rent at the current values.
   - Raising level 1–3 rents further, or lowering the Start reward, would increase pressure. The Start reward is fixed by the GDD, so changing it needs owner approval.
4. **Investor was stronger than fair share.** In the earlier runs it won 28.5% in 4-player games against a 25% fair share, so it was nerfed from 20/160 to 15/120 RC. It is now about fair in 4-player games but still +5 pp in 3-player and +4.6 pp in 2-player games. Needs more tuning together with humans.
5. **Comeback potential is high.** Being ahead at round 10 barely predicts the winner. That is good for "party reversals", but it may also mean there is little room for skill under bot play. This needs human playtests.
6. **100 matches do not prove balance.** These are directional findings from simple bots.

### Balance tuning history (4 players)
| Version | Change | Matches | Matches with a bankruptcy | Rent paid per match |
|---|---|---|---|---|
| v1 initial draft | base rent ≈ 6% of price; level rows ×5 / ×12 / ×20 | 100 | 0% | 1,042 |
| v1b | level rows ×6 / ×16 / ×35, slightly higher base | 300 | 0.7% | 1,412 |
| v1c | base rent ≈ 12% of price, ×5 / ×13 / ×30; bots offer higher trade premiums | 300 | 4.7% | 2,933 |
| **v2 (current)** | ×6 / ×18 / ×45; cheaper upgrades (40–100) | 2,000 | 20.5% | 3,812 |

## 8. Proposed balance values (DRAFT v2, `client/data/rules/balance.json`)
| Tier | District | Price | Base rent | Upgrade cost | Liquidation value | Rent at L0 complete / L1 / L2 / L3 |
|---|---|---|---|---|---|---|
| 1 | D1 Old Market | 60 | 8 | 40 | 30 | 16 / 48 / 144 / 360 |
| 2 | D2 Harbor Quarter (tourist) | 90 | 11 | 40 | 45 | 22 / 66 / 198 / 495 |
| 3 | D3 Riverside | 120 | 15 | 60 | 60 | 30 / 90 / 270 / 675 |
| 4 | D4 Garden District | 150 | 18 | 60 | 75 | 36 / 108 / 324 / 810 |
| 5 | D5 Beach Resort (tourist) | 180 | 22 | 80 | 90 | 44 / 132 / 396 / 990 |
| 6 | D6 Financial Center | 220 | 26 | 80 | 110 | 52 / 156 / 468 / 1,170 |
| 7 | D7 Skyline Heights | 260 | 32 | 100 | 130 | 64 / 192 / 576 / 1,440 |

Fixed by the GDD: start cash 1,500 RC, Start reward 200 RC, 25 rounds, 30 min cap, 45 s turn, 20 s trade, 12 s auction, 30 s rescue.
Building refunds pay 50% of the upgrade cost. Discounts are capped at 75%.
District, property and card names are placeholders.

## 9. Known issues and limitations
- Balance is a draft (see §7). The bots are simple: they don't plan trades over several turns and don't block opponents' districts.
- The time model is assumed. **No real-device or UI timing exists yet.**
- `processed` (the idempotency cache) grows for the whole match. That is fine offline. The M3 server should cap or persist it.
- Disconnects are not modelled in M1. A disconnected trade receiver is treated as "no response" until the deadline.
- No UI exists. M1 is headless by design.
- Not run: Godot editor GUI open, Android/iOS export, any performance measurement.

## 10. Decisions requiring owner review
1. **Timeout on AwaitRoll:** the server rolls for an idle player (default), or the turn ends without moving (`timeout_auto_roll: false`).
2. **Forced settlement:** a debtor who *can* cover the debt by liquidating is force-liquidated at the deadline and survives. Bankruptcy (G7) applies only when even full liquidation is insufficient. Under G7 the creditor then receives only the remaining cash, not the liquidation value of the returned properties. So a debtor who liquidates manually before going bankrupt gives the creditor more than one who doesn't. Confirm this is acceptable.
3. **Only level-0 properties can be traded.**
4. **Full ties share a rank.** There is no seat-order tie-break.
5. **"One full round"** = (active players at creation) turns, counted from the turn the effect was created.
6. **Net worth at the cap uses liquidation value (50% of price).** This penalizes holding property at the end versus cash. It is a GDD rule, but its effect on end-game strategy should be confirmed.
7. Seat compensation, per-player-count round caps, and the Start reward vs rent pressure (§7 items 1–3).
8. Text and numbers for all 12 event cards, 4 opportunities and 3 characters (all DRAFT).

## 11. iOS / iPhone 14 Pro: remaining steps (not done in this environment)
Godot's iOS export needs macOS + Xcode. Nothing in this report claims an iOS build or a device measurement. To do on a Mac:
1. Install Godot 4.7.2-stable and its export templates (standard build), plus a current Xcode and command line tools.
2. Join the Apple Developer Program and create an App ID / bundle identifier and a provisioning profile for the test device.
3. Godot → Project → Export → add an **iOS** preset: team ID, bundle ID, icons and launch screen, the Mobile renderer.
4. Export the Xcode project, open it in Xcode, sign it, and run it on the iPhone 14 Pro.
5. Measure on device: FPS (target 30 FPS at low/medium), frame time, memory and thermals over a 20–30 min match. Use the Godot remote debugger / monitors and Xcode Instruments.
6. Check the safe areas (Dynamic Island) and that touch targets are ≥ 44 pt.

These steps belong to M2 (visual slice) and M4 (MVP), once there is something to render.

## 12. Acceptance criteria status
| # | Criterion | Status | Evidence |
|---|---|---|---|
| 1 | Offline rules run independently of the UI | **PASS** | Domain scripts all `extends RefCounted`; tests and simulations run headless with no scene |
| 2 | Automated test suite passes | **PASS** | 144 / 144, `docs/test-logs/m1_tests.txt` |
| 3 | Simulation: no stuck turns or invalid states | **PASS** | 4,100 matches, 0 stuck / 0 invariant / 0 rejected |
| 4 | Identical seeds ⇒ identical results | **PASS** | `test_replay.gd` (state hash, full event log, input-log replay); repeated batches identical |
| 5 | Financial invariants preserved | **PASS** | Checked after every step: cash ≥ 0, money conserved, unique sequential tx ids, single ownership, bankrupt players hold nothing |
| 6 | M1 report with commands, counts, results, failures, limitations, questions | **PASS** | This document |
| 7 | Plan and docs updated | **PASS** | IMPLEMENTATION_PLAN, PROTOCOL, README, RULES_M1 |
| 8 | Committed and pushed to the M1 branch | **PASS** | Implementation commit `331f33a` pushed to `origin/claude/m1-offline-game-rules` (confirmed by `git ls-remote`); this status line was added in a follow-up commit |
| — | Balance meets the 22–27 min pacing target | **Not met / unverified.** Simulation-only time model; needs owner decisions (§10.7) and real playtests |
| — | iPhone 14 Pro build and 30 FPS | **Not done.** Requires macOS/Xcode (§11) |

## 13. Next milestone (M2, after owner review)
Visual vertical slice:
- Isometric board section, token and dice animation.
- One property tile with 3 upgrade looks.
- Mobile HUD (9:16 and 16:9), low/medium/high quality presets.
- Placeholders clearly labelled.
- Animation consumes engine events only and never changes rules state.

Acceptance as in `CLAUDE_TASK_PROMPT.md` M2, plus a first iPhone 14 Pro build if a Mac is available.
