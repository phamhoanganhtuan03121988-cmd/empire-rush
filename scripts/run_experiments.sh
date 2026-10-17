#!/usr/bin/env bash
# Runs a balance-experiment spec (see client/tests/sim/run_experiments.gd) with a hard timeout.
# Usage: scripts/run_experiments.sh --spec=res://tests/sim/experiments/<name>.json [--out=/abs/path.json]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-godot}"
TIMEOUT_SECS="${SIM_TIMEOUT_SECS:-3600}"
LOG_DIR="$ROOT/logs"
mkdir -p "$LOG_DIR"

"$GODOT" --version
timeout "$TIMEOUT_SECS" "$GODOT" --headless --path "$ROOT/client" --import > "$LOG_DIR/import.log" 2>&1
timeout "$TIMEOUT_SECS" "$GODOT" --headless --path "$ROOT/client" \
	--script res://tests/sim/run_experiments.gd -- "$@" 2>&1 | tee "$LOG_DIR/experiments.log"
exit "${PIPESTATUS[0]}"
