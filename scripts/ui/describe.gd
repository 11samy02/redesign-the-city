extends RefCounted
## Builds the plain-language status lines shown in tile tooltips: who lives in a home, what each
## citizen needs, what they have and what is missing.

const TileDefs = preload("res://scripts/core/tile_defs.gd")
const Roles = preload("res://scripts/core/roles.gd")
const Scoring = preload("res://scripts/core/scoring.gd")
const CircumstanceDefs = preload("res://scripts/core/circumstance_defs.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const Grid = preload("res://scripts/core/grid.gd")

## Complaint types with what they mean and the fix. An unhappy citizen's own words (for example
## "No library within reach") come with the complaint as its detail.
const COMPLAINTS := {
	"Accessibility": {
		"icon": "res://assets/ui/route.svg",
		"meaning": "Cannot reach something they need by road.",
		"fix": "Link homes by road to the places their citizens need",
	},
	"Walkability": {
		"icon": "res://assets/ui/walk.svg",
		"meaning": "A long walk (6+ road squares) with no shade.",
		"fix": "Shade long walks with trees or a park, or shorten them",
	},
	"Greenery": {
		"icon": "res://assets/ui/sprout.svg",
		"meaning": "No park or trees next to home.",
		"fix": "Put a park near a home, or trees right next to it",
	},
	"Pollution": {
		"icon": "res://assets/ui/pollution.svg",
		"meaning": "Pollution of 8 or more lowers happiness.",
		"fix": "Add parks (-3) and trees (-1) to get pollution below 8",
	},
}

const GOOD := "#8DBB3C"
const BAD := "#E0533A"
const NOTE := "#9FB3C2"


static func signed(n: int) -> String:
	return "+%d" % n if n > 0 else str(n)


static func points(n: int) -> String:
	return "%s point%s" % [signed(n), "" if absi(n) == 1 else "s"]


static func _c(color: String, text: String) -> String:
	return "[color=%s]%s[/color]" % [color, text]


static func _plural(n: int, word: String) -> String:
	return "%d %s%s" % [n, word, "" if n == 1 else "s"]


static func _role_name(role: String, count := 1) -> String:
	var d: Dictionary = Roles.DEFS[role]
	return d["name"] if count == 1 else "%d %s" % [count, d["plural"]]


static func _role_tag(role: String, count := 1) -> String:
	return "[color=%s][b]%s[/b][/color]" % [Roles.DEFS[role]["color"], _role_name(role, count)]


## "a University and a Library" / "a Park".
static func _need_list(role: String) -> String:
	var names: Array[String] = []
	for n in Roles.DEFS[role]["needs"]:
		names.append("a " + Roles.NEEDS[n]["name"])
	return " and ".join(names)


static func _like_list(role: String) -> String:
	var d: Dictionary = Roles.DEFS[role]
	var names: Array[String] = []
	for k in d["like_kinds"]:
		names.append(TileDefs.DEFS[k]["name"].to_lower())
	for s in d["like_streets"]:
		names.append(TileDefs.STREETS[s]["name"].to_lower())
	return ", ".join(names)


static func effect_text(tile: Dictionary) -> String:
	var kind: int = tile["kind"]
	if TileDefs.is_home(kind):
		var n := TileDefs.citizens(kind)
		return "Houses %d citizen%s. Each one scores their happiness (-5 to +5) as points." % [n, "" if n == 1 else "s"]
	if tile.get("free", false):
		return "One of your %d free roads. " % GameState.FREE_ROADS + TileDefs.info(kind)["effect"]
	if TileDefs.is_special_street(tile):
		return TileDefs.STREETS[tile["variant"]]["effect"]
	return TileDefs.info(kind)["effect"]


## Who lives in a home tile and what each kind of citizen needs: one short line per role.
static func household_lines(tile: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	if not TileDefs.is_home(tile["kind"]):
		return lines
	var counts := {}
	var order: Array[String] = []
	for role in TileDefs.members(tile):
		if not counts.has(role):
			order.append(role)
		counts[role] = counts.get(role, 0) + 1
	for role in order:
		lines.append("%s  needs %s" % [_role_tag(role, counts[role]), _need_list(role)])
	return lines


static func shop_lines(tile: Dictionary, money: int, buys_left: int) -> Array[String]:
	var lines: Array[String] = household_lines(tile)
	var cost := TileDefs.tile_cost(tile)
	if buys_left <= 0:
		lines.append(_c(NOTE, "You have bought your %d tiles this round." % GameState.BUYS_PER_TURN))
	elif money >= cost:
		lines.append(_c(GOOD, "Click to pick it up, then choose a lot."))
	else:
		lines.append(_c(BAD, "You need %d more gold." % (cost - money)))
	return lines


## "Size 2:2: covers 4 squares (2 x 2) of your mat." / "Size 1:1: covers 1 square, half the width of a 2:2 tile."
static func size_text(tile: Dictionary) -> String:
	if TileDefs.footprint(tile) == 1:
		return "Size 1:1: covers 1 square, half the width of a 2:2 tile."
	return "Size 2:2: covers 4 squares (2 x 2) of your mat."


## Tooltip lines for the tile on square `square` (any square of it).
static func cell_lines(cells: Array, result: Dictionary, square: int) -> Array[String]:
	var lines: Array[String] = []
	var i := Grid.anchor_of(cells, square)
	if i < 0:
		lines.append("Empty lot.")
		return lines
	var t: Dictionary = cells[i]
	var kind: int = t["kind"]
	if t.get("fixed", false) and not TileDefs.is_home(kind):
		lines.append(_c(NOTE, "Came with the mat: it cannot be replaced or lost."))
	if TileDefs.is_home(kind):
		for a in result["apartments"]:
			if a["index"] == i:
				return _home_lines(cells, result, a)
	if TileDefs.is_service(kind):
		_service_lines(lines, cells, result, i)
		return lines
	match kind:
		TileDefs.Kind.PARK, TileDefs.Kind.TREES:
			var homes := 0
			for a in result["apartments"]:
				if i in a["green_sources"]:
					homes += 1
			var shaded_roads := {}
			for n in Grid.border(i, TileDefs.footprint(t)):
				if cells[n] != null and cells[n]["kind"] == TileDefs.Kind.ROAD:
					shaded_roads[Grid.anchor_of(cells, n)] = true
			var shades := shaded_roads.size()
			lines.append(_c(GOOD, "Pollution %d on this mat (now %d)." % [-3 if kind == TileDefs.Kind.PARK else -1, result["pollution"]]))
			var area := "within 2 squares of it" if kind == TileDefs.Kind.PARK else "next to it"
			lines.append(("Cheers up %s %s." % [_plural(homes, "home"), area]) if homes > 0 else _c(NOTE, "No homes %s yet." % area))
			if kind == TileDefs.Kind.PARK:
				var kids := _citizens_who(result, func(a, m): return i in a["green_sources"] and m["role"] == Roles.CHILD)
				if kids > 0:
					lines.append("Meets the park need of %s." % _plural(kids, "child").replace("childs", "children"))
			if shades > 0:
				lines.append("Shades %s." % _plural(shades, "road"))
		TileDefs.Kind.ROAD:
			if TileDefs.is_tree_like(t):
				var homes := 0
				for a in result["apartments"]:
					if i in a["green_sources"]:
						homes += 1
				lines.append(_c(GOOD, "Acts as trees: pollution -1 on this mat (now %d)." % result["pollution"]))
				lines.append(("Cheers up %s next to it." % _plural(homes, "home")) if homes > 0 else _c(NOTE, "No homes next to it yet."))
			elif _any_shaded(result, cells, i):
				lines.append(_c(GOOD, "Shaded by greenery: long walks here stay cool."))
			else:
				lines.append(_c(NOTE, "Not shaded. Trees or a park next to it give shade."))
			var uses := 0
			var squares := Grid.squares_of(cells, i)
			for a in result["apartments"]:
				for m in a["routes"]:
					for c in squares:
						if c in a["routes"][m]["path"]:
							uses += a["citizens"]
							break
			lines.append(("Part of the routes of %s." % _plural(uses, "citizen")) if uses > 0 else _c(NOTE, "Not part of a route yet."))
	return lines


## Counts the citizens for whom `test.call(home, member)` is true.
static func _citizens_who(result: Dictionary, test: Callable) -> int:
	var n := 0
	for a in result["apartments"]:
		for m in a["members"]:
			if test.call(a, m):
				n += 1
	return n


static func _any_shaded(result: Dictionary, cells: Array, anchor: int) -> bool:
	for c in Grid.squares_of(cells, anchor):
		if result["shaded"][c]:
			return true
	return false


static func _service_lines(lines: Array[String], cells: Array, result: Dictionary, i: int) -> void:
	var kind: int = cells[i]["kind"]
	var homes := 0
	var people := 0
	var needed := 0
	var liked := 0
	for a in result["apartments"]:
		if not a["routes"].has(i):
			continue
		homes += 1
		people += a["citizens"]
		for m in a["members"]:
			var def: Dictionary = Roles.DEFS[m["role"]]
			var is_need := false
			for n in def["needs"]:
				if kind in Roles.NEEDS[n]["kinds"]:
					is_need = true
			if is_need:
				needed += 1
			elif kind in def["like_kinds"]:
				liked += 1
	if homes == 0:
		lines.append(_c(BAD, "No homes reach it by road yet. It costs %s at the end." % _plural(Scoring.UNUSED_PENALTY, "point")))
	else:
		lines.append(_c(GOOD, "Reached by %s in %s." % [_plural(people, "citizen"), _plural(homes, "home")]))
		if needed > 0:
			lines.append("Needed by %s." % _plural(needed, "citizen"))
		if liked > 0:
			lines.append("Liked by %s." % _plural(liked, "citizen"))
		if needed == 0 and liked == 0:
			lines.append(_c(NOTE, "Nobody nearby needs or likes it."))
	var dislikers := 0
	var own := Grid.squares_of(cells, i)
	for a in result["apartments"]:
		var next_door := false
		for c in Grid.border(a["index"], TileDefs.footprint(cells[a["index"]])):
			next_door = next_door or c in own
		for m in a["members"]:
			if m["dislike"] and next_door:
				dislikers += 1
	if dislikers > 0:
		lines.append(_c(BAD, "%s dislike having it right next door." % _plural(dislikers, "citizen")))
	for id in result["bonus_sources"]:
		if i in result["bonus_sources"][id]:
			lines.append("%s Circumstance: %s" % [_c(GOOD, "+1 point"), CircumstanceDefs.title(id)])


static func _home_lines(cells: Array, result: Dictionary, a: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var shown: Array = []
	for m in a["members"]:
		var same := -1
		for k in shown.size():
			if _signature(shown[k]["m"]) == _signature(m):
				same = k
		if same >= 0:
			shown[same]["count"] += 1
		else:
			shown.append({"m": m, "count": 1})
	for entry in shown:
		_member_lines(lines, entry["m"], entry["count"])
	if a["pollution"] > 0:
		lines.append(_c(BAD, "Pollution: -%d for everyone here" % a["pollution"]))
	lines.append("[b]%s: %s[/b]" % [_plural(a["citizens"], "citizen"), points(a["sp"])])
	return lines


## Two citizens of one role that feel exactly the same share one block in the tooltip.
static func _signature(m: Dictionary) -> String:
	var met := []
	for n in m["needs"]:
		met.append(n["met"])
	return str([m["role"], m["happiness"], met, m["like"], m["dislike"], m["heat"], m["effects"]])


## "Student +3", then only what is missing or hurting.
static func _member_lines(lines: Array[String], m: Dictionary, count := 1) -> void:
	var h: int = m["happiness"]
	lines.append("%s  %s" % [_role_tag(m["role"], count), _c(GOOD if h > 0 else (BAD if h < 0 else NOTE), "%s each" % signed(h) if count > 1 else signed(h))])
	for n in m["needs"]:
		if not n["met"]:
			lines.append(_c(BAD, "   Missing: %s" % n["name"]))
	if m["dislike"]:
		lines.append(_c(BAD, "   Dislikes the %s next door" % TileDefs.DEFS[Roles.DEFS[m["role"]]["dislike_kind"]]["name"].to_lower()))
	if m["heat"] > 0:
		lines.append(_c(BAD, "   Long walk with no shade"))
	for id in m["effects"]:
		var d: int = m["effects"][id]
		lines.append(_c(GOOD if d > 0 else BAD, "   %s %s" % [CircumstanceDefs.title(id), signed(d)]))


static func _route_text(a: Dictionary, source: int, cells: Array) -> String:
	if not a["routes"].has(source):
		return ""
	var r: Dictionary = a["routes"][source]
	var how := "(%s" % _plural(r["length"], "road square")
	if r["length"] >= Scoring.LONG_ROUTE:
		how += ", shaded" if r["shaded"] else ", no shade"
	return how + ")"


static func _like_name(cells: Array, source: int) -> String:
	if source < 0 or cells[source] == null:
		return "something nearby"
	var t: Dictionary = cells[source]
	return "the " + TileDefs.display_name(t).to_lower()
