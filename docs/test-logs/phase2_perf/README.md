# Phase 2 — benchmark hiệu năng (A1/A2)

**Đây là số đo trên renderer phần mềm (lavapipe/llvmpipe, CPU), KHÔNG phải iPhone.**
- Số liệu dùng để so sánh tương đối trước/sau và để quy chi phí cho từng phần.
- Không dùng để kết luận FPS trên thiết bị thật. Mục tiêu 30 FPS trên mobile vẫn **chưa được đo**; quy trình đo trên máy thật nằm ở `docs/device/PERFORMANCE_BENCHMARK.md`.

## Cấu hình chung (giống nhau cho mọi lần đo)

| Mục | Giá trị |
|---|---|
| Engine | Godot 4.7.2, renderer Mobile (Vulkan) |
| Adapter | llvmpipe (LLVM 20.1.2, 256 bits), qua `xvfb-run` |
| Cửa sổ / viewport | 786×1704 / 720×1560 (portrait) |
| Cảnh | 4 người, seed 7, bố cục giữa ván cố định (giống `capture_scenarios.gd`), bảng mua ô 13 đang mở, bot bị đóng băng, đồng hồ lượt tạm dừng |
| Lệnh | `GODOT=… xvfb-run -a -s "-screen 0 2000x2000x24" godot --path client --resolution 786x1704 --script res://tests/capture/perf_bench.gd -- --out=FILE.json --frames=120` (thêm `--ablate=1` để chạy bảng quy chi phí) |
| "Trước" | commit `1493c25` (cuối M2.3) |
| "Sau" | nhánh `claude/visual-performance-multiplayer`, checkpoint A |

Định nghĩa các chỉ số:
- **frame**: thời gian thật giữa hai khung hình. Không dùng `delta`, vì Godot giới hạn `delta` ở 133 ms.
- **render GPU / CPU**: lấy từ `viewport_get_measured_render_time_*`.
- **render CPU**: luôn khoảng 0,4–0,7 ms. Nghĩa là cảnh bị giới hạn ở khâu raster/GPU, không phải ở CPU của engine.

## Kết quả — 3 lần lặp mỗi bên (`repeat_*.json`)

| Preset | p50 trước, ms (3 lần) | p50 sau, ms (3 lần) | Δ TB | GPU trước → sau | p95 trước → sau | Tam giác 3D | Tam giác bóng | Draw calls |
|---|---|---|---|---|---|---|---|---|
| low | 104.8, 107.5, 97.2 (TB 103.2) | 66.1, 69.6, 66.4 (TB 67.4) | **−35%** | 92 → 55 ms | 117 → 77 | 77,210 → 51,394 | 0 → 0 | 85 → 86 |
| medium | 258.0, 261.7, 254.2 (TB 258.0) | 230.8, 232.1, 217.5 (TB 226.8) | **−12%** | 246 → 214 ms | 291 → 268 | 77,210 → 51,394 | 77,130 → 44,390 | 113 → 114 |
| high | 554.1, 549.4, 540.5 (TB 548.0) | 482.9, 471.1, 456.1 (TB 470.1) | **−14%** | 535 → 458 ms | 612 → 522 | 77,210 → 51,394 | 140,268 → 44,390 | 113 → 114 |

- **Bộ nhớ:**
  - video ≈ 104 / 135 / 166 MB (low / medium / high), không đổi.
  - buffer 11,2 → 9,1 MB.
  - static ≈ 54 MB.
- **Nhiễu giữa các lần chạy:** khoảng ±5% (low) và ±3% (medium/high). Mọi thay đổi nhỏ hơn mức này được coi là không phân biệt được.

## Quy chi phí trước khi tối ưu (`ablation_before_1493c25.json`, p50 ms)

| Preset | base | no_shadows | no_hud | no_buildings | no_static | no_water | no_detail_tex |
|---|---|---|---|---|---|---|---|
| low | 104.1 | — | 96.0 | 93.1 | 66.4 | 73.5 | — |
| medium | 255.9 | 223.2 | — | — | 124.8 | 216.5 | 197.8 |
| high | 561.5 | 487.1 | — | — | 178.2 | — | 301.2 |

Kết luận rút ra:
- Phần lớn chi phí nằm ở **bảng tĩnh + đạo cụ** (đèn đường, cây, cửa sổ) và ở **texture chi tiết triplanar**.
- **Mặt nước** (toàn màn hình) cũng tốn đáng kể.
- **HUD** (~8%) và **toà nhà** (~10%) là phần nhỏ.

## Các bước đã làm (mỗi bước có file JSON riêng)

| Bước | Thay đổi | Bằng chứng / tác động |
|---|---|---|
| 1 `step1_shadow_split.json` | Tách bảng tĩnh thành *StaticBoard* (nền phẳng, **không đổ bóng**) và *StaticProps*. Medium dùng bóng orthogonal, High dùng 2 split thay vì 4 (bàn cờ chỉ ~9 m) | Tam giác bóng của high 140k → 77k. Cải thiện p50 nhỏ, vì phần lớn tam giác nằm ở props → dẫn tới bước 2 |
| 2 `step2_window_quads.json` | Cửa sổ dựng lại thành 3 quad (6 tam giác thay vì 24). Cây tròn, bollard, đèn đường dùng ít segment hơn | Tam giác 3D 77k → 51k, bóng 77k → 44k. Low giảm rõ. Medium gần như không đổi → bị giới hạn bởi fill-rate |
| 3 `step3_filter_lite_water.json` | Lọc anisotropic chỉ bật ở High (Low/Medium dùng mipmap tuyến tính). Thêm vật liệu *planar* (UV phẳng thay cho triplanar) cho nền đá/lát/nhựa đường/cỏ của bảng tĩnh. Low dùng `water_lite.gdshader` (unshaded, 1 lớp gợn) | Medium −13%, Low −41% so với base |
| 4 `step4_lite_water_foam.json` | Thêm lại viền bọt sát kè vào nước Low (vài phép tính ALU) vì ảnh chụp cho thấy thiếu bọt là khác biệt dễ thấy nhất | Trong mức nhiễu (xem bảng lặp) |

## Kiểm tra hình ảnh

- Ảnh: `docs/media/phase2/perf_before_after_presets.jpg`, gồm cùng cảnh `01_buy_prompt`, 786×1704 có notch, trước (`1493c25`) và sau, cho cả Low/Medium/High.
- Không thấy mất chi tiết ở Medium/High.
- Ở Low, nước phẳng hơn (không còn phản chiếu fresnel/normal map) nhưng vẫn giữ màu, gợn và viền bọt.

## Việc chưa làm / giới hạn

- Chưa có LOD mesh. Ở góc camera cố định của bàn cờ, mọi vật thể đều gần như cùng khoảng cách, nên LOD theo khoảng cách ít tác dụng. Đã giảm hình học trực tiếp thay cho LOD.
- Overdraw của HUD kính mờ chưa đo riêng; `no_hud` chỉ chiếm ~8% trên lavapipe.
- **Phải đo lại trên GPU di động thật.** GPU dạng tile (Apple/Mali/Adreno) có hồ sơ chi phí khác hẳn lavapipe: fill-rate rẻ hơn, nhưng băng thông bóng đổ đắt hơn.
