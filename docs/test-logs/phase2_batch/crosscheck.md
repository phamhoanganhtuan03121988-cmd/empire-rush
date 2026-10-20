# Independent cross-check (Python)

Rules versions in the file: [('d5e3a9a877afe932', 15000)]. Duplicate rows: 0.

| Players | n | missing seeds | median min (95% CI) | p10–p90 | > 35 min | turns / player | bankrupt matches | auctions opened / sold | upgrades | timeouts | abnormal |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 2 | 5000 | 0 | **14.54** (14.47–14.61) | 10.66–17.11 | 0 | 36.52 | 44.1% | 1.906 / 1.906 | 24.07 | 11.06 | 0 |
| 3 | 5000 | 0 | **16.64** (16.58–16.71) | 14.37–19.04 | 0 | 29.2 | 40.6% | 1.629 / 1.629 | 20.91 | 12.36 | 0 |
| 4 | 5000 | 0 | **18.21** (18.14–18.28) | 15.95–20.58 | 0 | 24.67 | 32.4% | 1.407 / 1.407 | 16.85 | 12.98 | 0 |

Seat win rates (shared wins split; Wilson 95% CI; chi-square test against equal shares):

- 2p: seat 0 52.88% [51.49–54.26], seat 1 47.12% [45.74–48.51] — χ²=16.59 (df 1), p=4.6e-05
- 3p: seat 0 37.94% [36.6–39.29], seat 1 32.5% [31.22–33.81], seat 2 29.56% [28.31–30.84] — χ²=54.23 (df 2), p=1.7e-12
- 4p: seat 0 30.9% [29.63–32.2], seat 1 26.12% [24.92–27.36], seat 2 22.96% [21.82–24.15], seat 3 20.02% [18.93–21.15] — χ²=130.05 (df 3), p=5.3e-28

Final position (mean by seat, RC):

- 2p: cash [1392.3, 1248.4], net worth [2265.4, 2046.0], net worth p10/median/p90 [0, 2381, 4179], winner margin p25/median/p75 [1675, 3112, 3839]
- 3p: cash [1691.6, 1524.2, 1404.8], net worth [2341.5, 2131.8, 1959.0], net worth p10/median/p90 [0, 2075, 4537], winner margin p25/median/p75 [687, 1815, 3550]
- 4p: cash [1860.9, 1722.4, 1605.8, 1519.9], net worth [2374.5, 2194.8, 2044.2, 1924.7], net worth p10/median/p90 [0, 2017, 4360], winner margin p25/median/p75 [460, 1449, 2943]
