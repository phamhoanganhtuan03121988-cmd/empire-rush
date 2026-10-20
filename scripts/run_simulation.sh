#!/usr/bin/env bash
# Runs the batch match simulation with a hard timeout.
# Usage: scripts/run_simulation.sh [--matches=100] [--players=2,3,4] [--seed=1] [--out=/abs/path.json] [--summary=1] [--idle=3]
#        (uses $GODOT or `godot` on PATH; use an absolute --out path)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-godot}"
TIMEOUT_SECS="${SIM_TIMEOUT_SECS:-900}"
LOG_DIR="$ROOT/logs"
mkdir -p "$LOG_DIR"

"$GODOT" --version
timeout "$TIMEOUT_SECS" "$GODOT" --headless --path "$ROOT/client" --import > "$LOG_DIR/import.log" 2>&1
timeout "$TIMEOUT_SECS" "$GODOT" --headless --path "$ROOT/client" \
	--script res://tests/sim/run_simulation.gd -- "$@" 2>&1 | tee "$LOG_DIR/simulation.log"
exit "${PIPESTATUS[0]}"
