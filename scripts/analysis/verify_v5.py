#!/usr/bin/env python3
"""Phase 4: independent re-check of the Phase 3 seat experiment, current rules
(V0) against the proposed zero-sum cash offsets (V5). Reads only the raw CSVs
in docs/test-logs/phase3_balance/ and the rules files; shares no code with the
GDScript simulator or seat_experiment.py.

Checks: rules fingerprint of every row == the current rules files; V0 and V5
use exactly the same seeds and seat->character assignment (paired design);
characters are spread evenly over seats; V0 rows that appear in both CSVs
(two separate runs) are bit-identical (determinism). Then prints, per player
count: win rate by seat (ties split) with Wilson 95% CI, spread, chi-square
vs uniform, median match length, share of matches with a bankruptcy, final
net worth. It applies nothing: the rules files are read, never written.

  python3 scripts/analysis/verify_v5.py [--md OUT.md]
"""
import csv
import gzip
import hashlib
import json
import math
import os
import statistics
import sys
from collections import Counter, defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DATA = os.path.join(ROOT, "docs", "test-logs", "phase3_balance")
RULES = os.path.join(ROOT, "client", "data", "rules")
RULE_FILES = ["balance.json", "board.json", "characters.json", "events.json", "opportunities.json"]
V0, V5 = "V0 baseline v3", "V5 zero-sum cash x-large"
VN = str.maketrans({",": ".", ".": ","})  # Vietnamese number format: 2.359 and 14,46


def fingerprint():
    # Same recipe as run_playtest_batch.gd: sha256 of the concatenated hex
    # digests of each rules file, first 16 hex chars.
    all_hex = "".join(hashlib.sha256(open(os.path.join(RULES, f), "rb").read()).hexdigest() for f in RULE_FILES)
    return hashlib.sha256(all_hex.encode()).hexdigest()[:16]


def wilson(p, n, z=1.96):
    if n == 0:
        return (0.0, 0.0)
    d = 1 + z * z / n
    c = (p + z * z / (2 * n)) / d
    h = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / d
    return (c - h, c + h)


def chi2_p(obs, exp):
    # Upper tail of chi-square (df = k-1) via the regularised gamma function.
    x = sum((o - e) ** 2 / e for o, e in zip(obs, exp))
    k = (len(obs) - 1) / 2.0
    s, term, i = 0.0, 1.0 / k, 0
    while term > 1e-15 and i < 10000:
        s += term
        i += 1
        term *= (x / 2) / (k + i)
    lower = s * math.exp(-x / 2 + k * math.log(x / 2) - math.lgamma(k)) if x > 0 else 0.0
    return x, max(0.0, 1 - lower)


def load():
    rows = defaultdict(list)
    for name in ("p3_seat_v1_matches.csv.gz", "p3_seat_v1b_matches.csv.gz"):
        with gzip.open(os.path.join(DATA, name), "rt", encoding="utf-8") as f:
            for r in csv.DictReader(f):
                r["_file"] = name
                rows[r["variant"]].append(r)
    return rows


def main():
    md_out = sys.argv[sys.argv.index("--md") + 1] if "--md" in sys.argv else None
    rows = load()
    fp = fingerprint()
    checks = []
    allrows = [r for v in rows.values() for r in v]
    checks.append((all(r["rules"] == fp for r in allrows), f"all {len(allrows)} rows carry rules fingerprint {fp} = current rules files"))
    # Determinism: V0 was run in both experiment files with the same seeds.
    by_file = defaultdict(dict)
    for r in rows[V0]:
        by_file[r["_file"]][(r["players"], r["seed"])] = r["state_hash"]
    a, b = by_file["p3_seat_v1_matches.csv.gz"], by_file["p3_seat_v1b_matches.csv.gz"]
    common = set(a) & set(b)
    checks.append((len(common) > 0 and all(a[k] == b[k] for k in common),
                   f"V0 re-run in a second experiment: {len(common)} matches, identical final state hash"))
    v0 = [r for r in rows[V0] if r["_file"] == "p3_seat_v1b_matches.csv.gz"]
    v5 = rows[V5]
    out = []
    for n in ("2", "3", "4"):
        s0 = {r["seed"]: r for r in v0 if r["players"] == n}
        s5 = {r["seed"]: r for r in v5 if r["players"] == n}
        checks.append((set(s0) == set(s5) and all(s0[k]["characters"] == s5[k]["characters"] for k in s0),
                       f"{n}p: V0 and V5 use the same {len(s0)} seeds and the same seat->character assignment"))
        seat_char = Counter((i, c) for r in s0.values() for i, c in enumerate(r["characters"].split("|")))
        per_seat = [sorted(v for (i, _), v in seat_char.items() if i == s) for s in range(int(n))]
        checks.append((max(max(x) for x in per_seat) - min(min(x) for x in per_seat) <= 1,
                       f"{n}p: each character sits in each seat equally often ({min(min(x) for x in per_seat)}-{max(max(x) for x in per_seat)} matches per seat x character)"))
        for label, data in (("V0 (luật hiện tại)", s0), ("V5 (đề xuất)", s5)):
            out.append(stats(int(n), label, list(data.values())))
    ok = all(c for c, _ in checks)
    lines = ["## Kiểm tra dữ liệu", ""] + [f"- {'PASS' if c else 'FAIL'} {t}" for c, t in checks] + [""]
    lines += ["## Kết quả (bot, mô hình thời gian m1)", "",
              "| Người | Phương án | Thắng theo ghế % (CI 95%) | Chênh max−min (điểm %) | χ² p | Thời lượng trung vị (phút) | Trận có phá sản | Tài sản cuối trung vị (mọi ghế) | Tài sản người thắng (trung vị) |",
              "|---|---|---|---|---|---|---|---|---|"]
    lines += out
    text = "\n".join(lines)
    print(text)
    print("VERIFY_V5", "PASS" if ok else "FAIL")
    if md_out:
        open(md_out, "w", encoding="utf-8").write(text + "\n")
    sys.exit(0 if ok else 1)


def stats(n, label, rs):
    wins = [0.0] * n
    for r in rs:
        w = [int(x) for x in r["winner_seats"].split("|") if x != ""]
        for s in w:
            wins[s] += 1.0 / len(w)
    m = len(rs)
    rates = [w / m for w in wins]
    cis = [wilson(p, m) for p in rates]
    _, p = chi2_p(wins, [m / n] * n)
    dur = statistics.median(float(r["game_duration_min"]) for r in rs)
    bank = sum(1 for r in rs if int(r["bankruptcies"]) > 0) / m
    nw_all = statistics.median(int(x) for r in rs for x in r["final_net_worth_by_seat"].split("|"))
    nw_win = statistics.median(max(int(x) for x in r["final_net_worth_by_seat"].split("|")) for r in rs)
    seats = " / ".join(f"{100 * q:.1f} ({100 * lo:.1f}–{100 * hi:.1f})" for q, (lo, hi) in zip(rates, cis))
    spread = 100 * (max(rates) - min(rates))
    return (f"| {n} | {label} | {seats} | **{spread:.1f}** | {('< 1e-10' if p < 1e-10 else f'{p:.3g}')} | {dur:.2f} | {100 * bank:.1f}% | {nw_all:,.0f} | {nw_win:,.0f} |").translate(VN)


if __name__ == "__main__":
    main()
