extends "res://tests/test_base.gd"

const GameState = preload("res://scripts/core/game_state.gd")
const Bot = preload("res://scripts/core/bot.gd")
const Scoring = preload("res://scripts/core/scoring.gd")


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
		if guard > 200:
			return false
		var level: int = gs.current_player().bot_level
		while gs.purchases < 2:
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
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	for level in [Bot.EASY, Bot.MEDIUM, Bot.HARD]:
		var gs := _game([level, level, level], 30 + level)
		check(_play_out(gs, rng), "level %d finishes" % level)
		check(gs.is_game_over(), "level %d game over" % level)


func test_bots_use_their_free_roads_by_the_end() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for level in [Bot.EASY, Bot.MEDIUM, Bot.HARD]:
		var gs := _game([level, level], 50 + level)
		_play_out(gs, rng)
		for p in gs.players:
			eq(p.free_roads, 0, "level %d spends free roads" % level)


func test_harder_bots_score_more_on_average() -> void:
	var totals := {Bot.EASY: 0, Bot.MEDIUM: 0, Bot.HARD: 0}
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var seatings := [[Bot.EASY, Bot.MEDIUM, Bot.HARD], [Bot.HARD, Bot.EASY, Bot.MEDIUM], [Bot.MEDIUM, Bot.HARD, Bot.EASY]]
	for g in 9:
		var levels: Array = seatings[g % 3]
		var gs := _game(levels, 400 + g)
		_play_out(gs, rng)
		for i in levels.size():
			totals[levels[i]] += gs.score(i)["total"]
	print("        bot totals over 9 games: easy %d, medium %d, hard %d" % [totals[Bot.EASY], totals[Bot.MEDIUM], totals[Bot.HARD]])
	check(totals[Bot.MEDIUM] > totals[Bot.EASY], "medium beats easy")
	check(totals[Bot.HARD] > totals[Bot.MEDIUM], "hard beats medium")


func test_medium_and_hard_bots_build_homes() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	for g in 4:
		var gs := _game([Bot.MEDIUM, Bot.HARD, Bot.MEDIUM], 600 + g)
		_play_out(gs, rng)
		for i in 3:
			check(gs.score(i)["citizens"] > 0, "game %d seat %d houses citizens" % [g, i])


func test_hard_bot_names_the_biggest_complaint() -> void:
	var r := Scoring.evaluate(mat(["s...", "....", "....", "...."]), 0)
	var rng := RandomNumberGenerator.new()
	eq(Bot.choose_change(r, Bot.HARD, rng), "Pollution", "biggest complaint")
