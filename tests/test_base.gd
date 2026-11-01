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


## Builds a 49-cell mat from 7 row strings of 7 characters. `variants` maps a cell index to the
## household / street variant of the tile placed there.
## Homes:  s m l = small / medium / large apartment, u = small student residence, v = large one.
## Places: C commercial, U university, L library, B bookshop, X print shop, F coffee shop,
##         K kiosk, E restaurant, S supermarket, M market, H hospital, c clinic, h school, Q parking.
## Green and streets: P park, T trees, R road. "." is an empty lot.
func mat(rows: Array, variants := {}) -> Array:
	var legend := {
		"s": TileDefs.Kind.APT_S, "m": TileDefs.Kind.APT_M, "l": TileDefs.Kind.APT_L,
		"u": TileDefs.Kind.STUDENT_S, "v": TileDefs.Kind.STUDENT_L,
		"C": TileDefs.Kind.COMMERCIAL, "U": TileDefs.Kind.UNIVERSITY, "L": TileDefs.Kind.LIBRARY,
		"B": TileDefs.Kind.BOOKSHOP, "X": TileDefs.Kind.PRINT_SHOP, "F": TileDefs.Kind.COFFEE_SHOP,
		"K": TileDefs.Kind.KIOSK, "E": TileDefs.Kind.RESTAURANT, "S": TileDefs.Kind.SUPERMARKET,
		"M": TileDefs.Kind.MARKET, "H": TileDefs.Kind.HOSPITAL, "c": TileDefs.Kind.CLINIC,
		"h": TileDefs.Kind.SCHOOL, "Q": TileDefs.Kind.PARKING,
		"P": TileDefs.Kind.PARK, "T": TileDefs.Kind.TREES, "R": TileDefs.Kind.ROAD,
	}
	var cells: Array = []
	for row in rows:
		for ch in row:
			if legend.has(ch):
				cells.append(TileDefs.make(legend[ch], variants.get(cells.size(), 0)))
			else:
				cells.append(null)
	return cells
