# Báo lỗi — EMPIRE RUSH (bản thử nội bộ)

Mỗi lỗi một phiếu. Không ghi tên thật; dùng mã người thử (ví dụ T03).

| Mục | Điền |
|---|---|
| Mã người thử / mã buổi | T__ / S__ |
| Bản build (commit, xem tên gói hoặc bảng thiết bị) | |
| Máy, hệ điều hành | |
| Hướng màn hình (dọc/ngang), đồ hoạ (Thấp/Vừa/Cao), giảm chuyển động (bật/tắt) | |
| Số người chơi, nhân vật | |
| Thời điểm (vòng mấy, phút mấy) | |
| Mức độ | 1 = khó chịu nhỏ · 2 = làm sai/hiểu sai nhưng chơi tiếp được · 3 = không chơi tiếp được / mất trận / treo |

**Các bước để gặp lại lỗi** (đánh số, càng cụ thể càng tốt):
1.
2.
3.

**Kết quả mong đợi:**

**Kết quả thực tế:**

**Ảnh chụp màn hình / video:** (tên file)

**Tệp kèm theo** (người điều phối thu thập bằng `collect_playtest_data.sh`):
- `telemetry/session_*.json` của trận đó (có bản ghi replay để tái hiện chính xác);
- `logs/godot.log`.

Người điều phối: chạy `tools/replay_match.gd` trên tệp telemetry (xem `docs/PHASE4_PLAYTEST_GUIDE.md` §6) và ghi kết quả:
- [ ] replay KHỚP trạng thái cuối → lỗi ở phần hiển thị/giao diện;
- [ ] trạng thái sai ngay trong replay → lỗi luật chơi, cần test hồi quy.
