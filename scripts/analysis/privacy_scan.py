#!/usr/bin/env python3
"""Privacy scan for playtest data before it is shared (Phase 4).

Looks for things that must never leave a tester's machine or reach the repo:
session tokens, private keys / certificates, e-mail addresses, absolute home
paths (they contain the OS user name), IP addresses, and tester names typed
into free-text fields when --names is given.

  python3 scripts/analysis/privacy_scan.py DIR [--names "An,Binh"]            # report only, exit 1 if findings
  python3 scripts/analysis/privacy_scan.py DIR --redact OUT_DIR [--names …]   # write redacted copies, then re-scan them

Redaction replaces findings with placeholders (<home>, <email>, <ip>, <token>,
<name>) and drops private-key files entirely. It never edits the originals.
Binary files (images) are copied unchanged and listed, so a person can check
screenshots by eye.
"""
import argparse
import os
import re
import shutil
import sys

RULES = [
    ("private_key", re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----")),
    ("certificate", re.compile(r"-----BEGIN CERTIFICATE-----")),
    ("token", re.compile(r'(?i)("?(?:token|session|secret|password|api_key)"?\s*[:=]\s*"?)[A-Za-z0-9_\-]{16,}')),
    ("email", re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}")),
    # Home folders carry the OS user name; iOS app containers carry a
    # per-install UUID (/var/mobile/Containers/Data/Application/<UUID>).
    # Windows: a JSON-escaped user name (C:\\Users\\Ph\u1ea1m) is matched whole.
    ("home_path", re.compile(r"(/home/[^/\s\"']+|/Users/[^/\s\"']+|/root\b|/var/mobile/Containers/Data/Application/[0-9A-Fa-f-]+|[A-Za-z]:\\\\?Users\\\\?(?:\\u[0-9A-Fa-f]{4}|[^\\\s\"'])+)")),
    # Any other UUID (iOS bundle / app-group paths, vendor ids). The game
    # writes none; match ids, hashes and seeds are not in this form.
    ("uuid", re.compile(r"\b[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}\b")),
    # Vietnamese mobile numbers (0912 345 678, +84 912345678) typed into notes.
    ("phone", re.compile(r"(?<![\d.])(?:\+84[ .-]?|0)[35789](?:[ .-]?\d){8}(?![\d.])")),
    ("ip_address", re.compile(r"\b(?:(?:25[0-5]|2[0-4]\d|1?\d?\d)\.){3}(?:25[0-5]|2[0-4]\d|1?\d?\d)\b")),
]
PLACEHOLDER = {"phone": "<phone>", "uuid": "<uuid>", "token": "<token>", "email": "<email>", "home_path": "<home>", "ip_address": "<ip>", "certificate": "<certificate>"}
TEXT_EXT = {".json", ".jsonl", ".csv", ".txt", ".log", ".md", ".cfg", ".ini"}
SAFE_IPS = {"127.0.0.1", "0.0.0.0"}


def scan_text(text, names):
    found = []
    for kind, rx in RULES:
        for m in rx.finditer(text):
            if kind == "ip_address" and m.group(0) in SAFE_IPS:
                continue
            if kind == "ip_address" and re.fullmatch(r"\d+\.\d+\.\d+\.\d+", m.group(0)) and _looks_like_version(text, m.start()):
                continue
            found.append((kind, m.group(0)[:60]))
    for n in names:
        if n and re.search(r"\b" + re.escape(n) + r"\b", text, re.I):
            found.append(("name", n))
    return found


def _looks_like_version(text, pos):
    # "4.7.2.stable" / "v1.2.3.4" style version strings are not addresses.
    before = text[max(0, pos - 2):pos]
    return before.endswith("v") or text[pos:pos + 20].count(".stable") > 0


def redact_text(text, names):
    for kind, rx in RULES:
        if kind == "token":
            text = rx.sub(lambda m: m.group(1) + "<token>", text)  # keep the key: JSON stays valid
        elif kind in PLACEHOLDER:
            text = rx.sub(lambda m: m.group(0) if (kind == "ip_address" and m.group(0) in SAFE_IPS) else PLACEHOLDER[kind], text)
    for n in names:
        if n:
            text = re.sub(r"\b" + re.escape(n) + r"\b", "<name>", text, flags=re.I)
    return text


def _parses(text):
    import json
    try:
        json.loads(text)
        return True
    except ValueError:
        return False


def walk(root):
    for d, _, files in os.walk(root):
        for f in sorted(files):
            yield os.path.join(d, f)


def self_test():
    """Checks the rules on generated strings (nothing read from disk). Each
    case below is a regression for a defect found in Phase 4."""
    import json
    sample = ('{"token": "0123456789abcdef0123456789abcdef", "p": "/home/alice/x", "r": "/root/.local", '
              '"m": "a.b@example.com", "ip": "192.168.1.20", "v": "4.7.2.stable", "lo": "127.0.0.1", '
              '"ios": "/var/mobile/Containers/Data/Application/1A2B-33/Documents"} An')
    kinds = sorted({k for k, _ in scan_text(sample, ["An"])})
    assert kinds == ["email", "home_path", "ip_address", "name", "token"], kinds
    red = redact_text(sample, ["An"])
    assert not scan_text(red, ["An"]), scan_text(red, ["An"])
    # Token redaction once replaced the key too and broke the JSON.
    json.loads(red.rsplit("}", 1)[0] + "}")
    assert '"token": "<token>"' in red, red
    # `/root` (no user-name segment) was missed in godot.log lines.
    assert scan_text("BENCH_REPORT /root/.local/share/godot/x.json", [])
    # iOS bundle path and a bare vendor UUID.
    ios = "/var/containers/Bundle/Application/0F1E2D3C-4B5A-6978-8796-A5B4C3D2E1F0/EmpireRush.app"
    assert [k for k, _ in scan_text(ios, [])] == ["uuid"], scan_text(ios, [])
    assert "0F1E2D3C" not in redact_text(ios, [])
    # A Windows user name with a JSON \u escape must go whole, not leave a suffix.
    win = json.dumps({"log": "C:\\Users\\Ph\u1ea1m\\AppData\\x"})
    out = redact_text(win, [])
    assert json.loads(out)["log"] == "<home>\\AppData\\x", out
    # Replay-relevant fields must come out byte-identical: hashes, seeds,
    # ids, timestamps, engine version, loopback address.
    replay = json.dumps({"engine": "4.7.2.stable", "server": "127.0.0.1", "seed": 404,
                         "replay": {"match_id": "local-21", "state_hash": "5dc39a781eebed095acd0268a0ee05a3a1d8f43c9c702014c75b33139315240e",
                                    "input_log": [{"command_id": "c17", "player_id": "p0", "at_ms": 1792311089, "type": "BuyProperty",
                                                   "payload": {"property_id": "P_D3_1"}}]},
                         "mean_frame_game_s": 0.0277, "session_wall_seconds": 11.5})
    assert not scan_text(replay, []), scan_text(replay, [])
    assert redact_text(replay, []) == replay
    # Phone numbers in free-text notes; timestamps and floats are not phones.
    assert [k for k, _ in scan_text("goi 0912 345 678 hoac +84 987654321", [])] == ["phone", "phone"]
    assert not scan_text('{"at_ms": 1792311089, "t": 0.0912345678, "n": 309123456789}', [])
    print("PRIVACY_SELF_TEST PASS")


def main():
    if "--self-test" in sys.argv:
        self_test()
        return
    ap = argparse.ArgumentParser()
    ap.add_argument("dir")
    ap.add_argument("--redact")
    ap.add_argument("--names", default="")
    ap.add_argument("--binaries-reviewed", action="store_true",
                    help="images/binaries in the data were checked by eye")
    a = ap.parse_args()
    names = [x.strip() for x in a.names.split(",") if x.strip()]
    target = a.dir
    binaries = []
    if a.redact:
        for path in walk(a.dir):
            rel = os.path.relpath(path, a.dir)
            out = os.path.join(a.redact, rel)
            os.makedirs(os.path.dirname(out), exist_ok=True)
            ext = os.path.splitext(path)[1].lower()
            if ext in (".key", ".pem", ".p12", ".mobileprovision"):
                print(f"DROPPED {rel} (key/certificate file)")
                continue
            if ext in TEXT_EXT:
                text = open(path, encoding="utf-8", errors="replace").read()
                if "PRIVATE KEY-----" in text:
                    print(f"DROPPED {rel} (contains a private key)")
                    continue
                red = redact_text(text, names)
                if ext == ".json" and _parses(text) and not _parses(red):
                    print(f"ERROR redaction broke the JSON of {rel}; nothing should be shared")
                    sys.exit(2)
                open(out, "w", encoding="utf-8").write(red)
            else:
                shutil.copy2(path, out)
                binaries.append(rel)
                print(f"COPIED AS IS {rel} (binary: check by eye)")
        target = a.redact
    findings = 0
    for path in walk(target):
        if os.path.splitext(path)[1].lower() not in TEXT_EXT:
            continue
        for kind, sample in scan_text(open(path, encoding="utf-8", errors="replace").read(), names):
            findings += 1
            print(f"FINDING {kind:12s} {os.path.relpath(path, target)}: {sample}")
    print(f"PRIVACY_SCAN {'CLEAN' if findings == 0 else 'FOUND %d' % findings} ({target})")
    if findings:
        sys.exit(1)
    # Text can be checked by rules; images cannot. Sharing stays blocked until
    # a person has looked at them (a screenshot can show a notification, a
    # name or a desktop).
    if binaries and not a.binaries_reviewed:
        print(f"SHARING BLOCKED: {len(binaries)} image/binary file(s) not checked. Look at each one, "
              "delete what shows anything personal, then re-run with --binaries-reviewed.")
        sys.exit(3)


if __name__ == "__main__":
    main()
