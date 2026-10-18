# EMPIRE RUSH — Art Direction & Design System (M2.3, updated in Phase 2)

**Style:** premium stylized realism 3D — a miniature city board game.
- An architectural scale model on a stone quay in a harbour.
- Believable materials, selective detail, warm late-afternoon light.
- **Gameplay information always wins over decoration.**

The concept boards in `reference_art/` are direction only (see the asset register: reference_only). Nothing is traced or imported from them.

This document is implemented in code and assets:

| What | Where |
|---|---|
| UI tokens | `client/scripts/ui/ui_theme.gd` |
| 3D kit | `client/tools/asset_forge/` → `client/assets/` |
| Board assembly | `client/scripts/presentation/board_view.gd` |
| Guards | tests in `client/tests/unit/test_production_kit.gd` and `client/tests/ui/` |

## 1. Pillars
1. **Readable first.** Every tile reads on a 393 pt-wide phone in portrait:
   - owner;
   - district;
   - building level;
   - special-tile type;
   - what the player can do now.
   Decoration may never cover a tile or a HUD panel (UI tests assert this).
2. **Miniature, not toy.**
   - Real-world proportions: one tile = 1 m in the scene ≈ a city block. Buildings L1 0.3–0.45 m, L2 0.6–0.8 m, L3 1.0–1.3 m.
   - Materials with texture and normal detail. No flat plastic colours.
3. **One light, one palette.**
   - One warm key light, one cool fill and sky ambient.
   - All assets share one material library, so they sit in the same world.
4. **Cheap on phones.**
   - The static board is two merged meshes: flat ground (does not cast shadows) and props (Phase 2).
   - Buildings are one mesh each, with shared materials.
   - No SSAO in the Mobile renderer: baked vertex AO and contact-shadow decals replace it.

## 2. Colour tokens
### HUD (`UiTheme`)
| Token | Hex | Use |
|---|---|---|
| NAVY | `#121a2e` | panel base (glass panels at 94% opacity, 9-slice) |
| NAVY_SOFT | `#1e2a48` | active / raised surfaces |
| GOLD | `#f5b83d` | primary actions, money, titles, round counter |
| INK | `#1d1606` | text and icons on gold |
| TEXT | `#f6f1e7` | primary text on navy |
| TEXT_MUTED | TEXT at 72% | secondary text (character, rent table) |
| BLUE | `#3f74de` | secondary actions (pass, back, end turn) |
| RED | `#e0574c` | danger (bankruptcy, reject), timer < 10 s |
| GREEN | `#5fd38a` | gains, upgrade markers |
| AMBER | `#ffcf5a` | auctions, warnings |

### Players (seat colours, also pawn enamel)
| Seat | Colour | Pawn head |
|---|---|---|
| 0 | `#e63946` red | crown |
| 1 | `#2f80ed` blue | top hat |
| 2 | `#27ae60` green | rook |
| 3 | `#f2994a` orange | gem |

Seats differ by **shape and colour**, so colour-blind players can still tell pawns apart.

### Districts (band + building accents)

| District | Colour | Architectural family |
|---|---|---|
| D1 Chợ Cũ | `#c8643c` | old market shophouses, terracotta roofs |
| D2 Cảng Biển | `#2a9d8f` | harbour warehouses, containers, lighthouse |
| D3 Ven Sông | `#6aa84f` | riverside cottages, terraced green condo |
| D4 Phố Hoa | `#e07aa5` | flower kiosk, boutique, glass-dome mall |
| D5 Khu Nghỉ Dưỡng | `#f2b134` | bungalow, resort wing with pool, curved hotel |
| D6 Trung Tâm Tài Chính | `#3d6fd6` | glass offices, setback tower, skyscraper |
| D7 Đỉnh Thượng Lưu | `#8e44ad` | villa, neoclassical mansion, gold-crowned tower |

Special tiles use their colour as a light tint on the marble slab plus a dark icon:
- Start: arrow;
- Event: card "!";
- Opportunity: "?" diamond;
- Rest: coffee cup;
- Tax: percent coin.

## 3. Typography
- **Typeface:** Be Vietnam Pro (SIL OFL 1.1, `client/assets/fonts`). Full Vietnamese diacritics (tested).
- **Weights:**
  - Medium: body;
  - Bold: buttons, names;
  - ExtraBold: titles, money, ranks.
- **Scale** (px at the 720 px design width; 1 pt ≈ 1.83 px):

| Style | Size | Use |
|---|---|---|
| Caption | 20 | minimum for information (≈ 11 pt), enforced by a UI test |
| Body | 24 | |
| Label | 26 | |
| Button | 28 (26 / 22 in 2 / 3-column grids) | |
| Title / number | 30 | |

- Money is always `<number> RC` with a gold coin icon. It is never shown before its animation (EventPresenter).

## 4. Icons
- 29 single-colour SVGs in `client/assets/ui/icons`, on a 64 px grid with a solid silhouette.
- Interior details are **mask cut-outs**, so an icon stays readable in any tint (dark on gold, white on blue).
- Every action button carries an icon (`GameHud.ACTION_ICONS`):
  - dice: roll;
  - coin: buy;
  - gavel: pass / auction / bid;
  - house: upgrade;
  - bolt: ability;
  - flag: end turn;
  - check / close: trade;
  - bank-crossed: bankruptcy.

## 5. Spacing, shape, depth
- **Spacing unit:** 10 px.
  - Panel padding: 20 px.
  - Screen margin: 14 px inside the safe area.
- **Radii:**
  - Buttons: 16 px.
  - Panels: 24 px.
  - Badges: round.
- **Buttons** are 9-slice skins (2x) with:
  - a vertical gradient;
  - a 1 px top highlight;
  - a 6 px bottom lip.
  The pressed state drops the lip and shifts content down by 4 px. Disabled is slate at 75% text.
- **Touch targets:** at least 88 px (≈ 48 pt). The secondary graphics button is 82 px (≈ 44 pt, Apple minimum).
- **Elevation:**
  - Panels have a soft shadow.
  - The active player card adds a 10 px glow in the seat colour.
  - Toasts have a 6 px colour bar by message type.

## 6. Components
| Component | Rule |
|---|---|
| Top bar | Round chip (clock icon), build tag (decorative), graphics button, 4 player cards, turn timer (gold, red under 10 s) |
| Player card | Avatar badge (character emblem on the seat colour), name (seat colour), character, coin + cash. The active card has a border + glow; bankrupt cards are at 45% |
| Action panel | Icon + title (gold), muted body, button grid: 1 column for one action, side by side for 2–3, 2 columns above that. Long lists scroll inside the panel. Labels break only at explicit line breaks: name on line 1, "→ cấp N · price" on line 2, joined with non-breaking spaces (UI test measures every line) |
| Landscape layout (Phase 2) | Board on the left at full height. Player bar, toasts and action panel share the right column (46% of the width) |
| Toast | At most 2, under the top bar, never over tiles. Icon + text, 3.2 s, fade |
| Info modal | Gold-framed glass panel, centred, closes with QUAY LẠI |
| Results sheet | Bottom sheet in portrait (2-column ranking with medal badges), right column in landscape. The board stays visible |
| Device panel | Internal builds only (BuildFlavor) |

## 7. 3D materials and light
- **Material library** (`client/assets/materials`):
  - Vertex-colour tinted, so one material serves every district.
  - World-space triplanar mapping, so there are no UV seams on kit pieces.
  - Material list:
    - plaster;
    - concrete;
    - paving;
    - stone wall;
    - asphalt;
    - grass;
    - roof tile;
    - wood;
    - foliage;
    - marble;
    - glass;
    - metal;
    - gold;
    - fabric;
    - paint;
    - enamel (clear-coat);
    - window glow (emissive, 0.85);
    - contact shadow (unshaded alpha).
- **Planar variants (Phase 2):** marble, paving, asphalt and grass also exist as `*_planar` materials. They use the same textures with world-XZ UVs instead of triplanar mapping, and are used only by flat ground pieces. Triplanar is wasted work on a surface that only faces up.
- **Textures:** 512 px tileable detail and normal maps from fixed seeds, VRAM-compressed with mipmaps. The **Low preset turns the triplanar detail and normal maps off** (vertex colour only) to save fill rate on weak GPUs. Anisotropic filtering is used on **High only**; Low and Medium use trilinear mipmaps.
- **Preset summary (Phase 2):**

| | Low | Medium | High |
|---|---|---|---|
| Shadows | off | orthogonal | 2 splits |
| Detail/normal maps | off | on | on |
| Texture filter | trilinear | trilinear | anisotropic |
| Water | `water_lite` (unshaded, 1 ripple + foam) | full | full |

  Benchmarks: `docs/test-logs/phase2_perf/`.
- **Light:**
  - Key: sun `#ffe2b8` at 1.45, −48° pitch, shadows on medium and high.
  - Fill: `#9cc3ff` at 0.35.
  - Ambient: sky at 0.8.
  - Filmic tonemap, soft glow (threshold 1.0, so only lit windows and gold bloom).
- **Depth cues without SSAO:**
  - Baked ground AO on every model (bottom 12–14 cm darkened to 68–70%).
  - Contact-shadow quads under buildings and props.
- **Water:** depth tint, layered ripples that fade with distance (no moiré), foam hugging the quay, fresnel sky tint. Low uses `water_lite.gdshader`: same colours and foam, no lighting, fresnel or normal map.
- **Geometry budget (Phase 2):** windows are 3 quads (pane + sill top + sill front; 6 triangles). Small props use 6–8 segments. Board scene: about 51k triangles visible, 44k in the shadow pass.

## 8. Readability rules for 3D at phone size
- **Ownership** = a 5 cm frame in the owner colour around the slab + a flag on the lot corner. The tile and building keep their materials; identity colour never floods the tile.
- **District** = a coloured band with a gold trim on the street edge of the tile.
- **Level** = building mass. Every district's L3 is at least 0.35 m taller than its L1 (tested). Silhouettes differ per district (tested: at least 6 distinct L3 heights).
- **State markers** float over tiles (billboards, always on top):
  - amber gavel: under auction;
  - green arrow: you can upgrade this now.
- **Active tile:** a warm emissive frame.
- **Pawns (Phase 2):** each pawn stands on a ring in its seat colour. Other players' rings are at 55% opacity. The active player's ring is opaque and slightly larger, and breathes (static with reduced motion). From the portrait camera a pawn is about 13 px wide; the ring carries the "whose pawn" information.
- **Animation budget:**
  - Token hop 0.16 s per tile.
  - Building pop 0.5 s.
  - Bursts and dust under 1 s.
  - `--reduced-motion` disables particles and halves hop time.
  - Nothing waits on an effect.

## 9. Asset rules
- **Every asset is generated or authored in the repo, or it comes from a licensed source.** Each one is listed in `docs/ASSET_REGISTER.csv` with its source and licence.
- **Generated assets are deterministic.** Running `scripts/forge_assets.sh` produces byte-identical files.
- **Budgets** (tested):
  - Building: ≤ 8,000 triangles, footprint ≤ 0.6 m, height ≤ 1.32 m.
  - Materials: from the library only.
- **2D assets** are SVG icons and 9-slice skins. No full-screen raster HUD art. Layouts stay responsive.

## 10. What is still placeholder-grade
- **Buildings and props are procedural** (boxes, lathes, cylinders) with real materials. There is no sculpted or hand-modelled detail, LOD or texture painting yet. They are the vertical-slice set that fixes scale, palette, silhouettes and budgets for a 3D artist.
- **Character portraits are emblems,** not illustrated characters.
- **No audio.**
- **Not yet built:** pre-match setup screen, character selection screen, trade proposal UI. The current flow starts a match directly.
