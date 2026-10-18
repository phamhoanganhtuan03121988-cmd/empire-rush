# EMPIRE RUSH — Playtest checklist (M2.2)

**Current build limits (tell testers before they start):**
- Offline only: **1 person plays against 1–3 bots**. Online play or several people on one phone is not available yet (M3).
- All art is placeholder; there is no sound yet.

Game rules and balance are **not changed** based on these results. Record them and write proposals only.

## 1. For the tester (read in 1 minute)
1. Open the game. You are **"Bạn"**, seat 1. Play to the end of the match, or until you want to stop. **If you want to stop, that is useful data too: tell us when and why.**
2. Talk out loud while playing (think-aloud): "I don't know what this button does", "why did I lose money", "waiting too long"…
3. Don't ask the facilitator how to play. Try to work it out yourself; the facilitator only takes notes.
4. At the end, answer the 6 questions in §3.

## 2. For the facilitator
**Before:**
- [ ] Fill in the header: tester code (no real name), age group, how often they play board / mobile games, device, iOS, build commit (device panel), number of bots, portrait / landscape.
- [ ] Phone charged ≥ 50%, Do Not Disturb on, preset **Vừa**.
- [ ] Note the start time.

**During** (one line per event in `playtest_log_template.csv`):
| Type | Code | Example |
|---|---|---|
| Confusion | `CONFUSED` | doesn't know when to press KẾT THÚC LƯỢT; doesn't understand why rent is that amount |
| Input error | `MISTAP` | meant to tap MUA but hit BỎ QUA; button hard to reach |
| Waited too long | `WAIT` | complained or looked away while bots were playing |
| Bored / disengaged | `BORED` | picked up another phone, sighed, asked "how much longer" |
| Excited | `DELIGHT` | laughed, reacted to an event card, auction or upgrade |
| Technical issue | `BUG` | stutter, wrong layout, crash (note the time; take a screenshot if possible) |

**After:**
- [ ] Note the end time and how it ended: played to the end · stopped early (round ___, reason ___).
- [ ] Copy `telemetry/session_*.json` and `device_validation/run_*.json` (Files app → On My iPhone → Empire Rush). The telemetry file records **match length, per-turn length, human turns vs bot turns (waiting time), and animation time**.
- [ ] Do not change rules or balance because of a single session.

## 3. Six questions after the match (scale 1–5 plus one sentence)
1. How clear was it what you needed to do on each turn?
2. Was waiting for the other players' (bots') turns too long?
3. Was the text, the land and the money easy to read on the phone?
4. Were the buttons easy to tap and placed well?
5. Which moment was the most fun? Which was the most boring?
6. Would you play another match? Why or why not?

## 4. Summary after several sessions
| Metric | Source | Target / notes |
|---|---|---|
| Match length (median, P90) | telemetry `session_game_seconds` | GDD: median 22–27 min, P90 ≤ 35 min (4-player). Offline vs bots does not represent online yet |
| Human turn length (mean) | `mean_turn_s.human` | Compare against the 45 s timer |
| Wait time per round (sum of bot turns) | `turn_log` (human = false) | The main cause of `WAIT` / `BORED` |
| Animation time per turn | `mean_presentation_s_per_turn` | |
| Confusion points | `CONFUSED` count by spot | Group by screen / action |
| Input errors | `MISTAP` count by button | Compare with the device checklist C1–C2 |
| Stopped early | number of sessions, round, reason | |
