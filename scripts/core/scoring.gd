extends RefCounted
## Final-scoring rules for one 7x7 player mat. Happiness is worked out per citizen: every citizen
## has a role (roles.gd) with two needs, a few likes and a dislike. Green space, pollution and
## heat are shared by everyone in a home.

const TileDefs = preload("res://scripts/core/tile_defs.gd")
const Roles = preload("res://scripts/core/roles.gd")
const CircumstanceDefs = preload("res://scripts/core/circumstance_defs.gd")

const SIZE := 7
const START_POLLUTION := 16
## Loan n costs LOAN_PENALTIES[n - 1] points; every loan after the last listed one costs 2 more.
const LOAN_PENALTIES := [6, 9, 12]
const LOAN_STEP := 3
## A service no home can reach is wasted: buying it only to keep it from others must not pay off.
const UNUSED_PENALTY := 1
const HAPPY_MIN := -5
const HAPPY_MAX := 5
## A walk of this many roads or more is long: without shade it heats the citizen up.
const LONG_ROUTE := 3
## Most green sources that count for one citizen.
const GREEN_CAP := 2

## A mix of citizens is worth more, because every kind needs different services at the same time.
## A kind counts once at least one of its citizens is happy (a lone unserved resident earns nothing),
## and the city then earns VARIETY_BONUS[kinds counted]: each extra kind is worth a little more.
const VARIETY_BONUS := [0, 0, 3, 7, 12, 19, 27]
const VARIETY_HAPPY := 1

## The dearer twin of a service meets the same need as the cheap one and adds this much happiness
## for every need it meets (hospital over clinic, supermarket over market).
const PREMIUM_KINDS := [TileDefs.Kind.HOSPITAL, TileDefs.Kind.SUPERMARKET]
const PREMIUM_BONUS := 1

## Order also breaks ties when picking an unhappy citizen's complaint.
const COMPLAINT_TYPES := ["Accessibility", "Walkability", "Greenery", "Pollution"]


static func neighbours(i: int) -> Array[int]:
	var out: Array[int] = []
	var x := i % SIZE
	var y := i / SIZE
	if y > 0: out.append(i - SIZE)
	if x < SIZE - 1: out.append(i + 1)
	if y < SIZE - 1: out.append(i + SIZE)
	if x > 0: out.append(i - 1)
	return out


static func in_park_area(park: int, cell: int) -> bool:
	return park != cell and absi(park % SIZE - cell % SIZE) <= 1 and absi(park / SIZE - cell / SIZE) <= 1


static func kind_at(cells: Array, i: int) -> int:
	return -1 if cells[i] == null else cells[i]["kind"]


## Points lost for `loans` loans in total: 5, then 7, then 9, then 11, 13...
static func loan_penalty(loans: int) -> int:
	var total := 0
	for n in loans:
		total += LOAN_PENALTIES[n] if n < LOAN_PENALTIES.size() else LOAN_PENALTIES[-1] + LOAN_STEP * (n - LOAN_PENALTIES.size() + 1)
	return total


static func pollution_level(cells: Array) -> int:
	var level := START_POLLUTION
	for t in cells:
		if t == null:
			continue
		if t["kind"] == TileDefs.Kind.PARK:
			level -= 3
		elif TileDefs.is_tree_like(t):
			level -= 1
	return maxi(0, level)


static func pollution_penalty(level: int) -> int:
	if level >= 13:
		return 2
	if level >= 8:
		return 1
	return 0


static func shaded_roads(cells: Array) -> Array[bool]:
	var shaded: Array[bool] = []
	shaded.resize(cells.size())
	for i in cells.size():
		if kind_at(cells, i) != TileDefs.Kind.ROAD:
			continue
		# a shaded street has its own trees
		if TileDefs.is_tree_like(cells[i]):
			shaded[i] = true
		for n in neighbours(i):
			if kind_at(cells, n) == TileDefs.Kind.PARK or TileDefs.is_tree_like(cells[n]):
				shaded[i] = true
	return shaded


## Shortest road routes from a building to every service it can reach.
## Returns { service_index: {"length": int, "shaded": bool, "path": Array[int], "kind": int} }.
## Among equally short routes a shaded one is preferred.
static func routes_from(cells: Array, start: int, shaded: Array[bool]) -> Dictionary:
	var dist := {}
	var shade_ok := {}
	var parent := {}
	var queue: Array[int] = []
	for n in neighbours(start):
		if kind_at(cells, n) == TileDefs.Kind.ROAD:
			dist[n] = 1
			shade_ok[n] = shaded[n]
			parent[n] = -1
			queue.append(n)
	var head := 0
	while head < queue.size():
		var r := queue[head]
		head += 1
		for n in neighbours(r):
			if kind_at(cells, n) != TileDefs.Kind.ROAD:
				continue
			if not dist.has(n):
				dist[n] = dist[r] + 1
				shade_ok[n] = shaded[n] or shade_ok[r]
				parent[n] = r
				queue.append(n)
			elif dist[n] == dist[r] + 1 and shade_ok[r] and not shade_ok[n]:
				shade_ok[n] = true
				parent[n] = r

	var routes := {}
	for m in cells.size():
		var kind := kind_at(cells, m)
		if kind == -1 or not TileDefs.is_service(kind) or m == start:
			continue
		var best := -1
		for r in neighbours(m):
			if not dist.has(r):
				continue
			if best == -1 or dist[r] < dist[best] or (dist[r] == dist[best] and shade_ok[r] and not shade_ok[best]):
				best = r
		if best == -1:
			continue
		var path: Array[int] = []
		var step: int = best
		while step != -1:
			path.push_front(step)
			step = parent[step]
		routes[m] = {"length": dist[best], "shaded": shade_ok[best], "path": path, "kind": kind}
	return routes


## Weights of the four complaint types for one citizen; the heaviest wins, earlier types win ties.
static func _weights(unmet: int, walk: int, no_green: int, air: int) -> Array:
	return [unmet, walk, no_green, air]


static func _heaviest(weights: Array) -> int:
	var best := 0
	for i in weights.size():
		if weights[i] > weights[best]:
			best = i
	return best


## Everything one citizen feels in their home. `home` carries what the whole home shares.
static func _member(role: String, cells: Array, home: Dictionary, circumstances: Array) -> Dictionary:
	var def: Dictionary = Roles.DEFS[role]
	var routes: Dictionary = home["routes"]
	var needs: Array = []
	var met := 0
	var premium_bonus := 0
	var heat := 0
	var hot_route := -1
	for need_id in def["needs"]:
		var nd: Dictionary = Roles.NEEDS[need_id]
		var source := -1
		if nd["area"]:
			for g in cells.size():
				if kind_at(cells, g) in nd["kinds"] and in_park_area(g, home["index"]):
					source = g
					break
		else:
			for m in routes:
				if not (routes[m]["kind"] in nd["kinds"]):
					continue
				if source == -1 or routes[m]["length"] < routes[source]["length"] \
						or (routes[m]["length"] == routes[source]["length"] and routes[m]["shaded"] and not routes[source]["shaded"]) \
						or (routes[m]["length"] == routes[source]["length"] and routes[m]["shaded"] == routes[source]["shaded"]
							and routes[m]["kind"] in PREMIUM_KINDS and not routes[source]["kind"] in PREMIUM_KINDS):
					source = m
		var premium: bool = source != -1 and not nd["area"] and routes[source]["kind"] in PREMIUM_KINDS
		needs.append({"id": need_id, "name": nd["name"], "met": source != -1, "source": source, "premium": premium})
		if source != -1:
			met += 1
			if premium:
				premium_bonus += PREMIUM_BONUS
			if not nd["area"] and routes[source]["length"] >= LONG_ROUTE and not routes[source]["shaded"]:
				heat = def["heat_factor"]
				hot_route = source

	var like_source := -1
	for m in routes:
		if routes[m]["kind"] in def["like_kinds"]:
			like_source = m
			break
	if like_source == -1:
		for street in def["like_streets"]:
			for c in home["route_cells"]:
				if cells[c]["kind"] == TileDefs.Kind.ROAD and cells[c].get("variant", 0) == street:
					like_source = c
			for c in neighbours(home["index"]):
				if kind_at(cells, c) == TileDefs.Kind.ROAD and cells[c].get("variant", 0) == street:
					like_source = c

	var dislike := false
	if def["dislike_kind"] >= 0:
		for c in neighbours(home["index"]):
			if kind_at(cells, c) == def["dislike_kind"]:
				dislike = true

	var green: int = mini(home["green_sources"].size(), GREEN_CAP)
	var need_score := (met - (2 - met)) if needs.size() == 2 else 0
	var base: int = need_score + premium_bonus + (1 if like_source != -1 else 0) + green - heat - home["pollution"] - (1 if dislike else 0)

	var effects := {}
	if not circumstances.is_empty():
		var ctx := _context(role, needs, home, cells, base)
		for id in circumstances:
			if id == "population_growth":
				continue
			var d := CircumstanceDefs.member_effect(id, ctx)
			if d != 0:
				effects[id] = d
				ctx["so_far"] += d
		if "population_growth" in circumstances:
			var d := CircumstanceDefs.member_effect("population_growth", ctx)
			if d != 0:
				effects["population_growth"] = d
	var delta := 0
	for id in effects:
		delta += effects[id]
	var raw := base + delta
	var happiness := clampi(raw, HAPPY_MIN, HAPPY_MAX)

	# what is dragging this citizen down, for the complaint and for the reflection
	var unmet: Array = []
	for n in needs:
		if not n["met"]:
			unmet.append(n["id"])
	var need_hits := 0
	var walk_hits := 0
	var green_hits := 0
	var air_hits := 0
	var hit_card := ""
	for id in effects:
		if effects[id] >= 0:
			continue
		if id in CircumstanceDefs.NEED_CARDS:
			need_hits += 1
			hit_card = id
		elif id in CircumstanceDefs.WALK_CARDS:
			walk_hits += 1
		elif id in CircumstanceDefs.GREEN_CARDS:
			green_hits += 1
		else:
			air_hits += 1
	var weights := _weights(unmet.size() + need_hits, heat + walk_hits, (1 if green == 0 else 0) + green_hits, home["pollution"] + air_hits)
	# an unmet need is always the main complaint; otherwise the heaviest of the other causes
	var main := 0 if weights[0] > 0 else _heaviest(weights)
	var improve := ""
	if happiness < HAPPY_MAX:
		improve = COMPLAINT_TYPES[main] if weights.max() > 0 else ("Accessibility" if green > 0 else "Greenery")
	var complaint := ""
	var detail := ""
	if happiness < 0:
		complaint = COMPLAINT_TYPES[main]
		match complaint:
			"Accessibility":
				detail = Roles.missing_text(unmet[0]) if not unmet.is_empty() else ("Hit by %s" % CircumstanceDefs.title(hit_card))
			"Walkability":
				detail = "A walk of %d roads or more with no shade" % LONG_ROUTE
			"Greenery":
				detail = "No park or trees nearby"
			"Pollution":
				detail = "Pollution is too high"
	return {
		"role": role, "needs": needs, "like": like_source != -1, "like_source": like_source,
		"dislike": dislike, "heat": heat, "hot_route": hot_route, "green": green, "premium": premium_bonus,
		"effects": effects, "raw": raw, "happiness": happiness,
		"complaint": complaint, "complaint_detail": detail, "improve": improve,
	}


## The facts the circumstance cards look at for one citizen (see CircumstanceDefs.member_effect).
static func _context(role: String, needs: Array, home: Dictionary, cells: Array, base: int) -> Dictionary:
	var met := {}
	for n in needs:
		met[n["id"]] = n["met"]
	var nearest := {}
	var routes: Dictionary = home["routes"]
	for m in routes:
		var k: int = routes[m]["kind"]
		nearest[k] = mini(nearest.get(k, 99), routes[m]["length"])
	var has_park := false
	var bike := false
	var pedestrian := false
	for g in home["green_sources"]:
		if kind_at(cells, g) == TileDefs.Kind.PARK:
			has_park = true
	for c in home["route_cells"]:
		var v: int = cells[c].get("variant", 0)
		bike = bike or v == TileDefs.STREET_BIKE
		pedestrian = pedestrian or v == TileDefs.STREET_PEDESTRIAN
	var parking_adjacent := false
	for c in neighbours(home["index"]):
		if kind_at(cells, c) == TileDefs.Kind.PARKING:
			parking_adjacent = true
	var member_heat := 0
	for n in needs:
		if n["met"] and n["source"] != -1 and routes.has(n["source"]):
			var r: Dictionary = routes[n["source"]]
			if r["length"] >= LONG_ROUTE and not r["shaded"]:
				member_heat = Roles.DEFS[role]["heat_factor"]
	return {
		"role": role, "needs": met, "routes": routes, "nearest_kind": nearest, "heat": member_heat,
		"green": home["green_sources"].size(), "has_park": has_park, "pollution": home["pollution_level"],
		"parking_adjacent": parking_adjacent, "bike_route": bike, "pedestrian_route": pedestrian,
		"so_far": base, "long_route": LONG_ROUTE,
	}


## Parks in the 3x3 area around home `i` and trees (or shaded streets) right next to it.
static func _green_sources(cells: Array, i: int) -> Array[int]:
	var out: Array[int] = []
	var x := i % SIZE
	var y := i / SIZE
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var nx := x + dx
			var ny := y + dy
			if (dx == 0 and dy == 0) or nx < 0 or ny < 0 or nx >= SIZE or ny >= SIZE:
				continue
			var j := ny * SIZE + nx
			var t = cells[j]
			if t == null:
				continue
			if t["kind"] == TileDefs.Kind.PARK:
				out.append(j)
			elif (dx == 0 or dy == 0) and TileDefs.is_tree_like(t):
				out.append(j)
	out.sort()
	return out


## `circumstances` are the ids of the hidden circumstances revealed so far (see circumstance_defs.gd).
## Their happiness effects are applied per citizen; `effects` on each member lists what each card did.
## `apartments` holds every home (apartments and student residences).
static func evaluate(cells: Array, loans: int, circumstances: Array = [], card_points := 0) -> Dictionary:
	var pollution := pollution_level(cells)
	var penalty := pollution_penalty(pollution)
	var shaded := shaded_roads(cells)
	var complaints := {}
	# points still on the table per change, and how many homes each change would help
	var room := {}
	var room_homes := {}
	for c in COMPLAINT_TYPES:
		complaints[c] = 0
		room[c] = 0
		room_homes[c] = 0
	var served := {}
	var served_homes := {}
	var served_student_homes := {}

	var homes: Array = []
	var citizens := 0
	var happy := 0
	var unhappy := 0
	var citizen_sp := 0
	var role_happy := {}
	for i in cells.size():
		var kind := kind_at(cells, i)
		if kind == -1 or not TileDefs.is_home(kind):
			continue
		var routes := routes_from(cells, i, shaded)
		var green_sources := _green_sources(cells, i)
		var route_cells := {}
		for m in routes:
			for c in routes[m]["path"]:
				route_cells[c] = true
		var home := {
			"index": i, "routes": routes, "green_sources": green_sources, "route_cells": route_cells.keys(),
			"pollution": penalty, "pollution_level": pollution,
		}
		var members: Array = []
		var sp := 0
		var heat := 0
		var hot_route := -1
		var delta := 0
		var has_student := false
		var seen_improve := {}
		for role in TileDefs.members(cells[i]):
			var m := _member(role, cells, home, circumstances)
			members.append(m)
			sp += m["happiness"]
			delta += _sum(m["effects"])
			has_student = has_student or role == Roles.STUDENT
			if m["heat"] > heat:
				heat = m["heat"]
				hot_route = m["hot_route"]
			if m["happiness"] < 0:
				unhappy += 1
				complaints[m["complaint"]] += 1
			elif m["happiness"] > 0:
				happy += 1
			if m["happiness"] >= VARIETY_HAPPY:
				role_happy[role] = true
			if m["improve"] != "":
				room[m["improve"]] += HAPPY_MAX - m["happiness"]
				if not seen_improve.has(m["improve"]):
					seen_improve[m["improve"]] = true
					room_homes[m["improve"]] += 1
		var n := members.size()
		for m in routes:
			served[m] = true
			served_homes[m] = served_homes.get(m, 0) + 1
			if has_student:
				served_student_homes[m] = served_student_homes.get(m, 0) + 1
		citizens += n
		citizen_sp += sp
		homes.append({
			"index": i, "kind": kind, "citizens": n, "members": members,
			"routes": routes, "green_sources": green_sources, "green_bonus": green_sources.size(),
			"heat": heat, "hot_route": hot_route, "pollution": penalty,
			"circumstance_delta": delta,
			"happiness": roundi(float(sp) / n) if n > 0 else 0, "sp": sp,
		})

	var variety_roles: Array[String] = []
	for role in Roles.IDS:
		if role_happy.has(role):
			variety_roles.append(role)
	var variety_bonus: int = VARIETY_BONUS[variety_roles.size()]

	var unused: Array[int] = []
	for i in cells.size():
		if kind_at(cells, i) != -1 and TileDefs.is_service(kind_at(cells, i)) and not served.has(i):
			unused.append(i)
	var unused_penalty := unused.size() * UNUSED_PENALTY
	room["Accessibility"] += unused_penalty

	var circumstance_bonus := 0
	var bonus_sources := {}
	var stats := {"cells": cells, "served_homes": served_homes, "served_student_homes": served_student_homes}
	for id in circumstances:
		var got: Array[int] = CircumstanceDefs.point_bonus(id, stats)
		if not got.is_empty():
			bonus_sources[id] = got
			circumstance_bonus += got.size()
	var attractors: Array[int] = []
	attractors.append_array(bonus_sources.get("new_attractor", []))

	var penalty_points := loan_penalty(loans)
	return {
		"pollution": pollution, "pollution_penalty": penalty, "shaded": shaded,
		"apartments": homes, "citizens": citizens,
		"happy_citizens": happy, "unhappy_citizens": unhappy,
		"citizen_sp": citizen_sp, "loans": loans, "loan_penalty": penalty_points,
		"unused": unused, "unused_penalty": unused_penalty,
		"circumstances": circumstances.duplicate(), "circumstance_bonus": circumstance_bonus,
		"attractors": attractors, "bonus_sources": bonus_sources,
		"card_points": card_points,
		"variety_roles": variety_roles, "variety_bonus": variety_bonus,
		"total": citizen_sp - penalty_points - unused_penalty + circumstance_bonus + variety_bonus + card_points, "complaints": complaints,
		"room": room, "room_homes": room_homes,
	}


static func _sum(effects: Dictionary) -> int:
	var total := 0
	for id in effects:
		total += effects[id]
	return total
