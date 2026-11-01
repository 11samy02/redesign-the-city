extends "res://tests/test_base.gd"

const GameState = preload("res://scripts/core/game_state.gd")
const Scoring = preload("res://scripts/core/scoring.gd")

const K := TileDefs.Kind


func _new_game(n: int, seed_value := 7) -> GameState:
	var names := ["Ana", "Ben", "Cleo", "Dimitri"].slice(0, n)
	var gs := GameState.new()
	gs.setup(names, [0, 1, 2, 3].slice(0, n), seed_value)
	return gs


## Index of the first stack of `kind` (and `variant`, unless -1) that still has tiles.
func _slot(gs: GameState, kind: int, variant := -1) -> int:
	for i in gs.shop.size():
		var s: Dictionary = gs.shop[i]
		if s["count"] > 0 and s["tile"]["kind"] == kind and (variant < 0 or s["tile"]["variant"] == variant):
			return i
	return -1


func _slot_with_cost(gs: GameState, cost: int) -> int:
	for i in gs.shop.size():
		if gs.stack_count(i) > 0 and TileDefs.tile_cost(gs.shop[i]["tile"]) == cost:
			return i
	return -1


func test_setup_gives_each_player_the_starting_kit() -> void:
	var gs := _new_game(4)
	eq(gs.players.size(), 4, "players")
	for p in gs.players:
		eq(p.money, 100, "everyone starts with 100 gold, whatever their seat")
		eq(p.free_roads, 4, "free roads")
		eq(p.loans, 0, "loans")
		eq(p.cells.size(), 49, "mat size")
	eq(GameState.ROUNDS, 8, "rounds")
	eq(GameState.BUYS_PER_TURN, 4, "buys per turn")
	eq(GameState.LOAN_AMOUNT, 20, "loan")
	eq(gs.round_number, 1, "round")
	eq(gs.current_index(), gs.turn_order()[0], "first player in the order")


func test_shop_for_four_players_holds_222_tiles_in_stacks() -> void:
	var gs := _new_game(4)
	eq(gs.tiles_left(), 222, "tiles")
	var counts := {}
	for s in gs.shop:
		counts[s["tile"]["kind"]] = counts.get(s["tile"]["kind"], 0) + s["count"]
		eq(s["start"], s["count"], "a fresh stack is full")
	eq(counts[K.APT_S], 18, "small apartments")
	eq(counts[K.UNIVERSITY], 5, "universities")
	eq(counts[K.ROAD], 38, "roads")
	check(gs.shop.size() >= 28 and gs.shop.size() <= 36, "about 32 stacks, got %d" % gs.shop.size())


func test_stacks_are_sorted_by_shop_group() -> void:
	for n in [2, 3, 4]:
		var gs := _new_game(n)
		var last := -1
		for s in gs.shop:
			var key := TileDefs.sort_key(s["tile"])
			check(key > last, "%d players: stacks stay in group order and are unique" % n)
			last = key


func test_fewer_players_remove_fifty_five_tiles_each() -> void:
	eq(_new_game(3).tiles_left(), 167, "3 players")
	eq(_new_game(2).tiles_left(), 112, "2 players")
	for n in [2, 3]:
		for s in _new_game(n).shop:
			check(s["start"] > 0, "%d players: no empty stacks are created" % n)


func test_every_player_count_can_afford_the_whole_game_in_tiles() -> void:
	for n in [2, 3, 4]:
		check(_new_game(n).tiles_left() >= n * GameState.ROUNDS * GameState.BUYS_PER_TURN, "%d players: enough tiles" % n)


func test_buying_pays_places_and_shrinks_the_stack() -> void:
	var gs := _new_game(4)
	var slot := _slot(gs, K.COFFEE_SHOP)
	var before := gs.stack_count(slot)
	check(gs.buy_and_place(slot, 5), "purchase should succeed")
	var p = gs.current_player()
	eq(p.money, 122, "a coffee shop costs 3")
	eq(gs.stack_count(slot), before - 1, "stack shrinks")
	eq(p.cells[5]["kind"], K.COFFEE_SHOP, "tile on mat")
	eq(gs.purchases, 1, "purchases")
	check(gs.shop[slot] != null, "the stack stays in the list")


func test_a_household_variant_is_kept_when_bought() -> void:
	var gs := _new_game(4)
	var slot := _slot(gs, K.APT_L, 1)
	check(gs.buy_and_place(slot, 0), "buy three generations")
	eq(TileDefs.household_name(gs.current_player().cells[0]), "Three generations", "household")


func test_an_empty_stack_cannot_be_bought_and_stays_listed() -> void:
	var gs := _new_game(4)
	var slot := _slot(gs, K.UNIVERSITY)
	gs.shop[slot]["count"] = 0
	check(gs.stack_tile(slot) == null, "no tile")
	check(not gs.can_afford(slot), "cannot afford an empty stack")
	check(not gs.buy_and_place(slot, 0), "cannot buy")
	eq(gs.shop[slot]["start"], 5, "start is remembered")


func test_cannot_buy_what_you_cannot_afford() -> void:
	var gs := _new_game(4)
	gs.current_player().money = 1
	var slot := _slot(gs, K.HOSPITAL)
	check(not gs.buy_and_place(slot, 0), "purchase should fail")
	eq(gs.current_player().money, 1, "money unchanged")
	eq(gs.stack_count(slot), 5, "tile still in shop")


func test_cannot_build_on_an_occupied_lot() -> void:
	var gs := _new_game(4)
	check(gs.buy_and_place(_slot(gs, K.TREES), 0), "first")
	check(not gs.buy_and_place(_slot(gs, K.TREES), 0), "second on same lot")


func test_four_purchases_per_turn() -> void:
	var gs := _new_game(4)
	check(not gs.can_end_turn(), "cannot end before buying")
	eq(gs.buys_left(), 4, "buys at the start")
	for i in 3:
		check(gs.buy_and_place(_slot(gs, K.TREES), i), "buy %d" % i)
		check(not gs.can_end_turn(), "still buys left after %d" % (i + 1))
	check(gs.buy_and_place(_slot(gs, K.TREES), 3), "fourth")
	check(gs.can_end_turn(), "can end after four")
	check(not gs.buy_and_place(_slot(gs, K.TREES), 4), "fifth blocked")


func test_street_types_have_their_own_price_and_art() -> void:
	eq(TileDefs.tile_cost(TileDefs.make(K.ROAD, 0)), 1, "plain road")
	eq(TileDefs.tile_cost(TileDefs.make(K.ROAD, 1)), 3, "shaded street")
	eq(TileDefs.art_path(TileDefs.make(K.ROAD, 1), 5), "res://assets/tiles/road_shaded_5.svg", "art")
	var gs := _new_game(4)
	var before: int = gs.current_player().money
	check(gs.buy_and_place(_slot(gs, K.ROAD, 1), 0), "buy the shaded street")
	eq(gs.current_player().money, before - 3, "it costs 3 gold")


func test_pedestrian_street_and_bike_lane_connect_like_a_plain_road() -> void:
	var rows := ["sRRS...", ".......", ".......", ".......", ".......", ".......", "......."]
	var plain := Scoring.evaluate(mat(rows, {0: 0}), 0)
	for variant in [2, 3]:
		var r := Scoring.evaluate(mat(rows, {0: 0, 1: variant}), 0)
		eq(r["pollution"], plain["pollution"], "pollution with street %d" % variant)
		eq(r["apartments"][0]["routes"].size(), 1, "the home still reaches the supermarket over street %d" % variant)
		check(not TileDefs.street_suits(TileDefs.make(K.ROAD, variant)).is_empty(), "street %d lists the roles it suits" % variant)


func test_shaded_street_is_a_road_with_trees_built_in() -> void:
	var rows := ["sRRRS..", ".......", ".......", ".......", ".......", ".......", "......."]
	var plain := Scoring.evaluate(mat(rows, {0: 0}), 0)
	var cells := mat(rows, {0: 0, 2: TileDefs.STREET_SHADED})
	var r := Scoring.evaluate(cells, 0)
	eq(plain["apartments"][0]["members"][0]["heat"], 1, "the plain 3-road walk is hot")
	eq(r["apartments"][0]["members"][0]["heat"], 0, "a shaded street cools the walk")
	eq(r["pollution"], plain["pollution"] - 1, "pollution -1, like trees")
	check(r["shaded"][2], "it is shaded itself")
	check(r["shaded"][1], "and shades the road next to it")
	check(TileDefs.is_tree_like(cells[2]), "counts as trees")
	check(not TileDefs.is_tree_like(TileDefs.make(K.ROAD)), "a plain road is not trees")


## Every planner in turn buys four plain roads and builds them on the bottom row, which leaves
## every score untouched.
func _finish_round_with_roads(gs: GameState) -> void:
	for t in gs.players.size():
		for cell in [42, 43, 44, 45]:
			var slot := _slot(gs, K.ROAD, 0)
			check(gs.buy_and_place(slot, cell), "road purchase")
		gs.end_turn()


func test_round_one_order_follows_the_seats() -> void:
	for seed_value in 10:
		eq(_new_game(4, seed_value).turn_order(), [0, 1, 2, 3], "seat order in round 1")
	var gs := _new_game(4)
	var events := []
	for i in 4:
		for c in 4:
			gs.buy_and_place(_slot(gs, K.ROAD, 0), c)
		events.append(gs.end_turn())
	eq(events, ["turn", "turn", "turn", "round"], "events")
	eq(gs.round_number, 2, "round")


func test_later_rounds_start_with_the_fewest_points() -> void:
	var gs := _new_game(3)
	# nothing is within reach, so every home is unhappy: the bigger the home, the lower the score
	gs.players[0].cells[0] = TileDefs.make(K.APT_S)
	gs.players[2].cells[0] = TileDefs.make(K.APT_L)
	_finish_round_with_roads(gs)
	eq(gs.round_number, 2, "round 2")
	eq(gs.turn_order(), [2, 0, 1], "lowest score first")
	eq(gs.current_index(), 2, "the order drives who plays")


func test_ties_go_to_whoever_picked_later_last_round() -> void:
	var gs := _new_game(4)
	var first_round := gs.turn_order()
	_finish_round_with_roads(gs)
	first_round.reverse()
	eq(gs.turn_order(), first_round, "all tied: reverse of last round")


func test_loan_gives_twenty_and_is_only_offered_when_short() -> void:
	var gs := _new_game(4)
	check(not gs.can_take_loan(), "rich player cannot loan")
	check(not gs.take_loan(), "loan refused")
	gs.current_player().money = 3
	check(gs.can_take_loan(), "3 gold cannot pay for the 4 cheapest tiles (1 each)")
	check(gs.take_loan(), "loan granted")
	eq(gs.current_player().money, 23, "money after loan")
	eq(gs.current_player().loans, 1, "loans")
	gs.current_player().money = 4
	gs.current_player().loans = 0
	check(not gs.can_take_loan(), "4 gold pays for four 1-gold tiles")


func test_loan_after_a_purchase_checks_the_tiles_still_to_buy() -> void:
	var gs := _new_game(4)
	gs.buy_and_place(_slot(gs, K.TREES), 0)
	gs.current_player().money = 3
	check(not gs.can_take_loan(), "3 gold still pays for the 3 buys left")
	gs.current_player().money = 2
	check(gs.can_take_loan(), "2 gold does not")


func test_the_loan_penalty_grows_with_every_loan() -> void:
	var gs := _new_game(4)
	eq(gs.next_loan_penalty(), 6, "first loan")
	gs.current_player().money = 0
	check(gs.take_loan(), "first")
	eq(gs.next_loan_penalty(), 9, "second loan")
	gs.current_player().money = 0
	check(gs.take_loan(), "second")
	eq(gs.next_loan_penalty(), 12, "third loan")
	eq(gs.score(gs.current_index())["loan_penalty"], 15, "two loans cost 15 points")


func test_free_roads_do_not_count_as_purchases() -> void:
	var gs := _new_game(4)
	for c in [3, 7, 11, 15]:
		check(gs.place_free_road(c), "free road at %d" % c)
	check(not gs.place_free_road(19), "no fifth free road")
	var p = gs.current_player()
	eq(p.free_roads, 0, "free roads left")
	eq(p.money, 100, "free roads cost nothing")
	eq(gs.purchases, 0, "not a purchase")
	eq(p.cells[3]["kind"], K.ROAD, "road placed")
	check(p.cells[3].get("free", false), "marked free")


func test_full_games_end_after_eight_rounds() -> void:
	for n in [2, 3, 4]:
		var gs := _new_game(n, 100 + n)
		var rng := RandomNumberGenerator.new()
		rng.seed = 42
		var last := ""
		var guard := 0
		while not gs.is_game_over() and guard < 200:
			guard += 1
			while gs.purchases < GameState.BUYS_PER_TURN:
				while gs.can_take_loan():
					gs.take_loan()
				var slots := []
				for i in gs.shop.size():
					if gs.can_afford(i):
						slots.append(i)
				var p = gs.current_player()
				var empty := []
				for c in 49:
					if p.cells[c] == null:
						empty.append(c)
				check(gs.buy_and_place(slots[rng.randi() % slots.size()], empty[rng.randi() % empty.size()]), "bot purchase")
			last = gs.end_turn()
		eq(last, "game_over", "%d players: last event" % n)
		check(gs.is_game_over(), "%d players: game over" % n)
		eq(gs.round_number, 8, "%d players: round counter" % n)
		for p in gs.players:
			var bought := 0
			for t in p.cells:
				if t != null and not t.get("free", false):
					bought += 1
			eq(bought, 32, "%d players: 32 tiles bought" % n)


func test_one_human_against_bots_also_reorders_after_round_one() -> void:
	var gs := GameState.new()
	gs.setup(["Ana", "Bot1", "Bot2"], [0, 1, 2], 7, [0, 1, 1])
	gs.players[0].cells[0] = TileDefs.make(K.APT_S)
	gs.players[2].cells[0] = TileDefs.make(K.APT_L)
	_finish_round_with_roads(gs)
	eq(gs.round_number, 2, "round 2")
	eq(gs.turn_order(), [2, 0, 1], "lowest score first even with one human")
