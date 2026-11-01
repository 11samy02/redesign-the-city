extends Control
## The hidden circumstance card of the round as a collectible game card. It slides in face down, flips over, and
## its gem, rule text and foil sheen come alive. The card tilts toward the cursor, and lifts away
## on Continue. In review mode (opened from the top bar) it shows the front straight away.
## Emits `dismissed` once the planners have read it.

const UiKit = preload("res://scripts/ui/ui_kit.gd")
const OverlayKit = preload("res://scripts/ui/overlay_kit.gd")
const CircumstanceDefs = preload("res://scripts/core/circumstance_defs.gd")
const CircumstanceCardFace = preload("res://scripts/game/circumstance_card_face.gd")
const CardFx = preload("res://scripts/game/overlays/card_fx.gd")

signal dismissed

const CARD_W := CircumstanceCardFace.WIDTH
const CARD_H := CircumstanceCardFace.HEIGHT

var _gs
var _entry: Dictionary
var _review := false
var _stage: Control
var _front: Control
var _back: Control
var _button_row: Control
var _close_x: Button
var _flipped := false
var _done := false
var _tilt := 0.0
var _intro_rotation := 0.0


func _init(gs, entry: Dictionary, review := false) -> void:
	_gs = gs
	_entry = entry
	_review = review


func _ready() -> void:
	OverlayKit.fill_dimmed(self, 0.86).gui_input.connect(_on_backdrop_input)
	var id: String = _entry["id"]
	var tint := CircumstanceDefs.tint(id)

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
	_front = CircumstanceCardFace.front(id)
	_back = CircumstanceCardFace.back(id)
	content.add_child(_front)
	content.add_child(_back)
	for face in [_front, _back]:
		face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_front.visible = _review
	_back.visible = not _review

	_button_row = _build_button_row()
	_button_row.modulate.a = 0.0
	col.add_child(_button_row)
	# the X rides on the card's top-right corner and appears together with the Continue / Close button
	_close_x = OverlayKit.close_button(_finish)
	_close_x.position = Vector2(CARD_W - _close_x.size.x * 0.65, -_close_x.size.y * 0.35)
	_close_x.modulate.a = 0.0
	_close_x.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_close_x)

	modulate.a = 0.0
	CardFx.hide_parts(_front)
	await get_tree().process_frame
	_play_intro()


## "Round N hidden circumstance" on its own dark plate, so it never fights the busy screen behind it.
func _header(tint: Color) -> Control:
	var plate := PanelContainer.new()
	plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var sb := UiKit.box(Color(UiKit.INK_DEEP, 0.95), 99, 2, tint.darkened(0.1), 9)
	sb.content_margin_left = 30
	sb.content_margin_right = 30
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 12
	plate.add_theme_stylebox_override("panel", sb)
	plate.add_child(UiKit.label("Round %d hidden circumstance" % _entry["round"], 26, UiKit.GOLD, "display_bold"))
	return plate


func _build_button_row() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	var go := UiKit.button("Close" if _review else "Continue", "primary", 24)
	go.pressed.connect(_finish)
	row.add_child(go)
	row.add_child(UiKit.keycap("Esc" if _review else "Enter"))
	return row


# ================================================================ animation and input

func _play_intro() -> void:
	CardFx.intro(self, _stage)
	if _review:
		await get_tree().create_timer(0.35).timeout
		if is_instance_valid(self):
			_bring_to_life()
	else:
		await get_tree().create_timer(1.2).timeout
		if is_instance_valid(self):
			_flip()


## Turns the card over: the back narrows to a line, then the front widens out of it.
func _flip() -> void:
	if _flipped:
		return
	_flipped = true
	_back.pivot_offset = _back.size / 2.0
	_front.pivot_offset = _front.size / 2.0
	var half := create_tween()
	half.tween_property(_back, "scale:x", 0.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await half.finished
	_back.visible = false
	_front.visible = true
	_front.scale.x = 0.0
	Sfx.play("whoosh")
	var full := create_tween()
	full.tween_property(_front, "scale:x", 1.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await full.finished
	Sfx.play("place")
	_bring_to_life()


## After the flip: the gem pops in, the rule fades up, the foil sheen starts sweeping.
func _bring_to_life() -> void:
	_flipped = true
	CardFx.bring_to_life(self, _front, [_button_row, _close_x])
	_close_x.mouse_filter = Control.MOUSE_FILTER_STOP


## The card leans a little toward the cursor.
func _process(delta: float) -> void:
	if _stage == null or _done:
		return
	_tilt = CardFx.lean(self, _stage, _tilt, _intro_rotation, delta)


func _unhandled_input(event: InputEvent) -> void:
	if _done:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE]:
			if _flipped or _review:
				_finish()
			else:
				_flip()
			get_viewport().set_input_as_handled()


## A click on the dimmed area outside the card closes it, like Continue / Esc.
func _on_backdrop_input(event: InputEvent) -> void:
	if _done or not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if _stage.get_global_rect().has_point(event.global_position):
		return
	if _flipped or _review:
		_finish()
	else:
		_flip()
	get_viewport().set_input_as_handled()


## The card lifts and fades away.
func _finish() -> void:
	if _done or not _front.visible:
		return
	_done = true
	await CardFx.lift_away(self, _stage).finished
	dismissed.emit()
	queue_free()
