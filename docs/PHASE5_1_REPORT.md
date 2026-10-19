# EMPIRE RUSH: Phase 5.1 Report (Dice, Characters & New Player Experience)

## 1. Baseline, branch, commits
| | |
|---|---|
| Date | 2026-10-19 |
| Baseline | `claude/phase5-visual-overhaul` @ `b509100` (end of Phase 5, CI green) |
| Branch | **`claude/phase5-1-player-experience`** |
| Code commit of the Windows ZIP | `f4163f9` (§8) |
| Final commit | the commit that adds this report (docs and capture tools only; hash and CI in the hand-off message) |
| Git | No merge, no PR. `main` and the Phase 5 branch untouched |

| Commit | Content |
|---|---|
| `b59032c` | A: foreground dice stage |
| `c3a478a` | B: character select with illustrated portraits (cosmetic) |
| `6242dfd` | C: new player experience (coach: tips, guided tutorial, idle hint) |
| `a068bfa` | D: rules audit, quick guide, net worth on player cards |
| `683da15` | E: tiles, ownership marks, city centre |
| `e06603f`, `82e3289` | Windows package (quick guide), README, art review, Windows CI on this branch; benchmark logs |
| `f4163f9` | Fixes found on the final captures (coach card height on 540×960, decision tips first, net worth first on cards) |

**Rules and balance unchanged:**
- `git diff b509100 -- client/data/rules` is empty.
- `verify_v5.py` reports PASS.

Personas carry no rules data; the three approved rules characters are shown as roles.

**Not claimed:**
- no human playtest;
- no run on real Windows hardware (GitHub runner only);
- no FPS on any device;
- nobody listened to the sound (§6).

## 2. A. Dice
**Root cause** (scene, mesh, material, lighting, depth):
- The dice were 0.34 m cubes thrown onto the city block in the board centre, between trees and towers, at board scale.
- On a 1280×720 window a die was about 20 px.
- Tree and tower meshes were in front of the dice in depth, and the dice were lit by the board scene: green from the grass.

**Fix: `DiceStage`.**
- **Own 3D world:** the same baked 3D dice are thrown in their own 3D world (SubViewport, `own_world_3d`). The world has a felt tray in the board palette, its own camera and neutral light.
- **Board behind:** while the dice are up, the board dims (42%).
  - No board object shares that world, so nothing can cover a die (tested).
  - A die is at least 60 px wide on a 720×1280 screen (tested).
- **Motion:** a fall, two bounces and a settle (0.85 s). Then the result card **"Bạn đổ được 5 + 6 = 11"** is held 0.8 s (bots 0.5 s) before the pawn moves. A full roll presentation stays under 2.6 s (tested).
- **Skip:** a tap, Space or Enter skips to the result. Reduced motion places the dice on their faces with no throw.
- **Sound** follows the beats: throw → each bounce → landing → result chime. Two new generated sounds; earlier files are byte-identical.
- **Determinism:** the faces always come from the engine's `DiceRolled` event; the stage only changes timing.
  - **Tested on 8 seeds:** card text and die faces equal `state.last_roll`.
  - **Skipping:** the roll, the command count and the move are the same as watching.
- **Captures:** `docs/media/phase5_1/`
  - `dice_before_after_landscape.jpg`;
  - `dice_beats_portrait.jpg`: before the roll, rolling, result, pawn moving;
  - `dice_seeds.jpg`: 5 seeds, every card matches the faces shown.

## 3. B. Characters
- **Inventory before:** "Nhân vật" was the rules character (Doanh Nhân / Đầu Tư / Đàm Phán, with abilities) shown as a title and an icon. Names were fixed (Bạn / Minh / Lan / Huy), with 4 pawn colours.
- **Now:** 8 personas, each with:
  - a name;
  - an illustrated portrait (stylised bust drawn as vectors by `scripts/art/gen_portraits.py`, CC0);
  - a signature colour, a preferred pawn colour and a one-line bio.
- **Cosmetic only:** no ability, bonus or stat (tested: no gameplay key, same cash and role).
- **Setup page:**
  - portrait grid (one row of 8 in landscape), selected persona highlighted, bio;
  - name and pawn colour;
  - **"Vai trò trong trận (kỹ năng)"**: the approved rules characters, with a note that the persona is only looks;
  - line-up: a portrait per seat (you + bots).
- **In the match:**
  - bots take the other personas;
  - HUD cards show the portraits;
  - every pawn is the chosen colour and carries a portrait medallion;
  - owned tiles carry the owner's portrait seal.
- **Persistence:** the persona choice is saved in settings.
- **Checked at** 1280×720, 960×540, 786×1704 (notch) and 540×960 (`character_select.jpg`).

## 4. C. New player experience
- **Facts first:** `docs/RULES_AS_IMPLEMENTED_VI.md`
  - the match as the engine runs it, every number cited file:line;
  - 22 GDD / docs vs engine differences, with the source of truth per project rules: engine + data under decisions G1–G12 and M1.2; [REVIEW] items open.
- **Intro:** two short pages from the rules data: **"Mục tiêu của bạn"** and **"Bạn làm gì trong mỗi lượt?"**.
- **Coach (`CoachOverlay`):**
  - **Contextual tips**, shown once each, the first time the situation happens to the player:
    - roll, buy, auction, one action per turn, upgrade, ability, choice, trade, rescue;
    - event card, rent paid / received, Start, tax, district complete, a bankruptcy.
  - **Decision tips** pause the turn timer and close when the player acts.
  - Tips persist once seen, and can be switched off or shown again in Settings.
  - **Guided tutorial** on a real 2-player match: welcome → roll → buy → end turn (HUD button highlighted) → the bot's turn → closing card.
  - **Idle hint:** "Gợi ý: …" names the next step after 10 s of waiting.
- **Fixes against the engine:**
  - Start pays when passing **or landing**;
  - the old guide promised a trade button the HUD does not have;
  - the player cards now show **net worth** ("Tài sản"), which decides the winner and was visible nowhere.
- **Captures:** `coach_landscape.jpg`, `coach_portrait.jpg`.

## 5. D. Complexity audit and E. graphics
- **D. Complexity audit and quick guide:**
  - `docs/NEW_PLAYER_RULES_AUDIT.md`: 21 mechanics, turn-1 vs contextual, clarity before → after (team judgement from real screens, no user test), 12 confusion points, simplifications done and proposed (UI only), and **rule-change options kept separate, NOT applied**;
  - `docs/HUONG_DAN_NHANH.md`: a 5-minute Vietnamese guide to a whole match, also inside the Windows ZIP.
- **E. Graphics:** review against the art direction in `docs/art_direction/ART_DIRECTION.md` §Phase 5.1. Changed:
  - **Tiles:** district colour wash on the paved lot; the board no longer reads as white.
  - **Ownership:** bolder frame in the owner colour, 1.5× flag, owner portrait seal.
  - **Centre:** landmark in warm stone on a walnut / gold / marble dais with district flags; tree parks instead of bare discs.
  - **Pawns:** portrait medallions.
- **Still open:** tile buildings and trees are low-poly and repeated; the landmark mesh is still box stacks.
- **Captures:** `board_before_after_landscape.jpg`, `board_before_after_portrait.jpg`, `board_closeup_before_after.jpg`.

## 6. Tests
| Suite | Result (`f4163f9`, local) |
|---|---|
| Unit/integration | **208 / 208**, 29 files |
| Script compile | **114** scripts, 0 failed |
| UI flows | **51 / 51**, 8 files (14 new Phase 5.1 tests; the Phase 5 tutorial test was replaced by the coach tests) |
| Net e2e (chaos + concurrent) | PASS |
| Release lock (Public: no device tools or telemetry) | RELEASE LOCK OK |
| Repository readiness (incl. asset licences) | READINESS PASS |
| `verify_v5.py` (rules unchanged) | PASS |
| CI `tests` on `f4163f9` | success |

**New UI tests:**
- `test_phase51_dice.gd` (5): result = engine on 8 seeds, own world + size + dim + on screen, skip changes timing only, beat and sound order, reduced motion.
- `test_phase51_characters.gd` (3): no gameplay keys, choice reaches the HUD card, the pawn model and the medallion, bots differ, roles and cash unchanged, persistence.
- `test_phase51_coach.gd` (6): guided tutorial order on real play, tips once + persisted + timer frozen + card fits its text, rent tip + switch off, idle hint, texts from data, net worth on cards.

**Audio** (`docs/test-logs/phase5_1_audio/README.md`):
- The Master-bus mix was recorded during a roll (Dummy driver, no sound card).
- Every beat (throw, 2 bounces, landing, result chime, steps) has signal, in order. Peak 0.50, no clipping.
- **Nobody heard it.** The Windows runner has no output device either.

**Captures:**
- 1280×720, 960×540, 540×960, 786×1704 (notch), 1920×1080 High;
- the menu, setup, tutorial, dice (5 seeds) and board scenarios, from the real game (lavapipe).

## 7. Performance (lavapipe, same machine; not a phone, not Windows)
- Interleaved A/B, 3 runs each, Phase 5 `b509100` vs Phase 5.1.
- 786×1704, fixed scene, 120 frames.
- Details: `docs/test-logs/phase5_1_perf/README.md`.

| Preset | Phase 5 p50 | Phase 5.1 p50 | Change |
|---|---|---|---|
| Low | 119.3 ms | 120.9 ms | +1.3% |
| Medium | 233.3 ms | 231.7 ms | −0.7% |
| High | 495.9 ms | 516.8 ms | +4.2% |

- **Frame time:** all changes are inside the ±5% run-to-run noise.
- **Draw calls:** +18 (portraits on pawns, tiles and HUD cards; the dais).
- **Triangles:** +5.5k (Low) / +10k (Medium and High).
- **Memory:** about +4 MB video, +2 MB static.
- The dice stage renders only while dice are on screen.
- No FPS claim for any device.

## 8. Windows x64 playtest ZIP
| | |
|---|---|
| Built from | `f4163f9` (branch `claude/phase5-1-player-experience`) |
| CI run | <https://github.com/phamhoanganhtuan03121988-cmd/empire-rush/actions/runs/39266593962> (`windows-playtest` #10, all 4 jobs green) |
| Download | <https://github.com/phamhoanganhtuan03121988-cmd/empire-rush/actions/runs/39266593962/artifacts/12193512211><br>Artifact `EMPIRE_RUSH_Windows_Playtest_x64`, expires 2026-11-18, GitHub login with read access. GitHub re-zips the package folder, so check `EmpireRush.exe` against `SHA256SUMS.txt` |
| SHA-256 `EMPIRE_RUSH_Windows_Playtest_x64.zip` | `5e7c2deef8acb5b95c04929428b47f9fe74154a7fd4496e1c3cbe61d03b59237` |
| SHA-256 `EmpireRush.exe` | `9ea3b53cba39d0939eb7459b724b5f110905c4dd265744b73781378ea0cf4ef2` (also in `BUILD_INFO.txt` and `SHA256SUMS.txt`) |
| Reproducible | CI built the ZIP twice (fresh clone) and compared. A local build from a clean clone of `f4163f9` gave the same ZIP SHA-256 as the CI build log: **match** |
| Contents | `EmpireRush.exe`, `README_PLAYTEST_VI.md`, **`HUONG_DAN_NHANH.md`** (new), `BAT_DAU_O_DAY.txt`, `BUILD_INFO.txt`, `SHA256SUMS.txt`, `MO_DU_LIEU_TRAN_DAU.bat`, `forms/` |

**Cách chạy:**
1. Giải nén ZIP (Extract All).
2. Nhấp đúp `EmpireRush.exe`. Nếu SmartScreen hiện: **More info** → **Run anyway** (file chưa ký số).
3. Lần đầu nên bấm **HƯỚNG DẪN TỪNG BƯỚC**. Hoặc bấm **CHƠI** → chọn nhân vật, tên, màu, vai trò, số người → **BẮT ĐẦU**.
4. Space tung xúc xắc (bấm lần nữa để bỏ qua hoạt cảnh); Esc tạm dừng.
5. Luật tóm tắt: `HUONG_DAN_NHANH.md`.

**Windows runner checks** (run #10, Windows Server 2025):

| Check | Result |
|---|---|
| ZIP SHA-256 and every file in `SHA256SUMS.txt`, unzipped into a path with Vietnamese letters and spaces | OK |
| Full bot matches with the exported `.exe` | 4p seed 4: exit 0, 100 turns<br>4p seed 7: exit 0, 96 turns<br>3p seed 5: exit 0, 90 turns<br>2p seed 3 with reduced motion: exit 0, 80 turns<br>Every match wrote its record |
| Rendered launch, 25 s | **Default driver:** Vulkan is not available on the runner, so it fell back to D3D12 (Microsoft Basic Render Driver); still running; 2 screenshots.<br>**Forced `d3d12`:** still running, but **no screenshot within 25 s** (Phase 5's run produced 1). Startup on the software renderer is slower, so this is a limit, not a failure of the check. |
| Audio device | None on the runner (WASAPI cannot open one); the game keeps running |
| Public Release `.exe` | No telemetry or device file written: **PUBLIC RELEASE LOCK OK on Windows** |
| Project suites on the Windows editor binary | success |
| `verify` | Every Windows match replays to the same final state; privacy scan of the Windows data: success |

## 9. Limits and open items
- **No human playtest.** The audit's clarity scores are the team's judgement from screenshots. A session with new players should confirm them (`docs/PHASE4_PLAYTEST_GUIDE.md`).
- **Audio:** measured as signal on a machine without a sound card; not listened to.
- **Windows:** GitHub runner only (software rendering, no audio device).
- **Graphics:** the tile buildings, trees and landmark are still low-poly kit pieces; the persona portraits are vector illustrations (no 3D persona pawns).
- **Not done (UI, no rule change):** player trade proposals (U1), active-effects strip (U4), net-worth breakdown on the results screen (U5). See the audit.
- **Rule-change options R1–R6 are proposals only**, waiting for the owner's decision.
