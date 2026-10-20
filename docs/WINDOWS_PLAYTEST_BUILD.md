# EMPIRE RUSH — Bản chơi thử Windows x64

| | |
|---|---|
| Branch | `claude/windows-playtest-build`, tách từ `claude/phase4-playtest-release` @ `73ddd4a` (cuối Phase 4) |
| Commit nguồn của ZIP | `ca96df5` (ca96df5ea0bd6ea7e112fe22ef5d72b7e589691c) |
| File | `EMPIRE_RUSH_Windows_Playtest_x64.zip` (40 MB) |
| SHA-256 của ZIP | `1d7160327d08700539896b54f867493af5bea58ddaed438f799b0632f2b24f36` |
| SHA-256 của `EmpireRush.exe` | `6824c544ddfbbb0b0ac331b563b98d37ad4e8d7642a77dcb522f5446636bd11a` |
| Engine | Godot 4.7.2-stable, export template chính thức `windows_release_x86_64.exe` (SHA-512 của gói template khớp SHA512-SUMS.txt của bản phát hành) |
| Không đổi | luật, balance (fingerprint `d5e3a9a877afe932`), tính năng, giao diện, dữ liệu. `main` không bị sửa, không merge |

## 1. Tải về
- **Cách 1 — file đính kèm** trong hội thoại Claude Code: `EMPIRE_RUSH_Windows_Playtest_x64.zip`.
- **Cách 2 — GitHub Actions** (workflow `windows-playtest`, run #2 của commit `ca96df5`):
  1. Link trực tiếp: <https://github.com/phamhoanganhtuan03121988-cmd/empire-rush/actions/runs/39218066295/artifacts/12170177936>
     - artifact `EMPIRE_RUSH_Windows_Playtest_x64`, id `12170177936`;
     - hết hạn 2026-11-18.
  2. Hoặc mở <https://github.com/phamhoanganhtuan03121988-cmd/empire-rush/actions/runs/39218066295>, mục **Artifacts**.
  3. Cần đăng nhập GitHub bằng tài khoản có quyền đọc repo (repo private). Artifact tự xoá sau 30 ngày.
  4. GitHub nén thư mục thành một file ZIP; bên trong là các file của gói, không có thư mục bọc ngoài.

Hai cách cho **cùng nội dung**: bản export tái lập được (§4). SHA-256 của `EmpireRush.exe` trong `BUILD_INFO.txt` / `SHA256SUMS.txt` phải là `6824c544…`.

## 2. Cách chạy (người không biết lập trình)
1. Chuột phải file ZIP → **Extract All…** → **Extract**.
2. Nhấp đúp **`EmpireRush.exe`**.
3. Nếu hiện **"Windows protected your PC"**: bấm **More info** → **Run anyway**. File **chưa ký số** nên SmartScreen (và có thể phần mềm diệt virus) cảnh báo.
4. Ở màn hình đầu: chọn số người chơi, nhân vật, đồ hoạ (máy yếu chọn Thấp), có thể bật Giảm chuyển động → **BẮT ĐẦU**. **CÁCH CHƠI** mở luật ngắn. Mọi thao tác dùng chuột trái.
5. Phản hồi: `forms\phieu_phan_hoi.csv`; báo lỗi: `forms\mau_bao_loi.txt`; file ghi trận: nhấp đúp `MO_DU_LIEU_TRAN_DAU.bat`.

Chi tiết: `README_PLAYTEST_VI.md` trong gói (nguồn: `docs/windows/README_PLAYTEST_VI.md`).

## 3. Nội dung gói
| File | |
|---|---|
| `EmpireRush.exe` | Game, một file duy nhất (dữ liệu nhúng bên trong), x86_64, preset **Windows Internal Test**: có ghi trận + replay để báo lỗi |
| `BAT_DAU_O_DAY.txt` | Hướng dẫn 4 bước (UTF-8 có BOM để Notepad hiện đúng dấu) |
| `README_PLAYTEST_VI.md` | Hướng dẫn đầy đủ |
| `BUILD_INFO.txt` | Commit, engine, preset, SHA-256 |
| `MO_DU_LIEU_TRAN_DAU.bat` | Mở `%APPDATA%\Godot\app_userdata\Empire Rush\telemetry` |
| `forms\phieu_phan_hoi.csv`, `forms\mau_bao_loi.txt` | Phiếu phản hồi, mẫu báo lỗi |
| `SHA256SUMS.txt` | Mã kiểm tra mọi file |

**Không có trong gói:**
- mã nguồn, `.git`, thư mục `tests/` và `tools/`;
- Godot Editor;
- token, khoá, session, dữ liệu thử nghiệm.

Script kiểm tra: rules data có trong exe, không có test/tools. Quét quyền riêng tư:
- mọi file chữ trong gói;
- 5.051 chuỗi chỉ có trong exe này mà không có trong template chính thức (tức phần của dự án).

Kết quả: CLEAN.

## 4. Build tái lập được
**Lỗi tìm thấy:** Godot 4.7 gán cho node gốc của `main.tscn` một id **ngẫu nhiên** ở mỗi lần import mới. Hậu quả: hai bản build cùng commit lệch nhau 20 byte, nên không chứng minh được ZIP gửi người chơi chính là ZIP đã test trên Windows.

**Sửa:**
- Gán `unique_id=1` cố định cho node gốc (metadata của scene, không đổi gameplay).
- Thời điểm build và ngày giờ trong ZIP lấy theo thời điểm commit.
- Workflow build lại từ một clone mới và **fail nếu SHA-256 khác**.
- ZIP build trong container của Claude từ clone sạch của `ca96df5` và ZIP build trên CI có cùng SHA-256 (§5).

## 5. Kiểm thử
Workflow `windows-playtest` **run #2** (id `39218066295`) trên commit `ca96df5`: **success**. Kết quả từ log:

**build (Linux):**
- export bằng template chính thức;
- ZIP SHA-256 `1d716032…2b24f36`; `EmpireRush.exe` SHA-256 `6824c544…36bd11a`;
- quét quyền riêng tư gói + chuỗi trong exe: CLEAN;
- **build lại từ clone mới: cùng SHA-256** (`first build` = `second build`);
- ZIP build trong container của Claude cũng ra **cùng SHA-256** `1d716032…`.

**windows-run (Windows Server, runner `windows-latest`), chạy chính file `EmpireRush.exe` trong ZIP:**

| Kiểm tra | Kết quả |
|---|---|
| Giải nén vào `…\Thử nghiệm Empire Rush\bản chơi thử\` (dấu tiếng Việt + khoảng trắng) | SHA-256 ZIP khớp; `SHA256SUMS.txt` khớp mọi file |
| Trận 4 người seed 4 (bot + autopilot cho người chơi) | exit 0, 100 lượt, có file ghi trận |
| Trận 4 người seed 7 | exit 0, 96 lượt |
| Trận 3 người seed 5 | exit 0, 90 lượt |
| Trận 2 người seed 3, **giảm chuyển động** | exit 0, 80 lượt |
| Chạy có đồ hoạ (không `--headless`), đợi 25 s | Game chạy, chụp được ảnh. Runner không có GPU: Vulkan không có → **tự chuyển sang Direct3D 12** (Microsoft Basic Render Driver). Tham số `--rendering-driver d3d12` cũng chạy |
| Bản **Public Release**: chạy cả trận với mọi cờ thiết bị/telemetry | **không ghi file nào** (8 trước = 8 sau) |

**windows-project (Windows, Godot 4.7.2 editor bản Windows, kiểm SHA-512):**

| Bộ test | Phát hiện | Pass | Fail |
|---|---|---|---|
| Unit + integration | 29 file / 208 test | 208 | 0 |
| Biên dịch script | 101 | 101 | 0 |
| UI (menu, chọn 2–4 người, nhân vật, đồ hoạ, Cách chơi, bấm nhanh, giảm chuyển động, trận đầy đủ đến màn hình kết quả) | 4 file / 30 test | 30 | 0 |

**verify (Linux), replay các trận ghi trên Windows:**
- 4/4 `MATCHES the recorded final state`: 188/188, 213/213, 247/247, 232/232 lệnh. Engine tất định giữa Windows và Linux.
- Các luồng đã xảy ra trong 4 trận Windows:

  | Luồng | Số lần |
  |---|---|
  | Mua đất | 86 |
  | Thu tiền thuê | 127 |
  | Nâng cấp | 90 |
  | Sự kiện thành phố (rút thẻ) | 30 |
  | Lựa chọn | 40 |
  | Đấu giá (bỏ qua mua → mở đấu giá, đặt giá) | 1 lần, 7 lượt giá |
  | Cứu nợ | 3 lần |
  | Bán đất trả nợ | 8 |
  | Phá sản | 1 |
  | Giao dịch | 7 |
  | Kết thúc trận | 4 |
- Quét quyền riêng tư file ghi trận và log Windows: CLEAN.

**CI cũ (`tests.yml`) trên branch này:** vẫn chạy, không sửa (xem §8).

## 6. Chưa xác minh được trên Windows thật
Runner GitHub là máy ảo Windows Server, **không có card đồ hoạ và không có người bấm**. Chưa kiểm được:
1. **Chơi bằng chuột trên máy Windows có GPU thật** (Vulkan / DirectX 12 của card đồ hoạ), tốc độ khung hình, độ nét chữ trên màn hình thật.
   - Trên runner, game chỉ chạy được bằng trình render phần mềm WARP.
2. **Thao tác của người:**
   - bấm qua menu (2–4 người, nhân vật, đồ hoạ, Cách chơi);
   - bấm nhanh;
   - kéo giãn cửa sổ.

   Các luồng này chỉ được kiểm bằng test UI tự động của project chạy trên Windows (bấm nút qua code), không phải bằng chuột thật trên bản export.
3. **SmartScreen / Windows Defender trên máy cá nhân:** runner không có SmartScreen. Đã ghi cách xử lý trong README.
4. **Windows 10 cũ, máy 4 GB RAM, card đồ hoạ tích hợp đời cũ.**
5. Âm thanh: game chưa có âm thanh (runner báo không có thiết bị âm thanh, không ảnh hưởng).

**Checklist cho lần chạy đầu trên máy Windows thật** (5 phút):
- [ ] Giải nén, nhấp đúp `EmpireRush.exe`. Ghi lại có cảnh báo SmartScreen không.
- [ ] Màn hình đầu hiện đúng; đổi 2/3/4 người, 3 nhân vật, Thấp/Vừa/Cao; mở và đóng CÁCH CHƠI.
- [ ] BẮT ĐẦU; chơi vài lượt (mua, bỏ qua để đấu giá, nâng cấp); bấm nhanh hai lần một nút.
- [ ] Phóng to cửa sổ; giao diện tự sắp lại.
- [ ] Chơi hết trận; màn hình kết quả, CHƠI LẠI / MENU.
- [ ] `MO_DU_LIEU_TRAN_DAU.bat` mở thư mục có file `session_*.json`.

## 7. Cách build lại
```
scripts/ci/install_templates.sh windows      # template chính thức, kiểm SHA-512
GODOT=/path/to/godot scripts/make_windows_playtest_package.sh
```
Output: `dist/EMPIRE_RUSH_Windows_Playtest_x64.zip` (+ `.sha256`).

Script từ chối nếu working tree còn thay đổi chưa commit. CI: `.github/workflows/windows-playtest.yml`, chạy khi push lên branch này hoặc chạy tay (workflow_dispatch).

## 8. CI
| Workflow | Commit | Kết quả |
|---|---|---|
| `windows-playtest` run #1 | `4fef705` | success. Phát hiện build không tái lập được (§4) |
| `windows-playtest` run #2 (id 39218066295) | `ca96df5` | **success** (build, so SHA, chạy exe trên Windows, test project trên Windows, replay). **Đây là bản ZIP để tải** |
| `tests` #24 / #25 | `4fef705` / `ca96df5` | success (unit/UI/e2e + release-lock + readiness) |

Commit tài liệu sau `ca96df5` chỉ đổi file này. CI của nó build lại một ZIP khác SHA, vì build stamp ghi commit mới; nội dung game không đổi.

**Bản để tải và chơi vẫn là ZIP của `ca96df5`:** SHA-256 `1d7160327d08700539896b54f867493af5bea58ddaed438f799b0632f2b24f36`.
