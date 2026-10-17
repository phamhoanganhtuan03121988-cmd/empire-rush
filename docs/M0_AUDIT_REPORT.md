# M0 — Repository Audit Report

Date: 2026-10-17 · Branch: `claude/intelligent-goldberg-jhefyx`

## 1. Repository state before M0
- `phamhoanganhtuan03121988-cmd/empire-rush`: **empty**. GitHub API returned `409 Git Repository is empty`, there were no branches, and `git ls-remote` returned no refs.
- So there was no existing code, Godot version, tests, networking or backend pattern to reuse or preserve. Nothing was overwritten.
- Handoff pack contents: README, `GAME_RULES_AND_GDD.md`, `CLAUDE_TASK_PROMPT.md`, `ASSET_REGISTER.csv` (header row only) and 2 reference PNGs. There was **no separate roadmap file**: the roadmap is the milestone list in `CLAUDE_TASK_PROMPT.md` plus the "Roadmap" panel on the concept board.

### Added in M0
| Path | Purpose |
|---|---|
| `docs/GAME_RULES_AND_GDD.md`, `docs/CLAUDE_TASK_PROMPT.md` | Handoff docs, unmodified |
| `docs/handoff/HANDOFF_README.md` | Original pack README, unmodified |
| `docs/ASSET_REGISTER.csv` | Header from the pack, plus rows for the 2 reference images |
| `reference_art/*.png` | Concept boards, reference only |
| `docs/IMPLEMENTATION_PLAN.md`, `docs/PROTOCOL.md`, this file | M0 deliverables |
| `client/project.godot` | Minimal Godot 4.7.2 project (mobile renderer, canvas_items stretch, sensor orientation) |
| `client/tests/` | Dependency-free headless test runner + M0 smoke tests |
| `scripts/run_tests.sh` | Single reproducible test command with timeout and logs |
| `README.md`, `server/README.md`, `.gitignore`s | Setup docs; server placeholder pending the M3 spike |

## 2. Reference art: what it is and isn't
Both PNGs (1536×1024) are **AI-generated concept/direction boards**. They mix key art, UI mockups, flow diagrams and Vietnamese text. They are **not** production assets:
- `empire_rush_concept_board_v1.png` is RGBA, but the alpha channel is lossy noise: only ~16% of pixels are fully opaque and most sit between 128 and 249. It is not an isolated, transparent sprite. Importing it directly would give a semi-transparent, washed-out image.
- `empire_rush_gameplay_ui_logic_reference.png` is RGB with no alpha.
- None of the characters, buildings, cards or icons are cut out, and the text is partly garbled (typical image-model artefacts). Per GDD §12 these images guide style only. Production assets have to be modelled or sourced, licensed and registered.

**Style takeaways for M2:** isometric miniature-city diorama on water. Warm sunset key light with cool sky/water fill. Glossy, slightly chibi-proportioned characters on round bases. Gold/navy UI with chunky rounded buttons. Coloured district bands on tiles. A building upgrade ladder going from house → apartment → commercial centre → tower. Strong bloom on gold elements. These should be kept readable on a phone by limiting bloom and using low-detail LODs.

### Conflicts between the reference art and the GDD
In every case below, **the GDD is followed**. Each item is flagged for the owner to confirm.
| Topic | Reference art | GDD (used) |
|---|---|---|
| Starting cash | 2,000,000; prices in the hundreds of thousands | 1,500 RC, 200 RC Start reward |
| Building levels | 5 levels (house → tower), "tối đa cấp 5" | Levels 0–3 |
| Characters | 4 shown (Doanh Nhân, Nhà Đầu Tư, Chuyên Gia Đàm Phán / Du Lịch, Nhà Thám Hiểm) | 3 characters |
| Tile types | Station, Company, TV, Parking (free), Tax | 21 property + Start + 2 Event + 2 Opportunity + Rest + Special |
| Win | also "đạt mục tiêu tài sản" (wealth target) | Last solvent player, or net worth at the 25-round / 30-min cap |
| Assets | "cầm cố tài sản" (mortgage) | Liquidation only; no debt in MVP |
| Turn actions | "Sử dụng vật phẩm" (use items) | No items in MVP |
| Event duration | "trong 3 lượt" (3 turns) | "one full round"; expiry must be deterministic |

## 3. GDD gaps that block or affect M1
These need owner decisions. The proposed defaults are what M1 would implement unless told otherwise.
| # | Gap | Proposed default |
|---|---|---|
| G1 | Property prices, rents, upgrade costs and liquidation values are not given | Generate a 7-tier balance table (cheap → premium) in `data/balance/`, tuned by simulation; owner reviews it |
| G2 | Rest/inspection tile rule | Nothing happens (safe tile) |
| G3 | Special tax/auction tile rule | Pay a 10% wealth tax capped at 200 RC |
| G4 | Opportunity tile choices | Two options with disclosed fixed outcomes, drawn from a 4-entry data table |
| G5 | Doubles: extra roll? | No extra roll (not in GDD) |
| G6 | Rent multiplier per level and the district-complete bonus | Base ×2 when the district is complete at level 0; levels 1/2/3 use a configured table |
| G7 | Bankruptcy asset resolution when the creditor is a player | Properties go back to the bank unowned; the player's remaining cash goes to the creditor (bank if a tax) |
| G8 | "One strategy action" vs trade being open-ended | Exactly one of upgrade / propose trade / ability, then the turn ends; the trade response happens asynchronously within 20 s |
| G9 | 30-minute cap in simulation | Uses an injected match clock; cap checked at the end of each turn (deterministic boundary) |
| G10 | Content for the 12 event cards and 3 characters | Draft from the GDD examples + reference art in M1 data files; owner reviews the text and numbers |
| G11 | "Objective bonuses" in net worth | Omitted in MVP and documented (like debt) |
| G12 | Asset register file name: GDD says `docs/asset_register.csv`, task prompt says `docs/ASSET_REGISTER.csv` | Uses `docs/ASSET_REGISTER.csv`, the file actually supplied |

## 4. Decisions needed from the owner before M1
1. Accept or adjust the defaults G1–G12.
2. Confirm the GDD numbers over the reference-art numbers (§2 table).
3. Name the Android baseline device (for the 30 FPS target).
4. Branch strategy: the repo has no `main` yet (see the report in chat).

## 5. Verification actually performed in M0
- Downloaded the official Godot `4.7.2-stable` Linux build. `--version` printed `4.7.2.stable.official.ed1daf0bf`.
- `GODOT=<path> scripts/run_tests.sh` → headless import succeeded, then `RESULT: 3 passed, 0 failed`, exit 0.
- Negative check: a temporary deliberately failing test gave `RESULT: 3 passed, 1 failed`, exit 1. The test file was then removed.
- Not done: opening the project in the Godot editor GUI, an Android export, any network tests (no networking exists yet).
