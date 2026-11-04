extends Control
## Every event and penalty card one planner drew during the game, oldest first, as the real cards in
## a grid of four by two. No text: click a card to see it large, click outside (or Esc) to close.

const UiKit = preload("res://scripts/ui/ui_kit.gd")
const OverlayKit = preload("res://scripts/ui/overlay_kit.gd")
const Face = preload("res://scripts/game/circumstance_card_face.gd")

signal closed

const COLUMNS := 4
const GAP := 26.0
## Share of the screen the grid may fill.
const FILL_W := 0.88
const FILL_H := 0.86

var _gs
var _index: int
var _big: Control
var _cards: Array[Control] = []
var _done := false


## `index` is the planner's seat.
func _init(gs, index: int) -> void:
	_gs = gs
	_index = index


func _ready() -> void:
	var dim := OverlayKit.fill_dimmed(self, 0.9)
	dim.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			_close())
	var ids: Array = []
	for e in _gs.cards_drawn_by(_index):
		ids.append(e["id"])
	var vp := get_viewport_rect().size
	var rows := maxi(1, ceili(float(ids.size()) / COLUMNS))
	rows = maxi(rows, 2)
	var scale := minf((vp.x * FILL_W - GAP * (COLUMNS - 1)) / (COLUMNS * Face.WIDTH), (vp.y * FILL_H - GAP * (rows - 1)) / (rows * Face.HEIGHT))
	scale = minf(scale, 0.8)
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", int(GAP))
	grid.add_theme_constant_override("v_separation", int(GAP))
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(grid)
	for k in ids.size():
		var slot := _build_card(ids[k], scale)
		grid.add_child(slot)
		_cards.append(slot)
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.15)
	await get_tree().process_frame
	_deal_in()


## The real card face at a smaller size; it lifts a little under the mouse.
func _build_card(id: String, scale: float) -> Control:
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(Face.WIDTH, Face.HEIGHT) * scale
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	slot.pivot_offset = slot.custom_minimum_size / 2.0
	var face := Face.front_turn(id)
	face.size = Vector2(Face.WIDTH, Face.HEIGHT)
	face.scale = Vector2.ONE * scale
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(face)
	slot.mouse_entered.connect(func():
		slot.create_tween().tween_property(slot, "scale", Vector2.ONE * 1.04, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
	slot.mouse_exited.connect(func():
		slot.create_tween().tween_property(slot, "scale", Vector2.ONE, 0.12))
	slot.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_show_big(id)
			slot.accept_event())
	return slot


## The cards drop onto the table one after the other.
func _deal_in() -> void:
	for k in _cards.size():
		var slot := _cards[k]
		slot.modulate.a = 0.0
		var tw := create_tween().set_parallel()
		tw.tween_property(slot, "modulate:a", 1.0, 0.2).set_delay(k * 0.05)
		# the face inside the slot moves; the slot itself belongs to the grid
		tw.tween_property(slot.get_child(0), "position:y", 0.0, 0.35).from(36.0).set_delay(k * 0.05).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play("whoosh")


func _show_big(id: String) -> void:
	if _big != null:
		return
	Sfx.play("pop")
	_big = Control.new()
	OverlayKit.fill_dimmed(_big, 0.72)
	_big.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			_close_big())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_big.add_child(center)
	var face := Face.front_turn(id)
	var s := minf(1.0, (get_viewport_rect().size.y * 0.9) / Face.HEIGHT)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(Face.WIDTH, Face.HEIGHT) * s
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.size = Vector2(Face.WIDTH, Face.HEIGHT)
	face.scale = Vector2.ONE * s
	holder.add_child(face)
	center.add_child(holder)
	add_child(_big)
	_big.modulate.a = 0.0
	create_tween().tween_property(_big, "modulate:a", 1.0, 0.12)
	holder.pivot_offset = holder.custom_minimum_size / 2.0
	holder.scale = Vector2.ONE * 0.9
	create_tween().tween_property(holder, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _close_big() -> void:
	if _big != null:
		_big.queue_free()
		_big = null


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if _big != null:
			_close_big()
		else:
			_close()
		get_viewport().set_input_as_handled()


func _close() -> void:
	if _done:
		return
	_done = true
	closed.emit()
	queue_free()
