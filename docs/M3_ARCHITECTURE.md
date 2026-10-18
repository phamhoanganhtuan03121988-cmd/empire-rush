# EMPIRE RUSH — M3 Online Foundation: Architecture, Spike Results, Plan

Status (2026-10-18, updated in Phase 3 — see §3d):
- **Architecture proposal + two verified spikes:**
  - **In-process** (M2.3): `LoopbackNetwork`, simulated time, runs in CI (§3).
  - **Multi-process** (Phase 2): one headless Godot server process + 2–4 headless Godot client processes over **real WebSockets on 127.0.0.1**, with a server crash/restart (§3b).
- **Not built:**
  - TLS;
  - hosting;
  - rooms/lobby;
  - accounts;
  - a database (the journal is a local file);
  - a client UI on top of the network path (`RemoteMatch`).
- **Multiplayer is not "done".** Nothing has run across the internet or on phones.

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

**Spike shortcut (in-process test only):** the bots choose moves by reading the host engine. The multi-process test below removes this shortcut: each client decides from its own view.

## 3b. Multi-process test over real sockets (Phase 2, C3)

| Part | File |
|---|---|
| Server process | `client/tools/net/server_main.gd`: `TCPServer` + `WebSocketPeer`, one `MatchHost`, server clock = wall clock × `time_scale` |
| Client process | `client/tools/net/client_main.gd`: `NetClient` over `WebSocketPeer`; a bot decides from a read-only `GameEngine` built with `GameState.from_dict(public snapshot)` |
| Orchestrator | `scripts/run_net_e2e.sh` (server + N clients, chaos schedule, SIGKILL + restart) |
| Checker | `client/tools/net/verify_e2e.gd` |

Run it with `GODOT=… scripts/run_net_e2e.sh OUT_DIR`. It takes about 30–70 s wall time per match.

**What one run does:**
- **Client 0:** sends every 5th command twice (same `command_id`).
- **Client 1:** every 6th command, sends a hostile frame. The kinds are spoofed `player_id`, a stale version, an unknown command type, a 16 KiB+ frame, protocol v99 and non-JSON.
- **Client 2:** closes its socket at 20 s and stays away 6 s (60 s of match time). That is longer than the 20 s seat hold, so the **server bot takes the seat**. The player **reclaims** it on reconnect.
- **Client 3:** fakes its local state (cash 999,999, owns every property) and acts on it. It also idles 8% of the time, so server timers act for it.
- **Server:** killed with **SIGKILL at 12 s** and restarted with `--resume`. It rebuilds the match by replaying its **write-ahead journal**: every accepted input is written and flushed before any frame leaves. Every client reconnects by itself with capped backoff and resends unanswered commands with the same id.

**The checker asserts:**
- every client's final public hash and `state_version` equal the server's;
- replaying the journal twice in fresh engines gives the server's exact final `state_hash` (determinism; no command applied twice);
- invariants hold;
- duplicates were deduplicated;
- hostile frames and commands were refused;
- the restart happened and every client reconnected;
- the bot took over and the seat was reclaimed.

**Results (local, this branch):** see `docs/test-logs/phase2_net_e2e/`. All runs PASS. They cover:
- 2, 3 and 4 players;
- 4 different seeds;
- both `bot` and `timers` policies.

**What this does not prove yet:**
- real network conditions (loss, latency, NAT, mobile radio switches);
- TLS;
- load (50 matches per vCPU);
- long soak;
- a phone client.

The server here runs one match per process.

**Design points proven by the run:**
1. **Restart recovery = seed + input journal.** No state dump is needed; the engine is deterministic. Server downtime does not count as match time: the clock resumes from the last journaled time.
2. **Write-ahead ordering.** Because inputs are journaled before results are sent, a command acknowledged to a client can never be lost by a crash. A command lost in flight is retried with the same id and applied once.
3. **The client never needs rules to stay correct.** A faked local state only produces commands the server rejects (`NOT_OWNER`, `WRONG_PHASE`, …). The next snapshot overwrites the fake view.
4. **Spike cost to fix in M3-2:** the test client asks for a full snapshot after each event batch (about 1 snapshot per state version, ≤ 16 KiB each). A production client should project events into its view and request snapshots only on gaps and reconnects.

## 3c. Disconnect policy (Phase 2, C4) — configuration, not a rule

`client/scripts/net/disconnect_policy.gd` is read by `MatchHost.policy`. Server flags: `--hold_ms`, `--policy`.

| Option | Behaviour | Status |
|---|---|---|
| `timers` | Seat held. Only the engine's own timers act for the absent player: auto-roll, pass → auction, end turn after `turn_timer_ms` (45 s). The table is never paused | Implemented, tested |
| `bot` | After `hold_ms` a server-side `BotPlayer` plays the seat. Its moves go through `submit()`: validated, journaled and broadcast like any command. On reconnect the player gets the seat back immediately | Implemented, tested (in-process + multi-process) |
| `forfeit` | Remove the player after the hold | **Not implemented.** The rules do not define what happens to a forfeiting player's cash and properties. This needs an owner rules decision (GDD), so it was not invented here |
| auto-skip whole turn | Skip the absent player's turns without rolling | Not implemented as a separate mode. The engine already has `timeout_auto_roll=false` (balance flag), which ends an idle turn without rolling. Changing it is a balance change for the owner |

**Proposed default for testing only:** `hold_ms = 60000` (60 s), then `bot`.
- Reason: with `timers` alone, one absent player costs the table up to 45 s per decision.
- This replaces the D5 recommendation below until the owner decides.

## 3d. Phase 3: rooms, hardening, 9 multi-process scenarios

**Server:**
- `RoomServer` (`client/scripts/net/room_server.gd`) hosts many private rooms in one process. Each room has its own `MatchHost` (engine, clock, journal, disconnect policy).
- Protocol additions: PROTOCOL.md §11.
- Running it: `docs/SERVER_DEPLOYMENT.md`.

**Verified on this machine** (`scripts/run_net_e2e.sh OUT all-scenarios`, logs in `docs/test-logs/phase3_net_e2e/`):

| Scenario | What it proves |
|---|---|
| chaos | 4 client processes. Room created and joined by code. Duplicates, hostile frames, a 1000-frame flood (rate limited), faked client state, drop > hold (bot takeover, then reclaim), **server SIGKILL + restart from journals** |
| concurrent | 3 rooms (2/3/4 players) at once in one server. Each room's journal replays alone to its final state (isolation) |
| sequential | 3 matches back to back on one server. Object count 1497 → 1497 → 1497, static memory 25.4 MB each time (no leak). Ended rooms removed |
| client_restart | A client **process** killed with kill -9 and started again. It resumes its seat from its saved session token |
| abandon | A player never returns. After the hold the bot plays to a normal end. No forfeit, assets untouched |
| tls | `wss://` with certificate verification (throw-away self-signed certificate, CN=localhost) |
| tls_bad_ca | A client trusting another certificate refuses the server. A plain `ws://` client cannot use the TLS port. No room is created |
| netem | Local proxy: 40–200 ms latency per chunk and every connection cut after 6–14 s (38 cuts). Clients reconnect and converge |
| lan | Server on 0.0.0.0; clients via 127.0.0.2, 127.0.0.3 and the host's own IP |

**In-process tests** (`test_room_server.gd`, in CI):
- concurrent isolation;
- error paths (unknown or full room, bad player count, guessed token, unknown character, room limit, case-insensitive codes);
- `SESSION_REPLACED`;
- rate limit and refill;
- handshake timeout;
- link limit;
- restart from meta + journal;
- player never returns, plus a restart during the takeover (takeover resumes);
- removal of ended rooms with no object growth.

**Disconnect policy** (configuration; test default 60 s hold, then bot):
- takeover after the hold (not before);
- reclaim on reconnect;
- match ends while the player is away;
- restart during a takeover.

All four are covered by tests. Forfeit is still not implemented: it needs a rule.

**Still NOT done:**
- Internet / real LAN between machines;
- phones;
- a public certificate;
- hosting;
- a lobby UI in the game client;
- event projection on the client (the test client re-fetches snapshots);
- load (many rooms at once beyond 3) and 24 h soak.

## 4. Decisions for the owner
| # | Decision | Options | Recommendation |
|---|---|---|---|
| D1 | Server runtime | (A) headless Godot 4.7.2 reusing `scripts/domain` · (B) Node/TS server with a ported engine | **A** — verified in Phase 2: a headless Godot process serves real WebSockets (`TCPServer` + `WebSocketPeer`), runs a full match and recovers from SIGKILL via its journal. Footprint per process is in `docs/test-logs/phase2_net_e2e/`. Still unproven: many matches per process, 24 h soak, hosting cost |
| D2 | Hosting | Self-managed VM / container service / managed game hosting | Needs owner budget and account; **no paid service chosen, no secrets in the repo** |
| D3 | Identity | Guest token per device vs accounts | Guest token for private rooms in M3; accounts in M4 |
| D4 | Persistence | PostgreSQL (plan) | Store seed + input log + results; the replay test shows that is enough to rebuild a match |
| D5 | Disconnect policy | `timers` / `bot` after a hold / `forfeit` (needs a rule) — §3c | Test default 60 s hold then `bot` (Phase 3: covered end to end); **final choice is a product decision** |
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
| `scripts/domain/*` | **No rule changes.** `GameState.from_dict` added (Phase 2) for client views and tested by round trip |
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
