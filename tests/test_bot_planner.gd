extends "res://tests/test_base.gd"
## The Hard bot's city planner: it keeps one plan across a turn, only plans what the shop can
## supply and hands the screen a finished plan to pick up.

const GameState = preload("res://scripts/core/game_state.gd")
const Bot = preload("res://scripts/core/bot.gd")
const BotPlanner = preload("res://scripts/core/bot_planner.gd")
const Scoring = preload("res://scripts/core/scoring.gd")


func _game(level: int, seed_value: int, seats := 2) -> GameState:
	var gs := GameState.new()
	var names := []
	var colors := []
	var levels := []
	for i in seats:
		names.append("P%d" % i)
		colors.append(i)
		levels.append(level)
	gs.setup(names, colors, seed_value, levels)
	return gs


func _plan(gs: GameState) -> Dictionary:
	return gs.get_meta("bot_plan_%d" % gs.current_index())


func test_thinking_ahead_leaves_a_plan_for_the_choices_that_follow() -> void:
	var gs := _game(Bot.HARD, 3)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	Bot.think(gs, Bot.HARD, rng)
	check(gs.has_meta("bot_plan_0"), "the plan is kept")
	var plan := _plan(gs)
	# 8 rounds x 4 buys, and the 4 free roads
	eq(plan["type"].size(), GameState.ROUNDS * GameState.BUYS_PER_TURN + GameState.FREE_ROADS, "one item per tile still to place")
	var before: PackedInt32Array = plan["cell"].duplicate()
	var move := Bot.choose_purchase(gs, Bot.HARD, rng)
	eq(_plan(gs)["cell"], before, "choosing does not search again")
	check(move[1] in before, "the lot comes from the plan")


func test_the_plan_is_followed_for_the_whole_turn() -> void:
	var gs := _game(Bot.HARD, 5)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	var move := Bot.choose_purchase(gs, Bot.HARD, rng)
	var items: int = _plan(gs)["type"].size()
	for k in GameState.BUYS_PER_TURN:
		check(move[1] in _plan(gs)["cell"], "purchase %d goes where the plan says" % k)
		check(gs.buy_and_place(move[0], move[1]), "purchase %d is legal" % k)
		if gs.buys_left() > 0:
			move = Bot.choose_purchase(gs, Bot.HARD, rng)
			items -= 1
			eq(_plan(gs)["type"].size(), items, "the item just bought is used up, the rest stays")


func test_the_plan_never_counts_on_more_tiles_than_the_shop_has() -> void:
	var gs := _game(Bot.HARD, 7, 4)
	# nearly sold out: one of each, and nothing at all of the big services
	for s in gs.shop.size():
		gs.shop[s]["count"] = mini(gs.shop[s]["count"], 1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	Bot.think(gs, Bot.HARD, rng)
	var ctx := BotPlanner._context(gs)
	var plan := _plan(gs)
	for t in ctx["types"].size():
		var type: Dictionary = ctx["types"][t]
		check(plan["counts"][t] <= type["avail"], "type %d: %d planned, %d available" % [t, plan["counts"][t], type["avail"]])
		if not type["free"]:
			check(type["avail"] <= gs.stack_count(type["slot"]), "never more than the stack holds")


func test_free_roads_in_the_plan_go_on_empty_lots() -> void:
	var gs := _game(Bot.HARD, 9)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var cell := Bot.choose_free_road(gs, Bot.HARD, rng)
	check(cell >= 0 and gs.can_place(cell), "the plan has a free road for an empty lot, got %d" % cell)


func test_a_new_turn_replans_around_lots_that_were_built_on() -> void:
	var gs := _game(Bot.HARD, 11)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	Bot.choose_purchase(gs, Bot.HARD, rng)
	var taken: int = _plan(gs)["cell"][0]
	gs.current_player().cells[taken] = TileDefs.make(TileDefs.Kind.TREES)
	gs.round_number += 1  # a new turn, so the plan is searched again
	var move := Bot.choose_purchase(gs, Bot.HARD, rng)
	check(move[1] != taken, "the lot that was built on is not planned again")
	check(gs.can_place(move[1]), "and the move is legal")


## A planner in the middle of the game: free tiles first, then the turn's purchases.
func _play_turn(gs: GameState, rng: RandomNumberGenerator) -> void:
	var level: int = gs.current_player().bot_level
	var road := Bot.choose_free_road(gs, level, rng)
	while road >= 0 and gs.place_free_road(road):
		road = Bot.choose_free_road(gs, level, rng)
	while gs.buys_left() > 0:
		while gs.can_take_loan():
			gs.take_loan()
		var move := Bot.choose_purchase(gs, level, rng)
		if not gs.buy_and_place(move[0], move[1]):
			return
	gs.end_turn()


func test_a_hard_bots_city_is_not_in_the_red_while_it_grows() -> void:
	# a bot that builds homes and services in any order looks terrible for most of the game
	# (-30 to -80 points until the roads arrive); this one grows a city that already works
	var gs := _game(Bot.HARD, 21, 3)
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	while gs.round_number <= 4:
		_play_turn(gs, rng)
	for i in gs.players.size():
		check(gs.score(i)["total"] >= 0, "after 4 rounds planner %d has %d points" % [i, gs.score(i)["total"]])

