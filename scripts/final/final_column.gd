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

signal cards_pressed

var mat: MatView
var rank_label: Label
## Tile tooltips and the card history stay off until the tally has finished counting.
var inspectable := false:
	set(v):
		inspectable = v
		if _cards_btn != null:
			_cards_btn.disabled = not v

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
var _cards_btn: Button
var _complaints: HBoxContainer


func _init(player, result: Dictionary, cell: float, tooltip: Tooltip) -> void:
	_player = player
	_result = result
	_tooltip = tooltip
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var col := UiKit.player_color(player.color_index)
	var sb := UiKit.box(UiKit.PANEL, 22, 0, Color.TRANSPARENT, 18)
	sb.border_width_top = 8
	sb.border_color = col
	add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 7)
	add_child(v)
	v.add_child(_build_head(col))
	v.add_child(_build_mat(cell))
	v.add_child(_build_lines())
	v.add_child(_build_total())
	_complaints = HBoxContainer.new()
	_complaints.add_theme_constant_override("separation", 6)
	_complaints.custom_minimum_size.y = 34
	v.add_child(_complaints)


## Counts this city's score up home by home, then loans, unused places, variety and complaints.
## `screen` supplies the effects layer (`fx`), the pace (`speed`) and `wait(seconds)`.
func count(screen) -> void:
	var r := _result
	pivot_offset = size / 2
	if screen.speed > 0.0:
		create_tween().tween_property(self, "scale", Vector2.ONE * 1.03, 0.2)
	_pollution.text = "%d, %s" % [r["pollution"], "no effect" if r["pollution_penalty"] == 0 else "-%d per citizen" % r["pollution_penalty"]]
	_pollution.add_theme_color_override("font_color", UiKit.OLIVE if r["pollution_penalty"] == 0 else UiKit.HEAT)
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
	var av := Widgets.Avatar.new(44)
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
	mat.setup(cell, 5, TileView.Mode.MAT)
	mat.refresh(_player.cells, _result)
	for view in mat.views:
		view.apartment_info = null
		view.badge_text = ""
	mat.cell_hovered.connect(_on_cell_hovered)
	var mc := CenterContainer.new()
	mc.add_child(mat)
	return mc


func _build_lines() -> Control:
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 3)
	_citizens = _line(lines, "Citizens")
	_pollution = _line(lines, "Pollution")
	_loans = _line(lines, "Loans")
	_unused = _line(lines, "Unused places")
	_variety = _line(lines, "Variety")
	_cards = _line(lines, "Turn cards")
	_cards_btn = UiKit.button("Show cards", "ghost", 14)
	_cards_btn.disabled = true
	_cards_btn.tooltip_text = "See every card this planner drew and what it did to the score."
	_cards_btn.pressed.connect(cards_pressed.emit)
	_cards.get_parent().add_child(_cards_btn)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.add_child(lines)
	var rule := ColorRect.new()
	rule.color = UiKit.LINE
	rule.custom_minimum_size.y = 2
	box.add_child(rule)
	return box


func _build_total() -> Control:
	var total_row := HBoxContainer.new()
	total_row.add_child(UiKit.label("Total", 24, UiKit.LIMESTONE, "display_bold"))
	total_row.add_child(UiKit.spacer())
	_total = UiKit.label("0", 52, UiKit.LIMESTONE, "display_bold")
	total_row.add_child(_total)
	return total_row


func _line(parent: Control, caption: String) -> Label:
	var h := HBoxContainer.new()
	h.add_child(UiKit.label(caption, 17, UiKit.MUTED))
	h.add_child(UiKit.spacer())
	var l := UiKit.label("", 17, UiKit.LIMESTONE, "body_bold")
	h.add_child(l)
	parent.add_child(h)
	return l


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
		_citizens.text = "%d counted" % counted
		if screen.speed > 0.0:
			var center: Vector2 = view.get_global_rect().get_center()
			Widgets.float_text(screen.fx, Describe.signed(a["sp"]) if a["sp"] != 0 else "0", center, TileView.face_color(a["happiness"]), 30)
			Sfx.play("tick" if a["sp"] >= 0 else "minus", 1.0 + clampf(_running * 0.02, -0.3, 0.6))
		_set_total(_running + a["sp"], screen.speed)
		await screen.wait(0.32)
	_citizens.text = "%d, %d happy" % [_result["citizens"], _result["happy_citizens"]]
	if _result["apartments"].is_empty():
		_citizens.text = "None housed"


func _count_loans(screen) -> void:
	var r := _result
	_loans.text = "%d, -%d points" % [r["loans"], r["loan_penalty"]] if r["loans"] > 0 else "None"
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
	_variety.text = "%d of %d kinds, %s" % [kinds, Roles.IDS.size(), Describe.points(r["variety_bonus"])] if r["variety_bonus"] > 0 else "%d of %d kinds" % [kinds, Roles.IDS.size()]
	_variety.tooltip_text = "Kinds of citizen with at least one happy citizen: %s." % (", ".join(names) if not names.is_empty() else "none")
	_variety.mouse_filter = Control.MOUSE_FILTER_PASS
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
	_cards.text = Describe.points(pts) if pts != 0 else "None"
	if pts == 0:
		return
	if screen.speed > 0.0:
		Widgets.float_text(screen.fx, "%s cards" % Describe.signed(pts), _total.get_global_rect().get_center() - Vector2(0, 40), UiKit.OLIVE if pts > 0 else UiKit.HEAT, 26)
		Sfx.play("tick" if pts > 0 else "minus")
	_set_total(_running + pts, screen.speed)
	await screen.wait(0.4)


func _count_unused(screen) -> void:
	var r := _result
	_unused.text = "%d, -%d point%s" % [r["unused"].size(), r["unused_penalty"], "" if r["unused_penalty"] == 1 else "s"] if r["unused_penalty"] > 0 else "None"
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
