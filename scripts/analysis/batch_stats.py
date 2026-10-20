#!/usr/bin/env python3
"""Independent cross-check of a playtest batch (Phase 2, B1/B2).

Reads matches.csv written by tests/sim/run_playtest_batch.gd and recomputes
the statistics with plain Python (standard library only), so the numbers in
summary.md do not rest on the GDScript code alone. It also adds measures of
uncertainty (bootstrap CI for medians, Wilson CI and a chi-square test for
seat win rates) and flags abnormal matches.

Usage: python3 scripts/analysis/batch_stats.py DIR/matches.csv[.gz] [--json OUT.json] [--md OUT.md]
"""
import argparse
import csv
import gzip
import json
import math
import random
import statistics
import sys
from collections import Counter, defaultdict


def quantile(sorted_vals, q):
    # Same rule as run_playtest_batch.gd::_q (nearest rank, ceil).
    if not sorted_vals:
        return float("nan")
    i = min(len(sorted_vals) - 1, max(0, math.ceil(q * len(sorted_vals)) - 1))
    return sorted_vals[i]


def bootstrap_ci(vals, stat, n=2000, seed=1):
    rng = random.Random(seed)
    k = len(vals)
    reps = sorted(stat([vals[rng.randrange(k)] for _ in range(k)]) for _ in range(n))
    return reps[int(0.025 * n)], reps[int(0.975 * n) - 1]


def wilson(p, n, z=1.96):
    if n == 0:
        return (0.0, 0.0)
    d = 1 + z * z / n
    c = (p + z * z / (2 * n)) / d
    h = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / d
    return c - h, c + h


def chi2_sf(x, k):
    """Survival function of chi-square with k degrees of freedom (k <= 3 here),
    via the regularised upper incomplete gamma function (series/continued fraction)."""
    a, x2 = k / 2.0, x / 2.0
    if x2 <= 0:
        return 1.0
    if x2 < a + 1:
        term = s = 1.0 / a
        n = a
        for _ in range(500):
            n += 1
            term *= x2 / n
            s += term
            if abs(term) < abs(s) * 1e-12:
                break
        return 1.0 - s * math.exp(-x2 + a * math.log(x2) - math.lgamma(a))
    b = x2 + 1 - a
    c = 1e300
    d = 1 / b
    h = d
    for i in range(1, 500):
        an = -i * (i - a)
        b += 2
        d = an * d + b
        d = 1e-300 if abs(d) < 1e-300 else d
        c = b + an / c
        c = 1e-300 if abs(c) < 1e-300 else c
        d = 1 / d
        h *= d * c
        if abs(d * c - 1) < 1e-12:
            break
    return math.exp(-x2 + a * math.log(x2) - math.lgamma(a)) * h


def analyse(rows):
    out = {"rules_versions": sorted(Counter(r.get("rules", "?") for r in rows).items()), "by_players": {}}
    groups = defaultdict(list)
    for r in rows:
        groups[int(r["players"])].append(r)
    seen = Counter((int(r["players"]), int(r["seed"])) for r in rows)
    out["duplicate_rows"] = [f"{p}p seed {s}" for (p, s), c in seen.items() if c > 1]
    for pc in sorted(groups):
        g = groups[pc]
        n = len(g)
        seeds = sorted(int(r["seed"]) for r in g)
        missing = sorted(set(range(seeds[0], seeds[0] + n)) - set(seeds))
        dur = sorted(float(r["game_duration_min"]) for r in g)
        med_lo, med_hi = bootstrap_ci(dur, statistics.median)
        # Shared first places split, as in the GDScript summary.
        wins = [0.0] * pc
        for r in g:
            ws = [int(x) for x in r["winner_seats"].split("|") if x != ""]
            for w in ws:
                wins[w] += 1.0 / len(ws)
        exp = n / pc
        chi2 = sum((w - exp) ** 2 / exp for w in wins)
        tps = [int(x) for r in g for x in r["turns_by_seat"].split("|")]
        cash = defaultdict(list)
        nw = defaultdict(list)
        has_final = "final_cash_by_seat" in g[0] and g[0]["final_cash_by_seat"] != ""
        if has_final:
            for r in g:
                for seat, v in enumerate(r["final_cash_by_seat"].split("|")):
                    cash[seat].append(int(v))
                for seat, v in enumerate(r["final_net_worth_by_seat"].split("|")):
                    nw[seat].append(int(v))
        abnormal = []
        for r in g:
            why = []
            if r["stuck"] == "true":
                why.append("stuck")
            if int(r["invariant_errors"]) > 0:
                why.append("invariants")
            if int(r["rejections"]) > 0:
                why.append("rejections")
            if float(r["game_duration_min"]) > 35:
                why.append(">35 min")
            if r["end_reason"] not in ("round_cap", "last_solvent", "time_cap"):
                why.append("end_reason " + r["end_reason"])
            if why:
                abnormal.append({"seed": int(r["seed"]), "why": why})
        mean = lambda xs: sum(xs) / len(xs) if xs else float("nan")
        d = {
            "n": n,
            "missing_seeds": missing[:20],
            "missing_count": len(missing),
            "duration_min": {"min": dur[0], "p10": quantile(dur, 0.1), "p25": quantile(dur, 0.25),
                             "median": quantile(dur, 0.5), "median_ci95": [round(med_lo, 2), round(med_hi, 2)],
                             "p75": quantile(dur, 0.75), "p90": quantile(dur, 0.9), "p95": quantile(dur, 0.95),
                             "max": dur[-1], "mean": round(mean(dur), 2), "over_35": sum(1 for x in dur if x > 35)},
            "end_reasons_pct": {k: round(100 * v / n, 1) for k, v in Counter(r["end_reason"] for r in g).items()},
            "bankruptcy_match_pct": round(100 * sum(1 for r in g if int(r["bankruptcies"]) > 0) / n, 1),
            "bankruptcies_per_match": round(mean([int(r["bankruptcies"]) for r in g]), 3),
            "turns_per_match": round(mean([int(r["turns"]) for r in g]), 2),
            "turns_per_player": {"mean": round(mean(tps), 2), "min": min(tps), "max": max(tps)},
            "rounds_mean": round(mean([int(r["rounds"]) for r in g]), 2),
            "auctions_opened": round(mean([int(r["auctions_opened"]) for r in g]), 3),
            "auctions_sold": round(mean([int(r["auctions_sold"]) for r in g]), 3),
            "upgrades": round(mean([int(r["upgrades"]) for r in g]), 2),
            "purchases": round(mean([int(r["purchases"]) for r in g]), 2),
            "trades_proposed_accepted": [round(mean([int(r["trades_proposed"]) for r in g]), 2),
                                         round(mean([int(r["trades_accepted"]) for r in g]), 2)],
            "timeouts": round(mean([int(r["timeouts"]) for r in g]), 2),
            "seat_win_pct": [], "seat_chi2": round(chi2, 2), "seat_chi2_df": pc - 1,
            "seat_chi2_p": chi2_sf(chi2, pc - 1),
            "abnormal": abnormal,
        }
        for seat in range(pc):
            p = wins[seat] / n
            lo, hi = wilson(p, n)
            d["seat_win_pct"].append({"seat": seat, "pct": round(100 * p, 2),
                                      "ci95": [round(100 * lo, 2), round(100 * hi, 2)]})
        if has_final:
            d["final_cash_mean_by_seat"] = [round(mean(cash[s]), 1) for s in range(pc)]
            d["final_net_worth_mean_by_seat"] = [round(mean(nw[s]), 1) for s in range(pc)]
            allnw = sorted(v for s in range(pc) for v in nw[s])
            d["final_net_worth"] = {"p10": quantile(allnw, 0.1), "median": quantile(allnw, 0.5), "p90": quantile(allnw, 0.9)}
            # Winner margin: gap between the top two net worths (closeness of matches).
            gaps = []
            for r in g:
                v = sorted((int(x) for x in r["final_net_worth_by_seat"].split("|")), reverse=True)
                gaps.append(v[0] - v[1])
            gaps.sort()
            d["winner_margin_rc"] = {"p25": quantile(gaps, 0.25), "median": quantile(gaps, 0.5), "p75": quantile(gaps, 0.75)}
        out["by_players"][pc] = d
    return out


def to_markdown(a):
    L = ["# Independent cross-check (Python)", "",
         f"Rules versions in the file: {a['rules_versions']}. Duplicate rows: {len(a['duplicate_rows'])}.", ""]
    L.append("| Players | n | missing seeds | median min (95% CI) | p10–p90 | > 35 min | turns / player | bankrupt matches | auctions opened / sold | upgrades | timeouts | abnormal |")
    L.append("|---|---|---|---|---|---|---|---|---|---|---|---|")
    for pc, d in a["by_players"].items():
        du = d["duration_min"]
        L.append(f"| {pc} | {d['n']} | {d['missing_count']} | **{du['median']}** ({du['median_ci95'][0]}–{du['median_ci95'][1]}) | "
                 f"{du['p10']}–{du['p90']} | {du['over_35']} | {d['turns_per_player']['mean']} | {d['bankruptcy_match_pct']}% | "
                 f"{d['auctions_opened']} / {d['auctions_sold']} | {d['upgrades']} | {d['timeouts']} | {len(d['abnormal'])} |")
    L += ["", "Seat win rates (shared wins split; Wilson 95% CI; chi-square test against equal shares):", ""]
    for pc, d in a["by_players"].items():
        seats = ", ".join(f"seat {s['seat']} {s['pct']}% [{s['ci95'][0]}–{s['ci95'][1]}]" for s in d["seat_win_pct"])
        L.append(f"- {pc}p: {seats} — χ²={d['seat_chi2']} (df {d['seat_chi2_df']}), p={d['seat_chi2_p']:.2g}")
    if any("final_cash_mean_by_seat" in d for d in a["by_players"].values()):
        L += ["", "Final position (mean by seat, RC):", ""]
        for pc, d in a["by_players"].items():
            if "final_cash_mean_by_seat" in d:
                L.append(f"- {pc}p: cash {d['final_cash_mean_by_seat']}, net worth {d['final_net_worth_mean_by_seat']}, "
                         f"net worth p10/median/p90 {list(d['final_net_worth'].values())}, winner margin p25/median/p75 {list(d['winner_margin_rc'].values())}")
    return "\n".join(L) + "\n"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("csv")
    ap.add_argument("--json")
    ap.add_argument("--md")
    args = ap.parse_args()
    opener = gzip.open if args.csv.endswith(".gz") else open
    with opener(args.csv, "rt", newline="") as f:
        rows = list(csv.DictReader(f))
    if not rows:
        sys.exit("empty CSV")
    a = analyse(rows)
    if len(a["rules_versions"]) > 1:
        print("WARNING: rows from more than one rules version", a["rules_versions"], file=sys.stderr)
    md = to_markdown(a)
    print(md)
    if args.json:
        with open(args.json, "w") as f:
            json.dump(a, f, indent=2)
    if args.md:
        with open(args.md, "w") as f:
            f.write(md)


if __name__ == "__main__":
    main()
