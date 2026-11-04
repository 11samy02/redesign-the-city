extends VBoxContainer
## Right column: one card per planner in turn order, with a live score and a mini view of their city.

const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Describe = preload("res://scripts/ui/describe.gd")
const TileView = preload("res://scripts/ui/tile_view.gd")
const MatView = preload("res://scripts/ui/mat_view.gd")
const Bot = preload("res://scripts/core/bot.gd")

signal city_pressed(index: int)

var _gs
var _title: Label
var _cards: VBoxContainer
var _refs: Array = []
var _last_order: Array = []


func _init(gs) -> void:
	_gs = gs
	custom_minimum_size.x = 268
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 6)
	_title = UiKit.label("Turn order", 17, UiKit.LIMESTONE, "display_bold")
	add_child(_title)
	_cards = VBoxContainer.new()
	_cards.add_theme_constant_override("separation", 6)
	add_child(_cards)
	for i in _gs.players.size():
		_refs.append(_make_card(i))


func refresh() -> void:
	var order: Array[int] = _gs.turn_order()
	_title.text = "Round %d order" % _gs.round_number
	var reordered := not _last_order.is_empty() and _last_order != Array(order)
	var old_y := {}
	for i in _refs.size():
		old_y[i] = _refs[i]["panel"].position.y
	_last_order = Array(order)
	for pos in order.size():
		_refresh_card(order[pos], pos)
	if reordered:
		_animate_reorder(old_y)


## Floats a green "+8" or a red "-2" next to the gold of every planner whose gold changed since `before`
## (one amount per planner, taken before a card or a round event), and rolls the number to its new value.
## `fx_layer` is the screen's effects layer, where the floating numbers are drawn. Call it after refresh().
func show_gold_changes(before: Array, fx_layer: Control) -> void:
	var step := 0
	for i in _refs.size():
		var delta: int = _gs.players[i].money - before[i]
		if delta != 0:
			_announce_gold(i, before[i], delta, step * 0.18, fx_layer)
			step += 1


func _announce_gold(i: int, from_money: int, delta: int, delay: float, fx_layer: Control) -> void:
	var label: Label = _refs[i]["money"]
	var to_money := from_money + delta
	label.text = str(from_money)
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	if not is_instance_valid(label) or not is_instance_valid(fx_layer):
		return
	var color: Color = UiKit.OLIVE if delta > 0 else UiKit.HEAT
	var text_w := UiKit.font("display_bold").get_string_size(str(maxi(from_money, to_money)), HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	var at := label.get_global_rect().position + Vector2(text_w + 30.0, label.size.y * 0.5)
	_float_number(fx_layer, "%+d" % delta, at, color)
	label.add_theme_color_override("font_color", color)
	var tw := create_tween()
	tw.tween_method(func(v: float): label.text = str(roundi(v)), float(from_money), float(to_money), 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.6)
	tw.tween_callback(func(): label.add_theme_color_override("font_color", UiKit.GOLD))


## A number that pops in beside the gold, drifts up a little (not far enough to cover the planner's name
## or status) and fades out.
func _float_number(parent: Control, text: String, at: Vector2, color: Color) -> void:
	var l := UiKit.outline(UiKit.label(text, 26, color, "display_bold"), 8)
	parent.add_child(l)
	l.reset_size()
	l.position = at - l.size / 2.0
	l.pivot_offset = l.size / 2.0
	l.scale = Vector2.ONE * 0.5
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "position:y", l.position.y - 5.0, 1.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.5).set_delay(1.3)
	tw.chain().tween_callback(l.queue_free)


func _make_card(i: int) -> Dictionary:
	var p = _gs.players[i]
	var col := UiKit.player_color(p.color_index)
	var pc := PanelContainer.new()
	pc.mouse_filter = Control.MOUSE_FILTER_STOP
	pc.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	pc.add_child(h)
	var mini := MatView.new()
	mini.setup(3.8, 1, TileView.Mode.MINI, false)
	h.add_child(mini)
	var badge := _make_badge()
	mini.add_child(badge)

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var top := HBoxContainer.new()
	var name := UiKit.label(p.name, 16, UiKit.LIMESTONE, "display_bold")
	name.clip_text = true
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name)
	var status := UiKit.chip("", UiKit.PANEL_HI, UiKit.LIMESTONE, 12)
	top.add_child(status)
	info.add_child(top)
	var money := HBoxContainer.new()
	money.add_theme_constant_override("separation", 4)
	money.add_child(UiKit.icon("res://assets/ui/coin.svg", 20))
	var money_l := UiKit.label("", 15, UiKit.GOLD, "display_bold")
	money.add_child(money_l)
	if p.is_bot():
		money.add_child(UiKit.spacer())
		money.add_child(UiKit.chip("%s bot" % Bot.level_name(p.bot_level), UiKit.PANEL_HI, UiKit.MUTED, 11))
	info.add_child(money)
	var score_l := UiKit.label("", 13, UiKit.LIMESTONE)
	var poll_l := UiKit.label("", 12, UiKit.MUTED)
	for l in [score_l, poll_l, money_l]:
		l.clip_text = true
		l.custom_minimum_size.x = 100
	info.add_child(score_l)
	info.add_child(poll_l)
	h.add_child(info)

	pc.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			city_pressed.emit(i))
	pc.mouse_entered.connect(func(): Sfx.play("hover"))
	_cards.add_child(pc)
	return {"panel": pc, "mini": mini, "status": status, "money": money_l, "score": score_l, "pollution": poll_l, "color": col, "badge": badge}


## Gold number showing the planner's place in the order, pinned to the corner of the mini city.
func _make_badge() -> Label:
	var badge := UiKit.label("1", 17, UiKit.INK_DEEP, "display_bold")
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_stylebox_override("normal", UiKit.box(UiKit.GOLD, 14, 2, UiKit.INK_DEEP))
	badge.size = Vector2(28, 28)
	badge.position = Vector2(-10, -10)
	return badge


func _refresh_card(i: int, pos: int) -> void:
	var ref: Dictionary = _refs[i]
	_cards.move_child(ref["panel"], pos)
	ref["badge"].text = str(pos + 1)
	var p = _gs.players[i]
	var r: Dictionary = _gs.score(i)
	ref["mini"].refresh(p.cells, r)
	ref["money"].text = str(p.money)
	ref["score"].text = "%s, %d citizen%s" % [Describe.points(r["total"]), r["citizens"], "" if r["citizens"] == 1 else "s"]
	ref["pollution"].text = "Pollution %d%s" % [r["pollution"], ", %d loan%s" % [p.loans, "" if p.loans == 1 else "s"] if p.loans > 0 else ""]
	var current: bool = i == _gs.current_index()
	ref["status"].text = _status_text(current, pos)
	var chip_sb: StyleBoxFlat = ref["status"].get_theme_stylebox("normal").duplicate()
	chip_sb.bg_color = UiKit.BOUG if current else UiKit.PANEL_HI
	ref["status"].add_theme_stylebox_override("normal", chip_sb)
	var sb := UiKit.box(UiKit.PANEL if current else Color(UiKit.PANEL, 0.6), 16, 0, Color.TRANSPARENT, 10)
	sb.border_width_left = 6
	sb.border_color = ref["color"]
	if current:
		sb.set_border_width_all(3)
		sb.border_width_left = 8
	ref["panel"].add_theme_stylebox_override("panel", sb)
	ref["panel"].modulate = Color(1, 1, 1, 1.0 if current else 0.82)


func _status_text(current: bool, pos: int) -> String:
	if current:
		return "Now"
	if pos < _gs.turn:
		return "Done"
	return "Next" if pos == _gs.turn + 1 else "Waiting"


## Slides each planner card from its old slot to its new one when the order changes.
func _animate_reorder(old_y: Dictionary) -> void:
	await get_tree().process_frame
	for i in _refs.size():
		var panel: Control = _refs[i]["panel"]
		var new_y := panel.position.y
		panel.position.y = old_y[i]
		var tw := create_tween()
		tw.tween_interval(0.15)
		tw.tween_property(panel, "position:y", new_y, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
		var badge: Control = _refs[i]["badge"]
		badge.pivot_offset = badge.size / 2
		var bt := create_tween()
		bt.tween_interval(0.6)
		bt.tween_property(badge, "scale", Vector2.ONE * 1.4, 0.12)
		bt.tween_property(badge, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK)
