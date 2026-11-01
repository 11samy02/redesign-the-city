extends Control
## The event or penalty card of this turn in big. It moves exactly like the hidden
## circumstance card (see card_fx.gd): it slides in, the gem pops, the rule fades up, the foil sheen sweeps
## across, the card leans toward the cursor and lifts away. The X, Close, a click outside the card and
## Esc / Enter all close it. Emits `closed`.

const UiKit = preload("res://scripts/ui/ui_kit.gd")
const OverlayKit = preload("res://scripts/ui/overlay_kit.gd")
const CardDefs = preload("res://scripts/core/card_defs.gd")
const Face = preload("res://scripts/game/circumstance_card_face.gd")
const CardFx = preload("res://scripts/game/overlays/card_fx.gd")

signal closed

const CARD_W := Face.WIDTH
const CARD_H := Face.HEIGHT

var _id: String
var _stage: Control
var _front: Control
var _below: Control
var _close_x: Button
var _done := false
var _tilt := 0.0
var _intro_rotation := 0.0


func _init(id: String) -> void:
	_id = id


func _ready() -> void:
	OverlayKit.fill_dimmed(self, 0.86).gui_input.connect(_on_backdrop_input)
	var tint: Color = Face.EVENT_TINT if CardDefs.is_event(_id) else Face.PENALTY_TINT

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(col)

	col.add_child(_header(tint))

	_stage = Control.new()
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.custom_minimum_size = Vector2(CARD_W, CARD_H)
	col.add_child(_stage)
	var content := CardFx.supersampled_surface(self, _stage, CARD_W, CARD_H)
	_front = Face.front_turn(_id)
	content.add_child(_front)
	_front.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# the Close button fades in once the card is up
	_below = _build_button_row()
	_below.modulate.a = 0.0
	col.add_child(_below)

	# the X rides on the card's top-right corner and appears together with the Close button
	_close_x = OverlayKit.close_button(_finish)
	_close_x.position = Vector2(CARD_W - _close_x.size.x * 0.65, -_close_x.size.y * 0.35)
	_close_x.modulate.a = 0.0
	_close_x.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_close_x)

	modulate.a = 0.0
	CardFx.hide_parts(_front)
	await get_tree().process_frame
	CardFx.intro(self, _stage)
	await get_tree().create_timer(0.35).timeout
	if is_instance_valid(self) and not _done:
		CardFx.bring_to_life(self, _front, [_below, _close_x])
		_close_x.mouse_filter = Control.MOUSE_FILTER_STOP


## "Event card" or "Penalty card" on its own dark plate, so it never fights the busy screen behind it.
func _header(tint: Color) -> Control:
	var plate := PanelContainer.new()
	plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var sb := UiKit.box(Color(UiKit.INK_DEEP, 0.95), 99, 2, tint.darkened(0.1), 9)
	sb.content_margin_left = 30
	sb.content_margin_right = 30
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 12
	plate.add_theme_stylebox_override("panel", sb)
	var text := "Event card" if CardDefs.is_event(_id) else "Penalty card"
	plate.add_child(UiKit.label(text, 26, tint.lightened(0.45), "display_bold"))
	return plate


func _build_button_row() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	var go := UiKit.button("Close", "primary", 24)
	go.pressed.connect(_finish)
	row.add_child(go)
	row.add_child(UiKit.keycap("Esc"))
	return row


# ================================================================ input and finish

## The card leans a little toward the cursor.
func _process(delta: float) -> void:
	if _stage == null or _done:
		return
	_tilt = CardFx.lean(self, _stage, _tilt, _intro_rotation, delta)


func _unhandled_input(event: InputEvent) -> void:
	if _done:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		get_viewport().set_input_as_handled()
		_finish()


## A click on the dimmed area outside the card closes it, like Close / Esc.
func _on_backdrop_input(event: InputEvent) -> void:
	if _done or not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if _stage.get_global_rect().has_point(event.global_position):
		return
	_finish()
	get_viewport().set_input_as_handled()


## The card lifts and fades away.
func _finish() -> void:
	if _done:
		return
	_done = true
	await CardFx.lift_away(self, _stage).finished
	closed.emit()
	queue_free()
