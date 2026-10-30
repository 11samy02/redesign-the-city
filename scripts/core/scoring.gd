extends RefCounted
## Final-scoring rules for one 4x4 player mat (concept doc: Citizen, Pollution,
## Shade and heat, Accessibility, Complaint types, Bank).

const TileDefs = preload("res://scripts/core/tile_defs.gd")

const SIZE := 4
const START_POLLUTION := 10
const LOAN_PENALTY := 2
## An amenity no home can reach is wasted: buying it only to keep it from others must not pay off.
const UNUSED_PENALTY := 1
const HAPPY_MIN := -3
const HAPPY_MAX := 3
const LONG_ROUTE := 2

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


static func pollution_level(cells: Array) -> int:
	var level := START_POLLUTION
	for t in cells:
		if t == null:
			continue
		if t["kind"] == TileDefs.Kind.PARK:
			level -= 3
		elif t["kind"] == TileDefs.Kind.TREES:
			level -= 1
	return maxi(0, level)


static func pollution_penalty(level: int) -> int:
	if level >= 9:
		return 2
	if level >= 6:
		return 1
	return 0


static func shaded_roads(cells: Array) -> Array[bool]:
	var shaded: Array[bool] = []
	shaded.resize(cells.size())
	for i in cells.size():
		if kind_at(cells, i) != TileDefs.Kind.ROAD:
			continue
		for n in neighbours(i):
			var k := kind_at(cells, n)
			if k == TileDefs.Kind.PARK or k == TileDefs.Kind.TREES:
				shaded[i] = true
	return shaded


## Shortest road routes from a building to every amenity it can reach.
## Returns { amenity_index: {"length": int, "shaded": bool, "path": Array[int]} }.
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
		if kind_at(cells, m) != TileDefs.Kind.AMENITY or m == start:
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
		routes[m] = {"length": dist[best], "shaded": shade_ok[best], "path": path}
	return routes


static func _complaint(amenity_bonus: int, heat: int, green_bonus: int, penalty: int) -> String:
	var weights := [1 if amenity_bonus == 0 else 0, heat, 1 if green_bonus == 0 else 0, penalty]
	var best := 0
	for i in weights.size():
		if weights[i] > weights[best]:
			best = i
	return COMPLAINT_TYPES[best]


## What would lift a home that is not yet at the happiness cap the most.
static func _improvement(amenity_bonus: int, heat: int, green_bonus: int, penalty: int) -> String:
	var weights := [1 if amenity_bonus == 0 else 0, heat, 1 if green_bonus == 0 else 0, penalty]
	var best := 0
	for i in weights.size():
		if weights[i] > weights[best]:
			best = i
	if weights[best] == 0:
		return "Accessibility" if amenity_bonus <= green_bonus else "Greenery"
	return COMPLAINT_TYPES[best]


static func evaluate(cells: Array, loans: int) -> Dictionary:
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

	var apartments: Array = []
	var citizens := 0
	var happy := 0
	var unhappy := 0
	var citizen_sp := 0
	for i in cells.size():
		var kind := kind_at(cells, i)
		if kind == -1 or not TileDefs.is_apartment(kind):
			continue
		var routes := routes_from(cells, i, shaded)
		var heat := 0
		var hot_route := -1
		for m in routes:
			if routes[m]["length"] >= LONG_ROUTE and not routes[m]["shaded"]:
				heat = 1
				hot_route = m
		var green_sources: Array[int] = []
		for j in cells.size():
			var k := kind_at(cells, j)
			if k == TileDefs.Kind.PARK and in_park_area(j, i):
				green_sources.append(j)
			elif k == TileDefs.Kind.TREES and j in neighbours(i):
				green_sources.append(j)
		var raw := routes.size() + green_sources.size() - heat - penalty
		var happiness := clampi(raw, HAPPY_MIN, HAPPY_MAX)
		var n := TileDefs.citizens(kind)
		for m in routes:
			served[m] = true
		var improve := ""
		if happiness < HAPPY_MAX:
			improve = _improvement(routes.size(), heat, green_sources.size(), penalty)
			room[improve] += (HAPPY_MAX - happiness) * n
			room_homes[improve] += 1
		var complaint := ""
		if happiness < 0:
			complaint = _complaint(routes.size(), heat, green_sources.size(), penalty)
			complaints[complaint] += n
			unhappy += n
		elif happiness > 0:
			happy += n
		citizens += n
		citizen_sp += happiness * n
		apartments.append({
			"index": i, "kind": kind, "citizens": n,
			"routes": routes, "amenity_bonus": routes.size(),
			"heat": heat, "hot_route": hot_route,
			"green_sources": green_sources, "green_bonus": green_sources.size(),
			"pollution": penalty, "raw": raw, "happiness": happiness,
			"sp": happiness * n, "complaint": complaint, "improve": improve,
		})

	var unused: Array[int] = []
	for i in cells.size():
		if kind_at(cells, i) == TileDefs.Kind.AMENITY and not served.has(i):
			unused.append(i)
	var unused_penalty := unused.size() * UNUSED_PENALTY
	room["Accessibility"] += unused_penalty

	return {
		"pollution": pollution, "pollution_penalty": penalty, "shaded": shaded,
		"apartments": apartments, "citizens": citizens,
		"happy_citizens": happy, "unhappy_citizens": unhappy,
		"citizen_sp": citizen_sp, "loans": loans, "loan_penalty": loans * LOAN_PENALTY,
		"unused": unused, "unused_penalty": unused_penalty,
		"total": citizen_sp - loans * LOAN_PENALTY - unused_penalty, "complaints": complaints,
		"room": room, "room_homes": room_homes,
	}
