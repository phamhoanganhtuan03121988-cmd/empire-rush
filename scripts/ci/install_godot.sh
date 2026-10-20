#!/usr/bin/env bash
# Downloads the pinned Godot editor binary (Linux x86_64) used by CI and
# verifies it against the SHA-512 published in the official release's
# SHA512-SUMS.txt. Prints the binary path on the last line.
# Usage: scripts/ci/install_godot.sh [DEST_DIR]
set -euo pipefail

GODOT_VERSION="4.7.2-stable"
GODOT_ZIP="Godot_v${GODOT_VERSION}_linux.x86_64.zip"
GODOT_SHA512="9aa00f7a605200940bce3027a567b782f49bd8e940dd06ae9e987bd65aee1b1467edd56ed84fcdcbdd44354bf613bdbb4e5d2913e925850368e150c59ed54c65"
URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/${GODOT_ZIP}"
DEST="${1:-$HOME/.cache/godot/${GODOT_VERSION}}"
BIN="$DEST/Godot_v${GODOT_VERSION}_linux.x86_64"

if [ ! -x "$BIN" ]; then
	mkdir -p "$DEST"
	curl -fsSL --retry 4 -o "$DEST/$GODOT_ZIP" "$URL"
	echo "$GODOT_SHA512  $DEST/$GODOT_ZIP" | sha512sum -c -
	unzip -q -o "$DEST/$GODOT_ZIP" -d "$DEST"
	rm -f "$DEST/$GODOT_ZIP"
	chmod +x "$BIN"
fi
"$BIN" --headless --version >&2
echo "$BIN"
