#!/usr/bin/env bash
# Multi-process multiplayer end-to-end tests (see scripts/net_e2e.py).
# Usage: GODOT=/path/to/godot scripts/run_net_e2e.sh OUT_DIR [scenario ...]
#   default scenarios: chaos concurrent (what CI runs)
#   all: chaos concurrent sequential client_restart abandon tls tls_bad_ca netem lan
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-godot}"
"$GODOT" --headless --path "$ROOT/client" --import >/dev/null 2>&1 || true
exec python3 "$ROOT/scripts/net_e2e.py" "$@"
