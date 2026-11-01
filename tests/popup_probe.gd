extends Node
## Plays a human turn on the real game screen with real mouse clicks and checks every popup and
## action on the way: free road, buying, loan, replacing a tile, the pause menu with rules and options,
## the city viewer, the circumstance card review, ending the turn and the bots' turns (watched and
## Instant) until the human is up again. Started by the Game autoload:
##   godot --path . --resolution 1600x900 -- --probe=popups

const TileDefs = preload("res://scripts/core/tile_defs.gd")

## Counts the errors Godot reports.
class ErrorCounter extends Logger:
	var count := 0
	var last := ""

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, _error_type: int, _script_backtraces: Array) -> void:
		count += 1
		last = "%s (%s:%d)" % [rationale if rationale != "" else code, file.get_file(), line]


var _scene: Control
var _errors := ErrorCounter.new()
var _failures: Array[String] = []
var _started := false
var _cooldown := 0


func _ready() -> void:
	Sfx.muted = true
	Engine.time_scale = 4.0
	OS.add_logger(_errors)
	Game.settings["bot_speed"] = 2
	Game.seats = [
		{"name": "Player 1", "color": 0, "bot": 0},
		{"name": "Nikos", "color": 1, "bot": 1},
		{"name": "Eleni", "color": 2, "bot": 2},
		{"name": "Maria", "color": 3, "bot": 3},
	]
	Game.new_game()
	_scene = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child.call_deferred(_scene)


func _process(_delta: float) -> void:
	if _scene == null or not _scene.is_inside_tree() or _started:
		return
	if _cooldown > 0:
		_cooldown -= 1
		return
	if _scene.circumstance_open or _scene.handoff_open or _scene.turn_card_open:
		_press_any_overlay_button()
		_cooldown = 15
	elif not _scene.busy and _scene.modal_count == 0 and not _scene.bot_active and not _scene.current_is_bot():
		_started = true
		_run()


# ================================================================ helpers

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _expect(cond: bool, msg: String) -> void:
	if cond:
		print("POPUP ok    %s" % msg)
	else:
		_failures.append(msg)
		print("POPUP FAIL  %s" % msg)


func _click_at(pos: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	var m := InputEventMouseMotion.new()
	m.position = pos
	m.global_position = pos
	get_viewport().push_input(m, true)
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = button
		e.pressed = down
		e.position = pos
		e.global_position = pos
		get_viewport().push_input(e, true)


func _key(code: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.pressed = down
		get_viewport().push_input(e, true)


func _find_button(text_start: String) -> Button:
	var found: Button = null
	for b in _scene.find_children("*", "Button", true, false):
		if b.is_visible_in_tree() and b.text.begins_with(text_start) and b.modulate.a > 0.9:
			found = b
	return found


## Real click on the visible button whose text starts with `text_start`. Returns false when there is none.
func _click_button(text_start: String) -> bool:
	var b := _find_button(text_start)
	if b == null:
		return false
	_click_at(b.get_global_rect().get_center())
	return true


func _press_any_overlay_button() -> void:
	for b in _scene.overlays.find_children("*", "Button", true, false):
		if b.is_visible_in_tree() and not b.disabled and b.modulate.a > 0.9:
			_click_at(b.get_global_rect().get_center())
			return
	# the coin and the decks of a turn card are tapped, not buttons: Enter taps what is glowing
	if _scene.turn_card_open:
		_key(KEY_ENTER)


func _cell(i: int) -> Vector2:
	return _scene.mat_view.cell_global_rect(i).get_center()


func _calm() -> bool:
	return not _scene.busy and _scene.modal_count == 0 and not _scene.bot_active


## Waits (up to `max_frames`) until the screen is free again.
func _until_calm(max_frames := 400) -> void:
	var n := 0
	while not _calm() and n < max_frames:
		await get_tree().process_frame
		n += 1


# ================================================================ the run

func _run() -> void:
	var gs = _scene.gs
	var p = gs.current_player()
	p.money = 100
	_scene.refresh_all()
	await _frames(10)

	await _test_free_road(gs, p)
	await _test_buying(gs, p)
	await _test_loan(gs, p)
	await _test_replace(gs, p)
	await _test_menus(gs)
	await _test_viewers(gs)
	await _test_bot_rounds(gs)
	await _test_last_turn_and_final(gs)

	print("POPUP probe done: %d failure(s), %d script error(s)" % [_failures.size(), _errors.count])
	if _errors.count > 0:
		print("POPUP last script error: %s" % _errors.last)
	for f in _failures:
		print("POPUP   - %s" % f)
	OS.remove_logger(_errors)
	Engine.time_scale = 1.0
	get_tree().quit(1 if not _failures.is_empty() or _errors.count > 0 else 0)


func _test_free_road(gs, p) -> void:
	var roads: int = p.free_roads
	_click_at(_scene._action_bar.road_button_rect().get_center())
	await _frames(8)
	_expect(_scene.hand.get("type", "") == "free", "clicking Free road picks up a road")
	_click_at(_cell(10), MOUSE_BUTTON_RIGHT)
	await _frames(8)
	_expect(_scene.hand.is_empty(), "right click puts the road back")
	_click_at(_scene._action_bar.road_button_rect().get_center())
	await _frames(8)
	_click_at(_cell(24))
	await _until_calm()
	await _frames(10)
	_expect(p.cells[24] != null and p.free_roads == roads - 1, "free road placed on the centre lot")


func _test_buying(gs, p) -> void:
	for k in 2:
		var empty: int = p.cells.find(null)
		_click_at(_scene.shop_view.views[0].get_global_rect().get_center())
		await _frames(8)
		_expect(_scene.hand.get("type", "") == "shop", "shop slot click picks up a tile (buy %d)" % (k + 1))
		_click_at(_cell(empty))
		await _until_calm()
		await _frames(10)
		_expect(p.cells[empty] != null and gs.purchases == k + 1, "tile placed on lot %d with a click" % empty)
	# the centre of the screen, where the invisible transition badge used to take the clicks
	_click_at(_scene.shop_view.views[0].get_global_rect().get_center())
	await _frames(8)
	var centre: int = 25
	if p.cells[centre] != null:
		centre = p.cells.find(null)
	_click_at(_cell(centre))
	await _until_calm()
	await _frames(10)
	_expect(p.cells[centre] != null, "a tile can be placed at lot %d near the middle" % centre)


func _test_loan(gs, p) -> void:
	p.money = 0
	_scene.refresh_all()
	await _frames(5)
	_expect(_click_button("Take loan"), "Take loan button can be clicked")
	await _frames(25)
	_expect(_scene.modal_count == 1, "loan popup is open")
	_expect(_click_button("Not now"), "loan popup has a Not now button")
	await _frames(25)
	_expect(p.loans == 0 and _scene.modal_count == 0, "Not now takes no loan and closes the popup")
	_click_button("Take loan")
	await _frames(25)
	_expect(_click_button("Take 20"), "loan popup has a Take 20 gold button")
	await _frames(40)
	_expect(p.loans == 1 and p.money == 20 and _scene.modal_count == 0, "taking the loan gives 20 gold (money %d)" % p.money)


func _test_replace(gs, p) -> void:
	p.money = 100
	_scene.refresh_all()
	await _frames(5)
	var slot := -1
	var occupied := -1
	for sl in gs.shop.size():
		for c in 49:
			if slot < 0 and gs.can_replace(sl, c):
				slot = sl
				occupied = c
	if slot < 0:
		_expect(false, "a valid replace (slot and lot) exists to test with")
		return
	_click_at(_scene.shop_view.views[slot].get_global_rect().get_center())
	await _frames(8)
	_click_at(_cell(occupied))
	await _frames(25)
	_expect(_scene.modal_count == 1, "clicking one of your tiles with a tile in hand asks to replace it")
	_expect(_click_button("Keep it"), "replace popup has Keep it")
	await _frames(25)
	_expect(not p.replaced and _scene.modal_count == 0, "Keep it changes nothing")
	_click_at(_cell(occupied))
	await _frames(25)
	_expect(_click_button("Replace it"), "replace popup has Replace it")
	await _until_calm(600)
	await _frames(20)
	_expect(p.replaced, "Replace it swaps the tile")
	_scene.set_hand({})


func _test_menus(gs) -> void:
	_expect(_click_button("Menu"), "Menu button can be clicked")
	await _frames(25)
	_expect(_scene.modal_count == 1, "pause popup is open")
	_click_button("How to play")
	await _frames(40)
	_expect(_scene.overlays.get_child_count() == 1 and _scene.modal_count == 1, "How to play opens the rules")
	_click_button("Close")
	await _frames(40)
	_expect(_scene.modal_count == 0, "rules close with the Close button")

	_click_button("Menu")
	await _frames(25)
	_click_button("Options")
	await _frames(40)
	_expect(_scene.modal_count == 1, "Options opens the options panel")
	_click_button("Done")
	await _frames(40)
	_expect(_scene.modal_count == 0, "options close with Done")

	_click_button("Menu")
	await _frames(25)
	_click_button("Main menu")
	await _frames(25)
	_expect(_click_button("Stay"), "Main menu asks before leaving, Stay is offered")
	await _frames(25)
	_expect(_scene.modal_count == 0 and not _scene.leaving, "Stay keeps the game")

	_click_button("Menu")
	await _frames(25)
	_click_button("Quit game")
	await _frames(25)
	_expect(_click_button("Stay"), "Quit asks before quitting, Stay is offered")
	await _frames(25)
	_expect(_scene.modal_count == 0, "Stay after Quit keeps the game")

	_click_button("Menu")
	await _frames(25)
	_click_button("Resume")
	await _frames(25)
	_expect(_scene.modal_count == 0, "Resume closes the pause popup")


func _test_viewers(gs) -> void:
	# another planner's city
	var panel: Control = _scene._order_panel._cards.get_child(1)
	_click_at(panel.get_global_rect().get_center())
	await _frames(30)
	_expect(_scene.modal_count == 1, "clicking a planner's card opens their city")
	_click_button("Back to the game")
	await _frames(40)
	_expect(_scene.modal_count == 0, "city viewer closes with Back to the game")
	# a revealed circumstance card in the top bar
	var strips: Array = _scene._top_bar.find_children("*", "HBoxContainer", true, false).filter(func(n): return n.get_script() != null and n.get_script().resource_path.ends_with("circumstance_strip.gd"))
	if strips.is_empty():
		_expect(false, "circumstance strip found in the top bar")
		return
	_click_at(strips[0].get_child(0).get_global_rect().get_center())
	await _frames(30)
	_expect(_scene.modal_count == 1, "clicking the revealed circumstance opens it again")
	_key(KEY_ESCAPE)
	await _frames(60)
	_expect(_scene.modal_count == 0, "the circumstance card closes with Esc")


## Finishes the turn with the real End turn button and waits for the human to be up again.
func _end_turn_and_wait(label: String) -> void:
	var gs = _scene.gs
	var p = gs.current_player()
	while gs.buys_left() > 0:
		if gs.can_take_loan():
			gs.take_loan()
		var done := false
		for slot in gs.shop.size():
			if gs.can_afford(slot) and gs.stack_tile(slot)["kind"] != TileDefs.Kind.ROAD:
				var cell: int = p.cells.find(null)
				if cell >= 0 and gs.buy_and_place(slot, cell):
					done = true
					break
		if not done:
			break
	_scene.refresh_all()
	await _frames(10)
	var round_before: int = gs.round_number
	_expect(_click_button("End turn"), "%s: End turn button can be clicked" % label)
	var n := 0
	while n < 60 * 120 and not (_scene.handoff_open or _scene.circumstance_open or gs.game_over):
		await get_tree().process_frame
		n += 1
	_expect(_scene.handoff_open or _scene.circumstance_open or gs.game_over, "%s: the human is up again after the bots (%d frames)" % [label, n])
	# deal with the cards in the way
	var m := 0
	while m < 60 * 60 and not (_scene.handoff_open == false and _calm() and not _scene.turn_card_open and not _scene.circumstance_open and not _scene.current_is_bot()):
		if gs.game_over:
			return
		_press_any_overlay_button()
		await _frames(12)
		m += 12
	_expect(_calm(), "%s: the screen is playable again (round %d, was %d)" % [label, gs.round_number, round_before])
	_expect(_scene._fast_forward == null or not _scene._fast_forward.visible, "%s: no bots-playing box is left over the board" % label)
	# losses from this turn's card
	await _clear_losses()


func _clear_losses() -> void:
	var gs = _scene.gs
	var n := 0
	while not gs.pending_losses.is_empty() and n < 40:
		var glowing: Array = gs.loss_cells()
		if glowing.is_empty():
			break
		_click_at(_cell(glowing[0]))
		await _frames(30)
		n += 1


func _test_bot_rounds(gs) -> void:
	Game.settings["bot_speed"] = 2
	await _end_turn_and_wait("watched bots")
	Game.settings["bot_speed"] = 3
	await _end_turn_and_wait("instant bots")
	Game.settings["bot_speed"] = 1


func _test_last_turn_and_final(gs) -> void:
	if gs.game_over:
		return
	gs.round_number = GameState_ROUNDS()
	var p = gs.current_player()
	p.free_roads = 2
	_scene.refresh_all()
	while gs.buys_left() > 0:
		var cell: int = p.cells.find(null)
		var bought := false
		for slot in gs.shop.size():
			if gs.can_afford(slot) and gs.buy_and_place(slot, cell):
				bought = true
				break
		if not bought:
			gs.take_loan()
	_scene.refresh_all()
	await _frames(10)
	_click_button("End turn")
	await _frames(30)
	_expect(_scene.modal_count == 1, "last turn with free roads left asks before ending")
	_expect(_click_button("Keep building"), "popup has Keep building")
	await _frames(30)
	_expect(_scene.modal_count == 0 and gs.current_player() == p, "Keep building returns to the turn")
	_click_button("End turn")
	await _frames(30)
	_expect(_click_button("End turn anyway"), "popup has End turn anyway")
	Game.settings["bot_speed"] = 3
	var n := 0
	while n < 60 * 90 and get_tree().root.get_node_or_null("Final") == null and not _final_scene_open():
		await get_tree().process_frame
		n += 1
	_expect(_final_scene_open(), "after the last turn the final scoring screen opens (%d frames)" % n)
	await _frames(240)


func _final_scene_open() -> bool:
	for c in get_tree().root.get_children():
		var s = c.get_script()
		if s != null and s.resource_path.ends_with("scripts/final.gd"):
			return true
	return false


func GameState_ROUNDS() -> int:
	return load("res://scripts/core/game_state.gd").ROUNDS
