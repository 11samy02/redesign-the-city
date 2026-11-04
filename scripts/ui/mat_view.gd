extends Control
## A player's 14x14 mat: squares, tiles (1:1 or 2:2) with live badges, road routes and highlights.
##
## There is one TileView per square. A tile is drawn by the view of its top-left square (its anchor),
## which is made as big as the tile; the views of the other squares of a 2:2 tile are hidden. Signals
## carry the index of the view that was used: an empty square, or the anchor of a tile.

const TileView = preload("res://scripts/ui/tile_view.gd")
const TileDefs = preload("res://scripts/core/tile_defs.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Scoring = preload("res://scripts/core/scoring.gd")
const Grid = preload("res://scripts/core/grid.gd")

signal cell_pressed(index: int)
signal cell_right_pressed(index: int)
signal cell_hovered(index: int, inside: bool)

const N := Grid.SIZE
## Directions as [dx, dy, bit]: N = 1, E = 2, S = 4, W = 8.
const DIRS := [[0, -1, 1], [1, 0, 2], [0, 1, 4], [-1, 0, 8]]

var cell := 35.0
var gap := 2.0
var pad := 12.0
var views: Array = []
var cells: Array = []
var result: Dictionary = {}

var _routes: Array = []
var _route_t := 0.0
var _overlay: Control
var _ghost_tile = null
var _ghost_anchor := -1
## When the ghost replaces a bigger tile: that tile's size, so the squares it gives up can be marked too.
var _ghost_replaced_n := 0
var _ghost_valid := true
var _ghost_mask := 15
var _ghost_t := 0.0


func setup(cell_size: float, cell_gap: float, mode: int, interactive := true) -> void:
	cell = cell_size
	gap = cell_gap
	pad = maxf(6.0, cell * 0.2)
	var side := N * cell + (N - 1) * gap + 2 * pad
	custom_minimum_size = Vector2(side, side)
	size = custom_minimum_size
	for i in N * N:
		var v := TileView.new()
		v.mode = mode
		v.index = i
		v.position = cell_pos(i)
		v.size = Vector2(cell, cell)
		v.interactive = interactive
		v.pressed.connect(func(view): cell_pressed.emit(view.index))
		v.right_pressed.connect(func(view): cell_right_pressed.emit(view.index))
		v.hovered.connect(func(view, inside): cell_hovered.emit(view.index, inside))
		add_child(v)
		views.append(v)
	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.size = custom_minimum_size
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
	set_process(false)


func cell_pos(i: int) -> Vector2:
	return Vector2(pad + (i % N) * (cell + gap), pad + (i / N) * (cell + gap))


## Pixels along one side of a tile that covers `n` squares.
func span(n: int) -> float:
	return n * cell + (n - 1) * gap


## Centre of the square, or of the whole tile when `i` is the top-left square of one.
func cell_center(i: int) -> Vector2:
	var n := 1
	if i >= 0 and i < cells.size() and cells[i] != null and not cells[i].has("part"):
		n = TileDefs.footprint(cells[i])
	return cell_pos(i) + Vector2(span(n), span(n)) / 2.0


## Screen rect of the square, or of the whole tile when `i` is its top-left square.
func cell_global_rect(i: int) -> Rect2:
	return views[i].get_global_rect()


## Screen rect of a tile of `n` x `n` squares whose top-left square is `anchor` (built or not yet).
func footprint_global_rect(anchor: int, n: int) -> Rect2:
	# the view on the top-left square may belong to a bigger tile that stands there now (a 2:2 about to be replaced by
	# a 1:1), so the size comes from n, not from the view
	var a: Rect2 = views[anchor].get_global_rect()
	var k := a.size.x / maxf(views[anchor].size.x, 1.0)
	return Rect2(a.position, Vector2(span(n), span(n)) * k)


## The top-left square of the tile covering square `i`, or -1 when the square is empty.
func anchor_of(i: int) -> int:
	return Grid.anchor_of(cells, i) if cells.size() == N * N else i


## The sides (N=1, E=2, S=4, W=8) of the tile on square `i` that touch a square matching `pred`.
static func _side_mask(c: Array, i: int, pred: Callable) -> int:
	var mask := 0
	var at := Grid.tile_at(c, i)
	var a: int = at["anchor"] if at["anchor"] >= 0 else i
	var n: int = at["size"]
	var x := a % N
	var y := a / N
	for d in DIRS:
		for k in n:
			# the square just outside the tile on this side, at each of the n positions along it
			var nx: int = x + (n if d[0] > 0 else d[0]) if d[0] != 0 else x + k
			var ny: int = y + (n if d[1] > 0 else d[1]) if d[1] != 0 else y + k
			if nx < 0 or ny < 0 or nx >= N or ny >= N:
				continue
			var t = c[ny * N + nx]
			if t != null and pred.call(t):
				mask |= d[2]
				break
	return mask


## How a 2:2 street meets the roads around it: {"mask": the sides that touch another 2:2 street, "stubs": [{"dir", "k"}]}
## for every 1:1 road that touches it (dir: side N=1, E=2, S=4, W=8; k: which of the side's 2 squares it touches).
## The 2:2 street art only knows how to join the middle of a side, which is where another 2:2 street meets it; a
## 1:1 road meets it at a quarter of the side, so those are drawn as aligned strips (see TileView._draw_road_stubs).
static func big_road_links(c: Array, i: int) -> Dictionary:
	var at := Grid.tile_at(c, i)
	var a: int = at["anchor"] if at["anchor"] >= 0 else i
	var n: int = at["size"]
	var x := a % N
	var y := a / N
	var mask := 0
	var stubs: Array = []
	for d in DIRS:
		for k in n:
			var nx: int = x + (n if d[0] > 0 else d[0]) if d[0] != 0 else x + k
			var ny: int = y + (n if d[1] > 0 else d[1]) if d[1] != 0 else y + k
			if nx < 0 or ny < 0 or nx >= N or ny >= N:
				continue
			var t = c[ny * N + nx]
			if t == null or t["kind"] != TileDefs.Kind.ROAD:
				continue
			var other := Grid.tile_at(c, ny * N + nx)
			if TileDefs.footprint(c[other["anchor"]]) == 2:
				mask |= d[2]
			else:
				stubs.append({"dir": d[2], "k": k})
	if mask == 0 and not stubs.is_empty():
		# a street piece with only small roads beside it still needs a road through it, along the way they join
		mask = 5 if stubs[0]["dir"] in [1, 4] else 10
	return {"mask": mask, "stubs": stubs}


## Road sides of the tile on square `i` (N=1, E=2, S=4, W=8) that touch another road (a 2:2 street only counts
## the 2:2 streets: see big_road_links).
static func road_mask(c: Array, i: int) -> int:
	var at := Grid.tile_at(c, i)
	if at["anchor"] >= 0 and at["size"] == 2 and c[at["anchor"]]["kind"] == TileDefs.Kind.ROAD:
		return big_road_links(c, i)["mask"]
	return _side_mask(c, i, func(t): return t["kind"] == TileDefs.Kind.ROAD)


## Sides of the tile on square `i` (N=1, E=2, S=4, W=8) that touch trees or a park.
static func shade_dirs(c: Array, i: int) -> int:
	return _side_mask(c, i, func(t): return t["kind"] == TileDefs.Kind.PARK or TileDefs.is_tree_like(t))


func refresh(p_cells: Array, p_result: Dictionary) -> void:
	cells = p_cells
	result = p_result
	var apt := {}
	var served := {}
	for a in result["apartments"]:
		apt[a["index"]] = a
		for m in a["routes"]:
			served[m] = served.get(m, 0) + a["citizens"]
	for i in N * N:
		var v = views[i]
		var t = cells[i]
		if t != null and t.has("part"):
			# the rest of a bigger tile: the view of its top-left square covers it
			v.visible = false
			v.tile = null
			continue
		var n := TileDefs.footprint(t) if t != null else 1
		v.visible = true
		v.position = cell_pos(i)
		v.size = Vector2(span(n), span(n))
		v.tile = t
		v.apartment_info = apt.get(i)
		v.badge_text = ""
		v.shade_dirs = 0
		v.road_stubs = big_road_links(cells, i)["stubs"] if (t != null and t["kind"] == TileDefs.Kind.ROAD and n == 2) else []
		if t != null:
			if _any_shaded(i, n):
				v.shade_dirs = shade_dirs(cells, i)
			if TileDefs.is_service(t["kind"]):
				v.badge_text = "Serves %d" % served.get(i, 0)
			else:
				match t["kind"]:
					TileDefs.Kind.ROAD:
						v.road_mask = road_mask(cells, i)
						if TileDefs.is_tree_like(t):
							v.badge_text = "Air -1"
					TileDefs.Kind.PARK:
						v.badge_text = "Air -3"
					TileDefs.Kind.TREES:
						v.badge_text = "Air -1"
		v.queue_redraw()
	_overlay.queue_redraw()


func _any_shaded(i: int, n: int) -> bool:
	for dy in n:
		for dx in n:
			if result["shaded"][i + dy * N + dx]:
				return true
	return false


## Colours for squares or tiles: `map` is {square or anchor index: Color}. A colour on any square of a tile
## lights the whole tile; a colour on the tile's own top-left square wins over one on its other squares.
func set_highlights(map: Dictionary) -> void:
	var by_view := {}
	for k in map:
		var a := anchor_of(k)
		if a < 0:
			a = k
		if k == a or not by_view.has(a):
			by_view[a] = map[k]
	for i in N * N:
		views[i].highlight = by_view.get(i, Color(0, 0, 0, 0))
		views[i].queue_redraw()


func clear_highlights() -> void:
	set_highlights({})
	set_routes([])


## routes: [{ "cells": Array[int] (building, roads..., amenity), "hot": bool }]
func set_routes(routes: Array) -> void:
	_routes = routes
	_route_t = 0.0
	_update_processing()
	_overlay.queue_redraw()


## Lights the squares where a tile of `size` x `size` squares could be built (none when `on` is false).
func set_targets(on: bool, size := 1) -> void:
	var lit := {}
	if on and cells.size() == N * N:
		for a in Grid.valid_anchors(cells, size):
			for c in Grid.footprint(a, size):
				lit[c] = true
	for i in N * N:
		views[i].target_glow = lit.has(i) and cells[i] == null


## Shows `tile` floating over the squares where it would go, with its top-left square on `at`. A ghost that
## does not fit is drawn red. `tile` null removes it.
func set_ghost(tile, at: int, valid := true, replaced_n := 0) -> void:
	_ghost_replaced_n = replaced_n
	_ghost_tile = tile
	_ghost_anchor = at if tile != null else -1
	_ghost_valid = valid
	if tile != null and valid and cells.size() == N * N:
		var preview := cells.duplicate()
		Grid.place(preview, at, tile)
		_ghost_mask = road_mask(preview, at)
	_update_processing()
	_overlay.queue_redraw()


func set_keyboard_focus(at: int) -> void:
	var a := anchor_of(at) if at >= 0 else -1
	for i in N * N:
		views[i].keyboard_focus = i == a or (a < 0 and i == at)


func _update_processing() -> void:
	set_process(not _routes.is_empty() or _ghost_tile != null)


func _process(delta: float) -> void:
	_route_t += delta
	_ghost_t += delta
	_overlay.queue_redraw()


func _draw() -> void:
	var sb := UiKit.box(Color("#0C2433"), int(pad + cell * 0.1), 2, UiKit.LINE)
	draw_style_box(sb, Rect2(Vector2.ZERO, size))


func _draw_overlay() -> void:
	_draw_ghost()
	_draw_routes()


func _draw_ghost() -> void:
	if _ghost_tile == null or _ghost_anchor < 0:
		return
	var n := TileDefs.footprint(_ghost_tile)
	var r := Rect2(cell_pos(_ghost_anchor), Vector2(span(n), span(n)))
	var radius := int(r.size.x * 0.11)
	if _ghost_valid and _ghost_replaced_n > n:
		# the tile being replaced is bigger: it leaves, so the whole of it is marked and only one square is taken
		var old := Rect2(r.position, Vector2(span(_ghost_replaced_n), span(_ghost_replaced_n)))
		_overlay.draw_style_box(UiKit.box(Color(UiKit.HEAT, 0.16), radius, 2, Color(UiKit.HEAT, 0.7)), old)
	if _ghost_valid:
		# the tile itself follows the cursor (see Game); here only the squares it will cover are marked
		var a := 0.55 + 0.35 * sin(_ghost_t * 6.0)
		_overlay.draw_style_box(UiKit.box(Color(UiKit.GOLD, 0.16), radius, 3, Color(UiKit.GOLD, a)), r)
	else:
		_overlay.draw_style_box(UiKit.box(Color(UiKit.HEAT, 0.3), radius, 3, Color(UiKit.HEAT, 0.9)), r)


## The points of a route: the centre of every road square, and at each end the building square that touches the
## road, so the line only ever runs along the grid and never cuts across a 2:2 tile at an angle.
func _route_points(route: Array) -> PackedVector2Array:
	var squares: Array = route.duplicate()
	if squares.size() >= 2 and cells.size() == N * N:
		squares[0] = _touching_square(route[0], route[1])
		squares[squares.size() - 1] = _touching_square(route[route.size() - 1], route[route.size() - 2])
	var pts := PackedVector2Array()
	for c in squares:
		pts.append(cell_pos(c) + Vector2(cell, cell) / 2.0)
	return pts


## The square of the tile `anchor` that shares an edge with square `next`, or `anchor` when none does.
func _touching_square(anchor: int, next: int) -> int:
	for sq in Grid.squares_of(cells, anchor):
		if next in Grid.neighbours(sq):
			return sq
	return anchor


func _draw_routes() -> void:
	var w := maxf(2.5, cell * 0.11)
	for r in _routes:
		var pts := _route_points(r["cells"])
		if pts.size() < 2:
			continue
		var col: Color = UiKit.HEAT if r["hot"] else UiKit.OLIVE
		_overlay.draw_polyline(pts, Color(UiKit.INK_DEEP, 0.7), w + 4, true)
		_overlay.draw_polyline(pts, col, w, true)
		_overlay.draw_circle(pts[0], w * 1.3, col)
		_overlay.draw_circle(pts[pts.size() - 1], w * 1.6, col)
		# a walker travelling the route
		var total := 0.0
		for k in range(1, pts.size()):
			total += pts[k - 1].distance_to(pts[k])
		if total <= 0.0:
			continue
		var d := fmod(_route_t * cell * 3.2, total)
		for k in range(1, pts.size()):
			var seg := pts[k - 1].distance_to(pts[k])
			if d <= seg:
				var p := pts[k - 1].lerp(pts[k], d / maxf(seg, 0.001))
				_overlay.draw_circle(p, w * 1.5, UiKit.LIMESTONE)
				_overlay.draw_circle(p, w * 0.8, col)
				break
			d -= seg
