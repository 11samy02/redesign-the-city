extends RefCounted
## The pollution bars for the real board game, one A4 page of pieces to cut out and nothing else: four identical
## bars, one for each of the (at most) four players (green 0 on the left, red 16 on the right), and a chip in each of
## the first four player colours to mark the level.
##
## A bar reads like a tile shelf. The ribbon on top says what each colour costs every citizen as a face and a number
## (smiling 0, frowning -1, sad -2); under it sit 17 numbered squares, one for each pollution level, where a chip
## stands. Everyone starts on 16 at the right end and slides left as parks, trees and shaded streets clean the air
## (see Scoring.pollution_penalty). The bars share one navy frame like the game's own panels, so the chips alone
## carry the player colours.

const C = preload("res://scripts/ui/print_canvas.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const GameRules = preload("res://scripts/core/game_state.gd")
const Scoring = preload("res://scripts/core/scoring.gd")

const PAGE := Vector2(2480, 3508)
const CELL := 134.0
## The squares are as big as the cell allows, so a chip (CHIP) sits on one with room to spare.
const TILE := 128.0
const RIBBON_H := 118.0
const PAD := 18.0
const CHIP := 108.0

const NAVY := Color("#10283A")
const NAVY_HI := Color("#1C405A")
const LIMESTONE := Color("#EFE6D2")
const GREEN := Color("#8DBB3C")
const GOLD := Color("#F2B630")
const RED := Color("#E0533A")
const CUT := Color("#9AA5AE")


## The whole page as one control.
static func build() -> Control:
	var root := Control.new()
	root.size = PAGE
	root.custom_minimum_size = PAGE
	C.box(root, Rect2(Vector2.ZERO, PAGE), Color.WHITE)
	var levels := Scoring.START_POLLUTION + 1
	var strip := Vector2(levels * CELL + 2.0 * PAD, RIBBON_H + CELL + 2.0 * PAD + 10.0)
	# a bar and a chip for each of the (at most) four players, in the first four player colours
	var colours := GameRules.MAX_PLAYERS
	var pitch := strip.y + 96.0
	var chip_pitch := 190.0
	# bars on top, chips under them, the whole block centred on the page
	var block := colours * pitch + 40.0 + chip_pitch
	var y := (PAGE.y - block) / 2.0
	var x := (PAGE.x - strip.x) / 2.0
	for i in colours:
		_bar(root, Vector2(x, y + i * pitch), strip)
	var chips_y := y + colours * pitch + 40.0
	# one chip for each player colour
	for i in colours:
		var cx := x + strip.x * (i + 0.5) / colours
		_chip(root, Vector2(cx, chips_y + chip_pitch * 0.5 - 30.0), UiKit.PLAYER_COLORS[i])
	return root


## One bar. Every bar looks the same.
static func _bar(root: Control, at: Vector2, strip: Vector2) -> void:
	_cut_outline(root, Rect2(at - Vector2(18, 18), strip + Vector2(36, 36)), 54)
	C.box(root, Rect2(at, strip), NAVY, 40)
	C.box(root, Rect2(at + Vector2(7, 7), strip - Vector2(14, 14)), Color.TRANSPARENT, 34, 2, Color(LIMESTONE, 0.35))
	var inner := at + Vector2(PAD, PAD)
	var levels := Scoring.START_POLLUTION + 1
	# the ribbon: one panel for every colour zone, with its face and number
	var zones := [
		[0, 7, GREEN, 0],
		[8, 12, GOLD, 1],
		[13, Scoring.START_POLLUTION, RED, 2],
	]
	for z in zones:
		var x0: float = inner.x + int(z[0]) * CELL
		var w: float = (int(z[1]) - int(z[0]) + 1) * CELL
		var panel := Rect2(x0 + 4.0, inner.y, w - 8.0, RIBBON_H - 10.0)
		C.box(root, panel, z[2], 24)
		var badge := _ZoneBadge.new()
		badge.tint = z[2]
		badge.cost = z[3]
		badge.size = Vector2(290, 92)
		badge.position = panel.get_center() - badge.size / 2.0
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(badge)
	# the squares: a chip stands on each one
	for k in levels:
		var r := Rect2(inner.x + k * CELL + (CELL - TILE) / 2.0, inner.y + RIBBON_H + 6.0 + (CELL - TILE) / 2.0, TILE, TILE)
		var tint := _zone_color(k)
		C.box(root, Rect2(r.position + Vector2(0, 7), r.size), tint.darkened(0.3), 26)
		C.box(root, r, tint, 26)
		C.box(root, Rect2(r.position + Vector2(10, 8), Vector2(r.size.x - 20, 14)), Color(1, 1, 1, 0.22), 7)
		C.text(root, str(k), r.position + Vector2(0, 4), 62, NAVY, "display_bold", TILE, HORIZONTAL_ALIGNMENT_CENTER, TILE)


static func _zone_color(level: int) -> Color:
	var penalty := Scoring.pollution_penalty(level)
	return RED if penalty >= 2 else (GOLD if penalty == 1 else GREEN)


## A thin dashed line round a piece, to cut along.
static func _cut_outline(root: Control, rect: Rect2, radius: int) -> void:
	var o := _Dashed.new()
	o.rect = rect
	o.radius = radius
	o.size = PAGE
	o.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(o)


static func _chip(root: Control, centre: Vector2, color: Color) -> void:
	var c := _Chip.new()
	c.color = color
	c.position = centre - Vector2(CHIP, CHIP) / 2.0 - Vector2(24, 24)
	c.size = Vector2(CHIP + 48, CHIP + 48)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(c)


## A navy capsule with a face in the colour of the zone and what the zone costs every citizen: 0, -1 or -2.
class _ZoneBadge extends Control:
	var tint := Color.WHITE
	var cost := 0

	func _draw() -> void:
		var UiKitC = preload("res://scripts/ui/ui_kit.gd")
		draw_style_box(UiKitC.box(Color("#10283A"), int(size.y / 2.0), 4, Color("#EFE6D2")), Rect2(Vector2.ZERO, size))
		# the face
		var r := size.y * 0.36
		var c := Vector2(size.y * 0.55, size.y / 2.0)
		draw_circle(c, r, tint)
		draw_circle(c + Vector2(-r * 0.36, -r * 0.22), r * 0.13, Color("#10283A"))
		draw_circle(c + Vector2(r * 0.36, -r * 0.22), r * 0.13, Color("#10283A"))
		var w := maxf(3.0, r * 0.16)
		if cost == 0:
			draw_arc(c + Vector2(0, r * 0.05), r * 0.52, 0.35, PI - 0.35, 14, Color("#10283A"), w, true)
		elif cost == 1:
			draw_arc(c + Vector2(0, r * 0.9), r * 0.5, PI + 0.55, TAU - 0.55, 14, Color("#10283A"), w, true)
		else:
			draw_arc(c + Vector2(0, r * 0.9), r * 0.5, PI + 0.55, TAU - 0.55, 14, Color("#10283A"), w, true)
			# a second frown line and a tear: sadder still
			draw_circle(c + Vector2(r * 0.62, r * 0.12), r * 0.12, Color("#9FD0F5"))
		# the number
		var text := "0" if cost == 0 else "−%d" % cost
		var f := UiKitC.font("display_bold")
		var fs := int(size.y * 0.58)
		var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, Vector2(c.x + r + (size.x - c.x - r - tw) / 2.0, size.y / 2.0 + fs * 0.34), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("#EFE6D2"))


## A dashed rounded rectangle (the cut line round a bar).
class _Dashed extends Control:
	var rect := Rect2()
	var radius := 40

	func _draw() -> void:
		var pts := PackedVector2Array()
		var r := float(radius)
		var corners := [
			[rect.position + Vector2(r, r), PI, 1.5 * PI],
			[Vector2(rect.end.x - r, rect.position.y + r), 1.5 * PI, TAU],
			[rect.end - Vector2(r, r), 0.0, 0.5 * PI],
			[Vector2(rect.position.x + r, rect.end.y - r), 0.5 * PI, PI],
		]
		for c in corners:
			for s in 13:
				var a: float = lerpf(c[1], c[2], s / 12.0)
				pts.append(c[0] + Vector2(cos(a), sin(a)) * r)
		pts.append(pts[0])
		var total := 0.0
		for k in range(1, pts.size()):
			var seg := pts[k - 1].distance_to(pts[k])
			var d := 0.0
			while d < seg:
				var a := pts[k - 1].lerp(pts[k], d / seg)
				var b := pts[k - 1].lerp(pts[k], minf(d + 16.0, seg) / seg)
				if fmod(total + d, 32.0) < 16.0:
					draw_line(a, b, Color("#9AA5AE"), 2.5, true)
				d += 16.0
			total += seg


## A chip: a disc in the player colour with a darker rim and a soft highlight, inside a dotted ring to cut along.
class _Chip extends Control:
	var color := Color.WHITE

	func _draw() -> void:
		var c := size / 2.0
		var r := 56.0
		for k in 72:
			if k % 2 == 0:
				var a := TAU * k / 72.0
				draw_arc(c, r + 18.0, a, a + TAU / 72.0, 4, Color("#9AA5AE"), 2.5, true)
		draw_circle(c, r, color.darkened(0.22))
		draw_circle(c, r - 7.0, color)
		draw_circle(c + Vector2(-r * 0.22, -r * 0.26), r * 0.34, Color(1, 1, 1, 0.22))
