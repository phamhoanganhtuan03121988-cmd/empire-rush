# EMPIRE RUSH — Game Design & Rules Spec (MVP)
Version: 1.0
Engine: Godot 4.7.2 / GDScript
Target: Android-first, PC later
Art direction: Stylized realism 3D, miniature city diorama
Match: 2–4 players, target 20–30 minutes

## 1. Product pillars
1. Strategic economy: buy properties, complete districts, upgrade buildings, trade.
2. Party moments: short event cards, limited character abilities, visible reversals.
3. Premium readable 3D: board, tokens, property upgrades and effects look cohesive but stay legible on phone.
4. Fair online play: server is authoritative for dice, turns, cash, ownership, auctions and victory.

## 2. MVP scope
- One board, 28 spaces, 7 districts, 21 properties.
- 2–4 players, private room first; matchmaking can be stubbed until private-room flow is stable.
- 2d6 dice, 1,500 Rush Credits (RC) starting cash, 200 RC when passing Start.
- Buy, rent, upgrade levels 0–3, one auction flow, trade offers, 12 event cards, 3 characters.
- Timer per turn: 45 seconds; trade offer expires after 20 seconds.
- End by last solvent player or after 25 full table rounds / 30-minute cap. At cap, compute net worth.
- Android build first; PC UI/input support should not require rewriting game rules.
- No real-money gambling, no pay-to-win stats, no player-to-player real-money market.

## 3. Turn flow
1. Server opens turn and sets deadline.
2. Current player sends RollDice command.
3. Server validates turn, rolls two dice using server RNG, emits DiceRolled.
4. Server resolves token movement and Start reward if passed.
5. Server resolves destination tile:
   - unowned property: current player may buy or pass;
   - if passed, launch one short auction (10–15 seconds);
   - owned property: charge rent according to district completion and building level;
   - event tile: server draws a card and resolves it;
   - opportunity tile: offer a small choice with disclosed risk/reward;
   - special tile: apply the configured fixed rule.
6. Player gets one strategy action: upgrade, propose trade, use character ability, or skip.
7. Server checks insolvency, elimination and victory, then advances turn.
8. If player times out, server uses safe default: pass purchase, no upgrade, no ability, end turn.

Offline mode note (M2.2.1, owner decision): in an offline match on a phone, the turn timer and the 30-minute match cap pause while the app is in the background and resume with the remaining time. Background time never counts. A force-quit offline match is not recovered. Details: `docs/RULES_M1.md` "Offline lifecycle". Online matches keep server-side timers.

## 4. Board composition (28 spaces)
- 21 property spaces, arranged in 7 districts of 3 properties each.
- 1 Start.
- 2 City Event.
- 2 Opportunity.
- 1 Rest/inspection.
- 1 Special tax/auction space.
Total = 28.
Store board layout as data, not hard-coded UI logic. Each space has stable `space_id`, `space_type`, `property_id?`, `district_id?`, and presentation metadata.

## 5. Economy rules
- All balances are integers in RC; never use floating point for currency.
- Every cash transfer is a server-side atomic transaction with an audit event.
- Property data is configuration-driven: purchase price, base rent, rent by upgrade level, upgrade cost, liquidation value, district.
- Completing all 3 properties in a district unlocks upgrades for those properties.
- Upgrade levels 0–3 for MVP. Each level maps to a configured rent multiplier/table; do not calculate from client input.
- If a player cannot pay: enter Rescue phase, allow liquidation of properties at configured liquidation value and/or a trade offer for up to 30 seconds.
- If still unable to pay, mark bankrupt and resolve assets using a fixed, documented rule. No negative cash persists.
- Final net worth = cash + configured liquidation value of owned properties + objective bonuses - outstanding debt. If no debt feature is implemented, omit the debt term and document it.

## 6. Auction
Choose exactly one implementation for MVP: ascending bids with a 12-second timer.
- Server opens auction with property id and minimum bid.
- Valid bids must be greater than current bid and affordable from current cash.
- Server resets a short anti-sniping extension only once (e.g. +3 seconds, maximum 2 extensions).
- At deadline, highest valid bidder pays atomically and receives property; if no bids, property remains unowned.
- Ignore duplicate command IDs. Do not accept bids after deadline.

## 7. Trade
- Offer can include cash and up to 3 properties per side.
- Both parties must explicitly accept. Receiver may reject or let it expire after 20 seconds.
- Validate ownership and balances again at acceptance time.
- Transfer all items atomically or transfer nothing.
- Disable free gifts in ranked mode if ranked mode is later added; MVP may keep all modes on identical trade rules.
- Rate-limit offers to prevent turn stalling.

## 8. Event cards and characters
Start with 12 cards: 4 positive, 4 negative, 4 choice-based.
Examples:
- Tourism Boom: tourist district rent +50% for one full round.
- Market Downturn: high-level buildings pay a fixed maintenance fee.
- Smart Investment: pay now for a chance of a disclosed fixed reward next round.
All randomness and event timing are server-side. Event modifiers must expire deterministically.
Start with 3 characters. Each has one bounded passive or active ability with clear cooldown/use limit. Abilities must not manipulate dice odds. Balance values live in data files.

## 9. End conditions
- Immediate win when only one non-bankrupt player remains.
- At 25 full table rounds or 30 minutes, end at a deterministic boundary and rank by net worth.
- Tie-break: (1) net worth, (2) number of completed districts, (3) cash.
- All clients receive the same MatchEnded payload and final results.

## 10. Server-authoritative contract
Client sends intent only:
`Command { protocol_version, match_id, command_id, player_id, expected_state_version, type, payload }`
Server validates identity, seat, phase, turn, deadline, payload bounds, ownership, funds and state version.
Server applies rules, increments `state_version`, persists critical event/state, then emits events/snapshot.
Required:
- Dice RNG only on server.
- No client-authored cash/property/turn/win state.
- Idempotent `command_id`.
- Snapshot on join/reconnect.
- Reject stale state versions and invalid commands.
- Server-side timers; animation timing never decides rules.
- Audit events for cash, ownership, trade and match result.

## 11. Recommended architecture
Keep client and server in separate folders/projects or repositories if runtime differs.
Godot client:
- UI, 3D board, tokens, VFX, sound, input, local presentation.
- Domain rules should be pure GDScript and testable without scene tree.
Server:
- WebSocket session gateway, match/session lifecycle, authoritative rules, timers, persistence.
- A headless Godot server is acceptable only after a short feasibility spike for hosting, reliability and security; otherwise use a suitable backend runtime and share a protocol/schema.
Database:
- accounts, match history, rating, inventory, audit events.
Do not add matchmaking complexity before private rooms and reconnect work.

## 12. Art direction
- Isometric miniature city board; stylized realism, cinematic warm/cool lighting, readable silhouettes.
- Shared scale/material/light rules across all buildings, tokens and tiles.
- Art references in `reference_art/` are direction boards, not production-ready isolated sprites.
- Use temporary primitives/placeholders until gameplay is stable. Track every external asset and its license in `docs/asset_register.csv`.
- UI must remain readable at 16:9 and tall 9:16 mobile ratios; use safe areas and scalable anchors.
- Keep camera default fixed/isometric; optional mild zoom for inspect panels.
- Low/medium/high quality settings, reduced post-processing and no mandatory screen shake.

## 13. Suggested client project structure
res://
  autoload/ (app_state.gd, network_client.gd, audio_manager.gd, scene_router.gd)
  scenes/boot/
  scenes/menus/
  scenes/lobby/
  scenes/game/board_3d.tscn
  scenes/game/property_tile.tscn
  scenes/game/player_token.tscn
  scenes/game/ui/game_hud.tscn
  scenes/game/ui/property_panel.tscn
  scenes/game/ui/trade_panel.tscn
  scenes/game/ui/event_card.tscn
  scenes/results/
  scripts/domain/ (game_state, commands, events, turn, economy, property, trade, victory rules)
  scripts/presentation/ (camera, token animation, VFX)
  scripts/ui/
  data/board_layout.tres
  data/properties/
  data/events/
  data/characters/
  data/balance/
  assets/environment/
  assets/buildings/
  assets/tokens/
  assets/materials/
  assets/vfx/
  assets/audio/
  tests/unit/
  tests/integration/
  docs/

## 14. Acceptance criteria
Gameplay:
- Unit tests cover all core rules and edge cases.
- 100 simulated matches complete without soft-lock or invalid state.
- No persistent negative cash, duplicate property ownership or duplicate transaction.
Networking:
- Four clients can complete one match.
- Duplicate commands do not duplicate effects.
- Reconnect returns a full snapshot and resumes correctly.
- No state divergence across clients in automated integration test.
Mobile:
- Main touch targets approximately 44–48 dp or larger.
- Safe areas respected; primary labels readable on target Android device.
- 30 FPS target on agreed baseline device at low/medium preset.
Quality:
- No blocker/critical bugs in release candidate.
- Match median target 22–27 minutes; P90 <=35 minutes in 4-player tests.
- Crash-free session target >=99% in closed test after sufficient sample size.
- Build, test logs and reproducible steps attached to each milestone.
