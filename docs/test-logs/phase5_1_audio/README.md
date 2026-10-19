# Phase 5.1: audio measured from the mixed signal (no speaker)

**Script:** `client/tests/capture/audio_record.gd`.
- Adds an `AudioEffectRecord` to the Master bus, starts a 2-player match (seed 3) and presses ĐỔ XÚC XẮC.
- Records 2.4 s of what the engine actually mixes: music + effects, after bus volumes.
- Logs the presenter beat times.

**Environment:**
- Linux container, Godot 4.7.2, headless, **Dummy audio driver** (no sound card), 44.1 kHz stereo.
- The GitHub Windows runner has no output device either (WASAPI cannot open one).
- **Nobody listened to this sound.** The measurement shows signal and timing; it does not judge how it sounds.

**Result** (run of 2026-10-19). Peak of the mix: 0.50 (no clipping).

| Beat | Beat time (ms) | Nearest 10 ms energy peak | RMS 60 ms before → after |
|---|---|---|---|
| dice_roll (throw) | 2 | +0 ms | 0.051 → 0.133 |
| dice_bounce 1 | 188 | −55 ms | 0.097 → 0.089 |
| dice_bounce 2 | 429 | −55 ms | 0.076 → 0.047 |
| dice_land | 581 | −20 ms | 0.112 → 0.067 |
| dice_result (chime) | 747 | −95 ms | 0.040 → 0.084 |
| step × 4 | 1892 / 2057 / 2223 / 2390 | −30 / −10 / −80 / −65 ms | — |

**Reading:**
- Every beat of the roll has a sound in the mix, in the order of the animation: throw → two bounces → landing → result chime → pawn steps.
- **Timing:**
  - The energy peaks come 10–95 ms *before* the logged beat times. Most of this is a constant offset between the recorder's clock and the wall clock: recording starts at the next mix block, and the Dummy driver mixes ahead.
  - Relative to each other, the sounds land within about ±45 ms of their beats.
  - These are frame-level timings on a headless CPU renderer; on a real device the animation runs at full frame rate.
- **Music:** it plays under the effects (RMS ≈ 0.02–0.04 between beats).
- **Mute:** silencing the buses is covered by `test_phase5.gd::test_audio_follows_gameplay`.
