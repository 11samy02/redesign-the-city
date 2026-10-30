extends PanelContainer
## Bottom bar: the two purchase slots, the instruction line, key hints and the turn buttons.

const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Widgets = preload("res://scripts/ui/widgets.gd")
const TileDefs = preload("res://scripts/core/tile_defs.gd")
const Tooltip = preload("res://scripts/ui/tooltip.gd")
const Bot = preload("res://scripts/core/bot.gd")

signal free_road_pressed
signal loan_pressed
signal end_turn_pressed

const KEY_HINTS := [["Arrows", "move"], ["Enter", "pick"], ["Tab", "switch"], ["Esc", "back"]]

var _gs
var _tooltip: Tooltip
var _slots: Array = []
var _instr: Label
var _instr_sub: Label
var _btn_road: Button
var _btn_loan: Button
var _btn_end: Button
var _end_pulse: Tween


func _init(gs, tooltip: Tooltip) -> void:
	_gs = gs
	_tooltip = tooltip
	add_theme_stylebox_override("panel", UiKit.box(UiKit.PANEL, 20, 1, UiKit.LINE, 14))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	add_child(h)
	h.add_child(_build_slots())
	h.add_child(_build_instructions())
	h.add_child(_build_key_hints())
	_btn_road = _make_button("Free road", "secondary", 18, free_road_pressed.emit)
	_hover_tip(_btn_road, "Free road  (R)", func(): return ["You get 2 free roads for the whole game.", "Place them on any empty lot during your turns."], "res://assets/tiles/road_15.svg")
	h.add_child(_btn_road)
	_btn_loan = _make_button("Take loan", "gold", 18, loan_pressed.emit)
	_hover_tip(_btn_loan, "Loan  (L)", _loan_tip_lines, "res://assets/ui/bank.svg")
	h.add_child(_btn_loan)
	_btn_end = _make_button("End turn", "primary", 20, end_turn_pressed.emit)
	_hover_tip(_btn_end, "End turn  (E)", func(): return ["Available once you have bought 2 tiles.", "Then pass the mouse and keyboard on."])
	h.add_child(_btn_end)


## Shows the tiles bought so far this turn in the two slots.
func show_bought(tiles: Array) -> void:
	for k in 2:
		_slots[k].tile = tiles[k] if k < tiles.size() else null


func road_button_rect() -> Rect2:
	return _btn_road.get_global_rect()


func loan_button_rect() -> Rect2:
	return _btn_loan.get_global_rect()


## Refreshes buttons and the instruction text for the current player.
## `hand` is the picked-up item ({} when empty), `busy` locks the buttons during animations.
func update(hand: Dictionary, busy: bool) -> void:
	var p = _gs.current_player()
	_btn_road.text = "Free road x%d" % p.free_roads
	if p.is_bot():
		for b in [_btn_road, _btn_loan, _btn_end]:
			b.disabled = true
		_set_end_pulse(false)
		_instr.text = "%s is planning their city" % p.name
		_instr_sub.text = "%s bot. Hover any tile to see what it does. Esc opens the menu." % Bot.level_name(p.bot_level)
		return
	_btn_road.disabled = busy or p.free_roads <= 0
	_btn_loan.disabled = busy or not _gs.can_take_loan()
	_btn_end.disabled = busy or not _gs.can_end_turn()
	_set_end_pulse(not _btn_end.disabled and hand.is_empty())
	_write_instruction(p, hand)


func _write_instruction(p, hand: Dictionary) -> void:
	var buys: int = _gs.buys_left()
	var hand_type: String = hand.get("type", "")
	if hand_type == "shop":
		_instr.text = "Choose a lot for your %s" % TileDefs.display_name(_gs.shop[hand["slot"]]).to_lower()
		_instr_sub.text = "Hover a lot to preview the points. Right-click or Esc puts it back."
	elif hand_type == "free":
		_instr.text = "Choose a lot for your free road"
		_instr_sub.text = "Roads link homes to amenities. Right-click or Esc puts it back."
	elif buys > 0 and _gs.can_take_loan():
		_instr.text = "You cannot afford %d more tile%s" % [buys, "" if buys == 1 else "s"]
		_instr_sub.text = "Take a loan: +10 gold now, -2 points at the end."
	elif buys > 0:
		_instr.text = "Buy tile %d of 2" % (_gs.purchases + 1)
		_instr_sub.text = "Pick a tile from the construction site. Hover anything to see what it does."
	else:
		_instr.text = "Both tiles are built"
		_instr_sub.text = _end_turn_hint(p)


func _end_turn_hint(p) -> String:
	if p.free_roads > 0:
		return "Place a free road, or end your turn."
	if _gs.turn + 1 >= _gs.players.size():
		return "End your turn to finish round %d." % _gs.round_number
	var nxt = _gs.players[_gs.turn_order()[_gs.turn + 1]]
	if nxt.is_bot():
		return "End your turn. %s (%s bot) plays next." % [nxt.name, Bot.level_name(nxt.bot_level)]
	return "End your turn and pass the mouse and keyboard to %s." % nxt.name


func _set_end_pulse(on: bool) -> void:
	if on and (_end_pulse == null or not _end_pulse.is_valid()):
		_btn_end.pivot_offset = _btn_end.size / 2
		_end_pulse = create_tween().set_loops()
		_end_pulse.tween_property(_btn_end, "scale", Vector2.ONE * 1.07, 0.45).set_trans(Tween.TRANS_SINE)
		_end_pulse.tween_property(_btn_end, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_SINE)
	elif not on and _end_pulse != null and _end_pulse.is_valid():
		_end_pulse.kill()
		_btn_end.scale = Vector2.ONE


func _loan_tip_lines() -> Array:
	return [
		"+10 gold now, [color=#E0533A]-2 points[/color] at final scoring.",
		"Only allowed when you cannot afford the tiles you still have to buy this round." if not _gs.can_take_loan() else "[color=#8DBB3C]You can take one now.[/color]"]


func _build_slots() -> Control:
	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", 8)
	for n in 2:
		var s := Widgets.TurnSlot.new(n + 1)
		slots.add_child(s)
		_slots.append(s)
	return slots


func _build_instructions() -> Control:
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 2)
	_instr = UiKit.label("", 24, UiKit.LIMESTONE, "display_bold")
	_instr_sub = UiKit.label("", 16, UiKit.MUTED)
	text.add_child(_instr)
	text.add_child(_instr_sub)
	return text


func _build_key_hints() -> Control:
	var keys := HBoxContainer.new()
	keys.add_theme_constant_override("separation", 6)
	keys.alignment = BoxContainer.ALIGNMENT_CENTER
	for k in KEY_HINTS:
		keys.add_child(UiKit.keycap(k[0]))
		keys.add_child(UiKit.label(k[1], 13, UiKit.MUTED))
	return keys


func _make_button(text: String, kind: String, size: int, on_pressed: Callable) -> Button:
	var b := UiKit.button(text, kind, size)
	b.pressed.connect(on_pressed)
	return b


## Shows `lines()` (called on hover, so it reflects the current state) in the tooltip.
func _hover_tip(b: Button, title: String, lines: Callable, icon_path := "") -> void:
	b.mouse_entered.connect(func(): _tooltip.show_text(title, lines.call(), b.get_global_rect(), icon_path))
	b.mouse_exited.connect(_tooltip.hide_tip)
