# EMPIRE RUSH: Luật thực tế của một trận (đối chiếu GDD ↔ engine)

Ngày kiểm tra: 2026-10-19 · Phase 5.1, branch `claude/phase5-1-player-experience`. Luật và dữ liệu luật không đổi so với `8e571e2` (`git diff -- client/data/rules` rỗng).
Tài liệu này mô tả **luật đang chạy thật trong engine**, kèm nguồn file:dòng. Số dòng ứng với mã lúc kiểm tra và có thể lệch nhẹ ở các commit sau. Tóm tắt cho người mới: `docs/HUONG_DAN_NHANH.md`; đánh giá độ phức tạp: `docs/NEW_PLAYER_RULES_AUDIT.md`.

**Cập nhật Phase 5.1** (chỉ giao diện, luật không đổi). Một số nhận xét về UI bên dưới mô tả bản trước 5.1:
- Hướng dẫn trong game đã nói "đi qua **hoặc dừng đúng** Xuất phát" và không còn hứa nút đề nghị giao dịch (§2, §12 #7 và #14).
- Phần giới thiệu còn 2 trang; hướng dẫn 7 thẻ đọc liền được thay bằng gợi ý theo ngữ cảnh (`CoachOverlay`).
- Thẻ người chơi hiện "Tài sản" (§1). Ba vai trò được trình bày là "Vai trò (kỹ năng)", tách khỏi nhân vật ngoại hình (§7).

**Ký hiệu nguồn** (mọi số liệu đều trích file:dòng):
- GDD = `docs/GAME_RULES_AND_GDD.md`, R = `docs/RULES_M1.md`, PLAN = `docs/IMPLEMENTATION_PLAN.md`, TASK = `docs/CLAUDE_TASK_PROMPT.md`, AUDIT = `docs/M0_AUDIT_REPORT.md`, V3 = `docs/M1_2_BALANCE_V3_REPORT.md`
- bal = `client/data/rules/balance.json`, board = `.../board.json`, ev = `.../events.json`, opp = `.../opportunities.json`, chr = `.../characters.json`, vi = `client/data/presentation/strings_vi.json`, theme = `client/data/presentation/board_theme.json`
- eng = `client/scripts/domain/game_engine.gd`, cfg = `game_config.gd`, st = `game_state.gd`, clk = `match_clock.gd`, bot = `client/scripts/sim/bot_player.gd`, lm = `client/scripts/presentation/local_match.gd`, hud = `client/scripts/ui/game_hud.gd`, guide = `client/scripts/ui/rules_guide.gd`, txt = `client/scripts/ui/ui_text.gd`, menu = `client/scripts/ui/start_menu.gd`, setup = `client/scripts/ui/match_setup.gd`, main = `client/scripts/main.gd`

---

## 0. Nguồn nào có thẩm quyền?

- Repo **không có `CLAUDE.md`** (đã kiểm tra thư mục gốc và toàn repo).
- GDD là "product baseline" (TASK:6; README:16). PROTOCOL cũng ghi rằng khi PROTOCOL và GDD mâu thuẫn thì GDD thắng (PROTOCOL:4). Khi ảnh tham khảo mâu thuẫn với GDD thì GDD thắng (PLAN:81; AUDIT:31-41).
- Chỗ GDD còn thiếu được lấp bằng **quyết định G1–G12 đã được chủ dự án duyệt ở M0** (AUDIT:44-59; R:4 "Baseline: GDD v1.0 plus the owner's approved decisions G1–G12").
- Số cân bằng **v3 (Option C)** cũng đã được duyệt (V3:6-15; PLAN:7), nhưng vẫn là **DRAFT, chưa khóa** (bal:2; R:3).
- Theo TASK:13, mọi giá trị cân bằng phải nằm trong `data/rules/*.json`. UI không được hard-code.
- **Kết luận thực hành:**
  1. Muốn biết "trận đấu thực sự chạy thế nào" thì xem **engine + JSON**, được mô tả trong `RULES_M1.md`.
  2. Chỗ engine khác GDD đều đã có quyết định chủ dự án (G1–G12, M1.2), trừ các mục có cờ **[REVIEW]** trong R. Các mục [REVIEW] là cách hiểu đang chờ xác nhận (R:5).
  3. Khi GDD mâu thuẫn với chính nó hoặc chưa có quyết định, đó là điểm mở.

---

## 1. Kết thúc trận & người thắng

**Ba điều kiện kết thúc.** Engine kiểm tra **chỉ ở cuối mỗi lượt**, theo đúng thứ tự sau (eng:666-687; R:45-49):
1. **Chỉ còn ≤1 người chưa phá sản** → `last_solvent` (eng:670-672).
2. **Hết số vòng tối đa** → `round_cap`. Trận dừng khi ghế còn sống cuối cùng của vòng cuối vừa xong lượt (eng:680-683).
   - Số vòng phụ thuộc số người ngồi lúc bắt đầu: **2 người = 40, 3 người = 30, 4 người = 25** (bal:6-11; cfg:268-270).
   - Phá sản giữa trận **không** đổi mức trần này (R:47).
   - `max_rounds` = 25 chỉ là giá trị dự phòng (bal:5).
3. **Hết 30 phút**, tức `time_cap_ms` = 1 800 000 (bal:12) → `time_cap`.
   - Chỉ kiểm tra ở cuối lượt (eng:684-687; G9 AUDIT:56).
   - Ở chế độ offline, đồng hồ trận dừng khi app chạy nền (R:65-84).
   - Theo mô phỏng, gần như không trận nào kết thúc vì hết giờ, trừ mô hình "chơi chậm" với 4 người: 18% (V3:139-145).

**Xếp hạng** (eng:725-761; R:163-172):
- Tài sản ròng = **tiền mặt + Σ giá trị thanh lý** của đất đang sở hữu (có tính nhà) (eng:195-204).
  - Giá trị thanh lý = `liquidation_value` của hạng đất + `cấp × upgrade_cost × 50%` (eng:190-192; bal:42 `upgrade_refund_pct` = 50).
  - Người đã phá sản có tài sản ròng = 0 (eng:199-200).
  - **Không** tính thưởng mục tiêu, không có khoản nợ (G11; R:165-166).
- Thứ tự so sánh:
  1. Người còn trụ xếp trên người phá sản.
  2. Giữa những người còn trụ: tài sản ròng ↓, rồi **số quận trọn vẹn** ↓, rồi **tiền mặt** ↓ (eng:752-761).
  3. Giữa những người phá sản: ai phá sản muộn hơn xếp trên.
- Bằng nhau mọi khóa thì **đồng hạng** (1, 1, 3). Không dùng thứ tự ghế làm tie-break ngầm (eng:736-741; R:171 [REVIEW]).
- Màn kết quả hiển thị tài sản ròng (hud:617). Lý do kết thúc lấy từ txt:48-50.

**Lưu ý cho người mới:** tài sản ròng tính đất theo **giá thanh lý = 50% giá mua**, không theo giá mua (bal:46-52). Mua đất vì thế làm giảm ngay tài sản ròng trên giấy, vì tiền mặt đổi thành đất chỉ được tính một nửa. Đất chỉ có lợi khi thu tiền thuê bù lại.

---

## 2. Tiền khởi đầu & ô Xuất phát

- Tiền khởi đầu: **1 500 RC** (bal:3; eng:54). Mọi quân bắt đầu ở ô 0 (R:10).
- Đi **qua hoặc dừng đúng** ô Xuất phát: **+200 RC** (bal:4).
  - Engine kiểm tra `raw >= board_size`, nên dừng đúng ô cũng được thưởng (eng:573-579; R:33).
- Dừng ở Xuất phát không có tác dụng gì thêm (eng:610-612).
- Thẻ "Tàu Tốc Hành" đưa quân thẳng tới Xuất phát và được +200 (ev:11-13; eng:941-943).
- Hướng dẫn trong game chỉ nói "**Qua** ô Xuất phát nhận 200 RC" (guide:45), chưa nói rằng dừng đúng ô cũng được (xem §12).

---

## 3. Xúc xắc, di chuyển, bàn cờ

- **2 viên d6.** Quân đi số ô bằng tổng (eng:559-567; GDD:17).
- **Gieo đôi không có gì thêm**: không thêm lượt, không có "tù" (G5: AUDIT:52; eng:565; R:34). Trò chơi không có ô Tù.
- RNG duy nhất là `ErRng`, gieo hạt theo trận (R:13). Kỹ năng nhân vật không bao giờ đụng tới xúc xắc (chr:2; R:191).
- Bàn có **28 ô**, đi theo chiều tăng chỉ số, quay vòng (eng:574; cfg:162-167 kiểm tra 28 ô / 21 đất / 1 Start / 2 Sự kiện / 2 Cơ hội / 1 Nghỉ / 1 Đặc biệt).
- Chỉ có 6 loại ô (cfg:8).

### Danh sách ô theo thứ tự

Nguồn: board:6-270 (vị trí ô), board:272-319 (quận và hạng), bal:46-52 (giá); tên tiếng Việt lấy từ vi:128-190 và theme.

| # | Loại | Tên (EN / VI) | Quận (VI) | Hạng | Giá | Thuê cơ bản |
|---|---|---|---|---|---|---|
| 0 | START | Start / XUẤT PHÁT | – | – | – | +200 khi qua/dừng |
| 1 | PROPERTY | Fish Lane / Ngõ Cá | D1 Old Market / Chợ Cũ | 1 | 60 | 8 |
| 2 | PROPERTY | Lantern Row / Phố Đèn Lồng | D1 | 1 | 60 | 8 |
| 3 | OPPORTUNITY (?) | Cơ hội | – | – | – | – |
| 4 | PROPERTY | Canal Steps / Bến Kênh | D1 | 1 | 60 | 8 |
| 5 | PROPERTY | Dockside / Bến Tàu | D2 Harbor Quarter / Cảng Biển (**tourist**) | 2 | 90 | 11 |
| 6 | PROPERTY | Ferry Point / Mũi Phà | D2 (tourist) | 2 | 90 | 11 |
| 7 | PROPERTY | Net Street / Phố Lưới | D2 (tourist) | 2 | 90 | 11 |
| 8 | CITY_EVENT (!) | Sự kiện | – | – | – | rút thẻ |
| 9 | PROPERTY | Willow Bank / Bờ Liễu | D3 Riverside / Ven Sông | 3 | 120 | 15 |
| 10 | PROPERTY | Bridge End / Đầu Cầu | D3 | 3 | 120 | 15 |
| 11 | PROPERTY | Mill Court / Sân Cối Xay | D3 | 3 | 120 | 15 |
| 12 | REST | Rest/Inspection / NGHỈ | – | – | – | không có gì (G2) |
| 13 | PROPERTY | Lotus Park / Công Viên Sen | D4 Garden District / Phố Hoa | 4 | 150 | 18 |
| 14 | PROPERTY | Tea Terrace / Đồi Trà | D4 | 4 | 150 | 18 |
| 15 | PROPERTY | Orchid Walk / Lối Lan | D4 | 4 | 150 | 18 |
| 16 | OPPORTUNITY (?) | Cơ hội | – | – | – | – |
| 17 | PROPERTY | Sunset Pier / Cầu Hoàng Hôn | D5 Beach Resort / Khu Nghỉ Dưỡng (**tourist**) | 5 | 180 | 22 |
| 18 | PROPERTY | Palm Bay / Vịnh Cọ | D5 (tourist) | 5 | 180 | 22 |
| 19 | PROPERTY | Coral Strand / Bãi San Hô | D5 (tourist) | 5 | 180 | 22 |
| 20 | CITY_EVENT (!) | Sự kiện | – | – | – | rút thẻ |
| 21 | PROPERTY | Exchange Plaza / Quảng Trường Giao Dịch | D6 Financial Center / Trung Tâm Tài Chính | 6 | 220 | 26 |
| 22 | PROPERTY | Bank Tower / Tháp Ngân Hàng | D6 | 6 | 220 | 26 |
| 23 | PROPERTY | Capital Square / Quảng Trường Vốn | D6 | 6 | 220 | 26 |
| 24 | SPECIAL (%) | Wealth Tax / THUẾ | – | – | – | thuế tài sản |
| 25 | PROPERTY | Crown Spire / Tháp Vương Miện | D7 Skyline Heights / Đỉnh Thượng Lưu | 7 | 260 | 32 |
| 26 | PROPERTY | Sky Garden / Vườn Trên Mây | D7 | 7 | 260 | 32 |
| 27 | PROPERTY | Imperial Tower / Tháp Hoàng Gia | D7 | 7 | 260 | 32 |

- Thẻ `tourist` được gắn cho D2 và D5 (board:283, board:303).
- Ở lượt đầu, xác suất dừng ở ô đất là 28/36 ≈ 78%. Con số này tôi tính từ phân phối 2d6 trên các ô 2–12, không có trong docs.

---

## 4. Mua đất, BỎ QUA, đấu giá

**Mua đất:**
- Chỉ người vừa dừng ở ô đất chưa có chủ được mua, trong pha `AwaitBuyDecision` (eng:585-590, 330-344).
- Giá mua đúng bằng `price` của hạng đất (bal:46-52). Phải có tiền mặt ≥ giá (eng:338-339).
- Thiếu tiền thì nút MUA bị khóa và hiện "Không đủ tiền mua" (hud:851-861; txt:19).
- **Không thể** bán đất để lấy tiền mua.
- Mua xong thì chuyển sang pha hành động chiến lược (eng:343).

**"BỎ QUA (đấu giá)"** (txt:17) là lệnh `PassProperty`. Lệnh này **luôn mở đấu giá** cho mảnh đất đó (eng:347-356). Hết giờ ở pha mua cũng bị coi như Bỏ qua và mở đấu giá (eng:1017-1020).

**Luật đấu giá** (bal:17-25; eng:359-386, 768-792; R:96-104):
- Kiểu trả giá tăng dần, **12 giây** (bal:18).
- Giá mở tối thiểu = `max(10, 10% giá đất)` (bal:19-20; eng:774). Theo hạng 1→7: **10 / 10 / 12 / 15 / 18 / 22 / 26 RC**.
- Mỗi lần trả sau phải ≥ giá hiện tại + **10 RC** (bal:21; eng:256).
- Giá trả không được vượt tiền mặt của người trả (eng:376).
- Người đang dẫn đầu không được tự nâng giá của mình (eng:370).
- **Ai được trả giá:** mọi người chưa phá sản, **kể cả người vừa bỏ qua** (eng:365; R:99).
- **Chống "bắn tỉa"** (anti-snipe): giá trả đặt khi còn ≤3 s thì cộng thêm 3 s, tối đa 2 lần (bal:22-24; eng:382-385).
- **Khi hết giờ:** người trả cao nhất trả tiền và nhận đất. **Không ai trả giá** thì đất vẫn thuộc ngân hàng, và người sau dừng ở đó lại có quyền mua (eng:782-792).
- Đồng hồ lượt **tạm dừng** trong lúc đấu giá (eng:769; R:62).

**Giao diện người chơi khi đấu giá:**
- Chỉ có **2 nút**: "TRẢ <mức tối thiểu>" và "TRẢ <tối thiểu + 40>" (hud:862-876). Không nhập được số tùy ý.
- Ở bản offline, người chơi người luôn được phục vụ trong pha đấu giá, nếu chưa phá sản (lm:136-140).

**Bot khi đấu giá:**
- Bot định giá đất bằng giá × `buy_factor`, với `buy_factor` từ 80–140%. Nếu mảnh đất giúp bot hoàn thành quận thì giá trị ×1.5 (bot:91-106).
- Bot luôn giữ lại một nửa `reserve`. Mỗi lần bot trả mức tối thiểu cộng 0–2 bước 10 RC.
- Ở pha đấu giá, bot phản ứng nhanh hơn (độ trễ ×0.6, lm:93-94).
- Bot **mua thẳng** khi đủ tiền và còn lại ≥ `reserve` (60–220 RC), hoặc khi mảnh đất giúp hoàn thành quận. Trường hợp khác bot bỏ qua (bot:26, 80-88).

---

## 5. Tiền thuê, quận, nâng cấp, bán đất

**Tiền thuê:**
- Công thức: `thuê = base_rent × pct / 100`, và **chỉ một dòng hệ số được áp dụng**, không cộng dồn (bal:34-41; eng:213-235; R:106-117).

| Trạng thái | pct | H1 | H2 | H3 | H4 | H5 | H6 | H7 |
|---|---|---|---|---|---|---|---|---|
| Cấp 0, chưa đủ quận | 100 | 8 | 11 | 15 | 18 | 22 | 26 | 32 |
| Cấp 0, **đủ quận** (×2) | 200 | 16 | 22 | 30 | 36 | 44 | 52 | 64 |
| Cấp 1 (×7) | 700 | 56 | 77 | 105 | 126 | 154 | 182 | 224 |
| Cấp 2 (×22) | 2200 | 176 | 242 | 330 | 396 | 484 | 572 | 704 |
| Cấp 3 (×55) | 5500 | 440 | 605 | 825 | 990 | 1 210 | 1 430 | **1 760** |

(Số trong bảng khớp với V3:31-39.)

- "Đủ quận" nghĩa là cùng một chủ sở hữu cả 3 ô của quận (eng:171-179).
- **Hệ số phía chủ đất:** các thẻ sự kiện được **cộng** thành một phần trăm chung: `thuê × (100+Σpct)/100`, nhỏ nhất là 0 (eng:227-235). Gồm Bùng Nổ Du Lịch +50% (cho **cả D2 và D5**), Mất Điện −50%, Hợp Đồng Quảng Cáo −25%.
- **Hệ số phía người trả:** sau đó áp dụng **một** lần giảm 50% dùng một lần (Đàm Phán, Dạ Tiệc Từ Thiện), rồi mới áp trần của Bảo Hiểm Tiền Thuê (eng:259-271).
- Tiền thuê lớn nhất có thể gặp là **1 815 RC**: D5 cấp 3 = 1 210, nhân 1.5 khi có Bùng Nổ Du Lịch (R:117; V3:174).
- Tiền thuê bị trừ **tự động** (eng:594-598). Dừng ở đất của chính mình thì không có gì xảy ra (eng:591-593).

**Nâng cấp** (eng:290-301, 409-428; R:125-130):
- **Điều kiện:**
  - Sở hữu đủ 3 ô của quận.
  - Ô đó đang ở cấp < 3 (bal:43 `max_level` = 3).
  - Có đủ tiền.
- **Khi nào được nâng:**
  - Chỉ trong pha **StrategyAction**, tức sau khi đã đổ xúc xắc và xử lý xong ô vừa dừng. Không nâng được trước khi đổ.
  - Mỗi lần chỉ lên **1 cấp**. Nâng cấp **tính là hành động chiến lược của lượt và kết thúc lượt ngay** (eng:426-427). Vì vậy mỗi lượt nâng tối đa 1 cấp cho 1 ô.
  - **Không có luật "xây đều"**: được nâng một ô lên cấp 3 trong khi hai ô kia vẫn ở cấp 0. Engine không kiểm tra điều này.
- **Chi phí theo hạng 1→7:** **30 / 30 / 45 / 45 / 60 / 60 / 75** (bal:46-52). Công thức `cost × (100 − giảm)/100`, làm tròn xuống (eng:274-287).
- **Giảm giá:**
  - Doanh Nhân luôn được giảm 10% (chr:5-8).
  - Cộng thêm **tối đa một** phiếu giảm 50% (thẻ Trợ Giá Xây Dựng hoặc Cơ hội Quỹ Cải Tạo).
  - Tổng giảm tối đa 75% (bal:44).
  - Ví dụ cho Doanh Nhân: 30→27, 45→40, 60→54, 75→67.
- Nếu quận bị tách ra sau đó (do thanh lý), nhà xây rồi vẫn giữ nguyên. Tiền thuê khi đó dùng dòng của cấp hiện tại (R:130).

**Bán / phá dỡ:**
- **Không có** bán tự nguyện, không có phá nhà, không có thế chấp.
- Chỉ được **thanh lý cho ngân hàng trong pha Cứu nợ** (§9; eng:517-535). Thanh lý xong, đất về ngân hàng ở **cấp 0** và người khác lại có thể mua (eng:866-871).
- Giá trị thanh lý (eng:190-192):

| Hạng | Cấp 0 | Cấp 1 | Cấp 2 | Cấp 3 |
|---|---|---|---|---|
| 1 | 30 | 45 | 60 | 75 |
| 2 | 45 | 60 | 75 | 90 |
| 3 | 60 | 82 | 105 | 127 |
| 4 | 75 | 97 | 120 | 142 |
| 5 | 90 | 120 | 150 | 180 |
| 6 | 110 | 140 | 170 | 200 |
| 7 | 130 | 167 | 205 | 242 |

- Giá trị cấp 0 bằng 50% giá mua (bal:46-52). Mỗi cấp nhà cộng thêm `upgrade_cost × 50%`, làm tròn xuống.

---

## 6. Cấu trúc lượt, pha, đồng hồ

**Thứ tự các pha** (st:9-16; R:29-44):

`AwaitRoll → [AwaitBuyDecision → (Auction)] | [AwaitChoice] | [Rescue] → StrategyAction → lượt kế`

| Pha | Người chơi làm được gì | Nút trên HUD | Hết giờ thì |
|---|---|---|---|
| AwaitRoll | Đổ xúc xắc | ĐỔ XÚC XẮC (Space/Enter) (hud:847-850; txt:12) | **Máy tự đổ hộ** (`timeout_auto_roll` = true, bal:16; eng:1009-1016; R:54 [REVIEW]) |
| AwaitBuyDecision | Mua / Bỏ qua | MUA x RC / BỎ QUA (đấu giá) (hud:851-861) | Bỏ qua → đấu giá (eng:1017-1020) |
| Auction | Mọi người trả giá | TRẢ x (2 nút) | Đóng đấu giá (eng:1025-1026) |
| AwaitChoice (ô ! có lựa chọn, ô ?) | Chọn 1 trong 2 phương án | Mỗi phương án 1 nút, có ghi chi phí (hud:877-885) | Chọn `default_option`, luôn là phương án mất 0 RC (cfg:239-245; eng:1021-1022) |
| StrategyAction | **Tối đa 1** trong 3: Nâng cấp / Đề nghị giao dịch / Dùng kỹ năng; hoặc Kết thúc lượt | NÂNG CẤP, KỸ NĂNG (nếu dùng được), KẾT THÚC LƯỢT (hud:957-977). **Không có nút đề nghị giao dịch** | Kết thúc lượt (eng:1023-1024) |
| TradePending | Người nhận Đồng ý / Từ chối | ĐỒNG Ý / TỪ CHỐI (hud:888-893) | Giao dịch hết hạn, không có gì chuyển (eng:1027-1028) |
| Rescue | Thanh lý / (đề nghị 1 giao dịch) / Phá sản | BÁN +x RC cho từng ô, PHÁ SẢN (hud:894-900) | Engine tự xử lý bắt buộc (eng:1029-1030) |

**Đồng hồ:**
- **Một đồng hồ 45 giây cho cả lượt**, không phải cho từng pha (bal:13).
  - Hạn chót đặt ở đầu lượt (eng:697) và dùng chung cho các pha đổ, mua, chọn và chiến lược.
  - Đồng hồ chỉ **tạm dừng** trong Đấu giá, Giao dịch chờ và Cứu nợ, rồi chạy tiếp từ chỗ còn lại (eng:655-663; R:62).
  - Thanh thời gian chuyển đỏ khi còn dưới 10 giây (hud:554).
- Các đồng hồ riêng:

| Đồng hồ | Thời gian | Nguồn |
|---|---|---|
| Giao dịch | 20 s | bal:14 |
| Cứu nợ | 30 s | bal:15 |
| Đấu giá | 12 s (+3 s chống bắn tỉa, tối đa 2 lần) | bal:18, 22-24 |

- Giao dịch đề nghị trong lúc Cứu nợ bị cắt cho vừa hạn chót cứu nợ (eng:474-476).
- Nâng cấp và Dùng kỹ năng **kết thúc lượt ngay** (eng:427, 447).
- Đề nghị giao dịch kết thúc lượt khi giao dịch được giải quyết (eng:836-845).
- Thứ tự lượt theo ghế: ghế 0 đi trước (R:10). Ở bản offline, người chơi người luôn ngồi ghế 0 (main:196 `[0]`).
- Vòng tăng thêm 1 khi lượt quay về ghế đầu (eng:680, 688-689).
- Bot chờ animation diễn xong rồi mới hành động, **nhưng hạn chót vẫn chạy** (lm:15-17).
- Mở menu tạm dừng hoặc thẻ hướng dẫn thì trận **dừng hẳn** (tutorial_overlay.gd:5-7; pause_menu.gd:3).
- Ở bản offline, bot không bao giờ cố tình để hết giờ (lm:40, tham số `idle_chance_pct` = 0).

---

## 7. Nhân vật

- Có **3 nhân vật**, và đây là **vai trò ảnh hưởng gameplay**, không phải đồ trang trí (chr:57-78; cfg:198-199 bắt buộc đủ 3).
- Người chơi chọn nhân vật ở menu bắt đầu (setup:7-11; menu:295-303).
- Bot nhận các nhân vật còn lại theo vòng cố định. Với 4 người thì có nhân vật bị trùng (setup:24-32).
- Ở chế độ hướng dẫn và chạy bằng tham số dòng lệnh: thứ tự cố định `TYCOON, INVESTOR, NEGOTIATOR, TYCOON` (main:14).

| ID | Tên VI (vi:4-15) | Kỹ năng | Số liệu | Cách dùng |
|---|---|---|---|---|
| TYCOON | **Doanh Nhân** | Thụ động "Xây rẻ" | Mọi lần nâng cấp −10% (chr:5-8) | Luôn có hiệu lực, không cần bấm |
| INVESTOR | **Nhà Đầu Tư** (thẻ HUD: "Đầu Tư") | Chủ động "Gọi cổ tức" | +15 RC cho mỗi ô đang sở hữu, tối đa 120 RC; **2 lần mỗi trận**, **chờ 3 vòng** giữa hai lần (chr:10-15) | Nút KỸ NĂNG trong pha chiến lược. Tính là hành động chiến lược, kết thúc lượt |
| NEGOTIATOR | **Chuyên Gia Đàm Phán** ("Đàm Phán") | Chủ động "Điều khoản hợp đồng" | Lần trả thuê kế tiếp **trong 2 vòng** chỉ mất 50%; 2 lần mỗi trận, chờ 3 vòng (chr:17-22) | Như trên. Nếu không phải trả thuê lần nào trong 2 vòng thì hiệu lực mất |

**Cơ chế hồi chiêu:**
- Dùng ở vòng r thì vòng r+3 mới dùng lại được (eng:441-442, 304-307).
- Ngay từ vòng 1 đã dùng được (eng:55 `ability_ready_round` = 1).

**Độ dài "trong N vòng":**
- Bằng `N × số người còn sống lúc tạo` lượt (eng:934). Engine kiểm tra hết hạn ở đầu mỗi lượt (eng:702-710).

**Văn bản kỹ năng tiếng Việt** ở menu được sinh từ dữ liệu (menu:423-436). Không có trong `strings_vi.json`.

**Bot dùng kỹ năng:**
- Bot ưu tiên: nâng cấp > giao dịch > kỹ năng (bot:141-176).
- Nhà Đầu Tư chỉ dùng kỹ năng khi có ≥3 ô.

---

## 8. Ô Sự kiện (!), Cơ hội (?), Thuế (%), Nghỉ

**Ô ! (CITY_EVENT, ô 8 và 20):**
- Rút lá trên cùng của bộ **12 thẻ** đã xáo (eng:615-627).
- Bộ thẻ được xáo lại khi rút hết (eng:616-619).
- Thẻ có lựa chọn thì mở pha AwaitChoice.

| Thẻ (VI, vi:16-87) | Loại | Hiệu ứng chính xác (ev) |
|---|---|---|
| Bùng Nổ Du Lịch | + | Tiền thuê **mọi** quận tourist (D2, D5) +50% trong 1 vòng, bất kể chủ là ai (ev:5-7; eng:960-962) |
| Tài Trợ Thành Phố | + | +100 RC (ev:8-10) |
| Tàu Tốc Hành | + | Tới ngay Xuất phát, +200 RC. Không xử lý ô đích nào khác (ev:11-13) |
| Trợ Giá Xây Dựng | + | Lần nâng cấp kế tiếp trong 2 vòng −50% (ev:14-16) |
| Khủng Hoảng Thị Trường | − | Trả 40 RC cho mỗi ô của bạn ở cấp ≥2 (ev:17-19) |
| Sửa Chữa Công Trình | − | Trả 20 RC cho mỗi cấp nhà bạn sở hữu (ev:20-22) |
| Phạt Giao Thông | − | Trả 50 RC cho ngân hàng (ev:23-25) |
| Mất Điện | − | Đất của bạn thu thuê −50% trong 1 vòng (ev:26-28) |
| Đầu Tư Thông Minh | chọn | Đầu tư 100 RC: 50% cơ hội nhận +250 RC ở **đầu lượt kế tiếp** của bạn. Hoặc Bỏ qua (mặc định) (ev:29-35; eng:712-723) |
| Bảo Hiểm Tiền Thuê | chọn | Trả 60 RC: trong 2 vòng, mỗi lần trả thuê tối đa 100 RC. Hoặc Bỏ qua (mặc định) (ev:36-42) |
| Thưởng Danh Mục | chọn | +60 RC (mặc định), hoặc 20 RC cho mỗi ô, tối đa 400 (ev:43-49) |
| Dạ Tiệc Từ Thiện | chọn | Góp 50 RC: lần trả thuê kế tiếp trong 2 vòng giảm 50%. Hoặc Bỏ qua (mặc định) (ev:50-56) |

- Thẻ phạt tiền mà không đủ tiền mặt sẽ mở **Cứu nợ**, với chủ nợ là ngân hàng (eng:936-956).
- Phương án nào có chi phí lớn hơn tiền mặt hiện có sẽ bị từ chối, nút bị khóa (eng:403-404; hud:884).

**Ô ? (OPPORTUNITY, ô 3 và 16):**
- RNG chọn 1 trong 4 tình huống. Mỗi tình huống có đúng 2 phương án với kết quả công khai (eng:601-604; opp; R:158-161).

| Tình huống (VI) | Phương án A | Phương án B | Mặc định khi hết giờ |
|---|---|---|---|
| Chợ Phiên | +60 RC ngay | Trả 40, nhận 120 ở lượt sau (chắc chắn 100%) | A (opp:4-8) |
| Lễ Hội Đường Phố | +50 RC | 15 RC cho mỗi ô, tối đa 150 | A (opp:9-13) |
| Quỹ Cải Tạo | Nâng cấp kế tiếp trong 2 vòng −50% | +40 RC | **B** (opp:14-18) |
| Hợp Đồng Quảng Cáo | +90 RC, đất của bạn thu thuê −25% trong 1 vòng | +30 RC | **B** (opp:19-24) |

- Văn bản mô tả tiếng Việt chỉ ghi chung chung "Hai lựa chọn với kết quả cố định." (vi:90, 100, 110, 120). Nội dung thật nằm trên nhãn từng nút.

**Ô % (SPECIAL "Thuế", ô 24):**
- Thuế tài sản = `min(200, 10% × tài sản ròng)` (bal:29-33; eng:207-210, 605-609).
- Lúc mới vào trận (1 500 RC): thuế 150.
- Thuế này **không bao giờ gây phá sản**, vì thanh lý luôn đủ trả (R:135).
- GDD gọi ô này là "tax/auction". Engine chỉ thu thuế, không có đấu giá (G3: AUDIT:50).

**Ô Nghỉ (REST, ô 12):** không có gì xảy ra (G2: AUDIT:49; eng:610-612).

---

## 9. Cứu nợ (Rescue) & phá sản

**Khi nào mở Cứu nợ:**
- Một khoản phải trả (tiền thuê, thuế, thẻ) lớn hơn tiền mặt hiện có (eng:848-863).
- Chỉ **người đang tới lượt** mới có thể nợ (eng:855; R:151). Tiền mặt không bao giờ âm (eng:1038-1043).
- Pha Cứu nợ có **30 s** (bal:15).

**Trong pha Cứu nợ được làm gì** (R:140-144):
- **Thanh lý** bất kỳ ô nào cho ngân hàng theo giá trị thanh lý (bảng ở §5; eng:517-535).
  - Ngay khi tiền mặt ≥ khoản nợ, engine tự trả và **quay về pha chiến lược**, tức người chơi vẫn còn hành động của lượt (eng:874-881).
  - UI có một nút "TÊN · BÁN +x RC" cho mỗi ô (hud:899; txt:43).
- **Đề nghị 1 giao dịch.** Lượt này không tính là hành động chiến lược (eng:452-457, 474-476). **UI cho người chơi không có nút này.**
- **PHÁ SẢN** (`DeclareBankruptcy`) (hud:900).
  - Nếu tiền mặt + tổng giá thanh lý ≥ nợ, engine **tự thanh lý từ ô rẻ nhất** (bằng nhau thì theo thứ tự trên bàn) và người chơi **sống sót** (eng:888-906; R:146 [REVIEW]).
  - Như vậy bấm "PHÁ SẢN" không nhất thiết là phá sản thật. Hết 30 s cũng xử lý y hệt.

**Phá sản thật** (khi tài sản không đủ trả; G7: AUDIT:54; eng:907-922):
- Mọi ô của người phá sản **về ngân hàng, không ai được tiền, về cấp 0**.
- **Toàn bộ tiền mặt còn lại** chuyển cho chủ nợ. Chủ nợ là người chơi khác nếu nợ tiền thuê, là ngân hàng nếu nợ thuế hoặc thẻ.
- Các hiệu ứng và khoản thưởng chờ của người đó bị xóa. Lượt của họ bị bỏ qua từ đó về sau.
- Lượt kết thúc với lý do "bankrupt".

**Bot khi Cứu nợ:** bán từ ô rẻ nhất cho tới khi đủ, không đủ thì tuyên bố phá sản (bot:214-229).

---

## 10. Giao dịch

Luật trong engine (eng:451-514, 801-846; bal:26-28; R:174-182):
- **Nội dung:** tiền mặt và **tối đa 3 ô mỗi bên**.
  - Chỉ được giao dịch **ô cấp 0** (eng:827-830; [REVIEW]).
  - Ít nhất một bên phải có gì đó.
  - Không được giao dịch với chính mình hoặc với người đã phá sản.
- **Khi nào được đề nghị:**
  - Trong lượt của mình, ở pha chiến lược. Đây là **hành động chiến lược duy nhất** của lượt.
  - Thêm **1 lần** trong lúc Cứu nợ.
- **Người nhận:** có **20 s** để Đồng ý hoặc Từ chối. Hết giờ thì giao dịch `expired`.
  - Khi chấp nhận, engine **kiểm tra lại** điều kiện. Không còn hợp lệ thì `invalidated` và không có gì chuyển (eng:501-504).
  - Hợp lệ thì mọi thứ chuyển cùng lúc, nguyên tử (eng:505-513).
- **Thực tế trên client:**
  - Người chơi **chỉ nhận và trả lời** đề nghị của bot (hud:888-893).
  - **Không có giao diện để tự đề nghị giao dịch.** Điều này được ghi nhận ở M2_VERTICAL_SLICE_REPORT:22 và 155, MASTER_EXECUTION_REPORT:138. Grep `PROPOSE_TRADE` ngoài domain/sim không có kết quả nào.
- **Bot đề nghị giao dịch khi nào:**
  - Bot đã có 2/3 ô của một quận, và ô thứ ba (cấp 0) thuộc người khác.
  - Bot đề nghị **chỉ trả tiền**: 170–290% giá ô đó (bot:27, 179-196).
  - Bot chỉ đề nghị khi trả xong vẫn còn đủ `reserve` (bot:192), và chỉ với xác suất 25–70% mỗi lượt (bot:29, 164).
- **Bot chấp nhận khi nào:** khi giá trị nhận về ≥ giá trị đưa đi. Bot định giá ô của mình bằng 120% giá, hoặc 180% nếu ô đó giúp bên kia hoàn thành quận (bot:199-211).

---

## 11. Những thứ UI hiển thị mà người mới cần hiểu

- **"Vòng X/Y"** (txt:8; hud:508-509).
  - Y = `max_rounds_for(số người lúc bắt đầu)`: 2 người → **/40**, 3 người → **/30**, 4 người → **/25** (bal:6-11).
  - "Vòng 1/30" nghĩa là trận 3 người, "1/40" là trận 2 người.
  - **Chế độ hướng dẫn luôn là 2 người** (main:161 `n := 2 if as_tutorial`), nên luôn hiện "/40". Menu mặc định 4 người (setup:10), nên hiện "/25".
  - Một vòng = mỗi người còn sống đi một lượt.
- **"Bản thử nghiệm"** (txt:87).
  - Nhãn này **có trong code nhưng bị ẩn** trên HUD (hud:134-140, `visible = false`; ghi chú "build tag moved to the title screen").
  - Màn hình tiêu đề hiện thay bằng "**Bản thử nội bộ · <stamp>**" (menu:182).
  - Ý nghĩa: bản build để test, đồ họa và số cân bằng đều là DRAFT (bal:2; M2_VERTICAL_SLICE_REPORT:149). **Không ảnh hưởng tới luật.**
- **Nút "Đồ họa: Thấp/Vừa/Cao"** (txt:85-86; hud:141-153, 626-636).
  - Bấm để đổi preset đồ họa (main:213). Chỉ liên quan hình ảnh, không ảnh hưởng luật.
  - **Giữ khoảng 0.9 s** (hud:65 `LONG_PRESS_MS` = 900) sẽ mở bảng "Đo trên thiết bị". Bảng này chỉ có ở bản debug/internal (hud:629; build_flavor.gd:18-21).
- **Thanh thời gian:** 45 s cho cả lượt, đỏ khi còn dưới 10 s (hud:554). Hết giờ thì máy tự chọn phương án an toàn (txt:83).
- **Bảng "Hành động chiến lược (tối đa 1)"** (txt:22).
  - Nút NÂNG CẤP bị khóa khi chưa đủ quận, kèm dòng "Chưa có quận hoàn chỉnh để nâng cấp." (txt:29; hud:970-972).
  - Nút KỸ NĂNG chỉ hiện khi còn lượt dùng và đã hết hồi chiêu (hud:974-976). Doanh Nhân không bao giờ thấy nút này vì kỹ năng là thụ động.
- **Thông tin ô đất khi dừng:** "Giá x RC · Thuê y RC" và cả bảng thuê theo cấp (txt:20-21; hud:856-857). Chạm vào một ô bất kỳ để xem chủ sở hữu và cấp (guide:69; hud:571-574).
- **Đơn vị "RC"** (Rush Credits) là tiền ảo, số nguyên (GDD:17, 53).

---

## 12. Mâu thuẫn GDD/docs ↔ engine/data

| # | Chủ đề | GDD / docs | Engine / data | Nguồn được dùng |
|---|---|---|---|---|
| 1 | Số vòng tối đa | 25 vòng cho mọi số người (GDD:20, 89; PLAN:10 vẫn ghi 25) | 2p 40 / 3p 30 / 4p 25 (bal:6-11) | **Engine.** Quyết định M1.2 của chủ dự án (V3:9; R:47). PLAN:10 đã lỗi thời |
| 2 | Thời lượng đấu giá | "10–15 s" (GDD:31) và "12 s" (GDD:63) | 12 s (bal:18) | Engine, khớp GDD §6 |
| 3 | Chống bắn tỉa | "resets … only once (e.g. +3 s, maximum 2 extensions)" (GDD:66), tự mâu thuẫn | +3 s, tối đa 2 lần (bal:22-24) | Engine (R:102) |
| 4 | Giá mở đấu giá | "minimum bid", không có số (GDD:64) | max(10, 10% giá); bước +10 (bal:19-21) | Engine (R:99-100) |
| 5 | Tài sản ròng | cash + thanh lý + **thưởng mục tiêu − nợ** (GDD:60) | cash + thanh lý (eng:195-204) | Engine (G11; R:165-166) |
| 6 | Gieo đôi | GDD không nói | Không có thưởng gì (eng:565) | Engine (G5) |
| 7 | Dừng đúng Xuất phát | GDD chỉ nói "when passing Start" (GDD:17) | Qua **hoặc dừng** đều +200 (eng:575; R:33) | Engine (R). Hướng dẫn trong game (guide:45) chỉ nói "Qua" |
| 8 | Hết giờ ở pha đổ | Mặc định an toàn: "pass purchase, no upgrade, no ability, end turn" (GDD:38), không nói tự đổ | **Tự đổ hộ** (bal:16; eng:1013-1014) | Engine, nhưng là **[REVIEW]** (R:54), chưa được duyệt hẳn |
| 9 | Ô Đặc biệt | "Special tax/auction space" (GDD:48) | Chỉ thu thuế tài sản 10%, tối đa 200 | Engine (G3) |
| 10 | Bùng Nổ Du Lịch | "tourist district" số ít (GDD:81) | Mọi quận tourist: **D2 và D5** (board:283, 303) | Data. Ví dụ ở R:117 chỉ nhắc D5 nên dễ hiểu nhầm |
| 11 | Đầu Tư Thông Minh | Nhận thưởng "next round" (GDD:83) | Nhận ở **đầu lượt kế tiếp của mình** (eng:699, 712-723) | Engine (R:156) |
| 12 | Giao dịch: đất có nhà | GDD không cấm (GDD:71-76) | Chỉ cho giao dịch ô cấp 0 (eng:829) | Engine, **[REVIEW]** (R:175) |
| 13 | Giới hạn tần suất giao dịch | "Rate-limit offers" chung chung (GDD:76) | 1 lần mỗi lượt (là hành động chiến lược) + 1 lần khi Cứu nợ | Engine (R:182) |
| 14 | Giao dịch / hành động chiến lược | Người chơi được đề nghị giao dịch (GDD:36; guide:75 hướng dẫn bước 5 nhắc "đề nghị giao dịch") | **Client không có nút đề nghị giao dịch** (hud:957-977) | Engine hỗ trợ, UI thiếu. Đây là lỗ hổng UI đã biết (M2 report:22). **Hướng dẫn trong game hứa một tính năng chưa có** |
| 15 | Xử lý bắt buộc khi Cứu nợ | GDD:59: "if still unable to pay, mark bankrupt" | Nếu thanh lý đủ thì engine tự bán, người chơi sống. Nút "PHÁ SẢN" có thể không làm phá sản | Engine, **[REVIEW]** (R:146) |
| 16 | Tie-break | net worth → districts → cash (GDD:90) | Như GDD, cộng thêm: phá sản xếp sau, bằng hết thì đồng hạng | Engine (R:171 [REVIEW] về đồng hạng) |
| 17 | Nhân vật | Ảnh tham khảo có 4 nhân vật và cấp nhà tối đa 5 (AUDIT:36-37) | 3 nhân vật, cấp 0–3 | GDD/engine (PLAN:81) |
| 18 | Tiền tệ | Ảnh tham khảo dùng 2 000 000 khởi đầu (AUDIT:35) | 1 500 RC | GDD/engine |
| 19 | Thời lượng mục tiêu | 20–30 phút (GDD:6), trung vị 22–27 (GDD:176) | Mô phỏng v3 (mô hình "medium"): trung vị ~18 / 20 / 22 phút cho 2 / 3 / 4 người (V3:120) | Chưa đạt, chưa có số đo người thật (V3:146) |
| 20 | "Bản thử nghiệm" trên HUD | M2 report:149: thanh trên cùng ghi "Bản thử nghiệm — đồ họa tạm" | Nhãn bị ẩn (hud:139); màn tiêu đề ghi "Bản thử nội bộ" (menu:182) | Code. Report đã lỗi thời |
| 21 | Bước nâng cấp | GDD không nói | 1 cấp mỗi hành động, không cần xây đều | Engine |
| 22 | Bảo Hiểm Tiền Thuê kết hợp giảm giá | GDD không nói | Giảm 50% trước, rồi mới áp trần 100 (eng:259-271) | Engine |

---

## 13. Mechanics a new player must understand

Ghi chú về cột "Xuất hiện lần đầu":
- **"(tính)"** là số tôi tự tính bằng mô phỏng Monte Carlo 200 000 lần, **chỉ mô phỏng phần đi quân 2d6** trên 28 ô và bỏ qua thẻ Tàu Tốc Hành. Repo không có dữ liệu về lần xuất hiện đầu tiên.
- **"(sim)"** là số đo từ các trận bot trong docs (M1_REPORT:137; V3:122-125).

| Cơ chế | Cần ở lượt 1? | Xuất hiện lần đầu (trận điển hình) | Giải thích một câu |
|---|---|---|---|
| Đổ xúc xắc & đồng hồ 45 s | Có | Lượt 1 | Bấm ĐỔ XÚC XẮC; cả lượt (đổ + mua + chọn + hành động) chỉ có 45 giây, hết giờ máy tự đổ hoặc tự chọn phương án an toàn. |
| Mua đất / BỎ QUA | Có | Lượt 1 (khoảng 78% số lần đổ đầu tiên rơi vào ô đất) | Dừng ở ô chưa có chủ thì được mua đúng giá, hoặc bỏ qua để cả bàn đấu giá. |
| Đấu giá | Có thể | Lượt 1 trở đi, mỗi khi ai đó bỏ qua (khoảng 1.3–1.4 lần mỗi trận, sim) | Mọi người, kể cả người vừa bỏ qua, trả giá tăng dần trong 12 s; không ai trả thì đất vẫn chưa có chủ. |
| Mục tiêu = tài sản ròng | Có (để quyết định mua) | Từ đầu; được tính ở cuối trận | Người thắng là người có tiền mặt + giá thanh lý (50% giá đất và 50% tiền nhà) cao nhất, không phải người có nhiều đất nhất. |
| Vòng X/Y | Có (đọc HUD) | Lượt 1 | Y là số vòng tối đa theo số người (40/30/25); hết vòng Y thì trận kết thúc và tính tài sản. |
| Hành động chiến lược (tối đa 1) | Có | Lượt 1, sau khi xử lý xong ô vừa dừng | Mỗi lượt chọn tối đa một việc (nâng cấp, kỹ năng, hoặc giao dịch) rồi lượt kết thúc; không cần thì bấm KẾT THÚC LƯỢT. |
| Kỹ năng nhân vật | Có (chọn từ menu) | Dùng được ngay từ vòng 1 | Doanh Nhân luôn được nâng cấp rẻ hơn 10%; Đầu Tư và Đàm Phán có nút KỸ NĂNG, dùng được 2 lần mỗi trận, cách nhau 3 vòng, và dùng thay cho hành động của lượt. |
| Ô Xuất phát | Không | Lần đầu đi hết một vòng bàn: trung vị khoảng lượt thứ 4 của mỗi người (tính) | Mỗi lần đi qua hoặc dừng đúng Xuất phát được +200 RC. |
| Trả tiền thuê | Không | Thường từ vòng 2, khi đối thủ đã có đất | Dừng ở đất của người khác thì tự động trả thuê; quận đủ 3 ô thì thuê ×2, có nhà thì ×7 / ×22 / ×55. |
| Ô ! Sự kiện | Đôi khi (khoảng 14% ở lượt 1) | Trung vị khoảng lượt thứ 9 của mỗi người (tính) | Rút một trong 12 thẻ: được tiền, mất tiền, hiệu ứng tạm thời, hoặc phải chọn một trong hai. |
| Ô ? Cơ hội | Hiếm (khoảng 6% ở lượt 1) | Trung vị khoảng lượt thứ 9 (tính) | Chọn một trong hai phương án có kết quả nói rõ trước; hết giờ thì máy chọn phương án miễn phí. |
| Ô % Thuế tài sản | Không (0% ở lượt 1) | Trung vị khoảng lượt thứ 19 (tính); khoảng 7% đã gặp trong 3 lượt đầu | Nộp 10% tài sản ròng, tối đa 200 RC; không bao giờ làm bạn phá sản. |
| Ô Nghỉ | Hiếm | Bất kỳ lúc nào | Ô an toàn, không có gì xảy ra. |
| Quận trọn vẹn | Không | Giữa trận; cần cả 3 ô cùng màu (thường nhờ mua, đấu giá, hoặc bot đề nghị đổi) | Giữ đủ 3 ô một quận thì thuê ×2 và mở khóa nâng cấp. |
| Nâng cấp nhà | Không | Sau khi có quận trọn vẹn (khoảng 13–17 lần nâng mỗi trận, sim) | Mỗi lượt nâng 1 cấp cho 1 ô (30–75 RC tùy hạng); cấp 3 làm tiền thuê tăng vọt, tối đa 1 760 RC. |
| Hiệu ứng tạm thời (giảm thuê, trần thuê, giảm giá nâng cấp) | Không | Khi rút thẻ hoặc dùng kỹ năng | "Trong N vòng" nghĩa là N lượt của mỗi người còn sống; giảm giá dùng một lần sẽ mất nếu không dùng kịp. |
| Giao dịch (nhận đề nghị) | Không | Khi một bot có 2/3 ô của một quận mà bạn giữ ô còn lại (khoảng 3–5 đề nghị mỗi trận, sim) | Bot đề nghị trả tiền mua ô của bạn; bạn có 20 s để ĐỒNG Ý hoặc TỪ CHỐI (bản hiện tại bạn chưa tự đề nghị được). |
| Cứu nợ (thiếu tiền) | Không | Hiếm và muộn (0.2–0.6 lần mỗi trận, sim); phá sản trung vị vòng 23–34 (V3:126) | Không đủ tiền trả thì có 30 s để bán đất cho ngân hàng; bấm PHÁ SẢN khi tài sản vẫn đủ trả thì máy tự bán ô rẻ nhất và bạn vẫn sống. |
| Phá sản | Không | Cuối trận | Không đủ tài sản trả nợ thì mất hết đất (về ngân hàng) và tiền mặt còn lại về tay chủ nợ; bạn bị loại. |
| Kết thúc trận & tie-break | Không | Cuối trận | Trận dừng khi hết vòng tối đa, hết 30 phút, hoặc chỉ còn một người; bằng tài sản thì xét số quận trọn vẹn, rồi tiền mặt. |
| Nút Đồ họa / "Bản thử nội bộ" | Không | Luôn hiện | Chỉ liên quan tới hình ảnh và nhãn bản build, không ảnh hưởng luật chơi. |
