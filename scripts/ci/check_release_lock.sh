#!/usr/bin/env bash
# Exports the Linux "Public Release" and "Internal Test" presets (release mode)
# and runs both binaries headless with every device-tool flag. Fails if the
# public build writes any device report / telemetry file, or if the internal
# build does not (the tools must stay available for internal testing).
# Needs the Godot 4.7.2 export templates (linux_release.x86_64) installed.
# Usage: GODOT=/path/to/godot scripts/ci/check_release_lock.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GODOT="${GODOT:-godot}"
UD="${XDG_DATA_HOME:-$HOME/.local/share}/godot/app_userdata/Empire Rush"

"$ROOT/scripts/export_build.sh" linux public release
"$ROOT/scripts/export_build.sh" linux internal release

check() {
	local flavor="$1" expect="$2"
	rm -rf "$UD/device_validation" "$UD/telemetry"
	timeout 120 "$ROOT/build/linux-$flavor/EmpireRush.x86_64" --headless -- \
		--players=2 --seed=5 --perf --devpanel --bench=1 --bench-quit \
		--telemetry=user://telemetry/ci.json --stats=400 > "$ROOT/logs/release_lock_$flavor.log" 2>&1 || true
	local files
	files="$( (find "$UD/device_validation" "$UD/telemetry" -type f 2>/dev/null || true) | wc -l)"
	echo "$flavor build: $files device/telemetry files (expect $expect)"
	if [ "$expect" = "none" ] && [ "$files" -ne 0 ]; then
		echo "FAIL: public release wrote device tools output" >&2; exit 1
	fi
	if [ "$expect" = "some" ] && [ "$files" -eq 0 ]; then
		echo "FAIL: internal build has no device tools output" >&2; exit 1
	fi
}
mkdir -p "$ROOT/logs"
check public none
check internal some
echo "RELEASE LOCK OK"
