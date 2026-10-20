#!/usr/bin/env bash
# Runs the Godot headless test suite with a hard timeout.
# Usage: scripts/run_tests.sh            (uses $GODOT or `godot` on PATH)
#        GODOT=/path/to/Godot_v4.7.2-stable_linux.x86_64 scripts/run_tests.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-godot}"
TIMEOUT_SECS="${TEST_TIMEOUT_SECS:-300}"
LOG_DIR="$ROOT/logs"
mkdir -p "$LOG_DIR"

"$GODOT" --version
# Import once so class_name scripts are registered before tests load.
timeout "$TIMEOUT_SECS" "$GODOT" --headless --path "$ROOT/client" --import 2>&1 | tee "$LOG_DIR/import.log"
set +e
timeout "$TIMEOUT_SECS" "$GODOT" --headless --path "$ROOT/client" \
	--script res://tests/test_runner.gd 2>&1 | tee "$LOG_DIR/tests.log"
status="${PIPESTATUS[0]}"
set -e
# GDScript runtime errors (and failed assert()s) do not abort the process, so a
# test could "pass" after one. Treat any of them as a failure.
if grep -qE "SCRIPT ERROR|Assertion failed|Parse Error" "$LOG_DIR/tests.log"; then
	echo "FAIL: script/assertion errors found in $LOG_DIR/tests.log" >&2
	exit 1
fi
[ "$status" -eq 0 ] || exit "$status"

# Compile every script (parse errors only surface when a script is loaded).
timeout "$TIMEOUT_SECS" "$GODOT" --headless --path "$ROOT/client" \
	--script res://tests/check_scripts.gd 2>&1 | tee "$LOG_DIR/check_scripts.log"
[ "${PIPESTATUS[0]}" -eq 0 ] || exit 1

# UI flow tests: boot the real scene headless and drive it through HUD buttons.
set +e
timeout "$TIMEOUT_SECS" "$GODOT" --headless --path "$ROOT/client" \
	--script res://tests/ui/ui_test_runner.gd 2>&1 | tee "$LOG_DIR/ui_tests.log"
status="${PIPESTATUS[0]}"
set -e
if grep -qE "SCRIPT ERROR|Assertion failed|Parse Error" "$LOG_DIR/ui_tests.log"; then
	echo "FAIL: script/assertion errors found in $LOG_DIR/ui_tests.log" >&2
	exit 1
fi
exit "$status"
