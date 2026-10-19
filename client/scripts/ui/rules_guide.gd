## Phase 5: the one source for every rules text the player reads - the intro
## pages, the step-by-step tutorial, the how-to sheet and the pause-menu
## guide. Every number comes from GameConfig (rules data), so the text follows
## any balance change; nothing here is a copy of the rules that could drift.
## Wording follows docs/GAME_RULES_AND_GDD.md and docs/RULES_M1.md.
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


func _price_range() -> Array:
	var lo := 1 << 30
	var hi := 0
	for pid in config.property_ids:
		var p: int = config.tier_of(pid)["price"]
		lo = mini(lo, p)
		hi = maxi(hi, p)
	return [lo, hi]


## Short intro pages: [{title, body, icon}]. Goal first, then the turn, the
## economy, the end. Shown once at first launch (skippable) and from the title.
func intro_pages() -> Array:
	var pr := _price_range()
	return [
		{"icon": "trophy", "title": "Mục tiêu",
			"body": "Mua đất, gom đủ quận, xây nhà và thu tiền thuê. Khi trận kết thúc, người có TÀI SẢN RÒNG cao nhất thắng: tiền mặt cộng giá trị bán lại đất và nhà.\nMỗi người bắt đầu với %d RC." % _b("starting_cash")},
		{"icon": "dice", "title": "Một lượt chơi",
			"body": "Tung hai viên xúc xắc, quân đi theo tổng. Qua ô Xuất phát nhận %d RC.\nDừng ở đất chưa có chủ: MUA (giá %d–%d RC) hoặc BỎ QUA để cả bàn đấu giá." % [_b("start_reward"), pr[0], pr[1]]},
		{"icon": "build", "title": "Quận và nâng cấp",
			"body": "Bàn có %d quận, mỗi quận %d ô cùng màu. Giữ đủ cả quận thì tiền thuê tăng gấp %d và được nâng cấp nhà, tối đa cấp %d.\nNhà càng cao, tiền thuê càng lớn." % [config.district_props.size(), _district_size(), _b("rent_multiplier_pct")["level0_district_complete"] / 100, _b("max_level")]},
		{"icon": "event", "title": "Bất ngờ và kết thúc",
			"body": "Ô ! rút thẻ sự kiện, ô ? cho bạn chọn cơ hội. Thiếu tiền thì bán đất trả nợ; vẫn thiếu thì phá sản.\nTrận kết thúc khi hết số vòng (%s), hết %d phút, hoặc chỉ còn một người." % [_rounds_text(), int(_b("time_cap_ms") / 60000)]},
	]


func _district_size() -> int:
	for did in config.district_props:
		return config.district_props[did].size()
	return 0


## Tutorial steps, in play order. `wait` names the presenter cue or HUD
## state that completes the step in a real match ("" = the Tiếp button).
func tutorial_steps() -> Array:
	var a: Dictionary = _b("auction")
	var rm: Dictionary = _b("rent_multiplier_pct")
	var wt: Dictionary = _b("wealth_tax")
	return [
		{"icon": "dice", "title": "1. Tung xúc xắc và di chuyển", "wait": "dice_land",
			"body": "Bấm ĐỔ XÚC XẮC (hoặc phím Space). Quân của bạn đi số ô bằng tổng hai viên. Mỗi lượt có %d giây; hết giờ trò chơi tự chọn phương án an toàn." % int(_b("turn_timer_ms") / 1000)},
		{"icon": "tag", "title": "2. Ô đất và quyền mua", "wait": "",
			"body": "Ô đất mang màu quận và giá riêng. Dừng ở ô chưa có chủ, bạn có quyền mua trước. Chạm vào một ô bất kỳ để xem giá, tiền thuê và chủ sở hữu."},
		{"icon": "coin", "title": "3. Mua đất hoặc đấu giá", "wait": "",
			"body": "MUA: trả đúng giá và sở hữu ngay. BỎ QUA: cả bàn đấu giá trong %d giây, giá khởi điểm %d%% giá đất (tối thiểu %d RC), mỗi lần trả thêm ít nhất %d RC." % [int(a["timer_ms"] / 1000), a["min_bid_pct_of_price"], a["min_bid_floor"], a["min_increment"]]},
		{"icon": "coin", "title": "4. Thu tiền thuê", "wait": "",
			"body": "Người khác dừng ở đất của bạn phải trả tiền thuê, tự động. Giữ đủ cả quận: thuê ×%d ngay cả khi chưa xây. Nhà cấp 1/2/3: thuê ×%d / ×%d / ×%d giá thuê cơ bản." % [rm["level0_district_complete"] / 100, rm["level1"] / 100, rm["level2"] / 100, rm["level3"] / 100]},
		{"icon": "build", "title": "5. Nâng cấp", "wait": "",
			"body": "Sau khi di chuyển, bạn có MỘT hành động chiến lược: nâng cấp, đề nghị giao dịch hoặc dùng kỹ năng nhân vật, rồi KẾT THÚC LƯỢT. Chỉ nâng cấp được khi giữ đủ quận, tối đa cấp %d." % _b("max_level")},
		{"icon": "event", "title": "6. Sự kiện, cơ hội và cứu nợ", "wait": "",
			"body": "Ô ! rút một trong %d thẻ sự kiện. Ô ? cho chọn một cơ hội, kết quả nói rõ trước. Ô %% là thuế tài sản %d%% (tối đa %d RC). Thiếu tiền: bán đất cho ngân hàng để trả nợ; vẫn thiếu thì phá sản." % [config.cards.size(), wt["pct"], wt["cap"]]},
		{"icon": "trophy", "title": "7. Kết thúc và người thắng", "wait": "",
			"body": "Trận kết thúc khi hết số vòng (%s), hết %d phút, hoặc chỉ còn một người chưa phá sản. Người có tài sản ròng cao nhất thắng; bằng nhau thì xét số quận trọn vẹn, rồi tiền mặt." % [_rounds_text(), int(_b("time_cap_ms") / 60000)]},
	]


## The how-to sheet: every tutorial step as one block of text.
func how_to_text() -> String:
	var goal: Dictionary = intro_pages()[0]
	var out: Array[String] = ["%s\n%s" % [goal["title"], goal["body"]]]
	for s in tutorial_steps():
		out.append("%s\n%s" % [s["title"], s["body"]])
	out.append("Mẹo: chạm vào một ô trên bàn cờ để xem giá, tiền thuê và chủ sở hữu.")
	return "\n\n".join(out)
