#!/usr/bin/env bash
# Installs the Godot 4.7.2-stable Linux release export template only (CI
# release-lock check). Downloads the official .tpz, verifies the SHA-512 from
# the release's SHA512-SUMS.txt, extracts linux_release.x86_64 + version.txt.
# No iOS/macOS templates: iOS builds need macOS + Xcode.
set -euo pipefail
VERSION="4.7.2-stable"
TPZ="Godot_v${VERSION}_export_templates.tpz"
TPZ_SHA512="ca4d71c4d7b81dfc15d1a98baa07534aa95b03fdda78a0075b06672e1648d2e5f40980c9adc28d23e1b92e732ee7bf3461997aa804af74ec2fcd7a93ccb84079"
DEST="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/4.7.2.stable"
if [ -f "$DEST/linux_release.x86_64" ]; then
	echo "templates already installed in $DEST"
	exit 0
fi
TMP="$(mktemp -d)"
curl -fsSL --retry 4 -o "$TMP/$TPZ" "https://github.com/godotengine/godot/releases/download/${VERSION}/${TPZ}"
echo "$TPZ_SHA512  $TMP/$TPZ" | sha512sum -c -
mkdir -p "$DEST"
unzip -q -o "$TMP/$TPZ" templates/linux_release.x86_64 templates/version.txt -d "$TMP"
mv "$TMP/templates/linux_release.x86_64" "$TMP/templates/version.txt" "$DEST/"
rm -rf "$TMP"
echo "installed $(cat "$DEST/version.txt") linux_release.x86_64 -> $DEST"
