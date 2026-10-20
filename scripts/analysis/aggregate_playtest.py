#!/usr/bin/env python3
"""Anonymous aggregation of human playtest sessions (Phase 2, B3).

Inputs (any number of each; only files the facilitator really collected):
  --logs       event logs  (docs/device/playtest_log_template.csv format)
  --forms      answer sheets (docs/device/feedback_form_template.csv format)
  --telemetry  session_*.json files copied from the phone (internal builds)

Output: a Markdown summary (stdout or --md) and optional JSON (--json).
Anonymisation:
  - tester codes are replaced by T01, T02... in order of first appearance;
  - device model, iOS version and free-text quotes are NOT copied unless
    --include-quotes is given (quotes are then shown without tester codes);
  - telemetry files are matched to sessions only by session_id, never by name.
Sessions whose source is not "human" (autopilot / bench) are excluded from
human metrics and listed separately, so bot runs can never be mistaken for
playtest results.

  python3 scripts/analysis/aggregate_playtest.py --logs a.csv b.csv --forms f.csv --telemetry t/*.json --md out.md
  python3 scripts/analysis/aggregate_playtest.py --self-test   # checks the tool with generated data, prints nothing as results
"""
import argparse
import csv
import json
import statistics
import sys
from collections import Counter, defaultdict

EVENT_CODES = ["CONFUSED", "MISTAP", "WAIT", "BORED", "DELIGHT", "BUG"]
QUESTIONS = [f"q{i}" for i in range(1, 11)]
SCALE_QUESTIONS = ["q1", "q2", "q3", "q4", "q6", "q7", "q8"]  # 1-5 answers


def _read_csv(paths):
    rows = []
    for p in paths or []:
        with open(p, newline="", encoding="utf-8") as f:
            rows.extend(csv.DictReader(f))
    return rows


def _q(vals, q):
    s = sorted(vals)
    if not s:
        return None
    return s[min(len(s) - 1, max(0, int(-(-q * len(s) // 1)) - 1))]


def aggregate(logs, forms, telemetry, include_quotes=False):
    alias = {}

    def anon(code):
        code = (code or "").strip()
        if code not in alias:
            alias[code] = "T%02d" % (len(alias) + 1)
        return alias[code]

    out = {"sessions": {}, "excluded_non_human": [], "warnings": []}
    for r in logs:
        sid = r.get("session_id", "").strip()
        if not sid:
            out["warnings"].append("log row without session_id skipped")
            continue
        s = out["sessions"].setdefault(sid, {"tester": anon(r.get("tester_code")), "events": Counter(),
                                             "by_phase": defaultdict(Counter), "quotes": [], "orientation": r.get("orientation", ""),
                                             "bots": r.get("bots", "")})
        code = r.get("event_code", "").strip().upper()
        if code not in EVENT_CODES:
            out["warnings"].append(f"unknown event code '{code}' in session {sid}")
            continue
        s["events"][code] += 1
        s["by_phase"][r.get("phase", "").strip() or "?"][code] += 1
        if include_quotes and r.get("quote", "").strip():
            s["quotes"].append({"code": code, "phase": r.get("phase", ""), "quote": r["quote"].strip()})
    answers = defaultdict(list)
    stopped = []
    for r in forms:
        sid = r.get("session_id", "").strip()
        anon(r.get("tester_code"))
        for q in SCALE_QUESTIONS:
            v = (r.get(q) or "").strip()
            if v:
                try:
                    n = int(v)
                except ValueError:
                    out["warnings"].append(f"{sid} {q}: '{v}' is not 1-5")
                    continue
                if 1 <= n <= 5:
                    answers[q].append(n)
                else:
                    out["warnings"].append(f"{sid} {q}: {n} outside 1-5")
        if (r.get("finished") or "").strip().lower() in ("no", "khong", "không", "0", "false"):
            stopped.append({"round": r.get("stopped_round", ""), "reason": r.get("stopped_reason", "") if include_quotes else ""})
    tel = []
    for t in telemetry:
        if t.get("source", "human") != "human":
            out["excluded_non_human"].append(t.get("source"))
            continue
        tel.append(t)
    mins = [t["session_game_seconds"] / 60 for t in tel if "session_game_seconds" in t]
    human_turn = [t["mean_turn_s"]["human"] for t in tel if t.get("mean_turn_s", {}).get("human")]
    wait_round = []
    for t in tel:
        per_round = defaultdict(float)
        for turn in t.get("turn_log", []):
            if not turn.get("human"):
                per_round[turn["round"]] += turn.get("duration_s", 0.0)
        if per_round:
            wait_round.append(statistics.mean(per_round.values()))
    totals = Counter()
    phase_tot = defaultdict(Counter)
    for s in out["sessions"].values():
        totals.update(s["events"])
        for ph, c in s["by_phase"].items():
            phase_tot[ph].update(c)
    out["summary"] = {
        "testers": len([a for a in alias if a]),
        "sessions_logged": len(out["sessions"]),
        "telemetry_sessions": len(tel),
        "match_minutes": {"n": len(mins), "median": _q(mins, 0.5), "p90": _q(mins, 0.9)},
        "human_mean_turn_s": statistics.mean(human_turn) if human_turn else None,
        "bot_wait_per_round_s": statistics.mean(wait_round) if wait_round else None,
        "event_totals": dict(totals),
        "events_by_phase": {k: dict(v) for k, v in phase_tot.items()},
        "answers": {q: {"n": len(v), "mean": round(statistics.mean(v), 2), "dist": dict(Counter(v))} for q, v in answers.items()},
        "stopped_early": stopped,
    }
    if include_quotes:
        out["summary"]["quotes"] = [q for s in out["sessions"].values() for q in s["quotes"]]
    for s in out["sessions"].values():
        s["events"] = dict(s["events"])
        s["by_phase"] = {k: dict(v) for k, v in s["by_phase"].items()}
    return out


def to_markdown(a):
    s = a["summary"]
    L = ["# Playtest summary (anonymous)", "",
         f"- Testers: {s['testers']} · sessions with an event log: {s['sessions_logged']} · telemetry sessions (human): {s['telemetry_sessions']}",
         f"- Excluded non-human telemetry (autopilot / bench): {len(a['excluded_non_human'])}"]
    m = s["match_minutes"]
    if m["n"]:
        L.append(f"- Match length: median {m['median']:.1f} min, P90 {m['p90']:.1f} min (n={m['n']})")
    if s["human_mean_turn_s"] is not None:
        L.append(f"- Human mean turn: {s['human_mean_turn_s']:.1f} s · bot wait per round: {s['bot_wait_per_round_s'] or 0:.1f} s")
    L += ["", "| Event | Count |", "|---|---|"] + [f"| {k} | {s['event_totals'].get(k, 0)} |" for k in EVENT_CODES]
    if s["events_by_phase"]:
        L += ["", "| Phase | " + " | ".join(EVENT_CODES) + " |", "|---|" + "---|" * len(EVENT_CODES)]
        for ph, c in sorted(s["events_by_phase"].items()):
            L.append(f"| {ph} | " + " | ".join(str(c.get(k, 0)) for k in EVENT_CODES) + " |")
    if s["answers"]:
        L += ["", "| Question | n | mean (1-5) | distribution |", "|---|---|---|---|"]
        for q in SCALE_QUESTIONS:
            if q in s["answers"]:
                x = s["answers"][q]
                L.append(f"| {q} | {x['n']} | {x['mean']} | {x['dist']} |")
    L.append(f"\nStopped early: {len(s['stopped_early'])} session(s).")
    if a["warnings"]:
        L += ["", "Warnings:"] + [f"- {w}" for w in a["warnings"]]
    return "\n".join(L) + "\n"


def self_test():
    """Exercises the tool with data generated here (never written to disk)."""
    logs = [{"session_id": "S1", "tester_code": "alice-real-name", "event_code": "CONFUSED", "phase": "buy", "quote": "secret"},
            {"session_id": "S1", "tester_code": "alice-real-name", "event_code": "WAIT", "phase": "auction", "quote": ""},
            {"session_id": "S2", "tester_code": "bob", "event_code": "DELIGHT", "phase": "event", "quote": ""},
            {"session_id": "S2", "tester_code": "bob", "event_code": "NOPE", "phase": "event", "quote": ""}]
    forms = [{"session_id": "S1", "tester_code": "alice-real-name", "q1": "4", "q2": "2", "finished": "yes"},
             {"session_id": "S2", "tester_code": "bob", "q1": "5", "q2": "9", "finished": "no", "stopped_round": "12"}]
    tel = [{"source": "human", "session_game_seconds": 1200, "mean_turn_s": {"human": 9.0, "bot": 5.0},
            "turn_log": [{"round": 1, "human": False, "duration_s": 6.0}, {"round": 1, "human": False, "duration_s": 4.0}]},
           {"source": "autopilot", "session_game_seconds": 600}]
    a = aggregate(logs, forms, tel)
    md = to_markdown(a)
    assert "alice" not in md and "bob" not in md and "secret" not in md, "anonymisation"
    assert a["summary"]["testers"] == 2
    assert a["summary"]["event_totals"] == {"CONFUSED": 1, "WAIT": 1, "DELIGHT": 1}
    assert a["summary"]["answers"]["q1"]["mean"] == 4.5 and a["summary"]["answers"]["q2"]["n"] == 1
    assert len(a["warnings"]) == 2, a["warnings"]
    assert a["excluded_non_human"] == ["autopilot"] and a["summary"]["telemetry_sessions"] == 1
    assert a["summary"]["bot_wait_per_round_s"] == 10.0
    assert len(a["summary"]["stopped_early"]) == 1
    print("SELF_TEST PASS (generated data only; nothing written)")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--logs", nargs="*")
    ap.add_argument("--forms", nargs="*")
    ap.add_argument("--telemetry", nargs="*")
    ap.add_argument("--include-quotes", action="store_true")
    ap.add_argument("--md")
    ap.add_argument("--json")
    ap.add_argument("--self-test", action="store_true")
    a = ap.parse_args()
    if a.self_test:
        self_test()
        return
    if not (a.logs or a.forms or a.telemetry):
        sys.exit("no input files: nothing to aggregate (never fill these with invented data)")
    tel = []
    for p in a.telemetry or []:
        with open(p, encoding="utf-8") as f:
            tel.append(json.load(f))
    res = aggregate(_read_csv(a.logs), _read_csv(a.forms), tel, a.include_quotes)
    md = to_markdown(res)
    if a.md:
        with open(a.md, "w", encoding="utf-8") as f:
            f.write(md)
    else:
        print(md)
    if a.json:
        with open(a.json, "w", encoding="utf-8") as f:
            json.dump(res, f, indent=2, ensure_ascii=False)


if __name__ == "__main__":
    main()
