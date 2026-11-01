extends "res://tests/test_base.gd"
## The event and penalty decks: card data, every effect, and the turn flow (coin flip, draw,
## resolve, per-turn modifiers).

const GameState = preload("res://scripts/core/game_state.gd")
const Scoring = preload("res://scripts/core/scoring.gd")
const CardDefs = preload("res://scripts/core/card_defs.gd")
const CardEffects = preload("res://scripts/core/card_effects.gd")

const K := TileDefs.Kind
const EMPTY := "......."
const NONE := [EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY]


func _game(n := 2, seed_value := 3) -> GameState:
	var gs := GameState.new()
	gs.setup(["Ana", "Ben", "Cleo", "Dimitri"].slice(0, n), [0, 1, 2, 3].slice(0, n), seed_value)
	return gs


func _fx(id: String) -> Dictionary:
	return CardDefs.info(id)["fx"]


## Plays card `id` for player `me` (and the first option for a choice card unless `choice` is given).
func _play(gs: GameState, id: String, me := 0, choice := 0) -> Dictionary:
	gs.begin_card(id)
	return gs.resolve_turn_card(choice if gs.card_needs_choice() else -1)


func _count(cells: Array, kind: int) -> int:
	var n := 0
	for t in cells:
		if t != null and t["kind"] == kind:
			n += 1
	return n


# ---------------------------------------------------------------- the data

func test_each_deck_has_sixty_four_unique_cards() -> void:
	eq(CardDefs.DECK_SIZE, 64, "deck size")
	for type in CardDefs.TYPES:
		var ids := CardDefs.ids(type)
		eq(ids.size(), 64, "%s cards" % type)
		var seen := {}
		for id in ids:
			check(not seen.has(id), "%s is unique" % id)
			seen[id] = true
			eq(CardDefs.type_of(id), type, "%s type" % id)
	var all := {}
	for id in CardDefs.ids(CardDefs.EVENT) + CardDefs.ids(CardDefs.PENALTY):
		check(not all.has(id), "%s is not in both decks" % id)
		all[id] = true


func test_every_card_has_text_a_picture_and_highlight_words_from_its_rule() -> void:
	for id in CardDefs.ids(CardDefs.EVENT) + CardDefs.ids(CardDefs.PENALTY):
		var d := CardDefs.info(id)
		for k in ["title", "rule", "story", "motif", "badge"]:
			check(String(d[k]) != "", "%s has %s" % [id, k])
		check(String(d["rule"]).contains(CardDefs.key_words(id)), "%s: highlight words appear in the rule" % id)
		check(d["motif"] in CardDefs.MOTIF_TINT, "%s: motif %s has a colour" % [id, d["motif"]])
		check(d["motif"] in (CardDefs.EVENT_MOTIFS if d["type"] == CardDefs.EVENT else CardDefs.PENALTY_MOTIFS), "%s uses its own deck's pictures" % id)
		check(FileAccess.file_exists(CardDefs.art_path(id)), "%s: picture file %s" % [id, CardDefs.art_path(id)])
		check(FileAccess.file_exists(CardDefs.icon_path(id)), "%s: icon file" % id)


func test_the_events_are_good_and_the_penalties_are_bad() -> void:
	for id in CardDefs.ids(CardDefs.EVENT):
		check(not CardDefs.info(id)["badge"].begins_with("-") or id == "debt_relief", "%s badge is not a loss" % id)
	for id in CardDefs.ids(CardDefs.PENALTY):
		check(not CardDefs.info(id)["badge"].begins_with("+"), "%s badge is not a gain" % id)


# ---------------------------------------------------------------- gold

func test_gold_for_everyone_and_for_you() -> void:
	var gs := _game(3)
	_play(gs, "government_funding")
	for p in gs.players:
		eq(p.money, 129, "everyone +4")
	_play(gs, "regional_grant")
	eq(gs.players[gs.current_index()].money, 129 + 3 + 3, "the drawer gets 3 more")
	eq(gs.players[(gs.current_index() + 1) % 3].money, 132, "others get 3")
	_play(gs, "lottery_win")
	eq(gs.players[gs.current_index()].money, 129 + 6 + 8, "lottery")


func test_losses_never_take_gold_below_zero() -> void:
	var gs := _game()
	gs.current_player().money = 1
	var r := _play(gs, "pickpockets")
	eq(gs.current_player().money, 0, "floored at zero")
	check(r["lines"].size() > 0, "the result is described")


func test_the_player_with_the_least_money_gets_the_bank_bonus() -> void:
	var gs := _game(3)
	gs.players[0].money = 50
	gs.players[1].money = 20
	gs.players[2].money = 80
	_play(gs, "bank_bonus")
	eq([gs.players[0].money, gs.players[1].money, gs.players[2].money], [50, 26, 80], "only the poorest")
	gs.players[0].money = 26
	_play(gs, "bank_bonus")
	eq([gs.players[0].money, gs.players[1].money], [32, 32], "a tie shares it")


func test_when_everyone_ties_everyone_counts() -> void:
	var gs := _game(3)
	_play(gs, "environmental_fine")
	for p in gs.players:
		eq(p.money, 93, "equal pollution: everyone pays")


func test_environmental_fine_hits_the_most_polluted() -> void:
	var gs := _game(3)
	gs.players[1].cells = mat(["PPT....", EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY])
	_play(gs, "environmental_fine")
	eq([gs.players[0].money, gs.players[1].money, gs.players[2].money], [93, 100, 93], "the two polluted cities pay")


func test_others_pay_you() -> void:
	var gs := _game(3)
	var me := gs.current_index()
	_play(gs, "tourist_tax")
	eq(gs.players[me].money, 129, "two others pay 2")
	gs.players[(me + 1) % 3].money = 200
	gs.players[me].money = 100
	_play(gs, "generous_donor")
	eq(gs.players[me].money, 130, "the richest pays 5")
	eq(gs.players[(me + 1) % 3].money, 195, "and it is taken from them")
	gs.players[me].money = 500
	_play(gs, "generous_donor")
	eq(gs.players[me].money, 500, "if you are the richest nobody pays you")


func test_pay_each_other_player_and_transfer() -> void:
	var gs := _game(3)
	var me := gs.current_index()
	_play(gs, "road_toll_dispute", me, 0)
	eq(gs.players[me].money, 121, "paid 2 to each of 2 players")
	var gs2 := _game(3)
	gs2.players[0].money = 90
	gs2.players[1].money = 150
	gs2.players[2].money = 30
	_play(gs2, "rival_developer")
	eq([gs2.players[0].money, gs2.players[1].money, gs2.players[2].money], [90, 146, 34], "richest to poorest")


func test_gold_for_what_is_on_your_mat() -> void:
	var gs := _game()
	var me := gs.current_index()
	gs.players[me].cells = mat(["PPTTTTT", "TTTT...", EMPTY, EMPTY, EMPTY, EMPTY, EMPTY])
	_play(gs, "green_city_award")
	eq(gs.players[me].money, 135, "2 gold per green tile, up to 5")
	gs.players[me].money = 100
	gs.players[me].cells = mat(["RRR....", EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY])
	_play(gs, "construction_delays")
	eq(gs.players[me].money, 124, "1 gold per 2 roads")


func test_conditions_for_gold_and_points() -> void:
	var gs := _game()
	var me := gs.current_index()
	gs.players[me].cells = mat(["sRL....", EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY])
	_play(gs, "improved_circulation")
	eq(gs.players[me].money, 130, "connected homes pay 5")
	gs.players[me].money = 100
	gs.players[me].cells = mat(["s..L...", EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY])
	_play(gs, "improved_circulation")
	eq(gs.players[me].money, 100, "an unconnected home pays nothing")
	_play(gs, "clean_record")
	eq(gs.players[me].money, 130, "no loans")
	gs.players[me].loans = 1
	gs.players[me].money = 100
	_play(gs, "clean_record")
	eq(gs.players[me].money, 100, "a loan spoils it")
	_play(gs, "debt_scandal")
	eq(gs.players[me].card_points, -3, "a loan costs points")


# ---------------------------------------------------------------- points

func test_points_go_to_the_right_players() -> void:
	var gs := _game(3)
	var me := gs.current_index()
	_play(gs, "civic_pride")
	eq(gs.players[me].card_points, 2, "civic pride")
	var gs1 := _game(3)
	gs1.players[0].cells = mat(["F......", EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY])
	gs1.players[1].cells = mat(["E......", EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY])
	gs1.players[2].cells = mat([EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY])
	_play(gs1, "community_day")
	eq([gs1.players[0].card_points, gs1.players[1].card_points, gs1.players[2].card_points], [1, 1, 0], "only planners with a coffee shop or restaurant")
	var gs2 := _game(3)
	gs2.players[0].cells = mat(["uRLU...", EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY])
	gs2.players[1].cells = mat(["PPPPPP.", EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY])
	_play(gs2, "community_complaints")
	eq([gs2.players[0].card_points, gs2.players[1].card_points, gs2.players[2].card_points], [0, -2, -2], "the two cities with the fewest services both lose")


func test_points_for_what_you_own() -> void:
	var gs := _game()
	var me := gs.current_index()
	gs.players[me].cells = mat(["lllll..", "u......", EMPTY, EMPTY, EMPTY, EMPTY, EMPTY])
	_play(gs, "luxury_housing")
	eq(gs.players[me].card_points, 3, "1 point per large apartment, up to 3")
	_play(gs, "overcrowded_flats")
	eq(gs.players[me].card_points, 0, "and the penalty takes them back")
	_play(gs, "green_shortfall")
	eq(gs.players[me].card_points, -2, "no park")
	gs.players[me].cells[10] = TileDefs.make(K.PARK)
	_play(gs, "green_shortfall")
	eq(gs.players[me].card_points, -2, "a park protects you")


func test_card_points_count_in_the_score() -> void:
	var gs := _game()
	var before: int = gs.score(0)["total"]
	gs.players[0].card_points = 4
	var r := gs.score(0)
	eq(r["total"], before + 4, "total")
	eq(r["card_points"], 4, "listed in the result")


# ---------------------------------------------------------------- tiles

func test_lost_tiles_leave_the_mat() -> void:
	var gs := _game()
	var me := gs.current_index()
	gs.players[me].cells = mat(["TTRRR..", EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY])
	_play(gs, "storm_damage")
	eq(_count(gs.players[me].cells, K.TREES), 1, "one trees tile lost")
	_play(gs, "flooded_streets")
	eq(_count(gs.players[me].cells, K.ROAD), 1, "two roads lost")
	_play(gs, "sinkhole")
	eq(_count(gs.players[me].cells, K.ROAD), 0, "one more road lost")
	_play(gs, "sinkhole")
	eq(_count(gs.players[me].cells, K.ROAD), 0, "nothing left to lose is fine")
	_play(gs, "beetle_attack")
	eq(_count(gs.players[me].cells, K.TREES), 0, "the last trees go")


func test_a_planner_who_picks_chooses_which_tiles_a_penalty_takes() -> void:
	var gs := _game()
	gs.players_pick_losses = true
	var me := gs.current_index()
	gs.players[me].cells = mat(["RRRRTT.", EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY])
	_play(gs, "flooded_streets")
	eq(_count(gs.players[me].cells, K.ROAD), 4, "nothing is lost before the planner chooses")
	eq(gs.pending_loss(), {"kinds": [K.ROAD], "n": 2}, "two roads to choose")
	eq(gs.loss_cells(), [0, 1, 2, 3] as Array[int], "only roads can be picked")
	eq(gs.lose_tile_at(4), {}, "trees are not a valid pick")
	check(not gs.lose_tile_at(1).is_empty(), "the first road goes")
	eq(gs.players[me].cells[1], null, "the picked lot is empty")
	eq(_count(gs.players[me].cells, K.ROAD), 3, "only the picked road left")
	check(not gs.pending_losses.is_empty(), "one more to choose")
	check(not gs.lose_tile_at(3).is_empty(), "the second road goes")
	check(gs.pending_losses.is_empty(), "the penalty is settled")
	eq(_count(gs.players[me].cells, K.ROAD), 2, "the other two roads stay")


func test_nothing_to_choose_when_every_tile_has_to_go() -> void:
	var gs := _game()
	gs.players_pick_losses = true
	var me := gs.current_index()
	gs.players[me].cells = mat(["RR.....", EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY])
	_play(gs, "flooded_streets")
	check(gs.pending_losses.is_empty(), "no choice when it takes both")
	eq(_count(gs.players[me].cells, K.ROAD), 0, "both roads go")


func test_bots_still_lose_random_tiles() -> void:
	var gs := GameState.new()
	gs.setup(["Ana", "Bot"], [0, 1], 3, [0, 1])
	gs.players_pick_losses = true
	var bot := gs.players.find_custom(func(p): return p.is_bot())
	gs.turn = gs.order.find(bot)
	gs.players[bot].cells = mat(["RRRR...", EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY])
	_play(gs, "flooded_streets")
	check(gs.pending_losses.is_empty(), "a bot is never asked")
	eq(_count(gs.players[bot].cells, K.ROAD), 2, "two random roads are lost")


func _slot_of_kind(gs: GameState, kind: int) -> int:
	for k in gs.shop.size():
		if gs.shop[k]["tile"]["kind"] == kind and gs.shop[k]["count"] > 0:
			return k
	return -1


func test_a_tile_can_be_replaced_once_and_goes_back_to_the_shop() -> void:
	var gs := _game()
	var me := gs.current_index()
	gs.players[me].cells = mat(["P.T....", EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY])
	var kiosk := _slot_of_kind(gs, K.KIOSK)
	var park_slot := _slot_of_kind(gs, K.PARK)
	var money: int = gs.players[me].money
	var price := gs.price_of(gs.shop[kiosk]["tile"])
	var park_before: int = gs.shop[park_slot]["count"]
	var kiosk_before: int = gs.shop[kiosk]["count"]
	check(gs.can_replace(kiosk, 0), "a bought tile can be replaced")
	check(not gs.can_replace(kiosk, 1), "an empty lot is not a replacement")
	var old := gs.replace_tile(kiosk, 0)
	eq(old["kind"], K.PARK, "the park is what got replaced")
	eq(gs.players[me].cells[0]["kind"], K.KIOSK, "the kiosk stands there now")
	eq(gs.players[me].money, money - price, "the new tile is paid for")
	eq(gs.purchases, 1, "it counts as a buy")
	eq(gs.shop[park_slot]["count"], park_before + 1, "the park is back in the construction site")
	eq(gs.shop[kiosk]["count"], kiosk_before - 1, "the kiosk left it")
	check(not gs.can_replace(kiosk, 2), "only once")
	eq(gs.replace_tile(kiosk, 2), {}, "a second replacement is refused")
	eq(gs.players[me].cells[2]["kind"], K.TREES, "and changes nothing")


func test_free_roads_and_gifts_cannot_be_replaced() -> void:
	var gs := _game()
	var me := gs.current_index()
	gs.players[me].cells = mat(["R......", EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY])
	gs.players[me].cells[0]["free"] = true
	check(not gs.can_replace(_slot_of_kind(gs, K.KIOSK), 0), "a free road never came from the shop")


func test_the_same_kind_is_not_a_replacement() -> void:
	var gs := _game()
	var me := gs.current_index()
	var kiosk := _slot_of_kind(gs, K.KIOSK)
	gs.players[me].cells = mat(["K......", EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY])
	check(not gs.can_replace(kiosk, 0), "a kiosk for a kiosk changes nothing")


func test_losing_a_tile_that_you_do_not_have_does_nothing() -> void:
	var gs := _game()
	var me := gs.current_index()
	gs.players[me].cells = mat(NONE)
	var r := _play(gs, "shop_fire")
	eq(_count(gs.players[me].cells, K.KIOSK), 0, "no kiosk to burn")
	check(r["lines"].size() > 0, "the card still says what happened")


func test_free_tiles_go_to_the_bonus_stock() -> void:
	var gs := _game()
	var me := gs.current_index()
	_play(gs, "park_donation")
	eq(gs.players[me].bonus_tiles.size(), 1, "one bonus tile")
	eq(gs.players[me].bonus_tiles[0]["kind"], K.PARK, "a park")
	_play(gs, "bike_lane_gift")
	eq(gs.players[me].bonus_tiles[1]["variant"], TileDefs.STREET_BIKE, "a bike lane")
	_play(gs, "road_crew")
	eq(gs.players[me].free_roads, GameState.FREE_ROADS + 2, "two more free roads")
	_play(gs, "lost_permits")
	eq(gs.players[me].free_roads, GameState.FREE_ROADS + 1, "one lost")
	_play(gs, "planning_dispute")
	eq(gs.players[me].free_roads, GameState.FREE_ROADS - 1, "two lost")


func test_a_bonus_tile_is_placed_like_a_free_road() -> void:
	var gs := _game()
	var me := gs.current_index()
	_play(gs, "park_donation")
	check(not gs.place_bonus_tile(0, 99), "not off the mat")
	check(gs.place_bonus_tile(0, 10), "placed")
	eq(gs.players[me].cells[10]["kind"], K.PARK, "the park is on the mat")
	check(gs.players[me].cells[10].get("free", false), "marked as free")
	eq(gs.players[me].bonus_tiles.size(), 0, "stock is empty")
	check(not gs.place_bonus_tile(0, 11), "nothing left to place")
	eq(gs.players[me].money, 100, "it cost nothing")
	eq(gs.purchases, 0, "and it is not a purchase")


# ---------------------------------------------------------------- this turn only

func test_discounts_and_markups_last_for_one_turn() -> void:
	var gs := _game()
	var trees := TileDefs.make(K.TREES)
	var apt := TileDefs.make(K.APT_M)
	_play(gs, "tree_planting_campaign")
	eq(gs.price_of(trees), 0, "trees are free")
	eq(gs.price_of(apt), 5, "nothing else changes")
	_play(gs, "housing_subsidy")
	eq(gs.price_of(apt), 2, "homes -3")
	_play(gs, "builders_discount")
	eq(gs.price_of(apt), 0, "everything -2 on top, never below zero")
	eq(gs.price_of(trees), 0, "never below zero")
	gs.reset_turn_state()
	eq(gs.price_of(apt), 5, "back to normal next turn")
	_play(gs, "price_hike")
	eq(gs.price_of(trees), 3, "everything +2")
	_play(gs, "material_shortage")
	eq(gs.price_of(apt), 10, "homes +3 more")


func test_a_discount_is_what_you_pay() -> void:
	var gs := _game()
	_play(gs, "tree_planting_campaign")
	var slot := -1
	for i in gs.shop.size():
		if gs.shop[i]["tile"]["kind"] == K.TREES:
			slot = i
	check(gs.can_afford(slot), "affordable")
	check(gs.buy_and_place(slot, 0), "bought")
	eq(gs.current_player().money, 100, "for nothing")


func test_extra_and_fewer_buys() -> void:
	var gs := _game()
	eq(gs.buy_limit(), 4, "normal")
	_play(gs, "extra_hands")
	eq(gs.buy_limit(), 5, "one more")
	for c in 5:
		check(gs.buy_and_place(_cheap(gs), c), "buy %d" % c)
	check(gs.can_end_turn(), "five buys end the turn")
	var gs2 := _game()
	_play(gs2, "general_strike")
	eq(gs2.buy_limit(), 3, "one fewer")
	_play(gs2, "general_strike")
	eq(gs2.buy_limit(), 2, "twice")
	_play(gs2, "general_strike")
	_play(gs2, "general_strike")
	eq(gs2.buy_limit(), 1, "never fewer than one")


func _cheap(gs: GameState) -> int:
	var best := -1
	for i in gs.shop.size():
		if gs.stack_count(i) > 0 and (best < 0 or gs.price_of(gs.shop[i]["tile"]) < gs.price_of(gs.shop[best]["tile"])):
			best = i
	return best


func test_debt_relief_removes_one_loan() -> void:
	var gs := _game()
	gs.current_player().loans = 2
	_play(gs, "debt_relief")
	eq(gs.current_player().loans, 1, "one loan gone")
	gs.current_player().loans = 0
	_play(gs, "debt_relief")
	eq(gs.current_player().loans, 0, "nothing to remove")


# ---------------------------------------------------------------- choices

func test_choice_cards_need_a_choice() -> void:
	var gs := _game()
	gs.begin_card("roads_or_greenery")
	check(gs.card_needs_choice(), "needs a choice")
	eq(gs.resolve_turn_card(), {}, "no choice, no effect")
	var options := gs.card_choice_options()
	eq(options.size(), 2, "two options")
	eq(options[0]["label"], "A free road", "label")
	check(options[0]["available"], "available")
	var r := gs.resolve_turn_card(1)
	check(r.has("lines"), "resolved")
	eq(gs.current_player().bonus_tiles[0]["kind"], K.TREES, "the trees were chosen")
	eq(gs.resolve_turn_card(0), {}, "a card resolves only once")


func test_a_payment_you_cannot_make_is_not_offered() -> void:
	var gs := _game()
	gs.current_player().money = 1
	gs.begin_card("illegal_tree_recovery")
	var options := gs.card_choice_options()
	check(not options[0]["available"], "cannot pay 2 gold with 1")
	check(options[1]["available"], "can lose a tree")
	eq(gs.resolve_turn_card(0), {}, "an unavailable option is refused")


func test_bots_pick_the_cheaper_option() -> void:
	var gs := _game()
	gs.begin_card("bribery_scandal")
	var pick := CardEffects.pick_option(gs, gs.current_index(), gs.card_choice_options())
	eq(pick, 0, "3 gold is cheaper than 2 points")
	gs.current_player().money = 0
	pick = CardEffects.pick_option(gs, gs.current_index(), gs.card_choice_options())
	eq(pick, 1, "with no gold the points go")
	gs.begin_card("planners_pick")
	gs.current_player().money = 100
	check(CardEffects.pick_option(gs, gs.current_index(), gs.card_choice_options()) in [0, 1], "a good choice either way")


# ---------------------------------------------------------------- the turn flow

func test_the_coin_flip_picks_the_deck_and_draws_a_card() -> void:
	var gs := _game()
	var before_e := gs.card_deck_count(CardDefs.EVENT)
	var before_p := gs.card_deck_count(CardDefs.PENALTY)
	eq([before_e, before_p], [64, 64], "full decks")
	var draw := gs.flip_and_draw()
	check(draw["coin"] in ["heads", "tails"], "a coin")
	eq(draw["type"], CardDefs.EVENT if draw["coin"] == "heads" else CardDefs.PENALTY, "heads is an event, tails a penalty")
	eq(CardDefs.type_of(draw["id"]), draw["type"], "the card is from that deck")
	eq(gs.card_deck_count(draw["type"]), 63, "the deck shrinks")
	eq(gs.card_deck_count(CardDefs.EVENT) + gs.card_deck_count(CardDefs.PENALTY), 127, "only one card was drawn")
	eq(gs.flip_and_draw(), {}, "one card per turn")
	check(gs.has_pending_card(), "waiting to be resolved")


func test_the_coin_is_fair_enough_and_repeatable() -> void:
	var heads := 0
	for s in 200:
		if _game(2, s).flip_and_draw()["coin"] == "heads":
			heads += 1
	check(heads > 70 and heads < 130, "about half heads, got %d of 200" % heads)
	eq(_game(2, 9).flip_and_draw(), _game(2, 9).flip_and_draw(), "same seed, same first draw")


func test_no_card_comes_twice_in_a_game() -> void:
	var gs := _game(4, 5)
	var seen := {}
	for t in 32:
		var draw := gs.flip_and_draw()
		check(not draw.is_empty(), "turn %d draws" % t)
		check(not seen.has(draw["id"]), "%s was drawn twice" % draw["id"])
		seen[draw["id"]] = true
		gs.resolve_turn_card(0)
		gs.reset_turn_state()


func test_a_turn_starts_clean() -> void:
	var gs := _game()
	gs.flip_and_draw()
	gs.begin_card("extra_hands")
	gs.resolve_turn_card()
	gs.reset_turn_state()
	eq(gs.buy_limit(), 4, "modifiers are gone")
	check(not gs.has_pending_card(), "no card is waiting")
	check(not gs.flip_and_draw().is_empty(), "a new card can be drawn")


func test_the_shuffle_does_not_move_the_shop_or_the_hidden_deck() -> void:
	var a := _game(3, 11)
	var b := _game(3, 11)
	eq(a.circumstance_plan, b.circumstance_plan, "hidden deck")
	var sig_a := []
	var sig_b := []
	for s in a.shop:
		sig_a.append(s["count"])
	for s in b.shop:
		sig_b.append(s["count"])
	eq(sig_a, sig_b, "shop")


# ---------------------------------------------------------------- all cards

func _busy_game(seed_value: int) -> GameState:
	var gs := _game(3, seed_value)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for p in gs.players:
		for k in 24:
			var slot := rng.randi() % gs.shop.size()
			var cell := rng.randi() % 49
			if p.cells[cell] == null:
				p.cells[cell] = gs.shop[slot]["tile"].duplicate()
		p.money = rng.randi_range(0, 120)
		p.loans = rng.randi() % 3
	return gs


func test_every_card_resolves_safely_on_busy_and_empty_mats() -> void:
	for id in CardDefs.ids(CardDefs.EVENT) + CardDefs.ids(CardDefs.PENALTY):
		for variant in 3:
			var gs := _busy_game(10 + variant) if variant < 2 else _game(3, 4)
			gs.begin_card(id)
			var n := gs.card_choice_options().size() if gs.card_needs_choice() else 1
			for choice in n:
				var g := _busy_game(10 + variant) if variant < 2 else _game(3, 4)
				g.begin_card(id)
				var opts := g.card_choice_options()
				var r := g.resolve_turn_card(choice if g.card_needs_choice() else -1)
				if g.card_needs_choice() and not opts[choice]["available"]:
					eq(r, {}, "%s option %d is refused when unavailable" % [id, choice])
					continue
				check(r.has("lines") and r["lines"].size() > 0, "%s describes what happened" % id)
				for p in g.players:
					check(p.money >= 0, "%s: money stays positive" % id)
					check(p.loans >= 0 and p.free_roads >= 0, "%s: counters stay positive" % id)
					eq(p.cells.size(), 49, "%s: the mat keeps its size" % id)
				for i in g.players.size():
					check(g.score(i)["total"] > -500, "%s: score stays sane" % id)


# ---------------------------------------------------------------- the cards added later

func test_new_point_cards_give_points_to_the_right_players() -> void:
	var gs := _game(3)
	var me := gs.current_index()
	_play(gs, "festival_of_lights")
	for i in 3:
		eq(gs.players[i].card_points, 2 if i == me else 1, "festival: everyone 1, the drawer 2")
	var gs2 := _game(2)
	var me2 := gs2.current_index()
	_play(gs2, "ribbon_cutting")
	eq([gs2.players[me2].card_points, gs2.players[me2].money], [1, 129], "ribbon cutting: a point and 4 gold")
	var gs3 := _game(3)
	gs3.players[0].cells = mat(["PP.....", EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY])
	gs3.players[1].cells = mat(["P......", EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY])
	gs3.players[2].cells = mat([EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY])
	_play(gs3, "community_garden")
	eq([gs3.players[0].card_points, gs3.players[1].card_points, gs3.players[2].card_points], [1, 1, 0], "only planners with a park")
	_play(gs3, "flu_season")
	eq([gs3.players[0].card_points, gs3.players[1].card_points, gs3.players[2].card_points], [0, 0, -1], "everyone without a clinic loses")


func test_conditions_added_later() -> void:
	var gs := _game()
	var me := gs.current_index()
	gs.players[me].cells = mat(["P......", EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY])
	_play(gs, "heritage_prize")
	eq(gs.players[me].card_points, 0, "one park is not enough")
	gs.players[me].cells = mat(["PP.....", EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY])
	_play(gs, "heritage_prize")
	eq(gs.players[me].card_points, 2, "two parks")
	var g2 := _game()
	var m2 := g2.current_index()
	g2.players[m2].cells = mat(["s..L...", EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY])
	_play(g2, "gridlock")
	eq(g2.players[m2].card_points, -2, "a home without a route")
	g2.players[m2].cells = mat(["sRL....", EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY])
	_play(g2, "gridlock")
	eq(g2.players[m2].card_points, -2, "a connected city is spared")
	g2.players[m2].cells = mat([EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY])
	_play(g2, "gridlock")
	eq(g2.players[m2].card_points, -2, "an empty mat has no home to complain")


func test_interest_and_combined_cards() -> void:
	var gs := _game()
	var me := gs.current_index()
	gs.players[me].loans = 2
	_play(gs, "interest_due")
	eq(gs.players[me].money, 100 - 10, "5 gold for each loan")
	gs.players[me].money = 100
	gs.players[me].loans = 0
	_play(gs, "interest_due")
	eq(gs.players[me].money, 100, "no loan, no interest")
	gs.players[me].cells = mat(["MPP....", EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY])
	_play(gs, "grand_opening")
	eq([gs.players[me].money, gs.players[me].card_points], [130, 1], "a market earns gold and a point")
	var g2 := _game(2)
	var rich := 0 if g2.players[0].money >= g2.players[1].money else 1
	g2.players[rich].money = 140
	_play(g2, "overdue_taxes")
	eq([g2.players[rich].money, g2.players[rich].card_points], [134, -1], "the richest pays and loses a point")


func test_the_history_of_a_card_is_kept_per_player() -> void:
	var gs := _game(2)
	var me := gs.current_index()
	_play(gs, "ribbon_cutting")
	var last: Dictionary = gs.card_log[gs.card_log.size() - 1]
	eq([last["gold"][me], last["points"][me]], [4, 1], "what the card did to the drawer")
	eq([last["gold"][1 - me], last["points"][1 - me]], [0, 0], "and to the other planner")
	eq(gs.cards_drawn_by(me).size(), 1, "listed for the drawer")
	eq(gs.cards_drawn_by(1 - me).size(), 0, "and not for the other one")
	gs.reset_turn_state()
	_play(gs, "rent_hike", 0, 1)
	var choice: Dictionary = gs.card_log[gs.card_log.size() - 1]
	eq(choice["choice"], "Lose 1 point", "the option that was taken")
	eq(choice["points"][me], -1, "and its effect")


# ---------------------------------------------------------------- bills that grow with the city

func test_some_penalties_grow_with_what_you_have_built() -> void:
	var gs := _game()
	var me := gs.current_index()
	gs.players[me].cells = mat([EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY])
	_play(gs, "tax_audit")
	eq(gs.players[me].money, 100, "an empty mat owes nothing")
	gs.players[me].cells = mat(["RRRRRRR", "RRRR...", EMPTY, EMPTY, EMPTY, EMPTY, EMPTY])
	_play(gs, "tax_audit")
	eq(gs.players[me].money, 100 - 3, "11 tiles: 1 gold for every 3")
	gs.players[me].money = 100
	gs.players[me].cells = mat(["RRRRRRR", "RRRRRRR", "RRRRRRR", "RRRRRRR", "RRRRRRR", "RRRRRRR", "RRRRRRR"])
	_play(gs, "tax_audit")
	eq(gs.players[me].money, 100 - 12, "a full mat pays the cap")
	gs.players[me].money = 100
	_play(gs, "construction_delays")
	eq(gs.players[me].money, 100 - 8, "1 gold for every 2 roads, up to 8")
	gs.players[me].money = 100
	gs.players[me].cells = mat(["ssssss.", EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY])
	_play(gs, "emergency_repairs")
	eq(gs.players[me].money, 100 - 3, "6 citizens: 1 gold for every 2")


func test_penalties_cost_more_than_events_give() -> void:
	var gold := {CardDefs.EVENT: [], CardDefs.PENALTY: []}
	for type in CardDefs.TYPES:
		for id in CardDefs.ids(type):
			var amounts: Array = []
			_gold_amounts(CardDefs.info(id)["fx"], amounts)
			if not amounts.is_empty():
				gold[type].append(amounts.max())
	var event_avg := 0.0
	for v in gold[CardDefs.EVENT]:
		event_avg += v
	event_avg /= gold[CardDefs.EVENT].size()
	var penalty_avg := 0.0
	for v in gold[CardDefs.PENALTY]:
		penalty_avg += v
	penalty_avg /= gold[CardDefs.PENALTY].size()
	check(event_avg >= 3.0, "an event moves at least 3 gold on average (%.1f)" % event_avg)
	check(penalty_avg >= event_avg * 1.02, "penalties hurt a little more than events help (%.1f against %.1f)" % [penalty_avg, event_avg])


## Collects the gold amounts a card names (the size of each flat amount).
func _gold_amounts(fx: Dictionary, out: Array) -> void:
	match fx["op"]:
		"all":
			for f in fx["fxs"]:
				_gold_amounts(f, out)
		"choice":
			for o in fx["options"]:
				_gold_amounts(o["fx"], out)
		"gold_all", "gold_self", "gold_stat", "gold_if", "steal", "pay_each", "transfer", "discount_all":
			out.append(absf(float(fx["n"])))
		"gold_per", "gold_stat_per":
			out.append(absf(float(fx.get("n", fx.get("per", 0)))) * fx["cap"] / maxf(1.0, float(fx.get("every", 1))))
		"discount", "markup":
			out.append(absf(float(fx.get("by", 0))))


func test_no_card_gives_every_player_the_same_points() -> void:
	# equal gold for everyone is fine, but equal points never change who is ahead
	for type in CardDefs.TYPES:
		for id in CardDefs.ids(type):
			var parts: Array = []
			_flatten(CardDefs.info(id)["fx"], parts)
			check(not ("points_all" in parts), "%s: points go to some planners, not to all of them alike" % id)


func _flatten(fx: Dictionary, out: Array) -> void:
	match fx["op"]:
		"all":
			for f in fx["fxs"]:
				_flatten(f, out)
		"choice":
			for o in fx["options"]:
				_flatten(o["fx"], out)
		_:
			out.append(fx["op"])


func test_planners_who_do_not_qualify_for_points_are_left_alone() -> void:
	var gs := _game(3)
	gs.players[0].cells = mat(["RRRRRRR", "R......", EMPTY, EMPTY, EMPTY, EMPTY, EMPTY])
	gs.players[1].cells = mat(["RRRR...", EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY])
	gs.players[2].cells = mat(["PT.....", EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY])
	_play(gs, "heat_advisory")
	eq([gs.players[0].card_points, gs.players[1].card_points, gs.players[2].card_points], [-2, -2, 0], "only planners with no park or trees")


func test_amounts_on_a_card_are_a_number_and_a_picture_not_the_word_too() -> void:
	var Face = load("res://scripts/game/circumstance_card_face.gd")
	var text: String = Face.rich_rule("Gain 1 point and 2 gold.", "2 gold", "3F9A2B", 27, false, "")
	check(not text.contains("gold") and not text.contains("point"), "no unit word is left next to the pictures")
	check(text.contains("coin.svg") and text.contains("trophy.svg"), "a coin and a trophy stand in for them")
	eq(text.count("[img"), 2, "one picture for each amount")
	var plain: String = Face.rich_rule("Choose a free park.", "free park", "3F9A2B", 27, false, "")
	check(plain.contains("free park") and not plain.contains("[img"), "no amount: the key words are only coloured")
	for id in CardDefs.ids(CardDefs.EVENT) + CardDefs.ids(CardDefs.PENALTY):
		var rule: String = Face.rich_rule(CardDefs.info(id)["rule"], CardDefs.key_words(id), "3F9A2B", 27, false, "")
		check(not RegEx.create_from_string("\\d (gold|points?)").search(rule), "%s: no number is followed by its unit word" % id)
