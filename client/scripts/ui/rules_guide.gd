## The one source for every rules text the player reads: the two intro pages,
## the contextual coach tips (Phase 5.1), the guided-tutorial cards, the
## "what next" hints, the how-to sheet and the pause-menu guide. Every number
## comes from GameConfig (rules data), so the text follows any balance
## change; nothing here is a copy of the rules that could drift.
## Wording follows docs/GAME_RULES_AND_GDD.md, docs/RULES_M1.md and the engine
## (docs/NEW_PLAYER_RULES_AUDIT.md records where they differ).
class_name RulesGuide
extends RefCounted

var config: GameConfig


func _init(p_config: GameConfig) -> void:
	config = p_config


func _b(key: String) -> Variant:
	return config.balance[key]


func _rounds_text() -> String:
	var parts: Array[String] = []
	for n in [2, 3, 4]:
		parts.append("%d người: %d vòng" % [n, config.max_rounds_for(n)])
	return ", ".join(parts)


func _tier_range(key: String) -> Array:
	var lo := 1 << 30
	var hi := 0
	for pid in config.property_ids:
		var v: int = config.tier_of(pid)[key]
		lo = mini(lo, v)
		hi = maxi(hi, v)
	return [lo, hi]


## Resale value of land as a share of its price (liquidation / price), when
## every tier uses the same share; 0 otherwise.
func _resale_pct() -> int:
	var pct := -1
	for pid in config.property_ids:
		var t: Dictionary = config.tier_of(pid)
		var p: int = t["liquidation_value"] * 100 / t["price"]
		if pct >= 0 and p != pct:
			return 0
		pct = p
	return maxi(pct, 0)


func _mult(key: String) -> int:
	return _b("rent_multiplier_pct")[key] / 100


func _secs(key: String) -> int:
	return int(_b(key) / 1000)


## Phase 5.1: two short pages before playing (goal, one turn). Everything else
## is explained in context the first time it happens.
func intro_pages() -> Array:
	var resale := _resale_pct()
	var worth := "tiền mặt + giá bán lại đất và nhà" + (" (bằng %d%% số tiền đã bỏ ra)" % resale if resale > 0 else "")
	return [
		{"icon": "trophy", "title": "Mục tiêu của bạn",
			"body": "Trở thành người GIÀU NHẤT khi trận kết thúc.\nGiàu = %s.\nTrận kết thúc khi hết số vòng (%s), hết %d phút, hoặc khi chỉ còn một người chưa phá sản. Mỗi người bắt đầu với %d RC." % [
				worth, _rounds_text(), int(_b("time_cap_ms") / 60000), _b("starting_cash")]},
		{"icon": "dice", "title": "Bạn làm gì trong mỗi lượt?",
			"body": "1. Bấm ĐỔ XÚC XẮC: quân đi theo tổng hai viên.\n2. Xử lý ô vừa dừng: đất trống thì MUA hoặc BỎ QUA (cả bàn đấu giá); đất của người khác thì tự trả tiền thuê; ô ! và ? thì đọc thẻ hoặc chọn.\n3. Nếu muốn, làm MỘT việc: nâng cấp nhà hoặc dùng kỹ năng. Rồi bấm KẾT THÚC LƯỢT.\nMỗi lượt có %d giây. Điều gì mới sẽ được giải thích ngay khi nó xảy ra lần đầu." % _secs("turn_timer_ms")},
	]


## Phase 5.1 contextual tips, shown once each the first time the situation
## happens to the player (CoachOverlay). `pause`: the match waits while the
## card is up (a decision is pending); other tips are information only.
func tips() -> Dictionary:
	var a: Dictionary = _b("auction")
	var wt: Dictionary = _b("wealth_tax")
	var up := _tier_range("upgrade_cost")
	var resale := _resale_pct()
	return {
		"roll": {"icon": "dice", "title": "Lượt của bạn", "pause": false,
			"body": "Bấm ĐỔ XÚC XẮC (hoặc phím Space). Cả lượt có %d giây; hết giờ, trò chơi tự đổ hộ hoặc chọn phương án an toàn." % _secs("turn_timer_ms")},
		"buy": {"icon": "tag", "title": "Đất chưa có chủ", "pause": true,
			"body": "MUA: trả đúng giá ghi trên nút, ô này là của bạn và ai dừng ở đây sẽ trả thuê cho bạn.\nBỎ QUA: cả bàn đấu giá ô này trong %d giây, kể cả bạn." % int(a["timer_ms"] / 1000)},
		"auction": {"icon": "gavel", "title": "Đấu giá", "pause": true,
			"body": "Mọi người, kể cả người vừa bỏ qua, trả giá tăng dần trong %d giây; mỗi lần cao hơn ít nhất %d RC. Hết giờ, người trả cao nhất mua được đất. Không ai trả thì đất vẫn chưa có chủ." % [int(a["timer_ms"] / 1000), a["min_increment"]]},
		"strategy": {"icon": "build", "title": "Một việc cuối lượt", "pause": true,
			"body": "Bạn được làm TỐI ĐA MỘT việc: nâng cấp nhà (khi giữ đủ một quận) hoặc dùng kỹ năng của vai trò. Không cần gì thêm thì bấm KẾT THÚC LƯỢT."},
		"upgrade": {"icon": "build", "title": "Bạn có thể nâng cấp", "pause": true,
			"body": "Bạn giữ đủ một quận. NÂNG CẤP thêm 1 cấp nhà cho một ô (tối đa cấp %d, %d–%d RC mỗi lần). Tiền thuê tăng mạnh: cấp 1/2/3 là ×%d / ×%d / ×%d. Nâng cấp dùng hết việc của lượt." % [
				_b("max_level"), up[0], up[1], _mult("level1"), _mult("level2"), _mult("level3")]},
		"ability": {"icon": "star", "title": "Kỹ năng vai trò", "pause": true,
			"body": "Nút KỸ NĂNG dùng kỹ năng của vai trò bạn chọn. Nó thay cho việc cuối lượt, và có giới hạn số lần cùng thời gian chờ."},
		"choice": {"icon": "opportunity", "title": "Chọn một phương án", "pause": true,
			"body": "Hai lựa chọn, kết quả ghi rõ trên nút. Hết giờ, trò chơi chọn phương án không tốn tiền."},
		"trade": {"icon": "handshake", "title": "Đề nghị giao dịch", "pause": true,
			"body": "Máy muốn mua đất của bạn. ĐỒNG Ý: nhận tiền và giao đất. TỪ CHỐI: giữ đất. Bạn có %d giây." % _secs("trade_timer_ms")},
		"rescue": {"icon": "warning", "title": "Thiếu tiền trả nợ", "pause": true,
			"body": "Bạn có %d giây để BÁN đất cho ngân hàng%s. Đủ tiền là trả nợ ngay và chơi tiếp. PHÁ SẢN: nếu tài sản vẫn đủ, trò chơi tự bán ô rẻ nhất và bạn ở lại; không đủ thì bạn bị loại." % [
				_secs("rescue_timer_ms"), " (nhận %d%% giá đất)" % resale if resale > 0 else ""]},
		"event": {"icon": "event", "title": "Thẻ sự kiện", "pause": false,
			"body": "Ô ! rút một trong %d thẻ: được tiền, mất tiền, hoặc một hiệu ứng tạm thời. Kết quả hiện ở dòng thông báo." % config.cards.size()},
		"rent_paid": {"icon": "coin", "title": "Bạn vừa trả tiền thuê", "pause": false,
			"body": "Dừng ở đất của người khác thì tự động trả thuê. Chủ giữ đủ quận: thuê ×%d; có nhà: ×%d / ×%d / ×%d." % [
				_mult("level0_district_complete"), _mult("level1"), _mult("level2"), _mult("level3")]},
		"rent_got": {"icon": "coin", "title": "Bạn thu được tiền thuê", "pause": false,
			"body": "Đối thủ dừng ở đất của bạn nên trả thuê cho bạn. Gom đủ 3 ô cùng màu để thuê ×%d và được xây nhà." % _mult("level0_district_complete")},
		"start": {"icon": "arrow_start", "title": "Ô Xuất phát", "pause": false,
			"body": "Mỗi lần đi qua hoặc dừng đúng ô Xuất phát, bạn nhận %d RC." % _b("start_reward")},
		"tax": {"icon": "tax", "title": "Thuế tài sản", "pause": false,
			"body": "Ô %% thu %d%% tài sản ròng của bạn, tối đa %d RC. Thuế này không bao giờ làm bạn phá sản." % [wt["pct"], wt["cap"]]},
		"district": {"icon": "crown", "title": "Bạn có đủ một quận!", "pause": false,
			"body": "Giữ cả 3 ô cùng màu: tiền thuê ×%d, và từ lượt sau bạn được nâng cấp nhà (sau khi đi)." % _mult("level0_district_complete")},
		"bankrupt": {"icon": "bankrupt", "title": "Một người phá sản", "pause": false,
			"body": "Đất của họ về ngân hàng, ai dừng ở đó lại được mua; họ không còn lượt."},
	}


## The guided tutorial's own cards (the rest of the tutorial is the tips
## above, shown in play order on a real 2-player match).
func guided_cards() -> Dictionary:
	return {
		"welcome": {"icon": "trophy", "title": "Trận hướng dẫn", "pause": true,
			"body": "Bạn và 1 máy, chơi thật. Mục tiêu: giàu nhất khi hết trận. Mỗi bước chỉ dạy một thao tác; làm theo nút được làm sáng. Bỏ hướng dẫn được bất cứ lúc nào."},
		"watch": {"icon": "user", "title": "Lượt của máy", "pause": false,
			"body": "Bây giờ máy đi. Bạn chỉ cần theo dõi; nếu máy dừng ở đất của bạn, nó trả tiền thuê cho bạn."},
		"done": {"icon": "check", "title": "Bạn đã biết chơi một lượt!", "pause": true,
			"body": "Tiền thuê, đấu giá, sự kiện, nâng cấp và cứu nợ sẽ được giải thích ngay khi chúng xảy ra. Xem lại luật: ☰ → HƯỚNG DẪN."},
	}


## Short "what next" hint when the player has an action and waits too long.
func next_hint(phase: String) -> String:
	return {
		GameState.AWAIT_ROLL: "Gợi ý: bấm ĐỔ XÚC XẮC (hoặc Space) để đi.",
		GameState.AWAIT_BUY: "Gợi ý: MUA nếu muốn giữ ô này; BỎ QUA sẽ mở đấu giá.",
		GameState.AUCTION: "Gợi ý: trả giá nếu muốn ô này, hoặc chờ hết giờ.",
		GameState.AWAIT_CHOICE: "Gợi ý: chọn một phương án; kết quả ghi trên nút.",
		GameState.STRATEGY: "Gợi ý: không muốn nâng cấp? Bấm KẾT THÚC LƯỢT.",
		GameState.TRADE_PENDING: "Gợi ý: ĐỒNG Ý nếu giá hợp lý, TỪ CHỐI để giữ đất.",
		GameState.RESCUE: "Gợi ý: bán ô rẻ nhất trước cho tới khi đủ tiền.",
	}.get(phase, "")


## Rules reference, in play order (pause-menu guide and how-to sheet).
func tutorial_steps() -> Array:
	var a: Dictionary = _b("auction")
	var wt: Dictionary = _b("wealth_tax")
	var up := _tier_range("upgrade_cost")
	return [
		{"icon": "dice", "title": "1. Tung xúc xắc và di chuyển",
			"body": "Bấm ĐỔ XÚC XẮC (hoặc phím Space). Quân đi số ô bằng tổng hai viên; gieo đôi không có gì thêm. Đi qua hoặc dừng đúng ô Xuất phát: +%d RC. Mỗi lượt có %d giây; hết giờ trò chơi tự đổ hộ hoặc chọn phương án an toàn." % [_b("start_reward"), _secs("turn_timer_ms")]},
		{"icon": "tag", "title": "2. Ô đất và quyền mua",
			"body": "Ô đất mang màu quận và giá riêng. Dừng ở ô chưa có chủ, bạn có quyền mua trước. Chạm vào một ô bất kỳ để xem giá, tiền thuê và chủ sở hữu."},
		{"icon": "coin", "title": "3. Mua đất hoặc đấu giá",
			"body": "MUA: trả đúng giá và sở hữu ngay. BỎ QUA: cả bàn (kể cả bạn) đấu giá trong %d giây, giá khởi điểm %d%% giá đất (tối thiểu %d RC), mỗi lần trả thêm ít nhất %d RC. Không ai trả thì đất vẫn chưa có chủ." % [int(a["timer_ms"] / 1000), a["min_bid_pct_of_price"], a["min_bid_floor"], a["min_increment"]]},
		{"icon": "coin", "title": "4. Thu tiền thuê",
			"body": "Người khác dừng ở đất của bạn phải trả tiền thuê, tự động. Giữ đủ cả quận: thuê ×%d ngay cả khi chưa xây. Nhà cấp 1/2/3: thuê ×%d / ×%d / ×%d giá thuê cơ bản." % [_mult("level0_district_complete"), _mult("level1"), _mult("level2"), _mult("level3")]},
		{"icon": "build", "title": "5. Một việc cuối lượt: nâng cấp hoặc kỹ năng",
			"body": "Sau khi xử lý ô, bạn được làm TỐI ĐA MỘT việc: nâng cấp 1 cấp nhà cho một ô (cần giữ đủ quận, tối đa cấp %d, %d–%d RC) hoặc dùng kỹ năng vai trò; rồi KẾT THÚC LƯỢT. Máy có thể đề nghị mua đất của bạn: bạn ĐỒNG Ý hoặc TỪ CHỐI (bản này bạn chưa tự đề nghị giao dịch được)." % [_b("max_level"), up[0], up[1]]},
		{"icon": "event", "title": "6. Sự kiện, cơ hội, thuế và cứu nợ",
			"body": "Ô ! rút một trong %d thẻ sự kiện. Ô ? cho chọn một trong hai phương án, kết quả nói rõ trước. Ô %% là thuế tài sản %d%% (tối đa %d RC). Thiếu tiền: bán đất cho ngân hàng để trả nợ; vẫn thiếu thì phá sản, đất về ngân hàng." % [config.cards.size(), wt["pct"], wt["cap"]]},
		{"icon": "trophy", "title": "7. Kết thúc và người thắng",
			"body": "Trận kết thúc khi hết số vòng (%s), hết %d phút, hoặc chỉ còn một người chưa phá sản. Người có tài sản ròng cao nhất thắng (tiền mặt + giá bán lại đất và nhà); bằng nhau thì xét số quận trọn vẹn, rồi tiền mặt." % [_rounds_text(), int(_b("time_cap_ms") / 60000)]},
	]


## The how-to sheet: goal, the turn, then every rules section.
func how_to_text() -> String:
	var out: Array[String] = []
	for p in intro_pages():
		out.append("%s\n%s" % [p["title"], p["body"]])
	for s in tutorial_steps():
		out.append("%s\n%s" % [s["title"], s["body"]])
	out.append("Mẹo: chạm vào một ô trên bàn cờ để xem giá, tiền thuê và chủ sở hữu.")
	return "\n\n".join(out)
