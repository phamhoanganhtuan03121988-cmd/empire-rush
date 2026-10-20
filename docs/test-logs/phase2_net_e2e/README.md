# Phase 2 — kiểm thử multiplayer nhiều tiến trình (C3)

Mỗi thư mục là **một lần chạy thật**: 1 tiến trình server Godot headless + 2–4 tiến trình client Godot headless, kết nối qua **WebSocket thật** trên 127.0.0.1. Kịch bản và kết quả được mô tả trong `docs/M3_ARCHITECTURE.md` §3b.

## Cách chạy lại

```
GODOT=/path/to/godot PLAYERS=4 SEED=404 scripts/run_net_e2e.sh docs/test-logs/phase2_net_e2e/players4_seed404
```

| Biến | Mặc định | Ý nghĩa |
|---|---|---|
| `PLAYERS` | 4 | Số người chơi |
| `SEED` | 404 | Seed của trận |
| `TIME_SCALE` | 10 | Đồng hồ server chạy nhanh hơn thời gian thật bao nhiêu lần |
| `KILL_AT_S` | 12 | Giây thứ mấy thì kill -9 server |
| `DROP_AT_S` | 20 | Giây thứ mấy client 2 tự ngắt |
| `DOWN_S` | 6 | Client 2 vắng bao nhiêu giây |
| `HOLD_MS` | 20000 | Thời gian giữ ghế (giờ trận) |
| `POLICY` | `bot` | `bot` hoặc `timers` |

## File trong mỗi thư mục

| File | Nội dung |
|---|---|
| `journal.jsonl` | Nhật ký ghi trước (write-ahead) của server: lệnh đã chấp nhận và các lần `advance` kèm giờ server |
| `server_result.json` | Hash cuối, thống kê, chính sách, kết quả trận |
| `server.log` | Log server, gồm dòng `RESUMED` sau khi bị kill |
| `client_N.json` | Hash/phiên bản cuối của từng client, thống kê, các hành vi "phá" đã thực hiện |
| `verify.json` | Kết quả `tools/net/verify_e2e.gd` |
| `server_resources.log` | Mẫu RSS (KiB) và thời gian CPU của tiến trình server, lấy mỗi 0,5 s |

## Kết quả (commit của checkpoint C, Godot 4.7.2, Linux container)

| Lần chạy | Người | Chính sách | Kết quả | Kết thúc | state_version | Lệnh áp dụng | Trùng (đã khử) | Lệnh bị từ chối | Frame lỗi bị chặn | Bot: tiếp quản / nước đi / trả ghế | Restart | Client kết nối lại | Server |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| players2_seed11 | 2 | bot | PASS | round_cap r40 | 206 | 204 | 20 | BAD_REQUEST 2, STALE_STATE 5 | BAD_REQUEST 2, PAYLOAD_TOO_LARGE 3, PROTOCOL_UNSUPPORTED 3 | 0 / 0 / 0 (2 người: không có client 2) | 1 | 2 | RSS ≤ 107 MB |
| players3_seed12 | 3 | bot | PASS | round_cap r30 | 214 | 213 | 12 | BAD_REQUEST 2, STALE_STATE 2 | BAD_REQUEST 2, PAYLOAD_TOO_LARGE 2, PROTOCOL_UNSUPPORTED 2 | 1 / 11 / 1 | 1 | 4 | RSS ≤ 107 MB |
| players4_seed13_policytimers | 4 | timers | PASS | round_cap r25 | 268 | 251 | 12 | BAD_REQUEST 2, STALE_STATE 19 | BAD_REQUEST 1, PAYLOAD_TOO_LARGE 2, PROTOCOL_UNSUPPORTED 2 | 0 / 0 / 0 (đúng: chỉ timer) | 1 | 5 | RSS ≤ 107 MB |
| players4_seed14 | 4 | bot | PASS | round_cap r25 | 246 | 236 | 10 | BAD_REQUEST 2, NOT_OWNER 1, STALE_STATE 13, WRONG_PHASE 1 | BAD_REQUEST 1, PAYLOAD_TOO_LARGE 2, PROTOCOL_UNSUPPORTED 2 | 1 / 8 / 1 | 1 | 5 | RSS ≤ 107 MB |
| players4_seed404 | 4 | bot | PASS | round_cap r25 | 238 | 232 | 12 | BAD_REQUEST 2, NOT_OWNER 1, STALE_STATE 5, WRONG_PHASE 1 | BAD_REQUEST 1, PAYLOAD_TOO_LARGE 2, PROTOCOL_UNSUPPORTED 2 | 1 / 8 / 1 | 1 | 5 | RSS ≤ 107 MB |

## Cách đọc kết quả

- **`STALE_STATE`** là hành vi đúng:
  - client gửi lệnh dựa trên một phiên bản trạng thái cũ (ví dụ gửi lại sau khi server khởi động lại, hoặc lệnh "stale" cố ý của client 1);
  - server từ chối mà không đổi trạng thái;
  - client lấy snapshot mới.
- **`NOT_OWNER` / `WRONG_PHASE`** đến từ client 3: client này tự sửa trạng thái cục bộ (giả giàu, giả sở hữu mọi ô) rồi hành động theo đó.
- **CPU và bộ nhớ:**
  - CPU server cho cả trận sau restart chỉ khoảng 1 s.
  - RSS ~107 MB, phần lớn là nền của engine Godot. Bộ nhớ tĩnh đỉnh 35 MB.
  - Đây là số đo **một trận / một tiến trình**. Chưa đo nhiều trận trong một tiến trình, và chưa chạy soak 24 h.
- **Chưa chứng minh:** mạng thật (mất gói, độ trễ, NAT, chuyển Wi-Fi ↔ 4G), TLS, client trên điện thoại.
