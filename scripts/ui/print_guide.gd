extends RefCounted
## The planner's guide for the real board game: one card per player (two fit on an A4 page). The table lists,
## for every kind of citizen, what they need, like and dislike, with the buildings that give the points; the
## panels under it say how to count a citizen's happiness and the city's score. All numbers come from the rules
## (roles.gd, scoring.gd), so the card never drifts from the game.
##
## Laid out on a plain grid with fixed cells so nothing can overlap: short labels, one idea per cell.

const C = preload("res://scripts/ui/print_canvas.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const TileDefs = preload("res://scripts/core/tile_defs.gd")
const Roles = preload("res://scripts/core/roles.gd")
const Scoring = preload("res://scripts/core/scoring.gd")
const PrintBadge = preload("res://scripts/ui/print_badge.gd")

const WIDTH := 2380.0
const HEIGHT := 1690.0
const K := TileDefs.Kind

## Short names under the pictures.
const SHORT := {
	K.COMMERCIAL: "Commercial", K.UNIVERSITY: "University", K.LIBRARY: "Library", K.BOOKSHOP: "Bookshop",
	K.PRINT_SHOP: "Print shop", K.COFFEE_SHOP: "Coffee shop", K.KIOSK: "Kiosk", K.RESTAURANT: "Restaurant",
	K.SUPERMARKET: "Supermarket", K.MARKET: "Market", K.HOSPITAL: "Hospital", K.CLINIC: "Clinic",
	K.SCHOOL: "School", K.PARKING: "Parking", K.PARK: "Park",
}
const STREET_SHORT := {TileDefs.STREET_SHADED: "Shaded", TileDefs.STREET_PEDESTRIAN: "Pedestrian", TileDefs.STREET_BIKE: "Bike lane"}

const LEFT := 56.0
const ROW_W := 2268.0
const COL_NAME := 70.0
const COL_NEEDS := 420.0
const COL_LIKES := 1060.0
const COL_DISLIKE := 1860.0
const COL_HEAT := 2090.0
const THUMB := 96.0
const ROW_H := 160.0
const ROW_GAP := 8.0
const TABLE_Y := 178.0
const PANEL_Y := 1208.0


## The whole card as one control, WIDTH x HEIGHT pixels.
static func build() -> Control:
	var root := Control.new()
	root.size = Vector2(WIDTH, HEIGHT)
	root.custom_minimum_size = root.size
	C.box(root, Rect2(Vector2.ZERO, root.size), C.PAPER)
	C.box(root, Rect2(10, 10, WIDTH - 20, HEIGHT - 20), Color.TRANSPARENT, 34, 6, C.INK)
	_header(root)
	_table(root)
	_steps_panel(root)
	_city_panel(root)
	return root


# ================================================================ header

static func _header(root: Control) -> void:
	C.text(root, "Planner's guide", Vector2(LEFT, 40), 78, C.INK)
	# the three kinds of points, as they are on the tiles
	var x := 1330.0
	for item in [["need", 2, "a need met"], ["like", 1, "a like"], ["dislike", -1, "a dislike"]]:
		C.pill(root, PrintBadge.signed(item[1]), PrintBadge.pill_color(item[0]), x + 55, 58, 110, 60)
		C.text(root, item[2], Vector2(x + 128, 58), 32, C.INK, "body_bold", 0.0, HORIZONTAL_ALIGNMENT_LEFT, 60)
		x += 350.0


# ================================================================ the citizen table

static func _table(root: Control) -> void:
	for h in [[COL_NAME, "Citizen"], [COL_NEEDS, "Needs"], [COL_LIKES, "Likes"], [COL_DISLIKE, "Dislike"], [COL_HEAT, "Hot walk"]]:
		C.text(root, h[1], Vector2(h[0], TABLE_Y - 46), 28, C.MUTED, "display_bold")
	for i in Roles.IDS.size():
		_row(root, Roles.IDS[i], TABLE_Y + i * (ROW_H + ROW_GAP))


static func _row(root: Control, role: String, y: float) -> void:
	var def: Dictionary = Roles.DEFS[role]
	var color := Color(def["color"])
	C.box(root, Rect2(LEFT - 14, y, ROW_W, ROW_H), Color(color, 0.1), 24)
	C.box(root, Rect2(LEFT - 14, y, 12, ROW_H), color, 6)
	# who
	C.badge(root, {"role": role, "value": 0, "type": "resident"}, Vector2(COL_NAME - 4, y + (ROW_H - 100) / 2.0), 100)
	C.text(root, def["name"], Vector2(COL_NAME + 116, y), 28, C.INK, "display_bold", 190, HORIZONTAL_ALIGNMENT_LEFT, ROW_H)
	# needs
	var x := COL_NEEDS
	for need_id in def["needs"]:
		var nd: Dictionary = Roles.NEEDS[need_id]
		for kind in nd["kinds"]:
			var value := 2
			if not nd["area"] and kind in Scoring.PREMIUM_KINDS:
				value += Scoring.PREMIUM_BONUS
			C.thumb(root, TileDefs.make(kind), Vector2(x, y + 10), THUMB, value, "need", SHORT[kind])
			x += 140.0
		x += 16.0
	# likes
	x = COL_LIKES
	for kind in def["like_kinds"]:
		C.thumb(root, TileDefs.make(kind), Vector2(x, y + 10), THUMB, 1, "like", SHORT[kind])
		x += 140.0
	for street in def["like_streets"]:
		C.thumb(root, TileDefs.make(K.ROAD, street), Vector2(x, y + 10), THUMB, 1, "like", STREET_SHORT[street])
		x += 140.0
	# dislike
	if def["dislike_kind"] >= 0:
		C.thumb(root, TileDefs.make(def["dislike_kind"]), Vector2(COL_DISLIKE, y + 10), THUMB, -1, "dislike", SHORT[def["dislike_kind"]])
	else:
		C.text(root, "none", Vector2(COL_DISLIKE, y), 28, C.MUTED, "body_bold", THUMB, HORIZONTAL_ALIGNMENT_CENTER, ROW_H)
	# a long walk without shade
	C.picture(root, "res://assets/ui/sun.svg", Rect2(COL_HEAT + 8, y + 10, THUMB, THUMB))
	C.pill(root, PrintBadge.signed(-int(def["heat_factor"])), PrintBadge.DISLIKE, COL_HEAT + 8 + THUMB / 2.0, y + 10 + THUMB - 20, THUMB * 0.78, THUMB * 0.4)


# ================================================================ how to count

static func _panel(root: Control, rect: Rect2, title: String) -> void:
	C.box(root, rect, Color("#F5EEDB"), 28, 3, C.LINE)
	C.text(root, title, rect.position + Vector2(32, 14), 38, C.INK)


## Eight steps, two rows of four: a small picture on the left and one short line of words.
static func _steps_panel(root: Control) -> void:
	var rect := Rect2(LEFT - 14, PANEL_Y, 1580, HEIGHT - PANEL_Y - 36)
	_panel(root, rect, "Count a citizen")
	var steps := [
		["start", "Every citizen starts at −2."],
		["need", "Each need a road reaches. Hospital, supermarket: +3."],
		["like", "A like within reach, counted once."],
		["green", "A park near, or trees beside, the home. At most +2."],
		["heat", "A hot walk: %d+ road squares, no shade. Older, disability: −2." % Scoring.LONG_ROUTE],
		["dislike", "A disliked building right next to the home."],
		["air", "The pollution penalty on your bar, for everyone."],
		["cap", "Every citizen ends between −5 and +5."],
	]
	var col_w := (rect.size.x - 40.0) / 4.0
	for k in steps.size():
		var at := rect.position + Vector2(24 + (k % 4) * col_w, 92 + (k / 4) * 168)
		_step(root, steps[k], at, col_w)


static func _step(root: Control, step: Array, at: Vector2, w: float) -> void:
	var kind: String = step[0]
	var cx := at.x + 60.0
	var cy := at.y + 4.0
	match kind:
		"start":
			C.box(root, Rect2(cx - 50, cy + 14, 100, 56), C.INK, 28)
			C.text(root, "−2", Vector2(cx - 50, cy + 14), 36, Color.WHITE, "display_bold", 100, HORIZONTAL_ALIGNMENT_CENTER, 56)
		"need", "like", "dislike":
			var value := 2 if kind == "need" else (1 if kind == "like" else -1)
			C.pill(root, PrintBadge.signed(value), PrintBadge.pill_color(kind), cx, cy + 14, 100, 56)
		"green":
			C.picture(root, "res://assets/ui/leaf.svg", Rect2(cx - 52, cy + 12, 52, 52))
			C.pill(root, "+1", PrintBadge.LIKE, cx + 26, cy + 20, 70, 48)
		"heat":
			C.picture(root, "res://assets/ui/sun.svg", Rect2(cx - 52, cy + 12, 52, 52))
			C.pill(root, "−1", PrintBadge.DISLIKE, cx + 26, cy + 20, 70, 48)
		"air":
			C.picture(root, PrintBadge.cloud_texture(), Rect2(cx - 52, cy + 12, 54, 54))
			for z in 3:
				C.box(root, Rect2(cx + 12 + z * 22, cy + 26, 18, 28), [Color("#8DBB3C"), Color("#F2B630"), Color("#E0533A")][z], 5)
		"cap":
			C.picture(root, "res://assets/ui/smile_up.svg", Rect2(cx - 56, cy + 14, 50, 50))
			C.picture(root, "res://assets/ui/smile_down.svg", Rect2(cx + 4, cy + 14, 50, 50))
	C.text(root, step[1], Vector2(at.x + 130, at.y), 25, C.INK, "body_bold", w - 150.0, HORIZONTAL_ALIGNMENT_LEFT)


# ================================================================ the city's score

static func _city_panel(root: Control) -> void:
	var rect := Rect2(LEFT - 14 + 1580 + 24, PANEL_Y, ROW_W - 1580 - 24, HEIGHT - PANEL_Y - 36)
	_panel(root, rect, "Count your city")
	var x := rect.position.x + 32.0
	var w := rect.size.x - 64.0
	var y := rect.position.y + 70.0
	C.text(root, "Variety bonus: kinds of citizens at +1 or more", Vector2(x, y), 23, C.MUTED, "body_bold", w)
	var table: Array = Scoring.VARIETY_BONUS
	var cw := (w - 4.0 * 12.0) / 5.0
	for k in range(2, 7):
		var cx := x + (k - 2) * (cw + 12.0)
		C.box(root, Rect2(cx, y + 40, cw, 78), Color.WHITE, 16, 2, C.LINE)
		C.text(root, "%d kinds" % k, Vector2(cx, y + 44), 20, C.MUTED, "body_bold", cw, HORIZONTAL_ALIGNMENT_CENTER)
		C.text(root, "+%d" % table[k], Vector2(cx, y + 68), 38, PrintBadge.LIKE, "display_bold", cw, HORIZONTAL_ALIGNMENT_CENTER)
	var loans := "Loans: −%d, −%d, −%d, then −%d each." % [
		Scoring.LOAN_PENALTIES[0], Scoring.LOAN_PENALTIES[1], Scoring.LOAN_PENALTIES[2], Scoring.LOAN_PENALTIES[2] + Scoring.LOAN_STEP]
	var lines := [
		["−1", "for each service no home reaches."],
		["−", loans],
		["±", "Event and penalty cards."],
	]
	var ly := y + 138.0
	for line in lines:
		C.box(root, Rect2(x, ly, 76, 44), PrintBadge.DISLIKE if line[0] == "−1" else (C.INK if line[0] == "−" else PrintBadge.NEED), 22)
		C.text(root, line[0], Vector2(x, ly), 28, Color.WHITE, "display_bold", 76, HORIZONTAL_ALIGNMENT_CENTER, 44)
		C.text(root, line[1], Vector2(x + 96, ly), 24, C.INK, "body_bold", w - 96.0, HORIZONTAL_ALIGNMENT_LEFT, 44)
		ly += 50.0
