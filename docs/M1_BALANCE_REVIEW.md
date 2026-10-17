# M1.1 — Balance & Rules Review

Date: 2026-10-17 · Branch: `claude/m1-1-balance-review` (from `claude/m1-offline-game-rules` @ `3ac5dd6`) · Engine: Godot 4.7.2-stable headless
Status: **analysis and proposals only.** No balance value, rule, card or character was changed. `client/data/rules/*`, `game_engine.gd` and every M1 test are byte-identical to the M1 branch. All content stays **DRAFT** pending owner approval.

## 0. TL;DR
1. **Why matches end on the 25-round cap.** For 3–4 players this is structural: an elimination win needs 2–3 bankruptcies, and the economy inflates late. Start pays about 47 RC per player-turn, rent only moves money between players, and the big sink (buying property) is gone once the board is sold. Average cash *rises* from round 10 to round 25.
2. **Why simulated matches were short.** It is mostly the M1 time model (about 11 s per turn), plus the fixed 25 rounds for every player count. Duration ≈ rounds × players × s/turn, so 2-player matches are always about half as long as 4-player ones. **Whether the 20–30 min target is met depends on real per-turn time, which has not been measured.** Nothing here proves the target.
3. **First-player advantage is real and stable.** Across 5 independent seed blocks (10,000 four-player matches), seat 0 wins 31.2% and seat 3 wins 19.7% (±0.9). The mechanism is first access to property: seat 0 owns 2.70 properties at round 5, seat 3 owns 2.11. None of the economy options fixes it. Seat cash compensation does reduce it for 3–4 players; that is **data only, not adopted**.
4. **Net-worth formula.** The winner holds the most cash in 84–89% of matches. But a deliberate end-game cash-hoarding bot gains **no significant advantage** under the current formula. Ranking by book value would change the winner in 12–17% of matches and would penalize hoarding.
5. **Recommendation, pending owner approval:**
   - Option C: per-player-count round caps (2p 40 / 3p 30 / 4p 25) plus stronger level 1–3 rent and cheaper upgrades.
   - Keep the Start reward at 200 (GDD value).
   - A separate owner decision on seat compensation.
   - A separate owner decision on book-value ranking.
   - Validate everything with human playtests before locking.

## 1. Method
- **Engine.** The unchanged M1 rules engine. The experiment tooling (`client/tests/sim/run_experiments.gd`, `scripts/run_experiments.sh`, specs in `client/tests/sim/experiments/`) changes **only** simulation inputs:
  - balance patches through `GameConfig.with_balance()`, which never mutates the shipped config;
  - per-player-count round caps;
  - the time model;
  - an experiment-only seat cash delta;
  - a per-seat bot "hoarder" knob.
- **Default path reproduces M1.** Before any experiment, all four M1 simulation batches were re-run with the new tooling. They reproduced the committed M1 logs exactly: identical summaries and all 100 per-match rows. A unit test also asserts that explicit default options equal M1 behavior.
- **Paired comparison.** Every variant in a spec runs on the **same seeds**, so differences between variants are not seed noise. Seed blocks differ from M1's (M1 used 1…, 100000…, 200000…, 300000…).
- **Sample sizes.** Per variant: 1,000 two-player, 1,000 three-player and 2,000 four-player matches. Seat bias: 5 blocks × (1,000 / 1,000 / 2,000). In total **96,000 simulated matches** across the M1.1 experiments (12k pacing + 20k seat blocks + 16k hoarding + 24k options + 24k sensitivity), plus 4,100 for baseline reproduction: 0 stuck, 0 invariant violations, 0 rejected bot commands.
- **95% confidence intervals.** Normal approximation: about ±3.1 pp at n = 1,000 near 50%, about ±1.9 pp at n = 2,000 near 25%.
- **Time models.** All three are assumptions; none has been measured.

| Model | Decisions | Dice + token animation | Typical s/turn |
|---|---|---|---|
| `m1` (fast, M1 report) | 0.6–5 s | 1.8 s + 0.25 s/space | 11–12 |
| `medium` | 1–6 s | 2.2 s + 0.30 s/space | 13.5–14.5 |
| `slow` | 1.5–9 s | 2.5 s + 0.35 s/space | 17.5–18.5 |

## 2. Why nearly every match hits the 25-round cap
Data: `docs/test-logs/m1.1/pacing.json` (seed base 500000, M1 balance).

### 2.1 Money flow per player-turn (M1 balance, RC)
| Flow | 2p | 3p | 4p |
|---|---|---|---|
| Start reward (bank → player) | **+47.0** | **+46.8** | **+46.7** |
| Rent (player → player, zero-sum for the economy) | 14.9 | 29.4 | 36.5 |
| Purchases (player → bank, front-loaded) | 51.0 | 38.8 | 30.5 |
| Upgrades (player → bank) | 15.2 | 13.6 | 10.4 |
| Wealth tax (player → bank) | 5.5 | 5.5 | 5.4 |
| Average cash per player at round 5 / 10 / 15 / 20 / 25 | 1194 / 1112 / 1025 / 972 / 978 | 1225 / 1207 / 1194 / 1232 / 1323 | 1250 / 1285 / 1346 / 1455 / 1600 |

**Reading it:**
- Purchases are the main money sink, but they stop once the board is sold (only about 2–4 of 21 properties are still unowned at the end).
- After that, the bank injects about 47 RC per turn through Start and removes only about 16–21 RC per turn through upgrades and tax.
- Rent redistributes money between players but does not drain the table.
- So with 3–4 players, average cash *grows* through the second half, and bankruptcies are rare and late (median round 23).

### 2.2 Structural reason
- An elimination win needs n − 1 bankruptcies. With 4 players that is 3 in 25 rounds, and it happens in 0.1–0.3% of matches.
- Even the strongest pressure option tested (V5) only reaches 1.2% elimination wins in 4p.
- **For 3–4 players, the round cap is the expected ending in any balance close to the current one.** The GDD's 25 rounds / 30 min / net-worth ending is doing its job. Bankruptcies change *who* wins, not *how* matches end.

### 2.3 Duration
Medians are in minutes (P90 in brackets). The game outcomes are identical across time models; only the clock differs, except where the 30-minute cap triggers.

| Time model | 2p | 3p | 4p | 4p ending on time cap |
|---|---|---|---|---|
| m1 (fast) | 9.8 (11.5) | 14.1 (16.1) | 18.3 (20.8) | 0% |
| medium | 11.9 (13.6) | 17.0 (19.1) | 22.2 (24.6) | 0% |
| slow | 15.4 (17.0) | 22.1 (24.1) | 28.7 (30.2) | **19.3%** |

**Conclusions:**
- Duration ≈ rounds × players × seconds per turn. With a fixed 25 rounds, **2-player matches cannot reach 20 minutes** unless a turn takes about 24 s or more.
- 4-player matches reach the 22–27 min target only if a real turn takes about 13–16 s. That is plausible but **unmeasured**.
- Under the slow model, 4-player matches hit the 30-minute time cap in about 19% of cases, so the cap becomes an active ending.

## 3. First-player (seat) advantage
Data: `docs/test-logs/m1.1/seat_block_{1..5}000000.json` (M1 balance, m1 time model).

| Players | Matches | Seat 0 | Seat 1 | Seat 2 | Seat 3 | 95% CI | Fair share |
|---|---|---|---|---|---|---|---|
| 4 | 10,000 | **31.2** | 26.6 | 22.6 | **19.7** | ±0.9 | 25.0 |
| 3 | 5,000 | **37.3** | 33.3 | **29.4** | — | ±1.3 | 33.3 |
| 2 | 5,000 | **53.6** | **46.4** | — | — | ±1.4 | 50.0 |

**Stability across blocks.** In 4-player games seat 0 won 30.8–31.9% in every one of the 5 blocks, and seat 3 won 18.6–20.9%. The bias is monotonic in seat order in every block for 4 players.

**Mechanism.** Average properties owned at round 5:

| Players | Seat 0 | Seat 1 | Seat 2 | Seat 3 |
|---|---|---|---|---|
| 4 | 2.70 | 2.48 | 2.29 | 2.11 |
| 3 | 2.80 | 2.58 | 2.35 | — |
| 2 | 2.89 | 2.67 | — | — |

Early seats reach unowned land first. All seats play the same number of turns (the round cap ends after the last seat), so turn count is not the cause.

**Mitigation data.** Option V4, medium model, seed base 800000. **Data only: no compensation is in the rules or data.**

| Seat cash delta (seat k gets +k × delta) | 4p win % by seat (spread) | 3p (spread) | 2p (spread) |
|---|---|---|---|
| 0 (V4 baseline, same seeds; fast model, identical outcomes) | 30.1 / 26.8 / 23.3 / 19.9 (10.2) | 35.4 / 34.1 / 30.5 (4.9) | 55.1 / 44.9 (10.2) |
| +25 | 29.1 / 26.1 / 23.8 / 21.0 (8.1) | 34.9 / 34.1 / 31.0 (3.9) | 54.3 / 45.7 (8.6) |
| +50 | 27.9 / 26.1 / 24.4 / 21.7 (6.2) | 34.4 / 33.8 / 31.8 (2.6) | 54.1 / 45.9 (8.2) |
| +75 | 27.3 / 26.4 / 24.4 / 22.1 (5.2) | 33.4 / 33.5 / 33.1 (0.4) | 53.9 / 46.1 (7.8) |
| +100 | 26.5 / 25.4 / 24.8 / 23.4 (3.1) | 32.7 / 33.4 / 33.9 (1.2) | 53.7 / 46.3 (7.4) |

**Reading it:**
- Cash compensation works for 3–4 players. About +75 to +100 RC per seat brings the spread inside about 1–2 CIs.
- It barely moves 2-player games. There the advantage seems to come from tempo, not cash.
- These are bot results. Humans exploit first access differently, so any compensation value must be confirmed in playtests.

Other mitigations exist but were **not simulated**, because they would be new rules: a random first seat (this hides the bias rather than removing it), auction-only first lap, or reverse order in the last round. They are listed only as ideas for the owner.

## 4. Net worth, liquidation value and holding cash
Data: `pacing.json` and `balance_options.json` (valuation metrics), plus `hoarding.json`.

GDD §5 defines `net_worth = cash + liquidation value`. Property counts at 50% of price, plus 50% of building cost. Cash counts at 100%.

**Observations (M1 balance):**

| | 2p | 3p | 4p |
|---|---|---|---|
| Winner holds the most cash | 88.9% | 83.9% | 85.2% |
| Cash share of the winner's net worth | 59.5% | 72.8% | 78.5% |
| Cash share of the others' net worth | 38.8% | 58.7% | 71.3% |
| Winner would change if ranked by book value (cash + full price + full upgrade cost) | 16.8% | 16.9% | 11.8% |

**Is holding cash an exploit? Paired hoarding experiment** (seed base 600000). One bot, at seat (seed mod n) so that seat bias averages out, stops buying, bidding, upgrading and trading in the last N rounds:

| Focus seat strategy | 2p win % | 3p win % | 4p win % | Same strategy if ranked by book value (2p / 3p / 4p) |
|---|---|---|---|---|
| Normal play (control) | 50.6 | 32.9 | 23.9 | 52.7 / 32.7 / 24.0 |
| Hoard last 3 rounds | 53.5 | 34.0 | 24.1 | 49.3 / 32.4 / 23.4 |
| Hoard last 5 rounds | 54.7 | 33.4 | 23.9 | 45.6 / 30.6 / 22.6 |
| Hoard last 8 rounds | 52.5 | 31.8 | **20.4** | **36.3** / 26.6 / 17.9 |

95% CI: ±3.1 (2p), ±2.9 (3p), ±1.9 (4p).

**Reading it:**
- With the current formula, end-game hoarding gives **no significant gain** for 3–4 players. In 2p there is at most about +4 pp, roughly at the edge of the CI. Hoarding for 8 rounds hurts.
- The "winner has the most cash" correlation is mostly a symptom: winners are the players collecting rent. It is not a hoarding loophole for these bots.
- Under book-value ranking, hoarding is clearly penalized: the 2p hoard-5 player falls from 54.7% to 45.6% winning.
- **Limits.** The bots do not plan against the scoring formula. A human can do things the bots don't: refuse late upgrades whose 50% valuation loss exceeds the rent they would still earn, or decline late purchases. Treat these numbers as a lower bound on how much the formula can be exploited.

**Valuation options:**
| Option | Pros | Cons |
|---|---|---|
| N1. Keep GDD liquidation value (current) | Matches the GDD; one value used for both rescue and scoring; no hoarding exploit in bot data | Investing late *lowers* your score (a 260 RC property scores 130 RC), which works against the "build your empire" fantasy; the winner is usually the cash-richest player |
| N2. Book value for the **final ranking only** (cash + price + upgrade costs paid); rescue liquidation stays at 50% | Buying and building never lowers your score, so late-game building stays attractive; penalizes passive hoarding; changes the winner in about 8–17% of matches | **Changes GDD §5** (owner approval needed); a fully developed board could favor the early land-grabber (interacts with seat bias) |
| N3. Intermediate scoring value (for example 75% of book value) | A compromise | Another constant to tune; not simulated |

## 5. Balance options, side by side
Data: `docs/test-logs/m1.1/balance_options.json`. Seed base 700000, medium time model, same seeds for every variant. "Bankruptcy %" means matches with at least one bankruptcy. "Elim." is the share of matches won by elimination (last solvent player).

**What each variant changes:**
| Variant | Change | Changes a GDD value? |
|---|---|---|
| V0 | M1 baseline | — |
| V1 | Round cap 2p 40 / 3p 30 / 4p 25 | GDD §2 says 25 rounds; per-count caps need owner OK |
| V2 | Rent level rows ×7 / ×22 / ×55 (from ×6 / ×18 / ×45); upgrade cost 30 / 30 / 45 / 45 / 60 / 60 / 75 (from 40 / 40 / 60 / 60 / 80 / 80 / 100) | No (all tunable DRAFT values) |
| V3 | Start reward 150 (from 200) | **Yes** (GDD §2: 200 RC) |
| V4 | V1 + V2 | Round caps only |
| V5 | V1 + V2 + V3 | Round caps + Start reward |

**Results:**
| Variant | Median min 2p / 3p / 4p | Bankruptcy % 2p / 3p / 4p | Elim. 2p / 3p / 4p | Seat spread pp 2p / 3p / 4p | Investor win % (fair 50 / 33.3 / 25) | Winner ≠ book leader % (4p) |
|---|---|---|---|---|---|---|
| V0 | 11.9 / 17.2 / 22.1 | 2.5 / 10.4 / 20.3 | 2.5 / 0.2 / 0.1 | 3.4 / 9.8 / 8.1 | 54.4 / 37.5 / 27.5 | 11.8 |
| V1 | **18.1 / 20.4 / 22.1** | 27.8 / 27.2 / 20.3 | 27.8 / 2.8 / 0.1 | 6.2 / 12.5 / 8.1 | 52.0 / 35.9 / 27.5 | 11.8 |
| V2 | 11.8 / 17.2 / 22.0 | 5.4 / 18.1 / 31.2 | 5.4 / 1.5 / 0.7 | 4.6 / 8.8 / 7.9 | 54.6 / 37.7 / 26.8 | 8.3 |
| V3 | 11.8 / 17.3 / 22.1 | 3.8 / 13.4 / 24.3 | 3.8 / 0.5 / 0.3 | 5.0 / 8.3 / 8.5 | 57.0 / 36.9 / 27.5 | 12.6 |
| **V4** | **17.8 / 20.2 / 22.0** | **40.5 / 40.7 / 31.2** | 40.5 / 6.5 / 0.7 | 4.8 / 10.8 / 7.9 | 51.7 / 36.4 / 26.8 | 8.3 |
| V5 | 17.6 / 20.1 / 22.0 | 46.7 / 47.5 / 37.4 | 46.7 / 10.8 / 1.2 | 3.2 / 9.4 / 9.4 | 52.3 / 35.6 / 27.3 | 9.3 |

**Average cash per player** (2p r25 / r40; 3p r25 / r30; 4p r25):
| Variant | 2p | 3p | 4p |
|---|---|---|---|
| V0 | 970 / — | 1,332 / — | 1,597 |
| V4 | 1,056 / 1,394 | 1,404 / 1,536 | 1,652 |
| V5 | 817 / 1,026 | 1,143 / 1,219 | 1,383 |

**V4 sensitivity to the time model** (seed base 800000). Median minutes, P90 in brackets:
| Time model | 2p | 3p | 4p |
|---|---|---|---|
| m1 (fast) | 14.5 (17.2) | 16.6 (19.1) | 18.1 (20.6) |
| medium | 17.7 (20.5) | 20.2 (22.7) | 22.1 (24.4) |
| slow | 23.0 (25.8) | 26.1 (28.5); 1.4% time cap | 28.5 (30.1); 15.5% time cap |

**Side effects and observations:**
- **Per-player-count caps (V1)** are the only lever that equalizes duration across player counts. They also raise 2p and 3p bankruptcies a lot, because longer matches give buildings time to bite. Taken alone, they leave the 3–4p late-game inflation in place.
- **Rent and upgrade pressure (V2)** raises 4p bankruptcies from 20% to 31% and reduces "winner ≠ book leader" (more value sits in buildings). Duration is unchanged.
- **Start 150 (V3)** clearly drains cash (4p average cash at round 25 falls from 1,597 to 1,335) but adds few bankruptcies. It also changes a GDD constant.
- **V4 and V5 in 2p:** 40–47% of 2-player matches now end by elimination, around round 33. That is good for decisive 2p games, but it means 2p duration varies more (P90 about 20.5 min in the medium model).
- **Seat bias** is essentially unchanged by every economy option (spread 3–12 pp, within noise of each other). It needs its own fix (§3).
- **Investor** is 2–4 pp above fair share in 3p in every variant of this seed block (35.6–37.7% vs 33.3%), and slightly above in 4p. But on the sensitivity seed block (800000), V4 3p Investor was 31.8%. So the 3p effect is partly seed noise and needs a bigger sample before tuning. Characters stay **DRAFT** and were not changed in M1.1.

## 6. Proposed packages
### Option A: "Minimal" (V1)
- Per-player-count round caps (2p 40 / 3p 30 / 4p 25). Keep all M1 values.
- **Pros:** one rule change; equalizes duration (medium model 18–22 min); keeps the GDD economy.
- **Cons:** 3–4p economy still inflates and the winner is usually cash-rich; 4p bankruptcies unchanged at about 20%.

### Option B: "Economy pressure, GDD caps" (V2)
- Stronger level 1–3 rent and cheaper upgrades. Keep 25 rounds everywhere.
- **Pros:** no GDD change (only tunable values); more bankruptcies and more value in buildings.
- **Cons:** 2p stays about 12 min and 3p about 17 min (medium model); the pacing problem is not addressed.

### Option C: "Recommended" (V4 = A + B)
- Per-player-count caps, stronger level 1–3 rent and cheaper upgrades. Start reward stays 200 (GDD).
- **Pros:**
  - Medium-model medians of about 18 / 20 / 22 min for 2 / 3 / 4 players.
  - More bankruptcies (31–41% of matches) and decisive 2p endings.
  - Building matters more (winner ≠ book leader drops to 8% in 4p).
  - The only GDD change is the per-count round cap.
- **Cons:**
  - Rent at L3 for tier 7 rises to 1,760 RC (32 × 55), which is very punishing.
  - 2p duration is more variable.
  - Seat bias is untouched.
  - Under the slow model, 4p would hit the 30-minute cap in about 15% of matches.

### Option D: "Aggressive" (V5 = C + Start 150)
- **Pros:** strongest cash drain.
- **Cons:** changes the GDD Start reward; only small extra gain over C for 3–4p.

### Independent decisions, combinable with any package
- **S1. Seat compensation.** For example +75 RC per seat index for 3–4p. Bot data says it removes most of the 3–4p bias and does almost nothing for 2p. This is a new rule (owner approval needed) and the value must be playtested.
- **N2. Book-value final ranking** (§4). A GDD §5 change.

### My recommendation
1. Adopt **Option C** as the next DRAFT balance (v3).
2. Take **S1** for 3–4p **only after** a human playtest confirms the bias. Bots are a weak proxy for how humans race for land.
3. Choose between **N1 and N2** based on the product intent:
   - If building an empire should always score, pick N2.
   - If the owner wants to stay close to the GDD, keep N1. The bot data shows no hoarding exploit today.
4. Do **not** change the Start reward (D) unless playtests show C is still too inflationary.
5. Re-tune Investor after the economy is settled, then lock event and character content.

**Nothing above is applied.** `balance.json` is still M1 v2, so every M1 result remains the reference. Once the owner approves a package, the implementation is small:
- update `balance.json` (and, for per-count caps, add a `max_rounds_by_players` key read by `_end_turn`);
- add tests for the new values;
- re-run the M1 suite and simulations, and report before/after.

## 7. Bot and simulation limitations
- The bots are heuristic. Fixed reserves; they buy almost anything affordable; they never deny opponents a district, plan multi-turn trades, or react to the scoring formula; trade acceptance is formulaic.
  - Humans will likely trade more cleverly (more completed districts, more rent, more bankruptcies).
  - Humans will likely race for land harder (bigger seat effects).
- The time models are assumptions. **No UI exists, and no per-turn time has been measured.** No duration in this document is evidence that the 20–30 minute target is met.
- 3% of decisions time out on purpose (to exercise timeouts). Real idle rates are unknown.
- Confidence intervals cover sampling noise only, not model error (bot behavior, time model).
- Seat and character assignment rotate with the seed. Each character appears at each seat about equally often in the large runs.

## 8. Commands executed (all exit 0, 0 failures)
```
# Baseline reproduction (tooling must not change M1 results)
scripts/run_simulation.sh --matches=100  --players=2,3,4 --seed=1      --out=<scratch>/m1_sim_100_mixed.json
scripts/run_simulation.sh --matches=2000 --players=4     --seed=100000 --summary=1 --out=<scratch>/...
scripts/run_simulation.sh --matches=1000 --players=3     --seed=200000 --summary=1 --out=<scratch>/...
scripts/run_simulation.sh --matches=1000 --players=2     --seed=300000 --summary=1 --out=<scratch>/...
  → all four identical to docs/test-logs/m1_* (100 per-match rows compared)

# M1.1 experiments
scripts/run_experiments.sh --spec=res://tests/sim/experiments/pacing.json  --out=$PWD/docs/test-logs/m1.1/pacing.json               (12,000 matches)
scripts/run_experiments.sh --spec=res://tests/sim/experiments/seat_baseline.json --seed_base={1,2,3,4,5}000000 --out=.../seat_block_*.json (20,000)
scripts/run_experiments.sh --spec=res://tests/sim/experiments/hoarding.json --out=.../hoarding.json        (16,000)
godot --headless --path client --script res://tests/sim/run_experiments.gd -- --spec=res://tests/sim/experiments/balance_options.json --out=.../balance_options.json   (24,000)
godot --headless --path client --script res://tests/sim/run_experiments.gd -- --spec=res://tests/sim/experiments/recommendation_check.json --out=.../recommendation_check.json (24,000)

# Tests
GODOT=/opt/godot/Godot_v4.7.2-stable_linux.x86_64 scripts/run_tests.sh
  → RESULT: 151 passed, 0 failed  (144 M1 tests unchanged + 7 new tooling tests; docs/test-logs/m1.1/m1_1_tests.txt)
```
The two direct `godot` invocations skip the import step so that they could run in parallel with the other batches. The project had already been imported. Logs: `docs/test-logs/m1.1/*.txt|json`.

## 9. Files changed in M1.1
**Added:**
- `client/scripts/sim/sim_stats.gd`: aggregation moved out of `run_simulation.gd` unchanged, plus the M1.1 metrics.
- `client/tests/sim/run_experiments.gd`, `client/tests/sim/experiments/*.json`, `scripts/run_experiments.sh`.
- `client/tests/unit/test_experiment_tooling.gd`: 7 tests.
- `docs/M1_BALANCE_REVIEW.md`, `docs/test-logs/m1.1/*`.

**Modified:**
- `client/scripts/sim/match_simulator.gd`: time model, experiment-only seat delta, per-seat bot options, flow and valuation metrics. Defaults are unchanged.
- `client/scripts/sim/bot_player.gd`: `endgame_freeze_rounds` knob, default 0.
- `client/scripts/domain/game_config.gd`: `with_balance()`, a pure helper that does not change validation or loading.
- `client/tests/sim/run_simulation.gd`: delegates to SimStats with identical output.

**Unchanged:** all rules data, `game_engine.gd`, every M1 test, the GDD and the handoff docs. Verified with `git diff` against the M1 branch.

## 10. Questions for the owner
1. Approve per-player-count round caps (GDD §2 says 25)? Which values?
2. Approve Option C's rent/upgrade values as DRAFT v3, or prefer A or B?
3. Seat compensation: playtest first (recommended), or adopt a provisional value?
4. Final ranking: keep liquidation value (GDD, N1) or switch to book value (N2)?
5. Keep the Start reward at 200 (recommended)?
6. Target device timing: can we get a per-turn time estimate from the M2 prototype before locking caps?
