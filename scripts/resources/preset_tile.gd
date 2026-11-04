@tool
class_name PresetTile
extends Resource
## One tile that is already built on a prefixed player mat (see PlayerMatPreset).
##
## `x` and `y` are the grid square of the tile's TOP-LEFT corner, counted from 0 on the 14x14 mat:
## (0, 0) is the top-left square, (13, 13) the bottom-right one. A 2:2 tile covers x..x+1 and y..y+1.
## How big a tile is follows from its kind (see TileDefs.BIG_KINDS). Only streets can be made 2:2 here.

const TileDefs = preload("res://scripts/core/tile_defs.gd")

## Pick the tile from the drop-down.
@export var kind: TileDefs.Kind = TileDefs.Kind.ROAD
@export_range(0, 13) var x := 0
@export_range(0, 13) var y := 0
## Which household lives in a home (the index in TileDefs.HOUSEHOLDS, 0 = the first) or which street a
## road is (0 road, 1 shaded, 2 pedestrian, 3 bike lane). Leave 0 for everything else.
@export var variant := 0
## Roads only: make this street 2:2 instead of 1:1.
@export var large := false


## The tile as the game stores it. Prefixed tiles are `fixed`: they can't be replaced or lost.
func to_tile() -> Dictionary:
	var tile := TileDefs.make(kind, variant)
	tile["fixed"] = true
	if large and kind == TileDefs.Kind.ROAD:
		tile["big"] = true
	return tile


## Squares along one side: 1 or 2.
func footprint() -> int:
	return TileDefs.footprint(to_tile())
