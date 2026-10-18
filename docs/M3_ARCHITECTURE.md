# EMPIRE RUSH — M3 Online Foundation: Architecture, Spike Results, Plan

Status (2026-10-18):
- **Architecture proposal + a verified in-process technical spike.**
- **Not built:** a server process, a real transport (WebSocket/TLS), hosting, accounts or persistence.
- **Multiplayer is not "done".** The spike proves the rules engine, the protocol shape, idempotency and reconnect logic end to end with four simulated clients.

Inputs: GDD §10–11, `docs/PROTOCOL.md` (v1 draft), IMPLEMENTATION_PLAN §3–4 (M3 scope and the server-runtime decision).

## 1. Approved scope (from IMPLEMENTATION_PLAN)
M3 = **rooms + seats, server timers + RNG, idempotent commands, snapshot/reconnect, automated 4-client match with zero divergence.**

Out of scope for M3:
- matchmaking (stub only);
- ranked play;
- chat beyond fixed emotes;
- stores.

Private rooms first. Offline mode keeps running the same domain code.

## 2. Target architecture
```
 Phone / PC client (Godot)                         Server (authoritative)
 ┌────────────────────────────┐                     ┌──────────────────────────────────┐
 │ UI (GameHud) + 3D board    │                     │ Gateway (WebSocket over TLS)     │
 │   ▲ events / snapshot      │   JSON frames v1    │  - auth: session token -> seat   │
 │   │                        │  (PROTOCOL.md)      │  - frame size / version checks   │
 │ EventPresenter             │ ◄─────────────────► │  - rate limit                    │
 │   ▲                        │   Hello/Command     │                                  │
 │ Authority interface        │   Welcome/Snapshot  │ Match host (one per room)        │
 │  ├ LocalMatch  (offline)   │   Events/Result     │  - GameEngine (pure GDScript)    │
 │  └ RemoteMatch (M3: wraps  │                     │  - server clock + timers         │
 │     NetClient + transport) │                     │  - command dedupe (command_id)   │
 └────────────────────────────┘                     │  - event log -> broadcast         │
                                                    │  - snapshot for join/reconnect   │
                                                    ├──────────────────────────────────┤
                                                    │ Persistence (PostgreSQL, M3+)    │
                                                    │  match seed, input log, results, │
                                                    │  audit events (cash/ownership)   │
                                                    └──────────────────────────────────┘
```

**Rules of the design:**
1. The client sends intent only.
2. The server owns dice, money, ownership, turns, timers and victory.
3. Every number the client shows comes from an event or a snapshot (the same rule the offline EventPresenter already follows).

## 3. What the spike implemented and proved (`client/scripts/net/`, `client/tests/integration/test_net_loopback.gd`)
| Topic | Spike implementation | Verified by test |
|---|---|---|
| Domain engine as server core | `MatchHost` wraps `GameEngine` + `MatchClock` (server time) | Full 4-player match completes; invariants hold |
| Transport | `LoopbackNetwork`: ordered links, 20–120 ms latency, a disconnect drops in-flight frames, simulated time | Deterministic; no sleeps (a full simulated match takes seconds of CPU) |
| Command validation | Host binds the link to a session token. `player_id` must match the session. The engine validates phase, turn, funds and version | Spoofed `player_id` → `UNAUTHENTICATED`; unknown token rejected; stale `expected_state_version` → `STALE_STATE` |
| Frame checks | 16 KiB limit, `protocol_version` | Oversized → `PAYLOAD_TOO_LARGE`; v99 → `PROTOCOL_UNSUPPORTED` |
| Idempotency | Clients resend unanswered commands with the **same** `command_id`; engine dedupe returns the original result | 35 injected duplicates + one lost command after a disconnect; the final server state equals a replay of only the applied commands |
| State sync | Ordered `Events` frames carry `state_version` + a canonical public-state hash; clients check seq continuity and drop duplicates | All 4 clients end on the server hash and `state_version`; 0 gaps |
| Reconnect | `Hello` → `Welcome` + `Snapshot`; pending commands resent | The client that dropped mid-match resynced and converged |
| Timeouts | Server timers only (`MatchHost.tick` → `engine.advance()`); a disconnected player's turn times out normally | Match continued during the 20 s disconnect |
| Snapshot size | Public snapshot (no RNG, deck as a count) | 1,394 bytes at match start (well under 16 KiB) |

Numbers from the last local run:
- 285 commands, 35 duplicates, 0 rejections;
- 294 frames in, 1,299 frames out;
- 1 frame dropped by the disconnect;
- 9 snapshots;
- 234 s of simulated match time.

**Spike shortcut (test harness only):** the bots choose moves by reading the host engine. Real clients decide from their own snapshot + event stream. A client-side "view model" (§5 M3-2) is needed for that.

## 4. Decisions for the owner
| # | Decision | Options | Recommendation |
|---|---|---|---|
| D1 | Server runtime | (A) headless Godot 4.7.2 reusing `scripts/domain` · (B) Node/TS server with a ported engine | **A first** (spike passes on rules and protocol). Still unproven: hosting cost, memory per match and 24 h soak (exit criteria in IMPLEMENTATION_PLAN §4) |
| D2 | Hosting | Self-managed VM / container service / managed game hosting | Needs owner budget and account; **no paid service chosen, no secrets in the repo** |
| D3 | Identity | Guest token per device vs accounts | Guest token for private rooms in M3; accounts in M4 |
| D4 | Persistence | PostgreSQL (plan) | Store seed + input log + results; the replay test shows that is enough to rebuild a match |
| D5 | Reconnect window | How long a seat is held while disconnected (timers keep running) | 2 min hold, then bot takeover or forfeit — **a product decision** |
| D6 | Seed commitment | PROTOCOL §8 (optional for MVP) | Defer to M4 |

## 5. Milestones for M3
1. **M3-1 Transport** (1 week):
   - WebSocket server/client with Godot `WebSocketPeer` behind a `Transport` interface;
   - TLS terminates at a reverse proxy;
   - port the loopback test to run over localhost sockets with 4 headless clients.
2. **M3-2 RemoteMatch** (1–2 weeks):
   - a client authority with the same interface as `LocalMatch`;
   - a view model from snapshot + events, so bots and UI decide without server access;
   - the HUD and presenter are unchanged (that is the point of the existing boundary tests).
3. **M3-3 Rooms** (1 week):
   - create/join private room with a code;
   - seat assignment;
   - start when everyone is ready;
   - reconnect window (D5).
4. **M3-4 Server ops** (1 week):
   - Docker image for headless Godot;
   - 50-concurrent-match load test on 1 vCPU;
   - 24 h soak;
   - logs and metrics.
5. **M3-5 Acceptance:**
   - automated 4-client match over real sockets with zero divergence;
   - duplicate / stale / out-of-turn fuzzing;
   - reconnect at random points.

## 6. Modules to change / add
| Module | Change |
|---|---|
| `scripts/net/*` (new, spike) | Promote to production: a `Transport` interface; WebSocket implementation; rate limiting; logging |
| `scripts/presentation/local_match.gd` | Extract an `Authority` interface (`submit`, `events_emitted`, `seconds_left`, `human_actor`); add `RemoteMatch` |
| `scripts/domain/*` | **No rule changes.** Possibly a `public_snapshot` restore for client view models |
| `server/` (new) | Headless entry point, room manager, persistence adapter |
| `scripts/main.gd` | Choose Local vs Remote authority from a lobby screen (new) |
| Tests | Loopback test (exists) → socket test → load/soak harness |

## 7. Test strategy
1. **Unit:** protocol encode/decode, hash canonicalisation, session binding.
2. **Deterministic integration (exists):**
   - loopback with latency, disconnects, duplicates;
   - assertions: convergence hash, replay equality, invariants.
3. **Socket integration:** the same scenarios over localhost WebSocket with 4 headless Godot clients in CI.
4. **Fuzz:** random duplicate, stale and out-of-turn commands at random times. The server state must equal the replay of the applied input log.
5. **Load / soak (M3-4):** 50 matches per vCPU, 24 h, memory flat.
6. **Device:** two phones on real networks (Wi-Fi ↔ 4G switch) once M3-2 lands.

## 8. Logging and diagnostics
- **Per match:** seed, protocol version, rules fingerprint (as in the playtest batch tool), input log with server times, results.
- **Per frame (debug level):** link, kind, size, latency.
- **Counters:** duplicates, stale rejections, reconnects, snapshot bytes.
- A bug report can carry `match_id`, and the server can replay the match from the input log (proven by the replay assertion).

## 9. Cost and conditions (not decided)
- Hosting needs an owner decision (D2). The rough sizing to validate in M3-4 is one small VM for many 4-player matches, because matches are turn-based and light (a frame every ~1 s per match).
- No paid service has been selected. No credentials are in the repo. Secrets go to the CI/hosting secret store only.
