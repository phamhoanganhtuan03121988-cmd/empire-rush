#!/usr/bin/env bash
# Exports a build with a build stamp (commit + time) that the in-app device
# panel and every device report show.
# Usage: scripts/export_build.sh ios|linux internal|public [debug|release]
#   internal  = "... Internal Test" preset: custom feature "device_tools", so
#               the device panel, reports and telemetry files exist even in a
#               release build (for device measurements).
#   public    = "... Public Release" preset: no device tools. Only allowed
#               with release mode, because any debug build enables the tools.
#   GODOT=/path/to/Godot_v4.7.2-stable  (default: godot on PATH)
#   IOS_TEAM_ID=XXXXXXXXXX               (required for ios; never committed)
#   IOS_BUNDLE_ID=com.yourteam.empirerush (optional, default from preset)
# Needs the Godot 4.7.2 export templates installed. On Linux the iOS presets
# produce an Xcode project only; the .ipa must be built and signed on macOS.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-godot}"
USAGE="usage: export_build.sh ios|linux internal|public [debug|release]"
TARGET="${1:?$USAGE}"
FLAVOR="${2:?$USAGE}"
MODE="${3:-release}"
CLIENT="$ROOT/client"
PRESETS="$CLIENT/export_presets.cfg"

case "$FLAVOR" in
	internal) flavor_name="Internal Test" ;;
	public)
		flavor_name="Public Release"
		if [ "$MODE" != "release" ]; then
			echo "public builds must be release builds (debug builds enable the device tools)" >&2
			exit 2
		fi ;;
	*) echo "$USAGE" >&2; exit 2 ;;
esac
case "$MODE" in debug|release) ;; *) echo "$USAGE" >&2; exit 2 ;; esac

commit="$(git -C "$ROOT" rev-parse --short HEAD)"
dirty=""
git -C "$ROOT" diff --quiet HEAD -- client || dirty="-dirty"
printf '{"commit": "%s%s", "built_at": "%s", "target": "%s", "flavor": "%s", "mode": "%s"}\n' \
	"$commit" "$dirty" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$TARGET" "$FLAVOR" "$MODE" > "$CLIENT/data/build_info.json"

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
		preset="iOS $flavor_name"; out="$ROOT/build/ios-$FLAVOR/EmpireRush.ipa" ;;
	linux)
		preset="Linux $flavor_name"; out="$ROOT/build/linux-$FLAVOR/EmpireRush.x86_64" ;;
	*) echo "$USAGE" >&2; exit 2 ;;
esac

mkdir -p "$(dirname "$out")"
"$GODOT" --headless --path "$CLIENT" --import >/dev/null 2>&1 || true
"$GODOT" --headless --path "$CLIENT" "--export-$MODE" "$preset" "$out"
echo "EXPORTED $preset ($MODE) commit=$commit$dirty -> $(dirname "$out")"
