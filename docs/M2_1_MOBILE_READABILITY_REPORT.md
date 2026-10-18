# M2.1 — Mobile Readability & Presentation Pass

Date: 2026-10-18 · Branch: `claude/m2-1-mobile-readability` (from `claude/m2-vertical-slice` @ `c8d78c2`) · Engine: Godot 4.7.2-stable, Mobile renderer
Scope: board size and readability in portrait, HUD layout, and rendering draw calls.
**Not changed:** GDD, domain rules, rules/balance data, existing tests. Commit hashes are listed in §9.
**Not claimed:** no iOS build, no iPhone 14 Pro measurement, no 30 FPS claim.

## 1. Summary
| | M2 (before) | M2.1 (after) |
|---|---|---|
| Tile ring share of the portrait screen (786×1704, iPhone 14 Pro aspect) | 21.5% | **31.1%** |
| Ring width / height (% of viewport) | 77.7% / 27.6% | **88.3% / 35.2%** |
| Smallest tile edge on screen | 38.4 px | **45.8 px** (+19%) |
| Landscape (1704×786): ring share / smallest tile | 17.3% / 31.4 px | **23.4% / 37.5 px** |
| HUD panels or toasts covering board tiles (buy / upgrade / results) | Yes: toasts on the top corner, upgrade menu on Start, results over the board | **No**, asserted by a UI test |
| Smallest information text | 15–16 px (≈ 8 pt) | **20 px (≈ 11 pt)**, asserted by a UI test |
| 3D scene draw calls, mid-game (viewport counter) | 267 | **37** (−86%) |
| Shadow-pass draw calls, high preset | 260 | **30** |
| Total draw calls incl. 2D HUD: low / medium / high | 301 / 561 / 561 | **71 / 101 / 101** |
| Tests (`scripts/run_tests.sh`) | 169 domain / 59 compile / 9 UI | **169 / 62 / 12, all pass** |

All numbers come from the deterministic capture script `client/tests/capture/capture_scenarios.gd`. It sets up the same mid-game situation (14 owned lots, 9 buildings, buy prompt → auction → upgrade menu → results) and was run on both code bases at the same resolutions. Raw output: `docs/test-logs/m2_1/capture_metrics_{before,after}.txt`.

## 2. Priority 1: board in portrait (camera options)
Four camera and framing options were captured with the same scenario, the same resolution and the M2 HUD. Image: `docs/media/m2_1/camera_options_A_B_C_D.jpg`.

| Option | Yaw / pitch | What must stay in frame | Ring share | Smallest tile | Ring height |
|---|---|---|---|---|---|
| A (M2) | 45° / 50° | Whole quay skirt (±4.6 m) + 1.6 m height | 21.5% | 38.5 px | 27.7% |
| **B (chosen)** | **45° / 58°** | **Tile ring (±4.05 m) + 1.3 m towers** | **30.8%** | **45.7 px** | **34.9%** |
| C | 30° / 56° | Tile ring | 30.0% | 43.5 px | 34.0% |
| D | 0° / 56° (front-on) | Tile ring | 25.4% | 47.5 px | 29.4% |

**Why B:**
- **Biggest board.** In portrait the board diamond is limited by screen width, so the main gain comes from framing the tiles instead of the decorative quay skirt, which may now crop at the corners. A steeper pitch also uses more of the free height.
- **Keeps the isometric look.** B stays a 45° isometric diamond (the art direction) and gives the largest board area.
- **Why not C or D.** C (30°) is slightly smaller and starts to look skewed. D has marginally bigger tiles (47.5 vs 45.7 px) but loses the isometric miniature-city read, gives a smaller total board, and puts the near edge right against the action panel.
- **No tile ever crops.** A UI test asserts the whole tile ring stays on screen and inside the free area.
- Framing is solved numerically: the projected board points are fitted into the area between the HUD bands. So it adapts to the safe area (Dynamic Island emulation `--notch`) and to aspect ratio.

## 3. Priority 2: HUD layout
| Change | Why |
|---|---|
| Removed the separate "Lượt của…" line from the top panel. The active player is the highlighted card, and the action panel title says whose turn it is. | Saves about 40 px of height |
| Player cards: name 22 px, character **short** name 20 px (Doanh Nhân / Đầu Tư / Đàm Phán), cash 30 px | No text below 20 px (≈ 11 pt). Long character names no longer truncate. |
| **Reserved toast band** (max 2 toasts, single line, ellipsis) right under the top panel | Toasts can no longer cover tiles; the camera frames the board below the band |
| Action buttons in a grid: 2 side by side (Mua / Bỏ qua, Đồng ý / Từ chối, bids), 3 in a row (Nâng cấp / Kỹ năng / Kết thúc lượt), longer lists in 2 columns | Shorter panel; all buttons still ≥ 88 px tall (≈ 48 pt) |
| Long lists (upgrades, liquidation) scroll by touch inside the panel, capped to the reserved band (23.5% of height); the panel's fixed parts are measured, not guessed | The 6-district upgrade menu covered the Start tile; a new test caught it and it is fixed |
| Results shown as a **bottom sheet** in the action-panel slot, not centred over the board | The final board stays visible under the results |
| Special tiles show large glyphs (! Sự kiện, ? Cơ hội, % Thuế) instead of tiny two-line words; "XUẤT PHÁT" / "NGHỈ" drawn larger | Tile labels were unreadable at phone size. Tap a tile for full details. |
| Owned tiles get an owner-colour **tint over the whole tile**, plus the existing ring and flag | Ownership is readable at a glance |
| Quality toggle is 82 px tall (≈ 44 pt) | Meets Apple's minimum for a secondary control |
| Landscape | Same two-column layout. Toasts sit in the right column, the results sheet replaces the action panel. Board is bigger (§1). |

Before/after images, same resolution and scenario, M2 on the left and M2.1 on the right:
- `docs/media/m2_1/portrait_01_buy_prompt_before_after.jpg`: buy prompt + 2 toasts
- `docs/media/m2_1/portrait_02_auction_before_after.jpg`
- `docs/media/m2_1/portrait_03_upgrade_menu_before_after.jpg`
- `docs/media/m2_1/portrait_04_results_before_after.jpg`
- `docs/media/m2_1/landscape_buy_before_after.jpg`
- `docs/media/m2_1/after_portrait_{low,medium,high}_buy.jpg`: the three quality presets

## 4. Priority 3: rendering
**Baseline investigation** (mid-game scenario, M2 code). Every primitive was its own `MeshInstance3D`. Approximate objects in view:

| Source | Objects |
|---|---|
| Static board (quay, tiles, district bands, centre city blocks / roofs / trees) | ~117 |
| Buildings (each window strip a separate mesh) | ~88 |
| Owner flags | 42 |
| Pawns | 12 |
| Dice (when visible) | 44 |
| Labels, water, highlight | ~9 |

That is 267 scene draw calls, doubled by the shadow pass on medium and high.

**Change:** `MeshMerger` (`client/scripts/presentation/mesh_merger.gd`) merges primitives into one `ArrayMesh` per logical object, using vertex colours and shared materials:
- the whole static board is **one** mesh;
- each owner mark (tint + ring + flag) is one mesh;
- each building is one mesh, with windows on an emissive vertex-colour shader (`vertex_glow.gdshader`);
- each pawn and each die is one mesh.

Animations are unchanged: flags still pop, buildings still grow, pawns still hop and squash, dice still tumble. `DiceView.top_value()` still reads the die node, and the UI test confirms the dice faces match the engine roll.

**Measured** with the same scenario at 786×1704. Viewport counters for the 3D scene; the totals include the 2D HUD:

| Preset | Scene draw calls before → after | Shadow draw calls before → after | Total incl. HUD before → after | Primitives (total) |
|---|---|---|---|---|
| Thấp (low) | 267 → **37** | 0 → 0 | 301 → **71** | 17,968 → 18,136 |
| Vừa (medium) | 267 → **37** | 260 → **30** | 561 → **101** | 31,274 → 31,610 |
| Cao (high) | 267 → **37** | 260 → **30** | 561 → **101** | 36,578 → 40,502 |

Before = the same new camera and HUD with unmerged meshes ("pre-merge"), so only the rendering differs. The 3D-only before/after was also measured on the untouched M2 commit: 267 / 260 → 37 / 30. Totals include about 34 HUD canvas draw calls; the rest is 3D.

**Visual comparison** (same scenario and resolution, pre-merge vs merged; `docs/media/m2_1/rendering_merge_before_after_diff.png` shows before, after, and |diff| ×4):
- Mean absolute pixel difference: 3.0–3.2 / 255.
- Pixels with a difference above 30: 1.1–1.2% (low / medium / high).
- The differences are the **intended** owner tint on owned tiles, a slightly different glow on gold caps and windows (emission now comes from a vertex-colour shader), and water noise (animated shader). No geometry or animation regressions are visible.

**Tried and reverted:** collapsing every merged mesh to 2 material buckets (std + glow, glow strength carried in vertex alpha). Visible surfaces fell from 110 to 61, but the measured scene draw calls stayed at **37**: in this renderer and counter, draw calls track objects. Visual fidelity also dropped slightly (unified roughness). It was reverted, following "optimize only with a measured gain".

**What these numbers are not.**
- They come from Mesa lavapipe (software Vulkan) in a Linux container.
- Draw-call and primitive counts are renderer-side and hardware-independent proxies.
- FPS on lavapipe (1–11) says **nothing** about the iPhone 14 Pro and is not reported as performance.

**Remaining rendering work:**
- Owner marks and buildings are still one object each (14 + 9 in the scenario). They could be batched further with a MultiMesh per mark type, once the art is final.
- Each Label3D is still its own draw call (7 glyph tiles).
- Shadows could be limited to buildings and tokens on medium.

## 5. Tests actually run
`GODOT=/opt/godot/Godot_v4.7.2-stable_linux.x86_64 TEST_TIMEOUT_SECS=1800 scripts/run_tests.sh` → **exit 0** (`docs/test-logs/m2_1/m2_1_tests.txt`):

| Stage | Result |
|---|---|
| Domain + integration | **169 passed, 0 failed.** Unchanged from M2; no domain test modified. |
| Compile check | **62 scripts, 0 failed** |
| UI flows (real scene, real HUD buttons) | **12 passed, 0 failed:** the 9 M2 flows + 3 new |

The 9 M2 flows cover roll and dice, buy, auction, rent, the upgrade sub-menu, end turn, touch size and safe area, landscape, and a full autopilot match with the results screen. None was modified.

**New UI tests** (`client/tests/ui/test_ui_readability.gd`):
1. **Board large and uncovered, iPhone 14 Pro aspect, notch emulated:**
   - the ring spans ≥ 80% of the width;
   - the whole ring is on screen;
   - the top panel, toast band, action panel and results sheet do not intersect the board in the buy prompt, the 6-district upgrade menu, and the results state.
2. **Information text ≥ 20 px:** every visible label and button in the HUD (decorative "placeholder" tag excluded).
3. **Owner mark** appears as a single merged mesh after buying through the UI.

**Mutation checks** (scratch copies):
- Reverting the camera to the M2 framing fails test 1 ("board ring spans ≥ 80% of the width (78%)").
- Before the scroll fix, test 1 failed on the upgrade menu (action panel over the board by 5 px), which is what found the real defect.

## 6. Video
See §9.1. A 30 s clip at 786×1704 (notch emulation, medium preset), recorded with Godot Movie Maker at a fixed 30 fps from the committed code (`--players=4 --seed=7 --autoplay --notch`). It shows one full round: the human seat's turn (roll → move → buy Mũi Phá for 90 RC → end) and then the three bot turns, ending at the start of round 2. With `--autoplay` the human seat is played by the bot policy, so the clip shows the board, toasts, pawn and dice animation and cash updates, but not finger taps on the buttons. Those are covered by the capture screenshots and the UI tests.

## 7. Limits that remain
- **All art is placeholder** (primitives, Godot default font). Not replaced by design.
- **Board still limited by screen width in portrait.** The ring uses 88% of the width; further growth needs a different board presentation, pinch-zoom, or a narrower board ring. That is an art-direction decision.
- **The quay skirt now crops at the left and right corners in portrait.** Tiles never crop (tested).
- **Long lists scroll** inside the panel. Scrolling is a standard touch pattern, but it is less discoverable than a full list; a playtest should confirm.
- Toasts are limited to 2 lines; there is still no event-history panel.
- No trade-proposal UI, no sound, no reduced-motion setting (unchanged from M2).
- **Not done:** iOS build, device FPS and thermals, real Dynamic Island check. Still needs macOS + Xcode (M2 report §9).

## 8. Recommended next steps
1. **Real-device check on the iPhone 14 Pro:**
   - build via Xcode;
   - verify the safe area, readability at arm's length and touch comfort;
   - measure FPS and draw calls per preset with Instruments.
2. **First human playtest** with `--telemetry`, to get real turn times (still unmeasured).
3. **Art direction decision on board presentation** (current 45° diamond vs alternatives) before asset production. Then start production assets for tiles, buildings and pawns, batched via MultiMesh where they repeat.
4. **Small UX follow-ups:** event history drawer, settings (sound, reduced motion, language), trade proposal UI.
5. Keep v3 balance as the baseline. Tourism Boom and the 1,815 RC peak rent remain flagged for playtest.

## 9. Branch, commits and files
- Branch: `claude/m2-1-mobile-readability`.
- Commits (from `c8d78c2`): `cc7d147` (readability + HUD + merged meshes + tests + capture script), followed by the final commit with this report, media, logs and the 3D draw-call counters in the capture script. Hashes are reported in the hand-off message.

**Added:**
- `client/scripts/presentation/mesh_merger.gd`, `client/scripts/presentation/vertex_glow.gdshader`
- `client/tests/ui/test_ui_readability.gd`
- `client/tests/capture/capture_scenarios.gd`
- `docs/media/m2_1/*`, `docs/test-logs/m2_1/*`, this report

**Modified:**
- `client/scripts/presentation/{board_view,camera_rig,token_view,dice_view}.gd`
- `client/scripts/ui/{game_hud,ui_text,ui_theme}.gd`
- `client/scripts/main.gd`: camera override flags for experiments
- `client/data/presentation/{board_theme,strings_vi}.json`: glyphs, short names

**Unchanged:** `client/scripts/domain/*`, `client/data/rules/*`, GDD, handoff docs, all pre-existing tests.

### 9.1 Video file
`docs/media/m2_1/one_turn_786x1704.mp4`
