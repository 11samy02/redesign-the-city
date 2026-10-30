extends RefCounted
## Builds the plain-language status lines shown in tile tooltips.

const TileDefs = preload("res://scripts/core/tile_defs.gd")
const Scoring = preload("res://scripts/core/scoring.gd")

## Complaint types (concept doc: Approved additions 1) with what they mean and the fix.
const COMPLAINTS := {
	"Accessibility": {
		"icon": "res://assets/ui/route.svg",
		"meaning": "Cannot reach any amenity by road.",
		"fix": "Link homes to amenities by road, and reach every amenity",
	},
	"Walkability": {
		"icon": "res://assets/ui/walk.svg",
		"meaning": "A walk of 2+ roads with no shade.",
		"fix": "Shade long walks with trees or a park, or shorten them",
	},
	"Greenery": {
		"icon": "res://assets/ui/sprout.svg",
		"meaning": "No park or trees next to home.",
		"fix": "Put a park near a home, or trees right next to it",
	},
	"Pollution": {
		"icon": "res://assets/ui/pollution.svg",
		"meaning": "Pollution of 6 or more lowers happiness.",
		"fix": "Add parks (-3) and trees (-1) to get pollution below 6",
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


static func effect_text(tile: Dictionary) -> String:
	var kind: int = tile["kind"]
	if TileDefs.is_apartment(kind):
		var n := TileDefs.citizens(kind)
		return "Houses %d citizen%s. Each scores its happiness (-3 to +3) as points." % [n, "" if n == 1 else "s"]
	if tile.get("free", false):
		return "One of your 2 free roads. " + TileDefs.info(kind)["effect"]
	return TileDefs.info(kind)["effect"]


static func shop_lines(tile: Dictionary, money: int, buys_left: int) -> Array[String]:
	var cost := TileDefs.cost(tile["kind"])
	if buys_left <= 0:
		return [_c(NOTE, "You have bought your 2 tiles this round.")]
	if money >= cost:
		return [_c(GOOD, "Click to pick it up, then choose a lot.")]
	return [_c(BAD, "You need %d more gold." % (cost - money))]


static func cell_lines(cells: Array, result: Dictionary, i: int) -> Array[String]:
	var lines: Array[String] = []
	var t = cells[i]
	if t == null:
		lines.append("Empty lot.")
		return lines
	var kind: int = t["kind"]
	if TileDefs.is_apartment(kind):
		for a in result["apartments"]:
			if a["index"] == i:
				return _apartment_lines(cells, result, a)
	match kind:
		TileDefs.Kind.AMENITY:
			var homes := 0
			var people := 0
			for a in result["apartments"]:
				if a["routes"].has(i):
					homes += 1
					people += a["citizens"]
			if homes == 0:
				lines.append(_c(BAD, "No homes reach it by road yet."))
				lines.append("Link it to apartments with road tiles, or it costs 1 point at the end.")
			else:
				lines.append(_c(GOOD, "Serves %d citizen%s in %d home%s." % [people, "" if people == 1 else "s", homes, "" if homes == 1 else "s"]))
		TileDefs.Kind.PARK, TileDefs.Kind.TREES:
			var homes := 0
			for a in result["apartments"]:
				if i in a["green_sources"]:
					homes += 1
			var shades := 0
			for n in Scoring.neighbours(i):
				if cells[n] != null and cells[n]["kind"] == TileDefs.Kind.ROAD:
					shades += 1
			lines.append(_c(GOOD, "Pollution %d on this mat (now %d)." % [-3 if kind == TileDefs.Kind.PARK else -1, result["pollution"]]))
			var area := "in its 3x3 area" if kind == TileDefs.Kind.PARK else "next to it"
			lines.append(("Cheers up %d home%s %s." % [homes, "" if homes == 1 else "s", area]) if homes > 0 else _c(NOTE, "No homes %s yet." % area))
			if shades > 0:
				lines.append("Shades %d road%s." % [shades, "" if shades == 1 else "s"])
		TileDefs.Kind.ROAD:
			if result["shaded"][i]:
				lines.append(_c(GOOD, "Shaded by greenery: long walks here stay cool."))
			else:
				lines.append(_c(NOTE, "Not shaded. Trees or a park next to it give shade."))
			var uses := 0
			for a in result["apartments"]:
				for m in a["routes"]:
					if i in a["routes"][m]["path"]:
						uses += 1
			lines.append(("Part of %d citizen route%s." % [uses, "" if uses == 1 else "s"]) if uses > 0 else _c(NOTE, "Not part of a route yet."))
	return lines


static func _apartment_lines(cells: Array, result: Dictionary, a: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var n: int = a["citizens"]
	for m in a["routes"]:
		var r: Dictionary = a["routes"][m]
		var how := "%d road%s" % [r["length"], "" if r["length"] == 1 else "s"]
		if r["length"] >= Scoring.LONG_ROUTE:
			how += ", shaded" if r["shaded"] else ", no shade"
		lines.append("%s %s (%s)" % [_c(GOOD, "+1"), TileDefs.display_name(cells[m]), how])
	if a["routes"].is_empty():
		lines.append("%s No amenity reachable by road" % _c(NOTE, "+0"))
	for g in a["green_sources"]:
		lines.append("%s %s nearby" % [_c(GOOD, "+1"), TileDefs.display_name(cells[g])])
	if a["green_sources"].is_empty():
		lines.append("%s No park or trees nearby" % _c(NOTE, "+0"))
	if a["heat"] > 0:
		lines.append("%s Heat: a walk of 2+ roads with no shade" % _c(BAD, "-1"))
	if a["pollution"] > 0:
		lines.append("%s Pollution is %d" % [_c(BAD, "-%d" % a["pollution"]), result["pollution"]])
	else:
		lines.append(_c(NOTE, "Pollution %d has no effect" % result["pollution"]))
	if a["raw"] != a["happiness"]:
		lines.append(_c(NOTE, "Capped at %s (happiness runs -3 to +3)" % signed(a["happiness"])))
	lines.append("[b]%d citizen%s x %s = %s[/b]" % [n, "" if n == 1 else "s", signed(a["happiness"]), points(a["sp"])])
	if a["complaint"] != "":
		lines.append(_c(BAD, "%d %s complaint%s" % [n, a["complaint"], "" if n == 1 else "s"]))
	return lines
