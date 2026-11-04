extends SceneTree
## Renders one mat with a home, a road and a 2:2 service and saves a picture of the route line:
##   godot --path . --script res://tests/route_shot.gd -- --out=<file.png>
const MatView = preload("res://scripts/ui/mat_view.gd")
const TileView = preload("res://scripts/ui/tile_view.gd")
const Scoring = preload("res://scripts/core/scoring.gd")
const Grid = preload("res://scripts/core/grid.gd")
const TileDefs = preload("res://scripts/core/tile_defs.gd")
const Influence = preload("res://scripts/game/influence.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")


func _initialize() -> void:
	_run()


func _run() -> void:
	var cells := Grid.empty()
	Grid.place(cells, 5 * 14 + 2, TileDefs.make(TileDefs.Kind.APT_L))
	for x in [4, 5, 6]:
		Grid.place(cells, 6 * 14 + x, TileDefs.make(TileDefs.Kind.ROAD))
	Grid.place(cells, 5 * 14 + 7, TileDefs.make(TileDefs.Kind.LIBRARY))
	Grid.place(cells, 5 * 14 + 4, TileDefs.make(TileDefs.Kind.TREES))
	var r := Scoring.evaluate(cells, 0)
	var view := MatView.new()
	view.setup(40.0, 2.0, TileView.Mode.MAT)
	root.add_child(view)
	root.theme = UiKit.build_theme()
	view.refresh(cells, r)
	Influence.show_for(view, cells, r, 5 * 14 + 2)
	await process_frame
	await process_frame
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	var out := "route.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	root.get_texture().get_image().save_png(out)
	quit()
