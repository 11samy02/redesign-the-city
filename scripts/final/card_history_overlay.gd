extends Control
## Every event and penalty card one planner drew during the game, oldest first, with what each one
## did to their gold and points, so a final score can be traced back to the cards behind it.
## Click a row to see that card at full size.

const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Widgets = preload("res://scripts/ui/widgets.gd")
const Describe = preload("res://scripts/ui/describe.gd")
const OverlayKit = preload("res://scripts/ui/overlay_kit.gd")
const CardDefs = preload("res://scripts/core/card_defs.gd")
const Face = preload("res://scripts/game/circumstance_card_face.gd")

signal closed

const CARD_SCALE := 0.36

var _gs
var _index: int
var _big: Control


## `index` is the planner's seat.
func _init(gs, index: int) -> void:
	_gs = gs
	_index = index


func _ready() -> void:
	var dim := OverlayKit.fill_dimmed(self, 0.88)
	dim.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			_close())
	var p = _gs.players[_index]
	var col := UiKit.player_color(p.color_index)
	var sb := OverlayKit.planner_card_style(col, 26, 28, 8, 40)
	var card := OverlayKit.add_card(self, sb, 900)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	card.add_child(v)
	v.add_child(_build_head(p, col))
	var drawn: Array[Dictionary] = _gs.cards_drawn_by(_index)
	if drawn.is_empty():
		v.add_child(UiKit.label("%s did not draw any cards." % p.name, 20, UiKit.MUTED))
	else:
		v.add_child(_build_totals(drawn))
		v.add_child(_build_list(drawn))
	var back := UiKit.button("Back", "primary", 22)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(_close)
	v.add_child(back)
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.15)


func _build_head(p, col: Color) -> Control:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	var av := Widgets.Avatar.new(46)
	av.color = col
	av.letter = p.name.substr(0, 1).to_upper()
	head.add_child(av)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", -2)
	titles.add_child(UiKit.label("Turn cards: %s" % p.name, 30, col.lightened(0.25), "display_bold"))
	titles.add_child(UiKit.label("Every card they drew, and what it did. Click a card to read it again.", 16, UiKit.MUTED))
	head.add_child(titles)
	return head


## One line that adds the whole history up: the points and the gold the cards moved.
func _build_totals(drawn: Array) -> Control:
	var gold := 0
	var points := 0
	for e in drawn:
		gold += e["gold"][_index]
		points += e["points"][_index]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(UiKit.label("%d card%s" % [drawn.size(), "" if drawn.size() == 1 else "s"], 20, UiKit.LIMESTONE, "body_bold"))
	row.add_child(UiKit.spacer())
	row.add_child(_delta_chip(points, "point"))
	row.add_child(_delta_chip(gold, "gold"))
	return row


func _build_list(drawn: Array) -> Control:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, mini(drawn.size(), 2) * 232.0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)
	for e in drawn:
		list.add_child(_build_row(e))
	return scroll


func _build_row(e: Dictionary) -> Control:
	var id: String = e["id"]
	var good: bool = e["type"] == CardDefs.EVENT
	var tint: Color = Face.EVENT_TINT if good else Face.PENALTY_TINT
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", UiKit.box(UiKit.PANEL_HI, 16, 2, Color(tint, 0.7), 10))
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	row.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_show_big(id))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	row.add_child(h)
	h.add_child(_small_card(id))
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 4)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	top.add_child(UiKit.label(CardDefs.title(id), 24, UiKit.LIMESTONE, "display_bold"))
	top.add_child(UiKit.chip("Round %d" % e["round"], UiKit.PANEL, UiKit.MUTED, 13))
	top.add_child(UiKit.chip("Heads: event" if good else "Tails: penalty", tint.darkened(0.25), UiKit.LIMESTONE, 13))
	mid.add_child(top)
	mid.add_child(_wrapped(CardDefs.info(id)["rule"], 17, UiKit.MUTED))
	if e["choice"] != "":
		mid.add_child(_wrapped("Chose: %s" % e["choice"], 17, UiKit.GOLD))
	for line in e["lines"]:
		if String(line).begins_with("%s chose" % _gs.players[_index].name):
			continue
		mid.add_child(_wrapped(line, 16, UiKit.LIMESTONE))
	h.add_child(mid)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_child(_delta_chip(e["points"][_index], "point"))
	right.add_child(_delta_chip(e["gold"][_index], "gold"))
	h.add_child(right)
	return row


## The real card face, shrunk, so the list looks like the cards people drew.
func _small_card(id: String) -> Control:
	var box := Control.new()
	box.custom_minimum_size = Vector2(Face.WIDTH, Face.HEIGHT) * CARD_SCALE
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var face := Face.front_turn(id)
	face.scale = Vector2.ONE * CARD_SCALE
	face.size = Vector2(Face.WIDTH, Face.HEIGHT)
	box.add_child(face)
	return box


func _wrapped(text: String, size: int, color: Color) -> Label:
	var l := UiKit.label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size.x = 380
	return l


## "+2 points" or "-3 gold" in green or red, grey "0 gold" when nothing changed.
func _delta_chip(n: int, unit: String) -> Label:
	var text := "%s %s%s" % [Describe.signed(n), unit, "" if absi(n) == 1 or unit == "gold" else "s"]
	if n == 0:
		return UiKit.chip(text, UiKit.PANEL, UiKit.MUTED, 15)
	return UiKit.chip(text, Color(UiKit.OLIVE, 0.28) if n > 0 else Color(UiKit.HEAT, 0.3), UiKit.OLIVE.lightened(0.3) if n > 0 else UiKit.HEAT.lightened(0.3), 15)


func _show_big(id: String) -> void:
	if _big != null:
		return
	Sfx.play("whoosh")
	_big = Control.new()
	OverlayKit.fill_dimmed(_big, 0.7)
	_big.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			_big.queue_free()
			_big = null)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_big.add_child(center)
	var face := Face.front_turn(id)
	face.custom_minimum_size = Vector2(Face.WIDTH, Face.HEIGHT)
	center.add_child(face)
	add_child(_big)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if _big != null:
			_big.queue_free()
			_big = null
		else:
			_close()
		get_viewport().set_input_as_handled()


func _close() -> void:
	closed.emit()
	queue_free()
