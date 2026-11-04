extends RefCounted
## Carries out the effects of event and penalty cards (see card_defs.gd). Effects act on the game
## state at once; `lines` collects plain sentences saying what happened, for the card screen.
##
## "op" values: all, choice, gold_all, gold_self, gold_stat, gold_stat_per, gold_per, gold_if, steal, pay_each,
## transfer, points_self, points_all, points_all_if, points_stat, points_stat_per, points_per, points_if,
## free_tile, free_roads, lose_free_roads, loan_relief, discount, discount_all, markup, markup_all,
## buy_bonus, lose_tile, lose_roads.
##
## Rules that apply to every card: gold never drops below zero, and a player cannot pay more than
## they have. "The player with the most/least ..." means every player who ties for it; when everyone
## ties, everyone counts. Prices and the number of buys change for the current turn only.

const TileDefs = preload("res://scripts/core/tile_defs.gd")
const Scoring = preload("res://scripts/core/scoring.gd")
const CardDefs = preload("res://scripts/core/card_defs.gd")
const Grid = preload("res://scripts/core/grid.gd")

## About how many gold one point is worth to a bot choosing between two options.
const POINT_VALUE := 3.0


static func apply(gs, me: int, fx: Dictionary, lines: Array[String]) -> void:
	var n: int = fx.get("n", 0)
	match fx["op"]:
		"all":
			for f in fx["fxs"]:
				apply(gs, me, f, lines)
		"choice":
			apply(gs, me, fx["options"][0]["fx"], lines)
		"gold_all":
			for i in gs.players.size():
				_gold(gs, i, n, lines)
		"gold_self":
			_gold(gs, me, n, lines)
		"gold_stat":
			var hit := _extreme(gs, fx["stat"], fx["mode"])
			if hit.is_empty():
				lines.append("Nobody qualifies, so nothing happens.")
			for i in hit:
				_gold(gs, i, n, lines)
		"gold_stat_per":
			# "every" turns the statistic into steps ("1 gold for every 3 tiles"), so the bill grows with the city
			var owed := mini(stat_value(gs, me, fx["stat"]) / int(fx.get("every", 1)), fx["cap"]) * int(fx["per"])
			if owed == 0:
				lines.append("%s has none of those, so nothing happens." % gs.players[me].name)
			else:
				_gold(gs, me, owed, lines)
		"gold_per":
			var amount := mini(_count(gs.players[me].cells, fx["kinds"]), fx["cap"]) * n
			if amount == 0:
				lines.append("%s has none of those, so nothing happens." % gs.players[me].name)
			else:
				_gold(gs, me, amount, lines)
		"gold_if":
			if _cond(gs, me, fx):
				_gold(gs, me, n, lines)
			else:
				lines.append("%s does not meet the condition, so nothing happens." % gs.players[me].name)
		"steal":
			_steal(gs, me, fx["from"], n, lines)
		"pay_each":
			for i in gs.players.size():
				if i == me:
					continue
				var paid := mini(n, gs.players[me].money)
				gs.players[me].money -= paid
				gs.players[i].money += paid
				lines.append("%s pays %d gold to %s." % [gs.players[me].name, paid, gs.players[i].name])
		"transfer":
			_transfer(gs, n, lines)
		"points_self":
			_points(gs, me, n, lines)
		"points_all":
			for i in gs.players.size():
				_points(gs, i, n, lines)
		"points_all_if":
			var any := false
			for i in gs.players.size():
				if _cond(gs, i, fx):
					any = true
					_points(gs, i, n, lines)
			if not any:
				lines.append("Nobody qualifies, so nothing happens.")
		"points_stat":
			var hit := _extreme(gs, fx["stat"], fx["mode"])
			if hit.is_empty():
				lines.append("Nobody qualifies, so nothing happens.")
			for i in hit:
				_points(gs, i, n, lines)
		"points_stat_per":
			var amount := mini(stat_value(gs, me, fx["stat"]), fx["cap"]) * int(fx["per"])
			if amount == 0:
				lines.append("%s is fine, so nothing happens." % gs.players[me].name)
			else:
				_points(gs, me, amount, lines)
		"points_per":
			var amount := mini(_count(gs.players[me].cells, fx["kinds"]), fx["cap"]) * n
			if amount == 0:
				lines.append("%s has none of those, so nothing happens." % gs.players[me].name)
			else:
				_points(gs, me, amount, lines)
		"points_if":
			if _cond(gs, me, fx):
				_points(gs, me, n, lines)
			else:
				lines.append("%s does not meet the condition, so nothing happens." % gs.players[me].name)
		"free_tile":
			for k in n:
				var t := TileDefs.make(fx["kind"], fx.get("variant", 0))
				gs.players[me].bonus_tiles.append(t)
			lines.append("%s receives %s to place for free." % [gs.players[me].name, _a(TileDefs.display_name(TileDefs.make(fx["kind"], fx.get("variant", 0))).to_lower(), n)])
		"free_roads":
			gs.players[me].free_roads += n
			lines.append("%s receives %d extra free roads." % [gs.players[me].name, n])
		"lose_free_roads":
			var lost := mini(n, gs.players[me].free_roads)
			gs.players[me].free_roads -= lost
			lines.append(("%s loses %d free road%s." % [gs.players[me].name, lost, "" if lost == 1 else "s"]) if lost > 0 else "%s has no free roads left to lose." % gs.players[me].name)
		"loan_relief":
			if gs.players[me].loans > 0:
				gs.players[me].loans -= 1
				lines.append("%s's bank cancels one loan." % gs.players[me].name)
			else:
				lines.append("%s has no loan to cancel." % gs.players[me].name)
		"discount":
			gs.turn_discounts.append({"kinds": fx["kinds"], "price": fx.get("price", -1), "by": fx.get("by", 0)})
			lines.append("%s cost %s this turn." % [_group(fx["kinds"]), "0 gold" if fx.get("price", -1) == 0 else "%d gold less" % fx.get("by", 0)])
		"discount_all":
			gs.turn_discounts.append({"kinds": [], "price": -1, "by": n})
			lines.append("Every tile costs %d gold less this turn." % n)
		"markup":
			gs.turn_markups.append({"kinds": fx["kinds"], "by": fx["by"]})
			lines.append("%s cost %d gold more this turn." % [_group(fx["kinds"]), fx["by"]])
		"markup_all":
			gs.turn_markups.append({"kinds": [], "by": n})
			lines.append("Every tile costs %d gold more this turn." % n)
		"buy_bonus":
			gs.buy_bonus += n
			lines.append("%s may buy %d %s tile%s this turn." % [gs.players[me].name, absi(n), "more" if n > 0 else "fewer", "" if absi(n) == 1 else "s"])
		"lose_tile":
			_lose(gs, me, fx["kinds"], n, lines)
		"lose_roads":
			_lose(gs, me, [TileDefs.Kind.ROAD], n, lines)


# ---------------------------------------------------------------- bots

## What a bot would pick: the index of the option it likes best (the first available one on a tie).
static func pick_option(gs, me: int, options: Array) -> int:
	var best := -1
	var best_value := -INF
	for k in options.size():
		if not options[k]["available"]:
			continue
		var v := value_hint(gs, me, options[k]["fx"])
		if v > best_value:
			best_value = v
			best = k
	return maxi(best, 0)


## A rough worth in gold of an option for the current player (negative for a loss).
static func value_hint(gs, me: int, fx: Dictionary) -> float:
	var n: int = fx.get("n", 0)
	match fx["op"]:
		"all":
			var total := 0.0
			for f in fx["fxs"]:
				total += value_hint(gs, me, f)
			return total
		"gold_self":
			return float(n)
		"points_self":
			return n * POINT_VALUE
		"free_tile":
			return 5.0 * n if fx["kind"] != TileDefs.Kind.ROAD else 2.0 * n
		"lose_tile":
			return -7.0 * n
		"lose_roads":
			return -3.0 * n
		"pay_each":
			return -float(n * (gs.players.size() - 1))
		"buy_bonus":
			return 4.0 * n
	return 0.0


# ---------------------------------------------------------------- statistics

static func stat_value(gs, i: int, stat: String) -> int:
	var p = gs.players[i]
	match stat:
		"money":
			return p.money
		"loans":
			return p.loans
		"pollution":
			return Scoring.pollution_level(p.cells)
		"services":
			return _count(p.cells, CardDefs.SERVICES)
		"green":
			return _count(p.cells, CardDefs.GREEN)
		"homes":
			return _count(p.cells, CardDefs.HOMES)
		"roads":
			return _count(p.cells, [TileDefs.Kind.ROAD])
		"tiles":
			var built := 0
			for t in Grid.tiles(p.cells):
				if not t.get("fixed", false):
					built += 1
			return built
		"citizens":
			return gs.score(i)["citizens"]
		"unhappy":
			return gs.score(i)["unhappy_citizens"]
		"hot":
			# citizens with a long walk and no shade
			return _members_where(gs.score(i), func(m): return m["heat"] > 0)
		"unmet":
			# citizens who cannot reach something they need
			return _members_where(gs.score(i), _has_unmet)
		"unused":
			return gs.score(i)["unused"].size()
		"score":
			return gs.score(i)["total"]
	return 0


static func _has_unmet(member: Dictionary) -> bool:
	for n in member["needs"]:
		if not n["met"]:
			return true
	return false


## How many citizens of a scored mat pass `test`.
static func _members_where(result: Dictionary, test: Callable) -> int:
	var n := 0
	for a in result["apartments"]:
		for m in a["members"]:
			if test.call(m):
				n += 1
	return n


## The players who have the most ("max") or least ("min") of a statistic. Ties all count.
## Loans and unhappy citizens only count when somebody actually has some.
static func _extreme(gs, stat: String, mode: String) -> Array[int]:
	var values: Array[int] = []
	for i in gs.players.size():
		values.append(stat_value(gs, i, stat))
	var target: int = values.max() if mode == "max" else values.min()
	var out: Array[int] = []
	if mode == "max" and target <= 0 and stat in ["loans", "unhappy"]:
		return out
	for i in values.size():
		if values[i] == target:
			out.append(i)
	return out


static func _count(cells: Array, kinds: Array) -> int:
	var n := 0
	for t in Grid.tiles(cells):
		if t["kind"] in kinds:
			n += 1
	return n


## Tiles of these kinds a penalty can take: the ones a planner built, not the ones the mat came with.
static func _loseable(cells: Array, kinds: Array) -> Array[int]:
	var out: Array[int] = []
	for a in Grid.anchors(cells):
		if cells[a]["kind"] in kinds and not cells[a].get("fixed", false):
			out.append(a)
	return out


static func _cond(gs, me: int, fx: Dictionary) -> bool:
	var p = gs.players[me]
	match fx["cond"]:
		"connected":
			var r: Dictionary = gs.score(me)
			if r["apartments"].is_empty():
				return false
			for a in r["apartments"]:
				if a["routes"].is_empty():
					return false
			return true
		"no_hot":
			return gs.score(me)["citizens"] > 0 and stat_value(gs, me, "hot") == 0
		"all_met":
			return gs.score(me)["citizens"] > 0 and stat_value(gs, me, "unmet") == 0
		"no_unhappy":
			return gs.score(me)["citizens"] > 0 and gs.score(me)["unhappy_citizens"] == 0
		"no_loans":
			return p.loans == 0
		"has_loans":
			return p.loans > 0
		"citizens_min":
			return gs.score(me)["citizens"] >= fx["min"]
		"has_kind":
			return _count(p.cells, fx["kinds"]) > 0
		"lacks_kind":
			return _count(p.cells, fx["kinds"]) == 0
		"count_min":
			return _count(p.cells, fx["kinds"]) >= fx["min"]
		"pollution_min":
			return Scoring.pollution_level(p.cells) >= fx["min"]
		"not_connected":
			for a in gs.score(me)["apartments"]:
				if a["routes"].is_empty():
					return true
			return false
		"pollution_max":
			return Scoring.pollution_level(p.cells) <= fx["max"]
		"no_unused":
			return _count(p.cells, CardDefs.SERVICES) >= 3 and gs.score(me)["unused"].is_empty()
	return false


# ---------------------------------------------------------------- changes

static func _gold(gs, i: int, n: int, lines: Array[String]) -> void:
	var p = gs.players[i]
	var before: int = p.money
	p.money = maxi(0, p.money + n)
	var got: int = p.money - before
	if n > 0:
		lines.append("%s receives %d gold." % [p.name, got])
	elif got < 0:
		lines.append("%s pays %d gold." % [p.name, -got])
	else:
		lines.append("%s has no gold to pay." % p.name)


static func _points(gs, i: int, n: int, lines: Array[String]) -> void:
	var p = gs.players[i]
	p.card_points += n
	lines.append("%s %s %d point%s." % [p.name, "gains" if n > 0 else "loses", absi(n), "" if absi(n) == 1 else "s"])


static func _steal(gs, me: int, from: String, n: int, lines: Array[String]) -> void:
	var payers: Array[int] = []
	if from == "richest":
		var best := -1
		for i in gs.players.size():
			if i != me and (best < 0 or gs.players[i].money > gs.players[best].money):
				best = i
		if best >= 0 and gs.players[best].money >= gs.players[me].money:
			payers.append(best)
	else:
		for i in gs.players.size():
			if i != me:
				payers.append(i)
	if payers.is_empty():
		lines.append("Nobody can pay %s, so nothing happens." % gs.players[me].name)
	for i in payers:
		var paid := mini(n, gs.players[i].money)
		gs.players[i].money -= paid
		gs.players[me].money += paid
		lines.append("%s pays %d gold to %s." % [gs.players[i].name, paid, gs.players[me].name])


static func _transfer(gs, n: int, lines: Array[String]) -> void:
	var rich := 0
	var poor := 0
	for i in gs.players.size():
		if gs.players[i].money > gs.players[rich].money:
			rich = i
		if gs.players[i].money < gs.players[poor].money:
			poor = i
	if rich == poor or gs.players[rich].money == gs.players[poor].money:
		lines.append("Everyone has the same gold, so nothing happens.")
		return
	var moved := mini(n, gs.players[rich].money)
	gs.players[rich].money -= moved
	gs.players[poor].money += moved
	lines.append("%s gives %d gold to %s." % [gs.players[rich].name, moved, gs.players[poor].name])


## Removes `n` random tiles of the given kinds from a player's mat. A human planner (when the game
## lets players pick) chooses them instead, unless every tile of that kind has to go anyway.
static func _lose(gs, me: int, kinds: Array, n: int, lines: Array[String]) -> void:
	var p = gs.players[me]
	if gs.players_pick_losses and not p.is_bot() and _loseable(p.cells, kinds).size() > n:
		gs.pending_losses.append({"kinds": kinds, "n": n})
		lines.append("%s chooses %s to lose." % [p.name, _a(kinds_name(kinds), n)])
		return
	var lost := 0
	for k in n:
		var spots := _loseable(p.cells, kinds)
		if spots.is_empty():
			break
		var at: int = spots[gs.card_rng.randi() % spots.size()]
		lines.append("%s loses %s." % [p.name, _a(TileDefs.display_name(p.cells[at]).to_lower(), 1)])
		Grid.remove(p.cells, at)
		lost += 1
	if lost == 0:
		lines.append("%s has nothing of that kind to lose." % p.name)


## "road", "trees" or "kiosk or coffee shop or restaurant": what a loss of these kinds is called.
static func kinds_name(kinds: Array) -> String:
	if kinds == [TileDefs.Kind.ROAD]:
		return "road"
	var names: Array[String] = []
	for k in kinds:
		names.append(TileDefs.display_name({"kind": k}).to_lower())
	return " or ".join(names)


## "a road tile" / "2 road tiles": for the line that tells a planner what to pick.
static func describe_loss(kinds: Array, n: int) -> String:
	var name := kinds_name(kinds)
	return ("a %s tile" % name) if n == 1 else "%d %s tiles" % [n, name]


static func _a(name: String, n: int) -> String:
	return ("a " + name) if n == 1 else "%d %s tiles" % [n, name]


static func _group(kinds: Array) -> String:
	if kinds == CardDefs.HOMES:
		return "Homes"
	if kinds == CardDefs.GREEN:
		return "Parks and trees"
	if kinds == CardDefs.SERVICES:
		return "Shops and services"
	if kinds == CardDefs.STUDENT_HOMES:
		return "Student residences"
	if kinds == [TileDefs.Kind.TREES]:
		return "Trees"
	return "These tiles"
