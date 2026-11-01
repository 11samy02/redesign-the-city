extends RefCounted
## Small drawing helpers for custom card frames: rounded outlines and filled polygons with
## per-vertex colours, drawn straight onto a canvas item (used by StyleBox subclasses).


## Outline of a rounded rectangle, clockwise from the top-left corner.
static func rounded(rect: Rect2, radius: float, segments := 8) -> PackedVector2Array:
	var r := minf(radius, minf(rect.size.x, rect.size.y) / 2.0)
	var pts := PackedVector2Array()
	var corners := [
		[rect.position + Vector2(r, r), PI],
		[rect.position + Vector2(rect.size.x - r, r), PI * 1.5],
		[rect.position + rect.size - Vector2(r, r), 0.0],
		[rect.position + Vector2(r, rect.size.y - r), PI * 0.5],
	]
	for c in corners:
		for s in segments + 1:
			var a: float = c[1] + (PI * 0.5) * float(s) / float(segments)
			pts.append(c[0] + Vector2(cos(a), sin(a)) * r)
	return pts


## One colour per vertex, blending from `top` to `bottom` by height inside `rect`.
static func vertical_colors(pts: PackedVector2Array, rect: Rect2, top: Color, bottom: Color) -> PackedColorArray:
	var out := PackedColorArray()
	for p in pts:
		out.append(top.lerp(bottom, clampf((p.y - rect.position.y) / maxf(rect.size.y, 1.0), 0.0, 1.0)))
	return out


static func fill(ci: RID, pts: PackedVector2Array, color: Color) -> void:
	var colors := PackedColorArray()
	for p in pts:
		colors.append(color)
	RenderingServer.canvas_item_add_polygon(ci, pts, colors)


static func fill_colors(ci: RID, pts: PackedVector2Array, colors: PackedColorArray) -> void:
	RenderingServer.canvas_item_add_polygon(ci, pts, colors)


## Line through `pts`; `close` joins the last point back to the first.
static func line(ci: RID, pts: PackedVector2Array, color: Color, width: float, close := false) -> void:
	var p := pts.duplicate()
	if close and pts.size() > 0:
		p.append(pts[0])
	var colors := PackedColorArray()
	for i in p.size():
		colors.append(color)
	RenderingServer.canvas_item_add_polyline(ci, p, colors, width, true)
