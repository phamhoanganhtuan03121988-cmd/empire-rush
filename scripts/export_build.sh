#!/usr/bin/env bash
# Exports a device-test build with a build stamp (commit + time) that the
# in-app device panel and every device report show.
# Usage: scripts/export_build.sh ios|linux [debug|release]
#   GODOT=/path/to/Godot_v4.7.2-stable  (default: godot on PATH)
#   IOS_TEAM_ID=XXXXXXXXXX               (required for ios; never committed)
#   IOS_BUNDLE_ID=com.yourteam.empirerush (optional, default from preset)
# Needs the Godot 4.7.2 export templates installed. On Linux the iOS preset
# produces an Xcode project only; the .ipa must be built and signed on macOS.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-godot}"
TARGET="${1:?usage: export_build.sh ios|linux [debug|release]}"
MODE="${2:-debug}"
CLIENT="$ROOT/client"
PRESETS="$CLIENT/export_presets.cfg"

commit="$(git -C "$ROOT" rev-parse --short HEAD)"
dirty=""
git -C "$ROOT" diff --quiet HEAD -- client || dirty="-dirty"
printf '{"commit": "%s%s", "built_at": "%s", "target": "%s", "mode": "%s"}\n' \
	"$commit" "$dirty" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$TARGET" "$MODE" > "$CLIENT/data/build_info.json"

cp "$PRESETS" "$PRESETS.bak"
trap 'mv "$PRESETS.bak" "$PRESETS"' EXIT

case "$TARGET" in
	ios)
		: "${IOS_TEAM_ID:?set IOS_TEAM_ID (10-character Apple Developer Team ID)}"
		sed -i.tmp "s/^application\/app_store_team_id=.*/application\/app_store_team_id=\"$IOS_TEAM_ID\"/" "$PRESETS"
		if [ -n "${IOS_BUNDLE_ID:-}" ]; then
			sed -i.tmp "s/^application\/bundle_identifier=.*/application\/bundle_identifier=\"$IOS_BUNDLE_ID\"/" "$PRESETS"
		fi
		rm -f "$PRESETS.tmp"
		preset="iOS"; out="$ROOT/build/ios/EmpireRush.ipa" ;;
	linux)
		preset="Linux"; out="$ROOT/build/linux/EmpireRush.x86_64" ;;
	*) echo "unknown target $TARGET" >&2; exit 2 ;;
esac

mkdir -p "$(dirname "$out")"
"$GODOT" --headless --path "$CLIENT" --import >/dev/null 2>&1 || true
"$GODOT" --headless --path "$CLIENT" "--export-$MODE" "$preset" "$out"
echo "EXPORTED $preset ($MODE) commit=$commit$dirty -> $(dirname "$out")"
