extends Control
## Options overlay: display mode, VSync, volume, sound, bot speed, animation speed.
## Every change applies at once and is saved by the Game autoload.

const UiKit = preload("res://scripts/ui/ui_kit.gd")

signal closed

var _panel: PanelContainer
var _closing := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(UiKit.INK_DEEP, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			close())
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size.x = 660
	var sb := UiKit.box(UiKit.PANEL, 24, 2, UiKit.LINE, 30)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 30
	_panel.add_theme_stylebox_override("panel", sb)
	center.add_child(_panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	_panel.add_child(v)
	var head := HBoxContainer.new()
	head.add_child(UiKit.label("Options", 38, UiKit.LIMESTONE, "display_bold"))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	var close_btn := UiKit.button("Done", "primary", 19)
	close_btn.pressed.connect(close)
	head.add_child(close_btn)
	v.add_child(head)

	var s: Dictionary = Game.settings
	v.add_child(_row("Display", "F11 switches at any time.",
		_segmented(["Windowed", "Fullscreen"], 1 if s["fullscreen"] else 0, func(i): Game.set_setting("fullscreen", i == 1))))
	v.add_child(_row("VSync", "Smoother motion, no screen tearing.",
		_segmented(["On", "Off"], 0 if s["vsync"] else 1, func(i): Game.set_setting("vsync", i == 0))))
	v.add_child(_row("Volume", "", _volume_slider()))
	v.add_child(_row("Sound effects", "M switches during a game.",
		_segmented(["On", "Off"], 1 if s["muted"] else 0, func(i): Game.set_setting("muted", i == 1))))
	v.add_child(_row("Bot speed", "How long computer planners take per move.",
		_segmented(["Slow", "Normal", "Fast"], s["bot_speed"], func(i): Game.set_setting("bot_speed", i))))
	v.add_child(_row("Animations", "Fast plays every animation quicker.",
		_segmented(["Normal", "Fast"], 1 if s["fast_animations"] else 0, func(i): Game.set_setting("fast_animations", i == 1))))

	_panel.pivot_offset = _panel.size / 2
	modulate.a = 0.0
	_panel.scale = Vector2.ONE * 0.94
	await get_tree().process_frame
	_panel.pivot_offset = _panel.size / 2
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "modulate:a", 1.0, 0.18)
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play("whoosh")


func close() -> void:
	if _closing:
		return
	_closing = true
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "modulate:a", 0.0, 0.15)
	tw.tween_property(_panel, "scale", Vector2.ONE * 0.96, 0.15)
	await tw.finished
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER]:
			close()
		get_viewport().set_input_as_handled()


func _row(title: String, hint: String, control: Control) -> Control:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UiKit.box(UiKit.PANEL_HI, 14, 0, Color.TRANSPARENT, 14))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	pc.add_child(h)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 0)
	text.add_child(UiKit.label(title, 20, UiKit.LIMESTONE, "display_bold"))
	if hint != "":
		text.add_child(UiKit.label(hint, 14, UiKit.MUTED))
	h.add_child(text)
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(control)
	return pc


## Row of buttons where exactly one is selected.
func _segmented(options: Array, selected: int, on_pick: Callable) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var buttons: Array[Button] = []
	for i in options.size():
		var b := UiKit.button(options[i], "primary" if i == selected else "secondary", 16)
		b.custom_minimum_size.x = 96
		buttons.append(b)
		b.pressed.connect(func():
			for k in buttons.size():
				UiKit.style_button(buttons[k], "primary" if k == i else "secondary")
			on_pick.call(i))
		h.add_child(b)
	return h


func _volume_slider() -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 5
	slider.value = roundi(Game.settings["volume"] * 100)
	slider.custom_minimum_size = Vector2(220, 28)
	slider.focus_mode = Control.FOCUS_NONE
	slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var track := UiKit.box(UiKit.INK_DEEP, 6)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", UiKit.box(UiKit.BOUG, 6))
	slider.add_theme_stylebox_override("grabber_area_highlight", UiKit.box(UiKit.BOUG_HI, 6))
	var knob := _knob_texture()
	slider.add_theme_icon_override("grabber", knob)
	slider.add_theme_icon_override("grabber_highlight", knob)
	var value := UiKit.label("%d%%" % slider.value, 18, UiKit.LIMESTONE, "display_bold")
	value.custom_minimum_size.x = 56
	slider.value_changed.connect(func(x: float):
		value.text = "%d%%" % x
		Game.set_setting("volume", x / 100.0)
		Sfx.play("tick"))
	h.add_child(slider)
	h.add_child(value)
	return h


static func _knob_texture() -> Texture2D:
	var px := 24
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	var c := Vector2(px, px) / 2.0
	for y in px:
		for x in px:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			var a := clampf(px / 2.0 - 1.0 - d, 0.0, 1.0)
			var col := UiKit.LIMESTONE if d < px / 2.0 - 4.0 else UiKit.BOUG
			img.set_pixel(x, y, Color(col, a))
	return ImageTexture.create_from_image(img)
