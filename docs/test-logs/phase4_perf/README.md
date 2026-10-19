# Phase 4 — benchmark (lavapipe CPU renderer, NOT a phone)

**Method:** as in Phase 3 (`docs/device/PERFORMANCE_BENCHMARK.md` §A).
- 786×1704, fixed scene (4 players, seed 7, buy prompt open, bots frozen), 120 frames, presets Low / Medium / High.
- Each run alone on the machine. No other benchmark, test or e2e ran at the same time.
- Output paths in `meta.args.out` were reduced to the file name (privacy scan CLEAN).

## 1. `final_1..3.json` — Phase 4 code, three runs
p50 frame time 128.6 / 325.1 / 665.8 ms (Low / Medium / High). That is ~1.9× the Phase 3 files (69.0 / 167.3 / 352.6 ms). Draw calls, triangles and memory are **identical**, so the code was the first suspect to rule out.

## 2. A/B on the same machine, interleaved (P3, P4, P3, P4, P3, P4)
- `ab_phase3_f6a506e_*.json`: the Phase 3 final commit, from a separate worktree.
- `ab_phase4_*.json`: the Phase 4 code.

| Preset | Phase 3 `f6a506e` p50 (runs) | Phase 4 p50 (runs) | Difference |
|---|---|---|---|
| Low | 129.4 (131.1, 123.4, 133.6) | 129.6 (131.8, 134.9, 122.3) | +0.2% |
| Medium | 316.4 (324.9, 312.5, 311.9) | 321.4 (320.4, 334.6, 309.1) | +1.6% |
| High | 650.3 (652.8, 648.6, 649.6) | 647.8 (638.9, 661.6, 643.1) | −0.4% |

| Both commits | Low | Medium | High |
|---|---|---|---|
| Draw calls | 90 | 118 | 118 |
| Triangles | 55,992 | 100,560 | 100,560 |
| Video memory | 84.1 MB | 114.5 MB | 145.7 MB |

Static memory is ~56 MB for both.

**Conclusion:** no regression. Every difference is inside the ±5% run-to-run noise. The 1.9× slowdown against the Phase 3 files comes from the machine: this container has 4 CPUs today, and lavapipe renders on the CPU. Phase 4 made no rendering change and no optimisation.

**Load time on the same machine:**
- scene load + instantiate: 227–252 ms (P3), 238–319 ms (P4);
- to first frame: 1.26–1.56 s (P3), 1.19–1.54 s (P4).

The new start menu is not on this path (the bench passes `--players`).

**Limits:**
- lavapipe numbers say nothing about iPhone FPS; device FPS has **not** been measured;
- numbers from different days or machines must not be compared directly. Always A/B on the same machine.
