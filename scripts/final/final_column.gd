extends PanelContainer
## One planner's column on the final-scoring screen: their city, the tally lines and the total.

const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Widgets = preload("res://scripts/ui/widgets.gd")
const Describe = preload("res://scripts/ui/describe.gd")
const TileView = preload("res://scripts/ui/tile_view.gd")
const MatView = preload("res://scripts/ui/mat_view.gd")
const Tooltip = preload("res://scripts/ui/tooltip.gd")
const Scoring = preload("res://scripts/core/scoring.gd")
const Bot = preload("res://scripts/core/bot.gd")
const Roles = preload("res://scripts/core/roles.gd")
const Face = preload("res://scripts/game/circumstance_card_face.gd")

## The turn-card thumbnails were clicked.
signal cards_pressed
## The city itself was clicked: the planner wants the big view with the timeline.
signal city_pressed

const THUMB_W := 38.0

var mat: MatView
var rank_label: Label
## Tile tooltips, the big city view and the card history stay off until the tally has finished counting.
var inspectable := false:
	set(v):
		inspectable = v
		if _thumbs != null:
			_thumbs.modulate.a = 1.0 if v else 0.45
		if mat != null:
			mat.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if v else Control.CURSOR_ARROW

var _player
var _result: Dictionary
var _tooltip: Tooltip
var _running := 0
var _total: Label
var _citizens: Label
var _pollution: Label
var _loans: Label
var _unused: Label
var _variety: Label
var _cards: Label
var _thumbs: HBoxContainer
var _complaints: HBoxContainer
var _card_ids: Array


## `card_ids` are the turn cards this planner drew, oldest first.
func _init(player, result: Dictionary, cell: float, tooltip: Tooltip, card_ids: Array = []) -> void:
	_player = player
	_result = result
	_tooltip = tooltip
	_card_ids = card_ids
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var col := UiKit.player_color(player.color_index)
	var sb := UiKit.box(UiKit.PANEL, 22, 0, Color.TRANSPARENT, 14)
	sb.border_width_top = 8
	sb.border_color = col
	add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	v.add_child(_build_head(col))
	v.add_child(_build_mat(cell))
	v.add_child(_build_total())
	v.add_child(_build_stats())
	v.add_child(_build_thumbs())
	_complaints = HBoxContainer.new()
	_complaints.add_theme_constant_override("separation", 6)
	_complaints.custom_minimum_size.y = 26
	v.add_child(_complaints)


## Counts this city's score up home by home, then loans, unused places, variety and complaints.
## `screen` supplies the effects layer (`fx`), the pace (`speed`) and `wait(seconds)`.
func count(screen) -> void:
	var r := _result
	pivot_offset = size / 2
	if screen.speed > 0.0:
		create_tween().tween_property(self, "scale", Vector2.ONE * 1.03, 0.2)
	_show_stat(_pollution, str(r["pollution"]), 1 if r["pollution_penalty"] == 0 else -1,
		"Pollution %d: %s." % [r["pollution"], "no effect" if r["pollution_penalty"] == 0 else "every citizen loses %d point%s" % [r["pollution_penalty"], "" if r["pollution_penalty"] == 1 else "s"]])
	await _count_homes(screen)
	await _count_loans(screen)
	await _count_unused(screen)
	await _count_variety(screen)
	await _count_cards(screen)
	_set_total(_result["total"], screen.speed)
	await _show_complaints(screen)
	if screen.speed > 0.0:
		create_tween().tween_property(self, "scale", Vector2.ONE, 0.2)


func _build_head(col: Color) -> Control:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	var av := Widgets.Avatar.new(38)
	av.color = col
	av.letter = _player.name.substr(0, 1).to_upper()
	head.add_child(av)
	var name := UiKit.label(_player.name, 26, col.lightened(0.2), "display_bold")
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.clip_text = true
	head.add_child(name)
	if _player.is_bot():
		head.add_child(UiKit.chip("%s bot" % Bot.level_name(_player.bot_level), UiKit.PANEL_HI, UiKit.MUTED, 12))
	rank_label = UiKit.label("", 22, UiKit.GOLD, "display_bold")
	head.add_child(rank_label)
	return head


func _build_mat(cell: float) -> Control:
	mat = MatView.new()
	mat.setup(cell, 2, TileView.Mode.MAT)
	mat.refresh(_player.cells, _result)
	for view in mat.views:
		view.apartment_info = null
		view.badge_text = ""
	mat.cell_hovered.connect(_on_cell_hovered)
	mat.mouse_filter = Control.MOUSE_FILTER_PASS
	mat.gui_input.connect(_on_mat_input)
	mat.cell_pressed.connect(func(_c): _open_city())
	mat.mouse_entered.connect(func(): _hint_hover(true))
	mat.mouse_exited.connect(func(): _hint_hover(false))
	var mc := CenterContainer.new()
	mc.add_child(mat)
	return mc


## A click anywhere on the city, on a lot or between them, opens the big view.
func _on_mat_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_open_city()
		mat.accept_event()


func _open_city() -> void:
	if inspectable:
		city_pressed.emit()


func _hint_hover(inside: bool) -> void:
	if not inspectable:
		return
	mat.create_tween().tween_property(mat, "modulate", Color(1.12, 1.12, 1.12) if inside else Color.WHITE, 0.12)


## Six small tiles instead of a table: a caption over one number, the colour says good or bad.
func _build_stats() -> Control:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	_citizens = _stat(grid, "Happy")
	_pollution = _stat(grid, "Pollution")
	_loans = _stat(grid, "Loans")
	_unused = _stat(grid, "Unused")
	_variety = _stat(grid, "Variety")
	_cards = _stat(grid, "Cards")
	for l in [_citizens, _pollution, _loans, _unused, _variety, _cards]:
		_show_stat(l, "-", 0)
	return grid


func _stat(parent: Control, caption: String) -> Label:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", UiKit.box(Color(UiKit.PANEL_HI, 0.7), 12, 0, Color.TRANSPARENT, 5))
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", -4)
	panel.add_child(box)
	var cap := UiKit.label(caption, 13, UiKit.MUTED, "body_bold")
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(cap)
	var value := UiKit.label("", 23, UiKit.LIMESTONE, "display_bold")
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(value)
	parent.add_child(panel)
	return value


## Shows a stat: `text`, in green when it helps, red when it hurts, grey when it changes nothing.
func _show_stat(label: Label, text: String, effect: int, tip := "") -> void:
	label.text = text
	label.add_theme_color_override("font_color", UiKit.OLIVE if effect > 0 else (UiKit.HEAT if effect < 0 else UiKit.MUTED))
	label.get_parent().get_parent().tooltip_text = tip


## The turn cards this planner drew, as a row of small card faces. Click them for the full grid.
func _build_thumbs() -> Control:
	_thumbs = HBoxContainer.new()
	_thumbs.add_theme_constant_override("separation", 5)
	_thumbs.alignment = BoxContainer.ALIGNMENT_CENTER
	_thumbs.custom_minimum_size.y = Face.HEIGHT * THUMB_W / Face.WIDTH
	_thumbs.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_thumbs.tooltip_text = "Turn cards drawn. Click to see them."
	_thumbs.modulate.a = 0.45
	if _card_ids.is_empty():
		_thumbs.add_child(UiKit.label("No turn cards drawn", 15, UiKit.MUTED))
		_thumbs.mouse_default_cursor_shape = Control.CURSOR_ARROW
		_thumbs.tooltip_text = ""
		return _thumbs
	var s := THUMB_W / Face.WIDTH
	for id in _card_ids:
		var slot := Control.new()
		slot.custom_minimum_size = Vector2(THUMB_W, Face.HEIGHT * s)
		slot.mouse_filter = Control.MOUSE_FILTER_PASS
		slot.pivot_offset = slot.custom_minimum_size / 2.0
		var face := Face.front_turn(id)
		face.size = Vector2(Face.WIDTH, Face.HEIGHT)
		face.scale = Vector2.ONE * s
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(face)
		slot.mouse_entered.connect(func():
			if inspectable:
				slot.create_tween().tween_property(slot, "scale", Vector2.ONE * 1.18, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
		slot.mouse_exited.connect(func():
			slot.create_tween().tween_property(slot, "scale", Vector2.ONE, 0.12))
		slot.gui_input.connect(func(e):
			if inspectable and e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				cards_pressed.emit()
				slot.accept_event())
		_thumbs.add_child(slot)
	return _thumbs


func _build_total() -> Control:
	var total_row := HBoxContainer.new()
	var caption := UiKit.label("Total", 22, UiKit.MUTED, "display_bold")
	caption.size_flags_vertical = Control.SIZE_SHRINK_END
	total_row.add_child(caption)
	total_row.add_child(UiKit.spacer())
	_total = UiKit.label("0", 46, UiKit.LIMESTONE, "display_bold")
	total_row.add_child(_total)
	return total_row


func _on_cell_hovered(c: int, inside: bool) -> void:
	if inside and _player.cells[c] != null and inspectable:
		_tooltip.show_tile(_player.cells[c], mat.cell_global_rect(c), Describe.cell_lines(_player.cells, _result, c), false, MatView.road_mask(_player.cells, c))
	else:
		_tooltip.hide_tip()


func _set_total(value: int, speed: float) -> void:
	_running = value
	_total.text = Describe.signed(value) if value != 0 else "0"
	_total.add_theme_color_override("font_color", UiKit.OLIVE if value > 0 else (UiKit.HEAT if value < 0 else UiKit.LIMESTONE))
	_total.pivot_offset = _total.size / 2
	if speed > 0.0:
		var tw := create_tween()
		tw.tween_property(_total, "scale", Vector2.ONE * 1.2, 0.06)
		tw.tween_property(_total, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK)


func _count_homes(screen) -> void:
	var counted := 0
	for a in _result["apartments"]:
		var view = mat.views[a["index"]]
		view.apartment_info = a
		view.pop(0.18)
		counted += a["citizens"]
		_show_stat(_citizens, str(counted), 0)
		if screen.speed > 0.0:
			var center: Vector2 = view.get_global_rect().get_center()
			Widgets.float_text(screen.fx, Describe.signed(a["sp"]) if a["sp"] != 0 else "0", center, TileView.face_color(a["happiness"]), 30)
			Sfx.play("tick" if a["sp"] >= 0 else "minus", 1.0 + clampf(_running * 0.02, -0.3, 0.6))
		_set_total(_running + a["sp"], screen.speed)
		await screen.wait(0.32)
	_show_stat(_citizens, "%d/%d" % [_result["happy_citizens"], _result["citizens"]], 1 if _result["unhappy_citizens"] == 0 and _result["citizens"] > 0 else (-1 if _result["unhappy_citizens"] > 0 else 0),
		"%d of %d citizens are happy." % [_result["happy_citizens"], _result["citizens"]])
	if _result["apartments"].is_empty():
		_show_stat(_citizens, "0", 0, "Nobody is housed.")


func _count_loans(screen) -> void:
	var r := _result
	_show_stat(_loans, "-%d" % r["loan_penalty"] if r["loans"] > 0 else "0", -1 if r["loans"] > 0 else 0,
		"%d loan%s: -%d points." % [r["loans"], "" if r["loans"] == 1 else "s", r["loan_penalty"]] if r["loans"] > 0 else "No loans.")
	for k in r["loans"]:
		var cost := Scoring.loan_penalty(k + 1) - Scoring.loan_penalty(k)
		if screen.speed > 0.0:
			Widgets.float_text(screen.fx, "-%d loan" % cost, _total.get_global_rect().get_center() - Vector2(0, 40), UiKit.HEAT, 26)
			Sfx.play("minus")
		_set_total(_running - cost, screen.speed)
		await screen.wait(0.4)


## The bonus for housing several kinds of citizen well.
func _count_variety(screen) -> void:
	var r := _result
	var kinds: int = r["variety_roles"].size()
	var names: Array[String] = []
	for role in r["variety_roles"]:
		names.append(Roles.DEFS[role]["name"])
	_show_stat(_variety, Describe.signed(r["variety_bonus"]) if r["variety_bonus"] > 0 else "0", 1 if r["variety_bonus"] > 0 else 0,
		"%d of %d kinds of citizen have a happy citizen: %s." % [kinds, Roles.IDS.size(), ", ".join(names) if not names.is_empty() else "none"])
	if r["variety_bonus"] <= 0:
		return
	if screen.speed > 0.0:
		Widgets.float_text(screen.fx, "%s variety" % Describe.signed(r["variety_bonus"]), _total.get_global_rect().get_center() - Vector2(0, 40), UiKit.OLIVE, 26)
		Sfx.play("tick")
	_set_total(_running + r["variety_bonus"], screen.speed)
	await screen.wait(0.4)


## Points won or lost through event and penalty cards.
func _count_cards(screen) -> void:
	var pts: int = _result["card_points"]
	_show_stat(_cards, Describe.signed(pts) if pts != 0 else "0", signi(pts), "Points from event and penalty cards." if pts != 0 else "The turn cards changed no points.")
	if pts == 0:
		return
	if screen.speed > 0.0:
		Widgets.float_text(screen.fx, "%s cards" % Describe.signed(pts), _total.get_global_rect().get_center() - Vector2(0, 40), UiKit.OLIVE if pts > 0 else UiKit.HEAT, 26)
		Sfx.play("tick" if pts > 0 else "minus")
	_set_total(_running + pts, screen.speed)
	await screen.wait(0.4)


func _count_unused(screen) -> void:
	var r := _result
	_show_stat(_unused, "-%d" % r["unused_penalty"] if r["unused_penalty"] > 0 else "0", -1 if r["unused_penalty"] > 0 else 0,
		"%d empty lot%s: -1 point each." % [r["unused"].size(), "" if r["unused"].size() == 1 else "s"] if r["unused_penalty"] > 0 else "No empty lots.")
	for u in r["unused"]:
		mat.views[u].highlight = UiKit.HEAT
		mat.views[u].pop(0.18)
		if screen.speed > 0.0:
			Widgets.float_text(screen.fx, "-1 unused", mat.views[u].get_global_rect().get_center(), UiKit.HEAT, 26)
			Sfx.play("minus")
		_set_total(_running - Scoring.UNUSED_PENALTY, screen.speed)
		await screen.wait(0.4)


## "2x No library within reach" lines for every specific complaint of one type.
func _detail_text(type: String) -> String:
	var counts := {}
	for a in _result["apartments"]:
		for m in a["members"]:
			if m["complaint"] == type:
				counts[m["complaint_detail"]] = counts.get(m["complaint_detail"], 0) + 1
	var out: Array[String] = []
	for d in counts:
		out.append("%dx %s" % [counts[d], d])
	return "
".join(out)


func _show_complaints(screen) -> void:
	var r := _result
	for type in Describe.COMPLAINTS:
		var n: int = r["complaints"][type]
		if n == 0:
			continue
		var chip := HBoxContainer.new()
		chip.add_theme_constant_override("separation", 2)
		chip.add_child(UiKit.icon(Describe.COMPLAINTS[type]["icon"], 26))
		chip.add_child(UiKit.label(str(n), 18, UiKit.HEAT, "display_bold"))
		chip.tooltip_text = "%d %s complaint%s: %s
%s" % [n, type, "" if n == 1 else "s", Describe.COMPLAINTS[type]["meaning"], _detail_text(type)]
		chip.mouse_filter = Control.MOUSE_FILTER_PASS
		_complaints.add_child(chip)
		if screen.speed > 0.0:
			chip.modulate.a = 0.0
			create_tween().tween_property(chip, "modulate:a", 1.0, 0.2)
			Sfx.play("pop")
		await screen.wait(0.12)
	if r["unhappy_citizens"] == 0:
		_complaints.add_child(UiKit.label("No complaints", 16, UiKit.OLIVE, "body_bold"))
