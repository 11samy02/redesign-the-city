extends Node
## Draws every event and penalty card on the real game screen and plays it through with real mouse
## clicks: the choice buttons, Continue, and the glowing tiles a penalty takes. After each card it
## checks that nothing stayed locked and that Godot reported no script error. Choice cards run once
## per option. Started by the Game autoload:
##   godot --path . --resolution 1600x900 -- --probe=cards [--only=<card id>]

const TileDefs = preload("res://scripts/core/tile_defs.gd")
const Grid = preload("res://scripts/core/grid.gd")
const CardDefs = preload("res://scripts/core/card_defs.gd")

## Counts the errors Godot reports while a card runs.
class ErrorCounter extends Logger:
	var count := 0
	var last := ""

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, _error_type: int, _script_backtraces: Array) -> void:
		count += 1
		last = "%s (%s:%d)" % [rationale if rationale != "" else code, file.get_file(), line]


var _scene: Control
var _errors := ErrorCounter.new()
var _ready_to_start := false
var _running := false
var _want_choice := 0
var _cur := ""
var _click_cooldown := 0
var _rejected_once := false
var _failures: Array[String] = []
var _cards := 0
var _watchdog := 0
var _wrong_click_ok := true


func _ready() -> void:
	Sfx.muted = true
	Engine.time_scale = 5.0
	OS.add_logger(_errors)
	Game.seats = [
		{"name": "Player 1", "color": 0, "bot": 0},
		{"name": "Nikos", "color": 1, "bot": 1},
		{"name": "Eleni", "color": 2, "bot": 1},
		{"name": "Maria", "color": 3, "bot": 1},
	]
	Game.new_game()
	_scene = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child.call_deferred(_scene)


func _process(_delta: float) -> void:
	if _scene == null or not _scene.is_inside_tree():
		return
	if not _ready_to_start:
		_get_to_human_turn()
		return
	if not _running:
		return
	_watchdog += 1
	if _watchdog > 60 * 60:
		_fail(_cur, "stuck (option %d):" % (_want_choice + 1) + " turn_card_open=%s pending=%s modal=%d busy=%s" % [_scene.turn_card_open, str(_scene.gs.pending_losses), _scene.modal_count, _scene.busy])
		_finish()
		return
	if _click_cooldown > 0:
		_click_cooldown -= 1
		return
	_drive_ui()


## Clicks through the intro cards until the human can play.
func _get_to_human_turn() -> void:
	if _click_cooldown > 0:
		_click_cooldown -= 1
		return
	if _scene.circumstance_open or _scene.handoff_open or _scene.turn_card_open:
		if not _click_button(func(b): return true):
			_tap_enter()
		_click_cooldown = 15
	elif not _scene.busy and _scene.modal_count == 0 and not _scene.bot_active and not _scene.current_is_bot():
		_ready_to_start = true
		_card_loop()


func _drive_ui() -> void:
	var gs = _scene.gs
	if _scene.turn_card_open:
		# an option button of a choice card, or Continue
		var picked := _click_button(func(b): return b.get_meta("option", -1) == _want_choice or b.text == "Continue")
		if not picked:
			picked = _click_button(func(b): return b.text == "Continue" or b.has_meta("option"))
		if not picked:
			_tap_enter()
		_click_cooldown = 12
	elif not gs.pending_losses.is_empty() and _scene.modal_count == 0 and not _scene.busy:
		var glowing: Array = gs.loss_cells()
		if not _rejected_once:
			_rejected_once = true
			# a lot that is not glowing must be refused and change nothing
			for c in 49:
				if not glowing.has(c):
					var before: Array = gs.current_player().cells.duplicate()
					_click_at(_scene.mat_view.cell_global_rect(c).get_center())
					_click_cooldown = 6
					_wrong_click_ok = gs.current_player().cells == before
					return
		_click_at(_scene.mat_view.cell_global_rect(glowing[0]).get_center())
		_click_cooldown = 25


## The coin and the decks of a turn card are tapped, not buttons: Enter taps what is glowing.
func _tap_enter() -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = KEY_ENTER
		e.pressed = down
		get_viewport().push_input(e, true)


func _click_button(want: Callable) -> bool:
	for b in _scene.overlays.find_children("*", "Button", true, false):
		if b.is_visible_in_tree() and not b.disabled and b.modulate.a > 0.9 and want.call(b):
			_click_at(b.get_global_rect().get_center())
			return true
	return false


func _click_at(pos: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = pos
	m.global_position = pos
	get_viewport().push_input(m, true)
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		e.position = pos
		e.global_position = pos
		get_viewport().push_input(e, true)


## A mat with every kind of tile on it and a few empty lots.
func _full_mat() -> Array:
	var cells := Grid.empty()
	var kinds: Array = TileDefs.Kind.values()
	for k in [TileDefs.Kind.ROAD, TileDefs.Kind.ROAD, TileDefs.Kind.ROAD, TileDefs.Kind.ROAD, TileDefs.Kind.TREES, TileDefs.Kind.PARK,
			TileDefs.Kind.APT_S, TileDefs.Kind.APT_M, TileDefs.Kind.APT_L, TileDefs.Kind.COFFEE_SHOP, TileDefs.Kind.KIOSK, TileDefs.Kind.CLINIC]:
		kinds.append(k)
	# every tile gets its own 2x2 block of squares, seven blocks to a row, so any size fits
	for n in kinds.size():
		Grid.place(cells, (n / 7) * 2 * Grid.SIZE + (n % 7) * 2, TileDefs.make(kinds[n]))
	return cells


func _card_loop() -> void:
	var gs = _scene.gs
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
	var ids: Array = CardDefs.ids(CardDefs.EVENT) + CardDefs.ids(CardDefs.PENALTY)
	for id in ids:
		if only != "" and id != only:
			continue
		var options := 1
		var fx: Dictionary = CardDefs.info(id)["fx"]
		if fx["op"] == "choice":
			options = fx["options"].size()
		for choice in options:
			await _play_card(id, choice)
	_finish()


func _play_card(id: String, choice: int) -> void:
	var gs = _scene.gs
	var p = gs.current_player()
	gs.reset_turn_state()
	p.cells = _full_mat()
	p.bonus_tiles.clear()
	p.money = 100
	p.card_points = 0
	for q in gs.players:
		if q != p:
			q.money = 100
			q.cells = _full_mat()
	var type: String = CardDefs.type_of(id)
	gs.card_decks[type].append(id)
	_scene.refresh_all()
	_want_choice = choice
	_cur = id
	_rejected_once = false
	_wrong_click_ok = true
	_watchdog = 0
	_errors.count = 0
	var tiles_before: int = p.cells.count(null)
	_running = true
	await _scene._run_turn_card()
	_running = false
	# what _show_handoff does once the card is over
	_scene.busy = false
	_scene._update_actions()
	for i in 40:
		await get_tree().process_frame
	_cards += 1
	var tag := "%s%s" % [id, " (option %d)" % (choice + 1) if CardDefs.info(id)["fx"]["op"] == "choice" else ""]
	if not gs.turn_card.get("resolved", false):
		_fail(tag, "card was not resolved")
	if not gs.pending_losses.is_empty():
		_fail(tag, "a loss is still pending: %s" % str(gs.pending_losses))
	if _scene.modal_count != 0 or _scene.busy or _scene.turn_card_open or _scene._locked():
		_fail(tag, "screen stayed locked: modal=%d busy=%s card_open=%s" % [_scene.modal_count, _scene.busy, _scene.turn_card_open])
	if _scene.overlays.get_child_count() != 0:
		_fail(tag, "an overlay was left on screen (%d)" % _scene.overlays.get_child_count())
	if not _wrong_click_ok:
		_fail(tag, "clicking a lot that is not glowing changed the mat")
	if _errors.count > 0:
		_fail(tag, "script error: %s" % _errors.last)
	var lost: int = p.cells.count(null) - tiles_before
	print("CARD %-24s %-9s lost %d tile(s)%s" % [tag, "ok" if _failures.is_empty() or not _failures.back().begins_with(tag) else "FAIL", lost,
		"  bonus tiles: %d" % p.bonus_tiles.size() if not p.bonus_tiles.is_empty() else ""])
	# a free tile from an event card is placed with real clicks on the button and a lot
	if not p.bonus_tiles.is_empty():
		await _place_bonus(tag)


func _place_bonus(tag: String) -> void:
	var p = _scene.gs.current_player()
	# a lot where the gift fits, whatever its size
	var spots := Grid.valid_anchors(p.cells, TileDefs.footprint(p.bonus_tiles[0]))
	var empty: int = spots[spots.size() / 3] if not spots.is_empty() else p.cells.find(null)
	var before: int = p.bonus_tiles.size()
	_click_at(_scene._action_bar.bonus_button_rect().get_center())
	for i in 10:
		await get_tree().process_frame
	if _scene.hand.get("type", "") != "bonus":
		_fail(tag, "Free tile button did not pick up the tile (hand %s)" % str(_scene.hand))
		return
	_click_at(_scene.mat_view.cell_global_rect(empty).get_center())
	for i in 90:
		await get_tree().process_frame
	if p.bonus_tiles.size() != before - 1 or p.cells[empty] == null or _scene.busy:
		_fail(tag, "free tile was not placed with a click on lot %d" % empty)
	p.bonus_tiles.clear()
	_scene.set_hand({})


func _fail(tag: String, msg: String) -> void:
	_failures.append("%s: %s" % [tag, msg])
	print("CARD FAIL %s: %s" % [tag, msg])


func _finish() -> void:
	print("CARD probe done: %d card runs, %d failure(s)" % [_cards, _failures.size()])
	for f in _failures:
		print("CARD   - %s" % f)
	OS.remove_logger(_errors)
	Engine.time_scale = 1.0
	get_tree().quit(1 if not _failures.is_empty() else 0)
