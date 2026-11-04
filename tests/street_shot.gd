extends SceneTree
## Renders big streets with small roads joining them, for checking how they meet:
##   godot --path . --resolution 900x700 --script res://tests/street_shot.gd -- --out=<file.png>
const MatView = preload("res://scripts/ui/mat_view.gd")
const TileView = preload("res://scripts/ui/tile_view.gd")
const Scoring = preload("res://scripts/core/scoring.gd")
const Grid = preload("res://scripts/core/grid.gd")
const TileDefs = preload("res://scripts/core/tile_defs.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")


func _initialize() -> void:
	_run()


func _big() -> Dictionary:
	var t := TileDefs.make(TileDefs.Kind.ROAD)
	t["big"] = true
	return t


func _run() -> void:
	var cells := Grid.empty()
	for x in range(0, 14, 2):
		Grid.place(cells, 12 * 14 + x, _big())
	for y in range(0, 12, 2):
		Grid.place(cells, y * 14 + 6, _big())
	Grid.place(cells, 6 * 14 + 4, _big())
	Grid.place(cells, 6 * 14 + 2, _big())
	Grid.place(cells, 6 * 14 + 8, _big())
	# small roads joining the big streets from the side, at both squares of a side
	for sq in [11 * 14 + 2, 11 * 14 + 9, 10 * 14 + 5, 9 * 14 + 8, 4 * 14 + 4, 7 * 14 + 5, 1 * 14 + 8]:
		Grid.place(cells, sq, TileDefs.make(TileDefs.Kind.ROAD))
	var view := MatView.new()
	view.setup(60.0, 2.0, TileView.Mode.MAT)
	root.add_child(view)
	root.theme = UiKit.build_theme()
	view.refresh(cells, Scoring.evaluate(cells, 0))
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var out := "streets.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	root.get_texture().get_image().save_png(out)
	quit()
