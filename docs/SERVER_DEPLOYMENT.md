# EMPIRE RUSH — Headless server: run and deploy (Phase 3 draft)

**Status:** the server runs and is tested on one machine. That covers:
- loopback;
- other loopback addresses;
- the host's own non-loopback IP;
- local TLS with a throw-away certificate;
- a latency/disconnect proxy.

**Nothing has been deployed.** There is no public endpoint, no real certificate and no hosting account. No paid service is chosen. Every step that needs one is marked **[owner]**.

## 1. What runs

| Item | Detail |
|---|---|
| Process | One headless Godot 4.7.2 process: `client/tools/net/server_main.gd` |
| Contents | Rooms (`RoomServer`), each with its own `MatchHost` (rules engine, clock, journal) |
| Measured locally | ~107 MB RSS per process (mostly the engine), ~1 s CPU per match. Object count and static memory flat across 3 sequential matches (`docs/test-logs/phase3_net_e2e/sequential/leak_marks.json`) |
| Not measured | 50 concurrent rooms, 24 h soak |

### State on disk (`--dir`)
```
server_meta.json                 restarts, counters, object count, memory (no secrets)
rooms/<CODE>/meta.json           seats, seed, token SHA-256 hashes, policy
rooms/<CODE>/journal.jsonl       write-ahead input journal (commands + timer advances)
rooms/<CODE>/stats.json          counters, about once per second
rooms/<CODE>/result.json         final hash and results
```
The directory holds no plain tokens. **Back it up and keep it private anyway:** seeds of running matches are in it.

## 2. Run locally
```
GODOT=/path/to/Godot_v4.7.2-stable_linux.x86_64
$GODOT --headless --path client --script res://tools/net/server_main.gd -- \
  --dir=/var/lib/empire-rush --bind=0.0.0.0 --port=18765 \
  --hold_ms=60000 --policy=bot            # disconnect policy (test default, not a rule)
# after a crash: same command + --resume
```

Defaults:

| Flag | Default |
|---|---|
| `--time_scale` | 1 (only tests use more) |
| `--rate` / `--burst` | 20 / 40 |
| `--max_rooms` | 64 |
| `--linger_ms` | 30000 |

Client (test harness):
```
$GODOT --headless --path client --script res://tools/net/client_main.gd -- \
  --url=ws://HOST:18765 --dir=OUT --create=4 --code_out=OUT/code.txt --session=OUT/s0.json
```

Full automated check: `GODOT=$GODOT scripts/run_net_e2e.sh OUT [scenarios]`.

## 3. TLS
**Option A — TLS in Godot.**
- Run `--tls_key=/etc/empire-rush/server.key --tls_cert=/etc/empire-rush/fullchain.crt`. Clients connect with `wss://`.
- Tested locally (`tls`, `tls_bad_ca` scenarios).
- **[owner]** needs a domain and a certificate. Let's Encrypt is free, but needs a public DNS name.

**Option B — TLS at a reverse proxy** (nginx, Caddy, a cloud load balancer) in front of a plain `ws://` server bound to `127.0.0.1`.
- Lets the proxy renew certificates.
- Proxy idle timeouts must exceed the WebSocket heartbeat.
- **Not tested here.**

Rules either way:
- Keys and certificates are **never committed**. Keep them on the host with mode 600, owned by the service user.
- The repository's tests generate a new self-signed certificate per run in a temp directory (`tools/net/make_test_cert.gd`).

## 4. Service sketch (Linux host) — [owner] to adapt
```
# /etc/systemd/system/empire-rush.service
[Service]
User=empire
ExecStart=/opt/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path /opt/empire-rush/client \
  --script res://tools/net/server_main.gd -- --dir=/var/lib/empire-rush --bind=127.0.0.1 --port=18765 --resume
Restart=always
RestartSec=2
```

**Notes:**
- `--resume` is always safe. With no unfinished rooms it starts empty.
- `Restart=always` + `--resume` gives the crash recovery tested by the `chaos` scenario (kill -9, restart, every client reconnects).
- Firewall: open only 443 (proxy) or the TLS port.
- Logs: stdout (journald). Lines carry room codes and link ids, never tokens.

**Packaging:** export a Linux dedicated-server build instead of running from the project folder. Do this once a server export preset exists; it does not yet. Today `tools/` is excluded from client exports on purpose.

## 5. What is still missing before players can use it
1. **[owner]** Host, domain and certificate (paid or free; not chosen).
2. A client lobby screen (create/join by code) wired to `NetClient`. The protocol and server side exist.
3. A `RemoteMatch` client authority that projects events instead of re-fetching snapshots (M3-2).
4. Load and soak tests: many rooms per process, 24 h.
5. Real-network tests (Wi-Fi ↔ 4G, two phones). The local proxy only adds delay and connection cuts. It does not model packet loss, bandwidth or NAT.
6. Seed commitment (PROTOCOL §8) and accounts (later milestone).
