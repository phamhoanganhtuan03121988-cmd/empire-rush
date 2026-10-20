# Phase 4 — multi-process multiplayer e2e (final run)

`summary.json`: **9/9 scenarios PASS** in one run on the Phase 4 code. The run includes the RoomServer change (one room per link, 10-minute wait limit). It was done on one machine; see `docs/M3_ARCHITECTURE.md` §3d for what each scenario proves and what it does not.

| Scenario | Time | Key numbers (from `run.log`) |
|---|---|---|
| chaos | 59.9 s | 239 commands, 12 duplicates deduplicated; rejected STALE_STATE 8 / WRONG_PHASE 2 / BAD_REQUEST 2; 1 bot takeover + 1 reclaim; server kill -9 + restart |
| concurrent | 30.9 s | 3 rooms, 9 clients, 669 commands, 51 duplicates; each room replays alone |
| sequential | 80.3 s | 3 matches back to back, 6 clients |
| client_restart | 114.8 s | client process killed and resumed from its session |
| abandon | 23.6 s | 1 takeover, the bot made 44 moves to a normal end |
| tls / tls_bad_ca | 24.9 s / 4.4 s | verified `wss://`; wrong CA and plain `ws://` refused |
| netem | 146.7 s | latency + forced disconnects, converged |
| lan | 30.1 s | 3 clients on 3 addresses |

**Removed before committing:**
- 32 client session files (each holds that client's token: that is their purpose);
- the throw-away TLS keys and certificates.

**Privacy scan of this folder:** CLEAN. Server logs, journals and `meta.json` contain no token; the scan found tokens only in the removed session files.

Rerun: `GODOT=… scripts/run_net_e2e.sh OUT chaos concurrent sequential client_restart abandon tls tls_bad_ca netem lan`.
