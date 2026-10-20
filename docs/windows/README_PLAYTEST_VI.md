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
Màn hình đầu có 4 nút:

| Nút | Dùng để |
|---|---|
| **CHƠI** | Lần đầu: 2 trang ngắn **Mục tiêu của bạn** và **Bạn làm gì trong mỗi lượt?** (có nút BỎ QUA), rồi tới trang **Thiết lập trận** |
| **HƯỚNG DẪN TỪNG BƯỚC** | Một trận thật với 1 máy. Mỗi bước dạy một thao tác (đổ xúc xắc → mua đất → kết thúc lượt), nút cần bấm được làm sáng |
| **GIỚI THIỆU** | Xem lại 2 trang mở đầu |
| **CÀI ĐẶT** | Đồ hoạ, giảm chuyển động, âm lượng nhạc và hiệu ứng, tắt âm thanh, bật/tắt và hiện lại gợi ý cho người mới |

Trang **Thiết lập trận**:
- **Chọn nhân vật**: 8 nhân vật có chân dung riêng. Nhân vật chỉ là ngoại hình (tên, chân dung, màu), không có lợi thế gì.
- **Số người chơi** (bạn + máy): 2, 3 hoặc 4.
- **Tên và màu quân** của bạn.
- **Vai trò trong trận (kỹ năng)**: Doanh Nhân, Đầu Tư hoặc Đàm Phán. Đây là kỹ năng theo luật; dòng mô tả cho biết kỹ năng làm gì.
- **Đội hình trận**: chân dung của bạn và các máy.

Bấm **BẮT ĐẦU**. **CÁCH CHƠI** mở luật đầy đủ. Lựa chọn và cài đặt được nhớ cho lần sau.

**Trong trận:**
- Mỗi tình huống mới (mua đất, đấu giá, trả thuê, thẻ sự kiện, nâng cấp, thiếu tiền…) có một thẻ **gợi ý ngắn**, chỉ hiện lần đầu. Thẻ gợi ý cho một quyết định sẽ **tạm dừng đồng hồ** đến khi bạn đọc xong hoặc hành động.
- Đứng yên khoảng 10 giây sẽ hiện dòng **"Gợi ý: …"** cho bước tiếp theo.
- Thẻ mỗi người hiện **Tài sản** (tiền mặt + giá bán lại đất và nhà). Người có tài sản cao nhất khi hết trận sẽ thắng.
- Luật tóm tắt đọc trong 5 phút: file **`HUONG_DAN_NHANH.md`** trong thư mục game.

## 3. Điều khiển
| Thao tác | Chuột / bàn phím |
|---|---|
| Mọi nút | chuột trái |
| Tung xúc xắc | nút **ĐỔ XÚC XẮC** hoặc phím **Space** / **Enter** |
| Bỏ qua hoạt cảnh xúc xắc | chạm vào màn hình hoặc **Space** khi xúc xắc đang lăn. Kết quả không đổi |
| Xem một ô (giá, tiền thuê, chủ) | bấm vào ô trên bàn cờ |
| Tạm dừng (tiếp tục, hướng dẫn, cài đặt, về màn hình chính) | nút **☰** góc trên hoặc phím **Esc** |

- Khi tạm dừng, đồng hồ lượt và máy cũng dừng.
- Cửa sổ có thể **kéo giãn hoặc phóng to**; giao diện tự sắp lại theo chiều ngang hoặc dọc.
- Đóng cửa sổ thì trận đang chơi sẽ mất (bản này không lưu trận dở).
- Âm thanh: nhạc nền và hiệu ứng (tự tạo cho dự án), có tiếng xúc xắc nảy và tiếng báo kết quả. Chỉnh hoặc tắt trong CÀI ĐẶT.

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
| Game chậm, giật | CÀI ĐẶT → **Đồ họa: Thấp**, hoặc bật **Giảm chuyển động** |
| Không nghe tiếng | CÀI ĐẶT: kiểm tra **Tắt âm thanh** đang TẮT và âm lượng > 0; kiểm tra loa của Windows |
| Chữ quá nhỏ | Kéo cửa sổ to hơn hoặc phóng to cửa sổ |
| Windows/antivirus chặn | Xem §1 bước 3–4 |

## 6. Kiểm tra file (không bắt buộc)
Mở PowerShell trong thư mục game và chạy:
```
Get-FileHash .\EmpireRush.exe -Algorithm SHA256
```
Mã in ra phải trùng với dòng `EmpireRush.exe` trong `SHA256SUMS.txt`.

## 7. Giới hạn của bản này
- Đồ hoạ và âm thanh là bản thử (vertical slice); chưa có lồng tiếng.
- Bạn chưa tự đề nghị giao dịch được; máy có thể đề nghị mua đất của bạn.
- Chưa có chơi nhiều người qua mạng.
- Luật và cân bằng: bản nháp DRAFT v3. Đừng đổi luật dựa trên một buổi chơi.
- File chưa ký số: có cảnh báo SmartScreen (§1).
