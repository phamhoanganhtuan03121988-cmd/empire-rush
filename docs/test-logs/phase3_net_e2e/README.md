# Phase 3 — multi-process multiplayer e2e (final run)

`summary.json`: 9/9 scenarios PASS in one run on the final Phase 3 code (one machine; see `docs/M3_ARCHITECTURE.md` §3d for what each scenario proves and what it does not).

Each folder holds:
- server and client logs;
- `rooms/<CODE>/{meta,journal,stats,result}`;
- per-client results;
- `verify.json`, the checker output;
- `server_rss_kib.log`.

**Removed before committing:**
- session files (client tokens);
- the throw-away TLS key and certificate.

Rerun: `GODOT=… scripts/run_net_e2e.sh OUT chaos concurrent sequential client_restart abandon tls tls_bad_ca netem lan`.
