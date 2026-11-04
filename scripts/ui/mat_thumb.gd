extends Control
## A small picture of a 14 x 14 mat for the map picker: the tiles drawn flat on a board, one draw call per tile.
## Cheap enough to show dozens at once (a MatView builds a node for every square).

const TileDefs = preload("res://scripts/core/tile_defs.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Grid = preload("res://scripts/core/grid.gd")
const MatView = preload("res://scripts/ui/mat_view.gd")

const LOT := Color("#CDBB92")
const LOT_EDGE := Color("#B9A57A")

var cells: Array = []
var gap := 1.0


## `px` is the width and height of the picture.
func show_mat(p_cells: Array, px: float) -> void:
	cells = p_cells
	custom_minimum_size = Vector2(px, px)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	var board := Rect2(Vector2.ZERO, size)
	draw_style_box(UiKit.box(Color("#0C2433"), 14, 2, UiKit.LINE), board)
	var pad := maxf(6.0, size.x * 0.045)
	var step := (size.x - 2.0 * pad + gap) / Grid.SIZE
	var cell := step - gap
	var radius := int(cell * 0.22)
	var lot := UiKit.box(LOT, radius, 1, LOT_EDGE)
	for i in Grid.CELLS:
		if cells.size() == Grid.CELLS and cells[i] != null:
			continue
		draw_style_box(lot, Rect2(_at(i, pad, step), Vector2(cell, cell)))
	if cells.size() != Grid.CELLS:
		return
	for a in Grid.anchors(cells):
		var t: Dictionary = cells[a]
		var n := TileDefs.footprint(t)
		var side := n * cell + (n - 1) * gap
		var mask := MatView.road_mask(cells, a) if t["kind"] == TileDefs.Kind.ROAD else 15
		draw_texture_rect(UiKit.tex(TileDefs.art_path(t, mask)), Rect2(_at(a, pad, step), Vector2(side, side)), false)


func _at(i: int, pad: float, step: float) -> Vector2:
	return Vector2(pad + (i % Grid.SIZE) * step, pad + (i / Grid.SIZE) * step)
