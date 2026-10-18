#!/usr/bin/env python3
"""Multi-process multiplayer end-to-end tests (Phase 3, B2/B5).

Every scenario starts ONE headless Godot server process (tools/net/server_main.gd)
and one headless Godot process per player (tools/net/client_main.gd), talking
over real WebSockets, then checks the result with tools/net/verify_e2e.gd.
Everything runs on this machine: loopback, other loopback addresses, the
container's own non-loopback address, a local TLS endpoint with a throw-away
certificate, and a local TCP proxy that adds latency and cuts connections.
None of this is the public Internet, a phone or a hosted server.

Usage: GODOT=/path/to/godot python3 scripts/net_e2e.py OUT_DIR [scenario ...]
Scenarios: chaos concurrent sequential client_restart abandon tls tls_bad_ca netem lan
           (default: chaos concurrent)
Exit code 0 only if every scenario passes. OUT_DIR/<scenario>/ keeps all logs.
"""
import asyncio
import json
import os
import random
import socket
import subprocess
import sys
import threading
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GODOT = os.environ.get("GODOT", "godot")
G = [GODOT, "--headless", "--path", os.path.join(ROOT, "client")]
SCALE = "10"          # accelerated server clock (all scenarios)
FAST_RATE = ["--rate=200", "--burst=400"]  # accelerated clocks send more frames per real second


def free_port():
    s = socket.socket()
    s.bind(("127.0.0.1", 0))
    p = s.getsockname()[1]
    s.close()
    return p


def host_ip():
    """The container's own non-loopback address (no packet leaves the host)."""
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("10.255.255.255", 1))
        return s.getsockname()[0]
    except OSError:
        return None
    finally:
        s.close()


class Run:
    def __init__(self, out, name):
        self.dir = os.path.join(out, name)
        os.makedirs(self.dir, exist_ok=True)
        for f in os.listdir(self.dir):
            p = os.path.join(self.dir, f)
            if os.path.isfile(p):
                os.remove(p)
        rooms = os.path.join(self.dir, "rooms")
        if os.path.isdir(rooms):
            subprocess.run(["rm", "-rf", rooms])
        self.port = free_port()
        self.server = None
        self.clients = {}
        self.t0 = time.time()

    def log(self, msg):
        print(f"  [{time.time() - self.t0:6.1f}s] {msg}", flush=True)

    def start_server(self, *extra):
        log = open(os.path.join(self.dir, "server.log"), "a")
        before = self._listening()
        self.server = subprocess.Popen(G + ["--script", "res://tools/net/server_main.gd", "--", f"--dir={self.dir}",
                                            f"--port={self.port}", f"--time_scale={SCALE}"] + FAST_RATE + list(extra),
                                       stdout=log, stderr=subprocess.STDOUT)
        for _ in range(200):
            if self._listening() > before:
                return
            if self.server.poll() is not None:
                raise RuntimeError("server exited: " + open(os.path.join(self.dir, "server.log")).read()[-2000:])
            time.sleep(0.05)
        raise RuntimeError("server did not start")

    def _listening(self):
        p = os.path.join(self.dir, "server.log")
        return open(p).read().count("LISTENING") if os.path.exists(p) else 0

    def client(self, name, *extra, url=None):
        log = open(os.path.join(self.dir, f"{name}.log"), "a")
        url = url or f"ws://127.0.0.1:{self.port}"
        self.clients[name] = (subprocess.Popen(G + ["--script", "res://tools/net/client_main.gd", "--", f"--url={url}",
                                                    f"--dir={self.dir}", f"--session={self.dir}/session_{name}.json"] + list(extra),
                                               stdout=log, stderr=subprocess.STDOUT), extra, url)
        return self.clients[name][0]

    def room(self, tag, n, opts=None, url=None, urls=None):
        """Creator + n-1 joiners for one room; opts[i] = extra args for seat i."""
        opts = opts or {}
        code = os.path.join(self.dir, f"code_{tag}.txt")
        self.client(f"{tag}_0", f"--create={n}", f"--code_out={code}", *opts.get(0, []), url=(urls or {}).get(0, url))
        for i in range(1, n):
            self.client(f"{tag}_{i}", f"--join_file={code}", *opts.get(i, []), url=(urls or {}).get(i, url))

    def wait_clients(self, timeout, actions=None):
        """actions: list of (seconds, callable) run once when due."""
        actions = sorted(actions or [], key=lambda a: a[0])
        start = time.time()
        while True:
            el = time.time() - start
            while actions and actions[0][0] <= el:
                actions.pop(0)[1]()
            if all(p.poll() is not None for p, _, _ in self.clients.values()) and not actions:
                return True
            if el > timeout:
                self.log("TIMEOUT")
                for p, _, _ in self.clients.values():
                    p.kill()
                return False
            if self.server and self.server.poll() is None:
                try:
                    rss = int(open(f"/proc/{self.server.pid}/status").read().split("VmRSS:")[1].split()[0])
                    with open(os.path.join(self.dir, "server_rss_kib.log"), "a") as f:
                        f.write(f"{el:.1f} {rss}\n")
                except (OSError, IndexError):
                    pass
            time.sleep(0.25)

    def kill_server(self):
        self.log("SIGKILL server")
        self.server.kill()
        self.server.wait()

    def stop_server(self, timeout=15):
        if self.server and self.server.poll() is None:
            try:
                self.server.wait(timeout)
            except subprocess.TimeoutExpired:
                self.server.terminate()
                self.server.wait()

    def verify(self, *flags):
        r = subprocess.run(G + ["--script", "res://tools/net/verify_e2e.gd", "--", f"--dir={self.dir}"] + list(flags),
                           capture_output=True, text=True)
        lines = [l for l in r.stdout.splitlines() if l.startswith("NET_E2E") or l.startswith("  FAIL")]
        for l in lines:
            self.log(l[:400])
        return r.returncode == 0


# --- scenarios ---------------------------------------------------------------------------

def sc_chaos(out):
    """1 room x 4 players: duplicates, hostile frames + a flood, a faked client
    state, a drop longer than the seat hold (bot takeover, then reclaim), and a
    SIGKILL of the server with restart from its journals."""
    r = Run(out, "chaos")
    r.start_server("--hold_ms=20000", "--exit_after_rooms=1", "--linger_ms=3000")
    r.room("A", 4, {0: ["--dup_every=5"], 1: ["--invalid_every=6", "--flood=1000"],
                    2: ["--drop_at_s=20", "--down_s=6"], 3: ["--fake_state_at=10", "--idle_pct=8"]})
    ok = r.wait_clients(420, [(12, r.kill_server), (14, lambda: r.start_server("--hold_ms=20000", "--exit_after_rooms=1", "--linger_ms=3000", "--resume"))])
    r.stop_server()
    return ok and r.verify("--rooms=1", "--expect_restart=1", "--expect_takeover=1", "--expect_duplicates=1",
                           "--expect_invalid=1", "--expect_rate_limit=1")


def sc_concurrent(out):
    """3 rooms (2, 3 and 4 players) at the same time in one server process."""
    r = Run(out, "concurrent")
    r.start_server("--exit_after_rooms=3", "--linger_ms=3000")
    for tag, n in (("A", 2), ("B", 3), ("C", 4)):
        r.room(tag, n, {0: ["--dup_every=4"]})
    ok = r.wait_clients(420)
    r.stop_server()
    return ok and r.verify("--rooms=3", "--expect_duplicates=1")


def sc_sequential(out):
    """3 matches one after another on the same server process; the server
    reports object count and memory after each room is removed (leak check)."""
    r = Run(out, "sequential")
    r.start_server("--exit_after_rooms=3", "--linger_ms=1000")
    marks = []
    ok = True
    for k, tag in enumerate(("A", "B", "C")):
        r.room(tag, 2)
        ok = r.wait_clients(300) and ok
        deadline = time.time() + 10
        while time.time() < deadline:  # wait for the room to be removed
            m = json.load(open(os.path.join(r.dir, "server_meta.json")))
            if m.get("rooms", 1) == 0 and m.get("stats", {}).get("rooms_removed", 0) == k + 1:
                break
            time.sleep(0.3)
        time.sleep(1.2)
        m = json.load(open(os.path.join(r.dir, "server_meta.json")))
        marks.append({"after_match": k + 1, "objects": m.get("objects"), "static_mem_mb": m.get("static_mem_mb"),
                      "rooms": m.get("rooms"), "links": m.get("links")})
        r.log(f"after match {k + 1}: {marks[-1]}")
    r.stop_server()
    json.dump(marks, open(os.path.join(r.dir, "leak_marks.json"), "w"), indent=2)
    stable = abs(marks[2]["objects"] - marks[1]["objects"]) <= 50 and all(m["rooms"] == 0 and m["links"] == 0 for m in marks)
    r.log(f"objects after matches 1/2/3: {[m['objects'] for m in marks]} -> {'stable' if stable else 'GROWING'}")
    return ok and stable and r.verify("--rooms=3")


def sc_client_restart(out):
    """A client PROCESS is killed (kill -9) mid-match and started again; it
    resumes its seat from its saved session token."""
    r = Run(out, "client_restart")
    r.start_server("--exit_after_rooms=1", "--linger_ms=3000", "--hold_ms=60000")
    r.room("A", 3)

    def restart_client():
        p, extra, url = r.clients["A_1"]
        r.log("SIGKILL client A_1")
        p.kill()
        p.wait()
        time.sleep(1.0)
        r.log("restart client A_1 from its session file")
        r.client("A_1", *extra, url=url)

    ok = r.wait_clients(420, [(10, restart_client)])
    r.stop_server()
    return ok and r.verify("--rooms=1", "--expect_resume=1")


def sc_abandon(out):
    """A player leaves for good: after the hold (20 s match time) the server bot
    plays the seat until the match ends normally; nothing is forfeited."""
    r = Run(out, "abandon")
    r.start_server("--exit_after_rooms=1", "--linger_ms=3000", "--hold_ms=20000")
    r.room("A", 2, {1: ["--drop_at_s=6", "--down_s=100000"]})
    p1 = r.clients["A_1"][0]
    start = time.time()
    while r.clients["A_0"][0].poll() is None and time.time() - start < 420:
        time.sleep(0.5)
    p1.kill()
    ok = r.clients["A_0"][0].returncode == 0
    r.stop_server()
    return ok and r.verify("--rooms=1", "--absent=1") and _takeover_without_reclaim(r)


def _takeover_without_reclaim(r):
    v = json.load(open(os.path.join(r.dir, "verify.json")))
    st = v["server_stats"]
    good = st.get("bot_takeovers", 0) == 1 and st.get("bot_commands", 0) > 0 and st.get("seat_reclaims", 0) == 0
    r.log(f"abandon: takeovers={st.get('bot_takeovers')} bot_moves={st.get('bot_commands')} reclaims={st.get('seat_reclaims')} -> {'ok' if good else 'BAD'}")
    return good


def _make_cert(r, name):
    d = os.path.join(r.dir, "tls")
    subprocess.run(G + ["--script", "res://tools/net/make_test_cert.gd", "--", f"--out={d}", f"--name={name}"],
                   capture_output=True, check=True)
    return os.path.join(d, name + ".key"), os.path.join(d, name + ".crt")


def sc_tls(out):
    """wss:// with a throw-away self-signed certificate; clients VERIFY it
    (CN=localhost, the certificate is their only trusted CA)."""
    r = Run(out, "tls")
    key, crt = _make_cert(r, "server")
    r.start_server(f"--tls_key={key}", f"--tls_cert={crt}", "--exit_after_rooms=1", "--linger_ms=3000")
    r.room("A", 2, {0: [f"--tls_ca={crt}", "--tls_name=localhost"], 1: [f"--tls_ca={crt}", "--tls_name=localhost"]},
           url=f"wss://127.0.0.1:{r.port}")
    ok = r.wait_clients(300)
    r.stop_server()
    return ok and r.verify("--rooms=1")


def sc_tls_bad_ca(out):
    """Negative: a client that trusts a DIFFERENT certificate must refuse the
    server, and a plain ws:// client cannot talk to the TLS port."""
    r = Run(out, "tls_bad_ca")
    key, crt = _make_cert(r, "server")
    _, other = _make_cert(r, "other")
    r.start_server(f"--tls_key={key}", f"--tls_cert={crt}")
    a = r.client("bad_ca", "--create=2", f"--tls_ca={other}", "--tls_name=localhost", "--max_connect_attempts=3",
                 url=f"wss://127.0.0.1:{r.port}")
    b = r.client("plain", "--create=2", "--max_connect_attempts=3", url=f"ws://127.0.0.1:{r.port}")
    r.wait_clients(60)
    r.server.terminate()
    r.server.wait()
    fatals = [f for f in os.listdir(r.dir) if f.startswith("fatal_")]
    rooms = os.path.join(r.dir, "rooms")
    no_room = not os.path.isdir(rooms) or not os.listdir(rooms)
    meta = json.load(open(os.path.join(r.dir, "server_meta.json")))
    created = meta.get("stats", {}).get("rooms_created", 0)
    good = len(fatals) == 2 and no_room and created == 0
    r.log(f"tls_bad_ca: clients gave up={len(fatals)}/2, rooms created={created} -> {'ok' if good else 'BAD'}")
    return good


class Proxy:
    """TCP proxy: adds 40-200 ms latency per chunk (order kept) and cuts each
    connection after a random 6-14 s lifetime. Userspace only: no real packet
    loss/retransmission (TCP hides loss as delay), no bandwidth limits."""

    def __init__(self, upstream_port, seed=7):
        self.up = upstream_port
        self.port = free_port()
        self.rng = random.Random(seed)
        self.stats = {"connections": 0, "cuts": 0, "chunks": 0}
        self.loop = asyncio.new_event_loop()
        threading.Thread(target=self._run, daemon=True).start()
        time.sleep(0.3)

    def _run(self):
        asyncio.set_event_loop(self.loop)
        self.loop.run_until_complete(self._serve())

    async def _serve(self):
        srv = await asyncio.start_server(self._handle, "127.0.0.1", self.port)
        async with srv:
            await srv.serve_forever()

    async def _pipe(self, reader, writer, q_delay):
        try:
            while True:
                data = await reader.read(65536)
                if not data:
                    break
                self.stats["chunks"] += 1
                await asyncio.sleep(q_delay())
                writer.write(data)
                await writer.drain()
        except (ConnectionError, asyncio.CancelledError):
            pass
        finally:
            try:
                writer.close()
            except Exception:
                pass

    async def _handle(self, cr, cw):
        self.stats["connections"] += 1
        try:
            ur, uw = await asyncio.open_connection("127.0.0.1", self.up)
        except OSError:
            cw.close()
            return
        delay = lambda: self.rng.uniform(0.04, 0.2)
        t1 = asyncio.ensure_future(self._pipe(cr, uw, delay))
        t2 = asyncio.ensure_future(self._pipe(ur, cw, delay))
        life = self.rng.uniform(6, 14)
        done, _ = await asyncio.wait([t1, t2], timeout=life, return_when=asyncio.FIRST_COMPLETED)
        if not done:
            self.stats["cuts"] += 1
        for t in (t1, t2):
            t.cancel()
        for w in (cw, uw):
            try:
                w.close()
            except Exception:
                pass


def sc_netem(out):
    """Clients behind a latency + connection-cutting proxy."""
    r = Run(out, "netem")
    r.start_server("--exit_after_rooms=1", "--linger_ms=5000", "--hold_ms=60000")
    px = Proxy(r.port)
    r.room("A", 3, url=f"ws://127.0.0.1:{px.port}")
    ok = r.wait_clients(420)
    r.stop_server()
    json.dump(px.stats, open(os.path.join(r.dir, "proxy_stats.json"), "w"))
    r.log(f"proxy: {px.stats}")
    return ok and px.stats["cuts"] > 0 and r.verify("--rooms=1")


def sc_lan(out):
    """Server bound to 0.0.0.0; clients reach it through 127.0.0.2, 127.0.0.3
    and the container's own non-loopback address (same host, not a real LAN)."""
    r = Run(out, "lan")
    ip = host_ip()
    r.start_server("--bind=0.0.0.0", "--exit_after_rooms=1", "--linger_ms=3000")
    hosts = ["127.0.0.2", "127.0.0.3", ip or "127.0.0.1"]
    r.log(f"client addresses: {hosts}")
    r.room("A", 3, urls={i: f"ws://{h}:{r.port}" for i, h in enumerate(hosts)})
    ok = r.wait_clients(300)
    r.stop_server()
    return ok and r.verify("--rooms=1")


SCENARIOS = {"chaos": sc_chaos, "concurrent": sc_concurrent, "sequential": sc_sequential,
             "client_restart": sc_client_restart, "abandon": sc_abandon, "tls": sc_tls,
             "tls_bad_ca": sc_tls_bad_ca, "netem": sc_netem, "lan": sc_lan}


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    out = os.path.abspath(sys.argv[1])
    names = sys.argv[2:] or ["chaos", "concurrent"]
    results = {}
    for n in names:
        print(f"== {n}", flush=True)
        t = time.time()
        try:
            results[n] = {"pass": bool(SCENARIOS[n](out)), "wall_s": round(time.time() - t, 1)}
        except Exception as e:  # a crashed harness is a failure, never a pass
            results[n] = {"pass": False, "error": repr(e), "wall_s": round(time.time() - t, 1)}
        print(f"== {n}: {'PASS' if results[n]['pass'] else 'FAIL'} ({results[n]['wall_s']} s)", flush=True)
    json.dump(results, open(os.path.join(out, "summary.json"), "w"), indent=2)
    print("NET_E2E_SUITE", "PASS" if all(r["pass"] for r in results.values()) else "FAIL", json.dumps(results))
    sys.exit(0 if all(r["pass"] for r in results.values()) else 1)


if __name__ == "__main__":
    main()
