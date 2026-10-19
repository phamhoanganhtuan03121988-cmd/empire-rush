# EMPIRE RUSH — Phase 5 Report: Visual Overhaul, Onboarding & Game Feel

## 1. Baseline, branch, commits
| | |
|---|---|
| Date | 2026-10-19 |
| Engine | Godot 4.7.2-stable |
| Baseline | `claude/windows-playtest-build` @ `8e571e2` (the Windows playtest build the user played) |
| Branch | **`claude/phase5-visual-overhaul`** |
| Code commit of the Windows ZIP | `3f9798b` (§9) |
| Final commit | the commit that adds this report (docs only; hash and CI in the hand-off message) |
| Git | No merge, no PR. `main` and earlier branches untouched |

| Commit | Content |
|---|---|
| `4938c50` | Tabletop diorama, hero roll button, entry flow (title, intro, setup), guided tutorial, pause, settings, audio |
| `26e63a2` | Richer city centre, price labels; UI tests now run on a real portrait canvas (two layout bugs found and fixed) |
| `74d2437` | Win celebration, Windows package docs for the new flow, art direction update, Windows CI on this branch |
| `19f622a` | Portrait title framing fix, before/after media, benchmark A/B logs |
| `3f9798b` | Net e2e test server saves its abuse counters at once (fixes a CI race, §6) |

**Not changed:**
- Rules, starting cash, rents, upgrade costs, win conditions, balance.
  - `git diff 8e571e2 -- client/data` is empty.
  - `verify_v5.py` reports PASS.
- No new tile types, items, mortgage, win conditions or mechanics.
- The intro, how-to and tutorial text is **generated from the rules data** (`RulesGuide`), not written by hand. It cannot drift from the GDD numbers.

**Not claimed:**
- no human playtest;
- no run on real Windows hardware (only the GitHub Windows runner);
- no FPS on any device;
- no iPhone, IPA or signing.

## 2. What the user reported and what changed
| Feedback after the Windows build | Phase 5 change |
|---|---|
| The roll button does not stand out | Hero **ĐỔ XÚC XẮC** button: 132 px high, 38 pt type, gold, dice icon, slow "breathing" glow.<br>States: normal / hover (brighter skin) / pressed / disabled / **ĐANG TUNG…** while the dice roll, then the result (`3 + 2 = 5`).<br>Space or Enter also rolls. A second press while rolling sends nothing. |
| Poor contrast, flat cyan background | The full-screen cyan water is gone. The board now sits on a **night-blue felt tabletop** (shader) with a soft light pool, a contact shadow and dithering (no banding).<br>Palette: navy / night blue / ivory / gold (`docs/art_direction/ART_DIRECTION.md` §Phase 5). |
| Board hard to read, basic city | Walnut plinth with gold inlay and an ivory coping.<br>Property tiles washed in their district colour (ivory blend) with a deeper colour band.<br>**Price label on every unowned tile** (hidden once owned; the owner tint takes over).<br>Larger pawns (×1.35) in the player's chosen colour.<br>City centre: varied silhouettes, tall blocks near the camera, low ones far away, so tiles are not hidden. |
| No onboarding, tutorial or character choice | **Title** (CHƠI / HƯỚNG DẪN TỪNG BƯỚC / GIỚI THIỆU / CÀI ĐẶT) over a slowly turning diorama.<br>**Intro**: 4 skippable pages, shown once on the first CHƠI.<br>**Setup**: 2–4 players, character (with its ability text), colour, display name, live line-up of you and the bots.<br>**Guided tutorial**: 7 steps on a real 2-player match; the steps wait for real actions.<br>**Pause menu** (☰ or Esc): resume, guide, settings, main menu. Pausing stops the turn timer and the bots. |
| Audio not verified | 20 sound effects and a music loop, made for the project (§5). Separate music and SFX volume, mute, all saved. |

**HUD hierarchy:**
- top bar: round, graphics, ☰;
- player cards, 2 × 2 in landscape with more than 2 players;
- money toasts that say *why* the money changed;
- the action panel with one hero action.

**Window layout:**
- Landscape uses a 1600×900 design canvas. HUD text used to shrink to 56% on desktop.
- The HUD column is at least 560 px wide.
- An orientation change re-fits the action panel; it was 33 px off screen before.

**Settings** (title or pause), saved in `user://settings.cfg`:
- Graphics Thấp / Vừa / Cao (Low shows no felt grain);
- Reduced motion (no title orbit, no breathing glow, shorter animations);
- Music volume, SFX volume, mute.

## 3. Before / after
All shots are real game frames: lavapipe (CPU Vulkan) under Xvfb, same scenes and seeds before and after.

| File | Content |
|---|---|
| `docs/media/phase5/board_landscape_before_after.jpg` | 1280×720: buy prompt, auction, results, tile info. Left: Phase 4 `8e571e2`; right: Phase 5 |
| `docs/media/phase5/board_portrait_before_after.jpg` | 786×1704 (iPhone-size, notch insets): buy prompt, upgrade menu, results |
| `docs/media/phase5/flow_landscape.jpg` | Title, intro, setup, how-to, settings, roll ready, rolling, money toast, pause, tutorial step 1 |
| `docs/media/phase5/flow_portrait_notch.jpg` | The same ten screens in portrait with notch insets |
| `docs/media/phase5/board_1920x1080_high.jpg` | 1920×1080, High preset |

## 4. Responsive and safe-area checks
- **Portrait design canvas:** UI tests now force 720×1280.
  - **Finding:** the headless test runner used a 1280×1280 canvas, so earlier "portrait" tests ran on a square screen.
  - On the real portrait canvas the tests found two bugs, both fixed:
    - the intro card grew wider than the screen;
    - the setup card was 761 px wide.
- **Every menu page** is checked in portrait: buttons at least touch size and inside the safe area; the card inside the safe area.
- **Landscape fit** is checked at 1600×900 and 1280×720 (a short window scales the title column down).
- **Captures:**
  - 786×1704 with notch;
  - 720×1280;
  - 1280×720;
  - 1920×1080 at High.
- **Found by review of the final captures:** in portrait the tagline overlapped the board and the title buttons floated mid-screen. Wrapped labels settle late, so the column is now re-placed when it does, and the camera frames the board in the measured gap. Fixed in `19f622a`.

## 5. Audio: sources, licence, wiring
- **Source:**
  - 20 WAV effects in `client/assets/audio/sfx/`;
  - `client/assets/audio/music/theme_loop.ogg` (46.5 s loop).
  - All are synthesised by `scripts/audio/gen_audio.py` (numpy; Vorbis encoding by ffmpeg; fixed seed 2026). **CC0**, made for this project.
  - No third-party samples.
  - Register entries `AUD-001`, `AUD-002`, `GEN-014` in `docs/ASSET_REGISTER.csv`. The readiness check verifies that every asset folder is registered with a licence.
- **Signal checks:**
  - every effect peaks between 0.35 and 0.80, starts and ends at zero (no click) and has no NaN;
  - the music loop seam jump is 0.004.
- **Wiring:** `EventPresenter` emits a `cue` for each gameplay moment it presents. `AudioDirector.on_cue` plays the sound.

| Gameplay moment | Sound |
|---|---|
| Your turn starts | `your_turn` |
| Dice thrown / dice land | `dice_roll` / `dice_land` |
| Each hop of the pawn | `step` (slight pitch jitter) |
| Buy / upgrade | `buy` / `upgrade` |
| Money gained / lost (human player only) | `cash_gain` / `cash_loss` |
| Event card / opportunity choice | `card` / `choice` |
| Auction opens / a bid | `auction` / `bid` |
| Rescue (sell to the bank) / bankrupt | `rescue` / `bankrupt` |
| Match won / lost | `win` / `lose` |
| Buttons | `ui_click`, `ui_confirm`, `ui_back`, `ui_hover` (desktop hover) |

- **Mixing:**
  - buses `Music` and `SFX` under Master;
  - pool of 8 players;
  - each sound has a minimum gap and a maximum simultaneous count, so a burst of ten `upgrade` cues plays once;
  - mute mutes both buses (checked by test);
  - music is off during automated runs and benchmarks.

## 6. Tests
| Suite | Result (local, `3f9798b` code) |
|---|---|
| Unit/integration (`scripts/run_tests.sh`) | **208 / 208** passed, 29 files |
| Script compile check | **108** scripts, 0 failed |
| UI flows | **38 / 38** passed, 5 files |
| Net e2e (chaos + concurrent) | PASS |
| Release lock (Public has no device tools or telemetry; Internal keeps them) | RELEASE LOCK OK |
| Repository readiness (incl. asset licences) | READINESS PASS |
| `verify_v5.py` (rules unchanged) | PASS |

**New or rewritten UI tests:**
- `test_phase5.gd`:
  - `test_hero_roll_button_states`: hero size and type, hover differs from normal, rolling stays disabled, exactly one roll sent;
  - `test_space_key_rolls`: Space rolls once; a second Space while rolling sends nothing;
  - `test_pause_menu_pauses_the_match`: the turn timer is frozen while paused and runs again after resume; guide and settings pages work;
  - `test_tutorial_follows_real_play`: a 2-player tutorial; step 1 completes on the player's real roll, the buy step on a real purchase; the match resumes and play-again starts a normal match;
  - `test_audio_follows_gameplay`: click, dice, step and buy sounds follow real commands; burst limit; mute silences the buses.
- `test_start_menu.gd`:
  - the full entry flow is pressed through **visible** buttons only;
  - back keeps choices;
  - intro and how-to come from the rules data;
  - touch size and safe area on every page;
  - landscape fit at 1600×900 and 1280×720;
  - settings persist and apply;
  - results offer MENU.
- Already present and still green:
  - double tap sends one command;
  - reduced-motion full match;
  - full match to results;
  - money toasts explained;
  - portrait board large and uncovered;
  - minimum font sizes.
- **On the Windows runner** (§9): the exported `.exe` plays full bot matches with 2, 3 and 4 players (one with reduced motion), does a rendered launch with screenshots and runs the Public build. The project test suites also run there.

**CI:**
- `tests` on `74d2437` failed in the net e2e chaos check "flood frames were rate limited".
  - Root cause: the test server saved its stats once per second, and the scenario SIGKILLs it at 12 s. A flood in the last second before the kill was lost.
  - Fixed in `3f9798b`: the counters are saved as soon as they change. Test-tool code only; no game or server-logic change.
- `tests` on `19f622a` and later: green.

## 7. Performance (lavapipe, same machine; not a phone, not Windows)
Full method and raw files: `docs/test-logs/phase5_perf/README.md`.
- 786×1704, fixed scene, 120 frames.
- Interleaved A/B, 3 runs each, against `8e571e2`.

| Preset | Phase 4 p50 | Phase 5 p50 | Change |
|---|---|---|---|
| Low | 131.5 ms | 117.8 ms | −10% |
| Medium | 330.2 ms | 219.5 ms | −34% |
| High | 664.3 ms | 473.0 ms | −29% |

- **Faster:** the full-screen animated water shader was replaced by an unshaded tabletop.
- **Costs:**
  - draw calls +8 (118 → 126 on Medium/High);
  - triangles about +5%;
  - video memory about +6 MB;
  - static memory about +3 MB;
  - launch to first frame 1.2–1.6 s → 2.1–2.4 s. Likely causes are audio loading and the menu pages built up front; this was not measured one by one.
- These numbers come from a CPU renderer. Only the **relative** change means anything. No FPS is claimed for phones or Windows GPUs.

## 8. Limits and open items
- **No human playtest.** Readability, tutorial clarity and sound levels are judged from captures and tests, not from players.
- **Windows:** only the GitHub Windows Server runner (software rendering). There is no listening test of the audio on real speakers; tests check what is played and that mute works.
- The audio is synthesised: clean and licence-free, but simple. Recorded or composed audio is a later step.
- Launch time grew by about 0.8 s on lavapipe (§7); not investigated further.
- Character portraits are icons, not illustrated characters; there is no voice.
- The file is unsigned, so Windows SmartScreen warns (the README explains how to run it).

## 9. Windows x64 playtest ZIP
| | |
|---|---|
| Built from | `3f9798b` (branch `claude/phase5-visual-overhaul`) |
| CI run | <https://github.com/phamhoanganhtuan03121988-cmd/empire-rush/actions/runs/39233613792> (`windows-playtest` #6) |
| Download | <https://github.com/phamhoanganhtuan03121988-cmd/empire-rush/actions/runs/39233613792/artifacts/12178303456><br>Artifact `EMPIRE_RUSH_Windows_Playtest_x64`, id `12178303456`, expires after 30 days. Needs a GitHub login with read access (the repo is private). |
| SHA-256 `EmpireRush.exe` | `24da517f09198744392fccf9b82fb7e7c76de5b7e5b17d5cdfe5aa4ecf048024` (also in `BUILD_INFO.txt` and `SHA256SUMS.txt` inside the package) |
| SHA-256 `EMPIRE_RUSH_Windows_Playtest_x64.zip` | `48da06e86d3b6a8b94f780f0223128838c0370d1a4c85f35637e0635a2f5e7f4` (the file sent in the hand-off message) |
| Reproducible | CI builds the ZIP twice (fresh clone) and compares. A local build from a clean clone of `3f9798b` gave the same ZIP SHA-256 as CI (`48da06e8…`, printed in the CI build log): **match** |
| Size | ZIP 42.2 MB; `EmpireRush.exe` 114.9 MB (data embedded) |

GitHub re-zips the package folder for the download. The files are inside it with no wrapping folder, and their checksums match `SHA256SUMS.txt`.

**Cách chạy** (đầy đủ: `docs/windows/README_PLAYTEST_VI.md`, có sẵn trong gói):
1. Chuột phải file ZIP → **Extract All…** → **Extract**. Không chạy từ trong ZIP.
2. Nhấp đúp `EmpireRush.exe`. Nếu SmartScreen hiện: **More info** → **Run anyway** (file chưa ký số).
3. Bấm **CHƠI**:
   - lần đầu có 4 trang giới thiệu (có nút BỎ QUA);
   - chọn số người, nhân vật, màu, tên;
   - bấm **BẮT ĐẦU**.

   Hoặc bấm **HƯỚNG DẪN TỪNG BƯỚC** để chơi ván có hướng dẫn.
4. Tung xúc xắc: nút **ĐỔ XÚC XẮC** hoặc phím Space. Tạm dừng: ☰ hoặc Esc. Âm thanh và đồ hoạ: **CÀI ĐẶT**.
5. Phản hồi: `forms\phieu_phan_hoi.csv`. Báo lỗi: `forms\mau_bao_loi.txt`. File ghi trận: nhấp đúp `MO_DU_LIEU_TRAN_DAU.bat`.

**Windows runner checks (run #6, Windows Server 2025, all green):**
| Check | Result |
|---|---|
| ZIP SHA-256 and every file in `SHA256SUMS.txt` | checksums OK, after unzipping into a path with Vietnamese letters and spaces (`Thử nghiệm Empire Rush\bản chơi thử`) |
| Full bot matches with the exported `.exe` | 4 players seed 4: exit 0, 100 turns<br>4 players seed 7: exit 0, 96 turns<br>3 players seed 5: exit 0, 90 turns<br>2 players seed 3 with reduced motion: exit 0, 80 turns<br>Every match wrote its match record |
| Rendered launch (title screen), 25 s each | Default driver: Vulkan not available on the runner, so it fell back to Direct3D 12 (Microsoft Basic Render Driver); still running, screenshots taken<br>Forced `d3d12`: still running, screenshot taken |
| No audio device on the runner | WASAPI could not open an output device. The game kept running (no crash). Sound itself was not heard on Windows. |
| Public Release `.exe` | Telemetry and device files before = after = 8, no file written: **PUBLIC RELEASE LOCK OK on Windows**. The Internal build writes match records (above) |
| Project suites on the Windows editor binary (`windows-project`) | unit/integration, script compile and UI suites: success |
| `verify` | every match recorded on Windows replays to the same final state hash; privacy scan of the Windows data: success |

