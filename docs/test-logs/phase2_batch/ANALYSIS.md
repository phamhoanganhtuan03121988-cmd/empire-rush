# Phase 2 — mô phỏng có kiểm soát (B1/B2)

**Đây là kết quả của bot heuristic, KHÔNG phải người chơi.** Thời lượng tính theo đồng hồ trận mô phỏng (mô hình thời gian trong `batch.json`), không phải thời gian người thật. Không thay đổi balance nào trong đợt này; mục "Giả thuyết" bên dưới chỉ là đề xuất để chủ dự án quyết.

## Cấu hình

| Mục | Giá trị |
|---|---|
| Lệnh | `scripts/run_playtest_batch.sh --out=… --players=2,3,4 --matches=5000 --seed=100001 --repro=200` |
| Số trận | 15.000 (5.000 mỗi cấu hình 2/3/4 người), seed 100001…105000 |
| Luật | fingerprint `d5e3a9a877afe932` (balance DRAFT v3), ghi trên **mỗi dòng** CSV (cột `rules` mới) |
| Bot | `BotPlayer`, idle 3% |
| CPU | 468 s |
| File | `matches.csv.gz` (mỗi trận một dòng; mới có thêm tiền mặt và tài sản cuối theo ghế), `summary.md` (GDScript), `crosscheck.md/json` (Python độc lập), `run.log` |

## B1 — Xác minh công cụ

| Kiểm tra | Kết quả |
|---|---|
| Tái lập trong cùng tiến trình | 600 trận chạy lại → 0 lệch hash trạng thái cuối |
| Tái lập giữa hai tiến trình | Chạy lại riêng 3×200 trận đầu: 0/600 dòng khác nhau, so mọi cột trừ `cpu_ms` |
| Không bỏ sót trận | Mỗi cấu hình đủ 5.000 dòng, 0 seed thiếu, 0 dòng trùng |
| Không trộn phiên bản luật | 1 fingerprint duy nhất trên 15.000 dòng. Công cụ Python cảnh báo nếu có nhiều hơn một |
| Thống kê đúng | Python (`scripts/analysis/batch_stats.py`) tính lại từ CSV, khớp `summary.md` (trung vị, phân vị, tỷ lệ thắng). Chạy trên batch M2.3 cũng khớp 14,4 / 16,6 / 18,1 phút |
| Trận bất thường | 0 kẹt, 0 lỗi bất biến, 0 lệnh bot bị từ chối, 0 trận > 35 phút |

## B2 — Kết quả (khoảng tin cậy 95%)

| Người | Trung vị phút (bootstrap CI) | p10–p90 | Lượt / người | Trận có phá sản | Đấu giá mở / bán | Nâng cấp / trận | Timeout / trận |
|---|---|---|---|---|---|---|---|
| 2 | **14,54** (14,47–14,61) | 10,7–17,1 | 36,5 | 44,1% | 1,91 / 1,91 | 24,1 | 11,1 |
| 3 | **16,64** (16,58–16,71) | 14,4–19,0 | 29,2 | 40,6% | 1,63 / 1,63 | 20,9 | 12,4 |
| 4 | **18,21** (18,14–18,28) | 16,0–20,6 | 24,7 | 32,4% | 1,41 / 1,41 | 16,9 | 13,0 |

- **So với baseline M2.3** (14,4 / 16,6 / 18,1 phút, 1.000 trận): trùng trong sai số. Baseline đứng vững với mẫu lớn gấp 5.
- **Kết thúc trận:** 4 người thì 99,1% hết số vòng (25 vòng); 2 người thì 44,1% kết thúc do chỉ còn một người không phá sản.
- **Tài sản cuối** (trung vị, mọi ghế): 2.381 / 2.075 / 2.017 RC.
- **Cách biệt người nhất – người nhì** (trung vị): 3.112 / 1.815 / 1.449 RC. Trận 4 người sát nhau hơn.

### Lợi thế ghế — xác nhận có ý nghĩa thống kê

| Người | Tỷ lệ thắng theo ghế (Wilson 95%) | χ² so với chia đều |
|---|---|---|
| 2 | 52,9% [51,5–54,3] · 47,1% | 16,6, p = 5×10⁻⁵ |
| 3 | 37,9% [36,6–39,3] · 32,5% · 29,6% | 54,2, p = 2×10⁻¹² |
| 4 | 30,9% [29,6–32,2] · 26,1% · 23,0% · 20,0% [18,9–21,2] | 130, p = 5×10⁻²⁸ |

- **Thứ tự:** tỷ lệ thắng giảm đơn điệu theo thứ tự ghế. Tài sản cuối trung bình cũng vậy: 4 người là 2.375 → 2.195 → 2.044 → 1.925 RC.
- **Độ lớn:** với 4 người, ghế 0 thắng nhiều hơn ghế 3 khoảng 11 điểm phần trăm.
- **Phạm vi:** đây là kết quả với bot; người chơi thật có thể khác.

## Giả thuyết (chưa kiểm chứng, không thay đổi luật)

1. **H1 — Lợi thế đi trước khi mua đất.**
   - Ghế đi trước có nhiều cơ hội gặp ô chưa có chủ hơn ở các vòng đầu.
   - Cách kiểm chứng: đo số ô mua được ở vòng 1–5 theo ghế. Cần thêm cột trong CSV; chưa làm.
2. **H2 — Hết số vòng không bù cho ghế sau.**
   - Ván kết thúc sau khi mọi ghế chơi đủ 25 vòng, nên số lượt bằng nhau. Nhưng tiền thuê ghế sau phải trả bắt đầu sớm hơn so với lúc nó kịp có tài sản.
   - Cách kiểm chứng: tách tiền thuê đã trả/nhận theo ghế.
3. **Phương án để chủ dự án cân nhắc** (đều là thay đổi balance, cần duyệt trước khi mô phỏng):
   - (a) Bù tiền khởi đầu cho ghế sau, ví dụ +25 / +50 / +75 RC.
   - (b) Ghế sau xuất phát lệch ô.
   - (c) Chấp nhận như hiện tại, vì với người thật thứ tự ghế được bốc ngẫu nhiên.
   Có thể thử bằng một tuỳ chọn thử nghiệm trong `MatchSimulator` mà không sửa `balance.json`, giống cách M1.1 đã làm.
4. **Đấu giá luôn bán được** (mở = bán ở mọi cấu hình).
   - Bot luôn trả ít nhất giá tối thiểu khi có tiền. Người thật có thể bỏ qua nhiều hơn.
   - Số liệu này **không** nói gì về độ hấp dẫn của đấu giá; cần playtest (câu hỏi 7 trong checklist).
