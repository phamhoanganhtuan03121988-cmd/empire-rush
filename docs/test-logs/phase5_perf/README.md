# Phase 5 — benchmark (lavapipe CPU renderer, NOT a phone, NOT Windows)

**Method:** as in Phase 3 and 4 (`docs/device/PERFORMANCE_BENCHMARK.md` §A).
- Script: `client/tests/capture/perf_bench.gd`.
- 786×1704 window, fixed scene: 4 players, seed 7, buy prompt open, bots frozen. 120 frames per preset (Low / Medium / High).
- A/B on the same machine, interleaved: P4, P5, P4, P5, P4, P5.
  - `ab_phase4_8e571e2_*.json`: the Phase 4 / Windows playtest commit `8e571e2`, from a separate git worktree.
  - `ab_phase5_*.json`: the Phase 5 code.
- Each run alone on the machine. No other test, capture or build ran at the same time.
- Output paths in `meta.args.out` are the file name only (privacy scan CLEAN).

## Frame time (ms, lower is better)
| Preset | Phase 4 `8e571e2` p50 (runs) | Phase 5 p50 (runs) | Change |
|---|---|---|---|
| Low | 131.5 (136.7, 131.5, 126.4) | 117.8 (118.0, 116.0, 117.8) | −10% |
| Medium | 330.2 (330.2, 331.1, 318.2) | 219.5 (219.5, 219.5, 222.2) | −34% |
| High | 664.3 (713.8, 664.3, 652.4) | 473.0 (486.6, 464.4, 473.0) | −29% |

The p95 values (median of 3 runs) move the same way: 160.7 → 140.7 (Low), 372.6 → 254.2 (Medium) and 744.8 → 531.6 (High).

## Scene cost
| | Phase 4 | Phase 5 |
|---|---|---|
| Draw calls, Low / Medium+High | 90 / 118 | 98 / 126 |
| Triangles, Low / Medium+High | 55,992 / 100,560 | 58,388 / 105,848 |
| Video memory, Low / Medium / High | 84.1 / 114.5 / 145.7 MB | 90.5 / 120.8 / 152.0 MB |
| Static memory | ~56 MB | ~59 MB |
| Scene load + instantiate | 248–305 ms | 349–388 ms |
| Launch to first frame | 1.19–1.57 s | 2.07–2.37 s |

## Reading
- **Why frames got faster:** the animated water shader covered most of the screen and was expensive per pixel on a CPU renderer. Phase 5 replaces it with an unshaded tabletop shader (felt, light pool, contact shadow, dither). The new city blocks, price labels and plinth add 8 draw calls and ~5% triangles, which costs less than what the water cost.
- **What got worse:** about +6 MB video memory, +3 MB static memory and about +0.8 s to the first frame. Likely causes, **not measured one by one**:
  - loading the audio: 20 WAV effects and the OGG music loop;
  - building the title and onboarding pages, which are created up front;
  - compiling the new shader.
- **Limits:**
  - lavapipe renders on the CPU, so these numbers say nothing about FPS on a phone or a Windows GPU. Only the *relative* change on the same machine is meaningful.
  - Run-to-run noise is about ±5%.
  - No Windows-GPU or phone numbers were taken in Phase 5. The Windows CI runner only checks that the build starts and renders; it does not benchmark.
