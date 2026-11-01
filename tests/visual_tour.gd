extends Node
## Plays a full game through the real UI and saves screenshots along the way.
## Run: godot --path . -- --tour=<output dir> [--players=N]
## Activated by the Game autoload only when --tour is passed.

const Scoring = preload("res://scripts/core/scoring.gd")
const TileDefs = preload("res://scripts/core/tile_defs.gd")
const Bot = preload("res://scripts/core/bot.gd")
const GameState = preload("res://scripts/core/game_state.gd")

var out_dir := ""
var players := 4
## "greedy" builds sensible cities; "random" exercises loans and complaints.
var bot := "greedy"
## One human (driven by this tour) against Easy, Medium and Hard bots.
var solo := false
var _shot := 0
## Stops after this many screenshots (0 plays the whole game). --shots=N
var max_shots := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--players="):
			players = int(a.substr(10))
		elif a == "--solo":
			solo = true
		elif a.begins_with("--bot="):
			bot = a.substr(6)
		elif a.begins_with("--shots="):
			max_shots = int(a.substr(8))
	DirAccess.make_dir_recursive_absolute(out_dir)
	Sfx.muted = true
	_run.call_deferred()


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	_shot += 1
	var path := "%s/%02d_%s.png" % [out_dir, _shot, name]
	get_viewport().get_texture().get_image().save_png(path)
	print("TOUR shot ", path)
	if max_shots > 0 and _shot >= max_shots:
		print("TOUR stopped after ", _shot, " shots")
		get_tree().quit()


func _key(code: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	Input.parse_input_event(e)
	var up := e.duplicate()
	up.pressed = false
	Input.parse_input_event(up)


func _mouse_to(pos: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = pos
	m.global_position = pos
	get_viewport().push_input(m, true)


func _click(pos: Vector2) -> void:
	for down in [true, false]:
		var b := InputEventMouseButton.new()
		b.position = pos
		b.global_position = pos
		b.button_index = MOUSE_BUTTON_LEFT
		b.pressed = down
		get_viewport().push_input(b, true)


## The coin flip and the card of a turn: screenshots the first event and the first penalty, picks
## the first option of a choice card and dismisses the card.
func _turn_card(game, gs, shots: Dictionary) -> void:
	var human: bool = not gs.current_player().is_bot()
	var type: String = gs.turn_card.get("type", "")
	var key := "turncard_%s_%s" % [type, "human" if human else "bot"]
	var first: bool = not shots.has(key)
	if first:
		shots[key] = true
		await _wait(0.6)
		await _snap(key + "_1_coin")
		# a person taps the coin and then the deck it picked (Enter does both)
		if human:
			_key(KEY_ENTER)
		await _wait(1.9)
		await _snap(key + "_2a_before")
		if human:
			_key(KEY_ENTER)
		await _wait(0.25)
		await _snap(key + "_2b_flying")
		await _wait(0.25)
		await _snap(key + "_2c_flying")
		await _wait(0.25)
		await _snap(key + "_2d_arriving")
		await _wait(0.9)
		await _snap(key + "_3_card")
		await _wait(1.4)
		await _snap(key + "_4_result")
	if not human:
		await _wait(0.5)
		return
	if not first:
		await _wait(0.6)
		_key(KEY_ENTER)
		await _wait(1.9)
		_key(KEY_ENTER)
	await _wait(2.8)
	for b in game.overlays.find_children("*", "Button", true, false):
		if not b.disabled and b.text.length() > 2 and b.text.substr(1, 3) == "   ":
			b.pressed.emit()
			break
	await _wait(0.6)
	_key(KEY_ENTER)
	await _wait(0.9)


## Hovering a revealed card in the top bar shows its tooltip, and clicking it opens the full card.
func _strip_check(game) -> void:
	var strip = game._top_bar._circumstance_strip
	var pos: Vector2 = strip._slots[0].get_global_rect().get_center()
	_mouse_to(pos + Vector2(2, 2))
	_mouse_to(pos)
	await _wait(0.6)
	print("TOUR strip tooltip ", "OK" if game.tooltip.visible else "FAILED")
	await _snap("strip_hover")
	_click(pos)
	await _wait(1.2)
	print("TOUR strip click ", "OK" if game.modal_count > 0 else "FAILED")
	await _snap("strip_review")
	_key(KEY_ESCAPE)
	await _wait(0.8)
	print("TOUR strip close ", "OK" if game.modal_count == 0 else "FAILED")
	_mouse_to(Vector2(800, 450))


func _scene() -> Node:
	return get_tree().current_scene


func _run() -> void:
	Game.settings["bot_speed"] = 2
	await _wait(3.0)
	await _snap("title")
	var title = _scene()
	if solo:
		title._setup_solo()
		Game.seats[0]["name"] = "Eleni"
		for k in range(1, Game.seats.size()):
			Game.seats[k]["bot"] = k  # one bot of each difficulty
	else:
		for k in players - 2:
			title._add_seat()
		var names := ["Eleni", "Marios", "Sofia", "Andreas"]
		for k in players:
			Game.seats[k]["name"] = names[k]
	title._rebuild_seats()
	await _wait(0.5)
	await _snap("title_seats")
	title._open_options()
	await _wait(0.6)
	await _snap("options")
	title._overlays.get_child(0).close()
	await _wait(0.4)
	title._open_rules()
	await _wait(0.6)
	await _snap("rules_goal")
	var rp = title._overlays.get_child(0)
	rp._show_tab(2)
	await _wait(0.4)
	await _snap("rules_tiles")
	rp._show_tab(3)
	await _wait(0.4)
	await _snap("rules_people")
	rp._show_tab(4)
	await _wait(0.4)
	await _snap("rules_happiness")
	rp._show_tab(6)
	await _wait(0.5)
	await _snap("rules_turn_cards")
	rp._show_tab(7)
	await _wait(0.4)
	await _snap("rules_circumstances")
	rp.close()
	await _wait(0.5)
	title._start()
	await _wait(1.6)

	var game = _scene()
	var gs = Game.state
	await _wait(1.0)
	print("TOUR sizes viewport ", get_viewport().get_visible_rect().size, " top ", game._top_bar.get_combined_minimum_size(), " action ", game._action_bar.get_combined_minimum_size(),
		" order ", game._order_panel.get_combined_minimum_size(), " shop ", game._shop_panel.get_combined_minimum_size(), " center ", game.banner.get_combined_minimum_size())
	var turn := 0
	var shots := {}
	var guard := 0
	while not gs.is_game_over() and guard < 4000:
		guard += 1
		if game.circumstance_open:
			var circumstance_key := "circumstance_r%d" % gs.round_number
			if not shots.has(circumstance_key):
				shots[circumstance_key] = true
				await _snap(circumstance_key + "_facedown")
				await _wait(2.1)
				await _snap(circumstance_key)
				await _wait(0.5)
				await _snap(circumstance_key + "_sheen")
			_key(KEY_ENTER)
			await _wait(0.8)
			continue
		if game.turn_card_open:
			await _turn_card(game, gs, shots)
			continue
		if game.handoff_open:
			var key := "handoff_r%d" % gs.round_number
			if not shots.has(key):
				shots[key] = true
				await _wait(0.6)
				await _snap(key)
			_key(KEY_ENTER)
			await _wait(0.8)
			continue
		if gs.round_number == 2 and gs.turn == 0 and not shots.has("round_banner") and game.overlays.get_child_count() > 0:
			shots["round_banner"] = true
			await _wait(1.0)
			await _snap("round_banner")
			await _wait(2.6)
			await _snap("cards_reordered")
			continue
		if gs.current_player().is_bot() or game.busy or game.modal_count > 0:
			if game.bot_active and gs.purchases == 1 and not shots.has("bot_turn"):
				shots["bot_turn"] = true
				await _snap("bot_turn")
			await _wait(0.2)
			continue
		if gs.round_number >= 2 and not shots.has("strip"):
			shots["strip"] = true
			await _strip_check(game)
		turn += 1
		await _play_turn(game, gs, turn)
		if gs.round_number == GameState.ROUNDS:
			# showcase: hover the home with the most routes
			var best := -1
			var most := -1
			for a in game.result["apartments"]:
				if a["routes"].size() > most:
					most = a["routes"].size()
					best = a["index"]
			if best >= 0:
				game._on_cell_hovered(best, true)
				await _wait(0.8)
			await _snap("last_turn")
			if best >= 0:
				game._on_cell_hovered(best, false)
		game._on_end_turn()
		await _wait(0.4)
		# "free roads left" prompt: end anyway
		for b in game.overlays.find_children("*", "Button", true, false):
			if b.text == "End turn anyway":
				b.pressed.emit()
		await _wait(0.5)
	while _scene() == game:
		await _wait(0.5)
	await _wait(3.0)
	await _snap("final_counting")
	await _wait(14.0)
	await _snap("scoreboard")
	var fin = _scene()
	fin.goto("cities")
	await _wait(0.6)
	await _snap("final_cities")
	fin.goto("reflect")
	for k in fin.gs.players.size():
		await _wait(0.6)
		await _snap("reflection_asking_%d" % k)
		var cards := []
		for b in fin.reflection.find_children("*", "Button", true, false):
			if b.flat:
				cards.append(b)
		if not cards.is_empty():
			cards[k % cards.size()].pressed.emit()
		await _wait(2.0)
		await _snap("reflection_picked_%d" % k)
		fin.reflection.next()
	for k in gs.players.size():
		print("TOUR score ", gs.players[k].name, " level ", gs.players[k].bot_level, " total ", gs.score(k)["total"], " citizens ", gs.score(k)["citizens"], " loans ", gs.players[k].loans, " card points ", gs.players[k].card_points)
	print("TOUR done")
	get_tree().quit()


## Buys one tile with only the keyboard: Tab to the shop, arrows, Enter, Enter.
func _keyboard_purchase(game, gs) -> void:
	var before: int = gs.purchases
	var target := -1
	for s in gs.shop.size():
		if gs.can_afford(s):
			target = s
			break
	var row := 0
	var col := 0
	for r in game.kb.shop_rows.size():
		var c: int = game.kb.shop_rows[r].find(target)
		if c >= 0:
			row = r
			col = c
	_key(KEY_TAB)
	await _wait(0.1)
	_key(KEY_TAB)
	await _wait(0.1)
	for k in row:
		_key(KEY_DOWN)
		await _wait(0.05)
	for k in col:
		_key(KEY_RIGHT)
		await _wait(0.05)
	await _wait(0.3)
	await _snap("keyboard_focus")
	_key(KEY_ENTER)
	await _wait(0.3)
	_key(KEY_ENTER)
	await _wait(1.2)
	print("TOUR keyboard purchase ", "OK" if gs.purchases == before + 1 else "FAILED (kb_area=%s kb_shop=%d target=%d)" % [game.kb.area, game.kb.shop, target])
	# Esc opens the pause menu, Esc again resumes
	_key(KEY_ESCAPE)
	await _wait(0.5)
	await _snap("pause_menu")
	_key(KEY_ESCAPE)
	await _wait(0.4)
	print("TOUR pause resume ", "OK" if game.modal_count == 0 else "FAILED")


func _play_turn(game, gs, turn: int) -> void:
	if turn == 1:
		await _keyboard_purchase(game, gs)
	while gs.purchases < gs.buy_limit():
		if gs.can_take_loan():
			game._on_loan()
			await _wait(0.4)
			_key(KEY_ENTER)
			await _wait(0.9)
			continue
		var best := _best_move(gs)
		game._on_slot_hovered(best[0], true)
		await _wait(0.25)
		if turn == 1 and gs.purchases == 0:
			await _snap("shop_tooltip")
		game._on_slot_pressed(best[0])
		await _wait(0.15)
		game._on_cell_hovered(best[1], true)
		await _wait(0.3)
		if turn == 1 or turn == gs.players.size() * 3 + 1:
			await _snap("placement_preview_t%d" % turn)
		game._on_cell_pressed(best[1])
		await _wait(0.9)
		game._on_cell_hovered(best[1], false)
	var p = gs.current_player()
	# free tiles from event cards
	while not p.bonus_tiles.is_empty():
		var brng := RandomNumberGenerator.new()
		brng.randomize()
		var bc: int = Bot.choose_bonus_cell(gs, Bot.HARD, brng)
		if bc < 0:
			break
		game._on_bonus_tile()
		await _wait(0.15)
		game._on_cell_pressed(bc)
		await _wait(0.9)
	# free roads when they help
	while p.free_roads > 0:
		var cell := _best_cell(p, TileDefs.make(TileDefs.Kind.ROAD), gs)
		if (cell[1] <= 0 or bot != "greedy") and gs.round_number < GameState.ROUNDS:
			break
		if cell[0] < 0:
			break
		game._on_free_road()
		await _wait(0.1)
		game._on_cell_pressed(cell[0])
		await _wait(0.9)
	if gs.round_number == 3 and gs.turn == 0:
		var apt := -1
		for i in 49:
			if p.cells[i] != null and TileDefs.is_home(p.cells[i]["kind"]):
				apt = i
		if apt >= 0:
			game._on_cell_hovered(apt, true)
			await _wait(0.5)
			await _snap("apartment_routes")
			game._on_cell_hovered(apt, false)
		game._open_city_viewer((gs.current_index() + 1) % gs.players.size())
		await _wait(0.5)
		await _snap("city_viewer")
		_key(KEY_ESCAPE)
		await _wait(0.4)


func _best_cell(p, tile: Dictionary, gs) -> Array:
	var base: int = Scoring.evaluate(p.cells, p.loans)["total"]
	var best := [-1, -999]
	for c in 49:
		if p.cells[c] != null:
			continue
		var cells: Array = p.cells.duplicate()
		cells[c] = tile
		var d: int = Scoring.evaluate(cells, p.loans)["total"] - base
		if d > best[1]:
			best = [c, d]
	return best


func _best_move(gs) -> Array:
	var p = gs.current_player()
	if bot == "greedy":
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		return Bot.choose_purchase(gs, Bot.HARD, rng)
	if bot == "random" or bot == "grey":
		var slots := []
		for s in gs.shop.size():
			if gs.can_afford(s):
				var k: int = gs.stack_tile(s)["kind"]
				if bot == "grey" and (k == TileDefs.Kind.PARK or k == TileDefs.Kind.TREES):
					continue
				slots.append(s)
		if slots.is_empty():
			for s in gs.shop.size():
				if gs.can_afford(s):
					slots.append(s)
		var empty := []
		for c in 49:
			if p.cells[c] == null:
				empty.append(c)
		return [slots.pick_random(), empty.pick_random(), 0.0]
	var best := [-1, -1, -9999.0]
	for s in gs.shop.size():
		if not gs.can_afford(s):
			continue
		var r := _best_cell(p, gs.stack_tile(s), gs)
		# small bonus for buildings and roads so cities grow instead of hoarding gold
		var score: float = r[1] + randf() * 0.5 + (0.6 if TileDefs.is_home(gs.stack_tile(s)["kind"]) else 0.0)
		if score > best[2]:
			best = [s, r[0], score]
	return best
