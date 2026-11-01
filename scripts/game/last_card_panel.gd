extends PanelContainer
## Next to the turn decks: the event or penalty card drawn this turn, as a small card. Click it to
## read it again in big (`pressed`). It stays after the pop-up closes.

const UiKit = preload("res://scripts/ui/ui_kit.gd")
const CardDefs = preload("res://scripts/core/card_defs.gd")
const Face = preload("res://scripts/game/circumstance_card_face.gd")

signal pressed(id: String)

const CARD_HEIGHT := 132.0
const SCALE := CARD_HEIGHT / Face.HEIGHT

var _slot: Control
var _shown_id := ""
var _tooltip


func _init(tooltip) -> void:
	_tooltip = tooltip
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_stylebox_override("panel", UiKit.box(Color(UiKit.PANEL, 0.6), 16, 0, Color.TRANSPARENT, 8))
	var center := CenterContainer.new()
	add_child(center)
	_slot = Control.new()
	_slot.custom_minimum_size = Vector2(Face.WIDTH, Face.HEIGHT) * SCALE
	center.add_child(_slot)
	_slot.gui_input.connect(func(e):
		if _shown_id != "" and e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			pressed.emit(_shown_id)
			_slot.accept_event())
	_slot.mouse_entered.connect(func():
		if _shown_id != "":
			_slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			_tooltip.show_text("This turn's card", ["Click to read it in big."], _slot.get_global_rect()))
	_slot.mouse_exited.connect(_tooltip.hide_tip)
	show_card({})


## `card` is GameState.turn_card: {"id", ...}, or {} before a card is drawn.
func show_card(card: Dictionary) -> void:
	var id: String = card.get("id", "")
	if id == _shown_id and _slot.get_child_count() > 0:
		return
	_shown_id = id
	for c in _slot.get_children():
		_slot.remove_child(c)
		c.queue_free()
	if id == "":
		var empty := Panel.new()
		empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		empty.add_theme_stylebox_override("panel", UiKit.box(Color(UiKit.INK_DEEP, 0.4), 10, 2, Color(UiKit.LINE, 0.7)))
		empty.size = _slot.custom_minimum_size
		_slot.add_child(empty)
		return
	var face := Face.front_turn(id)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.scale = Vector2.ONE * SCALE
	face.size = Vector2(Face.WIDTH, Face.HEIGHT)
	_slot.add_child(face)
