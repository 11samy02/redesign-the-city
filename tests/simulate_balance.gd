extends SceneTree
## Plays many bot-versus-bot games, turn cards included, and prints how the economy behaves.
## Not a test: it is for tuning the purse, prices, loans and cards.
## Run: godot --headless --path . --script res://tests/simulate_balance.gd -- [--games=6] [--level=2]

const GameState = preload("res://scripts/core/game_state.gd")
const Bot = preload("res://scripts/core/bot.gd")
const CardDefs = preload("res://scripts/core/card_defs.gd")
const TileDefs = preload("res://scripts/core/tile_defs.gd")

## Gold every planner starts with; --money=N overrides it to try other purses.
var start_money := GameState.START_MONEY
## Multiplies every shop stack; --supply=1.25 tries a bigger shop.
var supply := 1.0


func _init() -> void:
	var games := 6
	var level := Bot.MEDIUM
	var only_seats := 0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--games="):
			games = int(a.substr(8))
		elif a.begins_with("--level="):
			level = int(a.substr(8))
		elif a.begins_with("--money="):
			start_money = int(a.substr(8))
		elif a.begins_with("--seats="):
			only_seats = int(a.substr(8))
		elif a.begins_with("--supply="):
			supply = float(a.substr(9))
	var started := Time.get_ticks_msec()
	var card_counts := {}
	var total := {"games": 0, "players": 0, "gold_left": 0, "with_loan": 0, "loans": 0, "tiles": 0, "citizens": 0,
		"unhappy": 0, "score": 0, "min_score": 9999, "max_score": -9999, "card_points": 0, "card_gold": 0}
	for seats in [2, 3, 4]:
		if only_seats > 0 and seats != only_seats:
			continue
		var seat := {"players": 0, "gold_left": 0, "with_loan": 0, "loans": 0, "tiles": 0, "citizens": 0, "unhappy": 0, "score": 0, "min": 9999, "max": -9999}
		for g in games:
			var gs := _play(seats, level, 1000 + seats * 100 + g, card_counts)
			for i in gs.players.size():
				var p = gs.players[i]
				var r := gs.score(i)
				seat["players"] += 1
				seat["gold_left"] += p.money
				seat["loans"] += p.loans
				seat["with_loan"] += 1 if p.loans > 0 else 0
				seat["tiles"] += p.cells.count(null) * -1 + p.cells.size()
				seat["citizens"] += r["citizens"]
				seat["unhappy"] += r["unhappy_citizens"]
				seat["score"] += r["total"]
				seat["min"] = mini(seat["min"], r["total"])
				seat["max"] = maxi(seat["max"], r["total"])
				total["card_points"] += p.card_points
		var n: int = seat["players"]
		print("%d seats (%d games, %d planners): gold left %.1f, loans per planner %.2f (%d%% took one), tiles %.1f, citizens %.1f (%d%% unhappy), score avg %.1f (min %d, max %d)" % [
			seats, games, n, seat["gold_left"] / float(n), seat["loans"] / float(n), 100 * seat["with_loan"] / n,
			seat["tiles"] / float(n), seat["citizens"] / float(n), 100 * seat["unhappy"] / maxi(1, seat["citizens"]),
			seat["score"] / float(n), seat["min"], seat["max"]])
	var events := 0
	var penalties := 0
	for id in card_counts:
		if CardDefs.is_event(id):
			events += card_counts[id]
		else:
			penalties += card_counts[id]
	print("cards drawn: %d events, %d penalties, %d different cards" % [events, penalties, card_counts.size()])
	print("took %.0f s" % ((Time.get_ticks_msec() - started) / 1000.0))
	quit()


func _play(seats: int, level: int, seed_value: int, card_counts: Dictionary) -> GameState:
	var gs := GameState.new()
	var names := []
	var colors := []
	var levels := []
	for i in seats:
		names.append("P%d" % i)
		colors.append(i)
		levels.append(level)
	gs.setup(names, colors, seed_value, levels)
	for p in gs.players:
		p.money = start_money
	for st in gs.shop:
		st["count"] = ceili(st["count"] * supply)
		st["start"] = st["count"]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var guard := 0
	while not gs.is_game_over() and guard < 600:
		guard += 1
		if gs.has_pending_circumstance():
			gs.reveal_circumstance()
		var draw := gs.flip_and_draw()
		if not draw.is_empty():
			card_counts[draw["id"]] = card_counts.get(draw["id"], 0) + 1
			gs.resolve_turn_card(Bot.choose_card_option(gs, rng) if gs.card_needs_choice() else -1)
		while not gs.current_player().bonus_tiles.is_empty():
			var cell := Bot.choose_bonus_cell(gs, level, rng)
			if cell < 0 or not gs.place_bonus_tile(0, cell):
				break
		while gs.purchases < gs.buy_limit() and gs.buys_left() > 0:
			while gs.can_take_loan():
				gs.take_loan()
			var move := Bot.choose_purchase(gs, level, rng)
			if not gs.buy_and_place(move[0], move[1]):
				break
		var road := Bot.choose_free_road(gs, level, rng)
		while road >= 0:
			gs.place_free_road(road)
			road = Bot.choose_free_road(gs, level, rng)
		gs.end_turn()
	return gs
