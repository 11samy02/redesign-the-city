extends "res://tests/test_base.gd"
## The hidden circumstance deck as the game uses it: planning, revealing, gold and scoring.

const GameState = preload("res://scripts/core/game_state.gd")
const CircumstanceDefs = preload("res://scripts/core/circumstance_defs.gd")
const Scoring = preload("res://scripts/core/scoring.gd")

const EMPTY := "......."


func _new_game(n := 2, seed_value := 7) -> GameState:
	var gs := GameState.new()
	gs.setup(["Ana", "Ben", "Cleo", "Dimitri"].slice(0, n), [0, 1, 2, 3].slice(0, n), seed_value)
	return gs


## Everyone buys cheap stuff for four turns' worth of buys until the round changes.
func _finish_round(gs: GameState) -> void:
	var round_before := gs.round_number
	var guard := 0
	while gs.round_number == round_before and not gs.is_game_over() and guard < 20:
		guard += 1
		while gs.purchases < GameState.BUYS_PER_TURN:
			while gs.can_take_loan():
				gs.take_loan()
			var p = gs.current_player()
			var slot := -1
			for i in gs.shop.size():
				if gs.can_afford(i) and (slot < 0 or TileDefs.tile_cost(gs.shop[i]["tile"]) < TileDefs.tile_cost(gs.shop[slot]["tile"])):
					slot = i
			if slot < 0:
				return
			var spots := Grid.valid_anchors(p.cells, TileDefs.footprint(gs.shop[slot]["tile"]))
			gs.buy_and_place(slot, spots[0])
		gs.end_turn()


func _shop_signature(gs: GameState) -> Array:
	var out := []
	for s in gs.shop:
		out.append([s["tile"]["kind"], s["tile"]["variant"], s["count"]])
	return out


func test_setup_plans_eight_unique_cards_of_the_32() -> void:
	for seed_value in [1, 2, 3, 4, 5]:
		var gs := _new_game(2, seed_value)
		eq(gs.circumstance_plan.size(), 8, "one card per round")
		var seen := {}
		for id in gs.circumstance_plan:
			check(id in CircumstanceDefs.IDS, "%s is a real card" % id)
			check(not seen.has(id), "%s is not repeated" % id)
			seen[id] = true
		eq(gs.revealed, [], "nothing revealed yet")


func test_same_seed_plans_the_same_deck_and_leaves_the_shop_alone() -> void:
	var a := _new_game(3, 11)
	var b := _new_game(3, 11)
	eq(a.circumstance_plan, b.circumstance_plan, "same deck")
	eq(_shop_signature(a), _shop_signature(b), "same shop")


func test_different_seeds_do_not_all_give_the_same_deck() -> void:
	var decks := {}
	for seed_value in 12:
		decks[str(_new_game(2, seed_value).circumstance_plan)] = true
	check(decks.size() > 6, "decks vary between seeds, got %d distinct" % decks.size())


func test_one_card_is_revealed_per_round() -> void:
	var gs := _new_game()
	check(gs.has_pending_circumstance(), "round 1 card waits")
	var entry := gs.reveal_circumstance()
	eq(entry["round"], 1, "round of the card")
	eq(entry["id"], gs.circumstance_plan[0], "first planned card")
	check(not gs.has_pending_circumstance(), "only one per round")
	eq(gs.reveal_circumstance(), {}, "a second reveal does nothing")
	eq(gs.current_circumstance(), entry["id"], "current card")
	_finish_round(gs)
	check(gs.has_pending_circumstance(), "round 2 card waits")
	eq(gs.reveal_circumstance()["id"], gs.circumstance_plan[1], "second planned card")


func test_budget_cut_takes_gold_from_everyone_but_never_below_zero() -> void:
	var gs := _new_game()
	gs.circumstance_plan[0] = "budget_cut"
	gs.players[1].money = 5
	var entry := gs.reveal_circumstance()
	eq(gs.players[0].money, 92, "100 - 8")
	eq(gs.players[1].money, 0, "floored at zero")
	eq(entry["gold"], [-8, -5], "log of what each planner lost")


func test_grant_and_business_boom_pay_for_what_is_on_the_mat() -> void:
	var gs := _new_game()
	gs.circumstance_plan[0] = "grant"
	gs.circumstance_plan[1] = "business_boom"
	gs.players[0].cells = mat(["PPT....", EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY])
	gs.players[1].cells = mat(["CC.....", EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY])
	gs.reveal_circumstance()
	eq(gs.players[0].money, 100 + 6 + 2 * 3, "grant for 2 parks and 1 tree")
	eq(gs.players[1].money, 100 + 6, "grant with no green")
	_finish_round(gs)
	var money_before: int = gs.players[1].money
	gs.reveal_circumstance()
	eq(gs.players[1].money, money_before + 4, "business boom for 2 commercial areas")


func test_weather_cards_do_not_touch_gold() -> void:
	var gs := _new_game()
	gs.circumstance_plan[0] = "heatwave"
	var entry := gs.reveal_circumstance()
	eq(entry["gold"], [0, 0], "no gold change")
	eq(gs.players[0].money, 100, "money untouched")


func test_circumstances_never_change_tiles() -> void:
	var gs := _new_game()
	gs.players[0].cells = mat(["uRR....", ".U.....", EMPTY, EMPTY, EMPTY, EMPTY, EMPTY])
	var before := str(gs.players[0].cells)
	gs.circumstance_plan[0] = "exam_season"
	gs.reveal_circumstance()
	eq(str(gs.players[0].cells), before, "mat unchanged")


func test_score_includes_revealed_cards_only() -> void:
	var gs := _new_game()
	gs.players[0].cells = mat(["uRR....", ".U.....", EMPTY, EMPTY, EMPTY, EMPTY, EMPTY])
	gs.circumstance_plan[0] = "exam_season"
	var before: int = gs.score(0)["total"]
	gs.reveal_circumstance()
	eq(gs.score(0)["total"], before - 1, "the revealed card costs the student 1 point")


func test_a_full_game_reveals_eight_cards_and_scores_stay_finite() -> void:
	var gs := _new_game(2, 5)
	gs.reveal_circumstance()
	var guard := 0
	while not gs.is_game_over() and guard < 20:
		guard += 1
		var round_before := gs.round_number
		_finish_round(gs)
		if gs.round_number != round_before:
			gs.reveal_circumstance()
	eq(gs.revealed.size(), 8, "eight cards revealed")
	for i in 2:
		var total: int = gs.score(i)["total"]
		check(total > -1000 and total < 1000, "score %d is finite" % i)
