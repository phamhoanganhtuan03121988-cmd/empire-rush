#!/usr/bin/env bash
# M2.3 playtest batch: bot matches for 2/3/4 players -> CSV + JSON + summary.md.
# Usage: scripts/run_playtest_batch.sh --out=/abs/dir [--players=2,3,4] [--matches=100] [--seed=1] [--mode=fast|debug] [--repro=10]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-godot}"
TIMEOUT_SECS="${SIM_TIMEOUT_SECS:-900}"
LOG_DIR="$ROOT/logs"
mkdir -p "$LOG_DIR"

"$GODOT" --version
timeout "$TIMEOUT_SECS" "$GODOT" --headless --path "$ROOT/client" --import > "$LOG_DIR/import.log" 2>&1
timeout "$TIMEOUT_SECS" "$GODOT" --headless --path "$ROOT/client" \
	--script res://tests/sim/run_playtest_batch.gd -- "$@" 2>&1 | tee "$LOG_DIR/playtest_batch.log"
exit "${PIPESTATUS[0]}"
