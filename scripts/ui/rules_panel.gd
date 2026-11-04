extends Control
## "How to play" overlay: every rule, in pages. A sidebar lists the pages, the footer steps through
## them, and the card pages show the real cards (click one to see it big).

const TileDefs = preload("res://scripts/core/tile_defs.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const OverlayKit = preload("res://scripts/ui/overlay_kit.gd")
const Describe = preload("res://scripts/ui/describe.gd")
const CircumstanceDefs = preload("res://scripts/core/circumstance_defs.gd")
const Roles = preload("res://scripts/core/roles.gd")
const CardDefs = preload("res://scripts/core/card_defs.gd")
const Scoring = preload("res://scripts/core/scoring.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const CircumstanceCardFace = preload("res://scripts/game/circumstance_card_face.gd")

signal closed

const TABS := ["The goal", "Your turn", "Tiles", "People and needs", "Happiness", "Complaints", "Turn cards", "Hidden circumstances", "Objectives"]
const TAB_ICONS := [
	"res://assets/ui/crown.svg", "res://assets/ui/coin.svg", "res://assets/ui/bank.svg", "res://assets/ui/citizen.svg",
	"res://assets/ui/smile_up.svg", "res://assets/ui/smile_down.svg", "res://assets/ui/event.svg", "res://assets/ui/sun.svg",
	"res://assets/ui/trophy.svg",
]
const PANEL_SIZE := Vector2(1380, 810)
const SIDEBAR_W := 262.0
const CARD_COLUMNS := 4
const CARD_GAP := 16.0
## Cards are built a few at a time so opening a page with 32 of them does not stall.
const CARDS_PER_FRAME := 6

var _panel: PanelContainer
var _content: VBoxContainer
var _scroll: ScrollContainer
var _tab_buttons: Array[Button] = []
var _dots: Array[Panel] = []
var _back_btn: Button
var _next_btn: Button
var _tab := 0
var _gallery_gen := 0
var _zoom: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(UiKit.INK_DEEP, 0.86)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			close())
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var vp := get_viewport_rect().size
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(minf(PANEL_SIZE.x, vp.x - 40.0), minf(PANEL_SIZE.y, vp.y - 40.0))
	var sb := UiKit.box(UiKit.PANEL, 30, 2, UiKit.LINE, 0)
	sb.content_margin_left = 30
	sb.content_margin_right = 30
	sb.content_margin_top = 24
	sb.content_margin_bottom = 22
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 40
	_panel.add_theme_stylebox_override("panel", sb)
	center.add_child(_panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 18)
	_panel.add_child(root)
	root.add_child(_build_header())

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 26)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	body.add_child(_build_sidebar())

	var page := PanelContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_stylebox_override("panel", UiKit.box(Color(UiKit.INK, 0.45), 22, 0, Color.TRANSPARENT, 4))
	body.add_child(page)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(_scroll)
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "top", "right", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 22)
	_scroll.add_child(pad)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 18)
	pad.add_child(_content)

	root.add_child(_build_footer())
	_show_tab(0)
	_panel.pivot_offset = _panel.custom_minimum_size / 2
	_panel.scale = Vector2.ONE * 0.94
	modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "modulate:a", 1.0, 0.18)
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play("whoosh")


func _build_header() -> Control:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	var logo := PanelContainer.new()
	logo.add_theme_stylebox_override("panel", UiKit.box(UiKit.BOUG, 18, 0, Color.TRANSPARENT, 8))
	logo.add_child(UiKit.icon("res://assets/ui/crown.svg", 36))
	logo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(logo)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", -4)
	titles.add_child(UiKit.label("How to play", 38, UiKit.LIMESTONE, "display_bold"))
	titles.add_child(UiKit.label("Everything about Redesign the City, one page at a time.", 16, UiKit.MUTED))
	head.add_child(titles)
	head.add_child(UiKit.spacer())
	var x := OverlayKit.close_button(close, 46.0)
	x.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(x)
	return head


func _build_sidebar() -> Control:
	var tabs := VBoxContainer.new()
	tabs.custom_minimum_size.x = SIDEBAR_W
	tabs.add_theme_constant_override("separation", 6)
	for i in TABS.size():
		var b := Button.new()
		b.text = TABS[i]
		b.icon = UiKit.tex(TAB_ICONS[i])
		b.expand_icon = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.custom_minimum_size.y = 50
		b.add_theme_font_override("font", UiKit.font("display"))
		b.add_theme_font_size_override("font_size", 19)
		b.add_theme_constant_override("icon_max_width", 26)
		b.add_theme_constant_override("h_separation", 12)
		b.mouse_entered.connect(func():
			if _tab_buttons.find(b) != _tab:
				UiKit.play_sfx("hover"))
		b.pressed.connect(func():
			UiKit.play_sfx("click")
			_show_tab(i))
		tabs.add_child(b)
		_tab_buttons.append(b)
	tabs.add_child(UiKit.spacer(true))
	var keys := UiKit.label("Up and Down switch pages. Esc closes.", 14, UiKit.MUTED)
	keys.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	keys.custom_minimum_size.x = SIDEBAR_W - 12
	tabs.add_child(keys)
	return tabs


func _build_footer() -> Control:
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 14)
	_back_btn = UiKit.button("‹  Back", "ghost", 19)
	_back_btn.pressed.connect(func(): _show_tab(_tab - 1))
	foot.add_child(_back_btn)
	foot.add_child(UiKit.spacer())
	var dots := HBoxContainer.new()
	dots.add_theme_constant_override("separation", 8)
	dots.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for i in TABS.size():
		var d := Panel.new()
		d.custom_minimum_size = Vector2(11, 11)
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dots.add_child(d)
		_dots.append(d)
	foot.add_child(dots)
	foot.add_child(UiKit.spacer())
	_next_btn = UiKit.button("Next  ›", "primary", 19)
	_next_btn.pressed.connect(func():
		if _tab >= TABS.size() - 1:
			close()
		else:
			_show_tab(_tab + 1))
	foot.add_child(_next_btn)
	return foot


func close() -> void:
	if _zoom != null:
		return
	set_process_unhandled_input(false)
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "modulate:a", 0.0, 0.15)
	tw.tween_property(_panel, "scale", Vector2.ONE * 0.96, 0.15)
	await tw.finished
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if _zoom != null:
			if event.keycode in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
				_close_zoom()
			get_viewport().set_input_as_handled()
			return
		match event.keycode:
			KEY_ESCAPE, KEY_H, KEY_F1:
				close()
			KEY_UP, KEY_W, KEY_LEFT:
				_show_tab(wrapi(_tab - 1, 0, TABS.size()))
			KEY_DOWN, KEY_S, KEY_TAB, KEY_RIGHT:
				_show_tab(wrapi(_tab + 1, 0, TABS.size()))
		get_viewport().set_input_as_handled()


func _show_tab(i: int) -> void:
	if i < 0 or i >= TABS.size():
		return
	_tab = i
	_gallery_gen += 1
	for k in _tab_buttons.size():
		_style_tab(_tab_buttons[k], k == i)
		var dot := _dots[k]
		dot.add_theme_stylebox_override("panel", UiKit.box(UiKit.GOLD if k == i else UiKit.LINE, 99))
		dot.custom_minimum_size.x = 26 if k == i else 11
	_back_btn.disabled = i == 0
	_back_btn.modulate.a = 0.0 if i == 0 else 1.0
	_next_btn.text = "Done" if i == TABS.size() - 1 else "%s  ›" % TABS[i + 1]
	for c in _content.get_children():
		_content.remove_child(c)
		c.queue_free()
	match i:
		0: _goal()
		1: _turn()
		2: _tiles()
		3: _people()
		4: _happiness()
		5: _complaints()
		6: _turn_cards()
		7: _events()
		8: _objectives()
	_scroll.scroll_vertical = 0
	_content.modulate.a = 0.0
	create_tween().tween_property(_content, "modulate:a", 1.0, 0.15)


## The page list: the open page is a bougainvillea pill, the others are quiet until you hover them.
func _style_tab(b: Button, active: bool) -> void:
	var flat := UiKit.box(Color(0, 0, 0, 0), 16, 0, Color.TRANSPARENT)
	flat.content_margin_left = 16
	flat.content_margin_right = 12
	flat.content_margin_top = 8
	flat.content_margin_bottom = 8
	var on: StyleBoxFlat = flat.duplicate()
	on.bg_color = UiKit.BOUG
	on.shadow_color = Color(UiKit.BOUG, 0.4)
	on.shadow_size = 10
	var hover: StyleBoxFlat = flat.duplicate()
	hover.bg_color = Color(1, 1, 1, 0.07)
	b.add_theme_stylebox_override("normal", on if active else flat)
	b.add_theme_stylebox_override("hover", on if active else hover)
	b.add_theme_stylebox_override("pressed", on if active else hover)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(c, Color.WHITE if active else UiKit.LIMESTONE)
	b.add_theme_color_override("icon_normal_color", Color.WHITE if active else Color(UiKit.LIMESTONE, 0.75))
	b.add_theme_color_override("icon_hover_color", Color.WHITE)
	b.add_theme_color_override("icon_pressed_color", Color.WHITE)


# ---------------------------------------------------------------- helpers

## The page title and a lead paragraph under it.
func _hero(title: String, lead: String) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.add_child(UiKit.label(title, 38, UiKit.LIMESTONE, "display_bold"))
	box.add_child(_rich(lead, 19, Color(UiKit.LIMESTONE, 0.85)))
	_content.add_child(box)


## A section heading with a gold bar in front of it.
func _h(text: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var bar := ColorRect.new()
	bar.color = UiKit.GOLD
	bar.custom_minimum_size = Vector2(5, 26)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	row.add_child(UiKit.label(text, 25, UiKit.LIMESTONE, "display_bold"))
	_content.add_child(row)


func _rich(text: String, size: int, color: Color) -> RichTextLabel:
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rt.mouse_filter = Control.MOUSE_FILTER_PASS
	rt.add_theme_font_override("normal_font", UiKit.font("body"))
	rt.add_theme_font_override("bold_font", UiKit.font("body_bold"))
	rt.add_theme_font_size_override("normal_font_size", size)
	rt.add_theme_font_size_override("bold_font_size", size)
	rt.add_theme_color_override("default_color", color)
	rt.add_theme_constant_override("line_separation", 5)
	rt.text = text
	return rt


func _p(text: String, color := UiKit.LIMESTONE, size := 18) -> RichTextLabel:
	var rt := _rich(text, size, color)
	_content.add_child(rt)
	return rt


func _card(children: Array, bg := UiKit.PANEL_HI) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UiKit.box(Color(bg, 0.55), 20, 0, Color.TRANSPARENT, 18))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 18)
	for c in children:
		hb.add_child(c)
	pc.add_child(hb)
	return pc


func _stat(value: String, caption: String) -> Control:
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UiKit.label(value, 42, UiKit.GOLD, "display_bold"))
	v.add_child(UiKit.label(caption, 15, UiKit.MUTED))
	return v


## A round number badge for a step.
func _badge(n: int) -> Control:
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(46, 46)
	pc.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	pc.add_theme_stylebox_override("panel", UiKit.box(Color(UiKit.GOLD, 0.2), 99, 2, Color(UiKit.GOLD, 0.7)))
	var l := UiKit.label(str(n), 26, UiKit.GOLD, "display_bold")
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pc.add_child(l)
	return pc


## A card rule with the happiness words replaced by a smiley (see CircumstanceCardFace.happiness_icons).
func _rule_text(text: String, size: int) -> RichTextLabel:
	return _rich(CircumstanceCardFace.happiness_icons(text, "7ED957", "FF8A7A", size), size, UiKit.LIMESTONE)


func _wrap_label(text: String, size := 17, color := UiKit.LIMESTONE) -> Label:
	var l := UiKit.label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


# ---------------------------------------------------------------- card galleries

## A row of pill buttons above a grid of real cards: `groups` are [{"label", "ids", "kind"}], kind being
## "turn" (event and penalty cards) or "circumstance". Click a pill to switch, click a card to see it big.
func _card_gallery(groups: Array) -> void:
	var holder := VBoxContainer.new()
	holder.add_theme_constant_override("separation", 16)
	_content.add_child(holder)
	var pills := HBoxContainer.new()
	pills.add_theme_constant_override("separation", 8)
	holder.add_child(pills)
	var grid := GridContainer.new()
	grid.columns = CARD_COLUMNS
	grid.add_theme_constant_override("h_separation", int(CARD_GAP))
	grid.add_theme_constant_override("v_separation", int(CARD_GAP))
	holder.add_child(grid)
	var pill_buttons: Array[Button] = []
	var pick := func(k: int):
		for j in pill_buttons.size():
			_style_pill(pill_buttons[j], j == k)
		_fill_gallery(grid, groups[k])
	for k in groups.size():
		var b := Button.new()
		b.text = "%s  %d" % [groups[k]["label"], groups[k]["ids"].size()]
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.add_theme_font_override("font", UiKit.font("display_bold"))
		b.add_theme_font_size_override("font_size", 18)
		b.pressed.connect(func():
			UiKit.play_sfx("click")
			pick.call(k))
		pills.add_child(b)
		pill_buttons.append(b)
	pick.call(0)


func _style_pill(b: Button, active: bool) -> void:
	var sb := UiKit.box(UiKit.GOLD if active else Color(UiKit.PANEL_HI, 0.8), 99, 0, Color.TRANSPARENT)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 7
	sb.content_margin_bottom = 9
	var hover: StyleBoxFlat = sb.duplicate()
	if not active:
		hover.bg_color = UiKit.LINE
	for state in ["normal", "pressed"]:
		b.add_theme_stylebox_override(state, sb)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var ink := UiKit.INK if active else UiKit.LIMESTONE
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(c, ink)


## Fills the grid with the cards of one group, a few per frame.
func _fill_gallery(grid: GridContainer, group: Dictionary) -> void:
	_gallery_gen += 1
	var gen := _gallery_gen
	for c in grid.get_children():
		grid.remove_child(c)
		c.queue_free()
	var room: float = _scroll.size.x - 44.0 - 14.0
	if room < 400.0:
		room = 900.0
	var s: float = (room - CARD_GAP * (CARD_COLUMNS - 1)) / CARD_COLUMNS / CircumstanceCardFace.WIDTH
	var built := 0
	for id in group["ids"]:
		grid.add_child(_gallery_card(id, group["kind"], s))
		built += 1
		if built % CARDS_PER_FRAME == 0:
			await get_tree().process_frame
			if gen != _gallery_gen or not is_instance_valid(grid):
				return


func _gallery_card(id: String, kind: String, s: float) -> Control:
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(CircumstanceCardFace.WIDTH, CircumstanceCardFace.HEIGHT) * s
	# PASS, not STOP: the mouse wheel has to reach the page behind to scroll it
	slot.mouse_filter = Control.MOUSE_FILTER_PASS
	slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	slot.pivot_offset = slot.custom_minimum_size / 2.0
	var face := CircumstanceCardFace.front_turn(id) if kind == "turn" else CircumstanceCardFace.front(id)
	face.size = Vector2(CircumstanceCardFace.WIDTH, CircumstanceCardFace.HEIGHT)
	face.scale = Vector2.ONE * s
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(face)
	slot.mouse_entered.connect(func():
		slot.z_index = 1
		slot.create_tween().tween_property(slot, "scale", Vector2.ONE * 1.05, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
	slot.mouse_exited.connect(func():
		slot.z_index = 0
		slot.create_tween().tween_property(slot, "scale", Vector2.ONE, 0.12))
	slot.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_open_zoom(id, kind))
	return slot


## One card in big, over the page. A click anywhere, or Esc, puts it away.
func _open_zoom(id: String, kind: String) -> void:
	if _zoom != null:
		return
	Sfx.play("pop")
	_zoom = Control.new()
	OverlayKit.fill_dimmed(_zoom, 0.78).gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			_close_zoom())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_zoom.add_child(center)
	var s := minf(1.0, get_viewport_rect().size.y * 0.9 / CircumstanceCardFace.HEIGHT)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(CircumstanceCardFace.WIDTH, CircumstanceCardFace.HEIGHT) * s
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.pivot_offset = holder.custom_minimum_size / 2.0
	var face := CircumstanceCardFace.front_turn(id) if kind == "turn" else CircumstanceCardFace.front(id)
	face.size = Vector2(CircumstanceCardFace.WIDTH, CircumstanceCardFace.HEIGHT)
	face.scale = Vector2.ONE * s
	holder.add_child(face)
	center.add_child(holder)
	add_child(_zoom)
	_zoom.modulate.a = 0.0
	holder.scale = Vector2.ONE * 0.88
	var tw := create_tween().set_parallel()
	tw.tween_property(_zoom, "modulate:a", 1.0, 0.12)
	tw.tween_property(holder, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _close_zoom() -> void:
	if _zoom != null:
		_zoom.queue_free()
		_zoom = null


# ---------------------------------------------------------------- pages

func _goal() -> void:
	_hero("Build the happiest city in Egkomi", "You are a city planner. Every round you buy tiles from the shared construction site and build them on your own %dx%d mat. Tiles come in two sizes: a [b]1:1[/b] tile covers one square and a [b]2:2[/b] tile covers four. [b]Homes[/b] bring citizens, and every citizen needs different places nearby: a student needs a library, a child needs a school, an older resident needs a clinic, an international resident needs a restaurant. [b]Services, parks, trees and roads[/b] keep them happy. After %d rounds, the planner whose citizens score the most points wins." % [Scoring.SIZE, Scoring.SIZE, GameState.ROUNDS])
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 12)
	for s in [[str(GameState.ROUNDS), "rounds"], [str(GameState.BUYS_PER_TURN), "tiles per player per round"], ["%dx%d" % [Scoring.SIZE, Scoring.SIZE], "grid on each mat"], [str(GameState.START_MONEY), "gold to start with"]]:
		stats.add_child(_card([_stat(s[0], s[1])]))
	for c in stats.get_children():
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(stats)
	_h("Setup")
	_p("Each planner starts with [color=#F2B630][b]%d gold[/b][/color], [b]%d free road tiles[/b] and a mat with [b]pollution %d[/b]. There is no income: the gold you start with has to last all game." % [GameState.START_MONEY, GameState.FREE_ROADS, Scoring.START_POLLUTION])
	_p("The shop holds %d tiles for 4 planners. With 2 or 3 planners, %d random tiles per missing planner are removed so it stays balanced. By the end you will have built %d tiles: %d bought and %d free roads." % [TileDefs.BAG_SIZE, GameState.REMOVED_PER_MISSING_PLAYER, GameState.ROUNDS * GameState.BUYS_PER_TURN + GameState.FREE_ROADS, GameState.ROUNDS * GameState.BUYS_PER_TURN, GameState.FREE_ROADS], UiKit.MUTED, 16)
	_h("Winning")
	_p("Every citizen scores its happiness (-5 to +5) as points. Every loan costs points (%s), and every service that no home can reach costs %d point. A mixed city earns a variety bonus (%s): a kind of citizen counts once at least one of them is happy, and every kind is worth more than the last, because each needs different services at the same time. Totals can be negative. Ties go to the planner with more happy citizens, then more gold left." % [_loan_costs(), Scoring.UNUSED_PENALTY, _variety_costs()])


func _variety_costs() -> String:
	var parts: Array[String] = []
	for kinds in range(2, Scoring.VARIETY_BONUS.size()):
		parts.append("%d kinds +%d" % [kinds, Scoring.VARIETY_BONUS[kinds]])
	return ", ".join(parts)


func _loan_costs() -> String:
	var parts: Array[String] = []
	for n in 3:
		parts.append(str(Scoring.loan_penalty(n + 1) - Scoring.loan_penalty(n)))
	return "%s, then %d and more for every further one" % [", ".join(parts), Scoring.LOAN_PENALTIES[-1] + Scoring.LOAN_STEP]


func _turn() -> void:
	_hero("Your turn", "Draw a card, buy %d tiles, build them, end your turn. Here is how it goes, step by step." % GameState.BUYS_PER_TURN)
	var steps := [
		["Pick a tile", "Click a stack in the construction site. Its gold cost is on the coin and the number in the corner is how many are left. You must buy %d tiles every round." % GameState.BUYS_PER_TURN],
		["Check who lives there", "Homes show round icons for the citizens inside. Hover a home to see what each of them needs, likes and dislikes before you buy."],
		["Build it", "Click an empty lot on your mat. Building is permanent, so think about roads and neighbours first. Right-click or Esc puts the tile back."],
		["Free roads", "Place your %d free roads on any empty lot during any of your turns. They never count as purchases." % GameState.FREE_ROADS],
		["Loan if needed", "Only when you cannot afford the tiles you still have to buy: +%d gold now, and points off at the end (%s)." % [GameState.LOAN_AMOUNT, _loan_costs()]],
		["End your turn", "After %d purchases, end your turn and pass the mouse and keyboard to the next planner." % GameState.BUYS_PER_TURN],
	]
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	for i in steps.size():
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UiKit.label(steps[i][0], 21, UiKit.LIMESTONE, "display_bold"))
		col.add_child(_wrap_label(steps[i][1], 16, UiKit.MUTED))
		var c := _card([_badge(i + 1), col])
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(c)
	_content.add_child(grid)
	_p("[b]Turn order.[/b] The first round is drawn at random. In every later round the city with the fewest points so far picks first; a tie goes to whoever picked later last round. The round banner and the numbered planner cards show the order.", UiKit.MUTED, 16)
	_h("A loan can still pay off")
	_p("A family in a large apartment adds 3 citizens. If all of them are fully happy (+5 each), that is [color=#8DBB3C][b]15 points[/b][/color], more than the %d points the first loan costs. A second loan costs more, so borrow only when it buys you something." % (Scoring.loan_penalty(1)))
	_h("Controls")
	var keys := GridContainer.new()
	keys.columns = 4
	keys.add_theme_constant_override("h_separation", 14)
	keys.add_theme_constant_override("v_separation", 12)
	for row in [
		["Mouse", "Hover for details, click to pick and build"],
		["Arrows / WASD", "Move the gold cursor"],
		["Enter / Space", "Pick or build at the cursor"],
		["Tab", "Switch between shop and mat"],
		["R", "Pick up a free road"],
		["L", "Take a loan"],
		["E", "End your turn"],
		["Esc", "Put a tile back, or open the menu"],
		["H", "This help"],
		["M", "Sound on or off"],
	]:
		var key := UiKit.keycap(row[0])
		key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		keys.add_child(key)
		var what := _wrap_label(row[1], 16, UiKit.LIMESTONE)
		what.custom_minimum_size.x = 250
		keys.add_child(what)
	_content.add_child(keys)


## A grid that spreads its columns evenly, added to the page.
func _grid(columns: int, gap := 14) -> GridContainer:
	var g := GridContainer.new()
	g.columns = columns
	g.add_theme_constant_override("h_separation", gap)
	g.add_theme_constant_override("v_separation", gap)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(g)
	return g


## The width each of `columns` equal columns gets on a page, so every card in a grid is as wide as the others.
func _col_width(columns: int, gap := 14) -> float:
	var room: float = _scroll.size.x - 44.0 - 34.0
	if room < 400.0:
		room = 900.0
	return floorf((room - gap * (columns - 1)) / columns)


## A small picture of a tile kind (a street needs its variant), with its name as a tooltip.
func _tile_icon(kind: int, px: float, variant := 0) -> Control:
	var t := TileDefs.make(kind, variant)
	var icon := UiKit.icon(TileDefs.art_path(t), px)
	icon.mouse_filter = Control.MOUSE_FILTER_PASS
	icon.tooltip_text = TileDefs.display_name(t)
	return icon


## A small caption over a row of things, in a role or tile card.
func _caption(text: String) -> Label:
	return UiKit.label(text.to_upper(), 12, UiKit.MUTED, "body_bold")


func _tiles() -> void:
	_hero("Tile set", "Homes, services, green space and streets. Hover any tile in the game to see exactly what it does on your mat right now. Quantities are for 4 planners. A small pattern in the corner of each tile shows its size: one filled square is a 1:1 tile, four are a 2:2 tile.")
	_p("[b]1:1 tiles[/b] (one square): small and medium apartments, small student residence, bookshop, print shop, clinic, commercial area, market, kiosk, coffee shop, trees and every road you buy. [b]2:2 tiles[/b] (four squares): large apartments, large student residence, university, library, hospital, school, supermarket, restaurant, park and parking place. A road that touches any side of a 2:2 tile connects to it, and the same goes for 2:2 streets.", UiKit.MUTED, 16)
	_p("[b]Player mats.[/b] Before a game you can choose a mat that already has streets and buildings on it, for example a long 2:2 street along the bottom edge and a university on the right. Everyone plays on the same one, and the tiles it came with can never be replaced or lost, so you build your city around them.", UiKit.MUTED, 16)
	for g in TileDefs.GROUPS:
		_h(g["name"])
		var grid := _grid(3)
		for k in g["kinds"]:
			var variants: Array = [0, 1, 2, 3] if k == TileDefs.Kind.ROAD else [0]
			for v in variants:
				grid.add_child(_tile_card(TileDefs.make(k, v), k, v))
	_p("[b]%d tiles in the shop.[/b] With 4 planners, %d are bought and %d stay in the shop. The %d free roads per planner come on top." % [TileDefs.BAG_SIZE, 4 * GameState.ROUNDS * GameState.BUYS_PER_TURN, TileDefs.BAG_SIZE - 4 * GameState.ROUNDS * GameState.BUYS_PER_TURN, GameState.FREE_ROADS], UiKit.LIMESTONE, 16)


## One tile as a card: the picture, its name, what it costs and does, and how many are in the shop.
func _tile_card(t: Dictionary, kind: int, variant: int) -> Control:
	var info := TileDefs.info(kind)
	var pc := PanelContainer.new()
	pc.custom_minimum_size.x = _col_width(3)
	pc.add_theme_stylebox_override("panel", UiKit.box(Color(UiKit.PANEL_HI, 0.55), 20, 0, Color.TRANSPARENT, 16))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	pc.add_child(v)
	var top := HBoxContainer.new()
	top.add_child(UiKit.icon(TileDefs.art_path(t), 84))
	top.add_child(UiKit.spacer())
	var cost := HBoxContainer.new()
	cost.add_theme_constant_override("separation", 5)
	cost.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	cost.add_child(UiKit.icon("res://assets/ui/coin.svg", 28))
	cost.add_child(UiKit.label(str(TileDefs.tile_cost(t)), 28, UiKit.GOLD, "display_bold"))
	top.add_child(cost)
	v.add_child(top)
	v.add_child(UiKit.label(TileDefs.display_name(t), 20, UiKit.LIMESTONE, "display_bold"))
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 6)
	chips.add_child(UiKit.chip(info["category"], UiKit.CATEGORY_COLORS[info["category"]], UiKit.LIMESTONE, 12))
	var in_shop: int = TileDefs.STREET_BAG.count(variant) if kind == TileDefs.Kind.ROAD else info["qty"]
	chips.add_child(UiKit.chip("x%d in shop" % in_shop, UiKit.PANEL, UiKit.MUTED, 12))
	v.add_child(chips)
	var text := _wrap_label(Describe.effect_text(t), 15, UiKit.MUTED)
	text.custom_minimum_size.x = 160
	v.add_child(text)
	return pc


func _people() -> void:
	_hero("People and needs", "Who lives in a home depends on the home you buy. Each citizen has a [b]role[/b] with two needs, a few likes and sometimes a dislike. A met need lifts happiness and a missing one drags it down. Reaching something they like adds +1, and a dislike right next door costs 1.")
	var grid := _grid(3)
	for role in Roles.IDS:
		grid.add_child(_role_card(role))
	_h("Who lives where")
	_p("Every home holds a few possible households. Which one moves in is part of the tile you buy.", UiKit.MUTED, 16)
	for kind in TileDefs.HOUSEHOLDS:
		var flow := HFlowContainer.new()
		flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		flow.add_theme_constant_override("h_separation", 8)
		flow.add_theme_constant_override("v_separation", 8)
		for h in TileDefs.HOUSEHOLDS[kind]:
			flow.add_child(_household_chip(h))
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 10)
		col.add_child(UiKit.label(TileDefs.DEFS[kind]["name"], 21, UiKit.LIMESTONE, "display_bold"))
		col.add_child(flow)
		_content.add_child(_card([UiKit.icon(TileDefs.art_path(TileDefs.make(kind)), 64), col]))
	_p("[b]Parking:[/b] Egkomi has been asking for parking for years, so everyone but the children likes having it within reach (residents with a disability like the reserved bays). Only children dislike it right next to their home (traffic).", UiKit.MUTED, 16)


## One kind of citizen: who they are, what they need, what they like and dislike, as pictures.
func _role_card(role: String) -> Control:
	var d: Dictionary = Roles.DEFS[role]
	var tint := Color(d["color"])
	var pc := PanelContainer.new()
	pc.custom_minimum_size.x = _col_width(3)
	var sb := UiKit.box(Color(UiKit.PANEL_HI, 0.55), 20, 0, Color.TRANSPARENT, 16)
	sb.border_width_top = 5
	sb.border_color = tint
	pc.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	pc.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	head.add_child(UiKit.icon(d["icon"], 52))
	var name_box := VBoxContainer.new()
	name_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_box.add_theme_constant_override("separation", -2)
	name_box.add_child(UiKit.label(d["name"], 22, tint.lightened(0.3), "display_bold"))
	if d["heat_factor"] > 1:
		name_box.add_child(UiKit.label("Feels the heat twice as hard", 13, UiKit.HEAT.lightened(0.2)))
	head.add_child(name_box)
	v.add_child(head)

	v.add_child(_caption("Needs"))
	for n in d["needs"]:
		var need: Dictionary = Roles.NEEDS[n]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		for k in need["kinds"]:
			row.add_child(_tile_icon(k, 34))
		var name := UiKit.label(need["name"], 16, UiKit.LIMESTONE, "body_bold")
		name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(name)
		v.add_child(row)

	v.add_child(_caption("Likes (+1)"))
	var likes := HFlowContainer.new()
	likes.add_theme_constant_override("h_separation", 6)
	likes.add_theme_constant_override("v_separation", 6)
	for k in d["like_kinds"]:
		likes.add_child(_tile_icon(k, 32))
	for s in d["like_streets"]:
		likes.add_child(_tile_icon(TileDefs.Kind.ROAD, 32, s))
	v.add_child(likes)

	if d["dislike_kind"] >= 0:
		v.add_child(_caption("Dislikes next door (-1)"))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.add_child(_tile_icon(d["dislike_kind"], 32))
		var name := UiKit.label(TileDefs.DEFS[d["dislike_kind"]]["name"], 16, UiKit.HEAT.lightened(0.25), "body_bold")
		name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(name)
		v.add_child(row)
	return pc


## A household as a pill: its name, then one round icon for every person in it.
func _household_chip(h: Dictionary) -> Control:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UiKit.box(Color(UiKit.INK, 0.5), 99, 0, Color.TRANSPARENT, 6))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var name := UiKit.label(h["name"], 15, UiKit.LIMESTONE, "body_bold")
	name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name)
	for r in h["members"]:
		var icon := UiKit.icon(Roles.DEFS[r]["icon"], 26)
		icon.mouse_filter = Control.MOUSE_FILTER_PASS
		icon.tooltip_text = Roles.DEFS[r]["name"]
		row.add_child(icon)
	pc.add_child(row)
	return pc


func _happiness() -> void:
	_hero("Citizen happiness", "Every citizen has a happy bar from [color=#E0533A][b]-5[/b][/color] to [color=#8DBB3C][b]+5[/b][/color] and scores it as points. Each citizen in a home has their own bar, so a family can have a happy parent and an unhappy child. The faces on your mat show it live.")
	var rows := [
		["res://assets/ui/route.svg", "Needs: +2, 0 or -2", "A need is met when a road path runs from the home to a matching place (a child's park only needs to be within 2 squares of the home). Both needs met is +2, one is 0, none is -2. Standing next to each other without a road does not count."],
		["res://assets/ui/trophy.svg", "+1 for something they like", "Any one of a citizen's liked places within reach, or a liked street on their route or next to their home, adds +1 once."],
		["res://assets/ui/leaf.svg", "+1 per park or trees nearby (up to +2)", "A park cheers up the homes within 2 squares of it, diagonals included. Trees cheer up the tiles that share an edge with them. Everyone in the home shares it."],
		["res://assets/ui/sun.svg", "-1 for a long, hot walk", "A route of %d or more road squares (3 full-size roads of the old board) to something a citizen needs costs 1 happiness from the heat (older residents feel it twice), unless at least one road on it is shaded." % Scoring.LONG_ROUTE],
		["res://assets/ui/leaf.svg", "Shade", "A road next to trees or a park counts as shaded. It shows a leafy green shadow on the side facing the trees and a Shade badge. Grey smog clouds are pollution, not shade."],
	]
	for r in rows:
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UiKit.label(r[1], 20, UiKit.LIMESTONE, "display_bold"))
		col.add_child(_wrap_label(r[2], 16, UiKit.MUTED))
		_content.add_child(_card([UiKit.icon(r[0], 44), col]))
	_h("Pollution")
	_p("Every mat starts at pollution %d. Each [b]park lowers it by 3[/b] and each [b]trees tile by 1[/b], never below 0. At the end it changes the happiness of every citizen on that mat:" % Scoring.START_POLLUTION)
	var bands := HBoxContainer.new()
	bands.add_theme_constant_override("separation", 12)
	for b in [["0 to 7", "No change", UiKit.OLIVE], ["8 to 12", "-1 happiness", UiKit.GOLD], ["13 to %d" % Scoring.START_POLLUTION, "-2 happiness", UiKit.HEAT]]:
		var v := VBoxContainer.new()
		v.add_child(UiKit.label(b[0], 28, b[2], "display_bold"))
		v.add_child(UiKit.label(b[1], 16, UiKit.LIMESTONE))
		var c := _card([v])
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bands.add_child(c)
	_content.add_child(bands)
	_p("Example: 2 parks and 2 trees bring a mat from %d down to %d, so pollution no longer affects anyone. A mat with no green space stays at %d and every citizen on it loses 2 happiness." % [Scoring.START_POLLUTION, Scoring.START_POLLUTION - 8, Scoring.START_POLLUTION], UiKit.MUTED, 16)


func _complaints() -> void:
	_hero("Complaints", "Every unhappy citizen (below 0) files a complaint. A missing need always comes first and is named in plain words, for example [b]No library within reach[/b]. You can see them on each home's card while you play.")
	for type in Describe.COMPLAINTS:
		var c: Dictionary = Describe.COMPLAINTS[type]
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UiKit.label(type, 21, UiKit.LIMESTONE, "display_bold"))
		col.add_child(_wrap_label("%s The fix: %s." % [c["meaning"], c["fix"].to_lower()], 16, UiKit.MUTED))
		_content.add_child(_card([UiKit.icon(c["icon"], 44), col]))
	_p("At the end of the game, each planner names the one change that would add the most points to their city. Every citizen below +5 and every service nobody reaches still has room to improve, so there is always something to name.")


func _turn_cards() -> void:
	_hero("Event and penalty cards", "At the start of every turn, tap the coin. [b]Heads[/b]: tap the [color=#6FD08C][b]event deck[/b][/color] for good news. [b]Tails[/b]: tap the [color=#F08A78][b]penalty deck[/b][/color] for trouble. The card is shown to everyone and its effect happens [b]at once[/b].")
	var decks := HBoxContainer.new()
	decks.add_theme_constant_override("separation", 14)
	for pair in [[CardDefs.EVENT, "Event cards", "Reward planners: gold, free tiles, cheaper tiles, extra buys or points. Some reward several planners, and some take from the others."],
			[CardDefs.PENALTY, "Penalty cards", "Punish planners: fees, lost tiles, dearer tiles, fewer buys or lost points. Some hit several planners, and some give you a choice of pain."]]:
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		col.add_child(UiKit.label(pair[1], 22, UiKit.LIMESTONE, "display_bold"))
		col.add_child(_wrap_label(pair[2], 16, UiKit.MUTED))
		var back_slot := Control.new()
		var s := 0.24
		back_slot.custom_minimum_size = Vector2(CircumstanceCardFace.WIDTH, CircumstanceCardFace.HEIGHT) * s
		var back := CircumstanceCardFace.back_turn(pair[0])
		back.size = Vector2(CircumstanceCardFace.WIDTH, CircumstanceCardFace.HEIGHT)
		back.scale = Vector2.ONE * s
		back_slot.add_child(back)
		var c := _card([back_slot, col])
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		decks.add_child(c)
	_content.add_child(decks)
	_p("[b]How cards work.[/b] Each deck has %d cards and a card is drawn at most once per game. Gold never drops below 0, and you cannot pay more than you have. \"The player with the most or least\" means everyone who ties for it. A card that changes prices or the number of tiles you may buy lasts for this turn only. A free tile is placed from the [b]Free tile[/b] button (B), costs nothing and is not one of your purchases. Some cards ask you to choose between two options. Every card you draw is remembered: on the final scoring screen, click the small cards under a city to see each one." % CardDefs.DECK_SIZE, UiKit.MUTED, 16)
	_h("Every card in the game")
	_p("Click a card to see it big.", UiKit.MUTED, 16)
	_card_gallery([
		{"label": "Event cards", "ids": CardDefs.ids(CardDefs.EVENT), "kind": "turn"},
		{"label": "Penalty cards", "ids": CardDefs.ids(CardDefs.PENALTY), "kind": "turn"},
	])


func _events() -> void:
	_hero("Hidden circumstances", "At the start of every round one hidden circumstance card is turned over. The deck holds %d cards and a game draws %d of them, so nobody knows what is coming. Every planner gets the same card, and it changes only happiness, points or gold, never your tiles." % [CircumstanceDefs.IDS.size(), GameState.ROUNDS])
	_p("[b]Happiness effects[/b] stay on until the end of the game and count in every score. [b]Gold effects[/b] happen once, the moment the card is revealed (gold never drops below 0). The cards shown so far sit in the top bar: hover one to read it again.", UiKit.MUTED, 16)
	_p("[b]Tip:[/b] keep a little gold in reserve for a budget cut, shade your long walks for a heatwave, and put parks and trees next to your homes. Those choices pay off whichever card turns up.", UiKit.LIMESTONE, 16)
	_h("Every circumstance card")
	_p("Click a card to see it big.", UiKit.MUTED, 16)
	var weather: Array = []
	var city: Array = []
	for id in CircumstanceDefs.IDS:
		if CircumstanceDefs.info(id)["family"] == CircumstanceDefs.FAMILY_WEATHER:
			weather.append(id)
		else:
			city.append(id)
	_card_gallery([
		{"label": "All", "ids": CircumstanceDefs.IDS.duplicate(), "kind": "circumstance"},
		{"label": "Weather", "ids": weather, "kind": "circumstance"},
		{"label": "City", "ids": city, "kind": "circumstance"},
	])


func _objectives() -> void:
	_hero("Why this game exists", "The game is built around four objectives about everyday life in Egkomi. Every tile tooltip shows which ones it serves.")
	for o in UiKit.OBJECTIVES:
		var tag := UiKit.label(o, 30, UiKit.GOLD, "display_bold")
		tag.custom_minimum_size.x = 56
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UiKit.label(UiKit.OBJECTIVE_SHORT[o], 20, UiKit.LIMESTONE, "display_bold"))
		col.add_child(_wrap_label(UiKit.OBJECTIVES[o], 16, UiKit.MUTED))
		_content.add_child(_card([tag, col]))
	_p("[b]Where you meet them:[/b] road placement on your mat is the city's circulation (O1). Complaints point at what to improve (O2). Parks and trees shade walking routes (O3). Happiness turns routes, greenery and pollution into score (O4).", UiKit.LIMESTONE, 16)
