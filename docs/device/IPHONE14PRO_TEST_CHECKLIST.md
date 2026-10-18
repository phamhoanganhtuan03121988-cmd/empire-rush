# iPhone 14 Pro device test checklist (M2.2)

Use with `docs/device/IOS_BUILD_GUIDE.md`. Fill in one copy per session and save it next to the JSON reports you pull from the phone.
**Every result needs the header filled in.** A number without a device, build and conditions is not a result.

## Session header (required)
| Field | Value |
|---|---|
| Tester / date / time | |
| Device | iPhone 14 Pro, storage: ___ GB, model number (Settings → General → About): ___ |
| iOS version | |
| Build | commit `_______` (device panel line "Build …"), debug / release, export date |
| Xcode version / Mac | |
| Battery % at start / charger connected? / Low Power Mode off? | |
| Room temperature / phone case on? | |
| Screen brightness / Display Zoom (Standard / Larger Text) | |
| Preset(s) tested | Thấp / Vừa / Cao |
| Players / seed (if known) | |

Result codes: **P** pass · **F** fail (open an issue with a screenshot or screen recording) · **N/A** · **?** unsure.

## A. Install and launch
| # | Check | How | Result |
|---|---|---|---|
| A1 | Installs from Xcode, icon shows (placeholder diamond) | | |
| A2 | Cold start to interactive board | Force-quit, start a stopwatch on tap, stop when the board is visible. Also record `load.engine_to_first_frame_ms` from the report (excludes iOS process launch) | ___ s / ___ ms |
| A3 | No crash in the first 5 minutes | | |
| A4 | **Internal Test build:** device panel opens (hold *Đồ họa* about 1 s, release) and shows model, iOS, GPU and build commit. **Public Release build:** a long press only cycles the preset, and the Files app shows no Empire Rush folder | | |

## B. Layout, safe area, readability
| # | Check | Result |
|---|---|---|
| B1 | Portrait: the Dynamic Island / status area does not cover the round label, player cards or cash | |
| B2 | Portrait: the home indicator does not cover the action buttons; the bottom button is fully tappable | |
| B3 | Landscape left **and** right: the island side does not cover cards or buttons; the board is fully visible | |
| B4 | Rotate during: your turn · an auction · the upgrade menu · the results screen. Layout recovers within 1 s and nothing is cut off | |
| B5 | All 28 tiles are visible and distinguishable at arm's length (30–40 cm). Owner colours can be told apart | |
| B6 | Smallest text (player names, toasts, prices) is readable without zooming. Vietnamese diacritics are correct | |
| B7 | With Settings → Display & Brightness → Display Zoom → Larger Text: still no clipping | |
| B8 | Toasts: at most 2 at a time, never over tiles, readable before they disappear | |

## C. Touch and flows
| # | Check | Result |
|---|---|---|
| C1 | ĐỔ XÚC XẮC, MUA, BỎ QUA, KẾT THÚC LƯỢT: each hit first try, 10/10 taps, thumb only, one hand | |
| C2 | No accidental double action when tapping fast (e.g. double-tap MUA buys once) | |
| C3 | Upgrade menu: list scrolls with a finger, the right item is chosen, QUAY LẠI works | |
| C4 | Auction: TRẢ buttons respond, timer and current price update, leaving the auction works | |
| C5 | Tile info: tap a tile, the info panel opens; tap elsewhere and it closes | |
| C6 | Rescue / liquidation (if it occurs): buttons readable, BÁN and PHÁ SẢN work | |
| C7 | Results sheet readable; "play again" starts a new match | |
| C8 | Short press on *Đồ họa* cycles Thấp → Vừa → Cao; long press opens the device panel and does not change the preset | |

## D. Animation, latency, stability
| # | Check | Result |
|---|---|---|
| D1 | Dice roll, token hop and building pop look smooth; note any visible hitch (when, which preset) | |
| D2 | Input latency, subjective: button reaction feels immediate (< about 100 ms)? | |
| D3 | Input latency, in-app: `input_latency_ms` p50 / p95 from the report after about 50 taps (dispatch → next frame; excludes digitizer and display) | ___ / ___ ms |
| D4 | Optional end to end: film the screen and finger with 240 fps slow motion, count frames from touch to the button's pressed state (1 frame = 4.2 ms) | ___ ms |
| D5 | Background mid-turn (swipe home) for 10 s, then return: game continues, no crash. **Expected since M2.2.1:** the turn timer shows the same remaining time as before leaving (not reset, not reduced by the background time); no timeout fires on return | |
| D6 | Same with 5 minutes in background, near the end of a turn (≤ 5 s left), during an auction, and with a phone call / Control Center / lock screen. Expected: same as D5. Then force-quit from the app switcher and reopen: a new match starts (no recovery, by design) | |
| D7 | Play again 3 times in a row: no crash; memory does not keep growing (Xcode memory gauge) | |
| D8 | Next launch after any abnormal exit: the device panel shows the "kết thúc bất thường" line. Pull the `.ips` crash log | |

## E. Performance (release build)
Run *ĐO TỰ ĐỘNG* (3 × 60 s) at each point below. Copy the numbers from `device_validation/run_*.json` → `frame_segments` (tag `bench`).

| Point | Preset | mean FPS | p50 ms | p95 ms | p99 ms | % > 33 ms | draw calls | Memory footprint (Xcode) | Thermal state |
|---|---|---|---|---|---|---|---|---|---|
| Fresh start, portrait | Thấp | | | | | | | | |
| | Vừa | | | | | | | | |
| | Cao | | | | | | | | |
| Landscape | Thấp / Vừa / Cao | | | | | | | | |
| After 15 min of play | Thấp / Vừa / Cao | | | | | | | | |
| After 30 min (full match) | Thấp / Vừa / Cao | | | | | | | | |

**Proposed pass bar** (a proposal, to be confirmed by the owner; GDD §14 says "30 FPS target on agreed baseline device at low/medium preset"):
- Thấp and Vừa: p95 ≤ 33.3 ms **and** ≤ 5% of frames over 33 ms, at every point including after 30 min.
- Cao: informational only.
- No crash, no iOS termination, battery drop recorded for a 30-minute match.

Cross-check at least one row with Instruments (Metal System Trace / Game Performance) or the Metal Performance HUD, because the in-app number is the engine's frame delta.

## F. Files to attach
- `device_validation/run_*.json`, `telemetry/session_*.json`, `logs/godot.log` (Files app → On My iPhone → Empire Rush)
- Screenshots: portrait and landscape at buy, auction, upgrade and results
- A screen recording of one full turn
- Instruments trace (`.trace`) for one benchmark run, and crash logs if any
