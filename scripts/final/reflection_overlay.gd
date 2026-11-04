extends Control
## Concept doc, approved addition 1: each planner names the one change that would fix the most
## complaints. One planner at a time, on their own city; computer planners pick on their own.

const UiKit = preload("res://scripts/ui/ui_kit.gd")
const TileDefs = preload("res://scripts/core/tile_defs.gd")
const Widgets = preload("res://scripts/ui/widgets.gd")
const Describe = preload("res://scripts/ui/describe.gd")
const TileView = preload("res://scripts/ui/tile_view.gd")
const MatView = preload("res://scripts/ui/mat_view.gd")
const Tooltip = preload("res://scripts/ui/tooltip.gd")
const Bot = preload("res://scripts/core/bot.gd")
const Scoring = preload("res://scripts/core/scoring.gd")

signal back_pressed
signal cities_pressed

## The longest texts that appear after a pick. Their space is reserved from the start.
const LEGEND_LONGEST := "Green tiles gain points with this change. Gold tiles keep what holds them back."
const DETAIL_LONGEST := "Helps 99 homes and 9 unused places"
const VERDICT_LONGEST := "Accessibility is worth up to 99. Walkability holds the most back: up to 99 points."

var _gs
var _results: Array
var _tooltip: Tooltip
var _rng := RandomNumberGenerator.new()
var _stepper: HBoxContainer
var _stage_box: CenterContainer
var _next_btn: Button
var _step := 0
## Bumped on every stage, so a bot's delayed pick is dropped if the stage has moved on.
var _stage_token := 0
## player index -> the complaint type they named ("" when they had nothing to fix)
var _picked := {}


func _init(gs, results: Array, tooltip: Tooltip) -> void:
	_gs = gs
	_results = results
	_tooltip = tooltip
	_rng.randomize()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = UiKit.INK_DEEP
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + s, 40)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_bottom", 26)
	add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	margin.add_child(v)
	v.add_child(_build_head())
	_stage_box = CenterContainer.new()
	_stage_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_stage_box)
	v.add_child(_build_foot())
	_show_stage(0)
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.25)


## Moves to the next planner, or back to the results after the last one.
func next() -> void:
	if _step + 1 < _gs.players.size():
		_show_stage(_step + 1)
	else:
		back_pressed.emit()


# ================================================================ frame

func _build_head() -> Control:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 24)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", -4)
	titles.add_child(UiKit.label("Name the one change", 48, UiKit.LIMESTONE, "display_bold"))
	titles.add_child(UiKit.label("If you could make only one change to your city, which would add the most points?", 18, UiKit.MUTED))
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(titles)
	_stepper = HBoxContainer.new()
	_stepper.add_theme_constant_override("separation", 8)
	_stepper.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_stepper)
	return head


func _build_foot() -> Control:
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 12)
	var back := UiKit.button("Back to results", "ghost", 19)
	back.pressed.connect(back_pressed.emit)
	foot.add_child(back)
	var cities := UiKit.button("View cities", "secondary", 19)
	cities.pressed.connect(cities_pressed.emit)
	foot.add_child(cities)
	foot.add_child(UiKit.spacer())
	_next_btn = UiKit.button("Next planner", "primary", 24)
	_next_btn.pressed.connect(next)
	foot.add_child(_next_btn)
	return foot


func _refresh_stepper() -> void:
	for c in _stepper.get_children():
		_stepper.remove_child(c)
		c.queue_free()
	for i in _gs.players.size():
		_stepper.add_child(_stepper_pill(i))


func _stepper_pill(i: int) -> Control:
	var p = _gs.players[i]
	var col := UiKit.player_color(p.color_index)
	var current := i == _step
	var pill := PanelContainer.new()
	var sb := UiKit.box(UiKit.PANEL_HI if current else Color.TRANSPARENT, 99, 2, col if current else Color.TRANSPARENT, 6)
	sb.content_margin_right = 14
	pill.add_theme_stylebox_override("panel", sb)
	pill.modulate.a = 1.0 if current else (0.8 if _picked.has(i) else 0.4)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var av := Widgets.Avatar.new(32)
	av.color = col
	av.letter = p.name.substr(0, 1).to_upper()
	h.add_child(av)
	var nl := UiKit.label(p.name, 18, col.lightened(0.25), "display_bold")
	nl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(nl)
	pill.add_child(h)
	return pill


func _card_style(card: PanelContainer, bg: Color, border: Color, width: int) -> void:
	card.add_theme_stylebox_override("panel", UiKit.box(bg, 18, width, border, 14))


## Wraps a label so its slot is as big as `worst` would be. Text that appears later (after a
## pick) then never makes the slot grow, so nothing around it shifts.
func _reserve(real: Label, worst: String) -> Control:
	var box := MarginContainer.new()
	var ghost: Label = real.duplicate()
	ghost.text = worst
	ghost.modulate.a = 0.0
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(real)
	box.add_child(ghost)
	return box


func _fade_in(c: Control) -> void:
	c.modulate.a = 0.0
	create_tween().tween_property(c, "modulate:a", 1.0, 0.3)


# ================================================================ one planner's stage

## One planner's turn: their city on the left, the four possible changes on the right.
func _show_stage(i: int) -> void:
	_step = i
	_stage_token += 1
	var token := _stage_token
	for c in _stage_box.get_children():
		_stage_box.remove_child(c)
		c.queue_free()
	var p = _gs.players[i]
	var r: Dictionary = _results[i]
	_next_btn.text = "Back to results" if i == _gs.players.size() - 1 else "Next planner"
	_next_btn.disabled = true

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 36)
	_stage_box.add_child(row)
	var city := _build_city_panel(p, r)
	row.add_child(city["panel"])
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 14)
	rv.custom_minimum_size.x = 680
	rv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(rv)
	var prompt := UiKit.label("", 38, UiKit.LIMESTONE, "display_bold")
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rv.add_child(prompt)
	var sub := UiKit.label("", 19, UiKit.MUTED)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rv.add_child(sub)

	var room_total := 0
	for t in r["room"]:
		room_total += r["room"][t]
	var who := "your" if not p.is_bot() else "%s's" % p.name
	if room_total == 0:
		_show_nothing_to_fix(i, p, who, prompt, sub, city["legend"])
		_refresh_stepper()
		_fade_in(row)
		return

	prompt.text = "Which one change adds the most points?" if not p.is_bot() else "%s is picking a change." % p.name
	sub.text = "%s city could still score up to %d more point%s. Hover the homes to see what holds them back, then choose the one change that would help most." % [who.capitalize() if not p.is_bot() else who, room_total, "" if room_total == 1 else "s"]
	var ui := {"cards": {}, "mat": city["mat"], "legend": city["legend"], "verdict": null, "verdict_label": null}
	rv.add_child(_build_choice_grid(i, p, ui))
	rv.add_child(_build_verdict(ui))

	_refresh_stepper()
	_fade_in(row)
	if p.is_bot():
		# computer planners name their change on their own
		var pick := Bot.choose_change(r, p.bot_level, _rng)
		get_tree().create_timer(1.2).timeout.connect(func():
			if token == _stage_token:
				_reveal(i, pick, ui))


## The planner's city card: avatar and name, the mat with tile tooltips and a hint line.
func _build_city_panel(p, r: Dictionary) -> Dictionary:
	var col := UiKit.player_color(p.color_index)
	var cell := clampf((get_viewport_rect().size.y - 340.0) / 14.0 - 4.0, 22.0, 45.0)
	var pc := PanelContainer.new()
	pc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var psb := UiKit.box(UiKit.PANEL, 24, 0, Color.TRANSPARENT, 18)
	psb.border_width_top = 8
	psb.border_color = col
	pc.add_theme_stylebox_override("panel", psb)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 10)
	pc.add_child(lv)
	var ph := HBoxContainer.new()
	ph.add_theme_constant_override("separation", 10)
	var av := Widgets.Avatar.new(44)
	av.color = col
	av.letter = p.name.substr(0, 1).to_upper()
	ph.add_child(av)
	var pn := UiKit.label(p.name, 28, col.lightened(0.2), "display_bold")
	pn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ph.add_child(pn)
	if p.is_bot():
		ph.add_child(UiKit.chip("%s bot" % Bot.level_name(p.bot_level), UiKit.PANEL_HI, UiKit.MUTED, 12))
	lv.add_child(ph)
	var mv := MatView.new()
	mv.setup(cell, 2, TileView.Mode.MAT)
	mv.refresh(p.cells, r)
	mv.cell_hovered.connect(func(c, inside):
		if inside and p.cells[c] != null:
			_tooltip.show_tile(p.cells[c], mv.cell_global_rect(c), Describe.cell_lines(p.cells, r, c), false, MatView.road_mask(p.cells, c))
		else:
			_tooltip.hide_tip())
	var mc := CenterContainer.new()
	mc.add_child(mv)
	lv.add_child(mc)
	var legend := UiKit.label("Hover a home to see what holds it back.", 16, UiKit.MUTED)
	legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	legend.custom_minimum_size.x = mv.custom_minimum_size.x
	lv.add_child(_reserve(legend, LEGEND_LONGEST))
	return {"panel": pc, "mat": mv, "legend": legend}


## Every home is at +5 and every place is used: the only change left is more homes.
func _show_nothing_to_fix(i: int, p, who: String, prompt: Label, sub: Label, legend: Label) -> void:
	var empty := 0
	for cell_tile in p.cells:
		empty += 1 if cell_tile == null else 0
	prompt.add_theme_color_override("font_color", UiKit.OLIVE)
	var loans: int = _results[i]["loans"]
	if empty == 0 and loans == 0:
		prompt.text = "A perfect city!"
		sub.text = "Every home is at +5, every place is used and every lot is built. No change could add a single point to %s city." % who
		legend.text = "Nothing holds this city back."
	else:
		prompt.text = "Every home in %s city is at +5." % who
		sub.text = "No change makes a home happier."
		if empty > 0:
			sub.text += " The only points left are in new homes: %d empty lot%s could house more citizens." % [empty, "" if empty == 1 else "s"]
		if loans > 0:
			sub.text += " Loans cost %d points." % _results[i]["loan_penalty"]
		legend.text = "Every home is at the happiness cap."
	_picked[i] = ""
	_next_btn.disabled = false


func _build_choice_grid(i: int, p, ui: Dictionary) -> Control:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	for t in Describe.COMPLAINTS.keys():
		var card := _choice_card(t, p.is_bot())
		grid.add_child(card["card"])
		ui["cards"][t] = card
		if p.is_bot():
			continue
		var hit: Button = card["hit"]
		hit.mouse_entered.connect(func():
			if not _picked.has(i):
				_card_style(card["card"], UiKit.PANEL_HI, Color(UiKit.LIMESTONE, 0.7), 2)
				Sfx.play("hover"))
		hit.mouse_exited.connect(func():
			if not _picked.has(i):
				_card_style(card["card"], UiKit.PANEL, UiKit.LINE, 2))
		hit.pressed.connect(func(): _reveal(i, t, ui))
	return grid


## Empty panel that fills with the result once a change is chosen.
func _build_verdict(ui: Dictionary) -> Control:
	var vp := PanelContainer.new()
	vp.custom_minimum_size.y = 86
	vp.modulate.a = 0.0
	# same padding and border as the revealed look, so the panel never changes size
	vp.add_theme_stylebox_override("panel", UiKit.box(Color.TRANSPARENT, 18, 2, Color.TRANSPARENT, 16))
	var vl := UiKit.label("", 22, UiKit.LIMESTONE, "display_bold")
	vl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vp.add_child(_reserve(vl, VERDICT_LONGEST))
	ui["verdict"] = vp
	ui["verdict_label"] = vl
	return vp


## A big clickable card for one kind of change.
func _choice_card(t: String, locked: bool) -> Dictionary:
	var d: Dictionary = Describe.COMPLAINTS[t]
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(333, 120)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card_style(card, UiKit.PANEL, UiKit.LINE, 2)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	card.add_child(body)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	body.add_child(h)
	var ic := UiKit.icon(d["icon"], 52)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 0)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tv.add_child(UiKit.label(t, 24, UiKit.LIMESTONE, "display_bold"))
	var fix := UiKit.label(d["fix"], 16, UiKit.MUTED)
	fix.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tv.add_child(fix)
	h.add_child(tv)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", -6)
	cv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cv.modulate.a = 0.0
	cv.custom_minimum_size.x = 124
	var count := UiKit.label("0", 44, UiKit.LIMESTONE, "display_bold")
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(count)
	var cap := UiKit.label("points to gain", 14, UiKit.MUTED)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(cap)
	h.add_child(cv)
	# both invisible until the reveal; they sit on the full card width so a long line never
	# squeezes the text column, and their space is reserved so the cards never change size
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 10)
	var detail := UiKit.label("0 homes", 15, UiKit.LIMESTONE, "body_bold")
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.modulate.a = 0.0
	var detail_slot := _reserve(detail, DETAIL_LONGEST)
	detail_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(detail_slot)
	var tag := UiKit.chip("Most points", UiKit.OLIVE, UiKit.INK_DEEP, 13)
	tag.modulate.a = 0.0
	tag.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	foot.add_child(tag)
	body.add_child(foot)
	var hit := Button.new()
	hit.flat = true
	hit.focus_mode = Control.FOCUS_NONE
	hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if locked:
		hit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(hit)
	return {"card": card, "hit": hit, "tag": tag, "detail": detail, "count": count, "cap": cap, "counts": cv}


# ================================================================ reveal

## Shows what the chosen change would gain: on the cards, on the city, and in a verdict.
func _reveal(i: int, chosen: String, ui: Dictionary) -> void:
	if _picked.has(i):
		return
	_picked[i] = chosen
	var p = _gs.players[i]
	var r: Dictionary = _results[i]
	var most := 0
	var best := ""
	for t in Describe.COMPLAINTS.keys():
		if r["room"][t] > most:
			most = r["room"][t]
			best = t
	var n: int = r["room"][chosen]
	var right := n == most
	_reveal_cards(r, chosen, most, right, ui)
	_reveal_city(r, chosen, n, ui)
	_reveal_verdict(p, n, right, best, most, ui)
	if right:
		Sfx.play("coin")
		Widgets.burst(self, ui["cards"][chosen]["card"].get_global_rect().get_center(), "sparkle", 24)
	else:
		Sfx.play("minus")
	_next_btn.disabled = false
	_refresh_stepper()


func _reveal_cards(r: Dictionary, chosen: String, most: int, right: bool, ui: Dictionary) -> void:
	var unused: Array = r["unused"]
	for t in Describe.COMPLAINTS.keys():
		var c: Dictionary = ui["cards"][t]
		var k: int = r["room"][t]
		c["hit"].mouse_filter = Control.MOUSE_FILTER_IGNORE
		c["count"].text = "+%d" % k if k > 0 else "0"
		c["count"].add_theme_color_override("font_color", UiKit.LIMESTONE if k > 0 else UiKit.MUTED)
		c["cap"].text = "point to gain" if k == 1 else "points to gain"
		var homes: int = r["room_homes"][t]
		var parts: Array[String] = []
		if homes > 0:
			parts.append("%d home%s" % [homes, "" if homes == 1 else "s"])
		if t == "Accessibility" and not unused.is_empty():
			parts.append("%d unused place%s" % [unused.size(), "" if unused.size() == 1 else "s"])
		c["detail"].text = "Helps " + " and ".join(PackedStringArray(parts)) if not parts.is_empty() else "Nothing to gain here"
		c["detail"].add_theme_color_override("font_color", UiKit.LIMESTONE if k > 0 else UiKit.MUTED)
		create_tween().tween_property(c["counts"], "modulate:a", 1.0, 0.3)
		create_tween().tween_property(c["detail"], "modulate:a", 1.0, 0.3)
		if t == chosen:
			_mark_chosen(c, right)
		elif k == most:
			_card_style(c["card"], Color(UiKit.OLIVE, 0.1), UiKit.OLIVE, 3)
			c["tag"].text = "Most points"
			c["tag"].modulate.a = 1.0
		else:
			_card_style(c["card"], UiKit.PANEL, UiKit.LINE, 2)
			c["card"].modulate.a = 0.6


func _mark_chosen(c: Dictionary, right: bool) -> void:
	var edge := UiKit.OLIVE if right else UiKit.GOLD
	_card_style(c["card"], Color(edge, 0.16), edge, 4)
	c["tag"].text = "Best pick" if right else "Picked"
	var tsb := UiKit.box(edge, 99)
	tsb.content_margin_left = 10
	tsb.content_margin_right = 10
	tsb.content_margin_top = 2
	tsb.content_margin_bottom = 3
	c["tag"].add_theme_stylebox_override("normal", tsb)
	c["tag"].modulate.a = 1.0


## The change that would help a home most: the chosen one when it helps any citizen there.
func _home_improve(a: Dictionary, chosen: String) -> String:
	var first := ""
	for m in a["members"]:
		if m["improve"] == chosen:
			return chosen
		if first == "" and m["improve"] != "":
			first = m["improve"]
	return first


## On the city: green tiles gain with this change, gold ones stay as they are.
func _reveal_city(r: Dictionary, chosen: String, n: int, ui: Dictionary) -> void:
	var mv: MatView = ui["mat"]
	var map := {}
	var spots: Array = []
	for a in r["apartments"]:
		var improve := _home_improve(a, chosen)
		if improve != "":
			spots.append([a["index"], improve])
	for u in r["unused"]:
		spots.append([u, "Accessibility"])
	var marks := 0
	for spot in spots:
		var ring := UiKit.OLIVE if spot[1] == chosen else UiKit.GOLD
		map[spot[0]] = ring
		marks += 1
		_add_mark(mv, spot[0], spot[1], ring, marks)
	mv.set_highlights(map)
	ui["legend"].text = "Green tiles gain points with this change. Gold tiles keep what holds them back." if n > 0 else "This change helps none of these tiles. They all stay as they are."


## Small round badge in a tile's corner showing which kind of change would help it.
func _add_mark(mv: MatView, cell: int, kind: String, ring: Color, order: int) -> void:
	var side: float = mv.span(TileDefs.footprint(mv.cells[cell]) if mv.cells[cell] != null else 1)
	var px := mv.cell * 0.3 + (4.0 if side > mv.cell else 0.0)
	var mark := PanelContainer.new()
	mark.add_theme_stylebox_override("panel", UiKit.box(Color(UiKit.INK_DEEP, 0.92), 99, 2, ring, 4))
	mark.add_child(UiKit.icon(Describe.COMPLAINTS[kind]["icon"], px))
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.position = mv.cell_pos(cell) + Vector2(side - px - 16, side - px - 16)
	mv.add_child(mark)
	mark.pivot_offset = mark.get_combined_minimum_size() / 2
	mark.scale = Vector2.ZERO
	create_tween().tween_property(mark, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.1 * order)


func _reveal_verdict(p, n: int, right: bool, best: String, most: int, ui: Dictionary) -> void:
	var vp: PanelContainer = ui["verdict"]
	var vl: Label = ui["verdict_label"]
	var tone := UiKit.OLIVE if right else UiKit.GOLD
	vp.add_theme_stylebox_override("panel", UiKit.box(Color(tone, 0.14), 18, 2, tone, 16))
	var lead := "This" if not p.is_bot() else "%s's pick" % p.name
	var plural := "" if n == 1 else "s"
	if right:
		vl.text = "%s%s is worth up to %d point%s, the most in %s city." % ["Right call! " if not p.is_bot() else "", lead, n, plural, "your" if not p.is_bot() else "their"]
	else:
		vl.text = "%s is worth up to %d. %s holds the most back: up to %d points." % [lead, n, best, most]
	vl.add_theme_color_override("font_color", tone.lightened(0.15))
	create_tween().tween_property(vp, "modulate:a", 1.0, 0.3).set_delay(0.2)
