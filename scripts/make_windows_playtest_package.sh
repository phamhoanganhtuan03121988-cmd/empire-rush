#!/usr/bin/env bash
# Builds the Windows x64 playtest ZIP for people who do not program:
#   dist/windows-playtest/                       folder that goes into the ZIP
#   dist/EMPIRE_RUSH_Windows_Playtest_x64.zip    the file to download
# Contents: EmpireRush.exe (Internal Test, release, game data embedded: no
# Godot, Python or other tool needed), README_PLAYTEST_VI.md, the quick rules guide (HUONG_DAN_NHANH.md), a short
# quick-start .txt, build info, the feedback/bug forms, a .bat that opens the
# match-record folder, and SHA256SUMS.txt. No source code, tests, tools, .git,
# editor or secrets.
# Steps that fail stop the script and no ZIP is written:
#   clean working tree (the ZIP name and build info carry the commit;
#   ALLOW_DIRTY=1 for local experiments only), export, content checks
#   (PE x86-64, rules data inside, no tests/tools), privacy scan of every
#   text file and of the strings inside the .exe.
# The .exe itself is tested on a real Windows runner by
# .github/workflows/windows-playtest.yml (this script runs on Linux).
# Usage: GODOT=/path/to/godot scripts/make_windows_playtest_package.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-godot}"
commit="$(git -C "$ROOT" rev-parse --short HEAD)"
if [ -n "$(git -C "$ROOT" status --porcelain)" ] && [ "${ALLOW_DIRTY:-0}" != "1" ]; then
	git -C "$ROOT" status --short
	echo "REFUSED: uncommitted changes; commit first so the ZIP matches $commit"
	exit 1
fi
# Reproducible: the stamp and every ZIP date come from the commit, so a CI
# build and a local build of the same commit give the same bytes.
BUILD_TIME="$(TZ=UTC0 git -C "$ROOT" log -1 --format=%cd --date=format-local:%Y-%m-%dT%H:%M:%SZ)"
export BUILD_TIME
"$ROOT/scripts/export_build.sh" windows internal release
EXE="$ROOT/build/windows-internal/EmpireRush.exe"
SCAN="$ROOT/scripts/analysis/privacy_scan.py"

echo "== content checks"
file "$EXE" | grep -q "PE32+ executable (GUI) x86-64" || { file "$EXE"; echo "NOT A WINDOWS x64 GUI EXE"; exit 1; }
grep -qa "data/rules/balance.json" "$EXE" || { echo "rules data missing from the .exe"; exit 1; }
if grep -qaE "tests/test_runner|tools/replay_match" "$EXE"; then echo "tests/tools packed into the .exe"; exit 1; fi
stamp="$(grep -ao '"commit": "[^"]*"' "$EXE" | head -1)"
[ "$stamp" = "\"commit\": \"$commit\"" ] || [ "${ALLOW_DIRTY:-0}" = "1" ] || { echo "build stamp $stamp != $commit"; exit 1; }
echo "PE x86-64 GUI, rules data inside, no tests/tools, build stamp $stamp"

OUT="$ROOT/dist/windows-playtest"
ZIP="$ROOT/dist/EMPIRE_RUSH_Windows_Playtest_x64.zip"
rm -rf "$OUT" "$ZIP"
mkdir -p "$OUT/forms"
cp "$EXE" "$OUT/EmpireRush.exe"
{ printf '\xef\xbb\xbf'; sed 's/$/\r/' "$ROOT/docs/windows/README_PLAYTEST_VI.md"; } > "$OUT/README_PLAYTEST_VI.md"
{ printf '\xef\xbb\xbf'; sed 's/$/\r/' "$ROOT/docs/HUONG_DAN_NHANH.md"; } > "$OUT/HUONG_DAN_NHANH.md"
cp "$ROOT/docs/device/feedback_form_template.csv" "$OUT/forms/phieu_phan_hoi.csv"
{ printf '\xef\xbb\xbf'; sed 's/$/\r/' "$ROOT/docs/playtest/BUG_REPORT_TEMPLATE.md"; } > "$OUT/forms/mau_bao_loi.txt"
# UTF-8 with BOM and CRLF, so Notepad shows the Vietnamese text and lines.
{ printf '\xef\xbb\xbf'; sed 's/$/\r/' <<TXT
EMPIRE RUSH — bản chơi thử trên Windows (x64), phiên bản $commit

1. Giải nén toàn bộ file ZIP (chuột phải > Extract All). Không chạy game bên trong file ZIP.
2. Nhấp đúp EmpireRush.exe.
   Nếu Windows hiện "Windows protected your PC": bấm "More info" > "Run anyway".
   (File chưa được ký số nên Windows cảnh báo; đây là bản chơi thử nội bộ.)
3. Lần đầu chơi: bấm HƯỚNG DẪN TỪNG BƯỚC (một trận thật, dạy từng thao tác).
   Hoặc CHƠI: chọn nhân vật (chân dung), tên, màu quân, vai trò (kỹ năng),
   số người, rồi BẮT ĐẦU. Gợi ý tự hiện khi gặp tình huống mới.
   Chuột trái cho mọi nút, Space tung xúc xắc (bấm lần nữa để bỏ qua
   hoạt cảnh), Esc tạm dừng. Âm lượng và gợi ý: CÀI ĐẶT.
   Luật tóm tắt: HUONG_DAN_NHANH.md (mở bằng Notepad).
4. Chơi xong: điền forms\\phieu_phan_hoi.csv (mở bằng Excel). Gặp lỗi: điền forms\\mau_bao_loi.txt.
   Nhấp đúp MO_DU_LIEU_TRAN_DAU.bat để mở thư mục ghi trận, gửi kèm các file session_*.json.

Chi tiết: README_PLAYTEST_VI.md (mở bằng Notepad).
TXT
} > "$OUT/BAT_DAU_O_DAY.txt"
sed 's/$/\r/' > "$OUT/MO_DU_LIEU_TRAN_DAU.bat" <<'BAT'
@echo off
rem Opens the folder with this computer's EMPIRE RUSH match records (telemetry).
rem The files hold seed, player codes p0..p3, moves and timings: no names, no account.
set "D=%APPDATA%\Godot\app_userdata\Empire Rush\telemetry"
if exist "%D%" (
  explorer "%D%"
) else (
  echo Chua co tran nao duoc ghi lai. Hay choi het mot tran truoc.
  echo No match record yet. Finish a match first.
  pause
)
BAT
sha="$(sha256sum "$EXE" | cut -d' ' -f1)"
sed 's/$/\r/' > "$OUT/BUILD_INFO.txt" <<TXT
EMPIRE RUSH - Windows playtest build
Source commit : $commit ($(git -C "$ROOT" rev-parse HEAD))
Branch        : $(git -C "$ROOT" rev-parse --abbrev-ref HEAD)
Commit time   : $BUILD_TIME
Engine        : Godot $("$GODOT" --headless --version 2>/dev/null | tail -1), official export template windows_release_x86_64.exe
Preset        : Windows Internal Test (release, device_tools on: match records + replay)
Format        : one self-contained .exe (data embedded), x86_64, not code-signed
Rules         : DRAFT v3, fingerprint d5e3a9a877afe932 (unchanged; V5 not applied)
EmpireRush.exe SHA-256: $sha
TXT
( cd "$OUT" && find . -type f ! -name SHA256SUMS.txt -printf '%P\n' | sort | xargs sha256sum > SHA256SUMS.txt )

echo "== privacy: package text files and strings inside the .exe"
python3 "$SCAN" "$OUT" || { echo "PACKAGE BLOCKED: privacy findings in $OUT (no ZIP written)"; exit 1; }
STR="$(mktemp -d)"
trap 'rm -rf "$STR" "$STR.report"' EXIT
# Scan only the strings that are NOT in the official template: that is the
# project part (embedded game data, icon, version info). The template itself
# is unmodified upstream code (its build paths and standard GUIDs are not ours).
TPL="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/4.7.2.stable/windows_release_x86_64.exe"
python3 - "$EXE" "$TPL" "$STR/exe_project_strings.txt" <<'PY'
import re, sys
words = lambda p: set(re.findall(rb"[\x20-\x7e]{6,}", open(p, "rb").read()))
extra = sorted(words(sys.argv[1]) - words(sys.argv[2]))
open(sys.argv[3], "w").write("\n".join(w.decode() for w in extra))
print(f"strings only in this .exe (project part): {len(extra)}")
PY
python3 "$SCAN" "$STR" > "$STR.report" || { cat "$STR.report"; echo "PACKAGE BLOCKED: privacy findings in the project part of the .exe"; exit 1; }
echo "exe project strings: $(tail -1 "$STR.report")"

python3 - "$OUT" "$ZIP" "$BUILD_TIME" <<'PY'
import os, sys, zipfile
src, dst, when = sys.argv[1], sys.argv[2], sys.argv[3]
stamp = tuple(int(x) for x in (when[0:4], when[5:7], when[8:10], when[11:13], when[14:16], when[17:19]))
paths = sorted(os.path.relpath(os.path.join(d, f), src) for d, _, fs in os.walk(src) for f in fs)
with zipfile.ZipFile(dst, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
    for rel in paths:
        info = zipfile.ZipInfo("EMPIRE_RUSH_Windows_Playtest_x64/" + rel.replace(os.sep, "/"), stamp)
        info.compress_type = zipfile.ZIP_DEFLATED
        info.external_attr = 0o644 << 16
        with open(os.path.join(src, rel), "rb") as fh:
            z.writestr(info, fh.read(), compresslevel=9)
with zipfile.ZipFile(dst) as z:
    bad = z.testzip()
    assert bad is None, bad
    print("ZIP entries:", len(z.namelist()))
PY
( cd "$ROOT/dist" && sha256sum EMPIRE_RUSH_Windows_Playtest_x64.zip > EMPIRE_RUSH_Windows_Playtest_x64.zip.sha256 )
echo "PACKAGE $ZIP ($(du -h "$ZIP" | cut -f1)) sha256 $(cut -d' ' -f1 "$ZIP.sha256")"
