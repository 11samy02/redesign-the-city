extends RefCounted
## Two prefixed mats built in code, used by the tests that check how fixed tiles behave (they can't be replaced or lost,
## bots build around them). They are test fixtures only: the game itself ships no prefixed mats any more, a player
## builds their own in the mat editor.

const PlayerMatPreset = preload("res://scripts/resources/player_mat_preset.gd")
const PresetTile = preload("res://scripts/resources/preset_tile.gd")
const TileDefs = preload("res://scripts/core/tile_defs.gd")


static func _tile(kind: int, x: int, y: int, large := false) -> PresetTile:
	var t := PresetTile.new()
	t.kind = kind
	t.x = x
	t.y = y
	t.large = large
	return t


static func _mat(title: String, description: String, tiles: Array) -> PlayerMatPreset:
	var m := PlayerMatPreset.new()
	m.title = title
	m.description = description
	var list: Array[PresetTile] = []
	for t in tiles:
		list.append(t)
	m.tiles = list
	return m


## A 2:2 street along the bottom and a university on the right edge.
static func avenue() -> PlayerMatPreset:
	var tiles: Array = []
	for x in range(0, 14, 2):
		tiles.append(_tile(TileDefs.Kind.ROAD, x, 12, true))
	tiles.append(_tile(TileDefs.Kind.UNIVERSITY, 12, 6))
	return _mat("Avenue", "A street runs along the bottom and a university stands on the right edge.", tiles)


## Two 2:2 streets cross in the middle, a school and a park wait in the corners.
static func crossroads() -> PlayerMatPreset:
	var tiles: Array = []
	for y in range(0, 14, 2):
		tiles.append(_tile(TileDefs.Kind.ROAD, 6, y, true))
	for x in [0, 2, 4, 8, 10, 12]:
		tiles.append(_tile(TileDefs.Kind.ROAD, x, 6, true))
	tiles.append(_tile(TileDefs.Kind.SCHOOL, 1, 1))
	tiles.append(_tile(TileDefs.Kind.PARK, 10, 10))
	return _mat("Crossroads", "Two wide streets cross in the middle. A park and a school wait in the corners.", tiles)


static func all() -> Array:
	return [avenue(), crossroads()]
