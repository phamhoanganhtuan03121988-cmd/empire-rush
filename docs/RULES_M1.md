# EMPIRE RUSH — Implemented Rules Specification (M1)

Status: **implemented in `client/scripts/domain/`, balance values are DRAFT v3** (M1.2, owner-approved trial values, not locked; see `M1_2_BALANCE_V3_REPORT.md`). Rule mechanics are unchanged since M1; only the round cap became per-player-count and the rent/upgrade numbers changed.
Baseline: `GAME_RULES_AND_GDD.md` v1.0 plus the owner's approved decisions G1–G12 (M0 approval).
This document records how every rule was made precise enough to code and test. Items marked **[REVIEW]** are interpretations the owner should confirm; the full list is in `M1_REPORT.md` §7.

All money is integer RC. Every division floors (integer division on non-negative values).

## 1. Setup
- 2–4 players, seats 0..n-1, turn order = seat order. Seat 0 starts.
- Starting cash 1,500 RC. All tokens on Start (space 0).
- The event deck (12 cards) is shuffled with the match RNG.
- Match RNG = `ErRng` (xorshift128, 32-bit) seeded per match. It is the only source of randomness: dice, card shuffles, Opportunity entry draws and Smart Investment payouts.

## 2. Board (data: `client/data/rules/board.json`)
| Index | Space | Index | Space |
|---|---|---|---|
| 0 | Start | 13–15 | District D4 |
| 1, 2, 4 | District D1 | 16 | Opportunity |
| 3 | Opportunity | 17–19 | District D5 (tourist) |
| 5–7 | District D2 (tourist) | 20 | City Event |
| 8 | City Event | 21–23 | District D6 |
| 9–11 | District D3 | 24 | Special (wealth tax) |
| 12 | Rest / Inspection | 25–27 | District D7 |

Totals: 21 properties, 7 districts × 3, 1 Start, 2 City Event, 2 Opportunity, 1 Rest, 1 Special = 28. These counts are checked when the config is loaded.

## 3. Turn flow
Phases: `AwaitRoll → (AwaitBuyDecision | Auction | AwaitChoice | Rescue)* → StrategyAction → next turn`.

1. **Turn start.** Turn timer 45 s. Expired modifiers are removed. Delayed payouts owed to this seat are resolved.
2. **RollDice.** The server rolls 2d6 and moves the token by the sum.
   - Passing **or landing on** Start pays 200 RC.
   - **G5:** doubles grant nothing extra.
3. **Landing.**
   - **Unowned property** → AwaitBuyDecision. Buy (needs cash ≥ price) or Pass. Pass starts an auction.
   - **Owned by another player** → rent (§5). If the player can't pay, Rescue (§8).
   - **Own property, Start, Rest (G2)** → nothing happens.
   - **City Event** → draw the top card (§9).
   - **Opportunity** → choice (§10).
   - **Special** → wealth tax (§7).
4. **StrategyAction (G8).** At most one of: Upgrade, ProposeTrade, UseAbility. Or EndTurn.
   - Upgrade and UseAbility end the turn immediately.
   - ProposeTrade ends the turn when the trade resolves (accepted / rejected / expired / invalidated).
5. **Turn end.** The checks run in this order:
   1. Last solvent player wins.
   2. Round cap: the last round is complete, i.e. the last active seat of that round just finished. The cap depends on how many players were seated at the start (`max_rounds_by_players`, v3: **2p 40 / 3p 30 / 4p 25**). Bankruptcies do not change it; `max_rounds` (25) is the fallback for an unlisted count.
   3. Time cap (G9): `clock − match_start ≥ 30 min`, checked **only at turn end**.
   4. Otherwise the next non-bankrupt seat starts. Wrapping past the last seat increments `round`.

### Timers and timeout defaults (GDD §3.8)
| Phase | Deadline | On timeout |
|---|---|---|
| AwaitRoll | turn timer | Server rolls for the player **[REVIEW]**. With `timeout_auto_roll = false`, the turn ends without moving instead. |
| AwaitBuyDecision | turn timer | Pass, then the property is auctioned |
| AwaitChoice | turn timer | The option's `default_option`, which config validation guarantees costs 0 |
| StrategyAction | turn timer | End turn, no action |
| Auction | 12 s (+ anti-snipe) | Close the auction |
| TradePending | 20 s (clipped to the rescue deadline when proposed during Rescue) | Trade `expired`, nothing moves |
| Rescue | 30 s | Forced settlement (§8) |

The turn timer is **paused** during Auction, TradePending and Rescue, and resumes with the time that was left.
A command is accepted only while `now < deadline`. At or after the deadline it gets `DEADLINE_PASSED`, and `advance()` applies the default.

### Offline lifecycle: background, resume and force quit (M2.2.1, offline mode only)
The rules engine reads time only through the injected `MatchClock`. In offline mode, `LocalMatch` advances that clock by frame time, filtered by `LifecycleGate` (`client/scripts/presentation/lifecycle_gate.gd`).

**Background.** When the OS suspends the app (`NOTIFICATION_APPLICATION_PAUSED`), and on phones also when the app loses focus (Control Center, a call banner, the app switcher), the match clock stops. While it is stopped:
- no deadline moves: turn, auction, trade and rescue;
- the 30-minute cap does not advance;
- bots do not act;
- no timeout can fire.

Session telemetry stops counting game time in the same way.

**Resume.** The clock continues from exactly where it stopped. The turn timer is **not reset**: the remaining time is what was left when the app left the foreground. Time spent in the background never counts.
- The first frame after resume may carry the whole suspension in its delta, and the OS may deliver that frame before or after the resume notice. Either way, it counts only the real time that has passed since resume.
- One frame (≤ about 16 ms) can be lost at that moment. That is all.

**Timeouts.** They are applied by the engine's `advance()` only when the clock reaches a deadline. A stopped clock therefore cannot produce a timeout, and a timeout that already fired is never repeated by later pause/resume cycles. This is tested: a run with background periods produces an identical event log to a run that only saw the foreground time.

**Animations / pending UI.** The presenter keeps its queue of events. If frames still run while the clock is stopped (focus loss on a phone), animations finish and buttons stay usable. Any command is validated against the stopped clock, so it is treated the same as just before the pause.

**Desktop.** Losing window focus (alt-tab) does **not** pause, so an app that stays in the foreground behaves exactly as before.

**Force quit / OS termination.** There is **no match recovery** (not designed yet). The offline match exists only in memory. If the app is force-quit from the app switcher, killed by iOS while suspended, or crashes:
- the match is lost;
- the next launch starts a new match;
- no result is recorded;
- the unfinished match writes no telemetry summary.

Internal test builds keep their periodically saved device report, and the launch marker shows `background` (killed while suspended) or `running` (died in the foreground). A save/resume design would be a separate, owner-approved feature.

**Online (M3).** None of this applies to online play. Server timers keep running; a client that returns gets a snapshot (PROTOCOL.md).

## 4. Purchase and auction (GDD §6)
- Buy: the player pays the price to the bank and becomes the owner.
- Auction: ascending bids, 12 s.
  - Every non-bankrupt player may bid, including the player who passed.
  - Minimum opening bid: `max(10, 10% of price)`. Each later bid must be at least the current bid + 10.
  - A bid must be ≤ the bidder's cash. The current high bidder cannot raise their own bid.
  - Anti-snipe: a bid placed with ≤ 3 s left adds 3 s, at most 2 times.
  - At the deadline the high bidder pays and receives the property. With no bids, the property stays unowned.
  - Duplicate command IDs have no effect. Bids after the deadline are rejected.

## 5. Rent (G6)
`rent = base_rent × pct / 100`. **Exactly one** row of `rent_multiplier_pct` applies, so nothing stacks:

| State | pct | Tier 1 (base 8) | Tier 7 (base 32) |
|---|---|---|---|
| Level 0, district incomplete | 100 | 8 | 32 |
| Level 0, district complete | 200 | 16 | 64 |
| Level 1 | 700 | 56 | 224 |
| Level 2 | 2200 | 176 | 704 |
| Level 3 | 5500 | 440 | 1,760 |

(Balance v3. M1 v2 rows were 600 / 1800 / 4500. With Tourism Boom (+50%) on the tourist district D5 at level 3, a single rent can reach 22 × 55 × 1.5 = **1,815 RC**.)

Levels 1–3 already include the value of completing the district. They never get the 2× on top.

Modifiers are applied in this order:
1. **Owner side:** event-card rent modifiers (Tourism Boom +50% on tourist districts, Blackout −50%, Billboard −25%) are **summed** into one percentage: `rent × (100 + Σpct) / 100`, floored at 0.
2. **Payer side:** one single-use "next rent −50%" discount (Negotiator ability, Charity Gala), then the Rent Insurance cap.

## 6. Upgrades
- Requirements: you own all 3 properties of the district, the level is < 3, and you can pay.
- Cost: `upgrade_cost × (100 − discount) / 100`. v3 upgrade costs by tier: 30 / 30 / 45 / 45 / 60 / 60 / 75.
  - Discount = Tycoon passive 10% + at most one single-use subsidy (50%), capped at 75%.
- Only one level per action.
- Buildings stay if the district is later broken by liquidation. Rent then uses that property's level row.

## 7. Wealth tax (Special tile, G3)
- `taxable_wealth = cash + Σ liquidation value of owned properties (buildings included)`. This is exactly the MVP net worth (§11).
- `tax = min(200, taxable_wealth × 10 / 100)`.
- Because the tax is at most 10% of what the player could raise, forced liquidation always covers it. **The wealth tax can never cause bankruptcy** (there is a test for this).
- If cash is short, the normal Rescue flow applies, with the bank as creditor.

## 8. Rescue, liquidation, bankruptcy (GDD §5; G7)
- **Trigger:** a payment larger than the player's cash (rent, tax, card). Phase Rescue, 30 s.
- **What the debtor can do in Rescue:**
  - `Liquidate` any owned properties. The bank pays the liquidation value: `tier.liquidation_value + level × upgrade_cost × 50%`. The property returns to the bank at level 0.
  - Propose **one** trade. It does not count as the turn's strategic action.
  - `DeclareBankruptcy`.
- **When the debt is paid:** as soon as cash ≥ debt, the debt is paid and the turn continues in StrategyAction.
- **Forced settlement**, at the deadline or on DeclareBankruptcy:
  - If cash + Σ liquidation values ≥ debt: the server liquidates cheapest first (ties broken by board order) until the debt is covered. The player **survives**. **[REVIEW]**
  - Otherwise **bankruptcy (G7):**
    - All properties return to the bank unowned, without proceeds.
    - The player's remaining cash goes to the creditor if that is another player, or back to the bank for tax or cards.
    - The player's modifiers and pending payouts are removed. The player is skipped from then on.
- Only the current player can ever owe money: every charge in the rules is paid by the player whose turn it is. Cash never goes negative. `_transfer` refuses that, and the invariants check it.

## 9. City Event cards (data: `events.json`, DRAFT, G10)
4 positive, 4 negative and 4 choice cards. Payment effects are always last in a card's effect list, which config validation enforces.
- **"One full round"** = `duration_rounds × (active players when created)` turns. Modifiers are removed at the start of the turn when that count is reached.
- **Smart Investment** pays its disclosed 50% chance at the start of the player's next turn, using the match RNG, so it is deterministic per seed.

## 10. Opportunity (data: `opportunities.json`, DRAFT, G4)
- The seeded RNG picks one of the 4 entries.
- Each entry has exactly 2 options with fixed, disclosed outcomes. "Collect 120 next turn" is a 100%-chance delayed payout.
- Choosing an option whose cost exceeds your cash is rejected. On timeout the free default option applies.

## 11. Net worth and ranking (GDD §5, §9; G9, G11)
- `net_worth = cash + Σ liquidation value (buildings included)`.
  - Objective bonuses are **excluded** in MVP (G11).
  - There is no debt feature, so there is no debt term.
- Ranking:
  1. Solvent players come before bankrupt players.
  2. Solvent players are ordered by net worth ↓, then completed districts ↓, then cash ↓.
  3. Bankrupt players are ordered by later bankruptcy first.
- Players equal on every key **share** a rank (competition ranking 1, 1, 3). Seat order is never used as a hidden tie-break. **[REVIEW]**
- Every client receives the same `MatchEnded` payload.

## 12. Trades (GDD §7; G8)
- Cash plus up to 3 properties per side. Properties must be **level 0** **[REVIEW]**. At least one side must be non-empty. You cannot trade with yourself or a bankrupt player.
- Terms are validated when proposed and **re-validated at acceptance**. If they no longer hold, the status is `invalidated` and nothing moves.
- An accepted trade transfers everything in one step.
- Receiver states:
  - **No response within 20 s:** `expired`.
  - **Disconnected:** treated as no response. Offline M1 has no connection concept; this keeps the outcome deterministic.
- An unresolved trade can never block the match: the deadline always resolves it.
- Rate limit: one trade per turn (it is the strategic action), plus one during Rescue.

## 13. Characters (data: `characters.json`, DRAFT, G10)
| Character | Ability | Limits |
|---|---|---|
| Tycoon | Passive: upgrades cost 10% less | — |
| Investor | Dividend Call: +15 RC per owned property, max 120 | 2 uses, 3-round cooldown, strategic action |
| Negotiator | Contract Clause: next rent paid within 2 rounds is halved | 2 uses, 3-round cooldown, strategic action |

Abilities cannot charge the player (config validation) and never reference dice (test).

## 14. Idempotency and versioning (GDD §10)
- Each accepted command is stored under `(seat, command_id)`. Resending it returns the original result with `duplicate: true` and no new events. Rejected commands are not stored, because they had no effect.
- `expected_state_version` must equal the current version, otherwise `STALE_STATE` is returned with the current version.
- Every accepted command and every timeout step bumps `state_version` by exactly 1. Event `seq` numbers are contiguous.
