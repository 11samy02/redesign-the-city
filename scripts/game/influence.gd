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
			var involved: bool = idx == i or m == i or i in route["path"]
			if not involved:
				continue
			var path: Array = [idx]
			path.append_array(route["path"])
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
	_mark_green_reach(hl, cells, t["kind"], i)
	hl[i] = UiKit.GOLD
	view.set_highlights(hl)
	view.set_routes(routes)


## A park lights its 3x3 area, trees their four neighbours.
static func _mark_green_reach(hl: Dictionary, cells: Array, kind: int, i: int) -> void:
	var faint := Color(UiKit.OLIVE, 0.7)
	if kind == TileDefs.Kind.PARK:
		for c in cells.size():
			if Scoring.in_park_area(i, c) and not hl.has(c):
				hl[c] = faint
	elif kind == TileDefs.Kind.TREES:
		for c in Scoring.neighbours(i):
			if not hl.has(c):
				hl[c] = faint
