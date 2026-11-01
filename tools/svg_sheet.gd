extends SceneTree
## Lays the pictures of a folder (default assets/cards) out in one contact sheet so they can be looked at
## together:  godot --headless --path . --script res://tools/svg_sheet.gd -- --out=C:/some/sheet.png [--dir=res://assets/ui] [--only=prefix] [--skip=N --count=M]

const COLUMNS := 8
const CELL := 256


func _initialize() -> void:
	var out := "res://card_sheet.png"
	var dir := "res://assets/cards"
	var only := ""
	var skip := 0
	var count := 100000
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--dir="):
			dir = a.substr(6)
		elif a.begins_with("--only="):
			only = a.substr(7)
		elif a.begins_with("--skip="):
			skip = int(a.substr(7))
		elif a.begins_with("--count="):
			count = int(a.substr(8))
	var files: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".svg") and (only == "" or f.begins_with(only)):
			files.append(f)
	files.sort()
	files = files.slice(skip, skip + count)
	var rows := ceili(files.size() / float(COLUMNS))
	var sheet := Image.create(COLUMNS * CELL, rows * CELL, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("#F4EFE3"))
	for i in files.size():
		var img := Image.new()
		var text := FileAccess.get_file_as_string(dir + "/" + files[i])
		img.load_svg_from_string(text, 1.0)
		img.convert(Image.FORMAT_RGBA8)
		sheet.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i((i % COLUMNS) * CELL, (i / COLUMNS) * CELL))
	sheet.save_png(out)
	print("sheet of ", files.size(), " pictures written to ", out)
	quit()
