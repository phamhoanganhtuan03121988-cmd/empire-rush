## HUD skin textures (M2.3): anti-aliased rounded rectangles with vertical
## gradients, a top highlight and a bottom "lip", saved as 2x PNGs used as
## 9-slice StyleBoxTextures (they stretch to any button/panel size, so layout
## stays responsive). Colours come from the design tokens in
## docs/art_direction/ART_DIRECTION.md.
class_name UiGen
extends RefCounted

const S := 2  # authoring scale (2x for crisp edges on phones)


## Rounded-rect coverage for pixel (x, y) in a w x h box with radius r.
static func _cover(x: float, y: float, w: float, h: float, r: float) -> float:
	var qx := absf(x - w * 0.5) - (w * 0.5 - r)
	var qy := absf(y - h * 0.5) - (h * 0.5 - r)
	var outside := Vector2(maxf(qx, 0.0), maxf(qy, 0.0)).length()
	var d := outside + minf(maxf(qx, qy), 0.0) - r
	return clampf(0.5 - d, 0.0, 1.0)


## A button/panel skin: body gradient top->bottom, optional lip under the
## face (pressed buttons have none), 1 px highlight on top, thin border.
static func skin(w: int, h: int, radius: int, top: Color, bottom: Color, lip: Color, lip_px: int,
		border := Color(1, 1, 1, 0.0), highlight := 0.22) -> Image:
	var W := w * S
	var H := h * S
	var R := float(radius * S)
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	var face_h := float(H - lip_px * S)
	for y in H:
		for x in W:
			var px := x + 0.5
			var py := y + 0.5
			var all := _cover(px, py, W, H, R)
			if all <= 0.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var face := _cover(px, py, W, face_h, R)
			var t := clampf(py / maxf(face_h, 1.0), 0.0, 1.0)
			var c := top.lerp(bottom, t)
			# Inner top highlight band.
			var hl := (1.0 - smoothstep(0.0, 6.0 * S, py)) * highlight
			c = c.lerp(Color.WHITE, hl)
			# Border: coverage of the outer shape minus an inset shape.
			if border.a > 0.0:
				var inner := _cover(px - S * 1.5, py - S * 1.5, W - S * 3.0, face_h - S * 3.0, maxf(R - S * 1.5, 1.0))
				var b := clampf(face - inner, 0.0, 1.0)
				c = c.lerp(Color(border.r, border.g, border.b, 1.0), b * border.a)
			# Face over lip: the lip shows only below the face outline.
			var k := clampf(face / all, 0.0, 1.0)
			var out := lip.lerp(c, k)
			out.a = all * lerpf(lip.a, c.a, k)
			img.set_pixel(x, y, out)
	return img


static func all() -> Dictionary:
	var gold_t := Color("#ffd36b")
	var gold_b := Color("#f0a92a")
	var blue_t := Color("#4f86ea")
	var blue_b := Color("#2f5fc4")
	var red_t := Color("#ef6b5f")
	var red_b := Color("#c9443a")
	var slate_t := Color("#4a5677")
	var slate_b := Color("#36405c")
	return {
		"btn_primary": skin(64, 56, 16, gold_t, gold_b, Color("#a8701a"), 6),
		"btn_primary_pressed": skin(64, 56, 16, gold_b, gold_b.darkened(0.08), Color(0, 0, 0, 0), 0),
		"btn_secondary": skin(64, 56, 16, blue_t, blue_b, Color("#1f3f86"), 6),
		"btn_secondary_pressed": skin(64, 56, 16, blue_b, blue_b.darkened(0.1), Color(0, 0, 0, 0), 0),
		"btn_danger": skin(64, 56, 16, red_t, red_b, Color("#8e2a23"), 6),
		"btn_danger_pressed": skin(64, 56, 16, red_b, red_b.darkened(0.1), Color(0, 0, 0, 0), 0),
		"btn_neutral": skin(64, 56, 16, slate_t, slate_b, Color("#232a3d"), 6),
		"btn_neutral_pressed": skin(64, 56, 16, slate_b, slate_b.darkened(0.1), Color(0, 0, 0, 0), 0),
		"btn_disabled": skin(64, 56, 16, Color("#59607a"), Color("#4b5168"), Color("#353a4b"), 6, Color(0, 0, 0, 0), 0.08),
		"panel": skin(96, 96, 24, Color(0.10, 0.14, 0.25, 0.94), Color(0.06, 0.09, 0.17, 0.94), Color(0, 0, 0, 0), 0, Color(1, 1, 1, 0.16), 0.08),
		"panel_gold": skin(96, 96, 26, Color(0.11, 0.15, 0.27, 0.97), Color(0.06, 0.09, 0.17, 0.97), Color(0, 0, 0, 0), 0, Color("#f2b134"), 0.08),
		"card": skin(64, 64, 16, Color(1, 1, 1, 0.09), Color(1, 1, 1, 0.04), Color(0, 0, 0, 0), 0, Color(1, 1, 1, 0.14), 0.06),
		"chip": skin(48, 40, 20, Color(1, 1, 1, 0.14), Color(1, 1, 1, 0.08), Color(0, 0, 0, 0), 0, Color(1, 1, 1, 0.18), 0.0),
	}
