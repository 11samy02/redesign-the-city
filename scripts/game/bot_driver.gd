extends RefCounted
## Plays a computer planner's whole turn on the game screen, with pauses so people can follow along.

const Bot = preload("res://scripts/core/bot.gd")

var _screen
var _rng := RandomNumberGenerator.new()
var _skipping := false


func _init(screen) -> void:
	_screen = screen
	_rng.randomize()


## Places the free tiles, buys the turn's tiles and ends the turn.
## Returns early, doing nothing more, when the screen is being left.
func play_turn() -> void:
	var gs = _screen.gs
	var p = gs.current_player()
	var level: int = p.bot_level
	_skipping = Game.bot_instant()
	_screen.bot_active = true
	if _skipping:
		_screen.begin_fast_forward()
	else:
		_screen.banner.set_money(p.money)
		_screen.refresh_all()
	if not _skipping:
		_screen.show_toast("%s (%s bot) is planning" % [p.name, Bot.level_name(level)])
		Sfx.play("turn")
		_screen.turn_intro()
	if await _pause(1.0):
		return
	if await _think(level):
		return
	# free tiles first: the roads and gifts the plan puts down early give the purchases something to join
	if not _skipping and await _place_bonus_tiles(level):
		return
	if not _skipping and await _place_free_roads(level):
		return
	while gs.buys_left() > 0 and not _skipping:
		if gs.can_take_loan():
			_screen.take_loan_now()
			if await _pause(1.0):
				return
			continue
		if await _buy_one(Bot.choose_purchase(gs, level, _rng)):
			return
	if _skipping:
		await _finish_quickly(level)
		if _screen_gone():
			return
	_screen.unfocus_cell()
	if await _pause(0.5):
		return
	if _skipping:
		# one frame per skipped turn, so a long run of bots never blocks the screen
		await _screen.get_tree().process_frame
		if _screen_gone():
			return
	_screen.bot_active = false
	_screen.finish_turn()


## Works out the turn's plan on a worker thread, so the window keeps drawing while a strong bot
## searches. Returns true when the screen is being left.
func _think(level: int) -> bool:
	var gs = _screen.gs
	# also while skipping: the "bots are playing" box keeps turning while the plan is worked out
	var worker := Thread.new()
	worker.start(Bot.think.bind(gs, level, _rng))
	var tree := Engine.get_main_loop() as SceneTree
	while worker.is_alive() and is_instance_valid(_screen) and not _screen.leaving:
		await tree.process_frame
	worker.wait_to_finish()
	return not is_instance_valid(_screen) or _screen.leaving


## The rest of the turn without pictures: the same choices, made straight on the game state.
func _finish_quickly(level: int) -> void:
	var gs = _screen.gs
	_screen.set_hand({})
	while not gs.current_player().bonus_tiles.is_empty():
		var cell: int = Bot.choose_bonus_cell(gs, level, _rng)
		if cell < 0 or not gs.place_bonus_tile(0, cell):
			break
	var road: int = Bot.choose_free_road(gs, level, _rng)
	while road >= 0 and gs.place_free_road(road):
		road = Bot.choose_free_road(gs, level, _rng)
	while gs.buys_left() > 0:
		if gs.can_take_loan():
			gs.take_loan()
			continue
		var move: Array = await _next_purchase(gs, level)
		if _screen_gone():
			return
		var tile: Dictionary = gs.stack_tile(move[0])
		if not gs.buy_and_place(move[0], move[1]):
			break
		_screen.turn_bought.append(tile)
	_screen.refresh_all()
	_screen.banner.set_money(gs.current_player().money)


func _screen_gone() -> bool:
	return not is_instance_valid(_screen) or _screen.leaving


## Works out the bot's next purchase. A hard bot looks a long way ahead, so that runs on its own
## thread while the screen keeps drawing (the board is not touched until it is done). Returns
## [shop slot, mat cell].
func _next_purchase(gs, level: int) -> Array:
	if level < Bot.MEDIUM:
		return Bot.choose_purchase(gs, level, _rng)
	var box: Array = []
	var worker := Thread.new()
	worker.start(func(): box.append(Bot.choose_purchase(gs, level, _rng)))
	var tree := Engine.get_main_loop() as SceneTree
	while worker.is_alive():
		await tree.process_frame
	worker.wait_to_finish()
	return box[0]


## Shows the pick, then the lot, then builds. Returns true when the screen is being left.
func _buy_one(move: Array) -> bool:
	var pick := {"type": "shop", "slot": move[0]}
	_screen.set_hand(pick)
	Sfx.play("pick")
	_screen.focus_slot(move[0])
	if await _pause(0.8):
		return true
	if _skipping:
		return false
	_screen.set_hand(pick)
	_screen.focus_cell(move[1])
	if await _pause(0.7):
		return true
	if _skipping:
		return false
	_screen.set_hand(pick)
	await _screen.commit(move[1])
	return await _pause(0.5)


## Builds the free tiles an event card gave this bot. Returns true when the screen is being left.
func _place_bonus_tiles(level: int) -> bool:
	var gs = _screen.gs
	while not gs.current_player().bonus_tiles.is_empty():
		var cell: int = Bot.choose_bonus_cell(gs, level, _rng)
		if cell < 0:
			return false
		_screen.set_hand({"type": "bonus", "index": 0})
		_screen.focus_cell(cell)
		if await _pause(0.6):
			return true
		if _skipping:
			return false
		_screen.set_hand({"type": "bonus", "index": 0})
		await _screen.commit(cell)
		if await _pause(0.4):
			return true
	return false


func _place_free_roads(level: int) -> bool:
	var road: int = Bot.choose_free_road(_screen.gs, level, _rng)
	while road >= 0:
		_screen.set_hand({"type": "free"})
		_screen.focus_cell(road)
		if await _pause(0.6):
			return true
		if _skipping:
			return false
		_screen.set_hand({"type": "free"})
		await _screen.commit(road)
		if await _pause(0.4):
			return true
		road = Bot.choose_free_road(_screen.gs, level, _rng)
	return false


## Waits between moves (scaled by the bot speed option) and while menus are open.
## Returns true when the screen is being left and the bot should stop.
func _pause(seconds: float) -> bool:
	if not is_instance_valid(_screen):
		return true
	var left := seconds * Game.bot_delay()
	while left > 0.0 and not _skipping:
		await _screen.get_tree().process_frame
		if not is_instance_valid(_screen):
			return true
		left -= _screen.get_process_delta_time()
	while is_instance_valid(_screen) and (_screen.modal_count > 0 or _screen.busy) and not _screen.leaving:
		await _screen.get_tree().process_frame
	return not is_instance_valid(_screen) or _screen.leaving
