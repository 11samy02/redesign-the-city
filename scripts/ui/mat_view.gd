extends Control
## A player's 4x4 mat: lots, tiles with live badges, road routes and highlights.

const TileView = preload("res://scripts/ui/tile_view.gd")
const TileDefs = preload("res://scripts/core/tile_defs.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")

signal cell_pressed(index: int)
signal cell_right_pressed(index: int)
signal cell_hovered(index: int, inside: bool)

const N := 4

var cell := 128.0
var gap := 8.0
var pad := 12.0
var views: Array = []
var cells: Array = []
var result: Dictionary = {}

var _routes: Array = []
var _route_t := 0.0
var _overlay: Control


func setup(cell_size: float, cell_gap: float, mode: int, interactive := true) -> void:
	cell = cell_size
	gap = cell_gap
	pad = maxf(6.0, cell * 0.09)
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
	_overlay.draw.connect(_draw_routes)
	add_child(_overlay)
	set_process(false)


func cell_pos(i: int) -> Vector2:
	return Vector2(pad + (i % N) * (cell + gap), pad + (i / N) * (cell + gap))


func cell_center(i: int) -> Vector2:
	return cell_pos(i) + Vector2(cell, cell) / 2.0


func cell_global_rect(i: int) -> Rect2:
	return views[i].get_global_rect()


static func road_mask(c: Array, i: int) -> int:
	var mask := 0
	var x := i % N
	var y := i / N
	var dirs := [[0, -1, 1], [1, 0, 2], [0, 1, 4], [-1, 0, 8]]
	for d in dirs:
		var nx: int = x + d[0]
		var ny: int = y + d[1]
		if nx < 0 or ny < 0 or nx >= N or ny >= N:
			continue
		var t = c[ny * N + nx]
		if t == null:
			continue
		if t["kind"] == TileDefs.Kind.ROAD:
			mask |= d[2]
	return mask


## Sides of road i (N=1, E=2, S=4, W=8) that touch trees or a park.
static func shade_dirs(c: Array, i: int) -> int:
	var mask := 0
	var x := i % N
	var y := i / N
	for d in [[0, -1, 1], [1, 0, 2], [0, 1, 4], [-1, 0, 8]]:
		var nx: int = x + d[0]
		var ny: int = y + d[1]
		if nx < 0 or ny < 0 or nx >= N or ny >= N or c[ny * N + nx] == null:
			continue
		var k: int = c[ny * N + nx]["kind"]
		if k == TileDefs.Kind.PARK or k == TileDefs.Kind.TREES:
			mask |= d[2]
	return mask


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
		v.tile = t
		v.apartment_info = apt.get(i)
		v.badge_text = ""
		v.shade_dirs = shade_dirs(cells, i) if result["shaded"][i] else 0
		if t != null:
			match t["kind"]:
				TileDefs.Kind.ROAD:
					v.road_mask = road_mask(cells, i)
				TileDefs.Kind.AMENITY:
					v.badge_text = "Serves %d" % served.get(i, 0)
				TileDefs.Kind.PARK:
					v.badge_text = "Air -3"
				TileDefs.Kind.TREES:
					v.badge_text = "Air -1"
		v.queue_redraw()


func set_highlights(map: Dictionary) -> void:
	for i in N * N:
		views[i].highlight = map.get(i, Color(0, 0, 0, 0))
		views[i].queue_redraw()


func clear_highlights() -> void:
	set_highlights({})
	set_routes([])


## routes: [{ "cells": Array[int] (building, roads..., amenity), "hot": bool }]
func set_routes(routes: Array) -> void:
	_routes = routes
	_route_t = 0.0
	set_process(not routes.is_empty())
	_overlay.queue_redraw()


func set_targets(on: bool) -> void:
	for i in N * N:
		views[i].target_glow = on and cells.size() == N * N and cells[i] == null


func set_ghost(tile, at: int) -> void:
	for i in N * N:
		var v = views[i]
		if i == at and tile != null:
			var preview := cells.duplicate()
			preview[i] = tile
			v.ghost_tile = tile
			v.ghost_mask = road_mask(preview, i)
		else:
			v.ghost_tile = null
		v.queue_redraw()


func set_keyboard_focus(at: int) -> void:
	for i in N * N:
		views[i].keyboard_focus = i == at


func _process(delta: float) -> void:
	_route_t += delta
	_overlay.queue_redraw()


func _draw() -> void:
	var sb := UiKit.box(Color("#0C2433"), int(pad + cell * 0.1), 2, UiKit.LINE)
	draw_style_box(sb, Rect2(Vector2.ZERO, size))


func _draw_routes() -> void:
	var w := maxf(3.0, cell * 0.055)
	for r in _routes:
		var pts := PackedVector2Array()
		for c in r["cells"]:
			pts.append(cell_center(c))
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
		var d := fmod(_route_t * cell * 1.6, total)
		for k in range(1, pts.size()):
			var seg := pts[k - 1].distance_to(pts[k])
			if d <= seg:
				var p := pts[k - 1].lerp(pts[k], d / seg)
				_overlay.draw_circle(p, w * 1.5, UiKit.LIMESTONE)
				_overlay.draw_circle(p, w * 0.8, col)
				break
			d -= seg
