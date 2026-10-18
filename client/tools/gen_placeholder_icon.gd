## Generates the PLACEHOLDER app icon (no external art): a gold board diamond
## on the dark-blue HUD colour. Needed only because iOS export refuses to run
## without an icon. Replace with a real icon before any release.
## Run: godot --headless --path client --script res://tools/gen_placeholder_icon.gd
extends SceneTree

const SIZE := 1024
const OUT := "res://assets/placeholder/app_icon_placeholder_1024.png"


func _init() -> void:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	var bg := Color("#13203a")
	var ring := Color("#f2b84b")
	var inner := Color("#3f8f5a")
	var c := SIZE / 2.0
	for y in SIZE:
		for x in SIZE:
			# Diamond distance (L1 norm) from the centre, like the board seen at 45 degrees.
			var d: float = (absf(x - c) + absf(y - c)) / c
			var col := bg
			if d < 0.78:
				col = ring if d > 0.52 else inner
			img.set_pixel(x, y, col)
	var err := img.save_png(ProjectSettings.globalize_path(OUT))
	print("ICON ", OUT, " err=", err)
	quit(0 if err == OK else 1)
