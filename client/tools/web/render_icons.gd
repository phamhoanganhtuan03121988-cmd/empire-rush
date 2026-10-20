## Renders the app icon SVG (assets/branding/app_icon.svg, drawn by
## scripts/art/gen_app_icon.py) to the PNG sizes the web/PWA export and the
## home screen need. Run: godot --headless --path client --script res://tools/web/render_icons.gd
extends SceneTree


func _initialize() -> void:
	var svg := FileAccess.get_file_as_string("res://assets/branding/app_icon.svg")
	for size in [1024, 512, 192, 180, 144]:
		var img := Image.new()
		if img.load_svg_from_string(svg, float(size) / 1024.0) != OK:
			push_error("SVG render failed")
			quit(1)
			return
		img.convert(Image.FORMAT_RGB8)  # opaque: iOS shows black behind alpha
		var path := ProjectSettings.globalize_path("res://assets/branding/icon_%d.png" % size)
		img.save_png(path)
		print("ICON ", path.get_file(), " ", img.get_size())
	quit(0)
