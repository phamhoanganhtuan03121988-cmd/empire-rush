# EMPIRE RUSH — Rà soát an ninh multiplayer (Phase 4)

**Phạm vi:**
- `RoomServer`, `MatchHost`, `NetProtocol`, `server_main.gd` / `client_main.gd`;
- telemetry, replay, log và gói playtest.

**Cách làm:** đọc code và chạy test. **Không** có máy chủ Internet thật, không có kiểm thử xâm nhập từ bên ngoài. Mọi số liệu đến từ container (loopback / LAN mô phỏng).

## 1. Đã kiểm tra trong Phase 4
| Hạng mục | Kết quả | Bằng chứng |
|---|---|---|
| Cách ly giữa các phòng | Mỗi phòng replay riêng ra đúng hash | `test_three_concurrent_rooms…`, e2e `concurrent` |
| Kiểm tra lệnh, giả mạo danh tính | `player_id` lấy từ phiên. Lệnh mạo danh → `UNAUTHENTICATED`; sai lượt/sai phase bị từ chối | e2e `chaos` (NOT_OWNER, WRONG_PHASE, STALE_STATE) |
| Lệnh trùng | Khử trùng theo `command_id` | e2e `chaos` (12 bản trùng) |
| Flood | Giới hạn tốc độ theo link; link flood mãi bị đóng | `test_rate_limit…`, e2e `chaos` |
| Crash / khôi phục | Journal ghi trước, `kill -9` rồi khởi động lại | e2e `chaos`, `client_restart` |
| Reconnect / takeover / reclaim | Giữ ghế 60 s → bot → người chơi lấy lại ghế | `test_player_never_returns…`, `test_disconnect_at_turn_change` |
| **Mới:** rớt mạng đúng lúc có giao dịch chờ | Người nhận rớt 30 s: giao dịch **hết hạn đúng một lần**. Người đề nghị rớt: người nhận vẫn trả lời. Trận kết thúc, replay khớp, client hội tụ | `test_disconnect_while_trade_is_pending` |
| **Mới:** rớt mạng đúng lúc đổi lượt | Bot giữ ghế sau 60 s; người chơi quay lại lúc 70 s và chơi tiếp; trận kết thúc bình thường, replay khớp | `test_disconnect_at_turn_change` |
| TLS | `wss://` có xác minh chứng chỉ chạy được. CA sai và `ws://` thường bị từ chối khi client yêu cầu TLS | e2e `tls`, `tls_bad_ca` |
| Token | 128 bit ngẫu nhiên, gửi một lần. Server chỉ lưu SHA-256 (bộ nhớ, `meta.json`). Log không có token | `test_room_errors_and_identity`, quét log e2e (§3) |
| Thông tin ẩn | Snapshot gửi client không có seed, trạng thái RNG hay thứ tự bộ bài sự kiện | `GameEngine.public_snapshot` |
| Telemetry / replay / log offline | Không token, khoá, e-mail, đường dẫn home hay UUID. Xoá thông tin không làm hỏng JSON hay replay | `privacy_scan.py --self-test`, 41 replay sau khi xoá vẫn khớp |

## 2. Lỗi tìm thấy và đã sửa trong Phase 4
| # | Lỗi | Mức | Sửa | Test hồi quy |
|---|---|---|---|---|
| S1 | Một link gửi `CreateRoom` liên tục: rate limit 20/s cho phép chiếm cả 64 phòng trong ~3 s. Phòng chưa đủ người **không bao giờ hết hạn** → mọi người khác nhận `SERVER_FULL` mãi mãi. Một link cũng có thể `JoinRoom` nhiều lần để chiếm nhiều ghế | **Cao** khi mở công khai | Một phòng mỗi link (`BAD_REQUEST`). Phòng chờ quá 10 phút bị xoá, token hết hiệu lực, link bị đóng (`ROOM_CLOSED`) | `test_one_room_per_link_and_waiting_rooms_expire` |
| S2 | Test UI ghi 45 tệp ghi trận **không replay được** (test sửa thẳng trạng thái engine) vào đúng thư mục người thử sẽ gom và gửi | Thấp (dữ liệu sai lẫn vào phân tích) | Test ghi vào `user://test_telemetry/`. Runner UI báo lỗi nếu có tệp mới trong `user://telemetry` | `ui_test_runner.gd` (kiểm tra trước/sau) |
| S3 | Bộ quét thiếu: đường dẫn bundle iOS / UUID, số điện thoại, tên Windows có ký tự `\u` (để lại một phần tên) | Trung bình | Thêm luật, kiểm tra JSON còn đọc được, chặn gửi khi có ảnh chưa xem | `privacy_scan.py --self-test` (chạy trong CI readiness) |

## 3. Rủi ro còn lại
**Mức độ** = tác động nếu server được mở ra Internet. Trên LAN tin cậy, hầu hết là Thấp.

| # | Rủi ro | Mức | Điều kiện khai thác | Cách sửa đề xuất |
|---|---|---|---|---|
| R1 | **Mặc định là `ws://` không mã hoá.** Token và mã phòng đi dạng rõ. Kẻ nghe lén có thể dùng token để chiếm ghế (`SESSION_REPLACED` đẩy người chơi thật ra) | **Cao** trên mạng không tin cậy | Cùng Wi-Fi / mạng trung gian, server chạy không có `--tls_key` | Bắt buộc TLS khi bind khác `127.0.0.1` (từ chối khởi động nếu không có cờ `--allow-plain`). Cần chứng chỉ + tên miền (chủ dự án) |
| R2 | **Đoán mã phòng.** Mã 6 ký tự / 31 chữ (~8,9×10⁸). Không giới hạn theo IP: 512 link × 20 lần/s ≈ 10.000 lần đoán/s. Với 64 phòng đang chờ, trung bình ~23 phút trúng một phòng | Trung bình | Server công khai, có nhiều phòng đang chờ. Hậu quả: người lạ vào ghế trống của phòng đang chờ. Không chiếm được ghế đã có người, không xem được phòng khác | Đếm `ROOM_NOT_FOUND` theo IP và chặn tạm. Mã dài hơn (8 ký tự ≈ 8,5×10¹¹). Chủ phòng duyệt người vào |
| R3 | **Cạn link / phòng do nhiều kết nối** (sau khi sửa S1). 512 link, 64 phòng, không giới hạn theo IP. Kẻ tấn công mở 64 kết nối tạo 64 phòng mỗi 10 phút, hoặc giữ 512 kết nối nửa mở | Trung bình | Server công khai | Transport truyền IP vào `RoomServer`; giới hạn link/phòng theo IP; reverse proxy có rate limit |
| R4 | **Seed 32 bit.** `ErRng.set_seed` cắt seed còn 32 bit; phòng online dùng 31 bit ngẫu nhiên. Client sửa đổi có thể dò seed offline từ vài lần đổ xúc xắc đầu (~2³¹ phép thử), rồi đoán trước xúc xắc và lá bài | Trung bình (gian lận online) | Người chơi có kỹ thuật, chơi online. Offline không ảnh hưởng | Seed/trạng thái RNG ≥ 128 bit cho phòng online; hoặc server rút xúc xắc bằng CSPRNG và ghi kết quả vào journal. Đổi engine + protocol, cần quyết định riêng |
| R5 | Không có tài khoản. Token là thông tin xác thực duy nhất; `client_main --session=FILE` lưu token dạng rõ trên đĩa | Thấp | Người khác đọc được thư mục người dùng trên máy client | Quyền tệp 0600; token hết hạn khi phòng kết thúc (đã có) |
| R6 | Một tiến trình, một luồng; journal không xoay vòng | Thấp | Tải lớn hoặc chạy rất lâu | Giới hạn số phòng theo tài nguyên; dọn journal của phòng đã kết thúc |
| R7 | Chưa kiểm thử trên Internet thật, chưa có chống DDoS, chưa quản lý chứng chỉ | — | — | Cần host, tên miền, chứng chỉ (chủ dự án; xem `docs/SERVER_DEPLOYMENT.md`) |
| R8 | Ảnh chụp màn hình và chữ tự do trong phiếu không quét tự động được | Thấp | Người điều phối gửi ảnh/phiếu chưa xem | Đã chặn: `collect_playtest_data.sh` trả `NOT READY` tới khi có `--binaries-reviewed`. Phiếu chỉ dùng mã T01… |

**Không có rủi ro nào ở trên ảnh hưởng tới bản playtest hiện tại**: bản đó chạy offline, không mở cổng mạng.

## 4. Ghi chú về log đã commit
Một số log Phase 2–3 trong `docs/test-logs/` có đường dẫn thư mục tạm của môi trường build (`/tmp/claude-0/…/<session id>/scratchpad/…`).
- Đây **không phải** thông tin xác thực. Session id đó đã công khai trong dòng `Claude-Session:` của commit.
- Không có token, khoá hay dữ liệu người dùng.
- Không viết lại lịch sử git vì lý do này.
