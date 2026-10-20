#!/usr/bin/env python3
"""Static repository / mobile-readiness checks (Phase 3, D + E). No Godot needed.

1. iOS export presets: both flavours exist; Team ID empty in the repo (it
   comes from IOS_TEAM_ID at export time); bundle id is the documented
   placeholder; no signing identity, provisioning profile or certificate
   values; Internal Test has `device_tools`, Public Release does not; tests/
   and tools/ are excluded from every export; iPhone family, iOS >= 16.
2. Orientation: the project allows portrait and landscape (sensor).
3. Secrets: no private keys, signing files or tokens committed.
4. Asset register: valid 6-column CSV, unique ids, and every asset folder
   under client/assets is covered by a register row.
Exit code 0 = all checks pass. Prints one line per check.
"""
import configparser
import csv
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PLACEHOLDER_BUNDLE = "com.example.empirerush"
fails = []


def check(ok, what):
    print(("PASS " if ok else "FAIL ") + what)
    if not ok:
        fails.append(what)


def presets():
    cp = configparser.RawConfigParser(strict=False)
    cp.optionxform = str
    cp.read(os.path.join(ROOT, "client", "export_presets.cfg"), encoding="utf-8")
    out = {}
    for sec in cp.sections():
        if re.fullmatch(r"preset\.\d+", sec):
            d = {k: v.strip('"') for k, v in cp.items(sec)}
            opts = {k: v.strip('"') for k, v in cp.items(sec + ".options")} if cp.has_section(sec + ".options") else {}
            out[d.get("name", sec)] = (d, opts)
    return out


def check_presets():
    p = presets()
    for name in ("iOS Internal Test", "iOS Public Release"):
        check(name in p, f"preset '{name}' exists")
        if name not in p:
            continue
        d, o = p[name]
        check(o.get("application/app_store_team_id", "") == "", f"{name}: Team ID empty in repo (set via IOS_TEAM_ID at export)")
        check(o.get("application/bundle_identifier") == PLACEHOLDER_BUNDLE,
              f"{name}: bundle id is the documented placeholder ({PLACEHOLDER_BUNDLE}; IOS_BUNDLE_ID overrides at export)")
        signing = {k: v for k, v in o.items() if re.search(r"provisioning|certificate|code_sign_identity|p12|password", k) and v not in ("", "0", "false")}
        check(not signing, f"{name}: no signing identity / provisioning / certificate values ({signing or 'none'})")
        check(o.get("application/targeted_device_family") == "0", f"{name}: iPhone device family")
        check(float(o.get("application/min_ios_version", "0")) >= 16.0, f"{name}: minimum iOS >= 16")
        check("tests/*" in d.get("exclude_filter", "") and "tools/*" in d.get("exclude_filter", ""), f"{name}: tests/ and tools/ excluded")
    for name, (d, _) in p.items():
        feats = d.get("custom_features", "")
        if "Internal" in name:
            check("device_tools" in feats, f"{name}: has device_tools (telemetry + device panel)")
        if "Public" in name:
            check("device_tools" not in feats, f"{name}: no device_tools (telemetry locked)")


def check_orientation():
    txt = open(os.path.join(ROOT, "client", "project.godot"), encoding="utf-8").read()
    m = re.search(r"window/handheld/orientation=(\d+)", txt)
    check(m is not None and m.group(1) == "6", "orientation = sensor (portrait and landscape)")


SECRET_PATTERNS = [
    (re.compile(rb"-----BEGIN (RSA |EC |OPENSSH |ENCRYPTED )?PRIVATE KEY-----"), "private key"),
    (re.compile(rb"AKIA[0-9A-Z]{16}"), "AWS access key id"),
    (re.compile(rb"ghp_[A-Za-z0-9]{36}"), "GitHub token"),
    (re.compile(rb"xox[baprs]-[A-Za-z0-9-]{10,}"), "Slack token"),
]
SECRET_EXT = (".p12", ".pfx", ".mobileprovision", ".cer", ".key", ".pem", ".keystore", ".jks")


def check_secrets():
    files = subprocess.run(["git", "-C", ROOT, "ls-files"], capture_output=True, text=True, check=True).stdout.split("\n")
    bad = [f for f in files if f.lower().endswith(SECRET_EXT)]
    check(not bad, f"no signing/key files tracked ({bad[:5] or 'none'})")
    hits = []
    for f in files:
        p = os.path.join(ROOT, f)
        if not f or not os.path.isfile(p) or os.path.getsize(p) > 5_000_000:
            continue
        data = open(p, "rb").read()
        for rx, what in SECRET_PATTERNS:
            if rx.search(data):
                hits.append(f"{f}: {what}")
        if '"token":' in data.decode("utf-8", "ignore") and "test-logs" in f:
            hits.append(f"{f}: session token in a test log")
    check(not hits, f"no secrets in tracked files ({hits[:5] or 'none'})")
    team = re.compile(r'app_store_team_id="([A-Z0-9]{10})"')
    check(not team.search(open(os.path.join(ROOT, "client", "export_presets.cfg")).read()), "no Apple Team ID committed")


def check_register():
    path = os.path.join(ROOT, "docs", "ASSET_REGISTER.csv")
    rows = list(csv.reader(open(path, encoding="utf-8")))
    check(all(len(r) == 6 for r in rows), f"ASSET_REGISTER.csv: every row has 6 fields ({[r[0] for r in rows if len(r) != 6] or 'ok'})")
    ids = [r[0] for r in rows[1:]]
    check(len(ids) == len(set(ids)), "ASSET_REGISTER.csv: asset ids unique")
    paths = " ".join(r[1] for r in rows[1:])
    licences = all(r[3].strip() for r in rows[1:])
    check(licences, "ASSET_REGISTER.csv: every row states a licence")
    assets = os.path.join(ROOT, "client", "assets")
    missing = []
    for dirpath, dirs, files in os.walk(assets):
        real = [f for f in files if not f.endswith((".import", ".uid"))]
        if not real:
            continue
        rel = os.path.relpath(dirpath, ROOT).replace(os.sep, "/")
        if rel not in paths:
            missing.append(rel)
    check(not missing, f"every asset folder is in the register ({missing or 'ok'})")


def check_privacy_tool():
    r = subprocess.run([sys.executable, os.path.join(ROOT, "scripts", "analysis", "privacy_scan.py"), "--self-test"],
                       capture_output=True, text=True)
    check(r.returncode == 0 and "PASS" in r.stdout, f"playtest privacy scanner self-test ({r.stdout.strip() or r.stderr.strip()[-200:]})")


def main():
    check_privacy_tool()
    check_presets()
    check_orientation()
    check_secrets()
    check_register()
    print(f"READINESS {'PASS' if not fails else 'FAIL'} ({len(fails)} failed)")
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
