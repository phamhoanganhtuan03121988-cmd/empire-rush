# Bot batch simulation

- Engine: 4.7.2-stable (official) · rules fingerprint `d5e3a9a877afe932`
- Balance: DRAFT v3 (owner-approved Option C from docs/M1_BALANCE_REVIEW.md, 2026-10-18) - trial values, NOT locked; per-turn timing must be measured after M2. All money is integer RC.
- Args: {"idle":"3","matches":"1000","mode":"fast","out":"/home/user/empire-rush/docs/test-logs/m2_3_playtest_batch","players":"2,3,4","repro":"50","seed":"1"}
- BotPlayer (scripted heuristic bot, idle_pct=3). Durations use the simulated game clock (time model in batch.json), not CPU time.
- Total CPU time: 79.8 s. Matches: 3000. Stuck: 0. Invariant errors: 0. Rejected bot commands: 0.
- Reproducibility: 150 matches re-run, 0 final-state hash mismatches.

| Players | n | min | p10 | p25 | median | p75 | p90 | p95 | max (min) | > 35 min |
|---|---|---|---|---|---|---|---|---|---|---|
| 2 | 1000 | 6.0 | 10.3 | 12.6 | **14.4** | 16.0 | 17.1 | 17.9 | 20.6 | 0 |
| 3 | 1000 | 10.3 | 14.4 | 15.5 | **16.6** | 17.8 | 19.0 | 19.8 | 23.5 | 0 |
| 4 | 1000 | 13.9 | 16.0 | 17.0 | **18.1** | 19.4 | 20.6 | 21.2 | 24.0 | 0 |

| Players | End reasons (%) | Matches with a bankruptcy | Bankruptcies / match | Turns | Auctions | Upgrades | Trades (proposed / accepted) | Timeouts | Stuck / invalid |
|---|---|---|---|---|---|---|---|---|---|
| 2 | {"last_solvent":44.4,"round_cap":55.6} | 44.4% | 0.44 | 72.7 | 1.86 | 24.34 | 4.88 / 2.20 | 10.92 | 0 / 0 |
| 3 | {"last_solvent":7.0,"round_cap":93.0} | 41.3% | 0.48 | 87.7 | 1.60 | 21.77 | 5.77 / 2.59 | 12.29 | 0 / 0 |
| 4 | {"last_solvent":0.7,"round_cap":99.3} | 31.3% | 0.41 | 98.8 | 1.40 | 17.27 | 5.09 / 2.29 | 12.86 | 0 / 0 |

Seat win rates (shared first places split; ±95% CI):

- 2p: seat 0 54.7% ±3.1, seat 1 45.3% ±3.1 (fair share 50.0%)
- 3p: seat 0 38.8% ±3.0, seat 1 31.7% ±2.9, seat 2 29.5% ±2.8 (fair share 33.3%)
- 4p: seat 0 29.7% ±2.8, seat 1 27.3% ±2.8, seat 2 23.9% ±2.6, seat 3 19.1% ±2.4 (fair share 25.0%)

Bots are scripted heuristics, not people: this measures rules flow and pacing under a time model, not fun or real human turn times.
