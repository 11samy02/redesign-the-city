extends Control
## Centered card with a title, body text and a row of choices.
## Emits `chosen(value)`; Enter picks the first choice, Esc the safe `cancel_index` one.

const UiKit = preload("res://scripts/ui/ui_kit.gd")

signal chosen(value)

var _card: PanelContainer
var _values: Array = []
var _cancel := 0
var _done := false


## choices: [[label, kind, value], ...]
static func make(title: String, body: String, choices: Array, icon_path := "", cancel_index := -1) -> Control:
	var m = load("res://scripts/ui/modal.gd").new()
	m._build(title, body, choices, icon_path)
	m._cancel = cancel_index if cancel_index >= 0 else choices.size() - 1
	return m


func _build(title: String, body: String, choices: Array, icon_path: String) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(UiKit.INK_DEEP, 0.75)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_card = PanelContainer.new()
	var sb := UiKit.box(UiKit.PANEL, 22, 2, UiKit.LINE, 30)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 24
	_card.add_theme_stylebox_override("panel", sb)
	center.add_child(_card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	_card.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	if icon_path != "":
		head.add_child(UiKit.icon(icon_path, 44))
	head.add_child(UiKit.label(title, 30, UiKit.LIMESTONE, "display_bold"))
	v.add_child(head)
	if body != "":
		var b := UiKit.label(body, 18, UiKit.MUTED)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size.x = 460
		v.add_child(b)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_END
	for c in choices:
		var btn := UiKit.button(c[0], c[1], 19)
		btn.pressed.connect(_choose.bind(c[2]))
		row.add_child(btn)
		_values.append(c[2])
	v.add_child(row)


func _ready() -> void:
	modulate.a = 0.0
	_card.pivot_offset = _card.size / 2
	_card.scale = Vector2.ONE * 0.92
	await get_tree().process_frame
	_card.pivot_offset = _card.size / 2
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "modulate:a", 1.0, 0.15)
	tw.tween_property(_card, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _unhandled_input(event: InputEvent) -> void:
	if _done:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			_choose(_values[0])
		elif event.keycode == KEY_ESCAPE:
			_choose(_values[_cancel])
		get_viewport().set_input_as_handled()


func _choose(value) -> void:
	if _done:
		return
	_done = true
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "modulate:a", 0.0, 0.12)
	tw.tween_property(_card, "scale", Vector2.ONE * 0.96, 0.12)
	await tw.finished
	chosen.emit(value)
	queue_free()
