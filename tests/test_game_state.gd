extends "res://tests/test_base.gd"

const GameState = preload("res://scripts/core/game_state.gd")


func _new_game(n: int, seed_value := 7) -> GameState:
	var names := ["Ana", "Ben", "Cleo", "Dimitri"].slice(0, n)
	var gs := GameState.new()
	gs.setup(names, [0, 1, 2, 3].slice(0, n), seed_value)
	return gs


func _tile_count(gs: GameState) -> int:
	var c := 0
	for t in gs.shop:
		if t != null:
			c += 1
	return c


func _slot_with_cost(gs: GameState, cost: int) -> int:
	for i in gs.shop.size():
		if gs.shop[i] != null and TileDefs.cost(gs.shop[i]["kind"]) == cost:
			return i
	return -1


func test_setup_gives_each_player_the_starting_kit() -> void:
	var gs := _new_game(4)
	eq(gs.players.size(), 4, "players")
	for p in gs.players:
		eq(p.money, 20, "everyone starts with 20 gold, whatever their seat")
		eq(p.free_roads, 2, "free roads")
		eq(p.loans, 0, "loans")
		eq(p.cells.size(), 16, "mat size")
	eq(gs.round_number, 1, "round")
	eq(gs.current_index(), gs.turn_order()[0], "first player in the order")


func test_full_shop_has_the_documented_tile_mix() -> void:
	var gs := _new_game(4)
	eq(gs.shop.size(), 36, "slots")
	var counts := {}
	for t in gs.shop:
		counts[t["kind"]] = counts.get(t["kind"], 0) + 1
	eq(counts[TileDefs.Kind.APT_S], 4, "small apartments")
	eq(counts[TileDefs.Kind.APT_M], 4, "medium apartments")
	eq(counts[TileDefs.Kind.APT_L], 3, "large apartments")
	eq(counts[TileDefs.Kind.AMENITY], 8, "amenities")
	eq(counts[TileDefs.Kind.PARK], 4, "parks")
	eq(counts[TileDefs.Kind.TREES], 5, "trees")
	eq(counts[TileDefs.Kind.ROAD], 8, "roads")


func test_fewer_players_remove_four_tiles_each() -> void:
	eq(_tile_count(_new_game(3)), 32, "3 players")
	eq(_tile_count(_new_game(2)), 28, "2 players")
	var gs := _new_game(2)
	var removed := 0
	for r in gs.removed:
		if r:
			removed += 1
	eq(removed, 8, "removed slots marked")


func test_shop_is_sorted_so_identical_tiles_sit_together() -> void:
	for n in [2, 3, 4]:
		var gs := _new_game(n)
		var last := -1
		var last_variant := -1
		var ended := false
		for i in gs.shop.size():
			var t = gs.shop[i]
			if t == null:
				ended = true
				check(gs.removed[i], "%d players: empty slot %d is a locked one" % [n, i])
				continue
			check(not ended, "%d players: tiles come before the locked slots" % n)
			check(t["kind"] >= last, "%d players: slot %d keeps the kind order" % [n, i])
			if t["kind"] == last:
				check(t["variant"] >= last_variant, "%d players: slot %d keeps the variant order" % [n, i])
			last = t["kind"]
			last_variant = t["variant"]


func test_buying_pays_and_places_the_tile() -> void:
	var gs := _new_game(4)
	var slot := _slot_with_cost(gs, 4)
	var kind: int = gs.shop[slot]["kind"]
	check(gs.buy_and_place(slot, 5), "purchase should succeed")
	var p = gs.current_player()
	eq(p.money, 16, "money")
	eq(gs.shop[slot], null, "slot emptied")
	eq(p.cells[5]["kind"], kind, "tile on mat")
	eq(gs.purchases, 1, "purchases")


func test_cannot_buy_what_you_cannot_afford() -> void:
	var gs := _new_game(4)
	gs.current_player().money = 1
	var slot := _slot_with_cost(gs, 6)
	check(not gs.buy_and_place(slot, 0), "purchase should fail")
	eq(gs.current_player().money, 1, "money unchanged")
	check(gs.shop[slot] != null, "tile still in shop")


func test_cannot_build_on_an_occupied_lot() -> void:
	var gs := _new_game(4)
	check(gs.buy_and_place(_slot_with_cost(gs, 1), 0), "first")
	check(not gs.buy_and_place(_slot_with_cost(gs, 1), 0), "second on same lot")


func test_only_two_purchases_per_turn() -> void:
	var gs := _new_game(4)
	check(not gs.can_end_turn(), "cannot end before buying")
	gs.buy_and_place(_slot_with_cost(gs, 1), 0)
	gs.buy_and_place(_slot_with_cost(gs, 1), 1)
	check(gs.can_end_turn(), "can end after two")
	check(not gs.buy_and_place(_slot_with_cost(gs, 1), 2), "third blocked")


## Every planner in turn buys two road tiles and builds them on the bottom row,
## which leaves every score untouched.
func _finish_round_with_roads(gs: GameState) -> void:
	for t in gs.players.size():
		for cell in [14, 15]:
			var slot := -1
			for i in gs.shop.size():
				if gs.shop[i] != null and gs.shop[i]["kind"] == TileDefs.Kind.ROAD:
					slot = i
					break
			check(gs.buy_and_place(slot, cell), "road purchase")
		gs.end_turn()


func test_round_one_order_is_a_random_draw_of_all_seats() -> void:
	var firsts := {}
	for seed_value in 40:
		var gs := _new_game(4, seed_value)
		var sorted_order := gs.turn_order()
		sorted_order.sort()
		eq(sorted_order, [0, 1, 2, 3], "every seat plays once")
		firsts[gs.turn_order()[0]] = true
	eq(firsts.size(), 4, "over many games every seat gets to start")
	var gs := _new_game(4)
	var events := []
	for i in 4:
		gs.buy_and_place(_slot_with_cost(gs, 1), 0)
		gs.buy_and_place(_slot_with_cost(gs, 1), 1)
		events.append(gs.end_turn())
	eq(events, ["turn", "turn", "turn", "round"], "events")
	eq(gs.round_number, 2, "round")


func test_later_rounds_start_with_the_fewest_points() -> void:
	var gs := _new_game(3)
	# no green space, so every home is unhappy: the bigger the home, the lower the score
	gs.players[0].cells[0] = TileDefs.make(TileDefs.Kind.APT_S)
	gs.players[2].cells[0] = TileDefs.make(TileDefs.Kind.APT_L)
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


func test_loan_only_when_two_tiles_are_unaffordable() -> void:
	var gs := _new_game(4)
	check(not gs.can_take_loan(), "rich player cannot loan")
	check(not gs.take_loan(), "loan refused")
	gs.current_player().money = 1
	check(gs.can_take_loan(), "poor player can loan")
	check(gs.take_loan(), "loan granted")
	eq(gs.current_player().money, 11, "money after loan")
	eq(gs.current_player().loans, 1, "loans")


func test_loan_after_first_purchase_checks_one_tile() -> void:
	var gs := _new_game(4)
	gs.buy_and_place(_slot_with_cost(gs, 1), 0)
	gs.current_player().money = 1
	check(not gs.can_take_loan(), "can still afford a 1-cost tile")
	gs.current_player().money = 0
	check(gs.can_take_loan(), "cannot afford anything")


func test_free_roads_do_not_count_as_purchases() -> void:
	var gs := _new_game(4)
	check(gs.place_free_road(3), "first free road")
	check(gs.place_free_road(7), "second free road")
	check(not gs.place_free_road(11), "no third free road")
	var p = gs.current_player()
	eq(p.free_roads, 0, "free roads left")
	eq(p.money, 20, "free roads cost nothing")
	eq(gs.purchases, 0, "not a purchase")
	eq(p.cells[3]["kind"], TileDefs.Kind.ROAD, "road placed")
	check(p.cells[3].get("free", false), "marked free")


func test_full_games_end_after_four_rounds() -> void:
	for n in [2, 3, 4]:
		var gs := _new_game(n, 100 + n)
		var rng := RandomNumberGenerator.new()
		rng.seed = 42
		var last := ""
		var guard := 0
		while not gs.is_game_over() and guard < 100:
			guard += 1
			while gs.purchases < 2:
				while gs.can_take_loan():
					gs.take_loan()
				var slots := []
				for i in gs.shop.size():
					if gs.shop[i] != null and gs.can_afford(i):
						slots.append(i)
				var p = gs.current_player()
				var empty := []
				for c in 16:
					if p.cells[c] == null:
						empty.append(c)
				check(gs.buy_and_place(slots[rng.randi() % slots.size()], empty[rng.randi() % empty.size()]), "bot purchase")
			last = gs.end_turn()
		eq(last, "game_over", "%d players: last event" % n)
		check(gs.is_game_over(), "%d players: game over" % n)
		for p in gs.players:
			var bought := 0
			for t in p.cells:
				if t != null and not t.get("free", false):
					bought += 1
			eq(bought, 8, "%d players: 8 tiles bought" % n)
