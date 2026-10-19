# EMPIRE RUSH: Đánh giá độ phức tạp cho người mới (Phase 5.1)

Ngày: 2026-10-19 · Branch `claude/phase5-1-player-experience` · Luật và cân bằng **không đổi** (DRAFT v3, dữ liệu `client/data/rules/*` giống hệt `8e571e2`).

**Nguồn và cách làm:**
- **Luật:** đọc GDD, `docs/RULES_M1.md`, dữ liệu luật và engine. Bản đầy đủ có trích dẫn file:dòng nằm ở `docs/RULES_AS_IMPLEMENTED_VI.md`.
- **UI:** đọc mã HUD và menu, xem ảnh chụp bản thật ở 1280×720, 960×540, 540×960 và 786×1704 (có tai thỏ).
- **Giới hạn:** chưa có người chơi thật thử. Điểm "độ rõ" dưới đây là đánh giá của nhóm phát triển dựa trên màn hình, chưa phải số đo từ người dùng. Cần một buổi playtest với người mới để xác nhận (`docs/PHASE4_PLAYTEST_GUIDE.md`).

## 1. Tóm tắt
- **Vòng lặp chính đơn giản:** đổ xúc xắc → mua đất / trả thuê → (tùy chọn) nâng cấp → hết lượt.
- **Nhưng một trận có khoảng 20 cơ chế.** Chỉ **6** cái cần ngay ở lượt đầu; phần còn lại xuất hiện dần, có cái tới giữa hoặc cuối trận mới gặp.
- **5 nguyên nhân chính khiến người mới, kể cả chính chủ dự án, chưa hiểu cách chơi** (trước Phase 5.1):
  1. **Không thấy mục tiêu.** Người thắng là người có *tài sản ròng* cao nhất, nhưng HUD chỉ hiện tiền mặt. Mua đất làm tiền mặt giảm, nên người chơi tưởng mình đang thua.
  2. **Hướng dẫn là một bức tường chữ.** Có 4 trang giới thiệu, rồi 7 thẻ hướng dẫn phải đọc lần lượt. Thẻ thứ 5 còn hứa một nút "đề nghị giao dịch" mà HUD không có.
  3. **"Nhân vật" thực ra là vai trò có kỹ năng.** Người chơi chọn một chức danh mà không có cảm giác chọn nhân vật, và cũng không hiểu kỹ năng đó làm gì trong trận.
  4. **Kết quả xúc xắc khó thấy.** Xúc xắc nhỏ, rơi giữa cây và nhà, nên người chơi không theo được "vì sao quân đi tới đó".
  5. **Đồng hồ 45 giây cho cả lượt.** Đọc chậm thì máy tự chọn hộ, người mới thấy bị "đuổi".
- **Phase 5.1 đã xử lý 1–4 mà không đổi luật** (§5). Mục 5 là chuyện luật, nên chỉ được ghi thành phương án chờ duyệt (§6). Phase 5.1 giảm áp lực bằng cách tạm dừng đồng hồ khi một thẻ gợi ý quan trọng đang mở.

## 2. Mọi cơ chế người chơi phải hiểu

**Ký hiệu:**
- Cột "Lượt 1": **Có** = cần ngay lượt đầu; **Ngữ cảnh** = giải thích khi gặp lần đầu.
- Cột "Độ rõ": 1 = rất khó hiểu, 5 = tự hiểu khi nhìn màn hình. Hai số là trước Phase 5.1 → sau Phase 5.1.
- Cột "Giải thích ở đâu (5.1)":
  - "Trang 1/2" là hai trang mở đầu;
  - "Gợi ý: x" là thẻ gợi ý theo ngữ cảnh `x` (`RulesGuide.tips()`);
  - "HD" là trận hướng dẫn từng bước;
  - "☰" là trang HƯỚNG DẪN trong menu tạm dừng.

| # | Cơ chế | Lượt 1 | Giải thích ở đâu (5.1) | Độ rõ | Ghi chú: vì sao |
|---|---|---|---|---|---|
| 1 | Mục tiêu: tài sản ròng cao nhất | Có | Trang 1; thẻ người chơi ghi "Tài sản" | 2 → 4 | Trước: không có số nào trên màn hình. Nay mỗi thẻ hiện "Vai trò · Tài sản N" |
| 2 | Đổ xúc xắc, đi quân | Có | Trang 2; Gợi ý: roll; HD bước 1 | 3 → 5 | Xúc xắc to ở lớp tiền cảnh, hiện "Bạn đổ được 5 + 6 = 11" |
| 3 | Đồng hồ 45 s cho cả lượt | Có | Trang 2; Gợi ý: roll | 2 → 3 | Thanh thời gian không có chữ. Gợi ý quyết định có tạm dừng đồng hồ |
| 4 | Mua / BỎ QUA | Có | Gợi ý: buy; HD bước 2 | 3 → 4 | Nhãn "BỎ QUA (đấu giá)" giờ được giải thích: bạn vẫn được trả giá |
| 5 | "Một việc cuối lượt" rồi KẾT THÚC LƯỢT | Có | Trang 2; Gợi ý: strategy; HD bước 3 | 2 → 4 | Trước đây người mới không hiểu vì sao lượt chưa kết thúc sau khi mua |
| 6 | Vai trò và kỹ năng | Có (chọn ở menu) | Trang thiết lập; Gợi ý: ability | 2 → 3 | Nay tách "Nhân vật" (ngoại hình) khỏi "Vai trò (kỹ năng)". Nút KỸ NĂNG chỉ hiện khi dùng được |
| 7 | Đấu giá | Ngữ cảnh | Gợi ý: auction | 2 → 3 | Chỉ có 2 nút trả giá. 12 s rất ngắn khi lần đầu gặp; thẻ gợi ý tạm dừng đấu giá trong lúc đọc |
| 8 | Ô Xuất phát +200 (qua **hoặc dừng**) | Ngữ cảnh | Gợi ý: start; ☰ bước 1 | 3 → 4 | Hướng dẫn cũ chỉ nói "qua"; đã sửa theo engine |
| 9 | Trả tiền thuê (tự động) | Ngữ cảnh | Gợi ý: rent_paid / rent_got | 3 → 4 | Trước chỉ có dòng thông báo tiền |
| 10 | Quận trọn vẹn: thuê ×2, mở nâng cấp | Ngữ cảnh | Gợi ý: district | 2 → 4 | Người mới không biết vì sao nút NÂNG CẤP bị khóa |
| 11 | Nâng cấp: 1 cấp/lần, tối đa cấp 3, tốn cả việc của lượt | Ngữ cảnh | Gợi ý: upgrade; ô có thể nâng được đánh dấu trên bàn | 2 → 4 | — |
| 12 | Bảng thuê theo cấp (×2, ×7, ×22, ×55) | Ngữ cảnh | Bảng mua đất; Gợi ý: upgrade, rent_paid | 3 → 3 | Số đúng nhưng nhiều; chưa có minh họa |
| 13 | Ô ! (12 thẻ sự kiện) | Ngữ cảnh | Gợi ý: event | 3 → 4 | — |
| 14 | Ô ? (chọn 1 trong 2) | Ngữ cảnh | Gợi ý: choice | 3 → 4 | Nội dung thật nằm trên nút. Hết giờ thì máy chọn phương án miễn phí |
| 15 | Ô % thuế 10% (tối đa 200), không gây phá sản | Ngữ cảnh | Gợi ý: tax | 2 → 4 | — |
| 16 | Ô Nghỉ | Ngữ cảnh | ☰ | 4 → 4 | Không có gì xảy ra |
| 17 | Hiệu ứng tạm thời "trong N vòng" | Ngữ cảnh | Dòng thông báo khi thẻ có hiệu lực | 2 → 2 | Chưa có chỗ xem hiệu ứng đang chạy (§5, U4) |
| 18 | Giao dịch (bot đề nghị, bạn ĐỒNG Ý / TỪ CHỐI) | Ngữ cảnh | Gợi ý: trade | 3 → 4 | Người chơi chưa tự đề nghị được: thiếu UI, engine đã hỗ trợ |
| 19 | Cứu nợ: bán đất 50% giá, 30 s | Ngữ cảnh | Gợi ý: rescue | 2 → 3 | Nút PHÁ SẢN không nhất thiết làm bạn phá sản (§4.8) |
| 20 | Phá sản: đất về ngân hàng | Ngữ cảnh | Gợi ý: bankrupt | 3 → 4 | — |
| 21 | Kết thúc trận (vòng / 30 phút / 1 người) và tie-break | Có (để biết trận dài bao lâu) | Trang 1; ☰ bước 7 | 2 → 4 | "Vòng 1/30" nay có giải thích 2 người 40 / 3 người 30 / 4 người 25 |

## 3. Độ rõ từng bước của một lượt (UI thực tế)

| Bước | Màn hình cho thấy gì | Còn thiếu |
|---|---|---|
| Bắt đầu lượt | Thẻ người chơi được viền màu, "Lượt của bạn!", nút ĐỔ XÚC XẮC lớn có hiệu ứng thở | — |
| Đổ | Khay xúc xắc tiền cảnh, nền tối đi, hai viên rơi và nảy, thẻ "5 + 6 = 11" giữ 0,8 s; chạm để bỏ qua | — |
| Đi quân | Quân nhảy từng ô có tiếng bước, chân dung nổi trên quân | Chưa đếm số ô trên đường đi |
| Ô đất trống | Tên ô, quận, giá, bảng thuê theo cấp, MUA x RC / BỎ QUA (đấu giá) | Bảng thuê dạng chữ, chưa có hình |
| Đấu giá | Tên ô, giá hiện tại, ai đang dẫn, 2 nút trả giá | Không nhập được số tùy ý; 12 s |
| Hành động cuối lượt | NÂNG CẤP (khóa và có lý do nếu chưa đủ quận), KỸ NĂNG (nếu dùng được), KẾT THÚC LƯỢT; ô nâng được sáng trên bàn | Không có nút giao dịch |
| Tiền thay đổi | Thông báo có lý do ("Bạn qua Xuất phát: +200 RC", "trả 18 RC tiền thuê cho…") | — |
| Kết thúc trận | Bảng xếp hạng theo tài sản ròng | Chưa tách tài sản thành tiền mặt / đất / nhà |

## 4. Điểm người mới dễ nhầm
1. **"Tiền ít đi nghĩa là tôi đang thua."** Mua đất đổi tiền mặt lấy đất, nhưng đất chỉ được tính 50% giá. → 5.1: hiện "Tài sản" trên thẻ; trang Mục tiêu nói rõ cách tính.
2. **"Tôi đã mua rồi, sao lượt chưa hết?"** Sau khi xử lý ô vẫn còn bước "một việc cuối lượt". → 5.1: gợi ý strategy và gợi ý "bấm KẾT THÚC LƯỢT" khi đứng yên 10 s.
3. **"BỎ QUA là bỏ luôn ô này?"** Không phải: BỎ QUA mở đấu giá, và bạn vẫn được trả giá, có khi rẻ hơn. → gợi ý buy và auction.
4. **"Sao không nâng cấp được?"** Phải giữ đủ 3 ô cùng màu, và chỉ nâng sau khi đã đi. → dòng lý do trên HUD, gợi ý district và upgrade.
5. **"Hết giờ thì sao?"** Máy tự đổ hộ hoặc chọn phương án an toàn. Đồng hồ là của *cả lượt*, không phải từng bước. → trang 2 và gợi ý roll. Thẻ gợi ý quyết định tạm dừng đồng hồ.
6. **"Doanh Nhân / Đầu Tư / Đàm Phán là nhân vật à?"** Đó là vai trò có kỹ năng. → 5.1 tách khỏi chọn nhân vật (ngoại hình) và ghi rõ trên trang thiết lập.
7. **"Vòng 1/30 nghĩa là gì?"** Số vòng tối đa phụ thuộc số người. → trang 1 và ☰ bước 7.
8. **Nút PHÁ SẢN khi Cứu nợ** không nhất thiết làm bạn phá sản: nếu tài sản vẫn đủ trả, máy tự bán ô rẻ nhất và bạn ở lại (engine, [REVIEW] trong RULES_M1). → gợi ý rescue nói rõ. Tên nút giữ nguyên vì là lệnh `DeclareBankruptcy`; đề xuất đổi nhãn ở U2.
9. **"Trong 2 vòng"** của hiệu ứng nghĩa là 2 lượt của mỗi người còn sống, không phải 2 lượt của riêng bạn. Chưa có chỗ xem hiệu ứng đang chạy (U4).
10. **Bùng Nổ Du Lịch** tăng thuê ở **cả hai** quận du lịch (D2 Cảng Biển, D5 Khu Nghỉ Dưỡng), bất kể ai là chủ.
11. **Gieo đôi** không có gì đặc biệt, và game không có tù. Người quen Cờ tỷ phú hay hỏi.
12. **Tự đề nghị giao dịch:** hướng dẫn cũ nói là có nhưng thực tế không có nút. → đã sửa chữ; tính năng đề xuất ở U1.

## 5. Đơn giản hóa không đổi luật

**Đã làm trong Phase 5.1:**

| Mã | Thay đổi | Ở đâu |
|---|---|---|
| S1 | Hai trang mở đầu: "Mục tiêu của bạn", "Bạn làm gì trong mỗi lượt?" (thay 4 trang dày) | `RulesGuide.intro_pages()` |
| S2 | Gợi ý theo ngữ cảnh, mỗi cái một lần. Gợi ý quyết định tạm dừng đồng hồ và tự đóng khi người chơi hành động. Có thể tắt hoặc bật lại trong Cài đặt | `CoachOverlay`, `RulesGuide.tips()` |
| S3 | Trận hướng dẫn dạy mỗi lần một thao tác, làm sáng nút cần bấm: đổ → mua → kết thúc lượt → xem máy đi → xong | `CoachOverlay` (guided) |
| S4 | "Gợi ý: …" khi người chơi đứng yên 10 s | `RulesGuide.next_hint()` |
| S5 | Thẻ người chơi hiện "Tài sản N" (điểm thắng) | `GameHud._refresh_worth()` |
| S6 | Xúc xắc tiền cảnh, kết quả "a + b = tổng" | `DiceStage` |
| S7 | Tách Nhân vật (ngoại hình) khỏi Vai trò (kỹ năng) | Trang thiết lập |
| S8 | Sửa chữ cho đúng engine: Xuất phát thưởng cả khi dừng đúng ô; bỏ lời hứa nút giao dịch | `RulesGuide` |

**Đề xuất tiếp (chỉ UI, không đổi luật, chưa làm):**

| Mã | Đề xuất | Lý do |
|---|---|---|
| U1 | Nút **ĐỀ NGHỊ GIAO DỊCH** trong pha chiến lược (engine đã có `ProposeTrade`) | Hiện người chơi chỉ trả lời được đề nghị của bot. Cần thiết kế màn chọn ô và giá |
| U2 | Nút ở Cứu nợ: "PHÁ SẢN" → "TỰ BÁN / PHÁ SẢN", kèm số tiền sẽ còn lại | Tránh hiểu nhầm ở §4.8 |
| U3 | Nhập giá đấu tùy ý (± 10) | 2 nút cố định là đủ cho người mới, nhưng người chơi có kinh nghiệm muốn chủ động |
| U4 | Dải "Hiệu ứng đang chạy" (giảm thuê, trần thuê, giảm giá nâng cấp) kèm số lượt còn lại | Người chơi quên hiệu ứng từ thẻ |
| U5 | Cảnh báo "Còn 3 vòng" và màn kết quả tách tài sản thành tiền mặt / đất / nhà | Hiểu vì sao mình thắng hoặc thua |
| U6 | Minh họa bảng thuê bằng hình nhà 1–3 cấp | Bảng chữ nhiều số khó đọc trên điện thoại |

## 6. Phương án ĐỔI LUẬT, chờ chủ dự án duyệt (CHƯA áp dụng)
Mọi mục dưới đây đều thay đổi luật hoặc cân bằng. Trước khi quyết định cần mô phỏng (`scripts/run_simulation.sh`) và playtest.

| Mã | Phương án | Lợi cho người mới | Rủi ro |
|---|---|---|---|
| R1 | Đồng hồ theo từng bước (ví dụ đổ 20 s, mua 20 s, hành động 25 s) thay vì 45 s cho cả lượt | Dễ hiểu hơn "thời gian còn lại cho việc đang làm" | Đổi thời lượng trận; cần đo lại |
| R2 | Chơi offline với máy: tùy chọn **không giới hạn thời gian** | Người mới đọc thoải mái | Trận dài hơn; mạng vẫn cần đồng hồ |
| R3 | Hết giờ ở pha đổ thì **không** tự đổ hộ, chỉ bỏ lượt (đang là [REVIEW] trong RULES_M1) | Người chơi không thấy "máy chơi hộ" | Có thể làm trận chậm |
| R4 | Tính đất theo **giá mua** (thay vì 50%) khi xếp hạng | Mua đất không còn làm điểm giảm | Thay đổi cân bằng lớn (đất ↔ tiền mặt); phải mô phỏng lại toàn bộ |
| R5 | Bỏ thuế tài sản ở ô % hoặc đổi thành phí cố định | Bớt một công thức | Thay đổi cân bằng |
| R6 | Chế độ "Cơ bản" cho trận đầu: không sự kiện, không kỹ năng | Ít khái niệm | Hai bộ luật; phải duy trì và kiểm thử cả hai |

## 7. Tài liệu và engine chưa khớp (tóm tắt)
Chi tiết 22 điểm ở `docs/RULES_AS_IMPLEMENTED_VI.md` §12. Engine cùng dữ liệu là nguồn sự thật cho trận đang chạy, theo quyết định G1–G12 và M1.2. Những điểm ảnh hưởng tới hướng dẫn:
- **Số vòng:** GDD ghi 25 cho mọi trận; engine dùng 40 / 30 / 25 (quyết định M1.2). Chữ trong game lấy từ dữ liệu nên đúng; `docs/IMPLEMENTATION_PLAN.md` còn số cũ.
- **Ô Xuất phát:** GDD nói "khi đi qua"; engine thưởng cả khi dừng đúng ô. Hướng dẫn trong game đã theo engine.
- **Hết giờ ở pha đổ:** GDD không nói tự đổ; engine tự đổ hộ ([REVIEW]). Chưa đổi, chờ duyệt (R3).
- **Tài sản ròng:** GDD tính cả thưởng mục tiêu và trừ nợ; engine theo G11 (tiền mặt + giá thanh lý).
- **Giao dịch:** GDD cho người chơi đề nghị; client chưa có UI (U1).
- **Cứu nợ "PHÁ SẢN":** GDD nói phá sản ngay; engine tự thanh lý nếu đủ ([REVIEW]).
