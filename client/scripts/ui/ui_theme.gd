## Mobile UI theme. Sizes target iPhone 14 Pro (393 pt wide): the design
## viewport is 720 px wide, so 1 pt ≈ 1.83 px; buttons are >= 88 px (~48 pt).
class_name UiTheme
extends RefCounted

const NAVY := Color("#16203a")
const NAVY_SOFT := Color("#22305a")
const GOLD := Color("#f2b134")
const GOLD_DARK := Color("#b9821c")
const INK := Color("#1b1b1b")
const TEXT := Color("#f6f1e7")
const RED := Color("#e05d5d")
const BLUE := Color("#3d6fd6")
const MIN_TOUCH := 88


static func panel(bg := NAVY, border := Color(1, 1, 1, 0.12), radius := 22, alpha := 0.92) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(bg, alpha)
	s.set_corner_radius_all(radius)
	s.set_border_width_all(2)
	s.border_color = border
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 14
	s.content_margin_bottom = 14
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 8
	return s


static func build() -> Theme:
	var th := Theme.new()
	th.default_font_size = 28
	th.set_color("font_color", "Label", TEXT)
	th.set_constant("outline_size", "Label", 0)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var s := StyleBoxFlat.new()
		s.set_corner_radius_all(20)
		s.content_margin_left = 22
		s.content_margin_right = 22
		s.content_margin_top = 12
		s.content_margin_bottom = 12
		match state:
			"normal": s.bg_color = GOLD
			"hover": s.bg_color = GOLD.lightened(0.1)
			"pressed": s.bg_color = GOLD_DARK
			"disabled": s.bg_color = Color(0.45, 0.45, 0.5)
			"focus":
				s.bg_color = Color(0, 0, 0, 0)
				s.set_border_width_all(3)
				s.border_color = Color.WHITE
		s.border_width_bottom = maxi(s.border_width_bottom, 6 if state != "pressed" and state != "focus" else 0)
		if state != "focus":
			s.border_color = GOLD_DARK.darkened(0.2)
		th.set_stylebox(state, "Button", s)
	th.set_color("font_color", "Button", INK)
	th.set_color("font_hover_color", "Button", INK)
	th.set_color("font_pressed_color", "Button", INK)
	th.set_color("font_disabled_color", "Button", Color(0.85, 0.85, 0.85))
	th.set_font_size("font_size", "Button", 30)
	th.set_stylebox("panel", "PanelContainer", panel())
	return th


static func secondary(b: Button) -> void:
	for state in ["normal", "hover", "pressed"]:
		var s: StyleBoxFlat = b.get_theme_stylebox(state).duplicate()
		s.bg_color = BLUE if state == "normal" else (BLUE.lightened(0.1) if state == "hover" else BLUE.darkened(0.2))
		s.border_color = BLUE.darkened(0.4)
		b.add_theme_stylebox_override(state, s)
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(c, Color.WHITE)


static func danger(b: Button) -> void:
	for state in ["normal", "hover", "pressed"]:
		var s: StyleBoxFlat = b.get_theme_stylebox(state).duplicate()
		s.bg_color = RED if state == "normal" else (RED.lightened(0.1) if state == "hover" else RED.darkened(0.2))
		s.border_color = RED.darkened(0.4)
		b.add_theme_stylebox_override(state, s)
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(c, Color.WHITE)
