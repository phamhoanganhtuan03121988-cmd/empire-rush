# EMPIRE RUSH — Implementation Plan

Baseline: `docs/GAME_RULES_AND_GDD.md` v1.0. Engine: Godot 4.7.2 (verified `4.7.2.stable.official.ed1daf0bf`).
Audit findings and design conflicts: `docs/M0_AUDIT_REPORT.md`. Network contract: `docs/PROTOCOL.md`.
Implemented rules: `docs/RULES_M1.md`. M1 results: `docs/M1_REPORT.md`.

**Status (2026-10-18):** M0 merged to `main`. M1 implemented on `claude/m1-offline-game-rules`; M1.1 balance review on `claude/m1-1-balance-review`; M1.2 balance DRAFT v3 (owner-approved Option C: per-player-count round caps 40/30/25, stronger L1–3 rent, cheaper upgrades) on `claude/m1-2-balance-v3` (accepted as temporary technical baseline). M2 vertical slice on `claude/m2-vertical-slice`, awaiting review (`docs/M2_VERTICAL_SLICE_REPORT.md`). Balance is not locked until human per-turn time is measured. Reference device: **iPhone 14 Pro** (owner decision; replaces "Android baseline" below for performance targets). Android remains a build target.

## 1. MVP scope boundary (hard)
**In MVP:** 1 board, 28 spaces (21 properties / 7 districts / Start / 2 City Event / 2 Opportunity / Rest / Special). 2–4 players, private rooms. 2d6. 1,500 RC start, 200 RC Start reward. Buy / rent / upgrade levels 0–3. One auction type (ascending, 12 s). Cash + ≤3 property trades. 12 event cards. 3 characters. Rescue → bankruptcy. End by last solvent player or at 25 rounds / 30 min. Android first. Placeholder art until gameplay is stable.

**Out of MVP:** matchmaking (stub or feature flag only), ranked mode, debt/mortgage, items/consumables, extra board themes, 4th+ character, building levels 4–5, store/payments, cosmetics economy, iOS, chat beyond fixed emotes.
Anything here needs a written change request before it is built.

## 2. Target architecture
```
empire-rush/
  client/                Godot 4.7.2 project (res://)
    autoload/            app_state, network_client, audio_manager, scene_router
    scenes/              boot, menus, lobby, game (board_3d, tiles, tokens, ui/*), results
    scripts/domain/      PURE rules: GameState, Command, Event, TurnRules, Economy,
                         Auction, Trade, Events/Modifiers, Victory. No Node and no scene tree:
                         extends RefCounted/Resource only, injected RNG + clock.
    scripts/presentation/ camera, token animation, VFX (consumes Events only)
    scripts/sim/         bots, match simulator, invariants (M1 tooling)
    scripts/ui/
    data/rules/          board, balance, events, characters, opportunities (.json - decided in M1 so a
                         non-Godot server could load identical data)
    assets/              placeholder → final, every external file in ASSET_REGISTER.csv
    tests/unit, tests/integration, tests/test_runner.gd
  server/                gateway + match lifecycle (runtime decided in M3 spike)
  docs/  reference_art/  scripts/run_tests.sh
```
Layering rule: `presentation`/`ui` → read `Event`s and `Snapshot`s → never write domain state.
Offline mode (M1/M2) runs the *same* domain code through a `LocalAuthority` that has the same interface as the remote server. Swapping in `RemoteAuthority` in M3 must not change any UI code.

Domain design notes:
- `GameState` is a plain data object with `state_version`. `apply(command) -> {ok, events[], error}` is a pure function, given an injected `Rng` and `Clock`.
- Deterministic replay: seed + command log → identical state hash. This is the basis for the 100-match simulation, for divergence tests, and for bug reports.
- Money only moves through `Ledger.transfer(from, to, amount, reason) -> tx_id`. It asserts no negative balance and writes an audit event.
- Board and balance values come from `data/` resources and are validated on load (28 spaces, 7×3 districts, unique ids).

## 3. Milestones
| # | Goal | Depends on | Acceptance (summary — full list in CLAUDE_TASK_PROMPT.md) |
|---|---|---|---|
| **M0** | Repo + design baseline | — | Docs committed, Godot 4.7.2 clean import, `scripts/run_tests.sh` green, owner signs off the open decisions in M0_AUDIT_REPORT §4 |
| **M1** ✅ (review) | Offline rules prototype | M0 decisions | Unit tests for every rule in GDD §3–9; 100 seeded simulated matches with no soft-lock, no negative cash, no duplicate ownership/tx; logs committed under `docs/test-logs/`. Done: 144 tests, 4,100 simulated matches, 0 failures. Balance is still a DRAFT. |
| **M2** | Visual vertical slice | M1 | One polished board section + full board placeholder; token/dice animation; one tile with 3 upgrade looks; HUD + property panel; 9:16 and 16:9 screenshots; low/med/high presets; placeholders labelled |
| **M3** | Online foundation | M1 (rules), runtime spike | Rooms + seats, server timers + RNG, idempotent commands, snapshot/reconnect, automated 4-client match with zero divergence |
| **M4** | MVP integration + polish | M2, M3 | Full board, 12 cards, 3 characters, results, audio, reduced motion, telemetry; Android build launches on baseline device; pacing median 22–27 min |
| **M5** | Closed-test readiness | M4 | Regression + 100 sims after any balance change; known issues, rollback, deploy checklist |

### M1 breakdown (all delivered in M1; kept for traceability)
1. Data model + validators (board, properties, districts, balance) + tests.
2. `GameState`, `Command`/`Event`, `Ledger`, injected RNG/Clock + tests.
3. Turn loop: roll, move, Start reward, buy/pass, rent, timeout default.
4. Upgrades (district completion, levels 0–3).
5. Auction (ascending, anti-snipe, duplicate/late bids).
6. Trade (atomic, revalidated on accept, expiry, rate limit).
7. Event cards + deterministic modifier expiry; Opportunity choices; Special/Rest tiles.
8. Rescue → liquidation → bankruptcy asset rule; end conditions + tie-break.
9. Scripted/AI players + 100-match simulator with invariant checks after every command.

## 4. Key technical decision: server runtime (M3 spike, time-boxed 2–3 days)
| Option | Pros | Cons |
|---|---|---|
| **A. Headless Godot 4.7.2 server reusing `scripts/domain/`** | One rules implementation, so client offline mode and server cannot drift; replay tests shared | Hosting/ops less standard; GDScript perf and memory per match unproven; persistence/auth libraries thinner |
| B. Node.js/TypeScript server with a ported rules engine + shared JSON schema | Mature WebSocket/DB/auth ecosystem, easy hosting | Two rules implementations; needs cross-runtime golden replay tests on every rule change |

**Recommendation:** spike A first, because the domain is being written pure-GDScript in M1 anyway. Pass criteria: 50 concurrent matches on 1 vCPU, Docker image builds, 24 h soak without leak, TLS behind a reverse proxy. Fall back to B if it fails, and keep A's domain as the reference implementation for golden tests.
Persistence (accounts, match history, audit events): PostgreSQL in both options.

## 5. Risks
| Risk | Impact | Mitigation |
|---|---|---|
| Rules gaps/undefined tiles (see audit §3) | M1 blocked or rework | Owner decisions before M1; defaults proposed in audit report |
| Pacing: 4p × 25 rounds = 100 turns in ≤30 min ⇒ ≤18 s/turn average | Median 22–27 min target missed; matches end by time cap, not gameplay | Simulator records turn/round counts; add animation budget per turn (~6–8 s); tune economy so bankruptcies happen; consider fewer rounds for 4p |
| Server runtime unproven (Option A) | M3 slip | Time-boxed spike with exit criteria, Option B fallback |
| Art quality bar (stylized realism 3D) vs no production assets | M2/M4 slip, unlicensed assets | Placeholder primitives first; art pipeline doc in M2 (scale, PBR materials, LODs, polycount budget); every external asset licensed and registered |
| Mobile perf (30 FPS low/med on baseline device) | M4 fail | Mobile renderer from day 1; baseline device must be named; perf HUD + presets in M2 |
| Reference art conflicts with GDD numbers | Wrong implementation | GDD wins; conflicts listed in audit §2 |
| Reconnect/idempotency bugs | Cheating, double charges | Pure domain + replay tests + server-side dedupe table; fuzz duplicate/stale commands in integration tests |
| Single-maintainer repo, no CI | Regressions slip in | Add GitHub Actions running `scripts/run_tests.sh` headless (still open, proposed for early M2) |
| First-mover advantage (M1 sim: 4p seat 0 wins 30% vs seat 3 at 21%) | Unfair matches | Owner decision: seat compensation (+50 RC/seat halved the gap in an experiment), other mitigations, or accept |
| Pacing below target (M1 sim: 4p median 18 min, 2p 10 min, nearly all end on round cap) | Misses the 22–27 min target | Measure real UI time in M2/M4; consider per-player-count round caps; raise rent pressure |
| iOS build needs macOS + Xcode | No iPhone 14 Pro verification from Linux CI | Mac build machine or cloud Mac for M2/M4 device tests |

## 6. Test strategy
- `scripts/run_tests.sh`: headless Godot, hard timeout (default 300 s), logs to `logs/`. Any GDScript runtime error or failed `assert` in the log fails the run.
- `scripts/run_simulation.sh`: batch bot matches with metrics (duration, seats, characters, bankruptcies, cash, failures).
- Unit: one file per rule area under `client/tests/unit/`.
- Simulation: `tests/integration/` runs N seeded matches. After every command it checks invariants: cash ≥ 0, each property has ≤ 1 owner, tx ids unique, `state_version` monotonic, the match terminates.
- Network (M3): spawns the server plus 4 headless clients and compares the state hashes each client sees after every `seq`.
