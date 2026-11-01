extends PanelContainer
## Bottom bar: the purchase slots, the instruction line, key hints and the turn buttons.

const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Widgets = preload("res://scripts/ui/widgets.gd")
const TileDefs = preload("res://scripts/core/tile_defs.gd")
const TileView = preload("res://scripts/ui/tile_view.gd")
const Tooltip = preload("res://scripts/ui/tooltip.gd")
const Bot = preload("res://scripts/core/bot.gd")
const CardEffects = preload("res://scripts/core/card_effects.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const Scoring = preload("res://scripts/core/scoring.gd")

signal free_road_pressed
signal loan_pressed
signal end_turn_pressed
signal bonus_tile_pressed

const STOCK_SIZE := 60

const KEY_HINTS := [["Arrows", "move"], ["Enter", "pick"], ["Tab", "switch"], ["Esc", "back"]]

var _gs
var _tooltip: Tooltip
var _slots: Array = []
var _instr: Label
var _instr_sub: Label
var _btn_road: TileView
var _btn_bonus: TileView
## The free tiles are not Buttons, so "disabled" is tracked here.
var _road_on := false
var _bonus_on := false
var _btn_loan: Button
var _btn_end: Button
var _end_pulse: Tween


func _init(gs, tooltip: Tooltip) -> void:
	_gs = gs
	_tooltip = tooltip
	var sb := UiKit.box(UiKit.PANEL, 20, 0, Color.TRANSPARENT, 14)
	sb.corner_radius_bottom_left = 0
	sb.corner_radius_bottom_right = 0
	add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	add_child(h)
	h.add_child(_build_slots())
	h.add_child(_build_instructions())
	var road := TileDefs.make(TileDefs.Kind.ROAD)
	road["free"] = true
	_btn_road = _make_stock_tile(road, _on_road_pressed)
	_hover_tip(_btn_road, "Free road  (R)", func(): return ["You get %d free roads for the whole game." % GameState.FREE_ROADS, "Place them on any empty lot during your turns."], "res://assets/tiles/road_15.svg")
	h.add_child(_btn_road)
	_btn_bonus = _make_stock_tile(null, _on_bonus_pressed)
	_hover_tip(_btn_bonus, "Free tile  (B)", func(): return ["An event card gave you a tile to place for free.", "It costs nothing and is not one of your purchases."])
	_btn_bonus.modulate.a = 0.0
	h.add_child(_btn_bonus)
	_btn_loan = _make_button("Take loan", "gold", 18, loan_pressed.emit)
	_hover_tip(_btn_loan, "Loan  (L)", _loan_tip_lines, "res://assets/ui/bank.svg")
	h.add_child(_btn_loan)
	_btn_end = _make_button("End turn", "primary", 20, end_turn_pressed.emit)
	_hover_tip(_btn_end, "End turn  (E)", func(): return ["Available once you have bought %d tiles." % _gs.buy_limit(), "Then pass the mouse and keyboard on."])
	h.add_child(_btn_end)


## Shows the tiles bought so far this turn in the purchase slots. A card can add or remove a slot.
func show_bought(tiles: Array) -> void:
	for k in _slots.size():
		_slots[k].tile = tiles[k] if k < tiles.size() else null
		_slots[k].modulate.a = 1.0 if k < _gs.buy_limit() else 0.0


func bonus_button_rect() -> Rect2:
	return _btn_bonus.get_global_rect()


func road_button_rect() -> Rect2:
	return _btn_road.get_global_rect()


func loan_button_rect() -> Rect2:
	return _btn_loan.get_global_rect()


## Refreshes buttons and the instruction text for the current player.
## `hand` is the picked-up item ({} when empty), `busy` locks the buttons during animations.
func update(hand: Dictionary, busy: bool) -> void:
	var p = _gs.current_player()
	_btn_road.stack_count = p.free_roads
	# the tile keeps its place when there is nothing to place, so the bar never shifts
	var has_bonus: bool = not p.bonus_tiles.is_empty()
	if has_bonus:
		_btn_bonus.tile = p.bonus_tiles[0]
	_btn_bonus.stack_count = p.bonus_tiles.size()
	_btn_bonus.modulate.a = 1.0 if has_bonus else 0.0
	_btn_bonus.interactive = has_bonus
	_btn_road.selected = hand.get("type", "") == "free"
	_btn_bonus.selected = hand.get("type", "") == "bonus"
	if p.is_bot():
		_set_stock_enabled(false, false)
		_btn_loan.disabled = true
		_btn_end.text = "End turn"
		_btn_end.disabled = true
		_set_end_pulse(false)
		_instr.text = "%s is planning their city" % p.name
		_instr_sub.text = "%s bot. Hover any tile to see what it does. Esc opens the menu." % Bot.level_name(p.bot_level)
		return
	_btn_end.text = "End turn"
	# a penalty that takes tiles must be settled before anything else
	busy = busy or not _gs.pending_losses.is_empty()
	_set_stock_enabled(not busy and p.free_roads > 0, not busy)
	_btn_loan.disabled = busy or not _gs.can_take_loan()
	_btn_end.disabled = busy or not _gs.can_end_turn()
	_set_end_pulse(not _btn_end.disabled and hand.is_empty())
	_write_instruction(p, hand)


func _write_instruction(p, hand: Dictionary) -> void:
	var buys: int = _gs.buys_left()
	var hand_type: String = hand.get("type", "")
	var loss: Dictionary = _gs.pending_loss()
	if not loss.is_empty():
		_instr.text = "Choose %s to lose" % CardEffects.describe_loss(loss["kinds"], loss["n"])
		_instr_sub.text = "Click one of the glowing tiles. It is gone for good."
	elif hand_type == "shop":
		_instr.text = "Choose a lot for your %s" % TileDefs.display_name(_gs.stack_tile(hand["slot"])).to_lower()
		if p.replaced:
			_instr_sub.text = "Hover a lot to preview the points. Right-click or Esc puts it back."
		else:
			_instr_sub.text = "Pick an empty lot, or a tile of yours to replace (once per game)."
	elif hand_type == "bonus":
		_instr.text = "Choose a lot for your free %s" % TileDefs.display_name(p.bonus_tiles[hand["index"]]).to_lower()
		_instr_sub.text = "It is a gift from your event card. Right-click or Esc puts it back."
	elif hand_type == "free":
		_instr.text = "Choose a lot for your free road"
		_instr_sub.text = "Roads link homes to the places citizens need. Right-click or Esc puts it back."
	elif buys > 0 and _gs.can_take_loan():
		_instr.text = "You cannot afford %d more tile%s" % [buys, "" if buys == 1 else "s"]
		_instr_sub.text = "Take a loan: +%d gold now, -%d points at the end." % [GameState.LOAN_AMOUNT, _gs.next_loan_penalty()]
	elif buys > 0:
		_instr.text = "Buy tile %d of %d" % [_gs.purchases + 1, _gs.buy_limit()]
		_instr_sub.text = "Pick a tile from the construction site. Hover anything to see what it does."
	else:
		_instr.text = "All %d tiles are built" % _gs.buy_limit()
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
		"+%d gold now, [color=#E0533A]-%d points[/color] at final scoring (more for every further loan)." % [GameState.LOAN_AMOUNT, _gs.next_loan_penalty()],
		"Only allowed when you cannot afford the tiles you still have to buy this round." if not _gs.can_take_loan() else "[color=#8DBB3C]You can take one now.[/color]"]


func _build_slots() -> Control:
	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", 8)
	for n in GameState.BUYS_PER_TURN + 1:
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
	# long texts are cut off instead of making the whole screen wider
	for l in [_instr, _instr_sub]:
		l.clip_text = true
		l.custom_minimum_size.x = 240
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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


## A free tile waiting to be placed, drawn like a construction-site tile. Left click picks it up.
func _make_stock_tile(tile, on_pressed: Callable) -> TileView:
	var v := TileView.new()
	v.mode = TileView.Mode.STOCK
	v.tile = tile
	v.custom_minimum_size = Vector2(STOCK_SIZE, STOCK_SIZE)
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.pressed.connect(func(_view): on_pressed.call())
	return v


## A tile that cannot be used right now is dimmed; it still shows its tooltip.
func _set_stock_enabled(road: bool, bonus: bool) -> void:
	_road_on = road
	_bonus_on = bonus
	_btn_road.dim = 0.0 if road else 0.9
	_btn_bonus.dim = 0.0 if bonus else 0.9
	_btn_road.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if road else Control.CURSOR_ARROW
	_btn_bonus.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if bonus else Control.CURSOR_ARROW


func _on_road_pressed() -> void:
	if _road_on:
		free_road_pressed.emit()


func _on_bonus_pressed() -> void:
	if _bonus_on:
		bonus_tile_pressed.emit()


func _make_button(text: String, kind: String, size: int, on_pressed: Callable) -> Button:
	var b := UiKit.button(text, kind, size)
	b.pressed.connect(on_pressed)
	return b


## Shows `lines()` (called on hover, so it reflects the current state) in the tooltip.
func _hover_tip(b: Control, title: String, lines: Callable, icon_path := "") -> void:
	b.mouse_entered.connect(func(): _tooltip.show_text(title, lines.call(), b.get_global_rect(), icon_path))
	b.mouse_exited.connect(_tooltip.hide_tip)
