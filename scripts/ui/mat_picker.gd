extends Control
## The "Select map" popup: every player mat as a card in a scrolling grid, in two sections. "Game mats" ship with
## the game and can't be deleted. "Your mats" are the ones made in the mat editor; its first card is "New mat".
##
## Clicking a card switches to that mat and the popup stays open: `picked(path)` is emitted ("" is the empty mat) and
## the card gets the "In use" mark. The popup is closed with Close or Esc. `finished({"action": ..., "path": ...})` is
## emitted once: action "new" (open the editor on a blank mat), "edit" (open it on `path`) or "close".
## `mat_deleted(path)` is emitted for every custom mat removed here, so the screen behind can fall back when it was
## the one in use.

const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Grid = preload("res://scripts/core/grid.gd")
const MatLibrary = preload("res://scripts/core/mat_library.gd")
const CustomMats = preload("res://scripts/core/custom_mats.gd")
const MatThumb = preload("res://scripts/ui/mat_thumb.gd")
const GlyphButton = preload("res://scripts/ui/glyph_button.gd")
const Modal = preload("res://scripts/ui/modal.gd")

signal finished(result: Dictionary)
signal picked(path: String)
signal mat_deleted(path: String)

const COLUMNS := 5
const THUMB := 168.0
const CARD_W := 197.0
const GAP := 16

## The mat in use ("" is the empty mat, "custom:<id>" a mat from the editor).
var current := ""
## A custom mat to scroll to and flash when the picker opens (the one just saved).
var focus_path := ""

var _card: PanelContainer
var _scroll: ScrollContainer
var _body: VBoxContainer
var _tab := 0
var _tab_btns: Array[Button] = []
var _note: Label
var _cards := {}
var _done := false
var _busy := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(UiKit.INK_DEEP, 0.84)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_finish({"action": "close"}))
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_card = PanelContainer.new()
	var sb := UiKit.box(UiKit.PANEL, 26, 2, UiKit.LINE, 28)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 30
	_card.add_theme_stylebox_override("panel", sb)
	center.add_child(_card)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	_card.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	head.add_child(UiKit.label("Select a map", 36, UiKit.LIMESTONE, "display_bold"))
	var sub := UiKit.label("Everyone in the game builds on the same mat.", 16, UiKit.MUTED)
	sub.size_flags_vertical = Control.SIZE_SHRINK_END
	head.add_child(sub)
	head.add_child(UiKit.spacer())
	var close := UiKit.button("Close", "ghost", 18)
	close.pressed.connect(func(): _finish({"action": "close"}))
	head.add_child(close)
	v.add_child(head)

	_tab = 1 if (CustomMats.is_custom(current) or focus_path != "") else 0
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	for k in 2:
		var t := UiKit.button("", "secondary", 19)
		t.pressed.connect(_set_tab.bind(k))
		_tab_btns.append(t)
		tabs.add_child(t)
	_note = UiKit.label("", 15, UiKit.MUTED)
	_note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var note_gap := Control.new()
	note_gap.custom_minimum_size.x = 8
	tabs.add_child(note_gap)
	tabs.add_child(_note)
	v.add_child(tabs)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.custom_minimum_size = Vector2(COLUMNS * CARD_W + (COLUMNS - 1) * GAP + 22, 530)
	v.add_child(_scroll)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 22)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_body)
	_fill()

	_card.pivot_offset = _card.size / 2
	modulate.a = 0.0
	_card.scale = Vector2.ONE * 0.95
	await get_tree().process_frame
	_card.pivot_offset = _card.size / 2
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "modulate:a", 1.0, 0.16)
	tw.tween_property(_card, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	UiKit.play_sfx("whoosh")
	if focus_path != "" and _cards.has(focus_path):
		await get_tree().process_frame
		_scroll.ensure_control_visible(_cards[focus_path])
		_cards[focus_path].flash()


## (Re)builds the cards of the open tab.
func _fill() -> void:
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	_cards.clear()
	var game_mats := MatLibrary.all()
	var mine := CustomMats.all()
	var counts := [game_mats.size() + 1, mine.size()]
	var names := ["Game mats", "Your mats"]
	for k in _tab_btns.size():
		_tab_btns[k].text = "%s  %d" % [names[k], counts[k]]
		UiKit.style_button(_tab_btns[k], "primary" if k == _tab else "secondary")
	_note.text = "Made for the game. They stay." if _tab == 0 else "Made in the editor. Edit or delete them any time."

	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", GAP)
	grid.add_theme_constant_override("v_separation", GAP)
	_body.add_child(grid)
	if _tab == 0:
		grid.add_child(_mat_card("", "Empty mat", "A blank 14 x 14 mat", Grid.empty(), false))
		for preset in game_mats:
			var cells: Array = preset.build_cells()
			grid.add_child(_mat_card(preset.resource_path, preset.title, "%d tiles built in" % Grid.tiles(cells).size(), cells, false))
	else:
		var add := AddCard.new()
		add.custom_minimum_size = Vector2(CARD_W, 0)
		add.activated.connect(func(): _finish({"action": "new"}))
		grid.add_child(add)
		for e in mine:
			var cells: Array = e["preset"].build_cells()
			var n := Grid.tiles(cells).size()
			grid.add_child(_mat_card(e["path"], e["title"], "%d tile%s" % [n, "" if n == 1 else "s"], cells, true))


## Makes `path` the mat in use. The popup stays open so another one can be tried.
func _pick(path: String) -> void:
	if _busy or _done or path == current:
		return
	current = path
	picked.emit(path)
	UiKit.play_sfx("pick")
	var keep := _scroll.scroll_vertical
	_fill()
	await get_tree().process_frame
	_scroll.scroll_vertical = keep
	if _cards.has(path):
		_cards[path].flash()


func _set_tab(k: int) -> void:
	if k == _tab or _busy or _done:
		return
	_tab = k
	UiKit.play_sfx("click")
	_fill()
	_scroll.scroll_vertical = 0


func _mat_card(path: String, title: String, sub: String, cells: Array, custom: bool) -> Control:
	var card := MatCard.new()
	card.custom_minimum_size = Vector2(CARD_W, 0)
	card.setup(title, sub, cells, path == current)
	card.activated.connect(func(): _pick(path))
	if custom:
		var edit := GlyphButton.make("edit", "Edit this mat")
		edit.position = Vector2(THUMB - 34 - 6 - 34 - 6, 6)
		edit.pressed.connect(func(): _finish({"action": "edit", "path": path}))
		card.thumb_holder.add_child(edit)
		var del := GlyphButton.make("delete", "Delete this mat", true)
		del.position = Vector2(THUMB - 34 - 6, 6)
		del.pressed.connect(func(): _ask_delete(path, title))
		card.thumb_holder.add_child(del)
	_cards[path] = card
	return card


func _ask_delete(path: String, title: String) -> void:
	if _busy or _done:
		return
	_busy = true
	var m := Modal.make("Delete \"%s\"?" % title, "This mat is gone for good. You can't undo it.",
		[["Delete mat", "primary", true], ["Keep it", "ghost", false]], "", 1)
	add_child(m)
	var yes: bool = await m.chosen
	_busy = false
	if not yes:
		return
	CustomMats.delete(path)
	mat_deleted.emit(path)
	if path == current:
		current = MatLibrary.DEFAULT
	var keep := _scroll.scroll_vertical
	_fill()
	await get_tree().process_frame
	_scroll.scroll_vertical = keep


func _finish(result: Dictionary) -> void:
	if _done or _busy:
		return
	_done = true
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "modulate:a", 0.0, 0.13)
	tw.tween_property(_card, "scale", Vector2.ONE * 0.97, 0.13)
	await tw.finished
	finished.emit(result)
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if _done or _busy:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_finish({"action": "close"})
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- cards

## One mat: its picture, its name and what it holds. Click it to use it.
class MatCard extends PanelContainer:
	signal activated

	var thumb_holder: Control
	var _selected := false
	var _hover := false
	var _flash := 0.0

	func setup(title: String, sub: String, cells: Array, selected: bool) -> void:
		_selected = selected
		mouse_filter = Control.MOUSE_FILTER_PASS
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(v)
		thumb_holder = Control.new()
		thumb_holder.custom_minimum_size = Vector2(THUMB, THUMB)
		thumb_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var thumb := MatThumb.new()
		thumb.show_mat(cells, THUMB)
		thumb_holder.add_child(thumb)
		if selected:
			var chip := UiKit.chip("In use", UiKit.GOLD, UiKit.INK, 13)
			chip.position = Vector2(8, 8)
			thumb_holder.add_child(chip)
		v.add_child(thumb_holder)
		var gapc := Control.new()
		gapc.custom_minimum_size.y = 6
		gapc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(gapc)
		var t := UiKit.label(title, 20, UiKit.LIMESTONE, "display_bold")
		t.clip_text = true
		t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		v.add_child(t)
		v.add_child(UiKit.label(sub, 14, UiKit.MUTED))
		mouse_entered.connect(func():
			_hover = true
			UiKit.play_sfx("hover")
			_style())
		mouse_exited.connect(func():
			_hover = false
			_style())
		_style()

	func _style() -> void:
		var bg := UiKit.PANEL_HI if not _hover else Color("#285C7E")
		var border := UiKit.LINE
		var w := 2
		if _selected:
			border = UiKit.GOLD
			w = 3
		elif _hover:
			border = UiKit.MUTED
		if _flash > 0.0:
			border = border.lerp(UiKit.BOUG_HI, _flash)
			w = 3
		var sb := UiKit.box(bg, 18, w, border, 14)
		sb.content_margin_bottom = 12
		add_theme_stylebox_override("panel", sb)

	## Pulses the border once: used on the mat that was just saved.
	func flash() -> void:
		var tw := create_tween()
		tw.tween_method(func(x: float):
			_flash = x
			_style(), 0.0, 1.0, 0.25)
		tw.tween_method(func(x: float):
			_flash = x
			_style(), 1.0, 0.0, 1.0)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			activated.emit()


## The first card of "Your mats": a dashed outline and a plus.
class AddCard extends PanelContainer:
	signal activated

	var _hover := false
	var _area: Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tooltip_text = "Build your own mat in the editor"
		var sb := UiKit.box(Color(UiKit.INK_DEEP, 0.35), 18, 0, Color.TRANSPARENT, 14)
		sb.content_margin_bottom = 12
		add_theme_stylebox_override("panel", sb)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(v)
		_area = Control.new()
		_area.custom_minimum_size = Vector2(THUMB, THUMB)
		_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_area.draw.connect(_draw_plus)
		v.add_child(_area)
		var gapc := Control.new()
		gapc.custom_minimum_size.y = 6
		gapc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(gapc)
		v.add_child(UiKit.label("New mat", 20, UiKit.LIMESTONE, "display_bold"))
		v.add_child(UiKit.label("Build your own", 14, UiKit.MUTED))
		mouse_entered.connect(func():
			_hover = true
			UiKit.play_sfx("hover")
			queue_redraw()
			_area.queue_redraw())
		mouse_exited.connect(func():
			_hover = false
			queue_redraw()
			_area.queue_redraw())

	func _draw_plus() -> void:
		var c := _area.size / 2.0
		_area.draw_circle(c, 36.0, UiKit.BOUG_HI if _hover else UiKit.BOUG)
		_area.draw_line(c + Vector2(-16, 0), c + Vector2(16, 0), Color.WHITE, 5.0, true)
		_area.draw_line(c + Vector2(0, -16), c + Vector2(0, 16), Color.WHITE, 5.0, true)

	## Dashed outline: dashes along the straight sides, a solid arc in each corner.
	func _draw() -> void:
		var col := Color(UiKit.GOLD, 0.9) if _hover else Color(UiKit.MUTED, 0.55)
		var r := Rect2(Vector2(1.5, 1.5), size - Vector2(3, 3))
		var rad := 17.0
		var w := 2.5
		draw_arc(r.position + Vector2(rad, rad), rad, PI, PI * 1.5, 10, col, w, true)
		draw_arc(Vector2(r.end.x - rad, r.position.y + rad), rad, PI * 1.5, TAU, 10, col, w, true)
		draw_arc(r.end - Vector2(rad, rad), rad, 0.0, PI * 0.5, 10, col, w, true)
		draw_arc(Vector2(r.position.x + rad, r.end.y - rad), rad, PI * 0.5, PI, 10, col, w, true)
		_dashes(Vector2(r.position.x + rad, r.position.y), Vector2(r.end.x - rad, r.position.y), col, w)
		_dashes(Vector2(r.position.x + rad, r.end.y), Vector2(r.end.x - rad, r.end.y), col, w)
		_dashes(Vector2(r.position.x, r.position.y + rad), Vector2(r.position.x, r.end.y - rad), col, w)
		_dashes(Vector2(r.end.x, r.position.y + rad), Vector2(r.end.x, r.end.y - rad), col, w)

	func _dashes(a: Vector2, b: Vector2, col: Color, w: float) -> void:
		var len := a.distance_to(b)
		var dir := (b - a) / maxf(len, 0.001)
		var d := 0.0
		while d < len:
			draw_line(a + dir * d, a + dir * minf(d + 8.0, len), col, w, true)
			d += 15.0

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			activated.emit()
