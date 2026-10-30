extends RefCounted
## Plays a computer planner's whole turn on the game screen, with pauses so people can follow along.

const Bot = preload("res://scripts/core/bot.gd")

var _screen
var _rng := RandomNumberGenerator.new()


func _init(screen) -> void:
	_screen = screen
	_rng.randomize()


## Buys and places both tiles, then spends free roads and ends the turn.
## Returns early, doing nothing more, when the screen is being left.
func play_turn() -> void:
	var gs = _screen.gs
	var p = gs.current_player()
	var level: int = p.bot_level
	_screen.bot_active = true
	_screen.banner.set_money(p.money)
	_screen.refresh_all()
	_screen.show_toast("%s (%s bot) is planning" % [p.name, Bot.level_name(level)])
	Sfx.play("turn")
	_screen.turn_intro()
	if await _pause(1.0):
		return
	while gs.buys_left() > 0:
		if gs.can_take_loan():
			_screen.take_loan_now()
			if await _pause(1.0):
				return
			continue
		if await _buy_one(Bot.choose_purchase(gs, level, _rng)):
			return
	if await _place_free_roads(level):
		return
	_screen.unfocus_cell()
	if await _pause(0.5):
		return
	_screen.bot_active = false
	_screen.finish_turn()


## Shows the pick, then the lot, then builds. Returns true when the screen is being left.
func _buy_one(move: Array) -> bool:
	var pick := {"type": "shop", "slot": move[0]}
	_screen.set_hand(pick)
	Sfx.play("pick")
	_screen.focus_slot(move[0])
	if await _pause(0.8):
		return true
	_screen.set_hand(pick)
	_screen.focus_cell(move[1])
	if await _pause(0.7):
		return true
	_screen.set_hand(pick)
	await _screen.commit(move[1])
	return await _pause(0.5)


func _place_free_roads(level: int) -> bool:
	var road: int = Bot.choose_free_road(_screen.gs, level, _rng)
	while road >= 0:
		_screen.set_hand({"type": "free"})
		_screen.focus_cell(road)
		if await _pause(0.6):
			return true
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
	await _screen.get_tree().create_timer(seconds * Game.bot_delay()).timeout
	while is_instance_valid(_screen) and (_screen.modal_count > 0 or _screen.busy) and not _screen.leaving:
		await _screen.get_tree().process_frame
	return not is_instance_valid(_screen) or _screen.leaving
