#!/usr/bin/env bash
# Builds the internal playtest package (Phase 4) for Linux x86_64 desktops:
#   1. exports the "Linux Internal Test" release build (device tools on,
#      telemetry + replay record on; no tests/ or tools/ inside);
#   2. smoke-tests THE EXPORTED BINARY: a full autoplay match must end, write
#      telemetry with a replay record, replay to the same final state, and
#      pass the privacy scan;
#   3. assembles build/playtest/EmpireRush-playtest-<commit>/ with the game,
#      a Vietnamese quick start, forms, the data-collection script and
#      SHA-256 sums, and a .tar.gz of it.
# Usage: GODOT=/path/to/godot scripts/make_playtest_package.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-godot}"
commit="$(git -C "$ROOT" rev-parse --short HEAD)"
"$ROOT/scripts/export_build.sh" linux internal release
BIN="$ROOT/build/linux-internal/EmpireRush.x86_64"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "== smoke test of the exported binary"
timeout 600 "$BIN" --headless -- --players=2 --seed=5 --autoplay --timescale=10 --quit-on-end \
	--telemetry=user://telemetry/package_smoke.json > "$WORK/smoke.log" 2>&1 || { tail -20 "$WORK/smoke.log"; echo "SMOKE FAILED"; exit 1; }
UD="${XDG_DATA_HOME:-$HOME/.local/share}/godot/app_userdata/Empire Rush"
TEL="$UD/telemetry/package_smoke.json"
[ -f "$TEL" ] || { echo "no telemetry written"; exit 1; }
cp "$TEL" "$WORK/"
"$GODOT" --headless --path "$ROOT/client" --script res://tools/replay_match.gd -- --file="$WORK/package_smoke.json" \
	| grep -q "MATCHES the recorded final state" || { echo "REPLAY MISMATCH"; exit 1; }
python3 "$ROOT/scripts/analysis/privacy_scan.py" "$WORK" > "$WORK/privacy.txt" || { cat "$WORK/privacy.txt"; exit 1; }
rm -f "$TEL"
echo "smoke OK: match ended, replay matches, privacy scan clean"

NAME="EmpireRush-playtest-$commit"
OUT="$ROOT/build/playtest/$NAME"
rm -rf "$OUT"; mkdir -p "$OUT/forms"
cp "$ROOT/build/linux-internal/"EmpireRush.* "$OUT/"
cp "$ROOT/docs/device/feedback_form_template.csv" "$ROOT/docs/device/playtest_log_template.csv" \
	"$ROOT/docs/playtest/BUG_REPORT_TEMPLATE.md" "$OUT/forms/"
cp "$ROOT/docs/PHASE4_PLAYTEST_GUIDE.md" "$OUT/HUONG_DAN_PLAYTEST.md"
cp "$ROOT/scripts/collect_playtest_data.sh" "$ROOT/scripts/analysis/privacy_scan.py" "$OUT/"
cat > "$OUT/BAT_DAU_O_DAY.txt" <<TXT
EMPIRE RUSH — bản thử nội bộ ($commit)

1. Mở terminal trong thư mục này và chạy:   ./EmpireRush.x86_64
   (lần đầu có thể cần:  chmod +x EmpireRush.x86_64)
2. Ở màn hình đầu: chọn số người chơi (bạn + máy), nhân vật, bấm BẮT ĐẦU.
   Bấm CÁCH CHƠI nếu chưa biết luật.
3. Chơi đến hết trận (khoảng 15–20 phút), hoặc dừng khi muốn — dừng sớm cũng là thông tin hữu ích.
4. Sau buổi chơi, người điều phối chạy:   ./collect_playtest_data.sh
   Script gom tệp ghi trận và xoá thông tin cá nhân trước khi gửi.

Trò chơi KHÔNG gửi gì qua mạng. Chi tiết: HUONG_DAN_PLAYTEST.md
TXT
( cd "$OUT" && sha256sum EmpireRush.* BAT_DAU_O_DAY.txt HUONG_DAN_PLAYTEST.md collect_playtest_data.sh privacy_scan.py forms/* > SHA256SUMS )
tar -C "$ROOT/build/playtest" -czf "$ROOT/build/playtest/$NAME-linux-x86_64.tar.gz" "$NAME"
echo "PACKAGE $ROOT/build/playtest/$NAME-linux-x86_64.tar.gz"
