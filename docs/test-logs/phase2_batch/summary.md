# Bot batch simulation

- Engine: 4.7.2-stable (official) · rules fingerprint `d5e3a9a877afe932`
- Balance: DRAFT v3 (owner-approved Option C from docs/M1_BALANCE_REVIEW.md, 2026-10-18) - trial values, NOT locked; per-turn timing must be measured after M2. All money is integer RC.
- Args: {"idle":"3","matches":"5000","mode":"fast","out":"/home/user/empire-rush/docs/test-logs/phase2_batch","players":"2,3,4","repro":"200","seed":"100001"}
- BotPlayer (scripted heuristic bot, idle_pct=3). Durations use the simulated game clock (time model in batch.json), not CPU time.
- Total CPU time: 468.0 s. Matches: 15000. Stuck: 0. Invariant errors: 0. Rejected bot commands: 0.
- Reproducibility: 600 matches re-run, 0 final-state hash mismatches.

| Players | n | min | p10 | p25 | median | p75 | p90 | p95 | max (min) | > 35 min |
|---|---|---|---|---|---|---|---|---|---|---|
| 2 | 5000 | 5.0 | 10.7 | 12.8 | **14.5** | 15.9 | 17.1 | 17.8 | 21.8 | 0 |
| 3 | 5000 | 9.4 | 14.4 | 15.5 | **16.6** | 17.9 | 19.0 | 19.7 | 24.1 | 0 |
| 4 | 5000 | 11.9 | 16.0 | 17.0 | **18.2** | 19.4 | 20.6 | 21.4 | 25.4 | 0 |

| Players | End reasons (%) | Matches with a bankruptcy | Bankruptcies / match | Turns | Auctions | Upgrades | Trades (proposed / accepted) | Timeouts | Stuck / invalid |
|---|---|---|---|---|---|---|---|---|---|
| 2 | {"last_solvent":44.1,"round_cap":55.9} | 44.1% | 0.44 | 73.0 | 1.91 | 24.07 | 5.14 / 2.12 | 11.06 | 0 / 0 |
| 3 | {"last_solvent":7.1,"round_cap":92.9} | 40.6% | 0.48 | 87.6 | 1.63 | 20.91 | 5.89 / 2.50 | 12.36 | 0 / 0 |
| 4 | {"last_solvent":0.9,"round_cap":99.1} | 32.4% | 0.43 | 98.7 | 1.41 | 16.85 | 5.19 / 2.20 | 12.98 | 0 / 0 |

Seat win rates (shared first places split; ±95% CI):

- 2p: seat 0 52.9% ±1.4, seat 1 47.1% ±1.4 (fair share 50.0%)
- 3p: seat 0 37.9% ±1.3, seat 1 32.5% ±1.3, seat 2 29.6% ±1.3 (fair share 33.3%)
- 4p: seat 0 30.9% ±1.3, seat 1 26.1% ±1.2, seat 2 23.0% ±1.2, seat 3 20.0% ±1.1 (fair share 25.0%)

Bots are scripted heuristics, not people: this measures rules flow and pacing under a time model, not fun or real human turn times.
