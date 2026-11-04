extends PanelContainer
## Next to the turn decks: every event and penalty card the planner has drawn this game, as small
## cards in a row, the newest on the right. The card drawn this turn is bright, the older ones are
## darker. Click one to read it in big (`pressed`). The row stays after the pop-up closes; when there
## are more cards than room, they overlap a little.

const UiKit = preload("res://scripts/ui/ui_kit.gd")
const CardDefs = preload("res://scripts/core/card_defs.gd")
const Face = preload("res://scripts/game/circumstance_card_face.gd")

signal pressed(id: String)

const CARD_HEIGHT := 132.0
const SCALE := CARD_HEIGHT / Face.HEIGHT
const CARD_WIDTH := Face.WIDTH * SCALE
const GAP := 8.0
## Older cards are dimmed; the one drawn this turn keeps its full colours.
const OLD_TINT := Color(0.58, 0.6, 0.66)

var _row: Control
var _slots: Array[Control] = []
var _shown_key := ""
var _ids_key := ""
var _tooltip


func _init(tooltip) -> void:
	_tooltip = tooltip
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_stylebox_override("panel", UiKit.box(Color(UiKit.PANEL, 0.6), 16, 0, Color.TRANSPARENT, 8))
	_row = Control.new()
	_row.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT + 20.0)
	_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.resized.connect(_layout)
	add_child(_row)
	show_cards([])


## `cards` are the planner's cards, oldest first: [{"id", "round", "now"}]. The last one is the newest;
## "now" marks the card drawn this turn.
func show_cards(cards: Array) -> void:
	var ids: Array[String] = []
	var flags := ""
	for c in cards:
		ids.append(c["id"])
		flags += "1" if c.get("now", false) else "0"
	var ids_key := ",".join(PackedStringArray(ids))
	var key := "%s|%s" % [ids_key, flags]
	if key == _shown_key and _row.get_child_count() > 0:
		return
	# a card that is simply added to the end keeps the others where they are and the new one lands
	var grew := not _slots.is_empty() and ids_key.begins_with(_ids_key) and ids.size() == _slots.size() + 1
	_shown_key = key
	_ids_key = ids_key
	if grew:
		_add_slot(cards[cards.size() - 1], true)
		_layout()
		_apply_tints(cards)
		return
	for c in _row.get_children():
		_row.remove_child(c)
		c.queue_free()
	_slots.clear()
	if cards.is_empty():
		var empty := Panel.new()
		empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		empty.add_theme_stylebox_override("panel", UiKit.box(Color(UiKit.INK_DEEP, 0.4), 10, 2, Color(UiKit.LINE, 0.7)))
		empty.size = Vector2(CARD_WIDTH, CARD_HEIGHT)
		empty.position = Vector2(maxf((_row.size.x - CARD_WIDTH) / 2.0, 0.0), (_row.size.y - CARD_HEIGHT) / 2.0)
		_row.add_child(empty)
		return
	for c in cards:
		_add_slot(c, false)
	_layout()
	_apply_tints(cards, false)


func _add_slot(card: Dictionary, animate: bool) -> void:
	var id: String = card["id"]
	var slot := Control.new()
	slot.size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	slot.pivot_offset = slot.size / 2.0
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	slot.set_meta("id", id)
	var face := Face.front_turn(id)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.scale = Vector2.ONE * SCALE
	face.size = Vector2(Face.WIDTH, Face.HEIGHT)
	slot.add_child(face)
	slot.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			pressed.emit(id)
			slot.accept_event())
	slot.mouse_entered.connect(func():
		slot.z_index = 1
		_tint_slot(slot, Color.WHITE)
		create_tween().tween_property(face, "position:y", -8.0, 0.1)
		_tooltip.show_text(CardDefs.title(id), ["Round %d. Click to read it in big." % card["round"]], slot.get_global_rect()))
	slot.mouse_exited.connect(func():
		slot.z_index = 0
		_tint_slot(slot, slot.get_meta("tint", Color.WHITE))
		create_tween().tween_property(face, "position:y", 0.0, 0.1)
		_tooltip.hide_tip())
	_row.add_child(slot)
	_slots.append(slot)
	if animate:
		slot.modulate = Color(1, 1, 1, 0)
		create_tween().tween_property(slot, "scale", Vector2.ONE, 0.3).from(Vector2.ONE * 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## The card drawn this turn is bright, every older one is darker.
func _apply_tints(cards: Array, animate := true) -> void:
	for k in _slots.size():
		var tint := Color.WHITE if cards[k].get("now", false) else OLD_TINT
		_slots[k].set_meta("tint", tint)
		if animate:
			_tint_slot(_slots[k], tint)
		else:
			_slots[k].modulate = tint


func _tint_slot(slot: Control, tint: Color) -> void:
	create_tween().tween_property(slot, "modulate", tint, 0.18)


## Cards side by side, the whole row centred in the panel; when they do not all fit, each one slides under the next.
func _layout() -> void:
	var n := _slots.size()
	if n == 0:
		if _row.get_child_count() > 0:
			_row.get_child(0).position = Vector2(maxf((_row.size.x - CARD_WIDTH) / 2.0, 0.0), (_row.size.y - CARD_HEIGHT) / 2.0)
		return
	var room := _row.size.x
	var step := CARD_WIDTH + GAP
	if n > 1 and room > 0.0 and CARD_WIDTH + step * (n - 1) > room:
		step = maxf((room - CARD_WIDTH) / (n - 1), 14.0)
	var total := CARD_WIDTH + step * (n - 1)
	var x0 := maxf((room - total) / 2.0, 0.0)
	var y0 := (_row.size.y - CARD_HEIGHT) / 2.0
	for k in n:
		_slots[k].position = Vector2(x0 + k * step, y0)
