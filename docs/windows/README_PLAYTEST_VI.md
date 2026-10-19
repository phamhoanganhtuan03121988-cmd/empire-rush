# EMPIRE RUSH — Bản chơi thử trên Windows

Bản thử nội bộ: **1 người chơi với 1–3 máy (bot), không cần mạng**. Không cần cài Godot, Python hay công cụ lập trình nào.

| | |
|---|---|
| Máy cần | Windows 10 hoặc 11, 64-bit |
| Card đồ hoạ | Hỗ trợ Vulkan hoặc DirectX 12 (đa số máy từ 2016 trở đi) |
| Phiên bản | xem `BUILD_INFO.txt` (commit nguồn, ngày build) |

## 1. Giải nén và chạy
1. Chuột phải vào `EMPIRE_RUSH_Windows_Playtest_x64.zip` → **Extract All…** (Giải nén tất cả) → **Extract**.
   **Không** chạy game từ bên trong file ZIP.
2. Mở thư mục vừa giải nén, nhấp đúp **`EmpireRush.exe`**.
3. Nếu Windows hiện màn hình xanh **"Windows protected your PC"**:
   - bấm **More info** (Thông tin thêm);
   - bấm **Run anyway** (Vẫn chạy).

   Cảnh báo này (SmartScreen) xuất hiện vì file **chưa được ký số**. Bản chơi thử nội bộ chưa ký số; bản phát hành sau sẽ cần ký.
4. Nếu phần mềm diệt virus chặn file: đây cũng là do chưa ký số. Chỉ cho phép nếu file tải từ đúng nguồn chủ dự án gửi. Có thể so mã `SHA256SUMS.txt` (xem §6).

## 2. Bắt đầu trận
Ở màn hình đầu chọn:
- **Số người chơi** (bạn + máy): 2, 3 hoặc 4;
- **Nhân vật**: dòng mô tả bên dưới cho biết kỹ năng;
- **Đồ họa**: Thấp / Vừa / Cao. Máy yếu chọn Thấp;
- **Giảm chuyển động**: bật nếu hiệu ứng làm khó chịu.

Bấm **CÁCH CHƠI** để đọc luật ngắn, rồi bấm **BẮT ĐẦU**.

## 3. Điều khiển
- Mọi thao tác đều bằng **chuột trái** (giống chạm trên điện thoại): bấm nút ở dưới màn hình (ĐỔ XÚC XẮC, MUA, BỎ QUA, ĐẤU GIÁ, NÂNG CẤP, KẾT THÚC LƯỢT…).
- Bấm vào một ô trên bàn cờ để xem giá, tiền thuê và chủ sở hữu.
- Cửa sổ mở ở dạng dọc như điện thoại. Có thể **kéo giãn hoặc phóng to** cửa sổ; giao diện tự sắp lại cho màn hình ngang.
- Thoát: đóng cửa sổ (nút X). Trận đang chơi sẽ mất, vì bản này không lưu trận dở.

## 4. Sau khi chơi: gửi phản hồi
1. Mở `forms\phieu_phan_hoi.csv` bằng Excel, điền **một dòng** cho buổi chơi.
   - Dùng mã người thử (T01, T02…), **không ghi tên thật**, số điện thoại hay e-mail.
   - Các cột câu hỏi được giải thích trong hướng dẫn playtest của dự án (`docs/PHASE4_PLAYTEST_GUIDE.md` §4).
2. Gặp lỗi: chép `forms\mau_bao_loi.txt`, điền các bước dẫn tới lỗi, kèm ảnh chụp màn hình nếu có.
   - Chỉ chụp cửa sổ game. Kiểm tra ảnh không lộ tên, thông báo hay màn hình riêng.
3. Nhấp đúp **`MO_DU_LIEU_TRAN_DAU.bat`**: thư mục ghi trận mở ra.
   - Gửi kèm các file `session_*.json` của buổi chơi.
   - Các file này chỉ chứa: seed, mã người chơi `p0`–`p3`, nhân vật, các nước đi và thời gian. Không có tên, tài khoản, vị trí hay đường dẫn máy.
   - Nhờ chúng, nhóm phát triển phát lại đúng ván đã chơi để tìm lỗi.
   - Mỗi file chỉ được ghi khi **trận kết thúc**. Tắt ngang thì không có file.

Thư mục ghi trận nằm ở `%APPDATA%\Godot\app_userdata\Empire Rush\telemetry`. Không cần mở thư mục nào khác.

## 5. Khi gặp sự cố
| Hiện tượng | Thử |
|---|---|
| Nhấp đúp không thấy gì, hoặc báo lỗi đồ hoạ (Vulkan / DirectX) | Cập nhật driver card đồ hoạ. Ghi tên máy và lỗi vào phiếu báo lỗi |
| Game chậm, giật | Chọn **Đồ họa: Thấp** ở màn hình đầu, hoặc bật **Giảm chuyển động** |
| Chữ quá nhỏ | Kéo cửa sổ to hơn hoặc phóng to cửa sổ |
| Windows/antivirus chặn | Xem §1 bước 3–4 |

## 6. Kiểm tra file (không bắt buộc)
Mở PowerShell trong thư mục game và chạy:
```
Get-FileHash .\EmpireRush.exe -Algorithm SHA256
```
Mã in ra phải trùng với dòng `EmpireRush.exe` trong `SHA256SUMS.txt`.

## 7. Giới hạn của bản này
- Chưa có âm thanh. Đồ hoạ là bộ asset vertical slice.
- Chưa có chơi nhiều người qua mạng.
- Luật và cân bằng: bản nháp DRAFT v3. Đừng đổi luật dựa trên một buổi chơi.
- File chưa ký số: có cảnh báo SmartScreen (§1).
