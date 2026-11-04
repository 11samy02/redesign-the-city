@tool
class_name PlayerMatPreset
extends Resource
## A prefixed player mat: a 14x14 mat that starts with some tiles already built, so players build their
## city around them. Every player in a game gets the same one. Drop a new .tres of this type into
## res://resources/mats/ and it appears in the mat picker on the title screen.
##
## To add a tile, add an element to `tiles`, pick its kind from the drop-down and give its x and y.
## Tiles that overlap or leave the mat are reported by problems() and skipped when the game builds the mat.

const Grid = preload("res://scripts/core/grid.gd")

@export var title := "New mat"
@export_multiline var description := ""
@export var tiles: Array[PresetTile] = []


## Things wrong with this mat, one sentence each. Empty when it is fine.
func problems() -> Array[String]:
	var out: Array[String] = []
	var cells := Grid.empty()
	for k in tiles.size():
		var t := tiles[k]
		if t == null:
			out.append("Tile %d is empty." % k)
			continue
		var tile := t.to_tile()
		var anchor := Grid.index_of(t.x, t.y)
		var size := t.footprint()
		if not Grid.in_bounds(anchor, size):
			out.append("Tile %d (%d, %d) does not fit on the mat." % [k, t.x, t.y])
		elif not Grid.fits(cells, anchor, size):
			out.append("Tile %d (%d, %d) overlaps another tile." % [k, t.x, t.y])
		else:
			Grid.place(cells, anchor, tile)
	return out


## The 14x14 squares with the prefixed tiles on them. Bad entries are skipped (see problems()).
func build_cells() -> Array:
	var cells := Grid.empty()
	for t in tiles:
		if t == null:
			continue
		var anchor := Grid.index_of(t.x, t.y)
		if Grid.fits(cells, anchor, t.footprint()):
			Grid.place(cells, anchor, t.to_tile())
	return cells
