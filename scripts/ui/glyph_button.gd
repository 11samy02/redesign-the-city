extends Button
## A small round button with a drawn icon: "edit" (pencil), "delete" (bin) or "plus".
## It keeps its clicks to itself, so it can sit on top of a clickable card.

const UiKit = preload("res://scripts/ui/ui_kit.gd")

var glyph := "edit"
var tone := UiKit.LIMESTONE
var _hover := false


static func make(p_glyph: String, tip: String, danger := false, px := 34.0) -> Button:
	var b: Button = load("res://scripts/ui/glyph_button.gd").new()
	b.glyph = p_glyph
	b.tone = UiKit.HEAT if danger else UiKit.LIMESTONE
	b.tooltip_text = tip
	b.custom_minimum_size = Vector2(px, px)
	b.size = Vector2(px, px)
	b.focus_mode = Control.FOCUS_NONE
	# STOP, so a click never travels on to the card behind the button and picks the mat
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.accessibility_name = tip
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for state in ["normal", "hover", "pressed"]:
		var bg := Color(UiKit.INK_DEEP, 0.88)
		if state != "normal":
			bg = Color(UiKit.HEAT, 0.92) if danger else Color(UiKit.PANEL_HI, 1.0)
		b.add_theme_stylebox_override(state, UiKit.box(bg, int(px / 2), 2, Color(UiKit.LINE, 0.9)))
	b.mouse_entered.connect(func():
		b._hover = true
		UiKit.play_sfx("hover")
		b.queue_redraw())
	b.mouse_exited.connect(func():
		b._hover = false
		b.queue_redraw())
	b.pressed.connect(func(): UiKit.play_sfx("click"))
	return b


func _draw() -> void:
	var c := size / 2.0
	var r := size.x * 0.2
	var col := Color.WHITE if (_hover and tone == UiKit.HEAT) else tone
	var w := maxf(2.0, size.x * 0.075)
	match glyph:
		"edit":
			# a pencil lying at 45 degrees
			var tip := c + Vector2(-r, r) * 1.05
			var top := c + Vector2(r, -r) * 1.05
			var dir := (top - tip).normalized()
			var side := Vector2(-dir.y, dir.x) * w * 0.9
			draw_colored_polygon(PackedVector2Array([tip, tip + dir * r * 0.7 + side, top - dir * r * 0.5 + side, top - dir * r * 0.5 - side, tip + dir * r * 0.7 - side]), col)
			draw_line(top - dir * r * 0.25 + side, top - dir * r * 0.25 - side, UiKit.INK_DEEP, w * 0.6, true)
		"delete":
			draw_line(c + Vector2(-r * 1.1, -r * 0.55), c + Vector2(r * 1.1, -r * 0.55), col, w, true)
			draw_line(c + Vector2(-r * 0.35, -r * 0.55), c + Vector2(-r * 0.35, -r * 0.95), col, w, true)
			draw_line(c + Vector2(r * 0.35, -r * 0.55), c + Vector2(r * 0.35, -r * 0.95), col, w, true)
			draw_line(c + Vector2(-r * 0.35, -r * 0.95), c + Vector2(r * 0.35, -r * 0.95), col, w, true)
			var body := PackedVector2Array([c + Vector2(-r * 0.8, -r * 0.3), c + Vector2(r * 0.8, -r * 0.3), c + Vector2(r * 0.6, r * 1.05), c + Vector2(-r * 0.6, r * 1.05), c + Vector2(-r * 0.8, -r * 0.3)])
			draw_polyline(body, col, w, true)
		"plus":
			draw_line(c + Vector2(-r, 0), c + Vector2(r, 0), col, w * 1.3, true)
			draw_line(c + Vector2(0, -r), c + Vector2(0, r), col, w * 1.3, true)
