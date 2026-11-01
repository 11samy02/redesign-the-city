extends RefCounted
## Full-screen overlay scaffolding shared by the game and final-scoring screens.

const UiKit = preload("res://scripts/ui/ui_kit.gd")


## Turns `ov` into a full-rect overlay that swallows the mouse and dims what is behind it.
static func fill_dimmed(ov: Control, dim_alpha: float) -> ColorRect:
	ov.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(UiKit.INK_DEEP, dim_alpha)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov.add_child(dim)
	return dim


## A round pink X for the top-right corner of a card. Pressing it calls `on_press`.
## Place it with `position`; it overhangs the card corner by about a third of its size.
static func close_button(on_press: Callable, px := 52.0) -> Button:
	var b := CloseButton.new()
	b.custom_minimum_size = Vector2(px, px)
	b.size = Vector2(px, px)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.tooltip_text = "Close"
	var radius := int(px / 2.0)
	for state in ["normal", "hover", "pressed"]:
		var color: Color = {"normal": UiKit.BOUG, "hover": UiKit.BOUG_HI, "pressed": Color("#B42A66")}[state]
		var sb := UiKit.box(color, radius, 3, Color(1, 1, 1, 0.9))
		sb.shadow_color = Color(0, 0, 0, 0.45)
		sb.shadow_size = 6
		sb.shadow_offset = Vector2(0, 3)
		b.add_theme_stylebox_override(state, sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.resized.connect(func(): b.pivot_offset = b.size / 2)
	b.mouse_entered.connect(func():
		UiKit.play_sfx("hover")
		b.create_tween().tween_property(b, "scale", Vector2.ONE * 1.1, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
	b.mouse_exited.connect(func():
		b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.12))
	b.pressed.connect(func(): UiKit.play_sfx("click"))
	b.pressed.connect(on_press)
	return b


## The button behind close_button: the two strokes of the X are drawn over the round background.
class CloseButton extends Button:
	func _draw() -> void:
		var c := size / 2.0
		var r := size.x * 0.18
		draw_line(c + Vector2(-r, -r), c + Vector2(r, r), Color.WHITE, 4.5, true)
		draw_line(c + Vector2(-r, r), c + Vector2(r, -r), Color.WHITE, 4.5, true)


## A card centred on the overlay. Returns the card so the caller can fill it.
static func add_card(ov: Control, style: StyleBox, min_width := 0.0) -> PanelContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov.add_child(center)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", style)
	card.custom_minimum_size.x = min_width
	center.add_child(card)
	return card


## Card background with a coloured top edge, the look of a planner's card.
static func planner_card_style(color: Color, radius: int, margin: int, edge: int, shadow := 0) -> StyleBoxFlat:
	var sb := UiKit.box(UiKit.PANEL, radius, 0, Color.TRANSPARENT, margin)
	sb.border_width_top = edge
	sb.border_color = color
	if shadow > 0:
		sb.shadow_color = Color(0, 0, 0, 0.5)
		sb.shadow_size = shadow
	return sb
