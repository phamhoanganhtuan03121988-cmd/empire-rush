# M1.2 — Balance DRAFT v3 Report

Date: 2026-10-18 · Branch: `claude/m1-2-balance-v3` (from `claude/m1-1-balance-review` @ `4ef90d2`) · Engine: Godot 4.7.2-stable headless
Scope: apply the owner-approved **Option C** (M1.1 V4) as a **trial** balance. Nothing is locked. Round caps and the economy must be re-checked once real per-turn time is measured after M2.

## 1. Owner decisions applied
| # | Decision | Applied as |
|---|---|---|
| 1 | Round caps 2p 40 / 3p 30 / 4p 25 | `balance.json` → `max_rounds_by_players` |
| 2 | Option C = A + B | Caps (A) + level rent rows ×7 / ×22 / ×55 and upgrade costs 30 / 30 / 45 / 45 / 60 / 60 / 75 (B) |
| 3 | No seat compensation | Not added. Seat compensation exists only as an experiment option in the simulator; it is not in the rules or data. |
| 4 | Keep GDD liquidation value / net worth | Unchanged (`upgrade_refund_pct` 50, `net_worth()` unchanged) |
| 5 | Start reward 200 RC | Unchanged |
| 6 | Not locked | `_status` in `balance.json` says "DRAFT v3 … trial values, NOT locked" |

**Source of the values.** Option C was reproducible exactly from the M1.1 material, so this milestone did not need to stop. The values were copied from the M1.1 `V4 = V1 + V2` definition, which is identical in three places:
- `client/tests/sim/experiments/balance_options.json`
- the definition stored in `docs/test-logs/m1.1/balance_options.json`
- the table in `docs/M1_BALANCE_REVIEW.md` §5

**Verified by reproduction.** Shipped v3 run on M1.1's seeds produces results **identical** to M1.1's V4 rows. This holds on seed base 700000 (medium time model) and on seed base 800000 (fast and slow models). M1 v2 patched back in reproduces M1.1's V0 row identically. (§4.1)

## 2. Configuration changes
`client/data/rules/balance.json`:
| Key | M1 v2 | v3 |
|---|---|---|
| `max_rounds_by_players` | (absent: 25 for every player count) | `{"2": 40, "3": 30, "4": 25}` |
| `max_rounds` (fallback) | 25 | 25 (unchanged) |
| `rent_multiplier_pct.level1 / level2 / level3` | 600 / 1800 / 4500 | **700 / 2200 / 5500** |
| `rent_multiplier_pct.level0_*` | 100 / 200 | 100 / 200 (unchanged) |
| `tiers[*].upgrade_cost` (tier 1→7) | 40 / 40 / 60 / 60 / 80 / 80 / 100 | **30 / 30 / 45 / 45 / 60 / 60 / 75** |
| prices, base rents, liquidation values, start cash, Start reward, timers, tax | — | unchanged |

**Code.** No balance numbers are hard-coded.
- `GameConfig.max_rounds_for(n)` reads `max_rounds_by_players` and falls back to `max_rounds`. The table is validated: only keys "2" / "3" / "4" are allowed, and each value must be a positive int.
- `GameEngine._end_turn`, `Invariants` and the bot use `max_rounds_for(players seated at start)`. A bankruptcy therefore never changes the cap; this is tested.
- Docs updated: `RULES_M1.md` §3 (round cap) and §5 (rent table, including the 1,815 RC maximum), `README.md`, `IMPLEMENTATION_PLAN.md`.

**Resulting rent at levels 1 / 2 / 3** (without event modifiers):

| Tier | Base rent | L1 | L2 | L3 |
|---|---|---|---|---|
| 1 | 8 | 56 | 176 | 440 |
| 2 | 11 | 77 | 242 | 605 |
| 3 | 15 | 105 | 330 | 825 |
| 4 | 18 | 126 | 396 | 990 |
| 5 | 22 | 154 | 484 | 1,210 |
| 6 | 26 | 182 | 572 | 1,430 |
| 7 | 32 | 224 | 704 | **1,760** |

## 3. Tests
Command: `GODOT=/opt/godot/Godot_v4.7.2-stable_linux.x86_64 scripts/run_tests.sh` → **RESULT: 165 passed, 0 failed** (exit 0; log `docs/test-logs/m1.2/m1_2_tests.txt`).
- 151 tests from M1.1, all kept. A script compared `func test_` and `assert_` counts in every pre-existing test file against M1.1: **no test or assertion was removed**.
- **14 new tests** in `client/tests/unit/test_balance_v3.gd`:
  - every shipped value against Option C, and the unchanged values (Start 200, liquidation 50%, prices);
  - caps for 2 / 3 / 4 players;
  - the full rent table for all 7 tiers × levels 0–3, computed by the engine;
  - a 1,760 RC charge and payout;
  - 1,760 rent bankrupting a player who holds only the starting 1,500 RC (creditor receives 1,500, per G7);
  - rent insurance capping 1,760;
  - v3 upgrade costs and liquidation values;
  - the cap ending after the last seat of the last round for each player count;
  - 2p continuing past round 25, 3p continuing to round 30;
  - the cap staying at 30 in a 3p match after a bankruptcy;
  - invalid cap tables rejected; fallback to `max_rounds`;
  - 30 simulated matches respecting the per-count caps, with some 2p/3p matches actually going past round 25.
- **Mutation check.** An engine that ignores the per-count caps (always 25) fails 7 assertions.

**Pre-existing tests whose expected numbers changed** because v3 changed the numbers. The assertions are the same; only the values were updated.
| Test | Change |
|---|---|
| test_rent `levels_use_their_own_row` | 48 / 144 / 360 → 56 / 176 / 440 (8 × 7 / 22 / 55) |
| test_rent `rent_cap` | Message only ("capped from 440") |
| test_abilities `negotiator_halves_next_rent` | 48/2 → 56/2 |
| test_endgame `net_worth_formula` | Buildings 3 × 70 → 3 × 60 (upgrade cost 30) |
| test_upgrade (4 tests) | Cost 40 → 30; Tycoon 90 → 67; discounted 40 → 30; "1 RC short" cash 39 → 29 |
| test_turns `round_cap_ends_match` | Reads the 2p cap from config (40) instead of the literal 25. Still checks "not ended before the last seat" and "ended after it". |
| test_experiment_tooling `round_cap_override` | Patches `max_rounds_by_players`, because a `max_rounds` patch is now only the fallback |
| integration test_simulation | `rounds <= 25` → `rounds <= max_rounds_for(players)` |

**Rescue tests (4 scenario inputs changed; 2 more tests only had expected values or messages updated) and test_regressions R1.** Level-3 rent on D1 rose from 360 to 440, so scenario cash was raised to keep each test exercising the same situation. Without this, e.g. "one liquidation covers the debt" would have turned into "bankrupt".
- "One liquidation covers the debt": 300 → 400.
- "Cheapest property alone covers the debt": 300 → 340.
- "DeclareBankruptcy cannot dodge a payable debt": 300 → 400.
- The rescue trade amount: 60 → 140.
- The expected values follow from those inputs.

## 4. Simulations actually run
All batches exit 0 with **0 stuck matches, 0 invariant violations, 0 rejected bot commands**. The runs total about **76,100 matches**: 4,100 on the M1 seeds plus 72,000 in experiments. Logs are in `docs/test-logs/m1.2/`.
```
# On M1's seeds (compare with docs/test-logs/m1_*), fast time model
godot --headless --path client --script res://tests/sim/run_simulation.gd -- --matches=100  --players=2,3,4 --seed=1      --out=.../v3_sim_100_mixed.json
godot ... run_simulation.gd -- --matches=2000 --players=4 --seed=100000 --summary=1 --out=.../v3_sim_2000_4p_summary.json
godot ... run_simulation.gd -- --matches=1000 --players=3 --seed=200000 --summary=1 --out=.../v3_sim_1000_3p_summary.json
godot ... run_simulation.gd -- --matches=1000 --players=2 --seed=300000 --summary=1 --out=.../v3_sim_1000_2p_summary.json
# On M1.1's seeds (specs in client/tests/sim/experiments/m12_*.json)
run_experiments.gd --spec=m12_options.json          (seed 700000, medium: M1 v2 vs v3)          8,000
run_experiments.gd --spec=m12_pacing.json           (seed 500000, v3 × fast/medium/slow)       12,000
run_experiments.gd --spec=m12_seat.json --seed_base={1..5}000000   (v3)                        20,000
run_experiments.gd --spec=m12_hoarding.json         (seed 600000, v3)                          16,000
run_experiments.gd --spec=m12_sensitivity.json      (seed 800000, v3 fast/slow)                 8,000
run_experiments.gd --spec=m12_l3_alternatives.json  (seed 700000, DATA ONLY: L3 ×50 / ×45)      8,000
```
`run_experiments.gd` was invoked as `godot --headless --path client --script res://tests/sim/run_experiments.gd -- …`, three processes in parallel, after a single import.
The M1.1 specs patch values relative to the shipped data, which was v2 at the time. M1.1's own numbers are reproducible on the `claude/m1-1-balance-review` branch. The M1.2 specs state v2 explicitly where they compare against it.

### 4.1 Reproduction checks (same seeds, all metrics except the new rent block)
| M1.2 run | M1.1 run | Result |
|---|---|---|
| options "M1 v2" | balance_options "V0 M1 baseline" | **identical** |
| options "v3 shipped" | balance_options "V4 = V1 + V2" | **identical** |
| sensitivity "v3 fast" | recommendation_check "V4 fast" | **identical** |
| sensitivity "v3 slow" | recommendation_check "V4 slow" | **identical** |

## 5. Before / after: M1.1 baseline (M1 v2) vs v3
Same seeds, medium time model, seed base 700000. n = 1,000 (2p), 1,000 (3p), 2,000 (4p). CI95: about ±3.1 pp (2p), ±2.9 pp (3p), ±1.9 pp (4p).

| Metric | 2p v2 → v3 | 3p v2 → v3 | 4p v2 → v3 |
|---|---|---|---|
| Duration median / P90 (min, medium model) | 11.9 / 13.6 → **17.8 / 20.3** | 17.2 / 19.3 → **20.2 / 22.5** | 22.1 / 24.4 → 22.0 / 24.4 |
| Rounds (mean) | 24.9 → 36.9 | 25.0 → 29.8 | 25.0 → 25.0 |
| Ends on round cap | 97.5% → **59.5%** | 99.8% → **93.5%** | 99.9% → 99.3% |
| Ends on last solvent player | 2.5% → **40.5%** | 0.2% → 6.5% | 0.1% → 0.7% |
| Ends on time cap | 0% → 0% | 0% → 0% | 0% → 0% |
| Matches with ≥1 bankruptcy | 2.5% → **40.5%** | 10.4% → **40.7%** | 20.3% → **31.2%** |
| Bankruptcies per match | 0.03 → 0.41 | 0.11 → 0.47 | 0.25 → 0.40 |
| Median round of bankruptcy | 23 → 34 | 23 → 27 | 23 → 23 |
| Win % by seat | 51.7 / 48.3 → 52.4 / 47.6 | 37.8 / 34.2 / 28.0 → 39.3 / 32.2 / 28.5 | 29.4 / 26.1 / 23.3 / 21.3 → 29.0 / 26.6 / 23.3 / 21.1 |
| Seat spread (pp) | 3.4 → 4.8 | 9.8 → 10.8 | 8.1 → 7.9 |
| Win % Investor / Negotiator / Tycoon (fair 50 / 33.3 / 25) | 54.4 / 48.2 / 47.4 → 51.7 / 48.3 / 49.9 | 37.5 / 30.3 / 32.2 → 36.4 / 31.7 / 31.9 | 27.5 / 22.8 / 24.7 → 26.8 / 23.3 / 24.9 |
| Comeback (winner ≠ round-10 book leader; chance = 50 / 67 / 75) | 45.0 → 50.8 | 64.1 → 68.6 | 75.0 → 76.3 |
| Winner holds the most cash | 88.9% → **96.0%** | 83.9% → 90.7% | 85.2% → 89.1% |
| Winner would change under book value | 16.8% → 3.6% | 16.9% → 7.2% | 11.8% → 8.3% |
| Avg cash per player at the last round | 970 (r25) → 1,394 (r40) | 1,332 (r25) → 1,536 (r30) | 1,597 → 1,652 |

**On M1's own seeds** (fast time model; `docs/test-logs/m1_*` vs `docs/test-logs/m1.2/v3_sim_*`, n = 1,000 / 1,000 / 2,000):

| | Median minutes | Rounds | Ends on cap | Matches with ≥1 bankruptcy | Win % by seat | Win % Investor / Negotiator / Tycoon |
|---|---|---|---|---|---|---|
| 2p | 9.8 → 14.5 | 24.9 → 36.6 | 97.1% → 55.2% | 2.9% → 44.8% | 51.6 / 48.4 → 53.3 / 46.7 | 54.6 / 47.3 / 48.1 → 49.9 / 51.5 / 48.6 |
| 3p | 14.2 → 16.6 | 25.0 → 29.8 | 99.4% → 92.4% | 10.2% → 40.9% | 38.2 / 35.0 / 26.8 → 39.3 / 34.2 / 26.5 | 38.3 / 30.2 / 31.5 → 36.1 / 32.7 / 31.2 |
| 4p | 18.2 → 18.1 | 25.0 → 25.0 | 100.0% → 99.0% | 20.5% → 33.2% | 30.0 / 27.6 / 21.8 / 20.7 → 29.9 / 27.6 / 22.2 / 20.3 | 25.9 / 23.0 / 26.1 → 26.4 / 22.7 / 25.9 |

### 5.1 Duration by time model (v3, seed base 500000; compare M1.1 `pacing.json` for v2)
Median minutes, P90 in brackets:

| Time model | 2p v2 → v3 | 3p v2 → v3 | 4p v2 → v3 | 4p ends on time cap |
|---|---|---|---|---|
| fast (~11–12 s/turn) | 9.8 (11.5) → 14.5 (17.1) | 14.1 (16.1) → 16.4 (18.8) | 18.3 (20.8) → 18.3 (20.8) | 0% → 0% |
| medium (~13.5–14 s/turn) | 11.9 (13.6) → 17.6 (20.3) | 17.0 (19.1) → 19.9 (22.3) | 22.2 (24.6) → 22.1 (24.6) | 0% → 0% |
| slow (~17.5–18 s/turn) | 15.4 (17.0) → 23.0 (25.6) | 22.1 (24.1) → 25.9 (28.3) | 28.7 (30.2) → 28.6 (30.1) | 19.3% → **18.2%** |

**No duration here is evidence that the 20–30 min target is met.** All three time models are assumptions. Under the medium model v3 lands at about 18 / 20 / 22 min. Under the slow model it lands at 23 / 26 / 29 min, and 18% of 4-player matches end on the 30-minute time cap.

### 5.2 Seat advantage (v3, 5 seed blocks, the same blocks as M1.1)
| Players | n | v3 win % by seat (pooled) | CI95 | M1.1 v2 (same blocks) |
|---|---|---|---|---|
| 4 | 10,000 | 31.6 / 26.3 / 22.4 / 19.7 | ±0.9 | 31.2 / 26.6 / 22.6 / 19.7 |
| 3 | 5,000 | 37.2 / 33.7 / 29.2 | ±1.3 | 37.3 / 33.3 / 29.4 |
| 2 | 5,000 | 54.2 / 45.8 | ±1.4 | 53.6 / 46.4 |

Properties owned at round 5 are unchanged: 4p 2.70 / 2.48 / 2.29 / 2.11. **v3 neither fixes nor worsens the first-player advantage.** It is still a separate, open owner decision; compensation was not applied, as instructed.

### 5.3 Net worth / hoarding (v3, seed base 600000; liquidation-based ranking kept)
Win % of the focus seat:

| Focus-seat strategy | 2p | 3p | 4p |
|---|---|---|---|
| Normal play | 50.3 | 31.8 | 23.9 |
| Hoard last 3 rounds | 50.9 | 31.7 | 24.1 |
| Hoard last 5 rounds | 51.1 | 31.7 | 23.6 |
| Hoard last 8 rounds | 50.4 | 29.7 | **19.4** |

Under v3 the small 2-player hoarding gain seen in M1.1 (+4 pp) disappears. Long hoarding hurts. This is still bot evidence only (see §7).

## 6. Metrics that got worse, explained
1. **"Winner holds the most cash" rose** (2p 88.9% → 96.0%, 4p 85.2% → 89.1%). Higher L3 rent concentrates rent income on whoever owns developed districts, and that income ends up as cash. It is *not* a hoarding effect: §5.3 shows hoarding does not pay. Together with the lower "winner changes under book value" (16.8% → 3.6% in 2p), it shows the leader is now clearer under both valuations.
2. **2-player duration varies more.** Medium model P10–P90 is 13.1–20.3 min (seed base 500000). In v2, 2p matches had a median of 11.9 and a P90 of 13.6. 40.5% of 2p matches now end by elimination around round 34 instead of reaching the cap. Decisive 2p endings were a goal of Option C, but it also means some 2p matches are short (P10 13 min).
3. **3-player duration and pressure.** Bankruptcy matches in 3p rose to 40.7%, but only 6.5% end by elimination. So in about a third of 3p matches, one player is knocked out and the remaining two play on to round 30. A knocked-out player waits through the rest of the match (median bankruptcy at round 27 of 30, so the wait is short in most cases). Watch this in playtests.
4. **Seat spread in 3p:** 9.8 → 10.8 pp on seed base 700000. This is within noise. The pooled 5-block numbers (§5.2) show no change.
5. **Slow model, 4 players:** 18% of matches still end on the time cap. That is unchanged from v2 because the 4p cap stayed at 25.
6. **Investor in 3p:** 36.4% (fair share 33.3), about 1 CI above. It was 37.5% in v2. M1.1's sensitivity block measured 31.8%. Not conclusive; character tuning remains open (DRAFT).

## 7. Level-3 rent of 1,760 RC (requested check)
Rent metrics are new in M1.2 (seed base 700000, medium model):

| Metric | 2p v2 → v3 | 3p v2 → v3 | 4p v2 → v3 |
|---|---|---|---|
| Share of rent events at L3 | 5.1% → 14.3% | 6.7% → 9.8% | 7.4% → 7.2% |
| Average L3 rent paid | 706 → 906 | 731 → 922 | 757 → 930 |
| **Highest single rent observed** | 1,440 → **1,815** | 1,440 → **1,815** | 1,485 → **1,815** |
| Matches with any rent ≥ 1,000 | 5.5% → 48.3% | 15.8% → 43.6% | 24.6% → 38.0% |
| Rents ≥ 1,000 per match | 0.06 → 0.74 | 0.24 → 0.88 | 0.55 → 0.91 |
| Bankruptcies whose debt was ≥ 1,000 | 64.0% → 57.3% | 44.3% → 59.7% | 54.2% → 65.8% |
| Median bankruptcy debt | 1,170 → 1,210 | 990 → 1,210 | 1,170 → 1,210 |

**Findings:**
- **The real maximum is 1,815 RC, not 1,760.** Tourism Boom adds +50% on the tourist districts: D5 at L3 is 22 × 55 = 1,210, × 1.5 = 1,815. Tier 7 at L3 (1,760) is the maximum *without* event modifiers. The same effect existed in v2 (1,485).
- A single max-level hit costs more than the 1,500 starting cash, so it can eliminate a player in one roll. This is tested in `test_1760_rent_bankrupts_a_fresh_player`.
  - By the time L3 exists (median bankruptcy in round 23–34), players hold about 1,200–1,650 RC on average plus property.
  - About 58–66% of all bankruptcies come from a single debt of ≥ 1,000.
  - Rent Insurance (cap 100) and the Negotiator / Charity −50% still apply to these rents (tested).

**Data-only alternatives** (not applied; same seeds, medium model):

| L3 row | Max T7 / D5 with Tourism Boom | Matches with ≥1 bankruptcy 2p / 3p / 4p | Elimination endings 2p / 3p / 4p | Bankruptcies from debt ≥ 1,000 (4p) | Median minutes 2p / 3p / 4p |
|---|---|---|---|---|---|
| **×55 (v3, approved)** | 1,760 / 1,815 | 40.5 / 40.7 / 31.2 | 40.5 / 6.5 / 0.7 | 65.8% | 17.8 / 20.2 / 22.0 |
| ×50 | 1,600 / 1,650 | 36.3 / 34.7 / 26.9 | 36.3 / 5.5 / 0.4 | 66.5% | 17.8 / 20.2 / 22.0 |
| ×45 (v2 row) | 1,440 / 1,485 | 29.6 / 30.2 / 22.8 | 29.6 / 3.8 / 0.2 | 52.0% | 17.9 / 20.3 / 22.0 |

**Proposal, for the owner to decide; v3 keeps ×55 as approved:**
- Keep ×55 for the first human playtest. It is the approved value, and the alternatives mainly trade decisiveness for fewer one-hit eliminations without changing duration.
- If playtesters find single-roll eliminations frustrating, ×50 is the smallest step back. It keeps about 85–90% of v3's bankruptcy pressure.
- Separately, consider whether Tourism Boom should apply to level-3 rent, or should be capped. That is the source of the 1,815 RC peak. It is a card-content question, and the cards are still DRAFT.

## 8. Simulation limits
- **Bots are heuristic.** They buy almost anything affordable, never block opponents' districts, use formulaic trade acceptance, ignore the scoring formula and keep fixed cash reserves. Humans will likely build and trade more deliberately, so they may see *more* L3 rent and bankruptcies than these numbers.
- **Time models are assumptions** (fast / medium / slow). **No per-turn time has been measured, and no UI exists.** The 20–30 min target is unverified.
- 3% of decisions time out on purpose. Real idle rates are unknown.
- Confidence intervals cover sampling noise only, not model error.
- No real-device runs. iPhone 14 Pro performance is still untested (needs macOS + Xcode, see M1_REPORT §11).

## 9. Parameters that still need human playtests
1. **Real seconds per turn** for 2 / 3 / 4 players (dice + token animation, decisions, trades, auctions). This decides whether the caps of 40 / 30 / 25 hit 20–30 min, and how often the 30-minute time cap fires in 4p.
2. **Whether one-roll eliminations** from 1,760–1,815 RC rents feel fair or frustrating. Decide ×55, ×50 or a Tourism Boom adjustment.
3. **The wait for knocked-out players** in 3p (one player out, two continuing to round 30) and in 4p.
4. **The size of the seat advantage with humans**, which decides whether compensation is needed (still not applied).
5. **Whether winning feels like "building an empire"** under liquidation-based net worth (GDD), or the owner wants to revisit book value later.
6. **Investor strength in 3p,** and the final wording of the cards and abilities (still DRAFT).
7. **2p decisiveness:** 40% elimination endings, P10 13 min. Check whether short 2p matches are acceptable.

## 10. Files changed
**Modified:**
- `client/data/rules/balance.json` (v3)
- `client/scripts/domain/game_config.gd` (`max_rounds_for`, validation)
- `client/scripts/domain/game_engine.gd` (one line: per-count cap)
- `client/scripts/sim/invariants.gd`, `client/scripts/sim/bot_player.gd` (read the cap through `max_rounds_for`)
- `client/scripts/sim/match_simulator.gd`, `client/scripts/sim/sim_stats.gd` (rent-level / max-rent / bankruptcy-debt metrics)
- `client/tests/sim/run_experiments.gd` (per-count cap patching)
- The tests listed in §3
- `docs/RULES_M1.md`, `README.md`, `docs/IMPLEMENTATION_PLAN.md`

**Added:**
- `client/tests/unit/test_balance_v3.gd`
- `client/tests/sim/experiments/m12_*.json`
- `docs/M1_2_BALANCE_V3_REPORT.md`
- `docs/test-logs/m1.2/*`

**Unchanged:** GDD, handoff docs, reference art, event cards, characters, opportunities, all rule mechanics, `main`, `claude/m1-offline-game-rules`, `claude/m1-1-balance-review`.

## 11. Commits and branch
Branch `claude/m1-2-balance-v3` pushed to `origin`:
- `eed83c9`: balance DRAFT v3 + tests
- `fe567cf`: metrics + M1.2 specs
- `79f9ff9`, `5ee01eb`: logs
- The final commit adds this report, the remaining logs and doc updates. Its hash is reported in the hand-off message, because a commit cannot contain its own hash.

No PR was created and nothing was merged. M2 was not started.
