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
timeout "$TIMEOUT_SECS" "$GODOT" --headless --path "$ROOT/client" \
	--script res://tests/test_runner.gd 2>&1 | tee "$LOG_DIR/tests.log"
exit "${PIPESTATUS[0]}"
