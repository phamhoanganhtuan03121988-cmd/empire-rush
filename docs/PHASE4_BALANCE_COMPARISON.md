# EMPIRE RUSH — So sánh luật hiện tại với phương án V5 (Phase 4)

**Tóm tắt một dòng:** trong 18.000 trận bot (ghép cặp seed), V5 giảm chênh lệch tỷ lệ thắng giữa ghế đầu và ghế cuối từ **5,1 / 10,7 / 11,9 điểm %** (2 / 3 / 4 người) xuống **0,1 / 3,3 / 3,0**. Thời lượng, phá sản và tài sản cuối không đổi trong phạm vi nhiễu.

**V5 chưa được áp dụng.** `client/data/rules/balance.json` không thay đổi trong Phase 4 (fingerprint `d5e3a9a877afe932`). Đây là dữ liệu **bot**, chưa có dữ liệu người thật.

## 1. Hai phương án

| | Luật hiện tại (V0, DRAFT v3) | V5 (đề xuất, chưa duyệt) |
|---|---|---|
| Tiền khởi đầu 2 người | 1.500 / 1.500 | 1.450 / 1.550 |
| Tiền khởi đầu 3 người | 1.500 / 1.500 / 1.500 | 1.370 / 1.500 / 1.630 |
| Tiền khởi đầu 4 người | 1.500 × 4 | 1.350 / 1.450 / 1.550 / 1.650 |
| Tổng tiền trong ván | 1.500 × n | **bằng nhau** (bù tổng bằng 0) |
| Mọi luật khác | — | giống hệt V0 |

Ghế 0 đi trước. V5 lấy bớt tiền của ghế đi trước, đưa cho ghế đi sau.

## 2. Giả định và cách đo
- **Người chơi là bot heuristic** (`BotPlayer`), cùng một cách ra quyết định ở mọi ghế. Thời gian theo mô hình `m1` (như batch Phase 2).
- **Ghép cặp:** V0 và V5 dùng **cùng 3.000 seed** cho mỗi số người chơi, cùng nhân vật ở cùng ghế. Khác biệt giữa hai cột chỉ đến từ tiền khởi đầu.
- **Phân bổ ghế:** nhân vật xoay vòng, mỗi cặp ghế × nhân vật đúng 1.000 trận. Lợi thế ghế không phải do nhân vật.
- **Thống kê:**
  - đồng hạng nhất thì chia đều phần thắng;
  - khoảng tin cậy Wilson 95%;
  - χ² so với chia đều (p lớn = không phân biệt được với công bằng);
  - "tài sản" = giá trị ròng cuối trận (tiền + tài sản).
- **Dữ liệu thô:** `docs/test-logs/phase3_balance/*_matches.csv.gz` (mỗi trận một dòng).

## 3. Kiểm tra lại độc lập (Phase 4)
`python3 scripts/analysis/verify_v5.py`

Script Python riêng: đọc CSV thô và các tệp luật, **không dùng chung code** với bộ mô phỏng GDScript hay `seat_experiment.py`. Kết quả:

## Kiểm tra dữ liệu

- PASS all 63000 rows carry rules fingerprint d5e3a9a877afe932 = current rules files
- PASS V0 re-run in a second experiment: 9000 matches, identical final state hash
- PASS 2p: V0 and V5 use the same 3000 seeds and the same seat->character assignment
- PASS 2p: each character sits in each seat equally often (1000-1000 matches per seat x character)
- PASS 3p: V0 and V5 use the same 3000 seeds and the same seat->character assignment
- PASS 3p: each character sits in each seat equally often (1000-1000 matches per seat x character)
- PASS 4p: V0 and V5 use the same 3000 seeds and the same seat->character assignment
- PASS 4p: each character sits in each seat equally often (1000-1000 matches per seat x character)

## Kết quả (bot, mô hình thời gian m1)

| Người | Phương án | Thắng theo ghế % (CI 95%) | Chênh max−min (điểm %) | χ² p | Thời lượng trung vị (phút) | Trận có phá sản | Tài sản cuối trung vị (mọi ghế) | Tài sản người thắng (trung vị) |
|---|---|---|---|---|---|---|---|---|
| 2 | V0 (luật hiện tại) | 52,6 (50,8–54,3) / 47,4 (45,7–49,2) | **5,1** | 0,00493 | 14,46 | 43,4% | 2.360 | 3.486 |
| 2 | V5 (đề xuất) | 50,0 (48,2–51,8) / 50,0 (48,2–51,8) | **0,1** | 0,971 | 14,47 | 43,7% | 2.362 | 3.488 |
| 3 | V0 (luật hiện tại) | 38,8 (37,1–40,6) / 33,0 (31,3–34,7) / 28,2 (26,6–29,8) | **10,7** | < 1e-10 | 16,50 | 42,8% | 2.031 | 3.938 |
| 3 | V5 (đề xuất) | 35,2 (33,5–36,9) / 33,0 (31,3–34,7) / 31,8 (30,2–33,5) | **3,3** | 0,0762 | 16,48 | 42,8% | 2.026 | 3.914 |
| 4 | V0 (luật hiện tại) | 31,3 (29,7–33,0) / 27,0 (25,4–28,6) / 22,3 (20,8–23,8) / 19,4 (18,0–20,9) | **11,9** | < 1e-10 | 18,23 | 30,9% | 2.035 | 3.961 |
| 4 | V5 (đề xuất) | 26,4 (24,8–28,0) / 26,2 (24,7–27,8) / 23,4 (21,9–24,9) / 24,0 (22,5–25,6) | **3,0** | 0,0395 | 18,22 | 30,5% | 2.034 | 3.938 |

Các con số trùng với `docs/test-logs/phase3_balance/ANALYSIS.md` (Phase 3). Tài sản trung vị chênh tối đa 1–5 RC do cách lấy trung vị khác nhau.

## 4. Đọc bảng cho người không làm thống kê
- **Thắng theo ghế.** Với luật hiện tại, 4 người:
  - ghế đi đầu thắng **31%**, ghế cuối **19%**;
  - nếu công bằng, mỗi ghế khoảng 25%;
  - với V5, mỗi ghế 23–26%.
- **Chênh max−min.** Khoảng cách giữa ghế may nhất và ghế kém nhất. V5 thu hẹp nó khoảng 4 lần ở 3–4 người.
- **χ² p.**
  - Luật hiện tại: p rất nhỏ, tức lợi thế ghế là thật chứ không phải ngẫu nhiên.
  - V5: p = 0,04–0,97, gần như không phân biệt được với công bằng.
  - Ở 4 người, ghế 0–1 (26%) vẫn hơi cao hơn ghế 2–3 (23–24%).
- **Thời lượng, phá sản, tài sản.** Hai phương án gần như bằng nhau (chênh ≤ 0,4 điểm % phá sản, ≤ 0,02 phút). V5 không làm ván dài hơn hay khốc liệt hơn.

## 5. Điều dữ liệu này KHÔNG trả lời
- **Với người thật lợi thế ghế có lớn như vậy không?** Bot chơi giống nhau ở mọi ghế; người thì không.
- **Người chơi có thấy V5 công bằng không?** Ghế đầu nhận ít tiền hơn 150 RC (10%) ngay từ đầu. Có thể bị coi là "bị phạt", dù về số liệu là bù trừ.
- **Ghế được chọn thế nào?** Nếu thứ tự ghế bốc ngẫu nhiên mỗi ván, lợi thế ghế công bằng *về kỳ vọng* giữa người chơi, nhưng vẫn quyết định một phần kết quả từng ván.

## 6. Quy trình quyết định đề xuất
Chi tiết ở `docs/PHASE4_PLAYTEST_GUIDE.md` §8:
1. **Vòng A — luật hiện tại**, 8–12 buổi, xoay vòng ghế của người thật. Thu thứ hạng theo ghế và câu hỏi công bằng.
2. **Quyết định 1 (chủ dự án):** giữ luật (ghi "ghế bốc ngẫu nhiên" vào GDD), hoặc sang vòng B.
3. **Vòng B — V5** chỉ sau khi chủ dự án duyệt, trong một bản build thử riêng có ghi tên phiên bản balance. Production không đổi.
4. **Quyết định 2:** so A với B về số liệu **và** cảm nhận. Ghi vào GDD / balance changelog.

Điều kiện để đổi luật: cả số liệu người thật lẫn cảm nhận đều tốt hơn. Bot đã cho thấy V5 *có thể* cân bằng ghế mà không phá kinh tế, nhưng chưa cho thấy người chơi *muốn* nó.
