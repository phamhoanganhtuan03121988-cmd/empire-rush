## The player's name is shown in full: "Tuấn" was cut to "Tu" on a player
## card. Every name label must fit its text, for short and long (14-char)
## Vietnamese names, 2-4 players, portrait and landscape canvases.
extends UiTestCase


## Shown in full: on one line, or wrapped with every line visible.
func _fits(l: Label) -> bool:
	var font := l.get_theme_font("font")
	var fs := l.get_theme_font_size("font_size")
	if font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= l.size.x + 0.5:
		return true
	return l.autowrap_mode != TextServer.AUTOWRAP_OFF and l.get_line_count() <= l.max_lines_visible \
		and l.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING


func test_player_names_fit_on_cards() -> void:
	for canvas in [Vector2i(720, 1280), Vector2i(1600, 900)]:
		for n in [2, 3, 4]:
			for name in ["Tuấn", "Nguyễn Văn Anh"]:
				MatchSetup.chosen = false
				MatchSetup.tutorial = false
				MatchSetup.players = n
				MatchSetup.player_name = name
				MatchSetup.persona = "khoi"
				tree.root.content_scale_size = canvas
				tree.root.size = canvas / 2 if canvas.x < canvas.y else canvas / 2
				main = load("res://scenes/main.tscn").instantiate()
				main.args_override = {"menu": "1", "quality": "low", "telemetry": scratch_telemetry_path()}
				tree.root.add_child(main)
				await frames(4)
				main.menu.buttons["title_play"].pressed.emit()
				await frames(3)
				if main.menu and main.menu.page == "intro":
					main.menu.buttons["intro_skip"].pressed.emit()
					await frames(3)
				main.menu.buttons["start"].pressed.emit()
				await frames(8)
				for c in main.hud._cards:
					var l: Label = c["name"]
					assert_true(_fits(l), "%s, %d players, %s: card name '%s' fits (%.0f px)" % [str(canvas), n, name, l.text, l.size.x])
				await stop_game()
	MatchSetup.player_name = "Bạn"
