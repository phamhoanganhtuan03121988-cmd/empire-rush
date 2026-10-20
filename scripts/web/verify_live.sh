#!/usr/bin/env bash
# Checks that the live GitHub Pages site serves EXACTLY a given web build.
#   scripts/web/verify_live.sh DEPLOYED_DIR URL [EXPECTED_COMMIT]
# DEPLOYED_DIR: the files that were deployed (the github-pages artifact,
# unpacked). URL: the site, ending in "/". EXPECTED_COMMIT: short SHA that
# must appear in the build stamp inside index.pck (data/build_info.json).
# Waits for the Pages CDN to serve the new index.html (up to ~5 minutes), then:
# - every deployed file is served with HTTP 200 and the same SHA-256;
# - index.wasm is served as application/wasm;
# - markers of the latest changes are present in the live files: the iPhone
#   audio unlock in the page shell, the audio bus layout and the HUD sound
#   icon in the game data (mobile visual + audio pass);
# - the build stamp names the expected commit.
# Exit 0 only if everything matches. Prints a Markdown summary on stdout.
set -euo pipefail
DIR="$1"
URL="$2"
EXPECT="${3:-}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fail=0
note() { echo "$*"; }
sha() { sha256sum "$1" | cut -d' ' -f1; }

want_html="$(sha "$DIR/index.html")"
ok=0
for i in $(seq 1 30); do
	if curl -fsS -H 'Cache-Control: no-cache' "${URL}index.html?verify=$RANDOM" -o "$TMP/index.html" 2>/dev/null \
		&& [ "$(sha "$TMP/index.html")" = "$want_html" ]; then
		ok=1
		break
	fi
	sleep 10
done
if [ "$ok" != 1 ]; then
	note "FAIL index.html: the live page is not this build after 5 minutes"
	exit 1
fi

note "| File | HTTP | Size | SHA-256 live = deployed |"
note "|---|---|---|---|"
while IFS= read -r -d '' f; do
	rel="${f#"$DIR"/}"
	case "$rel" in .*) continue ;; esac
	code="$(curl -sS -o "$TMP/live" -w '%{http_code}' "${URL}${rel}")"
	if [ "$code" = 200 ] && [ "$(sha "$TMP/live")" = "$(sha "$f")" ]; then
		note "| \`$rel\` | $code | $(stat -c %s "$f") | yes |"
	else
		note "| \`$rel\` | $code | $(stat -c %s "$f") | **NO** |"
		fail=1
	fi
done < <(find "$DIR" -type f -print0 | sort -z)

ctype="$(curl -sS -o /dev/null -w '%{content_type}' "${URL}index.wasm")"
case "$ctype" in application/wasm*) note "" ; note "index.wasm content type: $ctype" ;; *) note "FAIL index.wasm content type: $ctype"; fail=1 ;; esac

curl -fsS "${URL}index.pck" -o "$TMP/index.pck"
check_marker() {  # file, text, meaning
	if grep -a -q -- "$2" "$1"; then note "- present: $3 (\`$2\`)"; else note "- **MISSING**: $3 (\`$2\`)"; fail=1; fi
}
note ""
note "Latest changes in the live files:"
check_marker "$TMP/index.html" "TrackedAudioContext" "iPhone audio unlock in the page shell"
check_marker "$TMP/index.pck" "default_bus_layout" "audio bus layout (web sound fix)"
check_marker "$TMP/index.pck" "sound_off.svg" "HUD sound on/off icon"
stamp="$(grep -a -o '"commit": "[^"]*"' "$TMP/index.pck" | head -n 1 | sed 's/.*: "\(.*\)"/\1/')"
note "- build stamp in the live game data: \`$stamp\`"
if [ -n "$EXPECT" ] && [ "${stamp%%-*}" != "${EXPECT:0:7}" ]; then
	note "- **expected commit ${EXPECT:0:7}**"
	fail=1
fi
exit "$fail"
