extends RefCounted
## Turn flow, shop and bank for one local game (concept doc: How a Game Flows,
## Bank, Construction Site, Player Mat, Free roads, Balance for fewer players).

const TileDefs = preload("res://scripts/core/tile_defs.gd")
const Scoring = preload("res://scripts/core/scoring.gd")

const ROUNDS := 4
const BUYS_PER_TURN := 2
const START_MONEY := 20
const FREE_ROADS := 2
const LOAN_AMOUNT := 10
const MAT_CELLS := 16
const MAX_PLAYERS := 4
const REMOVED_PER_MISSING_PLAYER := 4


class PlayerData:
	var name := ""
	var color_index := 0
	var money := 0
	var free_roads := 0
	var loans := 0
	var cells: Array = []
	## 0 for a human, otherwise Bot.EASY / MEDIUM / HARD.
	var bot_level := 0

	func is_bot() -> bool:
		return bot_level > 0


var players: Array[PlayerData] = []
## 36 slots; null once bought or removed.
var shop: Array = []
## True for slots emptied by the fewer-players rule.
var removed: Array[bool] = []
var round_number := 1
## Position within the current round's turn order.
var turn := 0
## Player indexes in the order they play this round.
var order: Array[int] = []
var purchases := 0
var game_over := false
var rng := RandomNumberGenerator.new()


func setup(names: Array, color_indices: Array, seed_value := -1, bot_levels: Array = []) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	players.clear()
	for i in names.size():
		var p := PlayerData.new()
		p.name = names[i]
		p.color_index = color_indices[i]
		p.money = START_MONEY
		p.free_roads = FREE_ROADS
		p.bot_level = bot_levels[i] if i < bot_levels.size() else 0
		p.cells.resize(MAT_CELLS)
		players.append(p)

	_stock_shop(MAX_PLAYERS - names.size())

	round_number = 1
	turn = 0
	purchases = 0
	game_over = false
	_plan_order()


## Lays the 36 tiles out sorted by kind, so identical tiles sit next to each other.
## The fewer-players rule drops random tiles first; their locked slots go to the end.
func _stock_shop(missing_players: int) -> void:
	var bag := TileDefs.full_bag()
	_shuffle(bag)
	var locked := missing_players * REMOVED_PER_MISSING_PLAYER
	bag = bag.slice(locked)
	bag.sort_custom(func(a, b):
		if a["kind"] != b["kind"]:
			return a["kind"] < b["kind"]
		return a["variant"] < b["variant"])
	shop = bag
	removed.clear()
	removed.resize(TileDefs.BAG_SIZE)
	for i in TileDefs.BAG_SIZE:
		removed[i] = i >= bag.size()
	shop.resize(TileDefs.BAG_SIZE)


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


## Round 1 is drawn at random, so no seat is always first. After that the city with the fewest
## points so far picks first, which keeps the early shop picks from piling up with whoever
## leads. Ties go to whoever picked later in the previous round.
func _plan_order() -> void:
	var previous := order.duplicate()
	var seats: Array[int] = []
	for i in players.size():
		seats.append(i)
	if round_number == 1:
		_shuffle(seats)
	else:
		var points := {}
		for i in seats:
			points[i] = score(i)["total"]
		seats.sort_custom(func(a, b):
			if points[a] != points[b]:
				return points[a] < points[b]
			return previous.find(a) > previous.find(b))
	order = seats


func available_costs() -> Array[int]:
	var costs: Array[int] = []
	for t in shop:
		if t != null:
			costs.append(TileDefs.cost(t["kind"]))
	costs.sort()
	return costs


func buys_left() -> int:
	return mini(BUYS_PER_TURN - purchases, available_costs().size())


func cheapest_total(count: int) -> int:
	var costs := available_costs()
	var total := 0
	for i in mini(count, costs.size()):
		total += costs[i]
	return total


func can_afford(slot: int) -> bool:
	return slot >= 0 and slot < shop.size() and shop[slot] != null \
		and current_player().money >= TileDefs.cost(shop[slot]["kind"])


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


func can_place(cell: int) -> bool:
	return cell >= 0 and cell < MAT_CELLS and current_player().cells[cell] == null


func can_buy() -> bool:
	return not game_over and buys_left() > 0


func buy_and_place(slot: int, cell: int) -> bool:
	if not can_buy() or not can_afford(slot) or not can_place(cell):
		return false
	var tile: Dictionary = shop[slot]
	current_player().money -= TileDefs.cost(tile["kind"])
	current_player().cells[cell] = tile
	shop[slot] = null
	purchases += 1
	return true


func place_free_road(cell: int) -> bool:
	if game_over or current_player().free_roads <= 0 or not can_place(cell):
		return false
	var road := TileDefs.make(TileDefs.Kind.ROAD)
	road["free"] = true
	current_player().cells[cell] = road
	current_player().free_roads -= 1
	return true


func can_end_turn() -> bool:
	return not game_over and buys_left() <= 0


## Returns "turn", "round" or "game_over" ("" if the turn cannot end yet).
func end_turn() -> String:
	if not can_end_turn():
		return ""
	purchases = 0
	turn += 1
	if turn < players.size():
		return "turn"
	turn = 0
	if round_number >= ROUNDS:
		game_over = true
		return "game_over"
	round_number += 1
	_plan_order()
	return "round"


func is_game_over() -> bool:
	return game_over


func score(index: int) -> Dictionary:
	return Scoring.evaluate(players[index].cells, players[index].loans)
