extends RefCounted
## The Hard bot's city planner. It works out what the finished mat should look like, which tile
## goes on which lot, by trying many layouts and scoring each one with the real scoring rules.
## The layouts only use tiles the construction site can still supply and gold the planner has
## (or can borrow, at the price of the loan). The bot then buys what the plan needs most.
##
## The plan is a list of items, each a tile type on a lot. It is kept between calls so that the
## next purchase of the turn follows the same plan, and next turn's search starts from it.

const TileDefs = preload("res://scripts/core/tile_defs.gd")
const Scoring = preload("res://scripts/core/scoring.gd")
const Grid = preload("res://scripts/core/grid.gd")

const COLD_ITERATIONS := 3000
const WARM_ITERATIONS := 1500
const START_TEMP := 1.6
const END_TEMP := 0.065
## How many times its fair share of a stack a planner counts on getting: the others buy from it too,
## and counting on more than its share made plans fall through.
const SHARE := 1.0
## The longest one layout search may run, in milliseconds (the 14x14 mat makes every score slower than the old 7x7).
const TIME_BUDGET_MS := 1800

## The tiles a bot buys in one turn are the ones of its plan that look best on the mat right now (so
## its city grows as a connected whole, not as scattered pieces), with this much weight on buying
## first what the shop is running out of. The search keeps this many partial turns in play.
const SCARCITY_WEIGHT := 3.0
const PICK_BEAM := 4

## Experiment overrides for the numbers in this file and in bot.gd; empty in the game.
static var tune := {}


static func _t(key: String, default: float) -> float:
	return tune.get(key, default)


## The next [shop slot, lot] to buy, or [] when the plan has nothing affordable to offer.
static func next_purchase(gs, rng: RandomNumberGenerator, effort := 1.0) -> Array:
	var ctx := _context(gs)
	var plan := _plan_for(gs, ctx, rng, effort)
	var picks := _still_possible(gs, plan["picks"])
	if picks.is_empty():
		picks = _choose_picks(gs, ctx, plan)
	plan["picks"] = picks
	return [] if picks.is_empty() else picks[0]


## The picks that can still be bought: the tile fits on the mat, the stack has tiles and the gold is there.
static func _still_possible(gs, picks: Array) -> Array:
	var out := []
	var cells: Array = gs.current_player().cells
	for pick in picks:
		var tile = gs.stack_tile(pick[0])
		if tile != null and Grid.fits(cells, pick[1], TileDefs.footprint(tile)) and gs.can_afford(pick[0]):
			out.append(pick)
	return out


## The order to buy this turn's tiles in: of the plan's tiles, the set that scores best on the mat
## after the turn (a beam search), counting the scarcest tiles as a bonus. Returns [[slot, lot]...].
static func _choose_picks(gs, ctx: Dictionary, plan: Dictionary) -> Array:
	var p = gs.current_player()
	var types: Array = ctx["types"]
	var cands: Array = []
	for i in plan["type"].size():
		var t: Dictionary = types[plan["type"][i]]
		if t["free"] or gs.stack_count(t["slot"]) <= 0 or gs.price_of(t["tile"]) > p.money:
			continue
		var urgency: float = float(plan["counts"][plan["type"][i]]) / gs.stack_count(t["slot"])
		cands.append({"tile": t["tile"], "pieces": t["pieces"], "slot": t["slot"], "cell": plan["cell"][i], "price": gs.price_of(t["tile"]), "urgency": urgency})
	var beams := [{"cells": p.cells, "money": p.money, "picks": [], "used": {}, "taken": {}, "urgency": 0.0, "value": 0.0}]
	for step in gs.buys_left():
		var next := []
		var seen := {}
		for b in beams:
			for k in cands.size():
				var c: Dictionary = cands[k]
				if b["used"].has(k) or c["price"] > b["money"] or b["taken"].get(c["slot"], 0) >= gs.stack_count(c["slot"]):
					continue
				var used: Dictionary = b["used"].duplicate()
				used[k] = true
				var signature := str(used.keys())
				if seen.has(signature):
					continue
				seen[signature] = true
				var cells: Array = b["cells"].duplicate()
				Grid.place_pieces(cells, c["cell"], c["pieces"])
				var taken: Dictionary = b["taken"].duplicate()
				taken[c["slot"]] = taken.get(c["slot"], 0) + 1
				var urgency: float = b["urgency"] + c["urgency"]
				var score := float(Scoring.evaluate(cells, ctx["loans"], ctx["revealed"], ctx["card_points"])["total"])
				next.append({"cells": cells, "money": b["money"] - c["price"], "picks": b["picks"] + [[c["slot"], c["cell"]]],
					"used": used, "taken": taken, "urgency": urgency, "value": score + _t("scarcity", SCARCITY_WEIGHT) * urgency})
		if next.is_empty():
			break
		next.sort_custom(func(x, y): return x["value"] > y["value"])
		beams = next.slice(0, int(_t("beam", PICK_BEAM)))
	return beams[0]["picks"]


## The lot for the next free road the plan has, or -1 to keep the road for later.
static func next_free_road(gs, rng: RandomNumberGenerator, effort := 1.0) -> int:
	var ctx := _context(gs)
	var plan := _plan_for(gs, ctx, rng, effort)
	for i in plan["type"].size():
		var t: Dictionary = ctx["types"][plan["type"][i]]
		if t["free"] and t["tile"]["kind"] == TileDefs.Kind.ROAD:
			return plan["cell"][i]
	return -1


## The lot the plan gives the first free tile of an event card, or -1 when it has none.
static func bonus_cell(gs, rng: RandomNumberGenerator, effort := 1.0) -> int:
	var p = gs.current_player()
	if p.bonus_tiles.is_empty():
		return -1
	var ctx := _context(gs)
	var plan := _plan_for(gs, ctx, rng, effort)
	var key := TileDefs.sort_key(p.bonus_tiles[0])
	for i in plan["type"].size():
		var t: Dictionary = ctx["types"][plan["type"][i]]
		if t["free"] and t["key"] == key and t["tile"]["kind"] != TileDefs.Kind.ROAD:
			return plan["cell"][i]
	return -1


# ================================================================ the plan

## Everything a layout search needs to know, taken from the game as it stands.
static func _context(gs) -> Dictionary:
	var p = gs.current_player()
	var types: Array = []
	var players: int = gs.players.size()
	for s in gs.shop.size():
		var tile = gs.stack_tile(s)
		if tile == null:
			continue
		var left: int = gs.stack_count(s)
		var avail := clampi(ceili(left * _t("share", SHARE) / players), 1, left)
		types.append({"tile": tile, "cost": TileDefs.tile_cost(tile), "avail": avail, "slot": s, "free": false,
			"key": TileDefs.sort_key(tile), "size": TileDefs.footprint(tile), "pieces": Grid.pieces(tile)})
	var road := TileDefs.make(TileDefs.Kind.ROAD)
	road["free"] = true
	if p.free_roads > 0:
		types.append({"tile": road, "cost": 0, "avail": p.free_roads, "slot": -1, "free": true, "key": TileDefs.sort_key(road),
			"size": 1, "pieces": Grid.pieces(road)})
	var gifts := {}
	for tile in p.bonus_tiles:
		var key := TileDefs.sort_key(tile)
		if not gifts.has(key):
			gifts[key] = {"tile": tile, "cost": 0, "avail": 0, "slot": -1, "free": true, "key": key,
				"size": TileDefs.footprint(tile), "pieces": Grid.pieces(tile)}
		gifts[key]["avail"] += 1
	for key in gifts:
		types.append(gifts[key])
	var empty := 0
	var occ := PackedByteArray()
	occ.resize(Grid.CELLS)
	for c in Grid.CELLS:
		if p.cells[c] == null:
			empty += 1
		else:
			occ[c] = 1
	var buys: int = gs.buys_left() + (gs.ROUNDS - gs.round_number) * gs.BUYS_PER_TURN
	var free_items := 0
	for t in types:
		if t["free"]:
			free_items += t["avail"]
	return {
		"base": p.cells, "occ": occ, "types": types, "money": p.money, "loans": p.loans, "revealed": gs.revealed,
		"card_points": p.card_points, "buys": mini(buys, maxi(0, empty - free_items)),
		"player": gs.current_index(),
	}


## The plan for the current planner: the one kept from before when it still holds, otherwise a
## fresh search (from the old plan when there is one).
static func _plan_for(gs, ctx: Dictionary, rng: RandomNumberGenerator, effort: float) -> Dictionary:
	var meta := "bot_plan_%d" % ctx["player"]
	var old = gs.get_meta(meta) if gs.has_meta(meta) else null
	var plan := _carry_over(ctx, old)
	var bought := 0
	var wanted := 0
	for t in ctx["types"]:
		if t["free"]:
			wanted += t["avail"]
	for i in plan["type"].size():
		if not ctx["types"][plan["type"][i]]["free"]:
			bought += 1
	# the plan from earlier in this turn still fits: just carry on with it
	var stamp: int = gs.round_number * 100 + gs.turn
	if old != null and old["stamp"] == stamp and bought == ctx["buys"] and plan["type"].size() == bought + wanted:
		_count(ctx, plan)
		plan["stamp"] = stamp
		plan["picks"] = old["picks"]
		gs.set_meta(meta, plan)
		return plan
	_fill(ctx, plan, rng)
	_anneal(ctx, plan, int(_t("cold" if old == null else "warm", COLD_ITERATIONS if old == null else WARM_ITERATIONS) * effort), rng)
	_count(ctx, plan)
	plan["stamp"] = stamp
	plan["picks"] = []
	gs.set_meta(meta, plan)
	return plan


## The items of an earlier plan that can still be built: the tile still fits there and the tile
## type is still on offer.
static func _carry_over(ctx: Dictionary, old) -> Dictionary:
	var plan := {"type": PackedInt32Array(), "cell": PackedInt32Array(), "counts": PackedInt32Array(), "keys": PackedInt32Array()}
	if old == null:
		return plan
	var occ: PackedByteArray = ctx["occ"].duplicate()
	for i in old["type"].size():
		var key: int = old["keys"][i]
		var is_free: bool = old["free"][i]
		var cell: int = old["cell"][i]
		var t := _type_with(ctx, key, is_free)
		if t < 0:
			continue
		var size: int = ctx["types"][t]["size"]
		if not _free(occ, cell, size):
			continue
		_mark(occ, cell, size, 1)
		plan["type"].append(t)
		plan["cell"].append(cell)
	return plan


static func _type_with(ctx: Dictionary, key: int, is_free: bool) -> int:
	for t in ctx["types"].size():
		if ctx["types"][t]["key"] == key and ctx["types"][t]["free"] == is_free:
			return t
	return -1


## Tops the plan up (or trims it) to exactly the number of tiles still to be bought, and gives
## every free road and gift a lot.
static func _fill(ctx: Dictionary, plan: Dictionary, rng: RandomNumberGenerator) -> void:
	var types: Array = ctx["types"]
	var used: PackedByteArray = ctx["occ"].duplicate()
	for i in plan["cell"].size():
		_mark(used, plan["cell"][i], types[plan["type"][i]]["size"], 1)
	var have := PackedInt32Array()
	have.resize(types.size())
	var bought := 0
	var keep_t := PackedInt32Array()
	var keep_c := PackedInt32Array()
	for i in plan["type"].size():
		var t: int = plan["type"][i]
		if have[t] >= types[t]["avail"]:
			_mark(used, plan["cell"][i], types[t]["size"], 0)
			continue
		if not types[t]["free"]:
			if bought >= ctx["buys"]:
				_mark(used, plan["cell"][i], types[t]["size"], 0)
				continue
			bought += 1
		have[t] += 1
		keep_t.append(t)
		keep_c.append(plan["cell"][i])
	plan["type"] = keep_t
	plan["cell"] = keep_c
	# free roads and gifts first, then bought tiles
	for t in types.size():
		if not types[t]["free"]:
			continue
		while have[t] < types[t]["avail"]:
			var c := _random_anchor(used, types[t]["size"], rng)
			if c < 0:
				break
			_add(plan, used, types, t, c)
			have[t] += 1
	var buyable: Array[int] = []
	for t in types.size():
		if not types[t]["free"]:
			buyable.append(t)
	var guard := 0
	while bought < ctx["buys"] and not buyable.is_empty() and guard < 500:
		guard += 1
		var t: int = buyable[rng.randi() % buyable.size()]
		if have[t] >= types[t]["avail"]:
			continue
		var c := _random_anchor(used, types[t]["size"], rng)
		if c < 0:
			continue
		_add(plan, used, types, t, c)
		have[t] += 1
		bought += 1


static func _add(plan: Dictionary, used: PackedByteArray, types: Array, t: int, c: int) -> void:
	plan["type"].append(t)
	plan["cell"].append(c)
	_mark(used, c, types[t]["size"], 1)


## Do `size` x `size` squares with their top-left square on `anchor` lie on the mat and all lie empty?
static func _free(occ: PackedByteArray, anchor: int, size: int) -> bool:
	if anchor < 0 or anchor % Grid.SIZE + size > Grid.SIZE or anchor / Grid.SIZE + size > Grid.SIZE:
		return false
	for dy in size:
		for dx in size:
			if occ[anchor + dy * Grid.SIZE + dx] != 0:
				return false
	return true


static func _mark(occ: PackedByteArray, anchor: int, size: int, value: int) -> void:
	for dy in size:
		for dx in size:
			occ[anchor + dy * Grid.SIZE + dx] = value


## A random anchor where a tile of `size` fits, or -1.
static func _random_anchor(occ: PackedByteArray, size: int, rng: RandomNumberGenerator) -> int:
	for attempt in 40:
		var c := rng.randi() % Grid.CELLS
		if _free(occ, c, size):
			return c
	var open: Array[int] = []
	for c in Grid.CELLS:
		if _free(occ, c, size):
			open.append(c)
	return -1 if open.is_empty() else open[rng.randi() % open.size()]


## How many items of each type the plan holds, and what is needed to keep the plan between calls.
static func _count(ctx: Dictionary, plan: Dictionary) -> void:
	var counts := PackedInt32Array()
	counts.resize(ctx["types"].size())
	var keys := PackedInt32Array()
	var free: Array = []
	for i in plan["type"].size():
		var t: int = plan["type"][i]
		counts[t] += 1
		keys.append(ctx["types"][t]["key"])
		free.append(ctx["types"][t]["free"])
	plan["counts"] = counts
	plan["keys"] = keys
	plan["free"] = free


## What the finished mat of a plan scores, borrowing gold for whatever the purse cannot pay.
static func _energy(ctx: Dictionary, type: PackedInt32Array, cell: PackedInt32Array) -> float:
	var cells: Array = ctx["base"].duplicate()
	var cost := 0
	for i in type.size():
		var t: Dictionary = ctx["types"][type[i]]
		Grid.place_pieces(cells, cell[i], t["pieces"])
		cost += t["cost"]
	var loans: int = ctx["loans"] + maxi(0, ceili((cost - ctx["money"]) / 20.0))
	return float(Scoring.evaluate(cells, loans, ctx["revealed"], ctx["card_points"])["total"])


## Simulated annealing: change a tile's type, move it to another lot or swap two lots, keeping
## the move when the mat scores better or, now and then, a little worse. A tile only goes where its
## whole footprint fits, and only tiles of the same size swap places.
static func _anneal(ctx: Dictionary, plan: Dictionary, iterations: int, rng: RandomNumberGenerator) -> void:
	var types: Array = ctx["types"]
	var type: PackedInt32Array = plan["type"]
	var cell: PackedInt32Array = plan["cell"]
	var n := type.size()
	if n == 0:
		return
	var occ: PackedByteArray = ctx["occ"].duplicate()
	for i in n:
		_mark(occ, cell[i], types[type[i]]["size"], 1)
	var have := PackedInt32Array()
	have.resize(types.size())
	for t in type:
		have[t] += 1
	var buyable: Array[int] = []
	for t in types.size():
		if not types[t]["free"]:
			buyable.append(t)

	var current := _energy(ctx, type, cell)
	var best := current
	var best_type := type.duplicate()
	var best_cell := cell.duplicate()
	var temp: float = _t("t0", START_TEMP)
	var cool := pow(_t("t1", END_TEMP) / temp, 1.0 / maxi(1, iterations))
	var started := Time.get_ticks_msec()
	for step in iterations:
		# a big mat can make one search slow: never hold the game up for longer than the time budget
		if step % 64 == 63 and Time.get_ticks_msec() - started > TIME_BUDGET_MS:
			break
		temp *= cool
		var i := rng.randi() % n
		var roll := rng.randf()
		var old_t := type[i]
		var old_c := cell[i]
		var old_size: int = types[old_t]["size"]
		var j := -1
		if roll < 0.35 and not types[old_t]["free"] and buyable.size() > 1:
			var t: int = buyable[rng.randi() % buyable.size()]
			if t == old_t or have[t] >= types[t]["avail"]:
				continue
			_mark(occ, old_c, old_size, 0)
			if not _free(occ, old_c, types[t]["size"]):
				_mark(occ, old_c, old_size, 1)
				continue
			_mark(occ, old_c, types[t]["size"], 1)
			type[i] = t
		elif roll < 0.7:
			_mark(occ, old_c, old_size, 0)
			var c := _random_anchor(occ, old_size, rng)
			if c < 0:
				_mark(occ, old_c, old_size, 1)
				continue
			_mark(occ, c, old_size, 1)
			cell[i] = c
		else:
			j = rng.randi() % n
			if j == i or cell[i] == cell[j] or types[type[j]]["size"] != old_size:
				continue
			var tmp := cell[i]
			cell[i] = cell[j]
			cell[j] = tmp
		var value := _energy(ctx, type, cell)
		var delta := value - current
		if delta >= 0.0 or rng.randf() < exp(delta / temp):
			current = value
			if type[i] != old_t:
				have[old_t] -= 1
				have[type[i]] += 1
			if current > best:
				best = current
				best_type = type.duplicate()
				best_cell = cell.duplicate()
		else:
			# put the move back, squares and all
			if j >= 0:
				var tmp := cell[i]
				cell[i] = cell[j]
				cell[j] = tmp
			else:
				_mark(occ, cell[i], types[type[i]]["size"], 0)
				type[i] = old_t
				cell[i] = old_c
				_mark(occ, old_c, old_size, 1)
	plan["type"] = best_type
	plan["cell"] = best_cell
