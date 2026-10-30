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
