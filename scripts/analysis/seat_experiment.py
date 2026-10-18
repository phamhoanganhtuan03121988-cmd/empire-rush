#!/usr/bin/env python3
"""Seat-compensation experiment analysis (Phase 3, C2).

Reads the per-match CSV written by
  scripts/run_experiments.sh --spec=res://tests/sim/experiments/p3_seat_v1.json --csv=/abs/matches.csv
and compares every variant with the baseline on the SAME seeds:
seat win rates (Wilson CI, chi-square), seat spread, match length
(bootstrap CI of the median), bankruptcies, final cash / net worth.

Usage: python3 scripts/analysis/seat_experiment.py matches.csv[.gz] [--md OUT.md] [--json OUT.json]
"""
import argparse
import csv
import gzip
import json
import math
import os
import statistics
import sys
from collections import defaultdict

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from batch_stats import analyse, wilson  # noqa: E402  (same, already cross-checked code)


def diff_ci(p1, n1, p2, n2, z=1.96):
    """95% CI of p1 - p2 (independent-sample normal approximation; the
    seeds are paired, so this is conservative)."""
    se = math.sqrt(p1 * (1 - p1) / n1 + p2 * (1 - p2) / n2)
    d = p1 - p2
    return d - z * se, d + z * se


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("csv")
    ap.add_argument("--md")
    ap.add_argument("--json")
    a = ap.parse_args()
    opener = gzip.open if a.csv.endswith(".gz") else open
    with opener(a.csv, "rt", newline="") as f:
        rows = list(csv.DictReader(f))
    by_var = defaultdict(list)
    for r in rows:
        by_var[r["variant"]].append(r)
    names = list(dict.fromkeys(r["variant"] for r in rows))
    base = names[0]
    res = {v: analyse(by_var[v]) for v in names}
    # Paired-seed check: every variant must have played the same seeds.
    seeds = {v: sorted((r["players"], r["seed"]) for r in by_var[v]) for v in names}
    paired = all(seeds[v] == seeds[base] for v in names)
    L = ["# P3-SEAT-v1 — seat compensation experiment", "",
         f"Rows: {len(rows)} · variants: {len(names)} · same seeds in every variant: **{paired}** · rules: {res[base]['rules_versions']}", ""]
    out = {"paired_seeds": paired, "variants": {}}
    for pc in sorted({int(r["players"]) for r in rows}):
        L += [f"## {pc} players", "",
              "| Variant | Win % by seat (Wilson 95%) | Spread (pp) | χ² p | Seat 0 vs baseline (pp, 95% CI) | Median min (95% CI) | Bankrupt matches | Net worth median (all seats) | Mean final cash by seat |",
              "|---|---|---|---|---|---|---|---|---|"]
        b = res[base]["by_players"][pc]
        for v in names:
            d = res[v]["by_players"][pc]
            wins = [s["pct"] for s in d["seat_win_pct"]]
            spread = round(max(wins) - min(wins), 1)
            n = d["n"]
            p0, pb = d["seat_win_pct"][0]["pct"] / 100, b["seat_win_pct"][0]["pct"] / 100
            lo, hi = diff_ci(p0, n, pb, b["n"])
            du = d["duration_min"]
            seat_txt = " / ".join(f"{s['pct']:.1f}" for s in d["seat_win_pct"])
            vs = "—" if v == base else f"{100 * (p0 - pb):+.1f} [{100 * lo:+.1f}, {100 * hi:+.1f}]"
            L.append(f"| {v} | {seat_txt} | {spread} | {d['seat_chi2_p']:.2g} | {vs} | {du['median']} ({du['median_ci95'][0]}–{du['median_ci95'][1]}) | "
                     f"{d['bankruptcy_match_pct']}% | {d.get('final_net_worth', {}).get('median', '?')} | {d.get('final_cash_mean_by_seat', '?')} |")
            out["variants"].setdefault(v, {})[pc] = {"seat_win_pct": d["seat_win_pct"], "spread_pp": spread,
                                                     "chi2_p": d["seat_chi2_p"], "seat0_vs_base_pp": [round(100 * (p0 - pb), 2), round(100 * lo, 2), round(100 * hi, 2)],
                                                     "duration_min": du, "bankruptcy_match_pct": d["bankruptcy_match_pct"],
                                                     "final_net_worth": d.get("final_net_worth"), "final_cash_mean_by_seat": d.get("final_cash_mean_by_seat"),
                                                     "final_net_worth_mean_by_seat": d.get("final_net_worth_mean_by_seat"),
                                                     "abnormal": len(d["abnormal"])}
        L.append("")
    md = "\n".join(L) + "\n"
    print(md)
    if a.md:
        open(a.md, "w").write(md)
    if a.json:
        json.dump(out, open(a.json, "w"), indent=2)


if __name__ == "__main__":
    main()
