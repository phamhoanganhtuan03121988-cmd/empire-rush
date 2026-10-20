#!/usr/bin/env bash
# Installs Godot 4.7.2-stable release export templates (CI). Downloads the
# official .tpz, verifies the SHA-512 from the release's SHA512-SUMS.txt and
# extracts only the templates asked for, plus version.txt.
#   scripts/ci/install_templates.sh            -> linux_release.x86_64 (release-lock)
#   scripts/ci/install_templates.sh windows    -> + windows_release_x86_64.exe
#   scripts/ci/install_templates.sh web        -> + web_nothreads_release.zip
#     (single-threaded web: no SharedArrayBuffer, so no COOP/COEP headers
#     are needed - GitHub Pages cannot send them - and Safari/iOS runs it)
# No iOS/macOS templates: iOS builds need macOS + Xcode.
set -euo pipefail
VERSION="4.7.2-stable"
TPZ="Godot_v${VERSION}_export_templates.tpz"
TPZ_SHA512="ca4d71c4d7b81dfc15d1a98baa07534aa95b03fdda78a0075b06672e1648d2e5f40980c9adc28d23e1b92e732ee7bf3461997aa804af74ec2fcd7a93ccb84079"
DEST="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/4.7.2.stable"
WANT=(linux_release.x86_64)
for p in "$@"; do
	case "$p" in
		windows) WANT+=(windows_release_x86_64.exe) ;;
		web) WANT+=(web_nothreads_release.zip) ;;
		*) echo "unknown platform: $p" >&2; exit 2 ;;
	esac
done
missing=()
for f in "${WANT[@]}"; do [ -f "$DEST/$f" ] || missing+=("$f"); done
if [ "${#missing[@]}" -eq 0 ]; then
	echo "templates already installed in $DEST: ${WANT[*]}"
	exit 0
fi
TMP="$(mktemp -d)"
curl -fsSL --retry 4 -o "$TMP/$TPZ" "https://github.com/godotengine/godot/releases/download/${VERSION}/${TPZ}"
echo "$TPZ_SHA512  $TMP/$TPZ" | sha512sum -c -
mkdir -p "$DEST"
args=(templates/version.txt)
for f in "${missing[@]}"; do args+=("templates/$f"); done
unzip -q -o "$TMP/$TPZ" "${args[@]}" -d "$TMP"
for f in "${missing[@]}" version.txt; do mv "$TMP/templates/$f" "$DEST/"; done
rm -rf "$TMP"
echo "installed $(cat "$DEST/version.txt"): ${missing[*]} -> $DEST"
