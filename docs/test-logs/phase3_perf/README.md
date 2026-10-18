# Phase 3 — benchmark hiệu năng (A1/A2)

**Lavapipe (render bằng CPU), KHÔNG phải iPhone.** Số liệu chỉ dùng để so sánh trước/sau trên cùng máy và để quy chi phí cho từng phần. FPS trên thiết bị vẫn **chưa đo**.

Cấu hình giống Phase 2:
- 786×1704, cảnh cố định (4 người, seed 7, bảng mua ô 13, bot đóng băng);
- 120 khung hình;
- máy rảnh, các lần chạy trước/sau xen kẽ nhau.

Lệnh: xem `docs/device/PERFORMANCE_BENCHMARK.md` §A.

## 1. Quy chi phí trên baseline Phase 2 (`ablation_phase2_baseline_noisy.json`)
Lần chạy này trùng lúc máy đang chạy test, nên số tuyệt đối bị nhiễu. Chỉ dùng tỷ lệ để định hướng:

| Bỏ phần… | Low | Medium | High |
|---|---|---|---|
| bóng đổ | −6% | −24% | (nhiễu) |
| bảng tĩnh + đạo cụ | −35% | −47% | −61% |
| nước | −11% | −29% | −15% |
| texture chi tiết (triplanar + normal) | 0 (Low vốn tắt) | −10% | **−43%** |
| HUD | −10% | −7% | (nhiễu) |

**Kết luận:**
- Phần đắt nhất là việc lấy mẫu texture của bảng tĩnh/đạo cụ: triplanar thế giới tốn 3 lần lấy mẫu × 2 texture mỗi pixel, và High còn nhân thêm anisotropic + MSAA 4x.
- Thứ hai là nước, rồi tới bóng đổ.
- Render CPU vẫn ~0,5 ms, tức khung hình bị giới hạn ở khâu GPU/raster.

## 2. Các bước (p50 ms, trung bình các lần chạy; số trong ngoặc là từng lần)

| Bước | Low | Medium | High |
|---|---|---|---|
| Baseline Phase 2 (`42c4e8d`) | 67.2 (69, 66, 67) · p95 85 | 232.8 (228, 237, 234) · p95 261 | 481.3 (473, 497, 473) · p95 551 |
| 1. UV nướng sẵn thay triplanar cho mesh tĩnh đã gộp | 66.7 (66, 69, 66) · p95 81 | **192.0** (195, 198, 182) · p95 219 | **370.6** (367, 377, 368) · p95 420 |
| 2. + shadow atlas 2048 rõ ràng cho Medium/High | — | 183.0 (181, 185) · p95 207 | 362.3 (359, 365) · p95 410 |
| 3. + nước không nhận bóng | — | **167.0** (165, 169) · p95 187 | **351.2** (352, 351) · p95 406 |

**Tổng cộng:** Medium **−28%**, High **−27%**. Low không đổi, đúng như dự kiến vì Low đã tắt texture chi tiết và bóng.

### Bước 1 — UV nướng sẵn
- `MeshMerger` chiếu từng tam giác theo trục thế giới gần với pháp tuyến mặt của nó nhất. Với khối hộp, đây đúng là mặt mà triplanar chọn.
- Tam giác được tách đỉnh riêng, và có tangent đúng cho normal map.
- Vật liệu là bản sao không bật triplanar. `QualitySettings` vẫn bật/tắt texture chi tiết và lọc anisotropic cho các bản sao này.
- Kết quả: 1 lần lấy mẫu thay vì 3.
- Ảnh cận cảnh trước/sau: `docs/media/phase3/closeup_*_uvbake_before_after.jpg`. Không thấy khác biệt nhìn bằng mắt.
- Chi phí: buffer +1,1 MB (đỉnh không còn dùng chung).
- Chỉ áp dụng cho mesh tĩnh: toà nhà, quân cờ, xúc xắc vẫn dùng triplanar.

### Bước 2 — Shadow atlas 2048
Godot mặc định dùng 4096 trên desktop nhưng 2048 trên iOS/Android (`size.mobile`). Vì vậy benchmark desktop trước đây đo một shadow pass nặng hơn cấu hình thật của điện thoại.
- Đặt 2048 rõ ràng làm desktop khớp với điện thoại.
- Tác động nằm trong khoảng nhiễu: −5% / −2%.
- Bộ nhớ video Medium giảm 134,7 → 111,8 MB.
- Đây là **chỉnh cấu hình cho đúng**, không tính là tối ưu.

### Bước 3 — Nước không nhận bóng
Bóng của bàn cờ trên mặt nước hiện thành các mảng xanh đậm lốm đốm (artifact của shadow map). Bỏ đi thì hình sạch hơn và nhanh hơn 9% ở Medium. Ảnh: `docs/media/phase3/water_shadow_before_after.jpg`.

## 3. Draw call, tam giác, bộ nhớ (Medium, sau tối ưu)

| | Giá trị |
|---|---|
| Draw call | tổng 118 = 3D 43 + bóng 28 + 2D/HUD 47 (HUD = tổng − 3D − bóng) |
| Tam giác | 3D 52.162, bóng 44.390 (không đổi: bước 1 không thêm tam giác) |
| Video / texture / buffer | 111,8 / 79,7 / 10,2 MB |
| Thời gian tải | `perf_bench.gd` hiện ghi `meta.load_ms` (nạp scene → khung hình đầu); xem số cuối ở báo cáo Phase 3 |

## 4. Chưa làm
- MSAA 4x của High chưa được đánh giá riêng (nó là một lựa chọn chất lượng có chủ đích của High).
- Overdraw của HUD kính mờ chưa đo riêng.
- **Tất cả số trên cần đo lại trên GPU di động.** GPU dạng tile có hồ sơ chi phí khác lavapipe.
