extends RefCounted
## Highlights what one tile touches on a mat: citizen routes, green areas and the homes they serve.

const UiKit = preload("res://scripts/ui/ui_kit.gd")
const TileDefs = preload("res://scripts/core/tile_defs.gd")
const Scoring = preload("res://scripts/core/scoring.gd")
const MatView = preload("res://scripts/ui/mat_view.gd")


## `cells` and `r` (the scoring result for them) are what is on the mat now, or a preview of it.
static func show_for(view: MatView, cells: Array, r: Dictionary, i: int) -> void:
	var t = cells[i]
	if t == null:
		view.clear_highlights()
		return
	var hl := {}
	var routes: Array = []
	for a in r["apartments"]:
		var idx: int = a["index"]
		for m in a["routes"]:
			var route: Dictionary = a["routes"][m]
			var mid: Array = route["path"]
			if idx != i and m != i and not (i in mid):
				# a road on an equally short alternative route still connects the two
				mid = _alternative_path(cells, idx, m, i, route["length"]) if t["kind"] == TileDefs.Kind.ROAD else []
				if mid.is_empty():
					continue
			var path: Array = [idx]
			path.append_array(mid)
			path.append(m)
			var hot: bool = route["length"] >= Scoring.LONG_ROUTE and not route["shaded"]
			routes.append({"cells": path, "hot": hot})
			hl[idx] = UiKit.LIMESTONE
			hl[m] = UiKit.SKY
		if idx == i:
			for g in a["green_sources"]:
				hl[g] = UiKit.OLIVE
		elif i in a["green_sources"]:
			hl[idx] = UiKit.OLIVE
	_mark_green_reach(hl, cells, t, i)
	hl[i] = UiKit.GOLD
	view.set_highlights(hl)
	view.set_routes(routes)


## Road cells of a shortest route (`length` roads) from `home` to `service` that runs through road
## `via`, or [] if there is none.
static func _alternative_path(cells: Array, home: int, service: int, via: int, length: int) -> Array:
	var from_home := _road_bfs(cells, home)
	var from_service := _road_bfs(cells, service)
	if not from_home["dist"].has(via) or not from_service["dist"].has(via):
		return []
	if from_home["dist"][via] + from_service["dist"][via] - 1 != length:
		return []
	var path: Array = []
	var step: int = via
	while step != -1:
		path.push_front(step)
		step = from_home["parent"][step]
	step = from_service["parent"][via]
	while step != -1:
		path.append(step)
		step = from_service["parent"][step]
	return path


## Road distances (1 = next to `start`) and the step back towards `start` for every road reachable from it.
static func _road_bfs(cells: Array, start: int) -> Dictionary:
	var dist := {}
	var parent := {}
	var queue: Array[int] = []
	for n in Scoring.neighbours(start):
		if Scoring.kind_at(cells, n) == TileDefs.Kind.ROAD:
			dist[n] = 1
			parent[n] = -1
			queue.append(n)
	var head := 0
	while head < queue.size():
		var r := queue[head]
		head += 1
		for n in Scoring.neighbours(r):
			if Scoring.kind_at(cells, n) == TileDefs.Kind.ROAD and not dist.has(n):
				dist[n] = dist[r] + 1
				parent[n] = r
				queue.append(n)
	return {"dist": dist, "parent": parent}


## A park lights its 3x3 area, trees their four neighbours.
static func _mark_green_reach(hl: Dictionary, cells: Array, tile: Dictionary, i: int) -> void:
	var faint := Color(UiKit.OLIVE, 0.7)
	if tile["kind"] == TileDefs.Kind.PARK:
		for c in cells.size():
			if Scoring.in_park_area(i, c) and not hl.has(c):
				hl[c] = faint
	elif TileDefs.is_tree_like(tile):
		for c in Scoring.neighbours(i):
			if not hl.has(c):
				hl[c] = faint
