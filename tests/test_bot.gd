extends "res://tests/test_base.gd"

const GameState = preload("res://scripts/core/game_state.gd")
const Bot = preload("res://scripts/core/bot.gd")
const Scoring = preload("res://scripts/core/scoring.gd")
const BotPlanner = preload("res://scripts/core/bot_planner.gd")
const Roles = preload("res://scripts/core/roles.gd")


## Whole-game tests that only check the rules (games finish, roads get spent) do not need Hard's
## full search, so they run it lightly. The strength tests use the real thing.
func _quick_search() -> void:
	BotPlanner.tune["effort%d" % Bot.HARD] = 0.15


func _full_search() -> void:
	BotPlanner.tune.erase("effort%d" % Bot.HARD)


func _game(levels: Array, seed_value: int) -> GameState:
	var gs := GameState.new()
	var names := []
	var colors := []
	for i in levels.size():
		names.append("P%d" % i)
		colors.append(i)
	gs.setup(names, colors, seed_value, levels)
	return gs


## Plays a whole game with every seat driven by its bot level.
func _play_out(gs: GameState, rng: RandomNumberGenerator) -> bool:
	var guard := 0
	while not gs.is_game_over():
		guard += 1
		if guard > 400:
			return false
		var level: int = gs.current_player().bot_level
		while gs.purchases < GameState.BUYS_PER_TURN:
			while gs.can_take_loan():
				gs.take_loan()
			var move := Bot.choose_purchase(gs, level, rng)
			if not gs.buy_and_place(move[0], move[1]):
				return false
		var road := Bot.choose_free_road(gs, level, rng)
		while road >= 0:
			if not gs.place_free_road(road):
				return false
			road = Bot.choose_free_road(gs, level, rng)
		gs.end_turn()
	return true


func test_setup_stores_bot_levels() -> void:
	var gs := _game([0, Bot.HARD], 1)
	eq(gs.players[0].bot_level, 0, "human seat")
	eq(gs.players[1].bot_level, Bot.HARD, "bot seat")
	check(not gs.players[0].is_bot(), "human is not a bot")
	check(gs.players[1].is_bot(), "bot is a bot")


func test_every_level_picks_a_legal_purchase() -> void:
	for level in [Bot.EASY, Bot.MEDIUM, Bot.HARD]:
		var gs := _game([level, level], 3)
		var rng := RandomNumberGenerator.new()
		rng.seed = 9
		var move := Bot.choose_purchase(gs, level, rng)
		check(gs.can_afford(move[0]), "level %d: affordable slot" % level)
		check(gs.can_place(move[1]), "level %d: empty lot" % level)


func test_free_road_choice_is_an_empty_lot_or_none() -> void:
	var gs := _game([Bot.HARD, Bot.HARD], 4)
	var rng := RandomNumberGenerator.new()
	var cell := Bot.choose_free_road(gs, Bot.HARD, rng)
	check(cell == -1 or gs.can_place(cell), "legal free road")


func test_bots_finish_full_games_at_every_level() -> void:
	_quick_search()
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	for level in [Bot.EASY, Bot.MEDIUM, Bot.HARD]:
		var gs := _game([level, level], 30 + level)
		check(_play_out(gs, rng), "level %d finishes" % level)
		check(gs.is_game_over(), "level %d game over" % level)
	_full_search()


func test_bots_use_their_free_roads_by_the_end() -> void:
	_quick_search()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for level in [Bot.EASY, Bot.MEDIUM, Bot.HARD]:
		var gs := _game([level, level], 50 + level)
		_play_out(gs, rng)
		for p in gs.players:
			eq(p.free_roads, 0, "level %d spends free roads" % level)
	_full_search()


func test_harder_bots_score_more_on_average() -> void:
	var totals := {Bot.EASY: 0, Bot.MEDIUM: 0, Bot.HARD: 0}
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var seatings := [[Bot.EASY, Bot.MEDIUM, Bot.HARD], [Bot.HARD, Bot.EASY, Bot.MEDIUM], [Bot.MEDIUM, Bot.HARD, Bot.EASY]]
	for g in 6:
		var levels: Array = seatings[g % 3]
		var gs := _game(levels, 400 + g)
		_play_out(gs, rng)
		for i in levels.size():
			totals[levels[i]] += gs.score(i)["total"]
	print("        bot totals over 6 games: easy %d, medium %d, hard %d" % [totals[Bot.EASY], totals[Bot.MEDIUM], totals[Bot.HARD]])
	check(totals[Bot.MEDIUM] > totals[Bot.EASY], "medium beats easy")
	check(totals[Bot.HARD] > totals[Bot.MEDIUM], "hard beats medium")


func test_medium_and_hard_bots_build_homes() -> void:
	_quick_search()
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	for g in 2:
		var gs := _game([Bot.MEDIUM, Bot.HARD, Bot.MEDIUM], 600 + g)
		_play_out(gs, rng)
		for i in 3:
			check(gs.score(i)["citizens"] > 0, "game %d seat %d houses citizens" % [g, i])
	_full_search()


func test_hard_bot_names_the_biggest_complaint() -> void:
	var r := Scoring.evaluate(mat(["s......", ".......", ".......", ".......", ".......", ".......", "......."]), 0)
	var rng := RandomNumberGenerator.new()
	eq(Bot.choose_change(r, Bot.HARD, rng), "Accessibility", "a home with no service in reach")


func test_full_games_finish_for_every_player_count_and_level() -> void:
	_quick_search()
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for n in [2, 3, 4]:
		for level in [Bot.EASY, Bot.MEDIUM, Bot.HARD]:
			if level == Bot.HARD and n > 2:
				continue  # Hard thinks longest; two seats cover it
			var levels := []
			for i in n:
				levels.append(level)
			var gs := _game(levels, 900 + n * 10 + level)
			check(_play_out(gs, rng), "%d seats at level %d finish" % [n, level])
			for p in gs.players:
				var tiles := 0
				for t in p.cells:
					if t != null:
						tiles += 1
				eq(tiles, 36, "%d seats, level %d: 32 bought tiles + 4 free roads" % [n, level])
	_full_search()


func test_hard_bot_turn_is_fast_on_a_busy_mat() -> void:
	var gs := _game([Bot.HARD, Bot.HARD], 8)
	var p = gs.current_player()
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	# fill 24 lots with a mix of the tiles that are in the shop
	var c := 0
	for s in gs.shop.size():
		if c >= 24:
			break
		p.cells[c] = gs.shop[s]["tile"].duplicate()
		c += 1
	var started := Time.get_ticks_msec()
	var move := Bot.choose_purchase(gs, Bot.HARD, rng)
	var took := Time.get_ticks_msec() - started
	print("        hard bot turn on a busy mat took %d ms" % took)
	check(gs.can_place(move[1]), "legal lot")
	check(took < 6000, "a Hard bot decision takes under 6 seconds, took %d ms" % took)


func test_bots_place_a_bonus_tile_on_an_empty_lot() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 6
	for level in [Bot.EASY, Bot.MEDIUM, Bot.HARD]:
		var gs := _game([level, level], 14)
		gs.current_player().bonus_tiles.append(TileDefs.make(TileDefs.Kind.PARK))
		var cell := Bot.choose_bonus_cell(gs, level, rng)
		check(gs.can_place(cell), "level %d: an empty lot, got %d" % [level, cell])


func test_a_smart_bot_uses_its_free_service_to_serve_a_home() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 6
	var gs := _game([Bot.HARD, Bot.HARD], 14)
	gs.round_number = GameState.ROUNDS  # one turn left to finish the city
	var p = gs.current_player()
	p.cells = mat(["uRR....", ".......", ".......", ".......", ".......", ".......", "......."])
	p.bonus_tiles.append(TileDefs.make(TileDefs.Kind.UNIVERSITY))
	var cell := Bot.choose_bonus_cell(gs, Bot.HARD, rng)
	check(gs.can_place(cell), "a legal lot, got %d" % cell)
	check(gs.place_bonus_tile(0, cell), "the university is placed")
	while gs.purchases < gs.buy_limit() and gs.buys_left() > 0:
		while gs.can_take_loan():
			gs.take_loan()
		var move := Bot.choose_purchase(gs, Bot.HARD, rng)
		check(gs.buy_and_place(move[0], move[1]), "a legal purchase")
	var road := Bot.choose_free_road(gs, Bot.HARD, rng)
	while road >= 0 and gs.place_free_road(road):
		road = Bot.choose_free_road(gs, Bot.HARD, rng)
	var student: Dictionary = gs.score(gs.current_index())["apartments"][0]["members"][0]
	check(student["needs"][0]["met"], "the student can reach the university the bot was given")


## A hard bot is given free tiles and one home of a new citizen with a road next to it: it must put
## the tiles where that citizen can use them (the planner scores the real rules, so it has to
## understand what an expat or a resident with a disability needs).
func _serve_with_gifts(home_variant: int, gifts: Array, seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var gs := _game([Bot.HARD, Bot.HARD], seed_value)
	gs.round_number = GameState.ROUNDS
	var p = gs.current_player()
	p.cells = mat(["sRR....", ".......", ".......", ".......", ".......", ".......", "......."], {0: home_variant})
	for kind in gifts:
		p.bonus_tiles.append(TileDefs.make(kind))
	while not p.bonus_tiles.is_empty():
		var cell := Bot.choose_bonus_cell(gs, Bot.HARD, rng)
		check(gs.can_place(cell), "a legal lot for the free tile, got %d" % cell)
		if not gs.place_bonus_tile(0, cell):
			break
	while gs.purchases < gs.buy_limit() and gs.buys_left() > 0:
		while gs.can_take_loan():
			gs.take_loan()
		var move := Bot.choose_purchase(gs, Bot.HARD, rng)
		check(gs.buy_and_place(move[0], move[1]), "a legal purchase")
	var road := Bot.choose_free_road(gs, Bot.HARD, rng)
	while road >= 0 and gs.place_free_road(road):
		road = Bot.choose_free_road(gs, Bot.HARD, rng)
	return gs.score(gs.current_index())["apartments"][0]["members"][0]


func test_a_smart_bot_gives_an_expat_a_workplace_and_a_restaurant() -> void:
	var expat := _serve_with_gifts(3, [TileDefs.Kind.COMMERCIAL, TileDefs.Kind.RESTAURANT], 31)
	eq(expat["role"], "expat", "the home houses an expat")
	for n in expat["needs"]:
		check(n["met"], "the expat's need '%s' is met" % n["id"])


func test_a_smart_bot_gives_a_resident_with_a_disability_care_and_a_park() -> void:
	var resident := _serve_with_gifts(2, [TileDefs.Kind.CLINIC, TileDefs.Kind.PARK], 32)
	eq(resident["role"], "access", "the home houses a resident with a disability")
	for n in resident["needs"]:
		check(n["met"], "the resident's need '%s' is met" % n["id"])


## Whole games between bots: every kind of citizen gets built, and the new ones are looked after.
func test_bots_build_and_serve_every_kind_of_citizen() -> void:
	_quick_search()
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	var housed := {}
	var served := {}
	for g in 3:
		var gs := _game([Bot.MEDIUM, Bot.HARD, Bot.HARD], 900 + g)
		check(_play_out(gs, rng), "game %d finishes" % g)
		for i in 3:
			for home in gs.score(i)["apartments"]:
				for m in home["members"]:
					housed[m["role"]] = housed.get(m["role"], 0) + 1
					if m["happiness"] >= Scoring.VARIETY_HAPPY:
						served[m["role"]] = served.get(m["role"], 0) + 1
	print("        bot census (housed / happy): %s" % str({"housed": housed, "happy": served}))
	for role in Roles.IDS:
		check(housed.get(role, 0) > 0, "bots build homes for %s" % role)
	for role in ["access", "expat"]:
		check(served.get(role, 0) > 0, "bots make at least one %s happy" % role)
	_full_search()


func test_bots_resolve_a_choice_card_on_their_own() -> void:
	var gs := _game([Bot.MEDIUM, Bot.MEDIUM], 14)
	gs.begin_card("bribery_scandal")
	var rng := RandomNumberGenerator.new()
	var pick := Bot.choose_card_option(gs, rng)
	check(gs.card_choice_options()[pick]["available"], "an available option")
	check(not gs.resolve_turn_card(pick).is_empty(), "it resolves")


## Plays a whole game the way the screen does: card first, then free tiles, buys and free roads.
func _play_out_with_cards(gs: GameState, rng: RandomNumberGenerator) -> bool:
	var guard := 0
	while not gs.is_game_over():
		guard += 1
		if guard > 400:
			return false
		var level: int = gs.current_player().bot_level
		if gs.has_pending_circumstance():
			gs.reveal_circumstance()
		var draw := gs.flip_and_draw()
		if draw.is_empty():
			return false
		gs.resolve_turn_card(Bot.choose_card_option(gs, rng) if gs.card_needs_choice() else -1)
		while not gs.current_player().bonus_tiles.is_empty():
			if not gs.place_bonus_tile(0, Bot.choose_bonus_cell(gs, level, rng)):
				return false
		while gs.purchases < gs.buy_limit() and gs.buys_left() > 0:
			while gs.can_take_loan():
				gs.take_loan()
			var move := Bot.choose_purchase(gs, level, rng)
			if not gs.buy_and_place(move[0], move[1]):
				return false
		var road := Bot.choose_free_road(gs, level, rng)
		while road >= 0:
			if not gs.place_free_road(road):
				return false
			road = Bot.choose_free_road(gs, level, rng)
		if gs.end_turn() == "":
			return false
	return true


func test_full_games_with_turn_cards_finish_and_stay_sane() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	for n in [2, 3]:
		for level in [Bot.EASY, Bot.MEDIUM]:
			var levels := []
			for i in n:
				levels.append(level)
			var gs := _game(levels, 700 + n * 10 + level)
			check(_play_out_with_cards(gs, rng), "%d seats at level %d finish with cards" % [n, level])
			eq(gs.card_log.size(), n * GameState.ROUNDS, "%d seats: one card per turn" % n)
			for p in gs.players:
				check(p.money >= 0, "gold never below zero")
				check(p.cells.count(null) < 49, "something was built")


func test_bots_price_tiles_the_way_the_shop_does_after_a_card() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	for level in [Bot.EASY, Bot.MEDIUM, Bot.HARD]:
		var gs := _game([level, level], 21)
		gs.begin_card("price_hike")
		gs.resolve_turn_card()
		# exactly enough for the cheapest tile once everything costs 2 more
		gs.current_player().money = 3
		var move := Bot.choose_purchase(gs, level, rng)
		check(gs.can_afford(move[0]), "level %d picked a tile it can afford (slot %d costs %d with 2 gold)" % [level, move[0], gs.price_of(gs.shop[move[0]]["tile"])])
		var gs2 := _game([level, level], 22)
		gs2.begin_card("tree_planting_campaign")
		gs2.resolve_turn_card()
		gs2.current_player().money = 0
		check(gs2.can_afford(Bot.choose_purchase(gs2, level, rng)[0]), "level %d takes the free trees" % level)
