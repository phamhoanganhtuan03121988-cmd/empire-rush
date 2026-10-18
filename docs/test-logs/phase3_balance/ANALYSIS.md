# Phase 3 — thí nghiệm lợi thế ghế (C1/C2)

**Đây là mô phỏng bằng bot, không phải người chơi.**
- Mọi phương án là **tuỳ chọn chỉ có trong thí nghiệm**, gồm `seat_cash_offsets` và `seat_start_positions` trong `MatchSimulator`.
- `client/data/rules/balance.json` (DRAFT v3, fingerprint `d5e3a9a877afe932`) **không thay đổi**.
- Không phương án nào được đưa vào luật. Chủ dự án quyết định.

## C1 — Xác minh dữ liệu Phase 2
| Kiểm tra | Kết quả |
|---|---|
| Fingerprint luật trong 15.000 dòng của Phase 2 | `d5e3a9a877afe932`, trùng với file luật hiện tại (tính lại độc lập bằng Python) |
| Yếu tố gây nhiễu: nhân vật | Nhân vật xoay vòng theo seed. Ở 4 người, mỗi cặp ghế × nhân vật có 1.666–1.667 trận. **Trong cả 3 nhân vật, lợi thế ghế vẫn còn**: ghế 0 thắng 31,3 / 31,6 / 29,8% và ghế 3 thắng 19,4 / 21,9 / 18,7% (Tycoon / Investor / Negotiator). Tức là lợi thế do thứ tự ghế, không do nhân vật |
| Phương pháp | Tỷ lệ thắng chia đều khi đồng hạng nhất. Khoảng tin cậy Wilson 95%. χ² so với chia đều. Trung vị thời lượng có CI bootstrap. Code Python đã đối chiếu khớp với kết quả GDScript |
| Bất định | Với n = 3.000–5.000 mỗi cấu hình, CI của tỷ lệ thắng mỗi ghế là ±1,3–1,8 điểm %. Chênh lệch 11–12 điểm ở 4 người lớn hơn nhiều so với mức nhiễu |
| Giới hạn | Bot heuristic ra quyết định giống nhau ở mọi ghế. Với người thật, thứ tự ghế được bốc ngẫu nhiên và lối chơi khác hẳn, nên độ lớn của lợi thế có thể khác |

## C2 — Thiết kế thí nghiệm
- Spec: `client/tests/sim/experiments/p3_seat_v1.json` và `p3_seat_v1b.json` (phần tiếp nối).
- **Cùng seed cho mọi phương án** (so sánh cặp). 3.000 trận mỗi số người chơi × mỗi phương án, tổng **63.000 trận**, 0 kẹt, 0 vi phạm bất biến, 0 lệnh bị từ chối.
- Mô hình thời gian `m1` (giống batch Phase 2).

| Phương án | Thay đổi | Tổng tiền khởi đầu |
|---|---|---|
| V0 | baseline v3 | 1.500 × n |
| V1 | cộng/trừ nhỏ, tổng bằng 0: 2p −25/+25 · 3p −40/0/+40 · 4p −45/−15/+15/+45 | **không đổi** |
| V2 | cộng/trừ lớn, tổng bằng 0: 2p ±50 · 3p ±80 · 4p −90/−30/+30/+90 | **không đổi** |
| V3 | ghế sau +30/ghế (giống M1.1) | tăng 30 / 90 / 180 RC (tức +1,0 / +2,0 / +3,0%) |
| V4 | ghế k xuất phát ở ô 2k (không đổi tiền) | không đổi; ghế sau qua ô Xuất phát sớm hơn |
| V5 | cộng/trừ rất lớn, tổng bằng 0: 2p ±50 · 3p ±130 · 4p −150/−50/+50/+150 | **không đổi** |

## Kết quả

Tỷ lệ thắng theo ghế (%) và chênh lệch giữa ghế cao nhất với thấp nhất (điểm %). Bảng đầy đủ kèm CI: `p3_seat_v1_analysis.md` và `p3_seat_v1b_analysis.md`.

| Phương án | 2p | 3p | 4p | Ghi chú |
|---|---|---|---|---|
| V0 baseline | 52,6/47,4 · **5,1** | 38,8/33,0/28,2 · **10,7** | 31,3/27,0/22,3/19,4 · **11,9** | |
| V1 nhỏ | 51,0/49,0 · 1,9 | 37,8/33,1/29,2 · 8,6 | 29,9/26,9/22,6/20,5 · 9,4 | |
| V2 lớn | 50,0/50,0 · 0,1 | 36,8/32,9/30,3 · 6,5 | 28,3/26,8/22,9/22,0 · 6,3 | |
| V3 +30/ghế | 51,7/48,3 · 3,5 | 38,0/33,2/28,8 · 9,1 | 29,8/27,2/22,6/20,4 · 9,3 | tăng ngân sách |
| V4 lệch ô | 53,4/46,6 · **6,9 (tệ hơn)** | 35,3/34,9/29,8 · 5,5 | 28,0/26,0/23,7/22,4 · 5,6 | phá sản 4p 30,9 → **32,9%** |
| **V5 rất lớn** | 50,0/50,0 · **0,1** | 35,2/33,0/31,8 · **3,3** | 26,4/26,2/23,4/24,0 · **3,0** | χ² 4p p = 0,04 (gần mức không phân biệt được) |

**Tác động phụ:**

| Phương án | Thời lượng trung vị (phút) | Tỷ lệ trận có phá sản | Tài sản cuối trung vị | Người thắng đổi khi tính theo giá sổ sách |
|---|---|---|---|---|
| V0 | 14,46 / 16,50 / 18,23 | 43,4 / 42,8 / 30,9% | 2.359 / 2.031 / 2.035 | 3,1 / 7,4 / 8,5% |
| V5 | 14,47 / 16,48 / 18,22 | 43,7 / 42,8 / 30,5% | 2.361 / 2.026 / 2.034 | 3,4 / 7,3 / 8,8% |

- V1, V2, V3 cho kết quả tương tự: thời lượng nằm trong CI của baseline, phá sản thay đổi tối đa ±0,8 điểm.
- Ngoại lệ là V4: phá sản ở 4 người +2,0 điểm.
- Tiền mặt cuối của các ghế ngày càng đều nhau: ở 4 người, chênh giữa ghế 0 và ghế 3 là 391 RC ở V0, 221 RC ở V2 và 106 RC ở V5.

## Đọc kết quả (giả thuyết, không phải quyết định)

1. **Bù tiền với tổng bằng 0 hoạt động gần như tuyến tính, và không làm hỏng kinh tế.**
   - Thời lượng, tỷ lệ phá sản và phân bố tài sản cuối không đổi trong phạm vi nhiễu.
   - Mức bù cần để gần cân bằng là khoảng ±50 RC ở 2 người, ±130 ở 3 người, ±150/±50 ở 4 người, tức tới **±10% tiền khởi đầu**.
   - Ở 4 người, ghế 1 vẫn hơi cao (26,2%). Một hình dạng bù không tuyến tính có thể tốt hơn; điều này chưa thử.
2. **V4 (lệch ô xuất phát)** cải thiện 3–4 người, nhưng làm 2 người tệ hơn và tăng phá sản. Không nên dùng nguyên dạng này.
3. **V3 (chỉ cộng cho ghế sau)** kém hiệu quả hơn bù tổng bằng 0 ở cùng biên độ, và làm tăng tổng tiền trong ván.
4. **Chưa biết:** lợi thế ghế có lớn như vậy với người thật không. Nếu thứ tự ghế được bốc ngẫu nhiên, lợi thế ghế công bằng về kỳ vọng giữa người chơi, nhưng vẫn ảnh hưởng tới từng ván. Người chơi cũng có thể cảm nhận việc bị trừ tiền vì ngồi ghế đầu là không công bằng.

**Đề xuất cho chủ dự án** (cần duyệt, chưa áp dụng):
- Nếu muốn giảm lợi thế ghế, phương án tốt nhất trong dữ liệu là **bù tiền khởi đầu với tổng bằng 0, dạng V5**. Trước khi đưa vào luật nên thử thêm dạng không tuyến tính và kiểm chứng bằng playtest người thật.
- Nếu không muốn thay đổi luật: ghi rõ trong GDD rằng thứ tự ghế được bốc ngẫu nhiên.

## Tái lập
```
GODOT=… scripts/run_experiments.sh --spec=res://tests/sim/experiments/p3_seat_v1.json --out=/abs/r.json --csv=/abs/m.csv
python3 scripts/analysis/seat_experiment.py /abs/m.csv
```
`*_matches.csv.gz` chứa toàn bộ dữ liệu thô (mỗi trận một dòng, có cột `variant` và `rules`). `*_report.json` là báo cáo GDScript (`SimStats.extended`).
