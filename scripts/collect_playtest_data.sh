#!/usr/bin/env bash
# Collects this machine's EMPIRE RUSH playtest data (Phase 4) into a folder
# that is safe to share: match telemetry (+ replay records), device reports
# and the engine log, REDACTED by privacy_scan.py (home paths, e-mails,
# phone numbers, IP addresses, UUIDs, tokens; tester names with --names).
# Originals are untouched. Sharing stays BLOCKED (exit 3) while the data has
# images that nobody has looked at; re-run with --binaries-reviewed after
# checking them by eye.
# Usage: ./collect_playtest_data.sh [OUT_DIR] [--names "An,Binh"] [--binaries-reviewed]
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="$HERE/playtest_data_$(date +%Y%m%d_%H%M%S)"
NAMES=""
EXTRA=()
while [ $# -gt 0 ]; do
	case "$1" in
		--names) NAMES="${2:-}"; shift 2 ;;
		--binaries-reviewed) EXTRA+=(--binaries-reviewed); shift ;;
		*) OUT="$1"; shift ;;
	esac
done
UD="${XDG_DATA_HOME:-$HOME/.local/share}/godot/app_userdata/Empire Rush"
RAW="$(mktemp -d)"
trap 'rm -rf "$RAW"' EXIT
for d in telemetry device_validation logs; do
	[ -d "$UD/$d" ] && cp -r "$UD/$d" "$RAW/"
done
if [ -z "$(ls -A "$RAW")" ]; then echo "No data found in $UD"; exit 1; fi
SCAN="$HERE/privacy_scan.py"
[ -f "$SCAN" ] || SCAN="$HERE/analysis/privacy_scan.py"
set +e
python3 "$SCAN" "$RAW" --redact "$OUT" --names "$NAMES" "${EXTRA[@]}"
status=$?
set -e
case "$status" in
	0) echo "READY TO SHARE (redacted): $OUT"
	   echo "Do not add names, phone numbers or e-mails to the forms." ;;
	3) echo "NOT READY: check the images listed above by eye first: $OUT" ;;
	*) echo "NOT READY: privacy scan failed (status $status); do not share $OUT" ;;
esac
exit "$status"
