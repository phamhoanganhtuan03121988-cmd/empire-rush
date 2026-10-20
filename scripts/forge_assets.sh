#!/usr/bin/env bash
# Rebuilds the generated production kit (textures, materials, models) with the
# asset forge in client/tools/asset_forge/. Deterministic: same inputs give the
# same files. Two stages, with an import in between so materials can reference
# the imported textures.
# Usage: GODOT=/path/to/godot scripts/forge_assets.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-godot}"
"$GODOT" --headless --path "$ROOT/client" --import >/dev/null 2>&1 || true
"$GODOT" --headless --path "$ROOT/client" --script res://tools/asset_forge/forge.gd -- --stage=textures
"$GODOT" --headless --path "$ROOT/client" --import >/dev/null 2>&1 || true
"$GODOT" --headless --path "$ROOT/client" --script res://tools/asset_forge/forge.gd -- --stage=models
"$GODOT" --headless --path "$ROOT/client" --import >/dev/null 2>&1 || true
