extends RefCounted
## Turn flow, shop and bank for one local game: 8 rounds, 4 buys per turn, a fixed purse of gold
## and a construction site of stacked tiles.

const TileDefs = preload("res://scripts/core/tile_defs.gd")
const Scoring = preload("res://scripts/core/scoring.gd")
const CircumstanceDefs = preload("res://scripts/core/circumstance_defs.gd")
const CardDefs = preload("res://scripts/core/card_defs.gd")
const CardEffects = preload("res://scripts/core/card_effects.gd")
const Grid = preload("res://scripts/core/grid.gd")

const ROUNDS := 8
const BUYS_PER_TURN := 4
const START_MONEY := 100
const FREE_ROADS := 4
const LOAN_AMOUNT := 20
const MAT_CELLS := Grid.CELLS
const MAX_PLAYERS := 4
const REMOVED_PER_MISSING_PLAYER := 55


class PlayerData:
	var name := ""
	var color_index := 0
	var money := 0
	var free_roads := 0
	var loans := 0
	var cells: Array = []
	## 0 for a human, otherwise Bot.EASY / MEDIUM / HARD.
	var bot_level := 0
	## Points won or lost through event and penalty cards; they count in the score.
	var card_points := 0
	## Free tiles from event cards, waiting to be placed on the mat (see place_bonus_tile).
	var bonus_tiles: Array = []
	## True once the player has used their one tile replacement (see replace_tile).
	var replaced := false

	func is_bot() -> bool:
		return bot_level > 0


var players: Array[PlayerData] = []
## The prefixed mat everyone started on, or null for empty mats.
var mat_preset = null
## The construction site: one stack per kind of tile, as {"tile": Dictionary, "count": int,
## "start": int}. A bought-out stack stays in the list with count 0.
var shop: Array = []
var round_number := 1
## Position within the current round's turn order.
var turn := 0
## Player indexes in the order they play this round.
var order: Array[int] = []
var purchases := 0
var game_over := false
var rng := RandomNumberGenerator.new()
## The hidden circumstances planned for this game, one per round. Hidden: only `revealed` is public.
var circumstance_plan: Array = []
## Hidden circumstance ids revealed so far, oldest first. They count in every score.
var revealed: Array = []
## One entry per revealed card: { "id", "round", "gold": [change per planner] }.
var circumstance_log: Array[Dictionary] = []

## The event and penalty decks, face down: card ids, next card last.
var card_decks := {CardDefs.EVENT: [], CardDefs.PENALTY: []}
## Own random stream for the coin, the shuffles and "a random tile", so the shop stays as it was.
var card_rng := RandomNumberGenerator.new()
## This turn's card: {"id", "type", "coin", "resolved", "lines"}. Empty before the flip.
var turn_card := {}
var _card_drawn := false
## This turn only: price changes from cards, and how many more or fewer tiles may be bought.
var turn_discounts: Array = []
var turn_markups: Array = []
var buy_bonus := 0
## Every card drawn this game, oldest first: {"id", "type", "coin", "round", "player", "lines", "choice",
## "gold", "points"}. "gold" and "points" hold what the card changed for every planner (by seat), so the
## end screen can show why a score came out the way it did. "choice" is the option taken, or "".
var card_log: Array[Dictionary] = []
## When true, a human planner chooses which tiles a penalty takes (see lose_tile_at); otherwise they
## are picked at random. Bots always lose random tiles.
var players_pick_losses := false
## What each planner's city looked like when every round ended: city_history[seat][round - 1] =
## {"cells", "loans", "card_points", "money"}. Round 0, the empty mat, is not stored.
var city_history: Array = []
## Tiles the current planner still has to choose to lose: [{"kinds": Array, "n": int}].
var pending_losses: Array = []


## `mat` is a PlayerMatPreset (see mat_library.gd): every planner starts with its tiles already built,
## and those tiles can never be replaced or lost. Without one the mats start empty.
func setup(names: Array, color_indices: Array, seed_value := -1, bot_levels: Array = [], mat = null) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	players.clear()
	city_history = []
	for i in names.size():
		city_history.append([])
		var p := PlayerData.new()
		p.name = names[i]
		p.color_index = color_indices[i]
		p.money = START_MONEY
		p.free_roads = FREE_ROADS
		p.bot_level = bot_levels[i] if i < bot_levels.size() else 0
		p.cells = mat.build_cells() if mat != null else Grid.empty()
		players.append(p)
	mat_preset = mat

	_stock_shop(MAX_PLAYERS - names.size())
	_plan_circumstances(seed_value)
	_plan_cards(seed_value)

	round_number = 1
	turn = 0
	purchases = 0
	game_over = false
	_plan_order()


## Stacks the tiles by kind, in shop order. The fewer-players rule drops random tiles first.
func _stock_shop(missing_players: int) -> void:
	var bag := TileDefs.full_bag()
	_shuffle(bag)
	bag = bag.slice(missing_players * REMOVED_PER_MISSING_PLAYER)
	var by_key := {}
	for t in bag:
		var key := TileDefs.sort_key(t)
		if not by_key.has(key):
			by_key[key] = {"tile": t, "count": 0, "start": 0}
		by_key[key]["count"] += 1
		by_key[key]["start"] += 1
	var keys := by_key.keys()
	keys.sort()
	shop = []
	for k in keys:
		shop.append(by_key[k])


## Picks one card per round from the deck, without repeats. Uses its own random stream so the
## shop layout for a given seed does not change.
func _plan_circumstances(seed_value: int) -> void:
	var circumstances_rng := RandomNumberGenerator.new()
	if seed_value >= 0:
		circumstances_rng.seed = seed_value + 7919
	else:
		circumstances_rng.randomize()
	var deck: Array = CircumstanceDefs.IDS.duplicate()
	for i in range(deck.size() - 1, 0, -1):
		var j := circumstances_rng.randi_range(0, i)
		var tmp = deck[i]
		deck[i] = deck[j]
		deck[j] = tmp
	circumstance_plan = deck.slice(0, ROUNDS)
	revealed = []
	circumstance_log = []


## True while this round's card has not been turned over yet.
func has_pending_circumstance() -> bool:
	return not game_over and revealed.size() < mini(round_number, circumstance_plan.size())


## Turns over this round's card and applies its gold effect to every planner (never below 0).
## Returns the log entry, or {} when this round's card is already out.
func reveal_circumstance() -> Dictionary:
	if not has_pending_circumstance():
		return {}
	var id: String = circumstance_plan[revealed.size()]
	var gold: Array = []
	for p in players:
		var change := maxi(CircumstanceDefs.gold_change(id, p.cells), -p.money)
		p.money += change
		gold.append(change)
	revealed.append(id)
	var entry := {"id": id, "round": round_number, "gold": gold}
	circumstance_log.append(entry)
	return entry


## The card revealed most recently, or "" before the first one.
func current_circumstance() -> String:
	return "" if revealed.is_empty() else revealed[revealed.size() - 1]


func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


func current_index() -> int:
	return order[turn]


func current_player() -> PlayerData:
	return players[current_index()]


func turn_order() -> Array[int]:
	return order.duplicate()


## Round 1 follows the order the players were added. After that the city with the fewest points
## so far picks first, so whoever leads picks later and the early shop picks do not pile up with
## them. Ties go to whoever picked later in the previous round.
func _plan_order() -> void:
	var previous := order.duplicate()
	var seats: Array[int] = []
	for i in players.size():
		seats.append(i)
	if round_number == 1:
		pass
	else:
		var points := {}
		for i in seats:
			points[i] = score(i)["total"]
		seats.sort_custom(func(a, b):
			if points[a] != points[b]:
				return points[a] < points[b]
			return previous.find(a) > previous.find(b))
	order = seats


## The tile of a stack, or null when the stack is out of range or bought out.
func stack_tile(slot: int):
	if slot < 0 or slot >= shop.size() or shop[slot]["count"] <= 0:
		return null
	return shop[slot]["tile"]


func stack_count(slot: int) -> int:
	return 0 if slot < 0 or slot >= shop.size() else shop[slot]["count"]


func tiles_left() -> int:
	var total := 0
	for s in shop:
		total += s["count"]
	return total


## What a tile costs the current player right now: its price, less any discounts and plus any
## markups from this turn's card (never below zero).
func price_of(tile: Dictionary) -> int:
	var price := TileDefs.tile_cost(tile)
	for d in turn_discounts:
		if d["kinds"].is_empty() or tile["kind"] in d["kinds"]:
			if d["price"] >= 0:
				price = mini(price, d["price"])
			else:
				price -= d["by"]
	for m in turn_markups:
		if m["kinds"].is_empty() or tile["kind"] in m["kinds"]:
			price += m["by"]
	return maxi(0, price)


## How many tiles the current player must buy this turn: 4, plus or minus cards, but at least 1.
func buy_limit() -> int:
	return maxi(1, BUYS_PER_TURN + buy_bonus)


## The price of every tile still in the shop (as many entries as a turn could buy of it), cheapest first.
func available_costs() -> Array[int]:
	var costs: Array[int] = []
	for s in shop:
		for k in mini(s["count"], buy_limit()):
			costs.append(price_of(s["tile"]))
	costs.sort()
	return costs


func buys_left() -> int:
	return mini(buy_limit() - purchases, available_costs().size())


func cheapest_total(count: int) -> int:
	var costs := available_costs()
	var total := 0
	for i in mini(count, costs.size()):
		total += costs[i]
	return total


func can_afford(slot: int) -> bool:
	var t = stack_tile(slot)
	return t != null and current_player().money >= price_of(t)


## Only a player who cannot afford the tiles they still have to buy may borrow.
func can_take_loan() -> bool:
	if game_over or buys_left() <= 0:
		return false
	return current_player().money < cheapest_total(buys_left())


func take_loan() -> bool:
	if not can_take_loan():
		return false
	current_player().money += LOAN_AMOUNT
	current_player().loans += 1
	return true


## Points the player's next loan will cost at final scoring.
func next_loan_penalty() -> int:
	var loans := current_player().loans
	return Scoring.loan_penalty(loans + 1) - Scoring.loan_penalty(loans)


## Can a tile covering `size` x `size` squares go with its top-left square on `cell`?
func can_place(cell: int, size := 1) -> bool:
	return Grid.fits(current_player().cells, cell, size)


func can_buy() -> bool:
	return not game_over and buys_left() > 0


func buy_and_place(slot: int, cell: int) -> bool:
	if not can_buy() or not can_afford(slot) or not can_place(cell, TileDefs.footprint(shop[slot]["tile"])):
		return false
	var tile: Dictionary = shop[slot]["tile"].duplicate()
	current_player().money -= price_of(tile)
	Grid.place(current_player().cells, cell, tile)
	shop[slot]["count"] -= 1
	purchases += 1
	return true


## Whether the picked shop tile may take the place of the tile on `cell` (any of its squares): once per
## planner and game, it must be bought like any tile (so it needs a buy and the gold), and only a tile that
## came out of the shop can go back into it (free roads, event gifts and prefixed tiles cannot). The new
## tile goes where the planner points (`cell`, one of the old tile's squares) as long as it fits once the old tile
## is gone, so a small tile can take any square of a bigger one (see replace_anchor).
func can_replace(slot: int, cell: int) -> bool:
	var p := current_player()
	if p.replaced or not can_buy() or not can_afford(slot) or cell < 0 or cell >= MAT_CELLS:
		return false
	var anchor := Grid.anchor_of(p.cells, cell)
	if anchor < 0:
		return false
	var old: Dictionary = p.cells[anchor]
	if old.get("free", false) or old.get("fixed", false):
		return false
	if TileDefs.sort_key(old) == TileDefs.sort_key(shop[slot]["tile"]) or _stack_of(old) < 0:
		return false
	return replace_anchor(slot, cell) >= 0


## Buys the shop tile onto an occupied lot; the tile that stood there goes back into the construction
## site. Counts as one of the turn's buys. Returns the old tile, or {} when it is not allowed.
func replace_tile(slot: int, cell: int) -> Dictionary:
	if not can_replace(slot, cell):
		return {}
	var p := current_player()
	var anchor := Grid.anchor_of(p.cells, cell)
	var at := replace_anchor(slot, cell)
	var old: Dictionary = p.cells[anchor]
	var tile: Dictionary = shop[slot]["tile"].duplicate()
	p.money -= price_of(tile)
	Grid.remove(p.cells, anchor)
	Grid.place(p.cells, at, tile)
	shop[slot]["count"] -= 1
	shop[_stack_of(old)]["count"] += 1
	p.replaced = true
	purchases += 1
	return old


## Where the shop tile in `slot` would stand if it replaced the tile covering `cell`, as its top-left square, or -1
## when it does not fit. A tile at least as big as the old one keeps the old tile's top-left square when it fits
## there; otherwise (and for a smaller tile) it takes the squares around the one the planner pointed at, so a
## small tile can be put on any square of a bigger tile.
func replace_anchor(slot: int, cell: int) -> int:
	var p := current_player()
	var anchor := Grid.anchor_of(p.cells, cell)
	if anchor < 0:
		return -1
	var n := TileDefs.footprint(shop[slot]["tile"])
	var trial := p.cells.duplicate()
	Grid.remove(trial, anchor)
	if n >= TileDefs.footprint(p.cells[anchor]) and Grid.fits(trial, anchor, n):
		return anchor
	return Grid.find_anchor(trial, cell, n)


func _stack_of(tile: Dictionary) -> int:
	var key := TileDefs.sort_key(tile)
	for k in shop.size():
		if TileDefs.sort_key(shop[k]["tile"]) == key:
			return k
	return -1


## The loss the current planner is choosing right now: {"kinds", "n"}, or {} when there is none.
func pending_loss() -> Dictionary:
	return pending_losses[0] if not pending_losses.is_empty() else {}


## The tiles (their top-left squares) the current planner may pick for the loss they are choosing.
## Prefixed tiles can never be lost.
func loss_cells() -> Array[int]:
	var out: Array[int] = []
	var loss := pending_loss()
	if loss.is_empty():
		return out
	var cells: Array = current_player().cells
	for c in Grid.anchors(cells):
		if cells[c]["kind"] in loss["kinds"] and not cells[c].get("fixed", false):
			out.append(c)
	return out


## The planner gives up the tile on `cell` (any square of it) for the loss they are choosing. Returns that
## tile, or {} when the lot is not a valid pick.
func lose_tile_at(cell: int) -> Dictionary:
	var anchor := Grid.anchor_of(current_player().cells, cell)
	if anchor < 0 or not loss_cells().has(anchor):
		return {}
	var p := current_player()
	var lost: Dictionary = p.cells[anchor]
	Grid.remove(p.cells, anchor)
	pending_losses[0]["n"] -= 1
	if pending_losses[0]["n"] <= 0 or loss_cells().is_empty():
		pending_losses.pop_front()
	return lost


func place_free_road(cell: int) -> bool:
	if game_over or current_player().free_roads <= 0 or not can_place(cell):
		return false
	var road := TileDefs.make(TileDefs.Kind.ROAD)
	road["free"] = true
	Grid.place(current_player().cells, cell, road)
	current_player().free_roads -= 1
	return true


## Places the `index`-th free tile an event card gave the current player. Costs nothing and is not a purchase.
func place_bonus_tile(index: int, cell: int) -> bool:
	var p := current_player()
	if game_over or index < 0 or index >= p.bonus_tiles.size() or not can_place(cell, TileDefs.footprint(p.bonus_tiles[index])):
		return false
	var tile: Dictionary = p.bonus_tiles[index]
	tile["free"] = true
	Grid.place(p.cells, cell, tile)
	p.bonus_tiles.remove_at(index)
	return true


func can_end_turn() -> bool:
	return not game_over and buys_left() <= 0


## Returns "turn", "round" or "game_over" ("" if the turn cannot end yet).
func end_turn() -> String:
	if not can_end_turn():
		return ""
	purchases = 0
	reset_turn_state()
	turn += 1
	if turn < players.size():
		return "turn"
	turn = 0
	_record_round()
	if round_number >= ROUNDS:
		game_over = true
		return "game_over"
	round_number += 1
	_plan_order()
	return "round"


## Keeps a copy of every city as the round ends, so the end screen can replay how they grew.
func _record_round() -> void:
	for i in players.size():
		var p := players[i]
		city_history[i].append({"cells": p.cells.duplicate(true), "loans": p.loans, "card_points": p.card_points, "money": p.money})


func is_game_over() -> bool:
	return game_over


func score(index: int) -> Dictionary:
	return Scoring.evaluate(players[index].cells, players[index].loans, revealed, players[index].card_points)


# ================================================================ turn cards

## Shuffles the two decks. Own random stream, so the shop and the hidden deck for a seed stay put.
func _plan_cards(seed_value: int) -> void:
	if seed_value >= 0:
		card_rng.seed = seed_value + 104729
	else:
		card_rng.randomize()
	for type in CardDefs.TYPES:
		var deck: Array = CardDefs.ids(type)
		for i in range(deck.size() - 1, 0, -1):
			var j := card_rng.randi_range(0, i)
			var tmp = deck[i]
			deck[i] = deck[j]
			deck[j] = tmp
		card_decks[type] = deck
	turn_card = {}
	_card_drawn = false
	card_log = []
	reset_turn_state()


## The cards this planner drew, oldest first (entries of `card_log`).
func cards_drawn_by(index: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry in card_log:
		if entry["player"] == index:
			out.append(entry)
	return out


func card_deck_count(type: String) -> int:
	return card_decks[type].size()


## Clears this turn's card and everything it changed for the turn.
func reset_turn_state() -> void:
	turn_card = {}
	_card_drawn = false
	turn_discounts = []
	turn_markups = []
	buy_bonus = 0
	pending_losses = []


## The coin flip at the start of a turn: heads draws an event card, tails a penalty card.
## Returns {"coin", "type", "id"}, or {} when this turn's card is already drawn.
func flip_and_draw() -> Dictionary:
	if _card_drawn or game_over:
		return {}
	var coin := "heads" if card_rng.randf() < 0.5 else "tails"
	var type: String = CardDefs.EVENT if coin == "heads" else CardDefs.PENALTY
	if card_decks[type].is_empty():
		type = CardDefs.PENALTY if type == CardDefs.EVENT else CardDefs.EVENT
	if card_decks[type].is_empty():
		return {}
	var id: String = card_decks[type].pop_back()
	begin_card(id, coin)
	_card_drawn = true
	return {"coin": coin, "type": type, "id": id}


## Makes `id` this turn's card, waiting to be resolved. (flip_and_draw does this for you.)
func begin_card(id: String, coin := "") -> void:
	turn_card = {"id": id, "type": CardDefs.type_of(id), "coin": coin, "resolved": false, "lines": []}


func has_pending_card() -> bool:
	return not turn_card.is_empty() and not turn_card["resolved"]


func card_needs_choice() -> bool:
	return has_pending_card() and CardDefs.info(turn_card["id"])["fx"]["op"] == "choice"


## The options of a choice card: [{"label", "fx", "available"}]. A payment you cannot make is not available.
func card_choice_options() -> Array:
	var out: Array = []
	if turn_card.is_empty():
		return out
	var fx: Dictionary = CardDefs.info(turn_card["id"])["fx"]
	if fx["op"] != "choice":
		return out
	var money: int = current_player().money
	for o in fx["options"]:
		var f: Dictionary = o["fx"]
		var ok := true
		if f["op"] == "gold_self" and f["n"] < 0:
			ok = money >= -f["n"]
		elif f["op"] == "pay_each":
			ok = money >= f["n"] * (players.size() - 1)
		out.append({"label": o["label"], "fx": f, "available": ok})
	return out


## Carries out the card. A choice card needs the index of the chosen option. Returns {"lines", "id",
## "type"}, or {} when there is nothing to resolve or the choice is missing or not available.
func resolve_turn_card(choice := -1) -> Dictionary:
	if not has_pending_card():
		return {}
	var id: String = turn_card["id"]
	var fx: Dictionary = CardDefs.info(id)["fx"]
	var lines: Array[String] = []
	var chosen := ""
	var gold_before: Array[int] = []
	var points_before: Array[int] = []
	for p in players:
		gold_before.append(p.money)
		points_before.append(p.card_points)
	if fx["op"] == "choice":
		var options := card_choice_options()
		if choice < 0 or choice >= options.size() or not options[choice]["available"]:
			return {}
		chosen = options[choice]["label"]
		lines.append("%s chose: %s." % [current_player().name, chosen])
		CardEffects.apply(self, current_index(), options[choice]["fx"], lines)
	else:
		CardEffects.apply(self, current_index(), fx, lines)
	turn_card["resolved"] = true
	turn_card["lines"] = lines
	var gold: Array[int] = []
	var points: Array[int] = []
	for i in players.size():
		gold.append(players[i].money - gold_before[i])
		points.append(players[i].card_points - points_before[i])
	card_log.append({"id": id, "type": turn_card["type"], "coin": turn_card["coin"], "round": round_number,
		"player": current_index(), "lines": lines, "choice": chosen, "gold": gold, "points": points})
	return {"lines": lines, "id": id, "type": turn_card["type"]}
