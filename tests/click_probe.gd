extends Node
## Plays a human turn with real mouse events and reports which control receives each click, so a
## layer that swallows input shows up. Started by the Game autoload:
##   godot --path . --resolution 1600x900 -- --probe=click

var _scene: Control
var _frames := 0
var _stage := 0
var _wait := 0


func _ready() -> void:
	Sfx.muted = true
	Game.seats = [
		{"name": "Player 1", "color": 0, "bot": 0},
		{"name": "Nikos", "color": 1, "bot": 3},
		{"name": "Eleni", "color": 2, "bot": 3},
		{"name": "Maria", "color": 3, "bot": 3},
	]
	Game.new_game()
	_scene = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child.call_deferred(_scene)


func _process(_delta: float) -> void:
	_frames += 1
	if _frames > 60 * 40:
		print("CLICK timeout in stage %d" % _stage)
		get_tree().quit(1)
	if _scene == null or not _scene.is_inside_tree():
		return
	if _wait > 0:
		_wait -= 1
		return
	match _stage:
		0:
			if _scene.circumstance_open:
				_press_first_button(_scene.overlays)
				_wait = 20
			elif _scene.handoff_open:
				_press_first_button(_scene.overlays)
				_wait = 20
			elif _scene.turn_card_open:
				_press_first_button(_scene.overlays)
				# the coin and the decks are tapped, not buttons: Enter taps what is glowing
				for down in [true, false]:
					var e := InputEventKey.new()
					e.keycode = KEY_ENTER
					e.pressed = down
					get_viewport().push_input(e, true)
				_wait = 20
			elif not _scene.busy and _scene.modal_count == 0 and not _scene.bot_active and not _scene.current_is_bot():
				_stage = 1
		1:
			_motion(_slot_pos())
			_wait = 4
			_stage = 2
		2:
			_report("shop slot 0", _slot_pos())
			_click(_slot_pos())
			_wait = 10
			_stage = 3
		3:
			print("CLICK hand after slot click: %s" % str(_scene.hand))
			_motion(_cell_pos(24))
			_wait = 4
			_stage = 4
		4:
			for i in [0, 24, 48]:
				print("CLICK cell %d rect %s" % [i, _scene.mat_view.views[i].get_global_rect()])
			_report("mat cell 24", _cell_pos(24))
			_click(_cell_pos(24))
			_wait = 70
			_stage = 5
		5:
			print("CLICK after cell click: hand=%s busy=%s tile at 24=%s" % [str(_scene.hand), _scene.busy, _scene.gs.current_player().cells[24] != null])
			_motion(_scene._action_bar._btn_end.get_global_rect().get_center())
			_wait = 4
			_stage = 6
		6:
			var btn: Button = _scene._action_bar._btn_end
			_report("end turn button", btn.get_global_rect().get_center())
			print("CLICK RESULT: %s" % ("FAIL, the transition layer takes clicks" if _failed else "ok"))
			get_tree().quit(1 if _failed else 0)


func _slot_pos() -> Vector2:
	return _scene.shop_view.views[0].get_global_rect().get_center()


func _cell_pos(i: int) -> Vector2:
	return _scene.mat_view.views[i].get_global_rect().get_center()


## Every visible control of the Transition layer that would take a click at `pos`.
func _blockers(pos: Vector2) -> Array:
	var out: Array = []
	for c in Transition.find_children("*", "Control", true, false):
		if c.mouse_filter != Control.MOUSE_FILTER_IGNORE and c.is_visible_in_tree() and c.get_global_rect().has_point(pos):
			out.append("%s(filter %d)" % [c.get_class(), c.mouse_filter])
	return out


var _failed := false


func _report(label: String, pos: Vector2) -> void:
	if not _blockers(pos).is_empty():
		_failed = true
	var c = get_viewport().gui_get_hovered_control()
	print("CLICK %s at %s: hovered %s, transition blockers %s" % [label, pos, c.get_class() + "#" + str(c.get("index")) if c != null else "none", str(_blockers(pos))])


func _motion(pos: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = pos
	m.global_position = pos
	get_viewport().push_input(m, true)


func _click(pos: Vector2) -> void:
	_motion(pos)
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		e.position = pos
		e.global_position = pos
		get_viewport().push_input(e, true)


func _press_first_button(node: Node) -> void:
	for b in node.find_children("*", "Button", true, false):
		if not b.disabled and b.is_visible_in_tree():
			b.pressed.emit()
			return
