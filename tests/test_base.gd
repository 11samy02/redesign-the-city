extends RefCounted
## Tiny assertion helpers shared by the test suites.

const TileDefs = preload("res://scripts/core/tile_defs.gd")

var failures: Array[String] = []


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func eq(actual, expected, msg: String) -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [msg, str(expected), str(actual)])


## Builds a 16-cell mat from 4 row strings.
## s/m/l = small/medium/large apartment, A = amenity, P = park, T = trees, R = road, . = empty
func mat(rows: Array) -> Array:
	var legend := {
		"s": TileDefs.Kind.APT_S, "m": TileDefs.Kind.APT_M, "l": TileDefs.Kind.APT_L,
		"A": TileDefs.Kind.AMENITY, "P": TileDefs.Kind.PARK, "T": TileDefs.Kind.TREES,
		"R": TileDefs.Kind.ROAD,
	}
	var cells: Array = []
	for row in rows:
		for ch in row:
			cells.append(TileDefs.make(legend[ch]) if legend.has(ch) else null)
	return cells
