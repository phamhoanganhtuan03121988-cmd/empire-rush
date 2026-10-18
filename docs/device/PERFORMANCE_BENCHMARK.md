# EMPIRE RUSH — Performance benchmark: how to measure (Phase 2)

There are two benchmarks. They answer different questions; never mix their numbers.

| | A. Fixed-scene bench (desktop / CI machine) | B. In-app bench on a real phone |
|---|---|---|
| Tool | `client/tests/capture/perf_bench.gd` | Device panel → **ĐO TỰ ĐỘNG** (3 presets × 60 s), internal build |
| Answers | "Did this commit make rendering cheaper or more expensive?" and "Which part of the frame costs what?" (ablations) | "Does the game hold 30 FPS on the target phone?" |
| Renderer | Whatever the machine has. In this repo's container that is **lavapipe (CPU software Vulkan)** | The phone's GPU (Metal via MoltenVK on iOS) |
| Valid conclusions | Relative before/after and cost attribution, on the same machine | Absolute frame times, thermal behaviour, memory |
| Results so far | `docs/test-logs/phase2_perf/` | **None yet.** No iPhone has been measured |

## A. Fixed-scene bench

```
xvfb-run -a -s "-screen 0 2000x2000x24" $GODOT --path client --resolution 786x1704 \
  --script res://tests/capture/perf_bench.gd -- --out=/abs/out.json --frames=120 [--presets=low,medium,high] [--ablate=1]
```

**The fixed scene:**
- 4 players, seed 7, the mid-game board from `capture_scenarios.gd`;
- buy prompt open;
- bots frozen, turn clock paused.

The same scene is used for every run.

**Rules for a valid comparison:**
1. **Same machine, same resolution, same `--frames`.** Run before and after back to back.
2. **At least 3 runs per side.** Report every p50, not just the best. On lavapipe the run-to-run spread is about ±5%; smaller differences are noise.
3. **Read `render_cpu_ms` first.** If it is tiny compared with the frame time (as on lavapipe, about 0.5 ms), the frame is GPU/raster bound. CPU-side optimisations will not show.
4. **Use `--ablate=1` to attribute cost before changing anything.** It removes one part at a time: shadows, HUD, buildings, static board, water, detail textures, glow.
5. **Add before/after screenshots of the same scene** (`capture_scenarios.gd`, same preset). This shows the change did not cost visible quality.

## B. Device measurement (iPhone 14 Pro is the reference device)

The full step list is in `IPHONE14PRO_TEST_CHECKLIST.md` (§ benchmark table, pass bar, Instruments cross-check). Before running it:

1. **Build:** `scripts/export_build.sh ios internal release` on a Mac with Xcode. The build stamp (commit) shows in the device panel. Use **release** mode; debug builds are slower and not representative.
2. **Phone state:**
   - charged > 50% and not charging;
   - Low Power Mode off;
   - brightness fixed;
   - left 5 min at room temperature before the first run.
3. **Run order:**
   - ĐO TỰ ĐỘNG cold;
   - one full match;
   - ĐO TỰ ĐỘNG again;
   - after 30 min of play, ĐO TỰ ĐỘNG a third time (thermal).
4. **Copy back** `device_validation/run_*.json` and `telemetry/session_*.json` (Files app). Record the commit, preset and thermal state for every row.
5. **Pass bar** (a proposal until the owner confirms; GDD §14 says 30 FPS on low/medium): Thấp and Vừa p95 ≤ 33.3 ms and ≤ 5% of frames over 33 ms, at every point.

**Do not** take a desktop or lavapipe number as a phone result. Do not report an FPS for a device that has not been measured.

## Phase 3 notes
- **Load time:** `perf_bench.gd` records `meta.load_ms` (scene load + instantiate, and time to the first frame).
- **Shadow map size:** fixed per preset (2048 on Medium and High). The desktop bench therefore renders the same shadow map size that Godot uses on iOS/Android. Before Phase 3, desktop silently used 4096.
- **Results:** `docs/test-logs/phase3_perf/`.

## What changed in Phase 2 (the numbers B should confirm or refute)

Triangles went from 77k to 51k, and shadow-pass triangles from 140k to 44k (High). Low uses unshaded water and no detail textures. On tile-based mobile GPUs, shadow-pass bandwidth and fill rate weigh differently from lavapipe. Measure them on the phone before tuning presets further.
