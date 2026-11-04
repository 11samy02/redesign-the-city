extends RefCounted
## Tiny assertion helpers shared by the test suites.

const TileDefs = preload("res://scripts/core/tile_defs.gd")
const Grid = preload("res://scripts/core/grid.gd")

## Homes:  s m l = small / medium / large apartment, u = small student residence, v = large one.
## Places: C commercial, U university, L library, B bookshop, X print shop, F coffee shop,
##         K kiosk, E restaurant, S supermarket, M market, H hospital, c clinic, h school, Q parking.
## Green and streets: P park, T trees, R road, W a wide (2:2) street. "." is an empty lot.
const LEGEND := {
	"s": TileDefs.Kind.APT_S, "m": TileDefs.Kind.APT_M, "l": TileDefs.Kind.APT_L,
	"u": TileDefs.Kind.STUDENT_S, "v": TileDefs.Kind.STUDENT_L,
	"C": TileDefs.Kind.COMMERCIAL, "U": TileDefs.Kind.UNIVERSITY, "L": TileDefs.Kind.LIBRARY,
	"B": TileDefs.Kind.BOOKSHOP, "X": TileDefs.Kind.PRINT_SHOP, "F": TileDefs.Kind.COFFEE_SHOP,
	"K": TileDefs.Kind.KIOSK, "E": TileDefs.Kind.RESTAURANT, "S": TileDefs.Kind.SUPERMARKET,
	"M": TileDefs.Kind.MARKET, "H": TileDefs.Kind.HOSPITAL, "c": TileDefs.Kind.CLINIC,
	"h": TileDefs.Kind.SCHOOL, "Q": TileDefs.Kind.PARKING,
	"P": TileDefs.Kind.PARK, "T": TileDefs.Kind.TREES, "R": TileDefs.Kind.ROAD, "W": TileDefs.Kind.ROAD,
}

var failures: Array[String] = []


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func eq(actual, expected, msg: String) -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [msg, str(expected), str(actual)])


## Where the tile of the old 7x7 layout's cell `i` sits on the 14x14 mat (see `mat`).
func at(i: int) -> int:
	return (i / 7) * 2 * Grid.SIZE + (i % 7) * 2


## A 14x14 mat from 7 row strings of 7 characters, the way the game looked before tiles had sizes:
## every character is one block of 2x2 squares, and every tile fills its whole block (so a tile in
## cell i of the 7x7 layout sits on square `at(i)`, and a route of n old roads is 2n squares long).
## `variants` maps a 7x7 cell index to the household / street variant of the tile placed there.
func mat(rows: Array, variants := {}) -> Array:
	var cells := Grid.empty()
	var n := 0
	for row in rows:
		for ch in row:
			if LEGEND.has(ch):
				var tile := TileDefs.make(LEGEND[ch], variants.get(n, 0))
				tile["big"] = true
				Grid.place(cells, at(n), tile)
			n += 1
	return cells


## A mat from 14 row strings of 14 characters with real tile sizes: a 2:2 tile is written as a 2x2 block
## of its letter (park "PP" over "PP"), a 1:1 tile as one letter, and a wide street as a 2x2 block of W.
## `variants` maps the top-left square's index to a variant.
func mat14(rows: Array, variants := {}) -> Array:
	var cells := Grid.empty()
	var seen := {}
	for y in Grid.SIZE:
		for x in Grid.SIZE:
			var i := y * Grid.SIZE + x
			var ch: String = rows[y][x]
			if seen.has(i) or not LEGEND.has(ch):
				continue
			var tile := TileDefs.make(LEGEND[ch], variants.get(i, 0))
			if ch == "W":
				tile["big"] = true
			assert(Grid.fits(cells, i, TileDefs.footprint(tile)), "bad mat14 layout at %d,%d" % [x, y])
			Grid.place(cells, i, tile)
			for c in Grid.footprint(i, TileDefs.footprint(tile)):
				seen[c] = true
	return cells


## 14 empty rows for mat14.
func blank14() -> Array:
	var rows: Array = []
	for y in Grid.SIZE:
		rows.append(".".repeat(Grid.SIZE))
	return rows


## Puts `text` into row `y` of a mat14 layout starting at column `x`.
func put(rows: Array, x: int, y: int, text: String) -> Array:
	var row: String = rows[y]
	rows[y] = row.substr(0, x) + text + row.substr(x + text.length())
	return rows
