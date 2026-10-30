extends PanelContainer
## Short message that drops in over the mat and fades away.

const UiKit = preload("res://scripts/ui/ui_kit.gd")

var _label: Label
var _tween: Tween


func _init() -> void:
	var sb := UiKit.box(Color(UiKit.INK_DEEP, 0.95), 99, 2, UiKit.GOLD)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 8
	sb.content_margin_bottom = 10
	add_theme_stylebox_override("panel", sb)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = UiKit.label("", 18, UiKit.LIMESTONE, "body_bold")
	add_child(_label)
	visible = false


## Shows `text` centred at the top of `anchor` (a global rect).
func show_message(text: String, anchor: Rect2) -> void:
	_label.text = text
	reset_size()
	position = Vector2(anchor.get_center().x - size.x / 2, anchor.position.y + 14)
	visible = true
	if _tween and _tween.is_valid():
		_tween.kill()
	modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, 0.15)
	_tween.parallel().tween_property(self, "position:y", anchor.position.y + 24, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(2.4)
	_tween.tween_property(self, "modulate:a", 0.0, 0.3)
	_tween.tween_callback(func(): visible = false)
