# EMPIRE RUSH — Hướng dẫn playtest nội bộ (Phase 4)

**Dành cho:** người điều phối buổi thử (cần biết mở terminal, không cần biết Godot) và người thử (không cần biết gì kỹ thuật).

**Giới hạn của bản này:**

| | |
|---|---|
| Chế độ chơi | **Offline: 1 người chơi với 1–3 máy (bot).** Chơi nhiều người qua mạng chưa có trong bản thử |
| Nền tảng | Gói có sẵn là **Linux x86_64 (máy tính)**. Bản iPhone cần Mac + Xcode và chưa được build (xem `docs/device/IOS_BUILD_GUIDE.md`) |
| Đồ hoạ, âm thanh | Đồ hoạ là bộ asset dọc (vertical slice), chưa có âm thanh |
| Luật chơi và balance | Bản nháp DRAFT v3. **Không thay đổi luật dựa trên một buổi thử** (xem §8) |

## 1. Chuẩn bị gói (người điều phối, một lần cho mỗi bản build)
```
GODOT=/đường/dẫn/Godot_v4.7.2-stable_linux.x86_64 scripts/make_playtest_package.sh
```

Script thực hiện các bước sau. Nếu bất kỳ bước nào sai, nó dừng và không tạo gói:
1. Export bản **Linux Internal Test** (release).
2. **Chạy thử chính bản vừa export** một trận tự động hoàn chỉnh.
3. Kiểm tra tệp ghi trận có bản replay, và replay ra đúng trạng thái cuối.
4. Kiểm tra tệp ghi trận không chứa dữ liệu cá nhân.
5. Tạo `build/playtest/EmpireRush-playtest-<commit>-linux-x86_64.tar.gz`.

| Trong gói | Dùng để |
|---|---|
| `EmpireRush.x86_64`, `EmpireRush.pck` | Trò chơi |
| `BAT_DAU_O_DAY.txt` | Hướng dẫn 4 bước cho người thử |
| `HUONG_DAN_PLAYTEST.md` | Tài liệu này |
| `forms/feedback_form_template.csv` | Phiếu phản hồi, một dòng mỗi buổi |
| `forms/playtest_log_template.csv` | Ghi sự kiện trong lúc quan sát |
| `forms/BUG_REPORT_TEMPLATE.md` | Mẫu báo lỗi |
| `collect_playtest_data.sh`, `privacy_scan.py` | Gom dữ liệu và xoá thông tin cá nhân |
| `SHA256SUMS` | Kiểm tra gói không bị hỏng (`sha256sum -c SHA256SUMS`) |

## 2. Buổi thử — người thử (đọc trong 1 phút)
1. Chạy `./EmpireRush.x86_64`. Ở màn hình đầu chọn:
   - **số người chơi** (bạn + máy);
   - **nhân vật** (dòng mô tả cho biết kỹ năng);
   - **đồ hoạ**;
   - **giảm chuyển động** nếu hiệu ứng làm khó chịu.

   Bấm **CÁCH CHƠI** để đọc luật ngắn, rồi bấm **BẮT ĐẦU**.
2. Chơi như bình thường và **nói to suy nghĩ**: "không biết nút này làm gì", "sao mất tiền"…
3. Không hỏi người điều phối cách chơi. Muốn dừng lúc nào cũng được; cho biết **khi nào và vì sao**.
4. Cuối trận chọn **CHƠI LẠI** (cùng lựa chọn) hoặc **MENU** (đổi lựa chọn). Sau đó trả lời phiếu §4.

## 3. Buổi thử — người điều phối
**Trước buổi:**
- Đặt **mã người thử** (T01, T02…). **Không ghi tên thật**, số điện thoại hay e-mail vào bất kỳ tệp nào.
- Ghi lại mã build (tên gói), máy, hướng màn hình.

**Trong buổi:** mỗi sự kiện đáng chú ý là một dòng trong `playtest_log_template.csv`.

| Mã | Ví dụ |
|---|---|
| `CONFUSED` | không biết lúc nào bấm KẾT THÚC LƯỢT; không hiểu vì sao mất tiền |
| `MISTAP` | định bấm MUA mà trúng BỎ QUA |
| `WAIT` | than chờ máy lâu |
| `BORED` | cầm điện thoại khác, hỏi "còn bao lâu" |
| `DELIGHT` | cười, phản ứng với sự kiện, đấu giá |
| `BUG` | treo, sai bố cục, crash (ghi giờ; chụp màn hình) |

Cột `phase` là một trong: `roll, buy, auction, upgrade, event, trade, rescue, results`.

**Sau buổi:**
- Điền `feedback_form_template.csv` (§4).
- Chạy `./collect_playtest_data.sh` (§5).
- Với mỗi lỗi, điền một phiếu `BUG_REPORT_TEMPLATE.md`.

## 4. Phiếu phản hồi
Mỗi buổi một dòng. Cột `q1`–`q4` và `q6`–`q8` là thang **1–5**; các cột còn lại là câu ngắn.

| Cột | Câu hỏi | Đo gì |
|---|---|---|
| q1 | Mỗi lượt có rõ phải làm gì không? | độ dễ hiểu |
| q2 | Chờ lượt của máy có quá lâu không? | nhịp độ |
| q3 | Chữ, ô đất và tiền có dễ đọc không? | độ dễ đọc |
| q4 | Nút có dễ bấm, đặt đúng chỗ không? | thao tác |
| q5 | Lúc vui nhất? Lúc chán nhất? | cảm xúc |
| q6 | Có muốn chơi thêm ván nữa không? Vì sao? | độ vui tổng thể |
| q7 | Đấu giá có hấp dẫn hay mệt? | cơ chế |
| q8 | Nâng cấp có đáng không, có nhìn ra cấp nhà không? | cơ chế + hình ảnh |
| q9 | Luật nào chưa hiểu? | luật |
| q10 | Bắt đầu mất hứng ở đâu (nếu có)? | thời lượng |
| `fair_1_5` (ghi vào `q6_why` nếu chưa có cột riêng) | Trận có công bằng không? Ghế đi trước có lợi quá không? | cảm giác công bằng (§8) |

Thời lượng thật lấy từ tệp ghi trận, không từ trí nhớ.

## 5. Thu thập dữ liệu và quyền riêng tư
```
./collect_playtest_data.sh                     # gom vào playtest_data_<ngày giờ>/
./collect_playtest_data.sh OUT --names "An,Bình" # thêm: xoá các tên này nếu lỡ gõ vào
```

**Script gom:**
- `telemetry/` (thời lượng, từng lượt, bản ghi replay);
- `device_validation/` (đo hiệu năng nếu có);
- `logs/godot.log`.

**Script xoá:**
- đường dẫn thư mục người dùng (chứa tên đăng nhập máy) → `<home>`;
- e-mail, địa chỉ IP, token/mật khẩu;
- các tên được liệt kê.

Tệp khoá riêng bị bỏ hẳn. Ảnh chụp màn hình được giữ nguyên và **phải kiểm tra bằng mắt** trước khi gửi.

**Tệp ghi trận chứa:**
- seed;
- mã người chơi `p0..p3`, nhân vật;
- mọi lệnh và thời điểm;
- thời gian mỗi lượt;
- máy/hệ điều hành/CPU (cho phân tích hiệu năng).

**Tệp ghi trận không chứa:**
- tên người;
- tài khoản;
- vị trí;
- bất kỳ token mạng nào (bản offline không có).

**Bản Public Release không ghi tệp nào** (kiểm tra trong CI).

Tổng hợp nhiều buổi, ẩn danh:
```
python3 scripts/analysis/aggregate_playtest.py --logs log*.csv --forms form*.csv --telemetry data*/telemetry/*.json --md tong_hop.md
```
- Công cụ đổi mã người thử thành T01, T02…
- Bỏ trích dẫn tự do (trừ khi thêm `--include-quotes`).
- Không tính các trận autopilot.
- **Không bao giờ điền phiếu bằng dữ liệu bịa hoặc dữ liệu bot.**

## 6. Tái hiện lỗi
1. Lấy tệp `telemetry/session_*.json` của trận có lỗi (đã qua bước §5).
2. Trên máy có mã nguồn:
   ```
   godot --headless --path client --script res://tools/replay_match.gd -- --file=/abs/session_X.json
   godot --headless --path client --script res://tools/replay_match.gd -- --file=/abs/session_X.json --until=N --events=1
   ```
3. Đọc kết quả:
   - Dòng đầu phải in `MATCHES the recorded final state`.
   - Dùng `--until=N` để dừng ngay trước thời điểm lỗi và in trạng thái.
   - Trạng thái **đúng** mà màn hình **sai** → lỗi giao diện.
   - Trạng thái **sai** → lỗi luật: thêm test hồi quy vào `client/tests/unit/test_regressions.gd`.
4. **Giới hạn:**
   - Tệp ghi trận chỉ được ghi **khi trận kết thúc**. Crash hoặc tắt ngang chỉ để lại `logs/godot.log` và phiếu ghi của người điều phối.
   - Tắt ngang = mất trận, theo thiết kế: không có khôi phục trận offline.

## 7. Sau nhiều buổi: đọc kết quả
| Chỉ số | Nguồn | Ngưỡng tham khảo |
|---|---|---|
| Thời lượng trận (trung vị, P90) | telemetry | GDD: 22–27 phút trung vị với 4 người. Bot: 18,2 phút |
| Thời gian một lượt của người | telemetry `mean_turn_s.human` | so với 45 giây/lượt |
| Thời gian chờ máy mỗi vòng | telemetry `turn_log` | nguyên nhân chính của `WAIT`/`BORED` |
| Điểm khó hiểu | `CONFUSED` theo màn hình | nhóm theo phase |
| Bấm nhầm | `MISTAP` theo nút | |
| Dừng sớm | số buổi, vòng, lý do | |
| Công bằng ghế | câu hỏi công bằng + thứ hạng theo ghế trong telemetry | §8 |

## 8. Quy trình ra quyết định cân bằng ghế (V5)
Dữ liệu bot (63.000 trận, `docs/test-logs/phase3_balance/ANALYSIS.md`, kiểm lại ở `docs/PHASE4_BALANCE_COMPARISON.md`):
- ghế đầu thắng nhiều hơn ghế cuối khoảng 12 điểm % ở 4 người;
- phương án **V5** (bù tiền khởi đầu, tổng tiền không đổi) gần như xoá chênh lệch đó mà không làm dài trận hay tăng phá sản.

**V5 chưa được áp dụng.** Quy trình đề xuất:
1. **Vòng A — luật hiện tại**, ít nhất 8–12 buổi (khoảng 30+ trận người thật, có xoay vòng ghế của người chơi). Thu: thứ hạng theo ghế, câu hỏi công bằng, thời lượng.
2. **Quyết định 1 (chủ dự án):**
   - Nếu người chơi **không cảm thấy** bất công và không có dấu hiệu ghế đầu thắng áp đảo, giữ luật và ghi trong GDD rằng thứ tự ghế bốc ngẫu nhiên.
   - Nếu có, sang vòng B.
3. **Vòng B — V5 thử nghiệm**:
   - V5 phải được chủ dự án duyệt **trước** khi bật.
   - Chạy dưới dạng một bản build thử riêng, có ghi tên phiên bản balance trong build và trong telemetry. Production không đổi.
   - Số buổi tương đương vòng A.
4. **Quyết định 2:** so sánh A và B về thứ hạng theo ghế, câu hỏi công bằng, thời lượng, phá sản, và cảm nhận "bị trừ tiền vì ngồi ghế đầu".
   - Chỉ đưa V5 vào luật khi cả số liệu lẫn cảm nhận đều tốt hơn.
   - Ghi quyết định vào GDD/balance changelog.

Một buổi thử, hay vài trận, không đủ để đổi luật. Số trận người thật luôn ít hơn rất nhiều so với mô phỏng, nên kết luận phải dựa trên **cảm nhận + dấu hiệu nhất quán**, không dựa trên p-value.
