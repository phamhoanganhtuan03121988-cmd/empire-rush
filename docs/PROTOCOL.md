# EMPIRE RUSH — Network Protocol (draft v1)

Status: **M1: command/event vocabulary implemented by the offline rules engine** (`client/scripts/domain/game_engine.gd`, `er_command.gd`). The transport is not implemented yet; it is implemented and frozen in M3.
The baseline is GDD §10. When this document and the GDD disagree, the GDD wins until this document is updated.

## 1. Principles
- The client sends **intent only**. The server owns dice, cash, ownership, turn order, timers, the auction winner, bankruptcy and victory.
- Every state change goes through one server pipeline: validate → apply → `state_version += 1` → persist critical events → broadcast.
- Rules code (`scripts/domain/`) does not know about the transport. The gateway converts JSON frames into domain commands and back.
- Animation never feeds back into rules. The client may delay *showing* an event, but it never decides one.

## 2. Transport and encoding
- WebSocket over TLS (`wss://`). One socket per client session.
- JSON text frames, UTF-8. All currency is an **integer** RC value. All timestamps are integer ms since the Unix epoch, in server time.
- Max frame 16 KiB. Bigger frames are rejected with `PAYLOAD_TOO_LARGE`.
- `protocol_version` is an integer. Version 1 = this document. The server rejects an unsupported major version with `PROTOCOL_UNSUPPORTED` and sends back the version it supports.

## 3. Client → server: `Command`
```json
{
  "protocol_version": 1,
  "match_id": "m_7f3c...",
  "command_id": "c_01J...",          // client-generated, unique per player (ULID/UUIDv7)
  "player_id": "p_...",              // must match the authenticated session; never trusted alone
  "expected_state_version": 42,
  "type": "RollDice",
  "payload": {}
}
```

### Command types (MVP)
| type | payload | legal when |
|---|---|---|
| `JoinRoom` | `{room_code}` | lobby |
| `SetReady` | `{ready: bool, character_id}` | lobby |
| `StartMatch` | `{}` | lobby, host, 2–4 seated & ready |
| `RollDice` | `{}` | own turn, phase `AwaitRoll` |
| `BuyProperty` | `{property_id}` | own turn, phase `AwaitBuyDecision` |
| `PassProperty` | `{property_id}` | own turn, phase `AwaitBuyDecision` |
| `PlaceBid` | `{auction_id, amount}` | phase `Auction`, before deadline, amount ≥ min bid (first) or current + increment, amount ≤ own cash, not already high bidder |
| `ChooseOption` | `{choice_id, option_id}` | pending Opportunity / choice-card prompt for this player; option cost ≤ cash |
| `Upgrade` | `{property_id}` | own turn, phase `StrategyAction`, district complete, level < 3, funds |
| `ProposeTrade` | `{to_player_id, give:{cash, property_ids[≤3]}, take:{cash, property_ids[≤3]}}` | own turn `StrategyAction` or `Rescue`, rate-limited |
| `RespondTrade` | `{trade_id, accept: bool}` | addressed player, before expiry |
| `UseAbility` | `{ability_id, target?}` | own turn `StrategyAction`, cooldown/use limit available |
| `Liquidate` | `{property_ids[]}` | own `Rescue` phase |
| `DeclareBankruptcy` | `{}` | own `Rescue` phase; triggers forced settlement (RULES_M1 §8) |
| `EndTurn` | `{}` | own turn, phase `StrategyAction` |
| `RequestSnapshot` | `{}` | any time (rate-limited) |
| `Ping` | `{client_time}` | any time |

## 4. Server validation order
Rejects stop at the first failure. The rejected command has no side effects and does not change `state_version`.
1. Frame size, JSON shape, `protocol_version`.
2. Session auth → `player_id` matches the session, and the player is seated in `match_id`.
3. **Idempotency:** if `(match_id, player_id, command_id)` was **accepted** before, resend the original result with `duplicate: true` and no events. Do not apply it again. Rejected commands are not stored, because they changed nothing, so a client may retry the same id.
4. Rate limit (per player, per type).
5. `expected_state_version == state_version`, otherwise `STALE_STATE` plus the current `state_version`.
6. Deadline: the command is accepted only while `server_now < deadline`. Then the phase / turn check.
7. Payload bounds (ids exist, counts ≤ limits, integer amounts ≥ 0).
8. Domain rule check (ownership, funds, district completion, cooldowns).

## 5. Server → client messages
Every server message has `{protocol_version, match_id, state_version, server_time}`.

### `CommandResult`
`{command_id, ok: bool, error?: {code, message, current_state_version?}}`. Sent only to the client that sent the command.

### `Event` (broadcast, ordered)
`{seq, state_version, type, data}`. `seq` increases by exactly 1 per match. A gap in `seq` means the client must call `RequestSnapshot`.

| type | data (summary) |
|---|---|
| `MatchStarted` | seats, characters, board_config_hash, balance_config_hash, seed_commitment |
| `TurnStarted` | player_id, round, deadline |
| `DiceRolled` | player_id, d1, d2 |
| `TokenMoved` | player_id, from, to, passed_start |
| `CashChanged` | tx_id, from?, to?, amount, reason, balances_after |
| `PropertyBought` / `PropertyTransferred` | property_id, from?, to, price, tx_id |
| `RentCharged` | payer, owner, property_id, amount, tx_id |
| `AuctionOpened` / `BidPlaced` / `AuctionExtended` / `AuctionClosed` | auction_id, property_id, min_bid, current_bid, leader, deadline, winner? |
| `UpgradeBuilt` | property_id, level, cost, tx_id |
| `EventCardDrawn` / `ModifierAdded` / `ModifierExpired` | card_id, modifier_id, expires_at_round/turn |
| `ChoicePrompted` / `ChoiceResolved` | choice_id, options, deadline |
| `TradeProposed` / `TradeResolved` | trade_id, terms, status (`accepted`, `rejected`, `expired`, `invalidated`) |
| `AbilityUsed` | player_id, ability_id, effect |
| `RescueStarted` / `PlayerBankrupt` | player_id, debt, deadline / asset_resolution |
| `TurnEnded` | seat, reason (`ended`, `action`, `timeout`, `bankrupt`) |
| `DeadlineExpired` | phase, seat (a server timeout default follows) |
| `PropertyPassed` / `PropertyLiquidated` | seat, property_id, value? |
| `WealthTaxCharged` | seat, amount, taxable_wealth |
| `EventDeckReshuffled` | — |
| `PayoutScheduled` / `PayoutResolved` | payout_id, seat, reward, chance_pct / won |
| `RescueResolved` | seat, outcome |
| `MatchEnded` | reason, rankings[{player_id, net_worth, districts, cash}] — identical payload for every client |

### `Snapshot`
The full public state: board ownership and levels, balances, positions, phase, deadlines, active modifiers, pending auction/trade/choice, `seq`, `state_version`. It is produced by `GameEngine.public_snapshot()`, which **omits the RNG state and seed and sends only the event-deck size**, so clients cannot predict dice or cards. It is sent on join, on reconnect and after a `seq` gap. The client replaces its whole local state with it; it does not merge.

## 6. Error codes
`PROTOCOL_UNSUPPORTED, PAYLOAD_TOO_LARGE, BAD_REQUEST, UNAUTHENTICATED, NOT_SEATED, RATE_LIMITED, STALE_STATE, MATCH_ENDED, NOT_YOUR_TURN, WRONG_PHASE, DEADLINE_PASSED, INVALID_TARGET, INSUFFICIENT_FUNDS, NOT_OWNER, DISTRICT_INCOMPLETE, MAX_LEVEL, ABILITY_UNAVAILABLE, STRATEGY_ACTION_USED, TRADE_INVALID, BID_TOO_LOW, INTERNAL`.
(`PAYLOAD_TOO_LARGE`, `UNAUTHENTICATED`, `RATE_LIMITED` and `INTERNAL` belong to the M3 gateway. The rules engine emits the rest.)

## 7. Timers
Server-side only. Deadlines are sent as absolute `server_time`. Clients show `deadline - (local_now + clock_offset)`, where the offset is estimated from `Ping`/`Pong`.
Turn 45 s · trade 20 s · auction 12 s (+3 s anti-snipe, max 2 extensions) · rescue 30 s.
On turn timeout the server applies the safe default from GDD §3.8.

## 8. RNG and fairness
- Dice, card shuffles, Opportunity draws and chance payouts use one per-match `ErRng` (xorshift128, 32-bit lanes). It is portable: an independent Python port reproduces the golden values in `test_rng.gd`. The seed is stored server-side with the match.
- `seed_commitment` (a hash of the seed) is sent at `MatchStarted`, and the seed is revealed in `MatchEnded`. This allows a later fairness audit. It is optional for MVP and decided in M3.

## 9. Versioning
- Additive changes (new optional fields or event types): same `protocol_version`. Clients ignore unknown fields and events.
- Breaking changes: bump `protocol_version`. The server supports N and N-1 during a rollout.
- `board_config_hash` / `balance_config_hash` let clients detect mismatched data packs.

## 10. Open items (decide in M3)
- Auth model: Phase 3 implements **guest tokens per room seat** (§11). Accounts are still open.
- Persistence store and which events are "critical" (minimum: cash, ownership, trade, match result — GDD §10).
- Server runtime: headless Godot reusing `scripts/domain/` vs a separate backend. See IMPLEMENTATION_PLAN §4.

## 11. Rooms, sessions and hardening (Phase 3, implemented in `client/scripts/net/room_server.gd`)

**Rooms (private, code based)**

| Direction | Message | Body | Answer |
|---|---|---|---|
| C → S | `CreateRoom` | `{players: 2..4, character_id?}` | `RoomJoined{room_code, token, seat: 0, player_id, players, joined}` |
| C → S | `JoinRoom` | `{room_code, character_id?}` | `RoomJoined{…}` or `Error ROOM_NOT_FOUND / ROOM_FULL` |
| S → C | `RoomState` | `{room_code, players, joined, started}` | sent to every link in the room after each join |
| C → S | `Hello` | `{token, last_seq}` | `Welcome` + `Snapshot`; used both to enter a started match and to reconnect |

- The room starts when the last seat is taken. The server then picks the seed, never the client.
- Room codes have 6 characters from an alphabet without 0/O/1/I/L, and are case-insensitive on input.
- `player_id` (`p0`…`p3`) and the seat are assigned by the server.
- An unknown `character_id` is replaced by the server default.

**Sessions**
- The token is a 128-bit random value, sent **once** in `RoomJoined` to that link only.
- The server stores only `sha256(token)`: in memory, in `meta.json` and in logs.
- One live connection per seat. A second `Hello` with the same token closes the older link with `SESSION_REPLACED`.
- When an ended room is removed (after `linger_ms`, default 30 s), its tokens stop working and every link in it is closed with `ROOM_CLOSED`.

**Limits and abuse handling** (defaults; server flags in brackets)
- Frame size is checked before JSON parsing (16 KiB). The WebSocket inbound buffer is 32 KiB, so larger frames are cut at the socket.
- Rate limit is a token bucket per link: 20 frames/s, burst 40 (`--rate`, `--burst`).
  - Frames over the limit are dropped unread.
  - One `RATE_LIMITED` error is sent per 10 dropped frames.
  - After 50 violations the link is closed.
- Handshake timeout: a link that has not created, joined or resumed within 10 s is closed (`HANDSHAKE_TIMEOUT`).
- Server limits: max rooms 64 (`--max_rooms`, `SERVER_FULL`) and max links 512 (refused at accept).
- Identity always comes from the session. A command whose `player_id` is not the session's is rejected `UNAUTHENTICATED`.
- New error codes: `RATE_LIMITED, ROOM_NOT_FOUND, ROOM_FULL, ROOM_CLOSED, SERVER_FULL, HANDSHAKE_TIMEOUT, SESSION_REPLACED`.

**Persistence**
- Per room: `meta.json` (seats, seed, token hashes, policy) is written when the match starts.
- `journal.jsonl` is append-only: accepted commands and timer advances with server times. Each entry is written and flushed **before** any frame is sent.
- `result.json` is written when the match ends.
- On restart the server replays each unfinished room. Downtime does not count as match time.

**TLS**
- `server_main.gd --tls_key --tls_cert` serves `wss://` directly through Godot's `StreamPeerTLS`.
- Clients verify the certificate against a trusted CA (`TLSOptions.client`).
- Tested locally with a throw-away self-signed certificate, including a negative test: wrong CA and plain `ws://` against the TLS port.
- Not yet tested: a public certificate, an Internet endpoint, or a TLS-terminating proxy.
