extends Node
## Plays a full game through the real UI and saves screenshots along the way.
## Run: godot --path . -- --tour=<output dir> [--players=N]
## Activated by the Game autoload only when --tour is passed.

const Scoring = preload("res://scripts/core/scoring.gd")
const TileDefs = preload("res://scripts/core/tile_defs.gd")
const Bot = preload("res://scripts/core/bot.gd")

var out_dir := ""
var players := 4
## "greedy" builds sensible cities; "random" exercises loans and complaints.
var bot := "greedy"
## One human (driven by this tour) against Easy, Medium and Hard bots.
var solo := false
var _shot := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--players="):
			players = int(a.substr(10))
		elif a == "--solo":
			solo = true
		elif a.begins_with("--bot="):
			bot = a.substr(6)
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


func _key(code: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	Input.parse_input_event(e)
	var up := e.duplicate()
	up.pressed = false
	Input.parse_input_event(up)


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
	rp._show_tab(3)
	await _wait(0.4)
	await _snap("rules_happiness")
	rp.close()
	await _wait(0.5)
	title._start()
	await _wait(1.6)

	var game = _scene()
	var gs = Game.state
	var turn := 0
	var shots := {}
	var guard := 0
	while not gs.is_game_over() and guard < 4000:
		guard += 1
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
		turn += 1
		await _play_turn(game, gs, turn)
		if gs.round_number == 4:
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
	_key(KEY_TAB)
	await _wait(0.1)
	_key(KEY_TAB)
	await _wait(0.1)
	for k in target / 6:
		_key(KEY_DOWN)
		await _wait(0.05)
	for k in target % 6:
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
	while gs.purchases < 2:
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
		if turn == 1 or turn == gs.players.size() * 2 + 1:
			await _snap("placement_preview_t%d" % turn)
		game._on_cell_pressed(best[1])
		await _wait(0.9)
		game._on_cell_hovered(best[1], false)
	# free roads when they help
	var p = gs.current_player()
	while p.free_roads > 0:
		var cell := _best_cell(p, TileDefs.make(TileDefs.Kind.ROAD), gs)
		if (cell[1] <= 0 or bot != "greedy") and gs.round_number < 4:
			break
		if cell[0] < 0:
			break
		game._on_free_road()
		await _wait(0.1)
		game._on_cell_pressed(cell[0])
		await _wait(0.9)
	if gs.round_number == 3 and gs.turn == 0:
		var apt := -1
		for i in 16:
			if p.cells[i] != null and TileDefs.is_apartment(p.cells[i]["kind"]):
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
	for c in 16:
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
				var k: int = gs.shop[s]["kind"]
				if bot == "grey" and (k == TileDefs.Kind.PARK or k == TileDefs.Kind.TREES):
					continue
				slots.append(s)
		if slots.is_empty():
			for s in gs.shop.size():
				if gs.can_afford(s):
					slots.append(s)
		var empty := []
		for c in 16:
			if p.cells[c] == null:
				empty.append(c)
		return [slots.pick_random(), empty.pick_random(), 0.0]
	var best := [-1, -1, -9999.0]
	for s in gs.shop.size():
		if not gs.can_afford(s):
			continue
		var r := _best_cell(p, gs.shop[s], gs)
		# small bonus for buildings and roads so cities grow instead of hoarding gold
		var score: float = r[1] + randf() * 0.5 + (0.6 if TileDefs.is_apartment(gs.shop[s]["kind"]) else 0.0)
		if score > best[2]:
			best = [s, r[0], score]
	return best
