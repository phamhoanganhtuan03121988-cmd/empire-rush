# EMPIRE RUSH: Hướng dẫn nhanh (đọc 5 phút)

Hướng dẫn này mô tả đúng luật đang chạy trong game: bản nháp cân bằng **DRAFT v3**, số liệu lấy từ `client/data/rules/balance.json`. Bản chi tiết có trích nguồn nằm ở `docs/RULES_AS_IMPLEMENTED_VI.md`.

## 1. Mục tiêu
- **Trở thành người giàu nhất khi trận kết thúc.**
- **Giàu** = tiền mặt + giá bán lại đất và nhà. Giá bán lại bằng **50%** số tiền đã bỏ ra. Con số này hiện là "Tài sản" trên thẻ mỗi người.
- Mua đất làm *Tài sản* giảm ngay, vì đất chỉ được tính một nửa. Đất chỉ có lời khi thu tiền thuê bù lại.
- Mỗi người bắt đầu với **1 500 RC** (RC là tiền trong game).

**Trận kết thúc** khi một trong ba điều sau xảy ra (kiểm tra ở cuối mỗi lượt):
- hết số vòng: 2 người **40 vòng**, 3 người **30 vòng**, 4 người **25 vòng** (HUD hiện "Vòng 1/30");
- hết **30 phút**;
- chỉ còn **một người** chưa phá sản.

**Bằng tài sản thì:** ai có nhiều quận trọn vẹn hơn thắng, rồi tới ai nhiều tiền mặt hơn.

## 2. Một lượt của bạn
**Cả lượt có 45 giây** (thanh vàng dưới thẻ người chơi, chuyển đỏ khi còn dưới 10 giây). Hết giờ thì game tự đổ hộ hoặc chọn phương án an toàn. Khi một thẻ gợi ý quan trọng đang mở, đồng hồ tạm dừng.

1. **ĐỔ XÚC XẮC** (nút lớn hoặc phím Space):
   - đổ hai viên, quân đi số ô bằng tổng;
   - **gieo đôi không có gì thêm**, và game không có tù;
   - chạm, hoặc bấm Space, để bỏ qua hoạt cảnh xúc xắc; kết quả không đổi.
2. **Xử lý ô vừa dừng** (xem §3).
3. **Một việc cuối lượt (tùy chọn):** NÂNG CẤP nhà, hoặc dùng KỸ NĂNG của vai trò. Không muốn thì bấm **KẾT THÚC LƯỢT**.
   - Nâng cấp hoặc dùng kỹ năng sẽ kết thúc lượt ngay.

Đi qua **hoặc dừng đúng** ô **Xuất phát**: nhận **+200 RC**.

## 3. Các loại ô (bàn 28 ô)

| Ô | Chuyện gì xảy ra |
|---|---|
| **Đất** (21 ô, 7 quận × 3 ô cùng màu) | **Chưa có chủ:** bạn được MUA trước, đúng giá ghi trên nút. **Của người khác:** tự động trả tiền thuê. **Của bạn:** không có gì |
| **!** Sự kiện (2 ô) | Rút 1 trong 12 thẻ: được tiền, mất tiền, hiệu ứng tạm thời, hoặc chọn 1 trong 2 |
| **?** Cơ hội (2 ô) | Chọn 1 trong 2 phương án. Kết quả ghi trên nút; hết giờ thì game chọn phương án miễn phí |
| **%** Thuế (1 ô) | Nộp 10% tài sản, tối đa 200 RC. Không bao giờ làm bạn phá sản |
| **Nghỉ** (1 ô) | An toàn, không có gì xảy ra |
| **Xuất phát** | +200 RC khi đi qua hoặc dừng |

**Giá đất theo quận** (theo thứ tự trên bàn, từ Xuất phát):

| Quận | Giá mỗi ô | Thuê cơ bản | Nâng cấp mỗi lần |
|---|---|---|---|
| Chợ Cũ | 60 | 8 | 30 |
| Cảng Biển (du lịch) | 90 | 11 | 30 |
| Ven Sông | 120 | 15 | 45 |
| Phố Hoa | 150 | 18 | 45 |
| Khu Nghỉ Dưỡng (du lịch) | 180 | 22 | 60 |
| Trung Tâm Tài Chính | 220 | 26 | 60 |
| Đỉnh Thượng Lưu | 260 | 32 | 75 |

## 4. Mua đất và đấu giá
- **MUA:** trả đúng giá; ô thành của bạn. Không đủ tiền thì nút MUA bị khóa.
- **BỎ QUA (đấu giá):** cả bàn đấu giá ô đó trong **12 giây**, **kể cả bạn**.
  - Giá mở tối thiểu là 10% giá đất, ít nhất 10 RC. Mỗi lần trả phải cao hơn ít nhất 10 RC.
  - Hết giờ, người trả cao nhất mua được đất.
  - Không ai trả thì đất vẫn chưa có chủ, và người sau dừng ở đó lại được mua.
  - Trả giá trong 3 giây cuối thì đấu giá được cộng thêm 3 giây, tối đa 2 lần.

## 5. Tiền thuê, quận và nâng cấp
- **Giữ đủ 3 ô cùng màu** (quận trọn vẹn): tiền thuê **×2** và **được nâng cấp nhà**.
- **Nâng cấp:**
  - mỗi lần lên **1 cấp** cho một ô, tối đa **cấp 3**;
  - chỉ làm được sau khi đã đi, và dùng hết việc của lượt;
  - không bắt buộc xây đều giữa các ô.
- **Tiền thuê** theo cấp, chỉ áp dụng một hệ số:

  | Trạng thái | Hệ số | Ví dụ Chợ Cũ | Ví dụ Đỉnh Thượng Lưu |
  |---|---|---|---|
  | Chưa đủ quận | ×1 | 8 | 32 |
  | Đủ quận, chưa xây | ×2 | 16 | 64 |
  | Cấp 1 | ×7 | 56 | 224 |
  | Cấp 2 | ×22 | 176 | 704 |
  | Cấp 3 | ×55 | 440 | 1 760 |

- Chạm vào một ô bất kỳ để xem giá, tiền thuê và chủ sở hữu.

## 6. Vai trò (kỹ năng) và nhân vật
- **Nhân vật** (Minh Khôi, Thu Hà, Bác Tư…) chỉ là **ngoại hình**: chân dung, tên, màu quân. Không có lợi thế gì.
- **Vai trò** là kỹ năng thật trong trận. Bạn chọn một; các máy nhận vai trò còn lại.

| Vai trò | Kỹ năng |
|---|---|
| **Doanh Nhân** | Luôn được giảm 10% tiền nâng cấp (tự động) |
| **Nhà Đầu Tư** | Nút KỸ NĂNG: nhận 15 RC cho mỗi ô đang sở hữu, tối đa 120 RC. Dùng 2 lần mỗi trận, cách nhau 3 vòng |
| **Chuyên Gia Đàm Phán** | Nút KỸ NĂNG: lần trả thuê kế tiếp trong 2 vòng chỉ mất 50%. Dùng 2 lần mỗi trận, cách nhau 3 vòng |

## 7. Sự kiện, cơ hội, hiệu ứng tạm thời
- **Thẻ sự kiện có thể là:**
  - được tiền (+100, tới thẳng Xuất phát +200);
  - mất tiền (phạt 50; 20 cho mỗi cấp nhà; 40 cho mỗi ô cấp ≥ 2);
  - hiệu ứng tạm thời: Bùng Nổ Du Lịch (thuê ở **cả hai** quận du lịch +50%), Mất Điện (đất của bạn thu thuê −50%), Trợ Giá Xây Dựng (nâng cấp kế tiếp −50%);
  - lựa chọn: đầu tư, bảo hiểm tiền thuê, thưởng danh mục, dạ tiệc từ thiện.
- **"Trong N vòng"** = N lượt của **mỗi** người còn sống. Giảm giá dùng một lần sẽ mất nếu không kịp dùng.

## 8. Thiếu tiền: cứu nợ và phá sản
- Phải trả (thuê, thuế, thẻ) mà không đủ tiền mặt thì vào **Cứu nợ** trong **30 giây**.
  - **BÁN** từng ô cho ngân hàng, được 50% giá đất và 50% tiền nhà.
  - Đủ tiền là tự trả nợ, và bạn chơi tiếp lượt.
- **Nút PHÁ SẢN:**
  - nếu tài sản vẫn đủ trả, game **tự bán ô rẻ nhất** và bạn vẫn ở lại;
  - không đủ thì bạn **bị loại**: đất về ngân hàng, tiền mặt còn lại về tay chủ nợ.

## 9. Giao dịch
- Máy có thể đề nghị **mua đất của bạn** (thường khi nó có 2/3 ô của một quận). Bạn có **20 giây** để ĐỒNG Ý hoặc TỪ CHỐI.
- Chỉ ô **chưa xây nhà** mới giao dịch được.
- Bản này **bạn chưa tự đề nghị giao dịch được** (engine đã hỗ trợ, còn thiếu giao diện).

## 10. Đọc màn hình
| Chỗ | Ý nghĩa |
|---|---|
| "Vòng 1/30" | Vòng hiện tại / số vòng tối đa (theo số người) |
| Thẻ người chơi | Chân dung, tên, "Vai trò · Tài sản N", tiền mặt. Viền sáng = người đang đi |
| Thanh vàng / đỏ | Thời gian còn lại của lượt |
| Dòng thông báo | Mọi thay đổi tiền đều có lý do (mua, thuê, Xuất phát, thẻ…) |
| Bảng hành động (dưới / phải) | Nút cho việc bạn được làm lúc này |
| ☰ hoặc Esc | Tạm dừng (đồng hồ và máy dừng): Hướng dẫn, Cài đặt, về màn hình chính |
| "Đồ họa: Vừa" | Chỉ đổi chất lượng hình, không ảnh hưởng luật |

## 11. Mẹo cho trận đầu
- Mua đất rẻ ở những vòng đầu, nhắm **đủ 3 ô một quận**.
- Có quận rồi thì nâng cấp: cấp 1 đã ×7 tiền thuê.
- Đừng tiêu sạch tiền mặt: tiền thuê ở quận đắt có thể lên hàng trăm RC.
- Lần đầu chơi nên bấm **HƯỚNG DẪN TỪNG BƯỚC** ở màn hình chính. Gợi ý sẽ tự hiện khi một tình huống mới xảy ra; bật lại được trong **CÀI ĐẶT → Hiện lại tất cả gợi ý**.
