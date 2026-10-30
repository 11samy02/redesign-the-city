extends SceneTree
## Renders every SVG in assets/ into one PNG for art review.
## godot --headless --path . --script res://tools/contact_sheet.gd -- <out.png>

func _init() -> void:
	var out_path: String = OS.get_cmdline_user_args()[0]
	var files: Array[String] = []
	for dir in ["res://assets/tiles/", "res://assets/ui/"]:
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".svg"):
				files.append(dir + f)
	var cell := 200
	var cols := 7
	var rows := ceili(files.size() / float(cols))
	var sheet := Image.create(cols * cell, rows * cell, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("#0F2A3D"))
	for i in files.size():
		var img := Image.new()
		img.load_svg_from_string(FileAccess.get_file_as_string(files[i]), 1.0)
		img.resize(184, 184, Image.INTERPOLATE_LANCZOS)
		sheet.blend_rect(img, Rect2i(0, 0, 184, 184), Vector2i((i % cols) * cell + 8, (i / cols) * cell + 8))
	sheet.save_png(out_path)
	print("saved ", files.size())
	quit()
