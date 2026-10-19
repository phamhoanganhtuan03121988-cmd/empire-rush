#!/usr/bin/env bash
# Collects this machine's EMPIRE RUSH playtest data (Phase 4) into a folder
# that is safe to share: match telemetry (+ replay records), device reports
# and the engine log, REDACTED by privacy_scan.py (home paths, e-mails,
# IP addresses, tokens; tester names with --names). Originals are untouched.
# Usage: ./collect_playtest_data.sh [OUT_DIR] [--names "An,Binh"]
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="${1:-$HERE/playtest_data_$(date +%Y%m%d_%H%M%S)}"
NAMES="${3:-}"
[ "${2:-}" = "--names" ] || NAMES=""
UD="${XDG_DATA_HOME:-$HOME/.local/share}/godot/app_userdata/Empire Rush"
RAW="$(mktemp -d)"
trap 'rm -rf "$RAW"' EXIT
for d in telemetry device_validation logs; do
	[ -d "$UD/$d" ] && cp -r "$UD/$d" "$RAW/"
done
if [ -z "$(ls -A "$RAW")" ]; then echo "No data found in $UD"; exit 1; fi
SCAN="$HERE/privacy_scan.py"
[ -f "$SCAN" ] || SCAN="$HERE/analysis/privacy_scan.py"
python3 "$SCAN" "$RAW" --redact "$OUT" --names "$NAMES"
echo "Collected (redacted) into: $OUT"
echo "Check screenshots by eye before sharing. Do not add names, phone numbers or e-mails to the forms."
