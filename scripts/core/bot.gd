extends RefCounted
## Computer planners. Easy plays at random. Medium picks among its few best-looking
## moves. Hard plans both purchases of a turn together and weighs road links it can
## finish later and gold in hand.

const TileDefs = preload("res://scripts/core/tile_defs.gd")
const Scoring = preload("res://scripts/core/scoring.gd")

const EASY := 1
const MEDIUM := 2
const HARD := 3
const LEVEL_NAMES := {EASY: "Easy", MEDIUM: "Medium", HARD: "Hard"}
## Weights for Hard's look-ahead terms.
const HARD_WEIGHTS := {"route": 0.6, "green": 0.25, "amenity": 0.5, "money": 0.12}
## Medium picks at random among this many of its best moves, so it makes human-like slips.
const MEDIUM_CHOICES := 4


static func level_name(level: int) -> String:
	return LEVEL_NAMES.get(level, "Human")


static func _empty_cells(cells: Array) -> Array[int]:
	var out: Array[int] = []
	for c in cells.size():
		if cells[c] == null:
			out.append(c)
	return out


## Returns [shop slot, mat cell]. The caller handles loans first.
static func choose_purchase(gs, level: int, rng: RandomNumberGenerator) -> Array:
	var p = gs.current_player()
	var slots: Array[int] = []
	for s in gs.shop.size():
		if gs.can_afford(s):
			slots.append(s)
	var empty := _empty_cells(p.cells)
	if level <= EASY:
		return [slots[rng.randi() % slots.size()], empty[rng.randi() % empty.size()]]

	var first := _candidates(gs, p.cells, p.money, p.loans, -1, level, rng, 0.1)
	if level == MEDIUM:
		var pick: Array = first[rng.randi() % mini(MEDIUM_CHOICES, first.size())]
		return [pick[1], pick[2]]
	if gs.buys_left() < 2:
		return [first[0][1], first[0][2]]
	# Hard plans both purchases of the turn together: try the best first moves
	# and keep the one that leaves the best follow-up.
	var best: Array = first[0]
	var best_total := -INF
	for k in mini(8, first.size()):
		var m: Array = first[k]
		var cells: Array = p.cells.duplicate()
		cells[m[2]] = gs.shop[m[1]]
		var money_after: int = p.money - TileDefs.cost(gs.shop[m[1]]["kind"])
		var second := _candidates(gs, cells, money_after, p.loans, m[1], level, rng, 0.0)
		# no affordable follow-up means a loan: count its 2-point cost
		var total: float = second[0][0] if not second.is_empty() else _value(gs, cells, money_after, p.loans + 1, level)
		if total > best_total:
			best_total = total
			best = m
	return [best[1], best[2]]


## Every affordable [value, slot, cell] for a mat, best first. Identical tiles
## score identically, so each kind is evaluated once.
static func _candidates(gs, cells: Array, money: int, loans: int, skip_slot: int, level: int,
		rng: RandomNumberGenerator, noise: float) -> Array:
	var out: Array = []
	var seen := {}
	var empty := _empty_cells(cells)
	for s in gs.shop.size():
		var tile = gs.shop[s]
		if tile == null or s == skip_slot or TileDefs.cost(tile["kind"]) > money:
			continue
		var key := "%d/%d" % [tile["kind"], tile.get("variant", 0)]
		if seen.has(key):
			continue
		seen[key] = true
		var money_after: int = money - TileDefs.cost(tile["kind"])
		for c in empty:
			var trial: Array = cells.duplicate()
			trial[c] = tile
			out.append([_value(gs, trial, money_after, loans, level) + rng.randf() * noise, s, c])
	out.sort_custom(func(a, b): return a[0] > b[0])
	return out


## Cell for a free road, or -1 to keep it for later.
static func choose_free_road(gs, level: int, rng: RandomNumberGenerator) -> int:
	var p = gs.current_player()
	if p.free_roads <= 0:
		return -1
	var empty := _empty_cells(p.cells)
	if empty.is_empty():
		return -1
	var last_round: bool = gs.round_number >= gs.ROUNDS
	var road := TileDefs.make(TileDefs.Kind.ROAD)
	road["free"] = true
	if level <= EASY:
		# drops roads at random in the second half of the game
		if gs.round_number >= 3 and (last_round or rng.randf() < 0.5):
			return empty[rng.randi() % empty.size()]
		return -1
	var base := _value(gs, p.cells, p.money, p.loans, level)
	var best := -1
	var best_value := 0.0 if not last_round else -INF
	for c in empty:
		var cells: Array = p.cells.duplicate()
		cells[c] = road
		var v := _value(gs, cells, p.money, p.loans, level) - base + rng.randf() * 0.05
		if v > best_value:
			best_value = v
			best = c
	return best


## The change a bot names at the end of the game: the one with the most points still to gain.
static func choose_change(result: Dictionary, level: int, rng: RandomNumberGenerator) -> String:
	var types: Array = Scoring.COMPLAINT_TYPES
	if level <= EASY:
		return types[rng.randi() % types.size()]
	var best: String = types[0]
	for t in types:
		if result["room"][t] > result["room"][best]:
			best = t
	return best


## How good a mat looks to a bot. Medium only counts points; Hard plans ahead.
static func _value(gs, cells: Array, money: int, loans: int, level: int) -> float:
	var r := Scoring.evaluate(cells, loans)
	var v := float(r["total"])
	# rounds still to come, including this one, scale how much the future matters
	var future: float = float(gs.ROUNDS - gs.round_number + 1) / gs.ROUNDS
	# homes are worth building early even while pollution still makes them unhappy:
	# expect that pollution to be fixed in later rounds
	v += r["citizens"] * (r["pollution_penalty"] + 0.6) * future
	if level < HARD:
		return v
	var served := {}
	for a in r["apartments"]:
		for m in a["routes"]:
			served[m] = true
		if a["routes"].is_empty() and _next_to_road(cells, a["index"]):
			v += HARD_WEIGHTS["route"] * a["citizens"] * future
		if a["green_sources"].is_empty() and _next_to_empty(cells, a["index"]):
			v += HARD_WEIGHTS["green"] * a["citizens"] * future
	for m in cells.size():
		var t = cells[m]
		if t != null and t["kind"] == TileDefs.Kind.AMENITY and not served.has(m) and _next_to_road(cells, m):
			v += HARD_WEIGHTS["amenity"] * future
	v += money * HARD_WEIGHTS["money"] * future
	return v


static func _next_to_road(cells: Array, i: int) -> bool:
	for n in Scoring.neighbours(i):
		if cells[n] != null and cells[n]["kind"] == TileDefs.Kind.ROAD:
			return true
	return false


static func _next_to_empty(cells: Array, i: int) -> bool:
	for n in Scoring.neighbours(i):
		if cells[n] == null:
			return true
	return false
