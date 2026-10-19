## Phase 5.1: a persona portrait in a round badge ringed with the seat's
## pawn colour (setup line-up, HUD player cards, results). Cosmetic only.
class_name PortraitBadge
extends PanelContainer


static func make(tex: Texture2D, ring: Color, size := 56.0) -> PortraitBadge:
	var b := PortraitBadge.new()
	var st := StyleBoxFlat.new()
	st.bg_color = ring.darkened(0.35)
	st.set_corner_radius_all(int(size))
	st.set_border_width_all(maxi(2, int(size / 18.0)))
	st.border_color = ring
	st.set_content_margin_all(maxf(2.0, size / 18.0))
	b.add_theme_stylebox_override("panel", st)
	b.custom_minimum_size = Vector2(size, size)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := TextureRect.new()
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(t)
	return b
