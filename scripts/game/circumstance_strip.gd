extends HBoxContainer
## One mini card per round in the top bar. A revealed circumstance card shows its picture and badge:
## hover it for what it does, click it to see the full card again. A card that has not been turned
## over yet stays a face-down "?".

const UiKit = preload("res://scripts/ui/ui_kit.gd")
const CircumstanceDefs = preload("res://scripts/core/circumstance_defs.gd")
const CircumstanceCardFace = preload("res://scripts/game/circumstance_card_face.gd")

signal card_pressed(index: int)

const SLOT_SIZE := Vector2(40, 54)

var _tooltip
var _slots: Array[PanelContainer] = []
var _revealed: Array = []
var _round := 1


func _init(tooltip, rounds: int) -> void:
	_tooltip = tooltip
	add_theme_constant_override("separation", 5)
	for i in rounds:
		var slot := PanelContainer.new()
		slot.custom_minimum_size = SLOT_SIZE
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		slot.mouse_entered.connect(_on_slot_entered.bind(i))
		slot.mouse_exited.connect(_on_slot_exited.bind(i))
		slot.gui_input.connect(_on_slot_input.bind(i))
		slot.resized.connect(func(): slot.pivot_offset = slot.size / 2)
		add_child(slot)
		_slots.append(slot)
	_restyle()


## `revealed` holds the card ids turned over so far; `round_number` is the round being played.
func refresh(revealed: Array, round_number: int) -> void:
	var grew := revealed.size() > _revealed.size()
	_revealed = revealed.duplicate()
	_round = round_number
	_restyle()
	if grew:
		var slot := _slots[revealed.size() - 1]
		slot.scale = Vector2.ONE * 0.4
		create_tween().tween_property(slot, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _restyle() -> void:
	for i in _slots.size():
		var slot := _slots[i]
		for c in slot.get_children():
			slot.remove_child(c)
			c.queue_free()
		slot.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		var card: Control
		if i < _revealed.size():
			card = CircumstanceCardFace.mini(_revealed[i])
			slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		else:
			card = CircumstanceCardFace.mini_back(i + 1 == _round)
			slot.mouse_default_cursor_shape = Control.CURSOR_ARROW
		_ignore_mouse(card)
		slot.add_child(card)


## The slot itself must receive the mouse, so nothing inside it may swallow it.
func _ignore_mouse(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in node.get_children():
		_ignore_mouse(c)


func _on_slot_entered(i: int) -> void:
	if i < _revealed.size():
		create_tween().tween_property(_slots[i], "scale", Vector2.ONE * 1.1, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var rect := _slots[i].get_global_rect()
	if i < _revealed.size():
		var id: String = _revealed[i]
		var info := CircumstanceDefs.info(id)
		_tooltip.show_text("%s (round %d)" % [info["title"], i + 1],
			[CircumstanceCardFace.happiness_icons(info["rule"], "7ED957", "FF8A7A", 16), "[color=#9FB3C2]%s[/color]" % info["tip"], "[color=#F2B630]Click to see the full card.[/color]"], rect, CircumstanceDefs.art_path(id))
	else:
		_tooltip.show_text("Round %d hidden circumstance" % (i + 1),
			["[color=#9FB3C2]Hidden until the round starts. Every planner gets the same card.[/color]"], rect, "res://assets/ui/sun.svg")


func _on_slot_exited(i: int) -> void:
	_tooltip.hide_tip()
	create_tween().tween_property(_slots[i], "scale", Vector2.ONE, 0.12)


func _on_slot_input(event: InputEvent, i: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and i < _revealed.size():
		card_pressed.emit(i)
