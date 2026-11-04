extends RefCounted
## The 14x14 squares of a player mat and the tiles that cover them. A tile covers 1x1 or 2x2 squares.
##
## A mat is a flat array of CELLS entries (index = y * SIZE + x). A tile sits in its top-left square, the
## *anchor*. The other squares of a 2:2 tile hold a *part*: a copy of the tile's kind and variant, plus
## `part = true` and `dx`, `dy` (how far this square is from the anchor). That way "what is on this
## square" (kind_at) works for every square, so roads connect through any square of a 2:2 street, while
## code that counts or scores tiles walks `anchors` and sees each tile once.

const TileDefs = preload("res://scripts/core/tile_defs.gd")

const SIZE := 14
const CELLS := SIZE * SIZE
## Squares in the side of a 2:2 tile. Distances that used to be counted in tiles are counted in blocks of
## this many squares now, so the same physical walk still means the same thing.
const BLOCK := 2

static var _neighbour_cache: Array = []
static var _border_cache := {}


static func x_of(i: int) -> int:
	return i % SIZE


static func y_of(i: int) -> int:
	return i / SIZE


static func index_of(x: int, y: int) -> int:
	return y * SIZE + x


static func empty() -> Array:
	var cells: Array = []
	cells.resize(CELLS)
	return cells


## The (up to 4) squares that share an edge with square `i`: north, east, south, west.
static func neighbours(i: int) -> Array[int]:
	if _neighbour_cache.is_empty():
		for c in CELLS:
			var out: Array[int] = []
			var x := c % SIZE
			var y := c / SIZE
			if y > 0: out.append(c - SIZE)
			if x < SIZE - 1: out.append(c + 1)
			if y < SIZE - 1: out.append(c + SIZE)
			if x > 0: out.append(c - 1)
			_neighbour_cache.append(out)
	return _neighbour_cache[i]


# ---------------------------------------------------------------- tiles on squares

static func is_part(tile) -> bool:
	return tile != null and tile.has("part")


## Squares a tile of `size` covers when its top-left square is `anchor`.
static func footprint(anchor: int, size: int) -> Array[int]:
	var out: Array[int] = []
	var x := anchor % SIZE
	var y := anchor / SIZE
	for dy in size:
		for dx in size:
			out.append((y + dy) * SIZE + x + dx)
	return out


## The squares around a tile (sharing an edge with any square of it), without the tile's own squares.
static func border(anchor: int, size: int) -> Array[int]:
	var key := anchor * 4 + size
	if _border_cache.has(key):
		return _border_cache[key]
	var own := footprint(anchor, size)
	var out: Array[int] = []
	for c in own:
		for n in neighbours(c):
			if not (n in own) and not (n in out):
				out.append(n)
	out.sort()
	_border_cache[key] = out
	return out


## The footprint of the tile that covers square `i`, as {"anchor", "size"} (anchor -1 when it is empty).
static func tile_at(cells: Array, i: int) -> Dictionary:
	var t = cells[i]
	if t == null:
		return {"anchor": -1, "size": 1}
	if t.has("part"):
		return {"anchor": i - t["dx"] - t["dy"] * SIZE, "size": TileDefs.footprint(t)}
	return {"anchor": i, "size": TileDefs.footprint(t)}


## The anchor of the tile on square `i`, or -1.
static func anchor_of(cells: Array, i: int) -> int:
	if i < 0 or i >= cells.size() or cells[i] == null:
		return -1
	var t: Dictionary = cells[i]
	return i - t["dx"] - t["dy"] * SIZE if t.has("part") else i


## Square `i` itself when it is empty or a tile's anchor; the tile's anchor when it is a part.
static func tile_of(cells: Array, i: int):
	var a := anchor_of(cells, i)
	return null if a < 0 else cells[a]


## Every anchor on the mat, in order: one entry per tile.
static func anchors(cells: Array) -> Array[int]:
	var out: Array[int] = []
	for i in cells.size():
		var t = cells[i]
		if t != null and not t.has("part"):
			out.append(i)
	return out


## Every tile on the mat once (parts left out).
static func tiles(cells: Array) -> Array:
	var out: Array = []
	for t in cells:
		if t != null and not t.has("part"):
			out.append(t)
	return out


static func in_bounds(anchor: int, size: int) -> bool:
	return anchor >= 0 and anchor < CELLS and anchor % SIZE + size <= SIZE and anchor / SIZE + size <= SIZE


## Can a tile of `size` go with its top-left square on `anchor`: inside the mat and on empty squares?
static func fits(cells: Array, anchor: int, size: int) -> bool:
	if not in_bounds(anchor, size):
		return false
	for c in footprint(anchor, size):
		if cells[c] != null:
			return false
	return true


## Every anchor where a tile of `size` fits.
static func valid_anchors(cells: Array, size: int) -> Array[int]:
	var out: Array[int] = []
	for a in CELLS:
		if fits(cells, a, size):
			out.append(a)
	return out


## Where a tile of `size` goes when the player points at square `cell`: the anchor whose footprint
## contains `cell`, preferring `cell` as the top-left square, and that fits. -1 when none does.
static func find_anchor(cells: Array, cell: int, size: int) -> int:
	if cell < 0 or cell >= CELLS:
		return -1
	if size == 1:
		return cell if cells[cell] == null else -1
	var x := cell % SIZE
	var y := cell / SIZE
	for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		var ax: int = x - d.x
		var ay: int = y - d.y
		if ax < 0 or ay < 0:
			continue
		var a := ay * SIZE + ax
		if fits(cells, a, size):
			return a
	return -1


## Where the ghost of a tile of `size` is drawn when the player points at `cell`: like find_anchor, but
## when nothing fits it still gives the position next to the cursor so the red ghost can be drawn.
static func ghost_anchor(cell: int, size: int) -> int:
	var x := clampi(cell % SIZE, 0, SIZE - size)
	var y := clampi(cell / SIZE, 0, SIZE - size)
	return y * SIZE + x


## The squares a tile covers, ready to write: [tile, part(1,0), part(0,1), part(1,1)] for a 2:2 tile.
static func pieces(tile: Dictionary) -> Array:
	var out: Array = [tile]
	if TileDefs.footprint(tile) == 2:
		for d in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
			var part: Dictionary = {"kind": tile["kind"], "variant": tile.get("variant", 0), "part": true, "dx": d.x, "dy": d.y}
			if tile.get("fixed", false):
				part["fixed"] = true
			out.append(part)
	return out


## Writes `pieces` (see `pieces`) onto the mat with the anchor on `anchor`. No checks: use `fits` first.
static func place_pieces(cells: Array, anchor: int, pieces_of_tile: Array) -> void:
	cells[anchor] = pieces_of_tile[0]
	if pieces_of_tile.size() == 1:
		return
	for k in range(1, pieces_of_tile.size()):
		var p: Dictionary = pieces_of_tile[k]
		cells[anchor + p["dx"] + p["dy"] * SIZE] = p


static func place(cells: Array, anchor: int, tile: Dictionary) -> void:
	place_pieces(cells, anchor, pieces(tile))


## Empties every square of the tile that covers square `i`. Returns the tile, or null.
static func remove(cells: Array, i: int):
	var at := tile_at(cells, i)
	if at["anchor"] < 0:
		return null
	var tile = cells[at["anchor"]]
	for c in footprint(at["anchor"], at["size"]):
		cells[c] = null
	return tile


## The squares of the tile on square `i` (empty array when it is empty).
static func squares_of(cells: Array, i: int) -> Array[int]:
	var at := tile_at(cells, i)
	var out: Array[int] = []
	if at["anchor"] >= 0:
		out.append_array(footprint(at["anchor"], at["size"]))
	return out


## Gap between two tiles, counted like king moves between their nearest squares: 1 when they touch (also
## at a corner), 2 with one square between them. A tile that overlaps itself gives 0 or less.
static func gap(a_anchor: int, a_size: int, b_anchor: int, b_size: int) -> int:
	var ax0 := a_anchor % SIZE
	var ay0 := a_anchor / SIZE
	var bx0 := b_anchor % SIZE
	var by0 := b_anchor / SIZE
	var dx := maxi(ax0 - (bx0 + b_size - 1), bx0 - (ax0 + a_size - 1))
	var dy := maxi(ay0 - (by0 + b_size - 1), by0 - (ay0 + a_size - 1))
	return maxi(dx, dy)
