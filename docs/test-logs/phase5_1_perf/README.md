# Phase 5.1: benchmark (lavapipe CPU renderer, NOT a phone, NOT Windows)

**Method:** same as Phase 5 (`docs/test-logs/phase5_perf/README.md`).
- Script: `client/tests/capture/perf_bench.gd`.
- 786×1704 window, fixed scene: 4 players, seed 7, buy prompt open, bots frozen. 120 frames per preset (Low / Medium / High).
- A/B on the same machine, interleaved: P5, P5.1, P5, P5.1, P5, P5.1. Each run alone on the machine.
  - `ab_phase5_b509100_*.json`: Phase 5 final (`b509100`), from a separate git worktree.
  - `ab_phase51_*.json`: Phase 5.1 (`683da15`, the graphics and UI changes of this phase).
- Output paths in `meta.args.out` are the file name only.

## Frame time (ms, lower is better)
| Preset | Phase 5 p50 (runs) | Phase 5.1 p50 (runs) | Change |
|---|---|---|---|
| Low | 119.3 (125.1, 115.4, 119.3) | 120.9 (119.7, 122.4, 120.9) | +1.3% |
| Medium | 233.3 (237.0, 225.0, 233.3) | 231.7 (229.2, 244.7, 231.7) | −0.7% |
| High | 495.9 (488.7, 495.9, 503.7) | 516.8 (516.8, 549.9, 509.8) | +4.2% |

The p95 values (median of 3 runs):

| Preset | Phase 5 | Phase 5.1 |
|---|---|---|
| Low | 143.0 | 143.5 |
| Medium | 260.8 | 264.7 |
| High | 567.8 | 591.4 |

## Scene cost
| | Phase 5 | Phase 5.1 | Difference |
|---|---|---|---|
| Draw calls, Low / Medium+High | 98 / 126 | 116 / 144 | +18 |
| Triangles, Low / Medium+High | 58,388 / 105,848 | 63,906 / 115,822 | +5.5k / +10k |
| Video memory, Low / Medium / High | 90.5 / 120.8 / 152.0 MB | 94.5 / 124.8 / 156.0 MB | +4 MB |
| Static memory | ~59 MB | ~61 MB | +2 MB |
| Scene load + instantiate | 390–437 ms | 461–650 ms | about +100–200 ms |
| Launch to first frame | 2.29–2.64 s | 2.25–2.81 s | overlapping |

## Reading
- **Frame time:** every change is inside the ±5% run-to-run noise seen across phases. There is no measurable frame-time cost on this renderer.
- **Where the extra draw calls come from:**
  - one portrait medallion per pawn (4);
  - one portrait seal per owned tile (owned tiles in this scene);
  - portrait badges on the HUD cards;
  - the landmark dais and its flags.
  These are counted from the code, not profiled one by one.
- **Not in the benchmark frame:** the dice stage. Its SubViewport renders only while dice are on screen (`UPDATE_WHEN_VISIBLE`), and the benchmark scene has the buy prompt open.
- **Memory:** about +4 MB video memory (8 portrait SVGs imported at 512×512, the dice stage's resources), +2 MB static.
- **Limits:** lavapipe renders on the CPU. These numbers say nothing about FPS on a phone or a Windows GPU; only the relative change on the same machine means anything. No GPU or phone measurement was made in Phase 5.1.
